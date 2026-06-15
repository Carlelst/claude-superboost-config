# 🎯 基于你使用习惯的热门项目推荐

> 分析依据：CLAUDE.md 配置、已安装插件、Settings.json、Memory 偏好、RTK.md
> 数据基础：2025.7-至今 GitHub 新建 200+ 热门开源项目

---

## 👤 你的使用画像

| 维度 | 特征 |
|------|------|
| **主模型** | Claude Opus (Claude Code) |
| **效率体系** | RTK token 优化 + Superboost V3 + Agent Dispatch |
| **已装插件** | claude-mem, karpathy-skills, VoltAgent 全套 (7个), LSP x3, plugin-dev, pyright |
| **偏好** | Rust/Go 优先, 官方脚本安装, gh CLI > searx > WebSearch, rg/fd/bat 现代工具链 |
| **工作流** | 多 Agent 团队协作, Task-driven, Memory 持久化 |
| **通信** | 飞书生态 (lark-* skills 全套) |

---

## 🥇 第一梯队：强烈推荐（与你的技术栈高度匹配）

### 1. **rtk-ai/rtk** ⭐62k | Rust
```
https://github.com/rtk-ai/rtk
```
> CLI proxy，减少 60-90% LLM token 消耗。单 Rust 二进制，零依赖。

**匹配度：⭐⭐⭐⭐⭐** — 你已经在使用 RTK！这是你当前 RTK.md 配置所依赖的项目本身。关注上游更新、贡献或 stay tuned for major releases。

### 2. **gastownhall/beads** ⭐25k | Go
```
https://github.com/gastownhall/beads
```
> Coding Agent 的记忆升级插件

**匹配度：⭐⭐⭐⭐⭐** — 你已装 claude-mem (thedotmack)，beads 是 Golang 写的轻量记忆方案，可与 claude-mem 互补。Go + 记忆管理 = 你的菜。

### 3. **dmtrKovalenko/fff** ⭐8.5k | Rust
```
https://github.com/dmtrKovalenko/fff
```
> 最快最准的文件搜索工具包，为 AI Agent / Neovim / Rust / C / NodeJS 设计

**匹配度：⭐⭐⭐⭐⭐** — Rust 实现，比 rg/fd 更进一步，专为 AI Agent 场景优化。完美替代你当前 `rg`+`fd` 方案中的某些场景。

### 4. **esengine/DeepSeek-Reasonix** ⭐22k | Go
```
https://github.com/esengine/DeepSeek-Reasonix
```
> DeepSeek 原生终端 Coding Agent，围绕 prefix-cache 稳定性设计

**匹配度：⭐⭐⭐⭐** — Go 实现，多模型支持（你有 DeepSeek 选项），与你的 "run in terminal" 工作流一致。

### 5. **chopratejas/headroom** ⭐28k | Python
```
https://github.com/chopratejas/headroom
```
> 压缩工具输出/日志/文件/RAG chunk，减少 60-95% token，与 RTK 互补

**匹配度：⭐⭐⭐⭐⭐** — RTK 压缩命令层，headroom 压缩输出层，两者组合可达 90%+ token 节省。你 DISABLE_COMPACT=1 设了不压缩，headroom 可能更精准。

---

## 🥈 第二梯队：值得关注

### Agent 编排增强（你已有 VoltAgent 全套 + 多 Agent 工作流）

| 项目 | Stars | 语言 | 匹配点 |
|------|-------|------|--------|
| **multica-ai/multica** | 37k | Go | Go 实现的多 Agent 托管平台，与你的 VoltAgent 体系互补 |
| **getpaseo/paseo** | 8.6k | TypeScript | 桌面+移动端多 Agent 编排，移动场景补充 |
| **AgentWrapper/agent-orchestrator** | 7.6k | TypeScript | 并行 Coding Agent 编排，自动处理 CI/冲突 |

### 开发工具增强

| 项目 | Stars | 语言 | 匹配点 |
|------|-------|------|--------|
| **can1357/oh-my-pi** | 12k | TypeScript | Hash 锚定编辑 + LSP + 浏览器 — 你装了 3 个 LSP 插件，对代码智能工具需求明确 |
| **getagentseal/codeburn** | 8k | TypeScript | TUI 仪表板显示 Agent token 消耗 — 你对成本敏感（RTK 就是证明） |
| **repowise-dev/repowise** | 2.3k | Python | 代码健康评分 + 自动文档 + Git 分析 |

### 安全（VoltAgent QA-Sec 生态延伸）

| 项目 | Stars | 语言 | 匹配点 |
|------|-------|------|--------|
| **KeygraphHQ/shannon** | 45k | TypeScript | 自主白盒 AI 渗透测试，与你的 voltagent-qa-sec 插件互补 |
| **usestrix/strix** | 26k | Python | 开源 AI 漏洞发现与修复 |

### 研发能力延伸

| 项目 | Stars | 语言 | 匹配点 |
|------|-------|------|--------|
| **K-Dense-AI/scientific-agent-skills** | 28k | Python | 16 万科学家使用的 Skills，可扩展你的 agent skills 库 |
| **Imbad0202/academic-research-skills** | 31k | Python | 研究→写作→审阅→终稿的完整流程 Skills |
| **aiming-lab/AutoResearchClaw** | 13k | Python | 全自主研究 Agent：想法→论文 |

---

## 🥉 第三梯队：可以看看

| 项目 | Stars | 理由 |
|------|-------|------|
| **github/spec-kit** ⭐112k | SDD 工具包，你的 settings 有 effortLevel:xhigh，适合 spec-first 开发 |
| **Fission-AI/OpenSpec** ⭐55k | SDD for AI Coding，spec-kit 的竞品/互补品 |
| **garrytan/gstack** ⭐110k | YC 总裁的 Claude Code 配置，你的 gstack 式全栈借鉴 |
| **mattpocock/skills** ⭐129k | TypeScript 大神的 Skills，你装了 LSP 说明对 TS 有需求 |
| **sickn33/antigravity-awesome-skills** ⭐41k | 1500+ Skills 库，扩展你的 agent skills arsenal |
| **yvgude/lean-ctx** ⭐2.7k | Rust 实现的上下文智能层，与 RTK/headroom 形成 Rust 效率三件套 |

---

## 📦 推荐安装优先级

```bash
# 1. headroom — token 输出压缩（与 RTK 互补）
curl -fsSL https://raw.githubusercontent.com/chopratejas/headroom/main/install.sh | bash

# 2. fff — 更快的 Agent 文件搜索
# (需确认是否有官方安装脚本)

# 3. codeburn — token 消耗可视化仪表板
# 观察 RTK 实际节省了多少
```

---

## 🔗 关键对比：已有 vs 可用

| 你已有的 | 推荐升级/补充 | 理由 |
|-----------|---------------|------|
| RTK (CLI 层 token 优化) | **headroom** (输出层 token 压缩) | 组合使用，90%+ 节省 |
| claude-mem (记忆持久化) | **beads** (Go 轻量记忆) | 互补方案，不同场景 |
| VoltAgent QA-Sec (安全审查) | **shannon** (AI 渗透测试) | 主动攻防 vs 被动审查 |
| rg + fd (文件搜索) | **fff** (Agent-native 搜索) | 为 AI 场景优化 |
| VoltAgent Lang/Core (编码 Agent) | **oh-my-pi** (终端 Agent) | Hash 编辑 + LSP 深度集成 |
| LSP x3 (代码智能) | **codeburn** (token 可视化) | 补充成本观察维度 |
