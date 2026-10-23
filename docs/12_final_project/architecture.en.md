# Notes Chat App Architecture

---

## Components and responsibilities

| Component | File | Responsibility |
|-----------|------|-----------------|
| Settings | `notes_project/settings.py` | apps, DB, Channels, static, auth |
| Root URLs | `notes_project/urls.py` | admin, accounts, app include |
| App URLs | `notes_app/urls.py` | HTTP routes |
| WebSocket routing | `notes_project/routing.py` | `/ws/groups/<pk>/chat/` |
| Models | `notes_app/models.py` | domain schema, constraints, indexes |
| Views | `notes_app/views.py` | HTTP request/response, thin layer |
| Forms | `notes_app/forms.py` | validation and Crispy layout |
| Selectors | `notes_app/selectors.py` | read-only ORM queries, access scoping |
| Services | `notes_app/services.py` | mutating operations (create/update/delete) |
| Consumer | `notes_app/consumers.py` | WebSocket: `GroupChatConsumer` |
| Templates | `templates/` + `notes_app/templates/` | HTML |
| Static | `notes_app/static/notes_app/js/group_chat.js` | WebSocket JS client |
| Tests | `notes_app/tests/` | 6 modules |
| ASGI | `notes_project/asgi.py` | ProtocolTypeRouter |

---

## Application layers

```mermaid
flowchart TD
    Browser --> Nginx["Nginx :80"]
    Nginx -->|HTTP| Uvicorn["Uvicorn :8001<br>ASGI server"]
    Nginx -->|WebSocket| Uvicorn

    Uvicorn --> ASGI["ProtocolTypeRouter<br>notes_project/asgi.py"]
    ASGI -->|http| DjangoHTTP["Django HTTP stack<br>→ views.py"]
    ASGI -->|websocket| AuthMW["AuthMiddlewareStack<br>→ routing.py"]

    DjangoHTTP --> Views["views.py"]
    Views --> Forms["forms.py"]
    Views --> Selectors["selectors.py<br>(read)"]
    Views --> Services["services.py<br>(write)"]
    Selectors --> ORM["Django ORM"]
    Services --> ORM
    ORM --> PostgreSQL[("PostgreSQL<br>:5432")]

    AuthMW --> Consumer["GroupChatConsumer<br>consumers.py"]
    Consumer -->|database_sync_to_async| ORM
    Consumer --> ChannelLayer["Channel Layer<br>Redis :6379"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,Nginx,Uvicorn,DjangoHTTP,Forms,Selectors,Services,ORM,AuthMW,Consumer step;
    class ASGI decision;
    class PostgreSQL,ChannelLayer success;
    class Views warning;
```

---

## ASGI and protocols

`notes_project/asgi.py` routes traffic by protocol type:

```python
application = ProtocolTypeRouter({
    "http":      get_asgi_application(),
    "websocket": AuthMiddlewareStack(
                     URLRouter(websocket_urlpatterns)
                 ),
})
```

HTTP is handled by Django in the standard way.
WebSocket goes through `AuthMiddlewareStack`, which reads the session cookie and populates `scope["user"]`.

WebSocket URL: `/ws/groups/<group_pk>/chat/` → `GroupChatConsumer`.

---

## Docker Compose

```mermaid
flowchart LR
    db[("PostgreSQL<br>db:5432")]
    redis[("Redis<br>redis:6379")]
    web["web<br>uvicorn :8001"]
    nginx["nginx<br>:80"]
    ngrok[ngrok]
    worker[celery-worker]
    beat[celery-beat]
    selenium["selenium<br>chrome"]
    stests[selenium-tests]

    db --> web
    redis --> web
    web --> nginx
    nginx --> ngrok
    db --> worker
    redis --> worker
    db --> beat
    redis --> beat
    selenium --> stests
    nginx --> stests

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class db,redis,ngrok,worker,beat,selenium,stests step;
    class web,nginx success;
```

Dependencies: `web`, `celery-worker` and `celery-beat` start only after the `db` and `redis` health checks pass; `selenium-tests` (profile `test`) also waits for `web`, `nginx` and `selenium`.

---

## The layering principle (Views → thin)

```text
views.py         ← HTTP coordination (thin layer)
  ↓ forms.py     ← input data validation
  ↓ selectors.py ← read queries (returns a QuerySet or a list)
  ↓ services.py  ← write operations (atomic transactions)
  ↓ models.py    ← domain schema
```

Business logic is not added directly to a view without a documented reason.

---

## Channel Layer

| Condition | Backend |
|-------|---------|
| `REDIS_URL` is not set | `InMemoryChannelLayer` (dev, single process) |
| `REDIS_URL` is set | `RedisChannelLayer` (Docker, production) |

`socket_timeout=None` in the `RedisChannelLayer CONFIG` is required — it prevents `TimeoutError` on idle WebSocket connections.
