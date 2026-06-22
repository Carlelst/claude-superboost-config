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

## Skills 根目录解析

Agent 在执行任何命令前，必须首先按以下规则解析 skills 根目录 `$SKILLS_ROOT`：

### 1. 识别 Agent 应用及其默认路径

| Agent 应用 | 默认 skills 路径 | 环境变量回退 |
|-----------|-----------------|-------------|
| Claude Code | `~/.claude/skills` | `$CLAUDE_CONFIG_DIR/skills` |
| Continue | `~/.continue/skills` | `$CONTINUE_CONFIG_DIR/skills` |

### 2. 解析优先级（以 Claude Code 为例）

按以下顺序检测，使用第一个存在的路径：

1. **全局 skills 目录**：`~/.claude/skills/wiki/wiki_skill.sh` → `SKILLS_ROOT=~/.claude/skills`
2. **环境变量回退**：若 `$CLAUDE_CONFIG_DIR` 已设置且 `$CLAUDE_CONFIG_DIR/skills/wiki/wiki_skill.sh` 存在 → `SKILLS_ROOT=$CLAUDE_CONFIG_DIR/skills`
3. **本地仓库路径**（开发/调试用）：从当前工作目录向上查找 `skills/wiki/wiki_skill.sh`，找到则 `SKILLS_ROOT=<repo_root>/skills`
4. **默认回退**：以上均不满足 → `SKILLS_ROOT=~/.claude/skills`

### 3. 解析完成后应验证

确认 `${SKILLS_ROOT}/wiki/wiki_skill.sh` 文件存在后再执行命令。

## 执行入口

Agent 应首先解析 `$SKILLS_ROOT`，然后使用 `bash` 执行脚本：

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh <command> [options]
```

首次使用或凭据缺失时，脚本会自动提示输入用户名和密码。Agent 应引导用户在交互式提示中输入。

## 命令参考

### 1. 查询空间列表 — `spaces`
**用户意图**：列出所有空间、有哪些空间、空间列表

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh spaces --limit 50
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--limit` | 否 | 返回结果数量，默认 50 |

### 2. 搜索页面 — `search`
**用户意图**：搜索某内容、查找页面、根据关键词找页面

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh search --cql "type=page and title~'关键词'"
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
# 通过页面ID获取
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh page --page-id 12345

# 通过空间Key+标题获取
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh page --space DEV --title "页面标题"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | 二者选一 | 页面 ID |
| `--space` | 二者选一 | 空间 Key |
| `--title` | 二者选一 | 页面标题（需配合 --space） |

### 4. 获取子页面 — `children`
**用户意图**：子页面列表、某页面的下级页面

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh children --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 父页面 ID |
| `--limit` | 否 | 返回数量，默认 50 |

### 5. 获取附件 — `attachments`
**用户意图**：附件列表、页面附件

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh attachments --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 页面 ID |

### 6. 获取评论 — `comments`
**用户意图**：查看评论、页面评论

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh comments --page-id 12345
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 页面 ID |
| `--limit` | 否 | 返回数量，默认 50 |

### 7. 创建页面 — `create`
**用户意图**：新建页面、创建 Wiki 页面

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh create \
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

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh update \
  --page-id 12345 \
  --title "新标题" \
  --body "<p>新内容 HTML</p>"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 要更新的页面 ID |
| `--title` | **是** | 新标题 |
| `--body` | **是** | 新内容（HTML 格式） |

### 9. 添加评论 — `add-comment`
**用户意图**：评论页面、添加评论

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh add-comment --page-id 12345 --comment "评论内容"
```
| 参数 | 必填 | 说明 |
|------|------|------|
| `--page-id` | **是** | 目标页面 ID |
| `--comment` | **是** | 评论内容（纯文本或 HTML） |

### 10. 查看当前配置 — `config`
```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh config
```

### 11. 重新配置凭据 — `setup`
**用户意图**：配置凭据、设置用户名密码、修改密码

```bash
bash ${SKILLS_ROOT}/wiki/wiki_skill.sh setup
```

## Agent 执行指南

### 执行规则
1. **首先解析 `$SKILLS_ROOT`**：参照上文「Skills 根目录解析」章节，确定 skills 根目录路径
2. **始终使用变量引用**：`bash ${SKILLS_ROOT}/wiki/wiki_skill.sh <command> [options]`
3. **工作在 skills 根目录**：所有命令从 `$SKILLS_ROOT` 目录执行
4. **凭据首次提示**：如果用户尚未配置凭据，脚本会交互式提示输入用户名和密码，Agent 应告知用户输入
5. **结果直接返回用户**：脚本输出为可读文本，可直接展示给用户
6. **单次调用对应一个查询**：不需要重复执行来确认结果

### 常见场景映射

| 用户问题 | 执行命令 |
|---------|---------|
| "有哪些空间" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh spaces` |
| "搜索关于部署的文档" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh search --cql "text~'部署'"` |
| "XX空间下有哪些技术文档" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh search --cql "space=XX and title~'技术文档'"` |
| "帮我看看12345这个页面" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh page --page-id 12345` |
| "XX空间下的ABC页面在哪" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh page --space XX --title "ABC"` |
| "12345页面有哪些子页面" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh children --page-id 12345` |
| "12345页面有哪些附件" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh attachments --page-id 12345` |
| "帮我看看12345页面的评论" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh comments --page-id 12345` |
| "在DEV空间创建一个页面" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh create --space DEV --title "..." --body "..."` |
| "更新12345页面内容为..." | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh update --page-id 12345 --title "..." --body "..."` |
| "在12345页面上添加评论" | `bash ${SKILLS_ROOT}/wiki/wiki_skill.sh add-comment --page-id 12345 --comment "..."` |

## 依赖
- bash 4.0+
- curl
- jq

## 安全说明
凭据通过临时文件传递给 curl（不使用命令行参数 `-u`），进程列表中不会暴露用户名和密码。配置文件 `wiki.conf` 存储于 `~/.config/wiki-cli/`，建议设置 `chmod 600`。
