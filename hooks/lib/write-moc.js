#!/usr/bin/env node
// Generates the project MOC page (projects/PROJECT.md) from context.
// Env: CTX_FILE, PROJECT_PAGE, LANG, PROJECT, DATE, HHMM, TOOL_COUNT, SESSION_LINK
// Exits 0 on success, 1 on fatal error.

const fs = require('fs');

const ctxPath = process.env.CTX_FILE;
const pp = process.env.PROJECT_PAGE;
const lang = process.env.LANG || 'ru';
const project = process.env.PROJECT;
const date = process.env.DATE;

if (!pp || !project) {
  console.error('write-moc: missing required env vars (PROJECT_PAGE, PROJECT)');
  process.exit(1);
}

let ctx = {};
try {
  ctx = JSON.parse(fs.readFileSync(ctxPath, 'utf8'));
  if (typeof ctx !== 'object' || ctx === null) ctx = {};
} catch {}

const todos = (ctx.open_todos || []).slice(0, 5);
const sessions = ctx.recent_sessions || [];

const L = {
  ru: { title: 'Проект', status: 'В работе', since: 'Начало', sessions_h: 'Последние сессии',
        todos_h: 'Открытые задачи', date_h: 'Дата', tools_h: 'Инструменты', tag: 'проект', no_todos: 'Нет открытых задач' },
  en: { title: 'Project', status: 'In progress', since: 'Since', sessions_h: 'Recent Sessions',
        todos_h: 'Open Tasks', date_h: 'Date', tools_h: 'Tools', tag: 'project', no_todos: 'No open tasks' },
  zh: { title: '项目', status: '进行中', since: '开始', sessions_h: '最近会话',
        todos_h: '待办任务', date_h: '日期', tools_h: '工具', tag: '项目', no_todos: '无待办任务' },
};
const t = L[lang] || L.ru;

const md = [];
md.push('# ' + t.title + ': ' + project);
md.push('');
md.push('**' + t.status + '** | **' + t.since + ':** ' + (ctx.first_seen || date) + ' | **Sessions:** ' + (ctx.session_count || 1));
md.push('');

md.push('## ' + t.sessions_h);
md.push('');
md.push('| ' + t.date_h + ' | ' + t.tools_h + ' | |');
md.push('|------|-------|---|');
for (const s of sessions) {
  const summary = s.summary ? (' — ' + String(s.summary).substring(0, 60)) : '';
  const link = s.link || (s.date + '_' + String(s.time || '').replace(/:/g, '-') + '_' + project);
  md.push('| ' + s.date + ' ' + (s.time || '') + ' | ' + (s.tools || 0) + ' | [[' + link + ']]' + summary + ' |');
}
md.push('');

md.push('## ' + t.todos_h);
md.push('');
if (todos.length > 0) {
  for (const todo of todos) md.push('- [ ] ' + todo);
} else {
  md.push('_' + t.no_todos + '_');
}
md.push('');
md.push('#' + t.tag + ' #' + project);

const tmp = pp + '.tmp.' + process.pid;
fs.writeFileSync(tmp, md.join('\n'));
fs.renameSync(tmp, pp);
