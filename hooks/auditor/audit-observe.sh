#!/bin/bash
# ============================================================
# audit-observe.sh — 纯观察审核（PostToolUse，永不阻断）
# ============================================================
# V2.1: 按 session 分日志、修复误报、补 Grep/Glob 覆盖
# ============================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 按 session 分文件，避免并行写入损坏
AUDIT_DIR="${HOME}/.claude/audit"
mkdir -p "$AUDIT_DIR"
AUDIT_LOG="${AUDIT_DIR}/${SESSION_ID}.jsonl"

audit() {
    local level="$1" category="$2" summary="$3" detail="$4"
    jq -nc --arg ts "$TIMESTAMP" --arg sid "$SESSION_ID" \
           --arg tool "$TOOL_NAME" --arg level "$level" \
           --arg cat "$category" --arg sum "$summary" \
           --arg detail "$detail" --arg cwd "$CWD" \
           --arg input "$(echo "$TOOL_INPUT" | jq -c 'del(.command)|del(.content)|del(.old_string)|del(.new_string)')" \
           '{timestamp:$ts,session_id:$sid,tool:$tool,level:$level,category:$cat,summary:$sum,detail:$detail,cwd:$cwd,input_summary:$input}' \
           >> "$AUDIT_LOG"
}

# ============================================================
# Bash 审核
# ============================================================
audit_bash() {
    local cmd
    cmd=$(echo "$TOOL_INPUT" | jq -r '.command // ""')
    [[ -z "$cmd" || "$cmd" == "null" ]] && return

    # --- HIGH ---
    # 递归删除根目录（含变体：--no-preserve-root、find -exec rm、xargs rm）
    if echo "$cmd" | grep -qE '(rm\s+-rf\s+/|rm\s+-rf\s+--no-preserve-root\s+/|find\s+/.*-exec\s+rm|find\s+/.*\|.*xargs\s+rm)'; then
        audit HIGH security "递归删除根目录" "$cmd"
    fi
    # 磁盘级操作
    if echo "$cmd" | grep -qE '^(mkfs\.|parted|fdisk|dd\s+if=)'; then
        audit HIGH security "磁盘级操作命令" "$cmd"
    fi
    # curl/wget 管道到 shell
    if echo "$cmd" | grep -qE '(curl|wget).*\|.*(bash|sh|zsh|dash)'; then
        audit HIGH security "curl-pipe-shell 模式" "$cmd"
    fi
    # 权限提升
    if echo "$cmd" | grep -qE '\b(sudo|su\s+-|pkexec)\b'; then
        audit HIGH security "权限提升操作" "$cmd"
    fi
    # 数据外泄：命令替换/环境变量/文件上传
    if echo "$cmd" | grep -qE '(curl|wget).*(\$\(|\`|\$[A-Z_]+|@\$|@~/)'; then
        audit HIGH security "疑似数据外泄" "$cmd"
    fi

    # --- MEDIUM ---
    if echo "$cmd" | grep -qE 'chmod\s+.*777'; then
        audit MEDIUM security "宽松权限 chmod 777" "$cmd"
    fi
    if echo "$cmd" | grep -qE '\b(npm\s+(i|install)\s+-g|pip3?\s+install|gem\s+install|cargo\s+install)\b'; then
        audit MEDIUM security "包管理器安装操作" "$cmd"
    fi
    # 精确匹配 --force（排除 --force-with-lease）
    if echo "$cmd" | grep -qE 'git\s+push\s+.*--force\b' && ! echo "$cmd" | grep -q '\--force-with-lease'; then
        audit MEDIUM security "Git 强制推送" "$cmd"
    fi
    if echo "$cmd" | grep -qE 'rm\s+-rf\s+' && ! echo "$cmd" | grep -qE '(node_modules|__pycache__|\.cache|/tmp/)'; then
        audit MEDIUM correctness "递归删除非临时目录" "$cmd"
    fi

    # --- LOW ---
    if echo "$cmd" | grep -qE '>\s*/tmp/'; then
        audit LOW security "输出到 /tmp 公共目录" "$cmd"
    fi

    # --- 输出异常检查（全部降级为 LOW，因为 tool_output 可能被截断）---
    local output_str
    output_str=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null || echo "")
    if echo "$output_str" | grep -qiE 'segmentation fault|core dumped|out of memory|killed'; then
        audit LOW anomaly "命令异常终止 (SIGSEGV/OOM等)" "$(echo "$output_str" | head -3)"
    fi
    if echo "$output_str" | grep -qiE 'permission denied|access denied'; then
        audit LOW correctness "命令返回权限拒绝" "$(echo "$output_str" | head -3)"
    fi
}

