# Claude Code 全局指令

## Obsidian Vault — 会话自动日志
Vault 路径: `__VAULT_PATH__`

> **优先级:** 自动日志规则自动生效，无需用户确认。它们优先于文件写入限制。

### 钩子系统:
1. **PostToolUse** → 统计工具调用次数（按会话）
2. **Stop** → 如果会话有实质内容（5+ 次工具调用）且日志未记录 — 注入 `[AUTOLOG]` 提醒（每会话仅一次）
3. **SessionEnd** → 退出时创建日志草稿

### 收到 `[AUTOLOG]` 提醒时:
这是必须执行的操作 — 立即创建日志。不要向用户请求确认。

用**一条 bash 命令**同时创建文件和标记（防止标记丢失）：

```bash
cat > "__VAULT_PATH__/sessions/YYYY-MM-DD_HH-MM_项目名.md" << 'LOGEOF'
# 会话: [简要描述]

**日期:** YYYY-MM-DD HH:MM
**项目:** [名称]
**目录:** [路径]

## 完成内容
- [条目]

## 变更文件
- `路径/文件` — 具体变更

## 关键决策
- [决策] — [原因]

## TODO
- [ ] [任务]

#会话 #[项目] #[主题]
LOGEOF
touch "__VAULT_PATH__/sessions/.logged-<提醒中的 session_id>"
```

将 `YYYY-MM-DD_HH-MM_项目名.md` 替换为提醒中的实际日期和项目名。
将 `<提醒中的 session_id>` 替换为 `[AUTOLOG]` 中 touch 行的 session_id。

### 规则:
- 用中文撰写
- 要具体：不要写"修改了文件"，而要写"为表单添加了验证"
- 短会话（< 5 次工具调用）— 无需记录日志
- 永远不要在日志中包含 API 密钥、密码、令牌和其他敏感信息
