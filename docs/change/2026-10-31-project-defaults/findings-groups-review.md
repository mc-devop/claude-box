# Findings: the review of `claude/groups`

A fresh reviewer read the whole branch on 2026-10-31, after its five
tasks; `tests/run.sh` passed. Every finding was fixed on the same
branch, each with a test.

| # | Finding | Fixed by |
|---|---|---|
| 1 | The yes for a `.dev` group defaulted to yes, though Claude can write the line, and hid that the members then take this project's messages | `ask_no` (Enter is no); the question names what changes for the members |
| 2 | A member folder with a space in its name (`c d`) was read in the box as member `c`: a session named `c` was taken | `dev` leaves out, and names, a folder whose name isn't a session's (letters, digits, `. _ -`); box-workflow reads only lines of that shape, with a path under `/projects` or `remote` |
| 3 | Two projects of one folder name shared one groups file: one's start changed the other running box's trust | The file is named after the folder and a hash of its real path |
| 4 | A group folder inside a repo let a box add members (`git init` there) | `dev` refuses a group folder with a `.git` between it and your projects folder |
| 5 | Trust counted from `autotake group` on any line | Only as the file's last line |
| 6 | `read_dev` piped into `grep -q` under `pipefail` could drop a member | Read into a variable first |
| 7 | A project outside your projects folder joined by `.dev` showed as `remote` | Only a project in your projects folder joins by `.dev`; it's said otherwise. This narrows the [spec's D2](spec.md#decisions) ("a project elsewhere": outside the group folder): a deviation to name at acceptance |
| 8 | `read` without `IFS=` trimmed a yes's path | Read whole lines |
| 9 | The runbook said a member shows after "its restart"; joining a running box changes nothing | The runbook says when: a new box |
| 10 | `/autotake` listed an empty group as `group app ()` | `(no other members yet)` |
| 11 | Missing tests: a scratch, a folder member leaving, a project outside the projects folder, two projects of one name, a group folder in a repo, trust not on the last line | Each added |
