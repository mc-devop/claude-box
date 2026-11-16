# Architecture

What claude-box is, right now. Procedures are in the
[runbook](../runbook.md); where it's going is in the
[vision](../../direction/vision.md) and [backlog](../../direction/backlog.md).

The pictures are C4 views, drawn as small Mermaid flowcharts:

| View | Shows |
|---|---|
| [01-context.md](01-context.md) | claude-box, you, and the systems around it |
| [02-container.md](02-container.md) | Its parts: `dev`, `dev run`, the box, and the data they use |
| [03-deployment.md](03-deployment.md) | Where they run on your laptop, the image, and what the box has mounted |

Facts about an element are in the tables below its view's diagram.

### Reading the diagrams

An arrow points from the side that starts it (the request, the
connection, the action), and "from – label – to" reads as a sentence:
*the box – sends model requests to – the Claude API*. Data may flow both
ways along one arrow; the arrow says who starts. Dashed means planned.

## In one sentence

Claude Code runs in a rootless Podman container, started by `dev` from
the top folder of one project, that sees that project read-write, your
other projects read-only and your `~/.claude` as its home, and nothing
else of yours;
whatever needs your rights, Claude writes into `out/actions.txt` and you
run it with `dev run`.

## Who changes what

| Who | Changes | How |
|---|---|---|
| Claude, in the box | Files in the one project it was started in; commits to `claude/<topic>` branches | Directly |
| Claude, for other projects | Nothing: it reads them | Writes a prompt for that project's own Claude session and sends it there when that session runs (an answer to the sender's own address, which survives a restart with `--continue`; a first message, or one whose address went stale, by project name); every message both ways is added to the sender's `out/handoff-<project>.md`; the receiving box holds it until you take it, or your autotake lets its sender through |
| Claude, for anything else | Your machine, your servers, its own instructions and settings | Writes the change (a script, `out/actions.txt` steps, a draft) for you to review and run |
| You | Merging, pushing, running scripts, core and the plugins of this repo | `git merge --no-ff` and the rest as `dev run` steps; a merge to `main` reaches the boxes at the next `dev claude`, after your yes (the image and the plugins come from `main`, never from a checked-out branch) |

Anything Claude writes that you run (scripts, Makefiles, Containerfiles,
deploy files, editor settings) runs as you: the rules make Claude point
these out, and your review is the gate.

## Levels

