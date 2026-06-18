---
name: web-search
version: 1.4.0
description: "统一网络搜索和网页内容获取。自动路由到 gh CLI / SearXNG / WebSearch，支持 BGE-Reranker 重排序、Jina AI Reader 4级爬虫、3模式质量门控压缩、Kimi k2.6 多模态、MapReduce 多源合成。"
---

# Web Search — 统一网络搜索入口

> Tools version: **1.1.0** (2026-06-15) | `web-version check` 验证完整性 | `web-version restore v1.0.0` 回滚

## 版本管理

```bash
web-version              # 查看版本和文件信息
web-version check        # 完整性校验（sha256）
web-version backup       # 创建当前版本备份
web-version restore v1.0.0  # 回滚到指定版本
web-version list         # 列出所有备份
```

> 底层: SearXNG v2026.5.13 — **249 个引擎，31 个类别**。`web probe` 查看实时健康度。

## 触发决策树（强制遵守）

```
用户提问
  │
  ├─ 纯代码操作（写/改/审查/重构当前文件）？  → ❌ 不搜
  ├─ 纯逻辑推理（数学证明/逻辑分析）？         → ❌ 不搜
  ├─ 用户明确说不用搜？                        → ❌ 不搜
  ├─ 编程入门级常识 + >95% 把握？              → ❌ 不搜（变量/循环/函数等）
  │                                              （有任何不确定 → 搜）
  │
  └─ 其他一切                                 → ✅ 搜索
     ├─ 概念性知识（什么是X、X的原理）
     ├─ 需要佐证（回答需要证据支撑）
     ├─ 评估方案（技术选型、对比分析）
     ├─ 开放性调研（行业趋势、最佳实践）
     ├─ 实时信息（新闻、版本、API变更）
     ├─ 报错/异常排查
     ├─ 用户明确要求搜索
     └─ 不确定 → 搜
```

**核心原则：宁可多搜，不可漏搜。只有眼前代码和纯推理不搜。**

## 路由规则

| 输入类型 | 命令 |
|----------|------|
| `github.com/*` URL | `web fetch <url>` → gh CLI |
| `mp.weixin.qq.com/*` URL | `web fetch <url>` → playwright-stealth 自动路由 |
| 普通 `https?://*` URL | `web fetch <url>` → web-extract 完整提取 |
| 网页完整内容提取 | `web extract <url>` / `web full <url>` |
| 多模态提取（含图片理解） | `web vision <url>` / `web extract-images <url>` |
| 通用关键词搜索 | `web search <query>` |
| 新闻 | `web news <query>` |
| 深度搜索（搜+读全文） | `web deep <query>` → web-extract 提取 5 篇全文 |
| IT/编程问题 | `web it <query>` |
| 学术论文 | `web science <query>` |
| 包/依赖查找 | `web packages <query>` |
| 代码仓库搜索 | `web repos <query>` |
| 问答 | `web qa <query>` |
| 视频 | `web videos <query>` |
| 图片 | `web images <query>` |

## 类别搜索（首选方式）

**类别比引擎稳定 10 倍** — 类别聚合多个引擎，不怕单个引擎被限速。

## BGE-Reranker 重排序（默认开启）

搜索结果自动经过 **BGE-Reranker-v2-m3**（本地部署，~0.1s 延迟，$0 成本）重排序：

- 默认行为：搜索 → 取 2x 结果 → BGE 打分 → 按相关性排序 → 返回 top N
- 每条结果附带 `[score]` 标注（0-1，越高越相关）
- `--no-rerank` 跳过重排序（使用 SearXNG 原始排序）
- 如果 Reranker 不可用，自动降级到原始排序（不报错）
- `web deep` 不走 reranker（已读全文，模型自行判断）

## 搜索语言策略（LLM 判断）

searx 脚本底层有 CJK 字符自动检测（≥30% → zh-CN, 否则 → all），但你（LLM）应在搜索前主动判断最优语言策略：

