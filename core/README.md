# core

claude-box itself: isolation, `dev`, `dev run`, the inbox, and the rules
those need. It's always on, and only this repo changes it.

## Rules

Core's rules are the files in [rules/](rules/):
[CLAUDE.md](rules/CLAUDE.md) (the environment),
[branches-and-evidence.md](rules/branches-and-evidence.md) and
[levels.md](rules/levels.md). The image installs them into
`/etc/claude-code/`, Claude Code's managed policy, owned by root, where
no session can change them. Claude Code reads only `CLAUDE.md` there, so
it imports the other two with `@/etc/claude-code/<file>`. They load
beneath both levels, global and project, with or without the workflow
plugin. The `dev run` file format is a skill of the box's own plugin,
[box-workflow:dev-run](plugin/box-workflow/skills/dev-run/SKILL.md),
loaded when Claude writes `out/actions.txt`; so is the procedure for
messages between projects' sessions,
[box-workflow:handoff](plugin/box-workflow/skills/handoff/SKILL.md).

[managed-settings.json](managed-settings.json) sits beside them, in the
same place: auto mode's description of the box, telemetry off, the
[commit hook](bin/no-commit-on-main) that refuses `git commit` on `main`,
and `ask` rules for edits to your `~/.claude/` files.

## What `dev run` refuses

[run-actions](bin/run-actions) reads the whole `out/actions.txt` before
running anything, and runs none of it if one step is refused. The
refusals live in the script, not in any file a box can write.

A `local` step that installs software on your laptop:

- a downloaded script piped into a shell (`curl … | sh`, `wget … | bash`);
- `pip install` (also `python3 -m pip install`), `pipx install`,
  `uv tool install`;
- `dnf install`, `yum install`, `rpm-ostree install`, `brew install`,
  `cargo install`;
- `npm install --global`.

A tool a project needs goes into its `.dev` instead.

A `local` or `root` step that could print a secret into the log, which
Claude reads:

- a Podman secret's value (`--showsecret`), or Podman's secret storage;
- a process's environment (`/proc/*/environ`), or an environment dump
  (`env`, `printenv`, `export -p`, `declare -x`);
- `podman inspect` without `--format`, or `podman generate`, which show
  environment variables;
- reading a file that looks like it holds a secret (a token, password,
  credential, `.env`, `.pem`, `.key` or SSH key file) with `cat`, `less`,
  `head`, `base64` and the like;
- shell history, unless only counted (`grep -c`).

A `host` step that isn't a `<name>.sh` script, or whose arguments hold
anything but letters, digits, `.`, `_` and `-`, or that passes
`--apply` or `--main=` itself: `dev run` takes the script from your
`main`, does the dry run first and adds `--apply` after your yes.

## Map

| Part | What it is | Where it runs | What it feeds |
|---|---|---|---|
| [Containerfile](Containerfile) | The image: Fedora, Claude Code, core's rules and plugin | Built on your laptop, from `main` | Every box |
| [defaults.dev](defaults.dev) | Every kind of `.dev` line, explained with examples; the lines used without a `~/.claude/.dev` | Read by `dev` on your laptop | Your config, a project's `.dev` |
| [managed-settings.json](managed-settings.json) | Auto mode's description of the box, telemetry off, the commit hook, the `ask` rules | `/etc/claude-code/` in the image | Every session |
| [rules/](rules/) | Core's rules (above) | `/etc/claude-code/` in the image | Every session, under both levels |
| [plugin/box-workflow/](plugin/box-workflow/) | The box's own plugin: the inbox, `dev run`'s rows and toasts, the branch status line, the `dev-run` and `handoff` skills | The image, loaded by every session | Every session |
| [bin/run-actions](bin/run-actions) | `dev run`: runs the steps in `out/actions.txt`, with the refusals above | Your laptop (and `--check` in the box) | Your machine and servers |
| [bin/stage-seed](bin/stage-seed) | Installs marketplace plugins into a seed | In a throwaway box that sees only the seed, started by `dev` | The staged seed |
| [bin/no-commit-on-main](bin/no-commit-on-main) | The commit hook | In every box, before each Bash command | Claude's commits |
| [lib/](lib/) | `dev`'s modules: [common.sh](lib/common.sh) (the image, built from `main`, and its core check), [conf.sh](lib/conf.sh) (reading `.dev`, the approved copy), [layer.sh](lib/layer.sh) (approval, the image of your config), [mounts.sh](lib/mounts.sh) (rules mounts, host facts), [project.sh](lib/project.sh) (a project's `.dev`, image, plugins), [groups.sh](lib/groups.sh), [box.sh](lib/box.sh) (starting and joining boxes), [scratch.sh](lib/scratch.sh) | Your laptop, sourced by [dev](../dev) | Every box start |
