#!/usr/bin/env bash
# All checks: Markdown links, dev, run-actions, the mods and ShellCheck.
# Run before every commit, from anywhere: tests/run.sh
# Exit status: 0 = all passed.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
status=0
echo "== Links";      python3 plugins/workflow/starter/tests/check_links.py . || status=1
echo; echo "== Rules"
# The workflow plugin's claude-md rule loads on CLAUDE.md and rules files, and
# names every section of the starter's CLAUDE.md, so the two don't drift.
rule=plugins/workflow/rules/claude-md.md
if grep -qx '  - "\*\*/CLAUDE.md"' "$rule" && grep -qx '  - ".claude/rules/\*\*"' "$rule"; then
  while IFS= read -r h; do
    grep -qF "$h" "$rule" || { echo "claude-md.md doesn't name the starter's section: $h"; status=1; }
  done < <(sed -n 's/^## //p' plugins/workflow/starter/CLAUDE.md.starter)
else echo "claude-md.md: paths for **/CLAUDE.md and .claude/rules/** missing"; status=1; fi
# Core's rules: Claude Code reads only /etc/claude-code/CLAUDE.md, which
# imports the others; each import names a file of core/rules/, each file
# there is imported.
imports=$(sed -n 's|^@/etc/claude-code/||p' core/rules/CLAUDE.md)
for f in $imports; do [ -f "core/rules/$f" ] || { echo "core/rules/CLAUDE.md imports a missing file: $f"; status=1; }; done
for f in core/rules/*.md; do
  f=${f##*/}; [ "$f" = CLAUDE.md ] && continue
  grep -qx "$f" <<< "$imports" || { echo "core/rules/$f isn't imported by core/rules/CLAUDE.md"; status=1; }
done
grep -qx 'COPY rules/ /etc/claude-code/' core/Containerfile || { echo "Containerfile doesn't copy rules/ to /etc/claude-code/"; status=1; }
! grep -q 'local\.md' core/Containerfile || { echo "Containerfile still names local.md"; status=1; }
# The words that left the user's view (D1).
old=$(grep -rniwE 'company|packs?|layers?' core/rules plugins/workflow/rules) && { echo "rules use old words:"; echo "$old"; status=1; }
skill=core/plugin/box-workflow/skills/dev-run/SKILL.md
{ [ -f "$skill" ] && sed -n '2,/^---$/p' "$skill" | grep -qx 'name: dev-run' && grep -qF '/etc/claude-box/host' "$skill"; } \
  || { echo "$skill: missing, or without name: dev-run or /etc/claude-box/host"; status=1; }
echo "rules: checked"
echo; echo "== README"
# Its table under "What's in this repo" names exactly the top-level items:
# each tracked one, and out/. It never names tests/private-terms (D12: not
# part of a user's setup).
want=$( { git ls-files | cut -d/ -f1; printf '%s\n' out; } | sort -u)
have=$(awk '/^## /{ t = ($0 == "## What'"'"'s in this repo") } t && /^\| `/' README.md \
  | cut -d'`' -f2 | sed 's|/$||' | sort -u)
[ "$have" = "$want" ] || { echo "README: its table differs from the top level:"; diff <(echo "$want") <(echo "$have"); status=1; }
! grep -qiE 'private[- ]terms' README.md || { echo "README: names private-terms"; status=1; }
# The model's words only (spec D1), a table of what you change, and a map
# for core and the workflow plugin (D14, D15).
old=$(sed 's/layer\.sh//g' README.md core/README.md plugins/workflow/README.md | grep -niwE 'company|packs?|layers?' 2>&1) \
  && { echo "README and maps use old words:"; echo "$old"; status=1; }
grep -qx '| To change | Edit | It applies |' README.md \
  || { echo "README: no table of what you change"; status=1; }
for m in core/README.md plugins/workflow/README.md; do
  grep -qx '## Map' "$m" 2>/dev/null || { echo "$m: no ## Map"; status=1; }
done
! grep -q 'local/' .gitignore || { echo ".gitignore still names local/"; status=1; }
echo; echo "== Private terms"
# The check itself, on a throwaway repo: a term of tests/private-terms in a
# tracked file fails, its absence passes. Then this repo.
pt=$(mktemp -d)
( cd "$pt" && git init -q && echo 'hello Secretname' > a.txt && git add a.txt \
  && mkdir tests && echo 'secretname' > tests/private-terms ) || status=1
