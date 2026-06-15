#!/bin/bash
# statusline.sh — model + RAM bar + context bar + agents + time
INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"' 2>/dev/null)
CTX_PCT_RAW=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
CTX_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
CTX_PCT=$(awk "BEGIN {printf \"%.0f\", $CTX_PCT_RAW}")
DURATION=$(echo "$INPUT" | jq -r '.duration.total_seconds // 0' 2>/dev/null)

# ---- Model → context window size fallback ----
if [ "$CTX_SIZE" -le 0 ] 2>/dev/null; then
  case "$MODEL" in
    *Opus*)   CTX_SIZE=200000 ;;
    *Sonnet*) CTX_SIZE=200000 ;;
    *Haiku*)  CTX_SIZE=200000 ;;
    *deepseek*) CTX_SIZE=128000 ;;
    *)        CTX_SIZE=200000 ;;
  esac
fi

# ---- System RAM ----
TOTAL_MB=$(awk '/MemTotal/    {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
AVAIL_MB=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "$TOTAL_MB")

# ---- Claude process RSS ----
if [ "$(uname)" = "Darwin" ]; then
  CLAUDE_MB=$(ps -eo rss,comm 2>/dev/null | awk '/[Cc]laude$/ && !/awk/ {s+=$1} END {printf "%.0f", s/1024}')
else
  CLAUDE_MB=$(ps -eo rss,comm --no-headers 2>/dev/null | awk '/[Cc]laude$/ {s+=$1} END {printf "%.0f", s/1024}')
fi
CLAUDE_MB="${CLAUDE_MB:-0}"

# ---- Token/context numbers ----
CTX_USED=0
if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
  CTX_USED=$(awk "BEGIN {printf \"%.0f\", ($CTX_PCT_RAW / 100) * $CTX_SIZE}")
fi

# ---- Human-readable token sizes ----
human_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1fM\", $n / 1000000}"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.0fK\", $n / 1000}"
  else
    echo "${n}"
  fi
}
CTX_USED_HR=$(human_tokens "$CTX_USED")
CTX_TOTAL_HR=$(human_tokens "$CTX_SIZE")

# ---- Subagents ----
CLAUDE_PIDS=$(pgrep -x claude 2>/dev/null || true)
if [ -n "$CLAUDE_PIDS" ]; then
  AGENT_COUNT=$(echo "$CLAUDE_PIDS" | wc -l)
else
  AGENT_COUNT=0
fi
AGENT_COUNT=$(( AGENT_COUNT - 1 ))
[ "$AGENT_COUNT" -lt 0 ] && AGENT_COUNT=0

PER_AGENT=800
MAX_AGENTS=$(( (AVAIL_MB - 2048) / PER_AGENT ))
[ "$MAX_AGENTS" -lt 0 ] 2>/dev/null && MAX_AGENTS=0
[ "$MAX_AGENTS" -gt 15 ] 2>/dev/null && MAX_AGENTS=15

# ---- Session time ----
TIME_STR=""
if [ "$(echo "$DURATION > 0" | bc 2>/dev/null)" = "1" ]; then
  H=$(( ${DURATION%.*} / 3600 ))
  M=$(( (${DURATION%.*} % 3600) / 60 ))
  if [ "$H" -gt 0 ] 2>/dev/null; then
    TIME_STR=" │ ${H}h${M}m"
  else
    TIME_STR=" │ ${M}m"
  fi
fi

# ---- Progress bar helper ----
bar() {
  local pct=$1 color=$2
  local filled=$(( pct / 10 ))
  local empty=$(( 10 - filled ))
  local out="" i
  for ((i=0; i<filled; i++)); do out+="${color}█\033[0m"; done
  for ((i=0; i<empty;  i++)); do out+="░"; done
  printf '%b' "$out"
}

# ---- RAM bar: system used / system total ----
SYS_USED_MB=$(( TOTAL_MB - AVAIL_MB ))
SYS_USED_PCT=$(( SYS_USED_MB * 100 / TOTAL_MB ))
[ "$SYS_USED_PCT" -gt 100 ] 2>/dev/null && SYS_USED_PCT=100
[ "$SYS_USED_PCT" -lt 0 ]   2>/dev/null && SYS_USED_PCT=0

# ---- RAM label ----
SYS_USED_G=$(awk "BEGIN {printf \"%.1f\", $SYS_USED_MB / 1024}")
TOTAL_G=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB / 1024}")
CLAUDE_G=$(awk "BEGIN {printf \"%.1f\", $CLAUDE_MB / 1024}")

# ---- Colors (computed AFTER the percentages are known) ----
if   [ "$SYS_USED_PCT" -lt 50 ] 2>/dev/null; then RAM_C='\033[32m'
elif [ "$SYS_USED_PCT" -lt 80 ] 2>/dev/null; then RAM_C='\033[33m'
else RAM_C='\033[31m'
fi

if   [ "$CTX_PCT" -lt 50 ] 2>/dev/null; then CTX_C='\033[32m'
elif [ "$CTX_PCT" -lt 80 ] 2>/dev/null; then CTX_C='\033[33m'
else CTX_C='\033[31m'
fi

# ---- Render ----
RAM_BAR=$(bar "$SYS_USED_PCT" "$RAM_C")
CTX_BAR=$(bar "$CTX_PCT" "$CTX_C")

printf '%b' "${MODEL} │ RAM:${RAM_BAR} ${SYS_USED_G}G/${TOTAL_G}G │ ctx:${CTX_BAR} ${CTX_USED_HR}/${CTX_TOTAL_HR}│ agents:${AGENT_COUNT}/${MAX_AGENTS}${TIME_STR}"