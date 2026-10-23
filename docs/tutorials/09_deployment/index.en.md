# Step 9. Deployment

> This step walks you through a **complete production-ready stack**:
> PostgreSQL → Django → Redis → Channels → nginx → ngrok.
>
> The project — `notes_chat_app` — brings together all the previous steps:
> templates + auth + tests + async + WebSocket + Docker + nginx.
> You will see how all the components work together in a real system.
>
> **Result:** an application with PostgreSQL, a real-time group chat,
> Selenium E2E tests and public access through ngrok.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 7. Async and WebSocket](../07_async_django/index.md) — ASGI, Channels, Consumer, channel layer
    - [Step 6. Testing](../06_testing/index.md) — the test pyramid, TestCase, WebsocketCommunicator

---

## The course project

This step uses `notes_chat_app` — the same Django application as in the previous steps, but now packaged into a **production-ready Docker Compose stack**.

| | Dev (previous steps) | Production (this step) |
|--|----------------------|----------------------|
| **DB** | SQLite (file) | PostgreSQL (container) |
| **Server** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (static files, WebSocket) |
| **Channel layer** | InMemory | Redis (scalable) |
| **Public access** | — | ngrok (HTTPS tunnel) |
| **Startup** | `python manage.py runserver` | `docker compose up` |

---

## Production stack components

```
┌─────────────────────────────────────────────────────────────────┐
│  Internet (via ngrok)  ←────────────────────────────────┐       │
│                                                          │       │
│  Browser                                                 │       │
│      │                                                   │       │
│      ▼                                                   │       │
│  nginx :80  ← SSL termination, static files             │       │
│      │                                                   │       │
│      ├── GET /static/*  →  /staticfiles/ (volume)       │       │
│      └── everything else  →  web:8001                   │       │
│                   │                                      │       │
│                   ▼                                      │       │
│           Uvicorn ASGI :8001                             │       │
│                   │                                      │       │
│           ProtocolTypeRouter                             │       │
│                   │                                      │       │
│           ├── HTTP  → Django views                       │       │
│           └── WS   → GroupChatConsumer                  │       │
│                            │                             │       │
│                            ├── PostgreSQL :5432          │       │
│                            └── Redis :6379 (channel)    │       │
│                                                          │       │
│  ngrok ─────────────────────────────────────────────────┘       │
│  Selenium :4444 ← E2E tests                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Services table

| Service | Image | Port | Role |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Relational DB |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, static files |
| `ngrok` | `ngrok/ngrok` | 4040 | Public HTTPS tunnel |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome for E2E |

---

## Why the production stack is more complex

**SQLite is not suitable for production in Docker:** without a named volume, the `db.sqlite3` file is destroyed together with the container after `docker compose down`. PostgreSQL stores its data in a named volume, independently of the containers.

**InMemoryChannelLayer is not suitable for multiple workers:** it keeps messages in the RAM of a single process. If you run several uvicorn workers, they cannot see each other. The Redis channel layer solves this with shared pub/sub.

**`runserver` is not suitable for async:** Django's built-in development server is WSGI. WebSocket requires ASGI. Uvicorn handles both HTTP and WebSocket through a single event loop.

**nginx is required for:** serving static files without loading Python, WebSocket Upgrade headers, and correct proxying to Uvicorn.

---

## Reading order

1. **[Docker Compose](docker_compose.md)** — dependency diagram, the full `docker-compose.yml` with comments, healthcheck and start_period
2. **[PostgreSQL](postgresql.md)** — connecting via `DATABASE_URL`, migrations in Docker, `CONN_MAX_AGE=0` for ASGI
3. **[Redis](redis.md)** — `RedisChannelLayer`, broadcast, `socket_timeout=None`, `daphne` first in `INSTALLED_APPS`
4. **[Nginx](nginx.md)** — `nginx.conf` with comments, the staticfiles volume, WebSocket Upgrade headers
5. **[Ngrok](ngrok.md)** — public HTTPS tunnel, the CSRF + ngrok problem, `ERR_NGROK_8012`
6. **[Entrypoint](entrypoint.md)** — `entrypoint.sh`, `set -e`, `exec`, `collectstatic`, `--noinput`
7. **[Selenium in Docker](selenium_docker.md)** — Remote WebDriver, `_DockerLiveServerMixin`, `exec` vs `run`
8. **[Seed Data](seed_data.md)** — the `seed_demo_data` command, `SEED_DEMO_DATA=1`, `.env` configuration
9. **[Development Workflow](development_workflow.md)** — first launch, day-to-day development, useful commands
10. **[Production Checklist](production_checklist.md)** — security, performance, monitoring, common mistakes
11. **[Checkpoint](checkpoint.md)** — checklist, final table, congratulations
