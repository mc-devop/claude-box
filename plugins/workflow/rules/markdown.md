# Markdown files

- Write references to files, folders and sections as clickable links, not
  bare code spans: `[phase0/README.md](../phase0/README.md)`, or
  `[Deploy](../docs/brief.md#deploy)` for a heading.
- Paths are relative to the Markdown file that contains the link, so they
  work in editors and on git hosts alike. Check that each target exists.
- A project with Markdown docs checks its links in its test run: every
  relative link and `#anchor` resolves (the workflow
  plugin's starter `tests/check_links.py`, standard library only). A
  project that adopts the plugin copies it once, on a `claude/` branch,
  from `/usr/local/share/claude-box/plugins/workflow/starter/tests/`.
- Commands, file contents and paths that aren't meant to be opened stay in
  code spans or code blocks.
- Draw diagrams as Mermaid code blocks, in the subset the owner's preview
  renders: `flowchart` only (no C4 or other experimental syntax, no
  `%%{init}%%` or config front matter). Keep them small:
  - at most about 10–12 boxes per diagram; split bigger views into several
    diagrams, one per topic;
  - an arrow points from the side that starts it (the request, the
    connection, the action), and "from – label – to" reads as a
    sentence; data may flow both ways, the arrow says who starts;
  - short arrow labels ("purpose [protocol]", e.g. "sends model
    requests to [HTTPS]"), full descriptions in a table below the
    diagram.
- Only a very large picture that can't be split sensibly may be ASCII art.
