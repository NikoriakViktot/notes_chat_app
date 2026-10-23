# Notes Chat App — Deep Dive

`notes_chat_app` is the final project of the course, built on Django 5.2. It combines CRUD, group sharing of objects, a WebSocket chat, a full testing pyramid, and Docker Compose in a single codebase.

---

## Navigation

| Document | Purpose |
|----------|-------------|
| **[Project Overview](project_overview.md)** | roles, stack, architectural patterns |
| **[Architecture](architecture.md)** | components, ASGI routing, layers, Docker |
| **[Domain Model](domain_model.md)** | 10 models, ER diagram, fields, deletion behavior |
| **[Feature Map](feature_map.md)** | what is implemented and where in the code |
| **[Request Flows](request_flows.md)** | HTTP CRUD, auth, WebSocket flows (Mermaid) |
| **[Security Model](security_model.md)** | IDOR, Q-filter, group sharing, WebSocket auth |
| **[Async and Chat](async_and_chat.md)** | ASGI, GroupChatConsumer, channel layer |
| **[Background Tasks](background_tasks.md)** | Celery Worker, Beat, email reminders, Browser Toast |
| **[Testing Strategy](testing_strategy.md)** | 7 test files, 200+ tests, TransactionTestCase |
| **[Setup](setup.md)** | running with Docker Compose |
| **[Deployment](deployment.md)** | Docker services, production checklist |
| **[Student Tasks](student_tasks.md)** | practical tasks at 3 levels |

---

## Architecture at a glance

```mermaid
flowchart TD
    Browser --> Nginx["Nginx :80<br>(reverse proxy, static)"]
    Nginx -->|HTTP| Uvicorn["Uvicorn :8001<br>ASGI server"]
    Nginx -->|WebSocket upgrade| Uvicorn

    Uvicorn --> Router["ProtocolTypeRouter<br>notes_project/asgi.py"]
    Router -->|http| HTTP["Django HTTP stack"]
    Router -->|websocket| Auth["AuthMiddlewareStack<br>→ URLRouter"]

    HTTP --> Views["views.py<br>(thin layer)"]
    Views --> Forms["forms.py<br>(validation)"]
    Views --> Sel["selectors.py<br>(read-only ORM)"]
    Views --> Srv["services.py<br>(mutations)"]
    Sel --> ORM["Django ORM"]
    Srv --> ORM
    ORM --> PG[("PostgreSQL :5432")]

    Auth --> Consumer["GroupChatConsumer<br>consumers.py"]
    Consumer -->|database_sync_to_async| ORM
    Consumer -->|group_send| Redis[("Redis :6379<br>channel layer")]
    Redis -->|chat_message| Consumer

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,Nginx,Uvicorn,HTTP,Forms,Sel,Srv,ORM,Auth,Consumer step;
    class Router decision;
    class PG,Redis success;
    class Views warning;
```

---

## File structure

```
notes_chat_app/
├── notes_project/           ← Django project package
│   ├── settings.py          ← apps, DB, Channels, Redis, static, auth
│   ├── urls.py              ← root URLs: admin, accounts, app include
│   ├── asgi.py              ← ProtocolTypeRouter (http + websocket)
│   └── routing.py           ← WebSocket URL: /ws/groups/<pk>/chat/
│
├── notes_app/               ← the single Django app
│   ├── models.py            ← 10 models + constraints
│   ├── urls.py              ← 35+ URL routes
│   ├── views.py             ← FBV, @login_required, thin layer
│   ├── forms.py             ← NoteForm, GroupCreateForm, ...
│   ├── selectors.py         ← read-only QuerySets, access scoping
│   ├── services.py          ← mutations: create/update/delete
│   ├── consumers.py         ← GroupChatConsumer (AsyncWebsocketConsumer)
│   ├── tasks.py             ← @shared_task send_reminder_notifications (Celery)
│   ├── admin.py             ← model registration
│   └── tests/
│       ├── test_models.py
│       ├── test_services.py
│       ├── test_forms.py
│       ├── test_views.py
│       ├── test_consumers.py
│       ├── test_tasks.py
│       └── test_selenium.py
│
├── templates/               ← project-level templates
│   ├── base.html            ← DOCTYPE, head, navbar, messages
│   └── layouts/
│       └── dashboard.html   ← sidebar, content block
│
├── notes_app/templates/notes_app/   ← app-level templates
├── notes_app/static/notes_app/js/
│   ├── group_chat.js        ← WebSocket JS client
│   └── reminders.js         ← HTTP polling + Bootstrap Toast
│
├── nginx/
│   └── nginx.conf           ← proxy_pass, WebSocket upgrade, static
├── docker-compose.yml       ← db, redis, web, nginx, ngrok, selenium, celery-worker, celery-beat
├── Dockerfile
└── entrypoint.sh            ← wait-for-db, migrate, collectstatic, seed
```

