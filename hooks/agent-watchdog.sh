#!/bin/bash
# agent-watchdog.sh — Continuous agent memory watchdog (daemon)
# Part of Claude Code Superboost - ANTI-OOM layer
# Runs as background daemon, samples memory every 2s.
# Kills newest agent if ram drops below hard threshold.
# Designed to catch the "avalanche spawn" pattern that resource-check misses.
#
# Usage: agent-watchdog.sh start    # launch daemon
#        agent-watchdog.sh stop     # kill daemon
#        agent-watchdog.sh status   # check if running
# Save to: ~/.claude/hooks/agent-watchdog.sh

HOOKS_DIR="$(dirname "$0")"
source "$HOOKS_DIR/meminfo-lib.sh"

PIDFILE="$HOME/.claude/.agent-watchdog.pid"
LOGFILE="$HOME/.claude/logs/agent-watchdog.log"
mkdir -p "$(dirname "$LOGFILE")"

# --- Config ---
CHECK_INTERVAL=2           # seconds between checks
HARD_FLOOR_MB="${RESOURCE_HARD_FLOOR_MB:-2048}"      # 2GB absolute floor — kill below
SOFT_FLOOR_MB="${RESOURCE_SOFT_FLOOR_MB:-4096}"      # 4GB — kill newest agent
RATE_THRESHOLD_MB="${RESOURCE_RATE_THRESHOLD_MB:-500}" # MB/s drain rate to trigger preemptive kill
RATE_WINDOW=10             # seconds for rate calculation
MAX_AGENTS_HARD="${RESOURCE_MAX_AGENTS_HARD:-$(( ${RESOURCE_MAX_AGENT_CAP:-30} ))}"  # absolute cap to kill above

LOCKFILE="$HOME/.claude/.agent-watchdog.lock"

cmd_start() {
  # --- Mutual exclusion via flock ---
  exec 200>"$LOCKFILE"
  flock -n 200 || { echo "Another watchdog start in progress, skipping" >&2; exit 0; }

  local self_pid=$$
  local current_pid=""

  # --- Check if watchdog is already running via PID file ---
  if [ -f "$PIDFILE" ]; then
    current_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$current_pid" ] && kill -0 "$current_pid" 2>/dev/null; then
      echo "watchdog already running (pid $current_pid)"
      exit 0
    fi
    # PID file is stale
    rm -f "$PIDFILE"
  fi

  echo "Starting agent watchdog (hard_floor=${HARD_FLOOR_MB}MB, soft_floor=${SOFT_FLOOR_MB}MB, rate_threshold=${RATE_THRESHOLD_MB}MB/s)..."

  # Background daemon (starting external script with nohup for full detachment)
  local daemon_script="$HOOKS_DIR/.agent-watchdog-daemon.sh"
  nohup bash "$daemon_script" \
    "$PIDFILE" "$LOGFILE" "$CHECK_INTERVAL" \
    "$HARD_FLOOR_MB" "$SOFT_FLOOR_MB" "$RATE_THRESHOLD_MB" "$RATE_WINDOW" \
    "$MAX_AGENTS_HARD" \
    > /dev/null 2>&1 &
  DAEMON_PID=$!

  echo "watchdog started (pid $DAEMON_PID)"
}

cmd_stop() {
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo "Stopping watchdog (pid $PID)..."
      kill "$PID" 2>/dev/null
      sleep 0.5
      kill -9 "$PID" 2>/dev/null
    fi
    rm -f "$PIDFILE"
    echo "watchdog stopped"
  else
    echo "watchdog not running"
  fi
}

cmd_status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    PID=$(cat "$PIDFILE")
    AGE=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')
    echo "watchdog running (pid=$PID, age=${AGE}s)"
    echo "last 5 log lines:"
    tail -5 "$LOGFILE"
  else
    echo "watchdog NOT running"
  fi
}

case "${1:-}" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  *)      echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac