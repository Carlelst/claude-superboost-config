---
name: ragflow-kb-ops
description: RAGFlow enterprise knowledge base operations. Import wiki/HTML documents with VLM image recognition, manage multi-KB deployments, configure Dify external knowledge proxy, and update Confluence wiki documentation. Use when working with RAGFlow KB import, batch_import.py, document parsing, embedding, VLM image enrichment, or deploying RAGFlow on 192.168.20.21 / 10.9.200.13.
---

# RAGFlow 企业知识库运维手册

## 环境速查

| 机器 | 服务 | 端口 |
|------|------|------|
| 192.168.20.21 | RAGFlow 测试 (ragflow-test) | 8088 |
| 10.9.200.13 | RAGFlow (ragflow-server) + MySQL + ES + Proxy + Dify | 8088/3307/1200/8090/8086 |
| 172.16.90.36 | MinIO (文档+图片) | 9000 |
| 10.9.200.14 | PostgreSQL (wiki_metadata/html_metadata/wangpan_metadata) | 5432 |

关键凭据: RAGFlow API key `ragflow-307044760fae4f548209426ba6191d9e`, KB ID `abfeeC35Ff4AfcDfF5Fa88b8D38Fb4Ce`, MySQL root/infini_rag_flow, MinIO minioadmin/minioadmin, PG postgres/enflame db:metadata

## 导入流程

完整的 6 步流程：PG获取数据 → VLM图片识别(wiki) → 增量分析 → 创建文档 → 分块+向量化 → (可选)RAPTOR

### 基础命令

```bash
# 本机测试 (wiki)
PYTHONUNBUFFERED=1 docker exec -e VLM_ENABLED=1 -e PYTHONUNBUFFERED=1 \
  ragflow-test python3 /ragflow/tools/batch_import.py \
  --config /ragflow/tools/batch_config.yaml --source wiki --wait

# 本机 (html)
PYTHONUNBUFFERED=1 docker exec ragflow-test python3 \
  /ragflow/tools/batch_import.py \
  --config /ragflow/tools/batch_config.yaml --source html --wait

# 200.13
ssh "docker exec -e VLM_ENABLED=1 ragflow-server python3 /ragflow/tools/batch_import.py --config /ragflow/tools/batch_config.yaml --source wiki --wait"
```

### 清理重建

```bash
# 1. 杀进程
docker exec ragflow-test pkill -9 -f batch_import
# 2. 清 MySQL
docker exec docker-mysql-1 mysql -u root -pinfini_rag_flow -e "
  DELETE FROM rag_flow.task WHERE doc_id IN (SELECT id FROM rag_flow.document WHERE kb_id='KB_ID');
  DELETE FROM rag_flow.file2document WHERE document_id IN (SELECT id FROM rag_flow.document WHERE kb_id='KB_ID');
  DELETE FROM rag_flow.document WHERE kb_id='KB_ID';
"
# 3. 清 MinIO 缓存
python3 -c "from minio import Minio; c=Minio('172.16.90.36:9000',access_key='minioadmin',secret_key='minioadmin',secure=False); [c.remove_object('rag-data',o.object_name) for o in c.list_objects('rag-data',prefix='_vlm_enriched/',recursive=True)]"
```

### 失败重试

```bash
docker exec ragflow-test python3 -c "
import sys; sys.path.insert(0,'/ragflow')
from api.db.db_models import Document
from api.db.services.document_service import DocumentService
from api.db.services.file2document_service import File2DocumentService
from api.db.services.task_service import queue_tasks
kb_id='KB_ID'
for doc in Document.select().where(Document.kb_id==kb_id,Document.progress<0):
    d=doc.to_dict(); b,n=File2DocumentService.get_storage_address(doc_id=doc.id)
    queue_tasks(d,b,n,0)
print('done')
"
```

### 触发 RAPTOR

```bash
docker exec ragflow-test python3 -c "
import sys; sys.path.insert(0,'/ragflow')
from api.db.db_models import Document
from api.db.services.document_service import DocumentService, queue_raptor_o_graphrag_tasks
kb_id='KB_ID'
docs=list(Document.select(Document.id).where(Document.kb_id==kb_id,Document.progress==1.0))
s=DocumentService.get_by_id(docs[0].id)[1].to_dict()
print(queue_raptor_o_graphrag_tasks(s,'raptor',0,doc_ids=[d.id for d in docs]))
"
```

## 多数据源 + 联合检索

三个独立 KB（不同分块策略），检索时通过逗号分隔 knowledge_id 联合查询：

| source | KB 名 | 表 | 行数 | chunks | VLM |
|--------|-------|-----|------|--------|-----|
| wiki | enflame-wiki | wiki_metadata | 233 | 256 | Y |
| html | enflame-docs | html_metadata | 60 | 400 | N |
| wangpan | enflame-wangpan | wangpan_metadata | 0 | 400 | N |

Dify 配置 `knowledge_id: "kb_wiki_id,kb_html_id"`，proxy 自动拆分为 dataset_ids 数组，RAGFlow 原生支持多 KB 联合检索。

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

## Wiki 文档更新

使用 wiki skill 更新 RAGFlow 运维页面:

```bash
# 页面 ID: 370532312
# URL: http://wiki.enflame.cn/pages/viewpage.action?pageId=370532312
# TOC: 放在 body 最前面
# <ac:structured-macro ac:name="toc" ac:schema-version="1" />

body=$(cat /tmp/wiki_content.html)
bash ~/.claude/skills/wiki/wiki_skill.sh update --page-id 370532312 --body "$body"
```

注意: update 命令只接受 `--page-id` 和 `--body`，不支持 `--title`。代码块用 `<ac:structured-macro ac:name="code">` + CDATA 包裹。

## Proxy 溯源

proxy_server.py 在启动时从 MySQL+PG 预加载 source_url 映射，检索结果自动附带 `metadata.source_url`。需要重启 proxy 才会重新加载映射。

```bash
# 重启 proxy
pkill -f 'gunicorn.*proxy_server'
MYSQL_PORT=3306 nohup python3 -m gunicorn proxy_server:app --bind 0.0.0.0:8090 --workers 4 --worker-class gevent > /tmp/proxy.log 2>&1 &
```

## Embedding 压测结果

代理 `172.16.90.45:8082` (uvicorn 单 worker) 在 20 并发内稳定，32 并发 50% 失败。源头 `10.12.116.244:8006` 可轻松处理 32+ 并发。200.13 可以直连源头绕过代理。

## 脚本位置

项目内: `tools/batch_import.py`, `tools/batch_config.yaml`, `tools/preprocess_images.py`
Git 仓库: `https://github.com/Carlelst/ragflow` (tag: v0.1.1-ef-kb)
内部仓库: `git@git.enflame.cn:hw/spt/ef_agent_kits.git` (platform/ragflow/)
