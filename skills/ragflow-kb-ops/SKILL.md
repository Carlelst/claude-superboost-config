---
name: ragflow-kb-ops
version: 1.0.0
description: RAGFlow enterprise knowledge base operations. Import wiki/HTML documents with VLM image recognition, manage multi-KB deployments, configure Dify external knowledge proxy, and update Confluence wiki documentation. Use when working with RAGFlow KB import, batch_import.py, document parsing, embedding, VLM image enrichment, or deploying RAGFlow on 192.168.20.21 / 10.9.200.13.
---

# RAGFlow 企业知识库运维

## 导入 Flow

```
cleanup → kb_admin create（或前端）→ batch_import → frontend tune → RAPTOR(opt)
```

1. **kb_admin.py** — 创建 KB（首次）/ 查 KB（后续）
2. **batch_import.py** — PG 读元数据 → 增量对比 → 文档创建 → 入队 → 分块+向量化 → ES
3. **前端调优** — 改 chunk/delimiter/RAPTOR 参数 → kb_cleanup → batch_import 重导
4. **proxy** — Dify 外部知识库 API 格式转换 + source_url 溯源

## 模块

| 模块 | 功能 |
|------|------|
| `kb_admin.py` | create / delete / show KB |
| `kb_cleanup.py` | 清理 MySQL 文档 / ES chunk / MinIO 临时文件 |
| `batch_import.py` | 批量导入 + 增量同步 + 进度等待 |
| `proxy/proxy_server.py` | Dify API 代理 + source_url 溯源 |

## 环境（详细凭据见下方）

## 环境速查

| 机器 | 服务 | 端口 |
|------|------|------|
| 192.168.20.21 | RAGFlow 测试 (ragflow-test) | 8088 |
| 10.9.200.13 | RAGFlow (ragflow-server) + MySQL + ES + Proxy + Dify | 8088/3307/1200/8090/8086 |
| 172.16.90.36 | MinIO (文档+图片) | 9000 |
| 10.9.200.14 | PostgreSQL (wiki_metadata/html_metadata/wangpan_metadata) | 5432 |

关键凭据: 使用环境变量 — RAGFlow API key `${RAGFLOW_API_KEY}`, KB ID `${RAGFLOW_KB_ID}`, MySQL `${MYSQL_USER}/${MYSQL_PASSWORD}`, MinIO `${MINIO_ACCESS_KEY}/${MINIO_SECRET_KEY}`, PG `${PG_USER}/${PG_PASSWORD} db:${PG_DB}`

> ⚠️ 实际凭据不在本文件中。在 `~/.bashrc` 或 `~/.config/ragflow/env` 中设置以上环境变量。

## 架构设计

分层架构，API 优先：

```
┌─ REST API 层 ─────────────────────────────┐
│ KB 创建/配置 → POST/PUT /api/v1/datasets    │
│ RAPTOR → POST /api/v1/datasets/{id}/run_raptor │
├─ DB 直入层 ────────────────────────────────┤
│ 文档创建 → Document/File/File2Document      │
│ 任务入队 → queue_tasks (push Redis)          │
├─ 外部数据层 ────────────────────────────────┤
│ PG → wiki_metadata/html_metadata 读取       │
│ MinIO → 文档 + 图片存储                      │
├─ 业务逻辑层（自建）───────────────────────────┤
│ 增量同步 → PG vs MySQL diff                  │
│ 进度等待 → 轮询 document.progress            │
│ 失败重试 → queue_tasks                       │
│ Proxy溯源 → source_url_map                   │
└────────────────────────────────────────────┘
```

| 层 | 方式 | 原因 |
|------|------|------|
| KB 管理 | REST API | UUID/embd_id 格式自动正确 |
| 文档创建 | DB 直入 | 文件在外部 MinIO，API 不支持远程路径 |
| RAPTOR | REST API | 避免版本兼容问题 |
| 增量同步 | 自建 | API 无此功能 |

**为什么不用 SDK/MCP**：SDK 只是 REST API 封装，功能一致。MCP 需要额外服务，单一 API 调用不划算。直接用 `requests` 调 REST API 最简。

### 前端兼容性

- `knowledgebase.embd_id`：存 `qwen3-vl-embedding-8b@VLLM` 格式（`@provider`）
- `tenant_llm.llm_name`：存纯模型名 `qwen3-vl-embedding-8b`（不含 `___VLLM`）
- `knowledgebase.id`：标准 UUID1 格式（32 hex）
- `parser_config`：只含 API 文档支持的字段（`chunk_token_num`, `delimiter` 等，不含 `overlapped_percent`）
- API 创建 KB 自动处理 UUID 生成和 embd_id 验证，避免手动 DB 操作的不兼容

### VLM 图片识别

结论：**不在导入时调用 VLM**。

- 图片描述由 PG/MinIO 团队在元数据中提供
- 导入时只做图片路径替换（相对路径 → MinIO HTTP URL）
- RAGFlow 的 Markdown parser (type=md) 保留 `![](../images)` 引用，内部 `os.path.exists()` 找不到，不会下载/调 VLM
- 当前 type=txt 配合 `\n\n` 分隔符，段落分块无 URL 截断

### 模型代理 (172.16.90.45:8082)

- Python `HTTPServer` 单线程 → `ThreadingMixIn` 多线程（systemd service: model-proxy）
- embedding: `qwen3-vl-embedding-8b` → 10.12.116.244:8006
- VLM: `scs_qwen3.5-397b` → 172.21.6.6:4000 (default upstream)
- 代理 socket 超时已改为 120s
- 200.13 可直连 backend，本机必须走代理

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
docker exec docker-mysql-1 mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
  DELETE FROM rag_flow.task WHERE doc_id IN (SELECT id FROM rag_flow.document WHERE kb_id='KB_ID');
  DELETE FROM rag_flow.file2document WHERE document_id IN (SELECT id FROM rag_flow.document WHERE kb_id='KB_ID');
  DELETE FROM rag_flow.document WHERE kb_id='KB_ID';
"
# 3. 清 MinIO 缓存
python3 -c "from minio import Minio; c=Minio('172.16.90.36:9000',access_key='$MINIO_ACCESS_KEY',secret_key='$MINIO_SECRET_KEY',secure=False); [c.remove_object('rag-data',o.object_name) for o in c.list_objects('rag-data',prefix='_vlm_enriched/',recursive=True)]"
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

完整修复历史在 `references/fixes.md`（10 条记录，含文件路径和修复方式）。

```bash
cat "${SKILL_DIR:-$CLAUDE_CONFIG_DIR/skills/ragflow-kb-ops}/references/fixes.md"
```

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
