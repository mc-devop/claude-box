# Kinds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Both `.dev` files say what a line brings in: `plugin` or
`rules`, with the same values and the same meaning at both levels. A
project's plugins and rules are shown and approved like your global
ones.

**Architecture:** In code, the item kind takes over the job of
`use_form`'s guess. `plugin` reads its form from its value (a name, a
`~/.claude/` folder, or a marketplace pair), and `rules` takes a
`~/.claude/` file or a pinned URL. The approval half of `choose_layer`
becomes `approve_sources <what> <conf file> <approved dir>`, which
rebinds `CONF_FILE` and `APPROVED` as locals, so `snapshot`,
`conf_hash` and `save_approved` work unchanged for a project too. A
project's `plugin` (by name or folder) and `rules` lines become a small
config file, which goes through the same function with
`~/.local/state/claude-box/projects/<image name>/approved/`. Then
`choose_image` builds those plugins into the project image, and
`choose_mounts` mounts their rules.

**Tech Stack:** bash (`core/lib/*.sh`, `dev`), the fake Podman in
`tests/test_dev.sh`, Markdown docs.

**Spec:** [spec-kinds.md](spec-kinds.md) (K1–K7), under the
[spec](spec.md).

## Decisions this plan adds

| # | Decision | Why |
|---|---|---|
| Q1 | The internal helpers keep their names (`use_form`, `use_src`, `use_key`, `use_name`, `use_base`). `use_rules <value>` goes, because the kind now says it. Items are `plugin <value>` and `rules <value>` | Surgical: the names are internal, and renaming them would touch every module for no behaviour |
| Q2 | An old project line `plugin <name>@<market> <owner/repo>`, skipped since branch 2, is the new marketplace form and is read again. `pack` stays skipped | They're the same text, so nothing breaks |
| Q3 | A project image is built when `.dev` has packages **or** approved project plugins. Its label `claude-box.packages` gains `src:<hash>`, from the project's approved hash. The project Containerfile sets `ENV CLAUDE_CODE_PLUGIN_DIRS=${CLAUDE_CODE_PLUGIN_DIRS}:<its plugins>` (Podman substitutes the base's value). **To check in a real box at acceptance** | One label still decides rebuilds |
| Q4 | `plugin_deps` prints `plugin <name>@<market> <owner/repo>`. A project plugin's dependencies install at local scope, through `sync_plugins` | Same rule at both levels |

## Global Constraints

- Kinds, exact: `plugin`, `rules`. Global `use` refusal:
  `"use" is gone: write "<plugin|rules> <value>"` (the replacement
  worked out for the line). Project notice:
  `.dev line <n>: "use <value>" is no longer read: write "<replacement>"`.
- A rules file mounts at `~/.claude/rules/files/<file>`. Nothing mounts
  under `rules/use/` any more.
- A project's approved copy:
  `$(dirname "$APPROVED")/projects/<image name minus localhost/>/approved`.
- No message, help line or `core/defaults.dev` line says `dev` "works
  out" anything (`grep -niE 'works? out' dev core/defaults.dev core/lib`).
- `tests/run.sh` passes before every commit.

## Review Focus

- **A project's `.dev` is written by Claude in the box**: a new
  `plugin ~/.claude/x` or `rules` line in it reaches no box without your
  yes at a terminal. Task 3: no terminal, nothing built or mounted.
- **The same plugin at both levels** (`plugin workflow` globally and in
  a project): refused at the project line, and the box doesn't start
  on half of it. Task 3.
- **A project whose approved copy can't be read** (made before a kinds
  change): counts as none, so it asks again. It never starts on a
  half-read copy. Task 3, with a broken `.dev` in the approved copy.
- **Two projects with the same folder name**, in different places:
  they share an image name today, so they share an approved copy. Q3's
  label then rebuilds when you switch between them; nothing wrong is
  mounted, because mounts come from the copy just approved. Accepted,
  and named in the architecture's known limits.
