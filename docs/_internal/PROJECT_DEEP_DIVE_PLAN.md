# Project Deep Dive Plan

Phase 2 — Architecture Planning → **ЧАСТКОВО РЕАЛІЗОВАНО (Batch I, 2026-06-14)**
Створено: 2026-06-14

Повний план архітектурного розбору фактичного Notes Chat App.
Усі компоненти прив'язані до реальних файлів і символів коду.

---

## Відображення в mkdocs.yml

З Batch L "Notes Chat App" — окремий top-level розділ навігації.
35 глав плану реалізовано через 13 файлів у `docs/12_final_project/`.

| Файл у nav (Notes Chat App) | Глави плану що покриває | Статус |
|----------------------------|------------------------|--------|
| `README.md` | Ch.1 Огляд застосунку | ✅ expanded (Batch I) |
| `project_overview.md` | Ch.1 (деталізовано) | ✅ expanded (Batch I) |
| `architecture.md` | Ch.4 Django конфіг, Ch.23 ASGI, Ch.24 Channels | ✅ expanded (Batch I) |
| `domain_model.md` | Ch.7 Domain model, Ch.8 Models, Ch.9 Migrations | ✅ expanded (Batch I) |
| `feature_map.md` | Ch.2 Функціональна карта | ✅ expanded (Batch I) |
| `request_flows.md` | Flows 1–11 (наскрізні сценарії) | ✅ expanded (Batch I) |
| `async_and_chat.md` | Ch.25 GroupChatConsumer, Ch.26 WS lifecycle, Ch.28 Redis | ✅ expanded (Batch I) |
| `security_model.md` | Ch.16 Auth, Ch.17 Permissions, Ch.32 Security | ✅ expanded (Batch I) |
| `setup.md` | Ch.3 Структура репо, Ch.5 Settings/env, Ch.27 PostgreSQL | ✅ expanded (Batch I) |
| `testing_strategy.md` | Ch.29 Testing architecture, Ch.31 CI | ✅ expanded (Batch I) |
| `deployment.md` | Ch.30 Docker Compose, Ch.33 Production, Ch.34 Deployment | ✅ expanded (Batch I) |
| `student_tasks.md` | Ch.35 Напрямки розвитку | ✅ expanded (Batch I) |
| `orm_architecture_board.md` | — (iframe, не змінювався) | — |

### Глави без окремих файлів (охоплено через суміжні глави)

| Глави плану | Охоплення |
|------------|-----------|
| Ch.6 URL routing | В `architecture.md` (ASGI routing) + `feature_map.md` |
| Ch.10 Forms | В `security_model.md` (trust boundary) + `domain_model.md` |
| Ch.11 Selectors | В `security_model.md` (Q-filter patterns) |
| Ch.12 Services | В `domain_model.md` (deletion behavior) |
| Ch.13 Views | В `security_model.md` (IDOR, permission checks) |
| Ch.14 Templates | В `feature_map.md` (template references) |
| Ch.15 Static / JS | В `async_and_chat.md` (group_chat.js) |
| Ch.18 Groups | В `domain_model.md` (Group M2M, ChatMessage) |
| Ch.19–21 Lifecycles | В `feature_map.md` + `request_flows.md` |
| Ch.22 Reminders | В `domain_model.md` (CASCADE deletion) |

---

## Принцип

Deep Dive не повторює теорію — він розбирає **реальний код**.
Кожна глава посилається на канонічну теоретичну главу Knowledge Book.
Кожна глава перевіряє тільки те, що реально існує у `notes_app/` та `notes_project/`.

---

## Каталог глав

### Ch.1. Огляд застосунку

| Поле | Зміст |
|------|-------|
| Actual files | `docs/12_final_project/README.md`, `docs/12_final_project/project_overview.md` |
| Main symbols | — |
| Responsibility | Що робить Notes Chat App, для кого, які проблеми вирішує |
| Callers | — |
| Dependencies | Всі компоненти |
| Tests | — |
| Knowledge links | Частина II (Django Core) |
| Zero to Hero links | Кроки 0–8 (мета всього маршруту) |
| Diagram | Загальна архітектурна схема (Mermaid) |
| Accuracy risks | Перевірити фактичний feature set у коді |

