# Spec: claude-box is public, and this repo is retired

For the [intent](intent.md). Design agreed with the owner section by
section, 2026-10-30; the review's fixes (what breaks, what's
overkill, what's missing) applied the same day; approved by the owner
2026-10-30, after its review.

## Evidence (2026-10-30, read from the code, this box and `/projects`)

| # | Point | Finding |
|---|---|---|
| E1 | Your terms outside the records | Your project names in the [backlog](../../direction/backlog.md), the [runbook](../../system/runbook.md) and [inbox.test.ts](../../../core/plugin/box-workflow/hooks/inbox.test.ts); your laptop's name in the backlog; your git name in [test_dev.sh](../../../tests/test_dev.sh). Not yours: `forgejo` (an example in [change-management.md](../../../core/rules/branches-and-evidence.md)), the Karpathy URL (an opt-in example in [the defaults](../../../core/defaults.dev)), `mc-devop` (the repo's owner, shown in its clone URL) |
| E2 | The leak check | [check_private_terms.py](../../../tests/check_private_terms.py) reads `local/private-terms` and checks every tracked file; skipped without that file (ruling R3 of the config milestone, in the archive) |
| E3 | Your approval | `dev` keeps it in `~/.local/state/claude-box/approved/`, outside the clone: a new clone with the same `local/` starts without asking |
| E4 | `dev` on your PATH | [install.sh](../../../dev) links `~/.local/bin/dev` to the clone's `dev`; the box's name, this project's memory folder and the other projects' handoff addresses come from the folder name `claude-box` |
| E5 | The other projects | None links into this repo's files or its GitHub URL; they name it and read `/projects/claude-box` |
| E6 | A second clone | `~/Projects/mc-devop/claude-box`: an empty clone of the same GitHub repo (no commits, 2026-09-27); after the rename it points at the archive. Yours to delete or keep; this change leaves it alone |
| E7 | `git archive` | Leaves out paths marked `export-ignore` in `.gitattributes`; a folder whose parent pattern marks it is dropped even when its files are unmarked, so the folder itself needs `-export-ignore` too (tried with git 2.56) |
| E8 | `dev init` | Builds the image, then starts `claude` for the login: the login needs a person and an account |
| E9 | `gh` | Not in the box; the GitHub steps use your `gh` on the laptop, logged in with the `repo` scope (unchecked until run 1's first step); `gh repo rename` and `gh repo archive` ask to confirm unless given `--yes` |
| E10 | Links into the records | Outside the records, 59 links point into `docs/change/`: 32 in the backlog, 21 in the [architecture README](../../system/architecture/README.md) (each cross-cutting decision links to its record), 6 in two other views. In the export each is broken, and the link check fails |
| E11 | Identities in the history | Claude commits as `Claude MC <claude-mc@dummy.noreply>` (your `local/` config): public in every commit, so not a private term. The single first commit is made on your laptop, with your laptop's git identity unless the step sets one |
| E12 | Running from a moved folder | `dev run` reads `out/actions.txt` in the clone: a run that moves the clone keeps writing its log there, under the new folder name |
| E13 | Removing a user | `userdel -r` refuses while the user's systemd manager or Podman's pause process runs; whether it clears the user's `/etc/subuid` and `/etc/subgid` lines is unchecked |

## Decisions

| # | Topic | Decision | From |
|---|---|---|---|
| D1 | How | Clean up in this repo on ordinary branches, then export once: the new repo's single commit is `git archive main`, with nothing to clean afterwards | the owner |
| D2 | What stays out | `.gitattributes` marks `docs/change/**` and itself `export-ignore`, and unmarks this change's folder and its files (E7). So the new repo has no `.gitattributes`, and its check covers every file, future records included | the owner |
| D3 | This change's record | `docs/change/2026-10-30-publishing/` is the one record that goes public: written without your terms, it finishes in the new repo (acceptance results, closing). A log it cites is copied in only after the private-terms check passes on it. `operations-log.md` stays in the archive; the new repo starts its own when a run first needs one | the owner |
| D4 | The check | `check_private_terms.py` skips paths `git check-attr` reports `export-ignore` as set; your `local/private-terms` holds your project names, your laptop's, your servers' and your email, one regex each; not Claude's identity (E11). From then on `tests/run.sh` runs the check for real | E1, E2 |
| D5 | Names | GitHub: this repo becomes `mc-devop/claude-box-archive` (private, archived); the new one is `mc-devop/claude-box`, private until you flip it in GitHub's settings. Laptop: this folder moves to `~/Projects/claude-box-archive`, the new clone takes `~/Projects/claude-box` (E4) | the owner |
| D6 | What a clone carries over | `local/` and `out/` (its handoffs, `done/` and drafts), without `out/actions.*` | E3, E4 |
| D7 | The README | For a stranger: requirements (Linux with rootless Podman, tested on Fedora 44; a Claude account); quick start (`git clone`, `./install.sh`, `dev init`, `dev claude` in a project); what the box sees and refuses, with a link to the [architecture](../../system/architecture/README.md); your config and its approval; the packs are optional, so a user can plan their own way (e.g. GitHub Issues); MIT license | the owner |
| D8 | The stranger test | A throwaway user `cbtest` on your laptop runs the README's commands in its own session (`machinectl shell`, so Podman gets its runtime folder), cloning from a `git bundle` of the new commit (the repo is private). It runs `dev build` in place of `dev init` (E8) and stops before the login: a box starts on the public defaults, `claude --version` runs in it and the public identity shows. Then the user and its home are removed | the owner |
| D9 | Reruns | Every changing step checks the state first and refuses if it isn't what's expected (below) | change management |
| D11 | Identities | The first commit's author is you with your GitHub noreply address (`<id>+mc-devop@users.noreply.github.com`, the id from `gh api user`), set in the step. Claude keeps `Claude MC <claude-mc@dummy.noreply>` | the owner, E11 |
| D12 | The tested export | Before writing run 1, Claude extracts `git archive main` in its scratchpad, with `local/` copied in, and runs the whole `tests/run.sh` there (links, private terms, all of it). Run 1 names that commit and refuses if `main` isn't it. The laptop needs no test tools | E10 |
| D10 | Telling the others | Each project with a handoff in `out/` gets a notice: the GitHub repo and its records moved to `claude-box-archive`, `/projects/claude-box` stays the same, nothing for them to change | the intent |

## Deliverables

Two branches, in order, then two runs.

**1. `claude/public-check`:** D2, D4.

| File | Change |
|---|---|
| `.gitattributes` | New: D2 |
| [check_private_terms.py](../../../tests/check_private_terms.py) | Skips `export-ignore` paths |
| [tests/run.sh](../../../tests/run.sh) | `export-clean`: `git archive HEAD` holds no path under `docs/change/` but this change's folder, and no `.gitattributes`. `private-terms-attr`: a term in a marked path passes, the same term elsewhere fails |
| [inbox.test.ts](../../../core/plugin/box-workflow/hooks/inbox.test.ts), [test_dev.sh](../../../tests/test_dev.sh) | Neutral names in the fixtures |
| `local/private-terms` | New, untracked (D4) |

**2. `claude/public-docs`:** D7, and no term of yours left in a tracked
file outside the marked paths.

| File | Change |
|---|---|
| [README.md](../../../README.md) | D7 |
| `LICENSE` | New: MIT, copyright the repo's owner |
| [Runbook](../../system/runbook.md), [architecture](../../system/architecture/README.md) and its views | Your project names replaced by examples. Each decision linked to a record is stated in the doc itself, and its link removed (E10): the largest piece of this branch, its own task in the plan |
| [Vision](../../direction/vision.md), [backlog](../../direction/backlog.md) | The backlog's open items restated without your terms or links into the archive; *Now:* points at this change |

**Run 1, *publish claude-box, private*** (while a box runs; sudo only
for the stranger test):

1. Read: `gh --version`, `gh auth status` (account and scopes; the
   token stays masked), `gh api user --jq .id`.
2. Rename: refuses unless `mc-devop/claude-box` is this repo (private,
   not archived) and `claude-box-archive` doesn't exist; `gh repo
   rename --yes`, then `git remote set-url origin` to the new name.
3. Create: refuses if `mc-devop/claude-box` exists; `gh repo create
   mc-devop/claude-box --private --description <one line>`, without a
   README.
4. Export: refuses unless `main` is the commit D12 tested and equals
   `origin/main` (the checkout may stay on a `claude/` branch);
   `git archive main` into `~/.cache/claude-box-export/` (emptied
   first), with `local/` copied in (`.gitignore` keeps it out);
   `git init`, `git add -A`, `check_private_terms.py` there; one commit
   `claude-box` authored per D11; push.
5. Stranger test (sudo; the image build takes about 10 minutes):
   refuses if `cbtest` exists; D8; `loginctl terminate-user cbtest`,
   `userdel -r cbtest`, then checks no `cbtest` line is left in
   `/etc/subuid` and `/etc/subgid` (E13); `sudo -k`. Its first run has
   no `allow` or `expect`: a warning line from Podman or dnf aborts it,
   and the fix adds an `allow` for that line.

**Run 2, *switch to the public clone*** (after `/exit`):

1. Move: refuses while a container of claude-box runs (`podman ps`) or
   `~/Projects/claude-box-archive` exists; moves this folder there.
2. Clone: refuses if `~/Projects/claude-box` exists; clones the new
   repo; copies D6.
3. Archive: `gh repo archive mc-devop/claude-box-archive --yes`.

Run 2's log stays in `~/Projects/claude-box-archive/out/` (E12); Claude
reads it at `/projects/claude-box-archive`.

**Then, in the new repo:** the checks below, D10's notices, your
review and flip, the closing with the tag `publishing`.

## Acceptance

| Criterion | Check |
|---|---|
| One commit, no records, MIT | `git log` in the new repo: one commit, its author per D11; `LICENSE`; `docs/change/` holds only this change |
| No private term | `tests/run.sh` in the new clone with your `local/private-terms`; run 1's check before the push |
| A stranger installs from the README | Run 1's stranger test (D8), its log |
| The packs are optional | The README says so (D7) |
| Your box as before, developed there | `git diff --stat main <new commit>` in the archive shows only `docs/change/` and `.gitattributes`; `dev claude` in the new clone starts without asking (your layer and approval don't depend on the clone, E3). The first commit on a `claude/` branch of the new repo |
| Vision and backlog public, clean | The check above; no link into `docs/change/` but this change's folder |
| The archive | `gh repo view mc-devop/claude-box-archive`: private, archived |
| The others told | Each notice in `out/handoff-<project>.md` |
| Public | `gh repo view mc-devop/claude-box`: public, after your flip |

## Acceptance results (2026-10-30, in the new clone)

Two runs and the stranger test passed; the last criterion waits for your
flip. Evidence files are in
this folder; each log passed the private-terms check before it was
added.

| Criterion | Result | Evidence |
|---|---|---|
| One commit, no records, MIT | Met | `git log`: one commit 457b405 `claude-box`, author `mc-devop <275075502+mc-devop@users.noreply.github.com>` (D11); `LICENSE` MIT; `docs/change/` holds only this folder |
| No private term | Met | `check_private_terms.py` in the new clone with your `local/private-terms`: 48 files, 0 matches, these evidence files included |
| A stranger installs from the README | Met | [stranger-test.sh](stranger-test.sh): [stranger-test.log](stranger-test.log) (run 1) and [stranger-test-earlier.log](stranger-test-earlier.log) (an earlier try, whose checks missed the `\r` of machinectl's terminal) both end in `2.1.314 (Claude Code)`, `claude@claude-box.invalid`, `STRANGER-TEST-OK` |
| The packs are optional | Met | [README](../../../README.md) (D7) |
| Your box as before, developed there | Met, with two deviations | The archive's session compared trees with `diff -rq` instead of `git diff --stat main 457b405`, which the archive can't run (it can't fetch the new commit): its `main` f671f9f differs from the new clone (without `.git`, `out`, `local`) only by `docs/change/` and `.gitattributes`. Whether `dev claude` started without asking wasn't recorded: `dev claude --continue` failed first, and you settled it with the archive's session. This branch, `claude/publishing-acceptance`, is the first `claude/` branch of the new repo |
| Vision and backlog public, clean | Met | The private-terms check above; the link check passes with no link into `docs/change/` but this folder |
| The archive | Met | [actions-run-2.log](actions-run-2.log), step 3: `{"isArchived":true,"visibility":"PRIVATE"}`; read again in [actions-run-3.log](actions-run-3.log): the archive private and archived, `mc-devop/claude-box` private and not archived. Run 2's `ls out` listing named other projects: those four lines are replaced by a marked line, and the full log stays in the archive |
| The others told | Met | D10's notice to each of the three projects with a handoff, 2026-10-30, each in `out/handoff-<project>.md` |
| Public | Open | `gh repo view mc-devop/claude-box` after your flip |

Run 1's own log is gone (run 2 overwrote it); its evidence is the
stranger-test logs and [run 3's read](actions-run-3.log) of both repos. Branch 2's open
finding (the export link test prints only a count) no longer applies:
that test runs only where `.gitattributes` exists, and the new repo has
none.
