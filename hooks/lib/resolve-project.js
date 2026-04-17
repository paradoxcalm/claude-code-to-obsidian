#!/usr/bin/env node
// Resolves project name from CWD using a layered lookup:
//   1. .obsidian-project file in CWD or any parent (one line with project name)
//   2. project_roots map in config (longest prefix match)
//   3. git toplevel basename
//   4. basename(CWD)
// Env: CFG (config path), CWD, PROJECTS_DIR (optional — for legacy .context- lookup)
// Output: project name to stdout.
// Exits 0 always (falls back to 'general').

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const cfgPath = process.env.CFG || '';
const cwdRaw = process.env.CWD || '';
const projectsDir = process.env.PROJECTS_DIR || '';

function sanitize(name) {
  if (!name) return '';
  return String(name).replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 50);
}

function normalizePath(p) {
  return String(p).replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
}

function readConfig() {
  try {
    return JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  } catch {
    return {};
  }
}

function findOverride(startDir) {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    if (!dir || dir === '/' || /^[A-Za-z]:[\\\/]?$/.test(dir)) break;
    const f = path.join(dir, '.obsidian-project');
    try {
      if (fs.existsSync(f)) {
        const content = fs.readFileSync(f, 'utf8').trim().split('\n')[0].trim();
        const sanitized = sanitize(content);
        if (sanitized) return sanitized;
      }
    } catch {}
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return '';
}

function matchProjectRoots(cfg, cwd) {
  const roots = cfg.project_roots || {};
  const cwdNorm = normalizePath(cwd);
  let best = '';
  let bestLen = 0;
  for (const [root, name] of Object.entries(roots)) {
    const rootNorm = normalizePath(root);
    if (cwdNorm.startsWith(rootNorm) && rootNorm.length > bestLen) {
      best = sanitize(name);
      bestLen = rootNorm.length;
    }
  }
  return best;
}

function gitToplevelBasename(cwd) {
  try {
    const out = cp.execSync(`git -C "${cwd.replace(/"/g, '\\"')}" rev-parse --show-toplevel`, {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
      timeout: 2000,
    }).trim();
    if (out) return sanitize(path.basename(out));
  } catch {}
  return '';
}

function legacyContextLookup(cwd) {
  if (!projectsDir) return '';
  let dir = cwd;
  for (let i = 0; i < 4; i++) {
    if (!dir || dir === '/' || /^[A-Za-z]:[\\\/]?$/.test(dir)) break;
    const name = sanitize(path.basename(dir));
    if (name) {
      try {
        if (fs.existsSync(path.join(projectsDir, '.context-' + name + '.json'))) return name;
      } catch {}
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return '';
}

const cfg = readConfig();
const cwd = cwdRaw || process.cwd();

let project =
  findOverride(cwd) ||
  matchProjectRoots(cfg, cwd) ||
  gitToplevelBasename(cwd) ||
  legacyContextLookup(cwd) ||
  sanitize(path.basename(cwd)) ||
  'general';

process.stdout.write(project);
