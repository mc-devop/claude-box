# Public docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The tree `git archive main` exports reads right to a stranger
and passes every check on its own: a README they can install from, an
MIT license, and docs with no link into the records that stay behind.

**Architecture:** Docs only, plus one test: `tests/run.sh` checks the
links of the export itself, so a link into the archive fails here, not
after publishing ([spec D12](spec.md#decisions)).

**Tech Stack:** Markdown, Bash, Python 3 (standard library).

**Spec:** [spec.md](spec.md)

## Global Constraints

- Branch `claude/public-docs`, from `main`; `tests/run.sh` passes before
  every commit, with your `local/private-terms` in place (0 matches).
- Outside `docs/change/`, no link into `docs/change/` except into
  `docs/change/2026-10-30-publishing/`.
- A dropped citation never drops a fact: the decision, its date and its
  reason stay in the sentence that cited the record; where the record
  held something the sentence doesn't say, one sentence carries it.
- Terms keep their standards (C4's element names, the playbook's
  documents); `packs` stays marked as our own term.
- License text: the standard MIT text, `Copyright (c) 2026 mc-devop`.

## Review Focus

- A reader with no access to the archive: every statement in the
  architecture's limits and accepted risks still says what is accepted
  and why.
- A stranger following the README on a laptop that isn't yours: no step
  assumes your folders, your config, your plugins or the old toolbox
  setup; `dev init` is described as it behaves with the public defaults
  (it offers your config's plugins: none by default).
- The backlog read without its history: each open item still states its
  outcome and its *Done when*, without review codes (S1, M5) whose
  meaning lived in a record.
- A link into this change's own folder (the intent, the spec): allowed,
  and resolves in the export.
- This repo after the merge (it becomes the archive): its own link check
  still passes; the records keep their links.

---

### Task 1: A README a stranger can install from, and the license

**Files:**
- Modify: [README.md](../../../README.md)
- Create: `LICENSE`

**Interfaces:** none.

- [ ] **Step 1: Rewrite the README's top and Setup** per [D7](spec.md#decisions):
  - one paragraph on what it is (keep today's first two paragraphs);
  - **Requirements:** Linux with rootless Podman (tested on Fedora 44),
    python3 and flock (util-linux), a Claude account;
  - **Quick start:** `git clone https://github.com/mc-devop/claude-box`,
    `cd claude-box`, `./install.sh`, `dev init` (builds the image, logs
    Claude in, offers your config's plugins), then `dev claude` in a
    project's top folder (or `dev new <name>`);
  - drop the line about the old toolbox setup; link the runbook for
    setting up a config;
  - **Your config:** keep today's paragraph, and add that the packs
    (the documentation family, change management, the workflow plugin)
    are optional: leave them out to plan your own way, e.g. GitHub
    Issues;
  - Commands: `dev init`'s line says "offer your config's plugins", as
    `dev help` does;
  - Documentation table: `docs/change/` row says one folder per change;
  - a last section **License**: MIT, linking `LICENSE`.
- [ ] **Step 2: Create `LICENSE`** with the MIT text (Global Constraints).
- [ ] **Step 3: Run `tests/run.sh`.** Expected: `ALL PASSED`.
- [ ] **Step 4: Commit** `README.md`, `LICENSE`: "README for a stranger:
  requirements, quick start, optional packs; MIT license".

### Task 2: No link into the archive

**Files:**
- Modify: [tests/run.sh](../../../tests/run.sh), [check_links.py](../../../plugins/workflow/starter/tests/check_links.py)
  (only if it can't check another folder),
  [architecture README](../../system/architecture/README.md),
  [container view](../../system/architecture/02-container.md),
  [deployment view](../../system/architecture/03-deployment.md),
  [backlog](../../direction/backlog.md), [vision](../../direction/vision.md)
  (only if a fact in it needs a record)

**Interfaces:**
- Produces: `check_links.py [folder]`: checks that folder instead of the
  repo when given (default unchanged).

- [ ] **Step 1: Write the failing test** in `tests/run.sh`, inside the
  `if [ -e .gitattributes ]` block: extract
  `git archive --worktree-attributes HEAD` into a `mktemp -d` folder and
  run `python3 tests/check_links.py <that folder>`; on failure print
  `export: broken links` and set `status=1`; remove the folder.
  Give `check_links.py` the optional folder argument if it lacks one.
- [ ] **Step 2: Run `tests/run.sh`.** Expected: `export: broken links`,
  with about 63 problems, all links into `docs/change/` from the files
  above.
- [ ] **Step 3: The architecture and its views:** each `([spec, Dn](…))`,
  `([finding](…))`, `([why](…))`, `([record](…))` and `([results](…))`
  citation goes, by the rule in Global Constraints. Element tables
  whose cell links a record keep the cell's fact.
- [ ] **Step 4: The backlog:** *Now:* names this milestone and links its
  intent and spec; the list of finished milestones and its links go
  (their records stay in the archive; one sentence says so, without a
  link). Each open item keeps its outcome and *Done when*; record links
  and review codes go, their content stated where the item needs it.
- [ ] **Step 5: Run `tests/run.sh`.** Expected: `ALL PASSED`, and the
  repo's own link check still passes.
- [ ] **Step 6: Commit** `tests/run.sh` (and `check_links.py` if
  changed), the docs: "No link into the archive: the export's links are
  checked; the system docs and backlog state what their records held".
