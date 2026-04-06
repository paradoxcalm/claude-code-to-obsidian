#!/bin/bash
# PostToolUse hook: логирует каждый вызов инструмента
# Используется для подсчёта — была ли сессия существенной
# Формат строки: TIME | SESSION_ID | TOOL | CWD

VAULT="__VAULT_PATH__/sessions"

# Guard: если скрипт запущен без подстановки пути, VAULT будет содержать литерал
# Проверяем через наличие двойного подчёркивания в начале пути
case "$VAULT" in
  __*) exit 0 ;;
esac

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M:%S")
LOGFILE="${VAULT}/.tool-log-${DATE}.txt"

INPUT=$(cat)

# Извлекаем все поля одним вызовом node (каждое на отдельной строке)
FIELDS=$(printf '%s' "$INPUT" | node -e "
  process.stdin.setEncoding('utf8');
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try {
      const j=JSON.parse(d);
      process.stdout.write((j.tool_name||'?')+'\n');
      process.stdout.write((j.cwd||'?')+'\n');
      process.stdout.write((j.session_id||'?')+'\n');
    } catch {
      process.stdout.write('?\n?\n?\n');
    }
  });
" 2>/dev/null)

TOOL=$(printf '%s' "$FIELDS" | sed -n '1p')
CWD=$(printf '%s' "$FIELDS" | sed -n '2p')
SESSION_RAW=$(printf '%s' "$FIELDS" | sed -n '3p')

# Санитизация SESSION_ID — убираем слэши и спецсимволы
SESSION=$(printf '%s' "$SESSION_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION" ] && SESSION="?"

mkdir -p "$VAULT"
printf '%s\n' "${TIME} | ${SESSION} | ${TOOL} | ${CWD}" >> "$LOGFILE"

exit 0
