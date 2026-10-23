# Repository Structure

> Knowing where everything lives is a basic skill for working with any Django project.
> Here is a map of `notes_chat_app`: every directory and the most important files.

---

## The full tree

```
notes_chat_app/
│
├── notes_project/              ← Django project package
│   ├── settings.py             ← all configuration (DB, INSTALLED_APPS, MIDDLEWARE...)
│   ├── urls.py                 ← main URL router (includes notes_app.urls)
│   ├── asgi.py                 ← ASGI entrypoint (HTTP + WebSocket)
│   ├── wsgi.py                 ← WSGI (NOT used, only for compatibility)
│   ├── routing.py              ← WebSocket URL patterns
│   └── celery.py               ← Celery application instance
│
├── notes_app/                  ← Django app — all business logic
│   ├── models.py               ← 10 models (Note, Tag, Notebook, TodoList...)
│   ├── views.py                ← FBV view functions (note_list, note_create...)
│   ├── urls.py                 ← URL patterns for notes_app
│   ├── forms.py                ← ModelForm classes (NoteForm, TodoForm...)
│   ├── services.py             ← mutating operations (create_note, delete_tag...)
│   ├── selectors.py            ← read-only QuerySets (get_user_notes, ...)
│   ├── consumers.py            ← WebSocket Consumer (GroupChatConsumer)
│   ├── tasks.py                ← Celery tasks (reminder notifications...)
│   ├── admin.py                ← Django Admin model registration
│   ├── apps.py                 ← AppConfig
│   ├── context_processors.py   ← global context variables for templates
│   ├── management/
│   │   └── commands/
│   │       └── seed_demo_data.py  ← command that fills the DB with demo data
│   ├── migrations/             ← migration files (auto-generated)
│   ├── static/
│   │   └── notes_app/
│   │       ├── css/app.css
│   │       └── js/
│   │           ├── group_chat.js   ← WebSocket client (JS)
│   │           └── reminders.js    ← polling (fetch) for reminders
│   ├── templates/
│   │   └── notes_app/          ← app-level templates
│   │       ├── note_list.html
│   │       ├── note_detail.html
│   │       ├── note_form.html
│   │       └── ...
│   └── tests/
│       ├── test_models.py      ← model unit tests
│       ├── test_services.py    ← service unit tests
│       ├── test_forms.py       ← form unit tests
│       ├── test_views.py       ← view integration tests
│       ├── test_consumers.py   ← WebSocket Consumer tests
│       ├── test_tasks.py       ← Celery task tests
│       └── test_selenium.py    ← E2E Selenium tests
│
├── templates/                  ← project-level templates
│   ├── base.html               ← base layout (navbar, sidebar, messages)
│   ├── components/             ← reusable components (pagination, confirm_modal...)
│   ├── layouts/                ← layouts (dashboard.html)
│   └── registration/           ← auth templates (login, register, password reset...)
│
├── nginx/
│   └── nginx.conf              ← nginx configuration (static files, WebSocket proxy)
│
├── docs/                       ← all documentation (this site!)
│   ├── 00_getting_started/     ← you are here
│   ├── 01_web_foundations/ ... ← theory parts
│   ├── tutorials/              ← Zero to Hero Steps 1-9
│   └── 12_final_project/       ← final project documentation
│
├── Dockerfile                  ← Django container image
├── docker-compose.yml          ← the whole stack (db, redis, web, nginx, celery-worker, celery-beat, selenium, selenium-tests, ngrok)
├── entrypoint.sh               ← migrate → collectstatic → seed → uvicorn
├── requirements.txt            ← Python dependencies
├── .env.example                ← environment variables template
├── mkdocs.yml                  ← documentation configuration (this site)
└── manage.py                   ← Django CLI entrypoint
```

---

## Key files and their roles

### `notes_project/settings.py` — the heart of the configuration

```python
# Everything important lives here:
DATABASES = {...}          # PostgreSQL connection via DATABASE_URL
INSTALLED_APPS = [
    'daphne',              # FIRST — overrides runserver for ASGI
    'channels',
    'notes_app',
    ...
]
CHANNEL_LAYERS = {...}     # Redis for WebSocket broadcast
MIDDLEWARE = [...]         # request processing chain
TEMPLATES = [...]          # where to look for .html templates
STATIC_ROOT = ...          # where collectstatic gathers files
```

### `notes_project/asgi.py` — the ASGI entry point

```python
# HTTP and WebSocket through one process:
application = ProtocolTypeRouter({
    'http': django_asgi_app,           # → Django views
    'websocket': AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns) # → GroupChatConsumer
    ),
})
```

### `notes_app/models.py` — all the project's models

This is where they live: `Note`, `Tag`, `Notebook`, `Reminder`, `TodoList`, `TodoItem`, `ShoppingList`, `ShopItem`, `UserProfile`, `ChatMessage`.

### `notes_app/views.py` + `selectors.py` + `services.py` — architecture layers

```
HTTP Request → views.py (coordination) → selectors.py (reading from the DB)
                                       → services.py (writing to the DB)
                                       → render(template)
```

---

## What NOT to edit

```
staticfiles/    ← collectstatic output, auto-generated (ignored by git)
.venv/          ← virtual environment (if you have a local one), not for editing
__pycache__/    ← Python bytecode, auto-generated
migrations/     ← do not edit by hand, only via makemigrations
```

---

## Where to look, by topic

| I want to find | Where to look |
|------------|------------|
| The URL for a specific page | `notes_app/urls.py` |
| Request handling logic | `notes_app/views.py` |
| A DB query | `notes_app/selectors.py` |
| A data-changing operation | `notes_app/services.py` |
| A model's structure | `notes_app/models.py` |
| Page HTML | `notes_app/templates/notes_app/` |
| WebSocket logic | `notes_app/consumers.py` |
| The JavaScript WebSocket client | `notes_app/static/notes_app/js/group_chat.js` |
| Docker configuration | `docker-compose.yml` |
| nginx configuration | `nginx/nginx.conf` |

---

## Practical exercise

Find these files in your editor and open each one:

1. `notes_project/settings.py` → find `INSTALLED_APPS` and look at the order
2. `notes_app/models.py` → count how many models there are
3. `notes_app/views.py` → find the `note_list` function
4. `notes_app/selectors.py` → find `get_user_notes`
5. `docker-compose.yml` → count how many services there are

---

## Next

→ [Step 1. Hello Django](../tutorials/01_hello_django/index.md) — let's start building
