# Findings: the README alone (2026-10-31)

For the spec's acceptance row *From the README alone*
([spec](spec.md#acceptance)), [plan](plan-readme.md) Task 4. A fresh
subagent read only `README.md`'s text (commit ba169d5 plus the `out/`
row's rewording) and answered: which file do you edit, what is each
top-level item for, what are the layers and packs, where do you learn
how it works.

## Verdict

| Question | Its answer | Right? |
|---|---|---|
| The file to edit | `local/claude-box.conf`, not in git, written by `dev init`; every kind explained in `box/defaults.conf` | Yes |
| `README.md`, `LICENSE`, `dev` | This file; MIT; the one command, `./dev install` links it into `~/.local/bin` | Yes |
| `local/` | Your config and the files it names, not in git | Yes |
| `packs/` | Optional rule and skill bundles, one folder per pack | Yes |
| `box/` | Containerfile, `defaults.conf`, the box's own rules and plugin, helper scripts, dev's modules | Yes |
| `docs/` | Direction, change records, system docs (runbook, architecture) | Yes |
| `tests/` | The checks, `tests/run.sh` | Yes |
| `out/` | Not in git; what Claude hands you, e.g. `dev run`'s steps | Yes |
| `.gitignore` | Keeps `local/` and `out/` out of git | Yes |
| Layers, packs | company, global, project as the README lists them; a pack switched on by `pack <name>`, its project part also needing the project's `.dev` line | Yes |
| How it works | The architecture (its rules and packs sections); the runbook for steps | Yes |

## Where it was unsure, and what changed

| Doubt | Change |
|---|---|
| Is `box/defaults.conf` the fallback? | README: "Without it, `dev` uses `box/defaults.conf`'s lines" |
| "caps" unexplained | "memory and CPU caps" |
| Does `dev` propose edits, or confirm mine? Is `dev build` needed after a pack line? | "When you change yours, the next `dev claude` shows the change and applies it only after you say yes, with no `dev build`" |
| Is `out/` a repo item? | "made once Claude hands you something" |
| Which folder holds "your other projects"? | "(`~/Projects`)" in the opening |
| `company` against `global` lines in practice; `dev init` offering plugins before you have a config; the `--continue` line's wording; whether this repo has a `.dev` | Left: the first is the [architecture's](../../system/architecture/README.md#levels) table, the others don't stop a newcomer from setting up |
