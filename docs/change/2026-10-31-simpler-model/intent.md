# Intent: you set claude-box up once, and see how it hangs together

Drafted by Claude from the owner's words (claude-box session,
2026-10-31); approved by the owner 2026-10-31.

## In the owner's words

"I want to figure out what is core with my workflow and put it as
default, and I want it EASY to understand, these 3 layers … and how
they fit together, where the input edits and so on has to be super
clear … I want as little code as possible and as simple concept … a new
user understands what to edit and how and what is impacted."

"First consider the use, not what we have implemented."

"The user is someone like me. But the config is done once … and I have
no idea how to do it because now it's too complicated, so it has to be
easier to understand and do."

"Don't forget to consider a user looking at the code base needs to
understand how things hang together also."

On bringing things in: "a user should be able to config to import a mod
simply … also import other skills or plugin or whatever from anywhere,
and he shouldn't have to figure out himself where to put it."

On the levels: "perhaps we remove the company level thinking? and we
stay with global and [project]", with the global config "in home, same
as .claude", and "editing .claude is not done by auto, but each edit
needs to be explicit". On packs: "can we make it into a plugin even?"
And: "I want a possible future to just have to install it once."

## Outcome

You set claude-box up once, from the README, without help: you install
it, write your name, and you're working your way. From then on you change
anything (your setup, a project's, claude-box itself) by asking Claude,
and the next `dev claude` shows the change and applies it after your yes.
You never wonder whether to build or restart. Anything you want to bring in
(a plugin, a mod, a skill, a rules file, a whole way of working) is one
line, and claude-box decides where it goes. Someone opening the repo sees
the same model the README describes: what's core, what's optional,
and where yours lives.

## Acceptance criteria

- A new user sets up with `./dev install` alone; the config it writes,
  `~/.claude/.dev`, has their identity and one line for the workflow,
  and every other kind is explained in one reference file.
- Two levels only, the same at both: global (`~/.claude/`) and project,
  each with a `CLAUDE.md` for how Claude works and a `.dev` for what's
  in the box, in one vocabulary. No user-facing "company" layer.
- One `use <where>` line brings in a plugin (mods and skills
  included), a bare skill, a rules file, or the workflow, globally or
  for one project; the user never names a layer or folder and never
  types a hash.
- After a change to core, a plugin or a `.dev`, the next `dev claude`
  shows it and applies it after your yes, rebuilding when needed;
  `dev update` brings a new claude-box the same way.
- Without the workflow, a box still has every rule its own mechanics
  need (`dev run`, branches, secrets); with it, superpowers comes along.
- Claude asks you before every edit under `~/.claude/` in its own
  tools, in auto mode too; what it can't cover is a known limit in the
  architecture.
- Before writing a `local` step, Claude knows your laptop's OS and
  which common tools it has, without you configuring it.
- The repo's top level reads as the model (`dev`, `core/`, `plugins/`,
  `tests/`, `docs/`), each part with a short map; a fresh reader
  answers "where does X live, who changes it, how does it take effect"
  from the README and the maps alone.
- Your own setup moves over: the same behaviour in all four of your
  projects, from your `~/.claude/.dev`, and your `settings.json` no longer
  carries what core now holds.

## Not in this intent

- Installing from a package manager (npm, brew, COPR): a later
  milestone, decided then.
- Building in the typed rituals ("check logs", the review question).
- Keeping the backlog in GitHub Issues: its own backlog item, which
  becomes a plugin in this model.
