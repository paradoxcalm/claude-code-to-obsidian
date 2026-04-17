#!/usr/bin/env node
// Generates Obsidian Canvas visualization from context.
// Env: CTX_FILE, CANVAS_FILE, PROJECT
// Exits 0 on success, 1 on fatal error.

const fs = require('fs');

const ctxPath = process.env.CTX_FILE;
const canvasPath = process.env.CANVAS_FILE;
const project = process.env.PROJECT;

if (!canvasPath || !project) {
  console.error('write-canvas: missing required env vars (CANVAS_FILE, PROJECT)');
  process.exit(1);
}

let ctx = {};
try {
  ctx = JSON.parse(fs.readFileSync(ctxPath, 'utf8'));
  if (typeof ctx !== 'object' || ctx === null) ctx = {};
} catch {}

const sessions = ctx.recent_sessions || [];
const todos = (ctx.open_todos || []).slice(0, 5);

const nodes = [];
const edges = [];

const projectId = 'project-' + project;
nodes.push({
  id: projectId,
  type: 'text',
  x: 0, y: 0, width: 300, height: 80,
  text: '# ' + project + '\nSessions: ' + (ctx.session_count || 0),
  color: '4',
});

for (let i = 0; i < Math.min(sessions.length, 7); i++) {
  const s = sessions[i];
  const sid = 'session-' + i;
  nodes.push({
    id: sid,
    type: 'text',
    x: 400, y: i * 120, width: 350, height: 80,
    text: '**' + s.date + '** ' + (s.time || '') + '\n' + (s.summary || (s.tools + ' tools')),
    color: i === 0 ? '3' : '0',
  });
  edges.push({ id: 'edge-' + i, fromNode: projectId, toNode: sid, fromSide: 'right', toSide: 'left' });
}

if (todos.length > 0) {
  const todoId = 'todos';
  let todoText = '## TODO\n';
  for (const t of todos) todoText += '- [ ] ' + t + '\n';
  nodes.push({
    id: todoId,
    type: 'text',
    x: -450, y: 0, width: 350, height: 40 + todos.length * 30,
    text: todoText,
    color: '1',
  });
  edges.push({ id: 'edge-todos', fromNode: todoId, toNode: projectId, fromSide: 'right', toSide: 'left' });
}

const tmp = canvasPath + '.tmp.' + process.pid;
fs.writeFileSync(tmp, JSON.stringify({ nodes, edges }, null, 2));
fs.renameSync(tmp, canvasPath);