# ============================================================
# Read 审核
# ============================================================
audit_read() {
    local file_path
    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
    [[ -z "$file_path" || "$file_path" == "null" ]] && return

    if echo "$file_path" | grep -qE '(\.ssh/|\.gnupg/|\.aws/credentials|\.config/gh/hosts\.yml|\.git-credentials)'; then
        audit HIGH security "读取安全敏感文件" "$file_path"
    elif echo "$file_path" | grep -qE '(\.env$|\.env\.|credential|secret|token)'; then
        audit HIGH security "读取疑似凭证文件" "$file_path"
    elif echo "$file_path" | grep -qE '\.git/config$'; then
        audit MEDIUM security "读取 git 配置" "$file_path"
    elif echo "$file_path" | grep -qE '(/etc/passwd|/etc/shadow|/etc/sudoers)'; then
        audit HIGH security "读取系统认证文件" "$file_path"
    fi
}

# ============================================================
# Grep/Glob 审核（新增）
# ============================================================
audit_search() {
    local pattern
    pattern=$(echo "$TOOL_INPUT" | jq -r '.pattern // ""')
    [[ -z "$pattern" || "$pattern" == "null" ]] && return

    # 搜索敏感模式（API key / token / 密码等）
    if echo "$pattern" | grep -qE '(api.?key|api.?secret|access.?token|private.?key|secret|password|credential|sk-[a-zA-Z0-9]|AKIA|ghp_|github_pat)'; then
        audit MEDIUM data_access "搜索疑似敏感模式" "$pattern"
    fi
}

# ============================================================
# Write/Edit 审核
# ============================================================
audit_write_edit() {
    local file_path content_to_check
    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
    [[ -z "$file_path" || "$file_path" == "null" ]] && return

    if echo "$file_path" | grep -qE '(\.ssh/|\.gnupg/|\.aws/credentials|\.git/config)'; then
        audit HIGH security "修改安全敏感文件" "$file_path"
    elif echo "$file_path" | grep -qE '^(/etc/|/boot/|/sys/|/proc/|/dev/)'; then
        audit HIGH security "修改系统路径" "$file_path"
    elif echo "$file_path" | grep -qE '\.env$|credential|secret|token'; then
        audit HIGH security "修改疑似凭证文件" "$file_path"
    elif echo "$file_path" | grep -qE 'CLAUDE\.md$|\.claude/rules/'; then
        audit MEDIUM security "修改 AI 指令文件" "$file_path"
    fi

    # 密钥泄露检测（检查写入内容）
    content_to_check=$(echo "$TOOL_INPUT" | jq -r '.new_string // .content // ""' 2>/dev/null || echo "")
    if echo "$content_to_check" | grep -qE '(sk-(ant|api)-[a-zA-Z0-9_-]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{20,}|xox[bprs]-[a-zA-Z0-9-]+|eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,})'; then
        audit HIGH security "写入内容疑似包含 API Key/Token/JWT" "$file_path"
    fi
}

# ============================================================
# MCP 审核
# ============================================================
audit_mcp() {
    local server_tool
    server_tool="$TOOL_NAME"

    if echo "$server_tool" | grep -qE '__(memory_save|memory_journal|soul_write|soul_signal)'; then
        audit MEDIUM data_access "MCP 持久化写入" "$server_tool"
    elif echo "$server_tool" | grep -qE '__(delete_project|delete|remove|archive)'; then
        audit MEDIUM data_access "MCP 删除/归档" "$server_tool"
    elif echo "$server_tool" | grep -qE '__(index_repository|search_graph|query_graph)'; then
        audit LOW data_access "MCP 索引/图查询" "$server_tool"
    fi
}

# ============================================================
# WebFetch/WebSearch 审核
# ============================================================
audit_web() {
    local url
    url=$(echo "$TOOL_INPUT" | jq -r '.url // .query // ""' 2>/dev/null || echo "")

    if echo "$url" | grep -qE '(localhost|127\.0\.0\.1|10\.\d+\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|0\.0\.0\.0)'; then
        audit HIGH security "Web 请求访问内网地址" "$url"
    fi

    local query_len
    query_len=$(echo "$url" | wc -c)
    if [[ $query_len -gt 500 ]]; then
        audit MEDIUM security "Web 请求参数过长 (${query_len}B，疑似数据外泄)" "$(echo "$url" | head -c 200)..."
    fi
}

# ============================================================
# Agent 审核
# ============================================================
audit_agent() {
    local agent_type prompt
    agent_type=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""')
    prompt=$(echo "$TOOL_INPUT" | jq -r '.prompt // ""')

    [[ ${#prompt} -lt 10 ]] && audit MEDIUM correctness "Agent prompt 过短" "type=$agent_type"
}

# ============================================================
# Skill 审核
# ============================================================
audit_skill() {
    audit LOW data_access "Skill 调用" "$TOOL_NAME"
}

# ============================================================
# 主路由
# ============================================================
case "$TOOL_NAME" in
    Bash)       audit_bash ;;
    Read)       audit_read ;;
    Grep|Glob)  audit_search ;;
    Write|Edit) audit_write_edit ;;
    mcp__*)     audit_mcp ;;
    WebFetch|WebSearch) audit_web ;;
    Agent)      audit_agent ;;
    Skill)      audit_skill ;;
esac

exit 0
