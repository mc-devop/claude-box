# Spec: marketplace plugins land in the image

For the [intent](intent.md), approved 2026-11-01. Approved by the owner
2026-11-01, after the [review](findings-spec-review.md). Today a `plugin` line
for a folder is copied into the image, where no session can change it,
while a marketplace `plugin` line is installed by Claude Code into your
`~/.claude/plugins/` (user scope) or with the project's
`.claude/settings.local.json` (local scope), where any box can change
it ([architecture](../../system/architecture/README.md#plugins)). This
spec makes the marketplace line land like the folder one, at both
levels.

**What this replaces:** from the simpler-model
[spec-kinds](../2026-10-31-simpler-model/spec-kinds.md), K3's row
"plugin from a marketplace: installed by Claude Code, at user scope
from the global file, at local scope from a project's", and K4's
"Marketplace lines are asked by name, as today". Every other decision
there stands.

**Deviation from the intent:** its first criterion says "nothing of it
under `~/.claude/plugins/`". A plugin's data folder stays there (S11),
so the acceptance checks "nothing of its code" and names this.

## What Claude Code provides

Read on 2026-11-01 in Claude Code's
[plugin loading](https://code.claude.com/docs/en/plugins/loading.md)
and [organization](https://code.claude.com/docs/en/plugins/org.md#seed-containers-and-ci)
docs:

- A **seed directory** is a plugins folder filled at build time
  (`CLAUDE_CODE_PLUGIN_CACHE_DIR=<seed> claude plugin marketplace add …`,
  then `claude plugin install …`) and named at runtime in
  `CLAUDE_CODE_PLUGIN_SEED_DIR`, several separated by `:`, the first
  that has a plugin winning. "Claude Code never writes to the seed and
  forces `autoUpdate` off for seed marketplaces"; a seed marketplace
  overwrites the user's entry of the same name at every start.
- Plugins in a seed aren't enabled on their own: `enabledPlugins` turns
  them on. In managed settings, `true` force-enables, and no other
  scope overrides it.
- `claude plugin install` installs a plugin's dependencies with it, and
  its Node.js packages (registry packages only, no install scripts).
- A plugin's data folder, `${CLAUDE_PLUGIN_DATA}`, is always
  `~/.claude/plugins/data/<id>/`, whatever loads the plugin.
- `installed_plugins.json` in the seed records each plugin's
  `version` and `gitCommitSha`; a marketplace clone sits in
  `marketplaces/<name>/` with its `marketplace.json`.

## Decisions

| # | Topic | Decision |
|---|---|---|
| S1 | Mechanism | A marketplace `plugin` line goes into that level's **seed**, built by Claude Code itself: `dev` never fetches or installs a plugin. Your lines go into your seed, a project's lines into the project's seed. A marketplace line now needs your layer (`needs_layer`) or the project's image, like a folder line |
| S2 | Staging | When a level's marketplace lines are added, changed or removed, or S4 finds a newer commit, `dev` starts a throwaway box from the base image with an empty staging folder mounted and runs, for every line of that level (staging always builds the whole seed fresh), `claude plugin marketplace add <owner/repo>` and `claude plugin install <name>@<marketplace>` with `CLAUDE_CODE_PLUGIN_CACHE_DIR` set to it. The box sees no `~/.claude` and no project; only the staging folder is written |
| S3 | Approval | `dev` shows, per plugin, its version and commit before and after (from both seeds' `installed_plugins.json`), then asks. A plugin whose files and version are unchanged isn't shown; when nothing shown is left (an unrelated commit in a busy marketplace), the new seed is taken without asking. When the staging comes from a `.dev` change, it runs before that change's question, and the one question shows both: one yes applies them. **Yes:** the staging seed replaces the approved one, kept at `~/.local/state/claude-box/seed/` (yours) or `~/.local/state/claude-box/projects/<folder>-<hash>/seed/` (a project's), out of every box's reach. **No, or no terminal:** the approved seed stays, and so does the line's previous state. A rebuild for any other reason uses the approved seed and fetches nothing |
| S4 | The check at every start | At every `dev claude`, for each approved seed, `dev` runs `git ls-remote https://github.com/<owner/repo>` on each marketplace repo (the line's `owner/repo`, always over HTTPS) and on each plugin's own repo where its entry in the approved seed's `marketplace.json` names one (`url`, `github`, `git-subdir`, with its `ref` when set); these repo and ref fields are all `dev` reads of a source. It compares with the commits the approved seed recorded. Nothing moved: no box, no question. Something moved: S2 and S3. An entry pinned to a `sha` moves only with its marketplace. The check runs on your machine with `git`, which every claude-box machine has; a failed check (offline, a repo gone) starts with the approved seed and says so in one line; a removed line then waits for a start with network. Every applied update rebuilds your layer, and with it each project image at its next start: the cost of checking at every start, which the owner chose |
| S5 | Into the image | Your layer copies your approved seed to `/usr/local/share/claude-box/seed/`, a project's image copies its own to `/usr/local/share/claude-box/seed-project/`, both owned by root. `CLAUDE_CODE_PLUGIN_SEED_DIR` names the project's seed first, then yours. Each image adds a managed-settings drop-in (`/etc/claude-code/managed-settings.d/claude-box-plugins.json`, and `claude-box-project-plugins.json` for a project) with `enabledPlugins` set to `true` for that level's plugins. The seed's hash goes into the image's label, so the existing rebuild rule rebuilds when the approved seed changes |
| S6 | Dependencies | A folder plugin's dependencies (`plugin_deps`, superpowers for workflow) go into the same level's seed, staged and approved with it. A marketplace plugin's own dependencies come with `claude plugin install` and are switched on with it |
| S7 | A name at one level | Unchanged: a plugin named at both levels is refused (spec-kinds). **To check first** (the plan's first task, in a real box): a marketplace in both seeds, with a different plugin from it at each level, loads both plugins. If it doesn't, a marketplace may be named at one level only, refused like a plugin |
| S8 | What goes | `core/bin/box-plugins`; installing at user and local scope; `dev` reading the project's `.claude/settings.local.json`; the global plugin sync in `core/lib/layer.sh` |
| S9 | Moving over | At your first `dev claude` on this version, `dev` lists the user-scope installs whose plugin is now in your seed and offers to remove them (`claude plugin uninstall --scope user`, in a box with `~/.claude` mounted as today), which also drops them from `settings.json`, and removes the marketplaces no remaining install uses (`claude plugin marketplace remove`). A project's local-scope installs are offered the same way at that project's next `dev claude`. Nothing else under `~/.claude/plugins/` is touched; old copies go with Claude Code's own cleanup. No project `.dev` changes; the other projects get a handoff saying what changes for them |
| S10 | Failure | A staging that fails (a plugin or marketplace gone, no network, an install error) keeps the approved seed, prints the failing step's last lines, and the start goes on. A line with no approved seed yet starts without that plugin and says so |
| S11 | Known limit | `~/.claude/plugins/data/` stays writable from every box, as Claude Code places it. It holds a plugin's state, not its code. Recorded in the architecture's known limits. **To check first**, with S7: whether Claude Code writes the seed's marketplaces into your `~/.claude/plugins/known_marketplaces.json` at start; if it does, that is a known limit too (a native Claude Code on your laptop would find paths it lacks) |

## Deliverables

One branch, `claude/plugins-in-image`, from the current `main`.

- `core/lib/seed.sh` (new): staging (S2), approval (S3), the check (S4),
  each a function with one purpose. `core/lib/layer.sh` and
  `core/lib/project.sh`: copy the approved seed and write the drop-in
  (S5), dependencies into the seed (S6), the move-over offer (S9), and
  remove what S8 names. `core/Containerfile`: the
  `managed-settings.d/` folder.
- `core/defaults.dev` and `dev`'s help: one row for `plugin`, the same
  for both forms: "built into the image".
- Tests in `tests/test_dev.sh`, with `claude`, `podman` and `git`
  stubbed as the suite does today:
  - a new marketplace line staged and shown with the `.dev` change in
    one question; on no, left out;
  - upstream moved: shown and applied after yes; moved with no change
    to the plugin: taken without asking; not moved: no box started;
  - offline: starts with the approved seed and one line;
  - a removed line restages without it;
  - a folder plugin's dependency lands in the same seed;
  - a project's seed comes first in `CLAUDE_CODE_PLUGIN_SEED_DIR` and
    its drop-in names only its plugins;
  - the move-over offers only installs whose plugin is in a seed.
- Docs on the same branch: the README's
  [How it hangs together](../../../README.md#how-it-hangs-together),
  the architecture's [Plugins](../../system/architecture/README.md#plugins)
  table (one row per line) and known limits,
  [deployment](../../system/architecture/03-deployment.md) (your layer,
  a project's image, plugins), and the runbook's plugin steps.

## Acceptance

The intent's [criteria](intent.md#acceptance-criteria), checked by:

- the suite (`tests/run.sh`) passing;
- in a real box after `dev build`: `claude -p --output-format
  stream-json --verbose` lists superpowers, c4m and modularity with a
  `path` under `/usr/local/share/claude-box/seed/`; writing a file
  there as Claude fails; `~/.claude/settings.json` has no
  `enabledPlugins` entry for them; nothing of their code under
  `~/.claude/plugins/` is used (the data folder is the named deviation);
- one project with a marketplace line in its `.dev`, the same check
  under `seed-project/`;
- the move-over run on your laptop, read from `dev run`'s log.

## Acceptance results (2026-11-02, first run)

Not met: sessions don't load the marketplace plugins from the seed. Run
in claude-box's own box on the image of `main` 00f216d; evidence in
[acceptance-2026-11-02.txt](acceptance-2026-11-02.txt). The fix is the
[plugins-dir spec](spec-plugins-dir.md); the acceptance runs again
after it.

| Criterion | Result | Evidence |
|---|---|---|
| Lands like a folder plugin, a session can't change it | Not met | The seed is in the image, owned by root, writing into it fails, and the managed drop-in switches the three plugins on. But a session loads all three from `~/.claude/plugins/cache/`: `~/.claude/plugins/installed_plugins.json` holds a record per plugin, rewritten by Claude Code from the old user-scope installs as `scope: "managed"` (2026-11-01 16:21), and a recorded install wins over the seed: the debug log never says "Using seed cache". A box can write that file and the cache, so a session can change what every box loads |
| The commit you approved | Not met | superpowers runs as 6.4.2, the September copy; the approved seed holds 7.0.1 |
| Dependencies the same way | Not met | Same cause: superpowers, workflow's dependency, is the 6.4.2 copy |
| Your setup moves over | Not met | S9's move-over offers only `scope: "user"` records, so it found nothing to remove; the three projects' one-line replies (2026-11-01) checked the seed variable only |
| The docs, one row per line | Met | [core/defaults.dev](../../../core/defaults.dev), the README and the architecture's [Plugins](../../system/architecture/03-deployment.md#plugins) |
| A project's seed | Not run | No project's `.dev` has a marketplace line |
| The suite | Met, after a fix | `tests/run.sh` failed on `main` at one link (the instructions-review record linked a file its branch deleted); passes with `claude/fix-starter-link` |

Why the [seed checks](findings-seed-checks.md) missed it: they started
from an empty config folder, where no install record exists.

## Acceptance results (2026-11-03, second run)

After the fix ([spec-plugins-dir](spec-plugins-dir.md), merged 7ff6d22,
with `claude/python-isolated` from its review); evidence in
[acceptance-2026-11-03.txt](acceptance-2026-11-03.txt), the real-box
checks in [findings-plugins-dir-checks.md](findings-plugins-dir-checks.md)
and the review in [findings-review-plugins-dir.md](findings-review-plugins-dir.md).

| Criterion | Result | Evidence |
|---|---|---|
| Lands like a folder plugin, a session can't change it | Met | c4m, modularity and superpowers load from `/usr/local/share/claude-box/seed/cache/` in claude-box's box and in the three projects' (their replies); each box's `~/.claude/plugins` is its own (a marker written in one isn't in yours) |
| The commit you approved | Met | superpowers 7.0.2, the approved seed's version (the start-up check found it and the owner said yes). one project's 7.0.1 came from a box started before the merge |
| Dependencies the same way | Met | superpowers, workflow's dependency, from the seed |
| Your setup moves over | Met, after a second clear-up | The first clear-up ran while boxes from before the merge were still running; they wrote two records and three marketplaces back. With them ended, the second left none: no record, only `claude-plugins-official` (not ours), no `enabledPlugins` |
| The docs, one row per line | Met | As in the first run, plus the box's own plugins folder in [deployment](../../system/architecture/03-deployment.md#plugins) |
| A project's seed | Not run | No project has a marketplace line; the owner moves it later (the [backlog](../../direction/backlog.md)) |
| The suite | Met | `tests/run.sh` ALL PASSED at 7ff6d22 |

**Found in this run:** a new box's first interactive session asks for
`/reload-plugins`: its empty plugins folder has no marketplace
registered, so the seed's plugins are skipped until Claude Code has
registered them (`claude -p` waits, an interactive session doesn't).
The fix is [spec-plugins-registration](spec-plugins-registration.md).

## Acceptance results (2026-11-04, the first session's reload)

After [spec-plugins-registration](spec-plugins-registration.md) (P5,
merged 1e8cf54), checked before building in a throwaway box
([findings](findings-registration-check.md), [log](registration-check.log))
and after the merge and a `dev build` in the owner's terminal.

| Criterion | Result | Evidence |
|---|---|---|
| A new box's first session doesn't ask for `/reload-plugins` | Met | The owner, 2026-11-04: after `dev build` and a restart, the first session didn't ask; its plugins folder held the image's `known_marketplaces.json` (the three seed marketplaces at `/usr/local/share/claude-box/seed/marketplaces/`), and c4m, modularity and superpowers were loaded at start |
| The suite | Met | `tests/run.sh` ALL PASSED at 3f2e328 (246 in test_dev) |

**Deviation:** none from P5. Found while building: `dev` rebuilds an
image for a change of config or base, not of its own code, so images
from before the merge got the file only at `dev build`
([findings](findings-registration-check.md)).

**Version check:** the base is `fedora:44`; Fedora 45 is released, its
switch is a [backlog](../../direction/backlog.md) item. Claude Code
2.1.318 (installed by `dev build`, unpinned); the seed's plugins are the
approved commits (superpowers 7.0.2, c4m 2.0.0, modularity 1.5.0).

**What's left of the intent:** a project's seed, not run (no project
has a marketplace line): its own [backlog](../../direction/backlog.md)
item. Every other criterion is met over the three runs.
