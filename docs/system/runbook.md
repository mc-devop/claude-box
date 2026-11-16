# Runbook

How to set up, use, change, reset and remove claude-box. Steps only; the facts
they rely on are in the [architecture](architecture/README.md).

## Set up

1. The Quick start in the [README](../../README.md#quick-start):
   `./dev install` links `dev`, then runs `dev init`.
2. `dev init` asks Claude's git identity (Enter keeps
   `Claude <claude@claude-box.invalid>`) and writes `~/.claude/.dev`
   with it, `plugin workflow` and `autotake group`; one you have stays.
3. It builds the image and shows a URL: open it in your browser, log
   in, then type `/exit`.
4. Start `dev claude` in the clone and ask Claude to set you up.

## Update claude-box

1. `dev update`: it fetches, lists the commits coming to `main`, and
   moves `main` forward (fast-forward only) after your yes, even with
   another branch checked out.
2. The next `dev claude` shows which core files changed and rebuilds
   the image after your yes, and shows a changed plugin of this repo
   like any change to your config.

## Set up your config

Your settings live in `~/.claude/.dev`; each line is explained in
[core/defaults.dev](../../core/defaults.dev).

1. `dev init` writes `~/.claude/.dev` when there's none; edit it
   (e.g. `identity`, `memory 8g`), or ask Claude to.
