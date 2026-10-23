# 7B. Channel Layers and Daphne

---

## Daphne: why it comes first in INSTALLED_APPS

Daphne is an ASGI server from the Django Channels team. It intercepts the `python manage.py runserver` command and replaces the built-in WSGI server with an ASGI server.

```python
# notes_project/settings.py
INSTALLED_APPS = [
    'daphne',        # ← FIRST in the list! Must come before 'django.contrib.*'
    'channels',      # Django Channels
    'django.contrib.admin',
    # ... the rest of the apps
    'notes_app',
]
```

### What breaks if daphne is not first

```python
# Without 'daphne' first:
$ python manage.py runserver
# → Django starts the built-in WSGI server
# → WebSocket does not work (WSGI does not support WS)
# → No error at all — WS connections simply aren't established

# With 'daphne' first:
$ python manage.py runserver
# → Daphne overrides runserver → starts the ASGI server
# → WebSocket works
```

If `daphne` is not placed first, Django may load a different `runserver` implementation before Daphne gets a chance to override it. The order in `INSTALLED_APPS` determines the order in which management commands are registered.

### In production daphne is not required

```python
# In Docker (production) we use uvicorn directly:
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001

# → daphne first in INSTALLED_APPS is only needed for the local runserver
# → In production uvicorn is started directly, bypassing manage.py
```

### ASGI_APPLICATION instead of WSGI_APPLICATION

```python
# settings.py — Channels requires ASGI_APPLICATION
ASGI_APPLICATION = 'notes_project.asgi.application'

# (WSGI_APPLICATION can stay for compatibility, but Channels uses ASGI_APPLICATION)
```

---

## InMemoryChannelLayer vs RedisChannelLayer

### InMemoryChannelLayer (dev / tests)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

| Property | InMemoryChannelLayer |
|-------------|---------------------|
| Dependencies | None (built into channels) |
| Scaling | A single process only |
| Persistence | Lost on restart |
| Suitable for | Local development, unit tests |

**InMemory limitation:** with several Uvicorn workers, each one has its own InMemoryChannelLayer. Consumers in different workers do not see each other's messages.

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

| Property | RedisChannelLayer |
|-------------|------------------|
| Dependencies | A Redis server, the `channels_redis` package |
| Scaling | Unlimited (Redis shared between workers) |
| Persistence | Messages persist in Redis until delivered |
| Suitable for | Production, Docker Compose |

---

## CHANNEL_LAYERS configuration in settings.py

notes_chat_app automatically picks the channel layer depending on `REDIS_URL`:

```python
# notes_project/settings.py

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
    # Local dev (no Redis): InMemoryChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }
```

---

## Redis DB 0 for Channels

In the setting `"address": "redis://redis:6379/0"`, the `0` is the Redis database index.

```
Redis DB split (the default convention in notes_chat_app):
  redis://redis:6379/0  ← Django Channels (channel layer)
  redis://redis:6379/1  ← Celery (broker, if configured)

Why separate DBs?
  - Isolation: flushing the Celery queue will not touch WS messages
  - Debugging: redis-cli -n 0 KEYS '*' shows only the channels data
  - By default Redis has 16 DBs (0–15)
```

---

## socket_timeout=None: fixing TimeoutError on an idle WebSocket

### The problem

```
channels_redis default: socket_timeout=5 (5 seconds)
channels_redis uses Redis BRPOP with timeout=5

On an idle WebSocket (nobody writes for > 5 sec):
  BRPOP timeout → channels_redis raises TimeoutError
  → The Consumer gets an exception → the WS connection is closed
  → The user sees: "Connection lost"
```

### The solution

```python
"CONFIG": {
    "hosts": [{
        "address": _REDIS_URL,
        "socket_timeout": None,          # ← None = no timeout, BRPOP waits indefinitely
        "socket_connect_timeout": 5,     # ← timeout only for establishing the connection (5 sec)
        "health_check_interval": 30,     # ← ping Redis every 30 sec (keeps the connection alive)
    }],
}
```

**Why this is safe:**
- `socket_timeout=None` — aioredis has no socket timeout for read operations
- BRPOP can wait indefinitely without an error
- `health_check_interval=30` — a ping every 30 sec so the connection to Redis doesn't silently "die"
- nginx `proxy_read_timeout=300s` — nginx will not close the WS earlier than 5 minutes

### Detailed explanation

