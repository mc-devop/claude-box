# Spec: new projects start alike and find their neighbours

For the [intent](intent.md). Design agreed with the owner section by
section, 2026-10-31 (approach: the policy in your config, the content
in the workflow pack); the review's fixes (what breaks, what's overkill,
what's missing) applied the same day, with the owner's choices on
remote members (D6) and one group per project (D2); approved by the
owner 2026-10-31.

## Evidence (2026-10-31)

| # | Point | Finding |
|---|---|---|
| E1 | Who a session can reach | Your own sessions only, one claude.ai login: on this machine, on your other machines and in the cloud, the last two through Remote Control; a session can start a conversation with one on another machine by name. A cloud session can't answer with SendMessage (its answer stays in its transcript); an `offline` one gets the message when it reconnects. No setting reaches another account ([cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging)) |
| E2 | Boxes reach each other | Only through Remote Control: a session in a container can't reach another container's socket (same page). Every peer `ListAgents` shows here is labelled `Remote Control`, so a session on another machine looks the same as one on this laptop |
| E3 | What autotake matches | box-workflow takes the sender from the `from-name` attribute of Claude Code's wrapper (`sender()` in [lines.ts](../../../core/plugin/box-workflow/hooks/lines.ts)), the session's name: `dev` names it after the project's folder (`--remote-control "$(basename …)"` in [dev](../../../dev)), and Remote Control may add a suffix (`claude-box-d2`, this session; the only example seen) |
| E4 | Autotake today | Per session and sender, only from you (`/autotake`); kept in the plugin's store, a file in `~/.claude` that Claude can write, so the next session only offers it back, and only when the session's list is empty ([register.tsx](../../../core/plugin/box-workflow/hooks/register.tsx)) |
| E5 | `dev new` today | Creates `~/Projects/<name>` (one folder level), commits a one-line `README.md`, offers project plugins ([dev](../../../dev)); `dev add` writes `.dev` lines |
| E6 | A pack's starter today | `project/starter/` is built into your layer and Claude copies any file of it a project lacks on a `claude/` branch ([starter.md](../../../plugins/workflow/rules/markdown.md)); `dev new` doesn't use it |
| E7 | Rules read at every start | 242 lines in the image's three rule files, against your limit of 200 (backlog item) |
| E8 | The box's description for auto mode | [managed-settings.json](../../../core/managed-settings.json) says the receiving box holds each message until you release it |
| E9 | Your projects | Three of your other projects each wrote a `CLAUDE.md` of the same shape by hand (what it is, Start of a session, Commands, Rules) |
| E10 | Handoff paths | The rules and box-workflow's toast name a sender's copy as `/projects/<sender>/out/handoff-…` ([box/company/CLAUDE.md](../../../core/rules/CLAUDE.md), [lines.ts](../../../core/plugin/box-workflow/hooks/lines.ts)): wrong for a project one folder deeper |
| E11 | Path-scoped rules | Rules in `~/.claude/rules/` take `paths:` frontmatter, matched from the session's working folder, and load when Claude reads or edits a matching file ([memory](https://code.claude.com/docs/en/memory)) |
| E12 | What `dev` takes as a project | Any folder in `~/Projects`, `.git` or not (`is_project` in [project.sh](../../../core/lib/project.sh)), so a group folder would start a box of its own |

## Decisions

