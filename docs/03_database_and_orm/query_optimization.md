# Query Optimization

> QuerySet laziness і N+1 problem пояснюють, чому selectors важливі.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Інструменти

- `select_related` для ForeignKey/OneToOne через JOIN.
- `prefetch_related` для ManyToMany/reverse relations окремим запитом.
- `annotate` для counts.
- indexes для частих filters/orderings.

`get_user_notes` використовує `select_related('notebook', 'group')` і `prefetch_related('tags')`.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/selectors.py` | optimized read queries |
| `notes_app/models.py` | indexes on Note and ChatMessage |

## Практичне завдання

Знайдіть selector з `Count` і поясніть, який UI він підтримує.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [transactions and PostgreSQL](transactions_indexes_postgresql.md).
