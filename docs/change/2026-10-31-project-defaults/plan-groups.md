# Groups and trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Projects in one group know each other's names and paths, and with `autotake group` in your config their messages go on as your prompt.

**Architecture:** `dev` works out the project's group at each box start (a group folder from your config, or a `group` line in `.dev` after your yes, plus `remote` lines) and mounts one file, `/etc/claude-box/groups`, read-only into the box. box-workflow reads that file at session start and lets members through beside the `/autotake` list, never storing them. The box's rules tell Claude where the file is and how neighbours work together.

**Tech Stack:** Bash (`dev`, `box/lib/`), TypeScript mods (box-workflow, `claude plugin test`), Markdown rules.

**Spec:** [spec.md](spec.md) (D1–D9, D12), for the [intent](intent.md).

Branch `claude/groups`, from `main` after `claude/project-defaults` (spec and this plan) is merged.

## Global Constraints

- A group folder is under your `projects` folder; its group's name is the folder's name; every git repo directly in it is a member (D1).
- `.dev` `group <name>` counts only after your yes, kept by the project's path outside the box's reach; a project is in one group at most, `dev` refuses a second (D2).
- A project whose `.dev` line or folder is gone is no member; a kept yes for it is ignored (D3).
- `/etc/claude-box/groups`, read-only: the group, each other member's name and its path under `/projects` or `remote`, and the trust line; a scratch has none (D4).
- Group members are never written to box-workflow's store and never offered back; `/autotake off` turns them off for the session (D5).
- `remote <group> <name>` in your config: a member on another machine, `remote` in the file (D6).
- Match: the member's name, or it plus `-` and 1–4 of `[a-z0-9]` (D7).
- `box/defaults.conf` documents `group`, `remote`, `autotake`; `dev init`'s starter config has `autotake group`; the README says what it lets through and how to switch it off (D9).
- Checks pass before every commit: `tests/run.sh` ends with `ALL PASSED` (Mods run only in the box).

## Review Focus

- A group folder written with a trailing `/` or through `~`: it's the same folder, members found.
- A group folder outside the `projects` folder: refused with a message naming the line, not silently empty.
- A member folder with a space in its name: its line in the file stays one member with one path.
- Two group folders with the same last name (`~/Projects/a/app`, `~/Projects/b/app`): refused in the config, since they'd be one group by name.
- A sender named like a member with a longer suffix (`app-backend` against member `app`): held, not taken.

Each has its test in the task that owns the code.

## File Structure

| File | Change |
|---|---|
| `box/lib/conf.sh` | `read_conf`: kinds `group`, `remote`, `autotake` |
| `box/lib/project.sh` | `read_dev`, `dev_edit`, `valid_group`: `.dev` kind `group` |
| `box/lib/groups.sh` (new) | The project's group, its members, the yes, the file, the refusal of a group folder |
| `box/lib/mounts.sh` | `choose_mounts` adds the groups file |
| `dev` | sources `groups.sh`; `dev init`'s starter config; `refuse_group_folder` before project commands |
| `box/defaults.conf` | the three kinds explained |
| `box/plugin/box-workflow/types/index.d.ts` | `Groups` type, `group` and `groupTrust` state |
| `box/plugin/box-workflow/hooks/lines.ts` | `parseGroups`, `matchesMember`, `autoLine`, `senderCopy` |
| `box/plugin/box-workflow/hooks/register.tsx` | read the file, take members, listing, `/autotake off` |
| `box/company/CLAUDE.md`, `box/company/managed-settings.json` | D12's lines; autotake as the inbox's exception |
| `README.md`, `docs/system/architecture/*`, `docs/system/runbook.md` | what changed, D7's known limit |
| `tests/test_dev.sh`, `box/plugin/box-workflow/hooks/inbox.test.ts` | the tests below |

---

### Task 1: The config's kinds `group`, `remote`, `autotake`

