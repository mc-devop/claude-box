# README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a newcomer reads the README alone and knows the one file to
edit, the three layers and packs, and what each top-level item is
(spec deliverable 4); the runbook gains its section for developing
claude-box (D12); the stranger test reruns on the new README before the
flip.

**Architecture:** Docs only, plus one check in `tests/run.sh` that keeps
the README's list of top-level items in step with the repo, and a new
stranger-test script in this change's folder, run from `out/actions.txt`
before the merge.

**Tech Stack:** Markdown, Bash, ShellCheck.

**Spec:** [spec.md](spec.md), branch 4 (`claude/readme`), and its
*Acceptance* rows *From the README alone*, *private-terms for developing
claude-box*, *Publishing waits*.

## Global Constraints

- One fact, one place: the README summarises and links; the layers'
  table stays in the [architecture](../../system/architecture/README.md#levels),
  every config kind in [box/defaults.conf](../../../core/defaults.dev).
- The README names only `local/claude-box.conf` as a file to edit, and
  never `local/private-terms` (D12).
- Terms: company, global, project are our own names for Claude Code's
  managed policy, user, project levels; "pack" is our own term (as the
  architecture says).
- Top level per D9: `README.md`, `LICENSE`, `dev`, `local/`, `packs/`,
  `box/`, `docs/`, `tests/`, `out/`; `.gitignore` is tracked too.
- Branch from `main` at `7f2c05c`.

## Review Focus

1. A top-level item added or removed later and the README not updated:
   Task 1's check fails naming the item.
2. The README naming `private-terms`: Task 1's check fails.
3. The stranger test run against a commit other than the branch's: the
   script bundles the ref it's given and refuses one that doesn't exist.
4. The merge running after a failed stranger test: the stranger test is
   the run's first step, so an abort stops the merge.

---

### Task 1: README for a newcomer, with its check

**Files:**
- Modify: `README.md`, `tests/run.sh` (a `== README` block after
  `== Links`)

- [ ] **Step 1: Write the failing check** in `tests/run.sh`:

```bash
echo; echo "== README"
# Its table of top-level items names each tracked one, and local/ and out/;
# it never names local/private-terms (D12: not part of a user's setup).
items=$( { git ls-files | cut -d/ -f1 | sort -u; printf '%s\n' local out; } )
for i in $items; do
  grep -qE "^\| \`$i/?\` \|" README.md || { echo "README: top-level item $i not in its table"; status=1; }
done
! grep -q 'private-terms' README.md || { echo "README: names private-terms"; status=1; }
```

- [ ] **Step 2:** `tests/run.sh` → fails: `README: top-level item box not in its table` (and the others).

- [ ] **Step 3: Rewrite `README.md`**, keeping its opening, Requirements,
  Commands, `.dev` example, Documentation and License as they are:
  - **Quick start:** the code block ends with
    `cd ~/Projects/<project> && dev claude` (an existing project) and
    `dev new <name>` as its comment's alternative; the runbook link stays.
  - **Your config** (rewrite): the one file you edit is
    `local/claude-box.conf`; `dev init` writes it, its first line points
    to [box/defaults.conf](../../../core/defaults.dev), which explains every kind with
    examples; files it names go under `local/`; the approval sentence and
    runbook link stay.
  - **Three layers and packs** (new, about 8 lines): every rule a session
    reads comes from one of three layers, company (built into the image),
    global (every box, from your config), project (one project's own
    `CLAUDE.md`, and a pack's project rules when its `.dev` says
    `pack <name>`); a pack is a folder in `packs/` with a part per layer,
    switched on by one line, `pack <name>`; the packs are optional
    (keep the existing sentence on planning your own way). Links:
    [architecture#rules](../../system/architecture/README.md#levels), [#packs](../../system/architecture/README.md#plugins).
  - **What's in this repo** (new, before Documentation): a table, one row
    per item, first cell exactly `` `<item>` `` or `` `<item>/` ``:
    `README.md`, `LICENSE`, `dev` (the one command), `local/` (yours,
    not in git: your config and its files), `packs/`, `box/` (what
    builds and drives the box: Containerfile, defaults, the box's own
    rules and plugin, helper scripts, dev's modules), `docs/`, `tests/`
    (the checks, `tests/run.sh`), `out/` (not in git: what Claude hands
    you, e.g. `dev run`'s steps), `.gitignore`.

- [ ] **Step 4:** `tests/run.sh` → `ALL PASSED`.

- [ ] **Step 5: Commit** `README.md tests/run.sh`: "README for a newcomer: one file to edit, layers and packs, the repo's items".

### Task 2: Runbook: developing claude-box

**Files:**
- Modify: `docs/system/runbook.md` (the section *Check a change to this
  repo* becomes *Develop claude-box*)

- [ ] **Step 1: Rewrite the section**: `tests/run.sh` before every commit
  (its current sentence); then `local/private-terms`: a file for
  developing claude-box, not part of a user's setup: one Python regex per
  line, `#` starts a comment, matched case-insensitively; `tests/run.sh`
  fails when a tracked file holds one, and skips the check without the
  file. Fix any link to the old heading (`grep -rn 'check-a-change' docs`).

- [ ] **Step 2:** `tests/run.sh` → `ALL PASSED`.

- [ ] **Step 3: Commit** `docs/system/runbook.md`: "Runbook: developing claude-box, local/private-terms (D12)".

### Task 3: The stranger test on the new README

**Files:**
- Create: `docs/change/2026-10-30-clear-layout/stranger-test.sh` (from
  [the publishing one](../2026-10-30-publishing/stranger-test.sh))
- Modify: `tests/run.sh` (ShellCheck covers the new script)

- [ ] **Step 1: Write the script** with the publishing script's checks,
  `cbtest` handling and clean-up unchanged, and these differences:
  - usage `stranger-test.sh <branch>`; refuses unless
    `git rev-parse --verify refs/heads/<branch>` succeeds;
    `git bundle create "$bundle" <branch>` from the current repo (the
    repo is private, so no export folder);
  - in the user's session: `git clone -q -b <branch>` from the bundle,
    `./dev install` in place of `./install.sh`, then `ls -A | grep -vx .git`
    printed between the lines `LS-BEGIN` and `LS-END`;
  - one more result check: the lines between `LS-BEGIN` and `LS-END`
    are exactly `.gitignore LICENSE README.md box dev docs packs tests`
    (sorted), else it prints what differs and fails;
  - the log is `out/stranger-test.log` (gitignored: the merge step
    after it checks for a clean tree).

- [ ] **Step 2:** add the script to `tests/run.sh`'s ShellCheck line;
  `tests/run.sh` → `ALL PASSED`.

- [ ] **Step 3: Commit** the script and `tests/run.sh`: "The stranger test on the new README (./dev install, the top level)".

### Task 4: README test, review, merge run

- [ ] **Step 1: README test.** A fresh subagent gets only `README.md`'s
  text and the question: which file do you edit to make the box yours,
  and what is each top-level item for? Its answer and Claude's verdict
  (each item right or wrong) go into
  `docs/change/2026-10-30-clear-layout/findings-readme-test.md`; a wrong
  answer is fixed in the README and the test repeated. Commit.

- [ ] **Step 2: Branch review.** A fresh reviewer on the most capable
  model reviews `main..claude/readme` against this plan; fixes committed.

- [ ] **Step 3: `out/actions.txt`**, title *claude-box: Stranger test on
  the new README, merge claude/readme, push*:
  1. the stranger test, `bash docs/change/2026-10-30-clear-layout/stranger-test.sh claude/readme`
     (sudo; about 10 minutes for the image build); no `allow` or
     `expect` on its first run;
  2. `git switch main`, then merge, refusing unless the checkout is clean
     and `claude/readme` starts from `main` (as the last run's merge step);
     the branch deleted after;
  3. `git push origin main`.

  The acceptance branch copies the stranger test's log into this folder,
  after the private-terms check.

- [ ] **Step 4:** after the run, read `out/actions.log`; on an abort, find
  the cause before the next run.
