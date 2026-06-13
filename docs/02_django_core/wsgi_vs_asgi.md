# WSGI vs ASGI

> WSGI достатній для sync HTTP, ASGI потрібний для WebSocket і async runtime.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Різниця

| WSGI | ASGI |
| --- | --- |
| sync request/response | async-capable protocol router |
| `notes_project/wsgi.py` | `notes_project/asgi.py` |
| добре для CRUD | потрібно для WebSocket |

`runserver` з Daphne/Channels може підтримувати ASGI, але явний `uvicorn notes_project.asgi:application` краще показує модель.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/wsgi.py` | sync entrypoint |
| `notes_project/asgi.py` | ProtocolTypeRouter |

## Практичне завдання

Запустіть ASGI server і відкрийте chat page.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Детальніше про ASGI, Channels і async runtime: [WSGI та ASGI — повний розбір](../09_async_and_realtime/async_03_asgi_full.md).

Далі: [Database and ORM](../03_database_and_orm/README.md).
