# Layout moves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the box's internals into `box/` (spec D9) with `git mv`
only, plus the path fixes that keep everything working.

**Architecture:** One commit of moves and path fixes, so `tests/run.sh`
passes at every commit; a `dev run` step before it records what your
sessions load, for the spec's "Your box as before" check.

**Tech Stack:** Bash (`dev`, tests), Python (checks), Containerfile.

**Spec:** [spec.md](spec.md), branch 1 (`claude/layout-moves`).

## Global Constraints

- Moves and path fixes only: no wording changes, no behaviour changes.
- `packs/` and `install.sh` don't move on this branch: your
  `local/claude-box.conf` names `packs/` paths, and `local/` is the same
  on every branch (E11); packs move in branch 3, `install.sh` goes in
  branch 2.
- Commands keep their names inside the image (`run-actions`,
  `box-plugins`, `/usr/local/share/claude-box/plugins/box-workflow`):
  references to the command, not the file, stay as they are.
- Change records: only link targets change (spec, deliverable 1).
- Branch from the current `main` after `claude/publishing-acceptance`
  is merged.

## Review Focus

1. A path a shell string builds (`"$HERE/..."`, `"$REPO/..."`) that
   `grep` for the old literal misses: `tests/run.sh` must pass in full,
   including `== dev` and `== run-actions`.
2. The image build context: `podman build` gets `box/` as its context,
   so every `COPY` is relative to `box/`; `tests/check_managed_settings.py`
   pins the `COPY` lines.
3. `rules/local.md` moves too (`box/company/local.md`); branch 2 removes it.

---

### Task 1: Record what your sessions load (before)

**Files:**
- Create: `out/compare/before/` (not committed)

The box this session runs in is the "before" state, so it is read from
inside the box, not by a `dev run` step (spec E14 assumed one; a step
may not run `dev`, which `run-actions --check` refuses). The "after"
side is read the same way, in a box started after branch 3's merge run.

- [ ] **Step 1: Copy** `/etc/claude-code/`, `~/.claude/CLAUDE.md`
  (`~/.claude/rules/` doesn't exist), `git config --system --list` and
  `ls -R /usr/local/share/claude-box/plugins` into `out/compare/before/`,
  with `SHA256SUMS` of every file. Expected: 10 files.

### Task 2: Move into `box/` and fix the paths

**Files:**
- Move (`git mv`): `Containerfile` → `box/Containerfile`;
  `rules/claude-rules.md` → `box/company/CLAUDE.md`;
  `rules/managed-settings.json` → `box/company/managed-settings.json`;
  `rules/local.md` → `box/company/local.md`;
  `mods/box-workflow` → `box/plugin/box-workflow`;
  `run-actions` → `box/bin/run-actions`;
  `box-plugins` → `box/bin/box-plugins`;
  `config/claude-box.conf` → `box/defaults.conf`
- Modify: `box/Containerfile` (`COPY` sources relative to `box/`);
  `dev` (`build()`: `podman build … -f "$HERE/box/Containerfile" "$HERE/box"`;
  the defaults path in `conf_file`, `approved_items` and their messages;
  `dev run`'s `exec "$HERE/box/bin/run-actions"`; the header comment's path);
  `tests/check_managed_settings.py`, `tests/run.sh`, `tests/test_dev.sh`,
  `tests/test_run_actions.sh` (paths);
  `README.md`, `docs/system/runbook.md`,
  `docs/system/architecture/README.md`, `01-context.md`, `02-container.md`,
  `03-deployment.md`, and links in `docs/change/` (link targets)

**Interfaces:**
- Produces: the layout branch 2 starts from: `box/{Containerfile,defaults.conf,company/,plugin/box-workflow/,bin/}`.

- [ ] **Step 1: Run the checks before.** Run: `tests/run.sh`. Expected: `ALL PASSED`.

- [ ] **Step 2: `git mv` every row of Files' Move list.** Run: `git status --short`. Expected: only `R` lines.

- [ ] **Step 3: Run the checks to see what the move broke.** Run: `tests/run.sh`. Expected: failures in Links, Managed settings, dev, run-actions, ShellCheck (old paths).

- [ ] **Step 4: Fix each path in Files' Modify list.** `test_dev.sh` line 19 copies `dev`, `box/` (`run-actions`, `defaults.conf` at their new places) into its clone; `tests/run.sh`'s ShellCheck line names `box/bin/run-actions` and `box/bin/box-plugins`, and the mods lines `box/plugin/box-workflow`. Find leftovers: `grep -rnI --exclude-dir=.git --exclude-dir=out --exclude-dir=local -E '(rules/(claude-rules|managed-settings|local)|mods/box-workflow|config/claude-box\.conf|[^/]Containerfile\]|\(\.\./)+run-actions|box-plugins\])' .` Expected: only lines in this change's spec and plans.

- [ ] **Step 5: Run the checks.** Run: `tests/run.sh`. Expected: `ALL PASSED`; then `git diff --cached -M --stat` shows the moves as renames.

- [ ] **Step 6: Commit.** `git add -A && git commit` with message `Layout: the box's internals into box/ (moves and path fixes only)`.

### Task 3: The image still builds the same

**Files:** `out/actions.txt` (not committed)

- [ ] **Step 1: Ask the owner to run `dev build`** by hand (about 10
  minutes; a step may not run `dev`).

- [ ] **Step 2: Write the run.** Title `claude-box: Read the image built from box/`. One `local` step that reads only: `podman run --rm --entrypoint sh localhost/claude-box -c '…'` printing `sha256sum` of `/etc/claude-code/CLAUDE.md` and `/etc/claude-code/managed-settings.json` and `ls -d /usr/local/share/claude-box/plugins/box-workflow /usr/local/bin/run-actions /usr/local/bin/box-plugins`.

- [ ] **Step 3: Check it.** Run: `box/bin/run-actions --check out/actions.txt`. Expected: `ok`.

- [ ] **Step 4: Ask the owner to `dev run`, then read `out/actions.log`.** Expected: the two `sha256sum`s equal those of `box/company/CLAUDE.md` and `box/company/managed-settings.json`, and the three paths listed.
