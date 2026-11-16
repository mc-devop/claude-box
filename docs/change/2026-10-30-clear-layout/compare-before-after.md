# Findings: your box before branch 1 and after branch 3

For the spec's acceptance row *Your box as before*
([spec](spec.md#acceptance)). Read inside the box (a session of
yours), before branch 1 (2026-10-30) and after branch 3's merge run and
your `dev build` (2026-10-30), into `out/compare/before/` and
`out/compare/after/`, which stay in `out/`: your global `CLAUDE.md` is
yours, not for the public repo. Here: the checksums and every
difference.

## Checksums (sha256, first 12 characters)

| File | Before | After |
|---|---|---|
| `/etc/claude-code/CLAUDE.md` (the box's own rules) | `73604246bf42` | `46aa7ad4146d` |
| `/etc/claude-code/local.md` (imports your company rules) | `407de4cea850` | `053d3d456628` |
| `local/01-CLAUDE.md` (Karpathy, pinned) | `694a2d721e41` | `694a2d721e41` |
| `local/…-documentation.md` | `f25903471637` (02) | `f25903471637` (03) |
| `local/…-change-management.md` | `4f2c75503cd6` (03) | `4f2c75503cd6` (02) |
| `/etc/claude-code/managed-settings.json` | `970faa33541d` | `970faa33541d` |
| `git config --system` (identity) | `8b6542d1ffb1` | `8b6542d1ffb1` |
| The image's plugins (`box-workflow`, `workflow`) | `e6a7d7abb9d8` | `e6a7d7abb9d8` |
| `~/.claude/CLAUDE.md` (your global) | `6e8e11a7d602` (88 lines) | `ea683baff601` (42 lines) |
| `~/.claude/rules/workflow/markdown.md` | none | `f11ed21e27c1` |
| `~/.claude/rules/workflow/specs-and-plans.md` | none | `21153fc3cdc5` |
| `/usr/local/share/claude-box/packs/workflow/starter/` | none | `tests/check_links.py` |

## The differences

- **The box's own rules:** one sentence added, as branch 3 planned
  (E12): "A line `pack <name>` brings that pack's project rules, when
  the human's config has the pack."
- **`local.md`:** the same two company rule files, imported in the
  other order: change management before documentation (the pack's
  `company/` files in name order).
- **Your global `CLAUDE.md`:** its sections *Specs and plans
  (superpowers)* and *Markdown files* left it (88 lines to 42) and are
  now `packs/workflow/global/`, mounted at `~/.claude/rules/workflow/`,
  rewritten without your terms (D13). Every other section is unchanged.
- **The starter:** new, D3's read-only place for the pack's project
  part.
- Identity, plugins and managed settings: the same.
