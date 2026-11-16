# Spec: `plugin` and `rules`, the same in both `.dev` files

For the [intent](intent.md), after the [spec](spec.md). Branch 4,
`claude/one-way`, was built up to its docs
(its plan, `plan-one-way.md` on that branch, tasks 1–4). Reading the README's line "One line
brings something in, and `dev` works out where it goes", the owner
objected on 2026-10-31. A value whose meaning depends on its shape reads
as magic, and a project's `.dev` didn't take what the global one takes,
although the two are meant to share one vocabulary. The owner chose two
kinds named after what the thing is in Claude Code, with the same
meaning at both levels.

**What this replaces:** from the [spec](spec.md), D3's `use` (which is
now refused globally and skipped in a project), D4, D5, and
[plan 2](plan-dot-dev.md)'s P1 (a project's `use` took only marketplace
plugins). The intent's criterion "One `use <where>` line brings in a
plugin …" reads as "one `plugin` or `rules` line brings in …", by the
owner's ruling of 2026-10-31. The acceptance names this as a deviation.
Every other decision stands.

## Decisions

| # | Topic | Decision |
|---|---|---|
| K1 | Two kinds | `plugin <value>` brings in a Claude Code plugin; a bare skill folder (`SKILL.md` at its root) counts as one. `rules <value>` brings in a rules file. Both kinds take the same values in `~/.claude/.dev` and in a project's `.dev`. A line in the global file reaches every project; a line in a project's file reaches that project's boxes |
| K2 | Values | `plugin` takes a name in the clone's `plugins/` (read from `main`); a folder under `~/.claude/`; or `<name>@<marketplace> <owner/repo>`. `rules` takes a `.md` file under `~/.claude/`, or a `https` URL with a commit in its path. A `plugin` value ending in `.md` is refused, and so is a `rules` value that doesn't end in `.md`. Each refusal names the other kind. The path and character rules are today's (spec D4) |
| K3 | Where each lands | One fixed row per kind and form, in the docs and `core/defaults.dev`. **plugin, by name or folder:** built into the image under `/usr/local/share/claude-box/plugins/<name>` and loaded through `CLAUDE_CODE_PLUGIN_DIRS`. Its `rules/` is mounted read-only at `~/.claude/rules/<name>/`, and its `starter/` is laid down by `dev new` (global lines only). **plugin from a marketplace:** installed by Claude Code, at user scope from the global file, at local scope from a project's. **rules:** mounted read-only at `~/.claude/rules/files/<file>`. A global line goes into your layer; a project line goes into that project's image and mounts |
| K4 | A project's approval | A project's `plugin` (by name or folder) and `rules` lines are approved as the global ones are. The next box start shows the diff of the line and every file it names against what you approved last for that project, and applies it after your yes. The approved copy is `~/.local/state/claude-box/projects/<image name>/approved/`, out of every box's reach. A URL is pinned on approval (spec D6). No, or no terminal: that project's approved copy, or none. Marketplace lines are asked by name, as today |
| K5 | One name, one level | A plugin or rules file named at both levels is refused at the project line, naming the global one. Two mounts at one path would hide one of them |
| K6 | `use` goes | In `~/.claude/.dev`, a `use` line is refused with the line that replaces it (`rules …` for a `.md` value, else `plugin …`), like the other gone kinds. In a project's `.dev`, it's skipped with a one-line notice naming the replacement. A marketplace plugin it installed stays installed, as the `plugin` kind's old lines did. `dev add use` becomes `dev add plugin` and `dev add rules` |
| K7 | Moving over | Your `~/.claude/.dev`: four `use` lines become three `plugin` lines and one `rules` line, drafted in `out/` for the merge run. The empty mount points under `~/.claude/rules/use/` are removed in the same run. No project `.dev` has a `use` line today, so no handoff is needed |

## Deliverables

One branch, `claude/kinds`, from the current `main`, before
`claude/one-way` is rebuilt on top of it.

- `core/lib/conf.sh` and `core/lib/project.sh`: the two kinds at both
  levels, `use` refused or skipped, and the per-project approved copy.
  `core/lib/layer.sh`, `mounts.sh` and `project.sh` build and mount
  project-level plugins and rules.
- `core/defaults.dev` and `dev`'s help and messages say `plugin` and
  `rules`, with one row per form and where it lands; nothing says `dev`
  "works out" anything.
- Tests in `tests/test_dev.sh`:
  - each form of each kind, at both levels, and where it lands;
  - a value of the wrong kind refused, naming the other;
  - `use` refused globally and skipped in a project, with the
    replacement named;
  - a project's plugin change shown and applied after your yes, and
    left alone on no;
  - a name at both levels refused;
  - a project plugin's `rules/` mounted only in that project's box.
- The docs that describe `use` today (README, architecture, runbook)
  switch to the two kinds on this branch, and so does the backlog's
  "A plugin from any git repo is one `use` line". Branch 4's docs task
  then builds on them.

## Acceptance

Added to the spec's [acceptance](spec.md#acceptance), in place of the
row *One `use` line, no layer, no hash*:

| Criterion | Evidence |
|---|---|
| One `plugin` or `rules` line, the same at both levels, no folder named, no hash typed | The tests for each form at both levels, and a project's plugin shown and applied in a real box |
