# Крок 7. Async Django

> Цей крок охоплює два самостійних проєкти: **7A** (hello_app — sync vs async порівняння) та **7B** (notes_chat_app — WebSocket груповий чат).
> Перший — standalone застосунок на SQLite під Uvicorn.
> Другий — production-like стек з Docker, PostgreSQL, Redis, Daphne і Django Channels.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 1. Hello Django](../01_hello_django/index.md) — перший `HttpResponse`, URL routing
    - [Крок 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Крок 3. CRUD і архітектура](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL
    - [Крок 4. Templates і Forms](../04_templates_and_forms/index.md) — Crispy Forms, Dashboard, Context Processor
    - [Крок 5. Auth і Безпека](../05_auth_and_security/index.md) — Sessions, Password Security, IDOR, Group Sharing
    - [Крок 6. Testing](../06_testing/index.md) — TestCase, fixtures, Selenium

---

## 7A vs 7B: два проєкти в одному кроці

| | 7A — hello_app | 7B — notes_chat_app |
|-|----------------|---------------------|
| **Проєкт** | hello_app (окремий навчальний) | notes_chat_app (production-like) |
| **Запуск** | `uvicorn notes_project.asgi:application --port 8001` | `docker compose up --build` |
| **База даних** | SQLite | PostgreSQL (Docker) |
| **ASGI сервер** | Uvicorn | Uvicorn (у Docker) |
| **Channel layer** | InMemoryChannelLayer | RedisChannelLayer |
| **WebSocket** | Демо у розділі 18 README_8 | `GroupChatConsumer` (повна реалізація) |
| **Daphne** | Необов'язково | Перший у `INSTALLED_APPS` |
| **Redis** | Не потрібен | `REDIS_URL` → RedisChannelLayer |
| **Мета** | Порівняти sync і async views архітектурно | Показати де async — єдина можлива архітектура |

---

## Що ти вивчиш

### Частина 7A — Async Views

- Чому `async def view` не стає кориснішим просто від написання `async`
- Що таке lazy QuerySet і де SQL реально виконується
- Як `async for` замінює `for` при ітерації по QuerySet
- Коли і чому `sync_to_async` потрібен для `transaction.atomic()`
- Як запустити Django під ASGI через Uvicorn
- Як писати тести для async views через `AsyncClient`
- Що `aupdate()` + `F()` — атомарний SQL UPDATE без завантаження об'єкта
- Де async виправданий, а де — зайве ускладнення

### Частина 7B — WebSocket чат

- Чому HTTP не підходить для real-time і де async стає необхідністю
- Що таке asyncio event loop і cooperative multitasking
- Що таке WebSocket і як він відрізняється від HTTP (handshake, постійне з'єднання)
- Що таке ASGI і чим він відрізняється від WSGI
- Як `ProtocolTypeRouter` об'єднує HTTP і WebSocket в одному ASGI-процесі
- Що таке Consumer і як він відрізняється від View
- Як `AuthMiddlewareStack` автентифікує WebSocket-з'єднання
- Що таке `database_sync_to_async` і навіщо він потрібен у Consumer
- Як channel layer доставляє повідомлення всім учасникам (pub/sub)
- Чому `load_history` повертає `list`, а не QuerySet
- XSS захист у WebSocket клієнті: `escapeHtml()`
- Тестування Consumer через `WebsocketCommunicator` і `TransactionTestCase`

---

## Порядок читання

### Частина 7A — Sync vs Async Django (hello_app)

1. **[7A. Sync vs Async огляд](7a_sync_vs_async.md)** — архітектура проєкту, файлова таблиця, sync і async request flows, коли async виправданий
2. **[7A. Async Views та ORM](7a_async_views.md)** — `async_selectors.py`, `async_services.py`, `async_views.py`, lazy vs evaluation, `sync_to_async`
3. **[7A. Benchmark та тестування](7a_benchmark.md)** — `AsyncClient`, тести sync vs async, Postman, benchmark, Docker Compose

### Частина 7B — WebSocket чат (notes_chat_app)

4. **[7B. WebSocket протокол](7b_websocket_protocol.md)** — HTTP vs WebSocket, handshake, asyncio event loop, чому sync не підходить для чату
5. **[7B. ASGI стек](7b_asgi_stack.md)** — WSGI vs ASGI, `ProtocolTypeRouter`, `asgi.py`, `routing.py`, `AuthMiddlewareStack`
6. **[7B. Channel Layers і Daphne](7b_channels_settings.md)** — Daphne у `INSTALLED_APPS`, `InMemoryChannelLayer` vs `RedisChannelLayer`, `socket_timeout=None`
7. **[7B. Consumer](7b_consumer.md)** — lifecycle, `GroupChatConsumer` повний код, `database_sync_to_async`, broadcast
8. **[7B. WebSocket JS клієнт](7b_websocket_client.md)** — Vanilla JS WebSocket API, повний клієнт, XSS захист, повний flow
9. **[Checkpoint](checkpoint.md)** — чеклисти 7A і 7B, Consumer тести, типові помилки, навігація
