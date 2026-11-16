# shellcheck shell=bash
# Starting and joining boxes.

# Sets TTY_OPTS for the box's command: a terminal when stdin and stdout are
# both terminals; stdin when it's piped data (or /dev/null); else nothing,
# so `dev claude -p … | x` doesn't wait 3 s for a terminal's stdin that
# never arrives. Sets a global: a $( ) would make stdout a pipe.
term_opts() {
    TTY_OPTS=()
    if [ ! -t 0 ]; then TTY_OPTS=(-i)
    elif [ -t 1 ]; then TTY_OPTS=(-i -t); fi
}

# The box. Only Claude's home, your ~/.claude, is always there (with
# .claude.json inside it, through CLAUDE_CONFIG_DIR); a project is added
# only when you're in one (see run_box). Its plugins/ is the box's own, an
# anonymous volume gone with the box, so only the image's plugins load;
# plugins/data and plugins/store (plugins' state) are yours. Your config's
# memory and cpus (or DEV_MEMORY and DEV_CPUS) cap what it may use; unset,
# it's uncapped.
box() {  # [podman run options...] -- command...
    local opts=() caps=() p
    [ -z "$CAP_MEMORY" ] || caps+=(--memory="$CAP_MEMORY")
    [ -z "$CAP_CPUS" ] || caps+=(--cpus="$CAP_CPUS")
    while [ "$1" != -- ]; do opts+=("$1"); shift; done; shift
    term_opts
    podman image exists "$IMAGE" || build
    for p in "$HOME/.claude/plugins" "$HOME/.claude/plugins/data" "$HOME/.claude/plugins/store"; do
        [ ! -L "$p" ] || die "$p is a link: refused (any box can write there; remove the link)"
    done
    mkdir -p "$HOME/.claude/plugins/data" "$HOME/.claude/plugins/store"
    podman run --rm "${TTY_OPTS[@]}" \
        --userns=keep-id:uid=1000,gid=1000 \
        --cap-drop=all --security-opt=no-new-privileges "${caps[@]}" \
        --hostname claude-box -e TERM \
        -v "$HOME/.claude":/home/claude/.claude:z \
        --mount=type=volume,destination=/home/claude/.claude/plugins,U=true \
        -v "$HOME/.claude/plugins/data":/home/claude/.claude/plugins/data:z \
        -v "$HOME/.claude/plugins/store":/home/claude/.claude/plugins/store:z \
        -e CLAUDE_CONFIG_DIR=/home/claude/.claude \
        "${opts[@]}" "$BOX_IMAGE" "$@"
}

# The box with this project in it: this folder read-write at /work/<name>
# (its folder name), so Claude Code keeps each project's memory and
# sessions apart; its .git read-write so Claude can commit to claude/
# branches. The rules forbid it to touch git config and hooks (they would
# run as you); nothing enforces that.
# Your other projects are there read-only, at /projects. All use SELinux's
# shared label (z): a private one (Z) per project would hide it in /projects.
# A scratch's box has its folder there instead, without .git.
run_box() {
    local projects=() dir git=()
    dir="$(work_dir)"
    if [ -z "$SCRATCH" ]; then
        # $PWD is a real path (cd -P): so is the home it's compared with.
        [ "$PWD" != "$(cd -P "$HOME" && pwd)" ] && [ "$PWD" != / ] || die "Run this from a project folder, not $PWD."
        [ -d .git ] || die "Run this from the top folder of a git repo (no .git here)."
        git=(-v "$PWD/.git":"$dir/.git":z)
    fi
    # shellcheck disable=SC2054  # ro,z is one mount option list
    [ -d "$PROJECTS" ] && projects=(-v "$PROJECTS":/projects:ro,z)
    box "${projects[@]}" "${MOUNTS[@]}" "${PUBLISH[@]}" "${SHARE[@]}" -v "$PWD":"$dir":z "${git[@]}" -w "$dir" -- "$@"
}
# The folder's path in the box.
work_dir() {
    if [ -n "$SCRATCH" ]; then printf '/work/scratch-%s' "$SCRATCH"
    else printf '/work/%s' "$(basename "$PWD")"; fi
}

