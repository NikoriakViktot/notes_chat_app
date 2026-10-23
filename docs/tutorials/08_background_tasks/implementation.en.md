# Implementation

## What to install

Before you start, make sure these packages are in `requirements.txt`:

```
celery==5.3.6
redis==5.0.1
python-dateutil==2.9.0
```

`python-dateutil` is needed for `relativedelta`: precise date arithmetic (months, years). The standard `timedelta` cannot count months correctly.

---

## Step 1: `celery.py`: initializing the Celery app

First you need to create the Celery app. It is a Python object that knows about the project's settings and tasks.

```python
# notes_project/celery.py
import os
from celery import Celery

# Tell Django where to find settings.py
# This is needed BEFORE Celery tries to import Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# Create the Celery app named after our Django project
app = Celery('notes_project')

# Load the configuration from Django's settings.py
# namespace='CELERY' means: read only variables that start with CELERY_
# For example: CELERY_BROKER_URL, CELERY_RESULT_BACKEND, CELERY_BEAT_SCHEDULE
app.config_from_object('django.conf:settings', namespace='CELERY')

# Automatically finds tasks.py in every INSTALLED_APP
# Without this you would have to import every tasks.py by hand
app.autodiscover_tasks()
```

**Why `namespace='CELERY'`?**

Celery looks in `settings.py` only for variables that start with `CELERY_`:

```python
# settings.py
CELERY_BROKER_URL = '...'         # ✅ will be found
CELERY_BEAT_SCHEDULE = {...}      # ✅ will be found
BROKER_URL = '...'                # ❌ old style, ignored
```

### Connecting to Django through `__init__.py`

```python
# notes_project/__init__.py
from .celery import app as celery_app

__all__ = ('celery_app',)
```

**Why is this needed?**

When Django starts, it executes `notes_project/__init__.py`. This line guarantees that `celery_app` is loaded **before** any code starts using `@shared_task`.

Without it, this situation could occur:

```
Worker starts → imports notes_app.tasks → @shared_task does not know which app to bind to → error
```

With this line:

```
Worker starts → notes_project/__init__.py → celery_app already exists → @shared_task binds to it ✓
```

---

## Step 2: `tasks.py`: the background task

```python
# notes_app/tasks.py
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone


@shared_task
def send_reminder_notifications():
    # Import inside the function to prevent circular imports.
    # tasks.py is imported before Django is fully initialized,
    # so importing models at module level may cause AppRegistryNotReady.
    from .models import Reminder

    now = timezone.now()

    # select_related('note__user') solves N+1:
    # Instead of 1 query for the note + 1 query for the user for every reminder
    # → 1 SQL query with a JOIN: SELECT reminder.*, note.*, auth_user.*
    pending = (
        Reminder.objects
        .select_related('note__user')
        .filter(remind_at__lte=now, is_sent=False)
    )

    for reminder in pending:
        user = reminder.note.user

        # Check that the user has an email
        # (by default a User can be created without an email through UserCreationForm)
        if user.email:
            send_mail(
                subject=f'Нагадування: {reminder.note.title}',
                message=reminder.message or f'Час нагадування для «{reminder.note.title}».',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                # fail_silently=True: if SMTP is unavailable, don't raise an exception.
                # In production you should log the error, but not stop processing
                # the remaining reminders because of a single SMTP failure.
                fail_silently=True,
            )

        # Mark as sent
        reminder.is_sent = True

        # update_fields=['is_sent'] updates ONLY this field:
        # SQL: UPDATE reminder SET is_sent = TRUE WHERE id = 42
        # Instead of: UPDATE reminder SET remind_at=..., message=..., is_sent=TRUE, ... WHERE id = 42
        # More efficient and safer: if another process changed remind_at, we won't overwrite it
        reminder.save(update_fields=['is_sent'])

        # If the reminder repeats, create the next one
        _schedule_next(reminder)


def _schedule_next(reminder):
    """Creates the next reminder for repeating notes."""
    if reminder.repeat_pattern == 'none':
        return  # one-time: do nothing

    from .models import Reminder
    from dateutil.relativedelta import relativedelta

    # relativedelta instead of timedelta for months:
    # timedelta(days=30) for January 31 gives March 1 in 2024 (March 2 in a non-leap year), skipping February!
    # relativedelta(months=1) for January 31 gives February 28/29 (correct)
    delta_map = {
        'daily':   relativedelta(days=1),
        'weekly':  relativedelta(weeks=1),
        'monthly': relativedelta(months=1),
    }
    delta = delta_map.get(reminder.repeat_pattern)
    if delta:
        Reminder.objects.create(
            note=reminder.note,
            remind_at=reminder.remind_at + delta,
            message=reminder.message,
            is_sent=False,
            repeat_pattern=reminder.repeat_pattern,
        )
```

### Why `@shared_task` and not `@app.task`

```python
# ❌ DON'T DO THIS: hard coupling to a specific app
from notes_project.celery import app

@app.task
def send_reminder_notifications():
    ...
```

