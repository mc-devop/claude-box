# shellcheck shell=bash
# dev's shared helpers: errors, questions, images and the base build.

die() { echo "$*" >&2; exit 1; }

# The image's id, or nothing when there's none.
image_id() { podman image inspect --format '{{.Id}}' "$1" 2>/dev/null || true; }

# A rebuilt image leaves the one it replaced untagged: remove it by its id,
# and any earlier leftover of dev's (label claude-box.image) whose box has
# ended since. Podman refuses while a container uses one; it stays then.
drop_old() {  # old-id image
    local id
    { [ -n "$1" ] && [ "$1" != "$(image_id "$2")" ] && echo "$1"
      podman images --quiet --filter dangling=true --filter label=claude-box.image 2>/dev/null
    } | sort -u | while read -r id; do
        podman image rm "$id" > /dev/null 2>&1 || true
    done
}

# The parts of core/ the image holds (the Containerfile copies them);
# dev's own lib/, defaults.dev and the README aren't in it.
CORE_PARTS="Containerfile managed-settings.json rules bin plugin"

# core_key: a hash of git's tree ids of those parts on the clone's main;
# fails without them.
core_key() {
    local p refs=() ids
    for p in $CORE_PARTS; do refs+=("main:core/$p"); done
    ids="$(git -C "$HERE" rev-parse "${refs[@]}" 2>/dev/null)" || return 1
    printf '%s\n' "$ids" | sha256sum | cut -c1-40
}

# The image is built from core/ as it is on the clone's main (git archive),
# never from the working tree: a branch you're reviewing never reaches it.
# It's labelled claude-box.core (core_key) and claude-box.commit (main's
# commit), for check_core.
# CLAUDE_BUILD changes on every build, so the installer layer isn't taken
# from the cache: dev build always installs the latest Claude Code.
build() {
    local old key dir rc=0
    key="$(core_key)" || die "dev builds from the clone's main branch: $HERE has none (git clone it)"
    old="$(image_id "$IMAGE")"
    dir="$(mktemp -d)"
    if git -C "$HERE" archive main core | tar -x -C "$dir"; then
        podman build --pull=newer --build-arg CLAUDE_BUILD="$(date +%s)" --label "claude-box.core=$key" \
            --label "claude-box.commit=$(git -C "$HERE" rev-parse main)" \
            -t "$IMAGE" -f "$dir/core/Containerfile" "$dir/core" || rc=$?
    else rc=1; fi
    rm -rf "$dir"
    [ "$rc" = 0 ] || return "$rc"
    drop_old "$old" "$IMAGE"
}

# check_core: builds the image when there's none. When core on main differs
# from the one the image was built from, shows which files changed and
# rebuilds after your yes; no, no terminal or a failed build: the old image.
check_core() {
    local want have
    podman image exists "$IMAGE" || { build; return 0; }
    local was p paths=()
    want="$(core_key)" || die "dev builds from the clone's main branch: $HERE has none (git clone it)"
    have="$(label "$IMAGE" claude-box.core)"
    [ "$want" != "$have" ] || return 0
    echo "Core changed on main since your image was built:"
    was="$(label "$IMAGE" claude-box.commit)"
    for p in $CORE_PARTS; do paths+=("core/$p"); done
    if [ -n "$was" ] && git -C "$HERE" cat-file -e "$was^{commit}" 2>/dev/null; then
        # the commits, so you see what you approve, and the files they change
        git -C "$HERE" log --oneline "$was..main" -- "${paths[@]}" | sed 's/^/  /'
        git -C "$HERE" diff --stat "$was" main -- "${paths[@]}" | sed 's/^/  /'
    else
        echo "  (the image doesn't say which core it was built from, so the files can't be listed)"
    fi
    if ask "Rebuild the image?"; then
        build || echo "Rebuilding failed: starting on the old image."
    else echo "Starting on the old image."; fi
}

label() { podman image inspect --format "{{index .Labels \"$2\"}}" "$1" 2>/dev/null || true; }

# Asks a yes/no question on a terminal, Enter meaning yes; without a
# terminal the answer is no, so nothing is installed unseen.
ask() {
    local ans
    printf '%s [Y/n] ' "$1"
    if [ ! -t 0 ]; then echo "no (no terminal here: run dev shell in a terminal to answer)"; return 1; fi
    read -r ans || return 1
    [[ "$ans" != [nN]* ]]
}

# ask_no <question>: as ask, but only y answers yes; Enter is no.
ask_no() {
    local ans
    printf '%s [y/N] ' "$1"
    if [ ! -t 0 ]; then echo "no (no terminal here: run dev shell in a terminal to answer)"; return 1; fi
    read -r ans || return 1
    [[ "$ans" == [yY]* ]]
}

# Prints what changes from the "kind:name" words in $1 to those in $2.
show_change() {
    local old new w
    read -ra old <<< "$1"; read -ra new <<< "$2"
    for w in "${new[@]}"; do [[ " $1 " == *" $w "* ]] || echo "  + ${w%%:*} ${w#*:}"; done
    for w in "${old[@]}"; do [[ " $2 " == *" $w "* ]] || echo "  - ${w%%:*} ${w#*:}"; done
}
