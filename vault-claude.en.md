# Vault Rules

## General Rules
- All notes in English
- Date format: YYYY-MM-DD
- Tasks: `- [ ] text`
- Use [[wiki-links]] for connections
- Tags: #task, #idea, #meeting, #session

## Folder Structure
```
/notes      — notes, ideas
/projects   — projects
/daily      — daily journals
/sessions   — Claude Code session auto-logs
/archive    — archive
/templates  — templates
```

## Dataview Queries
- All sessions: `TABLE FROM "sessions" SORT file.name DESC`
- Open tasks: `TASK WHERE !completed`
- Past week: `TABLE FROM "daily" WHERE file.cday >= date(today) - dur(7 days)`
