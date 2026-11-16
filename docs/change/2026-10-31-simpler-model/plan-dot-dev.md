# Dot-dev Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Your config is `~/.claude/.dev`, in the same words as a
project's `.dev`. One `use` line brings in a plugin, a skill or a rules
file, and the workflow is an ordinary plugin.

**Architecture:** `dev` still snapshots your config and every file it
names, shows the diff against the copy you approved last, and builds
your layer from the approved copy. What changes is the file (`~/.claude/.dev`
in place of `local/claude-box.conf`), where the named files may come from
(the clone's `plugins/`, `~/.claude/`, your projects folder, a pinned URL),
and where each one lands (D5). The snapshot keeps its sources under fixed
keys, so everything after it reads only the snapshot or the approved copy,
as today.

**Tech Stack:** bash (`dev`, `core/lib/*.sh`), python3 (JSON), the fake
Podman in `tests/test_dev.sh`.

**Spec:** [spec.md](spec.md), deliverable 2: D2–D7, D14 (`local/` goes,
`private-terms` moves, `defaults.dev`), and D16's old-config refusal.

## Decisions this plan adds (for the owner's review)

These refine the spec where it leaves the how open. Each one is named
as a deviation at acceptance if it changes what the spec says.

| # | Decision | Why |
|---|---|---|
| P1 | **A project's `use` takes only marketplace plugins** (`use <name>@<market> <owner/repo>`, which replaces `.dev`'s `plugin`). A project's own rules and skills go where Claude Code already looks: its `.claude/rules/` and `.claude/skills/` | Nothing new to build, and a clone plugin per project is the per-project pack switch the spec removed. **Deviates from D5**, which built project `use` into that project's image |
| P2 | **`dev` installs a used plugin's dependencies itself.** `plugin.json`'s standard `dependencies`, plus the marketplace repos in its free-form `metadata.claude-box.marketplaces`, become marketplace `use` items at the same level. A dependency with no repo there is named in a warning, with the line to add | Doesn't depend on whether Claude Code resolves dependencies for a plugin loaded from a folder (D7's open check) |
| P3 | **A URL's content lives in the approved copy.** At the snapshot `dev` fetches the URL into it (or reuses the approved copy's file while the URL is unchanged, since a commit-pinned URL can't change), so the diff shows the rules' text and the build never downloads | Simpler than recording a sha256: the approved file *is* the pin |
| P4 | **Global marketplace plugins are only added, never removed.** A global `use` line that's missing from `~/.claude/settings.json`'s `enabledPlugins` is installed at user scope after your yes; a line taken out is left installed, and `dev` says so | `settings.json` also holds plugins you enabled yourself |
| P5 | **The workflow's moves are this branch's first commit, renames only.** The code can't read the plugin layout without the rest of this branch, so a moves-only branch would leave `main` broken. A commit of pure `git mv` still lets history follow each file | Keeps the reason behind "a restructure gets its own branch" (history) without a broken `main`. **Deviates from the change rules**, so the owner OKs it with this plan |
| P6 | `/etc/claude-code/local.md` stays, holding only its comment line, until branch 3 rewrites the rules | Touching the image's rules belongs to branch 3 |

## Global Constraints

- The config is `~/.claude/.dev`; without it, `dev` uses `core/defaults.dev`.
- A local `use` path is under `~/.claude/` or your projects folder,
  resolved (links included) inside that folder, characters
  `A-Za-z0-9._/-` after the `~/` or projects prefix, no `.` or `..`
  segment (B1).
- Names: plugin names from the folder's basename, unique, never
  `box-workflow` or `use`; rules files unique by basename.
- A URL is `https://` with a 7–40 hex commit segment, ending in `.md`.
- Gone kinds in `~/.claude/.dev` (`company`, `global`, `pack`, `plugin`,
  `rules`, `plugin-dir`): refused with the line that replaces them. In a
  project's `.dev`, `plugin` and `pack` are skipped with a one-line
  notice on stderr (B3).
