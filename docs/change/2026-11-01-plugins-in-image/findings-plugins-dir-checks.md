# Findings: the box's own plugins folder, checked in a real box (2026-11-03)

Task 1 of the [plan](plan-plugins-dir.md): the [spec](spec-plugins-dir.md)'s
P1 and P2, run on the owner's laptop with
[plugins-dir-checks.sh](plugins-dir-checks.sh) in throwaway boxes from
the owner's layer, each box's `~/.claude` a temp folder. Three runs; the
[log](plugins-dir-checks.log) of the last.

| # | Question | Answer | Consequence |
|---|---|---|---|
| 1 | Does a tmpfs at `~/.claude/plugins` give the box an empty folder? | **No.** With `--mount type=tmpfs,…,U=true` and with `--tmpfs …:U`, `/proc/mounts` lists the tmpfs, yet the box sees the host folder's file: the `~/.claude` bind lands on top of it. `--tmpfs` with `uid=` is refused by Podman | P1's tmpfs is replaced, below |
| 2 | Do an anonymous volume (`--mount=type=volume,destination=/home/claude/.claude/plugins,U=true`), an empty folder bound there, or a tmpfs elsewhere named by `CLAUDE_CODE_PLUGIN_CACHE_DIR` give an empty folder, Claude's, writable? | **Yes, all three** (`claude 755`, no entries, writable) | Any of them would do |
| 3 | With `data/` and `store/` bound into it: what outlives the box? | **Only `data/x` and `store/x`**, for all three; a file written beside them is gone | P2 holds |
| 4 | With an old install record (superpowers 6.4.2, scope `managed`) in the config folder: does the session take the seed? | **Yes, for all three**: "Using seed cache" for c4m 2.0.0, modularity 1.5.0 and superpowers **7.0.1**, at `/usr/local/share/claude-box/seed/cache/…`; the 6.4.2 path never named | The fix works |

**Chosen: the anonymous volume.** `--rm` removes it with the box, so
nothing is left on the laptop; the bound folder would need `dev` to make
and remove a host folder per box; the cache-dir route rests on runtime
behaviour the docs don't spell out, and leaves your `~/.claude/plugins`
in the box's sight. **Deviation from the spec:** P1 says tmpfs; the box
gets an anonymous volume, with the same effect (empty at start, gone
with the box). Task 2's option: `--mount=type=volume,destination=/home/claude/.claude/plugins,U=true`.
