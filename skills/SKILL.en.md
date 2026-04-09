# Claude Code → Obsidian: Vault Operation Skills

## Reading logs
- On entering a project, determine the name from the basename of the current directory
- Find files in `__VAULT_PATH__/sessions/` that contain this project name in frontmatter `project:`
- Read the last 3 by date
- Extract: open TODOs, "Where I stopped" section, key decisions
- Show the user in 3 lines: "Last session: {date}. Stopped at: {phrase}. Open TODOs: {count}"

## Writing logs
- Always use YAML frontmatter: project, date, time, tags, files_changed, status, previous_session
- status: "in-progress" if there are open TODOs, "completed" if all are closed
- tags in frontmatter = array: [auth, database, bugfix] etc.
- First TODO is always marked as "Next action"
- Max 5 TODOs (1 main + 4 backlog)
- files_changed — integer count of files modified during the session
- previous_session — link to the previous log for this project (from [CONTEXT] if available)

## Linking
- If work touches another project — add a wiki-link [[other-project]]
- If a bug repeats from a previous session — reference it: "See [[sessions/2024-03-10_my-app]]"
- In the "Key decisions" section, link to technologies: [[PostgreSQL]], [[OAuth2]]
- Use `previous_session` in frontmatter to create a session chain

## Updating project context
- After writing a log — check the file `__VAULT_PATH__/projects/{project-name}.md`
- If the file exists — data is updated automatically by the SessionEnd hook:
  - Last session: date and link
  - Current status: what is in progress
  - Open TODOs: collected from all sessions/ for this project
  - Stack: technologies determined by file extensions of changed files
- Context is cached in `__VAULT_PATH__/projects/.context-{project-name}.json`
- On the next session, the Stop hook will automatically inject [CONTEXT] from this cache
