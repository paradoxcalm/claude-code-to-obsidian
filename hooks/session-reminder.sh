#!/bin/bash
# Stop hook: контекст-инъекция при первом вызове + AUTOLOG напоминание
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

# Парсим JSON через sed — без node для скорости (~400ms экономии на Windows)
SESSION_ID_RAW=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
STOP_ACTIVE=$(printf '%s' "$INPUT" | sed -n 's/.*"stop_hook_active"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p')
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$STOP_ACTIVE" ] && STOP_ACTIVE="false"

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

  # 2. Git-based detection: берём имя репо из git toplevel или remote origin
  local git_name=""
  git_name=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
  git_name=$(printf '%s' "$git_name" | LC_ALL=C tr -cd 'a-zA-Z0-9._-' | head -c 50)
  if [ -n "$git_name" ]; then
    printf '%s' "$git_name"
    return
  fi

  # 3. Идём вверх по директориям, ищем .context-{name}.json
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

# ============================================================
# ПЕРВЫЙ ВЫЗОВ vs ПОВТОРНЫЙ
# ============================================================
SESSION_STARTED="${VAULT}/.session-started-${SESSION_ID}"

if [ ! -f "$SESSION_STARTED" ]; then
  # ПЕРВЫЙ ВЫЗОВ — определяем проект и инжектим контекст
  PROJECT=$(CFG="$CONFIG" CWD="$CWD" resolve_project "$CWD")
  mkdir -p "$VAULT" "$PROJECTS"

  # Auto-update: если repo доступен и VERSION изменился — пересобираем скрипты
  if [ -f "$CONFIG" ]; then
    _repo=$(sed -n 's/.*"repo_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
    _iver=$(sed -n 's/.*"installed_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
    if [ -n "$_repo" ] && [ -f "$_repo/VERSION" ]; then
      _rver=$(tr -d '[:space:]' < "$_repo/VERSION" 2>/dev/null)
      if [ -n "$_rver" ] && [ "$_rver" != "$_iver" ]; then
        for _s in log-session.sh log-tools.sh session-reminder.sh; do
          [ -f "$_repo/hooks/$_s" ] && sed "s|__VAULT_PATH__|${VAULT_ROOT}|g" "$_repo/hooks/$_s" > "${VAULT_ROOT}/scripts/$_s"
        done
        _tmp="${CONFIG}.tmp.$$"
        sed "s/\"installed_version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"installed_version\": \"$_rver\"/" "$CONFIG" > "$_tmp" && mv "$_tmp" "$CONFIG"
        printf '[UPDATE] Скрипты обновлены: v%s → v%s\n' "${_iver:-?}" "$_rver"
      fi
    fi
  fi

  # Записываем проект в маркер (SessionEnd и повторные Stop прочитают)
  printf '%s' "$PROJECT" > "$SESSION_STARTED"

  # Читаем контекст проекта + конфиг одним node-вызовом
  CONTEXT_FILE="${PROJECTS}/.context-${PROJECT}.json"

  CONTEXT_OUTPUT=$(CFG="$CONFIG" CTX="$CONTEXT_FILE" PROJECTS_DIR="$PROJECTS" \
  PROJECT="$PROJECT" node -e "
    const fs=require('fs'),path=require('path');
    try {
      // Конфиг
      let cfg={};
      try{cfg=JSON.parse(fs.readFileSync(process.env.CFG,'utf8'))}catch{}
      if(cfg.context_injection===false) process.exit(0);

      // Контекст проекта
      const ctxPath=process.env.CTX;
      if(!fs.existsSync(ctxPath)) process.exit(0);
      const c=JSON.parse(fs.readFileSync(ctxPath,'utf8'));

      const lines=[];

      // Где остановился — самое важное для СДВГ
      if(c.stopped_at) lines.push('Где остановился: '+c.stopped_at);

      // Последние 5 сессий — компактно, одна строка каждая
      const sessions=c.recent_sessions||[];
      if(sessions.length>0){
        lines.push('Последние сессии:');
        sessions.slice(0,5).forEach(s=>{
          const mark=s.summary&&s.summary.includes('не записаны')?'':'';
          lines.push('  '+s.date+' — '+(s.summary||s.tools+' tools'));
        });
      }

      // ВСЕ незакрытые TODO (не только из последней сессии)
      const todos=(c.open_todos||[]).slice(0,5);
      if(todos.length>0){
        lines.push('Задачи:');
        lines.push('  → '+todos[0]+' (следующее действие)');
        todos.slice(1).forEach(t=>lines.push('  → '+t));
      }

      // Stale detection: проверяем другие проекты
      const staleThreshold=cfg.stale_threshold_days||5;
      const now=new Date();
      const projDir=process.env.PROJECTS_DIR;
      const currentProject=process.env.PROJECT;
      try{
        const files=fs.readdirSync(projDir).filter(f=>f.startsWith('.context-')&&f.endsWith('.json'));
        const stale=[];
        for(const f of files){
          const name=f.replace('.context-','').replace('.json','');
          if(name===currentProject) continue;
          try{
            const pc=JSON.parse(fs.readFileSync(path.join(projDir,f),'utf8'));
            if(pc.last_seen){
              const days=Math.floor((now-new Date(pc.last_seen))/(86400000));
              if(days>=staleThreshold){
                stale.push({name,days,action:pc.stopped_at||(pc.open_todos&&pc.open_todos[0])||''});
              }
            }
          }catch{}
        }
        stale.sort((a,b)=>a.days-b.days);
        if(stale.length>0){
          const s=stale[0];
          lines.push('Внимание: '+s.name+' не трогался '+s.days+' дней'+(s.action?' ('+s.action+')':''));
        }
      }catch{}

      if(lines.length>0) console.log(lines.join('\n'));
    } catch{}
  " 2>/dev/null)

  if [ -n "$CONTEXT_OUTPUT" ]; then
    printf '[CONTEXT] Проект: %s\n%s\n' "$PROJECT" "$CONTEXT_OUTPUT"
  fi

  exit 0
fi

# ============================================================
# ПОВТОРНЫЕ ВЫЗОВЫ — AUTOLOG логика (без node, без resolve_project)
# ============================================================

# Читаем проект из маркера (уже определён при первом вызове)
PROJECT=$(cat "$SESSION_STARTED" 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="general"

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

# Читаем конфиг через sed — без node (экономим ~400ms)
MIN_TOOL_CALLS=5
LANG_CFG="ru"
if [ -f "$CONFIG" ]; then
  _mtc=$(sed -n 's/.*"min_tool_calls"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$CONFIG" 2>/dev/null)
  _lang=$(sed -n 's/.*"language"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
  [ -n "$_mtc" ] && MIN_TOOL_CALLS="$_mtc"
  [ -n "$_lang" ] && LANG_CFG="$_lang"
fi

# Считаем tool calls: session_id + fallback на CWD (ловит sub-agent вызовы)
TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
  TOOL_COUNT=${TOOL_COUNT:-0}
  # Fallback: если session_id не нашёл — ищем по CWD (sub-agent случай, exact match)
  if [ "$TOOL_COUNT" -eq 0 ] 2>/dev/null && [ -n "$CWD" ] && [ "$CWD" != "unknown" ]; then
    TOOL_COUNT=$(awk -F'|' -v cwd="$CWD" '{gsub(/^[ \t]+|[ \t]+$/,"",$4)} $4==cwd{c++} END{print c+0}' "$TOOL_LOG" 2>/dev/null || echo 0)
  fi
fi
TOOL_COUNT=${TOOL_COUNT:-0}

if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  exit 0
fi

# Ставим маркер
mkdir -p "$VAULT"
touch "$REMINDED"

VAULT_BASE="__VAULT_PATH__"
HHMM=$(date +"%H-%M")

# Находим предыдущую сессию из контекст-кэша (быстро, O(1))
PREV_SESSION=""
CTX_PREV="${PROJECTS}/.context-${PROJECT}.json"
if [ -f "$CTX_PREV" ]; then
  PREV_SESSION=$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CTX_PREV" 2>/dev/null | head -1)
fi

case "$LANG_CFG" in
  en)
    printf '[AUTOLOG] Significant session (%s tool calls). Write a detailed log:\n' "$TOOL_COUNT"
    printf -- '- Path: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- Include: what was done, files, decisions, TODO\n'
    if [ -n "$PREV_SESSION" ]; then
      printf -- '- Previous session: %s (use in frontmatter previous_session field)\n' "$PREV_SESSION"
    fi
    printf -- '- After writing run: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
  zh)
    printf '[AUTOLOG] 重要会话（%s 次工具调用）。请写入详细日志：\n' "$TOOL_COUNT"
    printf -- '- 路径: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- 包含: 完成的工作、文件、决策、TODO\n'
    if [ -n "$PREV_SESSION" ]; then
      printf -- '- 上次会话: %s（用于 frontmatter previous_session 字段）\n' "$PREV_SESSION"
    fi
    printf -- '- 写入后执行: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
  *)
    printf '[AUTOLOG] Сессия существенная (%s tool calls). Запиши подробный лог:\n' "$TOOL_COUNT"
    printf -- '- Путь: %s/sessions/%s_%s_%s.md\n' "$VAULT_BASE" "$DATE" "$HHMM" "$PROJECT"
    printf -- '- Включи: что сделано, файлы, решения, TODO\n'
    if [ -n "$PREV_SESSION" ]; then
      printf -- '- Предыдущая сессия: %s (используй в frontmatter previous_session)\n' "$PREV_SESSION"
    fi
    printf -- '- После записи выполни: touch "%s/sessions/.logged-%s"\n' "$VAULT_BASE" "$SESSION_ID"
    ;;
esac

exit 0
