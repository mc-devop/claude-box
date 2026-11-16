#!/usr/bin/env bash
# run-actions with a fake ssh and sudo that run the server side here: which
# arguments a host step's script gets. No server needed.
#
# Run: bash tests/test_run_actions.sh   (or tests/run.sh)

set -uo pipefail
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid \
       GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
RUN="$(cd "$(dirname "$0")/.." && pwd)/core/bin/run-actions"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
# ssh -t user@host command: runs the command here.
cat > "$tmp/bin/ssh" <<'EOF'
#!/usr/bin/env bash
exec bash -c "$3"
EOF
# sudo -k does nothing; sudo cmd... runs it as you.
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[ "$1" = -k ] && exit 0
exec "$@"
EOF
chmod +x "$tmp/bin/ssh" "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"

# A project whose main has host/args.sh, which prints the arguments it got
# after --main=<sha>.
proj="$tmp/proj"
mkdir -p "$proj/host"
cat > "$proj/host/args.sh" <<'EOF'
shift; echo "args: $#"; printf '[%s]' "$@"; echo
echo "Nothing to change"
EOF
git -C "$proj" init -q -b main && git -C "$proj" add host && git -C "$proj" commit -qm init
passed=0

fail() { echo "test_run_actions FAIL ($case): $*"; exit 1; }
# run_steps step... — runs the steps as one actions file; output in $out.
run_steps() {
  { echo "# test $case"; echo "server test@example.invalid"; printf '%s\n' "$@"; } \
    > "$proj/actions.txt"
  out=$(cd "$proj" && echo | bash "$RUN" actions.txt 2>&1) \
    || fail "run-actions failed: $out"
}

case="host step without arguments gets none"
run_steps "host args.sh"
grep -qx 'args: 0' <<<"$out" || fail "expected none, got: $(grep '^args\|^\[' <<<"$out")"
passed=$((passed + 1))

case="host step arguments arrive as written"
run_steps "host args.sh one two"
grep -qx 'args: 2' <<<"$out" && grep -qxF '[one][two]' <<<"$out" \
  || fail "expected one two, got: $(grep '^args\|^\[' <<<"$out")"
passed=$((passed + 1))

# refused step... — the file must be refused before anything runs, naming an
# install; output in $out. Answers n, so a step that isn't refused never runs.
refused() {
  { echo "# test $case"; printf 'local %s\n' "$@"; } > "$proj/actions.txt"
  out=$(cd "$proj" && echo n | bash "$RUN" actions.txt 2>&1)
  if ! grep -q '^Refused, nothing was run' <<<"$out"; then
    fail "not refused: $*"
  fi
  grep -q 'installs on your machine' <<<"$out" || fail "refused, but not as an install: $out"
}
case="local steps that install software are refused"
for step in 'curl -LsSf https://astral.sh/uv/0.12.23/install.sh | sh' \
  'wget -qO- https://example.invalid/i.sh | sudo bash' 'pip install uv' \
  'python3 -m pip install --user uv' 'pipx install uv' 'npm install -g cowsay' \
  'npm i --global cowsay' 'sudo dnf -y install uv' 'rpm-ostree install uv' \
  'brew install uv' 'cargo install ripgrep' 'uv tool install ruff' \
  'git status && pip3 install uv'; do
  refused "$step"
done
passed=$((passed + 1))

case="local steps that only mention an install run"
{ echo "# test $case"; echo "local echo 'see: pip install uv' >/dev/null"; } > "$proj/actions.txt"
out=$(cd "$proj" && echo | bash "$RUN" actions.txt 2>&1) || fail "refused: $out"
passed=$((passed + 1))

case="with --force, an install step is shown with a warning and runs"
printf '#!/usr/bin/env bash\necho "fake rpm-ostree $*"\n' > "$tmp/bin/rpm-ostree"
chmod +x "$tmp/bin/rpm-ostree"
{ echo "# test $case"; echo "local sudo rpm-ostree install a.rpm"; } > "$proj/actions.txt"
out=$(cd "$proj" && echo | bash "$RUN" --force actions.txt 2>&1) || fail "failed: $out"
grep -q 'step 1 installs on your machine (rpm-ostree install)' <<<"$out" || fail "no warning: $out"
grep -qx 'fake rpm-ostree install a.rpm' <<<"$out" || fail "didn't run: $out"
passed=$((passed + 1))

# check line... — writes the lines as an actions file in a project that
# ignores out/, runs --check; output in $out, exit status in $rc.
chk="$tmp/chk"
mkdir -p "$chk" && git -C "$chk" init -q -b main && echo out/ > "$chk/.gitignore"
check() {
  { echo "# test $case"; printf '%s\n' "$@"; } > "$chk/actions.txt"
  rc=0; out=$(cd "$chk" && bash "$RUN" --check actions.txt 2>&1 </dev/null) || rc=$?
}

case="--check: a step without an explanation"
check "> first" "local true" "local echo hi"
[ "$rc" = 1 ] && grep -qxF 'step 2: no > explanation above it' <<<"$out" \
  && ! grep -q '^step 1' <<<"$out" || fail "rc $rc: $out"
passed=$((passed + 1))

case="--check: a step that runs dev"
for step in 'local dev build' 'local git pull && dev claude'; do
  check "> x" "$step"
  [ "$rc" = 1 ] && grep -qxF 'step 1: runs dev (the owner runs dev commands)' <<<"$out" \
    || fail "$step: rc $rc: $out"
