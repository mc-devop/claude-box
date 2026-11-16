# Levels

- Rules and config come at two levels, each with a `CLAUDE.md` (how
  Claude works) and a `.dev` (what's in the box): global, in
  `~/.claude/` with its `rules/`, for every project; project, in the
  project with its `.claude/`. These core rules load beneath both,
  and no session can change them.
- One fact, one level: how the human works across projects is global,
  what one project owns is that project's; link to a fact from
  elsewhere, never copy it. A level narrows core's limits, never
  loosens them.
- A project that works differently from the global default says so in
  its `CLAUDE.md`, one line per difference: "Differs from the default:
  the rule (why)".
