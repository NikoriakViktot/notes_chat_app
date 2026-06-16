# Архітектура Notes Chat App

---

## Компоненти і відповідальність

| Компонент | Файл | Відповідальність |
|-----------|------|-----------------|
| Settings | `notes_project/settings.py` | apps, DB, Channels, static, auth |
| Root URLs | `notes_project/urls.py` | admin, accounts, app include |
| App URLs | `notes_app/urls.py` | HTTP routes |
| WebSocket routing | `notes_project/routing.py` | `/ws/groups/<pk>/chat/` |
| Models | `notes_app/models.py` | domain schema, constraints, indexes |
| Views | `notes_app/views.py` | HTTP request/response, thin layer |
| Forms | `notes_app/forms.py` | validation і Crispy layout |
| Selectors | `notes_app/selectors.py` | read-only ORM queries, access scoping |
| Services | `notes_app/services.py` | мутуючі операції (create/update/delete) |
| Consumer | `notes_app/consumers.py` | WebSocket: `GroupChatConsumer` |
| Templates | `templates/` + `notes_app/templates/` | HTML |
| Static | `notes_app/static/notes_app/js/group_chat.js` | WebSocket JS-клієнт |
| Tests | `notes_app/tests/` | 6 модулів |
| ASGI | `notes_project/asgi.py` | ProtocolTypeRouter |

---

## Шари застосунку

```mermaid
flowchart TD
    Browser --> Nginx["Nginx :80"]
    Nginx -->|HTTP| Uvicorn["Uvicorn :8001\nASGI server"]
    Nginx -->|WebSocket| Uvicorn

    Uvicorn --> ASGI["ProtocolTypeRouter\nnotes_project/asgi.py"]
    ASGI -->|http| DjangoHTTP["Django HTTP stack\n→ views.py"]
    ASGI -->|websocket| AuthMW["AuthMiddlewareStack\n→ routing.py\n→ GroupChatConsumer"]

    DjangoHTTP --> Views["views.py"]
    Views --> Forms["forms.py"]
    Views --> Selectors["selectors.py\n(read)"]
    Views --> Services["services.py\n(write)"]
    Selectors --> ORM["Django ORM"]
    Services --> ORM
    ORM --> PostgreSQL[("PostgreSQL\n:5432")]

    AuthMW --> Consumer["GroupChatConsumer\nconsumers.py"]
    Consumer -->|database_sync_to_async| ORM
    Consumer --> ChannelLayer["Channel Layer\nRedis :6379"]
```

---

## ASGI і протоколи

`notes_project/asgi.py` розподіляє трафік за типом протоколу:

```python
application = ProtocolTypeRouter({
    "http":      get_asgi_application(),
    "websocket": AuthMiddlewareStack(
                     URLRouter(websocket_urlpatterns)
                 ),
})
```

HTTP обробляється Django стандартним чином.
WebSocket — через `AuthMiddlewareStack`, який читає сесійний cookie і наповнює `scope["user"]`.

WebSocket URL: `/ws/groups/<group_pk>/chat/` → `GroupChatConsumer`.

---

## Docker Compose

```mermaid
flowchart LR
    db[(PostgreSQL\ndb:5432)]
    redis[(Redis\nredis:6379)]
    web[web\nuvicorn :8001]
    nginx[nginx\n:80]
    ngrok[ngrok]
    selenium[selenium\nchrome]

    db --> web
    redis --> web
    web --> nginx
    nginx --> ngrok
```

Залежності: `web` стартує лише після health check `db` і `redis`.

---

## Шаровий принцип (Views → thin)

```text
views.py         ← HTTP координація (тонкий шар)
  ↓ forms.py     ← валідація вхідних даних
  ↓ selectors.py ← read queries (повертає QuerySet або list)
  ↓ services.py  ← write operations (атомарні транзакції)
  ↓ models.py    ← domain schema
```

Бізнес-логіка не додається безпосередньо у view без документованої причини.

---

## Channel Layer

| Умова | Backend |
|-------|---------|
| `REDIS_URL` не встановлено | `InMemoryChannelLayer` (dev, один процес) |
| `REDIS_URL` встановлено | `RedisChannelLayer` (Docker, production) |

`socket_timeout=None` у `RedisChannelLayer CONFIG` є обов'язковим — запобігає `TimeoutError` при idle WebSocket з'єднаннях.
