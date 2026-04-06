**Русский** | [English](docs/README.en.md) | [中文](docs/README.zh.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)]()
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org)

# Claude Code → Obsidian Logger

Автоматическое логирование сессий [Claude Code](https://docs.anthropic.com/en/docs/claude-code) в [Obsidian](https://obsidian.md) vault.

Работаешь с Claude Code в любом проекте — логи сессий автоматически сохраняются в Obsidian как markdown-заметки.

## Что делает

```
Ты работаешь с Claude Code (любой проект)
    │
    ▼
PostToolUse hook → считает вызовы инструментов
    │
    ▼ (5+ вызовов = сессия существенная)
Stop hook → напоминает Claude записать подробный лог
    │
    ▼
Claude пишет лог → sessions/2024-03-15_14-30_my-project.md
    │
    ▼
SessionEnd hook → создаёт заготовку если Claude не записал
    │
    ▼
Открываешь Obsidian → видишь историю всех сессий
```

## Что попадает в лог

- Что было сделано (конкретные действия)
- Какие файлы изменены
- Ключевые решения и почему
- TODO на следующий раз
- Теги для поиска (#проект, #тема)

## Требования

- [Node.js](https://nodejs.org) v18+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Obsidian](https://obsidian.md) (рекомендуется, но не обязательно — логи это просто .md файлы)
- Bash (Git Bash на Windows, встроенный на macOS/Linux)

## Установка

```bash
git clone https://github.com/paradoxcalm/claude-code-to-obsidian.git
cd claude-obsidian-logger
bash install.sh
```

Установщик спросит путь к Obsidian vault и сделает всё автоматически:

1. Создаст структуру папок в vault
2. Установит скрипты-хуки
3. Настроит `~/.claude/settings.json`
4. Добавит инструкции в `~/.claude/CLAUDE.md`

### С указанием пути сразу

```bash
bash install.sh ~/Documents/MyVault
```

### Windows (Git Bash)

```bash
bash install.sh /c/Users/YourName/Documents/MyVault
```

## Структура vault после установки

```
MyVault/
├── CLAUDE.md           # Правила работы с vault
├── sessions/           # ← Логи сессий (автоматически)
│   ├── 2024-03-15_14-30_my-project.md
│   ├── 2024-03-15_16-00_other-project.md
│   └── README.md
├── daily/              # Ежедневные заметки
├── notes/              # Заметки и идеи
├── projects/           # Проекты
├── archive/            # Архив
├── templates/          # Шаблоны (daily, meeting, project)
└── scripts/            # Скрипты хуков
    ├── log-session.sh
    ├── log-tools.sh
    └── session-reminder.sh
```

## Как работают хуки

### 3 хука в `~/.claude/settings.json`:

| Хук | Событие | Что делает |
|-----|---------|-----------|
| `PostToolUse` | Каждый вызов инструмента | Пишет строку в `.tool-log-ДАТА.txt` (счётчик) |
| `Stop` | Claude закончил ответ | Если 5+ tool calls и лог не записан — впрыскивает напоминание `[АВТОЛОГ]` в контекст |
| `SessionEnd` | Выход из сессии | Создаёт заготовку лога если Claude не записал подробный |

### Умная логика:
- **Короткие сессии** (< 5 tool calls) — не трогает, не спамит
- **Длинные сессии** — Claude сам пишет подробный лог
- **Защита от дублей** — маркер-файл `.logged-SESSION_ID` предотвращает повторные напоминания

## Пример лога сессии

```markdown
# Сессия: Добавлена авторизация через OAuth

**Дата:** 2024-03-15 14:30
**Проект:** my-app
**Директория:** /home/user/projects/my-app

## Что сделано
- Добавлен OAuth2 flow через Google
- Создана таблица users в БД
- Написаны тесты для auth middleware

## Изменённые файлы
- `src/auth/oauth.ts` — новый модуль авторизации
- `src/db/migrations/001_users.sql` — миграция
- `src/middleware/auth.ts` — middleware проверки токена
- `tests/auth.test.ts` — тесты

## Ключевые решения
- Выбран OAuth вместо JWT — требование заказчика
- Refresh token хранится в httpOnly cookie

## TODO
- [ ] Добавить авторизацию через GitHub
- [ ] Rate limiting на /auth endpoints

#сессия #my-app #auth #oauth
```

## Конфигурация

После установки в vault создаётся `.obsidian-logger.json`:

```json
{
  "min_tool_calls": 5,
  "log_retention_days": 30,
  "language": "ru"
}
```

| Параметр | По умолчанию | Описание |
|----------|-------------|----------|
| `min_tool_calls` | `5` | Минимум tool calls для срабатывания напоминания |
| `log_retention_days` | `30` | Через сколько дней удалять технические файлы (`.tool-log-*`, `.logged-*`, `.reminded-*`) |
| `language` | `ru` | Язык логов и напоминаний (`ru`, `en`, `zh`) |

## Тесты

```bash
bash tests/test-install.sh
```

Тесты создают временные директории и не трогают ваш `~/.claude`.

## Удаление

```bash
bash uninstall.sh
```

Удаляет хуки из `settings.json` и секцию из `CLAUDE.md`. Vault и заметки **не удаляются**.

## Рекомендуемые плагины Obsidian

- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — SQL-подобные запросы по заметкам
- **[Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)** — управление задачами
- **[Templater](https://github.com/SilentVoid13/Templater)** — продвинутые шаблоны

### Полезные Dataview-запросы для сессий

Все сессии за последнюю неделю:
````markdown
```dataview
TABLE file.cday as "Дата"
FROM "sessions"
WHERE file.cday >= date(today) - dur(7 days)
SORT file.cday DESC
```
````

Все TODO из сессий:
````markdown
```dataview
TASK FROM "sessions"
WHERE !completed
```
````

## FAQ

**Q: Работает ли на macOS / Linux?**
A: Да. Скрипты написаны на bash + node, работают везде.

**Q: Что если я не использую Obsidian?**
A: Логи — обычные .md файлы. Можно открывать в любом редакторе, VS Code, Notion (импорт), etc.

**Q: Хуки замедляют Claude Code?**
A: Нет. Скрипты выполняются за ~50мс (запись строки в файл).

**Q: Можно ли отключить временно?**
A: Удали или закомментируй хуки в `~/.claude/settings.json`.

**Q: Лог пишется на русском. Как сменить язык?**
A: Отредактируй `~/.claude/CLAUDE.md` — замени "на русском" на нужный язык.

## Лицензия

MIT
