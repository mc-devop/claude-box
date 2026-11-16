# Core-rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A box has every rule its own mechanics need without the
workflow plugin. Your `settings.json` no longer has to carry the
telemetry switches or the commit hook. Claude asks before editing your
`~/.claude/` files, and knows your laptop's tools before writing a
`local` step.

**Architecture:** Core's rules are three files in `core/rules/`,
installed into `/etc/claude-code/`. Claude Code reads only
`/etc/claude-code/CLAUDE.md` there (there's no managed rules folder,
[check 4](findings-claude-code-checks.md)), so that file imports the
other two with `@`. The `dev run` format moves into a skill in core's
plugin. The managed settings gain `env`, a `PreToolUse` hook from the
image and `ask` rules. At every box start, `dev` writes a host-facts
file and mounts it read-only.

**Tech Stack:** Markdown rules and a skill, JSON managed settings, a
python3 hook, bash (`core/lib/mounts.sh`), and the fake Podman in
`tests/test_dev.sh`.

**Spec:** [spec.md](spec.md), deliverable 3: D8–D11. Also the stale
wording branch 2's review found (M-9): [layers.md](../../../plugins/workflow/rules/claude-md.md),
[starter.md](../../../plugins/workflow/rules/markdown.md), and
[Containerfile](../../../core/Containerfile) line 14 (the `local.md`
"older layers" comment).

## Decisions this plan adds (for the owner's review)

| # | Decision | Why |
|---|---|---|
| R1 | **This branch's first commit is moves only, with the path fixes:** `core/company/CLAUDE.md` → `core/rules/CLAUDE.md`, `core/company/managed-settings.json` → `core/managed-settings.json` (`core/company/` goes), `plugins/workflow/rules/change-management.md` → `core/rules/branches-and-evidence.md`, `plugins/workflow/rules/layers.md` → `plugins/workflow/rules/claude-md.md`. **Deviates from the change rules**, like branch 2's P5: on a branch of moves alone, `change-management.md` would sit in `core/rules/` unimported, and `main` would load fewer rules. The suite passes at this commit | History follows each file. "Company" leaves the code paths too (D1) |
| R2 | `core/rules/CLAUDE.md` ends with two import lines, `@/etc/claude-code/branches-and-evidence.md` and `@/etc/claude-code/levels.md`. The Containerfile copies all of `core/rules/` into `/etc/claude-code/`. `local.md` and its import go: no layer has written it since branch 2 | There's one entry file because Claude Code reads only that one |
| R3 | The commit hook is `core/bin/no-commit-on-main`: today's `~/.claude/hooks/no-commit-on-main.py` with the same logic, installed at `/usr/local/bin/`. The image's `dnf` line names `python3` explicitly | Fedora's base image happens to have python3 today; naming it means the hook can rely on it |
| R4 | Host facts format, one fact per line: `os <PRETTY_NAME>` (`os unknown` without `/etc/os-release`), `shell <basename of $SHELL>` (`shell unknown`), `has <names>`, `lacks <names>`, both in the spec's order. The file is `$(dirname "$APPROVED")/host`, one per laptop, rewritten at every box start (scratch boxes too) | Simple for the skill to read. It sits under `~/.local/state`, out of every box's reach |
| R5 | `core/README.md` starts on this branch with two sections, *Rules* (how they load) and *What `dev run` refuses* (D10). Branch 4 adds the map (D14) | D10 is in this branch's spec scope; the map isn't |

## Global Constraints

- Telemetry env, exact: `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`,
  `DISABLE_FEEDBACK_COMMAND`, `SUPERPOWERS_DISABLE_TELEMETRY`, each `"1"`.
- `ask` rules, exact: `Edit(~/.claude/CLAUDE.md)`, `Edit(~/.claude/.dev)`,
  `Edit(~/.claude/rules/**)`, `Edit(~/.claude/settings.json)`.
- Host tools, in this order: `git gh podman ssh rsync flatpak rpm-ostree
  dnf brew toolbox systemctl sudo python3 curl jq`.
- The skill is `box-workflow:dev-run`: `core/plugin/box-workflow/skills/dev-run/SKILL.md`.
- Neither "company", "pack" nor "layer" appears in `core/rules/` or
  `plugins/workflow/rules/` (D1; the acceptance greps for it).
- `tests/run.sh` passes before every commit.

## Review Focus

- **The hook on look-alike commands:** `git -C . commit` and
  `cd x && git commit` on `main` are blocked. `echo git commit`, a
  commit after `git switch -c`, a commit on a branch, and a folder
  that isn't a repo pass. Task 3 tests each.