2. Bring things in with `plugin` and `rules` lines: the repo's
   [plugins](architecture/README.md#plugins) by name (`plugin workflow`),
   your own plugins, skills and rules files under `~/.claude`
   (`rules ~/.claude/style.md`), pinned URLs, and marketplace plugins. The
   pinned Karpathy guidelines are in
   [core/defaults.dev](../../core/defaults.dev): copy the line if you want them.
3. The next `dev claude` or `dev shell` shows the change and asks
   `Apply it? [Y/n]`; Enter builds your layer, then it offers to install
   the marketplace plugins that aren't installed yet.

Back it up yourself (e.g. with your dotfiles), with the files it names.

## Change your config

Edit `~/.claude/.dev` or a file it names (or let Claude edit them). The
next box start shows the difference to what you approved last and asks;
`n`, or no terminal, starts on the approved version. A running box keeps
its config until its last session ends. Without `~/.claude/.dev`, `dev`
uses the defaults.

## Work in a project

- New project: `dev new <name>` creates `~/Projects/<name>` with the
  starter of each plugin in your approved config (the workflow plugin's:
  `CLAUDE.md`, `docs/`, `tests/run.sh`, `.gitignore`), all in its first
  commit. `dev new <group folder>/<name>` makes it in a
  group folder of your config ([groups](#make-a-group)). Claude writes
  the `CLAUDE.md`'s first paragraph at the first session.
- Existing project: `cd` into its top folder, then `dev claude`
  (options after `claude` go to Claude, e.g. `dev claude --continue`).
- In Zed: start an agent thread with `dev claude`; run `dev run` in its
  terminal.
- A project has one box: every `dev claude` and `dev shell` in it joins
  the running one, so a shell sees what Claude runs. The box ends when
  its last session does. `.dev` changes, ports and caps apply when a box
  starts, so quit every session first, or use `--new` (`dev shell
  --new`, `dev claude --new --continue`): a box of its own, ending with
  that session.
- A box that doesn't end (something it started still runs): `podman ps`
  lists `claude-box-<name>`; `podman rm -f claude-box-<name>` ends it,
  and every session in it.
- `out/` shows what's waiting on you: `dev run`'s files, the handoffs,
  and drafts not used yet. A used draft goes to `out/done/<date>/` and
  is deleted 14 days later, when a session starts; to keep one, move it
  out of `done/` first.

## Work without a project

For a one-off job, e.g. finding a hardware fault on the laptop.

- Start: `dev claude` in any folder that's not a project (no `.git`, not
  in `~/Projects`), e.g. `~`. It prints the session's name
  (`Scratch session brave-otter: …`) and writes nothing where you are.
  Claude Code asks once whether to trust the new folder.
- Run Claude's steps: `dev run --scratch <name>`, from any folder.
- Come back (after a reboot too): `dev claude --scratch <name>` carries
  on with the last conversation, unless a session of it still runs: then
  it says so and starts a new one (add `--continue` to resume anyway); `dev claude --scratch` without a name lists them and
  asks for a number.
- List: `dev scratch` (name, last used, topic from Claude's notes).
- Delete: `dev scratch --rm <name>` (asks first; its box must have
  ended).
- When Claude suggests a project: `dev new <name>`, then `dev claude`
  there; it reads the scratch's notes from `~/.claude/scratch/<name>/`.

## Hand a change to another project

- Claude writes the prompt into `out/handoff-<project>.md` and, if that
  project's box is running, sends it there. Start the other box with
  `dev claude` in its folder first if you want it delivered.
- In the receiving box, the row above the prompt lists it: **Read**,
  then **Take it** puts it in the prompt box; read it, add to it, press
  Enter. **Dismiss** drops it.
- On the phone the row shows but its buttons don't act: type `/take 1`
  (sends message 1 on as your prompt) or `/dismiss 1`; without a number,
  the oldest. Type it in the session's own input: the card the phone app
  shows for a message between sessions is Remote Control's, not the
  inbox, and its reply box doesn't reach either session.
- To let a session's messages through while the receiving one is idle:
  type `/autotake <sender>` there (the sender's project name, e.g.
  `/autotake alpha`); each message from it then goes on as your
  prompt, no Enter needed. `/autotake on` does it for every session.
  `/autotake off` holds them again; `/autotake`
  alone lists who's let through. The next session of the project
  offers it back in a row: **Restore** or **Leave off** (on the phone,
  type `/autotake` again); until you choose, it holds messages.
- A message lost (the box closed before you took it): the sender's copy
  is in the sender's `out/handoff-<project>.md`, under `/projects/` in
  the box; tell Claude to read it.
- A box's session is named after its folder; when an older session
  holds that name, Remote Control adds a suffix (`beta-ac`), new
  on every restart, and ListAgents may show the conversation's title
  instead. So Claude answers to the message's own sender address
  (`bridge:session_…`), which stays when a box restarts with
  `dev claude --continue`. A first message, or one whose address went
  stale (HTTP 409: a restart without `--continue`), goes to the one session
  ListAgents shows by project name. When none or several match, it
  sends nothing and says so: paste from `out/`. A
  message sent while the other box is down is lost without an error:
  if you restarted a box during an exchange, ask its Claude to read the
  other side's `out/handoff-<project>.md`.
- Every message, both ways, is added to the sender's
  `out/handoff-<project>.md`, dated, with the address it went to: the
  whole exchange, also for a session that restarted and forgot it.
- Remote Control not connecting (offline, logged out): the box works,
  but nothing reaches it; paste the prompt from `out/` as before.

## Make a group

Projects in a group know each other, and with `autotake group` in your
config (the one `dev init` writes has it) their messages go on as your
prompt; every other session's are held as before.

- A folder of projects: add `group ~/Projects/<folder>` to your config.
  Every git repo directly in it whose name has letters, digits, `. _ -`
  only is a member; the folder itself isn't a project (`dev` refuses to
  start there), and it may not lie inside a repo, where a box could add
  members.
- A project elsewhere in `~/Projects`: `dev add group <name>` in it; the
  next time its box starts, `dev` asks whether it counts in (Enter is
  no: Claude can write that line). A project is in one group.
- A project only on another machine: `remote <group> <name>` (its
  session name) in your config.
- A member added later shows in a running box only once that box
  starts anew (its last session ended, or `dev claude --new`); joining
  a running box changes nothing.
  `/autotake off` holds the group's messages too for that session;
  `/autotake` lists who's let through.

## Add tools to a project

From the project's top folder, e.g. `dev add dnf jq`, `dev add npm
cowsay`, `dev add pip pyfiglet`,
`dev add plugin c4m@c4-model-skill cheriftj/c4-model-skill` (`dev remove`
likewise); or edit `.dev`. The next `dev claude` shows the
change and asks; it asks only in a terminal. Commit `.dev`.

### Move a project's plugins into `.dev`

A project set up before `.dev` has its plugins in
`.claude/settings.json` (`enabledPlugins`). Add each to `.dev`
(`dev add plugin <name>@<marketplace> <owner/repo>`), remove `enabledPlugins` from
`.claude/settings.json`, commit, then `dev claude` and answer y.

## Open a project's web app on the laptop

From the project's top folder, e.g. `dev add port 2718` (or a
`port 2718` line in `.dev`); commit `.dev`. The next `dev claude` or
`dev shell` publishes it; nothing is installed or rebuilt. In the box,
start the app listening on `0.0.0.0` (e.g. `marimo run --host 0.0.0.0
--port 2718 app.py`), then open `http://localhost:2718` on the laptop.
Many apps listen on `127.0.0.1` by default (marimo does), which only the
box itself reaches: the browser then shows a reset connection
(`ERR_SOCKET_NOT_CONNECTED`).
Every session in the project's box reaches it. A `--new` box says
`Port 2718 not published to this box` and starts without it.

## Cap the box's memory and CPU

In your config, e.g. `memory 8g` and `cpus 10`
([set up](#set-up-your-config)); remove them to uncap. `DEV_MEMORY` and
`DEV_CPUS` in your shell override them. Check in a new
box: `dev shell --new`, then `cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max`
(`max` means uncapped).

## Run Claude's steps

When Claude says so, from the project's top folder: `dev run`. Read the
steps it shows, then Enter. When the run ends, Claude is told and reads
`out/actions.log` itself; after an abort it fixes the file, and the next `dev run` continues
where it stopped. `dev run --force` runs every step again, and runs a step
that installs on your machine, which plain `dev run` refuses.

## Change your setup

- Your `~/.claude/.dev`, a file it names, or a project's `.dev`: edit
  it (or let Claude). The next box start shows the difference and asks.
- Core ([core/](../../core/)) or a plugin of this repo
  ([plugins/workflow/](../../plugins/workflow/)): change it on a
  branch here and merge to `main`. The next `dev claude` shows the
  change and applies it after your yes; no `dev build`. A branch you
  have checked out never reaches a box.
- An existing project copies a plugin's starter files on a `claude/`
  branch.

A project's box keeps the old setup until its last session ends: quit
every `dev claude` and `dev shell` in it, then start again.

## Change Claude's own instructions

Edit `~/.claude` in your editor (e.g. `~/.claude/CLAUDE.md`,
`~/.claude/settings.json`). Claude drafts changes in the project's
`out/` for you to copy in.

## Update Claude Code

`dev build`. A project's box keeps the old version until its last
session ends: quit every `dev claude` and `dev shell` in it, then start
again.

## Plugins

- For all projects: `plugin <name>@<marketplace> <owner/repo>` in
  `~/.claude/.dev`; the next `dev claude` fetches it, shows its version
  and commit, and builds it into your layer after your yes. Taking the
  line out takes it out of the image the same way.
- For this project: `dev add plugin <name>@<marketplace> <owner/repo>` from
  its top folder; the next `dev claude` does the same for its image.
- To remove one from a project: `dev remove plugin <name>@<marketplace>`,
  then `dev claude`.
- A plugin update: when its upstream has new commits, `dev claude` shows
  them and rebuilds after your yes. There's no `/plugin` update in the
  box: Claude Code can't write to the image.
- A plugin or rules file of yours for this project only: `dev add plugin
  ~/.claude/<folder>` or `dev add rules ~/.claude/<file>.md`; the next
  `dev claude` shows it with its files and applies it after your yes. A
  name already in `~/.claude/.dev` is refused: one level only.

## Develop claude-box

Before every commit: `tests/run.sh` (Markdown links, `dev`, run-actions,
ShellCheck; the box's plugin only where `claude` is installed, so run it
in the box too).

`tests/private-terms` is a file for developing claude-box, kept out of
git, not part of a
user's setup: names that must never reach the public repo, one Python
regex per line, a line starting with `#` is a comment, matched
case-insensitively.
`tests/run.sh` fails when a tracked file holds one, and skips the check
without the file.

## Reset

`dev reset` removes the images (the base, your layer and every
project's), the copy of your config you approved, and the projects' boxes, ending every session in them. Your
project folders and `~/.claude` stay; to remove Claude's login, settings, plugins and memory too:
`rm -rf ~/.claude`.
Start again with `dev init`.

## Remove claude-box

1. `dev uninstall`: after your yes, it removes what `dev reset` does,
   dev's state (`~/.local/state/claude-box/`) and the `~/.local/bin/dev`
   link `./dev install` made (a link to another clone stays).
2. Your project folders, `~/.claude` and the clone stay: remove the
   clone with `rm -rf <clone>`, and Claude's login, settings, plugins,
   memory and scratch sessions with `rm -rf ~/.claude`.
