#!/bin/bash
# Auto-sync: detect changes and push to GitHub
# Designed to run via cron or systemd timer
set -e

REPO_DIR="$HOME/.hub/claude-config"
CLAUDE_DIR="$HOME/.claude"
LOCKFILE="/tmp/claude-config-sync.lock"
LOGFILE="$HOME/.claude/logs/auto-sync.log"

mkdir -p "$(dirname "$LOGFILE")"

# Prevent concurrent runs
exec 200>"$LOCKFILE"
flock -n 200 || { echo "$(date): Another sync in progress, skipping" >> "$LOGFILE"; exit 0; }

cd "$REPO_DIR"

# Check if there are any actual changes
git fetch origin main -q 2>/dev/null

CHANGED=false

# Check config files
for src in CLAUDE.md RTK.md session-init.sh env-wrapper.sh settings.json; do
  if ! diff -q "$CLAUDE_DIR/$src" "$REPO_DIR/$src" &>/dev/null; then
    CHANGED=true
    break
  fi
done

# Check hooks
for src in superboost-banner.sh superboost-statusline.sh ram-monitor.sh resource-check.sh resource-guard.sh agent-watchdog.sh meminfo-lib.sh; do
  if ! diff -q "$CLAUDE_DIR/hooks/$src" "$REPO_DIR/hooks/$src" &>/dev/null; then
    CHANGED=true
    break
  fi
done

# Check skills count
SKILLS_LOCAL=$(ls "$CLAUDE_DIR/skills/" 2>/dev/null | wc -l)
SKILLS_REPO=$(ls "$REPO_DIR/skills/" 2>/dev/null | wc -l)
if [ "$SKILLS_LOCAL" != "$SKILLS_REPO" ]; then
  CHANGED=true
fi

# Check agents count
AGENTS_LOCAL=$(ls "$CLAUDE_DIR/agents/" 2>/dev/null | wc -l)
AGENTS_REPO=$(ls "$REPO_DIR/agents/" 2>/dev/null | wc -l)
if [ "$AGENTS_LOCAL" != "$AGENTS_REPO" ]; then
  CHANGED=true
fi

if [ "$CHANGED" = "false" ]; then
  echo "$(date): No changes detected" >> "$LOGFILE"
  exit 0
fi

echo "$(date): Changes detected, syncing..." >> "$LOGFILE"

# Run sync
./sync.sh --auto 2>&1 | tee -a "$LOGFILE"

echo "$(date): Sync complete" >> "$LOGFILE"
