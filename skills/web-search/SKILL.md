---
name: web-search
version: 1.5.0
description: "统一网络搜索和网页内容获取。自动路由到 gh CLI / SearXNG / WebSearch，支持 BGE-Reranker 重排序、Jina AI Reader 4级爬虫、3模式质量门控压缩、Kimi k2.6 多模态、MapReduce 多源合成。"
---

# Web Search — 统一网络搜索入口

> 底层: SearXNG v2026.5.13 — **249 个引擎，31 个类别**。`web probe` 查看实时健康度。
> 详情: [reranker](references/reranker.md) | [语言策略](references/language-strategy.md) | [内容提取](references/content-extraction.md) | [质量保证](references/quality-assurance.md)

## 触发决策树

```
用户提问
  │
  ├─ 纯代码操作（写/改/审查/重构当前文件）？  → ❌ 不搜
  ├─ 纯逻辑推理（数学证明/逻辑分析）？         → ❌ 不搜
  ├─ 用户明确说不用搜？                        → ❌ 不搜
  ├─ 编程入门级常识 + >95% 把握？              → ❌ 不搜
  │                                              （有任何不确定 → 搜）
  │
  └─ 其他一切                                 → ✅ 搜索
```

**宁可多搜，不可漏搜。只有眼前代码和纯推理不搜。**

## 路由规则

| 输入类型 | 命令 |
|----------|------|
| `github.com/*` URL | `gh repo view` 查仓库 / `web fetch <url>` 抓页面 |
| `mp.weixin.qq.com/*` URL | `web fetch <url>` → playwright-stealth 自动路由 |
| 普通 `https?://*` URL | `web fetch <url>` → web-extract 完整提取 |
| 通用关键词搜索 | `web search <query>` |
| 新闻 | `web news <query>` |
| 深度搜索（搜+读全文） | `web deep <query>` |
| IT/编程问题 | `web it <query>` |
| 学术论文 | `web science <query>` |
| 包/依赖查找 | `web packages <query>` |
| 代码仓库搜索 | `web repos <query>` |
| 问答 | `web qa <query>` |
| 视频 | `web videos <query>` |
| 图片 | `web images <query>` |

## 类别引擎参考

| 命令 | 引擎池 | 场景 |
|------|--------|------|
| `web it` | GitHub, StackOverflow, npm, PyPI, crates.io, HuggingFace, MDN, HN... (44个) | 编程/框架/API |
| `web science` | arXiv, PubMed, Google Scholar, Crossref... (10个) | 论文/学术 |
| `web packages` | npm, PyPI, crates.io, Docker Hub, pkg.go.dev... (15个) | 包版本/API |
| `web repos` | GitHub, GitLab, HuggingFace, Codeberg... (10个) | 开源项目 |
| `web qa` | StackOverflow, AskUbuntu, SuperUser... (6个) | 技术问答 |
| `web news` | Bing News, Reuters, Google News... (17个) | 时事/动态 |
| `web videos` | YouTube, Bilibili, Vimeo... (29个) | 教程/演示 |
| `web images` | Google Images, Bing Images, Unsplash... (40个) | 图片/截图 |

## 常用命令

```bash
# 通用搜索
web search "<query>"                         # 多引擎聚合
web search "<query>" --time week             # 时间范围
web search "<query>" --count 10              # 更多结果

# 类别搜索（推荐，比指定引擎稳定 10 倍）
web it "rust async runtime"                  # IT/编程
web deep "<query>"                           # 搜索 + 读 5 篇全文

# 抓取
web fetch "<url>"                            # 通用抓取（文本+图片双通道）
web extract "<url>" --mode quick             # 快速概览 (~800 chars)
web extract "<url>" --mode deep              # 全文 (12K)
web extract "<url>" --no-vision              # 纯文本快速路径
web extract "<url>" --summarize              # LLM 抽象压缩

# 运维
web probe                                    # 完整健康检查
web-version check                            # 完整性校验
```

## 降级协议

```
web 脚本退出码:
  exit 0  → 成功
  exit 1  → SearXNG 不可用/结果太少 → fallback 到 WebSearch/WebFetch
  exit 2  → gh CLI 不可用 → fallback 到 SearXNG 或 WebFetch
```

## 执行规则

1. **所有网络搜索必须先经过 web 脚本**，不跳过直接调 WebSearch/WebFetch
2. 检查退出码：非 0 才 fallback
3. 使用 WebSearch 时标注 "⚠️ SearXNG 不可用，已降级至 WebSearch"
4. **GitHub 内容优先用 gh CLI**：代码仓库用 `gh repo view`，搜索用 `gh search repos`，网页文档用 `web fetch`
5. **社交平台内容用 agent-reach skill**，不走 web-search
6. 优先用类别搜索（`web it/science/packages`）而非通用搜索
7. 不要用 `curl` 或 `wget` 直接抓网页
8. 详情参考: [reranker](references/reranker.md) · [语言策略](references/language-strategy.md) · [内容提取](references/content-extraction.md) · [质量保证](references/quality-assurance.md)
