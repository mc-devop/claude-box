# Intent: every plugin line lands the same way

Drafted by Claude from the owner's words (claude-box session,
2026-11-01); approved by the owner 2026-11-01.

## In the owner's words

"Why not just make plugin a plugin.. 'End up in image'.. isnt it better
they end up where all other plugins end up? either in global or
project?" After the table of where each `.dev` line lands, which showed
a marketplace plugin as the only kind a session can change: "yeah
harmonize it."

## Outcome

Whatever `plugin` line you write, in `~/.claude/.dev` or a project's
`.dev`, it lands the same way: in that level's image, the copy you
approved, out of every session's reach. A marketplace plugin is no
longer the exception that lives in your `~/.claude` and that one
session can change for every other box.

## Acceptance criteria

- A marketplace `plugin` line lands like a folder one, at both levels:
  in your layer from `~/.claude/.dev`, in the project's image from its
  `.dev`, loaded by every session there; nothing of it under
  `~/.claude/plugins/` or in a settings file, and a session can't
  change it.
- It runs the commit you approved; a newer one upstream is shown, with
  its changes, and applied only after your yes.
- A plugin's dependencies (superpowers for workflow) land the same way.
- Your setup moves over: superpowers, c4m and modularity, and any
  project's marketplace lines, now in the image; what Claude Code
  installed for them under `~/.claude/plugins/` and in the settings
  files is gone; the same behaviour in all your projects.
- The docs show one row per `plugin` line, the same at both levels
  ([core/defaults.dev](../../../core/defaults.dev), the README, the
  architecture).

## Not in this intent

- A plugin from any git repo that isn't a marketplace: its own backlog
  item.
- Managing plugins with Claude Code's `/plugin` inside the box.
