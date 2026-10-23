# Part IX. Async and Real-Time

HTTP polling for a chat means 100 requests/sec for 100 clients. WebSocket gives you one long-lived connection. Django Channels implements WebSocket on top of ASGI, and Redis handles broadcast between processes.

**Prerequisites:** Parts II, III, VIII.
**Level:** Advanced.

---

## Conceptual bridge: asyncio → ASGI → Channels

Three concepts form a single stack. Each one answers a specific question:

```
asyncio          — How do you hold thousands of connections without thousands of threads?
    ↓               one event loop; await instead of blocking
ASGI             — How does Django receive async requests from the server?
    ↓               an async interface between Daphne/Uvicorn and Django; replaces WSGI
Django Channels  — How does Django route WebSocket alongside HTTP?
    ↓               ProtocolTypeRouter → "http" → views, "websocket" → Consumer
Redis            — How does Worker 1 send messages to Worker 2's clients?
                    channel layer: pub/sub between processes
```

**Dependencies between the levels:**

| Without | What becomes impossible |
|----------|-------------|
| `asyncio` | ASGI is impossible — there is no event loop for async I/O |
| `ASGI` | Channels cannot be plugged into Django — there is no async entry point |
| `Channels` | No WebSocket routing and no Consumer API |
| `Redis` | WebSocket messages will not reach clients of another worker process |

**WSGI vs ASGI — why the transition is needed:**

```python
# WSGI — synchronous: one request = one thread, the thread blocks until the response
def application(environ, start_response):
    data = requests.get(url)   # blocks the thread — nobody else can use it
    ...

# ASGI — asynchronous: one thread = thousands of coroutines, await frees the thread
async def application(scope, receive, send):
    async with httpx.AsyncClient() as client:
        data = await client.get(url)   # the thread is free — it handles other connections
    ...
```

Django Channels is the Django implementation of ASGI that adds a WebSocket Consumer API on top of the standard. `ProtocolTypeRouter` is the first routing point: HTTP goes to Django views, WebSocket goes to a Consumer.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [Sync vs Async](async_01_sync_vs_async_full.md) | blocking vs non-blocking I/O, GIL, thread pool, event loop |
| [asyncio](async_02_asyncio_full.md) | coroutine, `await`, `Task`, `gather`, `asyncio.run()` |
| [asyncio: Event Loop](lesson_34_documentation.md) | event loop architecture, callbacks, futures, libuv |
| [ASGI](async_03_asgi_full.md) | ASGI spec, `ProtocolTypeRouter`, lifecycle, scope |
| [Django Async Views](async_04_django_async_views_full.md) | `async def view()`, limitations, when it is worth it |
| [Async ORM](async_05_async_orm_full.md) | `aadd`, `acreate`, `aget`, `async for`, differences from sync |
| [sync_to_async](async_06_sync_to_async_full.md) | `database_sync_to_async`, `sync_to_async`, thread safety |
| [Async HTTP Clients](async_07_async_http_clients_full.md) | `httpx`, `aiohttp`, connection pooling |
| [Benchmarking](async_08_benchmarking_full.md) | comparing sync vs async, `locust`, results |
| [Async Use Cases](async_09_async_use_cases_full.md) | when async is justified, anti-patterns |
| [WebSocket and Channels](channels_websocket.md) | Django Channels, `AsyncWebsocketConsumer`, channel layer, Redis |

---

## Key concepts

**Coroutine and await:**

```python
import asyncio

async def fetch_data():
    await asyncio.sleep(1)   # does not block the event loop
    return "data"

async def main():
    result = await fetch_data()
    print(result)

asyncio.run(main())
```

**ASGI entrypoint:**

```python
# notes_project/asgi.py
# IMPORT ORDER IS CRITICAL!
import os
from django.core.asgi import get_asgi_application
from django.contrib.staticfiles.handlers import ASGIStaticFilesHandler

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
django_asgi_app = get_asgi_application()  # ← BEFORE any notes_app import

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from notes_project.routing import websocket_urlpatterns  # ← AFTER (it imports GroupChatConsumer)

application = ProtocolTypeRouter({
    "http":      ASGIStaticFilesHandler(django_asgi_app),  # static files — development only
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)  # r"^ws/groups/(?P<group_pk>\d+)/chat/$"
    ),
})
```

**GroupChatConsumer — lifecycle:**