- **Your global config's `use` lines right after the merge**: `dev`
  refuses them, naming each replacement, until the merge run puts the
  new file in place. Task 1's test, and K7's draft.

---

### Task 1: `plugin` and `rules` in your global config

**Files:** `core/lib/conf.sh` (`read_conf`, the gone kinds,
`use_rules` removed), `core/lib/layer.sh` (`needs_layer`,
`plugin_deps`, `build_layer`), `core/lib/mounts.sh` (`rules/files/`),
`core/lib/project.sh` (`sync_global_plugins`, `lay_starters`), `dev`
(`init`'s starter: `plugin workflow`), `core/defaults.dev`,
`core/rules/CLAUDE.md:23`; test: `tests/test_dev.sh`

**Interfaces:**
- Produces: global items `plugin <value>` and `rules <value>`. Where
  the code tested `[ "$kind" = use ]` with `use_rules`, it now tests
  the kind.

- [ ] **Step 1: Tests.** Every `use` line in `tests/test_dev.sh`'s
  global configs becomes `plugin` or `rules`, and every
  `rules/use/` mount becomes `rules/files/`. New tests:
  - `kinds-wrong`: `plugin ~/.claude/r.md` is refused, naming `rules`.
    `rules ~/.claude/my-plugin` and `rules workflow` are refused,
    naming `plugin`.
  - `kinds-use-gone`: `use workflow` and `use ~/.claude/r.md` are
    refused with `write "plugin workflow"` and
    `write "rules ~/.claude/r.md"`.
  - `init-starter`'s lines become `identity …`, `plugin workflow`,
    `autotake group`. (On `main`, `init` has no identity line yet:
    `plugin workflow` and `autotake group`.)
  Run `bash tests/test_dev.sh`. Expected: FAIL at the first converted
  config.
- [ ] **Step 2: Implement.** `read_conf` gets `plugin)`, which takes
  the market, clone and home forms (a home value ending in `.md` is
  refused, naming `rules`), and `rules)`, which takes the url form and
  home `.md`. `use)` dies with the replacement. `company`, `global`,
  `pack` and `plugin-dir` stay gone, and `rules` and `plugin` leave
  that list. In `core/defaults.dev`, one block per kind: the values,
  then where each lands, in the spec's words (K3).
- [ ] **Step 3: Run** `tests/run.sh`. Expected: all pass, and the
  `works? out` grep prints nothing.
- [ ] **Step 4: Commit** `kinds: plugin and rules replace use in your config`.

### Task 2: The same kinds in a project's `.dev`

**Files:** `core/lib/project.sh` (`read_dev`, `sync_plugins`,
`dev_edit`), `dev` (help); test: `tests/test_dev.sh`

**Interfaces:**
- Produces: `read_dev` prints `plugin <name>@<m> <o/r>`,
  `plugin <name or ~/.claude/…>` and `rules <…>`, each checked with
  `read_conf`'s rules (one line in a temp file, read by `read_conf`
  with no root). `project_sources` prints only the second and third
  kinds, for Task 3.

- [ ] **Step 1: Tests.** The existing `dev-use-*` and `dev-old-lines*`
  tests are rewritten:
  - `use …` in a project is skipped with the notice, which names the
    replacement.
  - `plugin a@b o/r` is read and offered (Q2).
  - `pack` is still skipped.
  - `dev add plugin a@b o/r` and `dev add rules ~/.claude/r.md` write
    their lines; `dev add use x` is refused, naming both kinds.
  - `kinds-project-wrong`: `plugin ~/.claude/r.md` in a project is
    refused, naming `rules`.
  Expected: FAIL.
- [ ] **Step 2: Implement.** `sync_plugins` takes marketplace `plugin`
  lines (three fields).
- [ ] **Step 3: Run** `tests/run.sh`. **Step 4: Commit**
  `kinds: a project's .dev takes plugin and rules too`.

### Task 3: A project's plugins and rules, approved and built (K4, K5)

