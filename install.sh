#!/bin/bash
# ============================================================
#  Claude Code → Obsidian Logger — Installer
#  Automatic session logging from Claude Code to Obsidian
# ============================================================

set -e

# Цвета / Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# i18n — все строки на 3 языках
# ============================================================
msg() {
  local key="$1"
  case "${LANG_CHOICE:-ru}" in
    ru)
      case "$key" in
        choose_lang)     echo "Выбери язык / Choose language / 选择语言:" ;;
        lang_1)          echo "1) Русский" ;;
        lang_2)          echo "2) English" ;;
        lang_3)          echo "3) 中文" ;;
        lang_prompt)     echo "Язык [1/2/3]: " ;;
        step_deps)       echo "Проверяю зависимости..." ;;
        no_node)         echo "Node.js не найден. Установи: https://nodejs.org" ;;
        no_claude)       echo "Claude Code CLI не найден в PATH (может работать через npx)" ;;
        step_paths)      echo "Настраиваю пути..." ;;
        vault_prompt)    echo "Укажи путь к Obsidian vault." ;;
        vault_examples)  printf "  Windows: /c/Users/UserName/Documents/MyVault\n  macOS:   ~/Documents/MyVault\n  Linux:   ~/obsidian-vault\n" ;;
        vault_input)     echo "Путь к vault: " ;;
        vault_arg)       echo "Используется аргумент:" ;;
        empty_path)      echo "Путь не может быть пустым" ;;
        bad_chars)       echo "Путь не должен содержать спецсимволы: \` \$ \" ' \\ ; | & ( ) < >" ;;
        bad_chars2)      echo "Переименуй папку или выбери другой путь" ;;
        step_structure)  echo "Создаю структуру vault..." ;;
        files_done)      echo "Папки и скрипты созданы" ;;
        step_hooks)      echo "Настраиваю Claude Code hooks..." ;;
        backup_done)     echo "Бэкап текущих настроек создан" ;;
        hooks_done)      echo "Hooks добавлены в" ;;
        step_claude_md)  echo "Настраиваю глобальный CLAUDE.md..." ;;
        section_exists)  echo "Секция автологирования уже есть, пропускаю" ;;
        section_added)   echo "Секция добавлена в существующий CLAUDE.md" ;;
        claude_md_done)  echo "CLAUDE.md создан" ;;
        done_title)      echo "Установка завершена!" ;;
        how_it_works)    echo "Как это работает:" ;;
        how_1)           echo "1. Работай с Claude Code в любом проекте" ;;
        how_2)           echo "2. PostToolUse → считает вызовы инструментов" ;;
        how_3)           echo "3. Stop → если сессия длинная, напоминает записать лог" ;;
        how_4)           echo "4. Claude пишет подробный лог в" ;;
        how_5)           echo "5. SessionEnd → создаёт заготовку если лог не записан" ;;
        open_obsidian)   echo "Открой Obsidian → выбери vault:" ;;
      esac ;;
    en)
      case "$key" in
        choose_lang)     echo "Выбери язык / Choose language / 选择语言:" ;;
        lang_1)          echo "1) Русский" ;;
        lang_2)          echo "2) English" ;;
        lang_3)          echo "3) 中文" ;;
        lang_prompt)     echo "Language [1/2/3]: " ;;
        step_deps)       echo "Checking dependencies..." ;;
        no_node)         echo "Node.js not found. Install: https://nodejs.org" ;;
        no_claude)       echo "Claude Code CLI not found in PATH (may work via npx)" ;;
        step_paths)      echo "Configuring paths..." ;;
        vault_prompt)    echo "Enter path to your Obsidian vault." ;;
        vault_examples)  printf "  Windows: /c/Users/UserName/Documents/MyVault\n  macOS:   ~/Documents/MyVault\n  Linux:   ~/obsidian-vault\n" ;;
        vault_input)     echo "Vault path: " ;;
        vault_arg)       echo "Using argument:" ;;
        empty_path)      echo "Path cannot be empty" ;;
        bad_chars)       echo "Path must not contain special characters: \` \$ \" ' \\ ; | & ( ) < >" ;;
        bad_chars2)      echo "Rename the folder or choose a different path" ;;
        step_structure)  echo "Creating vault structure..." ;;
        files_done)      echo "Folders and scripts created" ;;
        step_hooks)      echo "Configuring Claude Code hooks..." ;;
        backup_done)     echo "Backup of current settings created" ;;
        hooks_done)      echo "Hooks added to" ;;
        step_claude_md)  echo "Configuring global CLAUDE.md..." ;;
        section_exists)  echo "Auto-logging section already exists, skipping" ;;
        section_added)   echo "Section added to existing CLAUDE.md" ;;
        claude_md_done)  echo "CLAUDE.md created" ;;
        done_title)      echo "Installation complete!" ;;
        how_it_works)    echo "How it works:" ;;
        how_1)           echo "1. Work with Claude Code in any project" ;;
        how_2)           echo "2. PostToolUse → counts tool invocations" ;;
        how_3)           echo "3. Stop → if session is long, reminds to write a log" ;;
        how_4)           echo "4. Claude writes a detailed log to" ;;
        how_5)           echo "5. SessionEnd → creates a stub if no log was written" ;;
        open_obsidian)   echo "Open Obsidian → select vault:" ;;
      esac ;;
    zh)
      case "$key" in
        choose_lang)     echo "Выбери язык / Choose language / 选择语言:" ;;
        lang_1)          echo "1) Русский" ;;
        lang_2)          echo "2) English" ;;
        lang_3)          echo "3) 中文" ;;
        lang_prompt)     echo "语言 [1/2/3]: " ;;
        step_deps)       echo "检查依赖..." ;;
        no_node)         echo "未找到 Node.js。请安装: https://nodejs.org" ;;
        no_claude)       echo "未在 PATH 中找到 Claude Code CLI（可通过 npx 使用）" ;;
        step_paths)      echo "配置路径..." ;;
        vault_prompt)    echo "请输入 Obsidian vault 路径。" ;;
        vault_examples)  printf "  Windows: /c/Users/UserName/Documents/MyVault\n  macOS:   ~/Documents/MyVault\n  Linux:   ~/obsidian-vault\n" ;;
        vault_input)     echo "Vault 路径: " ;;
        vault_arg)       echo "使用参数:" ;;
        empty_path)      echo "路径不能为空" ;;
        bad_chars)       echo "路径不能包含特殊字符: \` \$ \" ' \\ ; | & ( ) < >" ;;
        bad_chars2)      echo "请重命名文件夹或选择其他路径" ;;
        step_structure)  echo "创建 vault 结构..." ;;
        files_done)      echo "文件夹和脚本已创建" ;;
        step_hooks)      echo "配�� Claude Code 钩子..." ;;
        backup_done)     echo "当前设置已备份" ;;
        hooks_done)      echo "钩子已添加到" ;;
        step_claude_md)  echo "配置全局 CLAUDE.md..." ;;
        section_exists)  echo "自动日志部分已存在，跳过" ;;
        section_added)   echo "部分已添加到现有 CLAUDE.md" ;;
        claude_md_done)  echo "CLAUDE.md 已创建" ;;
        done_title)      echo "安装完成！" ;;
        how_it_works)    echo "工作原理:" ;;
        how_1)           echo "1. 在任何项目中使用 Claude Code" ;;
        how_2)           echo "2. PostToolUse → 计算工具调用次数" ;;
        how_3)           echo "3. Stop → 如果会话较长，提醒写入日志" ;;
        how_4)           echo "4. Claude 将详细日志写入" ;;
        how_5)           echo "5. SessionEnd → 如果未写日志则创建草稿" ;;
        open_obsidian)   echo "打开 Obsidian → 选择 vault:" ;;
      esac ;;
  esac
}

