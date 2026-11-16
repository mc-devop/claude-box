# Intent: claude-box is public, and this repo is retired

Drafted by Claude from the owner's words (claude-box session,
2026-10-30); approved by the owner 2026-10-30.

## In the owner's words

Asked who the public repo is for, the owner chose: others who should be
able to install and run it, from the README alone. "But I would like to
create the repo as private until I have reviewed how it looks and
everything is as I want it at github before change the flag to public."

On GitHub Issues as a new user's backlog: "I would also like the
previous option open to the new user, if they want to use github issues
and backlog, then they are free to do so instead."

From the questions that followed: the public repo starts fresh, and this
repo's history and change records stay private in it; the vision and a
rewritten backlog go public, and planning goes on in the open; this repo
becomes `mc-devop/claude-box-archive` and the new one takes
`mc-devop/claude-box`; the license is MIT (Claude's recommendation);
the owner flips the flag to public in GitHub's settings ("I can do it
manually in the GUI"; `gh repo edit --visibility public` would do the
same); the other projects are told where claude-box now lives.

## Outcome

A stranger with Podman can clone `github.com/mc-devop/claude-box`,
follow its README alone and get a working box on the public defaults.
You run that same repo with your config, exactly as today, and develop
claude-box there, with its vision and backlog in the open. None of your
specifics are in it. This repo, its history and its change records stay
private as `claude-box-archive`. The new repo is public only after
you've reviewed it on GitHub and flipped the flag yourself.

## Acceptance criteria

- The new repo starts from one commit of today's tree without the
  change records, with an MIT license.
- No tracked file of the new repo holds a term from your
  `local/private-terms`, and a test fails when one does (the config
  milestone's open criterion, in its spec's acceptance results in the
  archive).
- Following only the README, a fresh clone without any config of yours
  installs and starts a box on the public defaults.
- The README says the rules and workflow packs are optional, so a user
  can plan their own way (e.g. GitHub Issues).
- Your box, built from the new clone with your `local/`, has the same
  rules, identity and plugins as before, and you develop claude-box
  there from then on.
- The new repo holds the vision and a rewritten backlog: none of your
  terms, no links into the archive.
- This repo is renamed `claude-box-archive` and archived on GitHub,
  still private.
- Your other projects are told where claude-box now lives.
- The new repo is public, flipped by you after your review.

## Not in this intent

- A pack where direction lives in GitHub Issues instead of
  `backlog.md`: its own backlog item.
- Rewriting this repo's history, or publishing its change records.