- **A broken managed file is dropped silently** by Claude Code, so
  every key, env value and rule is checked exactly, not just for
  presence. Task 3.
- **A laptop without `/etc/os-release`**, or with a quoted
  `PRETTY_NAME`: `os unknown`, or the name without quotes. Task 4
  tests both through `host_facts`' optional second argument.
- **A scratch box** gets the host file too (it has no project level,
  but it does have a laptop). Task 4.
- **An import or a rules file gone astray:** each `@/etc/claude-code/<f>`
  in `core/rules/CLAUDE.md` names a file in `core/rules/`, and each
  file there is imported. Task 2 tests both.

---

### Task 1: Moves (R1)

**Files:** the four `git mv`s of R1. Path fixes only: `core/Containerfile`
(`COPY rules/CLAUDE.md …`, `COPY managed-settings.json …`),
`tests/check_managed_settings.py` (path, Containerfile regex),
`tests/run.sh` (`rule=plugins/workflow/rules/claude-md.md`),
`tests/test_dev.sh:830` (`core/rules/CLAUDE.md`), and the links in
`docs/system/architecture/README.md`, `02-container.md`, `03-deployment.md`
and `docs/system/runbook.md`.

- [ ] **Step 1:** Make the moves and the path fixes, nothing else.
- [ ] **Step 2: Run** `tests/run.sh`. Expected: `ALL PASSED`.
- [ ] **Step 3: Commit** `Moves: core's rules into core/rules/, managed-settings.json into core/, layers.md becomes claude-md.md`.

### Task 2: The rules split, the `dev-run` skill, the stale wording

**Files:** `core/rules/CLAUDE.md`, `core/rules/branches-and-evidence.md`,
`core/rules/levels.md` (new), `core/Containerfile`,
`core/plugin/box-workflow/skills/dev-run/SKILL.md` (new),
`plugins/workflow/rules/claude-md.md`, `starter.md`, `markdown.md`,
`plugins/workflow/skills/closing/SKILL.md`,
`plugins/workflow/starter/CLAUDE.md.starter`, `tests/run.sh`,
`rules-map.md` (new, in this folder)

**Interfaces:**
- Produces: `/etc/claude-code/{CLAUDE.md,branches-and-evidence.md,levels.md}`
  in the image. Task 4 relies on the skill's `/etc/claude-box/host`
  instruction.

- [ ] **Step 1: Write the failing checks** in `tests/run.sh`, whose
  section `== Layers rule` becomes `== Rules`. The starter-sections check
  stays, on `claude-md.md`. Add:
  - every `^@/etc/claude-code/(.+)$` line of `core/rules/CLAUDE.md`
    names an existing `core/rules/<f>`, and every `core/rules/*.md`
    except `CLAUDE.md` is imported;
  - `grep -rniwE 'company|packs?|layers?' core/rules plugins/workflow/rules`
    prints nothing;
  - the Containerfile has `^COPY rules/ /etc/claude-code/$` and no `local.md`;
  - `core/plugin/box-workflow/skills/dev-run/SKILL.md` has `name: dev-run`
    in its front matter and names `/etc/claude-box/host`.
- [ ] **Step 2: Run** `tests/run.sh`. Expected: FAIL in `== Rules`.
- [ ] **Step 3: Write the rules.**
  - `branches-and-evidence.md`: the sections *Branches and approval* and
    *Evidence and secrets*, word for word. *Commands for the human* leaves.
  - `CLAUDE.md`: the "You can't push" bullet gains the intro that left:
    anything the human has to run goes into `out/actions.txt`, run with
    `dev run`, never commands to copy one by one; before writing that
    file, load `box-workflow:dev-run`. `# Your rules` and the
    `local.md` import are replaced by R2's two import lines.
  - `levels.md`, exact:

    ```markdown
    # Levels

    - Rules and config come at two levels, each with a `CLAUDE.md` (how
      Claude works) and a `.dev` (what's in the box): global, in
      `~/.claude/` with its `rules/`, for every project; project, in the
      project with its `.claude/`. These core rules load beneath both,
      and no session can change them.
    - One fact, one level: how the human works across projects is global,
      what one project owns is that project's; link to a fact from
      elsewhere, never copy it. A level narrows core's limits, never
      loosens them.
    - A project that works differently from the global default says so in
      its `CLAUDE.md`, one line per difference: "Differs from the default:
      the rule (why)".
    ```
