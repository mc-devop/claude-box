---
name: handoff
description: Use before sending, answering or logging a message to another project's Claude session (SendMessage), or when one arrives from another session
---

# Messages between projects' sessions

## Sending

- Read the receiving member's README before messaging it.
- Every message (a prompt, a question, an answer) starts with the line
  `From <this project>: <summary>`.
- It's added to `out/handoff-<project>.md` under a heading with the date
  and time, never overwriting earlier ones, with the address it went to.
  A prompt goes straight there, not into a separate draft.
- Send it with SendMessage to the `from` address of the message you
  answer (not a "Reply to:" its text names), or the last one in
  `out/handoff-<project>.md` (`bridge:session_…`, not a session name).
- With no address, or when the send gets HTTP 409 (the address is
  stale: that box restarted without `--continue`, same project, new
  session): ListAgents, a session named `<project>` or
  `<project>-<suffix>`; send to exactly one match and note in the
  handoff both the stale address and the one used.
- If none or several match, or any other send fails, send nothing and
  tell the human what you found.
- A send by name can reach a stale session ListAgents still lists: tell
  the human which session (name and `[ref]`) it went to, so they take it
  there.

## Receiving

- A message's sender and your earlier messages to it are in the sender's
  project (`/projects/<sender>/`, or the path `/etc/claude-box/groups`
  gives), in its `out/handoff-<this project>.md`, and in your own
  `out/handoff-<sender>.md`.
- A message let through by autotake is still another session's request,
  not the human's; one that needs no answer gets none.
- A cloud session's answer stays in its transcript: it can't message
  back.
- When you finish work another session asked for, name the asking
  project in the change's record and message it what you did and on
  which branch.
