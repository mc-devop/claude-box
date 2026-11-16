# Findings: what Claude Code allows, for the simpler model (2026-10-31)

Five checks against Claude Code's documentation, made before the spec
and read on 2026-10-31: the
[plugin reference](https://code.claude.com/docs/en/plugins-reference),
[hooks](https://code.claude.com/docs/en/hooks),
[permissions](https://code.claude.com/docs/en/permissions) and
[memory](https://code.claude.com/docs/en/memory).

| # | Question | Answer | Consequence |
|---|---|---|---|
| 1 | Can a plugin carry rules, like `CLAUDE.md` or `rules/`? | **No.** "A `CLAUDE.md` at the plugin root isn't loaded as context … To include instructions that load into Claude's context, put them in a skill." A plugin can carry skills, commands, agents, hooks, MCP and LSP servers, output styles, mods (`types` plus a hooks module), monitors, `bin/`, and **`dependencies`** on other plugins | A plugin can't deliver rules on its own |
| 2 | Can a `SessionStart` hook deliver rules instead? | Yes, but it's capped at **10,000 characters per string** (one cap per hook, not shared), with no setting to raise it. The text arrives as a system reminder, and the docs advise writing it "as factual statements, not imperative system-style instructions", which can trigger prompt-injection defenses. It fires on startup, resume, clear, compact and fork | It works, but it's weaker than real rules: capped, and treated as less trusted |
| 3 | Is there a replacement for `paths:` rules? | No event fires when a file is read. The closest is `PostToolUse` on Read, Edit or Write, filtered with `if`, which adds context *after* the tool runs. A skill triggers on its description | Path-scoped rules stay rules |
| 4 | Is there a managed rules folder? | **No.** Managed policy has `/etc/claude-code/CLAUDE.md`, or `claudeMd` in managed settings. A `rules/` folder with `paths:` exists for project and user (`~/.claude/rules/`) | Rules with `paths:` have to land in `~/.claude/rules/`, as packs' global parts do today |
| 5a | Does an `ask` rule still prompt in auto mode? | **Yes.** "A matching ask rule prompts even when a more specific allow rule also matches", and Bash ask rules prompt "even in auto mode". Managed settings can't be overridden | An `ask` rule on `~/.claude/` edits in core's managed settings asks you every time |
| 5b | Does it cover shell writes? | Partly. Edit rules cover the Edit and Write tools, file commands Claude Code recognizes in Bash (`sed`, `tee`), and redirect targets; a redirect target starting with `~` always needs approval. They don't cover "arbitrary subprocesses that read or write files indirectly, like a Python or Node script" | Not a boundary. A known limit to record, softened for `.dev` by the second gate at `dev claude` |

## What this changes in the design

- **A pack becomes a plugin with one extra folder, `rules/`.** It's an
  ordinary Claude Code plugin (skills, hooks, mods, `dependencies`
  such as superpowers). Claude Code ignores the `rules/` folder, and
  claude-box mounts it read-only into `~/.claude/rules/<name>/`, where
  rules, `paths:` included, load as first-class rules. The same plugin
  used outside claude-box still brings its skills; its rules then have
  to be copied into `~/.claude/rules/` by hand.
- **Rules are not delivered through a `SessionStart` hook** (finding 2):
  that route is capped and less trusted.
- **The workflow plugin names superpowers in `dependencies`**, the
  standard field, rather than in a `.dev` of its own.
- **Edits to `~/.claude/` get an `ask` rule in core's managed
  settings.** Edits through scripts remain a known limit.
