# Spec: a new box finds the seeds' marketplaces registered

For the [intent](intent.md), from the second acceptance run
([results](spec.md#acceptance-results-2026-11-03-second-run)): since
every box has its own plugins folder ([spec-plugins-dir](spec-plugins-dir.md)),
a box's first interactive session starts with no marketplace registered,
skips the seed's plugins ("marketplace not registered"), registers the
seeds' marketplaces, and asks for `/reload-plugins`. Approved by the
owner 2026-11-03 ("yes fix it").

**What this adds:** P5 below. Every decision in spec-plugins-dir stands.

**Checked in this box** (2026-11-03, a throwaway config folder each):
with an empty plugins folder, a session start logs 3 marketplaces
skipped as orphaned, then a sync from the seed; with the seeds'
`known_marketplaces.json` already there, none is skipped and nothing is
synced: the plugins load from the seed at once.

## Decisions

| # | Topic | Decision |
|---|---|---|
| P5 | The registration in the image | Each image with a seed carries `/home/claude/.claude/plugins/known_marketplaces.json`, built by `dev` from its approved seed or seeds: one entry per seed marketplace, as Claude Code writes it (its `source` from the seed's own record, `installLocation` the marketplace's folder in the image's seed, `autoUpdate` false). Your layer's names your seed's marketplaces; a project's image names its seed's, then yours, the first seed with a marketplace winning, as `CLAUDE_CODE_PLUGIN_SEED_DIR` orders them. Podman fills each box's new plugins volume from the image's folder there, so the first session finds them registered. A marketplace name that isn't `[A-Za-z0-9_.-]+` is left out |

## Deliverables

On `claude/plugins-registration`, from the current `main`:

- `core/lib/seed.sh`: `seed_known_json <seed dir> <image seed path>...`.
- `core/lib/layer.sh`, `core/lib/project.sh`: write it beside the
  drop-in and copy it to the image's `/home/claude/.claude/plugins/`.
- Tests in `tests/test_dev.sh`: your layer's file names your seed's
  marketplaces at `/usr/local/share/claude-box/seed/marketplaces/<name>`;
  a project's names its own first, then yours; a bad name is left out;
  no seed, no file.
- Docs: deployment's Plugins table, a row for the registration.

## Acceptance

- A read-only check before building, in a throwaway box from an image
  carrying the file: the new plugins volume holds it, Claude can write
  it, and a session start skips no marketplace.
- After the merge: a new box's first session in your terminal doesn't
  ask for `/reload-plugins`.