# The shared box's command, run under --init: waits up to 60 s for the
# first session, then ends when only it (and init) are left; --rm then
# removes the box. A glob counts the processes without starting one.
# shellcheck disable=SC2016  # expanded in the box
WATCHER='end=$((SECONDS + 60))
while p=(/proc/[0-9]*); [ ${#p[@]} -le 2 ]; do [ $SECONDS -lt $end ] || exit 0; sleep 1; done
while p=(/proc/[0-9]*); [ ${#p[@]} -gt 2 ]; do sleep 2; done'

# "<running> <project path>" of the named box; empty when there's none.
box_state() {
    podman container inspect --format '{{.State.Running}} {{index .Config.Labels "claude-box.project"}}' "$1" 2>/dev/null || true
}

# One box per project: claude-box-<n>, labelled with the project's path.
# Runs the command in it, starting the box first when none runs.
shared_box() {  # command...
    local name state cmd=claude
    [ "$1" != bash ] || cmd=shell
    name="$(image_name)"; name="${name#localhost/}"
    # One dev at a time checks and starts the box: a second one waits here,
    # then joins. Nothing started under the lock gets its descriptor, which
    # Podman's long-lived processes would otherwise hold for the box's life.
    # The lock is in your runtime folder, not a /tmp another user can write.
    # Its file names the holder while it's held: the kernel frees a dead
    # holder's lock, so a wait is always for a live dev, often at a question.
    [ -n "${XDG_RUNTIME_DIR:-}" ] || die "XDG_RUNTIME_DIR isn't set: log in through a systemd session (not su)."
    local lk lock="$XDG_RUNTIME_DIR/$name.lock" holder=""
    exec {lk}<>"$lock"
    if ! flock -n "$lk"; then
        read -r holder < "$lock" || true
        echo "Waiting for ${holder:-the other dev} starting $name…" >&2
        flock "$lk"
    fi
    printf 'dev %s (process %s, since %s)\n' "$cmd" "$$" "$(date +%H:%M)" > "$lock"
    state="$(box_state "$name" {lk}>&-)"
    case "$state" in
        "true $PWD")
            echo "Joined the running box of $(basename "$PWD"); .dev changes apply to the next new one (or use --new)." >&2 ;;
        true\ *) die "$name belongs to ${state#true }: use dev $cmd --new here." ;;
        *)  # none, or one left stopped (e.g. by a shutdown): start anew
            [ -z "$state" ] || podman rm -f -v "$name" > /dev/null {lk}>&-
            # Their questions and builds go to the terminal, not into a pipe.
            # A scratch has no .dev: the base image, no plugins or ports.
            choose_layer {lk}>&- >&2; choose_mounts {lk}>&- >&2
            if [ -z "$SCRATCH" ]; then
                choose_image {lk}>&- >&2; choose_ports {lk}>&- >&2
            fi
            SHARE=(-d --init --name "$name" --label "claude-box.project=$PWD")
            run_box bash -c "$WATCHER" > /dev/null {lk}>&- || die "Couldn't start $name."
            SHARE=() ;;
    esac
    : > "$lock"; exec {lk}>&-
    term_opts
    # podman exec doesn't pass a hangup on (a closed window): the session
    # notes its process in the box, and dev hangs it up there itself.
    # shellcheck disable=SC2016  # expanded in the box
    trap 'podman exec "$name" bash -c '"'"'p=$(cat "/tmp/dev-session.$1") && { kill -HUP -- "-$p" || kill -HUP "$p"; }'"'"' _ "$$" 2>/dev/null; exit 129' HUP TERM
    # shellcheck disable=SC2016  # expanded in the box
    local rc=0
    podman exec "${TTY_OPTS[@]}" -e TERM -w "$(work_dir)" "$name" \
        bash -c 'echo $$ > "/tmp/dev-session.$1"; shift; exec "$@"' _ "$$" "$@" || rc=$?
    # The box ended just as we joined it: Podman says 125 once it's gone,
    # 255 while it's stopped but not yet removed. Start a new one, once; a
    # session that ends with either leaves the box running.
    if { [ "$rc" = 125 ] || [ "$rc" = 255 ]; } && [ -z "${DEV_RETRIED:-}" ] && [ "$(box_state "$name")" != "true $PWD" ]; then
        DEV_RETRIED=1; shared_box "$@"; return
    fi
    return "$rc"
}