- An existing `local/claude-box.conf` makes `dev` refuse:
  `Your config moved to ~/.claude/.dev (every kind: core/defaults.dev); move local/claude-box.conf aside.`
- `tests/run.sh` passes before every commit.

## Review Focus

- **A link in `~/.claude/` pointing out of it** (`~/.claude/x.md ->
  ~/.ssh/id_ed25519`): refused, exactly as `clone_path` refuses one out
  of `local/` today. Task 2 tests it.
- **`~/.claude/.dev` itself a link**: refused (`mount_point`'s rule).
  Task 1 tests it.
- **An approved copy from before this branch** (it holds
  `local/claude-box.conf`): counts as none, so `dev` shows the whole new
  config and asks (the existing rule). Task 2 tests it.
- **Two plugins with one name** (`plugins/x` and `~/.claude/x/`), or a
  plugin named `use`: refused. Task 1 tests it.
- **The URL can't be fetched at the snapshot**: `dev` says which URL, and
  starts on the approved copy (the existing fallback). Task 2 tests it.

---

### Task 1: The workflow becomes a plugin (moves, then the manifest)

**Files:**
- Move (first commit, `git mv` only):
  `packs/workflow/company/plugin/.claude-plugin/` → `plugins/workflow/.claude-plugin/`,
  `packs/workflow/company/plugin/skills/` → `plugins/workflow/skills/`,
  `packs/workflow/company/*.md` and `packs/workflow/global/*.md` and
  `packs/workflow/project/rules/starter.md` → `plugins/workflow/rules/`,
  `packs/workflow/project/starter/` → `plugins/workflow/starter/`,
  `core/defaults.conf` → `core/defaults.dev`
- Modify (second commit): `plugins/workflow/.claude-plugin/plugin.json`

- [ ] **Step 1:** Make the moves, then run
  `git commit -m "Moves: packs/workflow becomes plugins/workflow, defaults.dev"`
  with nothing else staged. `tests/run.sh` is expected to fail at this
  commit (P5); it's the one exception, and it's ledgered.
- [ ] **Step 2:** In `plugin.json` add
  `"dependencies": ["superpowers@superpowers-marketplace"]` and
  `"metadata": {"claude-box": {"marketplaces": {"superpowers-marketplace": "obra/superpowers-marketplace"}}}`.
- [ ] **Step 3: Check** `claude plugin validate plugins/workflow`.
  Expected: `Validation passed` (warnings allowed).

Tasks 2–6 bring the code to this layout. Commit at the end of Task 2,
once the suite passes again.

### Task 2: `~/.claude/.dev`, its kinds, `use`, the snapshot

**Files:** `core/lib/conf.sh`, `core/lib/layer.sh` (`choose_layer` only),
`dev` (`init`'s starter), `tests/test_dev.sh`

**Interfaces:**
- Produces:
  - `CONF_FILE` = `$HOME/.claude/.dev`.
  - `conf_file`: prints `CONF_FILE` if it exists, else `$HERE/core/defaults.dev`.
  - `use_ok <value> <names>`: succeeds for a valid `use` value and
    prints its form, one of `clone`, `home`, `projects`, `url`, `market`.
  - `use_key <value>`: the path of its source inside a snapshot:
    `plugins/<name>`, `home/<path under ~>`, `projects/<path under the projects folder>`,
    `urls/<basename>`. Nothing for `market`.
  - `in_root <path> <root> f|d`: today's `clone_path` checks, for any
    root (`$HERE/plugins`, `$HOME/.claude`, `$PROJECTS`).
  - `read_conf <file> [root]`: items as today, for the kinds in D3. In a
    snapshot or approved root, `use` sources are read at `<root>/<use_key>`.
  - `snapshot <dest>`: writes `<dest>/.dev` and every source at its key.
    A URL comes from `$APPROVED/urls/` when the approved `.dev` has the
    same URL, else `curl -fsSL`.
  - `approved_ok`: `$APPROVED/.dev` reads.
  - `plugin_kind <dir>`: `plugin` (has `.claude-plugin/plugin.json`, or
    `skills/`, `commands/`, `agents/` or `hooks/hooks.json`) or `skill`
    (`SKILL.md` at its root); fails otherwise.

- [ ] **Step 1: Write the failing tests** in `tests/test_dev.sh`. Replace
  `conf()` with one that writes `$HOME/.claude/.dev`; `fresh()` copies
  `$REPO/plugins` into `$CLONE/plugins` instead of `packs`. New cases:
  - `dot-dev-old-conf`: a `$CLONE/local/claude-box.conf` → `dev shell`
    exits non-zero; output has `Your config moved to ~/.claude/.dev`.
  - `dot-dev-link`: `~/.claude/.dev` a link → refused, `is a link`.
  - `dot-dev-gone-kinds`: each of `company local/x.md`, `global x.md`,
    `pack workflow`, `plugin init a/b c@d x` → refused; output names `use`.
  - `use-forms`: `use workflow`, `use ~/.claude/my-plugin` (a folder with
    `.claude-plugin/plugin.json`), `use ~/.claude/skill-x` (a folder with
    `SKILL.md`), `use ~/.claude/r.md`,
    `use https://example.org/a/0123abc/r2.md`, and
    `use c4m@c4-model-skill cheriftj/c4-model-skill` → all accepted,
    approved with `y`.
  - `use-bounds`: `use ~/key` (outside `~/.claude/`), `use ~/.claude/l.md`
    as a link to `~/key`, `use /etc/passwd`, `use ~/.claude/../key`,
    `use plugins/../core` → each refused.
  - `use-names`: `use workflow` with `use ~/.claude/workflow/` → refused
    (two named workflow); a plugin folder named `use` → refused.
  - `use-url-pin`: approve a URL with `FAKE_CURL_BODY=One.`; then
    `FAKE_CURL_STATUS=22` and an unchanged `.dev` → starts, nothing
    asked, and `approved/urls/r2.md` holds `One.`. A changed URL with
    curl failing → says `Couldn't fetch <url>` and starts on the
    approved copy.
  - `use-old-approved`: an approved copy holding only
    `local/claude-box.conf` → the whole `.dev` is shown and asked.
  - `npm-pip-global`: `npm cowsay`, `pip pyfiglet` in `~/.claude/.dev` → accepted.
  - `project-kind-global`: `port 80` in `~/.claude/.dev` → refused,
    `project only`.
- [ ] **Step 2: Run** `bash tests/test_dev.sh`. Expected: FAIL at the
  first new case.
- [ ] **Step 3: Implement** the interfaces above in `core/lib/conf.sh`,
  and in `choose_layer` read `CONF_FILE`, not `local/`. `dev init` writes
  `~/.claude/.dev`, when it's missing, with three lines: a first-line
  comment pointing to `core/defaults.dev`, `use workflow`, and
  `autotake group`.
- [ ] **Step 4: Run** `bash tests/test_dev.sh`. Expected: the new cases
  pass. Rewrite the old cases that wrote `local/` or `packs/` to the new
  forms; delete the ones whose behaviour is gone (`conf-top-link`'s
  `packs/` half, the `pack_ok` names) and list them in the ledger.
- [ ] **Step 5: Commit** `dot-dev: ~/.claude/.dev, use, the snapshot`.

### Task 3: Your layer from `use`

**Files:** `core/lib/layer.sh`, `tests/test_dev.sh`

**Interfaces:**
- Consumes: `read_conf`, `use_ok`, `use_key`, `plugin_kind` (Task 2).
- Produces: `needs_layer <items>` is true for `identity`, `dnf`, `npm`,
  `pip`, or a `use` of form `clone`, `home` or `projects` that's a plugin.
  `plugin_deps <dir>` prints `use <name>@<market> <owner/repo>` per
  resolvable dependency (P2), and on stderr names any unresolvable one.

- [ ] **Step 1: Failing tests:**
  - `layer-plugin`: `use workflow` → the layer's Containerfile has
    `COPY plugins/workflow /usr/local/share/claude-box/plugins/workflow`,
    and `CLAUDE_CODE_PLUGIN_DIRS` ends with `:/usr/local/share/claude-box/plugins/workflow`.
  - `layer-skill`: `use ~/.claude/skill-x` → `COPY plugins/skill-x …`.
  - `layer-no-rules`: `use ~/.claude/r.md` → no `/etc/claude-code/local/`
    line in the Containerfile.
  - `layer-npm-pip`: `npm cowsay`, `pip pyfiglet` → `RUN npm install -g 'cowsay'`
    and `RUN pip install 'pyfiglet'` (and `dnf` of `npm`, `python3-pip`).
  - `plugin-deps`: `use workflow` → `box-plugins user superpowers-marketplace`
    is run with `obra/superpowers-marketplace superpowers@superpowers-marketplace`
    (Task 5's sync); a dependency without a repo → the warning names
    `use <dep> <owner/repo>`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `build_layer` for `use` (the plugin folder is
  copied from `<root>/<use_key>` under its name), npm and pip as in
  `build_project`, no `local.md` lines. Add `plugin_deps`.
- [ ] **Step 4: Run** → PASS. **Commit** `dot-dev: your layer from use`.

### Task 4: Mounts from `use`

**Files:** `core/lib/mounts.sh`, `tests/test_dev.sh`

- [ ] **Step 1: Failing tests:**
  - `mount-plugin-rules`: `use workflow` →
    `$APPROVED/plugins/workflow/rules:/home/claude/.claude/rules/workflow:ro,z`.
  - `mount-rules-file`: `use ~/.claude/r.md` →
    `$APPROVED/home/.claude/r.md:/home/claude/.claude/rules/use/r.md:ro,z`;
    a URL's file → `…/approved/urls/r2.md:/home/claude/.claude/rules/use/r2.md:ro,z`.
  - `mount-no-project-packs`: a project `.dev` with `pack workflow` → no
    `-project:` mount, and stderr has the skipped-line notice.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `choose_mounts` for `use`; drop the global and
  pack branches and the project-pack mounts.
- [ ] **Step 4: Run** → PASS. **Commit** `dot-dev: mounts from use`.

### Task 5: Marketplace plugins, `.dev`, `dev add use`, `dev new`

**Files:** `core/lib/project.sh`, `dev`, `tests/test_dev.sh`

**Interfaces:**
- Produces:
  - `sync_global_plugins`: installs (user scope, `box -- box-plugins user …`)
    each global marketplace `use` and each `plugin_deps` item missing from
    `~/.claude/settings.json`'s `enabledPlugins`, after `ask "Install them?"`;
    never uninstalls (P4). Called from `choose_layer` after approval.
  - `read_dev`: kinds `dnf npm pip use port group`; `use` only as
    `<name>@<market> <owner/repo>` (P1); `plugin` and `pack` print
    nothing and warn once: `.dev line N: "<kind> …" is no longer read: use "use <name>@<market> <owner/repo>" (core/defaults.dev)`.
  - `sync_plugins` reads `use` items where it read `plugin` items.
  - `dev_edit` kinds `dnf npm pip use port group`.
  - `lay_starters`: for each used plugin of the approved config with a
    `starter/`, as today; writes no `.dev` lines.
- [ ] **Step 1: Failing tests:**
  - `global-sync`: `use c4m@c4-model-skill cheriftj/c4-model-skill`, no
    `settings.json` → `box-plugins user cheriftj/c4-model-skill c4m@c4-model-skill`
    is run after `y`; with `enabledPlugins` holding `c4m@c4-model-skill: true`
    → not run.
  - `global-sync-no-remove`: `settings.json` enables `x@y`, `.dev` doesn't
    name it → no uninstall.
  - `dev-use`: a project `.dev` with
    `use c4m@c4-model-skill cheriftj/c4-model-skill` → sync asks and runs
    `box-plugins local …` as `plugin` lines do today; `use workflow` in a
    project `.dev` → refused, naming `~/.claude/.dev`.
  - `dev-add-use`: `dev add use c4m@c4-model-skill cheriftj/c4-model-skill`
    writes that line; `dev add plugin x` → `Usage:` naming `use`.
  - `dev-plugins-gone`: `dev plugins` → exits non-zero, names `use` and `.dev`.
  - `new-starters`: `use workflow` approved → `dev new q` lays down the
    starter (`tests/check_links.py` exists) and the new `.dev` has no
    `pack` line.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** `dev plugins` dies with
  `dev plugins is gone: add "use <name>@<market> <owner/repo>" to ~/.claude/.dev (every project) or the project's .dev`.
  `dev init` and `dev new` no longer call `install_plugins`; remove
  `choose_plugins`, `install_plugins`, `pack_ok` and `clone_path`,
  which nothing calls any more.
- [ ] **Step 4: Run** → PASS. **Commit** `dot-dev: marketplace plugins, .dev's use, dev new`.

### Task 6: `defaults.dev`, `private-terms`, docs

**Files:** `core/defaults.dev`, `plugins/workflow/rules/starter.md` (the
starter's path), `tests/check_private_terms.py`, `.gitignore`,
`tests/run.sh` (ShellCheck's starter path), `README.md`,
`docs/system/architecture/README.md`, `03-deployment.md`,
`docs/system/runbook.md`

- [ ] **Step 1:** Rewrite `core/defaults.dev`. It's the reference: every
  kind in D3 with an example, grouped as *both levels*, *global only*
  and *project only*; the four `use` forms and where each lands (D5,
  P1); the default lines `projects ~/Projects` and `remote-control on`.
  The test that checks each kind is explained reads `defaults.dev`.
- [ ] **Step 2:** `starter.md` names
  `/usr/local/share/claude-box/plugins/workflow/starter/`.
  `check_private_terms.py` reads `tests/private-terms`. `.gitignore`
  holds `out/` and `tests/private-terms` (`local/` is gone).
- [ ] **Step 3:** Docs, where they describe what changed. README: *Your
  config* is `~/.claude/.dev`, with the `use` line, and the *Packs*
  wording becomes plugins. Architecture: the Rules table's rows and the
  Packs section become plugins and `use`. Deployment: the mounts table
  and *Your layer*. Runbook: setting up your config. The full
  rewrite of the levels and the model belongs to branch 4 (D15).
- [ ] **Step 4: Run** `tests/run.sh`. Expected: `ALL PASSED`, and
  `git grep -nE 'local/claude-box\.conf|packs/' -- ':!docs/change'`
  prints only the refusal message and its test.
- [ ] **Step 5: Commit** `dot-dev: defaults.dev, private-terms, docs`.

## After the branch

1. A fresh reviewer on the most capable model reads the whole branch,
   and its Critical and Important findings are fixed.
2. Before the merge run (D16): Claude writes the owner's
   `~/.claude/.dev` from `local/claude-box.conf`. modularity and c4m
   become global `use` lines, and Karpathy's rules become
   `use https://raw.githubusercontent.com/…/CLAUDE.md`. The diff goes into
   the summary for the owner.
3. The merge run: merge, push; move `local/claude-box.conf` to
   `out/done/<date>/` and `local/private-terms` to `tests/private-terms`;
   remove the empty `local/`.
4. Then the owner runs `dev claude`, which shows the new config and asks.
5. Handoffs to the other projects: `plugin` and `pack` lines are skipped
   now; delete them, since modularity and c4m are global.
