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
