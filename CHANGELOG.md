# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.3] - 2026-04-09

### Fixed
- **CRITICAL**: `log-tools.sh` had a hardcoded personal vault path instead of `__VAULT_PATH__` placeholder — every installed copy wrote to the wrong location
- `recent_sessions` double-push: `unshift()` was called in both context-save and MOC-generation blocks, creating duplicate entries
- Daily note insertion: replaced `sed /a\` with `awk` for true cross-platform compatibility (macOS BSD sed + special chars in project names)
- Uninstall regex `[\s\S]*?(?=\n#+ )` stopped at `###` subsections — changed to `(?=\n## |\s*$)` to remove the full Obsidian section
- Release command `/release` step 5 referenced removed version strings — removed obsolete step

### Added
- Configuration section added to English and Chinese READMEs (was missing entirely)
- `project_roots` and `context_injection` fields added to config table in all READMEs
- Test assertion verifying vault path is actually written into `log-tools.sh`

### Changed
- Dataview query column header translated: `"Дата"` → `"Date"` (EN), `"日期"` (ZH)
- `CONTRIBUTING.md` updated with current project structure (skills/, .claude/commands/, multilingual files, VERSION, CHANGELOG)

## [2.0.2] - 2026-04-09

### Fixed
- Removed hardcoded version strings (v3) from hooks and instruction files — single source of truth is now `VERSION` file
- Daily note insertion: replaced `sed -i` with temp-file approach for macOS compatibility
- `previous_session` lookup: replaced slow `grep -rl` with instant read from `.context-{PROJECT}.json` cache

## [2.0.1] - 2026-04-09

### Fixed
- `previous_session` lookup now uses `grep` on frontmatter `project:` field instead of filename glob (prevents false matches like `app` matching `my-app-backend`)
- Daily note session insertion now uses `sed` to place entries after the section header, not blindly at end of file

### Changed
- README: added `canvas`, `daily_notes`, `stale_threshold_days` to configuration table

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

[Unreleased]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v2.0.3...HEAD
[2.0.3]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/paradoxcalm/claude-code-to-obsidian/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/paradoxcalm/claude-code-to-obsidian/releases/tag/v1.0.0
