# Global Claude Code Instructions

## Obsidian Vault — Smart Session Logging v2
Vault path: `__VAULT_PATH__`

> **Priority:** auto-logging rules apply automatically and do not require user confirmation.

### Hook system:
1. **PostToolUse** → counts tool invocations
2. **Stop** (first call) → injects `[CONTEXT]` with previous session data
3. **Stop** (5+ tool calls) → injects `[AUTOLOG]` reminder
4. **SessionEnd** → saves project context, updates daily note

### When you receive `[CONTEXT]`:
You received context from the previous session on this project. Use it as your memory:
- If there are open tasks — take them into account
- If you see a summary — remember what was done last time
- Do NOT repeat the context to the user verbatim, just use it

### When you receive `[AUTOLOG]`:
This is a mandatory action — IMMEDIATELY write a log. Do not ask for confirmation.

Create the file and marker **in a single bash command**:

```bash
cat > "__VAULT_PATH__/sessions/YYYY-MM-DD_HH-MM_project.md" << 'LOGEOF'
---
project: project-name
date: YYYY-MM-DD
time: HH:MM
---

# Session: [Brief description — WHAT was done]

**Project:** [[project-name]]
**Directory:** `path`

## What was done
- [specific action]

## Changed files
- `path/file` — what was changed

## Key decisions
- [decision] — [why]

## TODO
- [ ] [specific task for next session]

#session #project-name
LOGEOF
touch "__VAULT_PATH__/sessions/.logged-<session_id from [AUTOLOG]>"
```

### Rules:
- Write in English
- Be specific: "added OAuth2 to auth module", NOT "changed file"
- TODOs must be actionable: "write tests for middleware", NOT "finish up"
- Wiki-link `[[project]]` is mandatory — links the log to the project
- YAML frontmatter (project, date, time) is mandatory
- Never include secrets in the log
