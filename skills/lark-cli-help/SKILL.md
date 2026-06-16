---
name: lark-cli-help
description: 飞书 Lark CLI 工具使用技能。提供飞书文档、知识库、云空间、表格、日历、IM 消息、通讯录等功能的命令行操作能力。适用场景：(1) 创建/读取/更新飞书文档和知识库页面 (2) 搜索文档 (3) 管理云空间文件 (4) 操作飞书表格和电子表格 (5) 其他 Lark API 调用。通过 lark-cli 命令行工具实现。
metadata:
  requires:
    bins: ["lark-cli"]
  cliHelp: "lark-cli --help"
---

# 飞书 Lark CLI 工具

> `lark-cli` 是飞书（Lark）官方命令行工具，所有操作通过执行 `lark-cli` 命令完成。

提供对飞书文档、知识库（Wiki）、云空间（Drive）、表格、日历、IM 消息、通讯录等功能的完整命令行管理能力。

## 文档操作（docs）

### 创建文档

```bash
lark-cli docs +create --title "文档标题" --markdown "内容"
```

通过 `--markdown` 支持的内容数据格式：
- 直接传字符串：`--markdown "# 标题\n正文"`
- 当前目录的 Markdown 文件：`--markdown ./file.md`（必须是**相对路径**，不支持绝对路径）

可选参数：
- `--folder-token` 指定父文件夹
- `--wiki-space` 直接创建到知识库空间（传 `my_library` 为个人空间）
- `--wiki-node` 关联到 wiki 节点
- `--new-title` 创建时指定标题

### 读取文档内容

```bash
# v1 API（默认，已废弃但可用）
lark-cli docs +fetch --doc "DOC_TOKEN_OR_URL"

# v2 API（推荐）
lark-cli docs +fetch --doc "DOC_TOKEN_OR_URL" --api-version v2
```

- `--doc` 支持文档 URL 或 token
- v2 返回结构化内容（含 revision_id），v1 返回平文本
- 支持 `--format pretty` 美化输出，`--jq` 过滤 JSON

### 更新文档内容

```bash
lark-cli docs +update --doc "DOC_TOKEN" --mode append --markdown "新增内容"
lark-cli docs +update --doc "DOC_TOKEN" --mode overwrite --markdown "完整覆盖内容"
lark-cli docs +update --doc "DOC_TOKEN" --mode replace_all --markdown "全文替换"
```

更新模式（`--mode`）:
| 模式 | 说明 |
| --- | --- |
| `append` | 追加到文档末尾 |
| `overwrite` | 覆盖整个文档内容 |
| `replace_all` | 全文替换 |
| `insert_before` | 在指定位置前插入 |
| `insert_after` | 在指定位置后插入 |
| `delete_range` | 删除指定范围 |
| `replace_range` | 替换指定范围 |

定位方式：
- `--selection-by-title "## Section"` — 按标题定位
- `--selection-with-ellipsis "start...end"` — 按内容片段定位

> ⚠️ `--markdown` 参数如果传文件路径，必须是**相对路径**（如 `./file.md`），不支持绝对路径。

### 搜索文档

```bash
lark-cli docs +search --query "关键词"
```

### 插入媒体文件

```bash
lark-cli docs +media-insert --doc "DOC_TOKEN" --path ./image.png
lark-cli docs +media-upload --doc "DOC_TOKEN" --path ./file.pdf
```

## 知识库操作（wiki）

### 创建知识库节点

```bash
lark-cli wiki +node-create --space-id "SPACE_ID" --parent-node-token "PARENT_NODE" --title "节点标题" --obj-type docx
```

- `--space-id` 知识库空间 ID（`my_library` 为个人文档库）
- `--parent-node-token` 父节点 token（可选）
- `--obj-type` 对象类型：`docx`（文档）、`sheet`、`bitable`、`slides`、`mindnote`
- `--node-type shortcut` 可创建快捷方式，配合 `--origin-node-token`

### 知识库空间和节点管理

```bash
lark-cli wiki spaces list       # 列出所有空间
lark-cli wiki nodes list --space-id "SPACE_ID"    # 列出空间下的节点
lark-cli wiki +move --node-token "NODE" --target-space "TARGET_SPACE"  # 移动节点
lark-cli wiki +delete-space --space-id "SPACE_ID"  # 删除空间
```

## 云空间操作（drive）

### 文件管理

```bash
lark-cli drive files list       # 列出文件
lark-cli drive files stat --file-token "TOKEN"  # 查看文件详情
lark-cli drive +create-folder --name "文件夹名" --folder-token "PARENT"  # 创建文件夹
lark-cli drive +move --file-token "TOKEN" --target-folder-token "FOLDER"  # 移动文件
lark-cli drive +delete --file-token "TOKEN"  # 删除文件
```

### 上传/下载

```bash
lark-cli drive +upload --path ./local-file.md  --file-token "PARENT_FOLDER"
lark-cli drive +download --file-token "TOKEN" --output ./output.md
lark-cli drive +export --file-token "TOKEN" --type md
lark-cli drive +import --path ./file.md --type docx
```

## 通用 API 调用

对于未封装的 API，可用 `api` 命令直接调用：

```bash
# GET 请求
lark-cli api GET /open-apis/docx/v1/documents/TOKEN/raw_content

# POST 请求
lark-cli api POST /open-apis/bitable/v1/apps/APP_TOKEN/tables/TABLE_ID/records --data '{"fields": {...}}'

# 带查询参数
lark-cli api GET /open-apis/wiki/v2/spaces --params '{"page_size": 10}'
```

## 实用技巧

1. **文档 URL 和 token 互换**：飞书文档 URL 为 `https://xxx.feishu.cn/wiki/TOKEN`，最后的路径段就是文档 token
2. **输出格式化**：添加 `--format pretty` 美化 JSON 输出，或用 `--jq` 过滤特定字段
3. **身份切换**：`--as bot` 使用机器人身份，`--as user`（默认）使用用户身份
4. **绝对路径处理**：`--markdown` 传文件时不支持绝对路径，需 `cd` 到文件所在目录后用 `./file.md`

## 常见命令速查

```bash
# 文档
lark-cli docs +create --title "Title" --markdown "# Hello"
lark-cli docs +fetch --doc "TOKEN"
lark-cli docs +update --doc "TOKEN" --mode append --markdown "./content.md"
lark-cli docs +search --query "关键词"

# 知识库
lark-cli wiki +node-create --space-id "my_library" --title "页面标题"
lark-cli wiki spaces list

# 云空间
lark-cli drive +upload --path ./file.md
lark-cli drive +download --file-token "TOKEN"

# 通用 API
lark-cli api GET /open-apis/wiki/v2/spaces
```
