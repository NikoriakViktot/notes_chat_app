# Zero to Hero: the path from zero to production

This route takes you from an empty directory to a production-ready Django application with a WebSocket chat, Docker Compose, authentication and CI.

Each step solves **one specific problem** and leaves behind a working application.

---

## Route map

```
[0] Environment ──► [1] Hello Django ──► [2] First model ──► [3] CRUD + arch
                                                                      │
                                                                      ▼
[9] Deployment ◄── [8] Celery ◄── [7] WebSocket ◄── [6] Tests ◄── [5] Auth ◄── [4] Forms + UI
```

Steps 1–4 are standalone learning projects.
Steps 5–9 develop **notes_chat_app** (the final production application).

---

## Route projects

```text
hello_project        ← Step 1  — one view, SQLite, no models
bootstrap_notes      ← Step 2  — the first model, Django Admin
notes_project        ← Step 3  — CRUD, selectors/services, PostgreSQL
crispy_notes         ← Step 4  — ModelForm, Bootstrap 5, template inheritance
notes_chat_app       ← Steps 5–9 — auth, testing, WebSocket, Celery, Docker, CI
```

Each standalone project is a **separate repository**, not a branch of notes_chat_app.
It shows only the concept needed at that step.

---

## Summary table of steps

| # | Name | Project | New concept | Knowledge | Completion criterion |
|--:|-------|--------|---------------|-----------|---------------------|
| 0 | [Environment](#step-0-environment) | — | Python, pyenv, Docker | — | `python -c "import django; print(django.__version__)"` |
| 1 | [Hello Django](#step-1-hello-django) | hello_project | MTV, URLconf, HttpResponse | I, II | `curl http://127.0.0.1:8000/` → 200 |
| 2 | [First model](#step-2-the-first-model) | bootstrap_notes | ORM, migration, Admin | III | a DB record through Admin |
| 3 | [CRUD + arch](#step-3-crud-and-architecture) | notes_project | selectors/services, PostgreSQL | VI | a unit TestCase passes |
| 4 | [Forms + UI](#step-4-forms-and-bootstrap) | crispy_notes | ModelForm, Bootstrap 5 | IV, V | a crispy form in the browser |
| 5 | [Auth + security](#step-5-authentication-and-security) | notes_chat_app | IDOR, Q-filter, Groups | VII | the IDOR test fails without the fix and passes after it |
| 6 | [Testing](#step-6-testing) | notes_chat_app | TransactionTestCase, Selenium | VIII | 200+ tests green |
| 7 | [WebSocket](#step-7-async-and-websocket) | notes_chat_app | Channels, Redis, ASGI | IX | the consumer test passes |
| 8 | [Celery](#step-8-celery-and-background-tasks) | notes_chat_app | Celery Worker, Beat, Redis broker, HTTP polling | IX | reminders arrive by email + toast in the browser |
| 9 | [Deployment](#step-9-deployment-and-ci) | notes_chat_app | Docker Compose, Nginx, CI | X | GitHub Actions: green |

---

## Step 0. Environment

**Problem:** nothing runs.

**What we install:** Python (through pyenv), Git, Docker Desktop, VS Code + the Python extension.

**Check:**

```bash
python --version        # 3.12.x
docker version          # Engine: 24+
git --version           # 2.x
python -c "import django; print(django.__version__)"  # 5.2.x
```

**New concepts:** virtual environment, PATH, Docker daemon.

---

## Step 1. Hello Django

> **Tutorial:** [01: The first Django page](01_first_django_page.md) · **In detail:** [README_1](README_1.md)

**Problem:** how do you make a browser get a response from Python?

**What we build:** `hello_project`, an empty Django project with one view.

```bash
django-admin startproject hello_project .
python manage.py runserver
```

**Architecture at this step:**

```
Browser → urls.py → view function → HttpResponse
```

**New concepts:** MTV, URLconf, `HttpResponse`, `DEBUG`, `INSTALLED_APPS`.

**Common mistakes:**
- `ModuleNotFoundError: No module named 'django'`: the virtual environment is not activated
- `Error: That port is already in use`: another `runserver` is running

**Notes Chat App:** a similar structure `notes_project/urls.py` → `notes_app/views.py`, but with 15+ views instead of one.

---

## Step 2. The first model

> **Tutorial:** [02: The first model](02_first_model.md) · **In detail:** [README_2](README_2.md)

**Problem:** data disappears after the server restarts.

**What we build:** `bootstrap_notes`, a project with a `Note` model, migrations and Django Admin.

```python
class Note(models.Model):
    title   = models.CharField(max_length=200)
    content = models.TextField()
    created = models.DateTimeField(auto_now_add=True)
```

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

**Architectural change:** stateless HTTP → data is stored in SQLite between requests.

**New concepts:** `models.Model`, migration graph, `__str__`, `ForeignKey`, `on_delete`, Django Admin, QuerySet.

**Common mistakes:**
- Forgetting `makemigrations` after changing a model
- `IntegrityError: NOT NULL constraint`: a required field without a default

**Notes Chat App:** `notes_app/models.py` has 10 models with ForeignKey, M2M and `on_delete=CASCADE` / `SET_NULL`. SQLite is replaced by PostgreSQL starting from Step 3.

---

## Step 3. CRUD and architecture

> **Tutorial:** [03: CRUD](03_crud.md) · **In detail:** [README_3](README_3.md) · **CBV:** [README_4](README_4.md)

**Problem:** the view gets fat: ORM queries, validation and HTTP logic are mixed in one function.

**What we build:** `notes_project`, CRUD with `selectors.py` and `services.py`, PostgreSQL.

**Pedagogical evolution:**

```text
def note_list(request):
    notes = Note.objects.filter(user=request.user)  # ORM in the view
    ...

# Duplicated in 5 views → we extract it:

# selectors.py
def get_notes_for_user(user):
    return Note.objects.filter(user=user)  # read only

# services.py
def create_note(user, title, content):
    return Note.objects.create(user=user, title=title, content=content)  # mutation only
```

**Moving from SQLite → PostgreSQL:**

```text
SQLite: no full FOREIGN KEY constraints, limited concurrent writes
PostgreSQL: transactions, indexes, ON DELETE CASCADE/SET NULL, UNIQUE constraints
```

**New concepts:** PRG (Post/Redirect/Get), thin view, selector (read-only), service (mutation), `get_object_or_404`.

**Common mistakes:**
- Returning a lazy QuerySet from a selector → `SynchronousOnlyOperation` in an async context
- A mutation in a selector (a layer violation)
- `TypeError` if the view and service parameters do not match

---

## Step 4. Forms and Bootstrap

> **Tutorial:** [04: Templates + Bootstrap](04_templates_bootstrap.md) · **In detail:** [README_5](README_5.md)

**Problem:** HTML forms look bad, and validation is duplicated in the view and the template.

**What we build:** `crispy_notes`: `ModelForm`, crispy-forms, Bootstrap 5, a SaaS dashboard.

```python
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority']

    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title) < 3:
            raise ValidationError("Заголовок занадто короткий.")
        return title
```

**Template inheritance:**

```
templates/base.html           ← DOCTYPE, head, navbar
└── templates/layouts/dashboard.html  ← sidebar, content block
    └── notes_app/note_list.html       ← a specific page
```

**FBV vs CBV:**

```text
FBV: explicit if request.method == 'POST': more code, but more transparent
CBV: CreateView, UpdateView: less boilerplate, but harder to debug
→ notes_chat_app chooses FBV for explicitness and flexibility with permissions
```

**New concepts:** `ModelForm`, `clean_<field>`, CSRF, `{{ form|crispy }}`, `{% extends %}`, `{% block %}`, `{% include %}`.

---

## Step 5. Authentication and security

> **Tutorial:** [05: Auth and security](05_authentication.md) · **In detail:** [README_6](README_6.md)

**Problem:** anyone can read and edit other people's notes (IDOR).

**What we add to notes_chat_app:**

- `@login_required`: only authenticated users see notes
- Object-level permissions: `Note.user == request.user OR group`
- `UserProfile` (1:1 to `User`)
- `Group` sharing: several users have shared access
- Password reset flow

**The IDOR attack and the defense:**

```python
# VULNERABLE: only login is checked, not ownership
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)  # any note at all!
    ...

# SAFE: Q-filter by owner and group
def get_note_for_user(pk, user):
    user_groups = user.groups.all()
    return get_object_or_404(
        Note,
        Q(pk=pk) & (Q(user=user) | Q(group__in=user_groups))
    )
```

**New concepts:** `request.user`, `login_required`, sessions, `UserProfile`, `Q` objects, IDOR, `AbstractBaseUser`, password hashing, `authenticate()`.

**Common mistakes:**
- `@login_required` ≠ an object-level permission → IDOR
- Checking `note.user == request.user` without accounting for group sharing

---

## Step 6. Testing

> **Tutorial:** [06: Testing](06_testing.md) · **In detail:** [README_7](README_7.md)

**Problem:** refactoring breaks things nobody notices.

**Test suite architecture:**

```text
test_models.py    — check constraints, __str__, on_delete behaviour
test_services.py  — check the return value + persistence
test_forms.py     — valid data, invalid data, custom clean_
test_views.py     — Client + force_login, status codes, redirect targets
test_consumers.py — WebsocketCommunicator + TransactionTestCase (not TestCase!)
test_selenium.py  — E2E in a real browser (StaticLiveServerTestCase)
```

**Critical: TransactionTestCase for consumer tests:**

```text
TestCase wraps each test in a transaction → rollback after the test.
An async consumer reads the DB from a separate worker thread —
  that transaction is invisible to it → the setUp objects "disappear".
ALWAYS use TransactionTestCase for consumer tests.
```

**Running:**

```bash
# Unit + integration + consumer
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium E2E (requires the stack to be running)
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

**New concepts:** AAA (Arrange/Act/Assert), `setUp`, `force_login`, `WebsocketCommunicator`, `StaticLiveServerTestCase`, CI YAML.

---

## Step 7. Async and WebSocket

> **Tutorial:** [07: Async and WebSocket](07_async.md) · **In detail:** [README_8](README_8.md) · [README_9](README_9.md)

**Problem:** HTTP request/response is not suitable for real time: 100 clients = 100 requests/sec with polling.

**Pedagogical evolution:**

```text
HTTP polling
  setInterval(() => fetch('/new-messages/'), 1000)
  → 100 clients = 100 requests/sec: inefficient

WebSocket
  → one long-lived connection
  → the server can push events without a request from the client
  → Django Channels: an ASGI handler for WS
  → Redis channel layer: broadcast to a group
```

**The ASGI stack:**

```
Browser WS connect
  → Nginx (proxy_pass ws://)
  → Daphne ASGI server
  → ProtocolTypeRouter (asgi.py)
  → AuthMiddlewareStack  (reads the session cookie → scope["user"])
  → URLRouter (routing.py: /ws/groups/<pk>/chat/)
  → GroupChatConsumer
```

**Critical implementation details:**

```python
# asgi.py: get_asgi_application() BEFORE importing notes_app
django.setup() → get_asgi_application() → from notes_app.consumers import ...

# consumers.py: never call the sync ORM directly
history = await database_sync_to_async(
    lambda: list(ChatMessage.objects.filter(group=group_pk).values(...))
)()  # list() materializes the QuerySet BEFORE leaving the worker

# RedisChannelLayer (settings.py):
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL], "socket_timeout": None},
        #                                 ^^^^^^^^^^^^^^^^^^^
        #                     None = no timeout for idle WS
    }
}
```

**New concepts:** `asyncio`, coroutine, `await`, ASGI vs WSGI, `AsyncWebsocketConsumer`, channel layer, `group_send`, `database_sync_to_async`.

---

## Step 8. Celery and background tasks

> **Tutorial:** [08: Celery and background tasks](08_celery.md)

**Problem:** Django cannot send an email at exactly the scheduled time: a view runs only in response to a request.

**Two levels of reminders:**

```text
Email (Celery Worker)
  Celery Beat → every 60 sec → @shared_task send_reminder_notifications()
  → Reminder.filter(remind_at__lte=now, is_sent=False)
  → send_mail() → reminder.is_sent = True
  → _schedule_next() → a new Reminder if repeat_pattern ≠ none

Browser Toast (HTTP polling)
  reminders.js → every 60 sec → GET /reminders/check/
  → JsonResponse({reminders: [...]})
  → Bootstrap Toast for new ones (sessionStorage for deduplication)
```

**Redis DB allocation:**

```text
Redis DB 0 — Django Channels channel layer (WebSocket)
Redis DB 1 — Celery broker and result backend
```

**Docker Compose services:**

```yaml
celery-worker:
  command: celery -A notes_project worker -l info --concurrency=2
celery-beat:
  command: celery -A notes_project beat -l info   # exactly 1 instance!
```

**New concepts:** `@shared_task`, Celery Beat, broker, `CELERY_BEAT_SCHEDULE`, `relativedelta`, HTTP polling, Bootstrap Toast API, `sessionStorage`, `@override_settings(EMAIL_BACKEND=...)`, `mail.outbox`.

---

## Step 9. Deployment and CI

> **Tutorial:** [09: Deployment](09_deployment.md) · **In detail:** [README_9](README_9.md)

**Problem:** the application only works locally.

**The Docker Compose stack:**

```yaml
services:
  db:       # PostgreSQL + PostGIS
  redis:    # the channel layer for Channels
  web:      # Django (Daphne ASGI)
  nginx:    # reverse proxy, SSL termination, static files
  ngrok:    # a public HTTPS tunnel for development
  selenium: # Selenium Grid for E2E tests
```

**Production checklist:**

```text
✓ DEBUG=False
✓ SECRET_KEY — from env, not in the code
✓ DATABASE_URL — missing → Exception (no SQLite fallback!)
✓ ALLOWED_HOSTS — specific domains
✓ Static files — through Nginx, not Django
✓ DebugExceptionMiddleware — only if DEBUG=True
✓ HTTPS — CSRF_TRUSTED_ORIGINS, SESSION_COOKIE_SECURE
```

**GitHub Actions CI:**

```yaml
jobs:
  test:       # unit + integration + consumer tests
  selenium:   # E2E in Selenium Grid
```

**New concepts:** `Dockerfile`, multi-service `docker-compose.yml`, `ENTRYPOINT`, Nginx `proxy_pass`, `collectstatic`, the `.env` file, GitHub Actions workflow.

---

## Architectural evolution across the whole route

| Step | DB | Auth | Forms | Tests | Deploy | Background process |
|-----:|----|----|-------|-------|--------|----------------|
| 1 | SQLite (not used) | — | — | — | runserver | — |
| 2 | SQLite | — | Admin | — | runserver | — |
| 3 | PostgreSQL | — | raw HTML | TestCase | runserver | — |
| 4 | PostgreSQL | — | ModelForm + crispy | Form tests | runserver | — |
| 5 | PostgreSQL | login_required + Q-filter | ModelForm | IDOR test | runserver | — |
| 6 | PostgreSQL | ✓ | ✓ | 200+ tests | runserver | — |
| 7 | PostgreSQL | ✓ | ✓ | + consumer | Daphne ASGI | — |
| 8 | PostgreSQL | ✓ | ✓ | + test_tasks | Daphne ASGI | Celery Worker + Beat |
| 9 | PostgreSQL | ✓ | ✓ | + Selenium | Docker + Nginx + CI | Celery Worker + Beat |

---

## What's next

After finishing the Zero to Hero route:

- **[Notes Chat App Deep Dive](../12_final_project/README.md)**: a full architectural breakdown of the final application
- **[The Django book](../index.md)**: the theoretical foundation for deepening your knowledge
- **[Labs](../labs/README.md)**: practice without step-by-step hints
