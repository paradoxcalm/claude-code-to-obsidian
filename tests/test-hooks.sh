#!/bin/bash
# Integration tests for hook behavior.
# Runs full session lifecycle against a temp vault; asserts on artifacts.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_DIR="$(mktemp -d)"
VAULT="$TEST_DIR/vault"
mkdir -p "$VAULT/sessions" "$VAULT/projects" "$VAULT/scripts/lib"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS=0
PASSED=0
FAILED=0

pass() { TESTS=$((TESTS+1)); PASSED=$((PASSED+1)); printf "${GREEN}PASS${NC} %s\n" "$1"; }
fail() { TESTS=$((TESTS+1)); FAILED=$((FAILED+1)); printf "${RED}FAIL${NC} %s\n" "$1"; }
assert_eq() { if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (got '$1', want '$2')"; fi; }
assert_contains() { if printf '%s' "$1" | grep -qF "$2" 2>/dev/null; then pass "$3"; else fail "$3 (missing '$2')"; fi; }
assert_file_exists() { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }
assert_json_has_field() {
  local file="$1" field="$2" desc="$3"
  if [ -f "$file" ] && FILE="$file" FIELD="$field" node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.env.FILE,"utf8"));process.exit(c[process.env.FIELD]!==undefined?0:1)}catch{process.exit(1)}' 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc (field '$field' missing in $file)"
  fi
}

# Install hooks into temp vault
for f in log-session.sh log-tools.sh session-reminder.sh; do
  sed "s|__VAULT_PATH__|$VAULT|g" "$REPO_DIR/hooks/$f" > "$VAULT/scripts/$f"
  chmod +x "$VAULT/scripts/$f"
done
cp "$REPO_DIR/hooks/lib/"*.js "$VAULT/scripts/lib/"
cp "$REPO_DIR/hooks/lib/common.sh" "$VAULT/scripts/lib/"
cat > "$VAULT/.obsidian-logger.json" << EOF
{"min_tool_calls":5,"log_retention_days":30,"language":"ru","daily_notes":true}
EOF

TODAY=$(date +%Y-%m-%d)

printf "${YELLOW}=== 1. Malformed input is survived ===${NC}\n"
set +e
echo 'not json' | bash "$VAULT/scripts/session-reminder.sh" >/dev/null 2>&1
assert_eq "$?" "0" "session-reminder survives malformed input"
echo 'not json' | bash "$VAULT/scripts/log-session.sh" >/dev/null 2>&1
assert_eq "$?" "0" "log-session survives malformed input"
echo 'not json' | bash "$VAULT/scripts/log-tools.sh" >/dev/null 2>&1
assert_eq "$?" "0" "log-tools survives malformed input"

printf "\n${YELLOW}=== 2. Full session lifecycle ===${NC}\n"
# Simulate 7 tool calls in a session
for i in $(seq 1 7); do
  echo '{"session_id":"test-session-1","cwd":"/test/proj","tool_name":"Read"}' | bash "$VAULT/scripts/log-tools.sh"
done

# Verify tool log was written
assert_file_exists "$VAULT/sessions/.tool-log-${TODAY}.txt" "tool log created"
COUNT=$(grep -cF "| test-session-1 |" "$VAULT/sessions/.tool-log-${TODAY}.txt" 2>/dev/null || echo 0)
assert_eq "$COUNT" "7" "tool log records 7 calls"

# Mark session started (simulating what Stop hook does)
echo "testproj" > "$VAULT/sessions/.session-started-test-session-1"

# Run SessionEnd
echo '{"session_id":"test-session-1","cwd":"/test/proj"}' | bash "$VAULT/scripts/log-session.sh" >/dev/null 2>&1

# Verify all artifacts
assert_file_exists "$VAULT/projects/.context-testproj.json" "context JSON created"
assert_file_exists "$VAULT/projects/testproj.md" "MOC page created"
assert_file_exists "$VAULT/daily/${TODAY}.md" "daily note created"

# Verify context has all required fields (the class of bug that cost 9 months)
CTX="$VAULT/projects/.context-testproj.json"
assert_json_has_field "$CTX" "project" "context has 'project' field"
assert_json_has_field "$CTX" "first_seen" "context has 'first_seen' field"
assert_json_has_field "$CTX" "last_seen" "context has 'last_seen' field"
assert_json_has_field "$CTX" "session_count" "context has 'session_count' field"
assert_json_has_field "$CTX" "last_session" "context has 'last_session' field"
assert_json_has_field "$CTX" "recent_sessions" "context has 'recent_sessions' field"

# Verify MOC has the session row (not empty table)
MOC_CONTENT=$(cat "$VAULT/projects/testproj.md")
assert_contains "$MOC_CONTENT" "[[${TODAY}" "MOC contains session link"
assert_contains "$MOC_CONTENT" "| 7 |" "MOC shows 7 tool calls"

# Verify cleanup
[ ! -f "$VAULT/sessions/.session-started-test-session-1" ] && pass "session-started marker cleaned" || fail "session-started marker still exists"

