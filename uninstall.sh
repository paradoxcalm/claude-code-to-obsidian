#!/bin/bash
# ============================================================
#  Claude Code → Obsidian Logger — Uninstaller
#  Удаляет хуки из настроек Claude Code
#  НЕ удаляет vault и заметки
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}Claude Code → Obsidian Logger — Uninstaller${NC}"
echo ""

CLAUDE_HOME="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo -e "${YELLOW}settings.json не найден — ничего удалять${NC}"
  exit 0
fi

# Удаляем хуки через node — пути через process.env
SETTINGS_FILE="$SETTINGS_FILE" node -e "
const fs = require('fs');
const path = process.env.SETTINGS_FILE;
let s = {};
try {
  let raw = fs.readFileSync(path, 'utf8');
  raw = raw.replace(/^\uFEFF/, ''); // Убираем BOM
  s = JSON.parse(raw);
} catch { process.exit(0); }

if (s.hooks) {
  // Удаляем хуки по именам скриптов (не по слову 'Obsidian' в пути)
  for (const event of ['Stop', 'SessionEnd', 'PostToolUse']) {
    if (s.hooks[event]) {
      s.hooks[event] = s.hooks[event].filter(group => {
        if (!group.hooks) return true;
        return !group.hooks.some(h =>
          h.command && /session-reminder\.sh|log-session\.sh|log-tools\.sh/.test(h.command)
        );
      });
      if (s.hooks[event].length === 0) delete s.hooks[event];
    }
  }
  if (Object.keys(s.hooks).length === 0) delete s.hooks;
}

fs.writeFileSync(path, JSON.stringify(s, null, 2));
"

echo -e "${GREEN}✓${NC} Хуки удалены из $SETTINGS_FILE"

# Удаляем секцию из глобального CLAUDE.md
GLOBAL_CLAUDE="$CLAUDE_HOME/CLAUDE.md"
if [ -f "$GLOBAL_CLAUDE" ]; then
  GLOBAL_CLAUDE="$GLOBAL_CLAUDE" node -e "
    const fs = require('fs');
    const filePath = process.env.GLOBAL_CLAUDE;
    let content = fs.readFileSync(filePath, 'utf8');
    // Удаляем секцию от '## Obsidian Vault' до следующего заголовка любого уровня или конца файла
    content = content.replace(/\n*## Obsidian Vault[\s\S]*?(?=\n#+ |\s*$)/, '');
    content = content.trim();
    if (content) {
      fs.writeFileSync(filePath, content + '\n');
    } else {
      fs.unlinkSync(filePath);
    }
  "
  echo -e "${GREEN}✓${NC} Секция удалена из CLAUDE.md"
fi

echo ""
echo -e "${GREEN}Деинсталляция завершена.${NC}"
echo -e "Vault и заметки ${YELLOW}НЕ удалены${NC} — они остались на месте."
echo ""