# ============================================================
# Шаг 0: Выбор языка
# ============================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Claude Code → Obsidian Logger — Installer   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

echo -e "  $(msg choose_lang)"
echo -e "  $(msg lang_1)"
echo -e "  $(msg lang_2)"
echo -e "  $(msg lang_3)"
echo ""

read -p "  $(msg lang_prompt)" LANG_NUM
case "$LANG_NUM" in
  2) LANG_CHOICE="en" ;;
  3) LANG_CHOICE="zh" ;;
  *) LANG_CHOICE="ru" ;;
esac

echo ""

# ============================================================
# Шаг 1: Зависимости
# ============================================================
echo -e "${YELLOW}[1/5]${NC} $(msg step_deps)"

if ! command -v node &> /dev/null; then
  echo -e "${RED}✗ $(msg no_node)${NC}"
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Node.js $(node --version)"

if ! command -v claude &> /dev/null; then
  echo -e "${YELLOW}  ⚠ $(msg no_claude)${NC}"
else
  echo -e "  ${GREEN}✓${NC} Claude Code CLI"
fi

# ============================================================
# Шаг 2: Пути
# ============================================================
echo -e "${YELLOW}[2/5]${NC} $(msg step_paths)"

CLAUDE_HOME="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "  $(msg vault_prompt)"
echo -e "  ${CYAN}"
msg vault_examples
echo -e "${NC}"

