<!-- OMC:START -->
<!-- OMC:VERSION:4.14.7 -->

# oh-my-claudecode

## Core
- Delegate specialized work (multi-file, refactor, debug, review, plan, research) to agents.
- Work directly only for trivial ops, small clarifications, single commands.
- Choose lightest model: haiku (quick lookups), sonnet (standard), opus (architecture/deep analysis).
- Verify before claiming completion. Iterate if verification fails.
- Explore first, then plan. Run independent tasks in parallel.
- Never self-approve; use code-reviewer or verifier for approval pass.

## Agent Routing
- Task ≥ 10 min → dispatch to specialized agent.
- New code >30 lines, refactor, review, debug, security, perf, API design, test → auto-dispatch.

### Agent 职责边界
| 场景 | Agent(s) | 说明 |
|------|----------|------|
| 代码审查 | `code-reviewer` **+** `security-reviewer` | 两个 agent 同时 dispatch，分别审查质量和安全 |
| 架构分析 | `architect` | 只读，不调试运行时 bug |
| 调试 | `debugger` → 失败 3 次后 `tracer` | debugger 先修，tracer 做深度因果分析 |
| 方案审查 | `critic` | 只审查 plan/proposal，不审查代码 |
| 代码清理 | `code-simplifier` | 不改行为，只改善可读性 |

## Skills & Commands
- `/oh-my-claudecode:<name>` or keyword triggers: `autopilot`, `ultrawork`, `ralph`, `ralplan`, `deep-analyze`, `tdd`, `ultrathink`, `cancelomc`.

## Context
- `<remember>` persists 7 days; `<remember priority>` permanent.
- Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS`.
- Worktree: `.omc/state/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`. All `.omc/` paths relative to git project root (not cwd).

<!-- OMC:END -->

## 搜索架构（三层）

### 第一层：代码库搜索 — codebase-memory-mcp + explore agent
- **图优先**：`search_graph` → `trace_path` → `get_code_snippet` → `query_graph`（~500 tokens vs grep 80K）
- **回退条件**：项目未索引 / 字符串字面量 / 配置文件 / 非代码文件 / 图结果不足
- **大文件策略**：先 `get_code_snippet` 或 `lsp_document_symbols` 拿结构，再 `Read` 部分
- **复杂探索**：dispatch explore agent（haiku），自动走 graph-first + 3+ 并行搜索

### 第二层：网络搜索 — web-search skill
| 场景 | 命令 |
|------|------|
| 关键词/IT/新闻/学术/包/问答 | `web search` / `web it` / `web news` / `web science` / `web packages` / `web qa` |
| URL 抓取/深度搜索 | `web fetch <url>` / `web deep <query>` |
| 降级 | web 脚本 → WebSearch/WebFetch |

### 第三层：社交平台 — agent-reach skill
Twitter/X, Reddit, YouTube, Bilibili, XiaoHongShu, V2EX, LinkedIn, RSS 等 13 平台

### GitHub 内容边界
| 场景 | 工具 | 示例 |
|------|------|------|
| 仓库信息/README | `gh repo view` | `gh repo view owner/repo --json description` |
| 代码仓库搜索 | `gh search repos` | `gh search repos "topic" --sort stars` |
| 网页文档/Issue/PR | `web fetch <url>` | `web fetch "https://github.com/org/repo/issues/1"` |
| 开源项目发现 | `web repos` | `web repos "kubernetes operator"` |

## 工具
- **代码探索**：优先 codebase-memory-mcp（需先 `index_repository`）→ 次选 `Grep`/`Glob`
- **编辑**：先 `Read` 再 `Edit`
- **大输出**：优先 lean-ctx 的 ctx_shell/ctx_read（带压缩），避免 bash 直接处理超大输出
