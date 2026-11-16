#!/usr/bin/env bash
# shellcheck disable=SC2024  # the log is yours: written as you, not as root
# The stranger test for the simpler-model acceptance (spec, Acceptance:
# "Setup with ./dev install alone"): a throwaway user, cbtest, follows the
# README's Quick start, cloning from a bundle of the branch you name (the
# repo is private), runs ./dev install with no terminal (the default identity,
# the login declined: no Claude account in the test), prints the
# ~/.claude/.dev it wrote, and starts a box. It also checks the fresh clone's
# top level. The user is removed whatever happens.
# Usage: stranger-test.sh <branch>. Needs sudo (asks once), ends with sudo -k.
# Full output: out/stranger-test.log (out/ is gitignored, so the merge after
# it sees a clean tree); only the result lines are printed.
set -uo pipefail
branch=${1:-}
[[ "$branch" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "Usage: stranger-test.sh <branch>"; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
log="$(git -C "$here" rev-parse --show-toplevel)/out/stranger-test.log"
bundle=/tmp/claude-box-cbtest.bundle

git -C "$here" rev-parse -q --verify "refs/heads/$branch" >/dev/null || { echo "no branch $branch"; exit 1; }
if id -u cbtest >/dev/null 2>&1; then echo "user cbtest exists: remove it first (sudo userdel -r cbtest)"; exit 1; fi
[ ! -e "$bundle" ] || { echo "$bundle exists: remove it first"; exit 1; }
mkdir -p "$(dirname "$log")" && : > "$log"
git -C "$here" bundle create "$bundle" "$branch" >> "$log" 2>&1 || { echo "no bundle (see $log)"; exit 1; }
chmod 644 "$bundle"

sudo useradd -m cbtest || { rm -f "$bundle"; exit 1; }
grep -q '^cbtest:' /etc/subuid && echo "cbtest got subordinate ids"

status=0
sudo machinectl -q shell cbtest@ /bin/bash -lc "
  set -e
  git clone -q -b '$branch' $bundle claude-box && cd claude-box
  [ '$branch' = main ] || git branch main   # dev builds from main: the branch under test is it
  echo LS-BEGIN; ls -A | grep -vx .git; echo LS-END
  ./dev install < /dev/null || true
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  echo CONF-BEGIN; grep -v '^#' ~/.claude/.dev | grep .; echo CONF-END
  mkdir -p ~/Projects/hello && cd ~/Projects/hello && git init -q
  # The first start asks to apply the config, and only in a terminal:
  # python3's pty gives dev shell one (Fedora has no script by default);
  # y answers it, as a new user would.
  printf '%s\n' y 'claude --version' 'git config --system user.email' exit \\
    | python3 -I -c 'import pty; pty.spawn([\"dev\", \"shell\"])'
  echo STRANGER-TEST-OK
  # Core's rules without the workflow (spec, Acceptance): the config without
  # plugin workflow, approved, then what a new box holds (--new: the
  # first phase's box may still run, and joining it applies nothing).
  sed -i '/^plugin workflow\$/d' ~/.claude/.dev
  printf '%s\n' y 'echo CORE-BEGIN; ls -1 /etc/claude-code /usr/local/share/claude-box/plugins/box-workflow/skills; echo CORE-END; if [ -e ~/.claude/rules/workflow/documentation.md ]; then echo WORKFLOW-RULES-THERE; else echo WORKFLOW-RULES-GONE; fi' exit \\
    | python3 -I -c 'import pty; pty.spawn([\"dev\", \"shell\", \"--new\"])'" >> "$log" 2>&1
# machinectl's terminal ends each line with \r: drop it before matching.
result=$(tr -d '\r' < "$log")
grep -qx 'STRANGER-TEST-OK' <<< "$result" && echo "the Quick start ran to the end" || { echo "the Quick start stopped (see $log)"; status=1; }
grep -m1 -E '^[0-9.]+ \(Claude Code\)$' <<< "$result" || { echo "claude --version didn't run in the box"; status=1; }
grep -m1 -x 'claude@claude-box.invalid' <<< "$result" || { echo "the public identity didn't show"; status=1; }
top=$(sed -n '/^LS-BEGIN$/,/^LS-END$/p' <<< "$result" | sed '1d;$d' | LC_ALL=C sort | tr '\n' ' ')
want='.gitignore LICENSE README.md core dev docs plugins tests '
[ "$top" = "$want" ] && echo "the top level: $top" || { echo "the top level is '$top', not '$want'"; status=1; }
conf=$(sed -n '/^CONF-BEGIN$/,/^CONF-END$/p' <<< "$result" | sed '1d;$d')
echo "the config ./dev install wrote:"; sed 's/^/  /' <<< "$conf"
grep -qx 'identity Claude <claude@claude-box.invalid>' <<< "$conf" && grep -qx 'plugin workflow' <<< "$conf" \
  || { echo "the config lacks the identity or plugin workflow"; status=1; }
core=$(sed -n '/^CORE-BEGIN$/,/^CORE-END$/p' <<< "$result" | sed '1d;$d' | grep -v 'CORE-END')
echo "without the workflow, the box holds:"; sed 's/^/  /' <<< "$core"
grep -qx 'CLAUDE.md' <<< "$core" && grep -qx 'dev-run' <<< "$core" \
  || { echo "without the workflow, core's rules or the dev-run skill are missing"; status=1; }
grep -qx 'WORKFLOW-RULES-GONE' <<< "$result" && echo "the new box has no workflow rules" \
  || { echo "the box without the workflow didn't start, or still has its rules"; status=1; }

# Remove the user: end its session (its systemd manager, Podman's pause
# process) first, or userdel refuses.
sudo loginctl terminate-user cbtest >> "$log" 2>&1
for _ in 1 2 3 4 5; do
  sleep 2
  sudo userdel -r cbtest >> "$log" 2>&1 && break
done
if id -u cbtest >/dev/null 2>&1; then echo "user cbtest is still there (see $log)"; status=1
else echo "user cbtest removed"; fi
if sudo grep -q '^cbtest:' /etc/subuid /etc/subgid; then
  echo "cbtest's lines are still in /etc/subuid or /etc/subgid"; status=1
else echo "no cbtest line in /etc/subuid or /etc/subgid"; fi
rm -f "$bundle"
sudo -k
exit $status
