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

# Читаем конфиг одним node-вызовом (5 полей)
read -r LANG_CFG LOG_RETENTION_DAYS DAILY_NOTES MIN_TOOL_CALLS CANVAS_ENABLED < <(
  CFG="$CONFIG" node -e "
    try{const c=JSON.parse(require('fs').readFileSync(process.env.CFG,'utf8'));
    console.log([c.language||'ru',c.log_retention_days||30,c.daily_notes!==false?'true':'false',c.min_tool_calls||5,c.canvas===true?'true':'false'].join(' '))}
    catch{console.log('ru 30 true 5 false')}
  " 2>/dev/null || echo "ru 30 true 5 false"
)
LANG_CFG=${LANG_CFG:-ru}
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}
DAILY_NOTES=${DAILY_NOTES:-true}
MIN_TOOL_CALLS=${MIN_TOOL_CALLS:-5}
CANVAS_ENABLED=${CANVAS_ENABLED:-false}

# Compact mode: короткие сессии пропускают MOC/Canvas/daily
COMPACT_MODE="false"
if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  COMPACT_MODE="true"
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
  let stoppedAt='';

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

      // Парсим "Где остановился" / "Where I stopped" / "停止位置"
      const stoppedSec=log.split(/^##\\s+(?:Где остановился|Where I stopped|停止位置)/m)[1];
      if(stoppedSec){
        const line=stoppedSec.split(/^##/m)[0].trim().split('\\n')[0].trim();
        if(line && !line.startsWith('_')) stoppedAt=line;
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

  // "Где остановился" — ключевое для СДВГ
  if(stoppedAt) ctx.stopped_at=stoppedAt;
  else delete ctx.stopped_at;

  // TODO: max 5 (1 next action + 4 backlog)
  if(todos.length>0) ctx.open_todos=todos.slice(0,5);
  else delete ctx.open_todos;
  if(files.length>0) ctx.recent_files=files;

  // Автотеги по расширениям файлов
  const extMap={
    '.ts':'typescript','.tsx':'typescript','.js':'javascript','.jsx':'javascript',
    '.py':'python','.rs':'rust','.go':'golang','.java':'java','.rb':'ruby',
    '.sql':'database','.prisma':'database','.sh':'bash','.bash':'bash',
    '.css':'css','.scss':'css','.html':'html','.vue':'vue','.svelte':'svelte',
    '.json':'config','.yaml':'config','.yml':'config','.toml':'config',
    '.md':'docs','.mdx':'docs','.dockerfile':'docker','.docker':'docker'
  };
  const tags=new Set(ctx.tech_tags||[]);
  for(const f of files){
    const ext='.'+f.split('.').pop().toLowerCase();
    if(extMap[ext]) tags.add(extMap[ext]);
  }
  if(tags.size>0) ctx.tech_tags=[...tags].slice(0,10);

  fs.writeFileSync(ctxPath,JSON.stringify(ctx,null,2));
" 2>/dev/null

# ============================================================
# 3. СТРАНИЦА ПРОЕКТА (MOC) + 3b. CANVAS + 4. DAILY NOTE
# Пропускаем в compact mode (короткие сессии < min_tool_calls)
# ============================================================
if [ "$COMPACT_MODE" = "true" ]; then
  # Compact: только cleanup, пропускаем MOC/Canvas/daily
  rm -f "${SESSION_STARTED}" "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null
  # Ротация
  if [ "$LOG_RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
    find "$VAULT" -maxdepth 1 -name '.tool-log-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.logged-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.reminded-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.session-started-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  fi
  exit 0
fi

# --- Ниже только для substantial сессий ---
PROJECT_PAGE="${PROJECTS}/${PROJECT}.md"
SESSION_LINK_NAME="${DATE}_${TIME}_${PROJECT}"

# Определяем имя файла сессии (стаб или Claude-лог)
if [ "$SKIP_STUB" = "true" ] && [ -n "$SESSION_LOG" ]; then
  SESSION_LINK_NAME=$(basename "$SESSION_LOG" .md)
fi

CTX_FILE="$CONTEXT_FILE" PROJECT_PAGE="$PROJECT_PAGE" LANG="$LANG_CFG" \
PROJECT="$PROJECT" DATE="$DATE" HHMM="$HHMM" TOOL_COUNT="$TOOL_COUNT" \
SESSION_LINK="$SESSION_LINK_NAME" node -e "
  const fs=require('fs');
  const pp=process.env.PROJECT_PAGE;
  const ctx_path=process.env.CTX_FILE;
  const lang=process.env.LANG||'ru';
  const project=process.env.PROJECT;
  const date=process.env.DATE;
  const hhmm=process.env.HHMM;
  const tools=process.env.TOOL_COUNT;
  const sessionLink=process.env.SESSION_LINK;

  let ctx={};
  try{ctx=JSON.parse(fs.readFileSync(ctx_path,'utf8'))}catch{}

  const todos=(ctx.open_todos||[]).slice(0,7);
  const sessions=ctx.recent_sessions||[];

  // Добавляем текущую сессию в список (max 10)
  sessions.unshift({date,time:hhmm,link:sessionLink,tools:parseInt(tools)||0,summary:ctx.last_session?.summary||''});
  if(sessions.length>10) sessions.length=10;
  ctx.recent_sessions=sessions;

  // Сохраняем обновлённый контекст
  fs.writeFileSync(ctx_path,JSON.stringify(ctx,null,2));

  // Генерируем MOC
  const L={
    ru:{title:'Проект',status:'В работе',since:'Начало',sessions_h:'Последние сессии',
        todos_h:'Открытые задачи',date_h:'Дата',tools_h:'Инструменты',tag:'проект',no_todos:'Нет открытых задач'},
    en:{title:'Project',status:'In progress',since:'Since',sessions_h:'Recent Sessions',
        todos_h:'Open Tasks',date_h:'Date',tools_h:'Tools',tag:'project',no_todos:'No open tasks'},
    zh:{title:'项目',status:'进行中',since:'开始',sessions_h:'最近会话',
        todos_h:'待办任务',date_h:'日期',tools_h:'工具',tag:'项目',no_todos:'无待办任务'}
  };
  const t=L[lang]||L.ru;

  let md=[];
  md.push('# '+t.title+': '+project);
  md.push('');
  md.push('**'+t.status+'** | **'+t.since+':** '+(ctx.first_seen||date)+' | **Sessions:** '+(ctx.session_count||1));
  md.push('');

  // Живые ссылки на сессии
  md.push('## '+t.sessions_h);
  md.push('');
  md.push('| '+t.date_h+' | '+t.tools_h+' | |');
  md.push('|------|-------|---|');
  for(const s of sessions){
    const summary=s.summary?(' — '+s.summary.substring(0,60)):'';
    md.push('| '+s.date+' '+s.time+' | '+s.tools+' | [['+s.link+']]'+summary+' |');
  }
  md.push('');

  // TODO
  md.push('## '+t.todos_h);
  md.push('');
  if(todos.length>0){
    for(const todo of todos) md.push('- [ ] '+todo);
  } else {
    md.push('_'+t.no_todos+'_');
  }
  md.push('');
  md.push('#'+t.tag+' #'+project);

  fs.writeFileSync(pp, md.join('\n'));
" 2>/dev/null

# ============================================================
# 3b. CANVAS — визуальная карта проекта (опционально, default off)
# ============================================================
if [ "$CANVAS_ENABLED" = "true" ]; then
CANVAS_FILE="${PROJECTS}/${PROJECT}.canvas"

CTX_FILE="$CONTEXT_FILE" CANVAS_FILE="$CANVAS_FILE" PROJECT="$PROJECT" node -e "
  const fs=require('fs');
  const ctx_path=process.env.CTX_FILE;
  const canvasPath=process.env.CANVAS_FILE;
  const project=process.env.PROJECT;

  let ctx={};
  try{ctx=JSON.parse(fs.readFileSync(ctx_path,'utf8'))}catch{}

  const sessions=ctx.recent_sessions||[];
  const todos=(ctx.open_todos||[]).slice(0,5);

  // Ноды
  const nodes=[];
  const edges=[];
  let y=0;

  // Центральная нода — проект
  const projectId='project-'+project;
  nodes.push({
    id:projectId,
    type:'text',
    x:0, y:0, width:300, height:80,
    text:'# '+project+'\nSessions: '+(ctx.session_count||0),
    color:'4'
  });

  // Ноды сессий (справа)
  for(let i=0;i<Math.min(sessions.length,7);i++){
    const s=sessions[i];
    const sid='session-'+i;
    nodes.push({
      id:sid,
      type:'text',
      x:400, y: i*120, width:350, height:80,
      text:'**'+s.date+'** '+s.time+'\n'+(s.summary||s.tools+' tools'),
      color: i===0?'3':'0'
    });
    edges.push({
      id:'edge-'+i,
      fromNode:projectId,
      toNode:sid,
      fromSide:'right',
      toSide:'left'
    });
  }

  // Ноды TODO (слева)
  if(todos.length>0){
    const todoId='todos';
    let todoText='## TODO\n';
    for(const t of todos) todoText+='- [ ] '+t+'\n';
    nodes.push({
      id:todoId,
      type:'text',
      x:-450, y:0, width:350, height:40+todos.length*30,
      text:todoText,
      color:'1'
    });
    edges.push({
      id:'edge-todos',
      fromNode:todoId,
      toNode:projectId,
      fromSide:'right',
      toSide:'left'
    });
  }

  const canvas={nodes,edges};
  fs.writeFileSync(canvasPath,JSON.stringify(canvas,null,2));
" 2>/dev/null
fi  # CANVAS_ENABLED

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
