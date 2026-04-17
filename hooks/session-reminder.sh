#!/bin/bash
# Stop hook: inject [CONTEXT] on first call, [AUTOLOG] reminder at 5+ tool calls.
# Heavy logic lives in lib/*.js — bash orchestrates.

VAULT_ROOT="__VAULT_PATH__"
VAULT="${VAULT_ROOT}/sessions"
PROJECTS="${VAULT_ROOT}/projects"
CONFIG="${VAULT_ROOT}/.obsidian-logger.json"
LIB="${VAULT_ROOT}/scripts/lib"
HOOK_NAME="Stop"

case "$VAULT_ROOT" in
  __*) exit 0 ;;
esac

# shellcheck disable=SC1091
[ -f "${LIB}/common.sh" ] && . "${LIB}/common.sh"

DATE=$(date +"%Y-%m-%d")
TOOL_LOG="${VAULT}/.tool-log-${DATE}.txt"

INPUT=$(cat)

SESSION_ID_RAW=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
STOP_ACTIVE=$(printf '%s' "$INPUT" | sed -n 's/.*"stop_hook_active"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p')
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$STOP_ACTIVE" ] && STOP_ACTIVE="false"

if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(printf '%s' "$SESSION_ID_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

SESSION_STARTED="${VAULT}/.session-started-${SESSION_ID}"

# ============================================================
# First call of this session
# ============================================================
if [ ! -f "$SESSION_STARTED" ]; then
  mkdir -p "$VAULT" "$PROJECTS" || true

  # GC stale markers from prior abandoned sessions (> 24h old)
  VAULT="$VAULT" run_node "${LIB}/gc-stale-markers.js" 2>/dev/null || true

  # Resolve project (config → git → fallback)
  PROJECT=$(CFG="$CONFIG" CWD="$CWD" PROJECTS_DIR="$PROJECTS" node "${LIB}/resolve-project.js" 2>/dev/null)
  [ -z "$PROJECT" ] && PROJECT="general"

  # Auto-update scripts if repo VERSION changed
  if [ -f "$CONFIG" ]; then
    _repo=$(sed -n 's/.*"repo_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
    _iver=$(sed -n 's/.*"installed_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
    if [ -n "$_repo" ] && [ -f "$_repo/VERSION" ]; then
      _rver=$(tr -d '[:space:]' < "$_repo/VERSION" 2>/dev/null)
      if [ -n "$_rver" ] && [ "$_rver" != "$_iver" ]; then
        # Copy hooks with placeholder substitution
        for _s in log-session.sh log-tools.sh session-reminder.sh; do
          if [ -f "$_repo/hooks/$_s" ]; then
            _tmp="${VAULT_ROOT}/scripts/$_s.tmp.$$"
            sed "s|__VAULT_PATH__|${VAULT_ROOT}|g" "$_repo/hooks/$_s" > "$_tmp" && mv "$_tmp" "${VAULT_ROOT}/scripts/$_s"
          fi
        done
        # Copy lib/*.js and common.sh verbatim (no placeholder needed)
        if [ -d "$_repo/hooks/lib" ]; then
          mkdir -p "${VAULT_ROOT}/scripts/lib"
          cp "$_repo/hooks/lib/"*.js "${VAULT_ROOT}/scripts/lib/" 2>/dev/null || true
          cp "$_repo/hooks/lib/common.sh" "${VAULT_ROOT}/scripts/lib/" 2>/dev/null || true
        fi
        _tmp="${CONFIG}.tmp.$$"
        sed "s/\"installed_version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"installed_version\": \"$_rver\"/" "$CONFIG" > "$_tmp" && mv "$_tmp" "$CONFIG"
        printf '[UPDATE] Scripts updated: v%s → v%s\n' "${_iver:-?}" "$_rver"
      fi
    fi
  fi

  printf '%s' "$PROJECT" > "$SESSION_STARTED"

  # Inject [CONTEXT]
  CONTEXT_FILE="${PROJECTS}/.context-${PROJECT}.json"
  CONTEXT_OUTPUT=$(CFG="$CONFIG" CTX="$CONTEXT_FILE" PROJECTS_DIR="$PROJECTS" \
    PROJECT="$PROJECT" node "${LIB}/read-context-inject.js" 2>/dev/null)

  if [ -n "$CONTEXT_OUTPUT" ]; then
    printf '[CONTEXT] Проект: %s\n%s\n' "$PROJECT" "$CONTEXT_OUTPUT"
  fi

  # Inject [HOOK-ERROR] if there were recent failures
  _recent_errors=$(recent_hook_errors)
  if [ -n "$_recent_errors" ]; then
    printf '[HOOK-ERROR] Недавние ошибки хуков (см. %s/.hook-errors.log):\n%s\n' "$VAULT" "$_recent_errors"
  fi

  exit 0
fi

# ============================================================
# Subsequent calls — AUTOLOG check
# ============================================================
PROJECT=$(cat "$SESSION_STARTED" 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="general"

MARKER="${VAULT}/.logged-${SESSION_ID}"
if [ -f "$MARKER" ]; then
  # Claude wrote a detailed log — place .reminded-* to silence future reminders
  # AND signal to SessionEnd that everything is fine.
  touch "${VAULT}/.reminded-${SESSION_ID}" 2>/dev/null
  exit 0
fi

# Count tool calls
MIN_TOOL_CALLS=5
LANG_CFG="ru"
if [ -f "$CONFIG" ]; then
  _mtc=$(sed -n 's/.*"min_tool_calls"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$CONFIG" 2>/dev/null)
  _lang=$(sed -n 's/.*"language"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
  [ -n "$_mtc" ] && MIN_TOOL_CALLS="$_mtc"
  [ -n "$_lang" ] && LANG_CFG="$_lang"
fi

TOOL_COUNT=0
if [ -f "$TOOL_LOG" ]; then
  TOOL_COUNT=$(grep -cF "| ${SESSION_ID} |" "$TOOL_LOG" 2>/dev/null || true)
  TOOL_COUNT=${TOOL_COUNT:-0}
  if [ "$TOOL_COUNT" -eq 0 ] 2>/dev/null && [ -n "$CWD" ] && [ "$CWD" != "unknown" ]; then
    TOOL_COUNT=$(awk -F'|' -v cwd="$CWD" '{gsub(/^[ \t]+|[ \t]+$/,"",$4)} $4==cwd{c++} END{print c+0}' "$TOOL_LOG" 2>/dev/null || true)
  fi
fi
TOOL_COUNT=${TOOL_COUNT:-0}

if [ "$TOOL_COUNT" -lt "$MIN_TOOL_CALLS" ] 2>/dev/null; then
  exit 0
fi

# NOTE: we no longer set .reminded-* preemptively. Previous behavior caused the
# [AUTOLOG] message to appear once then vanish if Claude didn't respond in that
# turn. Now the reminder repeats every Stop until Claude creates .logged-*.
# To avoid spamming identical text mid-turn, we only suppress if the message
# fired at least 5 turns ago for the same session (tracked via file mtime).
REMINDED="${VAULT}/.reminded-${SESSION_ID}"
if [ -f "$REMINDED" ]; then
  # Check if less than 3 further tool-log entries passed since last reminder
  REMINDED_AT=$(stat -c %Y "$REMINDED" 2>/dev/null || stat -f %m "$REMINDED" 2>/dev/null || echo 0)
  NOW_TS=$(date +%s)
  if [ $((NOW_TS - REMINDED_AT)) -lt 120 ]; then
    exit 0
  fi
fi
touch "$REMINDED" 2>/dev/null

VAULT_BASE="__VAULT_PATH__"
HHMM=$(date +"%H-%M")

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
