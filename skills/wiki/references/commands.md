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
