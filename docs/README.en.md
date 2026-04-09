[🇷🇺 Русский](../README.md) | **English** | [🇨🇳 中文](README.zh.md)

# Claude Code → Obsidian Logger

Automatic session logging for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an [Obsidian](https://obsidian.md) vault.

Work with Claude Code in any project — session logs are automatically saved to Obsidian as markdown notes.

## What It Does

```
You work with Claude Code (any project)
    │
    ▼
PostToolUse hook → counts tool invocations
    │
    ▼ (5+ invocations = substantial session)
Stop hook → reminds Claude to write a detailed log
    │
    ▼
Claude writes a log → sessions/2024-03-15_14-30_my-project.md
    │
    ▼
SessionEnd hook → creates a draft if Claude didn't write one
    │
    ▼
Open Obsidian → see the history of all sessions
```

## What Gets Logged

- What was done (specific actions)
- Which files were changed
- Key decisions and reasoning
- TODOs for next time
- Tags for search (#project, #topic)

## Requirements

- [Node.js](https://nodejs.org) v18+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Obsidian](https://obsidian.md) (recommended but not required — logs are just .md files)
- Bash (Git Bash on Windows, built-in on macOS/Linux)

## Installation

```bash
git clone https://github.com/paradoxcalm/claude-code-to-obsidian.git
cd claude-obsidian-logger
bash install.sh
```

The installer will ask for your Obsidian vault path and handle everything automatically:

1. Creates the folder structure in the vault
2. Installs hook scripts
3. Configures `~/.claude/settings.json`
4. Adds instructions to `~/.claude/CLAUDE.md`

### Specifying the path directly

```bash
bash install.sh ~/Documents/MyVault
```

### Windows (Git Bash)

```bash
bash install.sh /c/Users/YourName/Documents/MyVault
```

## Vault Structure After Installation

```
MyVault/
├── CLAUDE.md           # Rules for working with the vault
├── .claude/
│   └── skills/
│       └── obsidian-logger/
│           └── SKILL.md    # Vault operation skills
├── sessions/           # ← Session logs (automatic)
│   ├── 2024-03-15_14-30_my-project.md
│   ├── 2024-03-15_16-00_other-project.md
│   └── README.md
├── daily/              # Daily notes
├── notes/              # Notes and ideas
├── projects/           # Projects
├── archive/            # Archive
├── templates/          # Templates (daily, meeting, project)
└── scripts/            # Hook scripts
    ├── log-session.sh
    ├── log-tools.sh
    └── session-reminder.sh
```

## How the Hooks Work

### 3 hooks in `~/.claude/settings.json`:

| Hook | Event | What it does |
|------|-------|-------------|
| `PostToolUse` | Every tool invocation | Appends a line to `.tool-log-DATE.txt` (counter) |
| `Stop` | Claude finished responding | If 5+ tool calls and no log written — injects a `[AUTOLOG]` reminder into the context |
| `SessionEnd` | Exiting the session | Creates a log draft if Claude didn't write a detailed one |

### Smart logic:
- **Short sessions** (< 5 tool calls) — no action, no spam
- **Long sessions** — Claude writes a detailed log on its own
- **Duplicate protection** — a marker file `.logged-SESSION_ID` prevents repeated reminders

## Session Log Example

```markdown
# Session: Added OAuth Authorization

**Date:** 2024-03-15 14:30
**Project:** my-app
**Directory:** /home/user/projects/my-app

## What Was Done
- Added OAuth2 flow via Google
- Created users table in the database
- Wrote tests for auth middleware

## Changed Files
- `src/auth/oauth.ts` — new authorization module
- `src/db/migrations/001_users.sql` — migration
- `src/middleware/auth.ts` — token verification middleware
- `tests/auth.test.ts` — tests

## Key Decisions
- Chose OAuth over JWT — client requirement
- Refresh token stored in httpOnly cookie

## TODO
- [ ] Add GitHub authorization
- [ ] Rate limiting on /auth endpoints

#session #my-app #auth #oauth
```

## Uninstallation

```bash
bash uninstall.sh
```

Removes hooks from `settings.json` and the section from `CLAUDE.md`. Your vault and notes are **not deleted**.

## Recommended Obsidian Plugins

- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — SQL-like queries across your notes
- **[Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)** — task management
- **[Templater](https://github.com/SilentVoid13/Templater)** — advanced templates

### Useful Dataview Queries for Sessions

All sessions from the last week:
````markdown
```dataview
TABLE file.cday as "Дата"
FROM "sessions"
WHERE file.cday >= date(today) - dur(7 days)
SORT file.cday DESC
```
````

All TODOs from sessions:
````markdown
```dataview
TASK FROM "sessions"
WHERE !completed
```
````

## FAQ

**Q: Does it work on macOS / Linux?**
A: Yes. The scripts are written in bash + node and work everywhere.

**Q: What if I don't use Obsidian?**
A: Logs are plain .md files. You can open them in any editor, VS Code, Notion (import), etc.

**Q: Do the hooks slow down Claude Code?**
A: No. The scripts execute in ~50ms (writing a line to a file).

**Q: Can I disable it temporarily?**
A: Remove or comment out the hooks in `~/.claude/settings.json`.

**Q: The logs are in Russian. How do I change the language?**
A: Edit `~/.claude/CLAUDE.md` — replace the language instruction with your preferred language.

## License

MIT
