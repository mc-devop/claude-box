# workflow

An ordinary, optional Claude Code plugin: the way this repo itself is
run. Documents come in three families (direction, change, system),
superpowers writes a change's spec and plans, and a closing skill
prepares a milestone's last branch and run. Bring it in with
`plugin workflow` in `~/.claude/.dev`; leave it out and plan your own
way. It brings [superpowers](https://github.com/obra/superpowers),
which `dev` builds into the image with it.

## Map

| Part | What it is | Where it lands |
|---|---|---|
| [.claude-plugin/plugin.json](.claude-plugin/plugin.json) | The plugin's name, its dependency on superpowers, and that marketplace's repo | Read by Claude Code and `dev` |
| [rules/documentation.md](rules/documentation.md) | The three families of documents, and where each fact lives | Read-only at `~/.claude/rules/workflow/`, read at every start |
| [rules/specs-and-plans.md](rules/specs-and-plans.md) | Where superpowers writes a change's documents | The same |
| [rules/markdown.md](rules/markdown.md) | Links and Mermaid diagrams in Markdown, and the link check an existing project copies from the starter | The same |
| [rules/claude-md.md](rules/claude-md.md) | The sections of a project's `CLAUDE.md`, read only when Claude reads or edits one | The same, path-scoped |
| [skills/sizes-of-change/](skills/sizes-of-change/SKILL.md) | `workflow:sizes-of-change`: one PR or an intent, and an intent's steps, loaded when a change starts | Built into the image, loaded by every session |
| [skills/closing/](skills/closing/SKILL.md) | `workflow:closing`: one branch with everything a milestone owes, one `dev run` that merges, tags and pushes | Built into the image, loaded by every session |
| [starter/](starter/) | A new project's first files: `CLAUDE.md`, the backlog, architecture and runbook pages, `docs/change/`, `tests/run.sh` with the link check, `.gitignore` | Laid down by `dev new` |
