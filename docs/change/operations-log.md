# Operations log

One entry per run applied to a running system, newest last. Append
only.

## 2026-11-16: the flip run

Squashed `main` to one commit `claude-box` by the owner's GitHub
noreply address (the history kept in a git bundle on the owner's
laptop, outside every repo), deleted `mc-devop/claude-box` on GitHub
and created it again, private, then pushed that commit (f63235f). The
first try stopped before the delete: `gh` lacked the `delete_repo`
scope; a step added to the same file refreshed it. Passed.

## 2026-11-16: the backlog cleanup

Replaced the one commit with one holding the backlog without history
(3f4bd29), deleted and recreated the repo again, pushed, and took
back `gh`'s `delete_repo` scope. Passed.

## 2026-11-16: the general backlog

Replaced the one commit with one holding the backlog with only
general items (80f1f91) and pushed it with `--force-with-lease`; the
repo wasn't recreated, as 3f4bd29 held no history. Passed.

## 2026-11-16: the flip

Made `mc-devop/claude-box` public with `gh repo edit`, refusing
unless GitHub held only `main` at 80f1f91
([log](2026-10-30-publishing/actions-run-flip.log)). Passed.
