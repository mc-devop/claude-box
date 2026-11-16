# New-project skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dev new` lays down the company default (the starters of the packs in your config), and one rule says what belongs in company, global and project.

**Architecture:** `dev new` copies each approved pack's `project/starter/` into the new project, replaces `{{name}}`, writes the packs into `.dev` and commits it all as the first commit. The workflow pack's starter grows into the full skeleton. A path-scoped rule in the workflow pack's global part loads whenever Claude reads or edits a `CLAUDE.md` or a rules file.

**Tech Stack:** Bash (`dev`, `box/lib/`), Markdown, Python 3 (the link check).

**Spec:** [spec.md](spec.md) (D10, D11, D13, D14), for the [intent](intent.md).

Branch `claude/new-skeleton`, from `main` (64c1128, groups merged).

## Global Constraints

- `dev new` copies the starter of each pack in your **approved** config, `{{name}}` replaced, writes `pack <name>` lines into `.dev`, commits "Start <name>", then offers plugins (D10).
- `dev new <folder>/<name>` works only when `<folder>` is a group folder of your config (D10, D1).
- The workflow starter: `CLAUDE.md` with the sections *what the project owns*, Start of a session, Commands, Rules, Neighbours' interfaces; `docs/direction/backlog.md`, `docs/system/architecture/README.md`, `docs/system/runbook.md`, `docs/change/`; `tests/run.sh` running `check_links.py`; `.gitignore` with `out/` (D11).
- `starter.md`: `dev new` lays the starter down; an existing project copies only `tests/check_links.py` (D11).
- The layers rule: `packs/workflow/global/layers.md`, `paths` for `**/CLAUDE.md` and `.claude/rules/**`; it names D11's sections (D13).
- Your global `CLAUDE.md` is checked against D13 once; anything misplaced goes to `out/` as a draft (D14).
- No private terms in anything tracked; checks pass before every commit.

## Review Focus

- A project name with a `.` or `-` (`my.app`): `{{name}}` is replaced literally, nowhere left.
- A pack in your config not yet approved: its starter isn't laid down.
- Two packs with a file of the same path: the first pack's stays, the second is said and skipped, nothing overwritten silently.
- `dev new x/y` where `x` isn't a group folder: refused, nothing created.
- A fresh project's own `tests/run.sh` passes straight after `dev new`.

Each has its test in Task 1.

## File Structure

| File | Change |
|---|---|
| `dev` | `new`: the name with an optional group folder; calls `lay_starters` |
| `box/lib/project.sh` | `lay_starters <name>` |
| `packs/workflow/project/starter/` | `CLAUDE.md`, `.gitignore`, `docs/…`, `tests/run.sh` added beside `tests/check_links.py` |
| `packs/workflow/project/rules/starter.md` | the new rule |
| `packs/workflow/global/layers.md` | new: the layers' shape |
| `tests/test_dev.sh`, `tests/run.sh` | the tests below; ShellCheck covers the starter's `tests/run.sh`; the layers rule's check |
| `README.md`, `docs/system/architecture/README.md`, `docs/system/runbook.md` | what `dev new` does, the packs table |

---

### Task 1: `dev new` lays down the starters

**Files:**
- Modify: `dev` (`new)` branch), `box/lib/project.sh`
- Create: `packs/workflow/project/starter/CLAUDE.md`, `.gitignore`, `docs/direction/backlog.md`, `docs/system/architecture/README.md`, `docs/system/runbook.md`, `docs/change/.gitkeep`, `tests/run.sh` (mode 755)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: `approved_items`, `APPROVED`, `group_folders` (groups.sh), `GROUP_NAME`.
- Produces: `lay_starters <name>`, run in the new project's folder: for each `pack` item of `approved_items`, copies `$APPROVED/packs/<pack>/project/starter/.` without overwriting (`cp -rn`; a file already there is named `skipped <path>: <pack>'s starter has it too`), appends `pack <pack>` to `.dev` for each pack with a `project/` part, then replaces `{{name}}` in every file that has it. With your config absent or unapproved, `approved_items` gives the defaults, which name no pack: only `README.md`, as today.

- [ ] **Step 1: Write the failing tests** (after `new-writes-dev`)

```bash
fresh new-skeleton          # dev new lays down the approved packs' starters, in the first commit
conf 'pack workflow'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
"$DEV" new my.app >/dev/null 2>&1 || fail "dev new exited $?"
q="$HOME/Projects/my.app"
for f in CLAUDE.md .gitignore docs/direction/backlog.md docs/system/architecture/README.md \
         docs/system/runbook.md docs/change/.gitkeep tests/run.sh tests/check_links.py; do
    [ -f "$q/$f" ] || fail "no $f"
