#!/usr/bin/env node
// Reads project context and stale-project data, emits [CONTEXT] body lines to stdout.
// Env: CFG, CTX, PROJECTS_DIR, PROJECT
// Output: multi-line text for injection (or empty if nothing to inject).
// Exits 0 always.

const fs = require('fs');
const path = require('path');

const cfgPath = process.env.CFG;
const ctxPath = process.env.CTX;
const projDir = process.env.PROJECTS_DIR;
const currentProject = process.env.PROJECT;

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
}

const cfg = readJson(cfgPath) || {};
if (cfg.context_injection === false) process.exit(0);

const c = readJson(ctxPath);
if (!c) process.exit(0);

const lines = [];

if (c.stopped_at) lines.push('Где остановился: ' + c.stopped_at);

const sessions = c.recent_sessions || [];
if (sessions.length > 0) {
  lines.push('Последние сессии:');
  sessions.slice(0, 5).forEach((s) => {
    lines.push('  ' + s.date + ' — ' + (s.summary || (s.tools + ' tools')));
  });
}

const todos = (c.open_todos || []).slice(0, 5);
if (todos.length > 0) {
  lines.push('Задачи:');
  lines.push('  → ' + todos[0] + ' (следующее действие)');
  todos.slice(1).forEach((t) => lines.push('  → ' + t));
}

const staleThreshold = cfg.stale_threshold_days || 5;
const now = new Date();
try {
  const files = fs
    .readdirSync(projDir)
    .filter((f) => f.startsWith('.context-') && f.endsWith('.json'));
  const stale = [];
  for (const f of files) {
    const name = f.replace('.context-', '').replace('.json', '');
    if (name === currentProject) continue;
    const pc = readJson(path.join(projDir, f));
    if (pc && pc.last_seen) {
      const days = Math.floor((now - new Date(pc.last_seen)) / 86400000);
      if (days >= staleThreshold) {
        stale.push({
          name,
          days,
          action: pc.stopped_at || (pc.open_todos && pc.open_todos[0]) || '',
        });
      }
    }
  }
  stale.sort((a, b) => a.days - b.days);
  if (stale.length > 0) {
    const s = stale[0];
    lines.push(
      'Внимание: ' + s.name + ' не трогался ' + s.days + ' дней' +
        (s.action ? ' (' + s.action + ')' : '')
    );
  }
} catch {}

if (lines.length > 0) process.stdout.write(lines.join('\n'));
