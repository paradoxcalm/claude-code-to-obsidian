#!/usr/bin/env node
// Updates .context-PROJECT.json from a session log.
// Env: CTX_FILE, LOG_FILE, CTX_PROJECT, CTX_DATE, CTX_HHMM, CTX_TOOLS, CTX_SID, CTX_CWD, CTX_LINK
// Exits 0 on success, 1 on fatal error. Errors go to stderr.

const fs = require('fs');

const ctxPath = process.env.CTX_FILE;
const logPath = process.env.LOG_FILE || '';
const PROJECT = process.env.CTX_PROJECT;
const DATE = process.env.CTX_DATE;
const HHMM = process.env.CTX_HHMM;
const TOOL_COUNT = process.env.CTX_TOOLS;
const SESSION_ID = process.env.CTX_SID;
const CWD = process.env.CTX_CWD;
const LINK = process.env.CTX_LINK;

if (!ctxPath || !PROJECT || !DATE) {
  console.error('write-context: missing required env vars (CTX_FILE, CTX_PROJECT, CTX_DATE)');
  process.exit(1);
}

let ctx = {};
try {
  ctx = JSON.parse(fs.readFileSync(ctxPath, 'utf8'));
  if (typeof ctx !== 'object' || ctx === null) ctx = {};
} catch (e) {
  if (e.code !== 'ENOENT') {
    console.error('write-context: could not parse existing ctx, starting fresh:', e.message);
  }
}

ctx.project = ctx.project || PROJECT;
ctx.first_seen = ctx.first_seen || DATE;
ctx.last_seen = DATE;
ctx.session_count = (ctx.session_count || 0) + 1;

let summary = TOOL_COUNT + ' tool calls';
let todos = ctx.open_todos || [];
let files = [];
let stoppedAt = '';

if (logPath) {
  try {
    const log = fs.readFileSync(logPath, 'utf8');

    const tm = log.match(/^#\s+(?:Сессия|Session|会话):\s*(.+)/m);
    if (tm && tm[1].trim() !== PROJECT) summary = tm[1].trim();

    const todoSec = log.split(/^##\s+TODO/m)[1];
    if (todoSec) {
      const items = todoSec.split(/^##/m)[0];
      const m = items.match(/^-\s*\[\s*\]\s*(.+)/gm);
      if (m) todos = m.map((x) => x.replace(/^-\s*\[\s*\]\s*/, '').trim());
    }

    const fileSec = log.split(/^##\s+(?:Изменённые файлы|Changed Files|变更文件)/m)[1];
    if (fileSec) {
      const items = fileSec.split(/^##/m)[0];
      const m = items.match(/`([^`]+)`/g);
      if (m) files = m.map((x) => x.replace(/`/g, '')).slice(0, 10);
    }

    const stoppedSec = log.split(/^##\s+(?:Где остановился|Where I stopped|停止位置)/m)[1];
    if (stoppedSec) {
      const line = stoppedSec.split(/^##/m)[0].trim().split('\n')[0].trim();
      if (line && !line.startsWith('_')) stoppedAt = line;
    }
  } catch (e) {
    if (e.code !== 'ENOENT') {
      console.error('write-context: could not parse log:', e.message);
    }
  }
}

ctx.last_session = {
  id: SESSION_ID,
  date: DATE,
  time: HHMM,
  summary: summary,
  cwd: CWD,
};

if (stoppedAt) ctx.stopped_at = stoppedAt;
else delete ctx.stopped_at;

if (todos.length > 0) ctx.open_todos = todos.slice(0, 5);
else delete ctx.open_todos;
if (files.length > 0) ctx.recent_files = files;

const extMap = {
  '.ts': 'typescript', '.tsx': 'typescript', '.js': 'javascript', '.jsx': 'javascript',
  '.py': 'python', '.rs': 'rust', '.go': 'golang', '.java': 'java', '.rb': 'ruby',
  '.sql': 'database', '.prisma': 'database', '.sh': 'bash', '.bash': 'bash',
  '.css': 'css', '.scss': 'css', '.html': 'html', '.vue': 'vue', '.svelte': 'svelte',
  '.json': 'config', '.yaml': 'config', '.yml': 'config', '.toml': 'config',
  '.md': 'docs', '.mdx': 'docs', '.dockerfile': 'docker', '.docker': 'docker',
};
const tags = new Set(ctx.tech_tags || []);
for (const f of files) {
  const ext = '.' + f.split('.').pop().toLowerCase();
  if (extMap[ext]) tags.add(extMap[ext]);
}
if (tags.size > 0) ctx.tech_tags = [...tags].slice(0, 10);

const sessions = ctx.recent_sessions || [];
sessions.unshift({
  date: DATE,
  time: HHMM,
  tools: parseInt(TOOL_COUNT) || 0,
  summary: summary,
  link: LINK,
});
if (sessions.length > 10) sessions.length = 10;
ctx.recent_sessions = sessions;

// Atomic write: write to temp then rename
const tmp = ctxPath + '.tmp.' + process.pid;
fs.writeFileSync(tmp, JSON.stringify(ctx, null, 2));
fs.renameSync(tmp, ctxPath);
