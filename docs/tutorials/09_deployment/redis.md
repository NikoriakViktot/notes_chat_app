# Redis і Channel Layer

> **Проблема InMemoryChannelLayer:** він зберігає повідомлення в RAM одного процесу.
> Якщо запустити 2 uvicorn workers — вони не бачать один одного → broadcast не дійде.
> Redis channel layer вирішує це через shared pub/sub.

---

## Як RedisChannelLayer реалізує broadcast

```
Worker 1 (Consumer Віктора)          Worker 2 (Consumer Олі)
┌────────────────────────┐           ┌────────────────────────┐
│  group_send(            │           │                        │
│    "chat_group_7", ... │──────────►│  Redis pub/sub         │
│  )                      │           │  channel: chat_group_7 │
└────────────────────────┘           │         │              │
                                     │         ▼              │
                                     │  chat_message()        │
                                     │  send() → браузер Олі  │
                                     └────────────────────────┘

Redis як shared message broker:
  Publish: Consumer Віктора → Redis LPUSH chat_group_7_msgs ...
  Subscribe: Consumer Олі  ← Redis BRPOP chat_group_7_msgs
```

Коли Віктор надсилає повідомлення, його Consumer викликає `group_send()` — публікує подію в Redis. Всі Consumer-и підписані на канал групи отримують подію і надсилають повідомлення до своїх браузерів. Оля бачить повідомлення Віктора в реальному часі навіть якщо їхні Consumer-и запущені на різних uvicorn processes.

---

## Налаштування channel layer

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
                    # socket_timeout=None: без обмеження на читання
                    # (важливо для довготривалих WS з'єднань!)
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # health_check_interval: Redis пінгує кожні 30 сек
                    # щоб виявити і відновити обірвані з'єднання
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Локальний dev без Docker — InMemory (одночасно один процес)
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }
```

`REDIS_URL` у `docker-compose.yml`:

```yaml
web:
  environment:
    REDIS_URL: redis://redis:6379/0
    #                   ↑      ↑  ↑
    #           DNS ім'я   порт  DB index
```

- `redis` — DNS ім'я сервісу у Docker мережі `app-net`
- `6379` — стандартний порт Redis
- `/0` — database index (Redis підтримує 16 баз, 0–15)

---

## Redis DB 0 vs DB 1 — чому різні

У цьому проєкті використовується тільки Redis DB `0`. В проєктах з Celery часто виділяють окремі бази:

```
Redis DB 0 → Channels (WebSocket pub/sub)
  REDIS_URL=redis://redis:6379/0
  → CHANNEL_LAYERS config → channels_redis

Redis DB 1 → Celery (task queue) — якщо б Celery використовувався
  CELERY_BROKER_URL=redis://redis:6379/1
  → celery.app.conf.broker_url
```

Розділення запобігає конфліктам ключів між різними системами, що пишуть у той самий Redis.

---

## `socket_timeout=None` — вирішення TimeoutError

**Симптом:** nginx лог показує `101` (WS upgrade), потім через хвилину:

```
"Exception in ASGI application → TimeoutError reading from redis:6379"
```

**Причина:**

```
GroupChatConsumer.receive()
  → channel_layer.group_send()   ← публікує в Redis
  → channel_layer підписується на відповідь

Redis відповідає через brpop_timeout=5 секунд
Але якщо socket_timeout=5 (або менше) у Redis client:
  client-side timeout < server brpop timeout
  → redis.exceptions.TimeoutError
  → ASGI application ERROR
  → WebSocket з'єднання падає
```

**Рішення:**

```python
"socket_timeout": None,   # читання без обмеження часу
```

`brpop_timeout` на сервері (5 сек) є природним лімітом — після цього часу якщо немає нових повідомлень, сервер повертає `None` і loop повторюється. `socket_timeout=None` означає що TCP-сокет не закривається від клієнта після певного часу очікування.

---

## daphne перший у INSTALLED_APPS

```python
# settings.py
INSTALLED_APPS = [
    'daphne',    # ← ПЕРШИМ! Override runserver → ASGI замість WSGI
    'channels',
    'django.contrib.admin',
    # ...
    'notes_app',
]

ASGI_APPLICATION = 'notes_project.asgi.application'
```

**Що відбувається якщо daphne НЕ перший:**

```bash
python manage.py runserver
# → Django використовує вбудований WSGI server
# → WebSocket URL /ws/... → 404
# → GroupChatConsumer недосяжний
# → Груповий чат не працює

python manage.py runserver
# + daphne перший:
# → daphne override runserver command
# → ASGI server з asyncio event loop
# → WebSocket + HTTP одночасно ✓
```

`daphne` перехоплює команду `manage.py runserver` і запускає ASGI development server замість стандартного WSGI. Це необхідно для локальної розробки з WebSocket. У Docker production використовується `uvicorn` напряму через `entrypoint.sh` — `daphne` там не бере участі в запуску, але має залишатись першим у `INSTALLED_APPS` для сумісності.

---

## Перевірка Redis у Docker

```bash
# Підключитись до Redis напряму:
docker compose exec redis redis-cli

# Корисні команди у redis-cli:
KEYS *            # всі ключі (обережно на великих БД!)
TYPE <key>        # тип ключа (string, list, set, zset, hash)
TTL <key>         # TTL ключа (-1 = без обмеження, -2 = не існує)
MONITOR           # live stream всіх команд до Redis (Ctrl+C щоб зупинити)

# Перевірити активні channel layer ключі:
KEYS asgi.*
# asgi.* — префікс channels_redis

---

## У книзі

- [Частина IX. Async і Realtime](../../09_async_and_realtime/README.md) — Django Channels, channel layers, WebSocket, InMemory vs Redis channel layer, pub/sub архітектура
- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker мережі, Redis у Docker

---

## Офіційна документація

- [Django Channels: Channel layers](https://channels.readthedocs.io/en/latest/topics/channel_layers.html) — Redis channel layer, group_send, group_add
- [channels-redis: Configuration](https://github.com/django/channels_redis) — `socket_timeout`, `health_check_interval`, hosts config
- [Redis: Commands reference](https://redis.io/docs/latest/commands/) — KEYS, TYPE, TTL, MONITOR, LPUSH, BRPOP
- [Redis: Pub/Sub](https://redis.io/docs/latest/develop/interact/pubsub/) — publish/subscribe механізм
- [redis-py: Connection pools](https://redis-py.readthedocs.io/en/stable/connections.html) — socket_timeout, socket_connect_timeout
```