---

### Ch.2. Функціональна карта

| Поле | Зміст |
|------|-------|
| Actual files | `docs/12_final_project/feature_map.md`, `notes_app/urls.py` |
| Main symbols | URL names у `notes_app/urls.py` |
| Responsibility | Повний перелік функціональності з посиланнями на views |
| Callers | Browser → Nginx → Daphne → URLconf |
| Dependencies | `notes_app/views.py`, `notes_app/consumers.py` |
| Tests | — |
| Knowledge links | Частина II |
| Zero to Hero links | Кроки 1–5 |
| Diagram | Feature map таблиця |
| Accuracy risks | Перевірити URL names у `notes_app/urls.py`, не вигадувати |

---

### Ch.3. Структура репозиторію

| Поле | Зміст |
|------|-------|
| Actual files | `docs/00_getting_started/repository_structure.md`, `docker-compose.yml` |
| Main symbols | `notes_project/`, `notes_app/`, `templates/`, `static/`, `nginx/` |
| Responsibility | Де що знаходиться і навіщо |
| Callers | — |
| Dependencies | Docker Compose stack |
| Tests | — |
| Knowledge links | Частина II |
| Zero to Hero links | Крок 0 |
| Diagram | Дерево директорій |
| Accuracy risks | ls реального репо, не вигадувати директорій |

---

### Ch.4. Django project конфігурація

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/settings.py`, `notes_project/urls.py`, `notes_project/middleware.py` |
| Main symbols | `INSTALLED_APPS`, `MIDDLEWARE`, `DATABASES`, `CHANNEL_LAYERS`, `DebugExceptionMiddleware` |
| Responsibility | Налаштування Django project |
| Callers | Django startup |
| Dependencies | Environment variables (`DATABASE_URL`, `REDIS_URL`, `SECRET_KEY`) |
| Tests | `manage.py check` |
| Knowledge links | Частини II, VII, X |
| Zero to Hero links | Кроки 1, 8 |
| Diagram | Settings layers (base → env override) |
| Accuracy risks | **DebugExceptionMiddleware** — production security issue (повертає traceback без if DEBUG). Не вигадувати SQLite fallback — settings.py piднімає Exception якщо DATABASE_URL не встановлено |

---

### Ch.5. Settings та environment variables

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/settings.py`, `.env.example` (якщо є), `docker-compose.yml` |
| Main symbols | `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `SEED_DEMO_DATA` |
| Responsibility | Конфігурація через env vars |
| Callers | Docker Compose, CI |
| Dependencies | dj-database-url |
| Tests | — |
| Knowledge links | Частина X (Environment variables) |
| Zero to Hero links | Крок 8 |
| Diagram | Env var flow: docker-compose.yml → container → settings.py |
| Accuracy risks | `DATABASE_URL` відсутній → `Exception` (не SQLite). Перевірити фактичні env vars |

---

### Ch.6. URL routing

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/urls.py`, `notes_app/urls.py`, `notes_project/routing.py` |
| Main symbols | `urlpatterns`, `include()`, `path()`, WebSocket `re_path()` |
| Responsibility | HTTP URL dispatch і WebSocket URL dispatch |
| Callers | `ProtocolTypeRouter` (для WS), Django URL resolver (для HTTP) |
| Dependencies | `notes_app/views.py`, `notes_app/consumers.py` |
| Tests | `resolve()` у unit tests |
| Knowledge links | Частина II (URL routing) |
| Zero to Hero links | Крок 1, Крок 7 |
| Diagram | URL tree: HTTP і WS окремо |
| Accuracy risks | Перевірити фактичні path names у коді |

---

