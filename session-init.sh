#!/bin/bash
# Claude Code session environment initializer

CACHE="$HOME/.claude/.env_cache"
PREAMBLE="$HOME/.claude/.env_preamble"
CACHE_DIR="$(dirname "$CACHE")"
CACHE_TTL="${ENV_CACHE_TTL:-3600}"  # 1 hour default

# Guard: ensure cache directory is writable
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# TTL check: skip if cache is fresh (within CACHE_TTL seconds)
if [ -s "$CACHE" ] && [ -s "$PREAMBLE" ] && [ -n "$(find "$CACHE" -mmin -$((CACHE_TTL/60)) 2>/dev/null)" ]; then
    :   # Cache is fresh, skip regeneration
else
    # Use login zsh, filter npm noise, with timeout
    exec -l zsh -c 'env' 2>/dev/null \
      | grep -v -E '^npm_config_|^NPM_CONFIG_|^npm_package_|^npm_lifecycle_|^npm_node_execpath|^npm_execpath' \
      > "$CACHE" 2>/dev/null || true

    # Pre-compute the env preamble for env-wrapper.sh (avoids 0.1s per Bash call)
    if [ -s "$CACHE" ]; then
        preamble=''
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" == '#'* ]] && continue
            [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && continue
            case "$key" in
                SHLVL|LINENO|PPID|BASH_FUNC_*|BASH_SOURCE*|RANDOM) continue ;;
                NPM_CONFIG_*|npm_config_*) continue ;;
            esac
            curr_val="${!key:-}"
            if [ "$curr_val" = "$value" ]; then continue; fi
            preamble+="export $key=$(printf '%q' "$value" 2>/dev/null || echo "\"$value\"");"
        done < "$CACHE"
        echo "$preamble" > "$PREAMBLE" 2>/dev/null || true
    fi
fi

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

# Dynamic API URL override (moved from env-wrapper — check once per session, not per Bash call)
ACTIVE_URL_FILE="/tmp/anthropic-active-url"
if [ -f "$ACTIVE_URL_FILE" ]; then
    active_url=$(cat "$ACTIVE_URL_FILE" 2>/dev/null || true)
    if [ -n "$active_url" ] && [ "$active_url" != "http://127.0.0.1:15801" ]; then
        export ANTHROPIC_BASE_URL="$active_url"
        export OPENDODE_BASE_URL="$active_url"
        export DEEPSEEK_BASE_URL="$active_url"
    fi
fi

# TTL: skip tool checks if status is fresh
if [ -s "$ALERT_DIR/status.txt" ] && [ -n "$(find "$ALERT_DIR/status.txt" -mmin -60 2>/dev/null)" ]; then
    :   # Tool status is fresh, skip checks
else
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

    echo "$TOOL_STATUS" > "$ALERT_DIR/status.txt" 2>/dev/null || true
fi
