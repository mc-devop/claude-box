# Level 2 — Container — claude-box

> **Diagram type**: Container
> **Scope**: claude-box's parts and the data they use. "Container" in
> the C4 sense: a separately running program or data store.

## Diagram

```mermaid
flowchart TD
  owner["<b>Owner</b><br/>[Person]"]

  subgraph system["claude-box"]
    dev["<b>dev</b><br/>[Bash, on the laptop]<br/>Builds, starts the box"]
    run["<b>dev run</b><br/>[Bash, on the laptop]<br/>Runs Claude's steps as you"]
    box["<b>The box</b><br/>[Podman container]<br/>Claude Code"]
    home[("<b>Claude's home</b><br/>[Folder: ~/.claude]<br/>Login, settings, memory")]
    project[("<b>The project</b><br/>[Folder]<br/>Files, .git, out/")]
    scratch[("<b>A scratch</b><br/>[Folder: ~/.claude/scratch/name]<br/>out/, notes.md")]
    projects[("<b>Your other projects</b><br/>[Folder, read-only]")]
  end

  api["<b>Claude API</b><br/>[External]"]
  rc["<b>Remote Control</b><br/>[External: claude.ai]<br/>Your other sessions, your phone"]
  servers["<b>Your servers and git remotes</b><br/>[External]"]

  owner -- "runs" --> dev
  owner -- "runs" --> run
  dev -- "starts" --> box
  box -- "keeps its state in" --> home
  box -- "edits, commits,<br/>writes out/actions.txt in" --> project
  box -- "writes out/actions.txt,<br/>notes.md in" --> scratch
  box -- "reads" --> projects
  box -- "sends model requests to<br/>[HTTPS]" --> api
  box -- "connects, under the<br/>project's name, to [HTTPS]" --> rc
  run -- "reads out/actions.txt,<br/>writes the log in" --> project
  run -- "reads out/actions.txt,<br/>writes the log in" --> scratch
  run -- "runs steps on<br/>[SSH, git]" --> servers

  classDef person fill:#08427b,stroke:#052e56,color:#fff
  classDef container fill:#438dd5,stroke:#2e6295,color:#fff
  classDef external fill:#999999,stroke:#6b6b6b,color:#fff
  class owner person
  class dev,run,box,home,project,scratch,projects container
  class api,rc,servers external
```

## Elements

| Element | Type | Technology | Responsibility |
|---|---|---|---|
| dev | Container | [dev](../../../dev) (Bash), on your `PATH` through `./dev install`; its parts in [core/lib/](../../../core/lib/) | The one command: reads your config and, after your yes to a change, builds it as your layer; builds the images, starts the project's box or joins the running one (a project is a repo's top folder or a folder in `~/Projects`, never `$HOME` or `/`; `dev claude` with Remote Control under the folder's name); outside a project, `dev claude` starts a scratch session, and `dev claude --scratch`, `dev scratch` and `dev run --scratch` come back to, list, delete and run one; installs what the project's `.dev` lists after asking, creates projects, hands `dev run` to run-actions |
| dev run | Container | [run-actions](../../../core/bin/run-actions) (Bash) | Runs `out/actions.txt` as you: [how](README.md#dev-run) |
| The box | Container | The `localhost/claude-box` image ([Containerfile](../../../core/Containerfile)): Claude Code (its version set by `dev build`), git, ripgrep, `ps`, ShellCheck, `diff`, `patch`; or, for a project whose `.dev` lists packages, its own image built on it ([how](03-deployment.md#the-image)); [stage-seed](../../../core/bin/stage-seed) stages marketplace plugins into a seed, in a throwaway box; the box's own plugin, [box-workflow](README.md#the-boxs-own-plugin), and [run-actions](../../../core/bin/run-actions) for its read-only checks | Runs Claude Code: one box per project or scratch, shared by its `dev claude` and `dev shell` sessions and gone after the last; every other `dev` command starts a fresh one (`--rm`); [its settings and mounts](03-deployment.md#the-box) |
| Your config | Container (data store) | `~/.claude/.dev`; the defaults in [core/defaults.dev](../../../core/defaults.dev) | Your git identity, what you bring in (`plugin`: plugins, skills, marketplace plugins; `rules`: rules files), packages, projects folder, caps, Remote Control, and groups (`group` folders, `remote` members, `autotake group`); the copy you approved last, with every file it names, is in `~/.local/state/claude-box/approved/`, whose rules boxes mount read-only, nothing else of it; your yeses to `.dev` group lines beside it, in `group-yes` ([mounts](03-deployment.md#mounts)) |
| Plugins | Container (data store) | [plugins/](../../../plugins/) in the clone, tracked | Optional Claude Code plugins, each with an optional `rules/` and `starter/`; reach a box only when your config names them ([architecture](README.md#plugins)) |
| Claude's home | Container (data store) | Your `~/.claude`, at `/home/claude/.claude` | Claude's login, settings, plugins' state, memory, history, global `~/.claude/CLAUDE.md` and `.claude.json`; you open and edit it like any of your files; neither `dev build`, `dev reset` nor `dev uninstall` touches it |
| The project | Container (data store) | The folder you start `dev` in, with its `.git` | What Claude works on; `.dev` lists what its box needs (dnf, npm and pip packages, marketplace plugins, ports to publish, the group it joins after your yes); `out/` (in `.gitignore`) holds the `dev run` files, the handoffs, drafts waiting on you, and `done/`: used drafts, deleted by box-workflow after 14 days ([rule](../../../core/rules/CLAUDE.md)); `actions.done` and the handoffs aren't trimmed ([accepted risk](README.md#accepted-risks)) |
| A scratch | Container (data store) | `~/.claude/scratch/<name>` (a random adjective-noun), at `/work/scratch-<name>` in its box | A session outside any project: `out/` as in a project (no `.gitignore`, no handoffs) and `notes.md`, whose first line names the job for `dev scratch`; no repo, no `.dev`. Its conversations and memory are in `~/.claude/projects/-work-scratch-<name>/`; `dev scratch --rm` deletes both after asking |
| Your other projects | Container (data store) | `~/Projects` (or `DEV_PROJECTS`) | Read by Claude; a change to one comes as a prompt for that project's own Claude session, sent to it when it runs |
| Remote Control | External | claude.ai, with your login | Carries messages between your sessions (SendMessage) and lets you drive a box from claude.ai or your phone; [accepted risk](README.md#accepted-risks) |