**Files:**
- Modify: `box/lib/conf.sh` (`read_conf`)
- Modify: `box/defaults.conf`, `dev` (the `init` branch's starter config)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Produces: `read_conf` prints `group <folder as written>`, `remote <group> <name>`, `autotake group`; refuses a second `group` folder with the same last name, `autotake` with any other value, names outside `^[A-Za-z0-9][A-Za-z0-9._-]*$`.

- [ ] **Step 1: Write the failing tests** (after the existing config-kind tests, same style)

```bash
fresh conf-groups
conf 'group ~/Projects/app/' 'remote app phone-app' 'autotake group'
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "the three kinds refused"
for bad in 'autotake on' 'remote app' 'remote app bad/name' 'group relative/app'; do
    conf "$bad"
    out=$(dev_in_p shell 2>&1) && fail "accepted: $bad"
    grep -qF "can't use" <<< "$out" || fail "no refusal for $bad: $out"
done
conf 'group ~/Projects/a/app' 'group ~/Projects/b/app'
out=$(dev_in_p shell 2>&1) && fail "two groups named app accepted"
grep -qF 'line 2' <<< "$out" || fail "doesn't name the line: $out"
passed=$((passed + 1))

case=init-autotake       # the starter config dev init writes
sed -n '/^    init)/,/;;/p' "$DEV" | grep -qF "'autotake group'" \
    || fail "dev init's starter config lacks autotake group"
passed=$((passed + 1))
```

- [ ] **Step 2: Run, see them fail**

Run: `bash tests/test_dev.sh`
Expected: `test_dev FAIL (conf-groups): the three kinds refused`

- [ ] **Step 3: Implement the kinds in `read_conf`**

`group`: `$projects`'s pattern, a trailing `/` dropped for the name check; its last segment must be new among this file's groups (track as `globals` is tracked). `remote`: two words, both matching the name pattern. `autotake`: `group` only. Add the three to `box/defaults.conf` under "Everything else", in its style:

```
#   group <folder>             your projects directly in this folder (under
#                              projects) are one group, named after it
#     group ~/Projects/app
#   remote <group> <name>      a project of that group that lives only on
#                              another of your machines (its session name)
#     remote app app-phone
#   autotake group             your group's members' messages go on as your
#                              prompt, as /autotake <member> would; others
#                              are held. dev init's config has it
```

In `dev`'s `init` branch, add `'autotake group'` as the starter config's third line.

- [ ] **Step 4: Run, see them pass**

Run: `bash tests/test_dev.sh`
Expected: `test_dev: <n> passed`

- [ ] **Step 5: Commit**

```bash
git add box/lib/conf.sh box/defaults.conf dev tests/test_dev.sh
git commit -m "Groups: the config's kinds group, remote and autotake"
```

### Task 2: The `.dev` kind `group`

**Files:**
- Modify: `box/lib/project.sh` (`read_dev`, `dev_edit`, new `valid_group`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Produces: `valid_group <name>` (same pattern as `valid_pack`); `read_dev` prints `group <name>`, dies on a second `group` line ("one group per project"); `dev add group <name>` / `dev remove group <name>`, refusing an add when `.dev` already has another group.

- [ ] **Step 1: Write the failing tests**

```bash
fresh dev-group
dev_in_p add group app >/dev/null || fail "dev add group exited $?"
grep -qx 'group app' "$HOME/Projects/p/.dev" || fail "no group line"
out=$(dev_in_p add group other 2>&1) && fail "a second group added"
grep -qF 'one group' <<< "$out" || fail "no reason: $out"
printf 'group app\ngroup other\n' > "$HOME/Projects/p/.dev"
out=$(dev_in_p shell 2>&1) && fail "two group lines accepted"
grep -qF 'one group' <<< "$out" || fail "no reason: $out"
dev_in_p add group 'bad/name' >/dev/null 2>&1 && fail "a bad name added"
passed=$((passed + 1))
```

- [ ] **Step 2: Run, see it fail**

Run: `bash tests/test_dev.sh`
Expected: `test_dev FAIL (dev-group): dev add group exited 1`

- [ ] **Step 3: Implement**

`read_dev`: case `group)` like `pack)` with `valid_group`, and a counter that dies `.dev line $n: one group per project`. Its unknown-kind message and `dev_edit`'s usage name `group`. `dev_edit`: kind `group` validated like `pack`; on add, refuse when another `group` line exists.

- [ ] **Step 4: Run, see it pass**

Run: `bash tests/test_dev.sh`
Expected: `test_dev: <n> passed`

- [ ] **Step 5: Commit**

```bash
git add box/lib/project.sh tests/test_dev.sh
git commit -m "Groups: the .dev kind group, dev add group"
```

### Task 3: The project's group and `/etc/claude-box/groups`

**Files:**
- Create: `box/lib/groups.sh`
- Modify: `box/lib/mounts.sh` (`choose_mounts`), `dev` (source it; `refuse_group_folder` for `claude`, `shell`, `add|remove`, `plugins`)
- Test: `tests/test_dev.sh`

**Interfaces:**
- Consumes: Task 1's config items (from `approved_items`), Task 2's `read_dev`, `PROJECTS`, `APPROVED`, `ask`.
- Produces:
  - `group_folders`: prints each configured group folder as a real path, one per line; dies `local/claude-box.conf: group <folder>: not in your projects folder (<PROJECTS>)` for one outside it.
  - `refuse_group_folder`: dies `<PWD> is a group folder: start Claude in one of its projects` when `$PWD` is one.
  - `project_group`: prints the project's group name or nothing. Folder group: `$PWD`'s parent is a group folder. Name group: `.dev`'s `group <name>`, counted after a yes in `$STATE/group-yes` (`STATE="$(dirname "$APPROVED")"`, lines `<group> <real path>`); asked with `ask "This project's .dev puts it in group <name>: its members' messages may go on as your prompt. Count it in?"`, yes appended; no or no terminal: prints `Not in group <name>: no yes for it.` to stderr and counts no group. Both kinds with different names: dies `This project is in group <a> (its folder) and <b> (.dev): one group per project`.
  - `group_file <group> <out>`: writes `group <name>`, then `member <name> <path>` for every other member (folder members; yes'd projects whose folder exists and whose `.dev` still says the group; `remote` lines as `member <name> remote`), sorted by name, then `autotake group` if the config has it. `<path>` is `/projects/<path under PROJECTS>`, or `remote` for a member outside it.
  - `choose_mounts`, outside a scratch, with a group: writes `$STATE/groups/<basename of PWD>` and adds `-v <it>:/etc/claude-box/groups:ro,z`.

- [ ] **Step 1: Write the failing tests**

```bash
# group_fixture: ~/Projects/app/{a,b,c d} as repos, the config approved.
group_fixture() {
    for d in a b 'c d'; do mkdir -p "$HOME/Projects/app/$d" && git -C "$HOME/Projects/app/$d" init -q; done
    conf "$@"
    echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "approving exited $?"
    : > "$LOG"
}
gfile() { cat "$HOME/.local/state/claude-box/groups/$1"; }

fresh group-folder
group_fixture 'group ~/Projects/app/' 'remote app phone' 'autotake group'
(cd "$HOME/Projects/app/a" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell exited $?"
has "$HOME/.local/state/claude-box/groups/a:/etc/claude-box/groups:ro,z"
[ "$(gfile a)" = "$(printf 'group app\nmember b /projects/app/b\nmember c d /projects/app/c d\nmember phone remote\nautotake group')" ] \
    || fail "file: $(gfile a)"
passed=$((passed + 1))

fresh group-no-autotake
group_fixture 'group ~/Projects/app'
(cd "$HOME/Projects/app/a" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell exited $?"
gfile a | grep -q autotake && fail "autotake without the line"
passed=$((passed + 1))

fresh group-outside-projects
mkdir -p "$tmp/elsewhere/app"
group_fixture "group $tmp/elsewhere/app"
out=$(dev_in_p shell 2>&1) && fail "a group folder outside projects accepted"
grep -qF 'not in your projects folder' <<< "$out" || fail "no reason: $out"
passed=$((passed + 1))

fresh group-folder-refused
group_fixture 'group ~/Projects/app'
out=$(cd "$HOME/Projects/app" && "$DEV" shell 2>&1) && fail "the group folder started a box"
grep -qF 'is a group folder' <<< "$out" || fail "no reason: $out"
not_called run
passed=$((passed + 1))

fresh group-name-yes      # p joins app by its .dev, after your yes
group_fixture 'group ~/Projects/app'
echo 'group app' > "$HOME/Projects/p/.dev"
echo y | (cd "$HOME/Projects/p" && tty_run "$DEV" shell) >/dev/null || fail "dev shell exited $?"
grep -qx "app $HOME/Projects/p" "$HOME/.local/state/claude-box/group-yes" || fail "the yes isn't kept"
(cd "$HOME/Projects/app/a" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell in a exited $?"
gfile a | grep -qx 'member p /projects/p' || fail "p not a member: $(gfile a)"
case=group-member-gone
rm "$HOME/Projects/p/.dev"
(cd "$HOME/Projects/app/a" && "$DEV" shell) >/dev/null 2>&1 || fail "dev shell in a exited $?"
gfile a | grep -q 'member p ' && fail "p still a member without its line"
passed=$((passed + 1))

fresh group-name-no       # no, or no terminal: not counted
group_fixture 'group ~/Projects/app'
echo 'group app' > "$HOME/Projects/p/.dev"
out=$(echo n | (cd "$HOME/Projects/p" && tty_run "$DEV" shell)) || fail "dev shell exited $?"
grep -qF 'Not in group app' <<< "$out" || fail "doesn't say so: $out"
out=$(dev_in_p shell 2>&1) || fail "dev shell exited $?"
grep -qF 'Not in group app' <<< "$out" || fail "no terminal: doesn't say so: $out"
[ ! -s "$HOME/.local/state/claude-box/group-yes" ] || fail "a yes was kept"
hasnt /etc/claude-box/groups
passed=$((passed + 1))

fresh group-two           # a folder member whose .dev names another group
group_fixture 'group ~/Projects/app'
echo 'group other' > "$HOME/Projects/app/a/.dev"
out=$(cd "$HOME/Projects/app/a" && echo y | tty_run "$DEV" shell 2>&1) && fail "two groups accepted"
grep -qF 'one group per project' <<< "$out" || fail "no reason: $out"
passed=$((passed + 1))

fresh group-none          # no group: no file, no mount
dev_in_p shell >/dev/null 2>&1 || fail "dev shell exited $?"
hasnt /etc/claude-box/groups
passed=$((passed + 1))
```

- [ ] **Step 2: Run, see them fail**

Run: `bash tests/test_dev.sh`
Expected: `test_dev FAIL (group-folder): podman was not called with: …/groups/a:/etc/claude-box/groups:ro,z`

- [ ] **Step 3: Implement `box/lib/groups.sh` and wire it in**

The functions in Interfaces, in the modules' style (a header comment, one comment per function). `dev` sources it after `mounts.sh` (with its `# shellcheck source=` line) and calls `refuse_group_folder` before `is_project` in the `claude`, `shell`, `add|remove` and `plugins` branches. `choose_mounts` calls `project_group` and `group_file` after its scratch return, so only outside a scratch.

- [ ] **Step 4: Run, see them pass; ShellCheck clean**

Run: `tests/run.sh`
Expected: `test_dev: <n> passed`, `shellcheck: clean`

- [ ] **Step 5: Commit**

```bash
git add box/lib/groups.sh box/lib/mounts.sh dev tests/test_dev.sh
git commit -m "Groups: the project's group, the yes, /etc/claude-box/groups"
```

### Task 4: box-workflow lets group members through

**Files:**
- Modify: `box/plugin/box-workflow/types/index.d.ts`, `hooks/lines.ts`, `hooks/register.tsx`
- Test: `box/plugin/box-workflow/hooks/inbox.test.ts`

**Interfaces:**
- Consumes: the file's format from Task 3.
- Produces:
  - `type Groups = { name: string; members: { name: string; path: string }[]; autotake: boolean }` (types); state `group: Groups | null`, `groupTrust: boolean`.
  - `parseGroups(text: string): Groups | null` (lines.ts): `group <name>` first, `member <name> <path…>` (the path is the rest of the line, spaces kept), `autotake group`; null without a `group` line.
  - `matchesMember(sender: string, member: string): boolean`: D7.
  - `autoLine(senders: readonly string[], group: { name: string; members: readonly string[] } | null): string`.
  - `senderCopy(project: string, from: string | null, path: string | null): string`.

- [ ] **Step 1: Write the failing tests**

`world(on, store, groups?)` gains a third argument: the file's text; its `process.run` answers `['cat', '/etc/claude-box/groups']` with `exitCode: 0, stdout: groups` when given, as today otherwise.

```ts
const GROUPS = 'group app\nmember beta /projects/app/beta\nmember phone remote\nautotake group\n'

test('a group member is taken as your prompt; a sender outside the group is held', async ($, on) => {
  const w = world(on, {}, GROUPS)
  await $.session.start(START)
  await $.session.receive({ origin: { kind: 'peer' }, text: from('beta', MSG) })
  await $.session.receive({ origin: { kind: 'peer' }, text: from('beta-d2', MSG) })
  await $.session.receive({ origin: { kind: 'peer' }, text: from('gamma', MSG) })
  await w.clock.advance(0)
  expect(w.submitted).toEqual([autoGroup(from('beta', MSG)), autoGroup(from('beta-d2', MSG))])
  expect(w.toasts).toContain('Held for you: From beta: proposes svc-beta v0.3')
  expect(w.store).toEqual({})
})

test('matching: the name, or it plus - and 1-4 of a-z0-9', () => {
  expect(matchesMember('beta', 'beta')).toBe(true)
  expect(matchesMember('beta-d2', 'beta')).toBe(true)
  expect(matchesMember('beta-backend', 'beta')).toBe(false)
  expect(matchesMember('beta-D2', 'beta')).toBe(false)
  expect(matchesMember('betax', 'beta')).toBe(false)
})

test('without autotake group, members are held', async ($, on) => {
  const w = world(on, {}, 'group app\nmember beta /projects/app/beta\n')
  await $.session.start(START)
  await $.session.receive({ origin: { kind: 'peer' }, text: from('beta', MSG) })
  expect(w.submitted).toEqual([])
})

test('/autotake off holds members too; /autotake lists them beside your own', async ($, on) => {
  const w = world(on, {}, GROUPS)
  await $.session.start(START)
  let r = await $.command.run({ command: 'autotake', args: 'delta', origin: { kind: 'composer' }, presentation: P })
  expect(r.text).toBe('Taking messages from group app (beta, phone) and from delta as your prompt until /autotake off.')
  r = await $.command.run({ command: 'autotake', args: 'off', origin: { kind: 'composer' }, presentation: P })
  expect(r.text).toBe('Autotake is off; messages are held for you.')
  await $.session.receive({ origin: { kind: 'peer' }, text: from('beta', MSG) })
  expect(w.submitted).toEqual([])
  expect(w.store).toEqual({})
})

test('with a group on, your own list is still offered back, and members pass while it waits', async ($, on) => {
  const w = world(on, { 'autotake:alpha': ['delta'] }, GROUPS)
  await $.session.start(START)
  const ui = await $.ui.mount({ plugin: 'box-workflow', surface: 'terminal', ...BAND })
  expect(await ui.find({ text: 'Autotake was on last session for delta ' })).toBeDefined()
  await $.session.receive({ origin: { kind: 'peer' }, text: from('beta', MSG) })
  await w.clock.advance(0)
  expect(w.submitted).toEqual([autoGroup(from('beta', MSG))])
  expect(w.store).toEqual({ 'autotake:alpha': ['delta'] })
})

test("Read names the sender's copy at its path, or on another machine", () => {
  expect(senderCopy('alpha', 'beta', '/projects/app/beta')).toBe('If this session ends first, the sender\'s copy stays: /projects/app/beta/out/handoff-alpha.md')
  expect(senderCopy('alpha', 'phone', 'remote')).toBe("If this session ends first, the sender's copy stays in its project, on another machine.")
})
```

`matchesMember` and `senderCopy` are imported from `./lines`. `autoGroup(text)` is `` `Message from another session (let through by your autotake group):\n\n${text}` ``; the toast for a taken member is `Taken by autotake group: <first line>`.

- [ ] **Step 2: Run, see them fail** (in the box)

Run: `claude plugin test box/plugin/box-workflow`
Expected: the new tests fail (`parseGroups`/`matchesMember` not exported)

- [ ] **Step 3: Implement**

At `session.start`, before `offerAutotake`: run `cat /etc/claude-box/groups`; exit 0 → `group = parseGroups(stdout)`, `groupTrust = group?.autotake ?? false`; anything else → null, false. In `session.receive`, after the `/autotake` list check: `groupTrust` and a member matching `from` → submit `autoText`'s group form and toast as above. `/autotake off` also sets `groupTrust` false; `/autotake on|<sender>` leaves it. `offerAutotake` reads only the own list (the group never enters it). Read's `senderCopy` gets the member's path when the sender matches one, else null (as today: `/projects/<sender>/…`).

- [ ] **Step 4: Run, see them pass** (in the box)

Run: `tests/run.sh`
Expected: Mods all pass, `ALL PASSED`

- [ ] **Step 5: Commit**

```bash
git add box/plugin/box-workflow
git commit -m "Groups: box-workflow lets the group's members through"
```

### Task 5: The rules, the description for auto mode, the docs

**Files:**
- Modify: `box/company/CLAUDE.md`, `box/company/managed-settings.json`, `README.md`, `docs/system/architecture/README.md`, `docs/system/architecture/02-container.md`, `docs/system/architecture/03-deployment.md`, `docs/system/runbook.md`

- [ ] **Step 1: The rules** (`box/company/CLAUDE.md`, after the inbox bullet)

Change the inbox bullet's first sentence to "A message from another session waits in your box's inbox until the human takes it into the prompt, or goes on as their prompt when they let its sender through (autotake)." and its path to "in the sender's project (`/projects/<sender>/`, or the path `/etc/claude-box/groups` gives)". Add:

```
- Your project's group, if it has one, is in `/etc/claude-box/groups`:
  each other member's project name and its path under `/projects`, or
  `remote` (on another of the human's machines: ask it, you can't read
  it). Read a member's README before messaging it. The project that
  provides an interface others use owns its contract in its own docs;
  a member using it links there, and a change to an interface a member
  relies on is told to it by a handoff. A message let through by
  autotake is still another session's request; one that needs no
  answer gets none. A cloud session's answer stays in its transcript.
```

- [ ] **Step 2: The description** (`managed-settings.json`)

Replace "the receiving box holds each one until the owner releases it" with "the receiving box holds each one until the owner releases it, unless the owner let its sender through (autotake: senders the owner named, or their project's group members when the owner's config says so)".

- [ ] **Step 3: The docs**

README: one sentence where the config is described: "`autotake group`, in the config `dev init` writes: messages from your sessions of a group's projects go on as your prompt without **Take it**; delete the line to have them held." Architecture: the inbox row (group members, `/autotake off`), the config's and `.dev`'s kinds (02-container), `/etc/claude-box/groups` and `group-yes` (03-deployment), and under Known limits: "**A session named like a group member plus a short suffix is taken as that member** (`app-v2` for `app`): within your own account; a miss is held." Runbook: "Make a group" (a folder line, or `dev add group <name>` and your yes; `remote` for one on another machine; `autotake group`).

- [ ] **Step 4: Run**

Run: `tests/run.sh`
Expected: `links: … 0 problems`, `managed settings: ok`, `ALL PASSED`

- [ ] **Step 5: Commit**

```bash
git add box/company README.md docs/system
git commit -m "Groups: the rules, the description for auto mode, the docs"
```

After the last task: a fresh reviewer on the whole branch, then `out/actions.txt` with the merge and push for `dev run`.