```python
# ✅ CORRECT: the task binds to the active app at run time
from celery import shared_task

@shared_task
def send_reminder_notifications():
    ...
```

The difference matters:

- `@app.task` requires importing a specific Celery app → circular imports
- `@shared_task` binds to whichever Celery app is active → portable between projects, no circular imports

### `relativedelta` vs `timedelta` for months

```python
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta

d = datetime(2024, 1, 31)

# timedelta counts in days and knows nothing about months
d + timedelta(days=30)        # → 2024-03-01 (February skipped entirely!)
d + timedelta(days=28)        # → 2024-02-28 (but for October this is wrong)

# relativedelta knows about months and their length
d + relativedelta(months=1)   # → 2024-02-29 (2024 is a leap year, correct!)
datetime(2024, 3, 31) + relativedelta(months=1)  # → 2024-04-30 (correct, April has 30 days)
```

---

## Step 3: `settings.py`: Celery configuration

```python
# notes_project/settings.py (end of the file)

# REDIS_URL is set through env: redis://redis:6379/0
# (the URL for Channels, DB 0)
# Replace /0 with /1: Celery uses DB 1 so it doesn't conflict with Channels
_CELERY_REDIS = _REDIS_URL.replace("/0", "/1") if _REDIS_URL else "redis://localhost:6379/1"

# Broker: where the Worker goes for tasks
CELERY_BROKER_URL = _CELERY_REDIS

# Result Backend: where execution results are stored
CELERY_RESULT_BACKEND = _CELERY_REDIS

# Timezone: Beat uses it to compute the schedule
CELERY_TIMEZONE = TIME_ZONE   # from Django settings: 'Europe/Kyiv'

# Serialization: JSON is safer than Pickle (no arbitrary code execution)
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]

# The schedule for Beat
CELERY_BEAT_SCHEDULE = {
    # An arbitrary name, shown in the Beat logs
    "send-reminders-every-minute": {
        # The full dotted path to the task: Beat finds it through autodiscover
        "task": "notes_app.tasks.send_reminder_notifications",
        # schedule=60.0 means every 60 seconds
        # You can also use: crontab(minute='*/5') for every 5 minutes
        "schedule": 60.0,
    },
}
```

### Configuring the email backend for dev

In development there is no real SMTP server. Use the console backend: it prints email right in the terminal:

```python
# settings.py
if DEBUG:
    # Prints email to the terminal instead of actually sending it
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
else:
    # Production: real SMTP (Gmail, SendGrid, etc.)
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = os.environ.get('EMAIL_HOST', '')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
    EMAIL_USE_TLS = True
    EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
    EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')

DEFAULT_FROM_EMAIL = 'noreply@notes.example.com'
```

When an email is sent with the console backend, you will see this in the `celery-worker` logs:

```
Content-Type: text/plain; charset="utf-8"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Subject: =?utf-8?b?0J3QsNCz0LDQtNGD0LLQsNC90L3Rjzog...?=
From: noreply@notes.example.com
To: alice@example.com
Date: Mon, 16 Jun 2026 10:00:00 -0000
Message-ID: <...>

Час нагадування для «Зустріч о 14:00».
```

### `schedule=60.0` vs `crontab`

Two ways to define a schedule:

```python
# Option 1: every N seconds (float or int)
"schedule": 60.0        # every 60 seconds
"schedule": 3600        # every hour

# Option 2: crontab, like Linux cron
from celery.schedules import crontab

"schedule": crontab(minute='*/1')          # every minute
"schedule": crontab(hour=9, minute=0)      # every day at 09:00
"schedule": crontab(day_of_week='monday')  # every Monday
```

For reminders `60.0` is simpler and sufficient. Every minute we check whether there are overdue reminders.

---

## Step 4: Docker Compose: two new services

```yaml
# docker-compose.yml (add to the services: section)
  celery-worker:
    build: .
    # -A notes_project  → read celery.py from notes_project/
    # worker            → worker mode (not beat!)
    # -l info           → logging level
    # --concurrency=2   → 2 parallel task execution processes
    command: celery -A notes_project worker -l info --concurrency=2
    volumes:
      - .:/app
    environment:
      DATABASE_URL: postgres://notes_user:notes_pass@db:5432/notes_db
      REDIS_URL: redis://redis:6379/0
      DJANGO_SETTINGS_MODULE: notes_project.settings
    depends_on:
      db:
        condition: service_healthy   # waits until PostgreSQL is ready
      redis:
        condition: service_healthy   # waits until Redis is ready
    networks:
      - app-net

  celery-beat:
    build: .
    # beat is the scheduler mode
    # Beat only puts tasks in the queue, it does NOT run them
    command: celery -A notes_project beat -l info
    volumes:
      - .:/app
    environment:
      DATABASE_URL: postgres://notes_user:notes_pass@db:5432/notes_db
      REDIS_URL: redis://redis:6379/0
      DJANGO_SETTINGS_MODULE: notes_project.settings
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-net
```

