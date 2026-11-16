# Findings: the spec after acceptance (2026-10-31)

The owner's review questions on the [spec](spec.md), once it was built
and accepted: what breaks, what's overkill, what's missing. Read
against the code on `main` (485677e). Where each open finding went is
named; the backlog item is *A new user sets up, updates and leaves
claude-box from the README alone* in the
[backlog](../../direction/backlog.md).

## What breaks

| # | Finding | Where it went |
|---|---|---|
| B1 | `pack workflow` alone isn't the whole workflow: its global rules ([specs-and-plans.md](../../../plugins/workflow/rules/specs-and-plans.md)) rely on the superpowers plugin, which the pack line doesn't bring and the defaults don't offer. *One line per pack* passed because the tests count the pack's parts, not what they rely on | Backlog item above |
| B2 | A pack of your own has to live in the clone's `packs/` (`pack_ok` in [conf.sh](../../../core/lib/conf.sh) takes `packs/<name>` only): a tracked folder, against "you edit one file", and in the way of `git pull` | Backlog item above |
| B3 | The four findings from the branches' reviews | The spec's [acceptance results](spec.md#acceptance-results-2026-10-31): in the backlog |

## What's overkill

| # | Finding | Where it went |
|---|---|---|
| O1 | D4, the flat fallback, never applied (the check found subfolders are read) | Nothing to do: a record stays as written |
| O2 | The evidence table's 17 rows; E5, E14, E15, E16 served one step each | Nothing to do: a record stays as written |
| O3 | D6's messages for the old kinds served one config, the owner's | Nothing to do: cheap, and built |
| O4 | *Your box as before* named a `dev run` step where a read in the box was enough | Named as a deviation in the acceptance results |

## What's missing

| # | Finding | Where it went |
|---|---|---|
| M1 | Updating claude-box: neither README nor runbook says `git pull`, then `dev build` for the box's own rules, while a pack's change is shown at the next start | Backlog item above |
| M2 | Leaving: nothing removes the `~/.local/bin/dev` link `dev install` makes; `dev reset` removes images and boxes | Backlog item above |
| M3 | D9's list leaves out `.gitignore`, which the README and its check list | Nothing to do: the README's table is the place, and its check keeps it true |
| M4 | A new user's real first steps (`dev init`'s starter config, then the first `dev claude` asking to apply it) never ran with Podman: the stranger test runs `dev build` | Backlog item above |
| M5 | "One file to edit" holds for the box's settings; your `~/.claude/CLAUDE.md` is a second place you edit (the README names it under *global*). The intent's wording didn't cover it | Done: the README names it under *Three layers and packs* |
