# Level 1 — System context — claude-box

> **Diagram type**: System context
> **Scope**: claude-box, the person who uses it, and the systems around it.

## Diagram

```mermaid
flowchart TD
  owner["<b>Owner</b><br/>[Person]"]
  zed["<b>Zed</b><br/>[External]<br/>Your editor"]
  box["<b>claude-box</b><br/>[Software system]<br/>Claude Code in a container<br/>that sees one project"]

  anthropic["<b>Claude API</b><br/>[External]<br/>Anthropic: models, login"]
  github["<b>GitHub</b><br/>[External]<br/>Plugin marketplaces,<br/>Karpathy guidelines"]
  sources["<b>Image sources</b><br/>[External]<br/>Fedora registry,<br/>Claude Code installer"]
  servers["<b>Your servers and git remotes</b><br/>[External]"]

  owner -- "starts, reviews, runs<br/>[dev]" --> box
  owner -- "works in" --> zed
  zed -- "starts an agent thread in<br/>[dev claude]" --> box
  box -- "sends model requests to<br/>[HTTPS]" --> anthropic
  box -- "downloads plugins<br/>and rules from [HTTPS]" --> github
  box -- "builds its image from<br/>[HTTPS]" --> sources
  box -- "runs your reviewed steps on<br/>[SSH, git]" --> servers

  classDef person fill:#08427b,stroke:#052e56,color:#fff
  classDef system fill:#1168bd,stroke:#0b4884,color:#fff
  classDef external fill:#999999,stroke:#6b6b6b,color:#fff
  class owner person
  class box system
  class zed,anthropic,github,sources,servers external
```

## Elements

| Element | Type | Description |
|---|---|---|
| Owner | Person | Starts Claude in a project, reviews its branches and `out/actions.txt`, merges, and runs `dev run` |
| claude-box | Software system | This repo: [containers](02-container.md) |
| Zed | External | Your editor: its agent thread starts `dev claude`, its terminal runs `dev run`, its Markdown preview shows drafts and docs. It has no Claude agent of its own |
| Claude API | External | Anthropic's API; the box logs in once (`dev init`) and sends every model request there |
| GitHub | External | The plugin marketplaces and pinned rules files your `plugin` and `rules` lines name ([core/defaults.dev](../../../core/defaults.dev)), fetched when a line first appears |
| Image sources | External | Fedora's registry (`fedora:44`) and Claude Code's installer (`claude.ai/install.sh`), at image build |
| Your servers and git remotes | External | Reached only by `dev run` on your laptop, as you: `root`/`host` steps over SSH, pushes as `local` steps. The box itself holds no credentials for them |
