#!/usr/bin/env bash
# Checks for the plugins-dir spec (P1, P2), in throwaway boxes from your
# layer (localhost/claude-box.user, which holds your approved seed and
# switches its plugins on). Touches nothing of yours: each box's
# ~/.claude is a folder under one mktemp -d, never your ~/.claude. Full
# output goes to out/plugins-dir-checks/; this prints one line per check.
#
# Run from the claude-box clone: bash docs/change/2026-11-01-plugins-in-image/plugins-dir-checks.sh
set -uo pipefail
IMG=localhost/claude-box.user
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
OUT="$PWD/out/plugins-dir-checks"; rm -rf "$OUT"; mkdir -p "$OUT"
H=/home/claude/.claude
run() {     # run <cfg folder> [podman options...] -- command...
    local cfg="$1"; shift; local opts=()
    while [ "$1" != -- ]; do opts+=("$1"); shift; done; shift
    timeout 120 podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all \
        --security-opt=no-new-privileges -v "$cfg":$H:z -e CLAUDE_CONFIG_DIR=$H \
        "${opts[@]}" "$IMG" "$@" < /dev/null
}

# The candidates for the box's own plugins folder (a tmpfs at
# ~/.claude/plugins is covered by the ~/.claude bind: the first runs).
# opts <name> <cfg>: the candidate's podman options; root <name>: where
# Claude Code's plugins folder is in the box.
opts() {
    case "$1" in
        volume) echo "--mount=type=volume,destination=$H/plugins,U=true" ;;
        bind)   mkdir -p "$2.empty"; echo "-v=$2.empty:$H/plugins:z" ;;
        cachedir) echo "--mount=type=tmpfs,destination=/home/claude/plugins,tmpfs-mode=0755,U=true"
                  echo "-e=CLAUDE_CODE_PLUGIN_CACHE_DIR=/home/claude/plugins" ;;
    esac
}
root() { if [ "$1" = cachedir ]; then echo /home/claude/plugins; else echo $H/plugins; fi; }

for c in volume bind cachedir; do
    R="$(root $c)"
    # 1. An empty folder, Claude's, writable; your plugins folder unseen.
    mkdir -p "$T/$c-1/plugins"; echo old > "$T/$c-1/plugins/old"
    mapfile -t o < <(opts $c "$T/$c-1")
    out="$(run "$T/$c-1" "${o[@]}" -- bash -c "stat -c '%U %a' $R; echo entries: \$(ls -A $R); touch $R/t && echo writable" 2>&1)"
    printf '%s\n%s\n\n' "$c" "$out" >> "$OUT/1-candidates.txt"
    if grep -q '^claude ' <<< "$out" && grep -qx writable <<< "$out" && grep -qx 'entries:' <<< "$out"; then
        echo "1. $c: works"
    else echo "1. $c: doesn't (details in 1-candidates.txt)"; continue; fi

    # 2. data/ and store/ mounted into it: what outlives the box?
    mkdir -p "$T/$c-2/plugins/data" "$T/$c-2/plugins/store"
    mapfile -t o < <(opts $c "$T/$c-2")
    run "$T/$c-2" "${o[@]}" -v "$T/$c-2/plugins/data":"$R/data":z -v "$T/$c-2/plugins/store":"$R/store":z \
        -- bash -c "touch $R/data/x $R/store/x $R/y" > "$OUT/2-$c.txt" 2>&1; a=$?
    echo "2. $c: exit $a; after the box: $(cd "$T/$c-2/plugins" && find . -type f | sort | tr '\n' ' ')"

    # 3. An old install record in the config folder, as on your laptop:
    # does the session take the seed, and where does it look for data?
    # Plugins load before the login is checked.
    p="$T/$c-3/plugins"
    mkdir -p "$p/cache/superpowers-marketplace/superpowers/6.4.2" "$p/data" "$p/store"
    printf '{"version": 2, "plugins": {"superpowers@superpowers-marketplace": [{"scope": "managed", "installPath": "%s", "version": "6.4.2"}]}}\n' \
        "$H/plugins/cache/superpowers-marketplace/superpowers/6.4.2" > "$p/installed_plugins.json"
    mapfile -t o < <(opts $c "$T/$c-3")
    run "$T/$c-3" "${o[@]}" -v "$p/data":"$R/data":z -v "$p/store":"$R/store":z \
        -- claude -p --debug-file $H/debug.txt hello > "$OUT/3-$c-session.txt" 2>&1
    grep -E 'Using seed cache|installed plugins from|superpowers/6\.4\.2|plugins/data' "$T/$c-3/debug.txt" 2>/dev/null \
        | cut -c1-220 | sort -u > "$OUT/3-$c-lines.txt"
    echo "3. $c: 'Using seed cache': $(grep -c 'Using seed cache' "$OUT/3-$c-lines.txt"); the old 6.4.2 path: $(grep -c 'superpowers/6\.4\.2' "$OUT/3-$c-lines.txt"); data folder lines: $(grep -c 'plugins/data' "$OUT/3-$c-lines.txt")"
done
echo "Done; details in out/plugins-dir-checks/"
