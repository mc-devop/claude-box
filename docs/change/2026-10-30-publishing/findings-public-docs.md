# Findings: branch 2, the public docs

From building [plan-public-docs.md](plan-public-docs.md), 2026-10-30,
and its branch review (a fresh reviewer, Opus): one important finding,
ten minor; fixed in one pass unless said otherwise below.

## Rulings

| # | Ruling | Why | Cost if wrong |
|---|---|---|---|
| R1 | The runbook's link to the README's `#setup` points at `#quick-start` | The heading was renamed | None |
| R2 | The README says `dev init` and `dev plugins --global` offer your config's plugins (none by default); `dev help` says the same | Both offer the config's `init` plugins; the public defaults list none | None |
| R3 | Both export tests archive a snapshot of the working tree (`git stash create`, no ref moves) instead of `HEAD` | Otherwise the checks can't pass before the commit | An untracked new file counts only once added |
| R4 | The intent's and spec's two links into the config milestone's record became plain text naming that record in the archive | This folder goes public; a moved link target is the one change records allow. In the archive those two links no longer resolve as links | None |
| R5 | The backlog's review codes became the review's name and date | Their meaning lived in records that stay in the archive; each item's *Done when* states the content | None |
| R6 | Review minors that a stranger reads in the export (the backlog's sources, a run-on sentence, the runbook's command count, *packs* marked as our own term, the stale help line) were fixed with the important one | Their effect is the public docs read wrong on the day they're published, the branch's goal | None |

## Open

- **The export link test prints only the count** when it fails, and
  deletes the log with the broken links; when `git archive` itself fails,
  `tail` adds its own error. Minor: the failure still fails the run;
  printing the problem lines is a one-line change for a later branch.

## From branch 1

- **M1 of [branch 1's findings](findings-public-check.md#review-minors):**
  the owner ruled the fixture's service name an invented example, not a
  private term (2026-10-30). Closed.
