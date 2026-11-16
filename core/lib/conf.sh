# shellcheck shell=bash
# Your config: reading it, the approved snapshot, the runtime values.

# Your config: ~/.claude/.dev, or the defaults in core/defaults.dev
# (which says what each kind means).
CONF_FILE="$HOME/.claude/.dev"
conf_file() {
    if [ -e "$CONF_FILE" ] || [ -L "$CONF_FILE" ]; then printf '%s' "$CONF_FILE"
    else printf '%s/core/defaults.dev' "$HERE"; fi
}

# conf_guard: refuses an old config in the clone, and a ~/.claude/.dev
# that's a link (any box can write ~/.claude; dev would follow it).
conf_guard() {
    [ ! -e "$HERE/local/claude-box.conf" ] \
        || die "Your config moved to ~/.claude/.dev (every kind: core/defaults.dev); move local/claude-box.conf aside."
    [ ! -L "$CONF_FILE" ] || die "$CONF_FILE is a link: refused (any box can write ~/.claude; remove the link)"
}

# in_root <path> <root> f|d: the path is in <root>, with no link on the
# way (any box can write ~/.claude), and names a file (f) or a folder (d)
# holding only files and folders.
in_root() {
    local p loc
    loc="$(realpath -e -- "$2" 2>/dev/null)" || return 1
    p="$(realpath -e -- "$1" 2>/dev/null)" || return 1
    [ "$p" = "$loc/$(realpath -ms --relative-to="$2" -- "$1")" ] && [[ "$p" == "$loc"/* ]] || return 1
    if [ "$3" = f ]; then [ -f "$p" ]; return; fi
    [ -d "$p" ] && [ -z "$(find "$p" ! -type f ! -type d -print -quit)" ]
}

# plugin_kind <folder>: a Claude Code plugin (a manifest, or a component
# folder of the standard layout), or a bare skill (SKILL.md at its root,
# which Claude Code loads as a one-skill plugin).
plugin_kind() {
    [ -d "$1" ] || return 1
    if [ -f "$1/.claude-plugin/plugin.json" ] || [ -d "$1/skills" ] || [ -d "$1/commands" ] \
            || [ -d "$1/agents" ] || [ -f "$1/hooks/hooks.json" ]; then echo plugin
    elif [ -f "$1/SKILL.md" ]; then echo skill
    else return 1; fi
}

# use_form <value>: market (<name>@<market> <owner/repo>), url, home
# (~/.claude/...) or clone (a name in the clone's plugins/).
use_form() {
    case "$1" in
        *" "*) echo market ;; https://*) echo url ;; \~/*) echo home ;; *) echo clone ;;
    esac
}

# use_key <value>: where its source sits in a snapshot (nothing for market).
use_key() {
    case "$(use_form "$1")" in
        clone) printf 'plugins/%s' "$1" ;; home) printf 'home/%s' "${1#\~/}" ;;
        url) printf 'urls/%s' "${1##*/}" ;;
    esac
}

# use_name <value>: a plugin's or rules file's name (its last segment).
use_name() { local v="${1%/}"; printf '%s' "${v##*/}"; }


# main_dir: a folder holding plugins/ as it is on the clone's main, never
# the working tree's, so a branch you're reviewing never reaches a box.
# One folder per tree id under ~/.local/state/claude-box/main/, out of
# every box's reach; made once (whole, then moved in place), older ones go.
main_dir() {
    local tree root tmp
    root="$(dirname "$APPROVED")/main"
    tree="$(git -C "$HERE" rev-parse --verify -q main:plugins 2>/dev/null)" \
        || die "dev reads plugins from the clone's main branch: $HERE has no plugins/ there (git clone it)"
    if [ ! -d "$root/$tree" ]; then
        mkdir -p "$root" && tmp="$(mktemp -d "$root/.new.XXXXXX")" || die "Can't write $root"
        git -C "$HERE" archive main plugins | tar -x -C "$tmp" || { rm -rf "$tmp"; die "Couldn't read plugins/ from main"; }
        mv -T "$tmp" "$root/$tree" 2>/dev/null || rm -rf "$tmp"
        find "$root" -mindepth 1 -maxdepth 1 \( ! -name '.*' ! -name "$tree" -o -name '.new.*' -mmin +60 \) \
            -exec rm -rf {} + 2>/dev/null || true
    fi
    printf '%s' "$root/$tree"
}

# use_src <value> [root]: its source, live (no root) or in a snapshot.
use_src() {
    if [ -n "${2:-}" ]; then printf '%s/%s' "$2" "$(use_key "$1")"
    elif [ "$(use_form "$1")" = clone ]; then printf '%s/plugins/%s' "$(main_dir)" "$1"
    else printf '%s/%s' "$HOME" "${1#\~/}"; fi
}

# use_base <value> [root]: the folder its source must stay in.
use_base() {
    case "$(use_form "$1")" in
        clone) if [ -n "${2:-}" ]; then printf '%s/plugins' "$2"; else printf '%s/plugins' "$(main_dir)"; fi ;;
        home) if [ -n "${2:-}" ]; then printf '%s/home/.claude' "$2"; else printf '%s/.claude' "$HOME"; fi ;;
        url) printf '%s/urls' "${2:-}" ;;
    esac
}

