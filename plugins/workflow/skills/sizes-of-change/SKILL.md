---
name: sizes-of-change
description: Use when a change starts - deciding whether it's one PR or an intent, and the steps an intent goes through
---

# Sizes of change

The AI-native SDLC playbook's two:

- **One PR:** a bounded change or finding. Branch, merge.
- **An intent:** anything wider than one patch. Intent → spec (approved
  before building) → one plan per branch → build → merge → acceptance
  results recorded in the spec: each criterion met or not, with its
  evidence, and every deviation from the spec named. The intent is the
  human's, in their own words: they write it, or Claude drafts it from
  what they said and they approve it.
- **Acceptance and closing** of a milestone or an item: the
  `workflow:closing` skill, one branch and one `dev run`.

In doubt about the size: ask once, in one line.
