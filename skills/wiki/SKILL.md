---
name: wiki
description: 一个用于访问Enflame Wiki的技能。当用户需要查询Wiki内容、搜索页面或管理Wiki页面时可以使用此技能。
---

# Wiki Skill

## 概述
通过 Shell 脚本访问 Enflame Wiki REST API，执行页面查询、搜索、创建、更新等操作。

## 触发条件
当用户消息包含以下意图时，Agent 应调用此技能：
- 查询 Wiki 空间列表
- 搜索 Wiki 页面内容
- 查看某个页面的详细信息、子页面、附件或评论
- 创建或更新 Wiki 页面
- 添加评论到页面

## 执行路径

Agent 在执行任何命令前，确认 `$CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh` 文件存在。

脚本路径固定为 `$CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh`。

## 执行入口

Agent 应使用以下路径执行脚本：

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh <command> [options]
```

首次使用或凭据缺失时，脚本会自动提示输入用户名和密码。Agent 应引导用户在交互式提示中输入。

## 命令参考

### 1. 查询空间列表 — `spaces`
**用户意图**：列出所有空间、有哪些空间、空间列表

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh spaces --limit 50
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--limit` | 否 | 返回结果数量，默认 50 |

### 2. 搜索页面 — `search`
**用户意图**：搜索某内容、查找页面、根据关键词找页面

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh search --cql "type=page and title~'关键词'"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--cql` | **是** | Confluence CQL 查询语句 |
| `--limit` | 否 | 返回结果数量，默认 50 |

CQL 常用语法：
- `title~'关键词'` — 标题模糊匹配
- `title='精确标题'` — 标题精确匹配
- `space=SPACEKEY` — 限定空间
- `text~'内容关键词'` — 全文搜索

### 3. 获取页面详情 — `page`
**用户意图**：查看页面内容、页面详情、某页面的信息

```bash
# 通过页面ID获取（完整信息，含标题、版本等元数据）
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --page-id 12345

# 仅输出页面正文（用于保存到文件）
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --page-id 12345 --raw

# 通过空间Key+标题获取
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --space DEV --title "页面标题"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | 二者选一 | 页面 ID |
| `--space` | 二者选一 | 空间 Key |
| `--title` | 二者选一 | 页面标题（需配合 --space） |
| `--raw` | 否 | 仅输出页面正文（HTML），不含元数据头。用于保存到本地文件 |

### 4. 获取子页面 — `children`
**用户意图**：子页面列表、某页面的下级页面

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh children --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 父页面 ID |
| `--limit` | 否 | 返回数量，默认 50 |

### 5. 获取附件 — `attachments`
**用户意图**：附件列表、页面附件

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh attachments --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 页面 ID |

### 6. 获取评论 — `comments`
**用户意图**：查看评论、页面评论

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh comments --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 页面 ID |
| `--limit` | 否 | 返回数量，默认 50 |

### 7. 创建页面 — `create`
**用户意图**：新建页面、创建 Wiki 页面

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh create \
  --space DEV \
  --title "页面标题" \
  --body "<p>页面内容 HTML</p>"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--space` | **是** | 目标空间 Key |
| `--title` | **是** | 页面标题 |
| `--body` | **是** | 页面内容（HTML 格式） |
| `--parent-id` | 否 | 父页面 ID |

### 8. 更新页面 — `update`
**用户意图**：修改页面、更新页面内容

**⚠️ 重要：更新页面必须遵循以下工作流，禁止直接调用 update 命令！**

**标题保留**：update 命令自动保留页面原标题，无需（也不应）指定 `--title`。

#### 标准更新流程

1. **获取当前页面信息**：使用 `page` 命令获取页面的标题、版本号等元数据
2. **保存正文到本地**：使用 `page --page-id <ID> --raw > /tmp/wiki_page_<id>.html` 将页面正文保存到临时文件
3. **按用户需求修改**：根据用户要求修改临时文件中的内容
4. **展示差异并确认**：向用户展示修改前后的差异（diff），等待用户确认
5. **上传更新**：用户确认后，使用 `update` 命令将修改后的内容上传

> 详细流程见下方「Agent 执行指南 → 更新页面标准流程」。

```bash
# 最终上传命令（标题自动保留，无需指定）
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh update \
  --page-id 12345 \
  --body "<p>新内容 HTML</p>"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 要更新的页面 ID |
| `--body` | **是** | 新内容（HTML 格式） |

> **注意**：`--body` 参数接收 HTML 格式内容。如果用户提供的是 Markdown 格式，Agent 应先将其转换为 HTML 再上传。页面标题自动保留，不可修改。

