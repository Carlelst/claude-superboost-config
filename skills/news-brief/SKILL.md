---
name: news-brief
version: 1.0.0
description: "世界动态简报。当用户问'世界上发生了什么''最近有什么新闻''有什么大事'等时，按 11 个板块体系主动搜索并呈现。"
metadata:
  triggers:
    - "世界上发生了什么"
    - "最近有什么新闻"
    - "有什么大事"
    - "新闻简报"
    - "世界动态"
    - "今日要闻"
    - "本周新闻"
    - "what happened"
    - "what's going on"
    - "news briefing"
---

# News Brief — 世界动态简报

按 11 大板块搜索并呈现近期动态。

## 板块体系

每板块用 `web news "<关键词>" --time week` 搜索。

| # | 板块 | web 命令 |
|---|------|----------|
| 1 | 🏛️ 地缘政治 | `web news "geopolitics conflict diplomacy"` |
| 2 | 🤖 AI 发展 | `web news "AI artificial intelligence OpenAI Anthropic LLM"` |
| 3 | 🚀 航天/太空 | `web news "space exploration NASA SpaceX Starship"` |
| 4 | 💻 科技更新 | `web news "semiconductor chip tech open source"` |
| 5 | 🔐 网络安全 | `web news "cybersecurity hack breach vulnerability"` |
| 6 | ⚡ 能源 | `web news "energy nuclear solar renewable power"` |
| 7 | 🗳️ 美国政治 | `web news "US politics election Trump Congress policy"` |
| 8 | 📈 经济 & 金融 | `web news "global economy finance stock market trade"` |
| 9 | 🌍 气候 & 环境 | `web news "climate environment disaster renewable"` |
| 10 | 🏥 生物医疗 | `web news "biotech medical health breakthrough MedTech"` |
| 11 | 💰 Web3 / 加密 | `web news "crypto bitcoin web3 regulation ETF"` |

## 执行规则

1. **并行搜索**：11 个板块可以并发执行（独立、无依赖）
2. **深度优先**：重要板块（地缘政治、AI、科技）加 `--deep`
3. **时间范围**：默认一周，可调整为 `--time day`（今日）或 `--time month`
4. **输出格式**：每个板块 3-5 条关键新闻，附带来源链接
5. **语言**：中文摘要，保留英文原文关键词

## 简化版（快速浏览）

如果用户只需要快速浏览，每个板块用 `--count 3` 减少结果：

```bash
web news "<关键词>" --time week --count 3
```
