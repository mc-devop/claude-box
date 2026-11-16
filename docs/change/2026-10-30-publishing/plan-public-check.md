# Public check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The private-terms check runs for real in this repo, skipping
only what the export leaves out, and `git archive` leaves out every
change record but this one.

**Architecture:** A `.gitattributes` marks the old records `export-ignore`
([spec D2](spec.md#decisions)); the check asks `git check-attr` which
tracked files are marked and skips them (D4). Your terms leave the
unmarked files, so the check passes with your list in place.

**Tech Stack:** Python 3 (standard library), Bash, git 2.56.

**Spec:** [spec.md](spec.md)

## Global Constraints

- Branch `claude/public-check`, from `main` after `claude/publishing-intent`
  is merged (this folder must be on `main`).
- `tests/run.sh` passes before every commit.
- No term of your list in any file of this branch outside the marked
  paths, this plan included: the list's content is described here, never
  spelled out.
- `.gitattributes` lines, exactly:
  ```
  docs/change/** export-ignore
  docs/change/2026-10-30-publishing -export-ignore
  docs/change/2026-10-30-publishing/** -export-ignore
  .gitattributes export-ignore
  ```

## Review Focus

- A file name with spaces or non-ASCII characters among the tracked
  files: the check still pairs each file with its attribute (use `-z`).
- A repo without `.gitattributes` (the new repo): nothing is skipped.
- A record added later under `docs/change/` in this repo: skipped, like
  the old ones; in the new repo: checked.
- A term in `.gitattributes` itself: skipped (it's marked), harmless since
  it never leaves this repo.
- Claude's identity (`Claude MC`) in `test_dev.sh`: not a term (D11), so
  that file stays as it is; the spec's deliverable row for it is moot.

---

### Task 1: The check skips what the export leaves out

**Files:**
- Create: `.gitattributes`
- Modify: [tests/check_private_terms.py](../../../tests/check_private_terms.py)
- Test: [tests/run.sh](../../../tests/run.sh) (section `== Private terms`)

**Interfaces:**
- Produces: `exported(repo: Path, files: list[str]) -> set[str]` in
  `check_private_terms.py`, the files whose `export-ignore` is not `set`.

- [ ] **Step 1: Write the failing tests** in `tests/run.sh`, after the
  existing throwaway-repo test:
  - `private-terms-attr`: in a throwaway repo with `local/private-terms`
    holding `secretname`, `old/a.txt` and `b.txt` both hold `Secretname`,
    and `.gitattributes` has `old/** export-ignore`. The check fails and
    names `b.txt:1`, and its output has no `old/a.txt`.
  - `export-clean`: `git archive HEAD | tar -t` in this repo lists
    `docs/change/2026-10-30-publishing/spec.md`, no other path under
    `docs/change/` except the folder entries `docs/change/` and
    `docs/change/2026-10-30-publishing/`, and no `.gitattributes`.
  Each failure prints `private terms: <what>` or `export: <what>` and sets
  `status=1`, as the existing lines do.
- [ ] **Step 2: Run `tests/run.sh`.** Expected: `private-terms-attr`
  fails (`old/a.txt` is reported) and `export-clean` fails (records
  listed).
- [ ] **Step 3: Implement** `exported()`: one call to
  `git check-attr -z --stdin export-ignore` with the file list on stdin,
  output read as NUL-separated triples (path, attribute, value). `main()`
  checks only `exported(repo, files)`. Docstring: says marked paths are
  skipped, and why (they never leave this repo). Create `.gitattributes`
  with the lines in Global Constraints.
- [ ] **Step 4: Run `tests/run.sh`.** Expected: `ALL PASSED`.
- [ ] **Step 5: Commit** `.gitattributes`, `tests/check_private_terms.py`,
  `tests/run.sh`: "Private terms check skips what the export leaves out;
  .gitattributes leaves out the old records".

### Task 2: Your terms out of the public files, and the list in place

**Files:**
- Modify: [inbox.test.ts](../../../core/plugin/box-workflow/hooks/inbox.test.ts),
  [backlog](../../direction/backlog.md), [runbook](../../system/runbook.md)
- Create: `local/private-terms` (untracked)

**Interfaces:**
- Consumes: Task 1's check.

- [ ] **Step 1: Write `local/private-terms`**, one case-insensitive regex
  per line with `\b` around each word, with a `#` comment per group:
  every folder name in `/projects` except the generic ones (`claude-box`,
  `dotfiles`, `mc-devop` and the two `.sh` scripts); your laptop's maker
  and model; the two server names found in the records
  (`user@host` strings); your email's local part and its domain.
- [ ] **Step 2: Run `tests/run.sh`.** Expected: `private terms` fails,
  naming lines in exactly the three files above (as E1 found).
- [ ] **Step 3: Replace the terms.** In `inbox.test.ts`: the project
  names become `alpha` (the receiving project) and `beta` (the sender),
  and the fixture's service name follows (`svc-beta`). In the backlog
  and runbook: a project name becomes "another project" or an example
  name (`alpha`, `beta`); the laptop becomes "a laptop project". Names
  only: links and wording stay for branch 2.
- [ ] **Step 4: Run `tests/run.sh`.** Expected: `ALL PASSED`, with
  `private terms: N files, 0 matches` (not `skipped`).
- [ ] **Step 5: Commit** the three files: "Your project names out of the
  public files; the private-terms check runs with your list".
