#!/usr/bin/env bash
# dev with a fake podman that records its arguments: which mounts and
# settings the box gets, and what dev reset removes. No Podman needed.
#
# Run: bash tests/test_dev.sh   (or tests/run.sh)

set -uo pipefail
exec < /dev/null      # dev asks on a terminal; only tty_run gives it one
# dev new commits; the fake HOME has no git identity of yours.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid \
       GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
# Your own caps, if set, would change what the box gets.
unset DEV_MEMORY DEV_CPUS DEV_PROJECTS XDG_STATE_HOME
REPO="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
# dev runs from a copy of the clone, so no test reads a plugin of yours
# or an old local/; it reads its config from the fake HOME.
CLONE="$tmp/clone"; mkdir -p "$CLONE"
mkdir -p "$CLONE/core/bin"
cp "$REPO/dev" "$CLONE/"; cp "$REPO/core/defaults.dev" "$CLONE/core/"
cp "$REPO/core/bin/run-actions" "$CLONE/core/bin/"; cp -r "$REPO/core/lib" "$CLONE/core/"
# dev builds the image from the clone's main (git archive): a Containerfile to send.
cp "$REPO/core/Containerfile" "$REPO/core/managed-settings.json" "$CLONE/core/"
cp -r "$REPO/core/rules" "$REPO/core/plugin" "$CLONE/core/"; cp "$REPO/core/bin/"* "$CLONE/core/bin/"
DEV="$CLONE/dev"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/podman" <<'EOF'
#!/usr/bin/env bash
# Logs its arguments (and a build's Containerfile); keeps each image as a
# folder in $FAKE holding its id and labels, and the project's named box as
# $FAKE/box ("<running> <project label>").
printf '%s\n' "$@" "--" >> "$LOG"
img() { printf '%s/%s' "$FAKE" "${1//\//_}"; }
case "$1" in
    image)
        case "$2" in
            exists) [ -d "$(img "$3")" ]; exit ;;
            rm) exit "${FAKE_RMI_STATUS:-0}" ;;   # image rm <id>: refused while in use
            inspect)    # image inspect --format <f> <image>
                d="$(img "$5")"; [ -d "$d" ] || exit 1
                if [ "$4" = '{{.Id}}' ]; then cat "$d/id"
                else l="${4#*\"}"; cat "$d/${l%%\"*}" 2>/dev/null; echo; fi ;;
        esac ;;
    build)
        ctx="${!#}"; shift; t="" f=""; labels=()
        while [ $# -gt 0 ]; do
            case "$1" in -t) t="$2"; shift ;; -f) f="$2"; shift ;; --label) labels+=("$2"); shift ;; esac
            shift
        done
        [ -z "$f" ] || cat "$f" >> "$LOG"
        mkdir -p "$FAKE/ctx"; cp -r "$ctx/." "$FAKE/ctx/"   # the build's context, for a look
        [ "${FAKE_BUILD_STATUS:-0}" = 0 ] || exit "$FAKE_BUILD_STATUS"
        d="$(img "$t")"; mkdir -p "$d"; echo "id$RANDOM$RANDOM" > "$d/id"
        for l in "${labels[@]}"; do printf '%s' "${l#*=}" > "$d/${l%%=*}"; done ;;
    run)
        # A staging box (CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed): writes what
        # Claude Code would into the mounted seed, one plugin per FAKE_STAGE
        # word "<name>@<market>=<version>", its file holding FAKE_STAGE_BODY.
        if printf '%s\n' "$@" | grep -qx 'CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed'; then
            [ -z "${FAKE_STAGE_SLEEP:-}" ] || sleep "$FAKE_STAGE_SLEEP"
            for a in "$@"; do case "$a" in *:/seed:z) sd="${a%:/seed:z}" ;; esac; done
            python3 -I - "$sd" <<'PY'
import json, os, sys
seed, words = sys.argv[1], os.environ.get("FAKE_STAGE", "").split()
plugins, known = {}, {}
for w in words:
    pid, ver = w.split("=")
    name, market = pid.split("@")
    rel = f"cache/{market}/{name}/{ver}"
    os.makedirs(f"{seed}/{rel}", exist_ok=True)
    open(f"{seed}/{rel}/f", "w").write(os.environ.get("FAKE_STAGE_BODY", "x"))
    os.makedirs(f"{seed}/marketplaces/{market}/.claude-plugin", exist_ok=True)
    open(f"{seed}/marketplaces/{market}/.claude-plugin/marketplace.json", "w").write(
        os.environ.get("FAKE_MARKET_JSON", '{"plugins": []}'))
    plugins[pid] = [{"scope": "user", "installPath": f"/seed/{rel}", "version": ver}]
    known[market] = {"source": {"source": "github", "repo": f"o/{market}"}, "installLocation": f"/seed/marketplaces/{market}"}
if plugins:
    json.dump({"version": 2, "plugins": plugins}, open(f"{seed}/installed_plugins.json", "w"))
    json.dump(known, open(f"{seed}/known_marketplaces.json", "w"))
PY
            exit "${FAKE_STAGE_STATUS:-0}"
        fi
        [ -z "${FAKE_ON_RUN:-}" ] || bash -c "$FAKE_ON_RUN"
        name="" label=""
        while [ $# -gt 0 ]; do
            case "$1" in --name) name="$2"; shift ;; --label) label="${2#claude-box.project=}"; shift ;; esac
            shift
        done
        [ -z "$name" ] || echo "true $label" > "$FAKE/box"
        exit "${FAKE_RUN_STATUS:-0}" ;;
    images) cat "$FAKE/dangling" 2>/dev/null ;;  # images --quiet --filter dangling=true --filter label=…
    container) [ -f "$FAKE/box" ] || exit 125; cat "$FAKE/box" ;;  # container inspect
    rm) rm -f "$FAKE/box" ;;
    exec)   # one session, the last: the box ends with it. With
            # FAKE_EXEC_STATUS, the first exec fails with it: the box ends
            # just then, or with FAKE_EXEC_KEEP, the session itself fails.
            # dev's look for a live Claude session (the dev-session files)
            # answers FAKE_LIVE (default: none) and leaves the box running.
        case "$*" in *dev-session.\**) exit "${FAKE_LIVE:-1}" ;; esac
        [ -z "${FAKE_ON_RUN:-}" ] || bash -c "$FAKE_ON_RUN"
        if [ -n "${FAKE_EXEC_STATUS:-}" ] && [ ! -e "$FAKE/exec-failed" ]; then
            touch "$FAKE/exec-failed"
            [ -n "${FAKE_EXEC_KEEP:-}" ] || rm -f "$FAKE/box"
            exit "$FAKE_EXEC_STATUS"
        fi
        rm -f "$FAKE/box" ;;
