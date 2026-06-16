#!/bin/bash
# resource-guard.sh — PreToolUse hook: blocks agent spawning when resources are low
# Part of Claude Code Superboost V3 — Anti-OOM layer
# Configured in settings.json: matcher=Agent → this script
#
# Logic:
#   1. Non-Agent tool calls → pass through immediately (exit 0)
#   2. Agent calls → run resource-check.sh → block if resource-check says no
#   3. If resource-check is blocked AND watchdog is running, watchdog handles it
#      This hook is the FIRST LINE — watchdog is the LAST RESORT
# Save to: ~/.claude/hooks/resource-guard.sh

HOOKS_DIR="$(dirname "$0")"
HOOK_LOG="${HOME}/.claude/logs/resource-guard.log"
mkdir -p "$(dirname "$HOOK_LOG")"

TOOL_INPUT=$(cat)

# Extract tool_name from stdin JSON
TOOL_NAME=$(echo "$TOOL_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', d.get('name', '')))
except:
    print('')
" 2>/dev/null || echo "")

# Only guard spawning operations
case "$TOOL_NAME" in
    Agent|TeamCreate|mcp__spawn-agent)
        : # fall through to check
        ;;
    *)
        exit 0  # allow non-spawn tools unconditionally
        ;;
esac

# Run resource check
CHECK_JSON=$("${HOOKS_DIR}/resource-check.sh" --quiet 2>/dev/null || echo '{"can_spawn":false,"reason":"check_failed","exit":1}')
CHECK_EXIT=$?

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "[$TIMESTAMP] Tool=$TOOL_NAME Exit=$CHECK_EXIT Check=$CHECK_JSON" >> "$HOOK_LOG"

if [ "$CHECK_EXIT" -eq 1 ]; then
    # Hard block
    REASON=$(echo "$CHECK_JSON" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    avail = d.get('available_gb', '?')
    reason = d.get('reason', 'unknown')
    procs = d.get('claude_processes', '?')
    rss = d.get('claude_rss_mb', '?')
    print(f'RESOURCE GUARD BLOCKED: {reason}. Available: {avail}GB, Agents: {procs} (RSS: {rss}MB)')
except:
    print('RESOURCE GUARD BLOCKED: insufficient resources')
" 2>/dev/null || echo "Resource guard: spawn blocked — system low on memory.")
    echo "$REASON" >&2
    echo "[$TIMESTAMP] BLOCKED: $REASON" >> "$HOOK_LOG"
    exit 1
fi

# exit 2 = warning — still allow spawn
exit 0