# Claude Code 组件系统使用指南

## 日常命令

| 场景 | 命令 |
|------|------|
| 搜索代码 | 直接描述需求，自动走 codebase-memory-mcp |
| 改代码前 | 代理自动调 `gitnexus impact`，你只需确认 |
| 提交前 | 代理自动调 `gitnexus detect_changes` |
| PR 审查 | `/gitnexus-pr-review` |
| 中文去 AI 味 | `/humanizer-zh 请人性化：<文本>` |
| 画架构图 | `/diagram <描述>` |
| 深度研究 | `/deep-research <问题>` |
| 持仓查询 | 说 "查持仓" 即可 |
| 社交平台 | "搜下 Twitter/Reddit 上关于 X 的讨论" |

## 自动运行（hooks，无需手动触发）

| 时机 | 做什么 |
|------|--------|
| 工具调用后 | 🛡️ 审核 10 类工具调用的安全性/准确性 |
| 工具调用失败 | 记录失败原因 |
| Agent 子调用结束 | 追溯子代理活动 |
| 每批工具完成 | 汇总 HIGH 风险发现 |
| Grep/Glob 时 | codebase-memory-mcp 图增强 |
| Bash 执行后 | GitNexus 索引新鲜度检查 |
| 写文件前 | write-guard 保护 .soul/ 文件 |
| 会话开始 | 加载 soul 上下文 + 环境初始化 |
| 会话结束 | soul 状态持久化 + 会话纠正 |

## 审核日志

```bash
# 查看当前会话 HIGH 风险
cat ~/.claude/audit/*.jsonl | jq 'select(.level=="HIGH")'

# 统计风险分布
cat ~/.claude/audit/*.jsonl | jq -r '.level' | sort | uniq -c

# 清理旧日志（建议每季度）
rm -rf ~/.claude/audit/
```

## 双引擎仲裁

```
要改代码？
  → gitnexus impact 查影响范围

要找代码/追调用链？
  → 直接问，自动走 codebase-memory-mcp

接陌生大仓库？
  → gitnexus analyze 先建索引，看社区结构和执行流
```

## 安装部署

```bash
# 新机器一键部署
git clone https://github.com/Carlelst/claude-superboost-config.git /tmp/setup
cd /tmp/setup && ./install.sh

# 安装额外组件
gitnexus analyze              # 对每个项目建代码索引
npm install -g gitnexus       # 如有 native 模块问题，手动装
```
