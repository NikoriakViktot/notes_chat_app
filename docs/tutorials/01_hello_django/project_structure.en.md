# Project structure

> This page explains **why** Django looks the way it does.
> Before writing code, understand the architecture.

---

## 01 · How Django handles a request

> **The most important question:** what happens when you type `http://localhost:8000/about/` into the browser?

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
   │                              │  HttpResponse("Це моя...")   │
   │                              │         │                    │
   │  ◄───────────── 200 OK  ─────│         │                    │
   │  (body: "Це моя перша...")   │                              │
```

### The three participants

```
URLS.PY            → "Who will respond?"   path('about/', views.about)
VIEWS.PY           → "What to respond?"    return HttpResponse("...")
TEMPLATE/RESPONSE  → "How will it look?"   a string or HTML
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
├── manage.py               ← CLI: run the server, migrations, shell, tests
│
├── hello_project/          ← Project configuration (one for the whole project)
│   ├── __init__.py         ← Empty: makes the folder a Python package
│   ├── settings.py         ← All settings: DB, INSTALLED_APPS, TEMPLATES...
│   ├── urls.py             ← Main URLconf: includes the apps' urls.py
│   ├── wsgi.py             ← Entry point for WSGI servers (Gunicorn, uWSGI)
│   └── asgi.py             ← Entry point for ASGI servers (Uvicorn, Daphne)
│
├── hello_app/              ← An app (one of possibly several)
│   ├── __init__.py
│   ├── admin.py            ← Registering models in Django Admin
│   ├── apps.py             ← AppConfig configuration
│   ├── models.py           ← Models: Python class → DB table
│   ├── views.py            ← View functions: request → response
│   ├── urls.py             ← App URLs (must be created by hand)
│   ├── forms.py            ← ModelForm and Form classes (must be created)
│   ├── migrations/         ← Automatically generated migration files
│   │   └── __init__.py
│   └── templates/          ← HTML templates (must be created)
│       └── hello_app/
│           └── index.html
│
└── db.sqlite3              ← DB file (appears after migrate)
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
  All of the application's code lives here.
  Each app = an isolated unit of functionality.
```

**Rule:** one `app` = one responsibility.
`notes_app` → notes. `users_app` → profiles. Do not mix everything into one big app.

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
python manage.py shell                     # Python shell with the Django context

# ── SQL ──────────────────────────────────────────────────────────────────────
python manage.py sqlmigrate hello_app 0001 # Show the SQL a migration will run
python manage.py dbshell                   # psql / sqlite3 shell

# ── Checks ───────────────────────────────────────────────────────────────────
python manage.py check                     # Check the configuration without running
python manage.py check --deploy            # Check production settings

# ── Tests ────────────────────────────────────────────────────────────────────
python manage.py test                      # All tests
python manage.py test hello_app            # Tests of a specific app
python manage.py test hello_app.tests.test_models -v 2

# ── Static files ─────────────────────────────────────────────────────────────
python manage.py collectstatic             # Collect static files into STATIC_ROOT
```

### How does manage.py know about your project?

```python
# manage.py — the first line after the shebang:
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'hello_project.settings')
# ↑ Tells Django where to find settings.py
# When running in Docker, this is often overridden with an ENV variable
```

---

## 04 · settings.py — anatomy of the configuration

`settings.py` is Django's brain. Read every setting; don't just copy it.

```python
# hello_project/settings.py

# ── Security ─────────────────────────────────────────────────────────────────
SECRET_KEY = 'django-insecure-...'   # Secret for CSRF, sessions, signatures
# In production: read it from os.environ or a .env file!
# os.environ.get('SECRET_KEY') — never store it in git

DEBUG = True
# True:  detailed error pages with a traceback → ONLY in development
# False: Production → a generic error without a traceback

ALLOWED_HOSTS = []
# List of domains that may access the site
# DEBUG=True → ALLOWED_HOSTS is not checked (localhost is always allowed)
# Production: ['example.com', 'www.example.com']


# ── Installed apps ───────────────────────────────────────────────────────────
INSTALLED_APPS = [
    'django.contrib.admin',         # /admin/ — the admin panel
    'django.contrib.auth',          # User model, login/logout
    'django.contrib.contenttypes',  # ContentType framework (generic relations)
    'django.contrib.sessions',      # Sessions: the django_session table
    'django.contrib.messages',      # Flash messages
    'django.contrib.staticfiles',   # Static files: /static/

    # Third-party (installed via pip):
    # 'crispy_forms',
    # 'crispy_bootstrap5',

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
    # ↑ Adds a trailing slash, APPEND_SLASH

    'django.middleware.csrf.CsrfViewMiddleware',
    # ↑ Checks the CSRF token in POST requests → 403 if missing

    'django.contrib.auth.middleware.AuthenticationMiddleware',
    # ↑ Reads the session → sets request.user
    # IMPORTANT: after SessionMiddleware!

    'django.contrib.messages.middleware.MessageMiddleware',
    # ↑ Flash messages: messages.success(request, ...)

    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # ↑ X-Frame-Options: DENY → protection against clickjacking
]
# Order is critical! Middleware is called in sequence (request↓, response↑)


# ── URL configuration ────────────────────────────────────────────────────────
ROOT_URLCONF = 'hello_project.urls'


# ── Templates ────────────────────────────────────────────────────────────────
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],  # Global templates (not inside an app/)
    'APP_DIRS': True,                  # Look for templates/ in every app
    # APP_DIRS: True → django looks in hello_app/templates/hello_app/*.html
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


# ── Language and time zone ───────────────────────────────────────────────────
LANGUAGE_CODE = 'uk'            # Language of the admin panel and built-in messages
TIME_ZONE = 'Europe/Kyiv'
USE_I18N = True
USE_TZ = True                   # Store datetimes in UTC in the DB
# USE_TZ=True: datetimes in the DB are always UTC → converted on display

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# BigAutoField → id: bigint (64-bit)
```

### SQLite vs PostgreSQL

| | SQLite (this step) | PostgreSQL (Steps 5–9) |
|-|-------------------|------------------------|
| **Running** | Nothing needed, it is a file | A separate server |
| **Where the file is** | `db.sqlite3` in the project folder | On the DB server |
| **Suitable for** | Development, learning, prototypes | Production |
| **Concurrent writes** | Locks the file | Full concurrency |
| **Configuration** | `'ENGINE': 'django.db.backends.sqlite3'` | `'ENGINE': 'django.db.backends.postgresql'` |

> In notes_chat_app (Step 5 and later) there is no SQLite fallback — only PostgreSQL via Docker is used.
