# Checkpoint

## Practical exercise

### Exercise 1: checking the worker

```bash
docker compose up -d

# Look at the beat logs:
docker compose logs -f celery-beat
# You should see: "Sending due task send-reminders-every-minute"
```

### Exercise 2: a manual test through the shell

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

### Exercise 3: browser toast

1. Run `docker compose up -d` and log in in the browser.
2. Do exercise 2 (create a reminder in the past).
3. Open `/notes/`: the Toast should appear at the bottom right within 3 seconds.
4. Open DevTools → Network → find the `/reminders/check/` request → check the JSON response.

### Exercise 4: understanding repeats

```python
# In the Django shell:
from dateutil.relativedelta import relativedelta
from datetime import datetime

# What does timedelta(days=30) return for January 31?
d = datetime(2024, 1, 31)
print(d + relativedelta(months=1))  # 2024-02-29 (correct)
print(d + __import__('datetime').timedelta(days=30))  # 2024-03-01 (wrong!)
```

Explain why `relativedelta` is the better choice for a monthly repeat.

### Exercise 5: scaling (research)

What happens if you run two instances of `celery-beat`? How can you protect against duplicate tasks? Hint: look up `celery beat --max-interval` and `django-celery-beat`.

---

## Self-check checklist

- [ ] `notes_project/celery.py` exists and contains `app = Celery('notes_project')`
- [ ] `notes_project/__init__.py` imports `celery_app`
- [ ] `CELERY_BROKER_URL` is configured in `settings.py`
- [ ] Celery and Channels use different Redis DBs (0 and 1)
- [ ] `CELERY_BEAT_SCHEDULE` contains `send_reminder_notifications`
- [ ] `celery-worker` and `celery-beat` are in `docker-compose.yml`
- [ ] `celery-beat` runs as a single instance
- [ ] `@shared_task` (not `@app.task`) in `tasks.py`
- [ ] `select_related('note__user')` in the pending reminders query
- [ ] `save(update_fields=['is_sent'])`: updating only one field
- [ ] `relativedelta` for the monthly repeat
- [ ] `GET /reminders/check/` returns `{"reminders": [...]}`
- [ ] `@login_required` on the `reminders_check` view
- [ ] `escapeHtml()` in JS before inserting into the DOM
- [ ] `sessionStorage` deduplicates Toasts within one session
- [ ] `aria-live="polite"` on the toast container
- [ ] Unit tests for `send_reminder_notifications`: `@override_settings(EMAIL_BACKEND=...)`
- [ ] `mail.outbox` checks the sent emails

---

## Navigation

**Previous:** [Step 7. Async Django](../07_async_django/index.md): WebSocket, Channels, GroupChatConsumer

**Next:** Step 9. Deployment: Docker Compose in production, nginx, GitHub Actions CI
