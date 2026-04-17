#!/bin/bash
# SessionEnd hook: writes stub log, updates project context, MOC, daily note.
# Node logic lives in lib/*.js — bash only orchestrates.

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"
PROJECTS="${VAULT_ROOT}/projects"
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"
LIB="${VAULT_ROOT}/scripts/lib"
HOOK_NAME="SessionEnd"

case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

# shellcheck disable=SC1091
[ -f "${LIB}/common.sh" ] && . "${LIB}/common.sh"

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H-%M")
HHMM=$(date +"%H:%M")

INPUT=$(cat)

SESSION_ID_RAW=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$SESSION_ID_RAW" ] && SESSION_ID_RAW="unknown"
[ -z "$CWD" ] && CWD="unknown"

SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

SESSION_STARTED="${VAULT}/.session-started-${SESSION_ID}"
PROJECT=""
if [ -f "$SESSION_STARTED" ]; then
  PROJECT=$(cat "$SESSION_STARTED" 2>/dev/null)
fi

if [ -z "$PROJECT" ]; then
  PROJECT=$(CFG="$CONFIG" CWD="$CWD" PROJECTS_DIR="$PROJECTS" node "${LIB}/resolve-project.js" 2>/dev/null)
fi
[ -z "$PROJECT" ] && PROJECT="general"

TOOL_LOG="${VAULT}/.tool-log-${DATE}.txt"
TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
  TOOL_COUNT=${TOOL_COUNT:-0}
  if [ "$TOOL_COUNT" -eq 0 ] 2>/dev/null && [ -n "$CWD" ] && [ "$CWD" != "unknown" ]; then
    TOOL_COUNT=$(awk -F'|' -v cwd="$CWD" '{gsub(/^[ \t]+|[ \t]+$/,"",$4)} $4==cwd{c++} END{print c+0}' "$TOOL_LOG" 2>/dev/null || true)
  fi
fi
TOOL_COUNT=${TOOL_COUNT:-0}

_cfg_line=$(CFG="$CONFIG" node "${LIB}/read-config.js" 2>/dev/null || echo "ru 30 true 5 false")
LANG_CFG=$(echo "$_cfg_line" | cut -d' ' -f1)
LOG_RETENTION_DAYS=$(echo "$_cfg_line" | cut -d' ' -f2)
DAILY_NOTES=$(echo "$_cfg_line" | cut -d' ' -f3)
MIN_TOOL_CALLS=$(echo "$_cfg_line" | cut -d' ' -f4)
CANVAS_ENABLED=$(echo "$_cfg_line" | cut -d' ' -f5)
LANG_CFG=${LANG_CFG:-ru}
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}
DAILY_NOTES=${DAILY_NOTES:-true}
MIN_TOOL_CALLS=${MIN_TOOL_CALLS:-5}
CANVAS_ENABLED=${CANVAS_ENABLED:-false}

COMPACT_MODE="false"
if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  COMPACT_MODE="true"
fi

MARKER="${VAULT}/.logged-${SESSION_ID}"
SKIP_STUB="false"
if [ -f "$MARKER" ]; then
  SKIP_STUB="true"
fi

mkdir -p "$VAULT" "$PROJECTS" || true

PREV_SESSION=""
CONTEXT_FILE="${PROJECTS}/.context-${PROJECT}.json"
if [ -f "$CONTEXT_FILE" ]; then
  PREV_SESSION=$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONTEXT_FILE" 2>/dev/null | head -1)
fi

# ============================================================
# 1. Stub log (if Claude didn't write a detailed one)
# ============================================================
TOOLS_USED=""
if [ -f "$TOOL_LOG" ] && [ "$TOOL_COUNT" -gt 0 ] && [ "$CWD" != "unknown" ]; then
  TOOLS_USED=$(awk -F'|' -v cwd="$CWD" '{gsub(/^[ \t]+|[ \t]+$/,"",$4); gsub(/^[ \t]+|[ \t]+$/,"",$3)} $4==cwd{count[$3]++} END{for(k in count) print count[k], k}' "$TOOL_LOG" 2>/dev/null | sort -rn | head -8 | awk '{printf "%s x%s, ", $2, $1}' | sed 's/, $//')
fi

