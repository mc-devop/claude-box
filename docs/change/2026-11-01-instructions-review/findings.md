# Findings: the instructions every session loads

Asked on 2026-11-01: review the new structure and workflow for
inconsistencies, ambiguities and rules stated twice, to save context.
Read in this box, in a claude-box session.

## What loads at every start

| Source | Level | Size (chars) | Loads |
|---|---|---|---|
| [core/rules/CLAUDE.md](../../../core/rules/CLAUDE.md) | core | 6,800 | always |
| [core/rules/branches-and-evidence.md](../../../core/rules/branches-and-evidence.md) | core | 1,500 | always |
| [core/rules/levels.md](../../../core/rules/levels.md) | core | 700 | always |
| `~/.claude/CLAUDE.md` | global | 1,900 | always |
| `~/.claude/rules/files/CLAUDE.md` (the `rules` URL line) | global | 2,400 | always |
| `~/.claude/rules/mermaid.md` | global | 350 | always |
| [workflow/rules/documentation.md](../../../plugins/workflow/rules/documentation.md) | workflow plugin | 4,200 | always |
| [workflow/rules/markdown.md](../../../plugins/workflow/rules/markdown.md) | workflow plugin | 1,400 | always |
| [workflow/rules/specs-and-plans.md](../../../plugins/workflow/rules/specs-and-plans.md) | workflow plugin | 900 | always |
| `workflow/rules/starter.md` (folded into [markdown.md](../../../plugins/workflow/rules/markdown.md)) | workflow plugin | 500 | always |
| [workflow/rules/claude-md.md](../../../plugins/workflow/rules/claude-md.md) | workflow plugin | 400 | path-scoped |
| superpowers' SessionStart hook (using-superpowers) | plugin | 3,200 | always, again after each compaction |

About 24,000 characters (roughly 6,000 tokens) before the first prompt.
The global rule "files loaded at every start stay under 200 lines"
holds for each file, but not for the total: 385 lines. Whether it means
one file or all of them together is unclear (A1).

## Stated twice

| # | Rule | Where | Keep it in |
|---|---|---|---|
| D1 | Link, never copy | global "One fact, one place"; core levels "One fact, one level"; documentation "A fact's family decides its home" | core levels (general) and documentation (families); cut the global bullet |
| D2 | Use a standard's terms | global "Standards over invented terms"; documentation "Terms come from the family's standard" | documentation; the global bullet keeps only "check the term against its source", or goes |
| D3 | Before /clear or /compact | core (move drafts, name the rest); global "Session hygiene" (backlog, docs, memory, first prompt, good moments) | one place; it's a procedure, so a skill (see S1) |
| D4 | Mermaid | markdown.md (flowchart only, small) plus mermaid.md (flowchart TD, C4 colours) | fine as layers, but mermaid.md's C4 colours matter only when drawing views: path-scope it to `docs/system/**` |
| D5 | Think first, keep it simple, change surgically | the `rules` URL file (65 lines); largely what Claude Code's own system prompt already says | the owner's call: drop the line, or keep it knowing it's mostly a repeat (see C1) |
| D6 | "Differs from the default" lines | core levels; claude-md.md | fine: claude-md.md is path-scoped and links the rule |

## Contradictions

- **C1. Ask or act.** The `rules` URL file says "if uncertain, ask; present
  every interpretation" and "bias toward caution over speed". Claude
  Code's own prompt and the AskUserQuestion guidance say: act when you
  have enough, ask only when blocked. documentation.md says "in doubt
  about the size: ask once". Three different thresholds for asking.
- **C2. Invoke every skill or keep it lean.** superpowers' hook says
  invoke a skill on "even a 1% chance", before any reply. The global
  rules want lean context. User instructions win by superpowers' own
  text, but nothing says so explicitly, so each session pays to load
  skills that don't apply.
