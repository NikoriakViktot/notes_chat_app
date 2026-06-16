# Checkpoint

## Практичне завдання

### Завдання 1 — перевірка воркера

```bash
docker compose up -d

# Переглянь логи beat:
docker compose logs -f celery-beat
# Має бути: "Sending due task send-reminders-every-minute"
```

### Завдання 2 — ручний тест через shell

```bash
# Створи нагадування в минулому
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
    message='Ручний тест!',
)
print('Created reminder id:', r.id)
"

# Виконай задачу вручну
docker compose run --rm web python manage.py shell -c "
from notes_app.tasks import send_reminder_notifications
send_reminder_notifications()
print('Done')
"

# Перевір що is_sent=True
docker compose run --rm web python manage.py shell -c "
from notes_app.models import Reminder
print('Sent:', Reminder.objects.filter(is_sent=True).count())
"
```

### Завдання 3 — browser toast

1. Запусти `docker compose up -d` і увійди у браузері.
2. Виконай завдання 2 (створи нагадування в минулому).
3. Відкрий `/notes/` — Toast має з'явитись знизу-праворуч протягом 3 секунд.
4. Відкрий DevTools → Network → знайди запит `/reminders/check/` → перевір JSON відповідь.

### Завдання 4 — розуміння повторень

```python
# У Django shell:
from dateutil.relativedelta import relativedelta
from datetime import datetime

# Що повертає timedelta(days=30) для 31 грудня?
d = datetime(2024, 1, 31)
print(d + relativedelta(months=1))  # 2024-02-29 (правильно)
print(d + __import__('datetime').timedelta(days=30))  # 2024-03-01 (неправильно!)
```

Поясни чому `relativedelta` є кращим вибором для місячного повторення.

### Завдання 5 — масштабування (дослідницьке)

Що станеться якщо запустити два екземпляри `celery-beat`? Як можна захиститись від дублювання задач? Підказка: шукай `celery beat --max-interval` і `django-celery-beat`.

---

## Чеклист самоперевірки

- [ ] `notes_project/celery.py` існує і містить `app = Celery('notes_project')`
- [ ] `notes_project/__init__.py` імпортує `celery_app`
- [ ] `CELERY_BROKER_URL` налаштований у `settings.py`
- [ ] Celery і Channels використовують різні Redis DB (0 і 1)
- [ ] `CELERY_BEAT_SCHEDULE` містить `send_reminder_notifications`
- [ ] `celery-worker` і `celery-beat` у `docker-compose.yml`
- [ ] `celery-beat` — один екземпляр
- [ ] `@shared_task` (не `@app.task`) у `tasks.py`
- [ ] `select_related('note__user')` у запиті pending reminders
- [ ] `save(update_fields=['is_sent'])` — оновлення лише одного поля
- [ ] `relativedelta` для місячного повторення
- [ ] `GET /reminders/check/` повертає `{"reminders": [...]}`
- [ ] `@login_required` на `reminders_check` view
- [ ] `escapeHtml()` у JS перед вставкою у DOM
- [ ] `sessionStorage` дедуплікує Toast-и в одній сесії
- [ ] `aria-live="polite"` на toast-container
- [ ] Unit тести для `send_reminder_notifications` — `@override_settings(EMAIL_BACKEND=...)`
- [ ] `mail.outbox` перевіряє надіслані email

---

## Навігація

**Попередній:** [Крок 7. Async Django](../07_async_django/index.md) — WebSocket, Channels, GroupChatConsumer

**Наступний:** Крок 9. Deployment — Docker Compose production, nginx, GitHub Actions CI
