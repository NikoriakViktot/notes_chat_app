# Redis and the Channel Layer

> **The InMemoryChannelLayer problem:** it keeps messages in the RAM of a single process.
> If you run 2 uvicorn workers, they cannot see each other → a broadcast will not get through.
> The Redis channel layer solves this with shared pub/sub.

---

## How RedisChannelLayer implements broadcast

```
Worker 1 (Viktor's Consumer)         Worker 2 (Olia's Consumer)
┌────────────────────────┐           ┌────────────────────────┐
│  group_send(            │           │                        │
│    "chat_group_7", ... │──────────►│  Redis pub/sub         │
│  )                      │           │  channel: chat_group_7 │
└────────────────────────┘           │         │              │
                                     │         ▼              │
                                     │  chat_message()        │
                                     │  send() → Olia's browser│
                                     └────────────────────────┘

Redis as a shared message broker:
  Publish: Viktor's Consumer → Redis LPUSH chat_group_7_msgs ...
  Subscribe: Olia's Consumer ← Redis BRPOP chat_group_7_msgs
```

When Viktor sends a message, his Consumer calls `group_send()`, which publishes an event to Redis. All Consumers subscribed to the group's channel receive the event and send the message to their browsers. Olia sees Viktor's message in real time even if their Consumers are running in different uvicorn processes.

---

## Configuring the channel layer

```python
# settings.py
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    # socket_timeout=None: no limit on reads
                    # (important for long-lived WS connections!)
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # health_check_interval: Redis is pinged every 30 sec
                    # to detect and recover broken connections
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Local dev without Docker — InMemory (a single process at a time)
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }
```

`REDIS_URL` in `docker-compose.yml`:

```yaml
web:
  environment:
    REDIS_URL: redis://redis:6379/0
    #                   ↑      ↑  ↑
    #           DNS name    port  DB index
```

- `redis` — the service's DNS name in the `app-net` Docker network
- `6379` — the standard Redis port
- `/0` — database index (Redis supports 16 databases, 0–15)

---

## Redis DB 0 vs DB 1 — why they differ

This project uses only Redis DB `0`. Projects with Celery often allocate separate databases:

```
Redis DB 0 → Channels (WebSocket pub/sub)
  REDIS_URL=redis://redis:6379/0
  → CHANNEL_LAYERS config → channels_redis

Redis DB 1 → Celery (task queue) — if Celery were used
  CELERY_BROKER_URL=redis://redis:6379/1
  → celery.app.conf.broker_url
```

The separation prevents key conflicts between different systems that write to the same Redis.

---

## `socket_timeout=None` — fixing TimeoutError

**Symptom:** the nginx log shows `101` (WS upgrade), then a minute later:

```
"Exception in ASGI application → TimeoutError reading from redis:6379"
```

**Cause:**

```
GroupChatConsumer.receive()
  → channel_layer.group_send()   ← publishes to Redis
  → channel_layer subscribes to the response

Redis responds using brpop_timeout=5 seconds
But if socket_timeout=5 (or less) in the Redis client:
  client-side timeout < server brpop timeout
  → redis.exceptions.TimeoutError
  → ASGI application ERROR
  → the WebSocket connection drops
```

**Solution:**

```python
"socket_timeout": None,   # reads without a time limit
```

`brpop_timeout` on the server (5 sec) is a natural limit: after that time, if there are no new messages, the server returns `None` and the loop repeats. `socket_timeout=None` means the TCP socket is not closed by the client after a certain waiting time.

---

## daphne first in INSTALLED_APPS

```python
# settings.py
INSTALLED_APPS = [
    'daphne',    # ← FIRST! Overrides runserver → ASGI instead of WSGI
    'channels',
    'django.contrib.admin',
    # ...
    'notes_app',
]

ASGI_APPLICATION = 'notes_project.asgi.application'
```

**What happens if daphne is NOT first:**

```bash
python manage.py runserver
# → Django uses the built-in WSGI server
# → WebSocket URL /ws/... → 404
# → GroupChatConsumer is unreachable
# → The group chat does not work

python manage.py runserver
# + daphne first:
# → daphne overrides the runserver command
# → ASGI server with an asyncio event loop
# → WebSocket + HTTP at the same time ✓
```

`daphne` intercepts the `manage.py runserver` command and starts an ASGI development server instead of the standard WSGI one. This is required for local development with WebSocket. In Docker production, `uvicorn` is used directly through `entrypoint.sh` — `daphne` takes no part in startup there, but it must stay first in `INSTALLED_APPS` for compatibility.

---

## Checking Redis in Docker

```bash
# Connect to Redis directly:
docker compose exec redis redis-cli

# Useful commands in redis-cli:
KEYS *            # all keys (careful on large DBs!)
TYPE <key>        # key type (string, list, set, zset, hash)
TTL <key>         # key TTL (-1 = no limit, -2 = does not exist)
MONITOR           # live stream of all commands sent to Redis (Ctrl+C to stop)

# Check active channel layer keys:
KEYS asgi.*
# asgi.* — the channels_redis prefix
```

---

## In the book

- [Part IX. Async and Realtime](../../09_async_and_realtime/README.md) — Django Channels, channel layers, WebSocket, InMemory vs Redis channel layer, pub/sub architecture
- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker networks, Redis in Docker

---

## Official documentation

- [Django Channels: Channel layers](https://channels.readthedocs.io/en/latest/topics/channel_layers.html) — Redis channel layer, group_send, group_add
- [channels-redis: Configuration](https://github.com/django/channels_redis) — `socket_timeout`, `health_check_interval`, hosts config
- [Redis: Commands reference](https://redis.io/docs/latest/commands/) — KEYS, TYPE, TTL, MONITOR, LPUSH, BRPOP
- [Redis: Pub/Sub](https://redis.io/docs/latest/develop/interact/pubsub/) — the publish/subscribe mechanism
- [redis-py: Connection pools](https://redis-py.readthedocs.io/en/stable/connections.html) — socket_timeout, socket_connect_timeout
