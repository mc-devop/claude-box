#!/usr/bin/env python3
"""Check core/managed-settings.json: auto mode's box description, telemetry
off, the commit hook and the ask rules on your ~/.claude files.

The image installs it as /etc/claude-code/managed-settings.json. Claude
Code drops a broken managed file silently, so this refuses any key, value
or rule but these, checks the Containerfile installs it and the hook
readable, and runs the hook on look-alike commands. Exit status: 0 = passed.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors = []

try:
    data = json.loads((ROOT / "core/managed-settings.json").read_text())
except (OSError, ValueError) as e:
    sys.exit(f"managed-settings.json: {e}")

if set(data) != {"autoMode", "env", "hooks", "permissions"}:
    errors.append(f"top-level keys {sorted(data)}, want autoMode env hooks permissions")
TELEMETRY = ["DISABLE_TELEMETRY", "DISABLE_ERROR_REPORTING",
             "DISABLE_FEEDBACK_COMMAND", "SUPERPOWERS_DISABLE_TELEMETRY"]
if data.get("env") != {k: "1" for k in TELEMETRY}:
    errors.append(f"env is {data.get('env')}, want each of {TELEMETRY} set to \"1\"")
ASK = ["Edit(~/.claude/CLAUDE.md)", "Edit(~/.claude/.dev)",
       "Edit(~/.claude/rules/**)", "Edit(~/.claude/settings.json)"]
if data.get("permissions") != {"ask": ASK}:
    errors.append(f"permissions is {data.get('permissions')}, want only ask: {ASK}")
HOOK = "/usr/local/bin/no-commit-on-main"
want_hooks = {"PreToolUse": [{"matcher": "Bash", "hooks": [
    {"type": "command", "command": HOOK, "statusMessage": "Checking branch before commit"}]}]}
if data.get("hooks") != want_hooks:
    errors.append(f"hooks is {data.get('hooks')}, want {want_hooks}")
auto = data.get("autoMode", {})
if set(auto) != {"environment"}:
    errors.append(f"autoMode keys {sorted(auto)}, want only environment")
env = auto.get("environment", [])
if len(env) != 1 or not isinstance(env[0], str):
    errors.append("environment must be exactly one string")
else:
    entry = env[0]
    if not entry.startswith("**Host containment**:"):
        errors.append("the entry doesn't start with **Host containment**:")
    for name in ("/work/<name>", "/projects", "/home/claude/.claude", "dev run",
                 # leave the box through files the owner runs on the laptop
                 "`.git` hooks", "out/actions.txt",
                 # the one exception under ~/.claude, by path
                 "~/.claude/projects/<folder>/memory/",
                 # handoffs to the owner's other sessions stay inside
                 "SendMessage", "claude-box sessions"):
        if name not in entry:
            errors.append(f"the entry doesn't name {name}")

containerfile = (ROOT / "core/Containerfile").read_text()
if not re.search(r"^COPY .*managed-settings\.json.* /etc/claude-code/$",
                 containerfile, re.M):
    errors.append("Containerfile doesn't copy managed-settings.json to /etc/claude-code/")
if "chmod 644 /etc/claude-code/*" not in containerfile.replace("*.md", "?"):
    errors.append("Containerfile doesn't chmod 644 /etc/claude-code/*")

# The box's own mods and run-actions, root-owned, loaded for every session.
PLUGIN = "/usr/local/share/claude-box/plugins/box-workflow"
if not re.search(rf"^COPY plugin/box-workflow {PLUGIN}$", containerfile, re.M):
    errors.append(f"Containerfile doesn't copy plugin/box-workflow to {PLUGIN}")
if not re.search(r"^COPY bin/run-actions /usr/local/bin/run-actions$", containerfile, re.M):
    errors.append("Containerfile doesn't copy bin/run-actions to /usr/local/bin/")
if f"ENV CLAUDE_CODE_PLUGIN_DIRS={PLUGIN}" not in containerfile:
    errors.append("Containerfile doesn't set CLAUDE_CODE_PLUGIN_DIRS to the plugin")
if not re.search(rf"^COPY bin/no-commit-on-main {HOOK}$", containerfile, re.M):
    errors.append(f"Containerfile doesn't copy bin/no-commit-on-main to {HOOK}")


def check_hook():
    """The hook on look-alike commands: blocked on main, let through otherwise."""
    script = ROOT / "core/bin/no-commit-on-main"
    if not os.access(script, os.X_OK):
        errors.append(f"{script.relative_to(ROOT)} is missing or not executable")
        return
    env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

    def run(cmd, cwd):
        p = subprocess.run([str(script)], input=json.dumps({"tool_input": {"command": cmd}, "cwd": cwd}),
                           capture_output=True, text=True, env=env)
        return p.returncode, p.stderr

    with tempfile.TemporaryDirectory() as repo, tempfile.TemporaryDirectory() as plain:
        git = lambda *a: subprocess.run(["git", "-C", repo, *a], check=True, capture_output=True, env=env)
        git("init", "-q", "-b", "main")
        git("commit", "-q", "--allow-empty", "-m", "first")
        cases = [("git commit -m x", repo, 2), ("git -C . commit -m x", repo, 2),
                 ("cd . && git commit -am x", repo, 2),
                 ("git -c user.name=x commit -m x", repo, 2), ("GIT_EDITOR=true git commit", repo, 2),
                 ("/usr/bin/git commit -m x", repo, 2), ("{ git commit -m x; }", repo, 2),
                 ("if true; then git commit -m x; fi", repo, 2), ("command git commit -m x", repo, 2),
                 ("git switch -c claude/x && git commit -m x", repo, 0),
                 ("echo git commit", repo, 0), ("git commit", plain, 0)]
        for cmd, cwd, want in cases:
            code, err = run(cmd, cwd)
            if code != want or (want == 2 and not err.startswith("Blocked: this repo is on main")):
                errors.append(f"hook: {cmd!r} in {'a repo on main' if cwd == repo else 'a non-repo'}: exit {code}, want {want}")
        git("switch", "-q", "-c", "claude/x")
        code, _ = run("git commit -m x", repo)
        if code != 0:
            errors.append(f"hook: 'git commit -m x' on claude/x: exit {code}, want 0")


check_hook()

for e in errors:
    print(f"managed settings: {e}")
if errors:
    sys.exit(1)
print("managed settings: ok")
