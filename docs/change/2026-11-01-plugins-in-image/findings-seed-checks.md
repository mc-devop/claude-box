# Findings: seed checks in a real box (2026-11-01)

Task 1 of the [plan](plan-plugins-in-image.md): the [spec](spec.md)'s
checks for S2, S7 and S11, run on the owner's laptop with
[seed-checks.sh](seed-checks.sh) in throwaway boxes from the base image
(Claude Code as built on 2026-11-01). Three runs; the
[log](seed-checks.log) of the last, and a
[debug excerpt](seed-checks-debug-excerpt.txt) of its session start.

| # | Question | Answer | Consequence |
|---|---|---|---|
| 1 | Does `claude plugin install` into a seed work without a login? (S2) | **Yes.** Both installs exit 0 with an empty, throwaway config folder; the seed records `installPath: /seed/cache/<market>/<plugin>/<version>` and `gitCommitSha` | S2 stands: the staging box needs no `~/.claude` |
| 2 | Do two seeds holding one marketplace, with a different plugin from it in each, load both? (S7) | **Yes.** At session start: "Synced 1 marketplace(s) from seed dir(s)", then "Using seed cache for elements-of-style … at /seedB/…" and "… superpowers … at /seedA/…"; both plugins' skills load | No refusal: a marketplace may be used at both levels, with a different plugin at each (Task 5's test) |
| 3 | Does Claude Code write the seed's marketplaces into the config folder? (S11) | **Yes, at session start.** `plugins/known_marketplaces.json` gets the seed's marketplace with `installLocation` under the seed and `autoUpdate: false`; it also writes `installed_plugins.json` | A known limit in the architecture: a native Claude Code on the laptop, reading the same `~/.claude`, would find a marketplace path that exists only in the box |
| 4 | Does `claude plugin list` show seed plugins? | **No**: it listed only the box's own plugin, though the session loaded both seed plugins | The acceptance checks a session's loaded plugins (a session start's debug log, or `claude -p --output-format stream-json --verbose` with the login), not `plugin list` |

The second run failed to start Claude Code: `timeout` inside the box
exited 125 before it. The third run put the time limit on `podman run`
outside the box.