```
With socket_timeout=5 (the default):
  channels_redis opens an aioredis connection
  channels_redis calls BRPOP (block and pop) on Redis
  BRPOP waits for a new message...
  
  If there are no messages for 5 seconds:
    aioredis: socket timeout expired → raises TimeoutError
    channels_redis: does not handle it → the exception propagates up
    Consumer: gets an unhandled exception → disconnect
    Browser: WS close code 1006 (abnormal closure)
    JS client: "Connection lost" → will try to reconnect

With socket_timeout=None:
  BRPOP waits indefinitely
  health_check_interval=30: a ping every 30 sec → keeps the Redis connection alive
  No spurious disconnects → the WS connection is stable
```

!!! note "The Redis timeout fix in notes_chat_app"
    This fix is applied in `notes_project/settings.py`; see the comment next to `CHANNEL_LAYERS`.
    `socket_timeout=None` in the `RedisChannelLayer CONFIG` fixes `TimeoutError` on idle WebSocket connections.

---

## Full settings check

```python
# Check in the Django shell:
docker compose exec web python manage.py shell

>>> from channels.layers import get_channel_layer
>>> layer = get_channel_layer()
>>> print(type(layer).__name__)
# Expected: RedisChannelLayer (if REDIS_URL is set)
# or:       InMemoryChannelLayer (if REDIS_URL is missing)

>>> import asyncio
>>> asyncio.run(layer.send('test-channel', {'type': 'test'}))
# If there is an exception — Redis is unavailable or the configuration is wrong
```

---

## Full configuration: routing.py and asgi.py

> **Why:** Channels is not just settings. You also need a WebSocket URL router and an ASGI application.

```python
# notes_project/routing.py — WebSocket URL patterns
from django.urls import re_path
from notes_app import consumers

websocket_urlpatterns = [
    # group_pk → scope['url_route']['kwargs']['group_pk'] in the consumer
    re_path(r'^ws/groups/(?P<group_pk>\d+)/chat/$', consumers.GroupChatConsumer.as_asgi()),
]
```

```python
# notes_project/asgi.py (without the long comments)
import os
from django.core.asgi import get_asgi_application
from django.contrib.staticfiles.handlers import ASGIStaticFilesHandler

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: django.setup() via get_asgi_application() BEFORE app-level imports!
# If you import consumers BEFORE this call → AppRegistryNotReady
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → the standard Django ASGI handler (+ /static/ via ASGIStaticFilesHandler)
    "http": ASGIStaticFilesHandler(django_asgi_app),

    # WebSocket → AuthMiddlewareStack → URLRouter → Consumer
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

**What each middleware does:**

| Middleware | Role |
|-----------|------|
| `AllowedHostsOriginValidator` | Rejects WS connections whose Origin is not in `ALLOWED_HOSTS` (**not** used in the project; see below) |
| `AuthMiddlewareStack` | Reads the session cookie → populates `scope["user"]` |
| `URLRouter` | Routes the URL `/ws/groups/7/chat/` to `GroupChatConsumer` |

The real `asgi.py` has no `AllowedHostsOriginValidator`. For production it is worth adding as protection against Cross-Site WebSocket Hijacking: `"websocket": AllowedHostsOriginValidator(AuthMiddlewareStack(URLRouter(websocket_urlpatterns)))` (imported from `channels.security.websocket`).

---

## Debugging: why the WebSocket does not connect

### Step 1 — Browser DevTools → Network → WS

```
F12 → Network tab → "WS" filter
Open the chat page.

What to look for:
1. Did a WebSocket request appear in the list?
   ─ It did NOT appear → JS does not call new WebSocket(...)
                        → check whether group_chat.js is included
   ─ It appeared → click on it → Status → Messages

2. Status 101 Switching Protocols → WS established ✓
3. Status 403 → the consumer called close() before accept() (not logged in
                or not a group member); with AllowedHostsOriginValidator, also a foreign Origin
4. Status 404 → URL not found → check routing.py
5. Status 500 → error in the Consumer or asgi.py → check the logs
```

**The Messages tab in DevTools:**
```
▲ sent   → {"content": "Hi"}   (JavaScript → server)
▼ receive → {"type": "message", "message_id": 42, "author": "alice", "content": "Hi", "timestamp": "..."}  (server → browser)
```

### Step 2 — Django/Uvicorn logs

```bash
# View the logs in real time:
docker compose logs -f web

# Typical messages for a successful WS:
# INFO    WebSocket CONNECT /ws/groups/7/chat/ [127.0.0.1:54321]
# INFO    WebSocket DISCONNECT /ws/groups/7/chat/ [127.0.0.1:54321]

# AuthMiddlewareStack error:
# ERROR   Exception inside application: ...
# → check the import order in asgi.py (django.setup() first!)
```

### Step 3 — Check the channel layer

```bash
docker compose exec web python manage.py shell
```

```python
from channels.layers import get_channel_layer
import asyncio

