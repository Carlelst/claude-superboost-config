#!/bin/bash
# superboost-banner.sh — SessionStart hook for Claude Code Superboost V3
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
# Save to: ~/.claude/hooks/superboost-banner.sh

HOOKS_DIR="$(dirname "$0")"
source "$HOOKS_DIR/meminfo-lib.sh"

SUPERBOOST_VERSION="3.0"
SETTINGS="$HOME/.claude/settings.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# ─── Self-Test ───────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0
ISSUES=""

check_pass() { PASS=$((PASS + 1)); }
check_fail() { FAIL=$((FAIL + 1)); ISSUES="${ISSUES}FAIL: $1\n"; }
check_warn() { WARN=$((WARN + 1)); ISSUES="${ISSUES}WARN: $1\n"; }

# 1. Critical hooks exist
for script in resource-check.sh ram-monitor.sh superboost-banner.sh superboost-statusline.sh; do
  if [ -x "$HOOKS_DIR/$script" ]; then
    check_pass
  else
    check_fail "$script missing or not executable"
  fi
done

# 2. settings.json exists
if [ -f "$SETTINGS" ]; then
  check_pass
  grep -q 'SessionStart' "$SETTINGS" 2>/dev/null && check_pass || check_warn "SessionStart hook not configured"
  grep -q 'superboost-banner' "$SETTINGS" 2>/dev/null && check_pass || check_warn "superboost-banner not bound"
  grep -q 'ram-monitor' "$SETTINGS" 2>/dev/null && check_pass || check_warn "ram-monitor not configured"
  grep -q 'superboost-statusline' "$SETTINGS" 2>/dev/null && check_pass || check_warn "statusLine not configured"
else
  check_fail "settings.json not found"
fi

# 3. CLAUDE.md exists
if [ -f "$CLAUDE_MD" ]; then
  check_pass
else
  check_warn "CLAUDE.md not found"
fi

# 4. Resource check functional
CHECK_JSON=$("$HOOKS_DIR/resource-check.sh" --quiet 2>/dev/null)
if echo "$CHECK_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  check_pass
else
  check_fail "resource-check.sh returned invalid output"
fi

# 5. Agent dispatch skill available
if [ -d "$HOME/.claude/skills/agent-dispatch" ]; then
  check_pass
else
  check_warn "agent-dispatch skill not found"
fi

# 6. Web search system
if [ -x /usr/local/bin/searx ] && [ -x "$HOME/.local/bin/web" ]; then
  check_pass
else
  check_warn "web search system incomplete"
fi

get_meminfo

# Compute max agents
SAFETY_MB=$(( TOTAL_MB * 10 / 100 ))
[ "$SAFETY_MB" -lt 2048 ] && SAFETY_MB=2048
PER_AGENT_MB="${RESOURCE_PER_AGENT_MB:-1000}"
MAX_AGENTS=$(( (AVAIL_MB - SAFETY_MB) / PER_AGENT_MB ))
[ "$MAX_AGENTS" -lt 0 ] && MAX_AGENTS=0
[ "$MAX_AGENTS" -gt "${RESOURCE_MAX_AGENT_CAP:-30}" ] && MAX_AGENTS="${RESOURCE_MAX_AGENT_CAP:-30}"

# Pick status
if [ "$AVAIL_MB" -gt 8192 ]; then STATUS="HEALTHY"
elif [ "$AVAIL_MB" -gt 4096 ]; then STATUS="MODERATE"
else STATUS="LOW"; fi

# Verdict
TOTAL=$((PASS + FAIL + WARN))
if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
  SELFTEST_ICON="✅"; SELFTEST_VERDICT="ALL SYSTEMS GO"
elif [ $FAIL -eq 0 ]; then
  SELFTEST_ICON="⚠️"; SELFTEST_VERDICT="OPERATIONAL (${WARN} warning(s))"
else
  SELFTEST_ICON="❌"; SELFTEST_VERDICT="DEGRADED (${FAIL} failure(s), ${WARN} warning(s))"
fi

ISSUE_BLOCK=""
if [ $FAIL -gt 0 ] || [ $WARN -gt 0 ]; then
  ISSUE_LIST=$(echo -e "$ISSUES" | sed '/^$/d' | sed 's/^/- /')
  ISSUE_BLOCK="
> **Issues detected:**
${ISSUE_LIST}
"
fi

cat <<EOF
SUPERBOOST SESSION START — Display the following banner to the user as your FIRST output before doing anything else. Use exactly this markdown format:

---
**ISYNCSO SUPERBOOST V${SUPERBOOST_VERSION}**

| Metric | Value |
|--------|-------|
| Version | V${SUPERBOOST_VERSION} |
| Boot Check | ${SELFTEST_ICON} ${SELFTEST_VERDICT} (${PASS}/${TOTAL} checks passed) |
| RAM | ${AVAIL_GB} GB free / ${TOTAL_GB} GB |
| CPU Load | ${LOAD_AVG} |
| Max Agents | ${MAX_AGENTS} |
| Status | ${STATUS} |
${ISSUE_BLOCK}
*Resource monitoring active. Auto-router enabled. Agent Dispatch Protocol armed.*
*For support: [isyncso.com](https://www.isyncso.com) | innovate@isyncso.com (Subject: Superboost V${SUPERBOOST_VERSION})*

---

After the banner, you MUST do the following:

1. Check if /tmp/claude-tool-status/ALERT.txt exists. If it does, read it
   and display its content to the user as a RED/BOLD warning before anything else.

2. Also check /tmp/claude-tool-status/status.txt (the newest file matching
   /tmp/claude-tool-status/status.txt). Parse the pipe-delimited rows and
   display a "🧰 工具链状态" table to the user.

For any row marked ❌, tell the user exactly what command to run.
For any row marked ⚠️, mention it's optional and what's missing.

Then proceed normally with whatever the user asks.
EOF

exit 0