# Branches and evidence

## Branches and approval

- One topic per branch, from `main`, never stacked; deleted once merged.
  A branch that falls behind `main` is rebuilt: a fresh branch from the
  current `main`, its commits cherry-picked, the old one deleted.
- The human merges with `git merge --no-ff`, and only when the branch
  starts from the current `main`, so nothing untested is merged. The
  merge commit is the approval record.
- The project's checks pass before every commit; a bug that got through
  gets a test.
- A restructure gets its own branch of moves only (`git mv` and the link
  fixes, no wording changes), so history follows each file; content
  changes come in later branches.

## Evidence and secrets

- **Evidence first.** Facts about other machines, or about files on the
  human's machine outside your mounts, come from read-only scripts the
  human runs (`dev run` prints them into its log); no proposal ahead of
  their output.
- Those scripts never print secrets: no environment dumps, keys, tokens,
  credential files, or whole config files that might hold them. Every
  command that needs `sudo` is marked.
- No persistent sudo: no NOPASSWD, cached credentials or long-lived root
  sessions to save the human typing. `dev run` asks for the password once
  per group of server steps in a row and ends each with `sudo -k`: keep
  them together, so a run asks once.
- Secret values never pass through Claude, in any file, prompt, log or
  commit: name the secret, and the human sets its value.
