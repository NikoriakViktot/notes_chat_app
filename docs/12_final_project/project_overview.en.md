# Project Overview

`notes_chat_app` is a learning Django application that brings all the key topics of the course together in a single codebase: CRUD, authentication, sharing through groups, testing, and a real-time chat.

---

## The problem it solves

Students often find it hard to see how the separate Django topics fit together into one coherent application. This project demonstrates every layer, from models to WebSocket, in a single codebase.

---

## User roles

| Role | Capabilities |
|------|-----------|
| Anonymous | `index`, `register`, `login` |
| Authenticated | manages their own notes, todo lists, shopping lists, notebooks, tags |
| Group member | sees group notes and group shopping lists, writes in the group chat |

---

## What is implemented

| Domain | Capabilities |
|-------|-----------|
| Notes | CRUD, pin, archive, priority (1–4), tags, notebooks, reminders |
| Todo lists | CRUD, marking items done, ordering (`order_position`), sharing with users |
| Shopping lists | CRUD, units of measure, price, `is_purchased`, group sharing and `shared_with` |
| Groups | create, members management, group chat |
| Real-time chat | WebSocket (Channels), Redis channel layer, persistence in the DB, the latest 50 messages on connect |
| Authentication | registration, login/logout, password change (Django built-in) |

---

## Technology stack

| Technology | Role |
|-----------|------|
| Django 5.2 | Web framework |
| Django Channels 4 | WebSocket / ASGI |
| Uvicorn | ASGI server |
| PostgreSQL 16 | Database |
| Redis 7 | Channel layer (DB 0), Celery broker (DB 1) |
| Celery 5 (worker + beat) | Background tasks: email reminders |
| Nginx 1.27 | Reverse proxy |
| Docker Compose | Orchestration |
| Crispy Forms + Bootstrap 5 | UI |
| Selenium | E2E tests |
| GitHub Actions | CI |

---

## Architectural patterns

| Pattern | Where |
|--------|----|
| Services / Selectors | `services.py`, `selectors.py` |
| Thin views | `views.py` calls forms → selectors → services |
| ASGI ProtocolTypeRouter | `asgi.py` |
| `database_sync_to_async` | `consumers.py` |
| `TransactionTestCase` for async tests | `test_consumers.py` |
| Q-filter scoped queryset | `selectors.py` |

---

## What is not implemented

| Component | Reason |
|-----------|---------|
| DRF / REST API | the course focuses on templates |
| Async HTTP views | `async_views.py` is absent from the current working tree |
| Production hardening | needs more work (SECRET_KEY, DEBUG, HTTPS) |

---

## Repository

```text
notes_chat_app/
├── notes_project/          ← Django project (settings, urls, asgi, routing)
├── notes_app/              ← Django app
│   ├── models.py           ← 10 models
│   ├── views.py
│   ├── forms.py
│   ├── selectors.py
│   ├── services.py
│   ├── consumers.py        ← GroupChatConsumer
│   ├── tasks.py            ← Celery: send_reminder_notifications
│   ├── tests/              ← 7 test files
│   ├── templates/
│   └── static/
├── templates/              ← base templates
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── requirements.txt
└── .env.example
```