### Ch.7. Domain model

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py`, `docs/12_final_project/domain_model.md` |
| Main symbols | `User`, `UserProfile`, `Notebook`, `Note`, `Tag`, `Reminder`, `TodoList`, `TodoItem`, `ShoppingList`, `ShopItem`, `ChatMessage` |
| Responsibility | Схема домену |
| Callers | ORM, services, selectors |
| Dependencies | PostgreSQL |
| Tests | `test_models.py` |
| Knowledge links | Частина III (Models) |
| Zero to Hero links | Кроки 2–5 |
| Diagram | ER-діаграма (Mermaid) з реальними полями |
| Accuracy risks | ChatMessage.author: CASCADE (не SET_NULL). ShopItem: quantity=DecimalField(8,2), is_purchased (не is_bought), store_name (не store). TodoItem: order_position (не position). Перевірити перед написанням |

---

### Ch.8. Models і relationships

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py` |
| Main symbols | FK on_delete choices, related_name, ManyToMany, OneToOne |
| Responsibility | Детальний розбір кожної моделі і зв'язку |
| Callers | ORM queries у selectors |
| Dependencies | PostgreSQL constraints |
| Tests | `test_models.py` — deletion cascade tests |
| Knowledge links | Частина III |
| Zero to Hero links | Кроки 2–5 |
| Diagram | Relationships per model |
| Accuracy risks | Перевірити on_delete для кожного FK. ChatMessage.group: CASCADE, related_name='chat_messages'. ChatMessage.author: CASCADE, related_name='chat_messages' |

---

### Ch.9. Migrations і constraints

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/migrations/` |
| Main symbols | міграції 0001–000N, `RunSQL`, constraint definitions |
| Responsibility | Еволюція схеми БД |
| Callers | `manage.py migrate` |
| Dependencies | PostgreSQL |
| Tests | — |
| Knowledge links | Частина III (Migrations) |
| Zero to Hero links | Крок 2 |
| Diagram | Migration dependency graph |
| Accuracy risks | Не вигадувати міграційних файлів — дивитись фактичну директорію |

---

### Ch.10. Forms і validation

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/forms.py` |
| Main symbols | `NoteForm`, `GroupCreateForm` та інші форми у файлі |
| Responsibility | Server-side validation, CSRF, queryset security |
| Callers | Views (POST requests) |
| Dependencies | `notes_app/models.py`, Django crispy-forms |
| Tests | `test_forms.py` — IDOR prevention, queryset security |
| Knowledge links | Частина IV (Forms) |
| Zero to Hero links | Крок 4, Крок 5 |
| Diagram | Form validation pipeline |
| Accuracy risks | Перевірити фактичні класи у forms.py. NoteForm.__init__(user=user) для queryset filtering |

---

### Ch.11. Selectors

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/selectors.py` |
| Main symbols | Всі публічні функції у файлі |
| Responsibility | Read-only ORM queries, access control, select_related/prefetch_related |
| Callers | Views |
| Dependencies | `notes_app/models.py`, Django ORM |
| Tests | Опосередковано через test_views.py |
| Knowledge links | Частина VI (Architecture), Частина III (ORM) |
| Zero to Hero links | Крок 3 |
| Diagram | Data flow: view → selector → ORM → PostgreSQL |
| Accuracy risks | Перевірити фактичні функції у selectors.py. Q(user=user) | Q(group__in=user_groups) |

---

### Ch.12. Services

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/services.py` |
| Main symbols | `create_note`, `update_note`, `delete_note` та інші |
| Responsibility | Mutating operations після validation |
| Callers | Views (після form.is_valid()) |
| Dependencies | `notes_app/models.py`, `notes_app/selectors.py` (для permission checks) |
| Tests | `test_services.py` |
| Knowledge links | Частина VI |
| Zero to Hero links | Крок 3 |
| Diagram | Service call chain |
| Accuracy risks | `update_note(note, *, title, content, priority, notebook, is_pinned, tag_ids)` — explicit keyword-only args. Не `**form.cleaned_data_for_service()` (метод не існує) |

---

