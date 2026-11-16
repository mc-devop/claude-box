# Findings: the registration in the image, checked in a real box (2026-11-04)

The check before building P5 of
[spec-plugins-registration](spec-plugins-registration.md), run on the
owner's laptop with [registration-check.sh](registration-check.sh): a
throwaway image from the owner's layer carrying the seeds'
`known_marketplaces.json` at `/home/claude/.claude/plugins/`, one box
from it set up as `dev` sets up a box, its `~/.claude` a temp folder.
The [log](registration-check.log).

| # | Question | Answer |
|---|---|---|
| 1 | Does the new plugins volume hold the image's file? | **Yes**: `claude 644`, the volume's `U=true` gives it to Claude |
| 2 | Can Claude write it? | **Yes** |
| 3 | Does a session start skip a marketplace? | **No**: 0 skipped as orphaned, 0 synced; c4m, superpowers and modularity "Using seed cache" from `/usr/local/share/claude-box/seed/cache/` |

**Consequence:** P5 is built as the spec says.

**Found while building:** `dev` rebuilds your layer when your approved
config or the base image changes, never for a change of its own code
(`core/lib/` isn't part of the image's key). So images built before the
merge get the file at their next rebuild: `dev build`, or a change of
your seed. Until then a box behaves as before the merge (asks for
`/reload-plugins` once). The acceptance after the merge runs after a
`dev build`.
