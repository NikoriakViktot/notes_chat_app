# WSGI vs ASGI — практичний розбір

> WSGI достатній для sync HTTP Django. ASGI потрібний для WebSocket і async runtime.
> У `notes_chat_app` обидва протоколи існують паралельно в одному процесі Uvicorn.

---

## Коротка різниця

| | WSGI | ASGI |
|--|------|------|
| **Стандарт** | PEP 3333 (2010) | PEP 3333 наступник (2019) |
| **Протоколи** | Тільки HTTP | HTTP + WebSocket + HTTP/2 |
| **Виконання** | Синхронне (блокуючий I/O) | Асинхронне (asyncio event loop) |
| **Файл у проєкті** | `notes_project/wsgi.py` | `notes_project/asgi.py` |
| **Сервер** | Gunicorn, uWSGI | Uvicorn, Daphne |
| **Підходить для** | CRUD, форми, авторизація | + WebSocket, real-time, streaming |

---

## Де знайти у проєкті

### `notes_project/wsgi.py`

```python
# notes_project/wsgi.py
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

application = get_wsgi_application()
# ↑ Стандартний Django WSGI callable
# Використовується якщо запускати через Gunicorn:
#   gunicorn notes_project.wsgi:application
#
# У notes_chat_app цей файл НЕ використовується в production —
# ми використовуємо asgi.py і Uvicorn.
# Файл залишений для сумісності (деякі платформи шукають wsgi.py)
```

**Що в ньому:** один рядок реального коду — `application = get_wsgi_application()`.
Це callable, який приймає `environ` dict і `start_response` функцію. Ніколи не чіпати без потреби.

### `notes_project/asgi.py`

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: ПЕРШИЙ рядок до будь-яких імпортів з notes_app
django_asgi_app = get_asgi_application()

# Після get_asgi_application() — безпечно імпортувати models, consumers
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    "http": django_asgi_app,          # HTTP → звичайний Django
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)  # WebSocket → Consumer
    ),
})
```

**Що тут змінювати:**
- Додати новий протокол (наприклад, `"lifespan"`) — дуже рідко
- Змінити `AuthMiddlewareStack` на власний middleware — якщо потрібна кастомна авторизація WS

**Що НЕ змінювати:**
- Порядок: `get_asgi_application()` завжди першим
- `ProtocolTypeRouter` — структура обов'язкова для Channels

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

**Що тут змінювати:**
- Додати новий WebSocket URL → новий рядок у `websocket_urlpatterns`
- Змінити URL pattern → відредагувати regex
- Підключити новий Consumer → `consumers.NewConsumer.as_asgi()`

**Не плутати з `notes_app/urls.py`** — той для HTTP URL, цей для WebSocket URL.

### `notes_project/settings.py` — ключові параметри

```python
# settings.py — що стосується ASGI:

INSTALLED_APPS = [
    'daphne',     # ← ПЕРШИЙ: override runserver → ASGI
    'channels',   # ← Django Channels framework
    # ...
]

# Вказує який ASGI callable використовувати:
ASGI_APPLICATION = 'notes_project.asgi.application'
# ↑ Змінюй тільки якщо перейменував asgi.py або переніс у інший пакет

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
# ↑ Змінюй: адресу Redis, параметри timeout
```

---

## Як це запускається у Docker

```
entrypoint.sh:
  exec python -m uvicorn notes_project.asgi:application \
      --host 0.0.0.0 --port 8001

Uvicorn:
  → завантажує notes_project/asgi.py
  → отримує application = ProtocolTypeRouter({...})

При HTTP запиті від nginx:
  ProtocolTypeRouter: protocol = "http"
  → передає до django_asgi_app (views, urls, templates)

При WebSocket від nginx (Upgrade: websocket):
  ProtocolTypeRouter: protocol = "websocket"
  → AuthMiddlewareStack → URLRouter → GroupChatConsumer
```

---

## Коли що змінювати

| Задача | Файл | Що робити |
|--------|------|-----------|
| Додати новий HTTP URL | `notes_app/urls.py` | `path(...)` у `urlpatterns` |
| Додати новий WebSocket URL | `notes_project/routing.py` | `re_path(...)` у `websocket_urlpatterns` |
| Додати новий Consumer | `notes_app/consumers.py` | Новий клас + `routing.py` |
| Змінити Redis конфіг | `notes_project/settings.py` | `CHANNEL_LAYERS["CONFIG"]` |
| Змінити middleware для WS | `notes_project/asgi.py` | Змінити `AuthMiddlewareStack(...)` |
| Додати lifespan events | `notes_project/asgi.py` | `"lifespan": ...` у `ProtocolTypeRouter` |
| Змінити WSGI (для gunicorn) | `notes_project/wsgi.py` | Рідко потрібно |

---

## Практичне завдання

```bash
# Запусти стек:
docker compose up -d

# 1. Переконайся що ASGI працює:
docker compose logs web | grep "Uvicorn running"

# 2. Відкрий чат у DevTools → Network → WS
# Переконайся що WS з'єднання встановлюється (101 Switching Protocols)

# 3. Переглянь asgi.py та routing.py:
docker compose exec web cat notes_project/asgi.py
docker compose exec web cat notes_project/routing.py
```

---

## Далі

Детальніше про Channels, async consumers і WebSocket:
- [07 — Async та WebSocket чат](../tutorials/07_async.md)
- [Async and Realtime](../09_async_and_realtime/README.md)
