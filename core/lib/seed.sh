# shellcheck shell=bash
# Marketplace plugins as a Claude Code seed (CLAUDE_CODE_PLUGIN_SEED_DIR):
# staged by Claude Code in a throwaway box, compared, and checked upstream.
# dev never fetches or installs a plugin itself.

# seed_lines <root>: the marketplace plugin lines of <root>/.dev (a
# snapshot or an approved copy) and the dependencies of its folder
# plugins, as "plugin <name>@<market> <owner/repo>", sorted, once each.
seed_lines() {
    local kind val
    while read -r kind val; do
        [ "$kind" = plugin ] || continue
        case "$(use_form "$val")" in
            market) echo "plugin $val" ;;
            clone|home) plugin_deps "$(use_src "$val" "$1")" ;;
        esac
    done < <(read_conf "$1/.dev" "$1") | sort -u
}

# stage_seed <dest> <lines>: a fresh seed in <dest> with every line's
# plugin, installed by Claude Code in a box that sees only <dest>. Records
# the lines (claude-box-lines) and the upstream heads (seed_record_heads).
# Fails, with the box's last lines, when the box fails or a line's plugin
# isn't in the seed afterwards.
stage_seed() {
    local dest="$1" lines="$2" args=() id repo out have
    rm -rf "$dest"; mkdir -p "$dest"
    while read -r _ id repo; do [ -z "$id" ] || args+=("$repo" "$id"); done <<< "$lines"
    if ! out="$(timeout "${SEED_STAGE_TIMEOUT:-600}" podman run --rm --userns=keep-id:uid=1000,gid=1000 --cap-drop=all \
            --security-opt=no-new-privileges -v "$dest":/seed:z \
            -e CLAUDE_CODE_PLUGIN_CACHE_DIR=/seed -e CLAUDE_CONFIG_DIR=/tmp/h \
            "$IMAGE" stage-seed "${args[@]}" 2>&1)"; then
        tail -n 5 <<< "$out" | LC_ALL=C sed 's/[^[:print:]\t]/?/g; s/^/  /' >&2; return 1
    fi
    have="$(seed_plugins "$dest" | cut -d' ' -f1)"
    while read -r _ id _; do
        [ -z "$id" ] || grep -qxF -- "$id" <<< "$have" || { echo "  $id isn't in the staged seed" >&2; return 1; }
    done <<< "$lines"
    printf '%s\n' "$lines" > "$dest/claude-box-lines"
    seed_record_heads "$dest" || true   # a head not recorded: the next check stages again
}

# seed_sources <seed>: "<url> <ref>" per upstream to check: each line's
# marketplace repo, and each installed plugin's own repo where its entry in
# the seed's marketplace.json names one (url, github, git-subdir; ref HEAD
# when unset). An entry pinned to a sha, a relative path or npm adds
# nothing: it moves only with its marketplace. These repo and ref fields
# are all dev reads of a source. GitHub always over HTTPS.
seed_sources() {
    local base="${SEED_GIT_BASE:-https://github.com/}"
    { [ ! -f "$1/claude-box-lines" ] || awk -v b="$base" 'NF == 3 { print b $3 " HEAD" }' "$1/claude-box-lines"
      python3 -I - "$1" "$base" <<'EOF'
import json, os, re, sys
seed, base = sys.argv[1], sys.argv[2]
try: installed = json.load(open(os.path.join(seed, "installed_plugins.json"))).get("plugins") or {}
except (OSError, ValueError): installed = {}
for pid in installed:
    name, _, market = pid.partition("@")
    try: entries = json.load(open(os.path.join(seed, "marketplaces", market, ".claude-plugin", "marketplace.json"))).get("plugins") or []
    except (OSError, ValueError): continue
    for e in entries:
        src = e.get("source") if isinstance(e, dict) and e.get("name") == name else None
        if not isinstance(src, dict) or src.get("sha"): continue
        kind = src.get("source")
        if kind in ("url", "git-subdir"): url = src.get("url") or ""
        elif kind == "github" and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+", str(src.get("repo") or "")): url = base + src["repo"]
        else: url = ""
        ref = str(src.get("ref") or "HEAD")
        # https only: no ssh agent, local path or other scheme from upstream text
        ok = url.startswith(base) or re.fullmatch(r"https://[A-Za-z0-9.-]+(/[A-Za-z0-9._~/-]*)?", url)
        if ok and " " not in url and re.fullmatch(r"[A-Za-z0-9._/-]+", ref):
            print(url, ref)
EOF
    } | sort -u
}