### Ch.13. Views

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/views.py` |
| Main symbols | Всі FBV, декоратори `@login_required` |
| Responsibility | HTTP coordination: form validation → selector/service → render/redirect |
| Callers | URLconf |
| Dependencies | `notes_app/forms.py`, `notes_app/selectors.py`, `notes_app/services.py` |
| Tests | `test_views.py` |
| Knowledge links | Частина II (Views), Частина VI, Частина VII |
| Zero to Hero links | Кроки 1, 3, 5 |
| Diagram | View responsibility flow |
| Accuracy risks | Views тонкі, не містять ORM. Перевірити permission check pattern для object-level auth |

---

### Ch.14. Templates

| Поле | Зміст |
|------|-------|
| Actual files | `templates/` (дерево) |
| Main symbols | `base.html`, template inheritance, `{% block %}`, `{% include %}` |
| Responsibility | Render HTML для HTTP responses |
| Callers | Views (`render()`) |
| Dependencies | Bootstrap 5, crispy-forms |
| Tests | `assertTemplateUsed()` у test_views |
| Knowledge links | Частина V (Templates) |
| Zero to Hero links | Кроки 1, 4 |
| Diagram | Template inheritance tree |
| Accuracy risks | Перевірити фактичну структуру templates/ |

---

### Ch.15. Static files і JavaScript

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/static/` |
| Main symbols | `group_chat.js` (WebSocket client) |
| Responsibility | CSS, JS, client-side WebSocket |
| Callers | Browser |
| Dependencies | Bootstrap 5, WebSocket API |
| Tests | Selenium E2E |
| Knowledge links | Частина V (Frontend) |
| Zero to Hero links | Крок 7 |
| Diagram | JS → WS → Consumer flow |
| Accuracy risks | Перевірити фактичні static файли. group_chat.js відправляє JSON до consumer |

---

### Ch.16. Authentication і sessions

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/urls.py` (auth URLs), `notes_app/views.py` |
| Main symbols | `@login_required`, `request.user`, `force_login()` у тестах |
| Responsibility | Login, logout, session management |
| Callers | Browser → SessionMiddleware → AuthMiddleware |
| Dependencies | Django built-in auth, sessions framework |
| Tests | `test_views.py` — anonymous redirect, authenticated access |
| Knowledge links | Частина VII |
| Zero to Hero links | Крок 5 |
| Diagram | Session cookie flow |
| Accuracy risks | AuthMiddlewareStack для WebSocket (scope["user"]) |

---

### Ch.17. Ownership, sharing і permissions

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/selectors.py`, `notes_app/views.py` |
| Main symbols | Q(user=user) | Q(group__in=user_groups) |
| Responsibility | Object-level access control: owner + shared group members |
| Callers | Views через selectors |
| Dependencies | Django Groups, `notes_app/models.py` |
| Tests | `test_views.py` — IDOR checks |
| Knowledge links | Частина VII |
| Zero to Hero links | Крок 5 |
| Diagram | Permission decision tree |
| Accuracy risks | Перевірити Q-фільтр у selectors.py. Write permission: лише owner (не group members) |

---

### Ch.18. Groups

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py`, `notes_app/views.py`, `notes_app/services.py` |
| Main symbols | Django built-in `Group`, `GroupCreateForm` |
| Responsibility | Sharing mechanism |
| Callers | Group management views |
| Dependencies | `User.groups` M2M |
| Tests | `test_services.py` — GroupServiceTest |
| Knowledge links | Частина VII (Permissions) |
| Zero to Hero links | Крок 5 |
| Diagram | Group membership and shared access |
| Accuracy risks | Django built-in Group, не кастомна модель. ChatMessage.group FK on_delete=CASCADE |

---

### Ch.19. Notes lifecycle

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py`, `notes_app/views.py`, `notes_app/services.py`, `notes_app/selectors.py` |
| Main symbols | `Note`, `Notebook`, `Tag`, `Reminder` |
| Responsibility | CRUD для нотаток з прив'язкою до notebook, тегів, нагадувань |
| Callers | Note-related views |
| Dependencies | PostgreSQL, selectors, services |
| Tests | `test_models.py`, `test_services.py`, `test_views.py` |
| Knowledge links | Частини III, VI, VII |
| Zero to Hero links | Кроки 2–5 |
| Diagram | Note CRUD state machine |
| Accuracy risks | Note.notebook: SET_NULL при видаленні Notebook. Reminder: CASCADE при видаленні Note |

