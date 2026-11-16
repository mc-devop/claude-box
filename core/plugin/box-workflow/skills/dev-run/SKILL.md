---
name: dev-run
description: Use before writing or changing out/actions.txt, the steps the human runs with dev run - its format, and the laptop facts a local step needs
---

# Commands for the human (`dev run`)

- Before a `local` step, read `/etc/claude-box/host`: the laptop's OS
  (`os`), its shell (`shell`), and the commands it has (`has`) and lacks
  (`lacks`). `local` steps run on the human's machine, as the human, not
  in the box: they use only commands it has (and the project's checks),
  and never install anything (`dev run` refuses it; see "A tool the box
  lacks").
- Overwrite the file each time. Format: the header of claude-box's
  `run-actions` (`# title`, `server user@host`, `> explanation`, `expect`,
  `allow`, then `local`, `root` or `host` steps). The `>`, `expect` and
  `allow` lines describe the step *below* them: put them above it.
- A new job gets a new title; a file fixed after an abort keeps its
  title, so `dev run` skips the steps that already ran (it never runs a
  step twice without `--force`).
- Put `>` lines above every step: what it does and why; for merges and dry
  runs, a short summary of the diff; for a step that runs over a minute,
  how long, so a silent step doesn't look hung. Say in the title and in
  chat when a step erases or overwrites something.
- `expect <regex>` only with text seen in real output of that tool and
  version; a guessed one aborts a good run, so a first read has none.
- Any error or warning line aborts the run, expected or not: read steps
  use known paths (no guessing with `find ... | head -1`) and don't probe
  things that may not exist. A step that reads logs (`journalctl`, a
  service's output) counts or filters them (`grep -c`, `--priority`)
  rather than printing them, or gets an `allow` for that log's lines.
- Steps run with the environment (`PATH`) of the terminal the human runs
  `dev run` in, and can ask there (a paste, a confirmation); their output
  goes through the log. Posting as the human (an issue comment, a forum
  post) is their own tool, e.g. `gh`, in a `local` step, with the text in
  the step.
- Steps that change something check the current state first and refuse
  if it is not the expected one (e.g. text to insert is already there),
  so a rerun cannot apply a change twice.
- Never write `--apply` in a `host` step: `dev run` dry-runs and asks first.
- Never put `dev` itself in a step (`dev build`, `dev claude`, ...): the
  human runs those; say so in chat.
- Make sure `out/` is in the project's `.gitignore` before the first run.
- Afterwards read `out/actions.log`. After an abort, find the cause before
  proposing the next run; fix the cause, not the check.
- Then tell the human in one line to run `dev run`, naming its steps in
  short (e.g. "`dev run`: merge claude/x, push forgejo, push github").
