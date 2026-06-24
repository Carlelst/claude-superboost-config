# 搜索语言策略

searx 脚本底层有 CJK 字符自动检测（≥30% → zh-CN, 否则 → all），但 LLM 应在搜索前主动判断最优策略。

## 判断规则

| 场景 | 策略 | 示例 |
|------|------|------|
| 用户用中文提问 + 通用话题 | `--lang zh-CN` | "人工智能最新进展" |
| 用户用中文提问 + 英文技术术语 | `--lang all`（双语结果更全） | "如何配置 kubernetes ingress" |
| 用户用中文提问 + 想要教程/解释 | `--lang zh-CN` | "Rust async await 教程" |
| 用户用英文提问 | `--lang all` 或不指定 | "best Python framework 2025" |
| 查找英文报错信息 | `--lang all` 或不指定 | `web qa "TypeError: Cannot read properties"` |
| 查找官方文档/API | `--lang all`（英文文档最权威） | "React 19 Server Components API" |
| 查找中文社区讨论 | `--lang zh-CN` | "Django 和 Flask 哪个好" |
| 不确定 | 不指定（auto 模式） | 让 searx 自动判断 |

## 执行方式

```bash
web search "query" --lang zh-CN
web it "Rust lifetime error" --lang all
web qa "Python import error"            # 不指定 → auto
web search "query" --lang all           # 返回中英文混合结果
```

## 类别 + 语言组合注意

- `web it` 包含 `baidu kaifa`（中文引擎），英文查询可能返回中文结果
- 纯英文技术查询建议用 `web search --lang all` 替代 `web it`
- `web science` 以英文学术引擎为主，一般不需要指定语言
