#!/usr/bin/env bash
# Does the first session in a fresh box get the seed's plugins? A throwaway
# box from your layer, set up as dev now sets up a box (its own plugins
# volume, data/ and store/ bound in), with a temp folder as its ~/.claude,
# never yours. Two sessions in it, one after the other; each prints the
# marketplace plugins its init event reports, and the order of the debug
# lines about the seed. Full output goes to out/first-session-check/.
#
# Run from the claude-box clone: bash docs/change/2026-11-01-plugins-in-image/first-session-check.sh
set -uo pipefail
IMG=localhost/claude-box.user
T="$(mktemp -d)"; trap 'podman rm -f -v "$name" > /dev/null 2>&1; rm -rf "$T"' EXIT
OUT="$PWD/out/first-session-check"; rm -rf "$OUT"; mkdir -p "$OUT"
H=/home/claude/.claude
mkdir -p "$T/cfg/plugins/data" "$T/cfg/plugins/store"
name="first-session-check-$$"
podman run -d --rm --name "$name" --userns=keep-id:uid=1000,gid=1000 --cap-drop=all \
    --security-opt=no-new-privileges -v "$T/cfg":$H:z -e CLAUDE_CONFIG_DIR=$H \
    --mount=type=volume,destination=$H/plugins,U=true \
    -v "$T/cfg/plugins/data":$H/plugins/data:z -v "$T/cfg/plugins/store":$H/plugins/store:z \
    "$IMG" sleep 600 > /dev/null
# shellcheck disable=SC2016 # expands in the box
for i in 1 2; do
    timeout 120 podman exec "$name" bash -c 'claude -p --output-format stream-json --verbose --debug-file '"$H/debug-$i.txt"' ok < /dev/null' \
        > "$OUT/$i-stream.jsonl" 2>&1
    got="$(python3 -I -c 'import json, sys
for l in open(sys.argv[1]):
    try: d = json.loads(l)
    except ValueError: continue
    if d.get("subtype") == "init":
        print(" ".join(sorted(p["source"] for p in d["plugins"] if "@" in p["source"] and not p["source"].endswith(("@inline", "@builtin")))) or "none")
        break
else: print("no init event")' "$OUT/$i-stream.jsonl")"
    grep -E 'orphaned enabledPlugins|Synced .* from seed|Using seed cache|Loaded .* skills from plugin (superpowers|c4m|modularity)' "$T/cfg/debug-$i.txt" 2>/dev/null \
        | cut -c26-150 > "$OUT/$i-debug-lines.txt"
    echo "session $i: init reports: $got; debug: $(grep -c orphaned "$OUT/$i-debug-lines.txt") skipped as orphaned, $(grep -c 'Synced' "$OUT/$i-debug-lines.txt") sync, $(grep -c 'Using seed cache' "$OUT/$i-debug-lines.txt") from the seed, $(grep -c 'Loaded' "$OUT/$i-debug-lines.txt") skill loads"
done
echo "Done; details in out/first-session-check/"
