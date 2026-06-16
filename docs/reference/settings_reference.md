# Settings Reference — notes_project/settings.py

Повний розбір всіх налаштувань у `notes_project/settings.py`.

---

## Критичні налаштування

| Змінна | Default (dev) | Production | Де встановлюється |
|--------|--------------|-----------|------------------|
| `SECRET_KEY` | `django-insecure-...` | Унікальний 50+ символів | `.env` → `os.environ` |
| `DEBUG` | `True` | `False` | `.env` → `os.environ` |
| `ALLOWED_HOSTS` | `['*']` або `['localhost']` | Конкретні домени | `.env` → `os.environ` |
| `DATABASE_URL` | SQLite (локально) | PostgreSQL URL | `.env` → `os.environ` |
| `REDIS_URL` | Не встановлено | `redis://redis:6379/0` | `.env` → `os.environ` |

---

## INSTALLED_APPS — порядок важливий

```python
INSTALLED_APPS = [
    'daphne',                         # ← ПЕРШИЙ: override runserver → ASGI
    'channels',                       # Django Channels (WebSocket)
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'crispy_forms',                   # Bootstrap форми
    'crispy_bootstrap5',              # Bootstrap 5 тема
    'notes_app',                      # наш додаток
]
```

**Чому `daphne` першим:** він override Django команду `runserver` щоб запускатись через ASGI.
Без цього `python manage.py runserver` запускає WSGI і WebSocket не працює.

---

## База даних

```python
import dj_database_url
import os

DATABASE_URL = os.environ.get('DATABASE_URL')

if not DATABASE_URL:
    raise Exception("DATABASE_URL не встановлено. Запускай через docker compose.")

DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
```

> ⚠️ **Важливо:** SQLite-fallback відсутній. Запуск Django без `DATABASE_URL` негайно підіймає
> `Exception`. Це навмисне рішення — проєкт вимагає PostgreSQL.
> Якщо ти бачиш цю помилку, запускай через `docker compose up` або встанови `DATABASE_URL`.
> Дивись [TROUBLESHOOTING.md](../TROUBLESHOOTING.md).

**DATABASE_URL формат:** `postgres://user:password@host:5432/dbname`

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
                    "socket_timeout": None,        # КРИТИЧНО: без цього TimeoutError
                    "socket_connect_timeout": 5,
                    "health_check_interval": 30,   # перевіряє Redis кожні 30 сек
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
# Celery використовує Redis DB 1, щоб не конфліктувати з
# Channels channel layer (DB 0)
_CELERY_REDIS = _REDIS_URL.replace("/0", "/1") if _REDIS_URL else "redis://localhost:6379/1"

CELERY_BROKER_URL      = _CELERY_REDIS   # черга задач
CELERY_RESULT_BACKEND  = _CELERY_REDIS   # результати задач
CELERY_TIMEZONE        = TIME_ZONE
CELERY_TASK_SERIALIZER  = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT   = ["json"]

CELERY_BEAT_SCHEDULE = {
    "send-reminders-every-minute": {
        "task": "notes_app.tasks.send_reminder_notifications",
        "schedule": 60.0,   # кожні 60 секунд
    },
}
```

| Змінна | Значення | Призначення |
|--------|---------|-------------|
| `CELERY_BROKER_URL` | `redis://redis:6379/1` | черга задач (DB 1, відокремлено від Channels) |
| `CELERY_RESULT_BACKEND` | `redis://redis:6379/1` | збереження результатів задач |
| `CELERY_BEAT_SCHEDULE` | `send_reminder_notifications`, 60 сек | Celery Beat розклад |

**Docker-сервіси:**
- `celery-worker` — `celery -A notes_project worker -l info --concurrency=2`
- `celery-beat` — `celery -A notes_project beat -l info` (завжди 1 екземпляр)

**Email у dev:**

```python
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
# Email виводиться у stdout контейнера web — не надсилається реально
```

---

## Static Files

```python
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'   # collectstatic кладе сюди

# STATICFILES_DIRS — додаткові директорії (зазвичай пусто):
# Django автоматично знаходить <app>/static/
STATICFILES_DIRS = []
```

**Як статика роздається:**
- Dev: Django сам роздає (auto, бо `DEBUG=True`)
- Production: nginx → `/staticfiles/` volume (без Django)

---

## CSRF і security

```python
# Для ngrok (HTTPS):
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# Production HTTPS (розкоментувати після отримання SSL сертифіката):
# SESSION_COOKIE_SECURE = True
# CSRF_COOKIE_SECURE = True
# SECURE_SSL_REDIRECT = True
# SECURE_HSTS_SECONDS = 31536000
```

---

## Auth і Session

```python
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# Session engine (БД за замовчуванням):
SESSION_ENGINE = 'django.contrib.sessions.backends.db'
SESSION_COOKIE_AGE = 1209600   # 2 тижні (секунди)
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
            'level': 'DEBUG',    # DEBUG: всі логи з notes_app
            'propagate': False,
        },
    },
}
```

---

## Інтернаціоналізація

```python
LANGUAGE_CODE = 'uk'      # Ukrainian
TIME_ZONE = 'Europe/Kyiv'
USE_I18N = True
USE_TZ = True             # Timezone-aware datetimes у БД
```

**USE_TZ = True** — всі datetime у БД зберігаються в UTC.
`timezone.now()` повертає UTC datetime; при відображенні конвертується у TIME_ZONE.

---

## DEFAULT_AUTO_FIELD

```python
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# → PRIMARY KEY автоматично BigInteger (64-bit) замість Integer (32-bit)
# Запобігає переповненню при мільярдах записів
```

---

## Швидка довідка — що де встановлюється

```
.env файл:
  SECRET_KEY, DEBUG, ALLOWED_HOSTS, DATABASE_URL, REDIS_URL,
  NGROK_DOMAIN, NGROK_AUTHTOKEN, SEED_DEMO_DATA

settings.py (читає з os.environ):
  всі вищезазначені + INSTALLED_APPS, MIDDLEWARE, CHANNEL_LAYERS, CELERY_*, STATIC_ROOT, ...

docker-compose.yml (передає у контейнер):
  DATABASE_URL, REDIS_URL, SECRET_KEY, NGROK_DOMAIN, SEED_DEMO_DATA, WEB_HOST,
  DJANGO_SETTINGS_MODULE (для celery-worker і celery-beat)
```