- [ ] **Step 4: Write the skill.** Front matter: `name: dev-run`, and
  `description: Use before writing or changing out/actions.txt, the steps the human runs with dev run - its format, and the laptop facts a local step needs`.
  The body has the bullets of *Commands for the human*, word for word,
  except the first. That one becomes: before a `local` step, read
  `/etc/claude-box/host` (the laptop's OS, shell, and the commands it
  `has` and `lacks`); a `local` step uses only commands it has (and the
  project's checks), and never installs anything.
- [ ] **Step 5: The workflow's wording.**
  - `claude-md.md`: keep the `paths:` front matter. The title becomes
    `# A project's CLAUDE.md`. The body is one paragraph: where each
    fact goes is core's levels rule; then the sections sentence, word
    for word; the Rules section holds the project's own rules and its
    "Differs from the default" lines.
  - `starter.md`: "pack" → "plugin" (title and both sentences).
  - `markdown.md`: "workflow pack's starter" → "workflow plugin's
    starter". The `always flowchart TD` bullet and the `C4 look via
    classDef` bullet leave (D8). "Keep them tall, not wide:" becomes
    "Keep them small:".
  - `closing/SKILL.md:10`: "the managed policy (documentation.md,
    change-management.md)" → "the rules (core's and documentation.md)".
  - `CLAUDE.md.starter`: "the company default" → "the default", twice.
- [ ] **Step 6: Containerfile.** Replace the two `COPY company…` lines
  and the `local.md` `RUN` with `COPY rules/ /etc/claude-code/`,
  `COPY managed-settings.json /etc/claude-code/` and
  `RUN chmod 644 /etc/claude-code/*`. Add `python3` to the `dnf` line (R3).
- [ ] **Step 7: Write `rules-map.md`:** a table
  `| Old file | Rule (its first words) | New place |`, one row per bullet
  or paragraph of the old `core/company/CLAUDE.md`, `change-management.md`
  and `layers.md`, and of the two Mermaid bullets. The Mermaid bullets
  go to the owner's `~/.claude/rules/mermaid.md` (a draft, see *After
  the branch*). `local.md`'s import: gone, with the reason from R2.
- [ ] **Step 8: Run** `tests/run.sh` (in the box, so `== Mods` runs
  `claude plugin validate core/plugin/box-workflow` with the skill).
  Expected: `ALL PASSED`.
- [ ] **Step 9: Commit** `core-rules: core's rules in core/rules/, the dev-run skill, the workflow's wording`.

### Task 3: Managed settings (D9)

**Files:** `core/managed-settings.json`, `core/bin/no-commit-on-main`
(new, mode 755), `core/Containerfile`, `tests/check_managed_settings.py`

**Interfaces:**
- Produces: `/usr/local/bin/no-commit-on-main`, reading the hook's JSON
  on stdin (`tool_input.command`, `cwd`). Exit 2 with
  `Blocked: this repo is on main. …` on stderr; 0 otherwise.

- [ ] **Step 1: Write the failing checks** in `check_managed_settings.py`:
  - the top-level keys are exactly `autoMode env hooks permissions`;
  - `env` is exactly the four telemetry variables, each `"1"`;
  - `permissions` is exactly `{"ask": [the four rules]}`;
  - `hooks` is exactly one `PreToolUse` entry, `matcher` `Bash`, one
    `command` hook with `/usr/local/bin/no-commit-on-main`;
  - the Containerfile has `^COPY bin/no-commit-on-main /usr/local/bin/no-commit-on-main$`;
  - `check_hook()`: in a temp `git init -b main` repo with one commit,
    run the script with `{"tool_input": {"command": c}, "cwd": repo}`:
    `git commit -m x`, `git -C . commit -m x` and `cd . && git commit -am x`
    → exit 2, stderr starts `Blocked: this repo is on main`;
    `git switch -c claude/x && git commit -m x` and `echo git commit`
    → 0. On a branch `claude/x`: `git commit -m x` → 0. With `cwd` a
    non-repo temp folder: `git commit` → 0.
- [ ] **Step 2: Run** `python3 tests/check_managed_settings.py`. Expected: FAIL.
- [ ] **Step 3: Implement.** Port the hook's logic as it is (its regexes
  included); its header comment names the managed settings as its
  caller. Add the three keys to `managed-settings.json`, with
  `"statusMessage": "Checking branch before commit"` on the hook. Add the
  `COPY` line next to `run-actions`'. Update the module docstring.
- [ ] **Step 4: Run** `tests/run.sh`. Expected: `ALL PASSED`.
- [ ] **Step 5: Commit** `core-rules: telemetry off, the commit hook and ask rules in managed settings`.

### Task 4: Host facts (D11)

**Files:** `core/lib/mounts.sh`, `tests/test_dev.sh`

**Interfaces:**
- Produces: `host_facts <out> [os-release]` writes R4's four lines to
  `<out>`. `os-release` defaults to `/etc/os-release`. The tool list
  is `HOST_TOOLS`, from the Global Constraints. `choose_mounts` calls it
  before its scratch return and adds
  `-v "$(dirname "$APPROVED")/host:/etc/claude-box/host:ro,z"`.

- [ ] **Step 1: Write the failing tests:**
  - `host-facts`: `dev shell` in `p` with `SHELL=/bin/bash` → `has
    "$HOME/.local/state/claude-box/host:/etc/claude-box/host:ro,z"`.
    In the file: line 1 is `os $(. /etc/os-release && echo "$PRETTY_NAME")`;
    line 2 is `shell bash`; each `HOST_TOOLS` name appears exactly once
    across the `has` and `lacks` lines; `git` is in `has`. A fake
    `brew` on `PATH` → `brew` is in `has`.
  - `host-facts-scratch`: a scratch box start (as `mounts-scratch`
    starts one) → the same mount.
  - `host-facts-os`: `bash -c '. core/lib/mounts.sh; host_facts "$1" "$2"'`.
    With a missing file → line 1 is `os unknown`. With a file holding
    `PRETTY_NAME="Fedora Linux 44 (Workstation Edition)"` → `os Fedora Linux 44 (Workstation Edition)`.
- [ ] **Step 2: Run** `bash tests/test_dev.sh`. Expected: FAIL at `host-facts`.
- [ ] **Step 3: Implement** `host_facts` (`command -v` per name; read
  `PRETTY_NAME` with `sed`, strip one pair of quotes, don't `source`
  the file) and the call in `choose_mounts`.
- [ ] **Step 4: Run** `tests/run.sh`. Expected: `ALL PASSED`.
- [ ] **Step 5: Commit** `core-rules: host facts at /etc/claude-box/host`.

### Task 5: `core/README.md` and the docs

**Files:** `core/README.md` (new), `README.md` (*Rules and plugins*),
`docs/system/architecture/README.md` (*Rules*, the workflow row,
*Known limits*), `03-deployment.md` (*The image*, *Mounts*),
`docs/system/runbook.md` (*Change the rules*),
`docs/direction/backlog.md` (lines 89 and 132: the old file names)

- [ ] **Step 1: `core/README.md`:**
  - *Rules*: core's three files load from the managed policy, where no
    session can change them, through `CLAUDE.md`'s imports (R2), and
    under both levels.
  - *What `dev run` refuses*: in plain words, each case of
    `run-actions`' `install_risk` (local steps) and `secret_risk`
    (local and root steps), the `--apply` and `--main` arguments in
    a host step, and that refusals live in the script (D10).
- [ ] **Step 2: Docs**, where this branch changed what they describe.
  - The architecture's *Rules* table: core's row links
    `core/rules/`, the skill and
    `core/README.md`.
  - The workflow row loses `change-management.md` and describes
    `claude-md.md`.
  - *Known limits*: D9's limit (a script writing those files isn't
    asked about).
  - Deployment: the image table (the rules files, the hook, python3)
    and the mounts table (`/etc/claude-box/host`).
  - The README's "change management" moves from the workflow's list to
    the box's own rules.
  - The runbook's *Change the rules* links `core/rules/`.
- [ ] **Step 3: Run** `tests/run.sh`. Expected: `ALL PASSED`.
  `git grep -nE 'core/company|change-management|layers\.md|local\.md' -- ':!docs/change'`
  prints nothing.
- [ ] **Step 4: Commit** `core-rules: core/README.md, the docs`.

## After the branch

1. A fresh reviewer on the most capable model reads the whole branch,
   and its Critical and Important findings are fixed.
2. Drafts in `out/` for the owner, for after the merge (D16):
   - `out/claude-settings.json`: `~/.claude/settings.json` without its
     `env` and `hooks` keys. Its `allow Edit(~/.claude/CLAUDE.md)` stays
     for the owner to decide; the managed `ask` prompts anyway
     ([check 5a](findings-claude-code-checks.md)).
   - `out/claude-CLAUDE.md`: the global `CLAUDE.md` without the
     "My hook" bullet.
   - `out/claude-rules-mermaid.md`: the two Mermaid bullets, for
     `~/.claude/rules/mermaid.md`.
3. The merge run: merge, push. The run puts each draft in place only
   if the target still matches what the draft was made from, and
   deletes `~/.claude/hooks/no-commit-on-main.py`. Then the owner runs
   `dev build` (the base changed) and starts a new box.
4. The acceptance evidence is read in that box: `/etc/claude-box/host`,
   core's rules and the `dev-run` skill listed without `use workflow`,
   and the `ask` prompt's text in auto mode.