**Files:** `core/lib/layer.sh` (`approve_sources` out of
`choose_layer`), `core/lib/project.sh` (`choose_project_sources`,
`choose_image`, `build_project`), `core/lib/mounts.sh`; test:
`tests/test_dev.sh`

**Interfaces:**
- Consumes: `project_sources` (Task 2).
- Produces: `approve_sources <what> <conf> <approved>` returns 0 when
  the approved copy is current or was just approved and built, and 1
  on no, no terminal or a failed build. It prints today's diff, headed
  `<what> differs from the one you approved last:`. A build hook is
  passed as `$4`: the global one builds your layer, the project one
  does nothing, because `choose_image` builds. `PROJECT_APPROVED`
  holds the project's approved folder once `choose_project_sources`
  ran, and is empty when the project has no sources.

- [ ] **Step 1: Tests.**
  - `project-plugin-approved`: `.dev` has `plugin ~/.claude/pp` (with
    `rules/`) and `rules ~/.claude/pr.md`. `y`: the project image's
    Containerfile has `COPY plugins/pp …` and the `ENV` line of Q3.
    The mounts include `…/projects/claude-box-p/approved/home/.claude/pp/rules:/home/claude/.claude/rules/pp:ro,z`
    and `…/pr.md:/home/claude/.claude/rules/files/pr.md:ro,z`.
  - `project-plugin-no`: `n`, and no terminal. No `COPY`, no project
    mounts, and the box starts.
  - `project-plugin-change`: after approval, change `pr.md`. The diff
    is shown and the mount still serves the approved copy until `y`.
  - `project-plugin-other-box`: a second project without the line
    mounts nothing of it.
  - `project-both-levels`: `plugin workflow` globally and in the
    project is refused at the project's line, naming `~/.claude/.dev`.
  - `project-approved-broken`: break the project's approved `.dev`. It
    asks again, and without a terminal starts without the project's
    sources.
  Expected: FAIL.
- [ ] **Step 2: Implement** `approve_sources`, moving the code out of
  `choose_layer` unchanged in behaviour. The global tests must stay
  green before the project code goes in.
- [ ] **Step 3: Implement** `choose_project_sources`, called from
  `choose_image`'s callers before it: `shared_box`, `--new`, and
  `dev shell --new`. Then `build_project`'s plugins, and
  `choose_mounts`' project part.
- [ ] **Step 4: Run** `tests/run.sh`. **Step 5: Commit**
  `kinds: a project's plugins and rules are shown, approved and built like yours`.

### Task 4: Docs and moving over (K3, K7)

**Files:** `README.md`, `docs/system/architecture/README.md`,
`01-context.md`, `02-container.md`, `03-deployment.md`,
`docs/system/runbook.md`, `docs/direction/backlog.md` (the "one `use`
line" item); drafts `out/claude-dot-dev-kinds` and `out/actions.txt`

- [ ] **Step 1:** Every `use` in those docs becomes `plugin` or
  `rules`. The README's block "One line brings something in …" becomes
  a table: kind, value, where it lands. The architecture's *Plugins*
  table gets one row per kind and form, at both levels, plus the
  per-project approved copy. *Known limits* gets Review Focus line 4.
  `git grep -nE '\buse (workflow|~/|https|[a-z0-9-]+@)' -- ':!docs/change'`
  prints nothing.
- [ ] **Step 2:** `out/claude-dot-dev-kinds`: the owner's
  `~/.claude/.dev`, with the four `use` lines rewritten and everything
  else byte for byte. `out/actions.txt` (loading `box-workflow:dev-run`
  first) merges and pushes, puts the draft in place only if the live
  file still matches what it was made from, and removes
  `~/.claude/rules/use/` when it holds only empty mount points.
- [ ] **Step 3: Run** `tests/run.sh`. **Step 4: Commit**
  `kinds: the docs say plugin and rules`.

## After the branch

A fresh reviewer on the most capable model (what breaks, what's
overkill, what's missing), then one fix pass. Then the merge run.
After it, `claude/one-way` is rebuilt on the new `main`.
