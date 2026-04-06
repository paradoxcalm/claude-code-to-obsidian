#!/bin/bash
# Stop hook: напоминает Claude записать подробный лог если сессия существенная
# Срабатывает после каждого ответа Claude
# stdout → попадает в контекст Claude (он видит это как сообщение)

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"

# Guard: если скрипт запущен без подстановки пути
case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

# Читаем конфиг (дефолты если файла нет)
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"
MIN_TOOL_CALLS=5
if [ -f "$CONFIG" ]; then
  MIN_TOOL_CALLS=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('${CONFIG}','utf8'));console.log(c.min_tool_calls||5)}catch{console.log(5)}" 2>/dev/null)
  MIN_TOOL_CALLS=${MIN_TOOL_CALLS:-5}
fi

DATE=$(date +"%Y-%m-%d")
TOOL_LOG="${VAULT}/.tool-log-${DATE}.txt"

INPUT=$(cat)

# Извлекаем session_id, stop_hook_active и cwd одним вызовом node
FIELDS=$(printf '%s' "$INPUT" | node -e "
  process.stdin.setEncoding('utf8');
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try {
      const j=JSON.parse(d);
      process.stdout.write((j.session_id||'')+'\n');
      process.stdout.write(String(j.stop_hook_active||false)+'\n');
      process.stdout.write((j.cwd||'')+'\n');
    } catch {
      process.stdout.write('\nfalse\n\n');
    }
  });
" 2>/dev/null)

SESSION_ID_RAW=$(printf '%s' "$FIELDS" | sed -n '1p')
STOP_ACTIVE=$(printf '%s' "$FIELDS" | sed -n '2p')
CWD=$(printf '%s' "$FIELDS" | sed -n '3p')

# Защита от бесконечного цикла: если stop_hook_active — выходим
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Санитизация SESSION_ID — убираем слэши и спецсимволы (защита маркеров и файлов)
SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')

# Нет session_id — не можем работать
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Вычисляем имя проекта (как в log-session.sh) для точного имени файла
PROJECT=$(basename "$CWD" 2>/dev/null || printf 'general')
PROJECT=$(printf '%s' "$PROJECT" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
[ -z "$PROJECT" ] && PROJECT="general"

# Уже записан подробный лог — молчим
MARKER="${VAULT}/.logged-${SESSION_ID}"
if [ -f "$MARKER" ]; then
  exit 0
fi

# Уже напоминали в этой сессии — молчим
REMINDED="${VAULT}/.reminded-${SESSION_ID}"
if [ -f "$REMINDED" ]; then
  exit 0
fi

# Считаем tool calls для ТЕКУЩЕЙ сессии (grep по session_id)
TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
fi
TOOL_COUNT=${TOOL_COUNT:-0}

# Короткая сессия — молчим
if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  exit 0
fi

# Ставим маркер чтобы не спамить
mkdir -p "$VAULT"
touch "$REMINDED"

# Читаем язык из конфига
LANG_CFG="ru"
if [ -f "$CONFIG" ]; then
  LANG_CFG=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('${CONFIG}','utf8'));console.log(c.language||'ru')}catch{console.log('ru')}" 2>/dev/null)
  LANG_CFG=${LANG_CFG:-ru}
fi

# Напоминаем Claude (единый тег [AUTOLOG] для всех языков)
VAULT_BASE="__VAULT_PATH__"
HHMM=$(date +"%H-%M")

case "$LANG_CFG" in
  en)
    printf '[AUTOLOG] Significant session (%s tool calls). Write a detailed log:\n' "$TOOL_COUNT"
    printf -- '- Path: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- Include: what was done, files, decisions, TODO\n'
    printf -- '- After writing run: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
  zh)
    printf '[AUTOLOG] 重要会话（%s 次工具调用）。请写入详细日志：\n' "$TOOL_COUNT"
    printf -- '- 路径: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- 包含: 完成的工作、文件、决策、TODO\n'
    printf -- '- 写入后执行: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
  *)
    printf '[AUTOLOG] Сессия существенная (%s tool calls). Запиши подробный лог:\n' "$TOOL_COUNT"
    printf -- '- Путь: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- Включи: что сделано, файлы, решения, TODO\n'
    printf -- '- После записи выполни: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
esac

exit 0