done
[ "$(head -n 1 "$q/CLAUDE.md")" = '# my.app' ] || fail "CLAUDE.md starts: $(head -n 1 "$q/CLAUDE.md")"
! grep -rqF '{{name}}' "$q" --exclude-dir=.git || fail "{{name}} left: $(grep -rlF '{{name}}' "$q" --exclude-dir=.git)"
grep -qx 'out/' "$q/.gitignore" || fail ".gitignore lacks out/"
grep -qx 'pack workflow' "$q/.dev" || fail ".dev: $(cat "$q/.dev")"
[ -x "$q/tests/run.sh" ] || fail "tests/run.sh isn't executable"
[ "$(git -C "$q" log --format=%s)" = 'Start my.app' ] || fail "commits: $(git -C "$q" log --oneline)"
[ -z "$(git -C "$q" status --porcelain)" ] || fail "left uncommitted: $(git -C "$q" status --porcelain)"
(cd "$q" && tests/run.sh) | tail -n 1 | grep -qx 'ALL PASSED' || fail "the new project's checks fail"
passed=$((passed + 1))

fresh new-unapproved        # a pack your config names but you haven't approved: not laid down
conf 'pack workflow'
"$DEV" new q >/dev/null 2>&1 || fail "dev new exited $?"
[ ! -e "$HOME/Projects/q/CLAUDE.md" ] || fail "an unapproved pack's starter was laid down"
passed=$((passed + 1))

fresh new-two-packs         # a path in two starters: the first stays, the second is said
mkdir -p "$CLONE/packs/second/project/starter" && echo 'second' > "$CLONE/packs/second/project/starter/CLAUDE.md"
conf 'pack workflow' 'pack second'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
out=$("$DEV" new q 2>&1) || fail "dev new exited $?"
[ "$(head -n 1 "$HOME/Projects/q/CLAUDE.md")" = '# q' ] || fail "the second pack's CLAUDE.md won"
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
```

- [ ] **Step 2: Run, see them fail**

Run: `bash tests/test_dev.sh`
Expected: `test_dev FAIL (new-skeleton): no CLAUDE.md`

- [ ] **Step 3: Write the starter's files**

`CLAUDE.md`:

```markdown
# {{name}}

_What this project owns, in one paragraph: written at the first session._

## Start of a session

Read the three families top-down:

1. **Direction:** [docs/direction/backlog.md](docs/direction/backlog.md),
   the only status.
2. **Change:** the intent, spec or plan its current milestone links.
3. **System:** [the architecture](docs/system/architecture/README.md) and
   [the runbook](docs/system/runbook.md), before proposing anything.

## Commands

- `tests/run.sh`: the project's checks, Markdown links to begin with.
  Healthy output ends with `ALL PASSED`.

## Rules

_This project's own rules. Where it works differently from the company
default, one line here says so: "Differs from the company default:
<rule> (<why>)"._

## Neighbours' interfaces

_Links to the contracts of other projects this one relies on; none yet._
```

`docs/direction/backlog.md`: `# Backlog`, one sentence ("The ordered queue of milestones, each an outcome with acceptance criteria, and the only place with status."), `**Now:** nothing started.`, `## Later`. `docs/system/architecture/README.md`: `# Architecture`, "What {{name}} is, right now: C4 views, each with an element table below its diagram. None drawn yet." `docs/system/runbook.md`: `# Runbook`, "Steps to run, change and recover {{name}}. None yet." `.gitignore`: `out/`. `tests/run.sh`, in `tests/run.sh`'s own style:

```bash
#!/usr/bin/env bash
# The project's checks. Healthy output ends with ALL PASSED.
cd "$(dirname "$0")/.." || exit 1
status=0
echo "== Links"; python3 tests/check_links.py . || status=1
echo; if [ "$status" = 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; fi
exit "$status"
```

- [ ] **Step 4: Implement `lay_starters` and `dev new <folder>/<name>`**

