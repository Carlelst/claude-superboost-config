#!/bin/bash
# Claude Code session environment initializer

CACHE="$HOME/.claude/.env_cache"
CACHE_DIR="$(dirname "$CACHE")"

# Guard: ensure cache directory is writable
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Use login zsh, filter npm noise, with timeout
exec -l zsh -c 'env' 2>/dev/null \
  | grep -v -E '^npm_config_|^NPM_CONFIG_|^npm_package_|^npm_lifecycle_|^npm_node_execpath|^npm_execpath' \
  > "$CACHE" 2>/dev/null || true

# Guard against empty cache (zsh may have failed)
if [ ! -s "$CACHE" ]; then
  echo "Warning: environment cache is empty — zsh may not be available" >&2
fi

# Start agent watchdog daemon for ANTI-OOM protection
~/.claude/hooks/agent-watchdog.sh start 2>/dev/null || true

# ─── Tool Status Check ──────────────────────────────────────
TOOL_STATUS=""
ALERT_DIR="/tmp/claude-tool-status"
mkdir -p "$ALERT_DIR" 2>/dev/null || true

check_tool() {
  local name="$1" cmd="$2" action="$3"
  if eval "$cmd" 2>/dev/null; then
    TOOL_STATUS="${TOOL_STATUS}| ✅ ${name} 已就绪 |"
  else
    TOOL_STATUS="${TOOL_STATUS}| ⚠️ ${name} — ${action} |"
  fi
}

check_tool "RTK"       "rtk --version >/dev/null 2>&1"      "rtk 未安装"
check_tool "lean-ctx"  "lean-ctx --version >/dev/null 2>&1"  "lean-ctx 未安装"
check_tool "fff"       "fff-mcp --version >/dev/null 2>&1"   "fff 未安装"
check_tool "headroom"  "headroom --version >/dev/null 2>&1"  "headroom 未安装"
check_tool "codeburn"  "codeburn --version >/dev/null 2>&1"  "codeburn 未安装"
check_tool "beads"     "bd version >/dev/null 2>&1"          "beads 未安装"

# Beads project init check
if git rev-parse --git-dir >/dev/null 2>&1; then
  if [ -d ".beads" ]; then
    TOOL_STATUS="${TOOL_STATUS}| ✅ beads 已初始化 (.beads/) |"
  else
    TOOL_STATUS="${TOOL_STATUS}| ❌ beads 未初始化 |"
    cat > "$ALERT_DIR/ALERT.txt" << 'ALERTEOF' 2>/dev/null || true
🔴 当前在 git 仓库中但 beads 未初始化。
请立即执行: bd init
（每个项目只需执行一次，之后自动生效）
ALERTEOF
  fi
else
  TOOL_STATUS="${TOOL_STATUS}| ℹ️ 非 git 仓库 |"
  rm -f "$ALERT_DIR/ALERT.txt" 2>/dev/null || true
fi

# Write status
echo "$TOOL_STATUS" > "$ALERT_DIR/status.txt" 2>/dev/null || true
