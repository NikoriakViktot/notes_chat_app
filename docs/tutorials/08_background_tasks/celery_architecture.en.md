# Celery architecture

## The problem: why a Django view cannot send email

Django is built on the **Request → Response** model. Each HTTP request occupies one thread of execution. Until the view returns a response, the browser waits. That is why every operation inside a view has to finish as quickly as possible.

Look at what happens if you try to send reminders right inside a view:

```python
# ❌ DON'T DO THIS: it is an antipattern
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    # Check every reminder for every user...
    for reminder in Reminder.objects.filter(remind_at__lte=timezone.now()):
        send_mail(...)   # an SMTP connection takes 300–500 ms per email
        reminder.is_sent = True
        reminder.save()

    return render(request, 'notes_app/note_detail.html', {'note': note})
```

If there are 20 reminders, the view blocks the thread for 6–10 seconds. The browser shows "Loading..." the whole time. With 100 concurrent users the server goes down.

**Three fundamental problems with this approach:**

| Problem | Why it happens | Consequence |
|----------|-------------|---------|
| `send_mail()` blocks the thread | The SMTP handshake is a network operation | the page takes 5+ seconds to load |
| Runs only on an HTTP request | the view fires only when someone opens the page | the reminder is not sent if nobody opens `/notes/42/` at exactly 14:00 |
| Impossible to schedule an exact time | standard Django has no "run at 14:00" mechanism | the reminder is either early or late |

**Rule:** a Django view must not perform operations that take more than ~200 ms or depend on time. That is what **background task queues** exist for.

---

## What a task queue is

A task queue is the "producer → queue → consumer" architectural pattern:

```
Django (view)                           Celery Worker
   │                                        │
   │  task.delay()                          │
   │  "put the task in the queue"           │
   ▼                                        │
Redis (broker)  ←────────────────────────  │
   │            "there is a new task"       │
   │                                        │
   └──────────────────────────────────────► │
                 "I take the task and run it"
                                            ▼
                                       send_mail()
                                       reminder.is_sent = True
```

**The key idea:** Django does not wait for the task to finish. It says "here is a task, run it" and immediately returns a response to the browser. The worker runs the task separately, in its own process.

---

## Celery: a task queue implementation for Python

**Celery** is the most popular task queue library for Python/Django. It consists of several components:

### Celery components

```
┌─────────────────────────────────────────────────────────────────────┐
│                        THE CELERY SYSTEM                            │
│                                                                     │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │  Django  │    │    Redis     │    │     Celery Worker        │  │
│  │  (view)  │───►│   (broker)  │───►│                          │  │
│  │          │    │             │    │  @shared_task functions   │  │
│  └──────────┘    └──────────────┘    └──────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Celery Beat                               │   │
│  │  (scheduler, runs tasks on a schedule, without Django)      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

| Component | Role | Analogy |
|-----------|------|---------|
| **Task** (`@shared_task`) | A Python function that can be put in the queue | "an order" |
| **Broker** (Redis) | a message queue that stores tasks | "the checkout line" |
| **Worker** | a separate process that reads tasks and runs them | "the cashier" |
| **Beat** | a separate scheduler process that queues tasks on a schedule | "the alarm clock" |
| **Result Backend** (Redis) | stores the results of completed tasks | "the receipt" |

### How Beat queues tasks without Django

Beat is a separate **Python process** started with the command:

```bash
celery -A notes_project beat -l info
```

It reads `CELERY_BEAT_SCHEDULE` from `settings.py` and every N seconds publishes a message to Redis:

```
Beat (every 60 sec):
  └─► publishes to Redis: {"task": "notes_app.tasks.send_reminder_notifications", "args": [], "kwargs": {}}

Worker (constantly listens to Redis):
  └─► receives the message → runs send_reminder_notifications()
```

Beat **does not run the task itself**: it only puts it in the queue. The worker runs it.

### Breaking down the Worker start command

```bash
celery -A notes_project worker -l info --concurrency=2
```

| Part | What it means |
|---------|-----------|
| `celery` | The Celery CLI |
| `-A notes_project` | the "app": reads `notes_project/celery.py` |
| `worker` | start a Worker (not Beat) |
| `-l info` | logging level (info, debug, warning, error) |
| `--concurrency=2` | 2 parallel executor processes |

---

## The architecture of the reminder system in notes_chat_app

The project has two independent reminder mechanisms:

```
MECHANISM 1: Email (always, regardless of the browser)
─────────────────────────────────────────────────
Celery Beat (every 60 seconds)
    │
    ▼
