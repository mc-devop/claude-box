# Core moves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `box/` becomes `core/`, with nothing else changed, so history
follows every file into the new name.

**Architecture:** One `git mv box core`, then every path that names
`box/` is fixed: in code, tests, living docs, and the link targets of
change records. The image's paths inside the container
(`/usr/local/share/claude-box/…`, `/etc/claude-code/…`) don't change, so
the image built before this branch keeps working.

**Tech Stack:** bash, git, Python 3 (the checks in `tests/`).

**Spec:** [spec.md](spec.md), deliverable 1 (`claude/core-moves`) and D14.

## Global Constraints

- Moves only: `git mv` plus path and link fixes. No wording changes
  (company rules, change management: "A restructure gets its own branch
  of moves only").
- Records under `docs/change/` stay as written; only their link targets
  change ("Records stay as written. Only link targets change, when files
  move."). Code spans naming `box/` in records stay.
- The branch starts from `main` after `claude/simpler-model` is merged.
- `tests/run.sh` passes before every commit.

## Review Focus

- **A user-facing message still names `box/defaults.conf`** (in
  `core/lib/conf.sh`'s `die` lines). Expected: it names
  `core/defaults.conf`. Task 1's grep checks it.
- **`dev build` with the new build context.** `common.sh` passes
  `"$HERE/box"` as the context; if only the `-f` path changes, the build
  fails. Task 1 checks both arguments.
- **`tests/test_dev.sh`'s fake clone** copies `box/…` into `$CLONE`. If
  its paths aren't fixed, every test after setup fails at once, which is
  loud. A `cp` that fails silently isn't, so Task 1 checks the copies.
- **A link in a record still points into `box/`.** `check_links.py`
  catches it; Task 3 runs it.
- **History.** After the merge, `git log --follow core/lib/conf.sh` has
  to reach back before this branch. Task 3 checks that git sees renames
  (`R` with a similarity index), not deletes plus adds.

---

### Task 1: Move the folder and fix the code

**Files:**
- Move: `box/` → `core/` (`git mv box core`)
- Modify: `dev` (the `source=` comments and `. "$HERE/box/lib/…"` lines,
  `run-actions` path), `core/lib/common.sh` (build `-f` and context),
  `core/lib/conf.sh` (the defaults path, the comment, and three `die`
  messages), `tests/run.sh` (the ShellCheck list and its comment),
  `tests/test_dev.sh` (the fake clone's copies, and every `$REPO/box/…`
  path and `fail` message), `tests/test_run_actions.sh` (`RUN`),
  `tests/check_managed_settings.py` (two paths)

**Interfaces:**
- Produces: every path is `core/…`; nothing else changes.

- [ ] **Step 1:** Run `git mv box core`.
- [ ] **Step 2:** Replace `box/` with `core/` in the files listed above.
  Leave `claude-box/`, `box-workflow`, `box-plugins` and `/usr/local/…`
  container paths alone.
- [ ] **Step 3: Check nothing in code still names the old folder**

Run: `git grep -nE '(^|[^a-z-])box/' -- dev core tests | grep -v 'claude-box/'`
Expected: no output.

- [ ] **Step 4: Run the checks**

Run: `tests/run.sh`
Expected: ends with `ALL PASSED`.

- [ ] **Step 5: Commit** `Moves: box/ becomes core/ (code and tests)`.

### Task 2: Fix the living docs

**Files:**
- Modify: `README.md`, `docs/system/architecture/README.md`,
  `01-context.md`, `02-container.md`, `03-deployment.md`,
  `docs/system/runbook.md`, `docs/direction/backlog.md`

- [ ] **Step 1:** Replace `box/` with `core/` in links and code spans in
  these files. In the README's *What's in this repo* table, only the
  name in the `box/` row changes.
- [ ] **Step 2: Check**

Run: `git grep -nE '(^|[^a-z-])box/' -- README.md docs/system docs/direction | grep -v 'claude-box/'`
Expected: no output.

Run: `tests/run.sh`
Expected: `ALL PASSED`.

- [ ] **Step 3: Commit** `Moves: box/ becomes core/ (docs)`.

### Task 3: Fix the link targets in records, and check the moves

**Files:**
- Modify: link targets only, in
  `docs/change/2026-10-30-clear-layout/{findings-spec-review,plan-readme,spec}.md`,
  `docs/change/2026-10-30-publishing/{plan-public-check,spec}.md`,
  `docs/change/2026-10-31-project-defaults/spec.md`,
  `docs/change/2026-10-31-simpler-model/spec.md`

- [ ] **Step 1:** In those files, change `box/` to `core/` inside
  `](…)` link targets only.
- [ ] **Step 2: Check that only link targets changed in records**

Run: `git diff -U0 HEAD -- docs/change | grep -E '^[-+][^-+]' | grep -vE '\]\([^)]*(box|core)/'`
Expected: no output.

Run: `git grep -nE '\]\([^)]*[^a-z-]box/' -- docs/change`
Expected: no output.

- [ ] **Step 3: Check the moves are renames**

Run: `git diff --stat -M --summary main | grep -c 'rename {box => core}'`
Expected: the number of files under `box/` on `main` (`git ls-tree -r --name-only main box | wc -l`).

Run: `tests/run.sh`
Expected: `ALL PASSED`.

- [ ] **Step 4: Commit** `Moves: box/ becomes core/ (link targets in records)`.

## After the branch

A fresh reviewer on the most capable model reads the whole branch
against this plan, its fixes are applied, then `out/actions.txt`: the
merge and push. No `dev build` is needed: the image's content doesn't
change.
