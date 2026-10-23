# Step 8. Background Tasks: Celery + Redis + Browser Notifications

> Learning project: **notes_chat_app**, the same one as in Steps 1–7.
>
> **Result:** note reminders are sent in the background through Celery Beat, and the browser receives Toast messages through HTTP polling.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 7. Async Django](../07_async_django/index.md): WebSocket, Channels, Redis
    - You need a running **Redis** and **Docker** (already there since Step 7)

---

## What you will learn

- **Why a Django view cannot run long tasks**: the Request → Response model and its limitations
- **Celery**: Worker, Beat, Broker, Result Backend
- **`@shared_task`**: the standard for Django projects
- **Celery Beat**: a scheduler for tasks on a schedule (cron-like)
- **Redis DB 0 vs DB 1**: isolating Channels and Celery
- **`CELERY_BEAT_SCHEDULE`** in `settings.py`: no external packages
- **Browser Notifications through JS polling**: when WebSocket is overkill
- **Toast UI**: Bootstrap Toast, aria-live, XSS protection, sessionStorage deduplication
- **Testing**: unit tests for the task, `@override_settings`, `mail.outbox`, Selenium E2E

---

## The learning project

The same `notes_chat_app` we have been building since Step 1. In this step we add:

- `notes_project/celery.py`: initialization of the Celery app
- `notes_app/tasks.py`: the background task `send_reminder_notifications`
- New `celery-worker` and `celery-beat` services in `docker-compose.yml`
- The JSON endpoint `/reminders/check/` for browser polling
- `reminders.js`: fetch + Bootstrap Toast
- Tests: `test_tasks.py`, additions to `test_views.py` and `test_selenium.py`

---

## The resulting architecture

```
Celery Beat (every minute)
        │
        ▼
@shared_task send_reminder_notifications()
        │
        ├─ email → Console backend (dev)
        └─ reminder.is_sent = True

Browser (every 60 seconds, HTTP polling)
        │
        ▼
GET /reminders/check/  →  JSON [{id, note__title, message, remind_at}]
        │
        ▼
reminders.js  →  Bootstrap Toast (bottom right)
```

---

## Reading order

1. **[Celery architecture](celery_architecture.md)**: the blocking problem, what Celery is, an ASCII diagram, Redis as the broker
2. **[Implementation](implementation.md)**: `celery.py`, `tasks.py`, `settings.py`, `docker-compose.yml` step by step
3. **[Browser Notifications](browser_notifications.md)**: the JSON endpoint, JavaScript polling, the Toast container
4. **[Tests](testing.md)**: unit tests for the task, view tests, Selenium E2E
5. **[Checkpoint](checkpoint.md)**: a practical exercise, a self-check checklist
