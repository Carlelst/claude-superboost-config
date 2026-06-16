#!/bin/bash
# Install auto-sync cron job (checks every 6 hours)
set -e

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/auto-sync.sh"

# Remove old entry if exists
crontab -l 2>/dev/null | grep -v "auto-sync.sh" | crontab - 2>/dev/null || true

# Add new cron entry: every 6 hours
(crontab -l 2>/dev/null; echo "0 */6 * * * $SCRIPT_PATH") | crontab -

echo "✓ Auto-sync cron installed (every 6 hours)"
echo "  Check: crontab -l"
echo "  Logs: ~/.claude/logs/auto-sync.log"
echo "  Remove: crontab -l | grep -v auto-sync | crontab -"
