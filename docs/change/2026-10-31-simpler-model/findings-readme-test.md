# Findings: the README and the maps alone (2026-11-01)

For the spec's acceptance row *The repo reads as the model*
([spec](spec.md#acceptance)), [plan 4](plan-one-way.md) Task 6. A fresh
subagent read only `README.md`, `core/README.md` and
`plugins/workflow/README.md` at commit d70b256, opened nothing else, and
for five things answered: where it lives, who changes it, and how a
change takes effect.

## Verdict

| Thing | Its answer | Right? |
|---|---|---|
| Claude's git identity | `~/.claude/.dev`, written by `dev init`, which asks for it; you, or Claude with your yes; the next `dev claude` shows it and applies it after your yes | Yes |
| Claude never commits to `main` | Core: the commit hook in the image's managed settings, and core's rules; only this repo, by merging to `main`; the next `dev claude` shows the changed core files and rebuilds after your yes | Yes |
| Documents in three families | The workflow plugin's `rules/documentation.md`, read-only at `~/.claude/rules/workflow/`; whoever wrote the plugin, this repo's by merging to `main`; the next `dev claude` after your yes, read at every start | Yes |
| A tool one project needs | The project's `.dev` (`dev add dnf jq`); you or Claude, on a branch; the next `dev claude` in it, after your yes | Yes |
| Claude Code's version | The image; you, with `dev build`; boxes started after the build | Yes |

## Where it was unsure, and what changed

| Doubt | Change |
|---|---|
| Whether "identity" means a name and an email, and what the line looks like | The README's table shows `identity Ann <ann@example.org>` |
| Whether a running box picks up a change | The README: "A running box keeps what it started with until its last session ends" |
| "Caps" undefined | "memory and CPU caps" |
| Whether `dev add` edits the file | "`dev add dnf jq` writes the line" |
| How Claude Code's version is chosen | "`dev build`, which installs the latest" |
| Why a checked-out branch never reaches a box | "so a change you're still reviewing can't change your boxes" |
| What "ask Claude to set you up" does | It walks you through your `~/.claude/.dev` and `CLAUDE.md` and proposes the changes, which you approve |

Left as they are: the `dev run` step kinds, groups and autotake, and
`box-workflow` against `workflow`. The README and the maps link to them
in the [runbook](../../system/runbook.md) and the
[architecture](../../system/architecture/README.md), which the reader
wasn't allowed to open. None of them stopped a correct answer.