---

### Ch.20. Todo lifecycle

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py`, відповідні views/services/selectors |
| Main symbols | `TodoList`, `TodoItem` (поле: `order_position`, не `position`) |
| Responsibility | CRUD для TodoList та TodoItem |
| Callers | Todo views |
| Dependencies | PostgreSQL |
| Tests | Відповідні тести |
| Knowledge links | Частина III |
| Zero to Hero links | Крок 5 |
| Diagram | Todo state machine |
| Accuracy risks | TodoItem.order_position (НЕ position). Перевірити перед написанням |

---

### Ch.21. Shopping lifecycle

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py`, відповідні views/services/selectors |
| Main symbols | `ShoppingList`, `ShopItem` |
| Responsibility | CRUD для ShoppingList та ShopItem |
| Callers | Shopping views |
| Dependencies | PostgreSQL |
| Tests | Відповідні тести |
| Knowledge links | Частина III |
| Zero to Hero links | Крок 5 |
| Diagram | Shopping list state machine |
| Accuracy risks | ShopItem: store_name (не store), quantity=DecimalField(8,2), is_purchased (не is_bought), unit (choices), estimated_price (nullable), NO position field |

---

### Ch.22. Reminders

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/models.py` |
| Main symbols | `Reminder` — FK to Note, CASCADE |
| Responsibility | Нагадування до нотаток |
| Callers | Note views або окремі reminder views |
| Dependencies | Note |
| Tests | test_models.py (CASCADE deletion) |
| Knowledge links | Частина III |
| Zero to Hero links | Крок 5 |
| Diagram | — |
| Accuracy risks | Reminder видаляється CASCADE при видаленні Note |

---

### Ch.23. ASGI

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/asgi.py` |
| Main symbols | `get_asgi_application()`, `ProtocolTypeRouter`, `AuthMiddlewareStack`, `URLRouter` |
| Responsibility | ASGI entry point — route HTTP і WebSocket |
| Callers | Daphne / Uvicorn |
| Dependencies | `notes_project/routing.py` |
| Tests | Consumer tests (end-to-end through ASGI) |
| Knowledge links | Частина IX (ASGI) |
| Zero to Hero links | Крок 7 |
| Diagram | ProtocolTypeRouter routing diagram |
| Accuracy risks | `get_asgi_application()` ПОВИНЕН бути викликаний ДО будь-якого імпорту notes_app (AppRegistryNotReady) |

---

### Ch.24. Channels

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/routing.py`, `notes_project/asgi.py`, `notes_project/settings.py` |
| Main symbols | `CHANNEL_LAYERS` setting, `InMemoryChannelLayer` vs `RedisChannelLayer` |
| Responsibility | Channel layer конфігурація і routing |
| Callers | ASGI application |
| Dependencies | Redis (для multi-process), channels library |
| Tests | `@override_settings(CHANNEL_LAYERS=InMemory)` у consumer tests |
| Knowledge links | Частина IX (Channels) |
| Zero to Hero links | Крок 7 |
| Diagram | Channel layer switching: без REDIS_URL → InMemory, з REDIS_URL → Redis |
| Accuracy risks | socket_timeout=None у RedisChannelLayer CONFIG — критично для idle WebSocket |

---

### Ch.25. GroupChatConsumer

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/consumers.py` |
| Main symbols | `GroupChatConsumer(AsyncWebsocketConsumer)`, `connect()`, `disconnect()`, `receive()`, `load_history()`, `chat_message()` |
| Responsibility | WebSocket lifecycle і message handling |
| Callers | ASGI → URLRouter → consumer instance |
| Dependencies | `database_sync_to_async`, `ChatMessage`, `Group`, channel layer |
| Tests | `test_consumers.py` — `GroupChatConsumerTest(TransactionTestCase)` |
| Knowledge links | Частина IX |
| Zero to Hero links | Крок 7 |
| Diagram | Consumer state machine (connect → join_group → receive → send → disconnect) |
| Accuracy risks | load_history: `.values('author__username', ...)` — ніколи NULL (CASCADE). database_sync_to_async + list(queryset) — не lazy QuerySet |

