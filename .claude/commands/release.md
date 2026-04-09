# /release — Выпуск новой версии

Ты выполняешь полный цикл релиза для проекта claude-code-to-obsidian.

## Шаги

### 1. Анализ изменений

Прочитай текущую версию из `VERSION`.
Найди последний тег: `git describe --tags --abbrev=0 2>/dev/null`.
Покажи изменения с последнего тега:

```
git log --oneline <последний_тег>..HEAD
git diff --stat <последний_тег>..HEAD
```

Если тегов нет — покажи весь `git log --oneline`.

### 2. Спроси пользователя

Покажи краткий список изменений и спроси:
- **Тип версии:** patch (багфиксы), minor (новые фичи), major (ломающие изменения)
- **Подтверждение** списка изменений для CHANGELOG

### 3. Обнови CHANGELOG.md

Формат — [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Removed
- ...
```

Правила:
- Вставляй новую секцию **между** `## [Unreleased]` и предыдущей версией
- Используй только непустые секции (Added/Changed/Fixed/Removed)
- Пиши на **английском** (changelog для международной аудитории)
- Каждый пункт — конкретное изменение, не "обновлены файлы"
- Обнови ссылки внизу файла:
  - `[Unreleased]` → `compare/vX.Y.Z...HEAD`
  - `[X.Y.Z]` → `compare/vPREV...vX.Y.Z`

### 4. Обнови VERSION

Запиши новую версию в файл `VERSION` (одна строка, без пробелов).

### 5. Коммит

```bash
git add VERSION CHANGELOG.md
# + любые файлы где обновилась версия
git commit -m "release: vX.Y.Z"
```

### 6. Тег

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### 7. Push

**Спроси подтверждение** перед push!

```bash
git push origin main
git push origin vX.Y.Z
```

### 8. GitHub Release

Извлеки секцию новой версии из CHANGELOG.md и создай релиз:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "$(секция из changelog)"
```

### 9. Отчёт

Покажи пользователю:
- Новая версия: vX.Y.Z
- Ссылка на релиз: `https://github.com/paradoxcalm/claude-code-to-obsidian/releases/tag/vX.Y.Z`
- Что вошло в релиз (кратко)

## Важно

- **Всегда спрашивай подтверждение** перед push и созданием релиза
- Не пропускай шаги — даже для patch-релиза нужен полный цикл
- Если `gh` CLI не установлен — предупреди и пропусти шаг 9
- Если нет remote — предупреди и пропусти шаги 8-9
