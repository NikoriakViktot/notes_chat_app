# Частина IX. Async і Real-Time

HTTP polling для чату — це 100 запитів/сек на 100 клієнтів. WebSocket дає одне довготривале з'єднання. Django Channels реалізує WebSocket поверх ASGI, Redis — broadcast між процесами.

**Передумови:** Частини II, III, VIII.
**Рівень:** Advanced.

---

## Концептуальний місток: asyncio → ASGI → Channels

Три концепти утворюють єдиний стек. Кожен відповідає на конкретне питання:

```
asyncio          — Як тримати тисячі з'єднань без тисячі потоків?
    ↓               один event loop; await замість блокування
ASGI             — Як Django отримує async-запити від сервера?
    ↓               async-інтерфейс між Daphne/Uvicorn і Django; замінює WSGI
Django Channels  — Як Django route-ує WebSocket поряд з HTTP?
    ↓               ProtocolTypeRouter → "http" → views, "websocket" → Consumer
Redis            — Як Worker 1 надсилає повідомлення клієнтам Worker 2?
                    channel layer: pub/sub між процесами
```

**Залежності між рівнями:**

| Без чого | Що неможливо |
|----------|-------------|
| `asyncio` | ASGI неможливий — немає event loop для async I/O |
| `ASGI` | Channels не підключити до Django — немає async entry point |
| `Channels` | Немає WebSocket routing і Consumer API |
| `Redis` | WebSocket повідомлення не дійдуть до клієнтів іншого worker-процесу |

**WSGI vs ASGI — чому потрібен перехід:**

```python
# WSGI — синхронний: один запит = один потік, потік блокується до відповіді
def application(environ, start_response):
    data = requests.get(url)   # блокує потік — ніхто інший не може його використати
    ...

# ASGI — асинхронний: один потік = тисячі корутин, await звільняє потік
async def application(scope, receive, send):
    data = await httpx.get(url)   # потік вільний — обробляє інші з'єднання
    ...
```

Django Channels — це Django-реалізація ASGI, яка додає WebSocket Consumer API поверх стандарту. `ProtocolTypeRouter` — це перша точка маршрутизації: HTTP іде до Django views, WebSocket — до Consumer.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Sync vs Async](async_01_sync_vs_async_full.md) | блокуючий vs неблокуючий I/O, GIL, thread pool, event loop |
| [asyncio](async_02_asyncio_full.md) | coroutine, `await`, `Task`, `gather`, `asyncio.run()` |
| [asyncio: Event Loop](lesson_34_documentation.md) | архітектура event loop, callbacks, futures, libuv |
| [ASGI](async_03_asgi_full.md) | ASGI spec, `ProtocolTypeRouter`, lifecycle, scope |
| [Django Async Views](async_04_django_async_views_full.md) | `async def view()`, обмеження, коли варто |
| [Async ORM](async_05_async_orm_full.md) | `aadd`, `acreate`, `afilter`, `aget`, відмінності від sync |
| [sync_to_async](async_06_sync_to_async_full.md) | `database_sync_to_async`, `sync_to_async`, thread safety |
| [Async HTTP Clients](async_07_async_http_clients_full.md) | `httpx`, `aiohttp`, connection pooling |
| [Benchmarking](async_08_benchmarking_full.md) | порівняння sync vs async, `locust`, результати |
| [Async Use Cases](async_09_async_use_cases_full.md) | коли async виправданий, антипатерни |
| [WebSocket та Channels](channels_websocket.md) | Django Channels, `AsyncWebsocketConsumer`, channel layer, Redis |

---

## Ключові концепти

**Coroutine і await:**

```python
import asyncio

async def fetch_data():
    await asyncio.sleep(1)   # не блокує event loop
    return "data"

async def main():
    result = await fetch_data()
    print(result)

asyncio.run(main())
```

**ASGI entrypoint:**