esac
exit 0
EOF
chmod +x "$tmp/bin/podman"
# curl -fsSL <url> -o <file>: writes FAKE_CURL_BODY, or fails with FAKE_CURL_STATUS.
cat > "$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
[ "${FAKE_CURL_STATUS:-0}" = 0 ] || exit "$FAKE_CURL_STATUS"
while [ $# -gt 0 ]; do [ "$1" = -o ] && printf '%s\n' "${FAKE_CURL_BODY:-}" > "$2"; shift; done
EOF
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
# The seed's upstream check (git ls-remote) reads local repos, never GitHub.
export SEED_GIT_BASE="file://$tmp/up/"
passed=0

fail() { echo "test_dev FAIL ($case): $*"; exit 1; }
has() { grep -qxF -- "$1" "$LOG" || fail "podman was not called with: $1"; }
hasnt() { ! grep -qF -- "$1" "$LOG" || fail "podman was called with: $1"; }
not_called() { ! grep -qxF -- "$1" "$LOG" || fail "podman $1 was called"; }
runs() { grep -qxF -- "$1" "$LOG" || fail "the box didn't run on $1"; }

# A fresh HOME with a space in its name, and a project in it.
fresh() {
    case="$1"
    export HOME="$tmp/home $case" LOG="$tmp/$case.log" FAKE="$tmp/$case.images"
    export XDG_RUNTIME_DIR="$tmp/run $case"; mkdir -p "$XDG_RUNTIME_DIR"
    mkdir -p "$HOME/Projects/p" && git -C "$HOME/Projects/p" init -q
    mkdir -p "$FAKE/localhost_claude-box" && echo base1 > "$FAKE/localhost_claude-box/id"
    rm -rf "$CLONE/local" "$CLONE/plugins"; mkdir -p "$CLONE/plugins"
    cp -r "$REPO/plugins/." "$CLONE/plugins/"
    # The clone is a git repo with everything on main, and the base image
    # was built from that main's core: no test starts with a core change.
    rm -f "$CLONE/core/bin/x.txt" "$CLONE/core/lib/x.txt" "$CLONE/u.txt" "$CLONE/l.txt"; cp "$REPO/core/Containerfile" "$CLONE/core/"
    rm -rf "$CLONE/.git"; git -C "$CLONE" init -q -b main; clone_commit fresh
    base_label
    : > "$LOG"
}

# clone_commit <message>: commits all of the clone on its current branch.
clone_commit() { git -C "$CLONE" add -A && git -C "$CLONE" commit -qm "$1"; }

# base_label: the fake base image was built from main's core as it is now.
# core_key: what dev labels the image with (core_key in core/lib/common.sh).
core_key() { HERE="$CLONE" bash -c '. "$HERE/core/lib/common.sh"; core_key'; }
base_label() { core_key > "$FAKE/localhost_claude-box/claude-box.core"; git -C "$CLONE" rev-parse main > "$FAKE/localhost_claude-box/claude-box.commit"; }

# conf <lines>: your config, ~/.claude/.dev.
conf() { mkdir -p "$HOME/.claude"; printf '%s\n' "$@" > "$HOME/.claude/.dev"; }

dev_in_p() { (cd "$HOME/Projects/p" && "$DEV" "$@"); }
tty_run_in_p() { (cd "$HOME/Projects/p" && tty_run "$@"); }

# up_repo <owner/repo>: an upstream repo with one commit; up_commit adds one.
up_repo() { mkdir -p "$tmp/up/$1" && git -C "$tmp/up/$1" init -q && up_commit "$1"; }
up_commit() { git -C "$tmp/up/$1" commit -q --allow-empty -m c; }

# run_seed <function> <args>: one of dev's functions, with dev's modules
# from the clone and the test's HOME.
run_seed() {
    HERE="$CLONE" IMAGE=localhost/claude-box APPROVED="$HOME/.local/state/claude-box/approved" bash -c '
        set -uo pipefail
        for m in common conf layer seed; do . "$HERE/core/lib/$m.sh" || exit 99; done
        "$@"' run_seed "$@"
}

# jq_ok <json file> <python expression on d>
jq_ok() { python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); sys.exit(0 if eval(sys.argv[2]) else 1)' "$1" "$2"; }

# Runs a command with a terminal on stdin (dev asks only then), feeding it
# what's piped in; exits with the command's status.
tty_run() {
    python3 -I -c 'import os, pty, sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' "$@"
}

# Runs a command with a terminal on stdin only, typing what's piped in;
# stdout and stderr stay the caller's (e.g. a pipe). Exits with its status.
tty_in() {
    python3 -I -c 'import os, subprocess, sys
master, slave = os.openpty()
os.write(master, sys.stdin.buffer.read())
sys.exit(subprocess.run(sys.argv[1:], stdin=slave).returncode)' "$@"
}

fresh shell
(cd "$HOME/Projects/p" && "$DEV" shell) || fail "dev shell exited $?"
has "$HOME/.claude:/home/claude/.claude:z"
has "CLAUDE_CONFIG_DIR=/home/claude/.claude"
has "$HOME/Projects/p:/work/p:z"
has "$HOME/Projects/p/.git:/work/p/.git:z"
has "/work/p"                       # the -w value
hasnt "$HOME/Projects/p:/work:z"
hasnt claude-home
hasnt --memory                      # caps only when asked for
hasnt --cpus
[ -d "$HOME/.claude" ] || fail "$HOME/.claude was not created"
passed=$((passed + 1))

fresh box-plugins-dir       # the box's own plugins folder, gone with it; only data/ and store/ are yours (plugins-dir P1, P2)
[ ! -e "$HOME/.claude/plugins" ] || fail "the fresh HOME has a plugins folder"
dev_in_p shell || fail "dev shell exited $?"
has "--mount=type=volume,destination=/home/claude/.claude/plugins,U=true"
has "$HOME/.claude/plugins/data:/home/claude/.claude/plugins/data:z"
has "$HOME/.claude/plugins/store:/home/claude/.claude/plugins/store:z"
[ -d "$HOME/.claude/plugins/data" ] && [ -d "$HOME/.claude/plugins/store" ] || fail "data/ or store/ not created"
passed=$((passed + 1))

fresh box-plugins-link      # a link a box planted at plugins/store: refused, not mounted (review C2)
mkdir -p "$HOME/.claude/plugins" "$tmp/elsewhere"; ln -s "$tmp/elsewhere" "$HOME/.claude/plugins/store"
out=$(dev_in_p shell 2>&1) && fail "started: $out"
grep -qF 'is a link: refused' <<< "$out" || fail "not said: $out"
hasnt "$tmp/elsewhere"
passed=$((passed + 1))

# One box per project: dev shell and dev claude start it, or join it.
fresh start
dev_in_p shell || fail "dev shell exited $?"
has -d; has --init; has --name; has claude-box-p
has "claude-box.project=$HOME/Projects/p"
has exec; has "/work/p"
grep -qx 'bash' "$LOG" || fail "no bash after exec"
passed=$((passed + 1))

fresh join
echo "true $HOME/Projects/p" > "$FAKE/box"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?"
not_called run
has exec
grep -qF 'Joined the running box of p' <<< "$out" || fail "no join note: $out"
passed=$((passed + 1))

fresh join-spaced
mkdir -p "$HOME/Projects/my app" && git -C "$HOME/Projects/my app" init -q
echo "true $HOME/Projects/my app" > "$FAKE/box"
(cd "$HOME/Projects/my app" && "$DEV" shell 2>/dev/null) || fail "dev shell exited $?"
not_called run; has "/work/my app"
passed=$((passed + 1))

fresh join-no-tty      # stdin is /dev/null here
echo "true $HOME/Projects/p" > "$FAKE/box"
dev_in_p shell 2>/dev/null || fail "dev shell exited $?"
has -i; not_called -t
passed=$((passed + 1))

fresh join-tty          # an interactive session keeps its terminal
echo "true $HOME/Projects/p" > "$FAKE/box"
(cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
has -i; has -t
passed=$((passed + 1))

fresh join-asks-nothing
echo 'dnf jq' > "$HOME/Projects/p/.dev"
echo "true $HOME/Projects/p" > "$FAKE/box"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
not_called build; has -t
passed=$((passed + 1))

fresh start-stdout-piped  # starting a box: its questions go to the terminal, not into the pipe
echo 'dnf jq' > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_in "$DEV" shell 2>/dev/null) > "$tmp/out" || fail "dev shell exited $?"
has build
[ ! -s "$tmp/out" ] || fail "stdout got: $(cat "$tmp/out")"
passed=$((passed + 1))

fresh home-symlink      # a home reached through a symlink (/home -> /var/home) is still home
mkdir -p "$tmp/var home" && mv "$HOME" "$tmp/var home/$case" && ln -s "$tmp/var home/$case" "$HOME"
git -C "$HOME" init -q
out=$(cd "$HOME" && "$DEV" shell 2>&1) && fail "dev shell ran in the home folder"
grep -qF 'Not a project: ' <<< "$out" || fail "no refusal: $out"
not_called run
passed=$((passed + 1))

fresh join-stdout-piped   # dev claude -p … | x: the pipe gets no terminal output
echo "true $HOME/Projects/p" > "$FAKE/box"
(cd "$HOME/Projects/p" && tty_in "$DEV" shell 2>/dev/null | cat) >/dev/null || fail "dev shell exited $?"
not_called -i; not_called -t     # no stdin either: claude -p would wait 3 s for it
passed=$((passed + 1))

fresh hangup            # a closed window: dev passes the hangup on to the session in the box
hook='[ -e "$FAKE/box" ] && [ ! -e "$FAKE/hup" ] && touch "$FAKE/hup" && kill -HUP "$(cut -d" " -f4 /proc/$PPID/stat)" && sleep 1'
(cd "$HOME/Projects/p" && FAKE_ON_RUN="$hook" "$DEV" shell 2>/dev/null) && fail "dev shell went on after a hangup"
[ -e "$FAKE/hup" ] || fail "the hook never sent the hangup"
grep -q 'kill -HUP' "$LOG" || fail "the session in the box wasn't sent the hangup"
passed=$((passed + 1))

fresh other-project     # another folder named p has the box
echo "true /elsewhere/p" > "$FAKE/box"
out=$(dev_in_p shell 2>&1) && fail "dev shell succeeded"
grep -qF 'belongs to /elsewhere/p' <<< "$out" || fail "no clash message: $out"
not_called exec
passed=$((passed + 1))

fresh leftover          # e.g. killed at shutdown before --rm ran
echo "false $HOME/Projects/p" > "$FAKE/box"
dev_in_p shell || fail "dev shell exited $?"
has rm; has -d; has exec
[ "$(grep -nxE 'rm|run' "$LOG" | cut -d: -f2 | paste -sd' ')" = "rm run" ] || fail "not rm, then run"
passed=$((passed + 1))

fresh run-fails         # under the lock nobody else starts it: a failed run is an error
out=$(cd "$HOME/Projects/p" && FAKE_RUN_STATUS=125 "$DEV" shell 2>&1) && fail "dev shell succeeded"
grep -qF "Couldn't start claude-box-p." <<< "$out" || fail "no error: $out"
not_called exec
passed=$((passed + 1))

fresh lock-waits        # a second dev waits for the first's start, then joins it
exec 8>"$XDG_RUNTIME_DIR/claude-box-p.lock"; flock 8
dev_in_p shell 2>"$tmp/err" 8>&- & waiter=$!
for _ in $(seq 50); do grep -qF 'Waiting for' "$tmp/err" && break; sleep 0.1; done
not_called run; not_called rm
grep -qF 'Waiting for the other dev starting claude-box-p…' "$tmp/err" || fail "no waiting line: $(cat "$tmp/err")"
echo "true $HOME/Projects/p" > "$FAKE/box"
exec 8>&-
wait "$waiter" || fail "dev shell exited $?"
not_called run; not_called rm; has exec
passed=$((passed + 1))

fresh lock-names-holder # the waiting line says which dev holds the lock
echo 'dev claude (process 4312, since 10:02)' > "$XDG_RUNTIME_DIR/claude-box-p.lock"
exec 8<>"$XDG_RUNTIME_DIR/claude-box-p.lock"; flock 8
dev_in_p shell 2>"$tmp/err" 8>&- & waiter=$!
for _ in $(seq 50); do grep -qF 'Waiting for' "$tmp/err" && break; sleep 0.1; done
grep -qF 'Waiting for dev claude (process 4312, since 10:02) starting claude-box-p…' "$tmp/err" || fail "no holder in the waiting line: $(cat "$tmp/err")"
echo "true $HOME/Projects/p" > "$FAKE/box"
exec 8>&-
wait "$waiter" || fail "dev shell exited $?"
passed=$((passed + 1))

fresh lock-holder-line  # the holder writes its own line, with no tail of an older one, and empties it after
echo 'dev claude (process 999999, since 23:59) and a long tail' > "$XDG_RUNTIME_DIR/claude-box-p.lock"
(cd "$HOME/Projects/p" && FAKE_ON_RUN='[ -e "$FAKE/held" ] || cp "$XDG_RUNTIME_DIR/claude-box-p.lock" "$FAKE/held"' "$DEV" shell) || fail "dev shell exited $?"
[ "$(wc -l < "$FAKE/held")" = 1 ] && grep -qE '^dev shell \(process [0-9]+, since [0-9]{2}:[0-9]{2}\)$' "$FAKE/held" || fail "holder line: $(cat "$FAKE/held")"
[ ! -s "$XDG_RUNTIME_DIR/claude-box-p.lock" ] || fail "lock file not emptied: $(cat "$XDG_RUNTIME_DIR/claude-box-p.lock")"
passed=$((passed + 1))

fresh no-runtime-dir    # no shared /tmp lock: refused, before any podman
for env in "-u XDG_RUNTIME_DIR" "XDG_RUNTIME_DIR="; do
    # shellcheck disable=SC2086  # $env is two words or one assignment
    out=$(cd "$HOME/Projects/p" && env $env "$DEV" shell 2>&1) && fail "dev shell ran ($env)"
    grep -qF "XDG_RUNTIME_DIR isn't set: log in through a systemd session (not su)." <<< "$out" || fail "no refusal ($env): $out"
    [ ! -s "$LOG" ] || fail "podman called ($env)"
done
passed=$((passed + 1))

fresh watcher           # the script dev passes to podman run ends the box after its last session
dev_in_p shell || fail "dev shell exited $?"
script="$(awk '/^--init$/ { i = 1 } i && /^-c$/ && !s { s = 1; next } s && /^--$/ { exit } s' "$LOG")"
[ -n "$script" ] || fail "no watcher script in podman run"
mkdir -p "$tmp/procs/1" "$tmp/procs/2" "$tmp/procs/3"   # init, the watcher, a session
timeout 15 bash -c "${script//\/proc\//$tmp/procs/}" & watcher=$!
sleep 3
kill -0 "$watcher" 2>/dev/null || fail "the watcher ended with a session left"
rmdir "$tmp/procs/3"
rc=0; wait "$watcher" || rc=$?
[ "$rc" = 0 ] || fail "the watcher didn't end after the last session (status $rc)"
passed=$((passed + 1))

fresh symlink           # a project through a symlink is the folder itself
ln -s "$HOME/Projects/p" "$HOME/q"
(cd "$HOME/q" && "$DEV" shell) || fail "dev shell exited $?"
has "claude-box.project=$HOME/Projects/p"; has "$HOME/Projects/p:/work/p:z"; has claude-box-p
passed=$((passed + 1))

fresh symlink-join
ln -s "$HOME/Projects/p" "$HOME/q"
echo "true $HOME/Projects/p" > "$FAKE/box"
(cd "$HOME/q" && "$DEV" shell 2>/dev/null) || fail "dev shell exited $?"
not_called run; has exec
passed=$((passed + 1))

fresh join-ending       # the box ends just as dev joins it: a new one, once
echo "true $HOME/Projects/p" > "$FAKE/box"
(cd "$HOME/Projects/p" && FAKE_EXEC_STATUS=125 "$DEV" shell 2>/dev/null) || fail "dev shell exited $?"
[ "$(grep -cx run "$LOG")" = 1 ] || fail "not one new box"
[ "$(grep -cx exec "$LOG")" = 2 ] || fail "not two execs"
has --name
passed=$((passed + 1))

fresh join-stopped      # the box has just stopped, not yet removed: Podman says 255
echo "true $HOME/Projects/p" > "$FAKE/box"
(cd "$HOME/Projects/p" && FAKE_EXEC_STATUS=255 "$DEV" shell 2>/dev/null) || fail "dev shell exited $?"
[ "$(grep -cx run "$LOG")" = 1 ] || fail "not one new box"
passed=$((passed + 1))

fresh session-125       # the session itself ends with 125 and the box runs on: no retry
echo "true $HOME/Projects/p" > "$FAKE/box"
rc=0; (cd "$HOME/Projects/p" && FAKE_EXEC_STATUS=125 FAKE_EXEC_KEEP=1 "$DEV" shell 2>/dev/null) || rc=$?
[ "$rc" = 125 ] || fail "exited $rc, not 125"
not_called run
[ "$(grep -cx exec "$LOG")" = 1 ] || fail "exec retried"
passed=$((passed + 1))

fresh lock-not-inherited   # neither the box's start nor the session holds the lock
(cd "$HOME/Projects/p" && FAKE_ON_RUN='ls -l /proc/$$/fd >> "$FAKE/fds"' "$DEV" shell) || fail "dev shell exited $?"
[ -s "$FAKE/fds" ] || fail "the hook didn't run"
! grep -q 'claude-box-p.lock' "$FAKE/fds" || fail "podman got the lock: $(grep lock "$FAKE/fds")"
passed=$((passed + 1))

fresh new               # --new: a separate box, as before
echo "true $HOME/Projects/p" > "$FAKE/box"
dev_in_p shell --new || fail "dev shell --new exited $?"
has --rm; hasnt --name; not_called exec
has -i; not_called -t
passed=$((passed + 1))

fresh new-tty           # box() gives the same options as joining
(cd "$HOME/Projects/p" && tty_run "$DEV" shell --new) >/dev/null || fail "dev shell --new exited $?"
has -i; has -t
passed=$((passed + 1))

fresh new-stdout-piped
(cd "$HOME/Projects/p" && tty_in "$DEV" shell --new 2>/dev/null | cat) >/dev/null || fail "dev shell --new exited $?"
not_called -i; not_called -t
passed=$((passed + 1))

fresh claude-new
dev_in_p claude --new --resume >/dev/null 2>&1 || fail "dev claude --new exited $?"
hasnt --name; not_called --new; has --resume
passed=$((passed + 1))

fresh caps
(cd "$HOME/Projects/p" && DEV_MEMORY=6g DEV_CPUS=4 "$DEV" shell) || fail "dev shell exited $?"
has --memory=6g
has --cpus=4
passed=$((passed + 1))

fresh spaced
mkdir -p "$HOME/Projects/my app" && git -C "$HOME/Projects/my app" init -q
(cd "$HOME/Projects/my app" && "$DEV" shell) || fail "dev shell exited $?"
has "$HOME/Projects/my app:/work/my app:z"
has "/work/my app"
passed=$((passed + 1))

fresh init
echo n | "$DEV" init >/dev/null 2>&1 || fail "dev init exited $?"
has "$HOME/.claude:/home/claude/.claude:z"
has "CLAUDE_CONFIG_DIR=/home/claude/.claude"
hasnt claude-home
hasnt ":/work"                     # no project mount
passed=$((passed + 1))

fresh reset
mkdir -p "$HOME/.claude" && touch "$HOME/.claude/keep"
out=$(echo y | "$DEV" reset) || fail "dev reset exited $?"
has localhost/claude-box
has "reference=localhost/claude-box-*"
has "name=^claude-box-"
hasnt claude-home
[ -f "$HOME/.claude/keep" ] || fail "$HOME/.claude was touched"
# shellcheck disable=SC2088  # the literal text dev prints
grep -qF '~/.claude' <<< "$out" || fail "output doesn't mention ~/.claude"
[ ! -e "$HOME/.local/state/claude-box/approved" ] || fail "the approved copy stayed"
passed=$((passed + 1))

fresh uninstall             # undoes dev install: reset, the state folder, the link to this clone
"$DEV" install >/dev/null 2>&1 || fail "dev install exited $?"
touch "$HOME/.claude/keep"; : > "$LOG"
out=$(echo n | "$DEV" uninstall) && fail "a no went on: $out"
[ -L "$HOME/.local/bin/dev" ] || fail "a no removed the link"
out=$(echo y | "$DEV" uninstall) || fail "dev uninstall exited $?: $out"
has "name=^claude-box-"
has "reference=localhost/claude-box-*"
[ ! -e "$HOME/.local/state/claude-box" ] || fail "the state folder stayed: $(ls -A "$HOME/.local/state/claude-box")"
[ ! -e "$HOME/.local/bin/dev" ] || fail "the link stayed"
[ -f "$HOME/.claude/keep" ] || fail "$HOME/.claude was touched"
[ -x "$DEV" ] || fail "the clone was touched"
grep -qF "rm -rf ~/.claude" <<< "$out" || fail "doesn't say how to remove ~/.claude: $out"
grep -qF "$CLONE" <<< "$out" || fail "doesn't name the clone: $out"
passed=$((passed + 1))

fresh uninstall-other-link  # a dev link to another clone stays
mkdir -p "$HOME/.local/bin" && ln -s /elsewhere/dev "$HOME/.local/bin/dev"
echo y | "$DEV" uninstall >/dev/null || fail "dev uninstall exited $?"
[ "$(readlink "$HOME/.local/bin/dev")" = /elsewhere/dev ] || fail "another clone's link was removed"
passed=$((passed + 1))

fresh build                 # built from main's core, never the working tree's
echo '# not committed' >> "$CLONE/core/Containerfile"
"$DEV" build >/dev/null || fail "dev build exited $?"
grep -qx -- 'CLAUDE_BUILD=[0-9]*' "$LOG" || fail "dev build passes no CLAUDE_BUILD, so the installer layer stays cached"
grep -qx -- "$CLONE/core" "$LOG" && fail "dev build's context is the working tree's core/"
[ "$(cat "$FAKE/ctx/Containerfile")" = "$(git -C "$CLONE" show main:core/Containerfile)" ] \
    || fail "the Containerfile built isn't main's"
has "claude-box.core=$(core_key)"
has "claude-box.commit=$(git -C "$CLONE" rev-parse main)"
git -C "$CLONE" checkout -q core/Containerfile
passed=$((passed + 1))

# core_change: a new file in core/, committed on the clone's current branch.
# core_change: a change on the clone's current branch to a part of core the image holds (bin/).
core_change() { echo x > "$CLONE/core/bin/x.txt"; clone_commit "core x"; }
base_core() { cat "$FAKE/localhost_claude-box/claude-box.core"; }

fresh core-unchanged        # main's core is the image's: nothing asked, nothing built
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qi core <<< "$out" && fail "said something about core: $out"
passed=$((passed + 1))

fresh core-changed-main     # a core change on main: shown, rebuilt after your yes
core_change
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'x.txt' <<< "$out" || fail "the changed file isn't named: $out"
grep -qF 'core x' <<< "$out" || fail "the commit isn't listed: $out"
has build
[ "$(base_core)" = "$(core_key)" ] || fail "the new image isn't labelled with main's core"
case=core-changed-again; rm -f "$FAKE/box"; : > "$LOG"
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
not_called build
passed=$((passed + 1))

fresh core-changed-no       # no, or no terminal: the old image, said so
core_change
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qF 'old image' <<< "$out" || fail "doesn't say it starts on the old image: $out"
rm -f "$FAKE/box"; : > "$LOG"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qF 'old image' <<< "$out" || fail "without a terminal, doesn't say so: $out"
runs localhost/claude-box
passed=$((passed + 1))

fresh core-on-branch        # a core change on a branch, or not committed: nothing asked
git -C "$CLONE" switch -q -c claude/x
core_change; echo '# dirty' >> "$CLONE/core/Containerfile"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qi 'core' <<< "$out" && fail "asked about a branch's core: $out"
runs localhost/claude-box
passed=$((passed + 1))

fresh core-not-in-image     # a change to core that isn't in the image (dev's own lib/, a README): nothing asked
echo x > "$CLONE/core/lib/x.txt"; echo "# more" >> "$CLONE/core/defaults.dev"; clone_commit "lib only"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qi 'core changed' <<< "$out" && fail "asked for a change the image doesn't hold: $out"
git -C "$CLONE" checkout -q HEAD~1 -- core/defaults.dev
passed=$((passed + 1))

fresh core-unlabelled       # an image from before the label, or a tree git doesn't have: asked once
for label in none 0123456789abcdef0123456789abcdef01234567; do
    if [ "$label" = none ]; then rm -f "$FAKE/localhost_claude-box/claude-box.core" "$FAKE/localhost_claude-box/claude-box.commit"
    else echo "$label" > "$FAKE/localhost_claude-box/claude-box.core"; echo "$label" > "$FAKE/localhost_claude-box/claude-box.commit"; fi
    rm -f "$FAKE/box"; : > "$LOG"
    out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
    grep -qF "can't be listed" <<< "$out" || fail "($label) doesn't say the files can't be listed: $out"
    grep -q 'fatal:' <<< "$out" && fail "($label) git's error shown: $out"
    has build
done
passed=$((passed + 1))

fresh core-rebuild-fails    # a failed rebuild: the box starts on the old image, said so
core_change
out=$(echo y | (cd "$HOME/Projects/p" && FAKE_BUILD_STATUS=1 tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'old image' <<< "$out" || fail "doesn't say so: $out"
runs localhost/claude-box
passed=$((passed + 1))

fresh build-no-main         # no main in the clone: refused, naming main
git -C "$CLONE" branch -q -m main other
out=$("$DEV" build 2>&1) && fail "dev build ran without main"
grep -qF 'main' <<< "$out" || fail "doesn't name main: $out"
not_called build
passed=$((passed + 1))

# removed <id>: dev asked podman to remove that image (podman image rm <id>).
removed() { grep -A1 -x rm "$LOG" | grep -qx -- "$1"; }

fresh build-drops-old       # the image a build replaces is removed by its id
"$DEV" build >/dev/null || fail "dev build exited $?"
removed base1 || fail "the replaced base base1 wasn't removed"
passed=$((passed + 1))

fresh build-old-in-use      # podman refuses while a container uses it: no error, the build stands
out=$(FAKE_RMI_STATUS=2 "$DEV" build 2>&1) || fail "dev build exited $?"
removed base1 || fail "no removal tried"
grep -qi error <<< "$out" && fail "an error shown: $out"
passed=$((passed + 1))

fresh build-sweeps          # leftovers of earlier builds (their box has ended) go too, by dev's label
echo old7 > "$FAKE/dangling"
"$DEV" build >/dev/null || fail "dev build exited $?"
removed old7 || fail "the leftover old7 wasn't removed"
has label=claude-box.image
passed=$((passed + 1))

fresh build-fails-keeps     # a failed build removes nothing
FAKE_BUILD_STATUS=1 "$DEV" build >/dev/null 2>&1 && fail "dev build succeeded"
grep -qx rm "$LOG" && fail "removed an image after a failed build"
passed=$((passed + 1))

# upstream: a bare upstream of the clone's main, with one commit the clone
# hasn't fetched ("Upstream change").
upstream() {
    local up="$tmp/up-$case.git" o="$tmp/other-$case"
    rm -rf "$up" "$o"; git clone -q --bare "$CLONE" "$up"
    git -C "$CLONE" remote add origin "$up" && git -C "$CLONE" fetch -q origin && git -C "$CLONE" branch -q -u origin/main main
    git clone -q "$up" "$o" && echo u > "$o/u.txt" && git -C "$o" add u.txt && git -C "$o" commit -qm 'Upstream change' \
        && git -C "$o" push -q origin main
}
main_is_up() { [ "$(git -C "$CLONE" rev-parse main)" = "$(git -C "$CLONE" rev-parse origin/main)" ]; }

fresh update-yes            # what's coming is listed, and main moves after your yes
upstream
out=$(echo y | tty_run "$DEV" update 2>&1) || fail "dev update exited $?: $out"
grep -qF 'Upstream change' <<< "$out" || fail "the coming commit isn't listed: $out"
main_is_up || fail "main didn't move"
grep -qF 'next dev claude' <<< "$out" || fail "doesn't say where it applies: $out"
case=update-none
out=$("$DEV" update 2>&1) || fail "dev update exited $?: $out"
grep -qF 'up to date' <<< "$out" || fail "doesn't say up to date: $out"
grep -qF '[Y/n]' <<< "$out" && fail "asked with nothing to pull: $out"
passed=$((passed + 1))

fresh update-no             # no, or no terminal: main stays
upstream
before="$(git -C "$CLONE" rev-parse main)"
out=$(echo n | tty_run "$DEV" update 2>&1) || fail "dev update exited $?: $out"
grep -qF 'Upstream change' <<< "$out" || fail "nothing listed: $out"
[ "$(git -C "$CLONE" rev-parse main)" = "$before" ] || fail "main moved after no: $out"
out=$("$DEV" update 2>&1) || fail "dev update without a terminal exited $?: $out"
[ "$(git -C "$CLONE" rev-parse main)" = "$before" ] || fail "main moved without a terminal: $out"
passed=$((passed + 1))

fresh update-no-upstream    # main without an upstream: refused, naming the fix
out=$("$DEV" update 2>&1) && fail "dev update ran without an upstream"
grep -qF 'branch -u' <<< "$out" || fail "doesn't name branch -u: $out"
passed=$((passed + 1))

fresh update-diverged       # main has commits the upstream lacks: refused, main unchanged
upstream
echo l > "$CLONE/l.txt"; clone_commit local; before="$(git -C "$CLONE" rev-parse main)"
out=$(echo y | tty_run "$DEV" update 2>&1) && fail "dev update ran on a diverged main: $out"
grep -qF 'only fast-forwards' <<< "$out" || fail "no reason: $out"
[ "$(git -C "$CLONE" rev-parse main)" = "$before" ] || fail "main changed"
passed=$((passed + 1))

fresh update-on-branch      # another branch checked out: main moves, the checkout stays
upstream
git -C "$CLONE" switch -q -c claude/x
out=$(echo y | tty_run "$DEV" update 2>&1) || fail "dev update exited $?: $out"
main_is_up || fail "main didn't move: $out"
[ "$(git -C "$CLONE" branch --show-current)" = claude/x ] || fail "the checkout changed"
passed=$((passed + 1))

fresh dev-plugins-gone      # dev plugins is gone: it names plugin and .dev
out=$("$DEV" plugins 2>&1) && fail "dev plugins succeeded"
grep -qF 'plugin <name>@<marketplace> <owner/repo>' <<< "$out" && grep -qF '.dev' <<< "$out" || fail "doesn't name plugin: $out"
passed=$((passed + 1))

fresh conf-bad              # a bad line is refused with its number, before any box
for line in 'colour blue' 'memory lots' 'cpus 0' 'remote-control maybe' 'identity Bob' "dnf 'x'" \
        'rules https://example.org/a.md' 'rules http://example.org/0123abc/a.md' 'rules https://example.org/0123abc/a.txt' \
        'projects /' 'projects ~' 'projects ~foo' "projects $HOME/.." "projects $HOME"; do
    conf "$line"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $line"
    grep -qF '/.claude/.dev line 1:' <<< "$out" || fail "no line number for: $line: $out"
    not_called run
done
passed=$((passed + 1))

fresh conf-groups           # group, remote, autotake: accepted; bad ones refused with the line
conf 'group ~/Projects/app/' 'remote app phone-app' 'autotake group'
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "the three kinds refused: $out"
for bad in 'autotake on' 'remote app' 'remote app bad/name' 'group relative/app' 'group ~/Projects/a b/../x'; do
    conf "$bad"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $bad"
    grep -qF "can't use" <<< "$out" || fail "no refusal for $bad: $out"
    not_called run
done
conf 'group ~/Projects/a/app' 'group ~/Projects/b/app'
out=$(dev_in_p shell 2>&1) && fail "two groups named app accepted"
grep -qF 'line 2' <<< "$out" || fail "doesn't name the line: $out"
passed=$((passed + 1))

case=init-autotake          # the starter config dev init writes has autotake group
sed -n '/^    init)/,/;;/p' "$DEV" | grep -qF "'autotake group'" \
    || fail "dev init's starter config lacks autotake group"
passed=$((passed + 1))

fresh dot-dev-old-conf      # an old config in the clone: refused, naming the new place
mkdir -p "$CLONE/local"; echo 'dnf jq' > "$CLONE/local/claude-box.conf"
out=$(dev_in_p shell 2>&1) && fail "started with local/claude-box.conf"
grep -qF 'Your config moved to ~/.claude/.dev' <<< "$out" || fail "doesn't say so: $out"
not_called run
rm -rf "$CLONE/local"
passed=$((passed + 1))

fresh dot-dev-link          # ~/.claude/.dev as a link (any box can write ~/.claude): refused
mkdir -p "$HOME/.claude"; echo 'dnf jq' > "$HOME/elsewhere"; ln -s "$HOME/elsewhere" "$HOME/.claude/.dev"
out=$(dev_in_p shell 2>&1) && fail "started with a linked .dev"
grep -qF 'is a link' <<< "$out" || fail "doesn't say so: $out"
not_called run
passed=$((passed + 1))

fresh dot-dev-gone-kinds    # the old kinds: refused, naming plugin and rules
for line in 'company local/x.md' 'global x.md' 'pack workflow' 'plugin-dir local/pl'; do
    conf "$line"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $line"
    grep -qF 'line 1:' <<< "$out" && grep -qF '"plugin ' <<< "$out" && grep -qF '"rules ' <<< "$out" \
        || fail "doesn't name plugin and rules for: $line: $out"
    not_called run
done
passed=$((passed + 1))

fresh kinds-use-gone        # use is gone: refused, naming the line that replaces it
for pair in 'use workflow|plugin workflow' 'use ~/.claude/r.md|rules ~/.claude/r.md' \
        'use a@b o/r|plugin a@b o/r'; do
    conf "${pair%|*}"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: ${pair%|*}"
    grep -qF "write \"${pair#*|}\"" <<< "$out" || fail "doesn't name ${pair#*|}: $out"
    not_called run
done
passed=$((passed + 1))

fresh kinds-wrong           # a value of the other kind: refused, naming the right one
mkdir -p "$HOME/.claude/my-plugin/skills"; echo r > "$HOME/.claude/r.md"
for pair in 'plugin ~/.claude/r.md|rules' 'rules ~/.claude/my-plugin|plugin' 'rules workflow|plugin' \
        'plugin https://example.org/a/0123abc/r.md|rules'; do
    conf "${pair%|*}"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: ${pair%|*}"
    grep -qF "\"${pair#*|} " <<< "$out" || fail "doesn't name ${pair#*|} for ${pair%|*}: $out"
    not_called run
done
passed=$((passed + 1))

# plugin_dir <name>: a plugin's folder in ~/.claude; rules files go there too.
plugin_dir() { mkdir -p "$HOME/.claude/$1/.claude-plugin"; echo "{\"name\":\"$1\"}" > "$HOME/.claude/$1/.claude-plugin/plugin.json"; }
approved=".dev"
# approve_layer: your config with an identity and a rules file, approved at a terminal.
approve_layer() {
    conf 'identity Ann <ann@example.invalid>' 'rules ~/.claude/r.md'; echo 'Be kind.' > "$HOME/.claude/r.md"
    echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
    : > "$LOG"
}
state() { cat "$HOME/.local/state/claude-box/approved/$1"; }

fresh use-forms             # each use form, and npm and pip: accepted and approved
plugin_dir pl; mkdir -p "$HOME/.claude/sk"; echo s > "$HOME/.claude/sk/SKILL.md"; echo r > "$HOME/.claude/r.md"
for line in 'plugin workflow' 'plugin ~/.claude/pl' 'plugin ~/.claude/sk' 'rules ~/.claude/r.md' \
        'rules https://example.org/a/0123abc/r2.md' 'plugin c4m@c4-model-skill cheriftj/c4-model-skill' 'npm cowsay' 'pip pyfiglet'; do
    conf "$line"; rm -rf "$HOME/.local/state/claude-box/approved"
    printf 'y\nn\n' | (cd "$HOME/Projects/p" && FAKE_CURL_BODY=x tty_run "$DEV" shell) >/dev/null 2>&1 || true
    grep -qxF "$line" <(state "$approved" 2>/dev/null) || fail "not accepted and approved: $line"
done
passed=$((passed + 1))

fresh use-bounds            # local paths stay in ~/.claude, links included; plugins by name
echo secret > "$HOME/key"; mkdir -p "$HOME/.claude/noplugin"; touch "$HOME/.claude/a b.md"
ln -s "$HOME/key" "$HOME/.claude/l.md"; plugin_dir pl; ln -s "$HOME/key" "$HOME/.claude/pl/README.md"
for line in 'plugin ~/key' 'rules ~/.claude/l.md' 'plugin /etc/passwd' 'plugin ~/.claude/../key' 'plugin ../core' \
        'plugin plugins/../core' 'plugin ~/.claude/noplugin' 'plugin nope' 'rules ~/.claude/a b.md' 'plugin ~/.claude/pl' \
        'rules ~/.claude/./r.md'; do
    conf "$line"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $line"
    grep -qF 'line 1:' <<< "$out" || fail "no line number for: $line: $out"
    not_called run
done
passed=$((passed + 1))

fresh use-link-inside       # no links in a source from ~/.claude, not even into ~/.claude
mkdir -p "$HOME/.claude/x"; echo hi > "$HOME/.claude/x/r.md"; ln -s x/r.md "$HOME/.claude/l.md"
plugin_dir pl; ln -s ../x/r.md "$HOME/.claude/pl/README.md"
for line in 'rules ~/.claude/l.md' 'plugin ~/.claude/pl'; do
    conf "$line"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $line"
    grep -qF 'line 1:' <<< "$out" || fail "no line number for: $line: $out"
    not_called run
done
passed=$((passed + 1))

fresh use-link-swap         # a file swapped for a link after the check: refused, nothing copied
echo secret > "$HOME/key"; mkdir -p "$HOME/.claude"; echo hi > "$HOME/.claude/r.md"
mkdir -p "$tmp/swap"; cat > "$tmp/swap/cp" <<'SWAP'
#!/usr/bin/env bash
for a; do
    if [ "$a" = "$SWAP_SRC" ] && [ ! -L "$a" ]; then rm -f -- "$a"; ln -s "$SWAP_TO" "$a"; fi
done
exec /usr/bin/cp "$@"
SWAP
chmod +x "$tmp/swap/cp"; conf 'rules ~/.claude/r.md'
out=$(echo y | (cd "$HOME/Projects/p" && PATH="$tmp/swap:$PATH" SWAP_SRC="$HOME/.claude/r.md" SWAP_TO="$HOME/key" \
    tty_run "$DEV" shell) 2>&1) && fail "started with a swapped link: $out"
grep -rqs secret "$HOME/.local/state/claude-box" && fail "the key reached the approved copy"
grep -qF secret <<< "$out" && fail "the key was shown: $out"
not_called run
passed=$((passed + 1))

fresh use-names             # one name, one plugin or rules file; never box-workflow or files
plugin_dir workflow; plugin_dir files; plugin_dir box-workflow; plugin_dir lp
echo '{ "name" : "box-workflow" }' > "$HOME/.claude/lp/.claude-plugin/plugin.json"
mkdir -p "$HOME/.claude/a" "$HOME/.claude/b"; echo x > "$HOME/.claude/a/r.md"; echo y > "$HOME/.claude/b/r.md"
for pair in 'plugin workflow|plugin ~/.claude/workflow' 'rules ~/.claude/a/r.md|rules ~/.claude/b/r.md' \
        'dnf jq|plugin ~/.claude/files' 'dnf jq|plugin ~/.claude/box-workflow' 'dnf jq|plugin ~/.claude/lp'; do
    conf "${pair%|*}" "${pair#*|}"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $pair"
    grep -qF 'line 2:' <<< "$out" || fail "not refused at line 2: $pair: $out"
done
passed=$((passed + 1))

fresh project-kind-global   # port is a project's, refused in yours; yours are refused in a project
conf 'port 80'
out=$(dev_in_p shell 2>&1) && fail "port accepted in ~/.claude/.dev"
grep -qF 'project only' <<< "$out" || fail "doesn't say so: $out"
conf 'dnf jq'
for line in 'identity Ann <a@b.org>' 'projects ~/P' 'memory 8g' 'cpus 2' 'remote-control on' 'remote g n' 'autotake group'; do
    echo "$line" > "$HOME/Projects/p/.dev"
    out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) && fail "accepted in a project: $line"
    grep -qF 'global only' <<< "$out" || fail "doesn't say global only: $line: $out"
done
rm "$HOME/Projects/p/.dev"
passed=$((passed + 1))

fresh use-url-pin           # a URL's file is the pin: kept in the approved copy, fetched once
url=https://example.org/a/0123abc/r2.md
conf "rules $url"
echo y | (cd "$HOME/Projects/p" && FAKE_CURL_BODY=One. tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
grep -qx 'One.' "$HOME/.local/state/claude-box/approved/urls/r2.md" || fail "the URL's file isn't in the approved copy"
has "$HOME/.local/state/claude-box/approved/urls/r2.md:/home/claude/.claude/rules/files/r2.md:ro,z"
case=use-url-unchanged; rm -f "$FAKE/box"; : > "$LOG"
out=$(cd "$HOME/Projects/p" && FAKE_CURL_STATUS=22 "$DEV" shell 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'Apply it?' <<< "$out" && fail "asked although nothing changed"
grep -qF "Couldn't fetch" <<< "$out" && fail "fetched an unchanged URL: $out"
case=use-url-unfetchable; rm -f "$FAKE/box"; : > "$LOG"
conf "rules https://example.org/a/0123abd/r2.md"
out=$(echo y | (cd "$HOME/Projects/p" && FAKE_CURL_STATUS=22 tty_run "$DEV" shell)) || fail "dev shell exited $?: $out"
grep -qF "Couldn't fetch https://example.org/a/0123abd/r2.md" <<< "$out" || fail "the URL isn't named: $out"
grep -qF 'approved last' <<< "$out" || fail "doesn't start on the approved copy: $out"
grep -qxF "rules $url" <(state "$approved") || fail "the approved copy changed"
passed=$((passed + 1))

fresh approved-old-schema   # an approved copy dev can't read counts as none
old_snapshot() {
    rm -rf "$HOME/.local/state/claude-box/approved"; mkdir -p "$HOME/.local/state/claude-box/approved/local"
    printf 'rules local/r.md\n' > "$HOME/.local/state/claude-box/approved/local/claude-box.conf"
    echo x > "$HOME/.local/state/claude-box/approved/local/r.md"; echo oldhash > "$HOME/.local/state/claude-box/approved/hash"
}
old_snapshot; conf 'identity Ann <ann@example.invalid>' 'rules ~/.claude/r.md'; echo x > "$HOME/.claude/r.md"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?: $out"
grep -qF '+rules ~/.claude/r.md' <<< "$out" || fail "the config isn't shown: $out"
grep -qxF 'rules ~/.claude/r.md' <(state "$approved") || fail "not approved"
runs localhost/claude-box.user
case="approved-old-schema-no-tty"; old_snapshot; : > "$LOG"
out=$(dev_in_p shell 2>&1) && fail "started without a terminal on no readable approval"
grep -qF '/.claude/.dev' <<< "$out" && grep -qF 'terminal' <<< "$out" || fail "doesn't say why: $out"
not_called run
passed=$((passed + 1))

fresh layer-race            # what's built and approved is what was shown, not what ~/.claude holds by the yes
conf 'identity Ann <ann@example.invalid>' 'rules ~/.claude/r.md'; echo 'Be kind.' > "$HOME/.claude/r.md"
{ sleep 3; echo 'Unseen line.' >> "$HOME/.claude/r.md"; echo y; } | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 \
    || fail "dev shell exited $?"
has build
grep -q 'Unseen' "$HOME/.local/state/claude-box/approved/home/.claude/r.md" && fail "a line written after the diff was approved"
case=layer-race-next; : > "$LOG"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF '+Unseen line.' <<< "$out" || fail "the next start doesn't show the unseen line: $out"
passed=$((passed + 1))

fresh layer-diff-clean      # the diff reaches the terminal without control characters
conf 'rules ~/.claude/r.md'; printf 'Be\033[2K kind.\n' > "$HOME/.claude/r.md"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell))    # no, with nothing approved: refused after the diff
grep -q $'\033' <<< "$out" && fail "an escape reached the terminal"
grep -qF 'Be?[2K kind.' <<< "$out" || fail "the line isn't shown, made safe: $out"
passed=$((passed + 1))

fresh layer-unreadable      # a file dev can't read, nothing approved before: nothing built or started, said so
conf 'rules ~/.claude/r.md'; echo 'Be kind.' > "$HOME/.claude/r.md"; chmod 000 "$HOME/.claude/r.md"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) && fail "started with nothing approved: $out"
not_called build
not_called run
grep -qi "couldn't read" <<< "$out" && grep -qF 'nothing started' <<< "$out" || fail "doesn't say so: $out"
[ ! -e "$HOME/.local/state/claude-box/approved" ] || fail "approved anyway"
chmod 644 "$HOME/.claude/r.md"
passed=$((passed + 1))

fresh layer-none            # no config of yours: no layer, the public base
dev_in_p shell >/dev/null || fail "dev shell exited $?"
not_called build
runs localhost/claude-box
passed=$((passed + 1))

fresh layer-first           # your config, new: shown, asked, built as a layer on the base
conf 'identity Ann <ann@example.invalid>' 'rules ~/.claude/r.md' 'dnf jq' 'npm cowsay' 'pip pyfiglet' 'plugin ~/.claude/pl'
echo 'Be kind.' > "$HOME/.claude/r.md"; plugin_dir pl
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?: $out"
grep -qF 'Apply it? [Y/n]' <<< "$out" || fail "not asked: $out"
grep -qF '+identity Ann <ann@example.invalid>' <<< "$out" || fail "config not shown: $out"
grep -qxF 'FROM localhost/claude-box' "$LOG" || fail "not built on the base"
grep -q '/etc/claude-code/local' "$LOG" && fail "rules built into the layer"
grep -qF "RUN dnf -y install 'jq' npm python3-pip" "$LOG" || fail "no dnf step: $(grep RUN "$LOG")"
grep -qF "RUN npm install -g 'cowsay'" "$LOG" || fail "no npm step"
grep -qF "RUN pip install 'pyfiglet'" "$LOG" || fail "no pip step"
grep -qF "git config --system user.name 'Ann'" "$LOG" || fail "no identity"
grep -qxF 'COPY plugins/pl /usr/local/share/claude-box/plugins/pl' "$LOG" || fail "plugin not copied"
grep -qxF 'ENV CLAUDE_CODE_PLUGIN_DIRS=/usr/local/share/claude-box/plugins/box-workflow:/usr/local/share/claude-box/plugins/pl' "$LOG" \
    || fail "plugin dir not added"
[ -s "$FAKE/localhost_claude-box.user/claude-box.config" ] || fail "no config label"
[ "$(cat "$FAKE/localhost_claude-box.user/claude-box.base")" = base1 ] || fail "no base label"
runs localhost/claude-box.user
grep -qxF 'dnf jq' <(state "$approved") || fail "approved copy not kept"
has "$HOME/.local/state/claude-box/approved/home/.claude/r.md:/home/claude/.claude/rules/files/r.md:ro,z"
passed=$((passed + 1))

case=layer-copy-sources     # every COPY of your layer names a file in its build context
while read -r _ src _; do
    [ -e "$FAKE/ctx/$src" ] || fail "COPY $src: not in the build context"
done < <(grep '^COPY ' "$LOG")
passed=$((passed + 1))

case=layer-unchanged; : > "$LOG"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?"
grep -qF 'Apply it?' <<< "$out" && fail "asked although nothing changed"
not_called build
runs localhost/claude-box.user
passed=$((passed + 1))

case=layer-rule-edited; : > "$LOG"
echo 'Be very kind.' > "$HOME/.claude/r.md"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF 'r.md' <<< "$out" || fail "the rule's change not shown: $out"
passed=$((passed + 1))

fresh layer-declined        # no, or no terminal: the version you approved last
approve_layer
echo 'dnf tree' >> "$HOME/.claude/.dev"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
not_called build
runs localhost/claude-box.user
grep -qF 'approved last' <<< "$out" || fail "doesn't say which version: $out"
case=layer-no-tty; : > "$LOG"
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
not_called build
runs localhost/claude-box.user
grep -q tree <(state "$approved") && fail "the declined change was approved"
passed=$((passed + 1))

fresh layer-base-changed    # a new base: rebuilt from the approved copy, without asking
approve_layer
echo base2 > "$FAKE/localhost_claude-box/id"
echo 'dnf tree' >> "$HOME/.claude/.dev"      # not approved: not built in
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
has build
[ "$(cat "$FAKE/localhost_claude-box.user/claude-box.base")" = base2 ] || fail "base label not updated"
grep -q tree "$LOG" && fail "the unapproved change was built in"
passed=$((passed + 1))

fresh layer-build-fails     # a failed build: the old layer and the old approval stay
approve_layer
echo 'dnf tree' >> "$HOME/.claude/.dev"
out=$(echo y | (cd "$HOME/Projects/p" && FAKE_BUILD_STATUS=1 tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qi 'fail' <<< "$out" || fail "no failure shown: $out"
runs localhost/claude-box.user
grep -q tree <(state "$approved") && fail "approved although the build failed"
passed=$((passed + 1))

fresh layer-deleted         # your config gone: the public base, not the old layer
approve_layer
mv "$HOME/.claude/.dev" "$HOME/.claude/dev.aside"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?"
grep -qF 'No ~/.claude/.dev' <<< "$out" || fail "doesn't say your config is gone: $out"
runs localhost/claude-box
grep -qxF localhost/claude-box.user "$LOG" && fail "the old layer was used"
passed=$((passed + 1))

fresh layer-project         # a project image builds on your layer
approve_layer
echo 'dnf tree' > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
grep -qxF 'FROM localhost/claude-box.user' "$LOG" || fail "project image not built on the layer"
[ "$(cat "$FAKE/localhost_claude-box-p/claude-box.base")" = "$(cat "$FAKE/localhost_claude-box.user/id")" ] \
    || fail "the project image's base label isn't the layer"
runs localhost/claude-box-p
case=layer-project-rebuilt; : > "$LOG"
echo 'Be very kind.' > "$HOME/.claude/r.md"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
[ "$(grep -c '^FROM ' "$LOG")" = 2 ] || fail "layer and project image not both rebuilt: $(grep '^FROM ' "$LOG")"
passed=$((passed + 1))

fresh layer-scratch         # a scratch's box runs on your layer
approve_layer
(cd "$HOME" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
runs localhost/claude-box.user
passed=$((passed + 1))

# full_plugin: plugin w in the clone with rules, a skill and a starter; your config names a rules file and it.
full_plugin() {
    local w="$CLONE/plugins/w"
    mkdir -p "$w/.claude-plugin" "$w/rules" "$w/starter" "$w/skills/s"
    echo '{"name":"w"}' > "$w/.claude-plugin/plugin.json"; echo s > "$w/skills/s/SKILL.md"
    echo 'Old.' > "$w/rules/g.md"; echo s > "$w/starter/s.md"
    mkdir -p "$HOME/.claude"; echo r > "$HOME/.claude/r.md"; conf 'rules ~/.claude/r.md' 'plugin w'
    clone_commit w
}
rules_mount() { grep -F ':/home/claude/.claude/rules' "$LOG"; }

fresh plugin-all-parts      # a plugin built into your layer, its rules/ mounted, a rules file mounted
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
grep -qxF 'COPY plugins/w /usr/local/share/claude-box/plugins/w' "$LOG" || fail "the plugin isn't in the layer"
grep -qxF 'ENV CLAUDE_CODE_PLUGIN_DIRS=/usr/local/share/claude-box/plugins/box-workflow:/usr/local/share/claude-box/plugins/w' "$LOG" \
    || fail "the plugin isn't loaded"
has "$HOME/.local/state/claude-box/approved/plugins/w/rules:/home/claude/.claude/rules/w:ro,z"
has "$HOME/.local/state/claude-box/approved/home/.claude/r.md:/home/claude/.claude/rules/files/r.md:ro,z"
rules_mount | grep -q starter && fail "the starter is mounted as rules: $(rules_mount)"
passed=$((passed + 1))

fresh plugin-branch-not-shown # a plugin changed on a branch, or not committed: not shown, not approved
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
git -C "$CLONE" switch -q -c claude/x
echo 'Branch.' > "$CLONE/plugins/w/rules/g.md"; clone_commit branch; echo 'Dirty.' > "$CLONE/plugins/w/rules/g.md"
rm -f "$FAKE/box"; : > "$LOG"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'differs' <<< "$out" && fail "a branch's plugin change was shown: $out"
grep -qx 'Old.' "$HOME/.local/state/claude-box/approved/plugins/w/rules/g.md" || fail "the approved copy changed"
passed=$((passed + 1))

fresh plugin-main-shown     # the same change on main: shown, approved after your yes
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
echo 'New.' > "$CLONE/plugins/w/rules/g.md"; clone_commit new; rm -f "$FAKE/box"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF '+New.' <<< "$out" || fail "the change isn't shown: $out"
grep -qx 'New.' "$HOME/.local/state/claude-box/approved/plugins/w/rules/g.md" || fail "not approved"
case=main-dir-one-tree
[ "$(find "$HOME/.local/state/claude-box/main" -mindepth 1 -maxdepth 1 | wc -l)" = 1 ] \
    || fail "main/ holds: $(ls "$HOME/.local/state/claude-box/main")"
passed=$((passed + 1))

fresh mounts-approved-only  # what's mounted is the approved copy, not plugins/ as it is now
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
echo 'New.' > "$CLONE/plugins/w/rules/g.md"; clone_commit new; rm -f "$FAKE/box"; : > "$LOG"
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
has "$HOME/.local/state/claude-box/approved/plugins/w/rules:/home/claude/.claude/rules/w:ro,z"
grep -qx 'Old.' "$HOME/.local/state/claude-box/approved/plugins/w/rules/g.md" || fail "the approved copy changed"
passed=$((passed + 1))

fresh mounts-points-yours   # dev makes the mount points, so they're yours, not Podman's
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
[ -d "$HOME/.claude/rules/w" ] && [ -O "$HOME/.claude/rules/w" ] || fail "rules/w isn't a folder of yours"
[ -f "$HOME/.claude/rules/files/r.md" ] && [ -O "$HOME/.claude/rules/files/r.md" ] || fail "rules/files/r.md isn't a file of yours"
passed=$((passed + 1))

fresh mounts-scratch        # a scratch's box gets the rules too
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
rm -f "$FAKE/box"; : > "$LOG"
(cd "$HOME" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
has "$HOME/.local/state/claude-box/approved/plugins/w/rules:/home/claude/.claude/rules/w:ro,z"
passed=$((passed + 1))

fresh mounts-none           # no config: nothing mounted under rules/
dev_in_p shell >/dev/null || fail "dev shell exited $?"
[ -z "$(rules_mount)" ] || fail "mounted: $(rules_mount)"
passed=$((passed + 1))

fresh dev-kinds-add         # dev add plugin and rules write their lines; dev add use is refused, naming both
dev_in_p add plugin c4m@c4-model-skill cheriftj/c4-model-skill >/dev/null || fail "dev add plugin exited $?"
[ "$(cat "$HOME/Projects/p/.dev")" = 'plugin c4m@c4-model-skill cheriftj/c4-model-skill' ] || fail ".dev: $(cat "$HOME/Projects/p/.dev")"
dev_in_p remove plugin c4m@c4-model-skill >/dev/null || fail "dev remove plugin exited $?"
[ ! -e "$HOME/Projects/p/.dev" ] || fail ".dev still has: $(cat "$HOME/Projects/p/.dev")"
mkdir -p "$HOME/.claude"; echo r > "$HOME/.claude/r.md"
# shellcheck disable=SC2088  # the literal ~ is what .dev holds
dev_in_p add rules '~/.claude/r.md' >/dev/null || fail "dev add rules exited $?"
grep -qxF 'rules ~/.claude/r.md' "$HOME/Projects/p/.dev" || fail ".dev: $(cat "$HOME/Projects/p/.dev")"
rm "$HOME/Projects/p/.dev"
out=$(dev_in_p add use a@b o/r 2>&1) && fail "dev add use succeeded"
grep -qF 'Usage:' <<< "$out" && grep -qF 'plugin' <<< "$out" && grep -qF 'rules' <<< "$out" || fail "doesn't name plugin and rules: $out"
passed=$((passed + 1))

fresh dev-group             # dev add group writes the line; one group per project
dev_in_p add group app >/dev/null || fail "dev add group exited $?"
grep -qx 'group app' "$HOME/Projects/p/.dev" || fail "no group line"
out=$(dev_in_p add group other 2>&1) && fail "a second group added"
grep -qF 'one group' <<< "$out" || fail "no reason: $out"
printf 'group app\ngroup other\n' > "$HOME/Projects/p/.dev"
out=$(dev_in_p shell 2>&1) && fail "two group lines accepted"
grep -qF 'one group' <<< "$out" || fail "no reason: $out"
rm "$HOME/Projects/p/.dev"
dev_in_p add group 'bad/name' >/dev/null 2>&1 && fail "a bad name added"
passed=$((passed + 1))

fresh dev-old-lines         # .dev's use and pack lines: skipped, said once naming the replacement, the box starts
full_plugin; printf 'pack w\nuse a@b o/r\n' > "$HOME/Projects/p/.dev"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
[ "$(grep -c 'is no longer read' <<< "$out")" = 2 ] || fail "not said once per line: $out"
grep -qF 'write "plugin a@b o/r"' <<< "$out" || fail "the replacement isn't named: $out"
runs localhost/claude-box.user
rules_mount | grep -q -- '-project' && fail "a project rules mount: $(rules_mount)"
grep -qxF 'a@b' "$LOG" && fail "an old plugin line was staged"
passed=$((passed + 1))

fresh dev-old-lines-kept    # a skipped use line: nothing staged, nothing asked about it
full_plugin; printf 'use a@b o/r\n' > "$HOME/Projects/p/.dev"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'a@b' "$LOG" && fail "a@b staged: $(cat "$LOG")"
passed=$((passed + 1))

fresh kinds-project-wrong   # a project's line of the wrong kind: refused, naming the right one
mkdir -p "$HOME/.claude"; echo r > "$HOME/.claude/r.md"
echo 'plugin ~/.claude/r.md' > "$HOME/Projects/p/.dev"
out=$(dev_in_p shell 2>&1) && fail "accepted: plugin ~/.claude/r.md in a project"
grep -qF '.dev line 1:' <<< "$out" && grep -qF '"rules ' <<< "$out" || fail "doesn't name rules: $out"
not_called run
passed=$((passed + 1))

case=box-rules-plugin       # the box's own rules name a project's plugin line
grep -qF '`plugin <name>@<marketplace> <owner/repo>`' "$REPO/core/rules/CLAUDE.md" || fail "core/rules/CLAUDE.md doesn't name plugin"
passed=$((passed + 1))

fresh workflow-shipped      # the repo's workflow plugin: built in, its rules mounted, superpowers in your seed
conf 'plugin workflow'
echo y | FAKE_STAGE='superpowers@superpowers-marketplace=5' tty_run_in_p "$DEV" shell >/dev/null || fail "approving exited $?"
[ -f "$FAKE/ctx/plugins/workflow/skills/closing/SKILL.md" ] || fail "the closing skill wasn't built in"
[ -f "$FAKE/ctx/plugins/workflow/starter/tests/check_links.py" ] || fail "the starter isn't in the layer"
has "$HOME/.local/state/claude-box/approved/plugins/workflow/rules:/home/claude/.claude/rules/workflow:ro,z"
has obra/superpowers-marketplace
has superpowers@superpowers-marketplace
grep -qF '"superpowers@superpowers-marketplace": true' "$FAKE/ctx/claude-box-plugins.json" || fail "superpowers not switched on"
not_called box-plugins
passed=$((passed + 1))

fresh plugin-deps-missing   # a dependency without a known repo: named, with the line to add
plugin_dir pd; echo '{"name":"pd","dependencies":["x@unknown"]}' > "$HOME/.claude/pd/.claude-plugin/plugin.json"
conf 'plugin ~/.claude/pd'
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF 'plugin x@unknown <owner/repo>' <<< "$out" || fail "the missing dependency isn't named: $out"
passed=$((passed + 1))


fresh init-starter          # dev init writes your config, pointing to the reference
"$DEV" init >/dev/null 2>&1 || fail "dev init exited $?"
head -n 1 "$HOME/.claude/.dev" | grep -qF "# What's in every box. Every kind, with examples: $CLONE/core/defaults.dev" \
    || fail "first line: $(head -n 1 "$HOME/.claude/.dev" 2>&1)"
[ "$(grep -v '^#' "$HOME/.claude/.dev" | grep .)" = "$(printf '%s\n' 'identity Claude <claude@claude-box.invalid>' 'plugin workflow' 'autotake group')" ] \
    || fail "the starter's lines: $(grep -v '^#' "$HOME/.claude/.dev" | grep .)"
passed=$((passed + 1))

fresh install-runs-init     # ./dev install links dev, then runs dev init (no terminal: the default identity)
out=$("$DEV" install 2>&1) || fail "dev install exited $?: $out"
[ "$(readlink "$HOME/.local/bin/dev")" = "$DEV" ] || fail "no link: $out"
grep -qx 'identity Claude <claude@claude-box.invalid>' "$HOME/.claude/.dev" || fail "no config with the default identity: $out"
runs localhost/claude-box
passed=$((passed + 1))

fresh init-identity-typed   # a typed identity is written
printf 'Ann <ann@example.org>\nn\n' | tty_run "$DEV" init >/dev/null 2>&1 || fail "dev init exited $?"
grep -qx 'identity Ann <ann@example.org>' "$HOME/.claude/.dev" || fail "not written: $(cat "$HOME/.claude/.dev")"
passed=$((passed + 1))

fresh init-identity-enter   # Enter keeps the default, written out
printf '\nn\n' | tty_run "$DEV" init >/dev/null 2>&1 || fail "dev init exited $?"
grep -qx 'identity Claude <claude@claude-box.invalid>' "$HOME/.claude/.dev" || fail "not written: $(cat "$HOME/.claude/.dev")"
passed=$((passed + 1))

fresh init-identity-bad     # a bad identity is asked again
out=$(printf 'Bob\nAnn <ann@example.org>\nn\n' | tty_run "$DEV" init 2>&1) || fail "dev init exited $?: $out"
[ "$(grep -c "Claude's git identity" <<< "$out")" -ge 2 ] || fail "not asked again: $out"
grep -qx 'identity Ann <ann@example.org>' "$HOME/.claude/.dev" || fail "not written: $(cat "$HOME/.claude/.dev")"
passed=$((passed + 1))

case=init-keeps             # a second dev init leaves your edits alone
echo 'memory 8g' >> "$HOME/.claude/.dev"; before="$(cat "$HOME/.claude/.dev")"
out=$(printf '\nn\n' | tty_run "$DEV" init 2>&1) || fail "dev init exited $?: $out"
[ "$(cat "$HOME/.claude/.dev")" = "$before" ] || fail "dev init changed your config"
grep -qF "git identity" <<< "$out" && fail "asked the identity with a config there: $out"
passed=$((passed + 1))

case=defaults-every-kind    # core/defaults.dev explains every kind
for k in identity plugin rules dnf npm pip projects memory cpus remote-control group remote autotake port; do
    grep -q "^#   $k " "$REPO/core/defaults.dev" || fail "core/defaults.dev doesn't explain $k"
done
passed=$((passed + 1))

fresh approved-none-declined # nothing approved dev can read, and no, or a failed build: not the defaults in your config's place
old_snapshot; conf 'identity Ann <ann@example.invalid>' 'rules ~/.claude/r.md'; echo x > "$HOME/.claude/r.md"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) && fail "started on no: $out"
grep -qF 'nothing started' <<< "$out" || fail "doesn't say so: $out"
not_called run
case="approved-none-build-fails"; old_snapshot; : > "$LOG"
out=$(echo y | (cd "$HOME/Projects/p" && FAKE_BUILD_STATUS=1 tty_run "$DEV" shell)) && fail "started after a failed build: $out"
grep -qF 'nothing started' <<< "$out" || fail "doesn't say so: $out"
not_called run
passed=$((passed + 1))

fresh approved-kept         # a new approval keeps the old copy, which running boxes still mount
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
echo 'New.' > "$CLONE/plugins/w/rules/g.md"; clone_commit new; rm -f "$FAKE/box"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
grep -qx 'New.' "$HOME/.local/state/claude-box/approved/plugins/w/rules/g.md" || fail "not approved"
grep -qsx 'Old.' "$HOME/.local/state/claude-box/approved-old/"*/plugins/w/rules/g.md || fail "the old copy is gone"
passed=$((passed + 1))

fresh mounts-no-links       # a link where a mount point goes (any box can write there): refused
full_plugin
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
mkdir -p "$HOME/elsewhere"
for l in "$HOME/.claude/rules/w" "$HOME/.claude/rules"; do
    rm -rf "$HOME/.claude/rules"; mkdir -p "$HOME/.claude/rules"; rm -rf "$l"; ln -s "$HOME/elsewhere" "$l"
    rm -f "$FAKE/box"; : > "$LOG"
    out=$(dev_in_p shell 2>&1) && fail "started with $l a link"
    grep -qF 'is a link' <<< "$out" || fail "doesn't say so: $out"
    not_called run
done
rm -f "$HOME/.claude/rules"
passed=$((passed + 1))

fresh layer-no-loosening    # a config with every build kind changes the box's image, nothing else of its run
run_args() { awk '$0 == "run" { on = 1; next } on && $0 == "--" { exit } on' "$LOG" | sed 's/^localhost\/claude-box\.user$/IMAGE/; s/^localhost\/claude-box$/IMAGE/'; }
(cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "dev shell exited $?"
plain="$(run_args)"
grep -qx -- '--cap-drop=all' <<< "$plain" || fail "no --cap-drop=all: $plain"
grep -qx -- '--security-opt=no-new-privileges' <<< "$plain" || fail "no no-new-privileges: $plain"
rm -f "$FAKE/box"; plugin_dir pl
conf 'identity Ann <ann@example.invalid>' 'plugin ~/.claude/pl' 'dnf jq' 'npm cowsay' 'pip pyfiglet' 'remote-control on'
: > "$LOG"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "approving exited $?: $out"
runs localhost/claude-box.user
[ "$(run_args)" = "$plain" ] || fail "the run changed beyond its image: $(diff <(echo "$plain") <(run_args))"
passed=$((passed + 1))

fresh runtime               # runtime values: asked like the rest, no layer, env wins
mkdir -p "$HOME/elsewhere"
conf 'memory 4g' 'cpus 2' 'remote-control off' 'projects ~/elsewhere'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
not_called build
runs localhost/claude-box
has --memory=4g
has --cpus=2
has "$HOME/elsewhere:/projects:ro,z"
: > "$LOG"; dev_in_p claude >/dev/null 2>&1 || fail "dev claude exited $?"
hasnt --remote-control
: > "$LOG"; (cd "$HOME/Projects/p" && DEV_MEMORY=8g "$DEV" shell) >/dev/null 2>&1 || fail "dev shell exited $?"
has --memory=8g
passed=$((passed + 1))

# .dev: dev add / dev remove edit it (one item per line).
devfile() { cat "$HOME/Projects/p/.dev"; }

fresh add
dev_in_p add dnf jq tree >/dev/null || fail "dev add exited $?"
[ "$(devfile)" = $'dnf jq\ndnf tree' ] || fail ".dev is: $(devfile)"
out=$(dev_in_p add dnf jq) || fail "dev add exited $?"
grep -q already <<< "$out" || fail "no 'already' in: $out"
[ "$(grep -c '^dnf jq$' "$HOME/Projects/p/.dev")" = 1 ] || fail "dnf jq added twice"
passed=$((passed + 1))

fresh remove
printf 'dnf jq\nnpm x\n' > "$HOME/Projects/p/.dev"
dev_in_p remove dnf jq >/dev/null || fail "dev remove exited $?"
[ "$(devfile)" = 'npm x' ] || fail ".dev is: $(devfile)"
out=$(dev_in_p remove dnf nope) || fail "dev remove exited $?"
grep -q 'not in .dev' <<< "$out" || fail "no 'not in .dev' in: $out"
dev_in_p remove npm x >/dev/null || fail "dev remove exited $?"
[ ! -e "$HOME/Projects/p/.dev" ] || fail "empty .dev not deleted"
passed=$((passed + 1))

fresh add-plugin            # dev add plugin: a marketplace plugin with its repo
dev_in_p add plugin a@b o/r >/dev/null || fail "dev add plugin a@b o/r exited $?"
grep -qx 'plugin a@b o/r' "$HOME/Projects/p/.dev" || fail ".dev is: $(devfile)"
out=$(dev_in_p add plugin x@y 2>&1) && fail "dev add plugin without a repo succeeded"
grep -qF 'dev add plugin <name>@<marketplace> <owner/repo>' <<< "$out" || fail "doesn't say how: $out"
passed=$((passed + 1))


fresh bad-dev
printf 'dnf jq\napt foo\n' > "$HOME/Projects/p/.dev"
out=$(dev_in_p claude 2>&1) && fail "dev claude with a bad .dev succeeded"
grep -q '.dev line 2:' <<< "$out" || fail "no '.dev line 2:' in: $out"
printf 'plugin a@b\n' > "$HOME/Projects/p/.dev"
out=$(dev_in_p claude 2>&1) && fail "dev claude with a plugin line without repo succeeded"
grep -q '.dev line 1:' <<< "$out" || fail "no '.dev line 1:' in: $out"
not_called run; not_called exec      # the box never started
passed=$((passed + 1))

fresh crlf
printf 'dnf jq\r\n  npm   x  \r\n' > "$HOME/Projects/p/.dev"
out=$(dev_in_p add dnf jq) || fail "dev add exited $?"
grep -q already <<< "$out" || fail "CRLF line not recognised: $out"
dev_in_p remove npm x >/dev/null || fail "dev remove exited $?"
[ "$(devfile)" = 'dnf jq' ] || fail ".dev is: $(devfile | od -c | head -3)"
passed=$((passed + 1))

fresh add-outside
out=$(cd "$HOME" && "$DEV" add dnf jq 2>&1) && fail "dev add outside a project succeeded"
grep -q 'Not a project: ' <<< "$out" || fail "unexpected message: $out"
passed=$((passed + 1))

# The project image: .dev's dnf, npm and pip packages.
three() { printf 'dnf jq\nnpm x\npip y==1\n' > "$HOME/Projects/p/.dev"; }

fresh no-dev
dev_in_p shell >/dev/null || fail "dev shell exited $?"
runs localhost/claude-box
not_called build
passed=$((passed + 1))

fresh first-build
three
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -q '+ dnf jq' <<< "$out" || fail "change not shown: $out"
has build
has "claude-box.packages=dnf:jq npm:x pip:y==1"
grep -qF "RUN dnf -y install 'jq' npm python3-pip" "$LOG" || fail "dnf step: $(grep RUN "$LOG")"
grep -qF "RUN npm install -g 'x'" "$LOG" || fail "npm step: $(grep RUN "$LOG")"
grep -qF "RUN pip install 'y==1'" "$LOG" || fail "pip step: $(grep RUN "$LOG")"
runs localhost/claude-box-p
passed=$((passed + 1))

case=unchanged; : > "$LOG"
out=$(dev_in_p shell) || fail "dev shell exited $?"
not_called build
grep -q '\[Y/n\]' <<< "$out" && fail "asked although nothing changed: $out"
runs localhost/claude-box-p
passed=$((passed + 1))

case=changed; : > "$LOG"
echo 'dnf tree' >> "$HOME/Projects/p/.dev"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -q '+ dnf tree' <<< "$out" || fail "change not shown: $out"
not_called build
runs localhost/claude-box-p
passed=$((passed + 1))

case=base-changed; : > "$LOG"
sed -i '/tree/d' "$HOME/Projects/p/.dev"
echo base2 > "$FAKE/localhost_claude-box/id"
dev_in_p shell >/dev/null || fail "dev shell exited $?"
has build
has "claude-box.base=base2"
passed=$((passed + 1))

fresh project-drops-old     # a rebuilt project image removes the one it replaced
three
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
grep -qx rm "$LOG" && fail "removed something on the first build"
old=$(cat "$FAKE/localhost_claude-box-p/id"); : > "$LOG"
echo 'dnf tree' >> "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
removed "$old" || fail "the replaced project image $old wasn't removed"
has "claude-box.image=1"
passed=$((passed + 1))

fresh answer-no
three
echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
not_called build
runs localhost/claude-box
passed=$((passed + 1))

fresh enter-is-yes
three
out=$(echo | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF '[Y/n]' <<< "$out" || fail "no [Y/n] in: $out"
has build
runs localhost/claude-box-p
passed=$((passed + 1))

fresh no-tty
three
echo y | dev_in_p shell >/dev/null || fail "dev shell exited $?"
not_called build
runs localhost/claude-box
passed=$((passed + 1))

fresh image-name
mkdir -p "$HOME/Projects/My App" && git -C "$HOME/Projects/My App" init -q
echo 'dnf jq' > "$HOME/Projects/My App/.dev"
echo y | (cd "$HOME/Projects/My App" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
has localhost/claude-box-my-app
passed=$((passed + 1))

fresh no-base
rm -rf "$FAKE/localhost_claude-box"
echo 'dnf jq' > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
first=$(grep -n '^-t$' "$LOG" | head -1 | cut -d: -f1)
[ "$(sed -n "$((first + 1))p" "$LOG")" = localhost/claude-box ] || fail "the base wasn't built first"
has localhost/claude-box-p
passed=$((passed + 1))

fresh build-fails
three
out=$(echo y | (cd "$HOME/Projects/p" && FAKE_BUILD_STATUS=1 tty_run "$DEV" shell)) && fail "dev shell succeeded"
grep -q 'Building localhost/claude-box-p failed: check .dev' <<< "$out" || fail "no failure message: $out"
not_called run
passed=$((passed + 1))

fresh plugins-only
echo 'plugin a@b o/r' > "$HOME/Projects/p/.dev"
dev_in_p shell >/dev/null || fail "dev shell exited $?"
not_called build
runs localhost/claude-box
passed=$((passed + 1))

fresh bad-name
echo 'pip foo;rm' > "$HOME/Projects/p/.dev"
out=$(dev_in_p shell 2>&1) && fail "a name with ; was accepted"
grep -q '.dev line 1:' <<< "$out" || fail "no '.dev line 1:' in: $out"
passed=$((passed + 1))

fresh plugins-none
dev_in_p shell >/dev/null || fail "dev shell exited $?"
not_called box-plugins
passed=$((passed + 1))

fresh new-no-offer          # dev new offers nothing and writes no .dev
conf 'plugin c4m@c4-model-skill cheriftj/c4-model-skill'
printf 'y\nn\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
: > "$LOG"
out=$("$DEV" new q 2>&1) || fail "dev new exited $?"
[ ! -e "$HOME/Projects/q/.dev" ] || fail ".dev written: $(cat "$HOME/Projects/q/.dev")"
grep -q '?' <<< "$out" && fail "asked: $out"
not_called box-plugins
passed=$((passed + 1))

# second_plugin: plugin second in the clone, with a starter.
second_plugin() { mkdir -p "$CLONE/plugins/second/.claude-plugin" "$CLONE/plugins/second/starter"; echo '{"name":"second"}' > "$CLONE/plugins/second/.claude-plugin/plugin.json"; }

fresh new-skeleton          # dev new lays down the starters of the approved plugins, in the first commit
conf 'plugin workflow'
printf 'y\nn\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
"$DEV" new my.app >/dev/null 2>&1 || fail "dev new exited $?"
q="$HOME/Projects/my.app"
for f in CLAUDE.md .gitignore docs/direction/backlog.md docs/system/architecture/README.md \
         docs/system/runbook.md docs/change/.gitkeep tests/run.sh tests/check_links.py; do
    [ -f "$q/$f" ] || fail "no $f"
done
[ "$(head -n 1 "$q/CLAUDE.md")" = '# my.app' ] || fail "CLAUDE.md starts: $(head -n 1 "$q/CLAUDE.md")"
! grep -rqF '{{name}}' "$q" --exclude-dir=.git || fail "{{name}} left: $(grep -rlF '{{name}}' "$q" --exclude-dir=.git)"
grep -qx 'out/' "$q/.gitignore" || fail ".gitignore lacks out/"
[ ! -e "$q/.dev" ] || fail ".dev written: $(cat "$q/.dev")"
[ -x "$q/tests/run.sh" ] || fail "tests/run.sh isn't executable"
[ "$(git -C "$q" log --format=%s)" = 'Start my.app' ] || fail "commits: $(git -C "$q" log --oneline)"
[ -z "$(git -C "$q" status --porcelain)" ] || fail "left uncommitted: $(git -C "$q" status --porcelain)"
(cd "$q" && tests/run.sh) | tail -n 1 | grep -qx 'ALL PASSED' || fail "the new project's checks fail"
passed=$((passed + 1))

fresh new-unapproved        # a plugin added to your config but not yet approved: not laid down
conf 'identity Ann <ann@example.invalid>'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
conf 'identity Ann <ann@example.invalid>' 'plugin workflow'
"$DEV" new q >/dev/null 2>&1 || fail "dev new exited $?"
[ ! -e "$HOME/Projects/q/CLAUDE.md" ] || fail "an unapproved plugin's starter was laid down"
passed=$((passed + 1))

fresh new-starter-fails     # a starter file that can't be copied: nothing left behind
conf 'plugin workflow'
printf 'y\nn\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
chmod 000 "$HOME/.local/state/claude-box/approved/plugins/workflow/starter/tests/run.sh"
"$DEV" new q >/dev/null 2>&1 && fail "dev new passed with a starter it couldn't copy"
chmod 755 "$HOME/.local/state/claude-box/approved/plugins/workflow/starter/tests/run.sh"
[ ! -e "$HOME/Projects/q" ] || fail "a half-made project was left"
passed=$((passed + 1))

fresh new-starter-git       # a starter's .git/ or .dev: refused, nothing left behind
for bad in .git/hooks/pre-commit .dev; do
    # from ~/.claude: git can't carry a .git/ into main, a folder of yours can
    sp="$HOME/.claude/second"; rm -rf "$sp"; mkdir -p "$sp/.claude-plugin" "$(dirname "$sp/starter/$bad")"
    echo '{"name":"second"}' > "$sp/.claude-plugin/plugin.json"; echo 'echo ran' > "$sp/starter/$bad"
    conf 'plugin ~/.claude/second' "# $bad"
    printf 'y\nn\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
    out=$("$DEV" new q 2>&1) && fail "a starter's $bad was laid down"
    grep -qF "refused: second's starter has $bad" <<< "$out" || fail "no reason for $bad: $out"
    [ ! -e "$HOME/Projects/q" ] || fail "a half-made project was left ($bad)"
done
passed=$((passed + 1))

fresh new-bad-names         # a name or folder starting with ., or with .., is refused
for bad in app/.git .x ../x app/.. ./x; do
    out=$("$DEV" new "$bad" 2>&1) && fail "dev new $bad ran"
    grep -qF 'Usage: dev new' <<< "$out" || fail "no usage for $bad: $out"
done
passed=$((passed + 1))

fresh new-two-starters      # a path in two starters: the first stays, the second is said
second_plugin; echo 'second' > "$CLONE/plugins/second/starter/CLAUDE.md"; clone_commit second
conf 'plugin workflow' 'plugin second'
printf 'y\nn\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
out=$("$DEV" new q 2>&1) || fail "dev new exited $?"
[ "$(head -n 1 "$HOME/Projects/q/CLAUDE.md")" = '# q' ] || fail "the second plugin's CLAUDE.md won"
grep -qF "skipped CLAUDE.md: second's starter has it too" <<< "$out" || fail "not said: $out"
passed=$((passed + 1))

fresh new-in-group          # dev new <group folder>/<name>; another folder refused
conf 'group ~/Projects/app'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
"$DEV" new app/x >/dev/null 2>&1 || fail "dev new app/x exited $?"
[ -d "$HOME/Projects/app/x/.git" ] || fail "app/x not made"
out=$("$DEV" new other/x 2>&1) && fail "dev new other/x ran"
grep -qF 'not a group folder' <<< "$out" || fail "no reason: $out"
[ ! -e "$HOME/Projects/other" ] || fail "other/ was created"
passed=$((passed + 1))

# stage-seed itself, with a fake claude: each marketplace added once.
case=stage-seed; LOG="$tmp/stage-seed.log"; : > "$LOG"
printf '#!/usr/bin/env bash\nprintf "%%s " "$@" >> "$LOG"; echo >> "$LOG"\n' > "$tmp/bin/claude"
chmod +x "$tmp/bin/claude"
CLAUDE_CONFIG_DIR="$tmp/stage-cfg" "$REPO/core/bin/stage-seed" o/m a@m o/m b@m >/dev/null || fail "stage-seed exited $?"
[ "$(grep -c 'plugin marketplace add o/m' "$LOG")" = 1 ] || fail "marketplace not added once: $(cat "$LOG")"
grep -qx 'plugin install a@m ' "$LOG" && grep -qx 'plugin install b@m ' "$LOG" || fail "no installs: $(cat "$LOG")"
printf '#!/usr/bin/env bash\nexit 3\n' > "$tmp/bin/claude"
CLAUDE_CONFIG_DIR="$tmp/stage-cfg" "$REPO/core/bin/stage-seed" o/m a@m >/dev/null 2>&1 && fail "a failed install passed"
rm "$tmp/bin/claude"
passed=$((passed + 1))

# Ports: .dev's ports published on your laptop's 127.0.0.1 only, never
# into the image. free_port prints a port nothing listens on.
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

fresh add-port
dev_in_p add port 2718 >/dev/null || fail "dev add port exited $?"
[ "$(devfile)" = 'port 2718' ] || fail ".dev is: $(devfile)"
out=$(dev_in_p add port 27x 2>&1) && fail "dev add port 27x succeeded"
grep -q 'Not a port' <<< "$out" || fail "no 'Not a port' in: $out"
dev_in_p remove port 2718 >/dev/null || fail "dev remove port exited $?"
[ ! -e "$HOME/Projects/p/.dev" ] || fail ".dev is: $(devfile)"
passed=$((passed + 1))

fresh bad-port
for p in 0 65536 02718 x; do
    echo "port $p" > "$HOME/Projects/p/.dev"
    out=$(dev_in_p shell 2>&1) && fail "port $p was accepted"
    grep -q '.dev line 1:' <<< "$out" || fail "no '.dev line 1:' for port $p in: $out"
done
passed=$((passed + 1))

fresh port
p=$(free_port)
echo "port $p" > "$HOME/Projects/p/.dev"
dev_in_p shell >/dev/null || fail "dev shell exited $?"
has "127.0.0.1:$p:$p"
not_called build                     # a port isn't a package
runs localhost/claude-box
passed=$((passed + 1))

fresh port-with-packages
p=$(free_port)
printf 'dnf jq\nport %s\n' "$p" > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
has "claude-box.packages=dnf:jq"
has "127.0.0.1:$p:$p"
passed=$((passed + 1))

fresh port-taken
python3 -c 'import socket, sys, time
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen()
open(sys.argv[1], "w").write(str(s.getsockname()[1])); time.sleep(60)' "$tmp/held" &
holder=$!
for _ in $(seq 50); do [ -s "$tmp/held" ] && break; sleep 0.1; done
p=$(cat "$tmp/held")
echo "port $p" > "$HOME/Projects/p/.dev"
out=$(dev_in_p claude 2>&1) || fail "dev claude exited $? with port $p taken: $out"
kill "$holder"
grep -q "Port $p not published to this box" <<< "$out" || fail "no note about port $p in: $out"
hasnt "127.0.0.1:$p:$p"
has claude                           # the box still started
passed=$((passed + 1))

fresh port-not-for-plugins
p=$(free_port)
printf 'plugin a@b o/r\nport %s\n' "$p" > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
[ "$(grep -cxF -- "127.0.0.1:$p:$p" "$LOG")" = 1 ] || fail "published other than once"
awk -v x="127.0.0.1:$p:$p" '$0 == "--" { if (s && f) bad = 1; s = f = 0; next } $0 == "stage-seed" { s = 1 } $0 == x { f = 1 }
    END { exit bad }' "$LOG" || fail "published to the staging box"
passed=$((passed + 1))

# Editing dev while a box runs (it's a link into this repo): once the box
# ends, dev reads no more of the changed file.
fresh edit-while-running
cp "$DEV" "$CLONE/dev-copy"
out=$(cd "$HOME/Projects/p" && FAKE_ON_RUN="python3 -c 'p = \"$CLONE/dev-copy\"; s = open(p).read(); open(p, \"w\").write(\"#\" * 300 + \"\\n\" + s)'" \
      bash "$CLONE/dev-copy" shell 2>&1) || fail "dev exited $? after its file changed: $out"
grep -q 'syntax error' <<< "$out" && fail "read the changed file: $out"
passed=$((passed + 1))

# Scratch sessions: dev claude outside a project. scratches lists their
# folders; one_scratch sets n to the only one.
scratches() { ls -A "$HOME/.claude/scratch" 2>/dev/null; }
one_scratch() {
    n="$(scratches)"
    [[ "$n" =~ ^[a-z]+-[a-z]+$ ]] || fail "expected one scratch, got: $n"
}
# claude_args a b...: claude was started with exactly these arguments next.
claude_args() {
    local want; want="$(printf '%s\n' claude "$@")"
    awk -v w="$want" 'BEGIN { n = split(w, a, "\n") } $0 == "claude" { s = NR; i = 1 }
        s && NR >= s && NR < s + n && $0 != a[NR - s + 1] { s = 0 }
        s && NR == s + n - 1 { f = 1 } END { exit !f }' "$LOG" || fail "claude not started as: claude $*"
}

fresh scratch-new
mkdir "$HOME/Downloads"
out=$(cd "$HOME/Downloads" && "$DEV" claude 2>&1) || fail "dev claude exited $?: $out"
one_scratch
grep -qxF "Scratch session $n: come back with dev claude --scratch $n" <<< "$out" || fail "no name line: $out"
[ -z "$(ls -A "$HOME/Downloads")" ] || fail "wrote into the start folder"
has "$HOME/.claude/scratch/$n:/work/scratch-$n:z"
has "/work/scratch-$n"
has "claude-box-scratch-$n"
has "claude-box.project=$HOME/.claude/scratch/$n"
hasnt "/.git:"
hasnt --continue
claude_args --remote-control "scratch-$n"
passed=$((passed + 1))

fresh scratch-git-outside
mkdir -p "$HOME/src/r" && git -C "$HOME/src/r" init -q
(cd "$HOME/src/r" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
has "$HOME/src/r:/work/r:z"
[ -z "$(scratches)" ] || fail "made a scratch for a repo"
passed=$((passed + 1))

fresh scratch-projects-folder
(cd "$HOME/Projects" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
one_scratch
passed=$((passed + 1))

fresh scratch-home-git
git -C "$HOME" init -q
(cd "$HOME" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
one_scratch
passed=$((passed + 1))

# A folder in ~/Projects without .git is a project (refused as one), also
# through a symlinked DEV_PROJECTS.
fresh scratch-symlinked-projects
mkdir "$HOME/Projects/q" && ln -s "$HOME/Projects" "$HOME/plink"
out=$(cd "$HOME/plink/q" && DEV_PROJECTS="$HOME/plink" "$DEV" claude 2>&1) && fail "not refused: $out"
grep -q 'no .git here' <<< "$out" || fail "$out"
[ -z "$(scratches)" ] || fail "made a scratch in ~/Projects"
passed=$((passed + 1))

fresh scratch-not-project
mkdir "$HOME/Downloads"
for c in shell "add dnf jq"; do
    # shellcheck disable=SC2086  # c is a command and its words
    out=$(cd "$HOME/Downloads" && "$DEV" $c 2>&1) && fail "dev $c not refused"
    grep -qxF "Not a project: $HOME/Downloads (no .git, not in ~/Projects). For a session without one: dev claude" <<< "$out" \
        || fail "dev $c: $out"
done
not_called run
[ ! -e "$HOME/Downloads/.dev" ] || fail ".dev written"
passed=$((passed + 1))

fresh scratch-new-flag
mkdir "$HOME/Downloads"
out=$(cd "$HOME/Downloads" && "$DEV" claude --new 2>&1) && fail "not refused"
grep -qxF -- "--new is for projects; a scratch has one box." <<< "$out" || fail "$out"
[ -z "$(scratches)" ] || fail "made a scratch"
passed=$((passed + 1))

# mkscratch name date [topic]: a scratch whose notes.md (with "# topic", or
# no heading) was last changed at date.
mkscratch() {
    local d; d="$HOME/.claude/scratch/$1"
    mkdir -p "$d"
    if [ $# -ge 3 ]; then printf '# %s\nfound\n' "$3" > "$d/notes.md"; else echo notes > "$d/notes.md"; fi
    touch -d "$2" "$d/notes.md"
}
dev_in_dl() { mkdir -p "$HOME/Downloads"; (cd "$HOME/Downloads" && "$DEV" "$@"); }

fresh scratch-continue
mkscratch brave-otter '2026-10-20 10:00'
dev_in_dl claude --scratch brave-otter --model x >/dev/null 2>&1 || fail "dev claude exited $?"
claude_args --remote-control scratch-brave-otter --continue --model x
has claude-box-scratch-brave-otter
[ "$(scratches)" = brave-otter ] || fail "made another scratch: $(scratches)"
passed=$((passed + 1))

# A running box with no Claude session left in it (e.g. one still ending):
# join it and carry on with the last conversation.
fresh scratch-join-idle
mkscratch brave-otter '2026-10-20 10:00'
echo "true $HOME/.claude/scratch/brave-otter" > "$FAKE/box"
out=$(dev_in_dl claude --scratch brave-otter 2>&1) || fail "dev claude exited $?: $out"
not_called run
claude_args --remote-control scratch-brave-otter --continue
! grep -q 'has a session running' <<< "$out" || fail "$out"
passed=$((passed + 1))

# A Claude session still runs in it: a new conversation, and dev says so.
fresh scratch-join-live
mkscratch brave-otter '2026-10-20 10:00'
echo "true $HOME/.claude/scratch/brave-otter" > "$FAKE/box"
out=$(FAKE_LIVE=0 dev_in_dl claude --scratch brave-otter 2>&1) || fail "dev claude exited $?: $out"
not_called run
hasnt --continue
grep -qxF "brave-otter has a session running: this is a new conversation (add --continue to resume the last one)" <<< "$out" \
    || fail "$out"
passed=$((passed + 1))

fresh scratch-bad-name
for a in ../x "a prompt"; do
    out=$(dev_in_dl claude --scratch "$a" 2>&1) && fail "--scratch $a not refused"
    grep -qxF "Not a scratch name: $a (dev scratch lists them)" <<< "$out" || fail "$out"
done
out=$(dev_in_dl claude --scratch calm-fox 2>&1) && fail "unknown scratch not refused"
grep -qxF "No scratch session calm-fox (dev scratch lists them)" <<< "$out" || fail "$out"
not_called run
[ -z "$(scratches)" ] || fail "made a scratch"
passed=$((passed + 1))

fresh scratch-ignores-dev
mkscratch brave-otter '2026-10-20 10:00'
printf 'dnf jq\nport 8080\n' > "$HOME/.claude/scratch/brave-otter/.dev"
dev_in_dl claude --scratch brave-otter >/dev/null 2>&1 || fail "dev claude exited $?"
not_called build; hasnt box-plugins; hasnt 8080
has localhost/claude-box
passed=$((passed + 1))

fresh scratch-list
mkscratch brave-otter '2026-10-20 10:00' 'Wi-Fi drops'
mkscratch calm-fox '2026-10-22 09:30'
out=$(dev_in_dl scratch) || fail "dev scratch exited $?"
[ "$out" = "$(printf ' 1  calm-fox  2026-10-22 09:30\n 2  brave-otter  2026-10-20 10:00  Wi-Fi drops')" ] \
    || fail "list is: $out"
passed=$((passed + 1))

fresh scratch-list-empty
out=$(dev_in_dl scratch) || fail "dev scratch exited $?"
[ "$out" = "No scratch sessions." ] || fail "$out"
passed=$((passed + 1))

fresh scratch-pick
mkscratch brave-otter '2026-10-20 10:00' 'Wi-Fi drops'
mkscratch calm-fox '2026-10-22 09:30'
printf '2\n' | (cd "$HOME" && tty_run "$DEV" claude --scratch) >/dev/null || fail "dev claude exited $?"
has claude-box-scratch-brave-otter
has --continue
passed=$((passed + 1))

fresh scratch-pick-cancel
mkscratch brave-otter '2026-10-20 10:00'
for input in '\n' '9\n' 'x\n'; do
    # shellcheck disable=SC2059  # the input is a format: \n
    out=$(printf "$input" | (cd "$HOME" && tty_run "$DEV" claude --scratch) 2>&1) && fail "$input: not cancelled"
    grep -q 'Cancelled\.' <<< "$out" || fail "$input: $out"
done
not_called run
passed=$((passed + 1))

fresh scratch-pick-no-tty
mkscratch brave-otter '2026-10-20 10:00'
out=$(dev_in_dl claude --scratch 2>&1) && fail "picked without a terminal"
grep -qxF "No terminal to pick on: dev claude --scratch <name> (dev scratch lists them)" <<< "$out" || fail "$out"
rm -r "$HOME/.claude/scratch/brave-otter"
out=$(printf '\n' | (cd "$HOME" && tty_run "$DEV" claude --scratch) 2>&1) && fail "picked from none"
grep -q 'No scratch sessions\.' <<< "$out" || fail "$out"
not_called run
passed=$((passed + 1))

fresh scratch-rm
mkscratch brave-otter '2026-10-20 10:00'
conv="$HOME/.claude/projects/-work-scratch-brave-otter"; mkdir -p "$conv"
out=$(printf 'y\n' | (cd "$HOME" && tty_run "$DEV" scratch --rm brave-otter) 2>&1) || fail "rc $?: $out"
grep -q 'Removes:' <<< "$out" && grep -qF "  the scratch:        $HOME/.claude/scratch/brave-otter" <<< "$out" \
    && grep -qF "  its conversations:  $conv  (Claude Code's own store, not a project)" <<< "$out" \
    || fail "folders not named: $out"
[ ! -e "$HOME/.claude/scratch/brave-otter" ] && [ ! -e "$conv" ] || fail "not removed"
passed=$((passed + 1))

fresh scratch-rm-declined
mkscratch brave-otter '2026-10-20 10:00'
conv="$HOME/.claude/projects/-work-scratch-brave-otter"; mkdir -p "$conv"
out=$(printf '\n' | (cd "$HOME" && tty_run "$DEV" scratch --rm brave-otter) 2>&1) && fail "not declined"
grep -q 'Cancelled\.' <<< "$out" || fail "$out"
[ -d "$HOME/.claude/scratch/brave-otter" ] && [ -d "$conv" ] || fail "removed"
passed=$((passed + 1))

fresh scratch-rm-running
mkscratch brave-otter '2026-10-20 10:00'
echo "true $HOME/.claude/scratch/brave-otter" > "$FAKE/box"
out=$(dev_in_dl scratch --rm brave-otter 2>&1) && fail "not refused"
grep -qxF "brave-otter's box is running: end its sessions first." <<< "$out" || fail "$out"
[ -d "$HOME/.claude/scratch/brave-otter" ] || fail "removed"
passed=$((passed + 1))

fresh scratch-rm-unknown
out=$(dev_in_dl scratch --rm calm-fox 2>&1) && fail "not refused"
grep -qxF "No scratch session calm-fox (dev scratch lists them)" <<< "$out" || fail "$out"
passed=$((passed + 1))

fresh scratch-run
mkscratch brave-otter '2026-10-20 10:00'
s="$HOME/.claude/scratch/brave-otter"; mkdir -p "$s/out"
printf '# t\n> where\nlocal pwd\n' > "$s/out/actions.txt"
out=$(echo | dev_in_dl run --scratch brave-otter 2>&1) || fail "rc $?: $out"
grep -qxF "$(cd -P "$s" && pwd)" "$s/out/actions.log" || fail "not run in the scratch: $(cat "$s/out/actions.log")"
passed=$((passed + 1))

fresh scratch-run-file
mkscratch brave-otter '2026-10-20 10:00'
s="$HOME/.claude/scratch/brave-otter"
printf '# t\n> where\nlocal pwd\n' > "$s/other.txt"
out=$(echo | dev_in_dl run --scratch brave-otter other.txt 2>&1) || fail "rc $?: $out"
grep -qxF "$(cd -P "$s" && pwd)" "$s/out/actions.log" || fail "not run in the scratch: $out"
passed=$((passed + 1))

# Every box can write ~/.claude/scratch: a link there mustn't point dev at
# another of your folders, to mount, list, create in or delete.
fresh scratch-link-entry
mkdir -p "$HOME/.claude/scratch" && ln -s ../.. "$HOME/.claude/scratch/evil-link"
out=$(dev_in_dl claude --scratch evil-link 2>&1) && fail "linked scratch entered"
grep -qxF "No scratch session evil-link (dev scratch lists them)" <<< "$out" || fail "$out"
out=$(echo | dev_in_dl run --scratch evil-link 2>&1) && fail "ran in a linked scratch"
out=$(printf 'y\n' | (cd "$HOME" && tty_run "$DEV" scratch --rm evil-link) 2>&1) && fail "rm through a link"
[ -L "$HOME/.claude/scratch/evil-link" ] && [ -d "$HOME/Projects" ] || fail "something was removed"
[ "$(dev_in_dl scratch)" = "No scratch sessions." ] || fail "a link listed: $(dev_in_dl scratch)"
not_called run
passed=$((passed + 1))

fresh scratch-link-root
mkdir -p "$HOME/.claude" "$HOME/my-notes" && ln -s .. "$HOME/.claude/scratch"
for c in scratch "scratch --rm my-notes" claude "claude --scratch my-notes"; do
    # shellcheck disable=SC2086  # c is a command and its words
    out=$(printf 'y\n' | (cd "$HOME/my-notes" && tty_run "$DEV" $c) 2>&1) && fail "dev $c: not refused: $out"
    grep -qF "$HOME/.claude/scratch is a link: refused" <<< "$out" || fail "dev $c: $out"
done
[ -d "$HOME/my-notes" ] || fail "removed through the link"
[ "$(ls -A "$HOME" | sort | paste -sd " ")" = ".claude Projects my-notes" ] || fail "made a folder in HOME: $(ls -A "$HOME")"
not_called run
passed=$((passed + 1))

fresh scratch-list-unreadable
mkscratch brave-otter '2026-10-20 10:00'
mkscratch calm-fox '2026-10-22 09:30'
mkdir "$HOME/.claude/scratch/calm-fox/locked" && chmod 000 "$HOME/.claude/scratch/calm-fox/locked"
out=$(dev_in_dl scratch 2>"$tmp/err"); rc=$?
chmod 700 "$HOME/.claude/scratch/calm-fox/locked"
[ "$rc" = 0 ] && [ "$(wc -l <<< "$out")" = 2 ] && grep -q '^ 1  calm-fox' <<< "$out" \
    && grep -q '^ 2  brave-otter' <<< "$out" || fail "rc $rc: $out"
[ ! -s "$tmp/err" ] || fail "stderr: $(cat "$tmp/err")"
passed=$((passed + 1))

fresh scratch-list-odd-notes
mkscratch brave-otter '2026-10-20 10:00'
rm "$HOME/.claude/scratch/brave-otter/notes.md"
mkdir -p "$HOME/.claude/scratch/calm-fox" && mkfifo "$HOME/.claude/scratch/calm-fox/notes.md"
mkdir -p "$HOME/.claude/scratch/dry-elk" && printf '# a\033[31mb\n' > "$HOME/.claude/scratch/dry-elk/notes.md"
out=$(cd "$HOME" && timeout 10 "$DEV" scratch 2>&1) || fail "rc $?: $out"
[ "$(wc -l <<< "$out")" = 3 ] || fail "not three: $out"
! grep -q $'\033' <<< "$out" || fail "escape sequence passed through: $(cat -v <<< "$out")"
grep -q 'dry-elk .* a\[31mb$' <<< "$out" || fail "topic: $(cat -v <<< "$out")"
passed=$((passed + 1))

fresh scratch-new-flag-orders
mkscratch brave-otter '2026-10-20 10:00'
out=$(dev_in_dl claude --scratch brave-otter --new 2>&1) && fail "--new after --scratch passed on"
grep -qxF -- "--new is for projects; a scratch has one box." <<< "$out" || fail "$out"
out=$(dev_in_p claude --new --scratch brave-otter 2>&1) && fail "--scratch after --new passed on"
grep -qxF -- "--new is for projects; a scratch has one box." <<< "$out" || fail "$out"
not_called run
passed=$((passed + 1))

fresh remote-control
dev_in_p claude --resume >/dev/null 2>&1 || fail "dev claude exited $?"
# claude, then Remote Control under the folder's name, then your arguments.
awk '/^claude$/ { c = NR } c && NR == c + 1 && $0 != "--remote-control" { exit 1 }
     c && NR == c + 2 && $0 != "p" { exit 1 } c && NR == c + 3 { exit $0 != "--resume" }
     END { if (!c) exit 1 }' "$LOG" || fail "claude not started as: claude --remote-control p --resume"
passed=$((passed + 1))

# Groups. group_fixture <config lines>: ~/Projects/app/{a,b,c d} as repos,
# the config approved. gpath <dir>: the groups file dev writes for that
# project, named by its folder and a hash of its real path. gfile <dir>: it.
group_fixture() {
    local d
    for d in a b 'c d'; do mkdir -p "$HOME/Projects/app/$d" && git -C "$HOME/Projects/app/$d" init -q; done
    conf "$@"
    echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
    : > "$LOG"
}
gpath() {
    local real; real="$(cd "$1" && pwd -P)"
    printf '%s/.local/state/claude-box/groups/%s-%s' "$HOME" "${real##*/}" "$(printf '%s' "$real" | sha256sum | cut -c1-16)"
}
gfile() { cat "$(gpath "$1")"; }
in_a() { (cd "$HOME/Projects/app/a" && "$DEV" "$@"); }

fresh group-folder          # a folder's repos are one group; remote members; the trust line
group_fixture 'group ~/Projects/app/' 'remote app phone' 'autotake group'
out=$(in_a shell 2>&1) || fail "dev shell exited $?"
has "$(gpath "$HOME/Projects/app/a"):/etc/claude-box/groups:ro,z"
[ "$(gfile "$HOME/Projects/app/a")" = "$(printf 'group app\nmember b /projects/app/b\nmember phone remote\nautotake group')" ] \
    || fail "file: $(gfile "$HOME/Projects/app/a")"
grep -qF "c d: not a member" <<< "$out" || fail "the folder whose name isn't a session's isn't named: $out"
passed=$((passed + 1))

fresh group-no-autotake     # without autotake group: members, no trust line
group_fixture 'group ~/Projects/app'
in_a shell >/dev/null 2>&1 || fail "dev shell exited $?"
gfile "$HOME/Projects/app/a" | grep -q autotake && fail "autotake without the line"
gfile "$HOME/Projects/app/a" | grep -qx 'member b /projects/app/b' || fail "file: $(gfile "$HOME/Projects/app/a")"
case=group-folder-member-gone
rm -rf "$HOME/Projects/app/b"
in_a shell >/dev/null 2>&1 || fail "dev shell exited $?"
gfile "$HOME/Projects/app/a" | grep -q 'member b ' && fail "b still a member after its folder went"
passed=$((passed + 1))

fresh group-same-name       # two projects named app: one file each, never shared
group_fixture 'group ~/Projects/app'
mkdir -p "$HOME/Projects/x/a" && git -C "$HOME/Projects/x/a" init -q
in_a shell >/dev/null 2>&1 || fail "dev shell exited $?"
(cd "$HOME/Projects/x/a" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell in x/a exited $?"
[ "$(gpath "$HOME/Projects/app/a")" != "$(gpath "$HOME/Projects/x/a")" ] || fail "one file for both"
gfile "$HOME/Projects/app/a" | grep -qx 'group app' || fail "x/a's start changed app/a's file"
passed=$((passed + 1))

fresh group-outside-projects # a group folder outside your projects folder: refused, named
mkdir -p "$tmp/elsewhere/app"
conf "group $tmp/elsewhere/app"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) && fail "a group folder outside projects accepted"
grep -qF 'not in your projects folder' <<< "$out" || fail "no reason: $out"
passed=$((passed + 1))

fresh group-in-a-repo       # a group folder inside a project: the box could add members
mkdir -p "$HOME/Projects/mono/mods" && git -C "$HOME/Projects/mono" init -q
conf 'group ~/Projects/mono/mods'
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) && fail "a group folder in a repo accepted"
grep -qF 'inside a repo' <<< "$out" || fail "no reason: $out"
passed=$((passed + 1))

fresh group-folder-refused  # the group folder itself is no project
group_fixture 'group ~/Projects/app'
out=$(cd "$HOME/Projects/app" && "$DEV" shell 2>&1) && fail "the group folder started a box"
grep -qF 'is a group folder' <<< "$out" || fail "no reason: $out"
not_called run
passed=$((passed + 1))

fresh group-name-yes        # p joins app by its .dev, after your yes
group_fixture 'group ~/Projects/app'
echo 'group app' > "$HOME/Projects/p/.dev"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF "[y/N]" <<< "$out" || fail "the question doesn't default to no: $out"
grep -qF "app's members will take this project's messages as your prompt" <<< "$out" || fail "the question hides what changes: $out"
grep -qx "app $HOME/Projects/p" "$HOME/.local/state/claude-box/group-yes" || fail "the yes isn't kept"
in_a shell >/dev/null 2>&1 || fail "dev shell in a exited $?"
gfile "$HOME/Projects/app/a" | grep -qx 'member p /projects/p' || fail "p not a member: $(gfile "$HOME/Projects/app/a")"
case=group-member-gone      # its line gone: no member, the kept yes ignored
rm "$HOME/Projects/p/.dev"
in_a shell >/dev/null 2>&1 || fail "dev shell in a exited $?"
gfile "$HOME/Projects/app/a" | grep -q 'member p ' && fail "p still a member without its line"
passed=$((passed + 1))

fresh group-name-no         # Enter, no, or no terminal: not counted, said
group_fixture 'group ~/Projects/app'
echo 'group app' > "$HOME/Projects/p/.dev"
out=$(echo | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF 'Not in group app' <<< "$out" || fail "Enter alone: doesn't say so: $out"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF 'Not in group app' <<< "$out" || fail "doesn't say so: $out"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?"
grep -qF 'Not in group app' <<< "$out" || fail "no terminal: doesn't say so: $out"
[ ! -s "$HOME/.local/state/claude-box/group-yes" ] || fail "a yes was kept"
hasnt /etc/claude-box/groups
passed=$((passed + 1))

fresh group-name-outside    # a project outside your projects folder can't join by .dev
group_fixture 'group ~/Projects/app'
mkdir -p "$tmp/out-$case" && git -C "$tmp/out-$case" init -q && echo 'group app' > "$tmp/out-$case/.dev"
out=$(echo y | (cd "$tmp/out-$case" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF 'only projects in your projects folder' <<< "$out" || fail "no reason: $out"
[ ! -s "$HOME/.local/state/claude-box/group-yes" ] || fail "a yes was kept"
passed=$((passed + 1))

fresh group-two             # a folder member whose .dev names another group: refused
group_fixture 'group ~/Projects/app'
echo 'group other' > "$HOME/Projects/app/a/.dev"
out=$(cd "$HOME/Projects/app/a" && echo y | tty_run "$DEV" shell 2>&1) && fail "two groups accepted"
grep -qF 'one group per project' <<< "$out" || fail "no reason: $out"
passed=$((passed + 1))

fresh group-none            # no group: no file, no mount
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
hasnt /etc/claude-box/groups
passed=$((passed + 1))

fresh group-scratch         # a scratch is in no group
group_fixture 'group ~/Projects/app' 'autotake group'
(cd "$tmp" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude (scratch) exited $?"
hasnt /etc/claude-box/groups
passed=$((passed + 1))

# Host facts: at every box start dev writes the laptop's OS, shell and
# which of a fixed list of commands it has, mounted read-only (spec D11).
HOST_LIST="git gh podman ssh rsync flatpak rpm-ostree dnf brew toolbox systemctl sudo python3 curl jq"
hostfile="$tmp/home host-facts/.local/state/claude-box/host"

fresh host-facts            # the file, its four lines, and its mount
mkdir -p "$tmp/hostbin"; printf '#!/bin/sh\n' > "$tmp/hostbin/brew"; chmod +x "$tmp/hostbin/brew"
(export SHELL=/bin/bash PATH="$tmp/hostbin:$PATH"; dev_in_p shell) >/dev/null || fail "dev shell exited $?"
has "$hostfile:/etc/claude-box/host:ro,z"
# shellcheck source=/dev/null
[ "$(sed -n 1p "$hostfile")" = "os $(. /etc/os-release && echo "$PRETTY_NAME")" ] || fail "line 1: $(sed -n 1p "$hostfile")"
[ "$(sed -n 2p "$hostfile")" = "shell bash" ] || fail "line 2: $(sed -n 2p "$hostfile")"
hasl=$(sed -n 's/^has//p' "$hostfile"); lacksl=$(sed -n 's/^lacks//p' "$hostfile")
for t in $HOST_LIST; do
    n=$(printf '%s\n' $hasl $lacksl | grep -cx -- "$t")
    [ "$n" = 1 ] || fail "$t appears $n times in has and lacks"
done
[ "$(printf '%s\n' $hasl $lacksl | wc -l)" = "$(wc -w <<< "$HOST_LIST")" ] || fail "has/lacks hold other names: $hasl /$lacksl"
grep -qw git <<< "$hasl" || fail "git isn't in has: $hasl"
grep -qw brew <<< "$hasl" || fail "the fake brew isn't in has: $hasl"
passed=$((passed + 1))

fresh host-facts-scratch    # a scratch's box gets the host file too
(cd "$HOME" && "$DEV" claude) >/dev/null 2>&1 || fail "dev claude exited $?"
has "$HOME/.local/state/claude-box/host:/etc/claude-box/host:ro,z"
passed=$((passed + 1))

case=host-facts-os          # no os-release: os unknown; a quoted PRETTY_NAME: without its quotes
facts() { bash -c '. "$1/core/lib/mounts.sh"; host_facts "$2" "$3"' _ "$CLONE" "$tmp/facts" "$1"; }
facts "$tmp/no-such-os-release" || fail "host_facts exited $?"
[ "$(sed -n 1p "$tmp/facts")" = "os unknown" ] || fail "missing file: $(sed -n 1p "$tmp/facts")"
echo 'PRETTY_NAME="Fedora Linux 44 (Workstation Edition)"' > "$tmp/os-release"
facts "$tmp/os-release" || fail "host_facts exited $?"
[ "$(sed -n 1p "$tmp/facts")" = "os Fedora Linux 44 (Workstation Edition)" ] || fail "quoted: $(sed -n 1p "$tmp/facts")"
passed=$((passed + 1))

# project_sources: project p's .dev names a plugin folder (with rules/) and a rules file of yours.
pa_dir() { printf '%s' "$HOME/.local/state/claude-box/projects/p-$(printf '%s' "$HOME/Projects/p" | sha256sum | cut -c1-16)/approved"; }
project_sources() {
    plugin_dir pp; mkdir -p "$HOME/.claude/pp/rules"; echo pr > "$HOME/.claude/pp/rules/a.md"; echo Old. > "$HOME/.claude/pr.md"
    printf 'plugin ~/.claude/pp\nrules ~/.claude/pr.md\n' > "$HOME/Projects/p/.dev"
}

fresh project-plugin-approved # a project's plugin and rules: shown, approved, built into its image, mounted
project_sources
out=$(printf 'y\ny\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) || fail "dev shell exited $?: $out"
grep -qF "This project's .dev" <<< "$out" || fail "not shown: $out"
grep -qxF 'COPY plugins/pp /usr/local/share/claude-box/plugins/pp' "$LOG" || fail "the plugin isn't in the project image"
grep -qxF 'ENV CLAUDE_CODE_PLUGIN_DIRS=${CLAUDE_CODE_PLUGIN_DIRS}:/usr/local/share/claude-box/plugins/pp' "$LOG" \
    || fail "the plugin isn't loaded"
has "$(pa_dir)/home/.claude/pp/rules:/home/claude/.claude/rules/pp:ro,z"
has "$(pa_dir)/home/.claude/pr.md:/home/claude/.claude/rules/files/pr.md:ro,z"
runs localhost/claude-box-p
case=project-plugin-again; rm -f "$FAKE/box"; : > "$LOG"     # unchanged: nothing asked, nothing built
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
not_called build
grep -qF 'differs' <<< "$out" && fail "asked again: $out"
runs localhost/claude-box-p
passed=$((passed + 1))

fresh project-plugin-no     # no, or no terminal: nothing of it built or mounted, the box starts
project_sources
for how in n none; do
    rm -f "$FAKE/box"; : > "$LOG"
    if [ "$how" = n ]; then out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1)
    else out=$(dev_in_p shell 2>&1); fi || fail "($how) dev shell exited $?: $out"
    hasnt 'COPY plugins/pp'; hasnt "/claude-box/projects/"
    runs localhost/claude-box
done
passed=$((passed + 1))

fresh project-plugin-change # a changed rules file: shown; the approved copy serves until your yes
project_sources
printf 'y\ny\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
echo New. > "$HOME/.claude/pr.md"; rm -f "$FAKE/box"; : > "$LOG"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
grep -qF '+New.' <<< "$out" || fail "the change isn't shown: $out"
grep -qx 'Old.' "$(pa_dir)/home/.claude/pr.md" || fail "the approved copy changed without a yes"
has "$(pa_dir)/home/.claude/pr.md:/home/claude/.claude/rules/files/pr.md:ro,z"
rm -f "$FAKE/box"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
grep -qx 'New.' "$(pa_dir)/home/.claude/pr.md" || fail "not approved"
passed=$((passed + 1))

fresh project-plugin-other  # another project doesn't get it
project_sources
printf 'y\ny\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
mkdir -p "$HOME/Projects/q" && git -C "$HOME/Projects/q" init -q; : > "$LOG"
(cd "$HOME/Projects/q" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell in q exited $?"
hasnt "/claude-box/projects/"; hasnt 'COPY plugins/pp'
passed=$((passed + 1))

fresh project-both-levels   # one plugin at both levels: refused at the project's line
conf 'plugin workflow'; rm -rf "$tmp/up"; up_repo obra/superpowers-marketplace
echo y | FAKE_STAGE='superpowers@superpowers-marketplace=5' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving exited $?"
echo 'plugin workflow' > "$HOME/Projects/p/.dev"; rm -f "$FAKE/box"; : > "$LOG"
out=$(dev_in_p shell 2>&1) && fail "accepted at both levels: $out"
# shellcheck disable=SC2088  # the literal text dev prints
grep -qF '.dev line 1:' <<< "$out" && grep -qF '~/.claude/.dev' <<< "$out" || fail "doesn't say where: $out"
not_called run
passed=$((passed + 1))

fresh project-approved-broken # a project's approved copy dev can't read: counts as none
project_sources
printf 'y\ny\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
echo 'bogus x' > "$(pa_dir)/.dev"; rm -f "$FAKE/box"; : > "$LOG"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?: $out"
hasnt "/claude-box/projects/"
grep -qF "without this project's plugin and rules lines" <<< "$out" || fail "doesn't say so: $out"
rm -f "$FAKE/box"; : > "$LOG"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
has "$(pa_dir)/home/.claude/pr.md:/home/claude/.claude/rules/files/pr.md:ro,z"
passed=$((passed + 1))

fresh project-dup-names     # two project lines with one name: refused at the second, before anything is approved
mkdir -p "$HOME/.claude/x"; echo a > "$HOME/.claude/CLAUDE.md"; echo b > "$HOME/.claude/x/CLAUDE.md"
printf 'rules ~/.claude/CLAUDE.md\nrules ~/.claude/x/CLAUDE.md\n' > "$HOME/Projects/p/.dev"
out=$(echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) 2>&1) && fail "accepted two rules files of one name: $out"
grep -qF '.dev line 2:' <<< "$out" || fail "not refused at line 2: $out"
not_called run
passed=$((passed + 1))

fresh project-add-unquoted  # dev add rules ~/.claude/r.md as typed (the shell expands ~): written as ~/, the box starts
mkdir -p "$HOME/.claude"; echo r > "$HOME/.claude/r.md"
dev_in_p add rules ~/.claude/r.md >/dev/null || fail "dev add rules exited $?"
# shellcheck disable=SC2088  # the literal ~ is what .dev holds
grep -qxF 'rules ~/.claude/r.md' "$HOME/Projects/p/.dev" || fail ".dev: $(cat "$HOME/Projects/p/.dev")"
out=$(dev_in_p add rules /etc/passwd 2>&1) && fail "dev add wrote a line dev can't read: $out"
grep -qxF 'rules /etc/passwd' "$HOME/Projects/p/.dev" && fail "the bad line was written"
dev_in_p shell >/dev/null 2>&1 || fail "the project doesn't start any more"
passed=$((passed + 1))

fresh project-same-name     # two projects of one folder name: each has its own approved copy
project_sources
printf 'y\ny\n' | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null 2>&1 || fail "approving exited $?"
mkdir -p "$HOME/Projects/other/p" && git -C "$HOME/Projects/other/p" init -q; rm -f "$FAKE/box"; : > "$LOG"
cp "$HOME/Projects/p/.dev" "$HOME/Projects/other/p/.dev"     # the same lines, never approved for other/p
(cd "$HOME/Projects/other/p" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell in other/p exited $?"
hasnt 'rules/files/pr.md'; hasnt 'rules/pp:'
passed=$((passed + 1))

C4='plugin c4m@c4-model-skill cheriftj/c4-model-skill'
fresh seed-stage            # a staged seed: its plugins read back; the box saw only the seed
conf "$C4"
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4" || fail "staging failed"
[ "$(run_seed seed_plugins "$tmp/s-$case")" = "c4m@c4-model-skill 1.0" ] || fail "plugins: $(run_seed seed_plugins "$tmp/s-$case")"
grep -qxF "$C4" "$tmp/s-$case/claude-box-lines" || fail "the lines aren't recorded"
has stage-seed; has cheriftj/c4-model-skill; has c4m@c4-model-skill
hasnt "/home/claude/.claude:"; hasnt "/work/"
passed=$((passed + 1))

fresh seed-stage-empty      # exit 0 but the plugin isn't there: failed
FAKE_STAGE='' run_seed stage_seed "$tmp/s-$case" "$C4" 2>/dev/null && fail "an empty staging passed"
FAKE_STAGE='x@y=1' run_seed stage_seed "$tmp/s2-$case" "$C4" 2>/dev/null && fail "a staging without the line's plugin passed"
FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_STATUS=1 run_seed stage_seed "$tmp/s3-$case" "$C4" 2>/dev/null && fail "a failed box passed"
passed=$((passed + 1))

fresh seed-lines-dedupe     # a line that is also a folder plugin's dependency: once
conf 'plugin workflow' 'plugin superpowers@superpowers-marketplace obra/superpowers-marketplace' "$C4"
run_seed snapshot "$tmp/snap-$case" || fail "snapshot failed"
out="$(run_seed seed_lines "$tmp/snap-$case")"
[ "$(grep -c superpowers@ <<< "$out")" = 1 ] || fail "not once: $out"
grep -qxF "$C4" <<< "$out" || fail "c4m missing: $out"
[ "$(sort <<< "$out")" = "$out" ] || fail "not sorted: $out"
passed=$((passed + 1))

fresh seed-changes          # same files: nothing; other files or version: ~; new: +; gone: -
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/a-$case" "$C4"
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/b-$case" "$C4"
[ -z "$(run_seed seed_changes "$tmp/a-$case" "$tmp/b-$case")" ] || fail "same seeds differ"
[ "$(run_seed seed_digest "$tmp/a-$case")" = "$(run_seed seed_digest "$tmp/b-$case")" ] || fail "same seeds, other digests"
FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_BODY=y run_seed stage_seed "$tmp/c-$case" "$C4"
[ "$(run_seed seed_changes "$tmp/a-$case" "$tmp/c-$case")" = "~ c4m@c4-model-skill 1.0 -> 1.0" ] || fail "file change: $(run_seed seed_changes "$tmp/a-$case" "$tmp/c-$case")"
[ "$(run_seed seed_digest "$tmp/a-$case")" != "$(run_seed seed_digest "$tmp/c-$case")" ] || fail "other files, same digest"
FAKE_STAGE='c4m@c4-model-skill=1.0 x@y=2' run_seed stage_seed "$tmp/d-$case" "$C4"
grep -qxF '+ x@y 2' <(run_seed seed_changes "$tmp/a-$case" "$tmp/d-$case") || fail "new plugin not shown"
grep -qxF -- '- x@y' <(run_seed seed_changes "$tmp/d-$case" "$tmp/a-$case") || fail "gone plugin not shown"
[ "$(run_seed seed_enable_json "$tmp/d-$case")" = '{"enabledPlugins": {"c4m@c4-model-skill": true, "x@y": true}}' ] || fail "enable json: $(run_seed seed_enable_json "$tmp/d-$case")"
passed=$((passed + 1))

fresh seed-check-same       # no new commit upstream: not moved (1)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4" || fail "staging failed"
grep -qF "${SEED_GIT_BASE}cheriftj/c4-model-skill HEAD " "$tmp/s-$case/claude-box-heads" || fail "heads: $(cat "$tmp/s-$case/claude-box-heads")"
run_seed seed_moved "$tmp/s-$case"; [ $? = 1 ] || fail "moved without a commit"
passed=$((passed + 1))

case=seed-check-moved       # a commit in the marketplace repo: moved (0)
up_commit cheriftj/c4-model-skill
run_seed seed_moved "$tmp/s-seed-check-same"; [ $? = 0 ] || fail "a new commit not seen"
passed=$((passed + 1))

fresh seed-check-plugin     # a commit in the plugin's own repo (a url entry): moved
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; up_repo o/plug
FAKE_MARKET_JSON="{\"plugins\": [{\"name\": \"c4m\", \"source\": {\"source\": \"url\", \"url\": \"${SEED_GIT_BASE}o/plug\"}}]}" \
    FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4" || fail "staging failed"
grep -qF "${SEED_GIT_BASE}o/plug HEAD " "$tmp/s-$case/claude-box-heads" || fail "the plugin's repo isn't recorded"
up_commit o/plug
run_seed seed_moved "$tmp/s-$case"; [ $? = 0 ] || fail "the plugin's new commit not seen"
passed=$((passed + 1))

fresh seed-check-pinned     # an entry with a sha: its repo isn't checked; a github entry is
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill
FAKE_MARKET_JSON='{"plugins": [{"name": "c4m", "source": {"source": "url", "url": "https://example.invalid/p.git", "sha": "abc"}}, {"name": "gh", "source": {"source": "github", "repo": "o/gh", "ref": "main"}}]}' \
    FAKE_STAGE='c4m@c4-model-skill=1.0 gh@c4-model-skill=1' run_seed stage_seed "$tmp/s-$case" "$C4" 2>/dev/null
out="$(run_seed seed_sources "$tmp/s-$case")"
grep -qF example.invalid <<< "$out" && fail "a pinned entry is checked: $out"
grep -qxF "${SEED_GIT_BASE}o/gh main" <<< "$out" || fail "the github entry isn't checked: $out"
passed=$((passed + 1))

fresh seed-check-offline    # a source that can't be reached: 2, one line naming it
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4"
rm -rf "$tmp/up"
out="$(run_seed seed_moved "$tmp/s-$case" 2>&1)"; rc=$?
[ "$rc" = 2 ] || fail "offline gave $rc"
grep -qF cheriftj/c4-model-skill <<< "$out" || fail "the source isn't named: $out"
passed=$((passed + 1))

fresh seed-check-timeout    # a check that hangs ends after SEED_TIMEOUT: 2
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill
FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4"
mkdir -p "$tmp/slow"; printf '#!/bin/sh\nsleep 30\n' > "$tmp/slow/git"; chmod +x "$tmp/slow/git"
t0=$SECONDS; PATH="$tmp/slow:$PATH" SEED_TIMEOUT=2 run_seed seed_moved "$tmp/s-$case" 2>/dev/null; rc=$?
[ "$rc" = 2 ] || fail "a hanging check gave $rc"
[ $((SECONDS - t0)) -lt 10 ] || fail "took $((SECONDS - t0))s"
grep -qF 'timeout "${SEED_TIMEOUT:-10}"' "$CLONE/core/lib/seed.sh" || fail "the default isn't 10 seconds"
passed=$((passed + 1))

STATE_SEED="approved/seed"     # under ~/.local/state/claude-box
seed_f() { cat "$HOME/.local/state/claude-box/$STATE_SEED/cache/c4-model-skill/c4m/1.0/f"; }
staged() { grep -qxF 'CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed' "$LOG"; }

fresh seed-layer            # a marketplace line: staged, shown with the .dev change, one question, built in
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
out=$(echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
[ "$(grep -c 'Apply it?' <<< "$out")" = 1 ] || fail "not one question: $out"
grep -qF '+ c4m@c4-model-skill 1.0' <<< "$out" || fail "plugin not shown: $out"
[ -f "$FAKE/ctx/seed/installed_plugins.json" ] || fail "seed not in the build context"
has 'COPY seed /usr/local/share/claude-box/seed'
has 'COPY claude-box-plugins.json /etc/claude-code/managed-settings.d/'
has 'ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed'
grep -qF '"c4m@c4-model-skill": true' "$FAKE/ctx/claude-box-plugins.json" || fail "not switched on"
has 'COPY known_marketplaces.json /home/claude/.claude/plugins/known_marketplaces.json'
has 'RUN chmod 644 /home/claude/.claude/plugins/known_marketplaces.json'
jq_ok "$FAKE/ctx/known_marketplaces.json" 'd == {"c4-model-skill": {"source": {"source": "github", "repo": "o/c4-model-skill"}, "installLocation": "/usr/local/share/claude-box/seed/marketplaces/c4-model-skill", "autoUpdate": False}}' \
    || fail "not registered: $(cat "$FAKE/ctx/known_marketplaces.json")"
[ "$(seed_f)" = x ] || fail "not approved"
not_called box-plugins
passed=$((passed + 1))

case=seed-not-moved         # nothing moved upstream: no staging box
rm -f "$FAKE/box"; : > "$LOG"
dev_in_p shell >/dev/null 2>&1 || fail "exited $?"
staged && fail "staged although nothing moved"
passed=$((passed + 1))

case=seed-package-rebuild   # a dnf line added: the layer rebuilds with the approved seed, no staging box
rm -f "$FAKE/box"; : > "$LOG"; conf "$C4" 'dnf jq'
echo y | tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "exited $?"
staged && fail "staged for a package change"
has 'COPY seed /usr/local/share/claude-box/seed'
passed=$((passed + 1))

case=seed-moved-same        # moved, same files: no question; the next start runs no staging box
rm -f "$FAKE/box"; : > "$LOG"; up_commit cheriftj/c4-model-skill
out=$(FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell 2>&1 < /dev/null) || fail "exited $?: $out"
grep -qF 'Apply it?' <<< "$out" && fail "asked for an unchanged plugin: $out"
: > "$LOG"; dev_in_p shell >/dev/null 2>&1 || fail "exited $?"
staged && fail "staged again: the heads weren't refreshed"
passed=$((passed + 1))

case=seed-moved-no-tty      # moved and changed, no terminal: the approved seed, one line, no question
rm -f "$FAKE/box"; : > "$LOG"; up_commit cheriftj/c4-model-skill
out=$(FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_BODY=y dev_in_p shell 2>&1) || fail "exited $?: $out"
grep -qF 'run dev claude in a terminal' <<< "$out" || fail "not said: $out"
grep -qF 'Apply it?' <<< "$out" && fail "asked without a terminal: $out"
staged && fail "staged without a terminal"
[ "$(seed_f)" = x ] || fail "the approved seed changed without a yes"
passed=$((passed + 1))

case=seed-moved             # moved and changed: shown, applied after yes
rm -f "$FAKE/box"; : > "$LOG"
out=$(echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_BODY=y tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
grep -qF '~ c4m@c4-model-skill 1.0 -> 1.0' <<< "$out" || fail "change not shown: $out"
[ "$(seed_f)" = y ] || fail "not applied"
has 'COPY seed /usr/local/share/claude-box/seed'
passed=$((passed + 1))

fresh seed-layer-no         # no: not built in, nothing approved, the box starts
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
echo n | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell >/dev/null 2>&1
[ -e "$FAKE/ctx/seed" ] && fail "built in after no"
[ -e "$HOME/.local/state/claude-box/$STATE_SEED" ] && fail "approved after no"
hasnt 'known_marketplaces.json'     # no seed, no registration
passed=$((passed + 1))

case=seed-known-json        # the registration: each seed's at its image path, the first seed's name wins, a bad name left out
k="$tmp/k-$case"; mkdir -p "$k/a" "$k/b"
printf '{"m": {"source": {"repo": "o/a"}, "installLocation": "/seed/marketplaces/m"}, "../x": {"source": {}}, "..": {"source": {}}, "n": 1}\n' > "$k/a/known_marketplaces.json"
printf '{"m": {"source": {"repo": "o/b"}}, "z.y_1-2": {"source": {"repo": "o/z"}}}\n' > "$k/b/known_marketplaces.json"
run_seed seed_known_json "$k/a" /img/a "$k/b" /img/b "$k/none" /img/none > "$k/out.json" || fail "exited $?"
jq_ok "$k/out.json" 'd == {"m": {"source": {"repo": "o/a"}, "installLocation": "/img/a/marketplaces/m", "autoUpdate": False}, "z.y_1-2": {"source": {"repo": "o/z"}, "installLocation": "/img/b/marketplaces/z.y_1-2", "autoUpdate": False}}' \
    || fail "got: $(cat "$k/out.json")"
passed=$((passed + 1))

fresh seed-removed          # a removed line: restaged without it; its id gone from the drop-in
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; up_repo o/x; conf "$C4" 'plugin x@y o/x'
echo y | FAKE_STAGE='c4m@c4-model-skill=1.0 x@y=1' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "exited $?"
grep -qF '"x@y": true' "$FAKE/ctx/claude-box-plugins.json" || fail "x@y not switched on first"
rm -f "$FAKE/box"; conf "$C4"
out=$(echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
grep -qF -- '  - x@y' <<< "$out" || fail "removal not shown: $out"
grep -qF 'x@y' "$FAKE/ctx/claude-box-plugins.json" && fail "x@y still switched on"
passed=$((passed + 1))

fresh seed-stage-fails      # a staging that fails: one line, the box starts without the plugin
rm -rf "$tmp/up"; conf "$C4"
out=$(echo y | FAKE_STAGE_STATUS=1 tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
grep -qF "Couldn't fetch the plugins" <<< "$out" || fail "not said: $out"
passed=$((passed + 1))

fresh seed-project          # a project's marketplace line: shown, approved, in its image
rm -rf "$tmp/up"; up_repo o/r; echo 'plugin a@b o/r' > "$HOME/Projects/p/.dev"
out=$(echo y | FAKE_STAGE='a@b=1' tty_run_in_p "$DEV" shell 2>&1) || fail "exited $?: $out"
grep -qF '+ a@b 1' <<< "$out" || fail "not shown: $out"
has 'COPY seed-project /usr/local/share/claude-box/seed-project'
has 'COPY claude-box-project-plugins.json /etc/claude-code/managed-settings.d/'
has 'ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed-project'
grep -qF '"a@b": true' "$FAKE/ctx/claude-box-project-plugins.json" || fail "not switched on"
has 'COPY known_marketplaces.json /home/claude/.claude/plugins/known_marketplaces.json'
jq_ok "$FAKE/ctx/known_marketplaces.json" 'list(d) == ["b"] and d["b"]["installLocation"] == "/usr/local/share/claude-box/seed-project/marketplaces/b"' \
    || fail "not registered: $(cat "$FAKE/ctx/known_marketplaces.json")"
runs localhost/claude-box-p
passed=$((passed + 1))

case=seed-project-other     # another project's box has no seed-project
mkdir -p "$HOME/Projects/q" && git -C "$HOME/Projects/q" init -q; rm -f "$FAKE/box"; : > "$LOG"
(cd "$HOME/Projects/q" && "$DEV" shell) >/dev/null 2>&1 || fail "exited $?"
hasnt "COPY seed-project"
passed=$((passed + 1))

fresh seed-project-both     # with your seed too: the project's first, then yours
rm -rf "$tmp/up"; up_repo o/r; up_repo cheriftj/c4-model-skill; conf "$C4"
echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving yours exited $?"
rm -f "$FAKE/box"; echo 'plugin a@b o/r' > "$HOME/Projects/p/.dev"
echo y | FAKE_STAGE='a@b=1' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "exited $?"
has 'ENV CLAUDE_CODE_PLUGIN_SEED_DIR=/usr/local/share/claude-box/seed-project:/usr/local/share/claude-box/seed'
grep -qF 'c4m' "$FAKE/ctx/claude-box-project-plugins.json" && fail "the project's drop-in names yours"
jq_ok "$FAKE/ctx/known_marketplaces.json" 'list(d) == ["b", "c4-model-skill"] and d["c4-model-skill"]["installLocation"] == "/usr/local/share/claude-box/seed/marketplaces/c4-model-skill"' \
    || fail "not both, the project's first: $(cat "$FAKE/ctx/known_marketplaces.json")"
passed=$((passed + 1))

case=seed-project-level     # the same marketplace plugin at both levels: refused at the project's line
rm -f "$FAKE/box"; : > "$LOG"; echo "$C4" > "$HOME/Projects/p/.dev"
out=$(dev_in_p shell 2>&1) && fail "accepted at both levels: $out"
grep -qF '.dev line 1:' <<< "$out" && grep -qF 'one level only' <<< "$out" || fail "not said: $out"
passed=$((passed + 1))

fresh seed-project-no       # no: nothing of it built, the box starts
rm -rf "$tmp/up"; up_repo o/r; echo 'plugin a@b o/r' > "$HOME/Projects/p/.dev"
echo n | FAKE_STAGE='a@b=1' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "exited $?"
hasnt "COPY seed-project"
has bash
passed=$((passed + 1))

fresh add-plugin-no-gitignore # dev add plugin <market>: .gitignore untouched (no local settings any more)
dev_in_p add plugin a@b o/r >/dev/null || fail "exited $?"
[ ! -e "$HOME/Projects/p/.gitignore" ] || fail ".gitignore written: $(cat "$HOME/Projects/p/.gitignore")"
passed=$((passed + 1))

# installed <json plugins map>: Claude Code's record of what it installed into ~/.claude/plugins.
installed() { mkdir -p "$HOME/.claude/plugins"; printf '{"version": 2, "plugins": %s}\n' "$1" > "$HOME/.claude/plugins/installed_plugins.json"; }
CB=/home/claude/.claude/plugins
M="{\"scope\": \"managed\", \"installPath\": \"$CB/cache/c4-model-skill/c4m/1\", \"version\": \"1\"}"
# leftovers: what an earlier claude-box left in ~/.claude/plugins for c4m, with
# your settings, a plugin's state and a seed marketplace a session recorded.
leftovers() {
    local P="$HOME/.claude/plugins"
    installed "{\"c4m@c4-model-skill\": [$M]}"
    mkdir -p "$P/cache/c4-model-skill/c4m/1" "$P/marketplaces/c4-model-skill" "$P/data/c4m" "$P/store"
    echo f > "$P/cache/c4-model-skill/c4m/1/f"; echo f > "$P/marketplaces/c4-model-skill/f"
    echo k > "$P/data/c4m/k"; echo k > "$P/store/k"
    printf '{"c4-model-skill": {"installLocation": "%s/marketplaces/c4-model-skill"}, "x": {"installLocation": "/usr/local/share/claude-box/seed/marketplaces/x"}}\n' "$CB" > "$P/known_marketplaces.json"
    printf '{"model": "m", "enabledPlugins": {"c4m@c4-model-skill": true, "z@y": true}}\n' > "$HOME/.claude/settings.json"
}
# jq_ok <file> <python expression on d>: the JSON file passes the check.
clear_start() { printf 'y\ny\n' | FAKE_STAGE="${1:-c4m@c4-model-skill=1.0}" tty_run_in_p "$DEV" shell 2>&1; }

fresh seed-clear            # what an earlier claude-box left for a plugin now in your seed: offered, removed on yes, the rest kept (P3)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && grep -qF 'c4m@c4-model-skill' <<< "$out" || fail "not offered: $out"
P="$HOME/.claude/plugins"
jq_ok "$P/installed_plugins.json" '"c4m@c4-model-skill" not in d["plugins"]' || fail "record kept"
[ ! -e "$P/cache/c4-model-skill/c4m/1" ] || fail "cache copy kept"
jq_ok "$P/known_marketplaces.json" 'd == {}' || fail "marketplaces kept: $(cat "$P/known_marketplaces.json")"
[ ! -e "$P/marketplaces/c4-model-skill" ] || fail "marketplace folder kept"
jq_ok "$HOME/.claude/settings.json" 'd == {"model": "m", "enabledPlugins": {"z@y": True}}' || fail "settings: $(cat "$HOME/.claude/settings.json")"
[ -e "$P/data/c4m/k" ] && [ -e "$P/store/k" ] || fail "data/ or store/ touched"
hasnt 'plugin uninstall'
passed=$((passed + 1))

case=seed-clear-again       # the next start: nothing left to offer
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && fail "offered again: $out"
passed=$((passed + 1))

fresh seed-clear-keep       # a record of a plugin in no seed: not offered, its files kept
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
installed "{\"x@y\": [$M]}"; rm "$HOME/.claude/plugins/known_marketplaces.json"
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && fail "offered: $out"
[ -e "$HOME/.claude/plugins/cache/c4-model-skill/c4m/1/f" ] || fail "files removed"
passed=$((passed + 1))

fresh seed-clear-shared     # a marketplace another record still uses: kept
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
installed "{\"c4m@c4-model-skill\": [$M], \"other@c4-model-skill\": [{\"scope\": \"user\", \"installPath\": \"/x\", \"version\": \"1\"}]}"
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" || fail "not offered: $out"
jq_ok "$HOME/.claude/plugins/known_marketplaces.json" '"c4-model-skill" in d and "x" not in d' || fail "marketplaces: $(cat "$HOME/.claude/plugins/known_marketplaces.json")"
[ -e "$HOME/.claude/plugins/marketplaces/c4-model-skill/f" ] || fail "shared marketplace folder removed"
passed=$((passed + 1))

fresh seed-clear-project    # a record of the project's seed plugin, any scope: offered at that project's start
rm -rf "$tmp/up"; up_repo o/r; echo 'plugin a@b o/r' > "$HOME/Projects/p/.dev"
installed '{"a@b": [{"scope": "local", "projectPath": "/somewhere", "installPath": "/x", "version": "1"}]}'
out=$(clear_start 'a@b=1') || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && grep -qF 'a@b' <<< "$out" || fail "not offered: $out"
jq_ok "$HOME/.claude/plugins/installed_plugins.json" 'd["plugins"] == {}' || fail "record kept"
passed=$((passed + 1))

fresh seed-clear-outside    # a record pointing out of the cache: the record goes, the path stays
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
mkdir -p "$HOME/.claude/outside"; echo f > "$HOME/.claude/outside/f"
ln -s "$HOME/.claude/outside" "$HOME/.claude/plugins/cache/c4-model-skill/c4m/2"
installed "{\"c4m@c4-model-skill\": [{\"scope\": \"managed\", \"installPath\": \"$CB/cache/../../outside\", \"version\": \"1\"}, {\"scope\": \"user\", \"installPath\": \"$CB/cache/c4-model-skill/c4m/2\", \"version\": \"2\"}]}"
out=$(clear_start) || fail "exited $?: $out"
jq_ok "$HOME/.claude/plugins/installed_plugins.json" 'd["plugins"] == {}' || fail "record kept"
[ -e "$HOME/.claude/outside/f" ] || fail "a path outside the cache removed"
passed=$((passed + 1))

fresh seed-clear-links      # links a box planted: the temp name, the cache folder; nothing written or removed through them (review C1, C2)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
echo victim > "$tmp/victim"; ln -s "$tmp/victim" "$HOME/.claude/settings.json.claude-box-tmp"
chmod 600 "$HOME/.claude/settings.json"
out=$(clear_start) || fail "exited $?: $out"
[ "$(cat "$tmp/victim")" = victim ] || fail "written through the link"
[ ! -L "$HOME/.claude/settings.json" ] && [ "$(stat -c %a "$HOME/.claude/settings.json")" = 600 ] || fail "settings.json a link, or its mode changed"
jq_ok "$HOME/.claude/settings.json" '"c4m@c4-model-skill" not in d["enabledPlugins"]' || fail "not cleared"
passed=$((passed + 1))

fresh seed-clear-links-cache
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
mkdir -p "$tmp/docs"; mv "$HOME/.claude/plugins/cache" "$tmp/docs/cache"; ln -s "$tmp/docs/cache" "$HOME/.claude/plugins/cache"
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && fail "offered: $out"
grep -qF 'is a link (remove the link): nothing cleared' <<< "$out" || fail "not said: $out"
[ -e "$tmp/docs/cache/c4-model-skill/c4m/1/f" ] || fail "removed through the link"
passed=$((passed + 1))

fresh seed-clear-changed    # the list changed after the yes: nothing removed (review I4)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
HOME="$HOME" bash -c '. "$1/core/lib/seed.sh"; _seed_clear_py apply "c4m@c4-model-skill" "  - something else"' _ "$CLONE" 2>/dev/null && fail "applied"
jq_ok "$HOME/.claude/plugins/installed_plugins.json" '"c4m@c4-model-skill" in d["plugins"]' || fail "removed"
passed=$((passed + 1))

fresh seed-clear-escapes    # a name with control characters is shown with ? (review I5)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
e=$'1\e[2J'; mkdir -p "$HOME/.claude/plugins/cache/c4-model-skill/c4m/$e"
installed "{\"c4m@c4-model-skill\": [{\"scope\": \"managed\", \"installPath\": \"$CB/cache/c4-model-skill/c4m/1\\u001b[2J\", \"version\": \"1\"}]}"
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'c4m/1?[2J' <<< "$out" && ! grep -qF $'\e[2J' <<< "$out" || fail "not escaped: $out"
passed=$((passed + 1))

fresh seed-clear-bad-json   # a broken record file: nothing asked, nothing rewritten, the box starts
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"; leftovers
echo '{' > "$HOME/.claude/plugins/installed_plugins.json"
out=$(clear_start) || fail "exited $?: $out"
grep -qF 'Remove them?' <<< "$out" && fail "offered: $out"
grep -qF "isn't valid JSON: nothing cleared" <<< "$out" && ! grep -qF Traceback <<< "$out" || fail "not said in one line: $out"
[ "$(cat "$HOME/.claude/plugins/installed_plugins.json")" = '{' ] || fail "rewritten"
has bash
passed=$((passed + 1))

fresh seed-clear-no-tty     # no terminal: nothing removed
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving exited $?"
leftovers
dev_in_p shell >/dev/null 2>&1 || fail "exited $?"
jq_ok "$HOME/.claude/plugins/installed_plugins.json" '"c4m@c4-model-skill" in d["plugins"]' || fail "removed without a terminal"
passed=$((passed + 1))

fresh python-isolated      # a json.py a box put in its project runs nothing on your machine (python3 -I)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
printf 'import os\nopen(os.path.expanduser("~/hijacked"), "w").write("x")\nfrom json import *\n' > "$HOME/Projects/p/json.py"
echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving exited $?"
dev_in_p shell >/dev/null 2>&1 || fail "exited $?"
[ ! -e "$HOME/hijacked" ] || fail "the project's json.py ran on the host"
passed=$((passed + 1))

fresh seed-project-market   # one marketplace at both levels, a different plugin at each: accepted (seed checks, S7)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
echo y | FAKE_STAGE='c4m@c4-model-skill=1.0' tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving yours exited $?"
rm -f "$FAKE/box"; echo 'plugin other@c4-model-skill cheriftj/c4-model-skill' > "$HOME/Projects/p/.dev"
out=$(echo y | FAKE_STAGE='other@c4-model-skill=2' tty_run_in_p "$DEV" shell 2>&1) || fail "refused: $out"
has 'COPY seed-project /usr/local/share/claude-box/seed-project'
grep -qF '"other@c4-model-skill": true' "$FAKE/ctx/claude-box-project-plugins.json" || fail "not switched on"
passed=$((passed + 1))

fresh seed-diff-nested      # a folder named seed inside a plugin of yours is shown in the diff (C1)
rm -rf "$tmp/up"; plugin_dir pz; mkdir -p "$HOME/.claude/pz/skills/seed"; echo a > "$HOME/.claude/pz/skills/seed/SKILL.md"
conf 'plugin ~/.claude/pz'
echo y | tty_run_in_p "$DEV" shell >/dev/null 2>&1 || fail "approving exited $?"
rm -f "$FAKE/box"; echo hidden-change > "$HOME/.claude/pz/skills/seed/SKILL.md"
out=$(echo n | tty_run_in_p "$DEV" shell 2>&1)
grep -qF 'hidden-change' <<< "$out" || fail "a nested seed/ folder isn't shown: $out"
passed=$((passed + 1))

fresh seed-sanitized        # upstream strings can't redraw the terminal (I1)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; conf "$C4"
out=$(echo n | FAKE_STAGE="c4m@c4-model-skill=1.0$(printf '\033')[2J" tty_run_in_p "$DEV" shell 2>&1)
grep -qF "$(printf '\033')[2J" <<< "$out" && fail "an escape reached the terminal"
grep -qF '+ c4m@c4-model-skill 1.0?[2J' <<< "$out" || fail "not shown sanitized: $out"
passed=$((passed + 1))

fresh seed-https-only       # a plugin's own repo is checked only over https (I2)
FAKE_MARKET_JSON='{"plugins": [{"name": "c4m", "source": {"source": "url", "url": "ssh://evil/x"}}, {"name": "d", "source": {"source": "url", "url": "file:///etc"}}, {"name": "e", "source": {"source": "git-subdir", "url": "https://h.example/e.git", "path": "p"}}]}' \
    FAKE_STAGE='c4m@c4-model-skill=1.0 d@c4-model-skill=1 e@c4-model-skill=1' run_seed stage_seed "$tmp/s-$case" "$C4" 2>/dev/null
out="$(run_seed seed_sources "$tmp/s-$case")"
grep -qE 'ssh:|file:///etc' <<< "$out" && fail "a non-https source is checked: $out"
grep -qxF 'https://h.example/e.git HEAD' <<< "$out" || fail "the https source isn't checked: $out"
grep -qF 'GIT_TERMINAL_PROMPT=0' "$CLONE/core/lib/seed.sh" || fail "git may prompt"
passed=$((passed + 1))

fresh seed-stage-timeout    # a staging box that hangs ends after SEED_STAGE_TIMEOUT: failed (I3)
t0=$SECONDS
FAKE_STAGE='c4m@c4-model-skill=1.0' FAKE_STAGE_SLEEP=30 SEED_STAGE_TIMEOUT=2 run_seed stage_seed "$tmp/s-$case" "$C4" 2>/dev/null && fail "a hanging staging passed"
[ $((SECONDS - t0)) -lt 15 ] || fail "took $((SECONDS - t0))s"
passed=$((passed + 1))

fresh seed-check-ref-gone   # a plugin ref that's gone doesn't hide a move of the marketplace (I4)
rm -rf "$tmp/up"; up_repo cheriftj/c4-model-skill; up_repo o/plug
FAKE_MARKET_JSON="{\"plugins\": [{\"name\": \"c4m\", \"source\": {\"source\": \"url\", \"url\": \"${SEED_GIT_BASE}o/plug\", \"ref\": \"gone\"}}]}" \
    FAKE_STAGE='c4m@c4-model-skill=1.0' run_seed stage_seed "$tmp/s-$case" "$C4" 2>/dev/null
up_commit cheriftj/c4-model-skill
run_seed seed_moved "$tmp/s-$case" 2>/dev/null; [ $? = 0 ] || fail "the marketplace's move is hidden by a gone ref"
passed=$((passed + 1))

echo "test_dev: $passed passed"
