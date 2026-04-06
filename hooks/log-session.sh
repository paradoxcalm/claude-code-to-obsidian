#!/bin/bash
# SessionEnd hook: создаёт заготовку лога сессии в Obsidian vault
# Срабатывает автоматически при завершении сессии Claude Code

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"

# Guard: если скрипт запущен без подстановки пути
case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

# Читаем конфиг (дефолты если файла нет)
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"
LOG_RETENTION_DAYS=30
if [ -f "$CONFIG" ]; then
  LOG_RETENTION_DAYS=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('${CONFIG}','utf8'));console.log(c.log_retention_days||30)}catch{console.log(30)}" 2>/dev/null)
  LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}
fi

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H-%M")
HHMM=$(date +"%H:%M")

INPUT=$(cat)

# Извлекаем session_id и cwd одним вызовом node (полный session_id, без обрезки)
FIELDS=$(printf '%s' "$INPUT" | node -e "
  process.stdin.setEncoding('utf8');
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try {
      const j=JSON.parse(d);
      process.stdout.write((j.session_id||'unknown')+'\n');
      process.stdout.write((j.cwd||'unknown')+'\n');
    } catch {
      process.stdout.write('unknown\nunknown\n');
    }
  });
" 2>/dev/null)

SESSION_ID_RAW=$(printf '%s' "$FIELDS" | sed -n '1p')
CWD=$(printf '%s' "$FIELDS" | sed -n '2p')

# Санитизация SESSION_ID — убираем слэши и спецсимволы (согласовано со всеми хуками)
SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# Санитизация имени проекта для безопасных имён файлов
PROJECT=$(basename "$CWD" 2>/dev/null || printf 'general')
PROJECT=$(printf '%s' "$PROJECT" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
[ -z "$PROJECT" ] && PROJECT="general"

# Если Claude уже записал подробный лог — не создаём заготовку
MARKER="${VAULT}/.logged-${SESSION_ID}"
if [ -f "$MARKER" ]; then
  exit 0
fi

# Формируем имя файла с проверкой коллизий
LOGFILE="${VAULT}/${DATE}_${TIME}_${PROJECT}.md"
if [ -f "$LOGFILE" ]; then
  SHORT_ID=$(printf '%s' "$SESSION_ID" | head -c 8)
  LOGFILE="${VAULT}/${DATE}_${TIME}_${PROJECT}_${SHORT_ID}.md"
fi

mkdir -p "$VAULT"

# Читаем язык из конфига
LANG_CFG="ru"
if [ -f "$CONFIG" ]; then
  LANG_CFG=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('${CONFIG}','utf8'));console.log(c.language||'ru')}catch{console.log('ru')}" 2>/dev/null)
  LANG_CFG=${LANG_CFG:-ru}
fi

# Пишем стаб-лог на языке из конфига
{
  case "$LANG_CFG" in
    en)
      printf '# Session: %s\n\n' "$PROJECT"
      printf '**Date:** %s %s\n' "$DATE" "$HHMM"
      printf '**Project:** %s\n' "$PROJECT"
      printf '**Directory:** %s\n' "$CWD"
      printf '**Session ID:** %s\n\n' "$SESSION_ID"
      printf '## What was done\n'
      printf '_Brief session — details not recorded_\n\n'
      printf '#session #%s\n' "$PROJECT"
      ;;
    zh)
      printf '# 会话: %s\n\n' "$PROJECT"
      printf '**日期:** %s %s\n' "$DATE" "$HHMM"
      printf '**项目:** %s\n' "$PROJECT"
      printf '**目录:** %s\n' "$CWD"
      printf '**Session ID:** %s\n\n' "$SESSION_ID"
      printf '## 完成内容\n'
      printf '_简短会话 — 未记录详情_\n\n'
      printf '#会话 #%s\n' "$PROJECT"
      ;;
    *)
      printf '# Сессия: %s\n\n' "$PROJECT"
      printf '**Дата:** %s %s\n' "$DATE" "$HHMM"
      printf '**Проект:** %s\n' "$PROJECT"
      printf '**Директория:** %s\n' "$CWD"
      printf '**Session ID:** %s\n\n' "$SESSION_ID"
      printf '## Что сделано\n'
      printf '_Краткая сессия — подробности не записаны_\n\n'
      printf '#сессия #%s\n' "$PROJECT"
      ;;
  esac
} > "$LOGFILE"

# Чистим маркер напоминания
rm -f "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null

# Ротация: удаляем технические файлы старше LOG_RETENTION_DAYS
if [ "$LOG_RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
  find "$VAULT" -maxdepth 1 -name '.tool-log-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.logged-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.reminded-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
fi

exit 0