```python
class GroupChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        user     = self.scope['user']
        group_pk = self.scope['url_route']['kwargs']['group_pk']

        if not user.is_authenticated:
            await self.close(); return

        is_member = await database_sync_to_async(self.check_membership)(group_pk, user)
        if not is_member:
            await self.close(); return

        self.room_group_name = f"chat_group_{group_pk}"
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

        # send the 50 most recent messages
        history = await database_sync_to_async(self.load_history)(group_pk)
        for msg in reversed(history):
            await self.send(text_data=json.dumps({'type': 'history', **msg}))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data    = json.loads(text_data)
        content = data.get('content', '').strip()
        if not content:
            return
        user = self.scope['user']
        await database_sync_to_async(self.save_message)(
            int(self.scope['url_route']['kwargs']['group_pk']), user, content
        )
        await self.channel_layer.group_send(
            self.room_group_name,
            {'type': 'chat_message', 'content': content, 'author': user.username}
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({'type': 'chat_message', **event}))
```

**database_sync_to_async + materialization:**

```python
# ✅ CORRECT: list() materializes the QuerySet in the worker thread, before returning
def load_history(self, group_pk):
    return list(
        ChatMessage.objects.filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:50]
        .values('content', 'author__username', 'timestamp')
    )

# ❌ WRONG: returns a lazy QuerySet → SynchronousOnlyOperation
def load_history_bad(self, group_pk):
    return ChatMessage.objects.filter(group_id=group_pk)  # lazy!
```

**Redis channel layer:**

```python
# settings.py
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [REDIS_URL],
            "socket_timeout": None,    # ← None = no timeout for idle WS
        },
    }
}
```

`socket_timeout=None` is critical: without it, the Redis connection is closed when idle → `TimeoutError` on the next message.

**Polling vs WebSocket:**

```text
HTTP Polling (setInterval 1s):
  100 clients × 1 req/s = 100 HTTP requests/sec
  Each request: TCP handshake + HTTP headers + response
  Latency: up to 1000ms

WebSocket:
  100 clients = 100 open connections (persistent)
  Messages: < 50ms
  Load: only on real events
```

---

## Where this lives in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_project/asgi.py` | `ProtocolTypeRouter`, import order |
| `notes_project/routing.py` | `re_path(r"^ws/groups/.../chat/$", ...)` |
| `notes_app/consumers.py` | `GroupChatConsumer` — connect, disconnect, receive, chat_message |
| `notes_app/static/.../group_chat.js` | JS client: `new WebSocket()`, `onmessage`, `send()` |
| `notes_app/tests/test_consumers.py` | `WebsocketCommunicator`, `TransactionTestCase` |
| `notes_project/settings.py` | `CHANNEL_LAYERS` with `socket_timeout: None` |

---

## Pedagogical connections

```text
Part IX: ASGI / Channels
  ← Part II: WSGI vs ASGI (async entrypoint)
  ← Part III: ORM (database_sync_to_async wrapping)
  ← Part VII: Auth (scope['user'], check_membership)
  ← Part VIII: TransactionTestCase (consumer tests)
```

**Zero to Hero:** Step 7 — WebSocket chat: Channels, Redis, GroupChatConsumer, consumer tests.

**Lab:** [Async Lab](../labs/async_lab.md) — write a simple consumer, a test, and a channel layer broadcast.

---

## Pitfalls

| Situation | Error | Solution |
|----------|---------|---------|
| `get_asgi_application()` after `from notes_app...` | `AppRegistryNotReady` | move `get_asgi_application()` BEFORE any notes_app import |
| Lazy QuerySet in `database_sync_to_async` | `SynchronousOnlyOperation` | `list()` in the sync helper before returning |
| `socket_timeout` is not `None` | `TimeoutError` on idle WS | `"socket_timeout": None` in `CHANNEL_LAYERS CONFIG` |
| `TestCase` for consumer tests | setUp objects disappear | `TransactionTestCase` |

---

## Review questions

- What is a coroutine? What is the difference between `async def` and `def`?
- What is an event loop? How many event loops can a process have?
- Why do we need `database_sync_to_async`? What happens without it?
- Why is `list()` inside a sync helper critical when returning into an async context?
- What is a channel layer? Why use Redis if there is an in-memory layer?
- Why is `socket_timeout=None` important for idle WebSocket connections?
- When should you use async views, and when sync views, in Django?

---

**Next →** [Part X. Linux, DevOps, and Deployment](../10_linux_and_devops/README.md) — how to run it in production.
