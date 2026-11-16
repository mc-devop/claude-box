"""Private terms check: no tracked file holds a term from tests/private-terms,
your own untracked list (one Python regex per line, # starts a comment),
matched case-insensitively. Without that file the check is skipped. Paths
marked export-ignore in .gitattributes are skipped too: they never leave this
repo (git archive leaves them out of the public export).

Run: python3 tests/check_private_terms.py [repo]   (or tests/run.sh)
"""

import re
import subprocess
import sys
from pathlib import Path


def exported(repo, files):
    """The files whose export-ignore attribute isn't set."""
    out = subprocess.run(["git", "check-attr", "-z", "--stdin", "export-ignore"], cwd=repo,
                         input="\0".join(files), capture_output=True, text=True,
                         check=True).stdout.split("\0")
    ignored = {out[i] for i in range(0, len(out) - 2, 3) if out[i + 2] == "set"}
    return [f for f in files if f not in ignored]


def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    terms_file = repo / "tests" / "private-terms"
    if not terms_file.is_file():
        print("private terms: skipped (no tests/private-terms)")
        return 0
    terms = [line.strip() for line in terms_file.read_text().splitlines()
             if line.strip() and not line.strip().startswith("#")]
    patterns = [re.compile(t, re.IGNORECASE) for t in terms]
    files = list(filter(None, subprocess.run(["git", "ls-files", "-z"], cwd=repo,
                                             capture_output=True, text=True,
                                             check=True).stdout.split("\0")))
    matches = 0
    checked = 0
    for name in exported(repo, files):
        path = repo / name
        try:
            text = path.read_text()
        except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
            continue
        checked += 1
        for n, line in enumerate(text.splitlines(), 1):
            for p in patterns:
                if p.search(line):
                    print(f"{name}:{n}: /{p.pattern}/")
                    matches += 1
    print(f"private terms: {checked} files, {matches} matches")
    return 1 if matches else 0


if __name__ == "__main__":
    sys.exit(main())
