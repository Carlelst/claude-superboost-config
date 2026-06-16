# Claude Code 一键配置指南

## 快速开始

```bash
git clone https://github.com/Carlelst/claude-superboost-config.git
cd claude-superboost-config
./install.sh
```

重启 Claude Code 后生效。

## install.sh 做了什么

| 步骤 | 内容 |
|------|------|
| 1/5 | 安装 6 个 CLI 工具：rtk、lean-ctx、fff-mcp、headroom、beads(bd)、codeburn |
| 2/5 | 安装 11 个 Claude Code 插件：claude-mem、karpathy-skills、VoltAgent(6)、LSP(3)、plugin-dev |
| 3/5 | 复制 97 个 Skills 到 ~/.claude/skills/ |
| 4/5 | 复制配置文件：CLAUDE.md、RTK.md、settings.json、hooks、session-init |
| 5/5 | 确认 MCP server 配置（lean-ctx、fff、headroom） |

## 手动步骤

安装后需要手动做的事：

```bash
# 在每个 git 项目里初始化 beads 任务管理
cd your-project
bd init

# 查看 token 消耗仪表板
codeburn report
```

## 工具速查

| 场景 | 用什么 |
|------|--------|
| 读文件 | lean-ctx `ctx_read`（缓存命中 ~13 tokens） |
| 搜代码 | lean-ctx `ctx_search` 或 fff `ffgrep` |
| 执行命令 | RTK 自动压缩（40+ 命令） |
| 管理任务 | beads `bd create / bd ready / bd close` |
| 项目记忆 | beads `bd remember "xxx"` |
| 看 token 消耗 | `codeburn report` |
| 看省了多少 | `rtk gain` |

## 架构

详见 [ARCHITECTURE.md](ARCHITECTURE.md)

## 故障排查

```bash
# 检查 hook 是否生效
grep -c "rtk\|bd prime\|env-wrapper" ~/.claude/settings.json

# 检查 MCP server 是否配置
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print(list(d.get('mcpServers',{}).keys()))"

# 检查工具是否安装
rtk --version && lean-ctx --version && fff-mcp --version && headroom --version && codeburn --version && bd version
```
