# shellcheck shell=bash
# A project: its .dev, plugins, image and ports.

# A project: a repo's top folder, or a folder in ~/Projects (where run_box
# still wants its .git). $HOME and / never are, even with a .git.
is_project() {
    local projects
    [ "$PWD" != "$(cd -P "$HOME" && pwd)" ] && [ "$PWD" != / ] || return 1
    [ ! -d .git ] || return 0
    projects="$(cd -P "$PROJECTS" 2>/dev/null && pwd)" || return 1
    [[ "$PWD" == "$projects"/* ]]
}
not_project() { die "Not a project: $PWD (no .git, not in ~/Projects). For a session without one: dev claude"; }

# lay_starters <name>: in a new project, the starter/ of each plugin your
# approved config's use lines name, without overwriting (a path two
# starters share is said and skipped); {{name}} replaced. A file named
# <x>.starter lands as <x> (the starter's CLAUDE.md would otherwise load
# as Claude's memory in this repo). A starter's .git/ or .dev is refused:
# git or dev would run it as you. Returns 1 on any failure, so dev new
# removes the half-made project.
lay_starters() {
    local items kind val pl src f dest
    items="$(approved_items)" || return 1
    while read -r kind val; do
        [ "$kind" = plugin ] || continue
        case "$(use_form "$val")" in clone|home) ;; *) continue ;; esac
        [ -e "$CONF_FILE" ] && approved_ok || continue
        pl="$(use_name "$val")"; src="$(use_src "$val" "$APPROVED")"; src="${src%/}/starter"
        [ -d "$src" ] || continue
        while IFS= read -r -d '' f; do
            f="${f#"$src/"}"; dest="${f%.starter}"
            if [[ "$dest" == .git/* || "$dest" == .dev ]]; then
                echo "refused: $pl's starter has $dest, which git or dev would run as you" >&2; return 1
            fi
            if [ -e "$dest" ]; then echo "  skipped $dest: $pl's starter has it too"
            else mkdir -p "$(dirname "$dest")" && cp -p "$src/$f" "$dest" || return 1; fi
        done < <(find "$src" -type f -print0 | sort -z)
    done <<< "$items"
    { grep -rlZF --exclude-dir=.git '{{name}}' . || true; } | xargs -0r sed -i "s/{{name}}/$1/g"
}

# .dev: what this project's box needs, one item per line: "<kind> <name>",
# kinds dnf, npm, pip, plugin and rules (the same values as in your
# config, checked by read_conf), port (a port to publish), group. Prints the
# items, one per line; dies on a line it can't read. "use" and "pack" lines
# are skipped (with a notice when DEV_NOTICE is set: choose_mounts, once per
# start).
read_dev() {
    [ -f .dev ] || return 0
    local n=0 line kind name repo extra groups=0 t e srcs=() at=()
    local ok='^[][A-Za-z0-9@._/+=:~<>!,-]*$'   # names go quoted into a Containerfile
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1)); line="${line%$'\r'}"
        read -r kind name repo extra <<< "${line%%#*}"
        [ -n "$kind" ] || continue
        [[ "$name$repo" =~ $ok ]] && [[ "$name" =~ ^[A-Za-z0-9@~] ]] \
            || [ -z "$name" ] || die ".dev line $n: \"$name${repo:+ $repo}\" has a character dev doesn't accept"
        case "$kind" in
            dnf|npm|pip) [ -n "$name" ] && [ -z "$repo" ] || die ".dev line $n: expected \"$kind <name>\"" ;;
            plugin|rules)   # the same values as in your config: read_conf checks them
                [ -z "$extra" ] || die ".dev line $n: expected \"$kind <value>\" (core/defaults.dev)"
                t="$(mktemp)"; printf '%s %s\n' "$kind" "$name${repo:+ $repo}" > "$t"
                if ! e="$( (read_conf "$t") 2>&1 >/dev/null)"; then
                    rm -f "$t"; die ".dev line $n: ${e#* line 1: }"
                fi
                rm -f "$t"; srcs+=("$kind $name${repo:+ $repo}"); at+=("$n")
                # one name, one level: a mount or a plugin folder would hide the other
                if [[ "$name" != *@* ]] && approved_items | awk -v k="$kind" '$1 == k { print $2 }' \
                        | while read -r e; do [ "$(use_name "$e")" = "$(use_name "$name")" ] && echo x; done | grep -q x; then
                    die ".dev line $n: \"$kind $name\": ~/.claude/.dev names $(use_name "$name") already (one level only)"
                fi
                # a marketplace plugin too: one seed per plugin
                if [[ "$name" == *@* ]] && approved_items | awk '$1 == "plugin" && NF == 3 { print $2 }' | grep -qxF -- "$name"; then
                    die ".dev line $n: \"plugin $name\": ~/.claude/.dev names $name already (one level only)"
                fi ;;
            use|pack)
                if [ -n "${DEV_NOTICE:-}" ]; then
                    if [ "$kind" = pack ]; then e="plugin <name>"
                    elif [[ "$name" == *.md ]] && [ -z "$repo" ]; then e="rules $name"
                    else e="plugin $name${repo:+ $repo}"; fi
                    echo ".dev line $n: \"$kind ${name}${repo:+ $repo}\" is no longer read: write \"$e\" (core/defaults.dev)" >&2
                fi
                continue ;;
            port) valid_port "$name" && [ -z "$repo" ] || die ".dev line $n: expected \"port <1-65535>\"" ;;
            group)
                valid_group "$name" && [ -z "$repo" ] || die ".dev line $n: expected \"group <name>\""
                groups=$((groups + 1)); [ "$groups" = 1 ] || die ".dev line $n: one group per project" ;;
            identity|projects|memory|cpus|remote-control|remote|autotake)
                die ".dev line $n: \"$kind\" is for ~/.claude/.dev only (global only)" ;;
            *) die ".dev line $n: unknown kind \"$kind\" (dnf, npm, pip, plugin, rules, port or group)" ;;
        esac
        echo "$kind $name${repo:+ $repo}"
    done < .dev
    # the plugin and rules lines together: one name once (a second would
    # be dropped when they're copied for approval)
    if [ ${#srcs[@]} -gt 1 ]; then
        t="$(mktemp)"; printf '%s\n' "${srcs[@]}" > "$t"
        if ! e="$( (read_conf "$t") 2>&1 >/dev/null)"; then
            rm -f "$t"; n="${e#* line }"; n="${n%%:*}"
            die ".dev line ${at[n-1]:-?}: ${e#* line *: }"
        fi
        rm -f "$t"
    fi
}

valid_port() { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$1" -le 65535 ]; }
valid_group() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

# project_sources: .dev's plugin lines (by name, folder or from a
# marketplace) and its rules lines: what's approved and built like your
# config's.
project_sources() {
    local items; items="$(read_dev)" || exit 1
    awk '$1 == "plugin" || $1 == "rules"' <<< "$items"
}

# project_approved_dir: where this project's approved copy lives, beside
# yours, out of every box's reach.
# Keyed by the folder's name and its path, as group files are: two
# projects of one name never share it.
project_approved_dir() {
    printf '%s/projects/%s-%s/approved' "$(dirname "$APPROVED")" "${PWD##*/}" "$(printf '%s' "$PWD" | sha256sum | cut -c1-16)"
}

# Sets PROJECT_APPROVED: this project's approved copy of its plugin and
# rules lines, once it's current or you said yes to it; else the one you
# approved last; empty when .dev has none or none dev can read.
choose_project_sources() {
    local lines t rc=0 dir
    PROJECT_APPROVED=""
    lines="$(project_sources)" || exit 1
    [ -n "$lines" ] || return 0
    dir="$(project_approved_dir)"; t="$(mktemp)"; printf '%s\n' "$lines" > "$t"
    approve_sources "this project's .dev (its plugin and rules lines)" "$t" "$dir" true || rc=$?
    rm -f "$t"
    if APPROVED="$dir" approved_ok; then
        PROJECT_APPROVED="$dir"
        [ "$rc" = 0 ] || echo "Starting on this project's plugin and rules lines you approved last."
    else
        echo "Starting without this project's plugin and rules lines (none approved)."
    fi
}

# project_plugins_hash: a hash of this project's approved plugin lines,
# every file of theirs, and its seed (its rules lines don't go into its
# image).
project_plugins_hash() {
    local kind val
    {   while read -r kind val; do
            [ "$kind" = plugin ] || continue
            echo "$val"
            [ "$(use_form "$val")" = market ] \
                || ( cd "$PROJECT_APPROVED" && find -L "$(use_key "$val")" -type f -print0 | sort -z | xargs -0r sha256sum )
        done < <(read_conf "$PROJECT_APPROVED/.dev" "$PROJECT_APPROVED")
        [ ! -d "$PROJECT_APPROVED/seed" ] || echo "seed $(seed_digest "$PROJECT_APPROVED/seed")"
    } | sha256sum | cut -c1-16
}

# pkgs_of <label>: a project image's label without its src: word.
pkgs_of() { local w out=(); for w in $1; do [[ "$w" == src:* ]] || out+=("$w"); done; echo "${out[*]}"; }

# The image's packages from .dev, sorted, as "kind:name" words: its label.
dev_packages() {
    local items; items="$(read_dev)" || exit 1
    awk '$1 ~ /^(dnf|npm|pip)$/ { print $1 ":" $2 }' <<< "$items" | sort | paste -sd ' ' -
}

# dev add|remove <kind> <name>...: edit .dev; installs nothing (the next
# dev claude asks). For "add plugin", the word after a marketplace plugin
# (<name>@<market>) is its marketplace's repo.
dev_edit() {
    local op="$1" kind="${2:-}" usage="Usage: dev $1 <dnf|npm|pip|plugin|rules|port|group> <name>...  (plugin <name>@<marketplace> <owner/repo>)"
    case "$kind" in dnf|npm|pip|plugin|rules|port|group) shift 2 ;; *) die "$usage" ;; esac
    [ $# -gt 0 ] || die "$usage"
    if [ "$kind" = port ]; then for w in "$@"; do valid_port "$w" || die "Not a port (1-65535): $w"; done; fi
    if [ "$kind" = group ]; then
        for w in "$@"; do valid_group "$w" || die "Not a group's name: $w"; done
        if [ "$op" = add ]; then
            [ $# -eq 1 ] || die "One group per project: dev add group <name>"
            local g; g="$(read_dev | awk '$1 == "group" { print $2 }')" || exit 1
            [ -z "$g" ] || [ "$g" = "$1" ] || die "This project is in group $g already: one group per project (dev remove group $g first)"
        fi
    fi
    [ -d .git ] || die "Run this from the top folder of a git repo (no .git here)."
    read_dev > /dev/null
    local names=() repos=() lines=() w i j k n found line
    for w in "$@"; do
        if [ "$op" = add ] && [ "$kind" = plugin ] && [[ "$w" != *@* ]] && [ ${#names[@]} -gt 0 ] \
                && [[ "${names[${#names[@]}-1]}" == *@* ]] && [ -z "${repos[${#repos[@]}-1]}" ]; then
            repos[${#repos[@]}-1]="$w"
        else names+=("$w"); repos+=(""); fi
    done
    if [ -f .dev ]; then
        while IFS= read -r line || [ -n "$line" ]; do lines+=("${line%$'\r'}"); done < .dev
    fi
    for i in "${!names[@]}"; do
        found=""
        for j in "${!lines[@]}"; do
            read -r k n _ <<< "${lines[j]%%#*}"
            if [ "$k $n" = "$kind ${names[i]}" ]; then found=$j; break; fi
        done
        if [ "$op" = add ]; then
            if [ -n "$found" ]; then echo "  already in .dev: $kind ${names[i]}"; continue; fi
            if [ "$kind" = plugin ] && [[ "${names[i]}" == *@* ]] && [ -z "${repos[i]}" ]; then
                die "A marketplace plugin needs its marketplace's repo: dev add plugin <name>@<marketplace> <owner/repo>"
            fi
            # the shell turned ~/ into your home: .dev holds ~/
            if [ "$kind" = plugin ] || [ "$kind" = rules ]; then names[i]="${names[i]/#"$HOME"\//\~/}"; fi
            lines+=("$kind ${names[i]}${repos[i]:+ ${repos[i]}}")
            echo "  added: $kind ${names[i]}"
        else
            if [ -z "$found" ]; then echo "  not in .dev: $kind ${names[i]}"; continue; fi
            unset 'lines[found]'; lines=("${lines[@]}")
            echo "  removed: $kind ${names[i]}"
        fi
    done
    # Write it back, or remove it when no item is left. A .dev dev can't
    # read is never left behind: the old one comes back.
    if grep -qv '^[[:space:]]*\(#.*\)\{0,1\}$' <<< "$(printf '%s\n' "${lines[@]}")"; then
        local old=""; [ ! -f .dev ] || old="$(cat .dev)"
        printf '%s\n' "${lines[@]}" > .dev
        if ! ( read_dev ) > /dev/null; then
            if [ -n "$old" ]; then printf '%s\n' "$old" > .dev; else rm -f .dev; fi
            die "Not written: .dev would hold a line dev can't read (above)."
        fi
    else
        rm -f .dev; echo "  .dev is empty now: removed it"
    fi
}

# The project's own image: localhost/claude-box-<folder name>, lower-cased,
# with each run of other characters turned into one "-".
image_name() {
    local n
    n="$(basename "$(work_dir)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"
    printf '%s-%s' "$IMAGE" "$n"
}

# Builds the project image ($1) FROM BASE_IMAGE (the base or your layer)
# with the packages ($2, "kind:name" words); labels it with them and the
# base's id ($3).
build_project() {
    local words w dir dnf=() npm=() pip=() old
    old="$(image_id "$1")"
    read -ra words <<< "$2"
    local kind val name plugins="" seeds known
    for w in "${words[@]}"; do
        case "${w%%:*}" in
            dnf) dnf+=("'${w#*:}'") ;; npm) npm+=("'${w#*:}'") ;; pip) pip+=("'${w#*:}'") ;;
        esac
    done
    [ ${#npm[@]} -eq 0 ] || dnf+=(npm)
    [ ${#pip[@]} -eq 0 ] || dnf+=(python3-pip)
    dir="$(mktemp -d)"; mkdir -p "$dir/plugins"
    {   echo "FROM $BASE_IMAGE"; echo "USER root"
        [ ${#dnf[@]} -eq 0 ] || echo "RUN dnf -y install ${dnf[*]} && dnf clean all"
        [ ${#npm[@]} -eq 0 ] || echo "RUN npm install -g ${npm[*]}"
        [ ${#pip[@]} -eq 0 ] || echo "RUN pip install ${pip[*]}"
        if [[ " $2 " == *" src:"* ]]; then     # the project's approved plugins
            while read -r kind val; do
                [ "$kind" = plugin ] && [ "$(use_form "$val")" != market ] || continue
                name="$(use_name "$val")"
                cp -rL -- "$(use_src "$val" "$PROJECT_APPROVED")" "$dir/plugins/$name" || { rm -rf "$dir"; die "Couldn't copy $val"; }
                echo "COPY plugins/$name /usr/local/share/claude-box/plugins/$name"
                plugins+=":/usr/local/share/claude-box/plugins/$name"
            done < <(read_conf "$PROJECT_APPROVED/.dev" "$PROJECT_APPROVED")
            # Podman puts the base's value in for ${CLAUDE_CODE_PLUGIN_DIRS}
            echo "ENV CLAUDE_CODE_PLUGIN_DIRS=\${CLAUDE_CODE_PLUGIN_DIRS}$plugins"
            if [ -d "$PROJECT_APPROVED/seed" ]; then   # its marketplace plugins, before yours
                cp -r "$PROJECT_APPROVED/seed" "$dir/seed-project" \
                    && seed_enable_json "$PROJECT_APPROVED/seed" > "$dir/claude-box-project-plugins.json" \
                    || { rm -rf "$dir"; die "Couldn't copy this project's seed"; }
                echo "COPY seed-project /usr/local/share/claude-box/seed-project"
                echo "COPY claude-box-project-plugins.json /etc/claude-code/managed-settings.d/"
                echo "RUN chmod 644 /etc/claude-code/managed-settings.d/claude-box-project-plugins.json"
                seeds=/usr/local/share/claude-box/seed-project known=("$PROJECT_APPROVED/seed" "$seeds")
                if [ "$BASE_IMAGE" = "$LAYER" ] && [ -d "$APPROVED/seed" ]; then
                    seeds+=:/usr/local/share/claude-box/seed; known+=("$APPROVED/seed" /usr/local/share/claude-box/seed)
                fi
                echo "ENV CLAUDE_CODE_PLUGIN_SEED_DIR=$seeds"
                seed_known_json "${known[@]}" > "$dir/known_marketplaces.json" || { rm -rf "$dir"; die "Couldn't copy this project's seed"; }
                echo "COPY known_marketplaces.json /home/claude/.claude/plugins/known_marketplaces.json"
                echo "RUN chmod 644 /home/claude/.claude/plugins/known_marketplaces.json"
            fi
            echo "RUN chmod -R a+rX /usr/local/share/claude-box"
        fi
        echo "USER claude"
    } > "$dir/Containerfile"
    if ! podman build -t "$1" --label claude-box.image=1 --label "claude-box.packages=$2" --label "claude-box.base=$3" \
            -f "$dir/Containerfile" "$dir"; then
        rm -rf "$dir"; die "Building $1 failed: check .dev"
    fi
    rm -rf "$dir"
    drop_old "$old" "$1"
}

# Sets BOX_IMAGE: BASE_IMAGE, or the project image with .dev's dnf, npm and
# pip packages. A changed list is built after asking (no: the previous
# project image, or the base); a rebuilt base is built on without asking.
choose_image() {
    local want img have="" had_base="" base
    want="$(dev_packages)" || exit 1
    # the project's approved plugins (by name or folder) go into its image too
    if [ -n "$PROJECT_APPROVED" ] && grep -q '^plugin ' "$PROJECT_APPROVED/.dev"; then
        want="${want:+$want }src:$(project_plugins_hash)"
    fi
    [ -n "$want" ] || return 0
    podman image exists "$IMAGE" || build
    base="$(podman image inspect --format '{{.Id}}' "$BASE_IMAGE")"
    img="$(image_name)"
    if podman image exists "$img"; then
        have="$(podman image inspect --format '{{index .Labels "claude-box.packages"}}' "$img")"
        had_base="$(podman image inspect --format '{{index .Labels "claude-box.base"}}' "$img")"
    fi
    if [ "$have" = "$want" ]; then
        [ "$had_base" = "$base" ] || build_project "$img" "$want" "$base"
    elif [ "$(pkgs_of "$have")" = "$(pkgs_of "$want")" ]; then
        build_project "$img" "$want" "$base"     # only the plugins you approved changed
    else
        echo "This project's .dev changes the packages in $img:"
        show_change "$have" "$want"
        if ask "Build it?"; then build_project "$img" "$want" "$base"
        elif [ -z "$have" ]; then return 0
        fi
    fi
    BOX_IMAGE="$img"
}

# Sets PUBLISH: each of .dev's ports, published on your laptop's 127.0.0.1
# only. One that can't be bound there, e.g. because another box of this
# project has it, is left out with a note; the box starts without it.
choose_ports() {
    local items p why
    items="$(read_dev)" || exit 1
    for p in $(awk '$1 == "port" { print $2 }' <<< "$items"); do
        if why="$(python3 -I -c 'import socket, sys
try: socket.socket().bind(("127.0.0.1", int(sys.argv[1])))
except OSError as e: sys.exit(e.strerror)' "$p" 2>&1)"; then
            PUBLISH+=(-p "127.0.0.1:$p:$p")
        else
            echo "Port $p not published to this box: $why (another box of this project?)" >&2
        fi
    done
}
