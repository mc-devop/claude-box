# Spec: you set claude-box up once, and see how it hangs together

For the [intent](intent.md). The owner and Claude agreed the design
section by section, 2026-10-31, starting from how claude-box is used
([findings-use.md](findings-use.md)) and from what Claude Code allows
([findings-claude-code-checks.md](findings-claude-code-checks.md)).
The review's fixes (what breaks, what's overkill, what's missing) were
applied the same day ([findings-spec-review.md](findings-spec-review.md)),
and the owner approved it on 2026-10-31.

This spec replaces the three layers and the config schema from the
[clear-layout spec](../2026-10-30-clear-layout/spec.md), and from the
[project-defaults spec](../2026-10-31-project-defaults/spec.md) its
D10 (`pack` lines in `.dev`) and D13 (the three layers in `layers.md`).
The other decisions in those specs stand.

## The model

**Three kinds of thing.** Each one is a top-level home:

| Kind | Home | What it is | Who changes it |
|---|---|---|---|
| Core | `core/` | claude-box itself: isolation, `dev`, `dev run`, the inbox, and the rules those need. Always on | The claude-box repo |
| Plugins | `plugins/` and anywhere a `use` line points | Everything optional: Claude Code plugins (mods and skills included), rules files, the workflow | Whoever wrote them; you choose them with `use` |
| Yours | `~/.claude/` and each project | How you work, and what's in your boxes | You, through Claude |

**Two levels, each with the same files:**

```
~/.claude/    CLAUDE.md  .dev  rules/     global: every project
<project>/    CLAUDE.md  .dev  .claude/   project: this one
```

- `CLAUDE.md` is how Claude works; `.dev` is what's in the box.
- Core's rules load underneath both levels, from the image's managed
  policy, where no session can change them. `core/README.md` records
  that as a fact for code readers; users never need it.
- **Every change takes effect the same way:** the next `dev claude`
  shows it and applies it after your yes.

## Decisions

