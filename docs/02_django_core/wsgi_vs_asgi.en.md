# WSGI vs ASGI — a practical breakdown

> WSGI is enough for sync HTTP Django. ASGI is needed for WebSocket and an async runtime.
> In `notes_chat_app` both protocols coexist in a single Uvicorn process.

---

## The short difference

| | WSGI | ASGI |
|--|------|------|
| **Standard** | PEP 3333 (2010) | A separate ASGI specification (not a PEP; version 3.0 in 2019) |
| **Protocols** | HTTP only | HTTP + WebSocket + HTTP/2 |
| **Execution** | Synchronous (blocking I/O) | Asynchronous (asyncio event loop) |
| **File in the project** | `notes_project/wsgi.py` | `notes_project/asgi.py` |
| **Server** | Gunicorn, uWSGI | Uvicorn, Daphne |
| **Suitable for** | CRUD, forms, authentication | + WebSocket, real-time, streaming |

---

## Where to find it in the project

### `notes_project/wsgi.py`

```python
# notes_project/wsgi.py
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

application = get_wsgi_application()
# ↑ The standard Django WSGI callable
# Used if you run the app through Gunicorn:
#   gunicorn notes_project.wsgi:application
#
# In notes_chat_app this file is NOT used in production —
# we use asgi.py and Uvicorn.
# The file is kept for compatibility (some platforms look for wsgi.py)
```

**What's in it:** one line of real code — `application = get_wsgi_application()`.
It is a callable that accepts an `environ` dict and a `start_response` function. Never touch it without a reason.

### `notes_project/asgi.py`

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: the FIRST line before any imports from notes_app
django_asgi_app = get_asgi_application()

# After get_asgi_application() it is safe to import models, consumers
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    "http": django_asgi_app,          # HTTP → regular Django
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)  # WebSocket → Consumer
    ),
})
```

**What to change here:**
- Add a new protocol (for example, `"lifespan"`) — very rarely
- Replace `AuthMiddlewareStack` with your own middleware — if you need custom WS authentication

**What NOT to change:**
- The order: `get_asgi_application()` always comes first
- `ProtocolTypeRouter` — this structure is mandatory for Channels

### `notes_project/routing.py`

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
```

**What to change here:**
- Add a new WebSocket URL → a new line in `websocket_urlpatterns`
- Change a URL pattern → edit the regex
- Hook up a new Consumer → `consumers.NewConsumer.as_asgi()`

**Do not confuse it with `notes_app/urls.py`** — that one is for HTTP URLs, this one is for WebSocket URLs.

### `notes_project/settings.py` — key parameters

```python
# settings.py — what relates to ASGI:

INSTALLED_APPS = [
    'daphne',     # ← FIRST: overrides runserver → ASGI
    'channels',   # ← Django Channels framework
    # ...
]

# Specifies which ASGI callable to use:
ASGI_APPLICATION = 'notes_project.asgi.application'
# ↑ Change it only if you renamed asgi.py or moved it to another package

# Channel layer:
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": os.environ.get('REDIS_URL'),
                "socket_timeout": None,
                "health_check_interval": 30,
            }]
        }
    }
}
# ↑ Change: the Redis address, timeout parameters
```

---

## How it starts in Docker

```
entrypoint.sh:
  exec python -m uvicorn notes_project.asgi:application \
      --host 0.0.0.0 --port 8001

Uvicorn:
  → loads notes_project/asgi.py
  → gets application = ProtocolTypeRouter({...})

On an HTTP request from nginx:
  ProtocolTypeRouter: protocol = "http"
  → passes it to django_asgi_app (views, urls, templates)

On a WebSocket from nginx (Upgrade: websocket):
  ProtocolTypeRouter: protocol = "websocket"
  → AuthMiddlewareStack → URLRouter → GroupChatConsumer
```

---

## When to change what

| Task | File | What to do |
|--------|------|-----------|
| Add a new HTTP URL | `notes_app/urls.py` | `path(...)` in `urlpatterns` |
| Add a new WebSocket URL | `notes_project/routing.py` | `re_path(...)` in `websocket_urlpatterns` |
| Add a new Consumer | `notes_app/consumers.py` | A new class + `routing.py` |
| Change the Redis config | `notes_project/settings.py` | `CHANNEL_LAYERS["CONFIG"]` |
| Change the WS middleware | `notes_project/asgi.py` | Change `AuthMiddlewareStack(...)` |
| Add lifespan events | `notes_project/asgi.py` | `"lifespan": ...` in `ProtocolTypeRouter` |
| Change WSGI (for gunicorn) | `notes_project/wsgi.py` | Rarely needed |

---

## Practical exercise

```bash
# Start the stack:
docker compose up -d

# 1. Make sure ASGI is working:
docker compose logs web | grep "Uvicorn running"

# 2. Open the chat in DevTools → Network → WS
# Make sure the WS connection is established (101 Switching Protocols)

# 3. Look at asgi.py and routing.py:
docker compose exec web cat notes_project/asgi.py
docker compose exec web cat notes_project/routing.py
```

---

## What's next

More about Channels, async consumers and WebSocket:
- [07 — Async and the WebSocket chat](../tutorials/07_async.md)
- [Async and Realtime](../09_async_and_realtime/README.md)
