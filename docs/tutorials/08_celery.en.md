# Tutorial 09 — Celery and background tasks

**Goal:** understand why Django cannot run long operations inside an HTTP request, how Celery solves this problem, and implement a complete reminder system with email delivery and browser notifications in `notes_chat_app`.

---

## Contents

1. [The problem: Django and request time](#the-problem-django-and-request-time)
2. [What Celery is](#what-celery-is)
3. [Reminder system architecture](#reminder-system-architecture)
4. [Step 1 — celery.py: initializing the app](#step-1--celerypy-initializing-the-app)
5. [Step 2 — tasks.py: @shared_task](#step-2--taskspy-shared_task)
6. [Step 3 — settings.py: CELERY_* configuration](#step-3--settingspy-celery_-configuration)
7. [Step 4 — Docker Compose: two new services](#step-4--docker-compose-two-new-services)
8. [Step 5 — Browser notifications: fetch + Toast](#step-5--browser-notifications-fetch--toast)
9. [Step 6 — Tests for the worker and the view](#step-6--tests-for-the-worker-and-the-view)
10. [Practical task](#practical-task)
11. [Self-check checklist](#self-check-checklist)

---

## The problem: Django and request time

Django is built on the **Request → Response** model. Every HTTP request should get a response as fast as possible — ideally in < 200 ms.

What happens if reminders are implemented right inside a view?

```python
# ❌ DON'T DO THIS
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    # Check all reminders for all users...
    for reminder in Reminder.objects.filter(remind_at__lte=now()):
        send_mail(...)   # 0.5 seconds per email
        reminder.is_sent = True
        reminder.save()

    return render(request, 'notes_app/note_detail.html', {'note': note})
```

**Problems:**

| Problem | Consequence |
|----------|---------|
| `send_mail()` blocks the thread | the page takes 5+ seconds to load |
| Runs only on an HTTP request | the reminder doesn't fire if nobody opened the page |
| The reminder must be sent exactly at the given time | impossible without a background scheduler |

**Rule:** a Django view must not perform operations that depend on time or may take longer than 1 second.

---

## What Celery is

**Celery** is a distributed task queue. It lets Django hand work off to a separate worker process and return a response to the browser immediately.

```
Django (view)
    │ .delay()  or  .apply_async()
    ▼
Redis (broker) ← a message in the queue
    │
    ▼
Celery Worker ← a separate process, runs the task
    │
    ▼
PostgreSQL / Email / any side effect
```

**Components:**

| Component | Role |
|-----------|------|
| **Task** | A Python function marked with `@shared_task` |
| **Broker** | the message queue (Redis DB 1 in our project) |
| **Worker** | a separate process that reads tasks from the broker and runs them |
| **Beat** | the scheduler: launches tasks on a schedule (cron-like) |
| **Result Backend** | storage for task results (Redis DB 1) |

**Why not WebSocket for reminders?**

WebSocket requires an active browser connection. A reminder must send an email regardless of whether the browser is open. The Celery Worker is always active.

---

## Reminder system architecture

```
Celery Beat (every minute)
        │
        ▼
@shared_task send_reminder_notifications()
        │
        ├─ Reminder.objects.filter(remind_at__lte=now, is_sent=False)
        │
        └─ for reminder:
               ├── send_mail()          ← email (in dev: console backend)
               ├── reminder.is_sent = True
               └── _schedule_next()    ← if repeat_pattern ≠ none

Browser (every 60 seconds, HTTP polling)
        │
        ▼
GET /reminders/check/  →  JSON [{id, note__title, message, remind_at}]
        │
        ▼
reminders.js  →  Bootstrap Toast (a pop-up message)
```

Two independent mechanisms:
- **Email** — Celery does this in the background, independently of the browser.
- **Browser Toast** — JS asks the server every minute and shows a pop-up UI.

---

## Step 1 — celery.py: initializing the app

The file `notes_project/celery.py` initializes the Celery app:

```python
# notes_project/celery.py
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

app = Celery('notes_project')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
```

`namespace='CELERY'` means that Celery reads only those settings from `settings.py` that start with `CELERY_`. For example, `CELERY_BROKER_URL`.

`autodiscover_tasks()` automatically finds the `tasks.py` files in every installed Django app.

Then in `notes_project/__init__.py` we register the Celery app when Django starts:

```python
# notes_project/__init__.py
from .celery import app as celery_app

__all__ = ('celery_app',)
```

This ensures that the Celery app is loaded before any code starts using `@shared_task`.

---

## Step 2 — tasks.py: @shared_task

```python
# notes_app/tasks.py
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone


@shared_task
def send_reminder_notifications():
    from .models import Reminder

    now = timezone.now()
    pending = (
        Reminder.objects
        .select_related('note__user')
        .filter(remind_at__lte=now, is_sent=False)
    )

    for reminder in pending:
        user = reminder.note.user

        if user.email:
            send_mail(
                subject=f'Нагадування: {reminder.note.title}',
                message=reminder.message or f'Час нагадування для «{reminder.note.title}».',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=True,
            )

        reminder.is_sent = True
        reminder.save(update_fields=['is_sent'])

        _schedule_next(reminder)


def _schedule_next(reminder):
    if reminder.repeat_pattern == 'none':
        return

    from .models import Reminder
    from dateutil.relativedelta import relativedelta

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

**Important details:**

**`@shared_task` instead of `@app.task`** — doesn't require a direct import of the Celery app. The task is "bound" to the active app at execution time. This is the standard for Django projects.

**`select_related('note__user')`** — one SQL query instead of N+1. Thanks to this, 100 reminders take 1 query, not 201.

**`save(update_fields=['is_sent'])`** — updates only one field, not the whole record. More efficient and safer (avoids overwriting changes from other processes).

**`relativedelta` instead of `timedelta` for months** — `timedelta(days=30)` gives an inaccurate result for February. `relativedelta(months=1)` correctly handles the length of the month:

```python
# ❌ timedelta is inaccurate for months
datetime(2024, 1, 31) + timedelta(days=30)  # → 2024-03-01 (February skipped!)

# ✅ relativedelta keeps the month logic
datetime(2024, 1, 31) + relativedelta(months=1)  # → 2024-02-29 (correct)
```

**Deferred model imports** (`from .models import Reminder` inside the function) prevent circular imports during Django initialization.

---

## Step 3 — settings.py: CELERY_* configuration

```python
# notes_project/settings.py (end of file)

# Celery uses Redis DB 1 so it doesn't conflict with
# the Channels channel layer (DB 0)
_CELERY_REDIS = _REDIS_URL.replace("/0", "/1") if _REDIS_URL else "redis://localhost:6379/1"

CELERY_BROKER_URL = _CELERY_REDIS
CELERY_RESULT_BACKEND = _CELERY_REDIS
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]

CELERY_BEAT_SCHEDULE = {
    "send-reminders-every-minute": {
        "task": "notes_app.tasks.send_reminder_notifications",
        "schedule": 60.0,   # every 60 seconds
    },
}
```

**Why Redis DB 1?**

In the project Redis is used twice:

| Who uses it | Redis DB | Purpose |
|-----------------|----------|-------------|
| Django Channels | `redis://redis:6379/0` | channel layer (WebSocket) |
| Celery | `redis://redis:6379/1` | broker + result backend |

If both use DB 0, Channels messages and Celery tasks may conflict. Different DBs isolate them.

**`CELERY_BEAT_SCHEDULE`** — defines the schedule without the external `django-celery-beat` package. Simpler for an educational project.

---

## Step 4 — Docker Compose: two new services

```yaml
# docker-compose.yml
  celery-worker:
    build: .
    command: celery -A notes_project worker -l info --concurrency=2
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

  celery-beat:
    build: .
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

**Why are the Worker and Beat separate services?**

| Service | Role | Number of instances |
|--------|------|----------------------|
| `celery-worker` | runs the tasks | 1+ (scale out) |
| `celery-beat` | puts tasks into the queue on a schedule | exactly 1 (!)  |

Beat must run as a single instance — if you start two, tasks will land in the queue twice.

**`--concurrency=2`** — the Worker starts 2 parallel processes to run tasks.

**Checking after startup:**

```bash
docker compose up -d

# Worker logs — you should see:
docker compose logs celery-worker
# celery@... ready.
# [tasks]
#   . notes_app.tasks.send_reminder_notifications

# Beat logs — you should see:
docker compose logs celery-beat
# beat: Starting...
# Scheduler: Sending due task send-reminders-every-minute (...)
```

---

## Step 5 — Browser notifications: fetch + Toast

Celery sends the email in the background. But to show a reminder right in the browser, you need a separate mechanism.

### Why not WebSocket?

WebSocket is ideal for a **live two-way stream** (chat). For reminders, **HTTP polling** is enough — a simpler mechanism without a persistent connection.

### JSON endpoint

```python
# notes_app/selectors.py
def get_due_reminders_for_browser(user):
    from datetime import timedelta
    now = timezone.now()
    return list(
        Reminder.objects
        .filter(
            note__user=user,
            remind_at__lte=now,
            remind_at__gte=now - timedelta(hours=1),   # 1-hour window
        )
        .select_related('note')
        .order_by('remind_at')
        .values('id', 'message', 'remind_at', 'note__title')
    )
```

```python
# notes_app/views.py
@login_required
def reminders_check(request):
    data = selectors.get_due_reminders_for_browser(request.user)
    for item in data:
        item['remind_at'] = item['remind_at'].strftime('%d.%m.%Y %H:%M')
    return JsonResponse({'reminders': data})
```

**The 1-hour window** (`remind_at__gte=now - timedelta(hours=1)`) — if the user opens the browser 30 minutes after the reminder, they will still see the Toast. Reminders older than 1 hour are no longer relevant.

### JavaScript polling

```javascript
// notes_app/static/notes_app/js/reminders.js
(function () {
  'use strict';

  var POLL_INTERVAL = 60_000;           // 60 seconds
  var STORAGE_KEY   = 'shown_reminders'; // sessionStorage — deduplication
  var CHECK_URL     = '/reminders/check/';

  function getShownIds() {
    try {
      return new Set(JSON.parse(sessionStorage.getItem(STORAGE_KEY) || '[]'));
    } catch (_) { return new Set(); }
  }

  function markShown(id) {
    var s = getShownIds();
    s.add(id);
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(Array.from(s)));
  }

  function escapeHtml(str) {   // XSS protection — always escape user content
    return String(str)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function showToast(reminder) {
    var container = document.getElementById('reminder-toast-container');
    if (!container) return;

    var toastEl = document.createElement('div');
    toastEl.className = 'toast align-items-center border-0';
    toastEl.innerHTML =
      '<div class="d-flex">'
      + '<div class="toast-body">'
      + '<strong>🔔 Нагадування</strong><br>'
      + '<span>' + escapeHtml(reminder.note__title) + '</span><br>'
      + (reminder.message ? '<small>' + escapeHtml(reminder.message) + '</small><br>' : '')
      + '<small class="text-muted">' + escapeHtml(reminder.remind_at) + '</small>'
      + '</div>'
      + '<button type="button" class="btn-close me-2 m-auto"'
      + ' data-bs-dismiss="toast" aria-label="Закрити"></button>'
      + '</div>';

    container.appendChild(toastEl);
    new bootstrap.Toast(toastEl, { delay: 8000, autohide: true }).show();
    toastEl.addEventListener('hidden.bs.toast', function () { toastEl.remove(); });
  }

  async function checkReminders() {
    try {
      var resp = await fetch(CHECK_URL, { credentials: 'same-origin' });
      if (!resp.ok) return;
      var data = await resp.json();
      var shown = getShownIds();
      (data.reminders || []).forEach(function (r) {
        if (!shown.has(r.id)) { showToast(r); markShown(r.id); }
      });
    } catch (_) { /* silent fail — the network is unavailable */ }
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!document.getElementById('reminder-toast-container')) return;
    checkReminders();                          // immediately on load
    setInterval(checkReminders, POLL_INTERVAL); // then every 60 seconds
  });
})();
```

**Key decisions:**

| Decision | Reason |
|---------|---------|
| `sessionStorage` for deduplication | A Toast won't appear twice in one session |
| `escapeHtml()` for all user content | XSS: an attacker could put a `<script>` into a note title |
| `checkReminders()` immediately on `DOMContentLoaded` | the test doesn't wait 60 seconds — the check happens on the first load |
| IIFE `(function () { ... })()` | module isolation — no global variables |

### Toast container in base.html

```html
<!-- templates/base.html -->
<body>

{% if user.is_authenticated %}
<div id="reminder-toast-container"
     class="toast-container position-fixed bottom-0 end-0 p-3"
     style="z-index: 1100;"
     aria-live="polite"
     aria-label="Нагадування">
</div>
{% endif %}

<!-- ... the rest of the body ... -->

{% if user.is_authenticated %}
<script src="{% static 'notes_app/js/reminders.js' %}"></script>
{% endif %}
```

`aria-live="polite"` — the screen reader announces new Toasts after the current sentence (it doesn't interrupt).

---

## Step 6 — Tests for the worker and the view

### Unit tests for the task

```python
# notes_app/tests/test_tasks.py
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from django.core import mail

from notes_app.models import Note, Reminder
from notes_app.tasks import send_reminder_notifications


class SendReminderTaskTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            'alice', email='alice@test.com', password='pass123'
        )
        self.note = Note.objects.create(
            user=self.user, title='Test Note', content=''
        )

    def _reminder(self, offset_minutes=-5, repeat='none', is_sent=False):
        return Reminder.objects.create(
            note=self.note,
            remind_at=timezone.now() + timedelta(minutes=offset_minutes),
            message='Тест',
            is_sent=is_sent,
            repeat_pattern=repeat,
        )

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
    def test_marks_due_reminder_as_sent(self):
        r = self._reminder(offset_minutes=-5)
        send_reminder_notifications()
        r.refresh_from_db()
        self.assertTrue(r.is_sent)

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
    def test_ignores_future_reminders(self):
        r = self._reminder(offset_minutes=+10)
        send_reminder_notifications()
        r.refresh_from_db()
        self.assertFalse(r.is_sent)

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
    def test_sends_email_to_user(self):
        self._reminder(offset_minutes=-5)
        send_reminder_notifications()
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn('alice@test.com', mail.outbox[0].to)

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
    def test_daily_repeat_creates_next_reminder(self):
        r = self._reminder(offset_minutes=-5, repeat='daily')
        original_at = r.remind_at
        send_reminder_notifications()
        next_r = Reminder.objects.filter(note=self.note, is_sent=False).first()
        self.assertIsNotNone(next_r)
        diff = (next_r.remind_at - original_at).total_seconds()
        self.assertAlmostEqual(diff, 86400, delta=60)
```

**`@override_settings(EMAIL_BACKEND='...locmem...')`** — captures email into `mail.outbox` without a real SMTP server. The standard Django pattern for testing email.

**`mail.outbox`** — a list of `EmailMessage` objects. Each has `.to`, `.subject`, `.body`. It is reset automatically after each test.

### JSON view tests

```python
class RemindersCheckViewTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob = User.objects.create_user('bob', password='pass123')
        self.note = Note.objects.create(user=self.alice, title='Alice Note', content='')

    def test_requires_login(self):
        resp = self.client.get('/reminders/check/')
        self.assertEqual(resp.status_code, 302)

    def test_returns_due_reminders(self):
        self.client.force_login(self.alice)
        r = Reminder.objects.create(
            note=self.note,
            remind_at=timezone.now() - timedelta(minutes=30),
        )
        resp = self.client.get('/reminders/check/')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(len(data['reminders']), 1)
        self.assertEqual(data['reminders'][0]['id'], r.id)

    def test_excludes_other_users_reminders(self):
        self.client.force_login(self.bob)
        Reminder.objects.create(
            note=self.note,
            remind_at=timezone.now() - timedelta(minutes=30),
        )
        resp = self.client.get('/reminders/check/')
        self.assertEqual(len(resp.json()['reminders']), 0)
```

### Selenium E2E test

```python
# notes_app/tests/test_selenium.py (an additional class)
class SeleniumReminderToastTest(_DockerLiveServerMixin, StaticLiveServerTestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            'rem_user', email='rem@test.com', password='pass123'
        )
        self.note = Note.objects.create(
            user=self.user, title='Selenium Reminder Note', content=''
        )

    def test_toast_appears_for_due_reminder(self):
        Reminder.objects.create(
            note=self.note,
            remind_at=timezone.now() - timedelta(minutes=30),
            message='JS toast test',
        )
        self._login_via_cookie()
        self.driver.get(f'{self.live_server_url}/notes/')

        # checkReminders() runs immediately on DOMContentLoaded — wait at most 10 sec
        toast = WebDriverWait(self.driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, '.toast.show'))
        )
        self.assertIn('Selenium Reminder Note', toast.text)
```

**Why doesn't the Selenium test wait 60 seconds?**

`reminders.js` calls `checkReminders()` immediately on `DOMContentLoaded` — before the first interval cycle. The test only waits for the HTTP fetch (< 2 seconds).

**Running:**

```bash
# Unit tests (without Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_tasks -v 2

# Selenium tests (the stack must be running):
docker compose up -d
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium.SeleniumReminderToastTest -v 2
```

---

## Practical task

**Task 1 — checking the worker:**

```bash
docker compose up -d

# Look at the beat logs:
docker compose logs -f celery-beat
# You should see: "Sending due task send-reminders-every-minute"
```

**Task 2 — a manual test via the shell:**

```bash
# Create a reminder in the past
docker compose run --rm web python manage.py shell -c "
from django.utils import timezone
from datetime import timedelta
from notes_app.models import Note, Reminder
from django.contrib.auth.models import User

u = User.objects.filter(is_superuser=False).first()
n = Note.objects.filter(user=u).first()
r = Reminder.objects.create(
    note=n,
    remind_at=timezone.now() - timedelta(minutes=2),
    message='Manual test!',
)
print('Created reminder id:', r.id)
"

# Run the task manually
docker compose run --rm web python manage.py shell -c "
from notes_app.tasks import send_reminder_notifications
send_reminder_notifications()
print('Done')
"

# Check that is_sent=True
docker compose run --rm web python manage.py shell -c "
from notes_app.models import Reminder
print('Sent:', Reminder.objects.filter(is_sent=True).count())
"
```

**Task 3 — browser toast:**

1. Run `docker compose up -d` and log in in the browser.
2. Do task 2 (create a reminder in the past).
3. Open `/notes/` — the Toast should appear in the bottom-right corner within 3 seconds.
4. Open DevTools → Network → find the `/reminders/check/` request → check the JSON response.

**Task 4 — understanding repeats:**

```python
# In the Django shell:
from dateutil.relativedelta import relativedelta
from datetime import datetime

# What does timedelta(days=30) return for December 31?
d = datetime(2024, 1, 31)
print(d + relativedelta(months=1))  # 2024-02-29 (correct)
print(d + __import__('datetime').timedelta(days=30))  # 2024-03-01 (wrong!)
```

Explain why `relativedelta` is the better choice for monthly repetition.

**Task 5 — scaling (research):**

What happens if you run two instances of `celery-beat`? How can you protect against duplicate tasks? Hint: look up `celery beat --max-interval` and `django-celery-beat`.

---

## Self-check checklist

- [ ] `notes_project/celery.py` exists and contains `app = Celery('notes_project')`
- [ ] `notes_project/__init__.py` imports `celery_app`
- [ ] `CELERY_BROKER_URL` is configured in `settings.py`
- [ ] Celery and Channels use different Redis DBs (0 and 1)
- [ ] `CELERY_BEAT_SCHEDULE` contains `send_reminder_notifications`
- [ ] `celery-worker` and `celery-beat` are in `docker-compose.yml`
- [ ] `celery-beat` — a single instance
- [ ] `@shared_task` (not `@app.task`) in `tasks.py`
- [ ] `select_related('note__user')` in the pending reminders query
- [ ] `save(update_fields=['is_sent'])` — updating just one field
- [ ] `relativedelta` for monthly repetition
- [ ] `GET /reminders/check/` returns `{"reminders": [...]}`
- [ ] `@login_required` on the `reminders_check` view
- [ ] `escapeHtml()` in JS before inserting into the DOM
- [ ] `sessionStorage` deduplicates Toasts within one session
- [ ] `aria-live="polite"` on the toast-container
- [ ] Unit tests for `send_reminder_notifications` — `@override_settings(EMAIL_BACKEND=...)`
- [ ] `mail.outbox` checks the sent emails

---

## Next

Next step: [09 — Deployment](09_deployment.md) — Docker Compose production, nginx, GitHub Actions CI.

In-depth documentation:
- [Background Tasks — book chapter](../12_final_project/background_tasks.md)
- [Celery Tasks — theory](../06_application_architecture/django_tasks_full.md)
- [Async and Real-Time](../09_async_and_realtime/README.md)