| # | Topic | Decision | From |
|---|---|---|---|
| D1 | Names | The README, the architecture, `dev`'s messages and the rules say *core*, *plugin*, *global* and *project*. "Company", "pack" and "layer" leave the user's view. The architecture names Claude Code's scopes (managed, user, project) where it explains loading | the owner; [use](findings-use.md#where-the-owner-got-lost) |
| D2 | The global config | `~/.claude/.dev`, beside your global `CLAUDE.md`. `local/claude-box.conf` and `local/` are gone, and `dev` refuses an old config with one line naming the new place. The approved copy stays in `~/.local/state/claude-box/approved/`, out of the box's reach. Accepted risk: any box can *propose* a change to it, and nothing applies without your yes at a terminal | the owner |
| D3 | One vocabulary | The kinds are the same in both `.dev` files. `use`, `dnf`, `npm` and `pip` work at both levels. `port` is project only. `group` takes a folder globally and a name in a project, as now. `identity`, `projects`, `memory`, `cpus`, `remote-control`, `remote` and `autotake` are global only, and `dev` says so if one appears in a project. `company`, `global`, `pack` and `plugin` are gone. The global config refuses each with the line that replaces it; in a project's `.dev`, `plugin` and `pack` lines are skipped with a one-line notice, so no project stops before its handoff is acted on. `dev plugins` and the plugin offer menu go; `dev add use <x>` writes a line. `dev new` lays down the starters of the plugins you use, offers nothing, and writes no `pack` lines. A scratch session gets the global `.dev`; it has no project level | the owner, [review](findings-spec-review.md) B3, M1, M3 |
| D4 | `use <where>` | `dev` looks at what it finds and decides where it goes (D5). It accepts: a name in the clone's `plugins/`; a path to a plugin folder (`.claude-plugin/plugin.json`, or the standard layout); a folder with `SKILL.md` at its root, which Claude Code already loads as a one-skill plugin; a `.md` file, as a path or a commit-pinned `https` URL, which is a rules file; `<name>@<marketplace> <owner/repo>`, a marketplace plugin. A local path must be under `~/.claude/` or your projects folder, which every box sees already, using today's safe characters, so nothing new reaches a box. A line in `~/.claude/.dev` applies to every project, a line in a project's `.dev` to that project | the owner, [checks](findings-claude-code-checks.md), [review](findings-spec-review.md) B1, O2 |
| D5 | Where each lands | A plugin (not from a marketplace) is built into the image under `/usr/local/share/claude-box/plugins/<name>`, read-only, and loaded through `CLAUDE_CODE_PLUGIN_DIRS`. Its `rules/` folder, if it has one, is mounted read-only at `~/.claude/rules/<name>/`. A rules file is mounted read-only at `~/.claude/rules/use/<file>`. A marketplace plugin is installed through Claude Code, as the `plugin` kind is today. A project-level `use` goes into that project's image and mounts only | [checks](findings-claude-code-checks.md) 1–4 |
| D6 | Pinning | A URL is fetched when its line first appears. `dev` shows what it is and where it lands, and on your yes records the file's sha256 in the approved copy; you never type a hash. The URL carries its commit, so it never changes under you; a newer version is a new line, shown and approved like any change | the owner, [review](findings-spec-review.md) O2 |
| D7 | The workflow plugin | `packs/workflow/` becomes `plugins/workflow/`, an ordinary plugin: `.claude-plugin/plugin.json` with `dependencies` naming superpowers, `skills/closing/`, `rules/` (documentation, specs-and-plans, the Markdown rules that its docs need, the sections of a project's `CLAUDE.md`), and `starter/`, which `dev new` lays down for every used plugin that has one. **To check in plan 2:** whether Claude Code honours `dependencies` for a plugin loaded from a folder. If it doesn't, `dev` turns each dependency into a marketplace `use`, and if it can't find the marketplace's repo it refuses, naming the line to add | the owner, [check 1](findings-claude-code-checks.md) |
| D8 | What core holds | `core/rules/` holds: the environment (today's `box/company/CLAUDE.md`); from workflow's `change-management.md`, *branches and approval* and *evidence and secrets*; and the levels rule in three lines (two levels, one fact in one place, a project that differs says so in one line). The sections of a project's `CLAUDE.md` stay path-scoped in the workflow plugin's `rules/`, costing nothing at start. The `dev run` file format becomes a skill in core's plugin, `box-workflow:dev-run`, loaded when Claude writes `out/actions.txt`. `change-management.md` disappears. Your Mermaid preferences (`TD`, the C4 colours) leave the plugin and go to your own rules | the owner, [use](findings-use.md#what-is-the-same-everywhere-the-default-the-owner-actually-uses) |
| D9 | Core's managed settings | These are added to [managed-settings.json](../../../core/managed-settings.json): telemetry off (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `DISABLE_FEEDBACK_COMMAND`, `SUPERPOWERS_DISABLE_TELEMETRY`); a `PreToolUse` hook from the image that refuses `git commit` on `main` unless the same command first creates a branch (today's hook in your `~/.claude/hooks/`); and `ask` rules for `Edit(~/.claude/CLAUDE.md)`, `Edit(~/.claude/.dev)`, `Edit(~/.claude/rules/**)` and `Edit(~/.claude/settings.json)`, which prompt you even in auto mode. Known limit: a script that writes those files itself isn't covered | the owner, [check 5](findings-claude-code-checks.md) |
| D10 | Refusals | `run-actions`' refusals (secrets, installs on the laptop) stay in the script; `core/README.md` lists them in plain words. Your own refusals are a backlog item | [review](findings-spec-review.md) O1, B5 |
| D11 | Host facts | At each box start `dev` writes your laptop's OS (`PRETTY_NAME`), your shell, and which of a fixed list of commands exist (git, gh, podman, ssh, rsync, flatpak, rpm-ostree, dnf, brew, toolbox, systemctl, sudo, python3, curl, jq) into a file mounted read-only at `/etc/claude-box/host`. The `dev-run` skill reads it before writing a `local` step. The backlog's `need <tool>` becomes unnecessary for local tools | the owner |
| D12 | One way to apply | The image is built from `git archive main` of the clone and carries a label `claude-box.core`: git's tree id of `main:core`. `dev claude` compares the two, shows which core files changed on `main`, and rebuilds after your yes; without a terminal it starts on the old image and says so. A branch you're reviewing never reaches the image. `dev build` stays, for a newer Claude Code or Fedora. `dev update` shows the commits coming from the clone's upstream, pulls them (`--ff-only`) after your yes, and leaves the rest to the next `dev claude` | the owner, [use](findings-use.md#where-the-owner-got-lost), [review](findings-spec-review.md) B2, O4 |
| D13 | Setup | `./dev install` links `dev` and runs `dev init`. `dev init` first asks Claude's git identity (Enter keeps `Claude <claude@claude-box.invalid>`) and writes `~/.claude/.dev` with it and `use workflow`, keeping one that already exists; then it builds and logs Claude in. The README adds one line: start `dev claude` in the clone and ask Claude to set you up | the owner, [review](findings-spec-review.md) B6 |
| D14 | The repo | Top level: `dev`, `core/`, `plugins/`, `tests/`, `docs/`. `box/` becomes `core/`, `box/defaults.conf` becomes `core/defaults.dev` (every kind with an example), and `local/private-terms` becomes `tests/private-terms`, still kept out of git. `core/README.md` and `plugins/workflow/README.md` each map their parts: what each part is, where it runs, what it feeds | the owner |
| D15 | The docs | The README is built around the model: the two-level picture, and a table of *what you change → where → who → how it takes effect*. The architecture's Rules and Packs sections become Levels and Plugins, with D9's limit under known limits and D2's risk under accepted risks. The runbook covers setup, update and changing your setup | the owner |
| D16 | Moving over | For the owner: before branch 2's merge run, Claude writes `~/.claude/.dev` from the current config. modularity and c4m become global `use` lines, so the projects' `.dev` plugin lines can go. A draft in `out/` removes from `settings.json` what core now holds; the owner deletes `~/.claude/hooks/no-commit-on-main.py`. Each other project gets a handoff saying that `.dev` `plugin` and `pack` lines become `use` lines or go, and each changes its own file | the owner |

## Deliverables

Four branches, in order, each from the current `main`. Each one updates
the README, the architecture and the runbook where it changes what they
describe, and each keeps `tests/run.sh` passing.

1. **`claude/core-moves`:** moves only. `box/` becomes `core/` with
   `git mv`, plus the path and link fixes in code, tests and docs. No
   wording changes.
2. **`claude/dot-dev`:** D2–D7, D14 (`local/` goes, `private-terms`
   moves, `defaults.dev`), and the old-config refusal from D16. The
   workflow becomes a plugin. Tests in `tests/test_dev.sh`: each `use`
   form and where it lands, paths outside `~/.claude/` and the projects
   folder refused, pinning on approval, gone kinds refused globally and
   skipped in a project, project-only and global-only kinds.
3. **`claude/core-rules`:** D8–D11. The rules are split and the
   `dev-run` skill written; managed settings; the refusals listed in
   `core/README.md`; host facts. Tests: `ask` rules, the hook and the
   telemetry env present in managed settings
   (`check_managed_settings.py`), and the host file's lines. A list maps
   every rule from the old files to its new place, so no rule is lost.
4. **`claude/one-way`:** D12, D13, D15. The core hash and rebuild from
   `main`; `dev update`; `./dev install` running `dev init`; the README
   and the maps. Tests: a core change on `main` asks for a rebuild, an
   unchanged `main` doesn't, and neither does a change on a branch. Then the README test with a fresh reader (as in
   [findings-readme-test.md](../2026-10-30-clear-layout/findings-readme-test.md)):
   from the README and the maps alone, the reader answers where five
   named things live, who changes them, and how a change takes effect.

