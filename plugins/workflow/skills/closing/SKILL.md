---
name: closing
description: Use when a milestone's acceptance is done or a backlog item closes - one claude/ branch with everything owed, then one dev run that merges, tags and pushes
---

# Closing a milestone or an item

One `claude/` branch carries everything; the human reviews it and runs
one `dev run`, and nothing is left to catch up afterwards. Every step
comes from the rules (core's and documentation.md) or this skill;
this is their order. Step 2 and the tag are for milestones only.

1. **What's owed.** Read `out/actions*.log` and the logs cited in the
   change's folder: every run applied to a running system since the
   newest entry in `docs/change/operations-log.md` gets its entry on
   this branch. Every open finding in the change's records has its one
   place (done, backlog, spec, accepted risk, or handed over).
2. **Version check.** The project's pin check if CLAUDE.md's Commands
   names one, else every pinned image and package listed by hand. Its
   table goes into the acceptance results. For each newer release, read
   its notes, security releases first; an update is its own PR or a
   backlog item, never part of this branch.
3. **Records.** The spec's acceptance results: each criterion met or
   not, with its evidence; every deviation from the spec named. An item
   without a spec: its record in its change folder.
4. **Direction.** The backlog item leaves with a link to its record;
   the "Now:" line; the session-handoff memory.
5. **Checks.** The project's checks pass on the branch's last commit:
   that commit is `<tested sha>` below.
6. **The human's run.** `out/actions.txt` from the template below (a
   new title per closing); then one line in chat naming its steps.

## Template

Fill `<project>`, `<title>`, `<branch>`, `<tested sha>`, `<summary>`;
for a milestone `<tag>` (`<milestone>-accepted`). For an item, drop the
tag step and push `main` alone.

Push steps: the ones in the project's runbook (tunnels, which remotes
get which closings); without any, one `git push <remote> main` step per
`git remote`. No `server` line: closing has only `local` steps.

```
# <project>: <title>

> Merges <branch> into main (--no-ff), refusing if it doesn't start
> from the current main. <summary>. The checks passed on <tested sha>
> in the box. Switches your checkout to main.
local git merge-base --is-ancestor main <branch> || { echo "<branch> doesn't start from main: rebuild it"; exit 1; }; git switch main && git merge --no-ff <branch> -m "Merge <branch>: <title>"

> The merged tree must equal the tested commit <tested sha>.
local git diff --exit-code <tested sha> main --stat

> Tags main as <tag>, refusing if the tag exists.
local if git rev-parse -q --verify refs/tags/<tag> >/dev/null; then echo "tag <tag> exists"; exit 1; fi; git tag -a <tag> -m "<tag>" main

> Pushes main and <tag> to <remote>.
local git push <remote> main refs/tags/<tag>

> Deletes the merged branch.
local git branch -d <branch>
```
