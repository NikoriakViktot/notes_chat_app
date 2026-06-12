# Services and Selectors

> Selector читає дані, service змінює дані, view координує HTTP.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Правило

| Шар | Робить | Не робить |
| --- | --- | --- |
| View | request, permissions, forms, render/redirect | складний ORM |
| Selector | SELECT queries | mutations |
| Service | create/update/delete, transaction | HTML response |

Це робить code testable: service можна тестувати без HTTP, selector можна оптимізувати без зміни template.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/selectors.py` | read layer |
| `notes_app/services.py` | write layer |
| `notes_app/tests/test_services.py` | service tests |

## Практичне завдання

Винесіть один повторюваний query у selector і додайте test.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Auth and security](../07_auth_and_security/README.md).
