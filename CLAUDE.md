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
- 2+ independent streams → team of agents.
- New code >30 lines, refactor, review, debug, security, perf, API design, test, deploy → auto-dispatch.

## Skills & Commands
- `/oh-my-claudecode:<name>` or keyword triggers: `autopilot`, `ultrawork`, `ralph`, `ralplan`, `deep-analyze`, `tdd`, `ultrathink`, `cancelomc`.
- Agent catalog, team pipeline, commit protocol → `omc-reference` skill.

## Context
- `<remember>` persists 7 days; `<remember priority>` permanent.
- Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS`.
- Worktree: `.omc/state/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`.

<!-- OMC:END -->

## 搜索

| 场景 | 命令 |
|------|------|
| 关键词/IT/新闻/学术/包/仓库/问答 | `web search` / `web it` / `web news` / `web science` / `web packages` / `web repos` / `web qa` |
| URL 抓取/深度搜索 | `web fetch <url>` / `web deep <query>` |
| 社交平台 | agent-reach skill |

## 工具

- **代码探索**：优先 `codebase-memory-mcp` 的 search_graph / trace_path / get_code_snippet（需先 index_repository）
- **纯文本搜索**：用 `ctx_search` 或 `Grep`
- **编辑**：先 `Read` 再 `Edit`
- **大输出**：优先 lean-ctx 的 ctx_shell/ctx_read（带压缩），避免 bash 直接处理超大输出
