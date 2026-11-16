# shellcheck shell=bash
# Scratch sessions: Claude outside a project.

# A scratch session: Claude outside a project, its out/ and notes in
# ~/.claude/scratch/<name>. In the box it's /work/scratch-<name>, so Claude
# Code keeps its conversations apart, and Claude's writes there aren't
# writes into ~/.claude, which auto mode guards.
# Every box can write ~/.claude/scratch: a link there could point dev at
# any of your folders, to mount, list, create in or delete. Links are
# refused, and enter_scratch checks where it landed.
scratch_dir() { printf '%s/.claude/scratch/%s' "$HOME" "$1"; }
scratch_root() {
    [ ! -L "$HOME/.claude/scratch" ] || die "$HOME/.claude/scratch is a link: refused (any box can write there; remove the link)"
}
enter_scratch() {
    SCRATCH="$1"; cd -P "$(scratch_dir "$1")"
    [ "$PWD" = "$(cd -P "$HOME/.claude" && pwd)/scratch/$1" ] || die "$1 isn't a folder in $HOME/.claude/scratch: refused"
}
SCRATCH_ADJ=(amber brave brisk calm clever cosy crisp dusty eager fancy gentle glad
    happy jolly keen lively lucky merry misty noble plucky proud quick quiet rapid
    shiny sly snowy sunny swift tidy witty)
SCRATCH_NOUN=(badger beaver bison crane eagle falcon ferret finch fox gecko heron ibis
    koala lark lemur lynx marten moose newt otter owl panda puffin quail raven robin
    seal sparrow stoat tapir walrus wren)
new_scratch() {
    local name
    scratch_root
    while name="${SCRATCH_ADJ[RANDOM % ${#SCRATCH_ADJ[@]}]}-${SCRATCH_NOUN[RANDOM % ${#SCRATCH_NOUN[@]}]}"
          [ -e "$(scratch_dir "$name")" ]; do :; done
    mkdir -p "$(scratch_dir "$name")"
    echo "Scratch session $name: come back with dev claude --scratch $name" >&2
    enter_scratch "$name"
}
# live_claude box: a dev claude session still runs in the box. Each
# session notes its process in /tmp/dev-session.<n> (shared_box); dev
# claude's command is claude, dev shell's bash.
live_claude() {
    # shellcheck disable=SC2016  # expanded in the box
    podman exec "$1" bash -c 'for f in /tmp/dev-session.*; do
        p=$(cat "$f" 2>/dev/null) && tr "\0" " " 2>/dev/null < "/proc/$p/cmdline" | grep -q "^claude " && exit 0
    done; exit 1' 2>/dev/null
}
# check_scratch arg: dies unless arg names a scratch.
check_scratch() {
    [[ "$1" =~ ^[a-z]+-[a-z]+$ ]] || die "Not a scratch name: $1 (dev scratch lists them)"
    scratch_root
    [ -d "$(scratch_dir "$1")" ] && [ ! -L "$(scratch_dir "$1")" ] || die "No scratch session $1 (dev scratch lists them)"
}
# "<last used> <name>" per scratch, last used first: its newest file's
# time, the folder's own while it has none. A folder find can't read all
# of (or a file gone while it looks) still gets a row.
scratch_rows() {
    local d t
    for d in "$HOME/.claude/scratch"/*; do
        [[ "${d##*/}" =~ ^[a-z]+-[a-z]+$ ]] && [ -d "$d" ] && [ ! -L "$d" ] || continue
        t="$(find "$d" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)" || true
        [ -n "$t" ] || t="$(stat -c %Y "$d")"
        printf '%s %s\n' "${t%.*}" "$(basename "$d")"
    done | sort -rn
}
# The numbered list of scratch_rows' rows (stdin). A topic is the first
# line of notes.md, if a "# " heading; a box writes it, so only a plain
# file's first 200 bytes, without control characters, reach your terminal.
list_scratches() {
    local i=0 t name topic f
    while read -r t name; do
        i=$((i + 1)); topic=""; f="$(scratch_dir "$name")/notes.md"
        if [ -f "$f" ] && [ ! -L "$f" ]; then
            topic="$(head -c 200 "$f" 2>/dev/null | head -n 1 | tr -d '[:cntrl:]')" || topic=""
        fi
        if [[ "$topic" == "# "* ]]; then topic="${topic#\# }"; else topic=""; fi
        printf '%2d  %s  %s  %s\n' "$i" "$name" "$(date -d "@$t" '+%Y-%m-%d %H:%M')" "$topic" | sed 's/ *$//'
    done
}
# Prints the name picked from the list on the terminal (list and question
# on stderr).
pick_scratch() {
    local rows names=() n
    scratch_root
    rows="$(scratch_rows)"     # once: the list and the numbers agree
    [ -n "$rows" ] || die "No scratch sessions."
    mapfile -t names < <(cut -d' ' -f2 <<< "$rows")
    [ -t 0 ] || die "No terminal to pick on: dev claude --scratch <name> (dev scratch lists them)"
    list_scratches <<< "$rows" >&2
    read -r -p 'Number (Enter cancels): ' n || n=""
    [[ "$n" =~ ^[1-9][0-9]*$ ]] && [ "$n" -le ${#names[@]} ] || die "Cancelled."
    echo "${names[n-1]}"
}
