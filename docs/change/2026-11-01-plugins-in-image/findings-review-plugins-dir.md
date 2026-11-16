# Findings: the plugins-dir branch review (2026-11-03)

Task 5 of the [plan](plan-plugins-dir.md): a fresh reviewer on
`claude/plugins-dir` (9af556b..d50b7ad), verdict "with fixes". Each
finding and where it went.

| # | Finding | Where it went |
|---|---|---|
| C1 | `seed_clear` wrote JSON through a fixed temp name in `~/.claude`: a link a box planted there made `dev` overwrite any file of yours (reproduced), up to running code as you | Fixed: a new file by `mkstemp`, with the old file's mode; test `seed-clear-links` |
| C2 | Links under `~/.claude/plugins` weren't refused: `box` would mount, and `seed_clear` remove inside, whatever a box linked there | Fixed: `box` refuses links at `plugins`, `data`, `store`; `seed_clear` at `plugins`, `cache`, `marketplaces` and the JSON files; tests `box-plugins-link`, `seed-clear-links-cache`, a linked copy in `seed-clear-outside` |
| C3 | Pre-existing: `dev`'s host-side `python3 -` and `-c` import from the project folder, which every box can write (reproduced: a `json.py` there ran on the host) | Its own branch, `claude/python-isolated`: `python3 -I` everywhere on the host; test `python-isolated` |
| I4 | The yes guarded a list worked out again afterwards | Fixed: only the list shown is removed; test `seed-clear-changed` |
| I5 | Names from box-written folders reached the terminal raw | Fixed: control characters shown as `?`; test `seed-clear-escapes` |
| M1 | `podman rm -f` without `-v` leaves a stopped box's volume | Fixed: `-v` in `box.sh` and `dev reset` |
| M2 | A broken JSON file printed a traceback at every start | Fixed: one line; `seed-clear-bad-json` checks it |
| M3 | One record could remove a cache folder a kept record uses | Fixed: such paths are skipped |
| M4 | `write` replaced a linked `settings.json` and reset its mode | Fixed with C1 (a link is refused, the mode kept) |
| M5 | The docs said "at every `dev claude`"; it's every box start | Fixed in [deployment](../../system/architecture/03-deployment.md#plugins) |
| M6 | The backlog still said the spec awaited approval | Fixed in the [backlog](../../direction/backlog.md) |
| M7 | A marketplace entry goes even when its folder isn't the box path, leaving the folder | Only for a Claude Code run on the laptop itself: the [accepted risk](../../system/architecture/README.md#accepted-risks) "the box writes into `~/.claude`" says none runs there |

Set aside by the reviewer, each placed: harm to a Claude Code on the
laptop (the same accepted risk); old cache versions no record names
(left, as P3 says); the time a fresh box spends if Claude Code clones a
marketplace into its empty folder at every start (the second acceptance
run measures a session start); a box enabling plugins through the
project's settings (the reworded accepted risk).