After the merges: D16, the owner's `dev build`, and the acceptance.

## Acceptance

Each criterion of the [intent](intent.md#acceptance-criteria), with its
evidence:

| Criterion | Evidence |
|---|---|
| Setup with `./dev install` alone | The stranger test runs `./dev install` in a fresh clone and declines the login; the `~/.claude/.dev` it wrote has two lines |
| Two levels, one vocabulary | `defaults.dev`; tests for global-only and project-only kinds; no "company" in the README, `dev`'s messages or `core/rules/` (grep) |
| One `use` line, no layer, no hash | Tests for each `use` form (branch 2) |
| Changes apply at the next `dev claude` | The core-hash test; a `.dev` change shown and applied in a real box |
| Core rules without the workflow | A box started with a `.dev` without `use workflow` lists core's rules and the `dev-run` skill |
| Asked before edits to `~/.claude/` | A real session in auto mode, with the prompt's text recorded; the limit is in the architecture |
| Host facts | `/etc/claude-box/host` in a real box |
| The repo reads as the model | The fresh reader's answers (branch 4) |
| Your setup moves over | Your four projects start with their boxes as before, read in each; `settings.json` without the hook and the telemetry env |

## Related backlog items

- *A new user sets up, updates and leaves claude-box from the README
  alone:* this milestone covers the plugin bringing what it relies on
  (D7), your own rules outside the repo (D4) and updating (D12). Still
  open after it: removing claude-box (`dev` undoing `dev install`), and
  the stranger test starting from the starter config.
- *Every session starts with under 200 lines of rules:* the `dev run`
  format moves into a skill (D8); the count is taken at acceptance.
- *Your part of Claude's home is out of the box's reach:* the `ask`
  rules (D9) are a first step; the item stays open.
- *A run's record is complete …:* the `need <tool>` part is covered by
  D11 for local tools.
- *New projects start alike and find their neighbours:* its acceptance
  runs after this milestone, on the new model, and names D10 and D13 of
  its spec as replaced here.

## Acceptance results (2026-11-15)

On `main` 0ba2814. The stranger test ran on the owner's laptop
(Fedora 44 COSMIC Atomic) through `dev run`, in four runs: the first
timed out at sudo; the second showed the test predated one-way (the
first start asks for a yes, only in a terminal) and the third that the
laptop has no `script`, both fixed in [stranger-test.sh](stranger-test.sh);
a fourth added a second phase for core's rules, whose first try joined
the first phase's box and so proved nothing, fixed to start a new one.
The last run's log: [stranger-test.log](stranger-test.log).

| Criterion | Result | Evidence |
|---|---|---|
| Setup with `./dev install` alone | Met, with a deviation | [stranger-test.log](stranger-test.log): a throwaway user's Quick start ran to the end, a box ran `2.1.325 (Claude Code)` with `claude@claude-box.invalid`, the clone's top level is the model's. The config has three lines, not two: `autotake group` too, which the groups branch of the project-defaults milestone added after this intent |
| Two levels, one vocabulary | Met | [core/defaults.dev](../../../core/defaults.dev) explains every kind (`test_dev.sh`, `defaults-every-kind`); a global-only kind in a project's `.dev` is refused (`test_dev.sh`, "global only"); "company" is left only in `dev`'s refusal of the old kinds ([core/lib/conf.sh](../../../core/lib/conf.sh)) |
| One `plugin` or `rules` line ([spec-kinds](spec-kinds.md)) | Met in the tests; not run in a real box | The tests for each form at both levels (`test_dev.sh`, e.g. `use-url-*`, `project-plugin-again`, `seed-project-level`). A project's plugin shown and applied in a real box: not run, no project has a `plugin` line (the [backlog](../../direction/backlog.md) item on a project's marketplace plugin) |
| Changes apply at the next `dev claude` | Met | `test_dev.sh` `core-changed-again`; in [stranger-test.log](stranger-test.log) a config change shown as a diff, applied after `y`, the layer rebuilt |
| Core rules without the workflow | Met | [stranger-test.log](stranger-test.log), second phase: the config without `plugin workflow`, applied after `y` in a new box, which has `/etc/claude-code/` (`CLAUDE.md`, `branches-and-evidence.md`, `levels.md`, managed settings) and the `dev-run` skill, and no `~/.claude/rules/workflow/documentation.md` |
| Asked before edits to `~/.claude/` | Met | [core-rules-box-evidence.md](core-rules-box-evidence.md) (2026-10-31): the prompt's text in auto mode, declined. Its option 2 is in the architecture's [known limits](../../system/architecture/README.md) |
| Host facts | Met | `/etc/claude-box/host` in claude-box's box, 2026-11-15: `os Fedora Linux 44.20261112.0 (COSMIC Atomic)`, `shell zsh`, `has …`, `lacks dnf` |
| The repo reads as the model | Met | [findings-readme-test.md](findings-readme-test.md): five of five right |
| Your setup moves over | Met | `~/.claude/.dev` holds the identity, three `plugin` lines and the group; `settings.json` has no `hooks` and no `env`, `~/.claude/hooks/no-commit-on-main.py` is gone; all four projects started sessions in their boxes since (two on 2026-11-15, two on 2026-11-14, by their transcripts' dates in `~/.claude/projects/`) |

**Deviations:** the third config line above; the stranger test changed
three times at acceptance (see above). The related items' "count taken
at acceptance" (D8): the rules loaded at every start in claude-box's box
are 282 lines (core's three files 131, the global `CLAUDE.md` 53, the
workflow's three always-loaded rules 97, the memory index 1), against
the limit of 200: the [backlog](../../direction/backlog.md) item stays.

**Version check:** the base is `fedora:44`; Fedora 45 is released, its
switch is a [backlog](../../direction/backlog.md) item. Claude Code
2.1.325 (installed at build, unpinned). The seed's plugins are the
approved commits, unchanged since plugins-in-image.

**What's left of the intent:** a project's plugin in a real box, with
the backlog item on a project's marketplace plugin. Every other
criterion is met.
