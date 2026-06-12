# 09. Async and Realtime

> Async потрібний там, де є довгі очікування або long-lived connections. У цьому проєкті головний приклад - WebSocket chat.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Channels and WebSocket](channels_websocket.md) | ASGI, routing, consumer, channel layer |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/asgi.py` | ProtocolTypeRouter |
| `notes_project/routing.py` | WebSocket URL |
| `notes_app/consumers.py` | GroupChatConsumer |

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

Далі: [Linux and DevOps](../10_linux_and_devops/README.md).

<!-- restored-full-chapters:start -->

## Повні відновлені глави

Цей блок веде до повних навчальних матеріалів, перенесених з `archive/` без скорочення змісту.

- [01 — Синхронне та асинхронне виконання](async_01_sync_vs_async_full.md)
- [02 — Python asyncio: як виконується async-код](async_02_asyncio_full.md)
- [03 — WSGI та ASGI: як Django отримав async-підтримку](async_03_asgi_full.md)
- [04 — Django Async Views: як писати та коли використовувати](async_04_django_async_views_full.md)
- [05 — Async ORM: чому async view не робить БД асинхронною](async_05_async_orm_full.md)
- [06 — sync_to_async: міст між sync і async кодом](async_06_sync_to_async_full.md)
- [07 — Async HTTP Clients: правильні зовнішні запити](async_07_async_http_clients_full.md)
- [08 — Benchmarking: як об'єктивно порівняти sync і async Django](async_08_benchmarking_full.md)
- [09 — Real-World Use Cases: коли async Django справді потрібен](async_09_async_use_cases_full.md)

<!-- restored-full-chapters:end -->