# read_conf <file> [root]: prints its items, one per line, "<kind> <value>"
# with single spaces; dies on a line it can't read. Parsed, never sourced.
# A use's source is checked live (no root) or in the snapshot at root.
read_conf() {
    local f="$1" root="${2:-}" n=0 line kind val ok e names=" " src groups=" " shown
    local gname='[A-Za-z0-9][A-Za-z0-9._-]*' seg='[A-Za-z0-9._-]+'
    local name='[A-Za-z0-9][A-Za-z0-9 ._-]*' mail='[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+'
    local word='[A-Za-z0-9][][A-Za-z0-9@._/+=:~<>!,-]*'
    local repo='[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' plug='[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+'
    local url='https://[A-Za-z0-9.-]+(/[A-Za-z0-9._~-]+)*/[0-9a-f]{7,40}/([A-Za-z0-9._~-]+/)*[A-Za-z0-9._~-]+\.md'
    local identity="^$name <$mail>\$"
    local projects='^(~/|/)[A-Za-z0-9 ._/+-]*$' cpus='^([1-9][0-9]*(\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$'
    shown="${f/#"$HOME"/\~}"; shown="${shown#"$HERE"/}"
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1)); line="${line%$'\r'}"; line="${line%%#*}"
        read -r kind val <<< "$line"
        [ -n "$kind" ] || continue
        val="$(printf '%s' "$val" | tr -s '[:blank:]' ' ')"
        ok=""
        case "$kind" in
            identity) [[ "$val" =~ $identity ]] && ok=1 ;;
            company|global|pack|plugin-dir)
                die "$shown line $n: \"$kind\" is gone: write \"plugin <name, ~/.claude/<folder> or <name>@<marketplace> <owner/repo>>\" or \"rules <~/.claude/<file>.md or a pinned URL>\" (core/defaults.dev)" ;;
            use)
                if [[ "$val" == *.md ]] && [[ "$val" != *" "* ]]; then e=rules; else e=plugin; fi
                die "$shown line $n: \"use\" is gone: write \"$e $val\" (core/defaults.dev)" ;;
            plugin|rules)
                if [ "$kind" = plugin ] && { [[ "$val" == *.md ]] || [ "$(use_form "$val")" = url ]; } && [[ "$val" != *" "* ]]; then
                    die "$shown line $n: \"plugin $val\" names a rules file: write \"rules $val\" (core/defaults.dev)"
                fi
                if [ "$kind" = rules ] && { [[ "$val" != *.md ]] || [ "$(use_form "$val")" = market ]; }; then
                    die "$shown line $n: \"rules $val\" isn't a rules file (.md): write \"plugin $val\" (core/defaults.dev)"
                fi
                case "$(use_form "$val")" in
                    market) [[ "$val" =~ ^$plug\ $repo$ ]] && ok=1 ;;
                    url) if [[ "$val" =~ ^$url$ ]] && [[ "$names" != *" rules:$(use_name "$val") "* ]]; then
                             [ -z "$root" ] || [ -f "$(use_src "$val" "$root")" ] || die "$shown line $n: $val isn't in the snapshot"
                             names+="rules:$(use_name "$val") "; ok=1
                         fi ;;
                    home|clone)
                        e="$(use_name "$val")"
                        if [ "$(use_form "$val")" = home ]; then [[ "$val" =~ ^~/\.claude(/$seg)+/?$ ]] || e=""
                        else [[ "$val" =~ ^$gname$ ]] || e=""; fi
                        [[ "/$val/" != */./* && "/$val/" != */../* ]] || e=""
                        src="$(use_src "$val" "$root")"
                        if [ -z "$e" ]; then :
                        elif [ "$kind" = rules ]; then
                            in_root "$src" "$(use_base "$val" "$root")" f && [[ "$names" != *" rules:$e "* ]] \
                                && { names+="rules:$e "; ok=1; }
                        elif [ "$e" != box-workflow ] && [ "$e" != files ] && [[ "$names" != *" plugin:$e "* ]] \
                                && in_root "$src" "$(use_base "$val" "$root")" d && plugin_kind "$src" > /dev/null \
                                && ! grep -qs '"name"[[:space:]]*:[[:space:]]*"box-workflow"' "$src/.claude-plugin/plugin.json"; then
                            names+="plugin:$e "; ok=1
                        fi ;;
                esac ;;
            dnf|npm|pip) [[ "$val" =~ ^$word$ ]] && ok=1 ;;
            port) die "$shown line $n: \"port\" is for a project's .dev only (project only)" ;;
            projects)       # never your home, a folder above it, or /
                if [[ "$val" =~ $projects ]]; then
                    e="$(realpath -m -- "${val/#\~/$HOME}")"
                    [ "$e" != / ] && [[ "$(realpath -m -- "$HOME")/" != "$e"/* ]] && ok=1
                fi ;;
            memory) [[ "$val" =~ ^[1-9][0-9]*[kmg]?$ ]] && ok=1 ;;
            cpus) [[ "$val" =~ $cpus ]] && ok=1 ;;
            remote-control) [[ "$val" =~ ^(on|off)$ ]] && ok=1 ;;
            group)          # a folder of projects; its last segment names the group, once
                e="${val%/}"
                if [[ "$e" =~ $projects ]] && [[ "/$e/" != */./* && "/$e/" != */../* ]] \
                        && [[ "${e##*/}" =~ ^$gname$ ]] && [[ "$groups" != *" ${e##*/} "* ]]; then
                    groups+="${e##*/} "; ok=1
                fi ;;
            remote) [[ "$val" =~ ^$gname\ $gname$ ]] && ok=1 ;;
            autotake) [ "$val" = group ] && ok=1 ;;
            *) die "$shown line $n: unknown kind \"$kind\" (core/defaults.dev lists them)" ;;
        esac
        [ -n "$ok" ] || die "$shown line $n: can't use \"$kind $val\" (core/defaults.dev says how)"
        echo "$kind $val"
    done < "$f"
}