In `dev`'s `new)`: the name matches `^([A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+$`; with a folder part, `$PROJECTS/<folder>` must be one of `group_folders` (else `die "<folder> is not a group folder of your config (group <folder>): dev new <name>"`, before anything is made); `mkdir -p` the folder. After `git init`, before the first commit: `printf '# %s\n' "${name##*/}" > README.md`, `lay_starters "${name##*/}"`, `git add -A`, commit "Start <name>" (the last segment). Add `tests/run.sh`'s starter copy to ShellCheck's list in `tests/run.sh`.

- [ ] **Step 5: Run, see them pass**

Run: `tests/run.sh`
Expected: `test_dev: <n> passed`, `links: … 0 problems`, `ALL PASSED`

- [ ] **Step 6: Commit**

```bash
git add dev box/lib/project.sh packs/workflow/project/starter tests
git commit -m "dev new lays down the approved packs' starters"
```

### Task 2: The layers rule, `starter.md`, your global `CLAUDE.md`

**Files:**
- Create: `packs/workflow/global/layers.md`
- Modify: `packs/workflow/project/rules/starter.md`, `tests/run.sh`
- Draft (only if D14 finds anything): `out/global-CLAUDE.md`

- [ ] **Step 1: Write the failing check** (in `tests/run.sh`, after Links)

```bash
echo; echo "== Layers rule"
rule=packs/workflow/global/layers.md
grep -qx '  - "\*\*/CLAUDE.md"' "$rule" && grep -qx '  - ".claude/rules/\*\*"' "$rule" \
  || { echo "layers.md: paths for **/CLAUDE.md and .claude/rules/** missing"; status=1; }
while IFS= read -r h; do
  grep -qF "$h" "$rule" || { echo "layers.md doesn't name the starter's section: $h"; status=1; }
done < <(sed -n 's/^## //p' packs/workflow/project/starter/CLAUDE.md)
```

- [ ] **Step 2: Run, see it fail**

Run: `tests/run.sh`
Expected: `layers.md: paths for **/CLAUDE.md and .claude/rules/** missing`, `SOME FAILED`

- [ ] **Step 3: Write `layers.md`**

Frontmatter `paths:` with `"**/CLAUDE.md"` and `".claude/rules/**"`, then D13 as rules: the table (company / global / project: holds, never holds), one fact one layer, a lower layer narrows and never loosens, the "Differs from the company default" line, and "A project's `CLAUDE.md` has these sections, in this order:" followed by the starter's headings (*what it owns* paragraph, Start of a session, Commands, Rules, Neighbours' interfaces). No links into this repo: it's read in every project.

- [ ] **Step 4: Rewrite `starter.md`**

```markdown
# The workflow pack's starter files

This project uses the workflow pack. `dev new` lays its starter files
down in a new project; they're in
`/usr/local/share/claude-box/packs/workflow/starter/` (read-only), laid
out as in a project. An existing project that adopts the pack copies
only `tests/check_links.py`, on a `claude/` branch, once, and runs it in
its test run; the rest of the starter is for new projects.
```

- [ ] **Step 5: Check your global `CLAUDE.md` against `layers.md` (D14)**

Read `~/.claude/CLAUDE.md`; a line that copies company policy (a rule the box's rules or a company pack already state) or holds a fact about one project is misplaced. If any: write `out/global-CLAUDE.md` without them (a draft for you, named in the summary). If none: say so in the summary.

- [ ] **Step 6: Run, see it pass**

Run: `tests/run.sh`
Expected: `ALL PASSED`

- [ ] **Step 7: Commit**

```bash
git add packs/workflow tests/run.sh
git commit -m "The layers rule; starter.md for dev new"
```

### Task 3: The docs

**Files:**
- Modify: `README.md`, `docs/system/architecture/README.md` (the packs table: the starter laid down by `dev new`, `layers.md` in the global part), `docs/system/runbook.md` ("New project": what `dev new` lays down, `dev new <group>/<name>`), `dev`'s header comment for `new`

- [ ] **Step 1: Write them**
- [ ] **Step 2: Run** `tests/run.sh`; expected `ALL PASSED`
- [ ] **Step 3: Commit** `git commit -m "Docs: what dev new lays down, the layers rule"`

After the last task: a fresh reviewer on the whole branch, then `out/actions.txt` with the merge and push.
