#!/bin/bash
# PostToolUse hook: логирует каждый вызов инструмента
# ГОРЯЧИЙ ПУТЬ — запускается на КАЖДЫЙ tool call, должен быть < 50ms
# Парсинг через sed (без node!) для максимальной скорости

VAULT="/c/Users/ParadoxCalm/Documents/Obsidian Vault/sessions"

# Guard
case "$VAULT" in
  __*) exit 0 ;;
esac

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M:%S")
LOGFILE="${VAULT}/.tool-log-${DATE}.txt"

INPUT=$(cat)

# Парсим JSON через sed — НЕ запускаем node (экономим ~400ms на Windows)
TOOL=$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
SESSION_RAW=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Санитизация SESSION_ID
SESSION=$(printf '%s' "$SESSION_RAW" | LC_ALL=C tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION" ] && SESSION="?"
[ -z "$TOOL" ] && TOOL="?"

mkdir -p "$VAULT"
printf '%s\n' "${TIME} | ${SESSION} | ${TOOL} | ${CWD}" >> "$LOGFILE"

exit 0
