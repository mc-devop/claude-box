# Intent: a new user sees one file to edit and a repo they can read

Drafted by Claude from the owner's words (claude-box session,
2026-10-30); approved by the owner 2026-10-30.

## In the owner's words

Before the repo goes public: "The repo has to become more user friendly
and easier to understand how to use it." On the many folders (rules,
packs, mods, config): "it's the number of items, not just the folders
... why do we have so many? can they be combined?"

On scripts: "The script can be modular, I even encourage it, but put
the helper and sub scripts in a folder. It's the config files that the
user is expected to fill in that I want as few as possible."

On the config: "it can be printed in the file or refer to a file with
the correct format, does not matter. But the structure and so on needs
to be clear, the user only edits the config file (either with text or
refer to other files he defines)."

## Outcome

A new user reads the README, installs, and edits one file,
`local/claude-box.conf`, to make the box theirs. Everything they set is
in that file or in files of their own that it names. The repo's top
level shows only what a user runs or reads; the scripts that build and
drive the box sit in one folder, split into as many parts as reads
best. You keep your box exactly as it works today.

## Acceptance criteria

- The only file a user edits is `local/claude-box.conf`; every other
  setting is a line in it or a file of the user's own that it names.
  `local/private-terms` is described as a file for developing
  claude-box, not part of a user's setup (the owner, 2026-10-30).
- The config's format is explained where the user meets it: in the
  file itself or in a file it points to.
- Each optional pack is switched on with one line.
- The top level holds only `README.md`, `LICENSE`, the entry points a
  user runs, and folders whose names say what they hold; helper and
  sub-scripts are in one folder.
- From the README alone, a newcomer can say which file they edit and
  what each top-level folder is for.
- Your box, with your config moved to the new format, has the same
  rules, identity and plugins as before, and `tests/run.sh` passes.
- The repo goes public only after this milestone; the publishing
  milestone's flip waits for it.

## Not in this intent

- Changing what the box does or allows.
- The GitHub Issues pack: its own backlog item.
