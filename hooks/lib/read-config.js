#!/usr/bin/env node
// Reads .obsidian-logger.json and prints selected fields space-separated.
// Env: CFG (path to config file)
// Output: "<language> <log_retention_days> <daily_notes> <min_tool_calls> <canvas>"
// Exits 0 even on missing/invalid config — prints defaults instead.

const fs = require('fs');

const defaults = ['ru', '30', 'true', '5', 'false'];

try {
  const c = JSON.parse(fs.readFileSync(process.env.CFG, 'utf8'));
  const parts = [
    c.language || 'ru',
    String(c.log_retention_days ?? 30),
    c.daily_notes !== false ? 'true' : 'false',
    String(c.min_tool_calls ?? 5),
    c.canvas === true ? 'true' : 'false',
  ];
  process.stdout.write(parts.join(' '));
} catch {
  process.stdout.write(defaults.join(' '));
}