if [ -n "$1" ]; then
  VAULT_PATH="$1"
  echo -e "  $(msg vault_arg) ${GREEN}$VAULT_PATH${NC}"
else
  read -p "  $(msg vault_input)" VAULT_PATH
fi

VAULT_PATH="${VAULT_PATH%/}"

if [ -z "$VAULT_PATH" ]; then
  echo -e "${RED}✗ $(msg empty_path)${NC}"
  exit 1
fi

if printf '%s' "$VAULT_PATH" | grep -qE '[`$"'"'"'\\;|&()<>]'; then
  echo -e "${RED}✗ $(msg bad_chars)${NC}"
  echo -e "${RED}  $(msg bad_chars2)${NC}"
  exit 1
fi

mkdir -p "$VAULT_PATH"
echo -e "  ${GREEN}✓${NC} Vault: $VAULT_PATH"

# ============================================================
# Шаг 3: Структура vault
# ============================================================
echo -e "${YELLOW}[3/5]${NC} $(msg step_structure)"

mkdir -p "$VAULT_PATH/sessions"
mkdir -p "$VAULT_PATH/daily"
mkdir -p "$VAULT_PATH/notes"
mkdir -p "$VAULT_PATH/projects"
mkdir -p "$VAULT_PATH/archive"
mkdir -p "$VAULT_PATH/templates"
mkdir -p "$VAULT_PATH/scripts"
mkdir -p "$VAULT_PATH/.claude/skills/obsidian-logger"

VAULT_PATH_ESCAPED=$(printf '%s' "$VAULT_PATH" | sed 's/[&|\\/]/\\&/g')

# Копируем скрипты (хуки — языконезависимые)
for script in hooks/log-session.sh hooks/log-tools.sh hooks/session-reminder.sh; do
  BASENAME=$(basename "$script")
  VAULT_PATH="$VAULT_PATH" SCRIPT_SRC="$SCRIPT_DIR/$script" SCRIPT_DST="$VAULT_PATH/scripts/$BASENAME" node -e "
    const fs = require('fs');
    const content = fs.readFileSync(process.env.SCRIPT_SRC, 'utf8');
    fs.writeFileSync(process.env.SCRIPT_DST,
      content.replace(/__VAULT_PATH__/g, () => process.env.VAULT_PATH));
  " 2>/dev/null || {
    sed "s|__VAULT_PATH__|${VAULT_PATH_ESCAPED}|g" "$SCRIPT_DIR/$script" > "$VAULT_PATH/scripts/$BASENAME"
  }
  chmod +x "$VAULT_PATH/scripts/$BASENAME"
done

# Копируем шаблоны на выбранном языке
for tmpl in daily meeting project; do
  SRC="$SCRIPT_DIR/templates/${tmpl}.${LANG_CHOICE}.md"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$VAULT_PATH/templates/${tmpl}.md"
  else
    cp "$SCRIPT_DIR/templates/${tmpl}.ru.md" "$VAULT_PATH/templates/${tmpl}.md" 2>/dev/null || true
  fi
done

