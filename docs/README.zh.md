[🇷🇺 Русский](../README.md) | [🇬🇧 English](README.en.md) | **中文**

# Claude Code → Obsidian Logger

将 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 会话自动记录到 [Obsidian](https://obsidian.md) vault 中。

在任何项目中使用 Claude Code 时，会话日志会自动以 markdown 笔记的形式保存到 Obsidian 中。

## 功能概述

```
你在使用 Claude Code（任意项目）
    │
    ▼
PostToolUse 钩子 → 统计工具调用次数
    │
    ▼ （5+ 次调用 = 有效会话）
Stop 钩子 → 提醒 Claude 记录详细日志
    │
    ▼
Claude 写入日志 → sessions/2024-03-15_14-30_my-project.md
    │
    ▼
SessionEnd 钩子 → 如果 Claude 未记录，则创建日志草稿
    │
    ▼
打开 Obsidian → 查看所有会话历史
```

## 日志包含哪些内容

- 完成了哪些工作（具体操作）
- 修改了哪些文件
- 关键决策及其原因
- 下次待办事项
- 用于搜索的标签（#项目、#主题）

## 环境要求

- [Node.js](https://nodejs.org) v18+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Obsidian](https://obsidian.md)（推荐但非必需 - 日志本质上就是 .md 文件）
- Bash（Windows 上使用 Git Bash，macOS/Linux 自带）

## 安装

```bash
git clone https://github.com/paradoxcalm/claude-code-to-obsidian.git
cd claude-obsidian-logger
bash install.sh
```

安装程序会询问 Obsidian vault 的路径，然后自动完成所有配置：

1. 在 vault 中创建目录结构
2. 安装钩子脚本
3. 配置 `~/.claude/settings.json`
4. 将指令添加到 `~/.claude/CLAUDE.md`

### 直接指定路径

```bash
bash install.sh ~/Documents/MyVault
```

### Windows (Git Bash)

```bash
bash install.sh /c/Users/YourName/Documents/MyVault
```

## 安装后的 vault 结构

```
MyVault/
├── CLAUDE.md           # vault 使用规则
├── sessions/           # ← 会话日志（自动生成）
│   ├── 2024-03-15_14-30_my-project.md
│   ├── 2024-03-15_16-00_other-project.md
│   └── README.md
├── daily/              # 每日笔记
├── notes/              # 笔记和灵感
├── projects/           # 项目
├── archive/            # 归档
├── templates/          # 模板（daily、meeting、project）
└── scripts/            # 钩子脚本
    ├── log-session.sh
    ├── log-tools.sh
    └── session-reminder.sh
```

## 钩子的工作原理

### `~/.claude/settings.json` 中的 3 个钩子：

| 钩子 | 触发事件 | 功能 |
|------|----------|------|
| `PostToolUse` | 每次工具调用 | 向 `.tool-log-日期.txt` 写入一行记录（计数器） |
| `Stop` | Claude 完成回复 | 如果 5+ 次工具调用且未记录日志，则向上下文注入 `[AUTOLOG]` 提醒 |
| `SessionEnd` | 退出会话 | 如果 Claude 未记录详细日志，则创建日志草稿 |

### 智能逻辑：
- **短会话**（< 5 次工具调用）— 不干扰，不打扰
- **长会话** — Claude 自动记录详细日志
- **防重复** — 标记文件 `.logged-SESSION_ID` 防止重复提醒

## 会话日志示例

```markdown
# 会话：添加了 OAuth 授权

**日期：** 2024-03-15 14:30
**项目：** my-app
**目录：** /home/user/projects/my-app

## 完成内容
- 添加了 Google OAuth2 流程
- 在数据库中创建了 users 表
- 编写了 auth 中间件测试

## 修改的文件
- `src/auth/oauth.ts` — 新的授权模块
- `src/db/migrations/001_users.sql` — 数据库迁移
- `src/middleware/auth.ts` — 令牌验证中间件
- `tests/auth.test.ts` — 测试

## 关键决策
- 选择 OAuth 而非 JWT — 客户要求
- Refresh token 存储在 httpOnly cookie 中

## 待办事项
- [ ] 添加 GitHub 授权
- [ ] 对 /auth 端点添加速率限制

#会话 #my-app #auth #oauth
```

## 卸载

```bash
bash uninstall.sh
```

从 `settings.json` 中移除钩子，从 `CLAUDE.md` 中移除相关配置段。vault 和笔记**不会被删除**。

## 推荐的 Obsidian 插件

- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — 类 SQL 查询笔记
- **[Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)** — 任务管理
- **[Templater](https://github.com/SilentVoid13/Templater)** — 高级模板

### 实用的 Dataview 会话查询

最近一周的所有会话：
````markdown
```dataview
TABLE file.cday as "Дата"
FROM "sessions"
WHERE file.cday >= date(today) - dur(7 days)
SORT file.cday DESC
```
````

所有会话中的待办事项：
````markdown
```dataview
TASK FROM "sessions"
WHERE !completed
```
````

## 常见问题

**Q: 支持 macOS / Linux 吗？**
A: 支持。脚本使用 bash + node 编写，跨平台运行。

**Q: 如果我不使用 Obsidian 怎么办？**
A: 日志是普通的 .md 文件，可以用任何编辑器打开，也可以导入 VS Code、Notion 等工具。

**Q: 钩子会拖慢 Claude Code 吗？**
A: 不会。脚本执行时间约 50ms（仅写入一行到文件）。

**Q: 可以临时禁用吗？**
A: 可以，删除或注释掉 `~/.claude/settings.json` 中的钩子即可。

**Q: 日志默认用俄语记录，如何更改语言？**
A: 编辑 `~/.claude/CLAUDE.md`，将语言设置改为你需要的语言。

## 许可证

MIT
