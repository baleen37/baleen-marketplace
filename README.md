# baleen-marketplace

Claude Code plugin marketplace by [Baleen](https://github.com/baleen37).

All plugins live in [baleen37/everything-agent](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins).

## Installation

Add this marketplace to Claude Code:

```bash
claude plugin add marketplace https://github.com/baleen37/everything-agent/baleen-plugins
```

Or install individual plugins directly:

```bash
claude plugin add https://github.com/baleen37/everything-agent/baleen-plugins/plugins/<plugin-name>
```

---

## Plugins

### Development

| Plugin | Description |
|--------|-------------|
| [git-guard](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/git-guard) | Git workflow protection — prevents commit/PR bypasses, enforces pre-commit checks |
| [suggest-compacting](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/suggest-compacting) | Suggests when to compact context during long sessions |
| [me](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/me) | Personal Claude Code config — TDD, systematic debugging, git workflow, code review |
| [lsp-bash](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-bash) | Language Server Protocol for Bash (`bash-language-server`) |
| [lsp-typescript](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-typescript) | Language Server Protocol for TypeScript/JavaScript (`typescript-language-server`) |
| [lsp-python](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-python) | Language Server Protocol for Python (`pyright`) |
| [lsp-go](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-go) | Language Server Protocol for Go (`gopls`) |
| [lsp-kotlin](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-kotlin) | Language Server Protocol for Kotlin (`kotlin-language-server`) |
| [lsp-lua](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-lua) | Language Server Protocol for Lua (`lua-language-server`) |
| [lsp-nix](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/lsp-nix) | Language Server Protocol for Nix (`nil`) |

### Productivity

| Plugin | Description |
|--------|-------------|
| [conversation-memory](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/conversation-memory) | Persistent semantic memory — search and retrieve past Claude Code sessions |
| [handoff](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/handoff) | Save and restore session context between Claude Code sessions |
| [ralph-loop](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/ralph-loop) | Continuous self-referential AI loops for iterative development (Ralph Wiggum technique) |
| [jira](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/jira) | Jira and Confluence integration via Atlassian MCP — issue tracking, status reports, backlogs |
| [databricks-devtools](https://github.com/baleen37/everything-agent/tree/main/baleen-plugins/plugins/databricks-devtools) | Databricks CLI wrapper for workspace management and SQL execution |
