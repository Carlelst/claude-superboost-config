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

完整 130 关键词索引、MCP 工具路由表 → 对应 skill 按需加载，此处省略。

## 工具使用

**大输出处理**: 单次命令/读取返回 >100 行时，优先用 lean-ctx 的 ctx_shell/ctx_read/ctx_search（带压缩），避免直接用 bash 处理超大输出。

**代码搜索**（避免与 lean-ctx 冲突）:
- **结构化代码探索**（找函数/类/调用链/架构）→ 优先 `codebase-memory-mcp` 的 `search_graph` / `trace_path` / `get_code_snippet`（需先 `index_repository`）
- **纯文本搜索**（grep 配置/日志/文档）→ 用 `ctx_search` 或 `Grep`
- **读文件后编辑** → 始终先 `Read` 再 `Edit`

**联网搜索分工**:
- 通用搜索/新闻/学术/ → `web-search` Skill（`web` 脚本）
- 社交平台抓取（Twitter/Reddit/B站/小红书/YouTube）→ `agent-reach` Skill