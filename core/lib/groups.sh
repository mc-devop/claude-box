# shellcheck shell=bash
# Groups: projects that know each other and, with "autotake group" in your
# config, take each other's messages as your prompt. A group is a folder
# your config names (group <folder>), or a .dev line counted after your
# yes; a project is in one at most. At each box start dev writes the
# project's group into one file the box mounts read-only.

# A member's name is its session's: letters, digits, . _ - only, so the
# box reads each "member <name> <path>" line one way.
GROUP_NAME='^[A-Za-z0-9][A-Za-z0-9._-]*$'

# The file of your yeses to .dev group lines, "<group> <project path>",
# beside the approved config (approved/ itself moves aside at each yes).
group_yes() { printf '%s/group-yes' "$(dirname "$APPROVED")"; }

# group_path: the project's groups file, by its folder's name and a hash of
# its real path, so two projects of one name never share one.
group_path() {
    local here; here="$(pwd -P)"
    printf '%s/groups/%s-%s' "$(dirname "$APPROVED")" "${here##*/}" "$(printf '%s' "$here" | sha256sum | cut -c1-16)"
}

# group_folders: each group folder of your approved config, as a real
# path; dies on one outside your projects folder, or inside a repo there
# (a box could make members in it).
group_folders() {
    local items val e d projects
    items="$(approved_items)" || exit 1
    projects="$(realpath -m -- "$PROJECTS")"
    while IFS= read -r val; do
        [ -n "$val" ] || continue
        e="$(realpath -m -- "${val/#\~/$HOME}")"
        [[ "$e" == "$projects"/* ]] || die "Your config (~/.claude/.dev): group $val: not in your projects folder ($PROJECTS)"
        d="$e"
        while [ "$d" != "$projects" ]; do
            [ ! -e "$d/.git" ] || die "Your config (~/.claude/.dev): group $val: inside a repo ($d), where a box could add members"
            d="$(dirname "$d")"
        done
        printf '%s\n' "$e"
    done < <(awk '$1 == "group" { $1 = ""; print substr($0, 2) }' <<< "$items")
}

# refuse_group_folder: a group folder holds projects; it isn't one.
refuse_group_folder() {
    local folders f here
    folders="$(group_folders)" || exit 1
    here="$(pwd -P)"
    while IFS= read -r f; do
        [ -z "$f" ] || [ "$f" != "$here" ] || die "$PWD is a group folder: start Claude in one of its projects"
    done <<< "$folders"
}

# project_group: sets GROUP to the project's group, or nothing: its folder's,
# or its .dev line's once you said yes (asked here, with a terminal; no
# by default, since Claude can write .dev). Only a project in your projects
# folder joins by .dev, so every local member has a path in the box.
project_group() {
    local folders f here projects byfolder="" byname=""
    GROUP=""
    folders="$(group_folders)" || exit 1
    here="$(pwd -P)"; projects="$(realpath -m -- "$PROJECTS")"
    while IFS= read -r f; do
        [ -z "$f" ] || [ "$f" != "$(dirname "$here")" ] || byfolder="${f##*/}"
    done <<< "$folders"
    byname="$(read_dev | awk '$1 == "group" { print $2 }')" || exit 1
    if [ -n "$byname" ] && [ "$byname" != "$byfolder" ]; then
        [ -z "$byfolder" ] || die "This project is in group $byfolder (its folder) and $byname (.dev): one group per project"
        if [[ "$here" != "$projects"/* || "$here" == *$'\n'* || ! "${here##*/}" =~ $GROUP_NAME ]]; then
            echo "Not in group $byname: only projects in your projects folder, named with letters, digits, . _ -, join by .dev."
            byname=""
        elif ! grep -qxF "$byname $here" "$(group_yes)" 2>/dev/null; then
            if ask_no "This project's .dev puts it in group $byname: $byname's members will take this project's messages as your prompt, and it theirs. Count it in?"; then
                mkdir -p "$(dirname "$(group_yes)")"; printf '%s %s\n' "$byname" "$here" >> "$(group_yes)"
            else
                echo "Not in group $byname: no yes for it."; byname=""
            fi
        fi
    fi
    GROUP="${byfolder:-$byname}"
}

# member_line <path> <projects>: a member as the box sees it, its path
# under /projects; a folder whose name isn't a session's is said, left out.
member_line() {
    if [[ "${1##*/}" =~ $GROUP_NAME ]]; then printf 'member %s /projects/%s\n' "${1##*/}" "${1#"$2"/}"
    else echo "${1##*/}: not a member (a member's name has letters, digits, . _ - only)" >&2; fi
}

# group_file <group> <file>: writes the group's name, every other member
# (the folder's repos; projects you said yes to while their .dev still
# names the group; your remote lines), and your trust line, last.
group_file() {
    local group="$1" items folders projects here f d line g p dev
    items="$(approved_items)" || exit 1
    folders="$(group_folders)" || exit 1
    projects="$(realpath -m -- "$PROJECTS")"; here="$(pwd -P)"
    {
        echo "group $group"
        {
            while IFS= read -r f; do
                [ -n "$f" ] && [ "${f##*/}" = "$group" ] || continue
                for d in "$f"/*/; do
                    d="${d%/}"; [ -d "$d/.git" ] && [ "$d" != "$here" ] && member_line "$d" "$projects"
                done
            done <<< "$folders"
            if [ -f "$(group_yes)" ]; then
                while IFS= read -r line; do
                    g="${line%% *}"; p="${line#* }"
                    [ "$g" = "$group" ] && [ "$p" != "$here" ] && [[ "$p" == "$projects"/* ]] && [ -d "$p" ] || continue
                    dev="$(cd "$p" && read_dev 2>/dev/null)" && grep -qxF "group $group" <<< "$dev" && member_line "$p" "$projects"
                done < "$(group_yes)"
            fi
            awk -v g="$group" '$1 == "remote" && $2 == g { print "member " $3 " remote" }' <<< "$items"
        } | LC_ALL=C sort -u
        if grep -qx 'autotake group' <<< "$items"; then echo 'autotake group'; fi
    } > "$2"
}
