#!/usr/bin/env bash
# The check before building P5 (spec-plugins-registration.md): an image
# carrying the seeds' known_marketplaces.json at ~/.claude/plugins/ fills a
# box's new plugins volume with it, Claude can write it, and a session
# start skips no marketplace. A throwaway image from your layer
# (localhost/claude-box-registration-check, removed at the end); each box's
# ~/.claude a temp folder, never yours. Full output: out/registration-check/.
#
# Run from the claude-box clone: bash docs/change/2026-11-01-plugins-in-image/registration-check.sh
set -uo pipefail
LAYER=localhost/claude-box.user IMG=localhost/claude-box-registration-check
T="$(mktemp -d)"; trap 'podman rmi -f "$IMG" > /dev/null 2>&1; rm -rf "$T"' EXIT
OUT="$PWD/out/registration-check"; rm -rf "$OUT"; mkdir -p "$OUT"
H=/home/claude/.claude S=/usr/local/share/claude-box/seed

# The file as P5 builds it, from the seed's own record in your layer.
podman run --rm "$LAYER" cat $S/known_marketplaces.json > "$T/seed-known.json" || { echo "No seed record in $LAYER"; exit 1; }
python3 -I - "$T/seed-known.json" "$S" > "$T/known_marketplaces.json" <<'EOF'
import json, re, sys
seed, path = json.load(open(sys.argv[1])), sys.argv[2]
print(json.dumps({m: {"source": v.get("source"), "installLocation": f"{path}/marketplaces/{m}", "autoUpdate": False}
                  for m, v in seed.items() if re.match(r"^[A-Za-z0-9_.-]+$", m) and isinstance(v, dict)}, indent=2))
EOF
printf 'FROM %s\nUSER root\nCOPY known_marketplaces.json %s/plugins/known_marketplaces.json\nRUN chmod 644 %s/plugins/known_marketplaces.json\nUSER claude\n' \
    "$LAYER" "$H" "$H" > "$T/Containerfile"
podman build -q -t "$IMG" -f "$T/Containerfile" "$T" > "$OUT/build.txt" 2>&1 || { echo "build failed: see out/registration-check/build.txt"; exit 1; }
echo "1. image built with the file: $(python3 -I -c 'import json, sys; print(sorted(json.load(open(sys.argv[1]))))' "$T/known_marketplaces.json")"

# A box as dev starts one.
mkdir -p "$T/cfg/plugins/data" "$T/cfg/plugins/store"
podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all --security-opt=no-new-privileges \
    -v "$T/cfg":$H:z -e CLAUDE_CONFIG_DIR=$H \
    --mount=type=volume,destination=$H/plugins,U=true \
    -v "$T/cfg/plugins/data":$H/plugins/data:z -v "$T/cfg/plugins/store":$H/plugins/store:z \
    "$IMG" bash -c "stat -c '%U %a' $H/plugins/known_marketplaces.json; touch $H/plugins/known_marketplaces.json && echo writable
        timeout 90 claude -p --debug-file $H/debug.txt hi < /dev/null > /dev/null 2>&1; true" > "$OUT/box.txt" 2>&1
echo "2. in a new box's volume: $(head -1 "$OUT/box.txt"), $(grep -cx writable "$OUT/box.txt") writable"
grep -E 'orphaned enabledPlugins|Synced .* from seed|Using seed cache' "$T/cfg/debug.txt" 2>/dev/null | cut -c26-150 > "$OUT/debug-lines.txt"
echo "3. a session start: $(grep -c orphaned "$OUT/debug-lines.txt") skipped as orphaned, $(grep -c Synced "$OUT/debug-lines.txt") sync, $(grep -c 'Using seed cache' "$OUT/debug-lines.txt") from the seed"
echo "Done; details in out/registration-check/"