```python
# notes_project/asgi.py
# ПОРЯДОК ІМПОРТІВ КРИТИЧНИЙ!
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
django_asgi_app = get_asgi_application()  # ← ПЕРЕД будь-яким notes_app імпортом

from notes_app.consumers import GroupChatConsumer  # ← ПІСЛЯ

application = ProtocolTypeRouter({
    "http":      django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter([re_path(r"^ws/groups/(?P<group_pk>\d+)/chat/$", GroupChatConsumer.as_asgi())])
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

        self.room_group_name = f"chat_{group_pk}"
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

        # надіслати 50 останніх повідомлень
        history = await database_sync_to_async(self.load_history)(group_pk)
        for msg in reversed(history):
            await self.send(text_data=json.dumps({'type': 'history', **msg}))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data    = json.loads(text_data)
        content = data.get('message', '').strip()
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

**database_sync_to_async + матеріалізація:**

```python
# ✅ ПРАВИЛЬНО: list() матеріалізує QuerySet у worker thread, до повернення
def load_history(self, group_pk):
    return list(
        ChatMessage.objects.filter(group_id=group_pk)
        .select_related('author')
        .order_by('-created_at')[:50]
        .values('content', 'author__username', 'created_at')
    )

# ❌ НЕПРАВИЛЬНО: повертає lazy QuerySet → SynchronousOnlyOperation
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
            "socket_timeout": None,    # ← None = без таймауту для idle WS
        },
    }
}
```

`socket_timeout=None` критично: без нього Redis з'єднання закривається при idle → `TimeoutError` при наступному повідомленні.

**Polling vs WebSocket:**

```text
HTTP Polling (setInterval 1s):
  100 клієнтів × 1 req/s = 100 HTTP запитів/сек
  Кожен запит: TCP handshake + HTTP headers + відповідь
  Затримка: до 1000ms

WebSocket:
  100 клієнтів = 100 відкритих з'єднань (persistent)
  Повідомлення: < 50ms
  Навантаження: тільки при реальних подіях
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_project/asgi.py` | `ProtocolTypeRouter`, import order |
| `notes_project/routing.py` | `re_path(r"^ws/groups/.../chat/$", ...)` |
| `notes_app/consumers.py` | `GroupChatConsumer` — connect, disconnect, receive, chat_message |
| `notes_app/static/.../group_chat.js` | JS-клієнт: `new WebSocket()`, `onmessage`, `send()` |
| `notes_app/tests/test_consumers.py` | `WebsocketCommunicator`, `TransactionTestCase` |
| `notes_project/settings.py` | `CHANNEL_LAYERS` з `socket_timeout: None` |

---

## Педагогічний зв'язок

```text
Частина IX: ASGI / Channels
  ← Частина II: WSGI vs ASGI (async entrypoint)
  ← Частина III: ORM (database_sync_to_async wrapping)
  ← Частина VII: Auth (scope['user'], check_membership)
  ← Частина VIII: TransactionTestCase (consumer tests)
```

**Zero to Hero:** Крок 7 — WebSocket chat: Channels, Redis, GroupChatConsumer, consumer tests.

**Lab:** [Async Lab](../labs/async_lab.md) — написати простий consumer, тест, channel layer broadcast.

---

## Підводні камені

| Ситуація | Помилка | Рішення |
|----------|---------|---------|
| `get_asgi_application()` після `from notes_app...` | `AppRegistryNotReady` | перенести `get_asgi_application()` ПЕРЕД будь-яким notes_app імпортом |
| Lazy QuerySet у `database_sync_to_async` | `SynchronousOnlyOperation` | `list()` у sync helper перед поверненням |
| `socket_timeout` не `None` | `TimeoutError` на idle WS | `"socket_timeout": None` у `CHANNEL_LAYERS CONFIG` |
| `TestCase` для consumer tests | setUp-об'єкти зникають | `TransactionTestCase` |

---

## Контрольні питання

- Що таке coroutine? Яка різниця між `async def` і `def`?
- Що таке event loop? Скільки event loop'ів може бути у процесі?
- Навіщо `database_sync_to_async`? Що трапиться без нього?
- Чому `list()` всередині sync helper критичний при поверненні у async-контекст?
- Що таке channel layer? Навіщо Redis якщо є in-memory layer?
- Чому `socket_timeout=None` важливий для idle WebSocket з'єднань?
- Коли варто використовувати async views, а коли sync views у Django?

---

**Далі →** [Частина X. Linux, DevOps і Deployment](../10_linux_and_devops/README.md) — як запустити в production.
