#!/bin/bash
# Sync local Claude Code config to claude-superboost-config repo
set -e

AUTO_MODE=false
[ "${1:-}" = "--auto" ] && AUTO_MODE=true

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
for h in superboost-banner.sh superboost-statusline.sh ram-monitor.sh resource-check.sh resource-guard.sh agent-watchdog.sh meminfo-lib.sh code-simplifier.mjs keyword-detector.mjs persistent-mode.mjs; do
  [ -f "$CLAUDE_DIR/hooks/$h" ] && cp "$CLAUDE_DIR/hooks/$h" hooks/
done

# 3. Sync skills
mkdir -p skills
rsync -a --delete "$CLAUDE_DIR/skills/" skills/ 2>/dev/null || cp -r "$CLAUDE_DIR/skills/" skills/

# 4. Sync agents
mkdir -p agents
rsync -a --delete "$CLAUDE_DIR/agents/" agents/ 2>/dev/null || cp -r "$CLAUDE_DIR/agents/" agents/

# 5. Sync self-built tools
mkdir -p tools/search tools/hooks
for t in web web-extract web-synthesize web-version rerank; do
  [ -f "$HOME/.local/bin/$t" ] && cp "$HOME/.local/bin/$t" tools/search/
done

# 6. Sync marketplaces + OMC config
python3 -c "
import json
d=json.load(open('$CLAUDE_DIR/settings.json'))
print(json.dumps(d.get('extraKnownMarketplaces',{}), indent=2))
" > marketplaces.json

[ -f "$CLAUDE_DIR/.omc-config.json" ] && cp "$CLAUDE_DIR/.omc-config.json" ./ || true

# 7. Sync docs
mkdir -p docs
for d in TOOLCHAIN.md ARCHITECTURE.md SETUP_GUIDE.md; do
  [ -f "$CLAUDE_DIR/docs/$d" ] && cp "$CLAUDE_DIR/docs/$d" docs/
done

# 8. Sync tools search directory docs
for d in web web-extract web-synthesize web-version rerank; do
  [ -f "$HOME/.local/bin/$d" ] && cp "$HOME/.local/bin/$d" tools/search/
done

# Show diff
echo ""
echo "Changes:"
git diff --stat

# Commit
if [ "$AUTO_MODE" = "true" ]; then
  if ! git diff --quiet; then
    git add -A
    git commit -m "Auto-sync: $(date +%Y-%m-%d)" 2>&1
    git push origin main 2>&1
    echo "✓ Auto-synced and pushed"
  fi
else
  read -p "Commit and push? [Y/n] " answer
  case $answer in
    [Nn]*) echo "Skipped."; exit 0 ;;
  esac
  git add -A
  git commit -m "Sync: $(date +%Y-%m-%d)" 2>&1 || echo "Nothing to commit"
  git push origin main 2>&1
  echo "✓ Synced and pushed"
fi