---

### Ch.26. WebSocket lifecycle

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/consumers.py`, `notes_app/static/group_chat.js` |
| Main symbols | `connect()`, `disconnect()`, handshake headers, `scope["user"]` |
| Responsibility | WS handshake, auth via session cookie, group join/leave |
| Callers | Browser JS → Nginx → Daphne |
| Dependencies | `AuthMiddlewareStack` |
| Tests | `test_consumers.py` — connect/disconnect scenarios |
| Knowledge links | Частина IX |
| Zero to Hero links | Крок 7 |
| Diagram | WebSocket handshake + lifecycle Mermaid |
| Accuracy risks | AuthMiddlewareStack читає session cookie → `scope["user"]`. Перевірити permission у connect() |

---

### Ch.27. PostgreSQL

| Поле | Зміст |
|------|-------|
| Actual files | `docker-compose.yml` (db service), `notes_project/settings.py` |
| Main symbols | `postgres:16-alpine`, `DATABASE_URL`, `dj-database-url` |
| Responsibility | Primary data store |
| Callers | Django ORM через DATABASE_URL |
| Dependencies | psycopg2 / psycopg |
| Tests | Усі тести, що торкаються БД |
| Knowledge links | Частина III (PostgreSQL) |
| Zero to Hero links | Крок 3 (перехід з SQLite) |
| Diagram | Django → ORM → psycopg2 → PostgreSQL |
| Accuracy risks | DATABASE_URL не встановлено → Exception (не SQLite fallback) |

---

### Ch.28. Redis channel layer

| Поле | Зміст |
|------|-------|
| Actual files | `docker-compose.yml` (redis service), `notes_project/settings.py` |
| Main symbols | `redis:7-alpine`, `REDIS_URL`, `RedisChannelLayer`, `InMemoryChannelLayer` |
| Responsibility | Channel layer для broadcast WebSocket messages |
| Callers | GroupChatConsumer |
| Dependencies | channels-redis |
| Tests | `@override_settings(CHANNEL_LAYERS=InMemory)` у тестах |
| Knowledge links | Частина IX |
| Zero to Hero links | Крок 7 |
| Diagram | Redis pub/sub для channel groups |
| Accuracy risks | `socket_timeout=None` у CONFIG — без цього TimeoutError на idle WS |

---

### Ch.29. Testing architecture

| Поле | Зміст |
|------|-------|
| Actual files | `notes_app/tests/` (6 файлів) |
| Main symbols | `NoteModelTest`, `NoteServiceTest`, `NoteFormTest`, `NoteListViewTest`, `GroupChatConsumerTest`, Selenium tests |
| Responsibility | Повна тестова піраміда |
| Callers | `manage.py test`, GitHub Actions |
| Dependencies | `WebsocketCommunicator`, `database_sync_to_async`, Selenium, selenium service у Docker |
| Tests | — (це і є тести) |
| Knowledge links | Частина VIII (Testing) |
| Zero to Hero links | Крок 6 |
| Diagram | Test pyramid: model → service → form → view → consumer → selenium |
| Accuracy risks | Consumer tests: ЗАВЖДИ TransactionTestCase. Selenium: ЗАВЖДИ exec (не run) |

---

### Ch.30. Docker Compose

| Поле | Зміст |
|------|-------|
| Actual files | `docker-compose.yml`, `Dockerfile` |
| Main symbols | services: db, redis, web, nginx, ngrok, selenium |
| Responsibility | Dev/prod stack оркестрація |
| Callers | `docker compose up` |
| Dependencies | Docker Engine |
| Tests | Smoke test: `docker compose up -d` → `curl localhost:8001/` |
| Knowledge links | Частина X (Docker) |
| Zero to Hero links | Крок 8 |
| Diagram | Service dependency graph |
| Accuracy risks | Перевірити фактичні service names у docker-compose.yml. Web service: port 8001 |

---

### Ch.31. CI — GitHub Actions

| Поле | Зміст |
|------|-------|
| Actual files | `.github/workflows/` |
| Main symbols | CI YAML jobs: unit+integration+consumers, selenium E2E |
| Responsibility | Автоматичні тести на кожен push |
| Callers | GitHub Events (push, PR) |
| Dependencies | Docker, PostgreSQL service у CI |
| Tests | Усі тести запускаються у CI |
| Knowledge links | Частина VIII (CI/CD) |
| Zero to Hero links | Крок 8 |
| Diagram | CI job dependency graph |
| Accuracy risks | Перевірити фактичний YAML у .github/workflows/ |

---

### Ch.32. Security model

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/settings.py`, `notes_project/middleware.py`, `notes_app/views.py` |
| Main symbols | `DebugExceptionMiddleware`, `CSRF`, `@login_required`, Q permissions |
| Responsibility | Захист від типових атак |
| Callers | Кожен request |
| Dependencies | Django security middleware stack |
| Tests | test_views.py (IDOR), test_forms.py (CSRF, queryset) |
| Knowledge links | Частина VII |
| Zero to Hero links | Крок 5 |
| Diagram | Security layers |
| Accuracy risks | **DebugExceptionMiddleware повертає traceback без if DEBUG** — production security issue |

