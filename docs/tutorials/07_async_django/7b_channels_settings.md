# 7B. Channel Layers і Daphne

---

## Daphne: чому перший у INSTALLED_APPS

Daphne — ASGI сервер від команди Django Channels. Він перехоплює команду `python manage.py runserver` і замінює вбудований WSGI-сервер на ASGI-сервер.

```python
# notes_project/settings.py
INSTALLED_APPS = [
    'daphne',        # ← ПЕРШИЙ у списку! Обов'язково перед 'django.contrib.*'
    'channels',      # Django Channels
    'django.contrib.admin',
    # ... решта apps
    'notes_app',
]
```

### Що ламається якщо daphne не перший

```python
# Без 'daphne' першим:
$ python manage.py runserver
# → Django запускає вбудований WSGI сервер
# → WebSocket не працює (WSGI не підтримує WS)
# → Ніякої помилки — просто WS з'єднання не встановлюються

# З 'daphne' першим:
$ python manage.py runserver
# → Daphne override runserver → запускає ASGI сервер
# → WebSocket працює
```

Якщо `daphne` розміщений не першим — Django може завантажити іншу реалізацію `runserver` до того, як Daphne встигне її перевизначити. Порядок у `INSTALLED_APPS` визначає порядок реєстрації management commands.

### У production daphne не обов'язковий

```python
# У Docker (production) використовуємо uvicorn напряму:
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001

# → daphne перший у INSTALLED_APPS потрібен тільки для локального runserver
# → У production uvicorn запускається безпосередньо, минаючи manage.py
```

### ASGI_APPLICATION замість WSGI_APPLICATION

```python
# settings.py — для Channels потрібен ASGI_APPLICATION
ASGI_APPLICATION = 'notes_project.asgi.application'

# (WSGI_APPLICATION може залишитись для сумісності, але Channels використовує ASGI_APPLICATION)
```

---

## InMemoryChannelLayer vs RedisChannelLayer

### InMemoryChannelLayer (dev / тести)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

| Властивість | InMemoryChannelLayer |
|-------------|---------------------|
| Залежності | Жодних (вбудований у channels) |
| Масштабування | Тільки один process |
| Персистентність | Зникає при restart |
| Підходить для | Локальна розробка, unit тести |

**Обмеження InMemory:** при кількох Uvicorn workers — кожен має свій InMemoryChannelLayer. Consumers у різних workers не бачать повідомлення одне одного.

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

| Властивість | RedisChannelLayer |
|-------------|------------------|
| Залежності | Redis сервер, `channels_redis` пакет |
| Масштабування | Необмежено (shared Redis між workers) |
| Персистентність | Messages персистентні в Redis до доставки |
| Підходить для | Production, Docker Compose |

---

## CHANNEL_LAYERS конфігурація у settings.py

notes_chat_app автоматично обирає channel layer залежно від `REDIS_URL`:

```python
# notes_project/settings.py

# Channel Layer — вибір залежно від середовища
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    # Docker / Production: RedisChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    # socket_timeout=None — КРИТИЧНО для idle WS з'єднань
                    # Без цього channels_redis встановлює socket_timeout=5
                    # і brpop_timeout=5 конфліктують → TimeoutError після простою
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # Перевіряє Redis кожні 30 сек — запобігає silent disconnect
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Local dev (без Redis): InMemoryChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }
```

---

## Redis DB 0 для Channels

В налаштуванні `"address": "redis://redis:6379/0"` — `0` означає Redis database index.

```
Redis БД поділ (умова за замовчуванням у notes_chat_app):
  redis://redis:6379/0  ← Django Channels (channel layer)
  redis://redis:6379/1  ← Celery (broker, якщо налаштовано)

Чому окремі БД?
  - Ізоляція: очищення Celery черги не торкнеться WS-повідомлень
  - Дебаг: redis-cli -n 0 KEYS '*' показує тільки channels дані
  - За замовчуванням Redis має 16 БД (0–15)
```

---

## socket_timeout=None: вирішення TimeoutError при idle WebSocket

### Проблема

```
channels_redis за замовчуванням: socket_timeout=5 (5 секунд)
channels_redis використовує Redis BRPOP з timeout=5

При idle WebSocket (ніхто не пише > 5 сек):
  BRPOP timeout → channels_redis піднімає TimeoutError
  → Consumer отримує exception → WS з'єднання закривається
  → Юзер бачить: "З'єднання втрачено"
```

### Рішення

```python
"CONFIG": {
    "hosts": [{
        "address": _REDIS_URL,
        "socket_timeout": None,          # ← None = немає timeout, BRPOP чекає необмежено
        "socket_connect_timeout": 5,     # ← timeout лише для встановлення з'єднання (5 сек)
        "health_check_interval": 30,     # ← ping Redis кожні 30 сек (підтримує з'єднання)
    }],
}
```

