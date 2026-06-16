# Крок 9. Deployment

> Цей крок проводить тебе через **повний production-ready стек**:
> PostgreSQL → Django → Redis → Channels → nginx → ngrok.
>
> Проєкт — `notes_chat_app` — об'єднує всі попередні кроки:
> шаблони + auth + тести + async + WebSocket + Docker + nginx.
> Ти побачиш як всі компоненти працюють разом у реальній системі.
>
> **Результат:** застосунок з PostgreSQL, груповим чатом у реальному часі,
> Selenium E2E тестами і публічним доступом через ngrok.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 7. Async і WebSocket](../07_async/index.md) — ASGI, Channels, Consumer, channel layer
    - [Крок 8. Тестування](../08_testing/index.md) — піраміда тестів, TestCase, WebsocketCommunicator

---

## Навчальний проєкт

Цей крок використовує `notes_chat_app` — той самий Django-застосунок що і у попередніх кроках, але тепер запакований у **production-ready Docker Compose стек**.

| | Dev (попередні кроки) | Production (цей крок) |
|--|----------------------|----------------------|
| **БД** | SQLite (файл) | PostgreSQL (контейнер) |
| **Сервер** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (статика, WebSocket) |
| **Channel layer** | InMemory | Redis (масштабується) |
| **Публічний доступ** | — | ngrok (HTTPS тунель) |
| **Запуск** | `python manage.py runserver` | `docker compose up` |

---

## Компоненти production стеку

```
┌─────────────────────────────────────────────────────────────────┐
│  Інтернет (через ngrok)  ←──────────────────────────────┐       │
│                                                          │       │
│  Браузер                                                 │       │
│      │                                                   │       │
│      ▼                                                   │       │
│  nginx :80  ← SSL termination, static files             │       │
│      │                                                   │       │
│      ├── GET /static/*  →  /staticfiles/ (volume)       │       │
│      └── все інше  →  web:8001                          │       │
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
│  Selenium :4444 ← E2E тести                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Таблиця сервісів

| Сервіс | Image | Порт | Роль |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Реляційна БД |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, static files |
| `ngrok` | `ngrok/ngrok` | 4040 | Публічний HTTPS тунель |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome для E2E |

---

## Чому production стек складніший

**SQLite не підходить для production через Docker:** без named volume файл `db.sqlite3` знищується разом з контейнером після `docker compose down`. PostgreSQL зберігає дані у named volume незалежно від контейнерів.

**InMemoryChannelLayer не підходить для кількох workers:** він зберігає повідомлення в RAM одного процесу. Якщо запустити кілька uvicorn workers — вони не бачать один одного. Redis channel layer вирішує це через shared pub/sub.

**`runserver` не підходить для async:** Django вбудований development сервер є WSGI. WebSocket вимагає ASGI. Uvicorn обробляє і HTTP, і WebSocket через один event loop.

**nginx необхідний для:** роздачі static files без навантаження на Python, WebSocket Upgrade заголовків, і правильного проксування до Uvicorn.

---

## Порядок читання

1. **[Docker Compose](docker_compose.md)** — схема залежностей, повний `docker-compose.yml` з коментарями, healthcheck і start_period
2. **[PostgreSQL](postgresql.md)** — підключення через `DATABASE_URL`, міграції у Docker, `CONN_MAX_AGE=0` для ASGI
3. **[Redis](redis.md)** — `RedisChannelLayer`, broadcast, `socket_timeout=None`, `daphne` перший у `INSTALLED_APPS`
4. **[Nginx](nginx.md)** — `nginx.conf` з коментарями, staticfiles volume, WebSocket Upgrade headers
5. **[Ngrok](ngrok.md)** — публічний HTTPS тунель, CSRF + ngrok проблема, `ERR_NGROK_8012`
6. **[Entrypoint](entrypoint.md)** — `entrypoint.sh`, `set -e`, `exec`, `collectstatic`, `--noinput`
7. **[Selenium у Docker](selenium_docker.md)** — Remote WebDriver, `_DockerLiveServerMixin`, `exec` vs `run`
8. **[Seed Data](seed_data.md)** — `seed_demo_data` команда, `SEED_DEMO_DATA=1`, `.env` конфігурація
9. **[Development Workflow](development_workflow.md)** — перший запуск, щоденна розробка, корисні команди
10. **[Production Checklist](production_checklist.md)** — безпека, продуктивність, моніторинг, типові помилки
11. **[Checkpoint](checkpoint.md)** — чеклист, фінальна таблиця, вітання
