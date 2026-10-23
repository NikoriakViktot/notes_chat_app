# Settings Reference — notes_project/settings.py

A complete breakdown of all settings in `notes_project/settings.py`.

---

## Critical settings

| Variable | Default (dev) | Production | Where it is set |
|--------|--------------|-----------|------------------|
| `SECRET_KEY` | `django-insecure-...` | Unique, 50+ characters | `.env` → `os.environ` |
| `DEBUG` | `True` | `False` | `.env` → `os.environ` |
| `ALLOWED_HOSTS` | `['*']` or `['localhost']` | Specific domains | `.env` → `os.environ` |
| `DATABASE_URL` | PostgreSQL URL (required, from `docker-compose.yml`) | PostgreSQL URL | `.env` → `os.environ` |
| `REDIS_URL` | Not set | `redis://redis:6379/0` | `.env` → `os.environ` |

---

## INSTALLED_APPS — order matters

```python
INSTALLED_APPS = [
    'daphne',                         # ← FIRST: overrides runserver → ASGI
    'channels',                       # Django Channels (WebSocket)
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'crispy_forms',                   # Bootstrap forms
    'crispy_bootstrap5',              # Bootstrap 5 theme
    'notes_app',                      # our app
]
```

**Why `daphne` comes first:** it overrides Django's `runserver` command so that it runs via ASGI.
Without this, `python manage.py runserver` starts WSGI and WebSocket does not work.

---

## Database

```python
import dj_database_url
import os

DATABASE_URL = os.environ.get('DATABASE_URL')

if not DATABASE_URL:
    raise Exception("DATABASE_URL не встановлено. Запускай через docker compose.")

DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
```

> ⚠️ **Important:** there is no SQLite fallback. Starting Django without `DATABASE_URL` immediately raises
> an `Exception`. This is a deliberate decision — the project requires PostgreSQL.
> If you see this error, run via `docker compose up` or set `DATABASE_URL`.
> See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md).

**DATABASE_URL format:** `postgres://user:password@host:5432/dbname`

---

## Channel Layers (WebSocket)

```python
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    "socket_timeout": None,        # CRITICAL: without this, TimeoutError
                    "socket_connect_timeout": 5,
                    "health_check_interval": 30,   # checks Redis every 30 sec
                }],
            },
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }

ASGI_APPLICATION = 'notes_project.asgi.application'
```

---

## Celery (Background Tasks)

```python
# Celery uses Redis DB 1 so it does not conflict with
# the Channels channel layer (DB 0)
_CELERY_REDIS = _REDIS_URL.replace("/0", "/1") if _REDIS_URL else "redis://localhost:6379/1"

CELERY_BROKER_URL      = _CELERY_REDIS   # task queue
CELERY_RESULT_BACKEND  = _CELERY_REDIS   # task results
CELERY_TIMEZONE        = TIME_ZONE
CELERY_TASK_SERIALIZER  = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT   = ["json"]

CELERY_BEAT_SCHEDULE = {
    "send-reminders-every-minute": {
        "task": "notes_app.tasks.send_reminder_notifications",
        "schedule": 60.0,   # every 60 seconds
    },
}
```

| Variable | Value | Purpose |
|--------|---------|-------------|
| `CELERY_BROKER_URL` | `redis://redis:6379/1` | task queue (DB 1, separated from Channels) |
| `CELERY_RESULT_BACKEND` | `redis://redis:6379/1` | storing task results |
| `CELERY_BEAT_SCHEDULE` | `send_reminder_notifications`, 60 sec | Celery Beat schedule |

**Docker services:**
- `celery-worker` — `celery -A notes_project worker -l info --concurrency=2`
- `celery-beat` — `celery -A notes_project beat -l info` (always 1 instance)

**Email in dev:**

```python
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
# Email is printed to the web container's stdout — it is not actually sent
```

---

## Static Files

```python
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'   # collectstatic puts files here

# STATICFILES_DIRS — extra directories (usually empty):
# Django finds <app>/static/ automatically
STATICFILES_DIRS = []
```

**How static files are served:**
- Dev: Django serves them itself (automatically, because `DEBUG=True`)
- Production: nginx → `/staticfiles/` volume (without Django)

---

## CSRF and security

```python
# For ngrok (HTTPS):
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# Production HTTPS (uncomment after obtaining an SSL certificate):
# SESSION_COOKIE_SECURE = True
# CSRF_COOKIE_SECURE = True
# SECURE_SSL_REDIRECT = True
# SECURE_HSTS_SECONDS = 31536000
```

---

## Auth and Session

```python
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# Session engine (DB by default):
SESSION_ENGINE = 'django.contrib.sessions.backends.db'
SESSION_COOKIE_AGE = 1209600   # 2 weeks (seconds)
```

---

## Crispy Forms

```python
CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'
```

---

## Logging

```python
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'WARNING',
    },
    'loggers': {
        'notes_app': {
            'handlers': ['console'],
            'level': 'DEBUG',    # DEBUG: all logs from notes_app
            'propagate': False,
        },
    },
}
```

---

## Internationalization

```python
LANGUAGE_CODE = 'uk'      # Ukrainian
TIME_ZONE = 'Europe/Kyiv'
USE_I18N = True
USE_TZ = True             # Timezone-aware datetimes in the DB
```

**USE_TZ = True** — all datetimes are stored in the DB in UTC.
`timezone.now()` returns a UTC datetime; on display it is converted to TIME_ZONE.

---

## DEFAULT_AUTO_FIELD

```python
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# → PRIMARY KEY is automatically BigInteger (64-bit) instead of Integer (32-bit)
# Prevents overflow with billions of records
```

---

## Quick reference — what is set where

```
.env file:
  SECRET_KEY, DEBUG, ALLOWED_HOSTS, DATABASE_URL, REDIS_URL,
  NGROK_DOMAIN, NGROK_AUTHTOKEN, SEED_DEMO_DATA

settings.py (reads from os.environ):
  all of the above + INSTALLED_APPS, MIDDLEWARE, CHANNEL_LAYERS, CELERY_*, STATIC_ROOT, ...

docker-compose.yml (passes into the container):
  DATABASE_URL, REDIS_URL, SECRET_KEY, NGROK_DOMAIN, SEED_DEMO_DATA, WEB_HOST,
  DJANGO_SETTINGS_MODULE (for celery-worker and celery-beat)
```
