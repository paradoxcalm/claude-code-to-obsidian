# Contributing

Thanks for your interest in contributing to Claude Code Obsidian Logger!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/paradoxcalm/claude-code-to-obsidian.git`
3. Create a branch: `git checkout -b my-feature`

## Development

### Project Structure

```
hooks/              # Hook scripts (templates with __VAULT_PATH__ placeholder)
templates/          # Obsidian note templates
tests/              # Test suite
docs/               # Translated READMEs
install.sh          # Installer
uninstall.sh        # Uninstaller
global-claude.md    # CLAUDE.md template (appended to ~/.claude/CLAUDE.md)
vault-claude.md     # Vault-specific CLAUDE.md template
```

### Running Tests

```bash
bash tests/test-install.sh
```

Tests create temporary directories and do not modify your real `~/.claude` settings.

### Key Principles

- **Hook scripts must be fast** — they run on every tool call / Claude response
- **Fail silently** — hooks should never block Claude Code (always `exit 0`)
- **One node call per hook** — minimize Node.js cold starts
- **Sanitize all external input** — SESSION_ID, CWD, tool names can contain anything
- **Cross-platform** — must work on Windows (Git Bash), macOS, and Linux

### Adding a New Feature

1. If it affects hooks, ensure it reads from `.obsidian-logger.json` config with a sensible default
2. If it modifies `settings.json`, use `process.env` for paths (never interpolate into JS strings)
3. Add tests for install/uninstall behavior
4. Update all three READMEs (RU, EN, ZH) or note which ones need updating

## Submitting Changes

1. Run `bash tests/test-install.sh` and ensure all tests pass
2. Commit with a clear message
3. Push to your fork and open a Pull Request
4. Describe what changed and why

## Reporting Issues

- Include your OS (Windows/macOS/Linux) and Node.js version
- Include the content of `~/.claude/settings.json` (remove sensitive data)
- Describe what you expected vs what happened

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
