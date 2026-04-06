#!/bin/bash
# SessionEnd hook v2: сохраняет контекст проекта, обновляет daily note, создаёт project page
# Срабатывает при завершении сессии Claude Code

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"
PROJECTS="${VAULT_ROOT}/projects"
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"

# Guard
case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H-%M")
HHMM=$(date +"%H:%M")

INPUT=$(cat)

# Извлекаем session_id и cwd
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

SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# ============================================================
# Определяем проект (из маркера Stop хука или из CWD)
# ============================================================
SESSION_STARTED="${VAULT}/.session-started-${SESSION_ID}"
if [ -f "$SESSION_STARTED" ]; then
  PROJECT=$(cat "$SESSION_STARTED" 2>/dev/null)
fi

if [ -z "$PROJECT" ]; then
  PROJECT=$(basename "$CWD" 2>/dev/null || printf 'general')
  PROJECT=$(printf '%s' "$PROJECT" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
fi
[ -z "$PROJECT" ] && PROJECT="general"

# Считаем tool calls этой сессии
TOOL_LOG="${VAULT}/.tool-log-${DATE}.txt"
TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
fi
TOOL_COUNT=${TOOL_COUNT:-0}

# Читаем конфиг
LANG_CFG="ru"
LOG_RETENTION_DAYS=30
DAILY_NOTES="true"
if [ -f "$CONFIG" ]; then
  LANG_CFG=$(CFG="$CONFIG" node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.language||'ru')}catch{console.log('ru')}" 2>/dev/null)
  LOG_RETENTION_DAYS=$(CFG="$CONFIG" node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.log_retention_days||30)}catch{console.log(30)}" 2>/dev/null)
  DAILY_NOTES=$(CFG="$CONFIG" node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.daily_notes!==false?'true':'false')}catch{console.log('true')}" 2>/dev/null)
  LANG_CFG=${LANG_CFG:-ru}
  LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}
fi

# Если Claude уже записал подробный лог — не создаём стаб
MARKER="${VAULT}/.logged-${SESSION_ID}"
SKIP_STUB="false"
if [ -f "$MARKER" ]; then
  SKIP_STUB="true"
fi

mkdir -p "$VAULT" "$PROJECTS"

# ============================================================
# 1. СТАБ-ЛОГ СЕССИИ (если Claude не записал)
# ============================================================
if [ "$SKIP_STUB" = "false" ]; then
  LOGFILE="${VAULT}/${DATE}_${TIME}_${PROJECT}.md"
  if [ -f "$LOGFILE" ]; then
    SHORT_ID=$(printf '%s' "$SESSION_ID" | head -c 8)
    LOGFILE="${VAULT}/${DATE}_${TIME}_${PROJECT}_${SHORT_ID}.md"
  fi

  {
    printf -- '---\n'
    printf 'project: %s\n' "$PROJECT"
    printf 'date: %s\n' "$DATE"
    printf 'time: %s\n' "$HHMM"
    printf 'session_id: %s\n' "$SESSION_ID"
    printf -- '---\n\n'

    case "$LANG_CFG" in
      en)
        printf '# Session: %s\n\n' "$PROJECT"
        printf '**Project:** [[%s]]\n' "$PROJECT"
        printf '**Directory:** `%s`\n\n' "$CWD"
        printf '## What was done\n'
        printf '_Brief session (%s tool calls) — details not recorded_\n\n' "$TOOL_COUNT"
        printf '#session #%s\n' "$PROJECT"
        ;;
      zh)
        printf '# 会话: %s\n\n' "$PROJECT"
        printf '**项目:** [[%s]]\n' "$PROJECT"
        printf '**目录:** `%s`\n\n' "$CWD"
        printf '## 完成内容\n'
        printf '_简短会话（%s 次工具调用）— 未记录详情_\n\n' "$TOOL_COUNT"
        printf '#会话 #%s\n' "$PROJECT"
        ;;
      *)
        printf '# Сессия: %s\n\n' "$PROJECT"
        printf '**Проект:** [[%s]]\n' "$PROJECT"
        printf '**Директория:** `%s`\n\n' "$CWD"
        printf '## Что сделано\n'
        printf '_Краткая сессия (%s tool calls) — подробности не записаны_\n\n' "$TOOL_COUNT"
        printf '#сессия #%s\n' "$PROJECT"
        ;;
    esac
  } > "$LOGFILE"
