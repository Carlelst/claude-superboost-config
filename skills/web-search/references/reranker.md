# BGE-Reranker 重排序

搜索结果自动经过 **BGE-Reranker-v2-m3**（本地部署，~0.1s 延迟，$0 成本）重排序：

- 默认行为：搜索 → 取 2x 结果 → BGE 打分 → 按相关性排序 → 返回 top N
- 每条结果附带 `[score]` 标注（0-1，越高越相关）
- `--no-rerank` 跳过重排序（使用 SearXNG 原始排序）
- 如果 Reranker 不可用，自动降级到原始排序（不报错）
- `web deep` 不走 reranker（已读全文，模型自行判断）
