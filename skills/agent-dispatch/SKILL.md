---
name: agent-dispatch
description: Lightweight agent registry and JIT router. Consult BEFORE performing specialized work such as code review, security audit, debugging, refactoring, performance optimization, infrastructure, data analysis, API design, testing, documentation, or any domain-specific engineering task. Maps tasks to specialized subagents, downloading them on demand if not installed locally.
version: 2.0.0
user-invocable: true
metadata:
  openclaw:
    homepage: https://github.com/userFRM/agent-dispatch
    always: false
    skillKey: agent-dispatch
---

# Agent dispatch

You have access to a registry of 130+ specialized subagents. **Before doing specialized work yourself, check this index and dispatch to the appropriate agent.** If the agent is not installed locally, download it on the fly.

## JIT dispatch procedure

When you encounter a specialized task, follow these steps in order.

### Step 1: index lookup

Scan the agent index at the bottom of this file. Format: `keyword = "agent-name:category"`.
Extract the agent name (before the colon) and category key (after the colon).
If no keyword matches, do the work yourself.

### Step 2: check local cache

Check if the agent file exists locally:
```bash
ls "${AGENTS_DIR:-$HOME/.claude/agents}/AGENT_NAME.md" 2>/dev/null
```

**Local agents always take priority.** If the local file exists, skip download and dispatch it directly (step 4). 
The local agents in `~/.claude/agents/` have been customized with OMC integration, model selection, tool permissions, and project-specific workflows — these MUST be preferred over downloaded agents.

Key local agents that override VoltAgent equivalents:
| Keyword | VoltAgent | Local agent | Reason |
|---------|-----------|-------------|--------|
| review | code-reviewer | code-reviewer | Local has OMC integration, severity model, spec compliance stage |
| debug | debugger | debugger | Local has investigation protocol, circuit breaker to tracer |
| security | security-auditor | security-reviewer | Local has OWASP Top 10, secrets scan, dependency audit |
| test | qa-expert | test-engineer | Local has TDD workflow, flaky test hardening |
| architecture | architect-reviewer | architect | Local has trade-off analysis, ralplan consensus mode |

If the local file exists, skip to step 4.

### Step 3: download the agent

Construct the download URL from these parts:
- Base: `https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories`
- Directory: look up the category key in the mapping below
- File: `AGENT_NAME.md`

Download:
```bash
mkdir -p "${AGENTS_DIR:-$HOME/.claude/agents}" && curl -sfL "URL" -o "${AGENTS_DIR:-$HOME/.claude/agents}/AGENT_NAME.md"
```

**If download fails** (non-zero exit or empty file):
- Run: `rm -f "${AGENTS_DIR:-$HOME/.claude/agents}/AGENT_NAME.md"`
- Tell the user: "Could not download AGENT_NAME — handling this task directly."
- Do the work yourself. Do not retry.

**Validation**: if the downloaded file does not start with `---` (YAML frontmatter), treat it as corrupt, delete it, and handle the task yourself.

### Step 4: read and dispatch

Read the agent file. Extract everything after the YAML frontmatter (after the second `---` line).
Pass that full text as the prompt to the **Task** tool, prepending the specific work request.
Use a general-purpose subagent with the full prompt inline — do not reference the agent by registered name.

### Step 5: return results

When the Task completes, relay its output to the user in the main conversation.
The downloaded agent file stays cached in the agents directory for future sessions.

### When to skip dispatch

- The task is trivial (one-liner, quick fix, simple question)
- You need tight back-and-forth with the user
- The task spans multiple domains simultaneously
- The user explicitly asks you to handle it directly

## Category directory mapping

| Key | Directory |
|-----|-----------|
| core | 01-core-development |
| languages | 02-language-specialists |
| infra | 03-infrastructure |
| quality | 04-quality-security |
| data | 05-data-ai |
| devex | 06-developer-experience |
| domains | 07-specialized-domains |
| business | 08-business-product |
| meta | 09-meta-orchestration |
| research | 10-research-analysis |

## Platform-specific paths

| Platform | Agent location | Dispatch mechanism |
|----------|---------------|-------------------|
| Claude Code | `~/.claude/agents/` | `Task` tool with inline prompt |
| OpenClaw | `~/.openclaw/workspace/` | `sessions_spawn` tool |
| Cursor | `.cursor/agents/` | Agent invocation |
| Codex | `.codex/agents/` | Agent invocation |

If your platform does not have a programmatic dispatch tool, instruct the user to invoke the agent manually and pause until it completes.

## Known limitations

- Each keyword maps to exactly one agent (TOML requires unique keys)
- Downloaded agents are cached permanently; delete manually to force re-download
- If you are offline, agents not already cached will be unavailable — handle the task yourself

## Agent index

The full agent index lives in `references/agents.toml`.
Use grep to find matching agents by keyword:

```bash
grep -i "<keyword>" "${SKILL_DIR:-$CLAUDE_CONFIG_DIR/skills/agent-dispatch}/references/agents.toml"
```

Format: `keyword = "agent-name:category"`. Extract the agent name (before the colon) and continue with Step 2.
