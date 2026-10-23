# Tutorial 01 — My first Django project

> This tutorial takes you from an **empty folder** to a full-fledged Django site
> with view functions, URL routing, an admin panel, and your first model.
>
> **Result:**
> ```
> http://localhost:8000/        →  Hello, Django!
> http://localhost:8000/about/  →  This is my first Django page!
> http://localhost:8000/admin/  →  Admin panel (superuser)
> ```

---

## Contents

**Theory** _(read before the code)_
- [01 · HOW DJANGO HANDLES A REQUEST — from the browser to the response](#01--how-django-handles-a-request)
- [02 · PROJECT STRUCTURE — what each file means](#02--project-structure)
- [03 · MANAGE.PY — Django's command center](#03--managepy)
- [04 · SETTINGS.PY — anatomy of the configuration](#04--settingspy)
- [05 · URL PATTERNS — how Django finds a view](#05--url-patterns)

**Step-by-step implementation**
1. [Step 1 — Virtual environment](#step-1--virtual-environment)
2. [Step 2 — Install Django](#step-2--install-django)
3. [Step 3 — Create the project](#step-3--create-the-project)
4. [Step 4 — Apply migrations](#step-4--apply-migrations)
5. [Step 5 — Create a superuser](#step-5--create-a-superuser)
6. [Step 6 — Create an app](#step-6--create-an-app)
7. [Step 7 — Write view functions](#step-7--write-view-functions)
8. [Step 8 — URL routes](#step-8--url-routes)
9. [Step 9 — Check in the browser](#step-9--check-in-the-browser)
10. [Bonus — Your first model and the Django shell](#bonus--first-model)

---

## 01 · How Django handles a request

> **The most important question:** what happens when you type `http://localhost:8000/` into the browser?

### The full Request/Response cycle

```
Browser                    runserver (manage.py)              Django
   │                              │                              │
   │  GET /about/  ───────────────►                              │
   │                              │  ProtocolTypeRouter          │
   │                              │  (WSGI or ASGI)              │
   │                              │         │                    │
   │                              │  SecurityMiddleware          │
   │                              │  SessionMiddleware           │
   │                              │  CommonMiddleware            │
   │                              │  CsrfViewMiddleware          │
   │                              │  AuthenticationMiddleware    │
   │                              │  MessageMiddleware           │
   │                              │         │                    │
   │                              │  URLconf → hello_project/urls.py
   │                              │         │                    │
   │                              │  include → hello_app/urls.py │
   │                              │         │                    │
   │                              │  path('about/', about_view)  │
   │                              │         │                    │
   │                              │  about(request)              │
   │                              │         │                    │
   │                              │  HttpResponse("This is my...")
   │                              │         │                    │
   │  ◄───────────── 200 OK  ─────│         │                    │
   │  (body: "This is my first...")                              │
```

### Three participants

```
URLS.PY            → "Who will respond?"   path('about/', views.about)
VIEWS.PY           → "What to respond?"    return HttpResponse("...")
TEMPLATE/RESPONSE  → "What will it look like?"   a string or HTML
```

**A restaurant analogy:**
- `urls.py` = the host: "Table 5 — your waiter is Marko"
- `views.py` = the cook: receives the order and prepares the dish
- `HttpResponse` = the plate that goes back to the guest

---

## 02 · Project structure

After `django-admin startproject hello_project .` and `startapp hello_app` you will have:

```
./
├── manage.py               ← CLI: running the server, migrations, shell, tests
│
├── hello_project/          ← Project configuration (one for the whole project)
│   ├── __init__.py         ← Empty: makes the folder a Python package
│   ├── settings.py         ← All settings: DB, INSTALLED_APPS, TEMPLATES...
│   ├── urls.py             ← The main URLconf: includes the apps' urls.py
│   ├── wsgi.py             ← Entry point for WSGI servers (Gunicorn, uWSGI)
│   └── asgi.py             ← Entry point for ASGI servers (Uvicorn, Daphne)
│
├── hello_app/              ← An app (one of possibly several)
│   ├── __init__.py
│   ├── admin.py            ← Registering models in the Django Admin
│   ├── apps.py             ← AppConfig configuration
│   ├── models.py           ← Models: Python class → DB table
│   ├── views.py            ← View functions: request → response
│   ├── urls.py             ← The app's URLs (must be created by hand)
│   ├── forms.py            ← ModelForm and Form classes (must be created)
│   ├── migrations/         ← Automatically generated migration files
│   │   └── __init__.py
│   └── templates/          ← HTML templates (must be created)
│       └── hello_app/
│           └── index.html
│
└── db.sqlite3              ← The DB file (appears after migrate)
```

### Why are `hello_project/` and `hello_app/` different things?

```
hello_project/   = CONFIGURATION
  One for the whole site.
  settings.py, urls.py, wsgi.py.
  Contains no business logic.
  You rarely edit it after the initial setup.

hello_app/       = FUNCTIONALITY
  There can be several (notes_app, users_app, chat_app).
  models.py, views.py, forms.py, templates/.
  This is where all the application code lives.
  Each app = an isolated unit of functionality.
```

**Rule:** one `app` = one responsibility.
`notes_app` → notes. `users_app` → profiles. Don't mix everything into one big app.

---

## 03 · manage.py

`manage.py` is Django's CLI orchestrator. All interaction with the project goes through it.

### The most important commands

```bash
# ── Development server ──────────────────────────────────────────────────────
python manage.py runserver                 # http://localhost:8000/
python manage.py runserver 0.0.0.0:8080   # a different port and host (for the network)

# ── Migrations ──────────────────────────────────────────────────────────────
python manage.py makemigrations            # Generates a migration plan from models.py
python manage.py makemigrations hello_app  # Only for one app
python manage.py migrate                   # Applies all migrations to the DB
python manage.py migrate hello_app 0002    # Roll back to a specific migration
python manage.py showmigrations            # Show the state of all migrations

# ── Administration ───────────────────────────────────────────────────────────
python manage.py createsuperuser           # Create a superuser interactively
python manage.py changepassword alice      # Change a user's password

# ── Code generation ──────────────────────────────────────────────────────────
python manage.py startapp blog_app         # A new app
python manage.py startproject config .     # A new project configuration

# ── Interactive shell ────────────────────────────────────────────────────────
python manage.py shell                     # A Python shell with the Django context
python manage.py shell -i bpython          # Or ipython/bpython if installed

# ── SQL ──────────────────────────────────────────────────────────────────────
python manage.py sqlmigrate hello_app 0001 # Show the SQL that a migration will run
python manage.py dbshell                   # psql / sqlite3 shell

# ── Checks ───────────────────────────────────────────────────────────────────
python manage.py check                     # Check the configuration without running
python manage.py check --deploy            # Check the production settings

# ── Tests ────────────────────────────────────────────────────────────────────
python manage.py test                      # All tests
python manage.py test hello_app            # Tests of a specific app
python manage.py test hello_app.tests.test_models -v 2

# ── Static files ─────────────────────────────────────────────────────────────
python manage.py collectstatic             # Collect static files into STATIC_ROOT

# ── Data ────────────────────────────────────────────────────────────────────
python manage.py dumpdata hello_app.Note   # Export data to JSON
python manage.py loaddata fixtures.json   # Import data
```

### How does manage.py know about your project?

```python
# manage.py — the first line after the shebang:
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'hello_project.settings')
# ↑ Tells Django where to look for settings.py
# When running in Docker, this is often overridden via an ENV variable
```

---

## 04 · settings.py

`settings.py` is Django's brain. Read every setting, don't just copy it.

### The full anatomy of settings.py

```python
# hello_project/settings.py

# ── Security ─────────────────────────────────────────────────────────────────
SECRET_KEY = 'django-insecure-...'   # The secret for CSRF, sessions, signatures
# In production: read it from os.environ or a .env file!
# os.environ.get('SECRET_KEY') — never store it in git

DEBUG = True
# True:  detailed error pages with a traceback → ONLY in development
# False: Production → a generic error without a traceback → configure LOGGING

ALLOWED_HOSTS = []
# A list of domains that may access the site
# DEBUG=True → ALLOWED_HOSTS is not checked (localhost is always allowed)
# Production: ['example.com', 'www.example.com']
# ngrok/Docker: add their domain here or via env


# ── Installed apps ───────────────────────────────────────────────────────────
INSTALLED_APPS = [
    # Django built-ins — THE ORDER MATTERS for some operations:
    'django.contrib.admin',         # /admin/ — the admin panel
    'django.contrib.auth',          # The User model, login/logout
    'django.contrib.contenttypes',  # ContentType framework (generic relations)
    'django.contrib.sessions',      # Sessions: the django_session table
    'django.contrib.messages',      # Flash messages
    'django.contrib.staticfiles',   # Static files: /static/

    # Third-party (installed via pip):
    'django_bootstrap5',
    'crispy_forms',
    'crispy_bootstrap5',

    # Your apps — always AT THE END:
    'hello_app',
]
# If an app is listed here → Django looks for models, views, templates, static in it


# ── Middleware — the request processing chain ────────────────────────────────
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    # ↑ HTTPS redirect, HSTS, XSS protection headers

    'django.contrib.sessions.middleware.SessionMiddleware',
    # ↑ Loads the session from the DB → request.session

    'django.middleware.common.CommonMiddleware',
    # ↑ Adds the trailing slash, APPEND_SLASH

    'django.middleware.csrf.CsrfViewMiddleware',
    # ↑ Checks the CSRF token in POST requests → 403 if it is missing

    'django.contrib.auth.middleware.AuthenticationMiddleware',
    # ↑ Reads the session → sets request.user
    # IMPORTANT: after SessionMiddleware!

    'django.contrib.messages.middleware.MessageMiddleware',
    # ↑ Flash messages: messages.success(request, ...)

    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # ↑ X-Frame-Options: DENY → protection against clickjacking
]
# The order is critical! Middleware is called in sequence (request↓, response↑)


# ── URL configuration ────────────────────────────────────────────────────────
ROOT_URLCONF = 'hello_project.urls'
# Relative to DJANGO_SETTINGS_MODULE


# ── Templates ────────────────────────────────────────────────────────────────
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],  # Global templates (not in an app/)
    'APP_DIRS': True,                  # Look for templates/ in every app
    # APP_DIRS: True → django looks for hello_app/templates/hello_app/*.html
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            # ↑ request is available in the template as {{ request }}
            'django.contrib.auth.context_processors.auth',
            # ↑ {{ user }} and {{ perms }} are available in all templates
            'django.contrib.messages.context_processors.messages',
            # ↑ {{ messages }} is available in all templates
        ],
    },
}]


# ── Database ─────────────────────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
# SQLite: a single file, ideal for development, not for production
# PostgreSQL (production): ENGINE = 'django.db.backends.postgresql'


# ── Static files ─────────────────────────────────────────────────────────────
STATIC_URL = '/static/'
# The URL prefix for static files: CSS, JS, images
# In a template: {% load static %} + {% static 'css/style.css' %}


# ── Language and time zone ───────────────────────────────────────────────────
LANGUAGE_CODE = 'uk'            # The language of the admin panel and built-in messages
TIME_ZONE = 'Europe/Kyiv'       # The time zone for DateTimeField
USE_I18N = True                 # Internationalization
USE_TZ = True                   # Store datetimes in UTC in the DB
# USE_TZ=True: datetimes in the DB are always in UTC → converted on display
# USE_TZ=False: datetimes are stored "as is" → dangerous when the TZ changes


# ── Auto primary key ─────────────────────────────────────────────────────────
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# BigAutoField → id: bigint (64-bit)
# AutoField     → id: int (32-bit, may overflow with billions of records)
```

---

## 05 · URL Patterns

> `urls.py` is the site map. Each URL leads to a specific view function.

### Anatomy of path()

```python
from django.urls import path, include, re_path
from . import views

urlpatterns = [
    # path(route, view, kwargs=None, name=None)
    path('about/', views.about, name='about'),
    #      ↑          ↑               ↑
    #   URL string   callable        a unique route name
    #   (no / at the start  (a function or CBV.as_view())
    #   if included via include)
]
```

### Path Converters — capturing values from the URL

```python
urlpatterns = [
    # <int:pk> — capture an integer
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    # /notes/42/ → the view receives pk=42

    # <str:username> — capture a string (does not include '/')
    path('users/<str:username>/', views.user_profile, name='user_profile'),
    # /users/alice/ → the view receives username='alice'

    # <slug:slug> — only letters, digits, hyphens
    path('articles/<slug:slug>/', views.article, name='article'),
    # /articles/my-first-post/

    # <uuid:pk> — UUID format
    path('orders/<uuid:pk>/', views.order_detail, name='order_detail'),

    # <path:file_path> — includes '/'
    path('files/<path:file_path>/', views.serve_file, name='serve_file'),
    # /files/images/2026/photo.jpg → file_path='images/2026/photo.jpg'
]
```

### A two-level URLconf — include()

```python
# hello_project/urls.py (the main one)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    # include() plugs in another app's URLconf
    path('', include('hello_app.urls', namespace='hello_app')),
    # '' → all URLs without a prefix go to hello_app.urls
    # namespace='hello_app' → for {% url 'hello_app:index' %}

    # Or with a prefix:
    path('notes/', include('hello_app.urls', namespace='hello_app')),
    # Then /notes/ + '' (in hello_app.urls) = /notes/
]
```

```python
# hello_app/urls.py (the modular one)
from django.urls import path
from . import views

app_name = 'hello_app'   # ← Required when there is a namespace in include()!
# Without app_name: ImproperlyConfigured: Specifying a namespace in include() without providing an app_name

urlpatterns = [
    path('', views.index, name='index'),        # ← '' here
    path('about/', views.about, name='about'),
]
```

### reverse() — generating URLs programmatically

```python
# In a view:
from django.urls import reverse
from django.shortcuts import redirect

def some_view(request):
    # Instead of hardcoding '/notes/':
    url = reverse('hello_app:note_list')
    return redirect(url)

# Or directly:
return redirect('hello_app:note_list')

# In a template:
# {% url 'hello_app:note_detail' pk=note.pk %}
# → /notes/42/
```

**Why `reverse()` instead of hardcoding `/notes/`?**
If you change the URL in `urls.py`, `reverse()` automatically generates the new URL.
With a hardcoded `/notes/` → you have to search and replace it across the whole codebase.

---

## Step 1 — Virtual environment

A virtual environment is an isolated Python environment. The packages you install into it do not affect other projects or the system Python.

```bash
# Create a venv in the current folder
python -m venv venv

# Activate — Linux / macOS
source venv/bin/activate

# Activate — Windows PowerShell
venv\Scripts\Activate.ps1

# Activate — Windows Command Prompt
venv\Scripts\activate.bat
```

After activation, `(venv)` will appear in the terminal prompt:
```
(venv) ~/projects/hello_django $
```

> **Activate it every time** you open a new terminal in the project.
> Forgot to activate it? `pip install django` will install into the system Python → version conflicts.

```bash
# Deactivate (return to the system Python):
deactivate

# Check that the correct Python is being used:
which python    # macOS/Linux → should be .../venv/bin/python
where python    # Windows
```

---

## Step 2 — Install Django

```bash
# Upgrade pip (recommended)
python -m pip install --upgrade pip

# Install Django (the latest stable version)
pip install django

# Or a specific version:
pip install django==5.2.2
```

```bash
# Save the dependencies to requirements.txt
pip freeze > requirements.txt
# Contents: Django==5.2.2 (and other dependencies)

# Install from requirements.txt (for another developer):
pip install -r requirements.txt
```

Check the installation:
```bash
python -m django --version
# → 5.2.2
```

### Python and Django compatibility

| Python | Django | Note |
|--------|--------|----------|
| 3.10 – 3.13 | 5.1.x or 5.2.x | A stable pair |
| 3.14+ | only 5.2+ | 5.1 does not support Python 3.14 |
| 3.9 | 4.2.x (LTS) | Old, but supported |

Check: `python --version`

---

## Step 3 — Create the project

```bash
django-admin startproject hello_project .
```

> **The dot `.` at the end is required!**
>
> With the dot:        `hello_project/` and `manage.py` in the current folder ✓
> Without the dot: Django will create `hello_project/hello_project/` → unnecessary nesting ✗

Result:
```
./
├── hello_project/
│   ├── __init__.py
│   ├── settings.py   ← configuration
│   ├── urls.py       ← the main router
│   ├── asgi.py       ← for uvicorn/daphne
│   └── wsgi.py       ← for gunicorn
└── manage.py         ← the CLI orchestrator
```

---

## Step 4 — Apply migrations

```bash
python manage.py migrate
```

Django includes built-in apps (`django.contrib.auth`, `django.contrib.admin`, and so on).
Each of them has tables in the database. `migrate` creates these tables in `db.sqlite3`.

### What exactly Django creates

```bash
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK        # ← Django ContentType framework
  Applying auth.0001_initial... OK                # ← auth_user, auth_group, auth_permission
  Applying admin.0001_initial... OK               # ← django_admin_log
  Applying sessions.0001_initial... OK            # ← django_session
```

### Tables that Django creates automatically

| Table | What it stores |
|---------|-------------|
| `auth_user` | Users: username, password (a PBKDF2+SHA256 hash), email, is_staff, is_superuser |
| `auth_group` | Groups/roles: name |
| `auth_permission` | Permissions: name + model (`add_note`, `change_note`, `delete_note`, `view_note`) |
| `auth_user_groups` | M:N: user ↔ group |
| `auth_user_user_permissions` | M:N: user ↔ permission |
| `django_session` | Sessions (the `sessionid` cookie → a record in the DB) |
| `django_admin_log` | A log of actions in the admin panel (who changed what and when) |
| `django_migrations` | Which migrations have already been applied (so they are not repeated) |
| `django_content_type` | A registry of all models (for generic FKs) |

> **Without `migrate` the admin panel crashes:**
> `OperationalError: no such table: auth_user`

---

## Step 5 — Create a superuser

```bash
python manage.py createsuperuser
```

Django will ask:
```
Username (leave blank to use 'niko'): admin
Email address: admin@example.com
Password:
Password (again):
Superuser created successfully.
```

### User types in Django

```
Superuser  → is_superuser=True, is_staff=True
             All permissions automatically.
             Bypasses permission checks.
             Access to /admin/ and all objects.

Staff user → is_staff=True, is_superuser=False
             Can log in to /admin/, but only with the assigned permissions.
             Does not see models without explicit permissions.

Regular    → is_staff=False, is_superuser=False
             An ordinary user. No access to /admin/.
             Can use the application's frontend.
```

### Django permissions (automatic)

Django automatically generates 4 permissions for each model:

```
hello_app.add_note      ← can create notes
hello_app.change_note   ← can edit
hello_app.delete_note   ← can delete
hello_app.view_note     ← can view

# In a template:
{% if perms.hello_app.add_note %}
    <a href="{% url 'hello_app:note_create' %}">+ New</a>
{% endif %}

# In a view:
from django.contrib.auth.decorators import permission_required
@permission_required('hello_app.add_note')
def note_create(request): ...

# Checking in Python:
request.user.has_perm('hello_app.add_note')
```

---

## Step 6 — Create an app

```bash
python manage.py startapp hello_app
```

This command creates:
```
hello_app/
├── __init__.py
├── admin.py        ← Registering models for the Django Admin
├── apps.py         ← HelloAppConfig — the app configuration
├── models.py       ← Models (empty)
├── tests.py        ← Tests (better turned into a tests/ package)
├── views.py        ← View functions (empty)
└── migrations/
    └── __init__.py
```

Register the app in `hello_project/settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'hello_app',    # ← ADD THIS LINE
]
```

> **Why do you need to register it?**
> Django knows about an app only if it is in `INSTALLED_APPS`.
> Without that:
> - Django does not look for templates in `hello_app/templates/`
> - `python manage.py makemigrations` ignores `hello_app/models.py`
> - The Django Admin does not know about the models from `hello_app/`
> - management commands from `hello_app/management/` are not available

---

## Step 7 — Write view functions

Open `hello_app/views.py`:

```python
from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    """Home page."""
    return HttpResponse("Hello, Django!")


def about(request):
    """About page."""
    return HttpResponse("This is my first Django page!")
```

### Anatomy of a view function

```python
def index(request):
    #       ↑
    #  HttpRequest object — contains:
    #    request.method   → 'GET', 'POST', 'PUT', 'DELETE'
    #    request.GET      → QueryDict: the parameters ?q=search&page=2
    #    request.POST     → QueryDict: the POST form body
    #    request.user     → the logged-in User or AnonymousUser
    #    request.session  → dict-like: the user's session
    #    request.META     → HTTP headers: REMOTE_ADDR, HTTP_HOST...
    #    request.FILES    → uploaded files
    #    request.COOKIES  → browser cookies

    return HttpResponse("Hello!")
    #         ↑
    #  HttpResponse — the response to the browser:
    #    status_code=200 (by default)
    #    content_type='text/html; charset=utf-8'
    #    body: 'Hello!'
```

### Response types

```python
from django.http import (
    HttpResponse,            # 200 OK with any content
    HttpResponseRedirect,    # 302 Redirect
    Http404,                 # raised as an exception → 404 page
    JsonResponse,            # 200 OK with a JSON body
)
from django.shortcuts import render, redirect, get_object_or_404

# The most common ones in views.py:
return render(request, 'hello_app/index.html', {'key': value})
# → renders an HTML template with a context → 200

return redirect('hello_app:note_list')
# → 302 Redirect to a URL from reverse()

return redirect('hello_app:note_detail', pk=42)
# → 302 Redirect with an argument

raise Http404("Not found")
# → Django returns the 404 page

note = get_object_or_404(Note, pk=pk)
# → Note.objects.get(pk=pk) but instead of DoesNotExist → Http404
```

---

## Step 8 — URL routes

Create a new file `hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = "hello_app"    # ← The namespace

urlpatterns = [
    path('', views.index, name='index'),        # → /
    path('about/', views.about, name='about'),  # → /about/
]
```

**Why `app_name`?** Without it, the link `{% url 'hello_app:index' %}` does not work.
Django raises: `ImproperlyConfigured: Specifying a namespace in include() without providing an app_name`

Plug it into the main `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
    #     ↑                              ↑
    #   empty prefix →               the namespace for {% url %}
    #   hello_app URLs start
    #   right from the root /
]
```

### How Django finds the view for the request GET /about/

```
GET /about/
    ↓
hello_project/urls.py:
  path('', include('hello_app.urls', ...))
  → prefix '' → PASS

hello_app/urls.py:
  path('about/', views.about, name='about')
  → 'about/' == 'about/' → MATCH!

views.about(request) is called
  → HttpResponse("This is my first page...")
```

---

## Step 9 — Check in the browser

```bash
python manage.py runserver
```

Expected output:
```
Watching for file changes with StatReloader
Performing system checks...

System check identified no issues (0 silenced).
June 13, 2026 - 10:00:00
Django version 5.2.2, using settings 'hello_project.settings'
Starting development server at http://127.0.0.1:8000/
Quit the server with CONTROL-C.
```

| URL | Result | HTTP code |
|-----|-----------|----------|
| `http://localhost:8000/` | `Hello, Django!` | 200 |
| `http://localhost:8000/about/` | `This is my first Django page!` | 200 |
| `http://localhost:8000/admin/` | Admin panel (login page) | 200 |
| `http://localhost:8000/admin/` (after login) | Dashboard with models | 200 |
| `http://localhost:8000/nonexistent/` | 404 Not Found | 404 |

### The Django admin panel

The Django Admin is an automatically generated web interface for managing data.
It is built into Django: `django.contrib.admin` in `INSTALLED_APPS`.

**What you see after logging in:**
```
Django administration                         Logged in as: admin
  AUTHENTICATION AND AUTHORIZATION
    Groups    → add / edit groups
    Users     → all users, password changes, permissions
```

---

## Bonus — First model

### 1. Describe the model in `hello_app/models.py`

```python
from django.db import models


class Note(models.Model):
    title      = models.CharField(max_length=200, verbose_name='Title')
    content    = models.TextField(blank=True, verbose_name='Text')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Created')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name        = 'Note'
        verbose_name_plural = 'Notes'
        ordering            = ['-created_at']   # Newest first
```

### Field types and what they mean

```python
# CharField — a short string, max_length is required
title = models.CharField(max_length=200)
# SQL: title VARCHAR(200) NOT NULL

# TextField — a long string, with no length limit
content = models.TextField(blank=True)
# blank=True: not required in Django forms
# SQL: content TEXT NOT NULL DEFAULT ''

# DateTimeField — date and time
created_at = models.DateTimeField(auto_now_add=True)
# auto_now_add=True: set on CREATE, never changes
# SQL: created_at TIMESTAMP NOT NULL DEFAULT NOW()

updated_at = models.DateTimeField(auto_now=True)
# auto_now=True: updated on every SAVE

# BooleanField
is_pinned = models.BooleanField(default=False)
# SQL: is_pinned BOOLEAN NOT NULL DEFAULT FALSE

# IntegerField with choices
PRIORITY_CHOICES = [(1, 'Low'), (2, 'Medium'), (3, 'High')]
priority = models.SmallIntegerField(choices=PRIORITY_CHOICES, default=1)
# SQL: priority SMALLINT NOT NULL DEFAULT 1

# ForeignKey — an N→1 relationship
user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
# SQL: user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE
```

### 2. Register it in the admin panel (`hello_app/admin.py`)

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display   = ('title', 'created_at')     # Columns in the list
    search_fields  = ('title', 'content')        # Search by fields
    list_filter    = ('created_at',)             # Filters on the right
    ordering       = ('-created_at',)            # Sorting
    readonly_fields = ('created_at', 'updated_at') # Not editable
```

**Result:** `http://localhost:8000/admin/hello_app/note/` — full CRUD for notes.

### 3. Create and apply a migration

```bash
python manage.py makemigrations
```

Output:
```
Migrations for 'hello_app':
  hello_app/migrations/0001_initial.py
    - Create model Note
```

```bash
python manage.py migrate
```

Output:
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, hello_app, sessions
Running migrations:
  Applying hello_app.0001_initial... OK
```

### The two-step rule

```bash
# After ANY change to models.py → always two steps:
python manage.py makemigrations   # Record the plan of changes
python manage.py migrate          # Apply it to the DB

# makemigrations WITHOUT migrate:
# → the Python class exists, the DB table does not → OperationalError on the first query
```

### What happens between models.py and the DB

```
models.py (Python class)
    ↓ python manage.py makemigrations
migrations/0001_initial.py  (a plan of changes in the form of Python operations)
    ↓ python manage.py migrate
     ↓ sqlmigrate shows the real SQL:
CREATE TABLE "hello_app_note" (
    "id"         bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "title"      varchar(200) NOT NULL,
    "content"    text NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL
);
    ↓
http://localhost:8000/admin/hello_app/note/   ← the model is now available
```

### 4. Django shell — ORM queries

```bash
python manage.py shell
```

```python
from hello_app.models import Note

# CREATE — INSERT INTO
Note.objects.create(title="First note", content="Hello Django!")
Note.objects.create(title="Django ORM", content="Very powerful!")

# READ — SELECT
Note.objects.all()                          # → QuerySet [<Note: First note>, ...]
Note.objects.count()                        # → 2
Note.objects.filter(title__icontains='django')  # → QuerySet (case-insensitive)
Note.objects.get(id=1)                      # → <Note: First note> or DoesNotExist
Note.objects.first()                        # → the first object
Note.objects.order_by('-created_at')        # → sorting: newest first

# UPDATE — UPDATE SET
note = Note.objects.get(id=1)
note.title = "Changed note"
note.save()                                 # → UPDATE hello_app_note SET title=... WHERE id=1

# DELETE — DELETE FROM
note.delete()                               # → DELETE FROM hello_app_note WHERE id=1
Note.objects.filter(id__gt=5).delete()     # → Delete all with id > 5

# QuerySets are lazy:
qs = Note.objects.all()   # ← SQL IS NOT EXECUTED YET
print(qs)                  # ← Only here is the SQL executed!
# SELECT * FROM hello_app_note

# Useful lookups:
Note.objects.filter(title__icontains='first')   # icontains = case-insensitive
Note.objects.filter(title__startswith='Django')
Note.objects.filter(created_at__year=2026)
Note.objects.filter(id__in=[1, 2, 3])
Note.objects.exclude(title='secret')            # exclude = NOT
```

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `OperationalError: no such table: auth_user` | Migrations were not run | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | The venv is not activated | Activate it: `source venv/bin/activate` |
| `Page not found (404)` at `/` | The route is not registered | Check `urls.py` in both files |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` is set, but `app_name` is missing | Add `app_name = "hello_app"` to `hello_app/urls.py` |
| Django doesn't see `hello_app` | Not in `INSTALLED_APPS` | Add `'hello_app'` to `settings.py` |
| `django-admin: command not found` | Django is not installed or the venv is not activated | Activate the venv, then `pip install django` |
| `ModuleNotFoundError: No module named 'hello_project'` | You are not running it from the project root | Go to the folder that contains `manage.py` |
| `DisallowedHost` | ALLOWED_HOSTS does not contain the host | Add the host to `ALLOWED_HOSTS` in settings.py |
| `CSRF verification failed` | `{% csrf_token %}` is missing from the form | Add `{% csrf_token %}` inside the `<form>` |

---

## Practical exercise

1. Go through steps 1–9 on your own and get `Hello, Django!` in the browser.
2. Add a third route `/contact/` with a view function `contact()` that returns a string with your name and email.
3. Add a route `/greet/<str:name>/` that returns "Hello, {name}!".
4. Create the `Note` model, make a migration, open the admin panel, and add 3 notes by hand.
5. In the Django shell: find the note with `id=2`, change its `title`, and save it. Check it in the admin panel.

---

## Self-check checklist

- [ ] `http://localhost:8000/` → `Hello, Django!`
- [ ] `http://localhost:8000/about/` → text
- [ ] `http://localhost:8000/admin/` → admin panel (superuser login)
- [ ] I understand the difference between `startproject` and `startapp`
- [ ] I know why `makemigrations` and `migrate` are two separate steps
- [ ] The `Note` model appears in the admin panel
- [ ] I can perform CRUD via the Django shell (`create`, `filter`, `get`, `save`, `delete`)
- [ ] I understand how Django finds a view by URL (the URLconf chain)
- [ ] I know the difference between superuser / staff / regular user

---

## Summary

| Concept | Where in the code |
|-----------|-----------|
| URL route | `hello_app/urls.py` → `path('about/', views.about)` |
| View function | `hello_app/views.py` → `def about(request): return HttpResponse(...)` |
| Including app URLs | `hello_project/urls.py` → `include('hello_app.urls')` |
| Namespace | `app_name = 'hello_app'` + `namespace='hello_app'` |
| Reverse URL | `reverse('hello_app:about')` or `{% url 'hello_app:about' %}` |
| Path converter | `path('notes/<int:pk>/', ...)` |
| Model → DB | `makemigrations` + `migrate` |
| ORM CRUD | `create`, `filter`, `get`, `.save()`, `.delete()` |
| Admin registration | `@admin.register(Note)` in `admin.py` |

---

## What's next

Next step: [02 — Bootstrap Notes](02_first_model.md) — Bootstrap 5, ModelForm, full CRUD with the PRG pattern.

Documentation modules:
- [Django Core](../02_django_core/README.md)
- [Database and ORM](../03_database_and_orm/README.md)
