# Each box's own plugins folder: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sessions load marketplace plugins only from the image's seeds, and what earlier claude-box versions left in `~/.claude/plugins/` is cleared after your yes.

**Architecture:** `box` mounts a tmpfs over `/home/claude/.claude/plugins` with your `plugins/data/` and `plugins/store/` mounted into it (P1, P2). `seed_clear`, run by `dev` on the host at every start, replaces `seed_moveover` (P3, P4).

**Tech Stack:** bash (`core/lib/`), python3 for JSON on the host (as `seed.sh` already does), Podman; tests in `tests/test_dev.sh` with its fake `podman`.

**Spec:** [spec-plugins-dir.md](spec-plugins-dir.md), on top of [spec.md](spec.md).

## Global Constraints

- Branch `claude/plugins-dir`, from the current `main`; `tests/run.sh` passes before every commit.
- Box paths: tmpfs at `/home/claude/.claude/plugins`; `$HOME/.claude/plugins/data` → `/home/claude/.claude/plugins/data`, `$HOME/.claude/plugins/store` → `/home/claude/.claude/plugins/store`, both `:z`.
- `seed_clear` touches nothing under `~/.claude/plugins/` except what P3 names, and in `~/.claude/settings.json` only those plugins' `enabledPlugins` keys.
- A path from a JSON record is removed only when it resolves (`realpath`) inside `$HOME/.claude/plugins/cache/` or `$HOME/.claude/plugins/marketplaces/`; records name box paths (`/home/claude/.claude/…`), mapped to `$HOME/.claude/…`.
- Ids and marketplace names from those files match `^[A-Za-z0-9_.-]+(@[A-Za-z0-9_.-]+)?$` or are skipped (they are box-writable).

## Review Focus