Two levels are yours, global and project, each with a `CLAUDE.md` (how
Claude works) and a `.dev` (what's in the box); core's rules load
underneath both. In Claude Code's scopes: core is managed policy, global
is user, project is project. All are read at every start:

| Level | File | Where it lives | Who can change it |
|---|---|---|---|
| The box's own rules | [core/rules/](../../../core/rules/): the environment, branches and evidence, the levels; the `dev run` format in the skill [box-workflow:dev-run](../../../core/plugin/box-workflow/skills/dev-run/SKILL.md), loaded when Claude writes `out/actions.txt`, and messages between sessions in [box-workflow:handoff](../../../core/plugin/box-workflow/skills/handoff/SKILL.md) ([core/README.md](../../../core/README.md)) | `/etc/claude-code/` in the image, owned by root; `CLAUDE.md` there imports the others | You: edit here, then `dev build` |
| Global: rules you bring in | The rules files your `~/.claude/.dev` names (`rules ~/.claude/<file>.md`, `rules https://…/<commit>/<file>.md`) and the `rules/` of each plugin it names | Read-only under `~/.claude/rules/files/` and `~/.claude/rules/<plugin>/` in every box, from the approved copy ([mounts](03-deployment.md#mounts)) | You: edit `~/.claude/.dev` or the files; `dev` shows the change, also one a pull brings to a plugin you use, and applies it after your yes |
| Global: ways of working | `~/.claude/CLAUDE.md`, and your own `~/.claude/rules/` | Your `~/.claude`, Claude's home | You, in your editor; auto mode blocks Claude from changing it (self-modification), so it drafts changes in `out/` |
| Project | The project's `CLAUDE.md` and `.claude/rules/` | The project | As any project file |

Auto mode's classifier reads the same three levels, and its environment
(what's trusted, what's sensitive) from three places: the box, from the
image's [managed-settings.json](../../../core/managed-settings.json)
(Host containment); all projects, from `autoMode` in your
`~/.claude/settings.json`; one project, from its `CLAUDE.md`. Claude Code
ignores `autoMode` in a project's `.claude/settings*.json`, so a repo
can't give itself allow rules.

## Plugins

Everything optional is brought in with a `plugin` or `rules` line
([core/defaults.dev](../../../core/defaults.dev) lists the values), the
same at both levels: in `~/.claude/.dev` it reaches every project, in a
project's `.dev` that project's boxes. Nothing reaches a box before it's
shown and approved: yours against the copy in
`~/.local/state/claude-box/approved/`, a project's against its own copy
in `~/.local/state/claude-box/projects/<folder>-<hash of its path>/approved/`. A name
can be at one level only. A source under `~/.claude` holds no
links: any box can write there, so `dev` refuses a link rather than
follow it, also one that appears while it copies:

| Line | Where it lands |
|---|---|
| `plugin <name>` (in the clone's [plugins/](../../../plugins/), from `main`) or `plugin ~/.claude/<folder>` (a plugin or skill folder) | Built into the image: yours into your layer ([deployment](03-deployment.md#your-layer)), a project's into its image; loaded by every session there. Its `rules/`, if any, mounted read-only at `~/.claude/rules/<name>/`; its `starter/`, if any, laid down by `dev new` (yours only) |
| `plugin <name>@<marketplace> <owner/repo>` | Built into the image the same way, as a Claude Code seed: Claude Code fetches it in a throwaway box that sees only the seed, `dev` shows its version and commit and keeps it in the approved copy after your yes, and every session there has it switched on ([seeds](03-deployment.md#plugins)). `dev claude` checks its upstream for new commits at every start |
| `rules ~/.claude/<file>.md` or `rules https://…/<commit>/<file>.md` | Mounted read-only at `~/.claude/rules/files/<file>` |

A plugin's dependencies (`plugin.json`'s `dependencies`) go into the
same level's seed when its `metadata.claude-box.marketplaces` names
their marketplace's repo; otherwise `dev` names the line to add. A project's
own rules and skills go in its `.claude/rules/` and `.claude/skills/`.

| Plugin | What it adds |
|---|---|
| [workflow](../../../plugins/workflow/README.md) | Documents in three families, where superpowers writes a change's records, links and diagrams, a project's `CLAUDE.md` sections, the closing skill and the starter `dev new` lays down; it brings superpowers. Its parts: [its map](../../../plugins/workflow/README.md#map) |

### The box's own plugin

[core/plugin/box-workflow](../../../core/plugin/box-workflow/) is built into the image,
owned by root, and loaded by every session through
`CLAUDE_CODE_PLUGIN_DIRS`; a session can't change or switch it off, and
nothing of it is in your `~/.claude`.

| Part | What you see |
|---|---|
| Inbox | A delivery from another session is held, never read by Claude: a toast, and a numbered row above the prompt with **Read**, **Take it** (into your prompt box; your Enter sends it) and **Dismiss**; on the phone, where the buttons don't act, `/take [n]` sends it on as your prompt and `/dismiss [n]` drops it, and only you can run them (typed at the terminal or through Remote Control). `/autotake <sender>`, also only yours, lets that sender's messages (named by the wrapper Claude Code puts around them, not by their text) go on as your prompt, once the session is idle, until `/autotake off`; `/autotake on` does it for every sender; `/autotake` alone lists who's let through. It's kept for the project (in the plugin's store, a file in `~/.claude`); since Claude can write that file, the next session only offers it back, in a row with **Restore** and **Leave off**, and holds messages until you press one (on the phone, type `/autotake` again). With `autotake group` in your config, a member of the project's group (from `/etc/claude-box/groups`, which `dev` mounts read-only; its name, or it plus `-` and 1–4 of `a-z0-9`) goes on as your prompt too, beside that list: never stored, never offered back, held again after `/autotake off` for that session, and listed by `/autotake` ([groups](../runbook.md#make-a-group)). Only the session's own subagents and your own channels (Remote Control, task notifications, scheduled tasks, Slack pings) pass; anything else, unknown kinds too, is held, and another session's message reaching the prompt any other way is dropped. Held messages last as long as the session; if holding fails, the message is refused |
| `dev run` | A row above the prompt while `out/actions.txt` has steps to run; a toast when a run passes or aborts, and a prompt telling Claude to read `out/actions.log` and carry on (title and step only, not the log's text); a toast with the first mistake `run-actions --check` finds after Claude writes the file |
| Branch | The status line: the branch, marked on `main`, and how far a branch is behind local `main` |
| `out/done/` | Nothing: at session start, folders in `out/done/` named by a date more than 14 days ago are deleted |

## `dev run`

[run-actions](../../../core/bin/run-actions) runs the steps Claude wrote to
`out/actions.txt`; the file format is at its top.

- It shows every step and asks once (Enter = yes).
- `local` steps run on your laptop, as you. `root` and `host` steps run
  on the server named in the file, one SSH session per group of them in a
  row: sudo asks for your password once per group and forgets it at the
  group's end (`sudo -k`), so a `local` step between them means a second
  prompt; each asks again
  before it runs (Enter = yes, `s` = skip, `n` = stop). The password
  never passes through the script or Claude.
- It refuses the whole file if a `local` or `root` step could print a
  secret (Podman secret values or storage, environment dumps,
  `podman inspect` without `--format`, token or key files, shell
  history), since the output goes to the log and to Claude. It also
  refuses a `local` step that installs software on your laptop
  (`curl … | sh`, pip, pipx, `npm -g`, dnf, rpm-ostree, brew, cargo,
  `uv tool`): a tool a project needs goes into its `.dev`. With
  `--force` it only warns, for an install you mean (e.g. on the
  laptop a project provisions).
- It aborts at the first failure, error or warning line, missing expected
  output, or new SELinux denial on the server.
- It never runs a step twice: steps that succeeded are recorded in
  `out/actions.done` under the file's title and the command; a file that
  keeps its title continues where it stopped. `--force` runs everything.
- Everything shown is saved to `out/actions.log`, which Claude reads.
- In a folder without `.git` (a scratch session, `dev run --scratch
  <name>`) it skips the `.gitignore` check and refuses `host` steps,
  whose scripts come from `main`; `local` and `root` steps run as in a
  project.
- Two modes only read, for the box's plugin: `--check` reports the
  file's mistakes (no `>` above a step, `>`, `expect` or `allow` lines
  after the last step, a `dev` command in a step, `out/` not in
  `.gitignore`, and the refusals above) and runs nothing;
  `--status` prints the job's title, steps not yet run, and the last
  run's result.

## Known limits

What the box doesn't prevent. Each stays as it is until the
[backlog](../../direction/backlog.md) says otherwise.

- **Anything under the project's `.git`, and any nested `.git`, can make
  your git run code as you**: hooks, config, a `.git/commondir` that
  points git at other config and hooks, submodules' config and hooks.
  The rules forbid Claude to touch them; nothing enforces it.
  Check them if in doubt, and don't run git in a folder Claude made a
  repo.
- **Claude is asked before editing your `~/.claude/` files only in its
  own tools.** Core's managed settings ask before every edit of
  `~/.claude/CLAUDE.md`, `.dev`, `rules/` and `settings.json`, also in
  auto mode, through the Edit and Write tools, the file commands Claude
  Code recognizes in Bash, and redirects. A script that writes those
  files itself (Python, Node) isn't covered; a change to `.dev` still
  waits for your yes at the next `dev claude`. The prompt's second
  answer, "Yes, and allow Claude to edit files in its ~/.claude folder
  for this session", stops the asking for the rest of that session.
- **A box working in the claude-box clone can move its `main`** without
  a merge (`git branch -f`, `git fetch . x:main`): the commit hook only
  checks `git commit`. The next `dev claude` then asks to rebuild, and
  lists the commits since the image was built, so you see what you'd
  approve; check them before your yes.
- **`dev` and `run-actions` run from the clone's checked-out files.**
  The image and the plugins come from `main`, but with a branch checked
  out in the clone, `dev` itself and `dev run` are that branch's
  ([backlog](../../direction/backlog.md)).
- **Secrets lying in `~/Projects`** (a `.env`, a key file) are readable
  in the box.
- **A plugin's state is writable from every box**: Claude Code's
  `~/.claude/plugins/data/<plugin>/` (`${CLAUDE_PLUGIN_DATA}`) and
  `~/.claude/plugins/store/` (a mod's key-value store), the only parts of
  your `~/.claude/plugins/` a box sees; the rest of the box's plugins
  folder is its own, gone with it
  ([checked](../../change/2026-11-01-plugins-in-image/findings-plugins-dir-checks.md)).
  The plugin's code is in the image.
- **`dev` and `core/defaults.dev` are read from the clone's working
  tree**, so a change Claude makes there while working on claude-box
  runs as you before it's merged; your own config, `~/.claude/.dev`, and
  the plugins and files it names are shown and confirmed first.
- **The network is open**: the box reaches the internet (it needs the
  Claude API). Services on your laptop's localhost aren't reachable by
  default.
- **A session named like a group member plus a short suffix is taken as
  that member** (`app-v2` for member `app`), within your own account
  only. A member whose session Remote Control names otherwise (its
  conversation's title) is held, as any other session.

## Accepted risks

Your decisions, recorded so they aren't re-argued; no action planned.

- **Any box can propose a change to your `~/.claude/.dev`** (it's in
  Claude's home). Accepted because nothing applies without your yes at
  a terminal, at the next `dev claude`, after you've seen the diff
  (2026-10-31).

- **`out/actions.done` and the handoffs only grow**, slowly (tens of
  kilobytes a month). Accepted because trimming `actions.done` would let
  `dev run` rerun steps that passed, and trimming a handoff would cut
  history other sessions read (2026-10-17).

- **The last session exiting 125 or 255 as its box ends starts a new
  box** and runs the command again: `dev` reads those as Podman's
  "the box ended as I joined it". Accepted because Claude and bash
  don't exit with these on their own, and ending that session ends it
  (2026-10-23).
- **`dev shell | tee log` can't take typing**: with stdin a terminal
  and stdout a pipe, the box's command gets no stdin, so `dev claude -p
  … | x` doesn't wait 3 s for it. Accepted as an odd use (2026-10-23).
- **`dev help` fails in a deleted folder.** Accepted because `cd` into
  a real folder fixes it (2026-10-23).
- **The box's user is you** (`--userns=keep-id`), so an escape from it
  runs with your UID. Accepted because SELinux keeps the box's domain,
  `container_t`, out of your home and `~/.ssh` (checked on the laptop),
  so a container runtime escape reaches only what the box already
  sees; a kernel escape gets past any UID. A separate UID stays an
  option for git's ownership check (2026-10-02).
- **The box writes into `~/.claude`**, the folder a Claude Code on your
  laptop would read and follow (its settings, hooks, plugins). Accepted
  because the laptop runs none and Zed goes through the box
  (2026-09-30).
  So: use Claude only through `dev claude`, including in Zed; never
  install Claude Code on the laptop. `dev run --scratch` does run a file
  from it: see the next risk.
- **A scratch's steps can come from any box**: every box can write
  `~/.claude/scratch/<name>/out/actions.txt`, so another project's
  Claude could put steps there. Accepted because `dev run` shows every
  step with its explanation and runs nothing before you say yes; read
  them as you would a project's. A link in `~/.claude/scratch` (the
  folder, or a scratch in it) could point `dev` at another of your
  folders, to mount or delete: `dev` refuses links there (2026-10-24).
- **Claude can enable a project's plugins without the question**: it can
  write the project's `.claude/settings.json` or `settings.local.json`,
  and Claude Code installs what they name into the box's own plugins
  folder, for that box's life; the question in `dev claude` guards only
  what `dev` builds into the image (2026-10-01; the box's own folder
  since 2026-11-03).
- **Projects with the same folder name share memory and sessions**:
  Claude Code names a project's folder in `~/.claude/projects/` after
  `/work/<name>`, every character but letters and digits turned into
  `-`, so `app` in two places, or `my.app` and `my-app`, end up in one.
  Accepted because everything under `~/Projects` has its own name
  (2026-09-30).
  A project folder named `scratch-<name>` would share them with that
  scratch session (and its box's name; the label check refuses joining
  the other's box).
- **Every box can be driven from claude.ai**: `dev claude` turns on
  Remote Control, so anyone with your claude.ai login can send prompts
  to a running box, as you can from your phone. Accepted so sessions
  reach each other by name without a step per box (2026-10-07).
