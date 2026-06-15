#!/bin/bash
# Claude Code Superboost 配置安装脚本
set -e
echo "Installing Claude Code Superboost config..."

# Backup existing config
mkdir -p ~/.claude/backups
cp ~/.claude/settings.json ~/.claude/backups/settings.json.bak 2>/dev/null || true
cp ~/.claude/CLAUDE.md ~/.claude/backups/CLAUDE.md.bak 2>/dev/null || true

# Install files
cp CLAUDE.md ~/.claude/
cp RTK.md ~/.claude/
cp session-init.sh ~/.claude/
cp env-wrapper.sh ~/.claude/
chmod +x ~/.claude/session-init.sh ~/.claude/env-wrapper.sh

# Install hooks
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

echo "Done. Restart Claude Code to apply."
