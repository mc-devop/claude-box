# Spec: a new user sees one file to edit and a repo they can read

For the [intent](intent.md). Design agreed with the owner section by
section, 2026-10-30; the review's fixes (what breaks, what's overkill,
what's missing) applied the same day, twice; approved by the owner
2026-10-30.

## Evidence (2026-10-30, read from the code, this box and Claude Code's docs)

| # | Point | Finding |
|---|---|---|
| E1 | What a user edits today | `dev` reads one config, `local/claude-box.conf`, or the defaults in `config/claude-box.conf` without it. Its `rules` and `plugin-dir` lines name paths under `local/` or `packs/` only (`clone_path`) |
| E2 | Approval | `dev` copies the config and every file it names into a snapshot, shows the change as a diff and keeps the snapshot under `~/.local/state/claude-box/approved/` after your yes; only approved files reach a box |
| E3 | The layers | Claude Code loads, in order, managed policy (`/etc/claude-code/`), user (`~/.claude/CLAUDE.md`, `~/.claude/rules/`), project (`CLAUDE.md`, `.claude/rules/`); all are concatenated, none overrides another (code.claude.com/docs/en/memory). The owner's names: company, global, project |
| E4 | User rules | "Personal rules in `~/.claude/rules/` apply to every project on your machine." Whether subfolders are read is not documented for that folder (it is for project rules) |
| E5 | Mount points | A bind mount inside the mounted `~/.claude` makes Podman create the mount point in your laptop's `~/.claude` (expected; checked in branch 3's first task) |
| E6 | Items at the top level | 13: `Containerfile`, `LICENSE`, `README.md`, `box-plugins`, `config/`, `dev`, `docs/`, `install.sh`, `mods/`, `packs/`, `rules/`, `run-actions`, `tests/` |
| E7 | Small files | `rules/local.md`: one comment line, the target `dev`'s layer replaces. `install.sh`: 9 lines, one link to `~/.local/bin/dev` |
| E8 | Scripts | `dev`: 878 lines, 49 functions in clear groups (config, layer, project, box, scratch, helpers). `run-actions`: 408 lines, one job |
| E9 | Your workflow today | Spread over three places: `packs/documentation.md` and `packs/change-management.md` (company), `packs/workflow` (the closing skill), and the superpowers paths and Markdown rules in your global `CLAUDE.md` |
| E10 | `local/private-terms` | Read only by `tests/check_private_terms.py`; `dev` never reads it |
| E11 | Which `dev` runs | `~/.local/bin/dev` links to this clone's `dev`, so the checked-out branch is the `dev` every box of yours starts with; `local/` is gitignored and the same on every branch. A config only one branch's `dev` reads stops every start on the other, the approved snapshot included (its fallback reads it with the same checks) |
| E12 | The box's own rules | `box/company/CLAUDE.md` (today `rules/claude-rules.md`) names `.dev`'s kinds for "a tool the box lacks" |
| E13 | Your global `CLAUDE.md` | Its workflow parts name one of your projects (the link check's source): a private term once public |
| E14 | What the box can run | No Podman in the box: anything that starts a box (D4's check, the comparison of what a session loads) is a `dev run` step on your laptop |
| E15 | Worktrees | `git worktree add` records absolute paths by default: the box's `/work/claude-box/...` is a missing folder to your laptop's git, which `git worktree prune` deletes. git 2.56 (box and laptop) has `--relative-paths`. A branch checked out in a worktree can't be checked out in the main one, so you review it in the worktree's folder |
| E16 | Starting without a terminal | Without a terminal `dev` takes the approved config; with none readable (D6) it would start on the public defaults, without your rules |
| E17 | Other projects | None refers to the paths that move (`grep` of `/projects`, 2026-10-30); they invoke `workflow:closing`, the plugin's name `workflow` |

## Decisions

| # | Topic | Decision | From |
|---|---|---|---|
| D1 | Layers | Every input belongs to one of three layers: **company** (managed policy, built into the image, root-owned), **global** (user level, `~/.claude/rules/`), **project** (one project's box) | the owner, E3 |
| D2 | A pack | One folder, `packs/<name>/`, with up to three parts: `company/` (rules `*.md`, and `plugin/`, a Claude Code plugin every session loads), `global/` (rules `*.md`), `project/` (`rules/*.md` and `starter/`, files a project copies once) | the owner |
| D3 | Applying the parts | company: into your layer of the image, as today. global: mounted read-only at `~/.claude/rules/<pack>/` in every box. project: `project/rules/` mounted read-only at `~/.claude/rules/<pack>-project/`, only in boxes of a project whose `.dev` has `pack <name>`; `project/starter/` goes into your layer at `/usr/local/share/claude-box/packs/<pack>/starter/` (read-only, never under `~/.claude/rules/`, where its Markdown would load as rules), and Claude copies it on a `claude/` branch when the project adopts the pack. Scratch sessions have no `.dev`: company and global parts only. Every file comes from the approved snapshot (E2). These mounts change what a box gets mounted, not what it allows (the intent's *Not in this intent*) | the owner, E4 |
| D4 | Flat fallback | If branch 3's first task finds subfolders of `~/.claude/rules/` aren't read, the mounts are flat files `~/.claude/rules/<pack>-<file>.md` and `<pack>-project-<file>.md` | E4 |
| D5 | The config | `local/claude-box.conf`, one `<kind> <value>` per line. New kinds: `pack <name>`; `company <file, plugin folder or pinned URL>` (a folder holding `.claude-plugin/plugin.json` is a plugin); `global <file>`. Kept: `identity`, `plugin`, `dnf`, `projects`, `memory`, `cpus`, `remote-control`, and E1's path rules (a path under `local/`; a pack by its name) | the owner |
| D6 | Old kinds | One simple schema, nothing kept for the old one: `rules` and `plugin-dir` are refused with a message naming the new line (`company …`). An approved snapshot `dev` can't read counts as none, so `dev` shows your config and asks once; without a terminal it refuses to start, naming why, rather than start on the defaults (E16) | the owner, the review |
| D7 | `.dev` | One new kind, `pack <name>`, written by `dev add pack <name>`. It takes effect only when your approved config has `pack <name>`; otherwise `dev` says so and starts without it. A project without the line works as before. Like every `.dev` change, it applies to the next new box, not to a running one you join | the owner, the review |
| D8 | The format's reference | `box/defaults.conf` explains every kind with examples, in one place. `dev init` writes a starter `local/claude-box.conf` whose first line points to it, when there's none | the owner |
| D9 | Layout | Top level: `README.md`, `LICENSE`, `dev`, `local/` (gitignored), `packs/`, `box/`, `docs/`, `tests/`, `out/` (gitignored). `box/`: `Containerfile`, `defaults.conf`, `company/` (the box's own `CLAUDE.md`, `managed-settings.json`), `plugin/box-workflow/`, `bin/` (`run-actions`, `box-plugins`), `lib/` (dev's modules) | the owner, E6 |
| D10 | Small files | `install.sh` becomes `dev install` (same link); `rules/local.md` is written by the layer build (E7) | the owner |
| D11 | dev's modules | `dev` parses the command and sources `box/lib/`: `common.sh` (die, ask, image helpers), `conf.sh` (config, snapshot, approval), `layer.sh` (your layer), `mounts.sh` (D3's mounts), `project.sh` (`.dev`, project images, ports, plugins), `box.sh` (starting and joining boxes, shell), `scratch.sh`. `run-actions` stays one file (E8) | the owner |
| D12 | private-terms | Stays `local/private-terms`; described in the runbook as a file for developing claude-box, not in the README's user steps (E10) | the owner |
| D13 | Your workflow | `packs/workflow/` holds all of E9: the two rule files and the closing skill in `company/`, the superpowers paths and Markdown rules in `global/`, the project rules and starter files in `project/`. The global part is rewritten without your terms (E13). Your global `CLAUDE.md` keeps only what isn't the workflow; Claude writes the trimmed version as a draft in `out/`; the merge run puts it in place (D15). The plugin keeps its name `workflow`, so `workflow:closing` stays the same (E17) | the owner, the review |
| D14 | Projects adopt | When branch 3 merges, each project with a handoff in `out/` gets a notice: the three layers and packs; that its rules are unchanged; and how to adopt the workflow pack's project part: `dev add pack workflow`, then the starter files copied on a branch of its own | the owner |
| D15 | Switching without a break | Branch 3 is built in a git worktree, `.worktrees/layers/` (gitignored, made with `--relative-paths`, E15), so this clone's checkout, the `dev` your boxes start with (E11), stays on `main` until the merge. The merge run merges, then puts your converted config (a draft in `out/`) in place as `local/claude-box.conf`, and your trimmed global `CLAUDE.md` (D13) as `~/.claude/CLAUDE.md`, each refusing unless the current file is the one its draft was made from; then removes the worktree. Before the merge your global `CLAUDE.md` stays whole, so no rule is missing in between | the review, E11 |

## Deliverables

Four branches, in order, each from the current `main` (after
`claude/publishing-acceptance` is merged); each updates the
[architecture](../../system/architecture/README.md) and the
[runbook](../../system/runbook.md) where it changes what they describe.

**1. `claude/layout-moves`:** D9 by `git mv` only, and the path fixes
that keep it working: the `Containerfile`'s `COPY` lines, `dev`'s and
the tests' paths, Markdown links, also in the change records (a moved link target is the one change records allow). Behaviour unchanged; no wording
changes.

**2. `claude/dev-modules`:** D10, D11. Behaviour unchanged but `dev
install`; `tests/run.sh` covers `dev install` (the link, rerun safe).

**3. `claude/layers`:** D1 to D8, D13 to D15, in a worktree.

| Task | Content |
|---|---|
| First: the check | A `dev run` step on your laptop (E14), from the worktree's `dev`: a rule file in a subfolder of `~/.claude/rules/` is loaded (E4); a read-only mount there works and what it leaves on the laptop (E5). D4 if not |
| Config | D5, D6 in `conf.sh`; the snapshot and hash cover pack folders as before |
| Layer, mounts | company parts into the layer; D3's mounts from the approved snapshot |
| `.dev` | D7; `box/company/CLAUDE.md` names the `pack` kind (E12) |
| The pack | `packs/workflow/` per D13 |
| Reference | `box/defaults.conf` per D8 |
| Tests | `test_dev.sh`: each new kind accepted and placed in its layer; `rules` and `plugin-dir` refused, naming the new line; an unreadable approved snapshot counts as none; `.dev` `pack` without the config's warns and starts; mounts are read-only and come from the approved snapshot |
| Your setup | Your config converted to the new form as a draft in `out/`, put in place by the merge run (D15), approved by you at the next start; the trimmed global `CLAUDE.md` as a draft in `out/` |
| Merge run | D15: merge, both files put in place, the worktree removed |
| Notices | D14, after the merge |

**4. `claude/readme`:** the README for a newcomer on the new layout:
quick start (`git clone`, `./dev install`, `dev init`, `dev claude`),
the one file to edit and its reference, the three layers and packs, what
each top-level folder is; the runbook's section for developing
claude-box, with D12.

## Acceptance

| Criterion | Check |
|---|---|
| One file to edit | The README and `box/defaults.conf` name only `local/claude-box.conf`; `test_dev.sh` shows every setting comes from a line in it or a file it names |
| The format explained where met | The starter config's first line points to `box/defaults.conf`, which explains every kind |
| One line per pack | `pack workflow` alone brings all three parts (the tests above) |
| The top level | `ls` of a fresh clone shows D9's items; helpers in `box/` |
| From the README alone | A fresh reviewer (a subagent given only the README) names the file to edit and each top-level folder's purpose correctly |
| Your box as before | The instruction files a session of yours loads (managed, user, project) read by a `dev run` step (E14) before branch 1 and after branch 3's merge run, and compared: the same text, in the layers D13 puts them; your identity and plugins the same; `tests/run.sh` passes |
| private-terms for developing claude-box | The runbook describes it (D12); the README's user steps don't name it |
| Publishing waits | The stranger test of the publishing spec reruns on the new README before the flip |

## Related backlog items

- *Changing your config never gets in your way* (one bad line in
  `local/` blocks every start): D6 and D15 keep this milestone from causing it;
  the item itself stays in the backlog.
- *Every session starts with under 200 lines of rules*: the layers make
  it easier (rules can move to `global/` or path-scoped files); it stays
  its own item.

## Acceptance results (2026-10-31)

All met, with the deviations named. The four branches merged and were
pushed: `claude/layout-moves`, `claude/dev-modules`, `claude/layers`
(7f2c05c), `claude/readme` (485677e).

| Criterion | Result | Evidence |
|---|---|---|
| One file to edit | Met | The [README](../../../README.md#how-it-hangs-together) and [box/defaults.conf](../../../core/defaults.dev) (its first line) name only `local/claude-box.conf` as the file you edit; `test_dev.sh` places every kind from a line in it or a file it names (`conf-packs`, `conf-new-bounds`, `pack-all-parts`, `mounts-approved-only`, `packs-shipped`), and the defaults only without it (`conf-defaults`) |
| The format explained where met | Met | `dev init` writes the starter config, whose first line is "Your claude-box config: every kind, with examples, is in box/defaults.conf." ([dev](../../../dev), `init`); `box/defaults.conf` explains every kind of D5 |
| One line per pack | Met | `test_dev.sh`: `packs-shipped`, the repo's workflow pack, all three parts from `pack workflow`; `dev-pack-mount` and `dev-pack-missing` for `.dev`'s line |
| The top level | Met | The stranger test's fresh clone: `.gitignore LICENSE README.md box dev docs packs tests`, plus `local/` and `out/` once used ([stranger-test.log](stranger-test.log), the `LS-BEGIN` lines); helpers in `box/bin/`, dev's modules in `box/lib/` |
| From the README alone | Met | A fresh subagent given only the README named the file to edit and each top-level item's purpose right; its doubts were fixed ([findings-readme-test.md](findings-readme-test.md)). `tests/run.sh` now checks the README's table against the top level |
| Your box as before | Met, with three deviations | [compare-before-after.md](compare-before-after.md): the same text in D13's layers, identity, plugins and managed settings the same; `tests/run.sh` passed in the new box. Deviations: the files were read inside the box, by a session of yours, not by a `dev run` step (E14 needs Podman only to start a box, not to read what a session loads); the company rule files load in the other order (change management before documentation, the pack's name order); the box's own `CLAUDE.md` gained E12's sentence on `pack` |
| private-terms for developing claude-box | Met | The runbook's [Develop claude-box](../../system/runbook.md#develop-claude-box); the README never names it, which `tests/run.sh` checks |
| Publishing waits | Met, with one deviation | [stranger-test.sh](stranger-test.sh) on `claude/readme` before its merge ([stranger-test.log](stranger-test.log), machinectl's `\r` removed): `./dev install`, `dev build`, a box on the public defaults, `2.1.316 (Claude Code)`, `claude@claude-box.invalid`, `STRANGER-TEST-OK`; cbtest removed. Deviation, as in the publishing spec's D8: `dev build` in place of `dev init` (no Claude login), so `dev init` writing the starter config isn't part of it; `test_dev.sh` runs `dev init` |

Findings left from the branches' reviews, each now in the
[backlog](../../direction/backlog.md) under *`dev` handles odd input
plainly*: a pack's company file whose name holds a space or `$` breaks
the real layer build; a pack named twice in `.dev` is mounted twice; an
existing `~/.claude/rules/<pack>/` of yours is hidden by the mount
without a word; a pack with only a global part still builds a layer.