# Копируем skill-файл на выбранном языке
SKILL_SRC="$SCRIPT_DIR/skills/SKILL.${LANG_CHOICE}.md"
[ ! -f "$SKILL_SRC" ] && SKILL_SRC="$SCRIPT_DIR/skills/SKILL.en.md"
SKILL_DST="$VAULT_PATH/.claude/skills/obsidian-logger/SKILL.md"

VAULT_PATH="$VAULT_PATH" SCRIPT_SRC="$SKILL_SRC" SCRIPT_DST="$SKILL_DST" node -e "
  const fs = require('fs');
  const content = fs.readFileSync(process.env.SCRIPT_SRC, 'utf8');
  fs.writeFileSync(process.env.SCRIPT_DST,
    content.replace(/__VAULT_PATH__/g, () => process.env.VAULT_PATH));
" 2>/dev/null || {
  sed "s|__VAULT_PATH__|${VAULT_PATH_ESCAPED}|g" "$SKILL_SRC" > "$SKILL_DST"
}

# Создаём конфиг с выбранным языком
if [ ! -f "$VAULT_PATH/.obsidian-logger.json" ]; then
  cat > "$VAULT_PATH/.obsidian-logger.json" << CONFIGEOF
{
  "min_tool_calls": 5,
  "log_retention_days": 30,
  "language": "${LANG_CHOICE}"
}
CONFIGEOF
fi

# CLAUDE.md для vault на выбранном языке
VAULT_CLAUDE_SRC="$SCRIPT_DIR/vault-claude.${LANG_CHOICE}.md"
[ ! -f "$VAULT_CLAUDE_SRC" ] && VAULT_CLAUDE_SRC="$SCRIPT_DIR/vault-claude.ru.md"

if [ ! -f "$VAULT_PATH/CLAUDE.md" ]; then
  VAULT_PATH="$VAULT_PATH" node -e "
    const fs = require('fs');
    const content = fs.readFileSync(process.argv[1], 'utf8');
    fs.writeFileSync(process.argv[2],
      content.replace(/__VAULT_PATH__/g, () => process.env.VAULT_PATH));
  " "$VAULT_CLAUDE_SRC" "$VAULT_PATH/CLAUDE.md" 2>/dev/null || {
    sed "s|__VAULT_PATH__|${VAULT_PATH_ESCAPED}|g" "$VAULT_CLAUDE_SRC" > "$VAULT_PATH/CLAUDE.md"
  }
fi

# README для sessions на выбранном языке
SESSIONS_README_SRC="$SCRIPT_DIR/vault-sessions-readme.${LANG_CHOICE}.md"
[ ! -f "$SESSIONS_README_SRC" ] && SESSIONS_README_SRC="$SCRIPT_DIR/vault-sessions-readme.ru.md"
cp "$SESSIONS_README_SRC" "$VAULT_PATH/sessions/README.md" 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} $(msg files_done)"

# ============================================================
# Шаг 4: Claude Code hooks
# ============================================================
echo -e "${YELLOW}[4/5]${NC} $(msg step_hooks)"

SETTINGS_FILE="$CLAUDE_HOME/settings.json"
mkdir -p "$CLAUDE_HOME"

if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%s)"
  echo -e "  ${GREEN}✓${NC} $(msg backup_done)"
fi

SETTINGS_FILE="$SETTINGS_FILE" VAULT_SCRIPTS="$VAULT_PATH/scripts" node -e "
const fs = require('fs');
const settingsPath = process.env.SETTINGS_FILE;
const vaultScripts = process.env.VAULT_SCRIPTS;

let settings = {};
try {
  let raw = fs.readFileSync(settingsPath, 'utf8');
  raw = raw.replace(/^\uFEFF/, '');
  settings = JSON.parse(raw);
} catch {}

if (!settings.hooks) settings.hooks = {};

function hasOurHook(event) {
  if (!settings.hooks[event]) return false;
  return settings.hooks[event].some(group =>
    group.hooks && group.hooks.some(h =>
      h.command && /session-reminder\.sh|log-session\.sh|log-tools\.sh/.test(h.command)
    )
  );
}

