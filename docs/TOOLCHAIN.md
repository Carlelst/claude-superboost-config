# 🧰 Claude Code 工具链全景手册

> 每次新 session 启动时自动注入此文档的速查表

---

## 一、工具总览

```
┌─────────────────────────────────────────────────────────────┐
│  SessionStart                                               │
│  session-init ──→ superboost-banner ──→ bd prime            │
│  (环境注入)        (健康检查)            (任务上下文+记忆)      │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  PreToolUse (命令调用前)                                      │
│  env-wrapper ──→ rtk hook claude                            │
│  (PATH环境)       (命令输出压缩)                               │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  MCP Tools (Agent 主动调用)                                   │
│  lean-ctx (76 tools) │ fff (搜索) │ headroom (压缩)           │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  PostToolUse / 其他                                          │
│  ram-monitor │ claude-mem (跨session记忆) │ codeburn (TUI)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、逐工具详解

### 1. RTK — 命令输出压缩

| 项目 | 内容 |
|------|------|
| **做什么** | 拦截 Bash 命令输出，在送到 LLM 之前压缩（如 git diff 只保留关键行，测试输出只保留失败项） |
| **触发方式** | 自动。PreToolUse Hook 在每次 Bash 调用时触发 `rtk hook claude` |
| **什么时候用到** | Agent 执行 `git status`, `ls`, `npm test`, `cargo build` 等 40+ 命令时，全程自动 |
| **你能看到什么** | 无感知。运行 `rtk gain` 可以看到节省了多少 token |
| **命令参考** | `rtk gain` — token 节省统计 |

### 2. lean-ctx — 上下文智能层

| 项目 | 内容 |
|------|------|
| **做什么** | 76 个 MCP 工具，替代原生的 Read/Grep/Bash 操作。核心能力：文件缓存（重复读取仅 13 tokens）、10 种读取模式、Shell 输出压缩、安全检查 |
| **触发方式** | Agent 按 CLAUDE.md 里的路由表主动调用 MCP 工具 |
| **什么时候用到** | 读文件→`ctx_read`，搜索代码→`ctx_search`，列目录→`ctx_tree`，执行命令→`ctx_shell` |
| **你能看到什么** | Agent 的工具调用会显示 `ctx_read`/`ctx_search` 而不是 `Read`/`Grep` |
| **命令参考** | `lean-ctx gain` — 查看节省统计 |

**10 种读取模式**：

| 模式 | 用途 |
|------|------|
| `full` | 完整查看或编辑文件 |
| `map` | 快速了解文件结构（类/函数列表） |
| `signatures` | 只看函数/类签名 |
| `diff` | 变更后验证 |
| `lines:N-M` | 只看指定行范围 |
| `density:X` | 按密度裁剪到 X% |
| `auto` | 自动选择最优模式 |

### 3. fff — Agent 文件精确搜索

| 项目 | 内容 |
|------|------|
| **做什么** | 比 rg/fd 更快更准的文件搜索，专为 AI Agent 设计。自带 frecency 记忆（常操作的文件排名更高）、定义优先提示、Git 状态标注 |
| **触发方式** | Agent 通过 MCP 调用 `ffgrep` / `fffind` / `fff-multi-grep` |
| **什么时候用到** | 搜索代码模式、查找文件、多文件并行搜索 |
| **你能看到什么** | Agent 使用 `ffgrep` 工具而非 `Grep` |
| **对比 rg/fd** | fff 有长驻内存索引，重复搜索比 rg 快一个数量级 |

### 4. headroom — 内容压缩

| 项目 | 内容 |
|------|------|
| **做什么** | 压缩送入 LLM 的内容——JSON 数据、代码（AST 级）、日志、对话历史。支持 CCR（压缩后可还原原文） |
| **触发方式** | Agent 通过 MCP 调用 `headroom_compress` / `headroom_retrieve` / `headroom_stats` |
| **什么时候用到** | 处理大量 JSON 数据、长日志压缩、对话历史膨胀时 |
| **你能看到什么** | Agent 使用 `headroom_compress` 工具 |

### 5. beads (bd) — 图谱任务管理

| 项目 | 内容 |
|------|------|
| **做什么** | 替代 markdown TODO 的 Agent 原生任务管理。基于 Dolt（Git-for-SQL 数据库），支持依赖图、原子领取、持久记忆 |
| **触发方式** | SessionStart Hook 自动执行 `bd prime` 注入上下文；Agent 按 CLAUDE.md 路由器使用 bd 命令 |
| **什么时候用到** | 创建任务、领取任务、关闭任务、记录项目记忆 |
| **你能看到什么** | Agent 用 `bd create`/`bd update --claim` 替代 TodoWrite |

**核心命令**：

```bash
bd ready                          # 可领取的任务
bd create "标题" -p 0 -t bug      # 创建 P0 bug
bd update <id> --claim            # 原子领取（其他 Agent 领不到）
bd show <id>                      # 查看详情
bd close <id>                     # 完成任务
bd remember "关键信息"             # 持久记忆（下次 bd prime 自动注入）
bd prime                          # 查看完整工作流上下文
```

**与传统 TODO 的对比**：

| 传统 | bd |
|------|-----|
| 静态文本 | Dolt 版本化数据库 |
| 任务之间无关系 | 依赖图（`bd dep add`） |
| 多 Agent 改同一文件 → 冲突 | Hash ID + 原子领取 |
| Agent 需读全文 | `bd ready` 只返回无阻塞任务 |

### 6. claude-mem — 跨 Session 记忆

| 项目 | 内容 |
|------|------|
| **做什么** | 自动记录每个 session 的观测数据，跨 session 压缩并注入上下文 |
| **触发方式** | 自动。Plugin 在后台持续记录 |
| **什么时候用到** | 下次 session 启动时，自动注入之前的相关上下文 |
| **与 beads 的区别** | claude-mem 管「session 之间的记忆」，beads 的 `bd remember` 管「项目层面的知识」 |

### 7. codeburn — Token 消耗可视化

| 项目 | 内容 |
|------|------|
| **做什么** | 交互式 TUI 仪表板，显示每个 tool call 的 token 消耗明细，按 Agent/模型/项目维度拆分 |
| **触发方式** | 手动。在终端执行 `codeburn report` |
| **什么时候用到** | 想了解 token 花在哪里、哪个 Agent 最烧钱时 |
| **命令参考** | `codeburn report` — 交互仪表板 / `codeburn status` — 紧凑状态 / `codeburn today` — 今日摘要 |

---

## 三、按场景速查

| 场景 | 用什么 | 具体操作 |
|------|--------|----------|
| 读文件 | lean-ctx `ctx_read` | Agent 自动选择读取模式 |
| 搜索代码 | lean-ctx `ctx_search` 或 fff `ffgrep` | Agent 按复杂度选择 |
| 找文件 | fff `fffind` | frecency 智能排序 |
| 执行命令 | RTK（自动压缩） | 无需操作 |
| 压缩长内容 | headroom `headroom_compress` | Agent 主动调用 |
| 创建任务 | beads `bd create` | Agent 替代 TodoWrite |
| 领取任务 | beads `bd update --claim` | 原子操作 |
| 记录记忆 | beads `bd remember` | 持久化到项目数据库 |
| 查看 Token | codeburn `codeburn report` | 手动执行 |
| 查看节省 | `rtk gain` / `lean-ctx gain` | 手动执行 |

---

## 四、需要你手动做的事

| 操作 | 时机 | 命令 |
|------|------|------|
| 初始化 beads（新 git 项目） | 每个项目一次 | `cd 项目目录 && bd init` |
| 查看 token 消耗 | 想看时 | `codeburn report` |
| 查看 token 节省 | 想看时 | `rtk gain` / `lean-ctx gain` |

其余全部自动。