---

## Layer model

```
HTTP Request
  └─► notes_project/urls.py  (include notes_app.urls)
       └─► notes_app/urls.py  (@login_required, path)
            └─► views.py  (coordination only)
                 ├─► forms.py      (validation, clean_*)
                 ├─► selectors.py  (scoped QuerySet — read)
                 └─► services.py   (create/update/delete)
                      └─► models.py → PostgreSQL
```

Rule: `views.py` contains no ORM queries. `selectors.py` contains no mutations. `services.py` knows nothing about HTTP.

---

## Domain Model

```mermaid
erDiagram
    AUTH_USER ||--|| USER_PROFILE : "1:1 CASCADE"
    AUTH_USER ||--o{ NOTEBOOK : "1:N CASCADE"
    AUTH_USER ||--o{ NOTE : "1:N CASCADE"
    AUTH_USER ||--o{ TAG : "1:N CASCADE"
    AUTH_USER ||--o{ TODO_LIST : "1:N CASCADE"
    AUTH_USER ||--o{ SHOPPING_LIST : "1:N CASCADE"
    AUTH_USER ||--o{ CHAT_MESSAGE : "1:N CASCADE"

    AUTH_GROUP ||--o{ NOTE : "FK SET_NULL"
    AUTH_GROUP ||--o{ SHOPPING_LIST : "FK SET_NULL"
    AUTH_GROUP ||--o{ CHAT_MESSAGE : "1:N CASCADE"

    AUTH_USER }o--o{ TODO_LIST : "shared_with M2M"
    AUTH_USER }o--o{ SHOPPING_LIST : "shared_with M2M"

    NOTEBOOK ||--o{ NOTE : "FK SET_NULL"
    NOTE }o--o{ TAG : "M2M"
    NOTE ||--o{ REMINDER : "1:N CASCADE"
    TODO_LIST ||--o{ TODO_ITEM : "1:N CASCADE"
    SHOPPING_LIST ||--o{ SHOP_ITEM : "1:N CASCADE"
```

### Key models

| Model | Specifics |
|--------|-------------|
| `Note` | `priority` 1–4 (`PositiveSmallIntegerField`, `CheckConstraint`), `group FK SET_NULL`, `notebook FK SET_NULL`, `tags M2M` |
| `TodoList` | `shared_with M2M(User)` — shared access through direct sharing |
| `ShoppingList` | `shared_with M2M(User)` + `group FK SET_NULL` — two kinds of sharing |
| `ChatMessage` | `author FK CASCADE`, `group FK CASCADE` — no SET_NULL; when a group is deleted, its messages are deleted |
| `Reminder` | `CASCADE` from `Note` — when a note is deleted, its reminders are deleted |
| `UserProfile` | `OneToOneField(User, CASCADE)` — `display_name(100)`, `bio`, `avatar_url`, `timezone` |

### Deletion behavior

```text
User deleted       → all of their Note, Notebook, Tag, TodoList, ShoppingList, ChatMessage → CASCADE
Notebook deleted   → Note.notebook → SET_NULL  (notes are not deleted)
Note deleted       → Reminder → CASCADE
Group deleted      → Note.group → SET_NULL, ShoppingList.group → SET_NULL
                   → ChatMessage → CASCADE  (messages are deleted!)
TodoList deleted   → TodoItem → CASCADE
ShoppingList deleted → ShopItem → CASCADE
```

