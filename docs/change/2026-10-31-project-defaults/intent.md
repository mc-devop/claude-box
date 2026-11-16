# Intent: new projects start alike and find their neighbours

Drafted by Claude from the owner's words (claude-box session,
2026-10-31); approved by the owner 2026-10-31.

## In the owner's words

"Before going public I also want the company level to be stipulating
how global and project should look like, e.g. the default schema that
makes them work seamlessly together. Of course you can have special
projects which collaborate differently internally, but I want the
default to be defined in company."

"For instance if I spin up 3 new neighboring projects, it could be
remote server, an app backend, and its app front end, they should be
able to find each other and work together like I have it now with
autotake and so on so that they can collaborate seamlessly."

On what `dev new` lays down: "company defines what dev new does." On
neighbours and trust: by default, "but this is also defined on company
level." On grouping: a group name, and "it should also be able to find
all projects in a specific folder locally"; reaching remote instances
and other accounts' instances "if it works, then I want it in and we
define it in company which accounts etc we can remote/autotake to."

## Outcome

You start three new projects that belong together, say a server, an
app's backend and its frontend. Each starts with the same files and
the same shape of `CLAUDE.md`, laid down by `dev new` from the company
default; each knows the other two, what they own, and messages them;
and their messages to each other go on as your prompt without a
`/autotake` per session, while everyone else's still wait for you. It
works the same for your sessions of those projects on other machines.
What belongs in company, global and project is written down once, at
company level; a project that works differently says where.

## Acceptance criteria

- `dev new` lays down the files the company default defines (the
  packs in your config), so a new project's `CLAUDE.md`, `docs/` and
  test run have the same shape as every other new project's.
- Projects in one folder you name in your config are one group; a
  project elsewhere joins a group with one line in its `.dev`, counted
  only after your yes, which Claude can't give; a project that lives
  only on another machine is named in your config. A project is in
  one group at most.
- In each project's box, Claude knows its group's members and reads
  what each owns in that project's own files, not in a copy.
- With trust switched on in your config, a group member's message goes
  on as your prompt, also from your sessions on other machines; a
  message from outside the group is held as today. Claude can't widen
  who's trusted.
- What belongs in company, global and project, and the shape of a
  project's `CLAUDE.md`, is written once in the company layer; your
  global `CLAUDE.md` is checked against it.
- Three projects made with `dev new` in a group folder message each
  other and are taken without a `/autotake`, shown by you starting
  their boxes.
- The repo goes public only after this milestone.

## Not in this intent

- Sessions of another Claude account: Claude Code reaches only your
  own account's sessions ([spec, E1](spec.md#evidence-2026-10-31)).
- Changing existing projects' files: they keep theirs and can join a
  group with one line.
