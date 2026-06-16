# 7B. ASGI стек

---

## WSGI vs ASGI

| | WSGI | ASGI |
|--|------|------|
| **Стандарт** | PEP 3333 (2010) | PEP 517 + channels spec |
| **Протоколи** | Тільки HTTP | HTTP + WebSocket + інші |
| **Модель** | Синхронна (один запит = один потік) | Асинхронна (coroutines) |
| **Сервери** | Gunicorn, uWSGI | Uvicorn, Daphne, Hypercorn |
| **Django** | Стандартний runserver | Потребує ASGI application + channels |
| **WebSocket** | ❌ Не підтримується | ✅ Нативно |

---

## Архітектура ASGI стеку notes_chat_app

```
Браузер (HTTP)          Браузер (WebSocket)
      │                        │
      ▼                        ▼
   nginx :80  (reverse proxy — передає далі)
      │                        │
      ▼                        ▼
   Uvicorn ASGI :8001  (один процес — обидва протоколи)
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
              ├──► PostgreSQL (через database_sync_to_async)
              └──► InMemoryChannelLayer / RedisChannelLayer (pub/sub)
```

| Компонент | Роль | Аналог в HTTP Django |
|-----------|------|---------------------|
| `ProtocolTypeRouter` | Розрізняє HTTP і WS за protocol type | `ROOT_URLCONF` |
| `AuthMiddlewareStack` | Читає session cookie → `scope['user']` | `@login_required` decorator |
| `WebSocket URLRouter` | Маршрутизує WS URL до Consumer | `urls.py` |
| `GroupChatConsumer` | Обробляє WS-з'єднання весь час | `view` (але живе довше) |
| `InMemoryChannelLayer` | Pub/sub broadcast між consumers | _(немає прямого аналога)_ |

---

## asgi.py — точка входу

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: get_asgi_application() ПЕРЕД будь-яким імпортом з notes_app
# Django app registry (AppConfig.ready()) має бути ініціалізований
# ПЕРЕД тим як importувати моделі або consumers.
# Якщо поміняти порядок → AppRegistryNotReady exception.
django_asgi_app = get_asgi_application()

# Тільки після get_asgi_application() — безпечно імпортувати з notes_app
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → звичайний Django (views.py, templates, static)
    "http": django_asgi_app,

    # WebSocket → Auth middleware → URL router → Consumer
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

### Критичний порядок імпортів

```python
# ❌ НЕПРАВИЛЬНО — AppRegistryNotReady:
from notes_project.routing import websocket_urlpatterns   # ← ДО get_asgi_application()
django_asgi_app = get_asgi_application()

# ✅ ПРАВИЛЬНО:
django_asgi_app = get_asgi_application()                  # ← СПОЧАТКУ
from notes_project.routing import websocket_urlpatterns   # ← ПОТІМ
```

**Чому так важливо:**

```
Django app registry ініціалізується при виклику get_asgi_application().
До цього моменту:
  - models не завантажені
  - AppConfig.ready() не виконаний
  - будь-який імпорт з notes_app.consumers → AppRegistryNotReady

Типова помилка:
  from notes_project.routing import websocket_urlpatterns
  # routing.py: from notes_app import consumers
  # consumers.py: from notes_app.models import ChatMessage
  # → AppRegistryNotReady!
```

---

## AuthMiddlewareStack — scope["user"] з сесії

```
WebSocket handshake request:
  GET /ws/groups/7/chat/
  Cookie: sessionid=abc123xyz

AuthMiddlewareStack:
  1. Читає sessionid cookie з заголовків handshake
  2. Знаходить сесію в Django session backend (БД)
  3. Завантажує User з сесії
  4. Кладе у scope['user']

Consumer:
  self.user = self.scope['user']
  # → User object (або AnonymousUser якщо не залогінений)
```

### Що таке scope

У ASGI `scope` — це словник з метаданими з'єднання. Аналог `request` у HTTP views, але для WebSocket:

```python
# scope при WebSocket з'єднанні:
{
    'type': 'websocket',
    'path': '/ws/groups/7/chat/',
    'url_route': {
        'kwargs': {'group_pk': '7'}   # ← з URL pattern
    },
    'user': <User: viktor>,           # ← AuthMiddlewareStack завантажив
    'headers': [...],                 # ← заголовки handshake request
    'session': <Session>,             # ← Django session
}
```

### Як Consumer використовує scope

```python
async def connect(self):
    self.user = self.scope['user']
    # ↑ User вже завантажений AuthMiddlewareStack

    self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])
    # ↑ group_pk з URL /ws/groups/<group_pk>/chat/
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

### re_path vs path для WebSocket

```python
# path() — простіший:
from django.urls import path
websocket_urlpatterns = [
    path('ws/groups/<int:group_pk>/chat/', consumers.GroupChatConsumer.as_asgi()),
]

# re_path() — regex, більше контролю:
from django.urls import re_path
websocket_urlpatterns = [
    re_path(r'^ws/groups/(?P<group_pk>\d+)/chat/$', consumers.GroupChatConsumer.as_asgi()),
]

# Обидва варіанти працюють.
# re_path — традиційний вибір для WebSocket (більше прикладів у документації)
```

### Consumer.as_asgi()

```python
consumers.GroupChatConsumer.as_asgi()
# Аналог View.as_view() у HTTP — перетворює клас Consumer у ASGI callable
# Кожне WebSocket з'єднання → окремий екземпляр Consumer
```

---

## nginx: WebSocket проксі

При роботі за nginx потрібні спеціальні заголовки для WebSocket.

```nginx
# nginx.conf — WebSocket location
location /ws/ {
    proxy_pass http://web:8001;
    proxy_http_version 1.1;          # ← HTTP/1.1 потрібен для WS Upgrade
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 300s;         # ← 5 хвилин для idle WS з'єднань
}
```

**Чому `proxy_http_version 1.1`:**
WebSocket Upgrade працює тільки через HTTP/1.1. nginx за замовчуванням використовує HTTP/1.0 для upstream-запитів. Без цього рядка WS Upgrade не відбудеться → браузер отримає HTTP 400.

**Чому `proxy_read_timeout 300s`:**
nginx за замовчуванням закриває upstream з'єднання після 60 сек без відповіді.
WebSocket може бути відкритим годинами без трафіку → збільш timeout до 5+ хвилин.

---

## Типові помилки ASGI стеку

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `AppRegistryNotReady` | Імпорт з notes_app ДО `get_asgi_application()` | Перенести імпорти після виклику |
| WS 400 через nginx | Відсутні Upgrade заголовки | `proxy_http_version 1.1` + Upgrade headers |
| Consumer не знаходиться | Відсутній `routing.py` у `asgi.py` | Підключити `websocket_urlpatterns` |
| `scope['user']` — AnonymousUser | `AuthMiddlewareStack` відсутній або сесія прострочена | Перевірити `is_authenticated` у `connect()` |

---

## Далі

Наступна глава: **[7B. Channel Layers і Daphne](7b_channels_settings.md)** — Daphne у `INSTALLED_APPS`, `InMemoryChannelLayer` vs `RedisChannelLayer`, `socket_timeout=None`.
