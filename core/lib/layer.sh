# shellcheck shell=bash
# Your config's layer under every box.

# needs_layer <items>: only these go into an image: your identity, your
# packages, and every plugin your lines name (not rules files, which are
# mounted).
needs_layer() {
    local kind val
    while read -r kind val; do
        case "$kind" in
            identity|dnf|npm|pip) return 0 ;;
            plugin) return 0 ;;     # by name or folder, or from a marketplace (its seed)
        esac
    done <<< "$1"
    return 1
}

# plugin_deps <folder>: a used plugin's dependencies (plugin.json's
# "dependencies") as "plugin <name>@<market> <owner/repo>" lines, the repo
# from its metadata.claude-box.marketplaces; one without a repo there is
# named on stderr, with the line to add.
plugin_deps() {
    [ -f "$1/.claude-plugin/plugin.json" ] || return 0
    python3 -I - "$1/.claude-plugin/plugin.json" <<'EOF'
import json, re, sys
try: m = json.load(open(sys.argv[1]))
except (OSError, ValueError): sys.exit(0)
repos = ((m.get("metadata") or {}).get("claude-box") or {}).get("marketplaces") or {}
for d in m.get("dependencies") or []:
    if isinstance(d, dict): name, market = d.get("name", ""), d.get("marketplace", "")
    else: name, _, market = str(d).partition("@")
    ok = re.fullmatch(r"[A-Za-z0-9_.-]+", name or "") and re.fullmatch(r"[A-Za-z0-9_.-]+", market or "")
    repo = repos.get(market, "") if ok else ""
    if ok and re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo or ""):
        print(f"plugin {name}@{market} {repo}")
    else:
        print(f"{m.get('name', '?')} needs {name}@{market or '?'}: add \"plugin {name}@{market or '<marketplace>'} <owner/repo>\" to ~/.claude/.dev", file=sys.stderr)
EOF
}