### 9. 添加评论 — `add-comment`
**用户意图**：评论页面、添加评论

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh add-comment --page-id 12345 --comment "评论内容"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 目标页面 ID |
| `--comment` | **是** | 评论内容（纯文本或 HTML） |

### 10. 查看当前配置 — `config`
```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh config
```

### 11. 重新配置凭据 — `setup`
**用户意图**：配置凭据、设置用户名密码、修改密码

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh setup
```

## Agent 执行指南

### 执行规则
1. **脚本路径固定**：`$CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh`，执行前确认文件存在
2. **始终使用完整路径执行**：`bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh <command> [options]`
3. **工作在 skills 目录**：所有命令从 `$CLAUDE_CONFIG_DIR/skills` 目录执行
4. **凭据首次提示**：如果用户尚未配置凭据，脚本会交互式提示输入用户名和密码，Agent 应告知用户输入
5. **结果直接返回用户**：脚本输出为可读文本，可直接展示给用户
6. **单次调用对应一个查询**：不需要重复执行来确认结果

### 更新页面标准流程

当用户请求更新 Wiki 页面时，Agent **必须**按以下步骤执行，**禁止跳过任何步骤**：

#### 步骤 1：获取当前页面信息

使用 `page` 命令获取目标页面的元数据（标题、版本号、空间）：

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --page-id <页面ID>
```

如果用户未提供页面 ID，先通过 `search` 命令查找：
```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh search --cql "title~'关键词'"
```

#### 步骤 2：保存页面正文到本地临时文件

使用 `--raw` 选项仅获取页面正文（HTML），重定向保存到临时文件：

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --page-id <页面ID> --raw > /tmp/wiki_page_<页面ID>.html
```

临时文件命名规范：`/tmp/wiki_page_<页面ID>.html`

#### 步骤 3：根据用户需求修改

在临时文件中按用户指定的需求修改内容：
- 保持 HTML 格式（Wiki 存储格式为 HTML）
- 如果用户以 Markdown 提供修改内容，需转换为 HTML
- 保留页面原有的结构和样式标签

#### 步骤 4：展示差异并等待用户确认

向用户展示修改前后的差异，**必须等待用户明确确认后才能继续**：
- 展示修改的关键变更点摘要
- 可使用 diff 对比展示
- 明确询问用户："以上修改是否正确？确认后将上传到 Wiki。"

#### 步骤 5：上传更新

用户确认后，使用 `update` 命令上传修改后的内容（标题自动保留）：

```bash
bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh update \
  --page-id <页面ID> \
  --body "$(cat /tmp/wiki_page_<页面ID>.html)"
```

> **注意**：`update` 命令会自动保留原标题并处理版本号递增（当前版本 +1），无需手动指定。

#### 更新流程检查清单

| 步骤 | 检查项 | 状态 |
|------|--------|------|
| 1 | 已获取页面元数据（标题、版本号） | ☐ |
| 2 | 已通过 `--raw` 保存页面正文到本地临时文件 | ☐ |
| 3 | 已按用户需求完成修改 | ☐ |
| 4 | 已向用户展示差异并获得确认 | ☐ |
| 5 | 已调用 update 上传并验证成功 | ☐ |

### 常见场景映射

| 用户问题 | 执行命令 |
|---------|---------|
| "有哪些空间" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh spaces` |
| "搜索关于部署的文档" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh search --cql "text~'部署'"` |
| "XX空间下有哪些技术文档" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh search --cql "space=XX and title~'技术文档'"` |
| "帮我看看12345这个页面" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --page-id 12345` |
| "XX空间下的ABC页面在哪" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh page --space XX --title "ABC"` |
| "12345页面有哪些子页面" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh children --page-id 12345` |
| "12345页面有哪些附件" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh attachments --page-id 12345` |
| "帮我看看12345页面的评论" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh comments --page-id 12345` |
| "在DEV空间创建一个页面" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh create --space DEV --title "..." --body "..."` |
| "更新12345页面内容为..." | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh update --page-id 12345 --body "..."` |
| "在12345页面上添加评论" | `bash $CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh add-comment --page-id 12345 --comment "..."` |

## 依赖
- bash 4.0+
- curl
- jq

## 安全说明
凭据通过临时文件传递给 curl（不使用命令行参数 `-u`），进程列表中不会暴露用户名和密码。配置文件 `wiki.conf` 存储于 `~/.config/wiki-cli/`，建议设置 `chmod 600`。