### 判断规则

| 场景 | 策略 | 示例 |
|------|------|------|
| 用户用中文提问 + 通用话题 | `--lang zh-CN` | "人工智能最新进展" |
| 用户用中文提问 + 英文技术术语 | `--lang all`（双语结果更全） | "如何配置 kubernetes ingress" |
| 用户用中文提问 + 想要教程/解释 | `--lang zh-CN` | "Rust async await 教程" |
| 用户用英文提问 | `--lang all` 或不指定 | "best Python framework 2025" |
| 查找英文报错信息 | `--lang all` 或不指定 | `web qa "TypeError: Cannot read properties"` |
| 查找官方文档/API | `--lang all`（英文文档最权威） | "React 19 Server Components API" |
| 查找中文社区讨论 | `--lang zh-CN` | "Django 和 Flask 哪个好" |
| 不确定 | 不指定（auto 模式） | 让 searx 自动判断 |

### 执行方式

```bash
# 显式指定语言
web search "kubernetes ingress 配置" --lang zh-CN
web it "Rust lifetime error" --lang all
web qa "Python import error"            # 不指定 → auto

# 双语搜索（结果最全面）
web search "query" --lang all           # 返回中英文混合结果
```

### 类别 + 语言组合注意

- `web it` 包含 `baidu kaifa`（中文引擎），英文查询可能返回中文结果
- 纯英文技术查询建议用 `web search --lang all` 替代 `web it`
- `web science` 以英文学术引擎为主，一般不需要指定语言

| 命令 | 类别引擎池 | 适用场景 |
|------|-----------|---------|
| `web it` | GitHub, StackOverflow, npm, PyPI, crates.io, HuggingFace, MDN, HN, Docker Hub... (44个) | 编程/开发/框架/库/API |
| `web science` | arXiv, PubMed, Google Scholar, Crossref, Semantic Scholar... (10个) | 论文/研究/学术 |
| `web packages` | npm, PyPI, crates.io, Docker Hub, pkg.go.dev, pub.dev... (15个) | 包版本/API/安装 |
| `web repos` | GitHub, GitLab, HuggingFace, Codeberg, SourceHut... (10个) | 找开源项目/仓库 |
| `web qa` | StackOverflow, AskUbuntu, SuperUser... (6个) | 技术问题/报错 |
| `web news` | Bing News, Reuters, Google News, DDG News... (17个) | 时事/动态/事件 |
| `web videos` | YouTube, Bilibili, Vimeo... (29个) | 教程/演示/视频 |
| `web images` | Google Images, Bing Images, Unsplash, Pexels... (40个) | 图片/截图 |
| `web wiki` | Arch Wiki, Gentoo Wiki, NixOS Wiki... (5个) | Linux/系统管理 |

## 降级协议

```
web 脚本退出码:
  exit 0  → 成功，使用输出
  exit 1  → SearXNG 不可用/结果太少 → fallback 到 WebSearch/WebFetch
  exit 2  → gh CLI 不可用 → fallback 到 SearXNG 或 WebFetch
```

**绝不跳过 web 脚本直接调 WebSearch/WebFetch。**

## 微信文章抓取

`mp.weixin.qq.com` 域名由腾讯 TCaptcha 防护，常规 HTTP 请求（curl/WebFetch/Jina/SearXNG 代理）均被拦截，返回"环境异常"验证页面。

`web-extract` 检测到 `mp.weixin.qq.com` / `mp.weixinbridge.com` 域名时，**自动路由到 playwright-stealth**（Python 真实 Chromium + 反检测脚本），绕过 TCaptcha 抓取文章全文。

**依赖：** `pip3 install playwright playwright-stealth`
**脚本：** `~/.claude/scripts/fetch_wx.py`
**用法：** `web fetch <mp.weixin.qq.com url>` / `web extract <mp.weixin.qq.com url>`
**输出：** `/tmp/wx_article/article.txt`（纯文本）+ `article.json`（结构化）