1. A record whose `installPath` points outside `~/.claude/plugins/cache/` (or through a symlink out of it): the record goes, the path stays (Task 3's `seed-clear-outside`).
2. `installed_plugins.json` or `settings.json` that isn't valid JSON: nothing removed, nothing rewritten, the start goes on (Task 3's `seed-clear-bad-json`).
3. `settings.json` with other keys and other plugins' `enabledPlugins`: all kept (Task 3's `seed-clear`).
4. A new user with no `~/.claude/plugins/`: the box starts, `data/` and `store/` exist after (Task 2's `box-plugins-dir`).
5. A second start after a yes: nothing offered (Task 3's `seed-clear-again`).

---

### Task 1: Check P1 and P2 in a real box

Before code, on the laptop through `dev run`. Read-only for your state: everything under a `mktemp -d`, your `~/.claude` never mounted.

**Files:**
- Create: `docs/change/2026-11-01-plugins-in-image/plugins-dir-checks.sh`
- Create: `docs/change/2026-11-01-plugins-in-image/findings-plugins-dir-checks.md`
- Modify: `out/actions.txt`

**Interfaces:**
- Produces: the tmpfs option string Task 2 uses (`TMPFS_OPT` in the findings).

- [ ] **Step 1: Write `plugins-dir-checks.sh`**, after [seed-checks.sh](seed-checks.sh) (time limit on `podman run`, outside the box; `--userns=keep-id:uid=1000,gid=1000 --cap-drop=all --security-opt=no-new-privileges`; image `localhost/claude-box.user`, your layer with the seed). A temp config folder `$T/cfg` is mounted at `/home/claude/.claude` with `CLAUDE_CONFIG_DIR` set to it.
  1. For each of `--mount type=tmpfs,destination=/home/claude/.claude/plugins,tmpfs-mode=0755,U=true` and `--tmpfs /home/claude/.claude/plugins:rw,mode=0755,uid=1000,gid=1000`: prints `stat -c '%U %a'` of the folder and whether `touch` in it works.
  2. With the first form that works, plus `$T/cfg/plugins/data` and `$T/cfg/plugins/store` mounted into it: writes `data/x`, `store/x` and `plugins/y` in the box; after it, prints which exist in `$T/cfg/plugins/`.
  3. `$T/cfg/plugins/installed_plugins.json` holds a shadow record (`superpowers@superpowers-marketplace`, scope `managed`, `installPath` `/home/claude/.claude/plugins/cache/superpowers-marketplace/superpowers/6.4.2`, an empty folder there). With the tmpfs, a session start with `--debug-file`: prints the lines matching `Using seed cache|installed plugins from`.
- [ ] **Step 2: Write `out/actions.txt`** (load `box-workflow:dev-run`): one `local` step running the script, its `>` saying it takes about a minute and writes only under a temp folder.
- [ ] **Step 3: The owner runs `dev run`; read `out/actions.log`.** If no tmpfs form gives Claude a writable folder, or 3 shows no "Using seed cache", stop and bring it to the owner.
- [ ] **Step 4: Record the findings** (one row per check), copy the log beside them as `plugins-dir-checks.log`, commit.

### Task 2: The box's plugins folder

**Files:**
- Modify: `core/lib/box.sh` (`box`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `TMPFS_OPT` from Task 1's findings.

- [ ] **Step 1: Write the failing test** `box-plugins-dir` next to the test at line ~188 (`has "$HOME/.claude:/home/claude/.claude:z"`): from a fresh HOME with no `~/.claude/plugins`, `dev_in_p shell`; then `has "$TMPFS_OPT"` (the exact argument), `has "$HOME/.claude/plugins/data:/home/claude/.claude/plugins/data:z"`, `has "$HOME/.claude/plugins/store:/home/claude/.claude/plugins/store:z"`, and `[ -d "$HOME/.claude/plugins/data" ] && [ -d "$HOME/.claude/plugins/store" ]`.
- [ ] **Step 2: Run** `bash tests/test_dev.sh`: FAIL at `box-plugins-dir`.
- [ ] **Step 3: In `box`**, after `mkdir -p "$HOME/.claude"`: `mkdir -p` the two folders; add the tmpfs and the two `-v` after the `~/.claude` mount (Podman mounts the deeper paths over it). Update the comment above `box`.
- [ ] **Step 4: Run** `tests/run.sh`: ALL PASSED.
- [ ] **Step 5: Commit.**

### Task 3: Clearing what's left (`seed_clear`)

**Files:**
- Modify: `core/lib/seed.sh` (replace `seed_moveover`), `core/lib/layer.sh:171`, `core/lib/mounts.sh:76`
- Test: `tests/test_dev.sh` (replace the five `seed-moveover*` tests)

**Interfaces:**
- Produces: `seed_clear <seed dir>`: the plugins of that approved seed (`seed_plugins`); returns 0 always. Callers: `seed_clear "$APPROVED/seed"` where `seed_moveover user` was, `seed_clear "$PROJECT_APPROVED/seed"` where `seed_moveover local` was.

Tests use the existing `installed` helper with `M='{"scope": "managed", "installPath": "/home/claude/.claude/plugins/cache/c4-model-skill/c4m/1", "version": "1"}'`, a cache folder made at that path under `$HOME`, `known_marketplaces.json` with `c4-model-skill` (`installLocation` `/home/claude/.claude/plugins/marketplaces/c4-model-skill`, folder made) and `x` (`/usr/local/share/claude-box/seed/marketplaces/x`), and `settings.json` `{"model": "m", "enabledPlugins": {"c4m@c4-model-skill": true, "z@y": true}}`.

- [ ] **Step 1: Write the failing tests:**
  - `seed-clear`: with `$C4` approved (as `seed-moveover` does), `printf 'y\ny\n'` → "Remove them?" shown, listing `c4m@c4-model-skill`; after: no `c4m@c4-model-skill` key in `installed_plugins.json`, its cache folder gone, `c4-model-skill` and `x` gone from `known_marketplaces.json`, `marketplaces/c4-model-skill` gone; `settings.json` keeps `model` and `z@y`, loses `c4m@c4-model-skill`; `data/` and `store/` untouched (a file in each stays); no `podman run` for it (`hasnt 'plugin uninstall'`).
  - `seed-clear-keep`: a record `x@y` (not in a seed): not listed, its files stay.
  - `seed-clear-shared`: `other@c4-model-skill` recorded too: `c4-model-skill` stays in `known_marketplaces.json` and `marketplaces/`.
  - `seed-clear-project`: the project's `.dev` has `plugin a@b o/r`, a record `a@b` at scope `local` with any `projectPath`: listed at that project's start.
  - `seed-clear-outside`: `installPath` `/home/claude/.claude/plugins/cache/../../../outside` with `$HOME/.claude/outside` present: the record goes, `$HOME/.claude/outside` stays.
  - `seed-clear-bad-json`: `installed_plugins.json` is `{`: nothing asked, the box starts, the file unchanged.
  - `seed-clear-no-tty`: no terminal: nothing removed, nothing asked.
  - `seed-clear-again`: after `seed-clear`'s yes, a second start: "Remove them?" not shown.
- [ ] **Step 2: Run** `bash tests/test_dev.sh`: the new tests FAIL.
- [ ] **Step 3: Implement `seed_clear`** in `seed.sh`: one python3 script computing the list (P3's four kinds), printing it; `ask "Remove them?"`; on yes, the same script with `--apply` removes them (JSON rewritten with `indent=2` to a temp file, then `mv`). Delete `seed_moveover`, its comment, and the call sites' old names.
- [ ] **Step 4: Run** `tests/run.sh`: ALL PASSED.
- [ ] **Step 5: Commit.**

### Task 4: The docs

**Files:**
- Modify: `docs/system/architecture/README.md` (known limits: the `known_marketplaces.json` item goes; the data-folder item names `store/` and says only those two folders are shared)
- Modify: `docs/system/architecture/03-deployment.md` (the two mounts tables at lines ~65 and ~94: rows for the tmpfs and the two folders; Plugins' "Moving over" row becomes "Clearing what's left", P3 in one line)
- Modify: `docs/system/architecture/02-container.md:57` ("global plugins" out of Claude's home: only plugins' state)

- [ ] **Step 1: Edit**, terms as the spec names them.
- [ ] **Step 2: Run** `tests/run.sh`: ALL PASSED (links).
- [ ] **Step 3: Commit.**

### Task 5: Review, merge run, handoffs

- [ ] **Step 1:** a fresh reviewer on the whole branch; fix Critical and Important findings with a test each; minors to the backlog or the spec's acceptance record.
- [ ] **Step 2:** `out/actions.txt`: merge `claude/plugins-dir`, push (as the earlier merge runs).
- [ ] **Step 3:** after the merge, the owner runs `dev claude` (answers P3's question) and restarts the other projects' sessions; a handoff to each of the three asks a one-line check (`claude -p --output-format stream-json --verbose` paths under `/usr/local/share/claude-box/seed`).
- [ ] **Step 4:** the acceptance per [spec-plugins-dir.md](spec-plugins-dir.md#acceptance), recorded in [spec.md](spec.md) as a second run.
