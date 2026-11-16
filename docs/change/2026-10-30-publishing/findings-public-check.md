# Findings: branch 1, the public check

From building [plan-public-check.md](plan-public-check.md), 2026-10-30,
and its branch review (a fresh reviewer, Opus): no critical or important
findings.

## Rulings

| # | Ruling | Why | Cost if wrong |
|---|---|---|---|
| R1 | `export-clean` lists `git archive --worktree-attributes HEAD` | `git archive` reads `.gitattributes` from the commit, so the checks couldn't pass before the commit | Until the commit, the test reads the working copy's attributes |
| R2 | `export-clean` runs only where `.gitattributes` exists | In the public repo (none there) every new record would fail it | None: the private-terms check covers that repo's records |
| R3 | ShellCheck takes the old record's `check.sh` only where it exists | Found by running `tests/run.sh` on the export (spec D12): the export lacks it | None |
| R4 | The backlog's link to a review heading named after your laptop project points at the file, without the anchor | The anchor holds a term; branch 2 removes links into the archive | None |
| R5 | `test_dev.sh` unchanged, against the spec's deliverable row | Claude's identity is public (D11), so not a term | None |

## Review minors

- **M1, a service name not on your list:** the fixture's service name,
  derived from a project name, was renamed with it but no term in
  `local/private-terms` matches it. Yours to decide: add a line for it,
  or accept it as not private.
- **M2, attributes from outside the repo:** `git check-attr` also reads
  `.git/info/attributes` and a global `core.attributesFile`; an
  `export-ignore` there would hide a file from the check. `git archive`
  reads the same sources, so the check and the export agree; in the
  public repo a push ignores `export-ignore`, so such a stray attribute
  could hide a pushed file. Accepted: none is set here, and the new repo
  has no reason for one.