| # | Topic | Decision | From |
|---|---|---|---|
| D1 | A folder group | Config kind `group <folder>` (under your `projects` folder, the config's path rules): every git repo directly in it is a member of the group named after the folder. Claude can't move folders on your laptop, so no question is asked. `dev` refuses a group folder as a project (E12) | the owner |
| D2 | A name group | `.dev` kind `group <name>`, written by `dev add group <name>`, for a project elsewhere. `dev` counts it only after your yes ("app-backend joins group app"), asked at the project's start with a terminal; without a terminal, or after no, it isn't a member and `dev` says so. Your yes is kept, by the project's path, beside the approved config in `~/.local/state/claude-box/approved/`, out of the box's reach. A folder group and a name group with the same name are one group. A project is in one group at most, so trust never chains from one group into another: `dev` refuses a second | the owner |
| D3 | Leaving | A project leaves when its `.dev` line or its folder goes; a kept yes for a project that's gone is ignored | the review |
| D4 | What the box gets | At each box start `dev` writes one file, mounted read-only at `/etc/claude-box/groups`: the project's group, each other member's name and its path under `/projects` (or `remote`, D6), and your trust line. A member added later appears in a running box after its restart. A scratch is in no group | the owner, E10 |
| D5 | Trust | Config kind `autotake group`: a member's message goes on as your prompt, as `/autotake <member>` would. box-workflow reads the members from `/etc/claude-box/groups` at session start, kept apart from the `/autotake` list, so they're never written to its store or offered back, and an offer of your own list still comes (E4). `/autotake off` turns both off for that session; `/autotake` alone lists the group's members beside your own. Without the line: as today | the owner, E4 |
| D6 | Remote members | Config kind `remote <group> <name>`: a project that lives only on another of your machines, a member by its session name, trusted like the others; its files aren't readable here, so it's asked, not read. Approved with your config like every line (E1: same account only) | the owner |
| D7 | Matching | A sender matches a member when its name is the member's, or the member's plus `-` and 1–4 lower-case letters or digits (E3). A miss is held, which is safe; a project named like a member plus a short suffix (`app-v2` for `app`) would match: a known limit, within your own account | E3, the review |
| D8 | Where members run | One rule for your sessions on this laptop, on other machines and in the cloud (E1, E2). The rules say a cloud session's answer is in its transcript, not a message | the owner, E1 |
| D9 | The default | `box/defaults.conf` documents `group`, `remote` and `autotake`; the starter config `dev init` writes has `autotake group`, which does nothing until you name a group. The README says in one sentence what it lets through and how to switch it off | the owner, the review |
| D10 | `dev new` | Copies the starter of each pack in your approved config into the new project, `{{name}}` replaced, writes `pack <name>` lines into `.dev`, commits ("Start <name>"), offers plugins. `dev new <folder>/<name>` works when `<folder>` is a group folder (D1). Project names stay unique across `~/Projects` ([accepted risk](../../system/architecture/README.md#accepted-risks)) | the owner, E5 |
| D11 | The workflow starter | `CLAUDE.md` with fixed sections: what the project owns (one paragraph, filled in at the first session), Start of a session, Commands, Rules, Neighbours' interfaces (links to the contracts it relies on; empty at first); `docs/direction/backlog.md`, `docs/system/architecture/README.md`, `docs/system/runbook.md`, `docs/change/`; `tests/run.sh` running `check_links.py`; `.gitignore` with `out/`. [starter.md](../../../plugins/workflow/rules/markdown.md) changes to: `dev new` lays the starter down; an existing project copies only `tests/check_links.py`, which the pack's rules rely on (E6) | the owner, E9 |
| D12 | Rules read at every start | A few lines in [box/company/CLAUDE.md](../../../core/rules/CLAUDE.md) beside the handoff rules: the group's members and their paths are in `/etc/claude-box/groups`, and a sender's copy of a handoff is at that path (E10; box-workflow's toast takes it from there too); a change to a neighbour's interface is told to it by a handoff; the project that provides a shared interface owns its contract, users link to it; a message let through by autotake is still another session's request, and one that needs no answer gets none. The inbox sentence and E8's description name autotake as the exception | the owner, E7, E10 |
| D13 | The layers' shape | A path-scoped rule in the workflow pack's global part, `layers.md`, with `paths` for `**/CLAUDE.md` and `.claude/rules/**`, so it loads whenever Claude reads or edits one (E11) and adds nothing at start: company holds the limits and the default way of working (never one project or you); global holds how you work across projects (company policy only linked, no project facts); project holds what it owns, its commands and rules, and links to the neighbours' interfaces it relies on. One fact, one layer; a lower layer narrows, never loosens; a project that works differently has one "Differs from the company default" line naming the rule it replaces. It names D11's sections, so the starter and the rule don't drift | the owner, E11 |
| D14 | Your global `CLAUDE.md` | Checked against D13 once; what's misplaced goes to `out/` as a draft for you | the owner |
| D15 | Existing projects | Unchanged; after the merge each project with a handoff gets a notice: groups, trust, and joining with `dev add group <name>` | the owner |

## Deliverables

Two branches, in order, each from the current `main`; each updates the
[architecture](../../system/architecture/README.md) (D7's known limit
included), the [runbook](../../system/runbook.md) and the README where
it changes what they describe.

**1. `claude/groups`:** D1–D9 and D12: `dev`'s `group`, `remote` and
`autotake` kinds, `dev add group`, the question and the kept yes, the
refusals (a group folder as a project, a second group),
`/etc/claude-box/groups` and its mount; box-workflow's group autotake,
its listing and the handoff path in its toast; the rule lines and E8's
description; `box/defaults.conf`, the starter config and the README
sentence. Tests: `tests/test_dev.sh` for the folder group, the name
group with yes, no and no terminal, a second group refused, a group
folder refused, a member gone, a remote member, and the file's
content; `inbox.test.ts` for a member taken, a non-member held, D7's
suffix rule, `/autotake off`, members never written to the store, and
your own list still offered back.

**2. `claude/new-skeleton`:** D10, D11, D13, D14: `dev new` laying
down the starters and `<folder>/<name>`; the workflow starter's files
and `starter.md`'s change; the `layers.md` rule; the draft of your
global `CLAUDE.md` in `out/` if D14 finds anything. Tests:
`tests/test_dev.sh` for a new project's files, `.dev` and the
substitution, and that `tests/run.sh` passes in a fresh project.

## Acceptance

- Each of the intent's criteria, with its evidence.
- A `dev run` makes three projects with `dev new` in a group folder
  under a temporary projects folder (`DEV_PROJECTS`), leaving
  `~/Projects` as it was, and shows their files and groups file.
- By hand, since sessions need your login: you start the three boxes,
  one messages another and it's taken without `/autotake`; a message
  from a project outside the group is held. You note what the toasts
  said.
- D15's notices sent and logged.
- No open finding left only in this folder.

## Related backlog items

- *Every session starts with under 200 lines of rules*: D12 adds a few
  lines; D13 loads only where it applies.
- *A new user sets up, updates and leaves claude-box from the README
  alone*: its stranger test covers the starter config, which gains D9's
  line.

## Acceptance results (2026-11-16)

On `main` 7b6d1dd, after the simpler-model milestone, whose model
replaced this spec's D10 and D13. Evidence:
[acceptance-dev-new.log](acceptance-dev-new.log) and
[acceptance-sessions.md](acceptance-sessions.md).

| Criterion | Result | Evidence |
|---|---|---|
| `dev new` lays down the default | Met | [acceptance-dev-new.log](acceptance-dev-new.log): three projects in `~/Projects/demo-app`, each with the workflow plugin's starter (`CLAUDE.md`, `docs/` direction, system and change, `tests/`, `.gitignore`) in one clean commit "Start <name>"; app-backend's `tests/run.sh` passes. Since the simpler model, the starter comes from each `plugin` line of your config, and no `pack` line is written |
| A group: a folder, or one `.dev` line after your yes, never Claude's; a remote member; one group at most | Met in the tests; the folder in a real box | The demo-app folder made one group ([sessions](acceptance-sessions.md)). `test_dev.sh`: `group-name-yes`, `group-name-no` (Enter, no, or no terminal: not counted), `group-folder` (remote members), `group-two`, `dev-group` (one group per project) |
| Each box knows its members and reads them in their own files | Met | [acceptance-sessions.md](acceptance-sessions.md): `/etc/claude-box/groups` in app-backend and app-frontend; app-backend read app-frontend's README through `/projects/demo-app/` |
| With trust on, a member is taken; others are held; Claude can't widen it | Met; other machines not run | [acceptance-sessions.md](acceptance-sessions.md), second try: app-backend's message "let through by your autotake group", claude-box's held. `inbox.test.ts`: `/autotake` not typed by the owner is refused. A member on another machine: not run, no second machine; the remote member is in `test_dev.sh` (`group-folder`) |
| What belongs at each level, written once; your global `CLAUDE.md` checked | Met, as the simpler model replaced it | Two levels, not three: core's [levels.md](../../../core/rules/levels.md) and the workflow plugin's [claude-md.md](../../../plugins/workflow/rules/claude-md.md) (the shape of a project's `CLAUDE.md`, checked against the starter by `tests/run.sh`). D14's draft of your global `CLAUDE.md` was overtaken by the instructions review (2026-11-01) |
| Three projects from `dev new` message each other, taken without `/autotake` | Met, at the second try | [acceptance-sessions.md](acceptance-sessions.md): at the first try every sender was let through, which proves nothing about the group; app-frontend, restarted with autotake left off, took app-backend's message by the group's trust and replied |
| The repo goes public only after this | Met | Still private; the flip is the publishing milestone's |

**Deviations:** the projects were made in `~/Projects/demo-app` by the
owner (`dev new` three times), not by a `dev run` under a temporary
`DEV_PROJECTS`: the run-file rules keep `dev` out of `dev run`, and your
config names `~/Projects/demo-app` as the group. The held row wasn't
seen; the transcript shows the message never reached Claude. D15's
notices went out only now, 2026-11-16, to the three projects with a
handoff (logged in claude-box's `out/`).

**Version check:** as in the simpler-model results of 2026-11-15
(`fedora:44`, Fedora 45 a backlog item; Claude Code unpinned).

**Left over:** a member on another machine stays untested until there
is one. `~/Projects/demo-app` and its `group` line stay for now: the
[backlog](../../direction/backlog.md) item on a project's marketplace
plugin names demo-app as its test project.
