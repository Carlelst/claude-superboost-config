# 网页内容提取

## 网页内容提取链

`web fetch`、`web extract`、`web deep` 统一使用 **web-extract**，默认**文本 + 图片双通道解析**：

```
URL 获取
  ├─ mp.weixin.qq.com → playwright-stealth (绕过 TCaptcha)
  ├─ GitHub URL → gh CLI（结构化 API）
  └─ 普通 URL → SearXNG 代理 / 直接 curl
       ↓
┌──── 文本通道 ────────────────┐   ┌──── 图片通道 ──────────────────┐
│  1. trafilatura    ← 主力    │   │  1. HTML <img> 解析            │
│  2. readability-lxml ← 备    │   │  2. 过滤装饰/跟踪/SVG/太小     │
│  3. html2text      ← 兜底   │   │  3. 下载 → base64              │
│  4. raw text       ← 保底   │   │  4. Kimi k2.6 多模态描述       │
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

## 降级协议

```
web fetch/提取失败
  → web-extract 所有层失败
  → SearXNG searx 代理抓取
  → 全部失败 → exit 1 → LLM 触发 WebFetch fallback
```

## 压缩策略 (质量门控)

三级压缩，平衡资料量与质量：

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

## web-extract 直接调用

```bash
web-extract "<url>"                          # 默认 Markdown，10000 字符
web-extract "<url>" --format text            # 纯文本输出
web-extract "<url>" --max-chars 20000        # 调整上限
web-extract "<url>" --raw-html               # 输出原始 HTML
```

## web-extract-images (多模态)

```bash
web-extract-images "<url>"                    # 文本 + 图片描述
web-extract-images "<url>" --max-images 5     # 最多 5 张图片
web-extract-images "<url>" --no-vision        # 纯文本，跳过视觉
web-extract-images "<url>" --raw              # JSON 输出（含结构化数据）
```

**图片提取**: HTML 解析 → 过滤装饰性/跟踪图片 → 下载 → base64 → Kimi k2.6 多模态描述 → 合并。
**过滤规则**: 自动跳过 SVG、favicon、tracking pixel、data URI（<500 字节）。

## 微信文章抓取

`mp.weixin.qq.com` 域名由腾讯 TCaptcha 防护，常规 HTTP 请求均被拦截。

`web-extract` 检测到此域名时，**自动路由到 playwright-stealth**（Python Chromium + 反检测脚本）绕过 TCaptcha。

**依赖：** `pip3 install playwright playwright-stealth`
**脚本：** `~/.claude/scripts/fetch_wx.py`
**用法：** `web fetch <mp.weixin.qq.com url>` / `web extract <mp.weixin.qq.com url>`
**输出：** `/tmp/wx_article/article.txt`（纯文本）+ `article.json`（结构化）
