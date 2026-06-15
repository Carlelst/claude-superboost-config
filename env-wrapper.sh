#!/bin/bash
# Claude Code environment injector for Bash tool calls.

set -euo pipefail

# Guard: if jq is missing, pass through unchanged
if ! command -v jq >/dev/null 2>&1; then
  read -r input_json && echo "$input_json"
  exit 0
fi

read -r input_json 2>/dev/null || { echo "{}"; exit 0; }

# Guard: non-JSON or empty input
orig_cmd=$(echo "$input_json" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

if [ -z "$orig_cmd" ]; then
  echo "$input_json"
  exit 0
fi

CACHE="$HOME/.claude/.env_cache"

if [ ! -f "$CACHE" ] || [ ! -s "$CACHE" ]; then
  echo "$input_json"
  exit 0
fi

# Build preamble of only the vars that differ from the current process
preamble=''
# Always suppress npm/corpack noise
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" == '#'* ]] && continue
  [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && continue

  case "$key" in
    SHLVL|LINENO|PPID|BASH_FUNC_*|BASH_SOURCE*|RANDOM)
      continue ;;
    NPM_CONFIG_*|npm_config_*)
      continue ;;
  esac

  curr_val="${!key:-}"
  if [ "$curr_val" = "$value" ]; then
    continue
  fi

  preamble+="export $key=$(printf '%q' "$value" 2>/dev/null || echo "\"$value\"");"
done < "$CACHE"

# Build the final command
if [ -n "$preamble" ]; then
  new_cmd="export NPM_CONFIG_ENGINE_STRICT=false COREPACK_ENABLE_STRICT=0 npm_config_yes=true; $preamble $orig_cmd"
else
  new_cmd="export NPM_CONFIG_ENGINE_STRICT=false COREPACK_ENABLE_STRICT=0 npm_config_yes=true; $orig_cmd"
fi

# Watchdog dynamic URL override
ACTIVE_URL_FILE="/tmp/anthropic-active-url"
if [ -f "$ACTIVE_URL_FILE" ]; then
    active_url=$(cat "$ACTIVE_URL_FILE" 2>/dev/null || true)
    if [ -n "$active_url" ] && [ "$active_url" != "http://127.0.0.1:15801" ]; then
        result=$(echo "$input_json" | jq -c \
            --arg cmd "$new_cmd" \
            --arg url "$active_url" \
            '.tool_input.command = ("export ANTHROPIC_BASE_URL=" + $url + ";" + $cmd)' 2>/dev/null || echo "$input_json")
        echo "$result"
        exit 0
    fi
fi

result=$(echo "$input_json" | jq -c --arg cmd "$new_cmd" '.tool_input.command = $cmd' 2>/dev/null || echo "$input_json")
echo "$result"
