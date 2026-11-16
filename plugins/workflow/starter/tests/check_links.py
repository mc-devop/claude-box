"""Markdown link check: every relative link in the repo's Markdown files
points to a file that exists, and every #anchor to a heading in it.
A link into out/ is refused: out/ isn't in git, so it breaks on any other clone.
Links to web pages (http:, https:, mailto:), code blocks and inline code
are skipped.

Run: python3 tests/check_links.py [repo]   (or tests/run.sh); repo defaults
to this one.
"""

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def anchors(path):
    """GitHub/Forgejo-style anchors of a Markdown file's headings."""
    found = set()
    for line in path.read_text().splitlines():
        m = re.match(r"#+ (.*)", line)
        if m:
            a = m.group(1).strip().lower()
            a = re.sub(r"[^\w\- ]", "", a).replace(" ", "-")
            found.add(a)
    return found


def main():
    repo = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else REPO
    files = subprocess.run(["git", "ls-files", "*.md"], cwd=repo,
                           capture_output=True, text=True, check=True).stdout.split()
    problems = 0
    for name in files:
        f = repo / name
        if not f.exists():
            continue
        text = re.sub(r"```.*?```", "", f.read_text(), flags=re.S)
        text = re.sub(r"`[^`\n]*`", "", text)
        for m in re.finditer(r"\]\(([^)\s]+)\)", text):
            link = m.group(1)
            if re.match(r"[a-z]+:", link):
                continue
            path, _, frag = link.partition("#")
            target = (f.parent / path).resolve() if path else f.resolve()
            if target == repo / "out" or (repo / "out") in target.parents:
                print(f"{name}: links into out/ (not in git) {link}")
                problems += 1
            elif not target.exists():
                print(f"{name}: missing {link}")
                problems += 1
            elif frag and target.suffix == ".md" and frag not in anchors(target):
                print(f"{name}: no heading #{frag} in {path or f.name}")
                problems += 1
    print(f"links: {len(files)} files, {problems} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
