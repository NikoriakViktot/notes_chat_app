# Django Tasks — Celery and Asynchronous Tasks

> `tasks.py` is the transport layer for background operations.
> A task contains no business logic. It only queues the work
> and delegates execution to a Service.

---

## Navigation

| Section | What's inside |
|--------|--------------|
| [Why Celery](#why-celery) | The problem of blocking operations |
| [Architecture](#celery--django-architecture) | Broker, Worker, Backend |
| [Anatomy of a Task](#anatomy-of-a-task) | Basic structure, rules |
| [Task = Transport Layer](#task--transport-layer) | Why logic does not belong in a task |
| [on_commit](#on_commit--safe-task-launch) | A guarantee of consistency with the DB |
| [Retry and errors](#retry-and-error-handling) | `autoretry_for`, `max_retries`, `retry_backoff` |
| [Idempotency](#idempotency) | Tasks that are safe to run again |
| [Common patterns](#common-patterns) | Chains, Groups, Chords |
| [Configuration](#configuration) | Configuring Celery in Django |
| [Anti-patterns](#anti-patterns) | What not to do and why |
| [Template](#template) | A copy-paste template for a new task |

---

## Why Celery

### The problem of blocking operations

An HTTP request should complete within ~200–500 ms. Some operations take much longer:

| Operation | Time | Problem |
|----------|-----|---------|
| Sending an email | 1–3 s | The client waits |
| Processing a DEM file | 30–120 s | Nginx/client timeout |
| ICESat-2 request to SlideRule | 10–60 s | The worker is blocked |
| ML inference | 5–30 s | The client waits |
| Generating a PDF report | 3–10 s | The client waits |

### The solution: an asynchronous queue

```
HTTP Request
    │
    ▼
View → queues the task → immediately returns 202 Accepted
    │
    ▼ (independently, in the background)
Celery Worker → runs the task → stores the result
```

The client does not wait. The worker does not block HTTP requests.

---

## Celery + Django architecture

```
Django App
    │
    │  task.delay(args)   ← queues the task
    ▼
Redis (Broker)            ← message queue
    │
    │  receives the task
    ▼
Celery Worker             ← a separate process, runs the task
    │
    │  result (optional)
    ▼
Redis / PostgreSQL (Backend)   ← stores the result if needed
```

| Component | Role |
|-----------|------|
| **Broker** | Message queue (usually Redis or RabbitMQ) |
| **Worker** | A separate Python process that runs tasks |
| **Backend** | Result storage (Redis, PostgreSQL) — optional |
| **Beat** | Scheduler for periodic tasks (similar to cron) |

---

## Anatomy of a Task

### Basic structure

```python
# apps/flood/tasks.py

from celery import shared_task


@shared_task
def notify_emergency_services_task(event_id: int) -> None:
    from apps.flood.selectors import flood_event_get_by_id
    from apps.flood.services import flood_event_notify

    event = flood_event_get_by_id(event_id=event_id)
    flood_event_notify(event=event)
```

### Why the imports are inside the function

Module-level imports can cause circular dependencies when the Celery worker starts. Local imports inside the task function are a safe pattern.

```python
# DANGEROUS — circular import when the worker starts
from apps.flood.services import flood_event_notify

@shared_task
def notify_task(event_id):
    ...

# SAFE — the import happens only when the task runs
@shared_task
def notify_task(event_id):
    from apps.flood.services import flood_event_notify
    ...
```

### Passing arguments

```python
# GOOD — pass simple types: int, str, list, dict
@shared_task
def process_flood_task(event_id: int) -> None:
    ...

# Call
process_flood_task.delay(event_id=42)


# BAD — passing Python objects (they do not serialize reliably)
@shared_task
def process_flood_task(event: FloodEvent) -> None:   # ❌
    ...
```

Celery serializes arguments via JSON. Pass IDs, strings, numbers — not ORM objects.

---

## Task = Transport Layer

A task is a queue for delivering a call, not a place for logic.

### Anti-pattern: logic in the task

```python
# BAD — all the logic in the task
@shared_task
def process_flood_task(event_id: int):
    event = FloodEvent.objects.get(id=event_id)
    event.status = 'processing'
    event.save()

    # ML pipeline
    result = run_ml_model(event.geometry)
    event.risk_level = result['risk']
    event.status = 'done'
    event.save()

    # Email
    send_mail(
        subject='Flood processed',
        message=f'Event {event_id} done',
        from_email='system@example.com',
        recipient_list=[event.created_by.email],
    )
```

**Problems:**
- The logic cannot be called from a View or the CLI without Celery
- It cannot be tested without starting a worker
- On retry, the whole pipeline runs again

### Correct: the task delegates to a service

```python
# GOOD — the task only transports the call
@shared_task
def process_flood_task(event_id: int) -> None:
    from apps.flood.selectors import flood_event_get_by_id
    from apps.flood.services import flood_event_process

    event = flood_event_get_by_id(event_id=event_id)
    flood_event_process(event=event)   # all the logic is in the service
```

```python
# services.py — the logic is here, independent of Celery
@transaction.atomic
def flood_event_process(*, event: FloodEvent) -> FloodEvent:
    event.status = 'processing'
    event.save(update_fields=['status'])

    result = run_ml_model(event.geometry)
    event.risk_level = result['risk']
    event.status = 'done'
    event.save(update_fields=['risk_level', 'status'])

    transaction.on_commit(
        lambda: send_flood_report_task.delay(event.id)
    )

    return event
```

The same `flood_event_process` can be called from a View, a management command, a test — without Celery.

---

## `on_commit` — Safe task launch

### The problem without `on_commit`

```python
@transaction.atomic
def flood_event_create(*, region_name: str, ...) -> FloodEvent:
    event = FloodEvent(...)
    event.save()

    # ❌ DANGEROUS:
    # The Celery worker may start BEFORE the transaction has closed.
    # The worker runs a SELECT — the record has not appeared in the DB yet.
    # The task fails with DoesNotExist.
    process_flood_task.delay(event.id)

    return event
```

### The solution

```python
@transaction.atomic
def flood_event_create(*, region_name: str, ...) -> FloodEvent:
    event = FloodEvent(...)
    event.save()

    # ✅ SAFE:
    # The task is queued ONLY after a successful commit.
    # If the transaction is rolled back, the task will not start at all.
    transaction.on_commit(
        lambda: process_flood_task.delay(event.id)
    )

    return event
```

> **Rule:** any `task.delay()` inside `@transaction.atomic` must always go through `on_commit`.

---

## Retry and error handling

### `autoretry_for` — automatic retry on exceptions

```python
import httpx
from celery import shared_task


@shared_task(
    autoretry_for=(httpx.HTTPError, ConnectionError),  # which errors to retry on
    max_retries=3,                                      # maximum number of attempts
    retry_backoff=60,                                   # exponential delay: base of 60 s
    retry_jitter=False,                                 # no random spread of the delay
)
def fetch_sliderule_data_task(job_id: int) -> None:
    from apps.satellite.services import icesat2_job_fetch

    icesat2_job_fetch(job_id=job_id)
```

With `retry_backoff=60` and `retry_jitter=False` the delays will be: 60s → 120s → 240s. (`retry_backoff=True` means a base of 1 s: 1s → 2s → 4s, and `countdown` is an argument of `apply_async()`/`self.retry()`, not an option of the `@shared_task` decorator.)

### Manual retry

```python
@shared_task(bind=True, max_retries=5)
def process_dem_task(self, dem_id: int) -> None:
    from apps.dem.services import dem_process

    try:
        dem_process(dem_id=dem_id)
    except TemporaryProcessingError as exc:
        # Manual retry with a custom delay
        raise self.retry(exc=exc, countdown=30 * (self.request.retries + 1))
```

`bind=True` gives access to `self` — the current task instance with its metadata.

### Handling after all attempts

```python
from celery.utils.log import get_task_logger

logger = get_task_logger(__name__)


@shared_task(
    autoretry_for=(Exception,),
    max_retries=3,
    default_retry_delay=60,
)
def critical_processing_task(job_id: int) -> None:
    from apps.flood.services import flood_job_process, flood_job_mark_failed

    try:
        flood_job_process(job_id=job_id)
    except Exception as exc:
        logger.error(f"Task failed for job_id={job_id}: {exc}")
        flood_job_mark_failed(job_id=job_id)
        raise   # lets Celery know the task failed → retry or FAILURE
```

---

## Idempotency

A task may run several times (a network error, a retry, a duplicate message). Every task must be **idempotent** — running it again with the same arguments must not break the system.

### Non-idempotent (dangerous)

```python
@shared_task
def send_welcome_email_task(user_id: int) -> None:
    user = User.objects.get(id=user_id)
    send_mail(subject='Ласкаво просимо!', ...)
    # On retry — the email will be sent a second time
```

### Idempotent (safe)

```python
@shared_task
def send_welcome_email_task(user_id: int) -> None:
    user = User.objects.get(id=user_id)

    if user.welcome_email_sent:   # check before sending
        return

    send_mail(subject='Ласкаво просимо!', ...)

    User.objects.filter(id=user_id).update(welcome_email_sent=True)
```

---

## Common patterns

### A simple delay — fire and forget

```python
# Run the task in the background
process_flood_task.delay(event_id=42)

# With keyword arguments
process_flood_task.apply_async(kwargs={'event_id': 42})
```

### apply_async — extended options

```python
from datetime import timedelta
from django.utils import timezone

# Delay execution by 10 minutes
process_flood_task.apply_async(
    kwargs={'event_id': 42},
    countdown=600,
)

# Run at a specific time
process_flood_task.apply_async(
    kwargs={'event_id': 42},
    eta=timezone.now() + timedelta(hours=1),
)

# Put it in a specific queue
process_flood_task.apply_async(
    kwargs={'event_id': 42},
    queue='high_priority',
)
```

### Chain — sequential execution

```python
from celery import chain

# Task 2 starts only after Task 1 completes successfully
pipeline = chain(
    fetch_sliderule_data_task.s(job_id=42),
    process_icesat2_points_task.s(job_id=42),
    finalize_icesat2_job_task.s(job_id=42),
)
pipeline.delay()
```

### Group — parallel execution

```python
from celery import group

# All tasks start in parallel
parallel_jobs = group(
    process_dem_task.s(dem_id=1),
    process_dem_task.s(dem_id=2),
    process_dem_task.s(dem_id=3),
)
parallel_jobs.delay()
```

### Periodic Tasks (Celery Beat)

```python
# config/celery.py

from celery.schedules import crontab

app.conf.beat_schedule = {
    'cleanup-old-jobs': {
        'task': 'apps.flood.tasks.cleanup_old_jobs_task',
        'schedule': crontab(hour=3, minute=0),   # every day at 3:00
    },
    'sync-satellite-data': {
        'task': 'apps.satellite.tasks.sync_icesat2_data_task',
        'schedule': crontab(minute='*/30'),       # every 30 minutes
    },
}
```

---

## Configuration

### `config/celery.py`

```python
# config/celery.py

import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')

app = Celery('project')
app.config_from_object('django.conf:settings', namespace='CELERY')

# Automatic discovery of tasks.py in all INSTALLED_APPS
app.autodiscover_tasks()
```

### `config/__init__.py`

```python
# config/__init__.py
from .celery import app as celery_app

__all__ = ('celery_app',)
```

### `settings.py`

```python
# settings.py

CELERY_BROKER_URL = 'redis://redis:6379/0'
CELERY_RESULT_BACKEND = 'redis://redis:6379/0'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'UTC'

# Important: always acknowledge the task AFTER execution
# (not after receiving it — protection against loss if the worker crashes)
CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
```

### Starting the worker

```bash
# Basic start
celery -A config worker --loglevel=info

# With several queues and concurrency
celery -A config worker \
    --loglevel=info \
    --concurrency=4 \
    --queues=default,high_priority

# Celery Beat (periodic tasks)
celery -A config beat --loglevel=info
```

---

## Anti-patterns

### Business logic in a task

```python
# BAD
@shared_task
def process_task(event_id):
    event = FloodEvent.objects.get(id=event_id)
    event.status = 'done'   # logic here
    event.save()

# GOOD
@shared_task
def process_task(event_id):
    from apps.flood.selectors import flood_event_get_by_id
    from apps.flood.services import flood_event_complete
    event = flood_event_get_by_id(event_id=event_id)
    flood_event_complete(event=event)
```

### Passing an ORM object to a task

```python
# BAD — an ORM object cannot be serialized to JSON (EncodeError), and with pickle it would carry stale state
process_task.delay(event=flood_event_object)

# GOOD — pass only the ID
process_task.delay(event_id=flood_event_object.id)
```

### `task.delay()` without `on_commit` inside a transaction

```python
# BAD — a race condition with the DB
@transaction.atomic
def create_event():
    event = FloodEvent.objects.create(...)
    process_task.delay(event.id)   # the worker may not find the record

# GOOD
@transaction.atomic
def create_event():
    event = FloodEvent.objects.create(...)
    transaction.on_commit(lambda: process_task.delay(event.id))
```

### Calling a task synchronously in a View

```python
# BAD — blocks the HTTP response
result = process_task(event_id=42)   # runs synchronously

# GOOD — queues it and returns immediately
process_task.delay(event_id=42)
return Response({'status': 'queued'}, status=202)
```

---

## Table: what a task should and should not do

| Action | Should it? |
|-----|----------|
| Receive simple arguments (int, str) | ✅ |
| Run a SELECT to get an object | ✅ (via a selector) |
| Delegate to a service | ✅ |
| Log errors | ✅ |
| Be idempotent | ✅ |
| Contain business logic | ❌ |
| Receive ORM objects as arguments | ❌ |
| Open `@transaction.atomic` | ❌ (that is the service's role) |
| Return a `Response` | ❌ |
| Know about HTTP | ❌ |

---

## Template

```python
# apps/<app>/tasks.py

from celery import shared_task
from celery.utils.log import get_task_logger

logger = get_task_logger(__name__)


@shared_task(
    autoretry_for=(Exception,),
    max_retries=3,
    retry_backoff=60,
    retry_jitter=False,
)
def <model>_<action>_task(<model>_id: int) -> None:
    from apps.<app>.selectors import <model>_get_by_id
    from apps.<app>.services import <model>_<action>

    logger.info(f"Starting <action> for <model>_id={<model>_id}")

    obj = <model>_get_by_id(<model>_id=<model>_id)
    <model>_<action>(obj=obj)

    logger.info(f"Completed <action> for <model>_id={<model>_id}")
```

```python
# Calling it from a service via on_commit
@transaction.atomic
def <model>_create(*, <field>: <type>) -> <Model>:
    obj = <Model>(<field>=<field>)
    obj.full_clean()
    obj.save()

    transaction.on_commit(
        lambda: <model>_<action>_task.delay(<model>_id=obj.id)
    )

    return obj
```

---

## Connection to the rest of the documentation

| Topic | File |
|------|------|
| Services (`on_commit`, the business logic a task delegates to) | [DJANGO_SERVICES.md](django_services_full.md) |
| Selectors (reading data inside a task) | [DJANGO_SELECTORS.md](django_selectors_full.md) |
| The full picture of the business layer | [DJANGO_SERVICES_SELECTORS.md](services_selectors_full.md) |
| Project structure (`infrastructure/celery/`) | [DJANGO_PROJECT_STRUCTURE.md](../02_django_core/project_structure_full.md) |
