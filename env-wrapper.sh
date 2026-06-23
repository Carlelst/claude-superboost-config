#!/bin/bash
# Claude Code environment injector for Bash tool calls (optimized: pre-computed preamble)

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  read -r input_json && echo "$input_json"; exit 0
fi

read -r input_json 2>/dev/null || { echo "{}"; exit 0; }

orig_cmd=$(echo "$input_json" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
if [ -z "$orig_cmd" ]; then
  echo "$input_json"; exit 0
fi

# Read pre-computed preamble from session-init.sh (generated once per TTL window)
PREAMBLE_FILE="$HOME/.claude/.env_preamble"
preamble=''
if [ -f "$PREAMBLE_FILE" ] && [ -s "$PREAMBLE_FILE" ]; then
  preamble=$(cat "$PREAMBLE_FILE" 2>/dev/null || true)
elif [ -f "$HOME/.claude/.env_cache" ] && [ -s "$HOME/.claude/.env_cache" ]; then
  # Fallback: compute on-the-fly (only if preamble is missing)
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
  done < "$HOME/.claude/.env_cache"
fi

new_cmd="export NPM_CONFIG_ENGINE_STRICT=false COREPACK_ENABLE_STRICT=0 npm_config_yes=true"
[ -n "$preamble" ] && new_cmd="$new_cmd; $preamble"
new_cmd="$new_cmd; $orig_cmd"

# Watchdog dynamic URL override
ACTIVE_URL_FILE="/tmp/anthropic-active-url"
if [ -f "$ACTIVE_URL_FILE" ]; then
    active_url=$(cat "$ACTIVE_URL_FILE" 2>/dev/null || true)
    if [ -n "$active_url" ] && [ "$active_url" != "http://127.0.0.1:15801" ]; then
        echo "$input_json" | jq -c \
            --arg cmd "$new_cmd" \
            --arg url "$active_url" \
            '.tool_input.command = ("export ANTHROPIC_BASE_URL=" + $url + ";" + $cmd)' 2>/dev/null || echo "$input_json"
        exit 0
    fi
fi

echo "$input_json" | jq -c --arg cmd "$new_cmd" '.tool_input.command = $cmd' 2>/dev/null || echo "$input_json"