- **C3. Artifacts or Markdown.** The global CLAUDE.md says drafts go
  into a file you open in the preview, Markdown only. The harness tells
  Claude to publish reports as Artifacts. Your rule wins, but it only
  names plugin output formats ("an HTML copy"), not Artifacts.
- **C4. Mermaid C4 syntax.** markdown.md forbids C4 syntax. The c4m
  plugin defaults to Mermaid C4. markdown.md wins, but c4m's skills
  will offer it every time.
- **C5. Stale text after plugins-in-image.** The workflow plugin's
  [README](../../../plugins/workflow/README.md) still says `dev`
  installs superpowers "after your yes". The plugins now land in the
  image. This is the same kind of drift as deferred minor M8.

## Ambiguities

- **A1.** "Under 200 lines": per file, or the total? (see above)
- **A2. Human, owner, me.** core says "the human", managed settings and
  messages say "the owner", the global file says "me". Each one is
  clear on its own, but three names for one person.
- **A3. Run output in `out/`.** core lists "run output" among what `out/`
  holds, then says everything except dev run's files, the handoffs and
  `done/` is a draft. Is run output a draft, and which step moves it?
- **A4. Two plugin names.** `box-workflow:` (core) and `workflow:`
  (optional) differ by one prefix. This is known: the rename was
  deferred to backlog item O3's spec.
- **A5. claude-box has no `CLAUDE.md`.** claude-md.md prescribes a
  project's sections. claude-box itself has none, and no line says
  that's on purpose.

## Loaded always, needed rarely

- **S1. Procedures in core.** The handoff procedure (addresses, 409,
  ListAgents, logging; about 35 lines), "a tool the box lacks", and the
  draft lifecycle in `out/` are steps, not rules. The global rule
  "procedures into skills" says they belong in a box-workflow skill
  (`handoff`, next to `dev-run`), leaving one line each in core. That
  saves about 3,000 characters.
- **S2. The scratch section** (12 lines) applies only in
  `/work/scratch-*`, but every project session loads it. It could go into
  the scratch folder's own `CLAUDE.md`, which `dev` writes there.
- **S3. Sizes of change and closing** in documentation.md are only needed
  when a change starts or closes. They could move into the closing skill,
  or into the brainstorming handover (our own choice).
- **S4. starter.md** is needed only at `dev new` or when a project adopts
  the plugin. It could be path-scoped, or a line in the closing or
  new-project flow.
- **S5. Session memory.** `session-handoff.md` has grown to 16,000
  characters, a log instead of "a pointer and the next action". It isn't
  loaded at start, but each read costs about 4,000 tokens. Trimming it to
  a few lines is Claude's own mess to clean up.

## Rough savings

S1 + S2 + D1–D3 + D4's scoping save about 6,000 characters from every
start, a quarter of the total. Adding D5 (if you drop the URL rules)
brings it to about a third.

## What was done (2026-11-01)

The owner kept the Karpathy principles, copied in once instead of loaded
from the URL, and asked for the other edits:

- S1: the handoff procedure moved to
  [box-workflow:handoff](../../../core/plugin/box-workflow/skills/handoff/SKILL.md);
  core keeps one pointer. A3: core now says run output is a draft.
- S3: "Sizes of change" moved to
  [workflow:sizes-of-change](../../../plugins/workflow/skills/sizes-of-change/SKILL.md);
  its acceptance steps were already in the closing skill, so they went.
- S4: starter.md folded into markdown.md's link-check line. C5: the
  workflow README's stale sentence fixed.
- D1, D2, D5, C1–C3, A1, D4: drafts of the global files in `out/global/`
  (Karpathy in our own words, as the source repo has no license), put
  in place by the owner's `dev run`.
- S2: deferred to the [backlog](../../direction/backlog.md) (it needs a
  read-only file in the scratch folder). S5: the session memory trimmed.
- Left as they are: A2, A4 (backlog item O3), A5, D3, D6, C4.
