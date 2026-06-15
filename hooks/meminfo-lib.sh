#!/bin/bash
# meminfo-lib.sh — Shared memory info functions
# Source this from other hook scripts to avoid duplicate /proc/meminfo reads
# Usage: source ~/.claude/hooks/meminfo-lib.sh; get_meminfo

get_meminfo() {
  if [ "$(uname)" = "Darwin" ]; then
    PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
    VM=$(vm_stat 2>/dev/null)
    FREE_P=$(echo "$VM" | awk '/^Pages free:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    INACT_P=$(echo "$VM" | awk '/^Pages inactive:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    PURG_P=$(echo "$VM" | awk '/^Pages purgeable:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    SPEC_P=$(echo "$VM" | awk '/^Pages speculative:sub(/[^0-9]/,"",$3); print $3+0}')
    AVAIL_MB=$(( (FREE_P + INACT_P + PURG_P + SPEC_P) * PAGE_SIZE / 1024 / 1024 ))
    TOTAL_MB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
    LOAD_AVG=$(uptime 2>/dev/null | awk -F'load averages:' '{print $2}' | awk '{gsub(/,/,""); print $1}')
  else
    AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    TOTAL_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    LOAD_AVG=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
  fi
  AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $AVAIL_MB / 1024}")
  TOTAL_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB / 1024}")
  USED_PCT=$(( 100 - (AVAIL_MB * 100 / TOTAL_MB) ))
}