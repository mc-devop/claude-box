# A new user sets up, updates and leaves claude-box from the README alone

The record of this backlog milestone, from the clear-layout spec's
[review](../2026-10-30-clear-layout/findings-spec-review.md). It had no
intent or spec of its own: the
[simpler-model milestone](../2026-10-31-simpler-model/spec.md#related-backlog-items)
covered most of it, and the last part, removing claude-box, was one
branch, `claude/flip-prep`.

## Acceptance criteria

Restated in today's terms: the backlog item predates the simpler model,
which replaced packs and `local/` with `plugin` and `rules` lines.

1. The workflow plugin brings or offers everything its rules rely on
   (superpowers).
2. Your own plugins and rules files live outside the tracked repo.
3. The README or runbook says how to update claude-box and how to
   remove it, and `dev` can undo `dev install`.
4. The stranger test starts a box from the starter config `dev init`
   writes, approving it as a new user would (no Claude login).

## Acceptance results (2026-11-16)

On `claude/flip-prep`; the checks (`tests/run.sh`) passed on its last
commit.

| Criterion | Result | Evidence |
|---|---|---|
| 1. Workflow brings superpowers | Met | [plugin.json](../../../plugins/workflow/.claude-plugin/plugin.json) names it as a dependency (simpler-model D7); the [stranger test](../2026-10-31-simpler-model/stranger-test.log) offered `superpowers@superpowers-marketplace 7.0.2` with the starter config and applied it after `y` |
| 2. Yours outside the repo | Met | Simpler-model D4: a local `plugin` or `rules` path must be under `~/.claude/` or your projects folder; [core/defaults.dev](../../../core/defaults.dev) |
| 3. Update and remove | Met | README's [Quick start](../../../README.md#quick-start) names `dev update` and `dev uninstall`; the runbook's [Update claude-box](../../system/runbook.md#update-claude-box) and [Remove claude-box](../../system/runbook.md#remove-claude-box); `test_dev.sh` `uninstall` (a no keeps everything; a yes removes the boxes, images, `~/.local/state/claude-box/` and the link, keeps `~/.claude` and the clone) and `uninstall-other-link` |
| 4. Stranger test from the starter config | Met | The simpler-model [acceptance results](../2026-10-31-simpler-model/spec.md#acceptance-results-2026-11-15): a throwaway user's Quick start, the login declined, the starter config approved, a box ran |

**Deviations:** none from the criteria above. No milestone tag:
the tags would point at commits that `main`'s squash before the flip
leaves behind. `dev uninstall` wasn't run on a real laptop, only
against the fake Podman in `test_dev.sh`.

## Version check

| Pin | In use | Newest | Where it goes |
|---|---|---|---|
| `registry.fedoraproject.org/fedora` | 44 ([Containerfile](../../../core/Containerfile)) | 45 | The [backlog](../../direction/backlog.md) item on Fedora 45 |
| Claude Code | Unpinned: the installer's latest at each build | n/a | `dev build` |
