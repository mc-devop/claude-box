# Documentation: three families

Every document in a project belongs to exactly one family. Work flows
direction → change → system; findings about the system flow back into
direction. A project creates a family's documents only when it needs
them.

| Family | Answers | Standard | Documents | Lifetime |
|---|---|---|---|---|
| **Direction** | Where are we going, what's next? | Product management | Product vision (long term); product backlog: an ordered queue, the only place with status | Living: reordered, items leave when done |
| **Change** | What was asked, decided and done for one change? | The AI-native SDLC playbook (claude.com/blog/the-ai-native-sdlc-playbook) | Intent, spec, plan, then the PR; findings from reviews and research; the operations log (append-only, one entry per run applied to a running system) | Point in time: a record once written, never edited again |
| **System** | What is, right now? | C4 (Simon Brown's), plus a runbook | The C4 views with their element tables, the decisions that cut across them; the runbook | Living: always what's built (planned elements dashed) |

In the system family:

- **C4 views:** system context, container, and deployment; a component
  view for a container whose parts others rely on. Every view has an
  element table below its diagram. A fact about an element (what it
  runs as, its credentials, its data, who reaches it) goes into that
  table or another table below the diagram keyed by element, never a
  separate document. A component groups related parts behind one
  interface; it isn't a file. The code level stays undrawn.
- **Runbook:** the one thing C4 doesn't cover: step-by-step procedures
  to run, change and recover the system. Steps only; facts are linked
  to the views.

## Rules

- **A fact's family decides its home.** Status only in the backlog; what
  was decided for one change only in its spec; what is only in the
  system docs. Link from anywhere else, never copy.
- **Terms come from the family's standard**, named as that standard
  names them. No analogies between standards ("the architecture is the
  high-level spec"). Where no standard has a term, say it's our own.
- **Outcomes aren't deliverables.** An outcome (a goal) is what's
  different for the human once it's done, checked by acceptance
  criteria; a deliverable is what gets built to get there. The vision,
  backlog items and intents state outcomes; specs and plans list
  deliverables. A backlog item that names a deliverable instead of an
  outcome is rewritten, or moves into a spec.
- **The backlog is ordered by milestones**, each an outcome with
  acceptance criteria. A milestone becomes an intent when it starts; its
  criteria are the intent's outcome. Phases and steps belong in plans.
- **Records stay as written.** Only link targets change, when files move.
  No "superseded" banners: the later spec says what it replaces. Every
  open finding in a record ends up in exactly one place: done (linked),
  the backlog, a spec, an accepted risk in the system docs, or another
  system's (listed in the backlog as handed over). An intent's acceptance
  checks that none is left only in a record.
- **Something that doesn't fit** gets placed in its family, not a new
  kind of document.
- **The branch that builds a change updates the system docs** (the C4
  views and their element tables, the runbook). The spec stays as its record.
- **A change's size** (one PR or an intent) and its steps: the
  `workflow:sizes-of-change` skill.
