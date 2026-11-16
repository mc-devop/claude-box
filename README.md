# claude-box

Claude Code normally runs as you on your host system, with access to your data, your SSH keys, your tokens and your shell. claude-box runs it in a rootless Podman container instead.

The container sees the project you start it in, your other projects
read-only, and Claude's home (`~/.claude`). Nothing else from your
machine: no keys, no git credentials. Claude commits to `claude/<topic>`
branches; you review and merge.

Anything that needs your access, like a push or a command on a server,
Claude writes to `out/actions.txt`, and you run it with `dev run`.
Tools the project needs go in its `.dev` (e.g.
`dnf jq`) and are installed in the box.

What Claude can and can't reach, and why: the
[architecture](docs/system/architecture/README.md).

## Requirements

- Linux with rootless Podman (tested on Fedora 44), python3 and flock
  (util-linux); Fedora has them all.
- A Claude account, to log Claude Code in.

## Quick start
```
git clone https://github.com/mc-devop/claude-box
cd claude-box
./dev install                          # dev on your PATH, your config, the image, Claude's login
cd ~/Projects/<project> && dev claude  # Claude in a project (a new one: dev new <name>)
```
To shape your setup, start `dev claude` in the clone and ask Claude to
set you up; it proposes the changes, you approve them. To update:
`dev update`; to remove claude-box: `dev uninstall`. The rest is in
the [runbook](docs/system/runbook.md).

## How it hangs together

- **Core** is claude-box itself: the isolation, `dev`, `dev run` and
  the rules they need. Always on; only this repo changes it
  ([core/](core/README.md)).
- **Plugins** are optional, one `plugin` line each, from a folder or a
  marketplace. Each lands in the box's image at its level, where no
  session can change it. This repo has one,
  [workflow](plugins/workflow/README.md): the way this repo is run
  (documents in three families, specs and plans, closing), bringing
  superpowers.
- **Yours** is how you work, at two levels with the same two files:

```
~/.claude/    CLAUDE.md  .dev     global: every project
<project>/    CLAUDE.md  .dev     project: this one
```

`CLAUDE.md` says how Claude works; `.dev` says what's in the box
(packages, plugins, rules files; every kind in
[core/defaults.dev](core/defaults.dev)). Core's rules load beneath
both, where no session can change them.

## Make it yours

| To change | Edit | It applies |
|---|---|---|
| What's in every box | `~/.claude/.dev` | At the next `dev claude` |
| How Claude works everywhere | `~/.claude/CLAUDE.md`, `~/.claude/rules/` | At the next session |
| What's in one project's box | Its `.dev` (`dev add dnf jq`) | At the next `dev claude` there |
| How Claude works in one project | Its `CLAUDE.md`, `.claude/rules/` | At the next session |

A running box keeps what it started with until its last session ends.
Boxes are built from `main` only, so a branch you're reviewing here
never reaches them.

## Commands

```
dev claude      start Claude in this project; outside one, a scratch session
dev new <name>  a new project in ~/Projects
dev add / dev remove <kind> <name>   change this project's .dev
dev run         run the steps Claude wrote to out/actions.txt
dev update      get the latest claude-box; the next dev claude applies it
dev build       rebuild the image for a newer Claude Code
dev uninstall   remove claude-box: images, boxes, its state, the dev link
dev             every command
```

## What's in this repo

| | |
|---|---|
| `README.md` | This file |
| `LICENSE` | MIT |
| `dev` | The one command you run (`./dev install` puts it on your PATH) |
| `plugins/` | Optional plugins, brought in with a `plugin` line |
| `core/` | What builds and drives the box: its Containerfile, `defaults.dev`, the box's own rules and plugin, helper scripts (`bin/`) and dev's modules (`lib/`) |
| `docs/` | Direction, change records and the system's docs (below) |
| `tests/` | The checks: `tests/run.sh` |
| `out/` | Not in git, made once Claude hands you something, here as in every project: e.g. the steps for `dev run` |
| `.gitignore` | Keeps `out/` and a file for developing claude-box out of git |

## Documentation
| | |
|---|---|
| [Runbook](docs/system/runbook.md) | How to set up, use, change and reset it |
| [Architecture](docs/system/architecture/README.md) | What Claude can reach, the rules, plugins, `dev run`, the known limits |
| [Vision](docs/direction/vision.md), [backlog](docs/direction/backlog.md) | Where it's going, what's next |
| `docs/change/` | One folder per change: intent, spec, plans, findings |

## License

MIT: see [LICENSE](LICENSE).
