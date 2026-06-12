# 03. Database and ORM

> Models описують domain, migrations змінюють schema, ORM перетворює Python calls у SQL.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Django models](django_models.md) | моделі фінального проєкту |
| [Migrations](migrations.md) | історія schema changes |
| [Query optimization](query_optimization.md) | select_related, prefetch_related, indexes |
| [Transactions and PostgreSQL](transactions_indexes_postgresql.md) | atomicity, indexes, PostgreSQL |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/models.py` | models and relationships |
| `notes_app/migrations/` | schema history |
| `notes_app/selectors.py` | optimized queries |

## Мінімальне завдання

Прочитайте головний документ розділу і знайдіть у коді всі згадані файли.

## Основне завдання

Поясніть своїми словами, як ця тема проявляється у поточному проєкті. Не змінюйте код, якщо завдання прямо цього не вимагає.

## Advanced challenge

Знайдіть одну потенційну точку покращення в цій темі і запишіть, які tests або checks мають підтвердити зміну.

## Контрольні питання

- Яка проблема вирішується цим шаром?
- Де межа відповідальності цього шару?
- Який файл є головною точкою входу?
- Яка типова помилка початківця?

## Далі

Далі: [Forms and validation](../04_forms_and_validation/README.md).

<!-- restored-full-chapters:start -->

## Повні відновлені глави

Цей блок веде до повних навчальних матеріалів, перенесених з `archive/` без скорочення змісту.

- [Архітектура проєкту Django та Еволюція бази даних](django_migrations_full.md)
- [Django ORM — глибока механіка](django_orm_deep_full.md)
- [Django ORM та Бази Даних](django_orm_full.md)
- [Індекси PostgreSQL — Глибока механіка](indexing_deep_full.md)
- [Django ORM та БД — Mermaid-схеми](orm_mermaid_full.md)
- [PostgreSQL Advanced — Архітектура, Docker та Production патерни](postgresql_advanced_full.md)
- [Реляційний фундамент та SQL](relational_db_foundations_full.md)
- [Транзакції, Блокування та Конкурентність в Django + PostgreSQL](transactions_concurrency_full.md)

<!-- restored-full-chapters:end -->