---

## URL routes

All routes are defined in `notes_app/urls.py`.

### Notes

| URL | Name | View |
|-----|------|------|
| `/notes/` | `note_list` | `note_list` |
| `/notes/new/` | `note_create` | `note_create` |
| `/notes/<pk>/` | `note_detail` | `note_detail` |
| `/notes/<pk>/edit/` | `note_edit` | `note_edit` |
| `/notes/<pk>/delete/` | `note_delete` | `note_delete` |

### Todo

| URL | Name | View |
|-----|------|------|
| `/todo/` | `todo_list` | `todo_list_list` |
| `/todo/new/` | `todo_create` | `todo_list_create` |
| `/todo/<pk>/` | `todo_detail` | `todo_list_detail` |
| `/todo/<pk>/share/` | `todo_share` | `todo_list_share` |
| `/todo/<pk>/items/add/` | `todo_item_add` | `todo_item_add` |
| `/todo/items/<pk>/toggle/` | `todo_item_toggle` | `todo_item_toggle` |

### Shopping

| URL | Name | View |
|-----|------|------|
| `/shopping/` | `shopping_list` | `shopping_list_list` |
| `/shopping/new/` | `shopping_create` | `shopping_list_create` |
| `/shopping/<pk>/share/` | `shopping_share` | `shopping_list_share` |
| `/shopping/<pk>/items/add/` | `shop_item_add` | `shop_item_add` |
| `/shopping/items/<pk>/toggle/` | `shop_item_toggle` | `shop_item_toggle_purchased` |

### Groups and Chat

| URL | Name | View |
|-----|------|------|
| `/groups/` | `group_list` | `group_list` |
| `/groups/new/` | `group_create` | `group_create` |
| `/groups/<pk>/` | `group_detail` | `group_detail` |
| `/groups/<pk>/delete/` | `group_delete` | `group_delete` |
| `/groups/<pk>/chat/` | `group_chat` | `group_chat` |

### WebSocket

```
ws://host/ws/groups/<pk>/chat/
```

Defined in `notes_project/routing.py`.

---

## Selectors

`notes_app/selectors.py` is the read-only ORM layer; it always returns materialized data or a `QuerySet` before rendering.

| Function | What it returns |
|---------|-------------|
| `get_user_notes(user, *, archived, notebook, tag, search)` | `QuerySet[Note]` with `select_related('notebook')`, `prefetch_related('tags')` |
| `get_note_detail(user, note_id)` | `Note` or `None` (owner + group members) |
| `get_pinned_notes(user, limit=5)` | `QuerySet[Note]` |
| `get_user_notebooks(user)` | `QuerySet[Notebook]` |
| `get_user_tags(user)` | `QuerySet[Tag]` |
| `get_user_todo_lists(user)` | `QuerySet[TodoList]` (own) |
| `get_shared_todo_lists(user)` | `QuerySet[TodoList]` (shared_with) |
| `get_todo_list_detail(user, pk)` | `TodoList` or `None` |
| `get_user_shopping_lists(user)` | own shopping lists |
| `get_shared_shopping_lists(user)` | shared_with lists |
| `get_shopping_list_detail(user, pk)` | with group access |
| `get_user_groups(user)` | `QuerySet[Group]` where the user is a member |
| `get_group_with_members(group_id, user)` | group + prefetched members |
| `get_pending_reminders()` | reminders with `remind_at <= now` |

**Access rule for shared objects:**

```python
# read: the owner OR a group member
Q(user=user) | Q(group__in=user.groups.all())

# write: the owner only
Q(user=user)
```

---

## Services

`notes_app/services.py` contains mutating operations; they are called only after form validation.

### Notes

```python
create_note(*, user, title, content='', notebook=None, priority=1, group=None, tag_ids=None)
update_note(note, *, title=None, content=None, priority=None, notebook=None,
            is_pinned=None, group=..., tag_ids=None)
delete_note(note)
toggle_pin_note(note)   # flip is_pinned
archive_note(note)      # is_archived = True
```

