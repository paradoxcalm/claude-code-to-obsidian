# Правила работы с vault

## Общие правила
- Все заметки на русском языке
- Формат дат: YYYY-MM-DD
- Задачи: `- [ ] текст`
- Используй [[wiki-ссылки]] для связей
- Теги: #задача, #идея, #встреча, #сессия

## Структура папок
```
/notes      — заметки, идеи
/projects   — проекты
/daily      — ежедневные дневники
/sessions   — автологи сессий Claude Code
/archive    — архив
/templates  — шаблоны
```

## Dataview запросы
- Все сессии: `TABLE FROM "sessions" SORT file.name DESC`
- Открытые задачи: `TASK WHERE !completed`
- За неделю: `TABLE FROM "daily" WHERE file.cday >= date(today) - dur(7 days)`