---

### Ch.33. Production preparation

| Поле | Зміст |
|------|-------|
| Actual files | `notes_project/settings.py`, `docker-compose.yml`, `nginx/` |
| Main symbols | `DEBUG=False`, `ALLOWED_HOSTS`, `SECRET_KEY`, `STATIC_ROOT` |
| Responsibility | Конфігурація для production |
| Callers | Deployment pipeline |
| Dependencies | Nginx, env vars |
| Tests | `manage.py check --deploy` |
| Knowledge links | Частина X (Deployment) |
| Zero to Hero links | Крок 8 |
| Diagram | Production request flow |
| Accuracy risks | DebugExceptionMiddleware слід прибрати або обгорнути у production |

---

### Ch.34. Deployment

| Поле | Зміст |
|------|-------|
| Actual files | `docker-compose.yml`, `nginx/`, `Dockerfile`, `.github/workflows/` |
| Main symbols | nginx:1.27-alpine, ngrok service |
| Responsibility | Deploy flow |
| Callers | DevOps/developer |
| Dependencies | Docker, Nginx, PostgreSQL, Redis |
| Tests | CI green → deploy |
| Knowledge links | Частина X |
| Zero to Hero links | Крок 8 |
| Diagram | Deploy pipeline |
| Accuracy risks | Перевірити фактичний nginx конфіг |

---

### Ch.35. Напрямки розвитку

| Поле | Зміст |
|------|-------|
| Actual files | `docs/12_final_project/student_tasks.md` |
| Main symbols | — |
| Responsibility | Ідеї для розширення проєкту студентами |
| Knowledge links | Всі частини |
| Zero to Hero links | Кроки 0–8 (базові) + нові кроки |
| Accuracy risks | Не вигадувати features, яких немає у коді |

---

## Наскрізні сценарії (Cross-Cutting Flows)

### Flow 1: Create note

```text
Browser POST /notes/new/
→ Nginx → Daphne → Django URLconf
→ notes_app/views.py: note_create()
→ NoteForm(request.POST, user=request.user).is_valid()
→ notes_app/services.py: create_note(user, title, content, ...)
→ Note.objects.create(...)
→ PostgreSQL INSERT
→ redirect → notes_app/views.py: note_list()
→ notes_app/selectors.py: get_notes_for_user(user)
→ Q(user=user) | Q(group__in=groups)
→ render('notes/list.html')
```

### Flow 2: Edit note permission check

