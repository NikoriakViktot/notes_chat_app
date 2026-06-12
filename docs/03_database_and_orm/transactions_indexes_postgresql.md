# Transactions, Indexes and PostgreSQL

> Transactions захищають цілісність, indexes пришвидшують типові queries, PostgreSQL потрібний для production-grade DB.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## У проєкті

`services.create_note` і notebook update operations використовують `transaction.atomic()` там, де треба змінити кілька пов'язаних речей.

`settings.py` перемикається на PostgreSQL, якщо задано `DATABASE_URL`.

## Межа

SQLite підходить для локального старту. PostgreSQL рекомендований для server deployment.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/services.py` | transactions and updates |
| `notes_project/settings.py` | DATABASE_URL parsing |

## Практичне завдання

Поясніть, чому `tags.set()` у create note краще виконувати в transaction.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Forms and validation](../04_forms_and_validation/README.md).
