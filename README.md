# Claude Code Superboost Config

Personal Claude Code configuration with multi-layer toolchain optimization.

## Tool Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Command compression | RTK | 60-90% token reduction on shell output |
| File intelligence | lean-ctx | Cached reads (~13 tokens), 10 read modes, 76 MCP tools |
| Agent search | fff | Frecency-ranked file search with git annotations |
| Content compression | headroom | JSON/code/text compression, reversible |
| Task management | beads (bd) | Graph-based issue tracker with Dolt DB |
| Token observability | codeburn | TUI dashboard for cost analysis |
| Cross-session memory | claude-mem | Auto observation capture and compression |
| Agent dispatch | VoltAgent | 7 specialized subagent plugins |
| Coding best practices | karpathy-skills | Karpathy's coding behavior guidelines |

## Quick Install

```bash
git clone https://github.com/Carlelst/claude-config.git
cd claude-config
./install.sh
```

Restart Claude Code to apply hooks and MCP servers.

## Prerequisites

```bash
# Core tools (auto-installed via their official scripts)
rtk          -- CLI proxy for token reduction
lean-ctx     -- Context intelligence layer
fff-mcp      -- Agent file search
headroom     -- Content compression
codeburn     -- Token observability
bd           -- Graph issue tracker
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full system architecture diagram.

## Hooks

- **SessionStart**: session-init → superboost-banner → bd prime
- **PreToolUse**: env-wrapper → rtk hook (Bash compression)
- **PostToolUse**: ram-monitor
- **PreCompact**: bd prime (context refresh)

## 持续同步

本机配置变更后，同步到仓库：

```bash
cd ~/.hub/claude-config
./sync.sh
```

脚本会自动复制最新配置文件、hooks、skills、agents，展示 diff，确认后 commit + push。
