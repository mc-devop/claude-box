# Plugins in the image: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A marketplace `plugin` line lands in that level's image as a Claude Code seed, approved like every other change, instead of being installed into `~/.claude/plugins/`.

**Architecture:** A new `core/lib/seed.sh` stages a seed in a throwaway box, records the upstream heads, compares seeds, and checks upstream with `git ls-remote`. The seed is part of a level's snapshot and approved copy (`<approved>/seed/`), so the existing `approve_sources` flow shows it, hashes it and saves it, and the existing labels rebuild the images. The layer and a project's image copy their approved seed in and switch its plugins on with a managed-settings drop-in.

**Tech Stack:** Bash (dev's modules), python3 for JSON, Podman, git, Claude Code's `claude plugin` CLI inside the box.

**Spec:** [spec.md](spec.md), with its [review](findings-spec-review.md).

## Global Constraints

- The seed folders in an image: `/usr/local/share/claude-box/seed/` (yours) and `/usr/local/share/claude-box/seed-project/` (a project's), owned by root.
- `CLAUDE_CODE_PLUGIN_SEED_DIR`: the project's seed first, then yours, separated by `:`.
- Drop-ins: `/etc/claude-code/managed-settings.d/claude-box-plugins.json` (layer) and `claude-box-project-plugins.json` (project), each `{"enabledPlugins": {"<id>": true, …}}`.
- `dev` never fetches or installs a plugin: Claude Code does, in the staging box. The only source fields `dev` reads are a `marketplace.json` entry's repo and `ref` (S4).
- The check always uses HTTPS: `https://github.com/<owner/repo>`; each `git ls-remote` gets `timeout 10`.
- The staging box sees no `~/.claude` and no project: one mounted folder, and `CLAUDE_CONFIG_DIR` inside the box's own `/tmp`.
- **Refinement of S3** (recorded in the acceptance): the approved seed lives in the approved copy, `<approved>/seed/` (`~/.local/state/claude-box/approved/seed/`, or the project's `…/projects/<folder>-<hash>/approved/seed/`), so it rotates into `approved-old/` with the rest.

## Review Focus

1. A staging that exits 0 but installed nothing (no `installed_plugins.json`, or a line's plugin missing from it) counts as failed: the approved seed stays (Task 2's `seed-stage-empty`).
2. A start without a terminal when upstream moved: nothing asked, the approved seed used, one line said (Task 4's `seed-moved-no-tty`).
3. A plugin named by a line and also a folder plugin's dependency is staged once (Task 2's `seed-lines-dedupe`).
4. A check that hangs (a slow host) ends after 10 seconds and counts as failed (Task 3's `seed-check-timeout`, with a fake `git` that sleeps).
5. Upstream moved with no change to any plugin: the approved seed's heads are refreshed silently, so the next start doesn't stage again (Task 4's `seed-moved-same`).

---

### Task 1: Check S7 and S11 in a real box

The spec's two checks, before any code. They run on the laptop through `dev run`, with the base image the laptop already has. Nothing touches `~/.claude`: each run uses a throwaway config folder.

**Files:**
- Create: `docs/change/2026-11-01-plugins-in-image/seed-checks.sh` (read-only for the laptop's state: writes only under a `mktemp -d`)
- Create: `docs/change/2026-11-01-plugins-in-image/findings-seed-checks.md`
- Modify: `out/actions.txt`

**Interfaces:**
- Produces: the findings that decide Task 5's S7 branch (both seeds may hold one marketplace, or a marketplace is refused at the second level) and Task 7's known-limit text (S11).

- [ ] **Step 1: Write `seed-checks.sh`**

It runs `podman run --rm --userns=keep-id:uid=1000,gid=1000 localhost/claude-box bash -c …` four times, mounting only its temp folders:
1. Stage seed A (`superpowers@superpowers-marketplace` from `obra/superpowers-marketplace`) and seed B (`elements-of-style@superpowers-marketplace`, the same marketplace) with `CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed` and `CLAUDE_CONFIG_DIR=/tmp/h`. Prints whether `claude plugin install` needed a login (exit status and its last line).
2. With both seeds mounted read-only, `CLAUDE_CODE_PLUGIN_SEED_DIR=/seedB:/seedA`, a drop-in mounted at `/etc/claude-code/managed-settings.d/x.json` enabling both, and `CLAUDE_CONFIG_DIR` an empty temp folder mounted read-write: `claude plugin list --json`. Prints each plugin's id, enabled state and path (S7: both load, each from its own seed).
3. After step 2: lists what Claude Code wrote into the temp config folder's `plugins/` (`find … -type f`) and prints `known_marketplaces.json` with paths only (S11).
4. As Claude, `touch` inside the seed fails (prints the error).

- [ ] **Step 2: Write `out/actions.txt`** (load `box-workflow:dev-run` first): one `local` step running the script, `>` lines saying it takes about two minutes (two plugin installs) and writes only under a temp folder.

- [ ] **Step 3: The owner runs `dev run`; read `out/actions.log`.**

- [ ] **Step 4: Record `findings-seed-checks.md`**: one row per check, answer and consequence. If `plugin install` needs a login, stop and bring it to the owner (the spec's S2 doesn't hold). If check 2 fails, Task 5 takes the refusal branch.

- [ ] **Step 5: Commit** the script, the log copy (`seed-checks.log`) and the findings.

### Task 2: Stage, read and compare a seed

**Files:**
- Create: `core/lib/seed.sh`
- Create: `core/bin/stage-seed` (`core/bin/box-plugins` stays until Task 5 removes its last caller)
- Modify: `core/Containerfile` (also copy `stage-seed`; `RUN mkdir -p /etc/claude-code/managed-settings.d`)
- Modify: `dev` (source `seed.sh` beside the other modules)
- Test: `tests/test_dev.sh` (the fake `podman run` learns to stage)

**Interfaces:**
- Consumes: `plugin_deps <folder>`, `use_form`, `use_src`, `read_conf` (existing).
- Produces:
  - `seed_lines <root>`: the marketplace lines of `<root>/.dev` plus `plugin_deps` of its folder plugins, as `plugin <name>@<market> <owner/repo>`, sorted, unique.
  - `stage_seed <dest> <lines>`: 0 when every line's plugin is in `<dest>/installed_plugins.json`, else 1 with the box's last 5 lines on stderr. Writes `<dest>/claude-box-lines` (the lines) and, through Task 3's `seed_record_heads`, `<dest>/claude-box-heads`.
  - `seed_plugins <seed>`: `<id> <version>` per plugin, sorted.
  - `seed_digest <seed>`: 16 hex characters over `seed_plugins` and every file under each plugin's install folder (paths taken relative to the seed).
  - `seed_changes <old> <new>`: lines `+ <id> <version>`, `- <id>`, `~ <id> <old version> -> <new version>` (also when only files differ); nothing when the seeds hold the same plugins with the same files.
  - `seed_enable_json <seed>`: `{"enabledPlugins": {...}}` with each id `true`.

- [ ] **Step 1: Teach the fake `podman run` to stage.** When its arguments hold `CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed`, it finds the `-v <dir>:/seed…` mount and, for each `FAKE_STAGE` word `<id>=<version>`, writes `installed_plugins.json` (`{"version": 2, "plugins": {"<id>": [{"scope": "user", "installPath": "/seed/cache/<market>/<name>/<version>", "version": "<version>"}]}}`), the folder `cache/<market>/<name>/<version>/` with a file `f` holding `$FAKE_STAGE_BODY` (default `x`), and `marketplaces/<market>/.claude-plugin/marketplace.json` from `FAKE_MARKET_JSON` (default `{"plugins": []}`). `FAKE_STAGE_STATUS` sets its exit.

- [ ] **Step 2: Write the failing tests**

```bash
fresh seed-stage            # a staged seed: its plugins read back; the box saw only the seed
conf 'plugin c4m@c4-model-skill cheriftj/c4-model-skill'
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s" "plugin c4m@c4-model-skill cheriftj/c4-model-skill" || fail "staging failed"
[ "$(run_seed seed_plugins "$tmp/s")" = "c4m@c4-model-skill 1.0" ] || fail "plugins: $(run_seed seed_plugins "$tmp/s")"
has stage-seed; has cheriftj/c4-model-skill; has c4m@c4-model-skill
hasnt "/home/claude/.claude:"; hasnt "/work/"

fresh seed-stage-empty      # exit 0 but the plugin isn't there: failed
FAKE_STAGE='' run_seed stage_seed "$tmp/s" "plugin c4m@c4-model-skill cheriftj/c4-model-skill" && fail "an empty staging passed"

fresh seed-lines-dedupe     # a line that is also a folder plugin's dependency: once
conf 'plugin workflow' 'plugin superpowers@superpowers-marketplace obra/superpowers-marketplace'
[ "$(run_seed seed_lines "$APPROVED_SNAPSHOT" | grep -c superpowers@)" = 1 ] || fail "staged twice"

fresh seed-changes          # same files: nothing; other files or version: ~; new: +; gone: -
L='plugin c4m@c4-model-skill cheriftj/c4-model-skill'
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/a" "$L"
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/b" "$L"
[ -z "$(run_seed seed_changes "$tmp/a" "$tmp/b")" ] || fail "same seeds differ"
FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_BODY=y run_seed stage_seed "$tmp/c" "$L"
[ "$(run_seed seed_changes "$tmp/a" "$tmp/c")" = "~ c4m@c4-model-skill 1.0 -> 1.0" ] || fail "file change not shown"
FAKE_STAGE='c4m@c4-model-skill=1.0 x@y=2' run_seed stage_seed "$tmp/d" "$L"
grep -qxF '+ x@y 2' <(run_seed seed_changes "$tmp/a" "$tmp/d") || fail "new plugin not shown"
grep -qxF -- '- x@y' <(run_seed seed_changes "$tmp/d" "$tmp/a") || fail "gone plugin not shown"
```

`tty_run_in_p` runs `tty_run` from the test project's folder. `run_seed <fn> <args>` (a new helper beside `dev_in_p`) sources `common.sh`, `conf.sh`, `layer.sh` and `seed.sh` from the clone with the test's `HOME` and calls the function. `$APPROVED_SNAPSHOT` is a `snapshot` of the test's config, made by the same helper.

- [ ] **Step 3: Run them to see them fail.** `bash tests/test_dev.sh` → `test_dev FAIL (seed-stage)`.

- [ ] **Step 4: Implement** `core/bin/stage-seed <owner/repo> <id>...` (pairs; `claude plugin marketplace add`, then `claude plugin install <id>`; exit 1 on the first failure, with Claude Code's output), and the six functions in `core/lib/seed.sh`. `stage_seed` runs `podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all --security-opt=no-new-privileges -v <dest>:/seed:z -e CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed -e CLAUDE_CONFIG_DIR=/tmp/h "$IMAGE" stage-seed …`; JSON is read with python3, as `enabled_plugins` does today.

- [ ] **Step 5: Run the suite.** `tests/run.sh` → `ALL PASSED` (the existing `box-plugins` tests still pass: nothing calls the new functions yet).

- [ ] **Step 6: Commit** `plugins-in-image: stage, read and compare a seed`.

### Task 3: Record and check upstream heads

**Files:**
- Modify: `core/lib/seed.sh`
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `<seed>/claude-box-lines`, `<seed>/marketplaces/<m>/.claude-plugin/marketplace.json`, `<seed>/installed_plugins.json`.
- Produces:
  - `seed_sources <seed>`: `<url> <ref>` pairs to check (`ref` is `HEAD` when unset): each line's `${SEED_GIT_BASE:-https://github.com/}<owner/repo>`, and for each installed plugin, its entry's `url` (`url`, `git-subdir`) or `${SEED_GIT_BASE}<repo>` (`github`); an entry with a `sha`, a relative path or `npm` adds nothing.
  - `seed_record_heads <seed>`: writes `<seed>/claude-box-heads`, `<url> <ref> <sha>` per source; 1 if any `ls-remote` fails.
  - `seed_moved <seed>`: 0 moved, 1 not moved, 2 the check failed (one line on stderr naming the source).

- [ ] **Step 1: Write the failing tests**, with local repos as upstream (`SEED_GIT_BASE="file://$tmp/up/"`):

```bash
fresh seed-check-same       # no new commit: 1
fresh seed-check-moved      # a commit in the marketplace repo: 0
fresh seed-check-plugin     # a commit in the plugin's own repo (a url entry): 0
fresh seed-check-pinned     # an entry with a sha: its repo isn't checked
fresh seed-check-offline    # a source that can't be reached: 2, one line naming it
fresh seed-check-timeout    # a fake git that sleeps 30s: 2 within 15s
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement** the three functions; `seed_record_heads` runs from `stage_seed` right after a successful staging.
- [ ] **Step 4: Run the suite** → `ALL PASSED`.
- [ ] **Step 5: Commit** `plugins-in-image: record and check upstream heads`.

### Task 4: Your seed, approved with your config and built into your layer

**Files:**
- Modify: `core/lib/conf.sh` (`snapshot`, `conf_hash`)
- Modify: `core/lib/layer.sh` (`needs_layer`, `build_layer`, `approve_sources`, `choose_layer`; remove `sync_global_plugins`'s call)
- Modify: `core/lib/project.sh` (remove `sync_global_plugins`)
- Test: `tests/test_dev.sh` (replaces `global-sync` and `workflow-shipped`'s `box-plugins` lines)

**Interfaces:**
- Consumes: Task 2 and 3's functions.
- Produces: `seed_snapshot <dest>` in `seed.sh`, called at the end of `snapshot`: no seed lines → no `<dest>/seed`; else the approved seed copied when its `claude-box-lines` equal the lines and `seed_moved` says 1 (or 2, with its line); else `stage_seed <dest>/seed`, and on failure the approved seed copied with "Couldn't fetch the plugins: keeping the ones you approved", or no seed with "…: starting without them" when there's none. `conf_hash` adds `seed_digest <root>/seed` when it exists. `approve_sources` prints `seed_changes` after the `.dev` diff, under "Plugins:"; when the hashes match but the snapshot's `seed/claude-box-heads` differ from the approved copy's, it replaces the approved seed with the snapshot's without asking.

- [ ] **Step 1: Write the failing tests**

```bash
fresh seed-layer            # a marketplace line: staged, shown with the .dev change, one question, built in
conf 'plugin c4m@c4-model-skill cheriftj/c4-model-skill'
out=$(echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
[ "$(grep -c 'Apply it?' <<< "$out")" = 1 ] || fail "not one question: $out"
grep -qF '+ c4m@c4-model-skill 1.0' <<< "$out" || fail "plugin not shown: $out"
[ -f "$FAKE/ctx/seed/installed_plugins.json" ] || fail "seed not in the build context"
has 'COPY seed /usr/local/share/claude-box/seed'   # the logged Containerfile
has 'ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed'
grep -qF '"c4m@c4-model-skill": true' "$FAKE/ctx/claude-box-plugins.json" || fail "not switched on"
hasnt box-plugins                                   # nothing installed into ~/.claude

fresh seed-layer-no         # no: not built in, the box starts
fresh seed-moved            # upstream moved and the plugin changed: shown, rebuilt after yes
fresh seed-moved-same       # moved, same files: no question; the next start runs no staging box
fresh seed-moved-no-tty     # moved, no terminal: approved seed, one line, no question
fresh seed-not-moved        # nothing moved: no staging box (no CLAUDE_CODE_PLUGIN_CACHE_DIR in the log)
fresh seed-removed          # a removed line: restaged without it; its id gone from the drop-in
fresh seed-deps             # plugin workflow: superpowers in your seed and the drop-in
fresh seed-package-rebuild  # a dnf line added: the layer rebuilds with the approved seed, no staging box
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement.** `needs_layer` returns 0 for a `market` line. `build_layer` copies `<root>/seed` into the context as `seed/`, writes `claude-box-plugins.json` from `seed_enable_json`, and adds `COPY seed /usr/local/share/claude-box/seed`, `COPY claude-box-plugins.json /etc/claude-code/managed-settings.d/`, `ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed`, before its `chmod -R a+rX`.
- [ ] **Step 4: Run the suite** → `ALL PASSED`.
- [ ] **Step 5: Commit** `plugins-in-image: your seed, approved and built into your layer`.

### Task 5: A project's seed

**Files:**
- Modify: `core/lib/project.sh` (`project_sources`, `project_plugins_hash`, `build_project`, `dev_edit`; remove `sync_plugins` and `enabled_plugins`)
- Modify: `core/lib/box.sh:107`, `dev:151`, `dev:179` (drop the `sync_plugins` calls)
- Modify: `core/Containerfile` (drop the `box-plugins` line)
- Delete: `core/bin/box-plugins`
- Modify: `core/lib/project.sh:read_dev` (S7 branch, below)
- Test: `tests/test_dev.sh` (replaces `kinds-project-market`, `dev-old-lines-kept`, `plugins-*` at lines 1341–1400 and `plugins-bad-json`; `add-plugin` no longer expects the `.gitignore` line)

**Interfaces:**
- Consumes: `seed_snapshot` (through `approve_sources`, as Task 4), `seed_digest`, `seed_enable_json`.
- Produces: a project image with `/usr/local/share/claude-box/seed-project/`, `ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed-project:${CLAUDE_CODE_PLUGIN_SEED_DIR}`, and `claude-box-project-plugins.json`.

- [ ] **Step 1: Write the failing tests**

```bash
fresh seed-project          # a project's marketplace line: shown, approved, in its image first
fresh seed-project-other    # another project's image has no seed-project
fresh seed-project-level    # the same plugin id at both levels: refused (spec-kinds, unchanged)
fresh seed-project-market   # Task 1's S7 answer: same marketplace at both levels loads (accepted) or is refused naming the level
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement.** `project_sources` keeps marketplace lines (`NF == 3`). `project_plugins_hash` adds `seed_digest`. `build_project` copies the project's approved seed as `seed-project/` and writes its drop-in, inside the `src:` branch. `dev_edit` no longer adds `.claude/settings.local.json` to `.gitignore`. If Task 1 found S7 fails, `read_dev` refuses a marketplace line whose `@<market>` your approved config already uses: `.dev line N: "plugin <id>": ~/.claude/.dev uses marketplace <market> already (one level only)`.
- [ ] **Step 4: Run the suite** → `ALL PASSED`.
- [ ] **Step 5: Commit** `plugins-in-image: a project's seed`.

### Task 6: Move the old installs over

**Files:**
- Modify: `core/lib/seed.sh` (`seed_moveover`)
- Modify: `core/lib/layer.sh` (`choose_layer`: call `seed_moveover user` where `sync_global_plugins` was)
- Modify: `core/lib/mounts.sh:74` (after `choose_project_sources`: `seed_moveover local`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `seed_plugins`; `~/.claude/plugins/installed_plugins.json` (its `scope`, `projectPath`) and `known_marketplaces.json`.
- Produces: `seed_moveover <user|local>`: lists the installs at that scope (for `local`, `projectPath` is `/work/<folder>`) whose id is in the matching approved seed; on yes, runs in a box (`box` for user, `run_box` for local) `claude plugin uninstall <id> --scope <scope>` for each, then `claude plugin marketplace remove <m>` for each marketplace no other install in `installed_plugins.json` uses. No terminal, no installs, or a no: nothing, and asked again at the next start.

- [ ] **Step 1: Write the failing tests**

```bash
fresh seed-moveover         # a user install of c4m, now in your seed: offered, uninstalled, its marketplace removed
fresh seed-moveover-keep    # an install you made yourself (not in a seed): never offered
fresh seed-moveover-local   # a local install in this project: offered at its start; another project's isn't
fresh seed-moveover-shared  # a marketplace another install still uses: not removed
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement** `seed_moveover`.
- [ ] **Step 4: Run the suite** → `ALL PASSED`.
- [ ] **Step 5: Commit** `plugins-in-image: move the old installs over`.

### Task 7: The docs, the reference and the handoffs

**Files:**
- Modify: `core/defaults.dev` (the `plugin` rows: "built into the image" for every form; the marketplace row says Claude Code fetches it into a seed, shown and approved; checked at every `dev claude`)
- Modify: `dev` (help text, if it names user or local scope)
- Modify: `README.md` (How it hangs together: one sentence, plugins land in the box at their level, no session can change them)
- Modify: `docs/system/architecture/README.md` (Plugins table: one row per line, the same at both levels; Known limits: S11, and Task 1's `known_marketplaces.json` answer)
- Modify: `docs/system/architecture/03-deployment.md` (Your layer, A project's image, Plugins: the seed folders, the variable, the drop-ins; the old "recorded in settings.local.json" row goes)
- Modify: `docs/system/runbook.md` (Plugins: no `/plugin`; an update is shown at `dev claude`)
- Modify: each `out/handoff-<project>.md` of the projects that had a marketplace line (one message each: their marketplace lines now land in their image; at their next `dev claude` they're asked to remove the old local installs; nothing to edit)

- [ ] **Step 1: Edit the docs**; every link checked by `tests/check_links.py` in the suite.
- [ ] **Step 2: Run the suite** → `ALL PASSED` (links included; the README's table checks unchanged).
- [ ] **Step 3: Commit** `plugins-in-image: docs and reference`.
- [ ] **Step 4: Send the three handoffs** after the merge run, per core's handoff rule, and log each address.
