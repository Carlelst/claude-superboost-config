#!/bin/bash
# Sync local Claude Code config to claude-superboost-config repo
set -e

REPO_DIR="$HOME/.hub/claude-config"
CLAUDE_DIR="$HOME/.claude"

cd "$REPO_DIR"

echo "Syncing Claude Code config..."

# 1. Sync config files
cp "$CLAUDE_DIR/CLAUDE.md" ./CLAUDE.md
cp "$CLAUDE_DIR/RTK.md" ./RTK.md
cp "$CLAUDE_DIR/session-init.sh" ./
cp "$CLAUDE_DIR/env-wrapper.sh" ./
cp "$CLAUDE_DIR/settings.json" ./settings.json

# 2. Sync hooks
mkdir -p hooks
cp "$CLAUDE_DIR/hooks/superboost-banner.sh" hooks/
cp "$CLAUDE_DIR/hooks/superboost-statusline.sh" hooks/
cp "$CLAUDE_DIR/hooks/ram-monitor.sh" hooks/
cp "$CLAUDE_DIR/hooks/resource-check.sh" hooks/
cp "$CLAUDE_DIR/hooks/agent-watchdog.sh" hooks/
cp "$CLAUDE_DIR/hooks/meminfo-lib.sh" hooks/

# 3. Sync skills (only new/changed)
mkdir -p skills
rsync -a --delete "$CLAUDE_DIR/skills/" skills/ 2>/dev/null || cp -r "$CLAUDE_DIR/skills/" skills/

# 4. Sync agents
mkdir -p agents
rsync -a --delete "$CLAUDE_DIR/agents/" agents/ 2>/dev/null || cp -r "$CLAUDE_DIR/agents/" agents/

# 5. Sync marketplaces
python3 -c "
import json
d=json.load(open('$CLAUDE_DIR/settings.json'))
print(json.dumps(d.get('extraKnownMarketplaces',{}), indent=2))
" > marketplaces.json

# 6. Sync docs
mkdir -p docs
cp "$CLAUDE_DIR/docs/TOOLCHAIN.md" docs/ 2>/dev/null || true
cp "$CLAUDE_DIR/docs/ARCHITECTURE.md" docs/ 2>/dev/null || true

# 7. Show diff and commit
echo ""
echo "Changes:"
git diff --stat

echo ""
read -p "Commit and push? [Y/n] " answer
case $answer in
  [Nn]*) echo "Skipped."; exit 0 ;;
esac

git add -A
git commit -m "Sync: $(date +%Y-%m-%d)" 2>&1 || echo "Nothing to commit"
git push origin main 2>&1
echo ""
echo "✓ Synced and pushed"
