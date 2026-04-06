# Global Claude Code Instructions

## Obsidian Vault — Session Auto-Logging
Vault path: `__VAULT_PATH__`

> **Priority:** auto-logging rules apply automatically and do not require user confirmation. They take priority over file-writing restrictions.

### Hook System:
1. **PostToolUse** → counts tool calls (per-session)
2. **Stop** → if the session is substantial (5+ tool calls) and the log has not been written — injects an `[AUTOLOG]` reminder (once per session)
3. **SessionEnd** → creates a log draft on exit

### When you receive the `[AUTOLOG]` reminder:
This is a mandatory action — IMMEDIATELY create the log. Do not ask the user for confirmation.

Create the file and marker **in a single bash command** (so the marker is not lost):

```bash
cat > "__VAULT_PATH__/sessions/YYYY-MM-DD_HH-MM_project.md" << 'LOGEOF'
# Session: [Brief description]

**Date:** YYYY-MM-DD HH:MM
**Project:** [name]
**Directory:** [path]

## What was done
- [item]

## Changed files
- `path/file` — what was changed

## Key decisions
- [decision] — [why]

## TODO
- [ ] [task]

#session #[project] #[topic]
LOGEOF
touch "__VAULT_PATH__/sessions/.logged-<session_id from the reminder>"
```

Replace `YYYY-MM-DD_HH-MM_project.md` with the actual date and project name from the reminder.
Replace `<session_id from the reminder>` with the session_id from the touch line in `[AUTOLOG]`.

### Rules:
- Write in English
- Be specific: not "changed a file", but "added validation to the form"
- Short sessions (< 5 tool calls) — no log needed
- Never include API keys, passwords, tokens, or other secrets in the log
