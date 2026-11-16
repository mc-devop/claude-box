# Findings: how claude-box is used (2026-10-31)

Before changing how layers, packs and config fit together, this looks at
what the owner actually does with claude-box and where they got lost.
It does not start from what's built.

**Sources:** the owner's prompt history in `~/.claude/history.jsonl`
(2026-09-26 to 2026-10-31: 1,413 prompts, about 1,000 longer than a
word or two) across four projects and two scratch sessions, plus each
project's `.dev` and `CLAUDE.md`. The three other projects are called
A, B and C here: a home server platform, an app it hosts, and a
laptop's provisioning. Counts come from keyword matches, so they are
approximate.

## What the owner does

| # | Journey | How often | What the owner touches |
|---|---|---|---|
| J1 | **Drive a change in a project**: ask, review the intent or spec, ask *"what breaks, what's overkill, what did we miss?"*, approve, "go native", review the branch, merge with `dev run` | Most of the time, in every project | Prompts, the branch in the editor, `dev run`, then "done, check logs" |
| J2 | **Change the box itself**: in claude-box's session, then rebuild and restart the other sessions | Weekly or more | `dev build`, restarting sessions, `--continue`, then "do I need to build?" |
| J3 | **Projects talk to each other**: first by pasting prompts between them, then by messages | Daily since 10-07 | **Take it**, `/autotake`, carrying prompts by hand |
| J4 | **A one-off job on the machine**: a scratch session, which later became a project (C) | Twice | `dev claude --scratch`, `dev new` |
| J5 | **A project needs a tool or port**: added to `.dev` | A few times per project | Asks Claude; restarts |
| J6 | **Push a learning up** from a project to every project: "we did some smart things I want to push to the upper levels" | Several times (docs families, `dev run` rules, no `dev` in steps) | Asks Claude in that project; claude-box changes; rebuild |

Typed by hand, again and again:

| Prompt | Times |
|---|---|
| "done, check logs" and its variants | ~62 |
| "whats next?" | ~35 |
| *"what breaks, what's overkill, what did we miss?"* | ~32 |
| "approve" | ~30 |
| "go native" | ~21 |

**The owner edits almost no file by hand.** Claude writes every change,
including the config, the rules and `.dev`. The owner reviews it in the
editor, approves it, and runs `dev run`, `dev build` or a restart. The
one file the owner places themselves is the global `CLAUDE.md`, from
Claude's draft. So for this user, "where do I edit X" is really two
questions: *which session do I ask*, and *what do I do afterwards so it
takes effect*.

## Where the owner got lost

| Confusion | Evidence | Root |
|---|---|---|
| **After a change: build, restart, or nothing?** | ~15 prompts: "I dont need to build?", "so do we need to build and restart?", "the 'do you want to load' is just for the first start right?", "ah I didnt restart" | A change takes effect in one of four ways: nothing; the next session; a yes at the next `dev claude`; or `dev build` plus a restart. Which one applies depends on the file |
| **Continue, resume or restart?** | ~8: "--continue or --resume or plain exit and restart?", the same question asked in three projects in one minute, "continue stopped working" | Two ways back into a conversation, plus a bug |
| **What the rule layers are called and where they come from** | "how we ended up with three CLAUDE.md's", "what do you mean global rule? the company policy-ish?", "where did rules come from? a standard or something you made up?", "global, local and project" corrected to "company, global, project" | The names are our own, and they changed over time |
| **Too many kinds of thing** | "why do we have so many different kind of folders, rules, packs, mods, configs?", "its the number of items … can they be combined?" | Config, `local/`, packs with three parts, the box's own rules, `.dev`, the global `CLAUDE.md` |
| **What's mine to do and what's Claude's** | "I dont see what is my action and what is yours", "Too many actions listed. what shall I do next?", "I do what there?" | Plans and replies don't separate the owner's steps |
| **A rule didn't reach, or didn't hold, in a project** | B: Claude installed a tool on the laptop instead of using `.dev`, and did another repo's work; a `dev` command was put in a `dev run` step | The rules lived in a different place from where they were needed, or loaded too late |

## What is the same everywhere: the default the owner actually uses

| Practice | In use |
|---|---|
| Docs in three families (direction, change, system), the backlog as the only status | All four projects |
| Intent, then spec, then plan; the review question; approve; build | All four |
| `claude/` branches, merging only through `dev run`, evidence from read-only steps | All four |
| Handoffs and messages between sessions | All four |
| superpowers; the modularity and C4 plugins | All four (the same two project plugins in every `.dev`) |
| Karpathy's guidelines | All four |
| `pack workflow` in a project's `.dev` | **None**: the project part of a pack never reached any project, yet every project works this way |

## What is only the owner's

The owner uses Zed with Claude in a thread, `dev run` in a terminal
beside it and Obsidian for reading. They use Remote Control from a
phone. They prefer Mermaid drawn top-down with clickable links, and
scripts over GUIs. Then there are their servers, their git identity and
their choice of plugins. The Markdown style is the owner's own
preference (asked for on 09-26 and 09-27), but it ships in the
`workflow` pack's global part, so it ships to every user.

## Setting it up once (J0)

The user is someone like the owner: everything goes through Claude
afterwards. The config, though, is set up once, by hand, and the owner
says they couldn't do that today: it's too complicated (2026-10-31).
Reaching the owner's own setup takes six places, four of them outside
claude-box's config:

| # | Place | What the owner's holds | How it got there |
|---|---|---|---|
| 1 | `local/claude-box.conf` | identity; Karpathy's rules as a URL with a commit and a sha256; `pack workflow`; three plugin lines; a group | Written by Claude over several milestones |
| 2 | `~/.claude/CLAUDE.md` | how the owner works, across projects | Claude's draft, put in place by the owner |
| 3 | `~/.claude/settings.json` | telemetry off (env), permissions, a hook, the status line, `autoMode.environment`, plugins and marketplaces | Partly `dev init`, partly `dev run` steps, partly by hand |
| 4 | `~/.claude/hooks/` | `no-commit-on-main.py`: enforces a rule every box already has | A `dev run` step |
| 5 | Each project's `.dev` | the same two plugins, in every project | `dev new` or `dev plugins`, once per project |
| 6 | `dev init` | installs superpowers | Once |

Of these, 3 and 4 are the same for anyone who wants claude-box's
guarantees: telemetry off, and no commits on `main`. Only the owner's
setup has them.

## What this says

1. **A user needs three answers for anything they can change:** where it
   lives, who changes it, and what makes it take effect. The third
   answer causes the most confusion, because today there are four
   possible answers.
2. **In practice there is one workflow, on everywhere.** The pack
   machinery (opt in per config, opt in again per project, three parts)
   serves a choice the owner never made. Other users might make it, but
   that's an assumption.
3. **Pushing a learning up (J6) is a real, frequent flow**, but nothing
   names it. It's the reason the layers exist: a rule starts in one
   project and moves up when it proves itself.
4. **The owner's personal taste is mixed into what ships** (the Markdown
   style, the plugin suggestions in `box/defaults.conf`).
5. **The rituals are typed, not built in** (the review question, "check
   logs", "go native"). That's outside this change, but it shows what
   the core workflow *is*.