`group=...` (Ellipsis) in `update_note` is a sentinel meaning "do not change". `group=None` removes the group.

### Notebooks, Tags

```python
create_notebook(*, user, title, color='#4A90E2', is_default=False)
update_notebook(notebook, *, title, description='', color, is_default)
delete_notebook(notebook)
create_or_get_tag(*, user, name, color='#808080')   # get_or_create
```

### Todo

```python
create_todo_list(*, user, title, description='')
share_todo_list(todo_list, username)    # adds to shared_with
unshare_todo_list(todo_list, username)
add_todo_item(todo_list, *, text, due_date=None)
toggle_todo_item(item)
```

### Shopping

```python
create_shopping_list(*, user, title, store_name='', group=None)
share_shopping_list(shopping_list, username)
add_shop_item(shopping_list, *, name, quantity=1, unit='шт', estimated_price=None)
toggle_shop_item_purchased(item)
```

### Groups

```python
create_group(*, name, creator)    # creates a Group + adds creator as a member
add_user_to_group(group, username)
```

---

## GroupChatConsumer

`notes_app/consumers.py` contains the single WebSocket consumer.

```python
class GroupChatConsumer(AsyncWebsocketConsumer):
    async def connect(self)          # auth + membership check → accept or close
    async def disconnect(self, code) # group_discard
    async def receive(self, text_data) # JSON parse → save_message → group_send
    async def chat_message(self, event) # broadcast from the channel layer → send to the client

    # sync helpers (called via database_sync_to_async)
    def check_membership(self, group_pk, user)  → bool
    def load_history(self, group_pk)            → list[dict]  # the latest 50
    def save_message(self, group_pk, user, content) → ChatMessage
```

**ASGI import order** (`asgi.py`):

```python
# CORRECT: django.setup() → get_asgi_application() → import consumers
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
django_asgi_app = get_asgi_application()   # ← BEFORE any notes_app import
from notes_app.consumers import GroupChatConsumer  # ← only AFTER
```

**database_sync_to_async + materialization:**

```python
# ✅ correct: list() materializes the data before it leaves the worker
history = await database_sync_to_async(self.load_history)(group_pk)

def load_history(self, group_pk):
    return list(
        ChatMessage.objects.filter(group_id=group_pk)
        .select_related('author')
        .order_by('-created_at')[:50]
        .values('content', 'author__username', 'created_at')
    )
```

---

## Security

### IDOR protection

All object-level queries use a scoped queryset, never a bare `.get(pk=pk)`:

```python
# selectors.py
def get_note_detail(user, note_id):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        pk=note_id
    ).select_related('notebook', 'group').prefetch_related('tags').first()
```

If the result is `None`, the view returns `Http404`.

### Permission matrix

| Object | Read | Write (edit/delete) |
|--------|------|---------------------|
| Note | owner + group members | owner only |
| Notebook | owner | owner |
| Tag | owner | owner |
| TodoList | owner + `shared_with` | owner |
| ShoppingList | owner + `shared_with` + group | owner |
| ChatMessage | group members (WS) | — |

### WebSocket authentication

`AuthMiddlewareStack` reads the session cookie during the WS handshake → `scope["user"]`.
The consumer checks `user.is_authenticated` and `check_membership()` in `connect()`.
An unauthenticated user or a non-member → `await self.close()`.

---

## Testing pyramid

| File | Class | Count | What it tests |
|------|------|-----------|-----------|
| `test_models.py` | `TestCase` | ~25 | constraints, `__str__`, on_delete |
| `test_services.py` | `TestCase` | ~65 | return value + persistence |
| `test_forms.py` | `TestCase` | ~20 | valid/invalid data, `clean_*` |
| `test_views.py` | `TestCase` | ~85 | status codes, redirects, IDOR |
| `test_consumers.py` | **`TransactionTestCase`** | ~10 | WS connect, message, reject |
| `test_tasks.py` | `TestCase` | ~18 | Celery task, email, repeat, JSON view |
| `test_selenium.py` | `StaticLiveServerTestCase` / `ChannelsLiveServerTestCase` | ~23 | E2E flow + Toast notifications |
| **Total** | | **200+** | |

