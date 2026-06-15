#!/bin/bash
# resource-check.sh — Pre-spawn resource health check for Claude Code agent teams
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
#
# Anti-OOM v2: two-tier protection
#   Soft: block when drain rate is dangerous (avalanche spawn pattern)
#   Hard: block when dangerously low on memory
#
# Usage: ./resource-check.sh [--min-agents N] [--quiet]
# Exit codes: 0 = safe, 1 = blocked (hard limit), 2 = warning (proceed with caution)
# Save to: ~/.claude/hooks/resource-check.sh

HOOKS_DIR="$(dirname "$0")"
source "$HOOKS_DIR/meminfo-lib.sh"

# --- Configuration (overridable via environment) ---
MIN_AVAILABLE_GB="${RESOURCE_MIN_AVAILABLE_GB:-6}"        # Hard block below 6GB
PER_AGENT_MB="${RESOURCE_PER_AGENT_MB:-1000}"             # Realistic: 874-1190MB measured
MAX_AGENT_CAP="${RESOURCE_MAX_AGENT_CAP:-20}"              # Conservative cap
MIN_AGENTS=1
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --min-agents) MIN_AGENTS="$2"; shift 2 ;;
        --quiet|-q) QUIET=true; shift ;;
        *) shift ;;
    esac
done

# --- Helpers ---
log()  { $QUIET || echo -e "$@"; }
warn() { $QUIET || echo -e "${YELLOW:-}WARNING: $1${NC:-}" >&2; }
err()  { echo -e "${RED:-}ERROR: $1${NC:-}" >&2; }

get_meminfo

# Swap check (Linux only)
SWAP_USED=0
# /proc/swaps columns: Filename Type Size Used Priority → $4 is Used
[ "$(uname)" != "Darwin" ] && SWAP_USED=$(awk 'NR>1 {used+=$4} END {print int(used/1024)}' /proc/swaps 2>/dev/null || echo 0)

# Active claude processes with RSS tracking
CLAUDE_INFO=$(ps -eo comm,pid,rss 2>/dev/null | awk '/^claude / {total_rss+=$3; count++} END {printf "%d|%d\n", count, int(total_rss/1024)}')
CLAUDE_PROCS=$(echo "$CLAUDE_INFO" | cut -d'|' -f1)
CLAUDE_TOTAL_RSS_MB=$(echo "$CLAUDE_INFO" | cut -d'|' -f2)

# Compute safe spawn count
SAFETY_MARGIN_MB=$(( TOTAL_MB * 15 / 100 ))   # 15% safety margin
[ "$SAFETY_MARGIN_MB" -lt 4096 ] && SAFETY_MARGIN_MB=4096  # min 4GB
REQUIRED_MB=$(( MIN_AGENTS * PER_AGENT_MB + SAFETY_MARGIN_MB ))
MAX_NEW=$(( (AVAIL_MB - SAFETY_MARGIN_MB) / PER_AGENT_MB ))
[ "$MAX_NEW" -lt 0 ] && MAX_NEW=0
[ "$MAX_NEW" -gt "$MAX_AGENT_CAP" ] && MAX_NEW=$MAX_AGENT_CAP

EXIT_CODE=0
REASON="OK"

# --- Hard blocks ---
if [ "$AVAIL_MB" -lt "$(( MIN_AVAILABLE_GB * 1024 ))" ]; then
    err "BLOCKED: Insufficient RAM. Have ${AVAIL_GB}GB, need ${MIN_AVAILABLE_GB}GB minimum."
    REASON="low_ram:${AVAIL_GB}GB"; EXIT_CODE=1
fi

if [ "$AVAIL_MB" -lt "$REQUIRED_MB" ]; then
    err "BLOCKED: Not enough RAM for ${MIN_AGENTS} agent(s). Have ${AVAIL_GB}GB, need ${REQUIRED_MB}MB."
    REASON="insufficient_for_count:${MIN_AGENTS}"; EXIT_CODE=1
fi

if [ "$CLAUDE_PROCS" -ge "$MAX_AGENT_CAP" ]; then
    err "BLOCKED: ${CLAUDE_PROCS} agents running (cap: ${MAX_AGENT_CAP})."
    REASON="rate_limit_cap"; EXIT_CODE=1
fi

if [[ "${SWAP_USED:-0}" =~ ^[0-9]+$ ]] && [ "${SWAP_USED:-0}" -gt 10000 ]; then
    err "BLOCKED: Heavy swapping (${SWAP_USED}MB)."
    REASON="swapping"; EXIT_CODE=1
fi

# --- Avalanche detection: existing agents already consuming too much ---
# If current agents collectively use >50% of available RAM above safety margin,
# spawning more is dangerous — this catches the "7 agents at 14GB → spawn more → OOM" pattern
if [ "$EXIT_CODE" -eq 0 ] && [ "$CLAUDE_PROCS" -ge 3 ]; then
    WORKING_POOL=$(( AVAIL_MB - SAFETY_MARGIN_MB ))
    # Estimate new agent at PER_AGENT_MB, check if we'd dip below 20% of working pool
    ESTIMATED_AFTER=$(( WORKING_POOL - PER_AGENT_MB ))
    USAGE_RATIO=$(( (WORKING_POOL - ESTIMATED_AFTER + CLAUDE_TOTAL_RSS_MB) * 100 / (WORKING_POOL + CLAUDE_TOTAL_RSS_MB) ))
    if [ "$CLAUDE_TOTAL_RSS_MB" -gt "$WORKING_POOL" ]; then
        err "BLOCKED: Agent memory pressure. ${CLAUDE_PROCS} agents using ${CLAUDE_TOTAL_RSS_MB}MB > ${WORKING_POOL}MB working pool."
        REASON="agent_memory_pressure"; EXIT_CODE=1
    fi
fi

# --- Soft warnings ---
LOAD_INT="${LOAD_AVG%%.*}"
MAX_INT="${RESOURCE_MAX_LOAD:-14}"
if [ "${LOAD_INT:-0}" -gt "${MAX_INT:-14}" ] && [ "$EXIT_CODE" -eq 0 ]; then
    warn "High CPU load (${LOAD_AVG} > ${MAX_INT}). Agents may be slower."
    EXIT_CODE=2
    REASON="high_load"
fi

# Machine-readable JSON
SAFE=$( [ "$EXIT_CODE" -le 2 ] && [ "$EXIT_CODE" -ne 1 ] && echo "true" || echo "false" )
JSON="{\"can_spawn\":${SAFE},\"reason\":\"${REASON}\",\"available_ram_mb\":${AVAIL_MB},\"available_gb\":${AVAIL_GB},\"total_ram_mb\":${TOTAL_MB},\"cpu_load\":\"${LOAD_AVG}\",\"claude_processes\":${CLAUDE_PROCS},\"claude_rss_mb\":${CLAUDE_TOTAL_RSS_MB},\"max_new_agents\":${MAX_NEW},\"used_pct\":${USED_PCT},\"exit\":${EXIT_CODE}}"

if $QUIET; then
    echo "$JSON"
else
    echo "Available: ${AVAIL_GB}GB | Agents: ${CLAUDE_PROCS} (${CLAUDE_TOTAL_RSS_MB}MB) | Max new: ${MAX_NEW} | Load: ${LOAD_AVG}"
    echo "JSON: $JSON"
fi

exit $EXIT_CODE