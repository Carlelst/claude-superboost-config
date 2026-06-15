<!-- OMC:START -->
<!-- OMC:VERSION:4.14.7 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.
<!-- OMC:END -->

<!-- User customizations -->
## 网络搜索

> 所有搜索走 `web` 脚本入口，详情 → **web-search** Skill。

| 输入 | 命令 |
|------|------|
| 关键词/IT/新闻/学术/包/仓库/问答 | `web search` / `web it` / `web news` / `web science` / `web packages` / `web repos` / `web qa` |
| URL 抓取 | `web fetch <url>` |
| 深度搜索 | `web deep <query>` |
| 图片/视频 | `web images` / `web videos` |

BGE-Reranker 自动重排序，SearXNG → gh CLI → WebSearch 三级降级。

## 新闻

用户问"世界上发生了什么" → **news-brief** Skill。

---

## Agent 智能调度 (Superboost + agent-dispatch)

### 路由决策 (每个非 trivial 任务必须执行)

| 独立流 | 耗时 | 决策 |
|--------|------|------|
| 1 | < 10 min | Solo |
| 1 | ≥ 10 min | 调 **agent-dispatch** Skill 匹配专业 agent |
| ≥ 2 | 任意 | 派团队，每流一个专业 agent |

输出: `🔀 Solo | Agent: <name> | Team of N`

### Agent 匹配 (遇专用任务必须派 agent，不自干)

触发: 新写(>30行) / 重构 / 审查 / 调试 / 安全 / 性能 / API设计 / 测试 / 部署

完整 130 关键词索引 → **agent-dispatch** Skill。高频速查:

Python→`python-pro` TS/JS→`typescript-pro`/`javascript-pro` Rust→`rust-engineer` Go→`golang-pro`
审查→`code-reviewer` 调试→`debugger` 安全→`security-auditor` 性能→`performance-engineer`
测试→`test-automator` API→`api-designer` DB→`sql-pro` Docker→`docker-expert` K8s→`kubernetes-specialist`
CI/CD→`devops-engineer` 重构→`refactoring-specialist` 文档→`documentation-engineer`
前端→`frontend-developer` 后端→`backend-developer`

### 派发协议

1. 预检: 任务描述精确、上下文充足
2. 进度: 多步骤任务要求输出进度
3. 回传: agent 结果在主对话呈现

@RTK.md

---

## MCP 工具路由 (遇到对应场景优先用 MCP 工具)

| 场景 | ❌ 不用 | ✅ 用 | MCP Server |
|------|--------|------|------------|
| 读文件 | `Read`/`cat` | `ctx_read` (10 种模式+缓存, 重读仅~13 tokens) | lean-ctx |
| 搜索代码 | `Grep`/`rg` | `ctx_search` / `ffgrep` | lean-ctx / fff |
| 目录浏览 | `ls`/`find` | `ctx_tree` | lean-ctx |
| 执行命令 | 直接 `bash` | `ctx_shell` (95+ 压缩模式) | lean-ctx |
| 文件编辑 | `Edit`/`StrReplace` | 照常用。如 Read 不可用则 `ctx_edit` | lean-ctx |
| 文件精确搜索 | `find`/`fd` | `fffind` (frecency+git标注) | fff |
| 多文件搜索 | 多次 `rg` | `fff-multi-grep` | fff |
| 长内容压缩 | — | `headroom_compress` (60-95%) | headroom |
| 压缩内容还原 | — | `headroom_retrieve` | headroom |
| 压缩统计 | — | `headroom_stats` | headroom |
| 任务管理 | TodoWrite/TaskCreate/md TODO | `bd create` / `bd ready` / `bd update --claim` | beads (CLI) |
| 项目记忆 | MEMORY.md 文件 | `bd remember "xxx"` | beads (CLI) |
| 跨 session 记忆 | — | claude-mem (自动) | claude-mem plugin |

### 读取文件速查 (lean-ctx ctx_read modes)

| 模式 | 用途 |
|------|------|
| `full` | 完整编辑 |
| `map` | 文件结构概览 |
| `signatures` | 函数/类签名 |
| `diff` | 变更后验证 |
| `lines:N-M` | 行范围 |
| `density:X` | 按密度裁剪到 X% |
| `auto` | 自动选择 |

### 任务管理速查 (beads bd)

```bash
bd ready                          # 可领取的任务
bd create "标题" -p 0 -t bug      # 创建任务
bd update <id> --claim            # 原子领取
bd show <id>                      # 查看详情
bd close <id>                     # 完成任务
bd remember "关键信息"             # 持久记忆
bd prime                          # 注入完整工作流上下文
```