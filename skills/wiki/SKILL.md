---
name: wiki
version: 1.0.0
description: >
  访问 Enflame Confluence Wiki 的技能。Triggers on: "查wiki", "wiki上有没有XX",
  "搜索wiki", "更新wiki页面", "在wiki创建页面", "wiki页面XX", "confluence"。
  支持空间列表、页面搜索/查看/创建/更新、子页面、附件、评论管理。
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

完整命令详情在 `references/commands.md`。以下是快速索引：

| 命令 | 用户意图 | 示例参数 |
|------|---------|---------|
| `spaces` | 列出所有空间 | `--limit 50` |
| `search` | 搜索页面内容 | `--cql "type=page and title~'关键词'"` |
| `page` | 查看页面详情 | `--page-id 12345` 或 `--space DEV --title "标题"` |
| `children` | 查看子页面列表 | `--page-id 12345` |
| `attachments` | 查看附件列表 | `--page-id 12345` |
| `comments` | 查看页面评论 | `--page-id 12345` |
| `create` | 创建新页面 | `--space DEV --title "标题" --body "<p>HTML</p>"` |
| `update` | 更新页面内容 | `--page-id 12345 --body "<p>新内容</p>"` (标题自动保留) |
| `add-comment` | 添加评论 | `--page-id 12345 --comment "内容"` |
| `config` | 查看当前配置 | (无参数) |
| `setup` | 配置/修改凭据 | (无参数) |

需要完整参数表和 CQL 语法时，读取 `references/commands.md`:
```bash
cat "${SKILL_DIR:-$CLAUDE_CONFIG_DIR/skills/wiki}/references/commands.md"
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
