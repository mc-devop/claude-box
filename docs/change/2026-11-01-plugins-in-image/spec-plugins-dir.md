# Spec: each box gets its own plugins folder

For the [intent](intent.md), after the first acceptance run failed
([results](spec.md#acceptance-results-2026-11-02-first-run)). Direction
given by the owner 2026-11-02 ("alright … orchestrate it"); approved by
the owner 2026-11-03 ("Yeah write the plan").

**The cause:** every box mounts your whole `~/.claude`, so Claude Code
in the box reads and writes your `~/.claude/plugins/`. An install
record there (`installed_plugins.json`, with its copy in `cache/`) wins
over the seed, and any box can write one. Claude Code's docs don't say
which wins (read 2026-11-02 in [org.md](https://code.claude.com/docs/en/plugins/org.md#seed-containers-and-ci)
and [loading.md](https://code.claude.com/docs/en/plugins/loading.md#find-plugins-on-disk));
the session's debug log shows it.

**What this replaces:** from the [spec](spec.md), S9 (moving over, by
`claude plugin uninstall` in a box) and S11's second check (the seeds'
marketplaces written into your `known_marketplaces.json`, a known
limit). Every other decision there stands.

## Decisions

| # | Topic | Decision |
|---|---|---|
| P1 | The box's plugins folder | Every box `dev` starts with your `~/.claude` (sessions, shells, the shared box) mounts an empty tmpfs over `/home/claude/.claude/plugins`, owned by Claude's user. What Claude Code writes there at start (install records, marketplaces, its cache) lives and dies with the box. The seeds are the only plugins a box finds besides the image's folder plugins |
| P2 | What stays yours | `~/.claude/plugins/data/` (a plugin's state, `${CLAUDE_PLUGIN_DATA}`) and `~/.claude/plugins/store/` (a mod's [key-value store](https://code.claude.com/docs/en/plugins/mods/interface.md#keep-state)) are mounted from your `~/.claude` into that tmpfs, created first when missing. S11's first known limit stands, widened to `store/` |
| P3 | Clearing what's left | At `dev claude`, `dev` itself (on your machine, no box) lists what earlier claude-box versions left in `~/.claude/plugins/`: install records, at any scope, of a plugin in your approved seed or this project's; the `cache/` folders only those records used; the marketplaces left with no record, in `known_marketplaces.json` and `marketplaces/`; and every `known_marketplaces.json` entry whose path is under `/usr/local/share/claude-box/`. On yes it removes exactly those and the `enabledPlugins` entries for those plugins in `~/.claude/settings.json`. No terminal or no: nothing removed, offered again at the next start. Nothing else under `~/.claude/plugins/` is touched |
| P4 | What goes | `seed_moveover` and its uninstall box (S9) |

## Deliverables

On `claude/plugins-dir`, from the current `main`:

- `core/lib/box.sh`: P1 and P2 in `box`.
- `core/lib/seed.sh`: P3 replaces `seed_moveover`; `core/lib/layer.sh`
  and `core/lib/project.sh` call it.
- Tests in `tests/test_dev.sh`: a box's `podman run` has the tmpfs and
  the two mounts, and `data/` and `store/` exist after; P3 lists and
  removes only what it names (a record of a plugin in no seed, another
  marketplace, `data/` and `store/` stay), without a terminal removes
  nothing, and finds nothing on a second start.
- Docs: the architecture's known limits (S11's second item goes, the
  first names `store/`), [deployment](../../system/architecture/03-deployment.md)
  (the box's mounts, Plugins' "Moving over" row), the runbook if it
  names the move-over.

## Acceptance

The intent's [criteria](intent.md#acceptance-criteria), checked by the
spec's [acceptance](spec.md#acceptance) again, plus:

- the session start's debug log says "Using seed cache" for each of the
  three plugins, superpowers at the approved version;
- a file written to `~/.claude/plugins/` in one box is gone in the
  next, and isn't in your `~/.claude/plugins/`;
- P3 run on your laptop at `dev claude`: what it listed, and
  `~/.claude/plugins/` after, read by a `dev run` step;
- the three other projects each check one box (a one-line handoff).
