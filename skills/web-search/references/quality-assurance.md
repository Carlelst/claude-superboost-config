# 搜索质量保证

## 查询优化规则

| 场景 | 策略 | 示例 |
|------|------|------|
| 编程问题 | 用 `web it` 或 `web qa` | `web qa "rust lifetime error"` |
| 找库/包 | 用 `web packages` | `web packages "http client rust"` |
| 学术论文 | 用 `web science` | `web science "attention is all you need"` |
| 英文技术查询 | 用英文关键词 + 版本号 | `"React 19 Server Components"` |
| 中文查询 | 直接搜中文 | `"2025 人工智能 监管政策"` |
| 错误排查 | 贴完整报错 | `web qa "TypeError: Cannot read properties"` |
| 最新动态 | 加 `--time day/week` | `web news "..." --time day` |
| GitHub | 优先 `gh repo view` / `web fetch <url>` | `web fetch "https://github.com/org/repo"` |

## 引擎策略

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

## 结果质量阈值

```
结果数 < 3 条  → ⚠️ 低质量 → 换类别/调整关键词
结果数 3-50 条 → ✅ 正常
结果数 > 50 条 → ⚠️ 查询太泛 → 加限定词
```

**对关键事实，至少找 2 个独立来源交叉验证。**

## 源可信度分层

| 层级 | 来源类型 | 示例 | 权重 |
|------|---------|------|------|
| T1 | 官方文档/标准 | docs.python.org, RFC, MDN, man pages | 优先采用 |
| T2 | 权威社区 | StackOverflow 高票答, GitHub 官方 repo, Wikipedia | 参考首选 |
| T3 | 技术博客/个人 | Medium, dev.to, 个人博客 | 交叉验证后采用 |
| T4 | 论坛/讨论 | Reddit, V2EX, 低分 SO 答 | 仅作参考线索 |
| T5 | 商业/营销 | 厂商博客, 广告页, SEO 堆砌页 | 忽略 |

**规则**：T1/T2 可直接引用。T3 需 ≥1 个其他来源印证。T4 仅作为发现关键词的线索。T5 丢弃。

## 内容质量过滤

| 信号 | 劣质特征 | 优质特征 |
|------|---------|---------|
| 信息密度 | 大量废话、SEO 填充 | 代码块/结构化数据/量化结论 |
| 时效性 | 过时（>2 年无更新且非稳定技术） | 近期更新或经典权威 |
| 原创性 | 明显转载/洗稿/机器生成 | 独立分析/一手经验 |
| 完整性 | 只有结论无推导、半截内容 | 完整逻辑链、可复现步骤 |

## 全面性与质量的平衡规则

```
搜索时：
  1. 先用 web search（多引擎，覆盖面最大）→ 拿 10-15 条
  2. 按源可信度分层 → 丢弃 T5
  3. 按信息密度排序 → 密度最低的 1/3 标记为"备选"
  4. 对 T1/T2 源 → web fetch 全文 → 提取关键段落
  5. 对 T3 源 → 仅看 Reranker 高分（≥0.75）的 → 交叉验证
  6. 最终交付：T1/T2 来源结论 + T3 交叉印证项 + 丢弃理由（一句话）

深度研究时：
  用 web deep（自动走以上流程，5 篇全文 + 压缩）
```
