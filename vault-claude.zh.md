# Vault 使用规则

## 通用规则
- 所有笔记使用中文
- 日期格式: YYYY-MM-DD
- 任务: `- [ ] 文本`
- 使用 [[wiki 链接]] 建立关联
- 标签: #任务, #想法, #会议, #会话

## 文件夹结构
```
/notes      — 笔记、想法
/projects   — 项目
/daily      — 每日日记
/sessions   — Claude Code 会话自动日志
/archive    — 归档
/templates  — 模板
```

## Dataview 查询
- 所有会话: `TABLE FROM "sessions" SORT file.name DESC`
- 未完成任务: `TASK WHERE !completed`
- 最近一周: `TABLE FROM "daily" WHERE file.cday >= date(today) - dur(7 days)`
