#!/bin/bash
# Copilot query via Dify workflow API
# Usage: ask_dify.sh "question" [--tool vcs]

DIFY_BASE="${COPILOT_DIFY_BASE:-http://10.9.200.12:8086}"
DIFY_KEY="${COPILOT_DIFY_KEY}"

if [ -z "$DIFY_KEY" ]; then
    echo "[错误] 请设置 COPILOT_DIFY_KEY 环境变量" >&2
    exit 1
fi

QUESTION="$1"
TOOL="vcs"
if [ "$2" = "--tool" ] && [ -n "$3" ]; then
    TOOL="$3"
fi

if [ -z "$QUESTION" ]; then
    echo "用法: ask_dify.sh <问题> [--tool <工具>]"
    exit 1
fi

# 调用 Dify workflow
curl -s -X POST "$DIFY_BASE/v1/chat-messages" \
    -H "Authorization: Bearer $DIFY_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"inputs\": {\"tool\": \"$TOOL\"},
        \"query\": \"$QUESTION\",
        \"response_mode\": \"blocking\",
        \"user\": \"claude-code\"
    }" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'answer' in d:
    print(d['answer'])
elif 'message' in d:
    print(d['message'])
else:
    print(json.dumps(d, ensure_ascii=False))
"
