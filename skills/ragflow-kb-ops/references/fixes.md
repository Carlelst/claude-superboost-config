## 关键修复记录

项目中遇到的 Bug 及其修复方式：

1. **Redis 连接 `list index out of range`**: RAGFlow 从 host 字段解析端口，host 必须含端口号
   - 修复: `dify-redis-1:6379` 而非 `dify-redis-1`
   - 文件: `rag/utils/redis_conn.py:129`

2. **batch_import --limit 误删文档**: 增量同步时 limit 集外的文档被标记删除
   - 修复: `limit > 0` 时跳过删除逻辑
   - 文件: `tools/batch_import.py:601`

3. **MinIO 路径重复拼接 `rag-data/rag-data/...`**: service_conf 的 bucket 字段导致 use_prefix_path 装饰器重复拼接
   - 修复: 去掉 `minio.bucket` 配置项
   - 文件: `rag/utils/minio_conn.py:82-86`

4. **VLM 描述不完整**: 默认 token 512 限制，表格数据被截断
   - 修复: `VLLM_MAX_TOKENS=1024`，prompt 改为逐行列出生数据

5. **图片 URL 匹配错误**: 用 `in` 子串匹配导致不同图片 filename 交叉命中
   - 修复: 构建 dict 精确映射 `filename → URL`

6. **VLM Pipeline 演进**: 经历了三个阶段
   - 阶段1: 自己写 VLM 调用 + 手动注入描述到正文 (灵活但维护成本高)
   - 阶段2: 改为 RAGFlow 原生 Markdown parser (type=md) 自动处理图片 (质量高但 VLM 并发瓶颈)
   - 最终: type=md (保留 Markdown 结构解析) + 图片路径替换为 MinIO HTTP URL
   - 结论: RAGFlow 原生图片管线(VisionFigureParser)比手写 VLM 完善，但 VLM 与 embedding 挤在 task executor 里导致 API 过载
   - 最终方案仍需平衡: type=md 结构好+图片 URL 保留，VLM 由批量导入前串行预处理

7. **代理扩容 (172.16.90.45:8082)**: 
   - 原 `HTTPServer` 单线程，32并发就 50% 超时
   - 改 `ThreadingMixIn` 后 64并发 100% 通过
   - 注意: 该代理路由 embedding → 10.12.116.244，VLM/LLM → 172.21.6.6:4000，两条链路独立

8. **RAGFlow 版本兼容性**: 
   - 容器跑 v0.25.6，本地仓库是 main 分支
   - `docker cp` 代码进容器可能不兼容 (如 `ensure_mineru_from_env` 导入失败)
   - 修复容器内代码时必须用同版本源文件

9. **type=md vs type=txt 权衡**:
   - md: Markdown parser 结构解析好 (标题/表格/列表)，但有 VLM 开销 (60-110s/doc)
   - txt: TxtParser 快 (2-3s/doc)，但丢失结构
   - 最佳: md + 无 VLM (图片保留 URL，VLM 单独预处理)

10. **网络拓扑**:
    - 本机 → 必须通过 172.16.90.45 代理访问所有内网服务
    - 200.13 → 可直连 10.12.116.244 (embedding), 172.21.6.6 (VLM)
    - 200.13 部署 VLM/embedding 都会更稳定
