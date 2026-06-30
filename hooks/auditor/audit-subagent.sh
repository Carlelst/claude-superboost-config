#!/bin/bash
# ============================================================
# audit-subagent.sh — 子代理追溯（SubagentStop）
# ============================================================
# Agent 子调用对 PostToolUse 不可见，在此做追溯记录
# ============================================================
set -euo pipefail

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUDIT_LOG="${HOME}/.claude/audit/${SESSION_ID}.jsonl"

jq -nc --arg ts "$TIMESTAMP" --arg sid "$SESSION_ID" \
       --arg type "$AGENT_TYPE" --arg aid "$AGENT_ID" \
       '{
           timestamp: $ts,
           session_id: $sid,
           tool: "Subagent",
           level: "INFO",
           category: "data_access",
           summary: ("子代理结束: " + $type),
           detail: ("agent_id=" + $aid)
       }' >> "$AUDIT_LOG"

exit 0
