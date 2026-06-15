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
MAX_AGENTS_HARD="${RESOURCE_MAX_AGENTS_HARD:-$(( RESOURCE_MAX_AGENT_CAP:-30 ))}"  # absolute cap to kill above

cmd_start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "watchdog already running (pid $(cat "$PIDFILE"))"
    exit 1
  fi

  echo "Starting agent watchdog (hard_floor=${HARD_FLOOR_MB}MB, soft_floor=${SOFT_FLOOR_MB}MB, rate_threshold=${RATE_THRESHOLD_MB}MB/s)..."

  # Background daemon
  (
    echo $$ > "$PIDFILE"

    # Track memory samples for rate detection
    SAMPLES=()

    while true; do
      get_meminfo 2>/dev/null

      if [ "$AVAIL_MB" -eq 0 ]; then
        sleep "$CHECK_INTERVAL"
        continue
      fi

      TIMESTAMP=$(date -u +%H:%M:%S)
      CLAUDE_COUNT=$(ps -eo comm,pid,etimes 2>/dev/null | awk -v now="$(date +%s)" '
        /^claude / {
          pid=$2
          etime=$3
          # get RSS in KB
          cmd="ps -o rss= -p " pid " 2>/dev/null"
          cmd | getline rss
          close(cmd)
          rss=int(rss/1024)
          printf "%d|%d|%d\n", pid, etime, rss
        }
      ')

      # --- Rate detection: memory drain speed ---
      if [ ${#SAMPLES[@]} -ge $((RATE_WINDOW / CHECK_INTERVAL)) ]; then
        SAMPLES=("${SAMPLES[@]:1}")
      fi
      SAMPLES+=("$AVAIL_MB")

      DRAIN_RATE=0
      if [ ${#SAMPLES[@]} -ge $((RATE_WINDOW / CHECK_INTERVAL)) ]; then
        OLDEST=${SAMPLES[0]}
        DRAIN_RATE=$(( (OLDEST - AVAIL_MB) / (${#SAMPLES[@]} * CHECK_INTERVAL) ))
      fi

      # --- Hard floor: kill newest claude processes ---
      if [ "$AVAIL_MB" -lt "$HARD_FLOOR_MB" ]; then
        NEWEST=$(echo "$CLAUDE_COUNT" | sort -t'|' -k2 -n | head -1)
        KILL_PID=$(echo "$NEWEST" | cut -d'|' -f1)
        KILL_RSS=$(echo "$NEWEST" | cut -d'|' -f3)
        echo "[$TIMESTAMP] 🚨 HARD FLOOR ${AVAIL_MB}MB < ${HARD_FLOOR_MB}MB — killing newest agent pid=$KILL_PID rss=${KILL_RSS}MB" >> "$LOGFILE"
        kill "$KILL_PID" 2>/dev/null
        sleep 1
        continue
      fi

      # --- Soft floor + high rate: preemptive kill ---
      if [ "$AVAIL_MB" -lt "$SOFT_FLOOR_MB" ] && [ "$DRAIN_RATE" -gt "$RATE_THRESHOLD_MB" ]; then
        # Find the largest newer agent (shortest running = most likely culprit)
        NEWEST=$(echo "$CLAUDE_COUNT" | sort -t'|' -k2 -n | head -1)
        KILL_PID=$(echo "$NEWEST" | cut -d'|' -f1)
        KILL_AGE=$(echo "$NEWEST" | cut -d'|' -f2)
        KILL_RSS=$(echo "$NEWEST" | cut -d'|' -f3)
        echo "[$TIMESTAMP] ⚠️ SOFT FLOOR + HIGH DRAIN ${DRAIN_RATE}MB/s — killing pid=$KILL_PID age=${KILL_AGE}s rss=${KILL_RSS}MB" >> "$LOGFILE"
        kill "$KILL_PID" 2>/dev/null
        sleep 1
        continue
      fi

      # --- Agent count hard cap ---
      AGENT_COUNT=$(echo "$CLAUDE_COUNT" | wc -l)
      if [ "$AGENT_COUNT" -gt "$MAX_AGENTS_HARD" ]; then
        OVER=$(( AGENT_COUNT - MAX_AGENTS_HARD ))
        # Kill newest N agents
        echo "$CLAUDE_COUNT" | sort -t'|' -k2 -n | head -"$OVER" | while IFS='|' read pid age rss; do
          echo "[$TIMESTAMP] 📊 AGENT CAP ${AGENT_COUNT} > ${MAX_AGENTS_HARD} — killing pid=$pid age=${age}s rss=${rss}MB" >> "$LOGFILE"
          kill "$pid" 2>/dev/null
        done
        sleep 1
        continue
      fi

      # --- Log trends (every 10th check) ---
      if [ $((RANDOM % 10)) -eq 0 ]; then
        echo "[$TIMESTAMP] avail=${AVAIL_MB}MB agents=${AGENT_COUNT} drain_rate=${DRAIN_RATE}MB/s" >> "$LOGFILE"
      fi

      sleep "$CHECK_INTERVAL"
    done
  ) &

  echo "watchdog started (pid $!)"
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