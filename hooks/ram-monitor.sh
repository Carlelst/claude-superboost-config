#!/bin/bash
# ram-monitor.sh — PostToolUse RAM monitor
HOOKS_DIR="$(dirname "$0")"

# Guard: if meminfo-lib missing, silently exit
if [ ! -f "$HOOKS_DIR/meminfo-lib.sh" ]; then
  exit 0
fi
source "$HOOKS_DIR/meminfo-lib.sh"

LOGDIR="$HOME/.claude/logs"
mkdir -p "$LOGDIR" 2>/dev/null || { exit 0; }

get_meminfo

# Guard: if memory info is zero, exit silently (procfs not available)
if [ "${AVAIL_MB:-0}" -eq 0 ] && [ "${TOTAL_MB:-0}" -eq 0 ]; then
  exit 0
fi

# Counter file with fallback
COUNTER_FILE="$LOGDIR/.ram-counter"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE" 2>/dev/null || true

# Periodic heavy check: every 50th call, only when memory is tight
PROC_INFO=""
if [ $((COUNT % 50)) -eq 0 ] && [ "${USED_PCT:-0}" -gt 70 ]; then
  TOP_PROCS=$(ps --no-headers -eo rss,comm 2>/dev/null | awk '{mem[$2]+=$1} END {for(p in mem) if(mem[p]>200000) printf "%s=%.0fMB ", p, mem[p]/1024}' 2>/dev/null || true)
  PROC_INFO=" procs=[$TOP_PROCS]"
fi

TIMESTAMP=$(date -u +%H:%M:%S 2>/dev/null || echo "unknown")
echo "$TIMESTAMP avail=${AVAIL_MB:-0}MB used=${USED_PCT:-0}%${PROC_INFO}" >> "$LOGFILE" 2>/dev/null || true

# Alert only if metrics are valid
if [ "${USED_PCT:-0}" -gt 90 ] && [ "${TOTAL_MB:-0}" -gt 0 ]; then
  echo "CRITICAL: Memory at ${USED_PCT}% (${AVAIL_GB:-?}GB free)" >&2
  exit 2
elif [ "${USED_PCT:-0}" -gt 80 ] && [ "${TOTAL_MB:-0}" -gt 0 ]; then
  echo "WARNING: Memory pressure — ${USED_PCT}% used (${AVAIL_GB:-?}GB free).${PROC_INFO}" >&2
fi

exit 0
