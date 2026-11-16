#!/usr/bin/env bash
# shellcheck disable=SC2024  # the log is yours: written as you, not as root
# The stranger test (spec D8): a throwaway user, cbtest, follows the README's
# Quick start, cloning from a bundle of the new repo's commit (the repo is
# private), runs `dev build` in place of `dev init` (no Claude login), and
# starts a box on the public defaults. The user is removed whatever happens.
# Needs sudo (asks once), ends with sudo -k. Full output: out/stranger-test.log;
# only the result lines are printed.
set -uo pipefail
log="$(cd "$(dirname "$0")" && pwd)/stranger-test.log"
bundle=/tmp/claude-box-cbtest.bundle
export_dir="$HOME/.cache/claude-box-export"

if id -u cbtest >/dev/null 2>&1; then echo "user cbtest exists: remove it first (sudo userdel -r cbtest)"; exit 1; fi
[ ! -e "$bundle" ] || { echo "$bundle exists: remove it first"; exit 1; }
: > "$log"
git -C "$export_dir" bundle create "$bundle" HEAD main >> "$log" 2>&1 || { echo "no bundle (see $log)"; exit 1; }
chmod 644 "$bundle"

sudo useradd -m cbtest || exit 1
grep -q '^cbtest:' /etc/subuid && echo "cbtest got subordinate ids"

status=0
sudo machinectl -q shell cbtest@ /bin/bash -lc '
  set -e
  git clone -q /tmp/claude-box-cbtest.bundle claude-box && cd claude-box
  ./install.sh
  export PATH="$HOME/.local/bin:$PATH"
  dev build < /dev/null
  mkdir -p ~/Projects/hello && cd ~/Projects/hello && git init -q
  printf "%s\n" "claude --version" "git config --system user.email" | dev shell
  echo STRANGER-TEST-OK' >> "$log" 2>&1
# machinectl's terminal ends each line with \r: drop it before matching.
result=$(tr -d '\r' < "$log")
grep -qx 'STRANGER-TEST-OK' <<< "$result" && echo "the Quick start ran to the end" || { echo "the Quick start stopped (see $log)"; status=1; }
grep -m1 -E '^[0-9.]+ \(Claude Code\)$' <<< "$result" || { echo "claude --version didn't run in the box"; status=1; }
grep -m1 -x 'claude@claude-box.invalid' <<< "$result" || { echo "the public identity didn't show"; status=1; }

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
