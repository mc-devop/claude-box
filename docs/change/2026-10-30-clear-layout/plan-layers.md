# Layers and packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every input belongs to one of three layers (company, global,
project); a pack brings all three with one line; your config has one
simple schema, explained in `box/defaults.conf` (spec D1 to D8, D13 to D15).

**Architecture:** `conf.sh` reads the new kinds and refuses the old ones;
`layer.sh` builds the company parts into your layer; a new `mounts.sh`
mounts the global and project parts read-only under `~/.claude/rules/`
from the approved snapshot; `project.sh` reads `.dev`'s `pack` lines. The
workflow pack moves into `packs/workflow/{company,global,project}/`.

**Tech Stack:** Bash, `tests/test_dev.sh` (fake podman), Markdown.

**Spec:** [spec.md](spec.md), branch 3 (`claude/layers`).

## Evidence: the check (spec, branch 3's first task)

Run 2026-10-30 22:43 on the laptop, with podman as `dev` mounts a box
(`out/actions.log`, copied into this folder as `check-rules-folder.log` in Task 6):

- **E4:** Claude Code reads a rule file in a subfolder of `~/.claude/rules/`
  (both codewords listed). D3's subfolders stand; D4 isn't needed.
- **Read-only:** a write into the `:ro` mount is refused.
- **E5:** Podman creates missing mount points in your laptop's
  `~/.claude`, owned by a user of its namespace, `~/.claude/rules/` itself
  included (sticky bit): you can't remove them or add rules there without
  `podman unshare`. So `dev` creates each mount point itself, as you,
  before it starts a box (Task 2).

## Global Constraints

- Built in the worktree `.worktrees/layers/` (D15); this clone's checkout
  stays on `main`. The worktree's `local/private-terms` links to the
  clone's (`../../../local/private-terms`), so the private-terms check runs.
- No aliases (D6): `rules` and `plugin-dir` are refused with a message
  naming `company`; nothing reads the old schema.
- Paths in your config: `local/<path>` only (E1's rules: letters, digits,
  `. _ / -`, no links out); the repo's packs only by `pack <name>`.
- Every file a box gets comes from the approved snapshot (E2, D3); mounts
  are `:ro,z`.