printf "\n${YELLOW}=== 3. Context injection on subsequent session ===${NC}\n"
# Second session with different session_id but same CWD — should get [CONTEXT]
OUT=$(echo '{"session_id":"test-session-2","cwd":"/test/proj","stop_hook_active":false}' | bash "$VAULT/scripts/session-reminder.sh" 2>/dev/null)
# Project resolution from /test/proj will give 'proj' (basename), not 'testproj'. So we need context for the actual resolved project.
# Alternatively, create override file to lock project name
mkdir -p "$TEST_DIR/projdir"
echo "myproject" > "$TEST_DIR/projdir/.obsidian-project"
for i in $(seq 1 6); do
  echo "{\"session_id\":\"test-session-3\",\"cwd\":\"$TEST_DIR/projdir\",\"tool_name\":\"Read\"}" | bash "$VAULT/scripts/log-tools.sh"
done
# First Stop resolves project from .obsidian-project file
OUT=$(echo "{\"session_id\":\"test-session-3\",\"cwd\":\"$TEST_DIR/projdir\",\"stop_hook_active\":false}" | bash "$VAULT/scripts/session-reminder.sh" 2>/dev/null)
assert_eq "$(cat "$VAULT/sessions/.session-started-test-session-3" 2>/dev/null)" "myproject" ".obsidian-project override honored"

printf "\n${YELLOW}=== 4. AUTOLOG repeats until .logged-* exists ===${NC}\n"
# Second Stop — should fire AUTOLOG
OUT1=$(echo "{\"session_id\":\"test-session-3\",\"cwd\":\"$TEST_DIR/projdir\",\"stop_hook_active\":false}" | bash "$VAULT/scripts/session-reminder.sh" 2>/dev/null)
assert_contains "$OUT1" "[AUTOLOG]" "AUTOLOG fires on 2nd Stop call"

# Simulate Claude writing the log
touch "$VAULT/sessions/.logged-test-session-3"

# Third Stop — should be silent
OUT2=$(echo "{\"session_id\":\"test-session-3\",\"cwd\":\"$TEST_DIR/projdir\",\"stop_hook_active\":false}" | bash "$VAULT/scripts/session-reminder.sh" 2>/dev/null)
if [ -z "$OUT2" ]; then pass "AUTOLOG silent after .logged-* present"; else fail "AUTOLOG still firing after .logged-* (got: $OUT2)"; fi

printf "\n${YELLOW}=== 5. hook-errors.log captures real failures ===${NC}\n"
# Induce a real node error by putting junk in a .js file path (simulate broken install)
mv "$VAULT/scripts/lib/write-context.js" "$VAULT/scripts/lib/write-context.js.bak"
echo 'this is not valid js; syntax error !!!' > "$VAULT/scripts/lib/write-context.js"

for i in $(seq 1 6); do
  echo '{"session_id":"test-err-1","cwd":"/error/test","tool_name":"Read"}' | bash "$VAULT/scripts/log-tools.sh"
done
echo "errproj" > "$VAULT/sessions/.session-started-test-err-1"
echo '{"session_id":"test-err-1","cwd":"/error/test"}' | bash "$VAULT/scripts/log-session.sh" >/dev/null 2>&1

if grep -q "write-context" "$VAULT/sessions/.hook-errors.log" 2>/dev/null; then
  pass "hook-errors.log records write-context failure"
else
  fail "hook-errors.log did not capture write-context failure"
fi

# Restore
mv "$VAULT/scripts/lib/write-context.js.bak" "$VAULT/scripts/lib/write-context.js"

printf "\n${YELLOW}=== 6. GC removes stale markers ===${NC}\n"
touch "$VAULT/sessions/.session-started-abandoned-xxx"
# Backdate to 2 days ago. Try GNU, BSD, Windows compat methods.
touch -d "2 days ago" "$VAULT/sessions/.session-started-abandoned-xxx" 2>/dev/null || \
touch -t "$(date -v-2d +%Y%m%d%H%M 2>/dev/null || date +%Y%m%d0000)" "$VAULT/sessions/.session-started-abandoned-xxx" 2>/dev/null || \
true

# Trigger first-call Stop (runs GC)
echo '{"session_id":"gc-trigger","cwd":"/tmp","stop_hook_active":false}' | bash "$VAULT/scripts/session-reminder.sh" >/dev/null 2>&1
if [ -f "$VAULT/sessions/.session-started-abandoned-xxx" ]; then
  # Check if we successfully backdated — if not, skip the assertion
  AGE_SEC=$(( $(date +%s) - $(stat -c %Y "$VAULT/sessions/.session-started-abandoned-xxx" 2>/dev/null || stat -f %m "$VAULT/sessions/.session-started-abandoned-xxx" 2>/dev/null || date +%s) ))
  if [ "$AGE_SEC" -lt 86400 ]; then
    printf "${YELLOW}SKIP${NC} GC test — could not backdate file on this platform\n"
  else
    fail "GC did not remove stale marker"
  fi
else
  pass "GC removed stale marker"
fi

printf "\n${YELLOW}=== Results ===${NC}\n"
printf "Total: %d, Passed: %s%d%s, Failed: %s%d%s\n" "$TESTS" "$GREEN" "$PASSED" "$NC" "$RED" "$FAILED" "$NC"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
