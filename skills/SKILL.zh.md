# Claude Code → Obsidian: Vault 操作技能

## 读取日志
- 进入项目时，从当前目录的 basename 确定项目名称
- 在 `__VAULT_PATH__/sessions/` 中查找 frontmatter `project:` 包含该项目名的文件
- 按日期读取最近的 3 个
- 提取：未完成的 TODO、"停止位置" 部分、关键决策
- 向用户展示 3 行："上次会话：{日期}。停止位置：{描述}。待办事项：{数量}"

## 写入日志
- 始终使用 YAML frontmatter：project, date, time, tags, files_changed, status, previous_session
- status："in-progress" 如果有未完成的 TODO，"completed" 如果全部完成
- tags 在 frontmatter 中 = 数组：[auth, database, bugfix] 等
- 第一个 TODO 始终标记为 "下一步操作"
- 最多 5 个 TODO（1 个主要 + 4 个待办）
- files_changed — 会话期间修改的文件整数计数
- previous_session — 该项目上一个日志的链接（从 [CONTEXT] 获取，如果可用）

## 关联
- 如果工作涉及其他项目 — 添加 wiki 链接 [[其他项目]]
- 如果上次会话中的 bug 重复出现 — 引用："参见 [[sessions/2024-03-10_my-app]]"
- 在 "关键决策" 部分引用技术：[[PostgreSQL]]、[[OAuth2]]
- 使用 frontmatter 中的 `previous_session` 创建会话链

## 更新项目上下文
- 写入日志后 — 检查文件 `__VAULT_PATH__/projects/{project-name}.md`
- 如果文件存在 — 数据由 SessionEnd 钩子自动更新：
  - 上次会话：日期和链接
  - 当前状态：进行中的工作
  - 待办 TODO：从该项目的所有 sessions/ 中收集
  - 技术栈：根据变更文件的扩展名确定
- 上下文缓存在 `__VAULT_PATH__/projects/.context-{project-name}.json`
- 下次会话时 Stop 钩子将自动从此缓存注入 [CONTEXT]