if (!hasOurHook('Stop')) {
  if (!settings.hooks.Stop) settings.hooks.Stop = [];
  settings.hooks.Stop.push({
    hooks: [{
      type: 'command',
      command: 'bash \"' + vaultScripts + '/session-reminder.sh\"'
    }]
  });
}

if (!hasOurHook('SessionEnd')) {
  if (!settings.hooks.SessionEnd) settings.hooks.SessionEnd = [];
  settings.hooks.SessionEnd.push({
    hooks: [{
      type: 'command',
      command: 'bash \"' + vaultScripts + '/log-session.sh\"'
    }]
  });
}

if (!hasOurHook('PostToolUse')) {
  if (!settings.hooks.PostToolUse) settings.hooks.PostToolUse = [];
  settings.hooks.PostToolUse.push({
    matcher: '',
    hooks: [{
      type: 'command',
      command: 'bash \"' + vaultScripts + '/log-tools.sh\"'
    }]
  });
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
"

echo -e "  ${GREEN}✓${NC} $(msg hooks_done) $SETTINGS_FILE"

# ============================================================
# Шаг 5: Глобальный CLAUDE.md
# ============================================================
echo -e "${YELLOW}[5/5]${NC} $(msg step_claude_md)"

GLOBAL_CLAUDE="$CLAUDE_HOME/CLAUDE.md"

# Выбираем global-claude на нужном языке
GLOBAL_CLAUDE_SRC="$SCRIPT_DIR/global-claude.${LANG_CHOICE}.md"
[ ! -f "$GLOBAL_CLAUDE_SRC" ] && GLOBAL_CLAUDE_SRC="$SCRIPT_DIR/global-claude.ru.md"

if [ -f "$GLOBAL_CLAUDE" ]; then
  if grep -qE "Obsidian.*(автологирование|auto.?logging|自动日志)" "$GLOBAL_CLAUDE" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} $(msg section_exists)"
  else
    echo "" >> "$GLOBAL_CLAUDE"
    VAULT_PATH="$VAULT_PATH" node -e "
      const fs = require('fs');
      const content = fs.readFileSync(process.argv[1], 'utf8');
      fs.appendFileSync(process.argv[2],
        content.replace(/__VAULT_PATH__/g, () => process.env.VAULT_PATH));
    " "$GLOBAL_CLAUDE_SRC" "$GLOBAL_CLAUDE" 2>/dev/null || {
      sed "s|__VAULT_PATH__|${VAULT_PATH_ESCAPED}|g" "$GLOBAL_CLAUDE_SRC" >> "$GLOBAL_CLAUDE"
    }
    echo -e "  ${GREEN}✓${NC} $(msg section_added)"
  fi
else
  VAULT_PATH="$VAULT_PATH" node -e "
    const fs = require('fs');
    const content = fs.readFileSync(process.argv[1], 'utf8');
    fs.writeFileSync(process.argv[2],
      content.replace(/__VAULT_PATH__/g, () => process.env.VAULT_PATH));
  " "$GLOBAL_CLAUDE_SRC" "$GLOBAL_CLAUDE" 2>/dev/null || {
    sed "s|__VAULT_PATH__|${VAULT_PATH_ESCAPED}|g" "$GLOBAL_CLAUDE_SRC" > "$GLOBAL_CLAUDE"
  }
  echo -e "  ${GREEN}✓${NC} $(msg claude_md_done)"
fi

# ============================================================
# Готово
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         $(msg done_title)               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Vault:     ${CYAN}$VAULT_PATH${NC}"
echo -e "  Hooks:     ${CYAN}$SETTINGS_FILE${NC}"
echo -e "  CLAUDE.md: ${CYAN}$GLOBAL_CLAUDE${NC}"
echo -e "  Language:  ${CYAN}$LANG_CHOICE${NC}"
echo ""
echo -e "  ${YELLOW}$(msg how_it_works)${NC}"
echo -e "  $(msg how_1)"
echo -e "  $(msg how_2)"
echo -e "  $(msg how_3)"
echo -e "  $(msg how_4) $VAULT_PATH/sessions/"
echo -e "  $(msg how_5)"
echo ""
echo -e "  ${YELLOW}$(msg open_obsidian)${NC} $VAULT_PATH"
echo ""
