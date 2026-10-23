# Step 7. Async Django

> This step covers two independent projects: **7A** (hello_app, a sync vs async comparison) and **7B** (notes_chat_app, a WebSocket group chat).
> The first is a standalone application on SQLite under Uvicorn.
> The second is a production-like stack with Docker, PostgreSQL, Redis, Daphne and Django Channels.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 1. Hello Django](../01_hello_django/index.md): the first `HttpResponse`, URL routing
    - [Step 2. Bootstrap Notes](../02_first_model/index.md): ModelForm, PRG, Bootstrap CRUD
    - [Step 3. CRUD and architecture](../03_crud_and_architecture/index.md): Services & Selectors, PostgreSQL
    - [Step 4. Templates and Forms](../04_templates_and_forms/index.md): Crispy Forms, Dashboard, Context Processor
    - [Step 5. Auth and Security](../05_auth_and_security/index.md): Sessions, Password Security, IDOR, Group Sharing
    - [Step 6. Testing](../06_testing/index.md): TestCase, fixtures, Selenium

---

## 7A vs 7B: two projects in one step

| | 7A: hello_app | 7B: notes_chat_app |
|-|----------------|---------------------|
| **Project** | hello_app (a separate learning project) | notes_chat_app (production-like) |
| **How to run** | `uvicorn notes_project.asgi:application --port 8001` | `docker compose up --build` |
| **Database** | SQLite | PostgreSQL (Docker) |
| **ASGI server** | Uvicorn | Uvicorn (in Docker) |
| **Channel layer** | InMemoryChannelLayer | RedisChannelLayer |
| **WebSocket** | Demo in section 18 of README_8 | `GroupChatConsumer` (full implementation) |
| **Daphne** | Optional | First in `INSTALLED_APPS` |
| **Redis** | Not needed | `REDIS_URL` → RedisChannelLayer |
| **Goal** | Compare sync and async views architecturally | Show where async is the only possible architecture |

---

## What you will learn

### Part 7A: Async Views

- Why an `async def view` does not become more useful just because you wrote `async`
- What a lazy QuerySet is and where SQL actually runs
- How `async for` replaces `for` when iterating over a QuerySet
- When and why `sync_to_async` is needed for `transaction.atomic()`
- How to run Django under ASGI with Uvicorn
- How to write tests for async views with `AsyncClient`
- That `aupdate()` + `F()` is an atomic SQL UPDATE without loading the object
- Where async is justified and where it is unnecessary complexity

### Part 7B: WebSocket chat

- Why HTTP is not suitable for real time and where async becomes a necessity
- What the asyncio event loop and cooperative multitasking are
- What WebSocket is and how it differs from HTTP (handshake, persistent connection)
- What ASGI is and how it differs from WSGI
- How `ProtocolTypeRouter` combines HTTP and WebSocket in a single ASGI process
- What a Consumer is and how it differs from a View
- How `AuthMiddlewareStack` authenticates WebSocket connections
- What `database_sync_to_async` is and why the Consumer needs it
- How the channel layer delivers messages to all participants (pub/sub)
- Why `load_history` returns a `list` and not a QuerySet
- XSS protection in the WebSocket client: `escapeHtml()`
- Testing the Consumer with `WebsocketCommunicator` and `TransactionTestCase`

---

## Reading order

### Part 7A: Sync vs Async Django (hello_app)

1. **[7A. Sync vs Async overview](7a_sync_vs_async.md)**: project architecture, file table, sync and async request flows, when async is justified
2. **[7A. Async Views and the ORM](7a_async_views.md)**: `async_selectors.py`, `async_services.py`, `async_views.py`, lazy vs evaluation, `sync_to_async`
3. **[7A. Benchmark and testing](7a_benchmark.md)**: `AsyncClient`, sync vs async tests, Postman, benchmark, Docker Compose

### Part 7B: WebSocket chat (notes_chat_app)

4. **[7B. The WebSocket protocol](7b_websocket_protocol.md)**: HTTP vs WebSocket, handshake, asyncio event loop, why sync does not fit a chat
5. **[7B. The ASGI stack](7b_asgi_stack.md)**: WSGI vs ASGI, `ProtocolTypeRouter`, `asgi.py`, `routing.py`, `AuthMiddlewareStack`
6. **[7B. Channel Layers and Daphne](7b_channels_settings.md)**: Daphne in `INSTALLED_APPS`, `InMemoryChannelLayer` vs `RedisChannelLayer`, `socket_timeout=None`
7. **[7B. Consumer](7b_consumer.md)**: lifecycle, the full `GroupChatConsumer` code, `database_sync_to_async`, broadcast
8. **[7B. WebSocket JS client](7b_websocket_client.md)**: the Vanilla JS WebSocket API, the full client, XSS protection, the full flow
9. **[Checkpoint](checkpoint.md)**: 7A and 7B checklists, Consumer tests, common mistakes, navigation
