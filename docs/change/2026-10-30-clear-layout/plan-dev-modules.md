# dev modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dev` becomes the command parser over `box/lib/` modules (spec
D11); `install.sh` becomes `dev install` and `box/company/local.md` is
written by the build (D10).

**Architecture:** Functions move unchanged into modules that `dev`
sources before its `case`; the one new behaviour is `dev install`.

**Tech Stack:** Bash, ShellCheck, `tests/test_dev.sh`.

**Spec:** [spec.md](spec.md), branch 2 (`claude/dev-modules`).

## Global Constraints

- Behaviour unchanged but `dev install`; `tests/run.sh` covers
  `dev install` (the link, rerun safe) (spec, deliverable 2).
- Functions move verbatim, comments with them: no renames, no rewording.
- `run-actions` stays one file (D11).
- No `mounts.sh` yet: D3's mounts are branch 3's, so it's created there
  (no empty module).
- Branch from the current `main` (`fc5274b` or later).

## Review Focus

1. A function used before its module is sourced: `dev` sources every
   module before the `case`, and nothing at a module's top level calls a
   function.
2. A global a module sets that `dev` or another module reads: ShellCheck
   checks `dev` with `-x` (follows the modules) and each module alone with
   `-e SC2034` (globals used across files).
3. `dev` reached through the `~/.local/bin/dev` link: `HERE` is the
   clone, so modules load from `$HERE/box/lib/` (a `dev install` test runs
   the link).
4. The base image without a layer still has `/etc/claude-code/local.md`
   (`box/company/CLAUDE.md` imports it).

---

### Task 1: `dev` sources its modules

**Files:**
- Create: `box/lib/common.sh`, `conf.sh`, `layer.sh`, `project.sh`,
  `box.sh`, `scratch.sh` (each starts `# shellcheck shell=bash` and one
  comment line saying what it holds)
- Modify: `dev` (functions out; one `source` line per module after `HERE`,
  each with `# shellcheck source=box/lib/<m>.sh`); `tests/test_dev.sh`
  (its clone copies `box/lib/`); `tests/run.sh` (ShellCheck line)

Which function goes where, in `dev`'s current order within each module:

| Module | Functions |
|---|---|
| `common.sh` | `die`, `image_id`, `drop_old`, `build`, `label`, `ask`, `show_change` |
| `conf.sh` | `conf_file`, `clone_path`, `read_conf`, `conf_paths`, `approved_items`, `load_conf`, `conf_value`, `load_runtime`, `conf_hash`, `snapshot`, `save_approved` |
| `layer.sh` | `needs_layer`, `build_layer`, `choose_layer` |
| `project.sh` | `is_project`, `not_project`, `choose_plugins`, `install_plugins`, `read_dev`, `valid_port`, `dev_packages`, `dev_edit`, `sync_plugins`, `image_name`, `build_project`, `choose_image`, `choose_ports` |
| `box.sh` | `term_opts`, `box`, `run_box`, `work_dir`, `box_state`, `shared_box` |
| `scratch.sh` | `scratch_dir`, `scratch_root`, `enter_scratch`, `new_scratch`, `live_claude`, `check_scratch`, `scratch_rows`, `list_scratches`, `pick_scratch` |

`dev` keeps its header (the help `dev help` prints), `set`, the globals,
`HERE`, the `source` lines, and everything from the "Bash reads a script
as it runs it" comment to the end.

- [ ] **Step 1: Run the checks before.** Run: `tests/run.sh`. Expected: `ALL PASSED`, `test_dev: 135 passed`.
- [ ] **Step 2: Move the functions** per the table; check none is left or doubled: `grep -hoE '^[a-z_]+\(\)' dev box/lib/*.sh | sort | uniq -d` prints nothing, and `grep -cE '^[a-z_]+\(\)' dev` prints `0`.
- [ ] **Step 3: Fix the test clone and ShellCheck.** `test_dev.sh`'s clone also gets `box/lib/`; `tests/run.sh` runs `shellcheck -S warning -x dev …` and `shellcheck -S warning -e SC2034 box/lib/*.sh`.
- [ ] **Step 4: Run the checks.** Run: `tests/run.sh`. Expected: `ALL PASSED`, `test_dev: 135 passed`; `dev help` prints the same text as on `main` (`git show main:dev > "$t/dev"; diff <(./dev help) <(bash "$t/dev" help)` is empty, `t` a temp folder).
- [ ] **Step 5: Commit** `dev: its functions into box/lib/ modules (moved, unchanged)`.

### Task 2: `dev install`, and `local.md` from the build

**Files:**
- Modify: `dev` (an `install` command and its help line, from
  `install.sh`'s three lines); `box/Containerfile` (writes
  `/etc/claude-code/local.md` with `local.md`'s one comment line instead
  of copying it); `tests/test_dev.sh`; `tests/run.sh` (ShellCheck no
  longer names `install.sh`); `README.md`, `docs/system/runbook.md`,
  `docs/system/architecture/` (`install.sh` → `./dev install`; `local.md`
  written by the build)
- Delete: `install.sh`, `box/company/local.md` (`git rm`)

**Interfaces:**
- Produces: `dev install` (from the clone, before `dev` is on `PATH`:
  `./dev install`): `ln -sfn "$HERE/dev" ~/.local/bin/dev`, prints the
  same two lines `install.sh` printed.

- [ ] **Step 1: Write the failing tests** in `test_dev.sh`, with `HOME` a temp folder:
  - `install`: `"$DEV" install` exits 0; `readlink "$HOME/.local/bin/dev"` is `$CLONE/dev`.
  - `install-rerun`: a second `"$DEV" install` exits 0, the link unchanged.
  - `install-link-runs`: `"$HOME/.local/bin/dev" help` exits 0 (modules load through the link).
  - `local-md-built`: `box/Containerfile` has no `COPY` of `local.md` and writes `/etc/claude-code/local.md`; `box/company/local.md` doesn't exist.
- [ ] **Step 2: Run them.** Run: `GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh`. Expected: the four FAIL (unknown command `install`; the `COPY`).
- [ ] **Step 3: Implement** `dev install`, the Containerfile line, `git rm` both files, the docs.
- [ ] **Step 4: Run the checks.** Run: `tests/run.sh`. Expected: `ALL PASSED`, `test_dev: 139 passed`; `tests/check_managed_settings.py`'s `COPY` check still finds `managed-settings.json`.
- [ ] **Step 5: Commit** `dev install replaces install.sh; the build writes local.md`.

### Task 3: The image still builds the same

**Files:** `out/actions.txt` (not committed)

- [ ] **Step 1: Ask the owner to run `dev build`** by hand (about 10 minutes).
- [ ] **Step 2: Write the run.** Title `claude-box: Read the image built on claude/dev-modules`. One `local` step that reads only: `podman image inspect --format '{{.Created}}' localhost/claude-box` (so a stale image shows), then `podman run --rm --entrypoint sh localhost/claude-box -c '…'` printing `cat /etc/claude-code/local.md` and `sha256sum /etc/claude-code/CLAUDE.md /etc/claude-code/managed-settings.json`.
- [ ] **Step 3: Check it.** Run: `box/bin/run-actions --check out/actions.txt`. Expected: `ok`.
- [ ] **Step 4: Ask the owner to `dev run`, then read `out/actions.log`.** Expected: created today; `local.md` is the one comment line; the checksums equal `box/company/`'s.
