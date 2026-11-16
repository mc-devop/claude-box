# Acceptance: the demo-app group's sessions (2026-11-16)

For the [spec](spec.md#acceptance)'s by-hand step. The owner started
`dev claude` in `~/Projects/demo-app/app-backend`, `app-frontend` and
`app-docs` (made by `dev new`, [log](acceptance-dev-new.log)); claude-box,
outside the group, sent messages. Read from the three sessions'
transcripts in `~/.claude/projects/-work-app-*/` (times UTC).

## First try (17:02 to 17:06): every sender let through

- 17:02:34, app-backend, `/autotake`: "Taking messages from group
  demo-app (app-docs, app-frontend) as your prompt until /autotake off."
  The trust line from the config, before anything was typed.
- Then in all three boxes autotake for every session was switched on
  ("Taking messages from every session"), so claude-box's message (17:04:52)
  and app-backend's to app-frontend (17:05:11) both arrived "let through
  by your /autotake". Delivery and replies worked; neither the group's
  trust nor the hold was shown.
- app-backend's `cat /etc/claude-box/groups`: `group demo-app`,
  `member app-docs /projects/demo-app/app-docs`,
  `member app-frontend /projects/demo-app/app-frontend`, `autotake group`;
  it read app-frontend's `README.md` through that path. app-frontend's
  file listed app-backend and app-docs the same way.

## Second try (17:21): app-frontend restarted, autotake left off

The owner restarted app-frontend with `dev claude --continue` and pressed
*Leave off* on the row offering last session's autotake back.

- 17:21, claude-box to app-frontend ("outside-group check"): never in
  app-frontend's transcript, so it never reached Claude: held.
- 17:21:22, app-backend to app-frontend ("groups test 2"), arrived at
  17:21:25 as "Message from another session (let through by your
  autotake group)".
- 17:21:32, app-frontend's reply reached app-backend.

The held row itself wasn't looked at before the boxes were closed.
