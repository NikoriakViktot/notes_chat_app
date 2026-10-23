# 7B. The ASGI stack

---

## WSGI vs ASGI

| | WSGI | ASGI |
|--|------|------|
| **Standard** | PEP 3333 (2010) | ASGI specification (asgi.readthedocs.io, not a PEP) |
| **Protocols** | HTTP only | HTTP + WebSocket + others |
| **Model** | Synchronous (one request = one thread) | Asynchronous (coroutines) |
| **Servers** | Gunicorn, uWSGI | Uvicorn, Daphne, Hypercorn |
| **Django** | Standard runserver | Requires an ASGI application + channels |
| **WebSocket** | ❌ Not supported | ✅ Natively |

---

## Architecture of the notes_chat_app ASGI stack

```
Browser (HTTP)          Browser (WebSocket)
      │                        │
      ▼                        ▼
   nginx :80  (reverse proxy — forwards requests)
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

| Component | Role | Equivalent in HTTP Django |
|-----------|------|---------------------|
| `ProtocolTypeRouter` | Distinguishes HTTP and WS by protocol type | `ROOT_URLCONF` |
| `AuthMiddlewareStack` | Reads the session cookie → `scope['user']` | `@login_required` decorator |
| `WebSocket URLRouter` | Routes a WS URL to a Consumer | `urls.py` |
| `GroupChatConsumer` | Handles the WS connection for its whole lifetime | `view` (but lives longer) |
| `InMemoryChannelLayer` | Pub/sub broadcast between consumers | _(no direct equivalent)_ |

---

## asgi.py — the entry point

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from django.contrib.staticfiles.handlers import ASGIStaticFilesHandler

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: get_asgi_application() BEFORE any import from notes_app
# The Django app registry (AppConfig.ready()) must be initialized
# BEFORE importing models or consumers.
# If you change the order → AppRegistryNotReady exception.
django_asgi_app = get_asgi_application()

# Only after get_asgi_application() is it safe to import from notes_app
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → regular Django (views.py, templates);
    # ASGIStaticFilesHandler serves /static/ straight from Django (handy in development;
    # in the Docker stack nginx serves /static/)
    "http": ASGIStaticFilesHandler(django_asgi_app),

    # WebSocket → Auth middleware → URL router → Consumer
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

### The critical import order

```python
# ❌ WRONG — AppRegistryNotReady:
from notes_project.routing import websocket_urlpatterns   # ← BEFORE get_asgi_application()
django_asgi_app = get_asgi_application()

# ✅ CORRECT:
django_asgi_app = get_asgi_application()                  # ← FIRST
from notes_project.routing import websocket_urlpatterns   # ← THEN
```

**Why this matters so much:**

```
The Django app registry is initialized when get_asgi_application() is called.
Until that moment:
  - models are not loaded
  - AppConfig.ready() has not run
  - any import from notes_app.consumers → AppRegistryNotReady

A typical mistake:
  from notes_project.routing import websocket_urlpatterns
  # routing.py: from notes_app import consumers
  # consumers.py: from notes_app.models import ChatMessage
  # → AppRegistryNotReady!
```

---

## AuthMiddlewareStack — scope["user"] from the session

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
  # → User object (or AnonymousUser if not logged in)
```

### What scope is

In ASGI, `scope` is a dictionary with the connection's metadata. It is the equivalent of `request` in HTTP views, but for WebSocket:

```python
# scope for a WebSocket connection:
{
    'type': 'websocket',
    'path': '/ws/groups/7/chat/',
    'url_route': {
        'kwargs': {'group_pk': '7'}   # ← from the URL pattern
    },
    'user': <User: viktor>,           # ← loaded by AuthMiddlewareStack
    'headers': [...],                 # ← handshake request headers
    'session': <Session>,             # ← Django session
}
```

### How the Consumer uses scope

```python
async def connect(self):
    self.user = self.scope['user']
    # ↑ User is already loaded by AuthMiddlewareStack

    self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])
    # ↑ group_pk from the URL /ws/groups/<group_pk>/chat/
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

### Consumer.as_asgi()

```python
consumers.GroupChatConsumer.as_asgi()
# Equivalent of View.as_view() in HTTP — turns the Consumer class into an ASGI callable
# Each WebSocket connection → a separate Consumer instance
```

---

## nginx: WebSocket proxy

When running behind nginx, WebSocket needs special headers.

```nginx
# nginx.conf — WebSocket location
location /ws/ {
    proxy_pass http://web:8001;
    proxy_http_version 1.1;          # ← HTTP/1.1 is required for the WS Upgrade
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 300s;         # ← 5 minutes for idle WS connections
}
```

**Why `proxy_http_version 1.1`:**
The WebSocket Upgrade only works over HTTP/1.1. By default, nginx uses HTTP/1.0 for upstream requests. Without this line the WS Upgrade will not happen → the browser gets HTTP 400.

**Why `proxy_read_timeout 300s`:**
By default, nginx closes the upstream connection after 60 sec without a response.
A WebSocket can stay open for hours without traffic → increase the timeout to 5+ minutes.

---

## Common mistakes in the ASGI stack

| Error | Cause | Fix |
|---------|---------|-------------|
| `AppRegistryNotReady` | Import from notes_app BEFORE `get_asgi_application()` | Move the imports after the call |
| WS 400 through nginx | Missing Upgrade headers | `proxy_http_version 1.1` + Upgrade headers |
| Consumer not found | `routing.py` is not wired into `asgi.py` | Include `websocket_urlpatterns` |
| `scope['user']` is AnonymousUser | `AuthMiddlewareStack` is missing or the session has expired | Check `is_authenticated` in `connect()` |

---

## Next

Next chapter: **[7B. Channel Layers and Daphne](7b_channels_settings.md)** — Daphne in `INSTALLED_APPS`, `InMemoryChannelLayer` vs `RedisChannelLayer`, `socket_timeout=None`.