fi

# ============================================================
# 2. СОХРАНЕНИЕ КОНТЕКСТА ПРОЕКТА
# ============================================================
CONTEXT_FILE="${PROJECTS}/.context-${PROJECT}.json"

# Находим лог-файл этой сессии (Claude мог записать, или стаб)
SESSION_LOG=""
if [ "$SKIP_STUB" = "true" ]; then
  # Claude записал — ищем файл по дате и проекту
  SESSION_LOG=$(ls -t "${VAULT}/${DATE}"*"${PROJECT}"*.md 2>/dev/null | head -1)
else
  SESSION_LOG="$LOGFILE"
fi

CTX_FILE="$CONTEXT_FILE" LOG_FILE="${SESSION_LOG:-}" node -e "
  const fs=require('fs');
  const ctxPath=process.env.CTX_FILE;
  const logPath=process.env.LOG_FILE;

  let ctx={};
  try { ctx=JSON.parse(fs.readFileSync(ctxPath,'utf8')); } catch{}

  ctx.project=ctx.project||'${PROJECT}';
  ctx.first_seen=ctx.first_seen||'${DATE}';
  ctx.last_seen='${DATE}';
  ctx.session_count=(ctx.session_count||0)+1;

  let summary='${TOOL_COUNT} tool calls';
  let todos=ctx.open_todos||[];
  let files=[];

  if(logPath){
    try{
      const log=fs.readFileSync(logPath,'utf8');
      const tm=log.match(/^#\\s+(?:Сессия|Session|会话):\\s*(.+)/m);
      if(tm && !tm[1].match(/^\\s*${PROJECT}\\s*$/)) summary=tm[1].trim();

      const todoSec=log.split(/^##\\s+TODO/m)[1];
      if(todoSec){
        const items=todoSec.split(/^##/m)[0];
        const m=items.match(/^-\\s*\\[\\s*\\]\\s*(.+)/gm);
        if(m) todos=m.map(x=>x.replace(/^-\\s*\\[\\s*\\]\\s*/,'').trim());
      }

      const fileSec=log.split(/^##\\s+(?:Изменённые файлы|Changed Files|变更文件)/m)[1];
      if(fileSec){
        const items=fileSec.split(/^##/m)[0];
        const m=items.match(/\`([^\`]+)\`/g);
        if(m) files=m.map(x=>x.replace(/\`/g,'')).slice(0,10);
      }
    }catch{}
  }

  ctx.last_session={
    id:'${SESSION_ID}',
    date:'${DATE}',
    time:'${HHMM}',
    summary:summary,
    cwd:'${CWD}'
  };

  if(todos.length>0) ctx.open_todos=todos;
  else delete ctx.open_todos;
  if(files.length>0) ctx.recent_files=files;

  fs.writeFileSync(ctxPath,JSON.stringify(ctx,null,2));
" 2>/dev/null

# ============================================================
# 3. СТРАНИЦА ПРОЕКТА (создаём если нет)
# ============================================================
PROJECT_PAGE="${PROJECTS}/${PROJECT}.md"
if [ ! -f "$PROJECT_PAGE" ]; then
  case "$LANG_CFG" in
    en)
      {
        printf '# Project: %s\n\n' "$PROJECT"
        printf '**Status:** In progress\n'
        printf '**Since:** %s\n\n' "$DATE"
        printf '## Open Tasks\n'
        printf '```dataview\nTASK FROM "sessions"\nWHERE contains(file.name, "%s") AND !completed\n```\n\n' "$PROJECT"
        printf '## Recent Sessions\n'
        printf '```dataview\nTABLE date as "Date", time as "Time"\nFROM "sessions"\nWHERE project = "%s"\nSORT date DESC\nLIMIT 10\n```\n\n' "$PROJECT"
        printf '#project #%s\n' "$PROJECT"
      } > "$PROJECT_PAGE"
      ;;
    zh)
      {
        printf '# 项目: %s\n\n' "$PROJECT"
        printf '**状态:** 进行中\n'
        printf '**开始:** %s\n\n' "$DATE"
        printf '## 待办任务\n'
        printf '```dataview\nTASK FROM "sessions"\nWHERE contains(file.name, "%s") AND !completed\n```\n\n' "$PROJECT"
        printf '## 最近会话\n'
        printf '```dataview\nTABLE date as "日期", time as "时间"\nFROM "sessions"\nWHERE project = "%s"\nSORT date DESC\nLIMIT 10\n```\n\n' "$PROJECT"
        printf '#项目 #%s\n' "$PROJECT"
      } > "$PROJECT_PAGE"
      ;;
    *)
      {
        printf '# Проект: %s\n\n' "$PROJECT"
        printf '**Статус:** В работе\n'
        printf '**Начало:** %s\n\n' "$DATE"
        printf '## Открытые задачи\n'
        printf '```dataview\nTASK FROM "sessions"\nWHERE contains(file.name, "%s") AND !completed\n```\n\n' "$PROJECT"
        printf '## Последние сессии\n'
        printf '```dataview\nTABLE date as "Дата", time as "Время"\nFROM "sessions"\nWHERE project = "%s"\nSORT date DESC\nLIMIT 10\n```\n\n' "$PROJECT"
        printf '#проект #%s\n' "$PROJECT"
      } > "$PROJECT_PAGE"
      ;;
  esac
fi

# ============================================================
# 4. DAILY NOTE (создаём/обновляем)
# ============================================================
if [ "$DAILY_NOTES" = "true" ]; then
  DAILY_DIR="${VAULT_ROOT}/daily"
  DAILY_FILE="${DAILY_DIR}/${DATE}.md"
  mkdir -p "$DAILY_DIR"

  if [ ! -f "$DAILY_FILE" ]; then
    case "$LANG_CFG" in
      en)
        {
          printf '# %s\n\n' "$DATE"
          printf '## Sessions\n'
          printf -- '- %s — [[%s]] — %s tool calls\n\n' "$HHMM" "$PROJECT" "$TOOL_COUNT"
          printf '## Tasks\n'
          printf '```dataview\nTASK FROM "sessions"\nWHERE file.cday = date(%s) AND !completed\n```\n\n' "$DATE"
          printf '#daily\n'
        } > "$DAILY_FILE"
        ;;
      zh)
        {
          printf '# %s\n\n' "$DATE"
          printf '## 会话\n'
          printf -- '- %s — [[%s]] — %s 次工具调用\n\n' "$HHMM" "$PROJECT" "$TOOL_COUNT"
          printf '## 任务\n'
          printf '```dataview\nTASK FROM "sessions"\nWHERE file.cday = date(%s) AND !completed\n```\n\n' "$DATE"
          printf '#daily\n'
        } > "$DAILY_FILE"
        ;;
      *)
        {
          printf '# %s\n\n' "$DATE"
          printf '## Сессии\n'
          printf -- '- %s — [[%s]] — %s tool calls\n\n' "$HHMM" "$PROJECT" "$TOOL_COUNT"
          printf '## Задачи\n'
          printf '```dataview\nTASK FROM "sessions"\nWHERE file.cday = date(%s) AND !completed\n```\n\n' "$DATE"
          printf '#daily\n'
        } > "$DAILY_FILE"
        ;;
    esac
  else
    # Дописываем строку в существующий daily note (перед ##  или в конец)
    if ! grep -qF "[[${PROJECT}]]" "$DAILY_FILE" 2>/dev/null; then
      # Ищем секцию "Сессии/Sessions/会话" и дописываем после неё
      printf -- '- %s — [[%s]] — %s tool calls\n' "$HHMM" "$PROJECT" "$TOOL_COUNT" >> "$DAILY_FILE"
    fi
  fi
fi

# ============================================================
# 5. CLEANUP
# ============================================================
rm -f "${SESSION_STARTED}" 2>/dev/null
rm -f "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null

# Ротация старых технических файлов
if [ "$LOG_RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
  find "$VAULT" -maxdepth 1 -name '.tool-log-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.logged-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.reminded-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.session-started-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
fi

exit 0
