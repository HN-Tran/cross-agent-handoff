# cross-agent-handoff

Pass **task state** across AI coding tools — Cursor, Claude Code, Codex, Antigravity CLI/desktop, and project chat — without copying full chat transcripts.

**Handoff, not sync:** this tool passes a structured baton (`.agent/SESSION.md` + optional digest). It does not replicate full history or keep all agents identical.

Tags: `cross-agent` `session-handoff` `cursor` `claude-code` `codex` `antigravity`

## How it works

| Layer | File | What it holds |
|-------|------|----------------|
| Static | `AGENTS.md` | Conventions, build commands (`CLAUDE.md` → symlink for Claude Code) |
| Dynamic | `.agent/SESSION.md` | Goal, progress, next steps, decisions, blockers, **context digest** |
| Execution | `.agent/state.json` | Branch, dirty files, recent commits (auto-captured) |
| Archive | `.agent/archive/` | Full transcript copies (reference only; not injected whole) |

On **session start**, hooks inject `SESSION.md` into the agent context. On **stop**, hooks require an updated handoff before the agent can finish. On **session end**, git state is captured in the background.

## Install

```bash
git clone https://github.com/HN-Tran/cross-agent-handoff.git
cd cross-agent-handoff
./install-global.sh --link    # ~/.local/bin/cross-agent-handoff + ~/.local/share/
```

Optional CLI alias: `cah`

## Quick start (per repo)

```bash
cd your-git-repo
cross-agent-handoff init
# Edit .agent/SESSION.md with your current task
```

For **cloud agents** that clone from GitHub (no access to gitignored files):

```bash
cross-agent-handoff init --web-mode   # keeps .agent/ committable
git add .agent/SESSION.md && git commit -m "chore: session handoff" && git push
```

## CLI

| Command | Purpose |
|---------|---------|
| `init [--web-mode] [DIR]` | Create `.agent/`, templates, AGENTS section, repo hook stubs |
| `capture [--tool NAME] [--transcript PATH]` | Write `state.json` (+ optional archive) |
| `export-for-project [--clipboard]` | Brief handoff for ChatGPT/Claude/Gemini Projects |
| `import --from-clipboard \| --from-file PATH` | Pull project-chat updates into `SESSION.md` |
| `digest` | Show latest archive tail; hints for context digest |
| `install-global [--link]` | Install CLI + wire user-level hooks |

## Hooks (Tier A — local CLIs)

After `install-global`:

| Tool | Config | Events |
|------|--------|--------|
| Cursor | `~/.cursor/hooks.json` | `sessionStart`, `stop`, `sessionEnd` |
| Claude Code | `~/.claude/settings.json` | `SessionStart`, `Stop`, `SessionEnd` |
| Codex | `~/.codex/hooks.json` | `SessionStart`, `Stop` (no SessionEnd) |
| Antigravity CLI | `~/.gemini/antigravity-cli/settings.json` | `SessionStart`, `AfterAgent`, `SessionEnd` |

**Codex:** run `codex /hooks` once to review and trust hooks.

**Cursor:** restart the IDE after install so `hooks.json` reloads (requires Cursor v2.4+).

`init` also writes **repo-level** hook stubs (`.cursor/hooks.json`, `.claude/settings.json`, etc.) for cloud sessions (Tier B).

## Project chat (Tier C)

```bash
cross-agent-handoff export-for-project --clipboard
# Paste into your project instructions or upload SESSION.brief.md

cross-agent-handoff import --from-clipboard
# After editing in the project UI, pull text back into the repo
```

See [`templates/project-instructions.md`](templates/project-instructions.md) for paste-ready project rules.

## Coverage tiers

| Tier | Tools | Automation |
|------|-------|------------|
| A | Cursor, Claude Code, Codex, Antigravity CLI | Full hooks |
| B | Cursor Cloud, Claude web, etc. | Repo-committed hooks + pushed `SESSION.md` |
| C+ | ChatGPT / Claude / Gemini Projects | `export-for-project` / `import` |
| D | Ad hoc chat | Manual paste |

## Architecture

```
cross-agent-handoff/
  bin/cross-agent-handoff      # CLI
  lib/common.sh                # shared helpers
  hooks/
    session-start.sh           # core logic
    stop-enforce-handoff.sh
    session-end.sh
    archive-transcript.sh
    adapters/                  # per-tool JSON output
  templates/
```

Core shell scripts hold the logic; thin adapters emit each tool’s hook JSON (`additional_context`, `followup_message`, `decision: block`, etc.).

## Troubleshooting

- **Hooks not firing:** check executable bits, paths in config, and tool-specific trust (`codex /hooks`).
- **Stop loop:** update `.agent/SESSION.md` (Goal, Progress, Next steps, Decisions, Blockers, Context digest) then stop again.
- **Cloud agent missing context:** use `init --web-mode` and commit `SESSION.md`, or push after local updates.

## License

Apache-2.0 — see [LICENSE](LICENSE).
