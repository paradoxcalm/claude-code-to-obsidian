# Claude Code 会话日志

此处自动保存 Claude Code 工作会话的日志。

## 搜索
- 按日期: 文件名中的 `YYYY-MM-DD`
- 按项目: 标签 `#项目-名称`
- Dataview: `TABLE file.name, file.cday FROM "sessions" SORT file.cday DESC`

## 日志结构
每个文件包含: 完成内容、变更文件、关键决策、TODO。

## 隐藏文件（以点开头）
- `.tool-log-YYYY-MM-DD.txt` — 工具调用计数器（技术文件）
- `.logged-SESSION_ID` — 已记录会话的标记（技术文件）
