# Specs and plans (superpowers)

The superpowers plugin, enabled for every project, writes a change's
documents: brainstorming the spec, writing-plans the plans,
executing-plans or subagent-driven-development the build. Unless a
project says otherwise, `docs/` holds one folder per family:
`direction/` (`vision.md`, `backlog.md`), `change/` and `system/`
(`architecture/` for the C4 views, `runbook.md`). Under `change/`, one
folder per change, `YYYY-MM-DD-<topic>/`, holds all its records:
`intent.md`, `spec.md`, one `plan-<topic>.md` per branch, the findings
that fed it, its scripts; this replaces superpowers' default paths. A
finding that served no single change gets its own dated folder; the
operations log, `operations-log.md`, sits at the top of `change/`.
Plans keep superpowers' checkbox format but aren't ticked: progress
shows in the commits and the backlog's status. Earlier documents keep
their paths.