# build_layer <root> <hash>: your layer from <root>'s config (a snapshot,
# or the approved copy), FROM the base; labelled with the config's hash
# and the base's id.
build_layer() {
    local root="$1" items dir kind val name src who="" old
    local dnf=() npm=() pip=() plugins=/usr/local/share/claude-box/plugins/box-workflow
    items="$(read_conf "$root/.dev" "$root")" || return 1
    dir="$(mktemp -d)"; mkdir -p "$dir/plugins"
    {   echo "FROM $IMAGE"; echo "USER root"
        while read -r kind val; do
            case "$kind" in
                plugin)     # under its name; rules files are mounted
                    case "$(use_form "$val")" in clone|home) ;; *) continue ;; esac
                    name="$(use_name "$val")"; src="$(use_src "$val" "$root")"
                    cp -rL -- "${src%/}" "$dir/plugins/$name" || { rm -rf "$dir"; return 1; }
                    plugins+=":/usr/local/share/claude-box/plugins/$name"
                    echo "COPY plugins/$name /usr/local/share/claude-box/plugins/$name" ;;
                dnf) dnf+=("'$val'") ;;
                npm) npm+=("'$val'") ;;
                pip) pip+=("'$val'") ;;
                identity) who="$val" ;;
            esac
        done <<< "$items"
        [ ${#npm[@]} -eq 0 ] || dnf+=(npm)
        [ ${#pip[@]} -eq 0 ] || dnf+=(python3-pip)
        [ ${#dnf[@]} -eq 0 ] || echo "RUN dnf -y install ${dnf[*]} && dnf clean all"
        [ ${#npm[@]} -eq 0 ] || echo "RUN npm install -g ${npm[*]}"
        [ ${#pip[@]} -eq 0 ] || echo "RUN pip install ${pip[*]}"
        if [ -n "$who" ]; then
            val="${who##*<}"
            echo "RUN git config --system user.name '${who% <*}' && git config --system user.email '${val%>}'"
        fi
        echo "ENV CLAUDE_CODE_PLUGIN_DIRS=$plugins"
        if [ -d "$root/seed" ]; then    # your marketplace plugins, switched on for every session
            cp -r "$root/seed" "$dir/seed" && seed_enable_json "$root/seed" > "$dir/claude-box-plugins.json" \
                && seed_known_json "$root/seed" /usr/local/share/claude-box/seed > "$dir/known_marketplaces.json" \
                || { rm -rf "$dir"; return 1; }
            echo "COPY seed /usr/local/share/claude-box/seed"
            echo "COPY claude-box-plugins.json /etc/claude-code/managed-settings.d/"
            echo "RUN chmod 644 /etc/claude-code/managed-settings.d/claude-box-plugins.json"
            # registered already, so a box's first session needs no reload
            echo "COPY known_marketplaces.json /home/claude/.claude/plugins/known_marketplaces.json"
            echo "RUN chmod 644 /home/claude/.claude/plugins/known_marketplaces.json"
            echo "ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed"
        fi
        echo "RUN chmod -R a+rX /usr/local/share/claude-box"
        echo "USER claude"
    } > "$dir/Containerfile" || return 1
    old="$(image_id "$LAYER")"
    if ! podman build -t "$LAYER" --label claude-box.image=1 --label "claude-box.config=$2" \
            --label "claude-box.base=$(image_id "$IMAGE")" -f "$dir/Containerfile" "$dir"; then
        rm -rf "$dir"; return 1
    fi
    rm -rf "$dir"
    drop_old "$old" "$LAYER"
}

# approve_sources <what> <conf> <approved> <build>: the config at <conf>,
# with every file it names (one snapshot: what you're shown is what's
# hashed, built and approved), against the copy you approved last in
# <approved>. A difference is shown and, after your yes, built with
# "<build> <snapshot> <hash>" and saved as the approved copy. Returns 0
# when the approved copy is current, 1 on no, a failed build or a source
# it can't read, 2 when there's no approved copy and no terminal to ask.
# CONF_FILE and APPROVED are rebound here, so the snapshot functions serve
# a project's copy as they serve yours.
approve_sources() {
    local what="$1" CONF_FILE="$2" APPROVED="$3" build="$4" snap want have d rc=0
    snap="$(mktemp -d)"; mkdir -p "$snap/approved"
    if ! snapshot "$snap/yours"; then
        echo "Couldn't read the files ${what} names."; rc=1
    else
        want="$(conf_hash "$snap/yours")" || exit 1
        have=""; ! approved_ok || have="$(cat "$APPROVED/hash")"
        if [ "$want" = "$have" ]; then seed_refresh "$snap/yours"
        else
            if [ -z "$have" ] && [ ! -t 0 ]; then rm -rf "$snap"; return 2; fi
            for d in .dev plugins home urls; do
                [ -z "$have" ] || [ ! -e "$APPROVED/$d" ] || cp -r "$APPROVED/$d" "$snap/approved/"
            done
            echo "${what^} differs from the one you approved last:"
            # Every file as text, control characters as "?": nothing it
            # holds can redraw your terminal. diff says 1: they differ.
            # the staged seed is shown below, by plugin: out of the way for
            # the diff (a -x would hide every folder named seed)
            [ ! -d "$snap/yours/seed" ] || mv "$snap/yours/seed" "$snap/seed"
            ( cd "$snap" && diff -ruNa approved yours ) | LC_ALL=C sed 's/[^[:print:]\t]/?/g; s/^/  /' || true
            [ ! -d "$snap/seed" ] || mv "$snap/seed" "$snap/yours/seed"
            d="$(seed_changes "$APPROVED/seed" "$snap/yours/seed" | LC_ALL=C sed 's/[^[:print:]\t]/?/g')"
            [ -z "$d" ] || { echo "Plugins:"; sed 's/^/  /' <<< "$d"; }
            if ask "Apply it?"; then
                if "$build" "$snap/yours" "$want"; then save_approved "$snap/yours" "$want"
                else echo "Building failed."; rc=1; fi
            else rc=1; fi
        fi
    fi
    rm -rf "$snap"
    return "$rc"
}

# layer_build <snapshot> <hash>: your layer, when your config needs one.
layer_build() { ! needs_layer "$(read_conf "$1/.dev" "$1")" || build_layer "$1" "$2"; }

# Sets BASE_IMAGE (and BOX_IMAGE) and the runtime values. A config of
# yours in ~/.claude/.dev that differs from the one you approved last is shown
# and applied after you say yes; no, or no terminal: the approved one.
# The layer is rebuilt from the approved copy when the base changed.
choose_layer() {
    local have rc
    BASE_IMAGE="$IMAGE"
    check_core
    if [ ! -e "$CONF_FILE" ] && [ -f "$APPROVED/hash" ]; then
        echo "No ~/.claude/.dev: the defaults, not your config (the one you approved last is kept in $APPROVED)."
    fi
    if [ -e "$CONF_FILE" ]; then
        rc=0; approve_sources "your config (~/.claude/.dev)" "$CONF_FILE" "$APPROVED" layer_build || rc=$?
        [ "$rc" != 2 ] || die "Your config (~/.claude/.dev) has no approved version dev can read, and no terminal to ask: run dev claude in a terminal once."
        # Never the defaults in your config's place: without an approved
        # config dev can read, nothing starts.
        if [ "$rc" != 0 ]; then
            approved_ok || die "No approved version of your config dev can read: nothing started (dev doesn't start on the defaults in its place)."
            echo "Starting on the version you approved last."
        fi
        if approved_ok && needs_layer "$(read_conf "$APPROVED/.dev" "$APPROVED")"; then
            have="$(cat "$APPROVED/hash")"
            if [ "$(label "$LAYER" claude-box.config)" != "$have" ] \
                    || [ "$(label "$LAYER" claude-box.base)" != "$(image_id "$IMAGE")" ]; then
                build_layer "$APPROVED" "$have" || echo "Rebuilding your layer failed: starting on the one there is."
            fi
            ! podman image exists "$LAYER" || BASE_IMAGE="$LAYER"
        fi
    fi
    BOX_IMAGE="$BASE_IMAGE"
    load_runtime
    [ ! -e "$CONF_FILE" ] || ! approved_ok || seed_clear "$APPROVED/seed"
}
