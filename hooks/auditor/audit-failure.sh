#!/bin/bash
# ============================================================
# audit-failure.sh — 失败调用审核（PostToolUseFailure）
# ============================================================
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUDIT_LOG="${HOME}/.claude/audit/${SESSION_ID}.jsonl"

# 工具调用失败本身就是值得关注的信号
jq -nc --arg ts "$TIMESTAMP" --arg sid "$SESSION_ID" --arg tool "$TOOL_NAME" \
       '{
           timestamp: $ts,
           session_id: $sid,
           tool: $tool,
           level: "MEDIUM",
           category: "anomaly",
           summary: ("工具调用失败: " + $tool)
       }' >> "$AUDIT_LOG"

exit 0
