# shellcheck shell=bash
# The read-only rules under ~/.claude/rules/: the rules files your rules
# lines name, and the rules/ of each plugin they name, from the approved
# copy; the project's group file; and the laptop's facts.

# mount_point <path> d|f: makes a mount point under ~/.claude/rules/, as
# you. A link on its way is refused: any box can write there, and dev and
# Podman would follow it, also out of ~/.claude.
mount_point() {
    local p
    for p in "$HOME/.claude/rules" "$(dirname "$1")" "$1"; do
        [ ! -L "$p" ] || die "$p is a link: refused (any box can write there; remove the link)"
    done
    if [ "$2" = d ]; then mkdir -p "$1"
    else mkdir -p "$(dirname "$1")"; [ -e "$1" ] || : > "$1"; fi
}

# The commands host_facts looks for on the laptop (spec D11).
HOST_TOOLS="git gh podman ssh rsync flatpak rpm-ostree dnf brew toolbox systemctl sudo python3 curl jq"

# host_facts <out> [os-release]: writes the laptop's facts for the box's
# /etc/claude-box/host: "os <PRETTY_NAME>", "shell <name>", then "has" and
# "lacks", each followed by its HOST_TOOLS names. Reads os-release
# (default /etc/os-release) with sed, never sources it.
host_facts() {
    local os="" t has="" lacks="" sh="${SHELL:-}"
    [ ! -r "${2:-/etc/os-release}" ] \
        || os="$(sed -n 's/^PRETTY_NAME=//p' "${2:-/etc/os-release}" | head -n 1 | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
    for t in $HOST_TOOLS; do
        if command -v "$t" > /dev/null; then has+=" $t"; else lacks+=" $t"; fi
    done
    sh="${sh##*/}"
    printf 'os %s\nshell %s\nhas%s\nlacks%s\n' "${os:-unknown}" "${sh:-unknown}" "$has" "$lacks" > "$1"
}

# mount_sources <items> <approved>: adds to MOUNTS each rules file of the
# items at rules/files/<its name>, and each plugin's rules/ at
# rules/<plugin>/, from the approved copy <approved>. Makes each mount
# point first, as you (mount_point): one Podman made would belong to a
# user of its namespace, in your ~/.claude.
mount_sources() {
    local kind val src r="$HOME/.claude/rules" t=/home/claude/.claude/rules
    while read -r kind val; do
        { [ "$kind" = plugin ] || [ "$kind" = rules ]; } && [ "$(use_form "$val")" != market ] || continue
        src="$(use_src "$val" "$2")"
        if [ "$kind" = rules ]; then
            mount_point "$r/files/$(use_name "$val")" f
            MOUNTS+=(-v "$src:$t/files/$(use_name "$val"):ro,z")
        elif [ -d "${src%/}/rules" ]; then
            mount_point "$r/$(use_name "$val")" d
            MOUNTS+=(-v "${src%/}/rules:$t/$(use_name "$val"):ro,z")
        fi
    done <<< "$1"
}

# Sets MOUNTS (podman -v words): the rules of your approved config and,
# in a project, of its approved plugin and rules lines (setting
# PROJECT_APPROVED, which choose_image builds from); the laptop's facts;
# the project's group.
choose_mounts() {
    local items="" val
    MOUNTS=(); PROJECT_APPROVED=""
    if [ -e "$CONF_FILE" ] && approved_ok; then
        items="$(read_conf "$APPROVED/.dev" "$APPROVED")" || exit 1
    fi
    mount_sources "$items" "$APPROVED"
    # The laptop's facts, at /etc/claude-box/host, for every box.
    val="$(dirname "$APPROVED")/host"
    mkdir -p "$(dirname "$val")" && host_facts "$val" || exit 1
    MOUNTS+=(-v "$val:/etc/claude-box/host:ro,z")
    [ -z "$SCRATCH" ] || return 0
    DEV_NOTICE=1 read_dev > /dev/null || exit 1
    # This project's plugin and rules lines, after your yes (project.sh).
    choose_project_sources
    [ -z "$PROJECT_APPROVED" ] || mount_sources "$(read_conf "$PROJECT_APPROVED/.dev" "$PROJECT_APPROVED")" "$PROJECT_APPROVED"
    [ -z "$PROJECT_APPROVED" ] || seed_clear "$PROJECT_APPROVED/seed"
    # The project's group, at /etc/claude-box/groups (groups.sh).
    project_group
    [ -n "$GROUP" ] || return 0
    val="$(group_path)"
    mkdir -p "$(dirname "$val")" && group_file "$GROUP" "$val" || exit 1
    MOUNTS+=(-v "$val:/etc/claude-box/groups:ro,z")
}