# _seed_head <url> <ref>: the commit the ref names upstream (HEAD, or
# exactly refs/heads/<ref> or refs/tags/<ref>); nothing when it can't be
# read within SEED_TIMEOUT seconds (default 10) or the ref is gone. git
# never prompts.
_seed_head() {
    local want="$2"
    [ "$2" = HEAD ] || want="refs/heads/$2 refs/tags/$2"
    # shellcheck disable=SC2086 # two patterns
    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false \
        timeout "${SEED_TIMEOUT:-10}" git -c credential.helper= ls-remote -- "$1" $want 2>/dev/null \
        | awk -v r="$2" '$2 == r || $2 == "refs/heads/" r || $2 == "refs/tags/" r { print $1; exit }'
}

# seed_record_heads <seed>: writes claude-box-heads, "<url> <ref> <sha>"
# per source; 1 when one can't be read (it's left out).
seed_record_heads() {
    local url ref sha rc=0
    : > "$1/claude-box-heads"
    while read -r url ref; do
        sha="$(_seed_head "$url" "$ref")"
        if [ -n "$sha" ]; then echo "$url $ref $sha" >> "$1/claude-box-heads"; else rc=1; fi
    done < <(seed_sources "$1")
    return "$rc"
}

# seed_moved <seed>: 0 when an upstream has moved (or a source has no
# recorded head), else 2 when one couldn't be checked (each named on
# stderr; the others are still checked), else 1.
seed_moved() {
    local url ref sha was moved=1 unchecked=0
    while read -r url ref; do
        sha="$(_seed_head "$url" "$ref")"
        if [ -z "$sha" ]; then
            echo "Couldn't check $url ($ref) for new plugin commits." | LC_ALL=C sed 's/[^[:print:]\t]/?/g' >&2
            unchecked=1; continue
        fi
        was="$(awk -v u="$url" -v r="$ref" '$1 == u && $2 == r { print $3 }' "$1/claude-box-heads" 2>/dev/null)"
        [ "$was" = "$sha" ] || moved=0
    done < <(seed_sources "$1")
    [ "$moved" = 0 ] && return 0
    [ "$unchecked" = 0 ] || return 2
    return 1
}

# _seed_py <mode> <seed> [<seed>]: reads installed_plugins.json.
#   plugins  "<id> <version>" per plugin, sorted
#   digest   16 hex over the ids, versions and every file of each plugin
#   changes  "+ <id> <version>", "- <id>", "~ <id> <old> -> <new>" (also
#            when only files differ) from the first seed to the second
#   enable   {"enabledPlugins": {...}} with each id true
_seed_py() {
    python3 -I - "$@" <<'EOF'
import hashlib, json, os, sys
mode, seeds = sys.argv[1], sys.argv[2:]
def read(seed):
    try: d = json.load(open(os.path.join(seed, "installed_plugins.json")))
    except (OSError, ValueError): return {}
    out = {}
    for pid, entries in (d.get("plugins") or {}).items():
        if not entries: continue
        e = entries[0]; ver = str(e.get("version", ""))
        path = str(e.get("installPath", ""))
        rel = path.split("/cache/", 1)[1] if "/cache/" in path else ""
        h = hashlib.sha256()
        root = os.path.join(seed, "cache", rel) if rel else ""
        if root and os.path.isdir(root):
            for dp, dns, fns in os.walk(root):
                dns.sort()
                for fn in sorted(fns):
                    p = os.path.join(dp, fn)
                    h.update(os.path.relpath(p, root).encode() + b"\0")
                    if not os.path.islink(p): h.update(open(p, "rb").read())
                    h.update(b"\0")
        out[pid] = (ver, h.hexdigest())
    return out
a = read(seeds[0])
if mode == "plugins":
    for pid in sorted(a): print(pid, a[pid][0])
elif mode == "digest":
    h = hashlib.sha256()
    for pid in sorted(a): h.update(f"{pid} {a[pid][0]} {a[pid][1]}\n".encode())
    print(h.hexdigest()[:16])
elif mode == "changes":
    b = read(seeds[1])
    for pid in sorted(set(a) | set(b)):
        if pid not in a: print(f"+ {pid} {b[pid][0]}")
        elif pid not in b: print(f"- {pid}")
        elif a[pid] != b[pid]: print(f"~ {pid} {a[pid][0]} -> {b[pid][0]}")
elif mode == "enable":
    print(json.dumps({"enabledPlugins": {pid: True for pid in sorted(a)}}))
EOF
}
seed_plugins() { _seed_py plugins "$1"; }
seed_digest() { _seed_py digest "$1"; }
seed_changes() { _seed_py changes "$1" "$2"; }
seed_enable_json() { _seed_py enable "$1"; }