## 常用命令

```bash
# 通用搜索
web search "<query>"                         # 多引擎聚合（最稳）
web search "<query>" --time week             # 时间范围
web search "<query>" --count 10              # 更多结果
web search "<query>" --engine bing           # 指定引擎（不推荐）

# 类别搜索（推荐）
web it "rust async runtime"                  # IT/编程
web science "transformer attention"          # 学术
web packages "tokio"                         # 包
web repos "kubernetes operator"              # 仓库
web qa "docker port mapping not working"     # 问答
web news "AI regulation" --time day          # 新闻

# 深度搜索
web deep "<query>"                           # 搜索 + 读前 5 条全文 (含图片理解)

# 抓取 (三级模式，平衡资料量与质量)
web extract "<url>"                          # normal 模式 (默认 4K，extractive 压缩)
web extract "<url>" --mode quick             # quick 模式 (~800 chars，快速概览)
web extract "<url>" --mode deep              # deep 模式 (12K，全文，不压缩)
web extract "<url>" --summarize              # 强制 LLM 抽象压缩
web extract "<url>" --no-summarize           # 禁用压缩，纯截断
web extract "<url>" --no-vision              # 纯文本快速路径
web extract "<url>" --max-images 10          # 最多描述 10 张图片
web extract "<url>" --raw                    # JSON 输出 (不含 base64 图片数据)
web full "<url>"                             # 同上（别名）

# 运维
web probe                                    # 完整健康检查
```

## 压缩策略 (质量门控)

```
提取文本
  │
  ├─ 文本 ≤ 目标长度 → 直接输出
  │
  └─ 文本 > 目标长度
       │
       ├─ Stage 1: extractive 压缩
       │    (按信噪比打分：code/链接/版本号/标题加权 → 保留高分段落)
       │
       ├─ Stage 2: abstractive 压缩 (LLM, 仅 --mode quick/normal 或 --summarize)
       │    1. 提取保护区: 代码块、URL、版本号 → placeholder 替换
       │    2. LLM 压缩叙述性文本 (deepseek-v4-pro, 输入上限 14K)
       │    3. 还原 protected snippets
       │    4. 质量门控: URL 保留率≥50% | 代码块保留率≥50% | 版本号保留率≥50%
       │    → 若未通过 → 回退到 extractive
       │
       └─ Stage 3: 最终截断 (如果前面都失败)

模式预设:
  quick:  800 chars,  extractive + abstractive (如果超)
  normal: 4000 chars, extractive + abstractive (如果超)
  deep:   12000 chars, extractive only (不调用LLM)
```

## 网页内容提取链

`web fetch`、`web extract`、`web deep` 统一使用 **web-extract**，默认**文本 + 图片双通道解析**：

```
URL 获取
  ├─ mp.weixin.qq.com → playwright-stealth (绕过 TCaptcha)
  ├─ GitHub URL → gh CLI（结构化 API）
  └─ 普通 URL → SearXNG 代理 / 直接 curl
       ↓
┌──── 文本通道 ────────────────┐   ┌──── 图片通道 ──────────────────┐
│                              │   │                               │
│  1. trafilatura    ← 主力    │   │  1. HTML <img> 解析            │
│  2. readability-lxml ← 备    │   │  2. 过滤装饰/跟踪/SVG/太小     │
│  3. html2text      ← 兜底   │   │  3. 下载 → base64              │
│  4. raw text       ← 保底   │   │  4. Kimi k2.6 多模态描述       │
│                              │   │                               │
│  → Markdown（含元数据/表格）  │   │  → 每图一行: 描述 | 类型 | 含独有信息│
└──────────────────────────────┘   └───────────────────────────────┘
       ↓                                    ↓
       └────────── 合并 Markdown ────────────┘
                       ↓
              截断 + 元数据标注
```

