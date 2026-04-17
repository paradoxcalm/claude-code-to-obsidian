# Shared bash helpers for hooks. Sourced, not executed.
# Expects: VAULT_ROOT, VAULT (sessions dir)

HOOK_ERR_LOG="${VAULT}/.hook-errors.log"

# Run a node script; on non-zero exit, log stderr excerpt to .hook-errors.log.
# Usage: run_node /path/to/script.js [env=val prefix done by caller]
# Returns the node exit code.
run_node() {
  local script="$1"
  local hook_name="${HOOK_NAME:-unknown}"
  local err_tmp
  err_tmp="${VAULT}/.hook-err.$$.$RANDOM"

  node "$script" 2>"$err_tmp"
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    local msg
    msg=$(head -c 800 "$err_tmp" 2>/dev/null | tr '\n\r' '  ' | tr -s ' ')
    [ -z "$msg" ] && msg="(no stderr, exit=$rc)"
    printf '%s | %s | %s | %s\n' \
      "$(date +'%Y-%m-%d %H:%M:%S')" \
      "$hook_name" \
      "$(basename "$script")" \
      "$msg" >> "$HOOK_ERR_LOG" 2>/dev/null || true
  elif [ -s "$err_tmp" ]; then
    # Non-error stderr (warnings / info) — still record, but prefixed INFO
    local msg
    msg=$(head -c 800 "$err_tmp" 2>/dev/null | tr '\n\r' '  ' | tr -s ' ')
    printf '%s | %s | %s | INFO: %s\n' \
      "$(date +'%Y-%m-%d %H:%M:%S')" \
      "$hook_name" \
      "$(basename "$script")" \
      "$msg" >> "$HOOK_ERR_LOG" 2>/dev/null || true
  fi

  rm -f "$err_tmp" 2>/dev/null
  return $rc
}

# Returns fresh errors (last 24h) from .hook-errors.log as compact lines, or empty.
# Output: up to 3 most recent lines.
recent_hook_errors() {
  [ ! -f "$HOOK_ERR_LOG" ] && return 0
  local cutoff
  cutoff=$(date -d '24 hours ago' +'%Y-%m-%d %H:%M:%S' 2>/dev/null) || \
  cutoff=$(date -v-1d +'%Y-%m-%d %H:%M:%S' 2>/dev/null) || \
  cutoff=""
  if [ -n "$cutoff" ]; then
    awk -F' \\| ' -v c="$cutoff" '$1 >= c && $4 !~ /^INFO:/' "$HOOK_ERR_LOG" 2>/dev/null | tail -3
  else
    # No date-arithmetic available — fall back to last 3 lines regardless of age
    grep -v ' | INFO:' "$HOOK_ERR_LOG" 2>/dev/null | tail -3
  fi
}
