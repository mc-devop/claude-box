#!/usr/bin/env bash
# Checks for the plugins-in-image spec (S2, S7, S11), in throwaway boxes
# from the base image the laptop has. Touches nothing of yours: every box
# sees only folders under one mktemp -d, and Claude Code's config folder
# in each box is a throwaway too. Full output goes to out/seed-checks/
# for Claude to read; this prints one line per check.
#
# Run from the claude-box clone: bash docs/change/2026-11-01-plugins-in-image/seed-checks.sh
set -uo pipefail
IMG=localhost/claude-box
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
OUT="$PWD/out/seed-checks"; rm -rf "$OUT"; mkdir -p "$OUT"
mkdir -p "$T/seedA" "$T/seedB" "$T/cfg"
run() { podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all \
        --security-opt=no-new-privileges "$@"; }

# 1. Staging: two seeds, one plugin each, from the same marketplace. Does
# claude plugin install work without a login?
# shellcheck disable=SC2016 # $0 expands in the box
stage() {   # stage <folder> <plugin>
    run -v "$1":/seed:z -e CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed -e CLAUDE_CONFIG_DIR=/tmp/h "$IMG" \
        bash -c 'mkdir -p /tmp/h && claude plugin marketplace add obra/superpowers-marketplace && claude plugin install "$0"' "$2"
}
stage "$T/seedA" superpowers@superpowers-marketplace > "$OUT/1a-stage.txt" 2>&1; a=$?
stage "$T/seedB" elements-of-style@superpowers-marketplace > "$OUT/1b-stage.txt" 2>&1; b=$?
echo "1. staging without a login: seed A exit $a, seed B exit $b"
( cd "$T" && find seedA seedB -maxdepth 4 -not -path '*/.git/*' | sort ) > "$OUT/1c-seed-tree.txt"
cp "$T/seedA/installed_plugins.json" "$OUT/1d-seedA-installed.json" 2>/dev/null
cp "$T/seedA/known_marketplaces.json" "$OUT/1e-seedA-known.json" 2>/dev/null

# 2. Both seeds read-only, B first, both plugins switched on in a managed
# drop-in: does each load, from its own seed?
printf '{"enabledPlugins": {"superpowers@superpowers-marketplace": true, "elements-of-style@superpowers-marketplace": true}}\n' > "$T/dropin.json"
run -v "$T/seedA":/seedA:ro,z -v "$T/seedB":/seedB:ro,z -v "$T/cfg":/cfg:z \
    -v "$T/dropin.json":/etc/claude-code/managed-settings.d/x.json:ro,z \
    -e CLAUDE_CODE_PLUGIN_SEED_DIR=/seedB:/seedA -e CLAUDE_CONFIG_DIR=/cfg "$IMG" \
    claude plugin list --json > "$OUT/2-plugin-list.json" 2> "$OUT/2-plugin-list.stderr"; c=$?
echo "2. plugin list with both seeds: exit $c"

# 2b. A session start with both seeds and no login: plugins load before
# the login is checked, so Claude Code's debug log says what it loaded,
# and from where. Only lines naming a plugin, a seed or a marketplace are
# kept.
mkdir -p "$T/cfg2"
timeout 120 podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all \
    --security-opt=no-new-privileges -v "$T/seedA":/seedA:ro,z -v "$T/seedB":/seedB:ro,z -v "$T/cfg2":/cfg:z \
    -v "$T/dropin.json":/etc/claude-code/managed-settings.d/x.json:ro,z \
    -e CLAUDE_CODE_PLUGIN_SEED_DIR=/seedB:/seedA -e CLAUDE_CONFIG_DIR=/cfg "$IMG" \
    claude --debug -p hello < /dev/null > "$OUT/2b-session.txt" 2>&1; d=$?
grep -rhiE 'superpowers|elements-of-style|seed|marketplace|plugin' "$T/cfg2" "$OUT/2b-session.txt" 2>/dev/null \
    | grep -viE 'token|key|secret|auth' | head -200 > "$OUT/2b-plugin-lines.txt"
( cd "$T/cfg2" && find . -type f | sort ) > "$OUT/2c-cfg2-files.txt"
cp "$T/cfg2/plugins/known_marketplaces.json" "$OUT/2d-cfg2-known.json" 2>/dev/null
echo "2b. session start without a login: exit $d, $(wc -l < "$OUT/2b-plugin-lines.txt") plugin lines in the debug log"

# 3. What Claude Code wrote into its (throwaway) config folder.
( cd "$T/cfg" && find . -type f | sort ) > "$OUT/3a-cfg-files.txt"
cp "$T/cfg/plugins/known_marketplaces.json" "$OUT/3b-cfg-known.json" 2>/dev/null
echo "3. files written into the config folder: $(wc -l < "$OUT/3a-cfg-files.txt")"
echo "Done; details in out/seed-checks/"