```text
Browser GET /notes/42/edit/
→ note_edit(request, pk=42)
→ get_object_or_404(Note, pk=42)
→ if note.user != request.user → 403 (owner-only write)
→ NoteForm(instance=note, user=request.user)
→ render form
Browser POST
→ NoteForm(request.POST, instance=note, user=request.user).is_valid()
→ services.update_note(note, title=..., content=..., tag_ids=[...])
→ PostgreSQL UPDATE
```

### Flow 3: Group-shared note access

```text
User B запитує /notes/ 
→ selectors.get_notes_for_user(user=B)
→ Note.objects.filter(Q(user=B) | Q(group__in=B.groups.all()))
→ повертає нотатки B + нотатки shared-груп де B є членом
```

### Flow 4: Login/session flow

```text
Browser POST /accounts/login/
→ Django AuthenticationForm.is_valid()
→ authenticate(username, password)
→ login(request, user) — створює session у DB/cache
→ Set-Cookie: sessionid=...
→ redirect
Наступний запит
→ SessionMiddleware читає cookie → session → request.user
```

### Flow 5: WebSocket connection flow

```text
Browser: new WebSocket('ws://host/ws/groups/5/chat/')
→ HTTP Upgrade → Nginx → Daphne
→ ProtocolTypeRouter → AuthMiddlewareStack
→ session cookie → scope["user"] = authenticated user
→ URLRouter → GroupChatConsumer.connect()
→ permission check: user in group
→ self.channel_layer.group_add(group_name, self.channel_name)
→ load_history() → database_sync_to_async
→ self.send(json.dumps(history))
```

### Flow 6: Chat message persistence flow

```text
Browser: ws.send(JSON.stringify({message: "Hello"}))
→ GroupChatConsumer.receive(text_data)
→ json.loads(text_data)
→ database_sync_to_async: ChatMessage.objects.create(group, author, content)
→ PostgreSQL INSERT
→ self.channel_layer.group_send(group_name, {type:'chat.message', ...})
→ GroupChatConsumer.chat_message() на кожному підключеному клієнті
→ self.send(text_data=json.dumps({author, message, timestamp}))
→ Browser: ws.onmessage → DOM update
```

### Flow 7: Test execution flow

```text
docker compose run --rm web python manage.py test notes_app.tests.test_consumers
→ TransactionTestCase.setUp() — create User, Group (committed immediately)
→ WebsocketCommunicator(application, url, headers)
→ communicator.connect() → ASGI → Consumer.connect()
→ consumer reads DB from worker thread → sees committed data
→ assertions
→ communicator.disconnect()
→ TransactionTestCase teardown — DELETE без rollback
```

### Flow 8: Docker startup flow

```text
docker compose up -d
→ db (postgres:16-alpine) → healthcheck
→ redis:7-alpine → healthcheck
→ web (Dockerfile) → entrypoint:
   manage.py migrate
   [if SEED_DEMO_DATA=1] manage.py seed_demo_data
   daphne -b 0.0.0.0 -p 8001 notes_project.asgi:application
→ nginx:1.27-alpine → reverse proxy :80 → web:8001
→ ngrok (якщо налаштовано)
→ selenium (для E2E tests)
```

### Flow 9: Todo sharing flow

```text
User A створює TodoList → TodoList.user = A
User A додає Group до TodoList → TodoList.group = G
User B (член G) запитує TodoLists
→ selectors: Q(user=B) | Q(group__in=B.groups.all())
→ TodoList A видно для B
User B не може delete — write permission: лише owner
```

### Flow 10: Group creation flow

```text
Browser POST /groups/new/
→ GroupCreateForm(request.POST).is_valid()
→ services: Group.objects.create(name=...) — Django built-in Group
→ request.user.groups.add(group)
→ redirect → group detail
```

### Flow 11: Shopping list sharing flow

```text
Аналогічно Todo sharing (Flow 9), але з ShoppingList/ShopItem
ShopItem: store_name, quantity (Decimal), is_purchased, unit, estimated_price
```