layer = get_channel_layer()
print(type(layer).__name__)
# → RedisChannelLayer (if REDIS_URL is set)
# → InMemoryChannelLayer (if REDIS_URL is missing)

# Send/receive test:
async def test_layer():
    await layer.send('test-ch', {'type': 'hello'})
    msg = await layer.receive('test-ch')
    print(msg)  # → {'type': 'hello'}

asyncio.run(test_layer())
# If TimeoutError or ConnectionRefusedError → Redis is unavailable
```

---

## nginx: WebSocket headers — required settings

If Django Channels runs behind nginx (Docker production), nginx must pass the WebSocket Upgrade headers. **Without them**, the WS handshake will fail even if Django is configured correctly.

```nginx
# nginx/nginx.conf

http {
    # ── WebSocket Upgrade mapping ─────────────────────────────────────────────
    # $http_upgrade = the "Upgrade" header from the browser ("websocket" or "")
    # If Upgrade: websocket → $connection_upgrade = "upgrade"
    # If plain HTTP → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    upstream django {
        server web:8001;   # "web" — the DNS name of the Django container
    }

    server {
        listen 80;

        location / {
            proxy_pass http://django;

            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (critical!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WS requires HTTP/1.1 (keep-alive).
            #   Without it nginx downgrades → HTTP/1.0 → Upgrade is ignored
            #   → WS handshake fails → browser 400 or 101 followed by an immediate close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ Pass Upgrade: websocket and Connection: upgrade on to Uvicorn
            #   Uvicorn sees these headers → switches protocol → ASGI WS scope

            proxy_read_timeout 300s;   # WS can live for 5 minutes without activity
            proxy_connect_timeout 75s;
            proxy_send_timeout 300s;
        }
    }
}
```

**What breaks without `proxy_http_version 1.1`:**
```
Browser: WebSocket Error: Connection closed before receiving a handshake response
nginx log: 400 Bad Request (WS Upgrade rejected)
```

---

## Common errors table

| Symptom | Cause | Solution |
|---------|---------|---------|
| WS connection 404 | routing.py is not wired in or the URL pattern is wrong | Check `websocket_urlpatterns` and the URL in the JS |
| WS connection 403 | The consumer rejected the handshake (not logged in or not a group member); or `AllowedHostsOriginValidator` rejects the Origin, if it was added | Log in / check the membership; for the validator, add the hostname to `ALLOWED_HOSTS` |
| `AppRegistryNotReady` in asgi.py | consumers imported before `get_asgi_application()` | Move the imports after `django_asgi_app = get_asgi_application()` |
| WebSocket does not work (HTTP OK) | `daphne` is not first in `INSTALLED_APPS` | Move `'daphne'` to the first position |
| `TimeoutError` after idling | `socket_timeout=5` in RedisChannelLayer | Set `socket_timeout=None` |
| Chat does not sync between tabs | `InMemoryChannelLayer` instead of Redis | Check `REDIS_URL`, switch to RedisChannelLayer |
| nginx: `Connection closed before handshake` | Missing `proxy_http_version 1.1` or Upgrade headers | Add all 4 WebSocket proxy directives |
| `ASGI_APPLICATION` not found | Wrong path in settings.py | `ASGI_APPLICATION = 'notes_project.asgi.application'` |
| WebSocket 101 but the chat is silent | The channel group is split across processes | InMemoryChannelLayer in multi-worker mode: each worker has its own memory |

---

## In the book

- [Part IX. Async and Real-Time](../../09_async_and_realtime/README.md) — the asyncio event loop, coroutines, `async def`, `await`, when to use async vs sync, Django Channels architecture

---

## Official documentation

- [Django Channels: Installation](https://channels.readthedocs.io/en/latest/installation.html) — INSTALLED_APPS, ASGI_APPLICATION
- [Django Channels: Channel Layers](https://channels.readthedocs.io/en/latest/topics/channel_layers.html) — InMemory vs Redis, configuration
- [channels_redis: docs](https://github.com/django/channels_redis) — CONFIG parameters, socket_timeout
- [Django: ASGI deployment](https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/) — asgi.py, ProtocolTypeRouter
- [nginx: WebSocket proxying](https://nginx.org/en/docs/http/websocket.html) — proxy_http_version, Upgrade headers

---

## Next

Next chapter: **[7B. Consumer](7b_consumer.md)** — the `GroupChatConsumer` lifecycle, `database_sync_to_async`, broadcasting through the channel layer.
