# Branch 3 (core-rules) evidence, read in a new box (2026-10-31)

For the simpler-model acceptance
([spec](spec.md#acceptance)). This was read
in the box the owner started after `dev build` on `main` bd8ecea. At acceptance it goes into
`docs/change/2026-10-31-simpler-model/`, after the private-terms check.

## Host facts (`cat /etc/claude-box/host`)

```
os Fedora Linux 44.20261031.0 (COSMIC Atomic)
shell zsh
has git gh podman ssh rsync flatpak rpm-ostree brew toolbox systemctl sudo python3 curl jq
lacks dnf
```

The format and order match plan 3's R4, and `dnf` is rightly missing on an Atomic desktop.

## Core rules and the dev-run skill

- `/etc/claude-code/` holds `CLAUDE.md`, `branches-and-evidence.md`,
  `levels.md` and `managed-settings.json`, all owned by root. The session's
  context lists all three rules files as "organization-managed policy
  instructions": `CLAUDE.md` imports the other two.
- The skill list has `box-workflow:dev-run`, from
  `/usr/local/share/claude-box/plugins/box-workflow/skills/dev-run`.
- Managed settings carry the env (`DISABLE_TELEMETRY`,
  `DISABLE_ERROR_REPORTING`, `DISABLE_FEEDBACK_COMMAND`,
  `SUPERPOWERS_DISABLE_TELEMETRY`, each `1`, also present in the session's
  environment), the four `ask` rules, and the `PreToolUse` hook
  `/usr/local/bin/no-commit-on-main`.
- **Not yet shown:** this box's `~/.claude/.dev` has `use workflow`. So the
  criterion "a box started with a `.dev` without `use workflow`" still
  needs a box without that line. The core rules do load from
  `/etc/claude-code/`, apart from the workflow's `~/.claude/rules/workflow/`.

## The ask prompt in auto mode

Claude tried to edit `~/.claude/CLAUDE.md` (a marked test line), and the owner
declined. The prompt's text, as the owner pasted it:

```
 Edit file
 ../../home/claude/.claude/CLAUDE.md
 # Global instructions
 # Global instructions (ask-prompt test, please decline)
 Do you want to make this edit to CLAUDE.md?
 ❯ 1. Yes
   2. Yes, and allow Claude to edit files in its ~/.claude folder for this session
   3. No
```

Option 2 lets the rest of the session edit `~/.claude` without asking.
That's worth a line under the architecture's known limits at acceptance.