**Why `TransactionTestCase` for consumers:**

```text
TestCase wraps each test in a transaction → rollback afterwards.
The async consumer reads the DB from a separate worker thread —
  that thread does not see TestCase's uncommitted transaction.
→ setUp objects "disappear" for the consumer.
→ ALWAYS use TransactionTestCase for WebSocket tests.
```

**Running:**

```bash
# unit + integration + consumer
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium (requires the running stack)
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

---

## Docker Compose

```yaml
services:
  db:             # postgres:16-alpine, volume postgres_data
  redis:          # redis:7-alpine — DB 0: Channels, DB 1: Celery
  web:            # Django + Uvicorn :8001, depends on db + redis
  nginx:          # nginx:1.27-alpine, :80, proxy_pass to web, serves static
  ngrok:          # public HTTPS tunnel (development, profile tunnel)
  selenium:       # Selenium standalone Chrome for E2E tests (profile test)
  selenium-tests: # runs test_selenium against selenium (profile test)
  celery-worker:  # runs @shared_task, --concurrency=2
  celery-beat:    # scheduler (exactly 1 instance), CELERY_BEAT_SCHEDULE
```

`entrypoint.sh` runs on every start:

```bash
# db and redis are already healthy (depends_on: condition: service_healthy)
python manage.py migrate --noinput
python manage.py collectstatic --noinput
[optional] python manage.py seed_demo_data --force
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --proxy-headers [--reload]
```

---

## End-to-end scenario: Create Note

```
Browser                    views.py           forms.py      services.py    PostgreSQL
   |                          |                  |               |              |
   |-- GET /notes/new/ ------>|                  |               |              |
   |<---- NoteForm (empty) ---|                  |               |              |
   |                          |                  |               |              |
   |-- POST /notes/new/ ----->|                  |               |              |
   |  (title, content, tags)  |-- NoteForm(data) ->             |              |
   |                          |<- cleaned_data --|               |              |
   |                          |-- create_note(user, **data) ---->|              |
   |                          |                  |  INSERT Note -|------------->|
   |                          |                  |  <-- Note pk -|-------------|
   |<-- redirect /notes/<pk>--|                  |               |              |
```

---

## End-to-end scenario: WebSocket Chat

```
Browser JS                 Nginx      Uvicorn   GroupChatConsumer    Redis
    |                        |           |              |               |
    |-- WS connect ---------->           |              |               |
    |  (Cookie: sessionid=...)            |              |               |
    |                        |-- upgrade ->             |               |
    |                        |           |-- connect() ->               |
    |                        |           |   check_membership()         |
    |                        |           |   group_add(channel_name) -->|
    |                        |           |   accept() + load_history()  |
    |<-- history JSON --------|-----------|<- send() ----|               |
    |                        |           |              |               |
    |-- send message -------->           |              |               |
    |  {"content": "Hello"}   |-- text -->              |               |
    |                        |           |-- receive() ->               |
    |                        |           |   save_message() → DB        |
    |                        |           |   group_send() ------------->|
    |                        |           |                              |
    |                        |           |<-- chat_message event -------|
    |<-{"type":"message",...}-|-----------|<- send() ----|               |
```

---

## Common pitfalls

| Situation | Error | Solution |
|----------|---------|---------|
| Lazy QuerySet from an async consumer | `SynchronousOnlyOperation` | `list()` inside `database_sync_to_async` |
| `get_asgi_application()` after importing notes_app | `AppRegistryNotReady` | reorder the imports in `asgi.py` |
| `TestCase` for a consumer | setUp objects disappear | `TransactionTestCase` |
| Redis `socket_timeout` is not `None` | `TimeoutError` on an idle WS | `"socket_timeout": None` in `CONFIG` |
| `DebugExceptionMiddleware` without `if DEBUG:` | traceback in the HTTP response in prod | wrap it in `if DEBUG:` in `settings.py` |
| `note.group = group_instance; note.save()` in a selector | layer violation (mutation) | move it to `services.py` |
