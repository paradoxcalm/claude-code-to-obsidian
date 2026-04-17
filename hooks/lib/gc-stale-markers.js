#!/usr/bin/env node
// Removes .session-started-* and .reminded-* markers older than 24h.
// Missing SessionEnd means abandoned session — stale markers would corrupt
// future session detection. Logs cleanup to stderr (captured to .hook-errors.log).
// Env: VAULT (sessions dir)
// Exits 0 always.

const fs = require('fs');
const path = require('path');

const vault = process.env.VAULT;
if (!vault) process.exit(0);

const STALE_HOURS = 24;
const staleMs = STALE_HOURS * 3600 * 1000;
const now = Date.now();

let files;
try {
  files = fs.readdirSync(vault);
} catch {
  process.exit(0);
}

const patterns = [/^\.session-started-/, /^\.reminded-/];
let cleaned = 0;

for (const f of files) {
  if (!patterns.some((p) => p.test(f))) continue;
  const full = path.join(vault, f);
  try {
    const st = fs.statSync(full);
    if (now - st.mtimeMs > staleMs) {
      fs.unlinkSync(full);
      cleaned++;
    }
  } catch {}
}

if (cleaned > 0) {
  console.error('gc-stale-markers: cleaned ' + cleaned + ' markers older than ' + STALE_HOURS + 'h');
}
