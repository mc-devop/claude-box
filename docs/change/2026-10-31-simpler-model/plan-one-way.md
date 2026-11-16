# One-way Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything reaches your boxes one way. A change merged to the
clone's `main` (to core, or to a plugin you use) shows at the next
`dev claude` and applies after your yes. A branch you're reviewing never
reaches them. `dev update` brings a new claude-box the same way.
`./dev install` is the whole setup, and the README reads as the model.

**Architecture:** `build` takes core from `git archive main core`, not
from the working tree, and labels the image `claude-box.core` with git's
tree id of `main:core`. `check_core`, at the start of `choose_layer`
(every new box), compares that label with `main:core`: a change is
shown with `git diff --stat` and rebuilt after your yes. Plugins named
by name (`use workflow`) come from a copy of `main:plugins` under
`~/.local/state/claude-box/main/`, so they reach your config's diff only
once merged. `dev update` fetches and moves `main` forward
(`--ff-only`) after your yes. `dev install` ends by running `dev init`,
which first asks Claude's git identity.

**Tech Stack:** bash (`dev`, `core/lib/*.sh`), git, the fake Podman in
`tests/test_dev.sh`, Markdown docs.

**Spec:** [spec.md](spec.md), deliverable 4: D12, D13, D15, and the maps
from D14, which [plan 3](plan-core-rules.md) R5 left for this branch.
Also: drop the `local/` lines from `.gitignore` (branch 2's handoff).

## Decisions this plan adds (for the owner's review)

| # | Decision | Why |
|---|---|---|
| W1 | **Plugins named by name come from `main` too**, not from the clone's working tree as today (`use_src` reads `$HERE/plugins/<name>`). `main_dir` extracts `git archive main plugins` once per tree id into `$(dirname "$APPROVED")/main/<tree>/` and removes older trees. `use_src` and `use_base` read from it for the clone form when no snapshot root is given | Without this, `use workflow` would still bring a checked-out branch into your layer, which D12 rules out |
| W2 | The check sits at the top of `choose_layer`, so it covers every new box: `dev claude` and `dev shell`, `--new`, and scratch boxes. Joining a running box doesn't check. A rebuild is the full `build`, so it also brings the latest Claude Code. Your layer and project images then rebuild on the new base without asking, as they do today | One place. A running box's sessions keep their image, as today |
| W3 | An image with no `claude-box.core` label (built before this branch), or one whose tree git no longer has, is treated as changed. `dev` says it can't list the files and asks once | The first start after the merge asks once, then never again on an unchanged `main` |
| W4 | **`autotake group` stays in the starter `dev init` writes**, so it has three lines: `identity`, `use workflow`, `autotake group`. The project-defaults spec's D9 put the line there, and this spec doesn't replace D9. The spec's acceptance row ("two lines") is then named as a deviation. *The alternative:* drop the line, and the README tells you to add it | Keeps project-defaults' pending acceptance as built. Your call |
| W5 | Enter at the identity question writes the default `identity Claude <claude@claude-box.invalid>` line. A typed identity is checked with `read_conf`'s own rule, and a bad one is asked again (three tries, then the default). Without a terminal, the default is written without asking. An existing `~/.claude/.dev` is kept, and nothing is asked | The file always shows Claude's identity (intent: "has their identity"). Cost: every user gets a layer, a build of a few seconds |
| W6 | `dev update` moves `main` even when the clone has another branch checked out: `git fetch . <upstream>:main`, which git refuses unless it fast-forwards. It never touches the checkout. **Known limit, for the architecture:** `dev` and `run-actions` themselves run from the clone's checked-out files, so a branch checked out there runs its own `dev`. A backlog item proposes running them from `main` | D12 covers the image. Fixing `dev` itself is wider than this branch |
| W7 | The acceptance's stranger test gets its own script in this change's folder, `stranger-test.sh`. It's adapted from the clear-layout one: `./dev install` with the login declined, in place of `dev build`; the top level `.gitignore LICENSE README.md core dev docs plugins tests`; the written `~/.claude/.dev` printed for the record. The old script stays as written | Records stay as written. The acceptance needs a script that matches the new setup |

## Global Constraints

- The label is `claude-box.core`, and its value is `git -C "$HERE" rev-parse main:core`.
- The branch is literally `main`. Nothing reads the clone's working tree
  into an image: core comes from `git archive main core`, plugins from
  `git archive main plugins`.
- The default identity, exact: `Claude <claude@claude-box.invalid>`.
- `dev update` only fast-forwards, and asks before it changes anything.
- Without a terminal, every question is answered no (`ask`). A box then
  starts on the old image and says so.
- D1: no "company", "pack" or "layer" in the README, `dev`'s messages or
  the help (`grep -niwE 'company|packs?|layers?'`). Code comments and
  variable names (`LAYER`) may keep "layer".
- `tests/run.sh` passes before every commit.

## Review Focus

- **The owner reviewing a `claude/` branch in the clone:** with a
  branch checked out that changes `core/` and `plugins/workflow/`, and
  with uncommitted edits too, `dev claude` asks nothing and builds
  nothing. Tasks 1 and 2 test both, through a branch commit and a dirty
  tree.
- **The first start after this merge:** an image without the label asks
  once. After the rebuild, the next start asks nothing. Task 1.
- **A tree git no longer has** (a fresh clone, or after gc): no git
  error shown, the question still comes. Task 1, with a made-up label.
- **`dev update` with local commits on `main`**, or with no upstream:
  nothing changes, and the refusal says why in one line. Task 3.
- **`./dev install` without a terminal** (the stranger test, a pipe):
  no hang, the default identity is written, and the login runs.
  Task 4.

---

### Task 1: Build from `main`, and ask when core changed

**Files:**
- Modify: `core/lib/common.sh` (`build`, new `core_tree` and `check_core`)
- Modify: `core/lib/layer.sh` (`choose_layer`: `check_core` first; its
  own `podman image exists "$IMAGE" || build` goes)
- Modify: `core/Containerfile` (header comment: built from `main`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Produces: `core_tree` prints `main:core`'s tree id, or fails when the
  clone has no `main` or no `core/` on it. `build` fails with
  `dev builds from the clone's main branch: <HERE> has none (git clone it)`
  when `core_tree` fails. `check_core` returns 0 always: it builds when
  there's no image, else asks as above.
- Produces (tests): `clone_commit <message>` commits all of `$CLONE` on
  its current branch. `base_label` writes the current `main:core` into
  the fake base's `claude-box.core`.

- [ ] **Step 1: Make the test clone a git repo.** `CLONE` gets
  `git init -q -b main` once, plus copies of `core/Containerfile` and
  `core/managed-settings.json` (so `git archive` has a core to send).
  `fresh` ends with `clone_commit fresh` (on `main`) and `base_label`,
  so every existing test starts with an unchanged core. Tests that
  change `$CLONE/plugins/…` after `fresh` (lines ~735–760, ~896,
  ~1167–1225) call `clone_commit` after the change. Run
  `bash tests/test_dev.sh`: it passes before any code changes, apart
  from `build` (next step).
- [ ] **Step 2: Write the failing tests.**
  - `build`: the context in the log isn't `$CLONE/core`, and
    `$FAKE/ctx/Containerfile` equals `git -C "$CLONE" show main:core/Containerfile`
    after the working tree's Containerfile was changed and not
    committed. The label `claude-box.core=<main:core>` is logged.
  - `core-unchanged`: `dev_in_p shell` calls no `build`, and its output
    has no "core".
  - `core-changed-main`: commit a new `core/x.txt` on `main`, then
    `echo y | tty_run dev shell`. The output names `x.txt`, `build` is
    called, and the new image's `claude-box.core` is the new tree.
    Then `case=core-changed-again` (new box, same `main`): no build.
  - `core-changed-no`: the same commit with `echo n`, and again without
    a terminal. No build, and the output has "old image".
  - `core-on-branch`: `git -C "$CLONE" switch -q -c claude/x`, change
    `core/Containerfile`, commit, and add an uncommitted change. No
    question, no build, and `has` shows the box runs on the base.
  - `core-unlabelled` and `core-unknown-tree`: remove the label, or set
    it to `0123…` (40 hex digits). The output says the files can't be
    listed, has no `fatal:`, and `y` builds.
  - `core-rebuild-fails`: `FAKE_BUILD_STATUS=1`, `y`. The box still
    runs (on the old base), and the output says so.
  - `build-no-main`: `git -C "$CLONE" branch -m main other`. `dev build`
    fails and names `main`.
- [ ] **Step 3: Run them.** `bash tests/test_dev.sh`. Expected: FAIL at
  `build`.
- [ ] **Step 4: Implement.** `build` extracts `git archive main core`
  into a `mktemp -d`, builds with context `<tmp>/core` and the label,
  and removes the folder in both outcomes. `check_core` prints
  `Core changed on main since your image was built:`, then
  `git diff --stat <old> <new>` indented (`git cat-file -e <old>`
  first, quiet). Unknown: `  (the image doesn't say which core it was
  built from, so the files can't be listed)`. Then `ask "Rebuild the
  image?"`. On no or failure: `Starting on the old image.`
- [ ] **Step 5: Run them.** `bash tests/test_dev.sh` passes, then
  `tests/run.sh`. Expected: all pass.
- [ ] **Step 6: Commit** `one-way: the image is built from main, and dev claude asks when core changed`.

### Task 2: Plugins named by name come from `main` (W1)

**Files:**
- Modify: `core/lib/conf.sh` (`use_src`, `use_base` for the clone
  form; new `main_dir`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `core_tree`'s failure message, which Task 1 established.
- Produces: `main_dir` prints the folder holding `main`'s `plugins/`
  (`$(dirname "$APPROVED")/main/<tree of main:plugins>`), extracting it
  first when it's missing (into a temp sibling, then `mv`, so two
  `dev`s never see half a copy). Older trees are removed. It fails like
  `build` without a `main`. `use_src <clone value>` (no root) =
  `$(main_dir)/plugins/<name>`, and `use_base` the same folder's
  `plugins`.

- [ ] **Step 1: Write the failing tests.**
  - `plugin-branch-not-shown`: `full_plugin`, approve. Switch to
    `claude/x`, change `plugins/w/rules/g.md`, commit, and also edit it
    uncommitted. `dev_in_p shell` without a terminal: the output has no
    "differs", and the approved `g.md` is still `Old.`.
  - `plugin-main-shown`: the same change committed on `main`:
    `echo y | tty_run` shows the diff line `+New.`, and the approved
    copy now has `New.`.
  - `main-dir-one-tree`: after `plugin-main-shown`, `main/` under the
    state folder holds exactly one tree folder.
  - The existing `mounts-approved-only` and the test at ~896 keep
    passing with their changes committed (Task 1 Step 1).
- [ ] **Step 2: Run them.** Expected: FAIL at `plugin-branch-not-shown`
  (the working tree's change is shown).
- [ ] **Step 3: Implement** `main_dir`, and the clone branches of
  `use_src` and `use_base`. Get the tree id with
  `git -C "$HERE" rev-parse main:plugins`.
- [ ] **Step 4: Run** `tests/run.sh`. Expected: all pass.
- [ ] **Step 5: Commit** `one-way: plugins named by name come from main, never from a checked-out branch`.

### Task 3: `dev update`

**Files:**
- Modify: `dev` (the `update)` case, the help lines)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `ask`. Produces: nothing for other tasks.

Behaviour, in order:

1. Without an upstream for `main`
   (`git rev-parse --abbrev-ref main@{upstream}` fails), refuse:
   `main has no upstream: git -C <HERE> branch -u origin/main main`.
2. Run `git fetch --quiet` for that remote. If it fails, stop with its
   message.
3. If `main` has commits the upstream lacks
   (`git rev-list main@{u}..main`), refuse:
   `main has commits the upstream lacks: dev update only fast-forwards`.
4. With nothing new, print `claude-box is up to date.` and exit 0.
5. Otherwise print `Coming from <upstream>:` and
   `git log --oneline main..main@{u}` indented, then
   `ask "Pull them?"`. On yes, with `main` checked out, run
   `git merge --ff-only --quiet main@{u}`. Elsewhere, run
   `git fetch --quiet . main@{u}:main`. Then print
   `Done. The next dev claude shows what changed in core and your plugins, and applies it after your yes.`

- [ ] **Step 1: Write the failing tests.** Make a bare upstream from
  `$CLONE` (`git clone -q --bare`), `branch -u`, and push one new commit
  to it from a second clone. The tests:
  - `update-yes`: `echo y | tty_run dev update` lists the commit's
    subject, and `main` equals the upstream.
  - `update-no`: `echo n` leaves `main` alone.
  - `update-none`: an up-to-date clone says so, and asks nothing.
  - `update-no-upstream`: refused, naming `branch -u`.
  - `update-diverged`: refused with "only fast-forwards", and `main`
    unchanged.
  - `update-on-branch`: with `claude/x` checked out, `y` moves `main`,
    and `HEAD` is still `claude/x`.
  - `update-no-terminal`: no change, exit 0.
- [ ] **Step 2: Run them.** Expected: FAIL with "Unknown command: update".
- [ ] **Step 3: Implement** the case. Help line:
  `dev update           pull a new claude-box (after your yes); the next dev claude applies it`.
- [ ] **Step 4: Run** `tests/run.sh`. Expected: all pass.
- [ ] **Step 5: Commit** `one-way: dev update shows what's coming and fast-forwards main after your yes`.

### Task 4: `./dev install` is the whole setup (D13, W4, W5)

**Files:**
- Modify: `dev` (`install)` ends with `exec "$HERE/dev" init`; `init)`
  asks the identity; the help lines for both)
- Test: `tests/test_dev.sh` (`init`, `init-starter`, `init-keeps`,
  `init-autotake`, new ones)

**Interfaces:**
- Consumes: `read_conf` (an identity is checked by writing
  `identity <typed>` to a temp file and reading it back), `ask`'s rule
  of no terminal meaning the default.
- Produces: the starter `~/.claude/.dev`. Its first line stays as today.
  Then, each with today's kind of one-line comment above it: the
  `identity …` line, `use workflow`, `autotake group` (W4).

- [ ] **Step 1: Write the failing tests.**
  - `install-runs-init`: `"$DEV" install < /dev/null` makes the link,
    writes `~/.claude/.dev` with
    `identity Claude <claude@claude-box.invalid>`, and runs the login
    box (`runs localhost/claude-box`).
  - `init-identity-typed`: `printf 'Ann <ann@example.org>\nn\n' | tty_run dev init`
    writes `identity Ann <ann@example.org>`.
  - `init-identity-enter`: `printf '\n'` writes the default.
  - `init-identity-bad`: `Bob`, then `Ann <ann@example.org>`. It asks
    again and writes Ann.
  - `init-keeps`, extended: an existing config means no identity
    question in the output.
  - `init-starter`: the lines are exactly `identity …`, `use workflow`,
    `autotake group` (`grep -v '^#' | grep .`).
- [ ] **Step 2: Run them.** Expected: FAIL at `install-runs-init` (no
  config written).
- [ ] **Step 3: Implement.** The question:
  `Claude's git identity, for its commits [Claude <claude@claude-box.invalid>]: `.
  `install` prints `Linked ~/.local/bin/dev -> <path>` and then runs
  init. Help: `./dev install   one-time, from the clone: puts dev on
  your PATH, then runs dev init`.
- [ ] **Step 4: Run** `tests/run.sh`. Expected: all pass.
- [ ] **Step 5: Commit** `one-way: ./dev install runs dev init, which asks Claude's identity first`.

### Task 5: The README, the maps and the docs (D15, D14's maps)

**Files:**
- Modify: `README.md`, `core/README.md` (adds *Map*),
  `docs/system/architecture/README.md`, `03-deployment.md` (*The
  image*), `docs/system/runbook.md`, `.gitignore` (the two `local/`
  lines go), `tests/run.sh` (README checks)
- Create: `plugins/workflow/README.md`,
  `docs/change/2026-10-31-simpler-model/stranger-test.sh` (W7)

- [ ] **Step 1: Write the failing checks** in `tests/run.sh` under
  `== README`:
  - `README.md`, `core/README.md` and `plugins/workflow/README.md` have
    no `company`, `pack(s)` or `layer(s)` (whole words, any case).
  - `README.md` has a heading `## What you change` whose table's header
    row is `| What you change | Where | Who | How it takes effect |`.
  - `core/README.md` and `plugins/workflow/README.md` each have a
    `## Map` heading.
  - `.gitignore` has no `local/`.
  Run `tests/run.sh`. Expected: FAIL on these four.
- [ ] **Step 2: README**, built around the model:
  - The two-level picture from the spec's *The model* (a code block).
  - *What you change*, with at least these rows: your global config
    (`~/.claude/.dev`), your global `CLAUDE.md` and rules, a project's
    `CLAUDE.md` and `.dev`, a plugin you use (yours, or this repo's),
    core (this repo's `core/`), and Claude Code itself. Each row links
    its runbook section.
  - The Quick start becomes `git clone …`, `cd claude-box`,
    `./dev install`, and the line "Then start `dev claude` in the clone
    and ask Claude to set you up" (D13).
  - *Commands* gains `dev update`, and `dev build` reads
    `rebuild the image for a newer Claude Code or Fedora`.
  - *Rules and plugins* says *core*, *global* and *project* (D1). The
    three-levels wording ("the box's own rules") becomes core under the
    two levels.
- [ ] **Step 3: The maps.** `core/README.md` adds `## Map`: one table
  row per part (`Containerfile`, `defaults.dev`, `managed-settings.json`,
  `rules/`, `plugin/box-workflow/`, `bin/` and each script, `lib/` and
  each module), with what it is, where it runs (laptop, image, box) and
  what it feeds. `plugins/workflow/README.md`: what the plugin is
  (ordinary, optional, brings superpowers) and `## Map` with
  `.claude-plugin/`, `rules/` (each file), `skills/closing/` and
  `starter/`. The architecture's workflow row then links this README
  instead of listing it (one fact, one place).
- [ ] **Step 4: Architecture.** *Rules* becomes *Levels* (core
  underneath, global, project, with Claude Code's scopes: managed,
  user, project). Fix every `#rules` link (the link check finds them).
  *Who changes what*'s last row: core changes by merging to `main`,
  then the next `dev claude`. *Known limits* gains W6's limit, and
  option 2 of the `ask` prompt (once chosen, the rest of the session
  edits `~/.claude` without asking; from
  `out/core-rules-box-evidence.md`). *Accepted risks* gains D2's: any
  box can propose a change to `~/.claude/.dev`, and nothing applies
  without your yes at a terminal. In `03-deployment.md`, *The image*:
  built from `git archive main core`, with the `claude-box.core` label.
  *Your layer*: plugins from `main` (W1).
- [ ] **Step 5: Runbook.** *Set up*: `./dev install` (the identity
  question, then the login). New *Update claude-box*: `dev update`,
  then the next `dev claude`. *Change the rules* becomes *Change your
  setup*: core and a plugin of this repo are changed by merging to
  `main`, then the next `dev claude` asks; no `dev build`. *Update
  Claude Code*: `dev build`, unchanged.
- [ ] **Step 6: `stranger-test.sh`** as W7. `shellcheck -S warning` is
  clean on it, and `tests/run.sh`'s ShellCheck line lists it.
- [ ] **Step 7: Run** `tests/run.sh`. Expected: all pass.
  `grep -niwE 'company|packs?|layers?' README.md core/README.md plugins/workflow/README.md`
  prints nothing.
- [ ] **Step 8: Commit** `one-way: the README around the model, the maps, update and setup in the runbook`.

### Task 6: The README test with a fresh reader

**Files:**
- Create: `docs/change/2026-10-31-simpler-model/findings-readme-test.md`

- [ ] **Step 1: Dispatch** a fresh subagent that reads only
  `README.md`, `core/README.md` and `plugins/workflow/README.md` at this
  branch's head, nothing else. For each of five things, it answers where
  it lives, who changes it, and how a change takes effect. The five
  things: Claude's git identity; the rule that Claude never commits to
  `main`; the rule on documents in three families; a tool one
  project's box needs; Claude Code's version.
- [ ] **Step 2: Record** the findings as the clear-layout ones are
  ([findings-readme-test.md](../2026-10-30-clear-layout/findings-readme-test.md)):
  the commit read, a verdict table (question, its answer, right?), and
  every doubt with the change it led to. Fix the README or the maps for
  each wrong or unsure answer, and ask again until all five are right.
- [ ] **Step 3: Run** `tests/run.sh`. Expected: all pass.
- [ ] **Step 4: Commit** `one-way: the README test with a fresh reader`.

## After the branch

1. A fresh reviewer on the most capable model reads the whole branch,
   and its Critical and Important findings are fixed.
2. The backlog gets W6's item (`dev` and `run-actions` run from `main`,
   not the checkout), on this branch.
3. The merge run (`out/actions.txt`): merge and push. Then the owner
   starts `dev claude` once: it asks once (W3) and rebuilds.
4. Then D16's remaining checks and the acceptance. These include a box
   whose `.dev` lacks `use workflow`, for the criterion
   `out/core-rules-box-evidence.md` leaves open, and the stranger test.