# seed_known_json <seed dir> <image seed path> [<seed dir> <image seed path>]...:
# known_marketplaces.json for an image's ~/.claude/plugins/, so a box's
# first session finds the seeds' marketplaces registered: each as Claude
# Code registers it, at its folder in the image's seed. The first seed with
# a name wins; a name that isn't [A-Za-z0-9_.-]+ (or is . or ..) is left out.
seed_known_json() {
    python3 -I - "$@" <<'EOF2'
import json, os, re, sys
out, a = {}, sys.argv[1:]
for seed, path in zip(a[::2], a[1::2]):
    try: d = json.load(open(os.path.join(seed, "known_marketplaces.json")))
    except (OSError, ValueError): continue
    for m, v in d.items() if isinstance(d, dict) else ():
        if re.fullmatch(r"[A-Za-z0-9_.-]+", m) and m not in (".", "..") and isinstance(v, dict) and m not in out:
            out[m] = {"source": v.get("source"), "installLocation": f"{path}/marketplaces/{m}", "autoUpdate": False}
print(json.dumps(out, indent=2))
EOF2
}

# seed_snapshot <dest>: the seed for the snapshot in <dest>, beside its
# .dev. The approved seed (in $APPROVED) when it holds the same lines and
# nothing moved upstream, or the check failed; else a fresh staging. A
# staging that fails keeps the approved seed, or starts without one.
seed_snapshot() {
    local dest="$1" lines rc
    lines="$(seed_lines "$dest")"
    [ -n "$lines" ] || return 0
    if approved_ok && [ -d "$APPROVED/seed" ] \
            && [ "$(cat "$APPROVED/seed/claude-box-lines" 2>/dev/null)" = "$lines" ]; then
        rc=0; seed_moved "$APPROVED/seed" || rc=$?
        # no terminal to ask: no staging (it takes minutes, and nothing could approve it)
        if [ "$rc" = 0 ] && [ ! -t 0 ]; then
            echo "New plugin commits upstream: run dev claude in a terminal to see them." >&2; rc=1
        fi
        if [ "$rc" != 0 ]; then cp -r "$APPROVED/seed" "$dest/seed"; return 0; fi
    fi
    stage_seed "$dest/seed" "$lines" && return 0
    rm -rf "$dest/seed"
    if approved_ok && [ -d "$APPROVED/seed" ]; then
        echo "Couldn't fetch the plugins: keeping the ones you approved." >&2
        cp -r "$APPROVED/seed" "$dest/seed"
    else
        echo "Couldn't fetch the plugins: starting without them." >&2
    fi
}

# seed_refresh <snapshot>: the snapshot's seed holds the plugins you
# approved, staged again because an upstream moved: it replaces the
# approved one without asking, so the next check compares against the new
# heads.
seed_refresh() {
    [ -d "$1/seed" ] && [ -d "$APPROVED/seed" ] || return 0
    cmp -s "$1/seed/claude-box-heads" "$APPROVED/seed/claude-box-heads" && return 0
    rm -rf "$APPROVED/seed" && cp -r "$1/seed" "$APPROVED/seed"
}

