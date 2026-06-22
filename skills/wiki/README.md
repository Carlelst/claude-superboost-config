# Wiki Skill

## 简介

Wiki技能是一个用于访问和操作Enflame Wiki的技能。它允许用户通过命令行界面查询Wiki空间、页面、搜索内容、管理附件和评论等。

## 目的

该技能旨在为用户提供一种便捷的方式，通过A1-Agent与Enflame Wiki进行交互，无需手动登录Wiki网站即可完成各种Wiki操作。

## 使用方法

当用户需要查询Wiki内容、搜索页面或管理Wiki页面时，此技能会被触发执行。

## 目录结构
```
wiki/
├── SKILL.md              # 技能的核心定义文件
├── README.md             # 该技能的说明文档
├── wiki_skill.sh         # 主执行脚本（Shell 实现）
├── wiki.conf             # 配置文件（用户运行时创建）
├── references/           # 参考文档目录
│   └── api_docs.md       # Wiki API 接口文档
```

## 功能特性

- 纯 Shell 实现，无需 Python 环境
- 支持基本的Wiki CRUD操作
- 使用HTTP Basic认证访问Wiki API
- 支持配置文件管理凭据
- 提供友好的命令行接口
- 支持CQL搜索查询

## 依赖安装

```bash
# Debian/Ubuntu
sudo apt-get install curl jq

# RHEL/CentOS
sudo yum install curl jq
```

## 配置说明

首次使用前需要配置Wiki凭据：

```bash
# 运行配置向导
bash wiki_skill.sh setup
```

配置文件为 `wiki.conf`（shell-sourceable 格式），存储位置按优先级：
1. 当前目录 `./wiki.conf`
2. 用户目录 `~/.config/wiki-cli/wiki.conf`

## 使用示例

### 查看帮助
```bash
bash wiki_skill.sh --help
```

### 查询所有空间
```bash
bash wiki_skill.sh spaces --limit 10
```

### 搜索页面
```bash
bash wiki_skill.sh search --cql "type=page and title~'技术文档'"
```

### 获取页面详情
```bash
bash wiki_skill.sh page --page-id 12345
```

### 创建页面
```bash
bash wiki_skill.sh create --space DEV --title "新页面" --body "<p>页面内容</p>"
```

### 获取页面子页面
```bash
bash wiki_skill.sh children --page-id 12345
```

### 获取页面附件
```bash
bash wiki_skill.sh attachments --page-id 12345
```

### 获取页面评论
```bash
bash wiki_skill.sh comments --page-id 12345
```

### 更新页面
```bash
bash wiki_skill.sh update --page-id 12345 --title "更新标题" --body "<p>更新内容</p>"
```

### 添加评论
```bash
bash wiki_skill.sh add-comment --page-id 12345 --comment "这是一条评论"
```

### 查看配置
```bash
bash wiki_skill.sh config
```

## 执行方式

```bash
# 直接执行
./wiki_skill.sh [command] [options]

# 或通过 bash 执行
bash wiki_skill.sh [command] [options]
```

## 注意事项

- 请确保网络可以访问Enflame Wiki服务器
- 需要有效的Wiki账户凭据才能访问受保护的内容
- 依赖 `curl` 和 `jq`，请确保已安装
- 配置文件包含明文密码，请妥善设置文件权限（建议 `chmod 600 wiki.conf`）