LOGFILE=""
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
    printf 'tags: [%s]\n' "$PROJECT"
    printf 'files_changed: 0\n'
    printf 'status: completed\n'
    printf 'session_id: %s\n' "$SESSION_ID"
    if [ -n "$PREV_SESSION" ]; then
      printf 'previous_session: "sessions/%s"\n' "$PREV_SESSION"
    fi
    printf -- '---\n\n'

    case "$LANG_CFG" in
      en)
        printf '# Session: %s\n\n' "$PROJECT"
        printf '**Project:** [[%s]]\n' "$PROJECT"
        printf '**Directory:** `%s`\n\n' "$CWD"
        printf '## What was done\n'
        if [ -n "$TOOLS_USED" ]; then
          printf '_Session: %s tool calls (%s)_\n\n' "$TOOL_COUNT" "$TOOLS_USED"
        else
          printf '_Brief session (%s tool calls) — details not recorded_\n\n' "$TOOL_COUNT"
        fi
        printf '#session #%s\n' "$PROJECT"
        ;;
      zh)
        printf '# 会话: %s\n\n' "$PROJECT"
        printf '**项目:** [[%s]]\n' "$PROJECT"
        printf '**目录:** `%s`\n\n' "$CWD"
        printf '## 完成内容\n'
        if [ -n "$TOOLS_USED" ]; then
          printf '_会话: %s 次工具调用 (%s)_\n\n' "$TOOL_COUNT" "$TOOLS_USED"
        else
          printf '_简短会话（%s 次工具调用）— 未记录详情_\n\n' "$TOOL_COUNT"
        fi
        printf '#会话 #%s\n' "$PROJECT"
        ;;
      *)
        printf '# Сессия: %s\n\n' "$PROJECT"
        printf '**Проект:** [[%s]]\n' "$PROJECT"
        printf '**Директория:** `%s`\n\n' "$CWD"
        printf '## Что сделано\n'
        if [ -n "$TOOLS_USED" ]; then
          printf '_Сессия: %s tool calls (%s)_\n\n' "$TOOL_COUNT" "$TOOLS_USED"
        else
          printf '_Краткая сессия (%s tool calls) — подробности не записаны_\n\n' "$TOOL_COUNT"
        fi
        printf '#сессия #%s\n' "$PROJECT"
        ;;
    esac
  } > "$LOGFILE"
fi

# ============================================================
# 2. Update project context JSON
# ============================================================
SESSION_LINK_NAME="${DATE}_${TIME}_${PROJECT}"

SESSION_LOG=""
if [ "$SKIP_STUB" = "true" ]; then
  SESSION_LOG=$(ls -t "${VAULT}/${DATE}"*"${PROJECT}"*.md 2>/dev/null | head -1)
  [ -n "$SESSION_LOG" ] && SESSION_LINK_NAME=$(basename "${SESSION_LOG}" .md)
else
  SESSION_LOG="$LOGFILE"
fi

CTX_FILE="$CONTEXT_FILE" LOG_FILE="${SESSION_LOG:-}" \
CTX_PROJECT="$PROJECT" CTX_DATE="$DATE" CTX_HHMM="$HHMM" \
CTX_TOOLS="$TOOL_COUNT" CTX_SID="$SESSION_ID" CTX_CWD="$CWD" \
CTX_LINK="$SESSION_LINK_NAME" \
run_node "${LIB}/write-context.js" || true

# ============================================================
# 3. MOC + Canvas + Daily note (only if there were tool calls)
# ============================================================
if [ "$TOOL_COUNT" -eq 0 ] 2>/dev/null; then
  rm -f "${SESSION_STARTED}" "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null
  if [ "$LOG_RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
    find "$VAULT" -maxdepth 1 -name '.tool-log-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.logged-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.reminded-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.session-started-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    find "$VAULT" -maxdepth 1 -name '.hook-errors.log' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  fi
  exit 0
fi

PROJECT_PAGE="${PROJECTS}/${PROJECT}.md"
CTX_FILE="$CONTEXT_FILE" PROJECT_PAGE="$PROJECT_PAGE" LANG="$LANG_CFG" \
PROJECT="$PROJECT" DATE="$DATE" HHMM="$HHMM" TOOL_COUNT="$TOOL_COUNT" \
SESSION_LINK="$SESSION_LINK_NAME" \
run_node "${LIB}/write-moc.js" || true

if [ "$CANVAS_ENABLED" = "true" ] && [ "$COMPACT_MODE" != "true" ]; then
  CANVAS_FILE="${PROJECTS}/${PROJECT}.canvas"
  CTX_FILE="$CONTEXT_FILE" CANVAS_FILE="$CANVAS_FILE" PROJECT="$PROJECT" \
  run_node "${LIB}/write-canvas.js" || true
fi

# ============================================================
# 4. Daily note
# ============================================================
if [ "$DAILY_NOTES" = "true" ]; then
  DAILY_DIR="${VAULT_ROOT}/daily"
  DAILY_FILE="${DAILY_DIR}/${DATE}.md"
  mkdir -p "$DAILY_DIR" || true

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
    if ! grep -qF "[[${PROJECT}]]" "$DAILY_FILE" 2>/dev/null; then
      DAILY_LINE=$(printf -- '- %s — [[%s]] — %s tool calls' "$HHMM" "$PROJECT" "$TOOL_COUNT")
      if grep -qE "^## (Сессии|Sessions|会话)" "$DAILY_FILE" 2>/dev/null; then
        DAILY_TMP="${DAILY_FILE}.tmp.$$"
        awk -v line="$DAILY_LINE" '/^## (Сессии|Sessions|会话)/{print; print line; next}{print}' "$DAILY_FILE" > "$DAILY_TMP" && mv "$DAILY_TMP" "$DAILY_FILE"
      else
        printf '\n%s\n' "$DAILY_LINE" >> "$DAILY_FILE"
      fi
    fi
  fi
fi

# ============================================================
# 5. Cleanup + rotation
# ============================================================
rm -f "${SESSION_STARTED}" 2>/dev/null
rm -f "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null

if [ "$LOG_RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
  find "$VAULT" -maxdepth 1 -name '.tool-log-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.logged-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.reminded-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.session-started-*' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$VAULT" -maxdepth 1 -name '.hook-errors.log' -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
fi

exit 0