# seed_clear <seed dir>: what earlier claude-box versions left in your
# ~/.claude/plugins/ for the plugins of that approved seed, now that every
# box has its own plugins folder (box.sh): their install records at any
# scope, the cache copies only those records used, the marketplaces left
# with no record, every recorded marketplace under the image's seeds, and
# their enabledPlugins in settings.json. Lists them; on yes, dev removes
# exactly those, here, with no box. Nothing else is touched. No terminal, a
# no, or a file that isn't valid JSON: nothing removed, asked again at the
# next start.
seed_clear() {
    local ids list
    [ -d "$1" ] && [ -d "$HOME/.claude/plugins" ] || return 0
    ids="$(seed_plugins "$1" | cut -d' ' -f1 | tr '\n' ' ')"
    list="$(_seed_clear_py list "$ids")" || return 0
    [ -n "$list" ] || return 0
    echo "Left in ~/.claude/plugins by an earlier claude-box, no longer used (the image has them):"
    printf '%s\n' "$list"
    ask "Remove them?" || return 0
    _seed_clear_py apply "$ids" "$list" || echo "Removing them failed; dev offers it again at the next start."
}
# _seed_clear_py list <ids>: prints what seed_clear would remove.
# _seed_clear_py apply <ids> <list>: removes it, only if it's still that list.
_seed_clear_py() {
    python3 -I - "$1" "$HOME/.claude" "$2" "${3:-}" <<'EOF'
import json, os, re, shutil, sys, tempfile
mode, home, seed, shown = sys.argv[1], sys.argv[2], set(sys.argv[3].split()), sys.argv[4]
P = os.path.join(home, "plugins")
BOX = "/home/claude/.claude/"   # the box's path of your ~/.claude, as records name it
ok = re.compile(r"^[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+$")
okm = re.compile(r"^[A-Za-z0-9_.-]+$")
def stop(why):
    print(f"~/.claude/plugins: {why}: nothing cleared", file=sys.stderr); sys.exit(1)
inst_f, known_f, set_f = (os.path.join(P, "installed_plugins.json"),
    os.path.join(P, "known_marketplaces.json"), os.path.join(home, "settings.json"))
# Any box can write there: a link would point dev's removals and writes elsewhere.
for p in (P, os.path.join(P, "cache"), os.path.join(P, "marketplaces"), inst_f, known_f, set_f):
    if os.path.islink(p): stop(f"{p} is a link (remove the link)")
def load(path, default):
    if not os.path.exists(path): return default
    try:
        with open(path) as f: d = json.load(f)
    except (OSError, ValueError): stop(f"{path} isn't valid JSON")
    if not isinstance(d, dict): stop(f"{path} isn't a JSON object")
    return d
inst = load(inst_f, {"plugins": {}}); known = load(known_f, {}); sett = load(set_f, {})
recs = inst.get("plugins") if isinstance(inst.get("plugins"), dict) else {}
def host(box_path):             # the host path of a record's box path
    if not isinstance(box_path, str) or not box_path.startswith(BOX): return None
    return os.path.realpath(os.path.join(home, box_path[len(BOX):]))
def inside(box_path, under):    # ... if it's a folder under <under>
    real, root = host(box_path), os.path.realpath(os.path.join(P, under))
    return real if real and real.startswith(root + os.sep) and os.path.isdir(real) else None
def entries(pid): return [e for e in (recs[pid] if isinstance(recs[pid], list) else []) if isinstance(e, dict)]
drop = sorted(pid for pid in recs if pid in seed and ok.match(pid))
kept = {h for pid in recs if pid not in drop for e in entries(pid) for h in [host(e.get("installPath"))] if h}
copies = sorted({p for pid in drop for e in entries(pid) for p in [inside(e.get("installPath"), "cache")]
                 if p and not any(k == p or k.startswith(p + os.sep) for k in kept)})
left = {pid.split("@")[1] for pid in recs if pid not in drop and "@" in pid}
gone_m = {pid.split("@")[1] for pid in drop} - left
known_drop = sorted(m for m, v in known.items() if okm.match(m) and (m in gone_m
    or (isinstance(v, dict) and str(v.get("installLocation", "")).startswith("/usr/local/share/claude-box/"))))
market_dirs = sorted({p for m in known_drop if isinstance(known[m], dict)
                      for p in [inside(known[m].get("installLocation"), "marketplaces")] if p})
ep = sett.get("enabledPlugins") if isinstance(sett.get("enabledPlugins"), dict) else {}
ep_drop = [pid for pid in drop if pid in ep]
lines = [f"  - {pid}: its install record" + (", its enabledPlugins entry" if pid in ep_drop else "") for pid in drop]
lines += [f"  - {p}" for p in copies + market_dirs]
lines += [f"  - marketplace {m} in known_marketplaces.json" for m in known_drop]
text = "\n".join("".join(c if c.isprintable() else "?" for c in l) for l in lines)
if mode == "list":
    if text: print(text)
    sys.exit(0)
if text != shown: stop("changed since you said yes")
def write(path, d):             # a new file beside it, with its mode, then renamed over it
    mode_ = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".claude-box-")
    with os.fdopen(fd, "w") as f:
        os.fchmod(f.fileno(), mode_); json.dump(d, f, indent=2); f.write("\n")
    os.replace(tmp, path)
for p in copies + market_dirs: shutil.rmtree(p)
if drop:
    for pid in drop: del recs[pid]
    write(inst_f, inst)
if known_drop:
    for m in known_drop: del known[m]
    write(known_f, known)
if ep_drop:
    for pid in ep_drop: del ep[pid]
    write(set_f, sett)
EOF
}