# approved_ok: there's an approved config and dev can read it. One it
# can't (e.g. from before a change of kinds) counts as none.
approved_ok() {
    [ -f "$APPROVED/hash" ] && ( read_conf "$APPROVED/.dev" "$APPROVED" ) > /dev/null 2>&1
}

# approved_items: the config you approved last while you have one in
# ~/.claude/.dev, else the defaults. Only these reach a box or a question.
approved_items() {
    if [ -e "$CONF_FILE" ] && approved_ok; then read_conf "$APPROVED/.dev" "$APPROVED"
    else read_conf "$HERE/core/defaults.dev"; fi
}

# load_conf: a bad line in your config is refused here, at once.
load_conf() {
    conf_guard
    read_conf "$(conf_file)" > /dev/null || exit 1
}

# conf_value <kind> <items>: the last value of that kind, or nothing.
conf_value() { awk -v k="$1" '$1 == k { $1 = ""; v = substr($0, 2) } END { print v }' <<< "$2"; }

# Sets the runtime values: from the config you approved last while you
# have one in ~/.claude/.dev, else from the defaults; DEV_* override each.
load_runtime() {
    local items v
    items="$(approved_items)" || exit 1
    v="$(conf_value projects "$items")"; v="${v:-$HOME/Projects}"
    PROJECTS="${DEV_PROJECTS:-${v/#\~/$HOME}}"
    CAP_MEMORY="${DEV_MEMORY:-$(conf_value memory "$items")}"
    CAP_CPUS="${DEV_CPUS:-$(conf_value cpus "$items")}"
    v="$(conf_value remote-control "$items")"; REMOTE_CONTROL="${v:-on}"
}

