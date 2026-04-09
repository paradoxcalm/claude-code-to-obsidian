# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-04-09

### Added
- Skills system: `skills/SKILL.{ru,en,zh}.md` with vault operation instructions (reading/writing logs, linking, updating context)
- Extended YAML frontmatter: `tags`, `files_changed`, `status`, `previous_session` fields
- Previous session tracking in AUTOLOG reminder and SessionEnd stub
- Skills deployment in `install.sh` to `.claude/skills/obsidian-logger/SKILL.md`
- Test 9: v3 frontmatter field validation
- Skill file installation assertions in language-specific tests (EN, ZH)
- `VERSION` file for semver tracking
- `/release` slash command for automated changelog and GitHub releases
- `CHANGELOG.md` in Keep a Changelog format

### Changed
- `global-claude.{ru,en,zh}.md`: expanded frontmatter template and rules section with skills reference
- `hooks/log-session.sh`: stub logs now include tags, files_changed, status, previous_session
- `hooks/session-reminder.sh`: AUTOLOG reminder includes previous session link
- Vault structure in all READMEs now shows `.claude/skills/` directory

## [1.0.0] - 2026-04-08

### Added
- Three-hook system: PostToolUse (counter), Stop (context injection + AUTOLOG), SessionEnd (stub + context + MOC + daily)
- Automatic project detection via config mapping, git, parent dir search
- Context injection from `.context-{PROJECT}.json` on session start
- Project page (MOC) generation with session history, open TODOs, tech stack
- Canvas visualization (optional)
- Daily note integration with session links
- Multi-language support: Russian, English, Chinese
- Configuration via `.obsidian-logger.json` (min_tool_calls, log_retention, language, canvas, daily_notes)
- Compact mode for short sessions (< min_tool_calls)
- Idempotent install/uninstall with BOM handling
- Test suite with 8 test cases
- Cross-platform support: Windows (Git Bash), macOS, Linux
- sed-based JSON parsing on hot paths for sub-50ms execution

[Unreleased]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/paradoxcalm/claude-code-to-obsidian/releases/tag/v1.0.0