- Names this plan fixes (our own):
  - A pack's name: `^[A-Za-z0-9][A-Za-z0-9._-]*$`, not `local`,
    not `box-workflow`, not ending `-project` (each would collide with
    a mount or the box's plugin).
  - Mount targets: `~/.claude/rules/<pack>/` (global),
    `~/.claude/rules/<pack>-project/` (project rules),
    `~/.claude/rules/local/<file>` (a `global` line).
  - A pack's plugin goes into the image at
    `/usr/local/share/claude-box/plugins/<pack>`, its starter at
    `/usr/local/share/claude-box/packs/<pack>/starter/`.
- Company rules are imported in config order. A pack's `company/*.md`
  files come at its line, sorted by name, numbered on (`NN-<file>`).
- `tests/run.sh` passes before every commit; the plugin keeps its name
  `workflow` (E17).

## Review Focus

1. **The first start after the merge.** Your approved snapshot has
   `rules` lines, so it's unreadable and counts as none (D6). At a
   terminal you're shown the whole config and asked; without one, dev
   refuses, naming why. It never starts on the defaults without saying
   so. Test: `approved-old-schema`.
2. **A layer that fails to build on real Podman.** The fake podman
   accepts any Containerfile. Test `layer-copy-sources`: every `COPY`
   source the layer's Containerfile names exists in the build context.
3. **Mount points on your laptop.** Each mount target exists before
   `podman run` and is owned by you, not Podman (E5). Test:
   `mounts-points-yours`.
4. **Two parts landing on one path.** Two `global` files of one name; a
   `company` folder and a pack's plugin of one name; a pack named
   `x-project` next to pack `x`. All are refused at their line. Test:
   `conf-collisions`.
5. **A starter file loaded as a rule.** Starter Markdown is never under
   `~/.claude/rules/`, only in the image's
   `/usr/local/share/claude-box/packs/`. Test: `pack-all-parts`
   asserts there's no mount of `starter`.

---

### Task 1: The config's kinds (D5, D6)

**Files:**
- Modify: `box/lib/conf.sh` (`clone_path`, `read_conf`, `conf_paths`, `approved_items`, a new `approved_ok`), `box/lib/layer.sh` (`needs_layer` and `build_layer`: the `rules` and `plugin-dir` cases become `company`'s, a file or URL a rule and a folder a plugin; `choose_layer`: D6's refusal, and the approved hash read only through `approved_ok`), `tests/test_dev.sh`

**Interfaces:**
- Produces:
  - `read_conf` items: `company <local/file|local/folder|URL sha256:…>`,
    `global <local/file.md>`, `pack <name>`, plus the kept kinds.
  - `conf_paths` prints `local/…` for `company` (not URLs) and
    `global`, and `packs/<name>` for `pack`; so `snapshot` and
    `conf_hash` cover pack folders.
  - `approved_ok`: true when `$APPROVED/hash` exists and its config
    reads.
  - `clone_path <path> p <root>`: a folder, with the same rules on
    links and specials as `d`, but no `plugin.json` needed.

- [ ] **Step 1: Convert the existing tests to the new schema.**
  - `rules local/…` and `plugin-dir local/…` become `company local/…`.
    `approve_layer` uses `company local/r.md`.
  - The `packs/` path tests become `pack` tests. Each keeps its refusal,
    asserted with `line N:`:
    - `conf-packs` (with `pack_dir` making `packs/<n>/company/plugin/`): accepted and in the approved copy; what's built is Task 2's;
    - `conf-packs-bounds` (a link out of `packs/<n>/`);
    - `conf-base-plugin`, `conf-manifest-name` (`packs/box-workflow`,
      or a pack plugin's manifest named `box-workflow`);
    - `conf-path-shape`, `conf-top-link`;
    - `layer-pack-change` (a pack file changed after approval is shown).
  - `packs-shipped` waits for Task 4: `pack workflow`.
- [ ] **Step 2: Add the failing tests:**
  - `conf-old-kinds`: for `rules local/r.md` and `plugin-dir local/pl`, `dev shell` exits non-zero; output has `line 1:` and `company`; `not_called run`.
  - `conf-new-kinds`: `company local/r.md`, `company local/pl` (a plugin folder), `company https://example.org/0123abc/k.md sha256:<64 hex>`, `global local/g.md`, `pack w` (`packs/w/global/a.md`) are each accepted (`dev shell` exits 0 at a terminal with `y`).
  - `conf-new-bounds`, each refused with `line 1:`:
    - `company packs/w/x.md`, `global packs/w/global/a.md` (packs only by name);
    - `global local/g.txt` (not `.md`);
    - `pack nope` (no folder);
    - `pack local`, `pack box-workflow`;
    - `pack e` with an empty `packs/e/` (none of the three parts).
  - `conf-collisions`, each refused at line 2:
    - `global local/a/g.md` then `global local/b/g.md`;
    - `company local/w` (a plugin folder) then `pack w` with `company/plugin/`;
    - `pack x` then `pack x-project`.
  - `approved-old-schema`: the approved snapshot holds `rules local/r.md` and a `hash`; your config is `company local/r.md`.
    - With `y` at a terminal: the diff shows `+company local/r.md`, it's approved, and the box runs.
    - Again with a fresh old snapshot and no terminal: exit non-zero; output names `local/claude-box.conf` and `terminal`; `not_called run`.
  - `conf-snapshot-pack`: after approving `pack w`, `approved/packs/w/global/a.md` exists; editing `packs/w/global/a.md` shows its diff at the next start.
- [ ] **Step 3: Run them.** Run: `GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh`. Expected: FAIL at the first new or converted case (`unknown kind "company"`).
- [ ] **Step 4: Implement** in `conf.sh` and `choose_layer`:
  - `rules`/`plugin-dir` die with `line $n: "$kind" is gone: use "company <file, plugin folder or URL in local/>" or "pack <name>" (box/defaults.conf)`.
  - Without a terminal (`[ -t 0 ]` false), no `approved_ok` and a config that differs: `die "Your config (local/claude-box.conf) has no approved version dev can read, and no terminal to ask: run dev claude in a terminal once."`
  - With no `approved_ok`, the diff compares against an empty `approved/`.
- [ ] **Step 5: Run the checks.** Run: `tests/run.sh > "$ws/run.log" 2>&1; echo $?` (`ws` the plan's workspace). Expected: `0`, `ALL PASSED`.
- [ ] **Step 6: Commit** `Config: company, global and pack; rules and plugin-dir refused`.

### Task 2: Your layer and the mounts (D3)

**Files:**
- Create: `box/lib/mounts.sh` (`choose_mounts`)
- Modify: `box/lib/layer.sh` (`needs_layer`, `build_layer`: packs), `box/lib/box.sh` (`run_box` adds `"${MOUNTS[@]}"`; `shared_box` calls `choose_mounts` after `choose_layer`, also for a scratch), `dev` (global `MOUNTS=()`; sources `mounts.sh`; `claude --new` and `shell --new` call `choose_mounts` after `choose_layer`), `tests/test_dev.sh`

**Interfaces:**
- Consumes: Task 1's items, `approved_ok`.
- Produces: `choose_mounts`: sets `MOUNTS` (podman `-v` words, each
  `<source>:<target>:ro,z`, sources under `$APPROVED`) and creates each
  target under `$HOME/.claude/rules/` first:
  - folders with `mkdir -p`;
  - a `global` file as an empty file, only when missing.

  With no `approved_ok`: no mounts. In a project it reads `.dev`'s `pack`
  lines with Task 3's `read_dev`; until then, global parts only.

- [ ] **Step 1: Write the failing tests:**
  - `layer-company`: `company local/r.md` gives `COPY rules/01-r.md …` and `@/etc/claude-code/local/01-r.md` in `local.md`; `company local/pl` gives `…/plugins/pl` in `CLAUDE_CODE_PLUGIN_DIRS`. These are `layer-first`'s assertions on the new lines; fold them into `layer-first`.
  - `pack-all-parts`, with pack `w`: `company/b.md`, `company/a.md`, `company/plugin/` (manifest `w`), `global/g.md`, `project/rules/p.md`, `project/starter/s.md`, and config `company local/r.md` then `pack w`:
    - The layer has `01-r.md`, `02-a.md`, `03-b.md` in that order in `local.md`.
    - `ENV CLAUDE_CODE_PLUGIN_DIRS=…/box-workflow:…/plugins/w`.
    - `COPY packs/w/starter /usr/local/share/claude-box/packs/w/starter`.
    - The box runs with `$HOME/.local/state/claude-box/approved/packs/w/global:/home/claude/.claude/rules/w:ro,z`.
    - No `-v` word contains `starter`, and no `w-project` mount (no `.dev`).
  - `mounts-global-file`: `global local/g.md` gives `…/approved/local/g.md:/home/claude/.claude/rules/local/g.md:ro,z`.
  - `mounts-approved-only`: after approval, editing `packs/w/global/g.md` and starting without a terminal mounts the approved copy, whose text is the old one.
  - `mounts-points-yours`: after a start, `$HOME/.claude/rules/w` is a folder and `$HOME/.claude/rules/local/g.md` a file, both owned by you (`[ -O … ]`).
  - `mounts-scratch`: a scratch's box gets the global mount.
  - `layer-copy-sources`: for `pack-all-parts`'s build, every `COPY <src> <dst>` in the logged Containerfile has `$FAKE/ctx/<src>`.
  - `mounts-none`: no config, no `-v` word with `/.claude/rules/`.
- [ ] **Step 2: Run them.** Run: `GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh`. Expected: FAIL at `layer-first` or `pack-all-parts`.
- [ ] **Step 3: Implement:**
  - `needs_layer` also matches `pack`.
  - `build_layer` handles `pack` (`company/*.md`, `company/plugin`, `project/starter`), and its `chmod -R a+rX` covers `/usr/local/share/claude-box`.
  - Then `mounts.sh`, `run_box` and the callers.
- [ ] **Step 4: Run the checks.** Run: `tests/run.sh > "$ws/run.log" 2>&1; echo $?`. Expected: `0`, `ALL PASSED`.
- [ ] **Step 5: Commit** `Layer and mounts: company parts built in, global parts mounted read-only`.

### Task 3: `.dev`'s `pack` (D7, E12)

**Files:**
- Modify: `box/lib/project.sh` (`read_dev`, `dev_edit`, their messages), `box/lib/mounts.sh` (project rules), `box/company/CLAUDE.md` (names the `pack` kind), `dev` (the help's `dev add` line names `pack`), `tests/test_dev.sh`

**Interfaces:**
- Produces: `.dev` items `pack <name>` (Task 1's name rule); `dev add pack <name>`, `dev remove pack <name>`.

- [ ] **Step 1: Write the failing tests:**
  - `dev-pack-add`: `dev add pack w` writes the line `pack w`; `dev remove pack w` takes it out.
  - `dev-pack-mount`: with the config's `pack w` approved and `.dev` `pack w`, the box runs with `…/approved/packs/w/project/rules:/home/claude/.claude/rules/w-project:ro,z`.
  - `dev-pack-missing`: `.dev` `pack w` without the config's: exit 0; stderr names `pack w` and `local/claude-box.conf`; the box runs, with no `w-project` mount.
  - `dev-pack-bad`: `.dev` `pack ../x` is refused with `.dev line 1:`.
  - `box-rules-pack`: `box/company/CLAUDE.md` names `` `pack` ``.
- [ ] **Step 2: Run them.** Run: `GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh`. Expected: FAIL at `dev-pack-add` (`Usage: dev add …`).
- [ ] **Step 3: Implement:**
  - `read_dev`'s `pack` kind.
  - `dev_edit`'s kinds and usage (`dnf|npm|pip|plugin|port|pack`).
  - `choose_mounts`' project part and the warning: `This project's .dev names pack <n>, which your approved config doesn't (local/claude-box.conf: pack <n>): starting without its project rules.`
  - In `box/company/CLAUDE.md`, a sentence after the kinds: `` `pack <name>` `` brings that pack's project rules, when the human's config has the pack.
- [ ] **Step 4: Run the checks.** Run: `tests/run.sh > "$ws/run.log" 2>&1; echo $?`. Expected: `0`, `ALL PASSED`.
- [ ] **Step 5: Commit** `.dev: pack <name> brings a pack's project rules`.

### Task 4: The workflow pack (D13)

**Files:**
- Move (`git mv`):
  - `packs/documentation.md` → `packs/workflow/company/documentation.md`;
  - `packs/change-management.md` → `packs/workflow/company/change-management.md`;
  - `packs/workflow/.claude-plugin`, `packs/workflow/skills` → `packs/workflow/company/plugin/`;
  - `tests/check_links.py` → `packs/workflow/project/starter/tests/check_links.py`.
- Create:
  - `packs/workflow/global/specs-and-plans.md` and `packs/workflow/global/markdown.md`: the sections "Specs and plans (superpowers)" and "Markdown files" of your global `CLAUDE.md`, as `#` headings, word for word except the clause naming another project as the source of `tests/check_links.py`, which becomes "the workflow pack's starter `tests/check_links.py` (standard library only)";
  - `packs/workflow/project/rules/starter.md`: the pack's starter files are in `/usr/local/share/claude-box/packs/workflow/starter/` (read-only); a file there that the project lacks is copied on a `claude/` branch, and `tests/check_links.py` runs in its test run.
- Modify: `tests/run.sh` (`python3 packs/workflow/project/starter/tests/check_links.py .` and its example check), `packs/workflow/company/plugin/.claude-plugin/plugin.json` (description unchanged unless it names a moved path), links to the moved files (`docs/system/`, `README.md`; records only by link target), `tests/test_dev.sh` (`packs-shipped`)

- [ ] **Step 1: Make `packs-shipped` fail.** `conf 'pack workflow'` approved at a terminal:
  - `$FAKE/ctx/plugins/workflow/skills/closing/SKILL.md` exists;
  - `local.md` imports `01-change-management.md` and `02-documentation.md`;
  - the box runs with the `rules/workflow:ro,z` mount;
  - `$FAKE/ctx/packs/workflow/starter/tests/check_links.py` exists.

  Run: `GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh`. Expected: FAIL at `packs-shipped`.
- [ ] **Step 2: Move and write** per Files. Run: `git status --short | grep -c '^R'`. Expected: `6` or more (the moves are renames).
- [ ] **Step 3: Run the checks.** Run: `tests/run.sh > "$ws/run.log" 2>&1; echo $?`. Expected: `0`, `ALL PASSED`; private terms `0 matches`.
- [ ] **Step 4: Commit** `packs/workflow: the whole workflow in three parts`.

### Task 5: The reference, `dev init`'s starter, the system docs (D8)

**Files:**
- Modify:
  - `box/defaults.conf`: its header explains every kind (`identity`, `company`, `global`, `pack`, `plugin`, `dnf`, `projects`, `memory`, `cpus`, `remote-control`) with an example each, a pack's three parts (D2) and where each lands (D3), and the repo's packs (`pack workflow`) and Karpathy's guidelines as a `company` URL line. Its items stay `projects` and `remote-control`;
  - `dev`: `init` writes `local/claude-box.conf` when there's none, and says so;
  - `docs/system/architecture/README.md`, `02-container.md`, `03-deployment.md`: layers, packs, mounts, the new kinds;
  - `docs/system/runbook.md`: "your settings" steps start from `dev init`'s file; editing a pack;
  - `README.md`: only the lines naming old kinds (branch 4 rewrites it);
  - `tests/test_dev.sh`.
- [ ] **Step 1: Write the failing tests:**
  - `init-starter`: `dev init`, with no `local/`, writes `local/claude-box.conf`. Its first line is `# Your claude-box config: every kind, with examples, is in box/defaults.conf.`, and it reads without error.
  - `init-keeps`: a second `dev init` leaves an edited config unchanged.
  - `defaults-every-kind`: each of the ten kinds appears in `box/defaults.conf` as `#   <kind> `.
- [ ] **Step 2: Run them.** Expected: FAIL at `init-starter`.
- [ ] **Step 3: Implement**, then `grep -rnE 'plugin-dir|rules (local|packs)/' README.md docs/system box dev`. Expected: nothing.
- [ ] **Step 4: Run the checks.** Run: `tests/run.sh > "$ws/run.log" 2>&1; echo $?`. Expected: `0`, `ALL PASSED`.
- [ ] **Step 5: Commit** `defaults.conf explains every kind; dev init writes your config`.

### Task 6: Your setup, as drafts (D13, D15)

**Files:**
- Create (not committed):
  - `out/claude-box.conf`: your `local/claude-box.conf` converted. Its first line is the starter's; then your `identity`, the Karpathy line as `company …`, `pack workflow`, `projects`, `remote-control`, your three `plugin` lines, with no old header;
  - `out/global-CLAUDE.md`: your `~/.claude/CLAUDE.md` without "Specs and plans (superpowers)" and "Markdown files";
  - `out/drafts-base.sha256`: the `sha256sum` of the two current files they replace:

    ```
    f3e1819929a197d484c62a5d76d110f05876f1d6ab304cc6aefff9f6ce7f275e  local/claude-box.conf
    6e8e11a7d602e68bf85ae651885ec289db4d7e721ee850228ac5b13462fb571a  ~/.claude/CLAUDE.md
    ```
- Copy: `out/actions.log` of the check → `docs/change/2026-10-30-clear-layout/check-rules-folder.log` (committed)

- [ ] **Step 1: Check the draft config.** Run it through the worktree's `read_conf` in a copy of the clone with `packs/`. Expected: its items print and nothing dies.
- [ ] **Step 2: Check the text moved, not lost.** The two removed sections equal the two `global/` files, apart from the heading level and the one rewritten clause. Run: `diff` of each pair. Expected: only those lines.
- [ ] **Step 3: Commit** the log: `Clear layout: the rules-folder check's log`.

### Task 7: Merge run and notices (after the final review and the owner's look)

**Files:** `out/actions.txt`, `out/handoff-<project>.md`

- [ ] **Step 1: Write the merge run**, titled `claude-box: Merge claude/layers (puts your config and global CLAUDE.md in place), push`. Each `local` step:
  1. `git merge --no-ff claude/layers`, refusing unless the checkout is a clean `main` and `claude/layers` starts from it.
  2. Puts `out/claude-box.conf` in place as `local/claude-box.conf` and `out/global-CLAUDE.md` as `~/.claude/CLAUDE.md`, each only if `sha256sum -c` of its line in `out/drafts-base.sha256` passes.
  3. `git worktree remove .worktrees/layers && rm .worktrees/.gitignore && rmdir .worktrees`, then `git branch -d claude/layers`.
  4. `git push origin main`.
- [ ] **Step 2: Check it.** Run: `box/bin/run-actions --check out/actions.txt`. Expected: `ok`.
- [ ] **Step 3: After the run**, the owner starts `dev claude --continue` at a terminal, sees the converted config and approves it. Then:
  - read the after state inside the new box and compare it with `out/compare/before/`;
  - send D14's notice to each project with a handoff in `out/`, logged there.