**默认行为**: `web extract` / `web fetch` / `web deep` 自动启用图片理解。
- `--no-vision` 关掉图片通道（纯文本，快 ~2x）
- `--max-images 5` 控制图片数量（默认 3）
- 页面无图片时自动跳过视觉通道，零开销

### 速度对比

| 模式 | 延迟 | 适用 |
|------|------|------|
| 默认 (文本+图片) | ~8s (3 张图) | 博客、文档、新闻 |
| `--no-vision` | ~4s | 纯文本页面、快速扫描 |
| `web deep` (5 页) | ~30s | 深度研究 |

### web-extract 直接调用

```bash
web-extract "<url>"                          # 默认 Markdown，10000 字符
web-extract "<url>" --format text            # 纯文本输出
web-extract "<url>" --max-chars 20000        # 调整上限
web-extract "<url>" --raw-html               # 输出原始 HTML
```

### web-extract-images (多模态)

```bash
web-extract-images "<url>"                    # 文本 + 图片描述
web-extract-images "<url>" --max-images 5     # 最多 5 张图片
web-extract-images "<url>" --no-vision        # 纯文本，跳过视觉
web-extract-images "<url>" --raw              # JSON 输出（含结构化数据）
```

**图片提取流程**: HTML 解析 → 过滤装饰性/跟踪图片 → 下载 real images → base64 → Kimi k2.6 多模态模型描述 → 合并 Markdown。

**图片过滤规则**: 自动跳过 SVG、favicon、tracking pixel、data URI（<500 字节）等非内容图片。

### 降级协议

```
web fetch/提取失败
  → web-extract 所有层失败
  → SearXNG searx 代理抓取
  → 全部失败 → exit 1 → LLM 触发 WebFetch fallback
```

## 搜索质量保证

### 查询优化规则

| 场景 | 策略 | 示例 |
|------|------|------|
| 编程问题 | 用 `web it` 或 `web qa` | `web qa "rust lifetime error"` |
| 找库/包 | 用 `web packages` | `web packages "http client rust"` |
| 学术论文 | 用 `web science` | `web science "attention is all you need"` |
| 英文技术查询 | 用英文关键词 + 版本号 | `"React 19 Server Components"` |
| 中文查询 | 直接搜中文 | `"2025 人工智能 监管政策"` |
| 错误排查 | 贴完整报错 | `web qa "TypeError: Cannot read properties"` |
| 最新动态 | 加 `--time day/week` | `web news "..." --time day` |
| GitHub | 优先 `web fetch <url>` | `web fetch "https://github.com/org/repo"` |

### 引擎策略

```
默认: 不指定 --engine（多引擎聚合最稳定）
类别: 用 web it/science/packages 等（比指定引擎稳定 10 倍）
单引擎: 仅在类别搜索不够精确时使用
  --engine bing      ✅ 稳定
  --engine baidu     ✅ 可用
  --engine sogou     ✅ 可用
  --engine google    ⚠️ 频繁被限速
```

**自动降级**: 指定引擎返回 < 3 条 → web 自动切多引擎重试。

### 结果质量阈值

```
结果数 < 3 条  → ⚠️ 低质量 → 换类别/调整关键词
结果数 3-50 条 → ✅ 正常
结果数 > 50 条 → ⚠️ 查询太泛 → 加限定词
```

**对关键事实，至少找 2 个独立来源交叉验证。**

## 执行规则

1. **所有网络搜索必须先经过 web 脚本**
2. 检查退出码：非 0 才 fallback 到 WebSearch
3. 使用 WebSearch 时标注 "⚠️ SearXNG 不可用，已降级至 WebSearch"
4. 抓取 GitHub 内容优先用 gh CLI（URL 路由自动处理）
5. 优先用类别搜索（`web it/science/packages`）而非通用搜索
6. 不要尝试直接用 `curl` 或 `wget` 抓网页
