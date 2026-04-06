#!/bin/bash
# ============================================================
#  Tests for install.sh and uninstall.sh
#  Run: bash tests/test-install.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_file_exists() {
  TOTAL=$((TOTAL + 1))
  if [ -f "$1" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $2"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $2 (not found: $1)"
  fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  if grep -q "$2" "$1" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $3"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $3"
  fi
}

assert_not_contains() {
  TOTAL=$((TOTAL + 1))
  if ! grep -q "$2" "$1" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $3"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $3"
  fi
}

assert_count() {
  TOTAL=$((TOTAL + 1))
  local count
  count=$(grep -c "$2" "$1" 2>/dev/null || echo 0)
  if [ "$count" -eq "$3" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $4 (count=$count)"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $4 (expected=$3, got=$count)"
  fi
}

# Setup
TMP_DIR=$(mktemp -d)
TMP_VAULT="${TMP_DIR}/test-vault"
TMP_CLAUDE="${TMP_DIR}/fake-claude-home"
ORIG_HOME="$HOME"

cleanup() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
  export HOME="$ORIG_HOME"
}
trap cleanup EXIT

export HOME="$TMP_CLAUDE"
mkdir -p "$TMP_CLAUDE"

echo ""
echo -e "${YELLOW}=== Claude Obsidian Logger — Tests ===${NC}"
echo ""

# ============================================================
# Test 1: Basic install (Russian, default)
# ============================================================
echo -e "${YELLOW}[1] Basic install (language=ru)${NC}"

# Input: "1" for Russian language, then vault path is passed as $1
echo "1" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_file_exists "$TMP_VAULT/sessions/README.md" "sessions/README.md created"
assert_file_exists "$TMP_VAULT/scripts/log-tools.sh" "scripts/log-tools.sh created"
assert_file_exists "$TMP_VAULT/scripts/session-reminder.sh" "scripts/session-reminder.sh created"
assert_file_exists "$TMP_VAULT/scripts/log-session.sh" "scripts/log-session.sh created"
assert_file_exists "$TMP_VAULT/CLAUDE.md" "vault CLAUDE.md created"
assert_file_exists "$TMP_VAULT/.obsidian-logger.json" "config created"
assert_file_exists "$TMP_CLAUDE/.claude/settings.json" "settings.json created"
assert_file_exists "$TMP_CLAUDE/.claude/CLAUDE.md" "global CLAUDE.md created"

assert_not_contains "$TMP_VAULT/scripts/log-tools.sh" "__VAULT_PATH__" "placeholder replaced in log-tools.sh"
assert_not_contains "$TMP_VAULT/scripts/session-reminder.sh" "__VAULT_PATH__" "placeholder replaced in session-reminder.sh"
assert_not_contains "$TMP_VAULT/scripts/log-session.sh" "__VAULT_PATH__" "placeholder replaced in log-session.sh"

assert_contains "$TMP_CLAUDE/.claude/settings.json" "session-reminder.sh" "Stop hook added"
assert_contains "$TMP_CLAUDE/.claude/settings.json" "log-session.sh" "SessionEnd hook added"
assert_contains "$TMP_CLAUDE/.claude/settings.json" "log-tools.sh" "PostToolUse hook added"

assert_contains "$TMP_VAULT/.obsidian-logger.json" '"language": "ru"' "language=ru in config"

echo ""

# ============================================================
# Test 2: Idempotency — install twice
# ============================================================
echo -e "${YELLOW}[2] Idempotency (install twice)${NC}"

echo "1" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_count "$TMP_CLAUDE/.claude/settings.json" "session-reminder.sh" 1 "No duplicate Stop hook"
assert_count "$TMP_CLAUDE/.claude/settings.json" "log-session.sh" 1 "No duplicate SessionEnd hook"

echo ""

# ============================================================
# Test 3: Preserves existing hooks
# ============================================================
echo -e "${YELLOW}[3] Preserves existing hooks${NC}"

cat > "$TMP_CLAUDE/.claude/settings.json" << 'TESTJSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /my/custom-hook.sh"
          }
        ]
      }
    ]
  }
}
TESTJSON

echo "1" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_contains "$TMP_CLAUDE/.claude/settings.json" "custom-hook.sh" "Custom hook preserved"
assert_contains "$TMP_CLAUDE/.claude/settings.json" "session-reminder.sh" "Our hook also added"

echo ""

# ============================================================
# Test 4: BOM in settings.json
# ============================================================
echo -e "${YELLOW}[4] BOM in settings.json${NC}"

printf '\xEF\xBB\xBF{"customSetting": true}' > "$TMP_CLAUDE/.claude/settings.json"

echo "1" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_contains "$TMP_CLAUDE/.claude/settings.json" "customSetting" "BOM did not destroy settings"
assert_contains "$TMP_CLAUDE/.claude/settings.json" "session-reminder.sh" "Hooks added despite BOM"

echo ""

# ============================================================
# Test 5: Uninstall
# ============================================================
echo -e "${YELLOW}[5] Uninstall${NC}"

bash "$SCRIPT_DIR/uninstall.sh"

assert_not_contains "$TMP_CLAUDE/.claude/settings.json" "session-reminder.sh" "Stop hook removed"
assert_not_contains "$TMP_CLAUDE/.claude/settings.json" "log-session.sh" "SessionEnd hook removed"
assert_not_contains "$TMP_CLAUDE/.claude/settings.json" "log-tools.sh" "PostToolUse hook removed"
assert_file_exists "$TMP_VAULT/sessions/README.md" "Vault NOT deleted"

echo ""

# ============================================================
# Test 6: Uninstall idempotency
# ============================================================
echo -e "${YELLOW}[6] Uninstall idempotency${NC}"

bash "$SCRIPT_DIR/uninstall.sh"
TOTAL=$((TOTAL + 1))
PASS=$((PASS + 1))
echo -e "  ${GREEN}✓${NC} Double uninstall does not crash"

echo ""

# ============================================================
# Test 7: English install
# ============================================================
echo -e "${YELLOW}[7] English install${NC}"

# Clean state
rm -rf "$TMP_VAULT" "$TMP_CLAUDE/.claude"
mkdir -p "$TMP_CLAUDE"

echo "2" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_contains "$TMP_VAULT/.obsidian-logger.json" '"language": "en"' "language=en in config"
assert_file_exists "$TMP_VAULT/CLAUDE.md" "vault CLAUDE.md created (EN)"
assert_file_exists "$TMP_CLAUDE/.claude/CLAUDE.md" "global CLAUDE.md created (EN)"

echo ""

# ============================================================
# Test 8: Chinese install
# ============================================================
echo -e "${YELLOW}[8] Chinese install${NC}"

rm -rf "$TMP_VAULT" "$TMP_CLAUDE/.claude"
mkdir -p "$TMP_CLAUDE"

echo "3" | bash "$SCRIPT_DIR/install.sh" "$TMP_VAULT"

assert_contains "$TMP_VAULT/.obsidian-logger.json" '"language": "zh"' "language=zh in config"
assert_file_exists "$TMP_VAULT/CLAUDE.md" "vault CLAUDE.md created (ZH)"
assert_file_exists "$TMP_CLAUDE/.claude/CLAUDE.md" "global CLAUDE.md created (ZH)"

echo ""

# ============================================================
# Results
# ============================================================
echo -e "${YELLOW}=== Results ===${NC}"
echo -e "  Total: $TOTAL"
echo -e "  ${GREEN}Passed: $PASS${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "  ${RED}Failed: $FAIL${NC}"
  exit 1
else
  echo -e "  ${GREEN}All tests passed!${NC}"
fi
echo ""