# conf_hash <root>: the hash of <root>/.dev and of every file of the
# sources it names (plugins/, home/, urls/).
conf_hash() {
    ( cd "$1" && {
        sha256sum .dev
        { find -L plugins home urls -type f -print0 2>/dev/null || true; } | sort -z | xargs -0r sha256sum
        [ ! -d seed ] || echo "seed $(seed_digest seed)"
    } | sha256sum | cut -c1-64 )
}

# snapshot <dest>: your config and every source it names, at its key
# (use_key). A URL's file comes from the approved copy while the approved
# config names the same URL (it's pinned to a commit), else it's fetched.
# Fails when one can't be copied or fetched, or a link turns up (no link is
# followed: the copy is what read_conf checks again).
snapshot() {
    local kind val src dest
    mkdir -p "$1" && cp -P -- "$CONF_FILE" "$1/.dev" && [ ! -L "$1/.dev" ] || return 1
    while read -r kind val; do
        [ "$kind" = plugin ] || [ "$kind" = rules ] || continue
        dest="$1/$(use_key "$val")"
        case "$(use_form "$val")" in
            market) continue ;;
            url)
                mkdir -p "$(dirname "$dest")"
                if approved_ok && grep -qxF "rules $val" <(read_conf "$APPROVED/.dev" "$APPROVED") \
                        && [ -f "$(use_src "$val" "$APPROVED")" ]; then
                    cp -- "$(use_src "$val" "$APPROVED")" "$dest" || return 1
                elif ! curl -fsSL "$val" -o "$dest"; then
                    echo "Couldn't fetch $val" >&2; return 1
                fi ;;
            *) src="$(use_src "$val")"; mkdir -p "$(dirname "$dest")" && cp -rP -- "${src%/}" "${dest%/}" || return 1
               # a file swapped for a link after read_conf checked it
               [ -z "$(find "${dest%/}" ! -type f ! -type d -print -quit)" ] \
                   || { echo "$val changed to hold a link while dev copied it" >&2; return 1; } ;;
        esac
    done < <(read_conf "$CONF_FILE")
    seed_snapshot "$1"
}

# save_approved <snapshot> <hash>: the snapshot you said yes to is now the
# approved config. The one before moves to approved-old/, not deleted:
# running boxes mount its rules folders. Kept 30 days.
save_approved() {
    local keep="$APPROVED-old" prev
    echo "$2" > "$1/hash"
    mkdir -p "$(dirname "$APPROVED")"
    if [ -d "$APPROVED" ]; then
        mkdir -p "$keep"; find "$keep" -mindepth 1 -maxdepth 1 -mtime +30 -exec rm -rf {} +
        prev="$keep/$(date +%Y%m%d-%H%M%S)-$$"; mv "$APPROVED" "$prev"; touch "$prev"
    fi
    mv "$1" "$APPROVED"
}
