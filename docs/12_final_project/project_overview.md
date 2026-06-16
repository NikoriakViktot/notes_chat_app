# Project Overview

`notes_chat_app` — навчальний Django-застосунок, який поєднує в одному codebase всі ключові теми курсу: CRUD, автентифікація, ділення через групи, тестування і real-time чат.

---

## Проблема, яку вирішує

Студентам часто важко побачити, як окремі теми Django складаються в один цілісний застосунок. Цей проєкт демонструє всі шари — від моделей до WebSocket — на єдиному codebase.

---

## Ролі користувачів

| Роль | Можливості |
|------|-----------|
| Anonymous | `index`, `register`, `login` |
| Authenticated | керує своїми нотатками, todo, shopping lists, записниками, тегами |
| Group member | бачить group-notes і group-shopping-lists, пише у group chat |

---

## Що реалізовано

| Домен | Можливості |
|-------|-----------|
| Нотатки | CRUD, пін, архів, пріоритет (1–4), теги, записники, нагадування |
| Todo lists | CRUD, позначення виконання, порядок (`order_position`), sharing з користувачами |
| Shopping lists | CRUD, одиниці виміру, ціна, `is_purchased`, group sharing і `shared_with` |
| Групи | create, members management, group chat |
| Real-time чат | WebSocket (Channels), Redis channel layer, збереження в БД, 50 останніх повідомлень при підключенні |
| Автентифікація | registration, login/logout, password change (Django built-in) |

---

## Технологічний стек

| Технологія | Роль |
|-----------|------|
| Django 5.2 | Web framework |
| Django Channels 4 | WebSocket / ASGI |
| Uvicorn | ASGI server |
| PostgreSQL 16 | БД |
| Redis 7 | Channel layer |
| Nginx 1.27 | Reverse proxy |
| Docker Compose | Оркестрація |
| Crispy Forms + Bootstrap 5 | UI |
| Selenium | E2E тести |
| GitHub Actions | CI |

---

## Архітектурні патерни

| Патерн | Де |
|--------|----|
| Services / Selectors | `services.py`, `selectors.py` |
| Thin views | `views.py` викликає forms → selectors → services |
| ASGI ProtocolTypeRouter | `asgi.py` |
| `database_sync_to_async` | `consumers.py` |
| `TransactionTestCase` для async tests | `test_consumers.py` |
| Q-filter scoped queryset | `selectors.py` |

---

## Що не реалізовано

| Компонент | Причина |
|-----------|---------|
| DRF / REST API | фокус курсу на templates |
| Celery | поза scope |
| Async HTTP views | `async_views.py` відсутній у поточному working tree |
| Production hardening | потребує доопрацювань (SECRET_KEY, DEBUG, HTTPS) |

---

## Репозиторій

```text
notes_chat_app/
├── notes_project/          ← Django project (settings, urls, asgi, routing)
├── notes_app/              ← Django app
│   ├── models.py           ← 9 моделей
│   ├── views.py
│   ├── forms.py
│   ├── selectors.py
│   ├── services.py
│   ├── consumers.py        ← GroupChatConsumer
│   ├── tests/              ← 6 test files
│   ├── templates/
│   └── static/
├── templates/              ← base templates
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── requirements.txt
└── .env.example
```