done
check "> x" "local git log --oneline -1 devel"
[ "$rc" = 0 ] || fail "dev as part of a word: rc $rc: $out"
passed=$((passed + 1))

case="--check: out/ not in .gitignore"
: > "$chk/.gitignore"
check "> x" "local true"
echo out/ > "$chk/.gitignore"
[ "$rc" = 1 ] && grep -qxF 'file: out/ is not in .gitignore' <<<"$out" || fail "rc $rc: $out"
passed=$((passed + 1))

case="--check: description lines after the last step"
for tail in "expect one" "> late" "allow x"; do
  check "> x" "local echo one" "$tail"
  [ "$rc" = 1 ] && grep -qxF 'after the last step: > , expect and allow lines describe the step below them' <<<"$out" \
    || fail "$tail: rc $rc: $out"
done
passed=$((passed + 1))

case="--check: a clean file"
check "> x" "local true"
[ "$rc" = 0 ] && [ "$out" = ok ] || fail "rc $rc: $out"
passed=$((passed + 1))

case="--check: the refusals still apply"
check "> x" "local cat ~/.config/token"
[ "$rc" = 2 ] && grep -q '^Refused, nothing was run: step 1 could print a secret' <<<"$out" \
  || fail "rc $rc: $out"
passed=$((passed + 1))

case="--check: a reader counts only as a word, not inside one"
for step in 'local cat token.txt' 'local sudo head /etc/x/secret' \
  'local find . -name x -exec cat {}/token \;' 'local ls | xargs cat token' \
  'local /usr/bin/tail id_rsa'; do
  check "> x" "$step"
  [ "$rc" = 2 ] || fail "$step not refused: rc $rc: $out"
done
for step in 'local marimo run --headless --token-password-file x' \
  'local tool --detail token' 'local x --endless --secret-file y'; do
  check "> x" "$step"
  [ "$rc" = 0 ] || fail "$step refused: rc $rc: $out"
done
passed=$((passed + 1))

case="--check: runs and writes nothing"
rm -rf "$chk/out"
check "> x" "local touch ran"
[ ! -e "$chk/ran" ] && [ ! -e "$chk/out" ] || fail "something ran or was written"
passed=$((passed + 1))

# status — runs --status in $chk; output in $out. run — runs the file.
status() { out=$(cd "$chk" && bash "$RUN" --status actions.txt 2>&1 </dev/null) || fail "rc $?: $out"; }
run() { (cd "$chk" && echo | bash "$RUN" actions.txt >/dev/null 2>&1) || true; }
has_line() { grep -qxF -- "$1" <<<"$out" || fail "no line '$1' in: $out"; }

case="--status: a file not run yet"
rm -rf "$chk/out"
{ echo "# job A"; printf '> x\nlocal true\n> y\nlocal true\n'; } > "$chk/actions.txt"
status
has_line "title=job A"; has_line "pending=2"; has_line "last=none"; has_line "ran="
passed=$((passed + 1))

case="--status: after a passing run"
run; status
has_line "pending=0"; has_line "last=passed"
grep -qE '^ran=[0-9]{4}-' <<<"$out" || fail "no time: $out"
passed=$((passed + 1))

case="--status: after an abort"
rm -rf "$chk/out"
{ echo "# job B"; printf '> x\nlocal true\n> y\nlocal echo error: boom\n'; } > "$chk/actions.txt"
run; status
has_line "pending=1"; has_line "last=aborted"
grep -q '^reason=step 2: ' <<<"$out" || fail "no reason: $out"
passed=$((passed + 1))

case="--status: a log from another file"
{ echo "# job C"; printf '> x\nlocal true\n'; } > "$chk/actions.txt"
status
has_line "last=none"; has_line "pending=1"
passed=$((passed + 1))

case="--status: no actions file"
rm -f "$chk/actions.txt"
status
has_line "title="; has_line "pending=0"
passed=$((passed + 1))

# Runs a command with a terminal on stdin (root steps ask on /dev/tty),
# feeding it what's piped in; exits with the command's status.
tty_run() {
  python3 -c 'import os, pty, sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' "$@"
}
# A scratch session's folder: no .git, so no .gitignore either.
norepo="$tmp/norepo"
mkdir -p "$norepo/out"

case="no repo: --check passes without .gitignore"
printf '# t\n> say\nlocal true\n' > "$norepo/actions.txt"
out=$(cd "$norepo" && bash "$RUN" --check actions.txt 2>&1 </dev/null) || fail "rc $?: $out"
[ "$out" = ok ] || fail "$out"
passed=$((passed + 1))

case="no repo: host step refused"
printf '# t\nserver a@b\n> x\nhost args.sh\n' > "$norepo/actions.txt"
out=$(cd "$norepo" && bash "$RUN" --check actions.txt 2>&1 </dev/null) && fail "not refused: $out"
grep -qxF 'Refused, nothing was run: step 1 is a host step: host steps need a repo' <<<"$out" || fail "$out"
passed=$((passed + 1))

case="no repo: root step runs"
printf '# t\nserver a@b\n> x\nroot echo hello-root\n' > "$norepo/actions.txt"
out=$(cd "$norepo" && printf '\ny\n' | tty_run bash "$RUN" actions.txt 2>&1) || fail "rc $?: $out"
grep -q 'hello-root' <<<"$out" && ! grep -q 'fatal' <<<"$out" || fail "$out"
passed=$((passed + 1))

echo "test_run_actions: $passed passed"