@shared_task send_reminder_notifications()
    │
    ├─ SELECT * FROM reminder WHERE remind_at <= now AND is_sent = FALSE
    │
    └─ for each reminder:
          ├── send_mail(to=user.email, ...)  ← in dev, email is printed to the console
          ├── reminder.is_sent = True
          ├── reminder.save(update_fields=['is_sent'])
          └── _schedule_next(reminder)       ← if repeat_pattern ≠ 'none'

MECHANISM 2: Browser Toast (only while the browser is open)
───────────────────────────────────────────────────────────
reminders.js (DOMContentLoaded + every 60 sec)
    │
    ├─ GET /reminders/check/
    │      └─ JsonResponse({reminders: [...]})
    │
    └─ for each new reminder:
          └── Bootstrap Toast (bottom right, 8 seconds)
```

**Why two mechanisms and not one?**

- Email is needed even if the browser is closed → Celery Worker
- The Browser Toast is needed if the browser is open → JS polling
- They are independent: Celery writes `is_sent=True` to the DB, JS reads through a separate endpoint

---

## The Reminder model

Before moving on to the implementation, understand the data structure:

```python
# notes_app/models.py
class Reminder(models.Model):
    REPEAT_CHOICES = [
        ('none',    'Одноразово'),
        ('daily',   'Щодня'),
        ('weekly',  'Щотижня'),
        ('monthly', 'Щомісяця'),
    ]

    note           = models.ForeignKey(Note, on_delete=models.CASCADE,
                                       related_name='reminders')
    remind_at      = models.DateTimeField()        # when to send
    message        = models.TextField(blank=True)  # reminder text
    is_sent        = models.BooleanField(default=False)  # whether it has been sent already
    repeat_pattern = models.CharField(max_length=10, choices=REPEAT_CHOICES,
                                      default='none')

    class Meta:
        ordering = ['remind_at']
```

The `is_sent` field is the key one: the Celery Worker sets it to `True` after sending. This prevents sending again on the next run of the task.

---

## Redis as the broker: why not the database

Popular broker options for Celery:

| Broker | Pros | Cons |
|--------|-------|--------|
| **Redis** | fast (in-memory), simple, already in the project | loses tasks on restart without persistence |
| **RabbitMQ** | reliable, complex routing | harder to set up |
| **PostgreSQL** | no separate service needed | slow, puts load on the DB |

In `notes_chat_app` Redis is already there for Django Channels. We use it for Celery too, but with **different DBs** so the messages do not get mixed:

```
Redis server (one)
├── DB 0  ← Django Channels (WebSocket channel layer)
└── DB 1  ← Celery (broker + result backend)
```

If both used DB 0, Redis could mix up chat WebSocket messages with Celery reminder tasks. Separate DBs isolate them.

---

## Comparison: sync in the view vs Celery in the background

| | Sync in the view | Celery in the background |
|-|-------------|-------------------|
| Response to the browser | **blocked** until completion | instant (< 10 ms) |
| Scheduled execution | ❌ impossible | ✅ Celery Beat |
| Scaling | 1 task at a time (blocks the thread) | N workers in parallel |
| Fault tolerance on error | exception → 500 for the user | automatic retry |
| State visibility | none | worker logs, result backend |
| Complexity | minimal | +2 services (worker, beat), broker |

**When Celery is worth using:**

- the task takes > 200 ms (email, HTTP to an external API, file processing, PDF)
- the task must run on a schedule, independently of HTTP requests
- the task must be run several times with retry on error
- you need to process hundreds of tasks in parallel

---

## In the book

- [Part VI. Application architecture](../../06_application_architecture/README.md): a detailed breakdown of the service layer architecture, Celery patterns, task design
- [Part IX. Async and Real-Time](../../09_async_and_realtime/README.md): asyncio, the event loop, when to use async vs threading vs multiprocessing

---

## Official documentation

- [Celery: First Steps with Django](https://docs.celeryq.dev/en/stable/django/first-steps-with-django.html)
- [Celery: User Guide — Tasks](https://docs.celeryq.dev/en/stable/userguide/tasks.html)
- [Celery: Periodic Tasks (Beat)](https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html)
- [Celery: Workers Guide](https://docs.celeryq.dev/en/stable/userguide/workers.html)
- [Redis: Select DB](https://redis.io/commands/select/): understanding Redis databases
