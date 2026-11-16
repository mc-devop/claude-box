# Findings: the spec's review before approval (2026-10-31)

The owner asked what breaks, what's overkill and what's missing in the
[spec](spec.md) as first written (037bf1b). It was read against the code
on `main` (e54ca8b). Every finding below was fixed in the spec, or moved
to the [backlog](../../direction/backlog.md), as its row says.

## What breaks

| # | Finding | Fix |
|---|---|---|
| B1 | **`use` with a path "from anywhere" could put `~/.ssh/id_ed25519` into a box** as a "rules file". That breaks the core guarantee that nothing else of yours reaches a box. Today `clone_path` only allows `local/` and `packs/`, with safe characters | D4: a local path must be under `~/.claude/` or your projects folder, both of which every box sees already, with today's safe characters. Nothing new reaches a box |
| B2 | **The core hash would rebuild from an unmerged branch.** You leave the clone checked out on `claude/` branches for review, so the next `dev claude` in *any* project would offer an image containing unreviewed code | D12: the hash is git's tree id of `main:core`, and the image is built from `git archive main`. A branch never reaches the image |
| B3 | **Refusing `plugin` and `pack` lines in a project's `.dev` stops every other project's box** the moment branch 2 merges, before their handoffs are acted on | D3: in a project's `.dev`, those lines are skipped with a one-line notice. Only the global config refuses gone kinds |
| B4 | **Your box would refuse to start after branch 2's merge** if `~/.claude/.dev` didn't exist yet | D16: Claude writes it before that merge run |
| B5 | **`run-actions` reading the live `~/.claude/.dev` for refusals** would let Claude remove refusals you set, because any box can write that file | Gone with O1 |
| B6 | **The stranger test can't get past `dev init`'s login** (no account in the test) | D13: `dev init` writes `~/.claude/.dev` first, before building and logging in, and keeps one that exists. The test checks the file and declines the login |

## What's overkill

| # | Finding | Fix |
|---|---|---|
| O1 | `refuse` lines and moving `run-actions`' patterns into a data file. The owner wasn't sure they wanted it, and nothing they've hit needs it | D10: refusals stay in `run-actions`, and `core/README.md` lists them. Your own refusals: backlog |
| O2 | `use` with a git repo (commit lookup plus archive hash). None of the owner's plugins come that way: Karpathy's rules are a file URL, and the plugins come from marketplaces | D4 and D6 drop it; backlog |
| O3 | `marketplace.json` for the workflow plugin. It serves Claude Code users without claude-box, which no criterion asks for | D7 drops it; backlog |
| O4 | `dev update` refreshing pinned downloads. With O2 gone, every pinned URL carries its commit, so there's nothing to refresh | D12: `dev update` only pulls |

## What's missing

| # | Finding | Fix |
|---|---|---|
| M1 | `dev new` without the offer menu: what it writes | D3: `dev new` lays down the starters of the plugins you use and offers nothing; it writes no `pack` lines (replacing project-defaults D10) |
| M2 | The levels rule moving into core is always loaded. Today the layer rule is path-scoped and costs nothing at start | D8: core gets the three-line levels rule; the sections of a project's `CLAUDE.md` stay path-scoped in the workflow plugin |
| M3 | Scratch sessions | D3: they get the global `.dev`; a scratch has no project level |