out=$(python3 tests/check_private_terms.py "$pt" 2>&1) && { echo "private terms: a match passed"; status=1; }
grep -q 'a.txt:1' <<< "$out" || { echo "private terms: match not named: $out"; status=1; }
echo 'hello' > "$pt/a.txt"
python3 tests/check_private_terms.py "$pt" > /dev/null || { echo "private terms: a clean repo failed"; status=1; }
rm -r "$pt"
# A path marked export-ignore never leaves this repo: skipped; the same
# term elsewhere still fails.
pt=$(mktemp -d)
( cd "$pt" && git init -q && mkdir old tests && echo 'Secretname' > old/a.txt \
  && echo 'Secretname' > b.txt && echo 'old/** export-ignore' > .gitattributes \
  && git add -A && echo 'secretname' > tests/private-terms ) || status=1
out=$(python3 tests/check_private_terms.py "$pt" 2>&1) && { echo "private terms: a match beside a marked path passed"; status=1; }
grep -q 'b.txt:1' <<< "$out" || { echo "private terms: match not named: $out"; status=1; }
! grep -q 'old/a.txt' <<< "$out" || { echo "private terms: a marked path was checked"; status=1; }
rm -r "$pt"
# Where .gitattributes marks the old records (not in the public repo): the
# export (git archive) holds this change's record and no other, and no
# .gitattributes. Of the working tree (a snapshot that moves no ref, and the
# working copy's attributes): the checks pass before the commit.
if [ -e .gitattributes ]; then
  snap=$(git stash create); snap=${snap:-HEAD}
  paths=$(git archive --worktree-attributes "$snap" | tar -t)
  grep -qx 'docs/change/2026-10-30-publishing/spec.md' <<< "$paths" || { echo "export: this change's record is missing"; status=1; }
  other=$(grep '^docs/change/' <<< "$paths" | grep -v -e '^docs/change/$' -e '^docs/change/2026-10-30-publishing/')
  [ -z "$other" ] || { echo "export: holds other records: $(head -3 <<< "$other")"; status=1; }
  ! grep -qx '.gitattributes' <<< "$paths" || { echo "export: holds .gitattributes"; status=1; }
  # Its links resolve without the records left behind.
  ex=$(mktemp -d)
  git archive --worktree-attributes "$snap" | tar -x -C "$ex" && ( cd "$ex" && git init -q && git add -A ) \
    && python3 plugins/workflow/starter/tests/check_links.py "$ex" > "$ex.log" 2>&1 \
    || { echo "export: broken links ($(tail -1 "$ex.log"))"; status=1; }
  rm -rf "$ex" "$ex.log"
fi
python3 tests/check_private_terms.py || status=1
echo; echo "== Managed settings"; python3 tests/check_managed_settings.py || status=1
# Under a terminal, as in dev run: a test that waits for an answer fails
# (timeout) instead of hanging. Without the box's /etc/gitconfig, as on
# your machine: the tests bring their own git identity.
echo; echo "== dev";  timeout 300 python3 -c 'import os, pty, sys
sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' env GIT_CONFIG_NOSYSTEM=1 bash tests/test_dev.sh < /dev/null || status=1
echo; echo "== run-actions"
GIT_CONFIG_NOSYSTEM=1 timeout 60 bash tests/test_run_actions.sh < /dev/null || status=1
echo; echo "== Mods"
if command -v claude >/dev/null; then
  claude plugin validate core/plugin/box-workflow >/dev/null && claude plugin test core/plugin/box-workflow \
    || status=1
else
  echo "mods: skipped (no claude here; run tests/run.sh in the box)"
fi
echo; echo "== ShellCheck"
# A record's script, only where the records are (not in the public export).
records=(); [ ! -e docs/change/2026-10-17-shared-box-odd-cases/check.sh ] \
  || records=(docs/change/2026-10-17-shared-box-odd-cases/check.sh)
# -x -a: dev with its modules (core/lib/), warnings in them included.
shellcheck -S warning -x -a dev core/bin/run-actions core/bin/stage-seed tests/run.sh tests/test_dev.sh plugins/workflow/starter/tests/run.sh \
  "${records[@]}" tests/test_run_actions.sh docs/change/2026-10-30-clear-layout/stranger-test.sh \
  docs/change/2026-10-31-simpler-model/stranger-test.sh \
  && echo "shellcheck: clean" || status=1
echo; [ "$status" = 0 ] && echo "ALL PASSED" || echo "SOME FAILED"
exit $status
