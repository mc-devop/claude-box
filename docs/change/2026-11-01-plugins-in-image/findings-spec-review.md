# Findings: review of the spec (2026-11-01)

Claude's review of the [spec](spec.md) at the owner's request ("what
breaks, what's overkill, what did we miss"). The owner accepted every
fix on 2026-11-01 and approved the spec with them; each is applied
there.

| # | Kind | Finding | Fix in the spec |
|---|---|---|---|
| R1 | Breaks | The intent's "nothing of it under `~/.claude/plugins/`" can't hold: the data folder stays there | Named as a deviation; the acceptance checks "nothing of its code" |
| R2 | Breaks | S1 said `dev` never parses a source type, but S4 reads the repo fields | S1: `dev` never fetches or installs; S4 names the fields it reads |
| R3 | Breaks | Any commit in a busy marketplace would stage and ask | S3: an unchanged plugin isn't shown; nothing left, no question |
| R4 | Breaks | A new line asked twice: the `.dev` diff, then the staging | S3: staging first, one question for both |
| R5 | Breaks | A marketplace in both seeds is undocumented | S7: checked first in a real box; else one level per marketplace |
| R6 | Breaks | The move-over left the marketplaces registered | S9: removes those no install uses |
| R7 | Overkill | Listing changed files per update | S3 shows version and commit only |
| R8 | Overkill | Two tests repeated others | Six cases, plus a removed line |
| R9 | Missed | Removing a line | S2: staging builds the whole seed fresh; S4: offline, a removal waits |
| R10 | Missed | Every update rebuilds the layer and the project images on it | S4 names the cost |
| R11 | Missed | `needs_layer` skips marketplace lines | S1 |
| R12 | Missed | GitHub over SSH was unreachable from the laptop | S4: always HTTPS |
| R13 | Missed | Claude Code may write the seed's marketplaces into `~/.claude` | S11: checked first with S7 |