### Why Worker and Beat are separate services

```
╔══════════════════╗       ╔══════════════════╗
║   celery-beat    ║       ║  celery-worker   ║
║                  ║       ║                  ║
║  Every minute:   ║──────►║  Runs the task   ║
║  "a new task"    ║       ║  send_reminder.. ║
║                  ║       ║                  ║
║  Instances: 1    ║       ║  Instances: 1+   ║
╚══════════════════╝       ╚══════════════════╝
         │                          │
         └──────── Redis ───────────┘
                  (broker)
```

**Why Beat = 1 instance?**

If you run two Beats:

```
Beat 1 at 10:00:00: "queueing the send_reminder_notifications task"
Beat 2 at 10:00:00: "queueing the send_reminder_notifications task"
→ The Worker runs the task TWICE → one user receives two emails!
```

The Worker can be scaled horizontally (`--concurrency=4`, or several `celery-worker` services). Beat is always one.

### Checking after startup

```bash
docker compose up -d

# Check the Worker logs; you should see:
docker compose logs celery-worker
# [2026-06-16 10:00:00,000: INFO/MainProcess] celery@abc123 ready.
# [2026-06-16 10:00:00,001: INFO/MainProcess] [tasks]
# [2026-06-16 10:00:00,001: INFO/MainProcess]   . notes_app.tasks.send_reminder_notifications

# Check the Beat logs; you should see:
docker compose logs celery-beat
# [2026-06-16 10:00:00,000: INFO/MainProcess] beat: Starting...
# [2026-06-16 10:00:00,000: INFO/MainProcess] Scheduler: Sending due task send-reminders-every-minute (notes_app.tasks.send_reminder_notifications)
```

If the Worker logs do **not** contain `notes_app.tasks.send_reminder_notifications` in the `[tasks]` list, `autodiscover_tasks()` did not find the task. Check that `notes_app` is in `INSTALLED_APPS`.

---

## Step 5: The URL for the JSON endpoint

For the browser to get reminders, it needs a URL:

```python
# notes_project/urls.py or notes_app/urls.py
from notes_app import views

urlpatterns = [
    # ... other URLs ...
    path('reminders/check/', views.reminders_check, name='reminders_check'),
]
```

---

## How to queue a task manually (without Beat)

In production Beat queues tasks automatically. But for testing you can queue a task manually:

```python
# Django shell or other code
from notes_app.tasks import send_reminder_notifications

# Option 1: delay() is syntactic sugar for apply_async()
send_reminder_notifications.delay()

# Option 2: apply_async() has more options
send_reminder_notifications.apply_async()
# or with a 30-second delay:
send_reminder_notifications.apply_async(countdown=30)

# Option 3: call it directly like a regular function (WITHOUT the queue, for tests)
send_reminder_notifications()
```

In tests we use option 3: we call the function directly, without the Worker and Redis. This lets us test the logic without Celery running.

---

## Common errors and their causes

### `ModuleNotFoundError: No module named 'celery'`

```
Solution: add celery to requirements.txt and rebuild: docker compose up --build
```

### The Worker does not find the task: `[tasks]` is empty

```
Cause: notes_app is not in INSTALLED_APPS, or tasks.py contains a syntax error

Check:
  docker compose logs celery-worker | grep "tasks"
  docker compose run --rm web python -c "from notes_app.tasks import send_reminder_notifications; print('OK')"
```

### Beat does not queue tasks

```
Cause: REDIS_URL points to the wrong place, or Beat is not connected to Redis

Check:
  docker compose logs celery-beat | grep "ERROR"
  docker compose exec redis redis-cli ping  # should answer PONG
```

### Email does not arrive in dev

```
Cause: EMAIL_BACKEND is not set to console.EmailBackend

Check settings.py and the celery-worker logs:
  docker compose logs celery-worker | grep "Subject"
```

---

## In the book

- [Part VI. Application architecture](../../06_application_architecture/README.md): `@shared_task` design patterns, idempotency, retry logic
- [Part III. Models, Database and the ORM](../../03_database_and_orm/README.md): `update_fields`, `select_related`, the N+1 problem

---

## Official documentation

- [Celery: @shared_task](https://docs.celeryq.dev/en/stable/reference/celery.app.shared_tasks.html)
- [Celery: Calling Tasks (.delay vs .apply_async)](https://docs.celeryq.dev/en/stable/userguide/calling.html)
- [Celery: Beat Schedule](https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html#entries)
- [Django: send_mail](https://docs.djangoproject.com/en/5.2/topics/email/#send-mail)
- [Django: EMAIL_BACKEND](https://docs.djangoproject.com/en/5.2/topics/email/#email-backends)
- [python-dateutil: relativedelta](https://dateutil.readthedocs.io/en/stable/relativedelta.html)
- [Docker Compose: depends_on](https://docs.docker.com/compose/compose-file/05-services/#depends_on)
