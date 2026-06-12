# Migrations

> Migration - це версійний файл, який описує зміну schema.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Фактичні migrations

- `0001_initial.py` - базовий домен.
- `0002...shared_with...` - direct sharing.
- `0003...group...` - group sharing.
- `0004_chatmessage.py` - chat history.

## Команди

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py showmigrations
python manage.py sqlmigrate notes_app 0004
```

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/migrations/` | migration files |
| `notes_app/models.py` | source of schema changes |

## Практичне завдання

Виконайте `showmigrations` після встановлення dependencies.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [query optimization](query_optimization.md).