**Чому це безпечно:**
- `socket_timeout=None` — aioredis не має socket timeout для операцій читання
- BRPOP може чекати необмежено без помилки
- `health_check_interval=30` — ping кожні 30 сек щоб з'єднання з Redis не "померло" тихо
- nginx `proxy_read_timeout=300s` — nginx не закриє WS раніше 5 хвилин

### Детальне пояснення

```
З socket_timeout=5 (за замовчуванням):
  channels_redis відкриває aioredis з'єднання
  channels_redis викликає BRPOP (block and pop) на Redis
  BRPOP чекає нове повідомлення...
  
  Якщо 5 секунд немає повідомлень:
    aioredis: socket timeout expired → підіймає TimeoutError
    channels_redis: не обробляє → exception піднімається вище
    Consumer: отримує unhandled exception → disconnect
    Браузер: WS close code 1006 (аварійне закриття)
    JS клієнт: "З'єднання втрачено" → спробує перепідключитись

З socket_timeout=None:
  BRPOP чекає необмежено
  health_check_interval=30: кожні 30 сек ping → підтримує з'єднання з Redis живим
  Немає spurious disconnects → WS з'єднання стабільне
```

!!! note "Redis timeout fix — зафіксовано в пам'яті проєкту"
    Ця проблема задокументована у `/home/niko_notebook/.claude/projects/.../memory/redis_timeout_fix.md`.
    `socket_timeout=None` у `RedisChannelLayer CONFIG` вирішує `TimeoutError` при idle WebSocket з'єднаннях.

---

## Повна перевірка налаштувань

```python
# Перевір у Django shell:
docker compose exec web python manage.py shell

>>> from channels.layers import get_channel_layer
>>> layer = get_channel_layer()
>>> print(type(layer).__name__)
# Очікуємо: RedisChannelLayer (якщо REDIS_URL є)
# або:       InMemoryChannelLayer (якщо REDIS_URL відсутній)

>>> import asyncio
>>> asyncio.run(layer.send('test-channel', {'type': 'test'}))
# Якщо виняток — Redis недоступний або конфігурація неправильна
```

---

## Повна конфігурація: routing.py та asgi.py

> **Навіщо:** Канали — це не просто settings. Потрібен ще маршрутизатор WebSocket URL і ASGI application.

```python
# notes_project/routing.py — WebSocket URL patterns
from django.urls import re_path
from notes_app import consumers

websocket_urlpatterns = [
    re_path(r'^ws/groups/(?P<group_id>\d+)/chat/$', consumers.GroupChatConsumer.as_asgi()),
]
```

```python
# notes_project/asgi.py
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# КРИТИЧНО: django.setup() через get_asgi_application() ПЕРЕД імпортами app-рівня!
# Якщо імпортувати consumers ДО цього виклику → AppRegistryNotReady
from django.core.asgi import get_asgi_application
django_asgi_app = get_asgi_application()

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator

from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → стандартний Django ASGI handler
    "http": django_asgi_app,

    # WebSocket → AuthMiddlewareStack → URLRouter → Consumer
    "websocket": AllowedHostsOriginValidator(
        AuthMiddlewareStack(
            URLRouter(websocket_urlpatterns)
        )
    ),
})
```

**Що кожен middleware робить:**

| Middleware | Роль |
|-----------|------|
| `AllowedHostsOriginValidator` | Відхиляє WS з Origin що не в `ALLOWED_HOSTS` |
| `AuthMiddlewareStack` | Читає session cookie → заповнює `scope["user"]` |
| `URLRouter` | Маршрутизує URL `/ws/groups/7/chat/` до `GroupChatConsumer` |

---

## Debugging: чому WebSocket не підключається

### Крок 1 — Browser DevTools → Network → WS

```
F12 → вкладка Network → фільтр "WS"
Відкрий чат-сторінку.

Що шукати:
1. Чи з'явився WebSocket запит у списку?
   ─ НЕ з'явився → JS не викликає new WebSocket(...)
                  → перевір group_chat.js чи підключений
   ─ З'явився → кліки на нього → Status → Messages

2. Status 101 Switching Protocols → WS встановлений ✓
3. Status 403 → AllowedHostsOriginValidator відхилила
4. Status 404 → URL не знайдений → перевір routing.py
5. Status 500 → помилка в Consumer або asgi.py → перевір логи
```

**Вкладка Messages у DevTools:**
```
▲ sent   → {"type": "chat_message", "message": "Привіт"}   (JavaScript → сервер)
▼ receive → {"type": "chat_message", "message": "Привіт", "username": "alice"}  (сервер → браузер)
```

### Крок 2 — Логи Django/Uvicorn

```bash
# Переглянути логи в реальному часі:
docker compose logs -f web

# Типові повідомлення при успішному WS:
# INFO    WebSocket CONNECT /ws/groups/7/chat/ [127.0.0.1:54321]
# INFO    WebSocket DISCONNECT /ws/groups/7/chat/ [127.0.0.1:54321]

# Помилка AuthMiddlewareStack:
# ERROR   Exception inside application: ...
# → перевір порядок імпортів в asgi.py (django.setup() перший!)
```

