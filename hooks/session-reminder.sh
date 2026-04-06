#!/bin/bash
# Stop hook v2: контекст-инъекция при первом вызове + AUTOLOG напоминание
# Срабатывает после каждого ответа Claude
# stdout → попадает в контекст Claude

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"
PROJECTS="${VAULT_ROOT}/projects"
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"

# Guard
case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

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

# Защита от бесконечного цикла
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Санитизация SESSION_ID
SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# ============================================================
# Определение проекта из CWD
# ============================================================
resolve_project() {
  local cwd="$1"

  # 1. Проверяем project_roots в конфиге
  if [ -f "$CONFIG" ]; then
    local mapped
    mapped=$(node -e "
      const fs=require('fs');
      try {
        const c=JSON.parse(fs.readFileSync(process.env.CFG,'utf8'));
        const roots=c.project_roots||{};
        const cwd=process.env.CWD.replace(/\\\\\\\\/g,'/').toLowerCase();
        for(const [root,name] of Object.entries(roots)){
          if(cwd.startsWith(root.replace(/\\\\\\\\/g,'/').toLowerCase())){
            process.stdout.write(name);process.exit(0);
          }
        }
      } catch{}
    " 2>/dev/null)
    if [ -n "$mapped" ]; then
      printf '%s' "$mapped"
      return
    fi
  fi

  # 2. Идём вверх по директориям, ищем .context-{name}.json
  local dir="$cwd" depth=0
  while [ "$depth" -lt 4 ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    local name
    name=$(basename "$dir" 2>/dev/null)
    name=$(printf '%s' "$name" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
    if [ -n "$name" ] && [ -f "${PROJECTS}/.context-${name}.json" ]; then
      printf '%s' "$name"
      return
    fi
    dir=$(dirname "$dir" 2>/dev/null)
    depth=$((depth + 1))
  done

  # 3. Fallback: basename
  local fallback
  fallback=$(basename "$cwd" 2>/dev/null || printf 'general')
  fallback=$(printf '%s' "$fallback" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
  [ -z "$fallback" ] && fallback="general"
  printf '%s' "$fallback"
}

PROJECT=$(CFG="$CONFIG" CWD="$CWD" resolve_project "$CWD")

# ============================================================
# ПЕРВЫЙ ВЫЗОВ — инъекция контекста
# ============================================================
SESSION_STARTED="${VAULT}/.session-started-${SESSION_ID}"

if [ ! -f "$SESSION_STARTED" ]; then
  mkdir -p "$VAULT" "$PROJECTS"

  # Записываем проект в маркер (SessionEnd прочитает)
  printf '%s' "$PROJECT" > "$SESSION_STARTED"

  # Читаем контекст проекта
  CONTEXT_FILE="${PROJECTS}/.context-${PROJECT}.json"

  # Проверяем включена ли инъекция
  CONTEXT_ENABLED="true"
  if [ -f "$CONFIG" ]; then
    CONTEXT_ENABLED=$(node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.context_injection!==false?'true':'false')}catch{console.log('true')}" 2>/dev/null)
  fi

  if [ "$CONTEXT_ENABLED" = "true" ] && [ -f "$CONTEXT_FILE" ]; then
    CONTEXT_OUTPUT=$(CFG="$CONTEXT_FILE" node -e "
      const fs=require('fs');
      try {
        const c=JSON.parse(fs.readFileSync(process.env.CFG,'utf8'));
        const lines=[];
        if(c.last_session){
          lines.push('Последняя сессия: '+c.last_session.date+' — '+(c.last_session.summary||'нет описания'));
        }
        if(c.open_todos && c.open_todos.length>0){
          lines.push('Открытые задачи:');
          c.open_todos.slice(0,7).forEach(t=>lines.push('  - [ ] '+t));
        }
        if(c.recent_files && c.recent_files.length>0){
          lines.push('Недавние файлы: '+c.recent_files.slice(0,5).join(', '));
        }
        if(lines.length>0) console.log(lines.join('\n'));
      } catch{}
    " 2>/dev/null)

    if [ -n "$CONTEXT_OUTPUT" ]; then
      printf '[CONTEXT] Проект: %s\n%s\n' "$PROJECT" "$CONTEXT_OUTPUT"
    fi
  fi

  exit 0
fi

# ============================================================
# ПОСЛЕДУЮЩИЕ ВЫЗОВЫ — AUTOLOG логика (из v1)
# ============================================================

# Уже записан лог — молчим
MARKER="${VAULT}/.logged-${SESSION_ID}"
if [ -f "$MARKER" ]; then
  exit 0
fi

# Уже напоминали — молчим
REMINDED="${VAULT}/.reminded-${SESSION_ID}"
if [ -f "$REMINDED" ]; then
  exit 0
fi

# Читаем конфиг
MIN_TOOL_CALLS=5
if [ -f "$CONFIG" ]; then
  MIN_TOOL_CALLS=$(node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.min_tool_calls||5)}catch{console.log(5)}" 2>/dev/null)
  MIN_TOOL_CALLS=${MIN_TOOL_CALLS:-5}
fi

# Считаем tool calls текущей сессии
TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
fi
TOOL_COUNT=${TOOL_COUNT:-0}

if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  exit 0
fi

# Ставим маркер
mkdir -p "$VAULT"
touch "$REMINDED"

# Читаем язык
LANG_CFG="ru"
if [ -f "$CONFIG" ]; then
  LANG_CFG=$(node -e "try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));console.log(c.language||'ru')}catch{console.log('ru')}" 2>/dev/null)
  LANG_CFG=${LANG_CFG:-ru}
fi

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
