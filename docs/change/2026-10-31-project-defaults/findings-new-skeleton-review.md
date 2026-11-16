# Findings: the review of `claude/new-skeleton`

A fresh reviewer read the whole branch on 2026-10-31, after its three
tasks; `tests/run.sh` passed. Every finding was fixed on the same
branch, each with a test where code changed.

| # | Finding | Fixed by |
|---|---|---|
| 1 | A starter file that couldn't be copied exited `dev new` past its cleanup, leaving a half-made project | `lay_starters` returns 1, so `dev new` removes the folder |
| 2 | A starter's `.git/hooks/…` would be copied and run by the first `git commit`, as you; a starter's `.dev` would land too | Both refused, nothing created |
| 3 | `dev new app/.git` would make the group folder look like a repo and block every later command | A name or folder must start with a letter or digit |
| 4 | "recorded in .dev: commit it" showed for every new project | Only when `.dev` changed after the first commit |
| 5 | The starter's `CLAUDE.md` loaded as Claude's memory when reading files under it in this repo | Stored as `CLAUDE.md.starter`; a `.starter` suffix is dropped when laid down |
| 6 | `layers.md` didn't load for drafts of global files in `out/`, and restated the box's draft rule | A path for `out/**/*CLAUDE*.md`; the restated sentence removed |
| 7 | The unapproved-pack test passed even without the code; rollback, `.git`/`.dev` and odd names untested | Tests for each |