### Крок 3 — Перевірити channel layer

```bash
docker compose exec web python manage.py shell
```

```python
from channels.layers import get_channel_layer
import asyncio

layer = get_channel_layer()
print(type(layer).__name__)
# → RedisChannelLayer (якщо REDIS_URL є)
# → InMemoryChannelLayer (якщо REDIS_URL відсутній)

# Тест відправки/отримання:
async def test_layer():
    await layer.send('test-ch', {'type': 'hello'})
    msg = await layer.receive('test-ch')
    print(msg)  # → {'type': 'hello'}

asyncio.run(test_layer())
# Якщо TimeoutError або ConnectionRefusedError → Redis недоступний
```

---

## nginx: WebSocket headers — обов'язкові налаштування

Якщо Django Channels запускається за nginx (Docker production) — nginx мусить передавати WebSocket Upgrade headers. **Без цього** — WS handshake провалиться навіть якщо Django налаштований правильно.

```nginx
# nginx/nginx.conf

http {
    # ── WebSocket Upgrade mapping ─────────────────────────────────────────────
    # $http_upgrade = заголовок "Upgrade" від браузера ("websocket" або "")
    # Якщо Upgrade: websocket → $connection_upgrade = "upgrade"
    # Якщо звичайний HTTP → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    upstream django {
        server web:8001;   # "web" — DNS ім'я Django-контейнера
    }

    server {
        listen 80;

        location / {
            proxy_pass http://django;

            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (критично!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WS вимагає HTTP/1.1 (keep-alive).
            #   Без цього nginx downgrade → HTTP/1.0 → Upgrade ігнорується
            #   → WS handshake fails → браузер 400 або 101 потім одразу close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ Передаємо Upgrade: websocket і Connection: upgrade до Uvicorn
            #   Uvicorn бачить ці заголовки → перемикає протокол → ASGI WS scope

            proxy_read_timeout 300s;   # WS може жити 5 хвилин без активності
            proxy_connect_timeout 75s;
            proxy_send_timeout 300s;
        }
    }
}
```

**Що ламається без `proxy_http_version 1.1`:**
```
Браузер: WebSocket Error: Connection closed before receiving a handshake response
nginx лог: 400 Bad Request (WS Upgrade rejected)
```

---

## Таблиця типових помилок

| Симптом | Причина | Рішення |
|---------|---------|---------|
| WS з'єднання 404 | routing.py не підключений або неправильний URL pattern | Перевір `websocket_urlpatterns` і URL у JS |
| WS з'єднання 403 | `AllowedHostsOriginValidator` відхиляє Origin | Додати hostname до `ALLOWED_HOSTS` |
| `AppRegistryNotReady` в asgi.py | Імпорт consumers перед `get_asgi_application()` | Перенести імпорти після `django_asgi_app = get_asgi_application()` |
| WebSocket не працює (HTTP OK) | `daphne` не перший у `INSTALLED_APPS` | Перемістити `'daphne'` першим |
| `TimeoutError` після простою | `socket_timeout=5` у RedisChannelLayer | Встановити `socket_timeout=None` |
| Чат не синхронізується між вкладками | `InMemoryChannelLayer` замість Redis | Перевірити `REDIS_URL`, перейти на RedisChannelLayer |
| nginx: `Connection closed before handshake` | Відсутні `proxy_http_version 1.1` або Upgrade headers | Додати всі 4 WebSocket proxy директиви |
| `ASGI_APPLICATION` not found | Неправильний шлях у settings.py | `ASGI_APPLICATION = 'notes_project.asgi.application'` |
| WebSocket 101 але чат мовчить | Channel group розходиться між processes | InMemoryChannelLayer у multi-worker: кожен worker — своя пам'ять |

---

## У книзі

- [Частина IX. Async і Real-Time](../../09_async_and_realtime/README.md) — asyncio event loop, coroutines, `async def`, `await`, коли async vs sync, Django Channels архітектура

---

## Офіційна документація

- [Django Channels: Installation](https://channels.readthedocs.io/en/latest/installation.html) — INSTALLED_APPS, ASGI_APPLICATION
- [Django Channels: Channel Layers](https://channels.readthedocs.io/en/latest/topics/channel_layers.html) — InMemory vs Redis, конфігурація
- [channels_redis: docs](https://github.com/django/channels_redis) — CONFIG параметри, socket_timeout
- [Django: ASGI deployment](https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/) — asgi.py, ProtocolTypeRouter
- [nginx: WebSocket proxying](https://nginx.org/en/docs/http/websocket.html) — proxy_http_version, Upgrade headers

---

## Далі

Наступна глава: **[7B. Consumer](7b_consumer.md)** — lifecycle `GroupChatConsumer`, `database_sync_to_async`, broadcast через channel layer.
