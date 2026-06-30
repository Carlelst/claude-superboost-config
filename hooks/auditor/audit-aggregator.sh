#!/bin/bash
# ============================================================
# audit-aggregator.sh — 批量审核汇总 (PostToolBatch)
# ============================================================
# V2.1: 按 session 文件读取，tail 替代 grep 全扫描
# ============================================================
set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
AUDIT_LOG="${HOME}/.claude/audit/${SESSION_ID}.jsonl"

[[ ! -f "$AUDIT_LOG" ]] && exit 0

# tail 最近 30 条，只检查本批次的 HIGH 发现
# 用时间戳过滤最近 10 秒内的（PostToolBatch 每批之间间隔很短）
CUTOFF=$(date -d '10 seconds ago' -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

HIGH_NOW=$(tail -30 "$AUDIT_LOG" | jq -r --arg cutoff "$CUTOFF" \
    'select(.level=="HIGH" and .timestamp >= $cutoff) | "\(.category): \(.summary)"' 2>/dev/null)

if [[ -n "$HIGH_NOW" ]]; then
    COUNT=$(echo "$HIGH_NOW" | wc -l)
    jq -n --arg count "$COUNT" --arg items "$(echo "$HIGH_NOW" | head -3 | paste -sd ';' -)" '{
        systemMessage: ("🔍 [审核] 最近检测到 \($count) 项 HIGH 风险: \($items)")
    }'
fi

exit 0
