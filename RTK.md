# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

Refer to CLAUDE.md for full command reference.

## 与其他工具的分工

RTK 负责 PreToolUse Hook 层的命令输出压缩。以下工具负责其他层面，互不冲突：

| 工具 | 层面 | 用途 |
|------|------|------|
| RTK | PreToolUse Hook | 命令 stdout 压缩 (git/diff/npm/test...) |
| lean-ctx | MCP | 文件缓存读取 + 结构搜索 + 目录树 (ctx_read/ctx_search/ctx_tree/ctx_shell) |
| fff | MCP | Agent 文件精确搜索 (ffgrep/fffind/fff-multi-grep) |
| headroom | MCP | 长内容压缩/还原 (headroom_compress/headroom_retrieve) |
| beads | CLI/SessionStart Hook | 图谱任务管理 (bd create/ready/update/close/remember) |
| claude-mem | Plugin | 跨 session 记忆归档 |
| codeburn | CLI | Token 消耗可视化仪表板 (codeburn report) |
