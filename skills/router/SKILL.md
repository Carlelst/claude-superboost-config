---
name: router
description: 智能任务调度器。自动分析用户意图，匹配最合适的 worker agent，并行分派执行后汇总结果。Use when 用户一句话里有多个独立任务，或需要跨领域并行处理（如飞书+代码+架构图）。
---

# 智能路由器

自动识别用户输入中的多个意图，匹配领域 worker，并行执行，汇总结果。

## 快速使用

```
/router "帮我审批飞书上张三的请假 + review PR #42 + 画架构图"
```

Router 自动：
1. 识别 3 个独立意图 → feishu + coding + arch
2. 匹配 3 个 worker profile（各自独立 skill 集和 context）
3. 并行 spawn 3 个 claude 进程
4. 等全部完成后汇总输出

## Worker Profiles

| Profile | 触发关键词 | Skills | 用途 |
|---------|-----------|--------|------|
| feishu | 飞书/审批/打卡/日历/IM... | 23 lark-* | 飞书办公全场景 |
| wecom | 企微/企业微信 | 7 wecomcli-* | 企业微信 |
| coding | 代码/开发/bug/review... | tdd+diagnose+prototype+... | 软件开发 |
| arch | 架构/图/diagram/C4... | diagram+kroki | 架构图 |
| enflame | enflame/网盘/jira/wiki | wangpan+wiki+jira+copilot | Enflame 工具 |
| research | 搜索/查/新闻/调研... | web-search+news-brief | 研究调研 |
| general | (默认兜底) | agent-dispatch+web-search | 通用任务 |

## 调度流程

```
用户输入 → intent-parser.sh（LLM 意图解析）
         → dispatch.sh（任务拆解 + 并行 spawn）
           ├─ spawn.sh: 飞书 worker（23 skills, lark MCP）
           ├─ spawn.sh: 代码 worker（10 skills, lean-ctx MCP）
           └─ spawn.sh: 架构 worker（2 skills, kroki MCP）
         → watch.sh（轮询等待）
         → 汇总输出
```

## 配置

Profiles 定义在 `~/.claude/router/profiles.json`。新增 worker 只需加一个 JSON 块。

## 故障处理

- Worker 崩溃 → 自动重试 1 次 → 降级到 general worker
- 意图不明确 → 降级到关键词匹配 → 兜底到 general
- 超时 → 报告部分完成状态

## 脚本位置

| 脚本 | 路径 |
|------|------|
| 配置 | `~/.claude/router/profiles.json` |
| 意图解析 | `~/.claude/router/scripts/intent-parser.sh` |
| Worker 启动 | `~/.claude/router/scripts/spawn.sh` |
| 结果监听 | `~/.claude/router/scripts/watch.sh` |
| 主调度 | `~/.claude/router/scripts/dispatch.sh` |