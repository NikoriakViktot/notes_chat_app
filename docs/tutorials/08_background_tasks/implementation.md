# Реалізація

## Що встановити

Перед початком — переконайся що ці пакети є у `requirements.txt`:

```
celery==5.3.6
redis==5.0.1
python-dateutil==2.9.0
```

`python-dateutil` потрібен для `relativedelta` — точне обчислення дат (місяці, роки). Стандартний `timedelta` не вміє правильно рахувати місяці.

---

## Крок 1 — `celery.py`: ініціалізація Celery-додатку

Спочатку потрібно створити Celery-додаток. Це Python-об'єкт, який знає про налаштування і задачі проєкту.

```python
# notes_project/celery.py
import os
from celery import Celery

# Вказуємо Django де шукати settings.py
# Це потрібно ПЕРЕД тим як Celery спробує імпортувати Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# Створюємо Celery-додаток з іменем нашого Django-проєкту
app = Celery('notes_project')

# Завантажуємо конфігурацію з Django settings.py
# namespace='CELERY' означає: читати тільки змінні що починаються з CELERY_
# Наприклад: CELERY_BROKER_URL, CELERY_RESULT_BACKEND, CELERY_BEAT_SCHEDULE
app.config_from_object('django.conf:settings', namespace='CELERY')

# Автоматично знаходить tasks.py у кожному INSTALLED_APP
# Без цього треба б вручну імпортувати кожен tasks.py
app.autodiscover_tasks()
```

**Чому `namespace='CELERY'`?**

Celery шукає у `settings.py` тільки ті змінні, що починаються з `CELERY_`:

```python
# settings.py
CELERY_BROKER_URL = '...'         # ✅ знайде
CELERY_BEAT_SCHEDULE = {...}      # ✅ знайде
BROKER_URL = '...'                # ❌ старий стиль, ігнорується
```

### Підключення до Django через `__init__.py`

```python
# notes_project/__init__.py
from .celery import app as celery_app

__all__ = ('celery_app',)
```

**Навіщо це потрібно?**

Коли Django стартує, він виконує `notes_project/__init__.py`. Цей рядок гарантує що `celery_app` завантажується **до** того, як будь-який код почне використовувати `@shared_task`.

Без цього могла б виникнути ситуація:

```
Worker стартує → імпортує notes_app.tasks → @shared_task не знає до якого додатку прив'язатись → помилка
```

З цим рядком:

```
Worker стартує → notes_project/__init__.py → celery_app вже існує → @shared_task прив'язується до нього ✓
```

---

## Крок 2 — `tasks.py`: фонова задача

```python
# notes_app/tasks.py
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone


@shared_task
def send_reminder_notifications():
    # Імпорт всередині функції — запобігає циклічним імпортам.
    # tasks.py імпортується до того як Django повністю ініціалізований,
    # тому імпорт моделей на рівні модуля може викликати AppRegistryNotReady.
    from .models import Reminder

    now = timezone.now()

    # select_related('note__user') — вирішує N+1:
    # Замість 1 запит на нотатку + 1 запит на юзера для кожного reminder
    # → 1 SQL запит з JOIN: SELECT reminder.*, note.*, auth_user.*
    pending = (
        Reminder.objects
        .select_related('note__user')
        .filter(remind_at__lte=now, is_sent=False)
    )

    for reminder in pending:
        user = reminder.note.user

        # Перевіряємо що у юзера є email
        # (User може бути створений без email через UserCreationForm за замовчуванням)
        if user.email:
            send_mail(
                subject=f'Нагадування: {reminder.note.title}',
                message=reminder.message or f'Час нагадування для «{reminder.note.title}».',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                # fail_silently=True: якщо SMTP недоступний — не кидаємо виняток.
                # В production варто логувати помилку, але не переривати обробку
                # решти нагадувань через один SMTP збій.
                fail_silently=True,
            )

        # Позначаємо як надіслане
        reminder.is_sent = True

        # update_fields=['is_sent'] — оновлює ТІЛЬКИ це поле:
        # SQL: UPDATE reminder SET is_sent = TRUE WHERE id = 42
        # Замість: UPDATE reminder SET remind_at=..., message=..., is_sent=TRUE, ... WHERE id = 42
        # Ефективніше і безпечніше: якщо інший процес змінив remind_at, ми не перезапишемо його
        reminder.save(update_fields=['is_sent'])

        # Якщо нагадування повторюється — створюємо наступне
        _schedule_next(reminder)


def _schedule_next(reminder):
    """Створює наступне нагадування для повторюваних нотаток."""
    if reminder.repeat_pattern == 'none':
        return  # одноразове — нічого не робимо

    from .models import Reminder
    from dateutil.relativedelta import relativedelta

    # relativedelta замість timedelta для місяців:
    # timedelta(days=30) для 31 січня дає 2 березня (пропускає лютий!)
    # relativedelta(months=1) для 31 січня дає 28/29 лютого (коректно)
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

### Чому `@shared_task`, а не `@app.task`

```python
# ❌ НЕ РОБИ ТАК — жорстке зв'язування з конкретним додатком
from notes_project.celery import app

@app.task
def send_reminder_notifications():
    ...
```

```python
# ✅ ПРАВИЛЬНО — задача прив'язується до активного додатку під час виконання
from celery import shared_task

@shared_task
def send_reminder_notifications():
    ...
```

Різниця важлива:

- `@app.task` вимагає імпортувати конкретний Celery-додаток → циклічні імпорти
- `@shared_task` прив'язується до будь-якого активного Celery-додатку → переносимо між проєктами, немає циклічних імпортів

### `relativedelta` vs `timedelta` для місяців

```python
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta

d = datetime(2024, 1, 31)

# timedelta рахує в днях — не знає про місяці
d + timedelta(days=30)        # → 2024-03-01 (лютий повністю пропущений!)
d + timedelta(days=28)        # → 2024-02-28 (але для жовтня це неправильно)

# relativedelta знає про місяці і їх довжину
d + relativedelta(months=1)   # → 2024-02-29 (2024 — високосний, правильно!)
datetime(2024, 3, 31) + relativedelta(months=1)  # → 2024-04-30 (правильно, у квітні 30 днів)
```

---

## Крок 3 — `settings.py`: конфігурація Celery

```python
# notes_project/settings.py (кінець файлу)

# REDIS_URL задається через env: redis://redis:6379/0
# (URL для Channels, DB 0)
# Замінюємо /0 на /1 — Celery використовує DB 1, щоб не конфліктувати з Channels
_CELERY_REDIS = _REDIS_URL.replace("/0", "/1") if _REDIS_URL else "redis://localhost:6379/1"

# Broker — куди Worker звертається за задачами
CELERY_BROKER_URL = _CELERY_REDIS

# Result Backend — де зберігаються результати виконання
CELERY_RESULT_BACKEND = _CELERY_REDIS

# Timezone — Beat використовує її для розрахунку розкладу
CELERY_TIMEZONE = TIME_ZONE   # з Django settings: 'Europe/Kyiv'

# Серіалізація — JSON безпечніший за Pickle (no arbitrary code execution)
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]

# Розклад для Beat
CELERY_BEAT_SCHEDULE = {
    # Довільна назва — відображається у логах Beat
    "send-reminders-every-minute": {
        # Повний dotted path до задачі — Beat знаходить її через autodiscover
        "task": "notes_app.tasks.send_reminder_notifications",
        # schedule=60.0 — кожні 60 секунд
        # Можна також: crontab(minute='*/5') для кожні 5 хвилин
        "schedule": 60.0,
    },
}
```

### Налаштування email backend для dev

У development немає реального SMTP-сервера. Використовуй консольний backend — він виводить email прямо у термінал:

```python
# settings.py
if DEBUG:
    # Виводить email у термінал замість реального надсилання
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
else:
    # Production: реальний SMTP (Gmail, SendGrid, тощо)
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = os.environ.get('EMAIL_HOST', '')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
    EMAIL_USE_TLS = True
    EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
    EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')

DEFAULT_FROM_EMAIL = 'noreply@notes.example.com'
```

Коли email відправляється з консольним backend — у логах `celery-worker` побачиш:

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

Два способи задати розклад:

```python
# Варіант 1: кожні N секунд (float або int)
"schedule": 60.0        # кожні 60 секунд
"schedule": 3600        # кожну годину

# Варіант 2: crontab — як Linux cron
from celery.schedules import crontab

"schedule": crontab(minute='*/1')          # кожну хвилину
"schedule": crontab(hour=9, minute=0)      # щодня о 09:00
"schedule": crontab(day_of_week='monday')  # щопонеділка
```

Для нагадувань `60.0` — простіше і достатньо. Перевіряємо кожну хвилину чи є прострочені нагадування.

---

## Крок 4 — Docker Compose: два нових сервіси

```yaml
# docker-compose.yml (додати до секції services:)
  celery-worker:
    build: .
    # -A notes_project  → читати celery.py з notes_project/
    # worker            → режим воркера (не beat!)
    # -l info           → рівень логування
    # --concurrency=2   → 2 паралельних процеси виконання задач
    command: celery -A notes_project worker -l info --concurrency=2
    volumes:
      - .:/app
    environment:
      DATABASE_URL: postgres://notes_user:notes_pass@db:5432/notes_db
      REDIS_URL: redis://redis:6379/0
      DJANGO_SETTINGS_MODULE: notes_project.settings
    depends_on:
      db:
        condition: service_healthy   # чекає поки PostgreSQL готовий
      redis:
        condition: service_healthy   # чекає поки Redis готовий
    networks:
      - app-net

  celery-beat:
    build: .
    # beat — режим планувальника
    # Beat тільки ставить задачі у чергу, НЕ виконує їх
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

### Чому Worker і Beat — окремі сервіси

```
╔══════════════════╗       ╔══════════════════╗
║   celery-beat    ║       ║  celery-worker   ║
║                  ║       ║                  ║
║  Щохвилини:      ║──────►║  Виконує задачу  ║
║  "є нова задача" ║       ║  send_reminder.. ║
║                  ║       ║                  ║
║  Екземплярів: 1  ║       ║  Екземплярів: 1+ ║
╚══════════════════╝       ╚══════════════════╝
         │                          │
         └──────── Redis ───────────┘
                  (broker)
```

**Чому Beat = 1 екземпляр?**

Якщо запустити два Beat:

```
Beat 1 о 10:00:00: «ставлю задачу send_reminder_notifications»
Beat 2 о 10:00:00: «ставлю задачу send_reminder_notifications»
→ Worker виконує задачу ДВІЧІ → один юзер отримує два email!
```

Worker можна масштабувати горизонтально (`--concurrency=4`, або кілька `celery-worker` сервісів). Beat — завжди один.

### Перевірка після старту

```bash
docker compose up -d

# Перевір логи Worker — має з'явитись:
docker compose logs celery-worker
# [2026-06-16 10:00:00,000: INFO/MainProcess] celery@abc123 ready.
# [2026-06-16 10:00:00,001: INFO/MainProcess] [tasks]
# [2026-06-16 10:00:00,001: INFO/MainProcess]   . notes_app.tasks.send_reminder_notifications

# Перевір логи Beat — має з'явитись:
docker compose logs celery-beat
# [2026-06-16 10:00:00,000: INFO/MainProcess] beat: Starting...
# [2026-06-16 10:00:00,000: INFO/MainProcess] Scheduler: Sending due task send-reminders-every-minute (notes_app.tasks.send_reminder_notifications)
```

Якщо у логах Worker **немає** `notes_app.tasks.send_reminder_notifications` в списку `[tasks]` — значить `autodiscover_tasks()` не знайшов задачу. Перевір що `notes_app` є у `INSTALLED_APPS`.

---

## Крок 5 — URL для JSON endpoint

Щоб браузер міг отримати нагадування — потрібен URL:

```python
# notes_project/urls.py або notes_app/urls.py
from notes_app import views

urlpatterns = [
    # ... інші URL ...
    path('reminders/check/', views.reminders_check, name='reminders_check'),
]
```

---

## Як вручну поставити задачу у чергу (без Beat)

У production Beat ставить задачі автоматично. Але для тестування можна поставити задачу вручну:

```python
# Django shell або інший код
from notes_app.tasks import send_reminder_notifications

# Варіант 1: delay() — синтаксичний цукор для apply_async()
send_reminder_notifications.delay()

# Варіант 2: apply_async() — більше опцій
send_reminder_notifications.apply_async()
# або з затримкою 30 секунд:
send_reminder_notifications.apply_async(countdown=30)

# Варіант 3: викликати напряму як звичайну функцію (БЕЗ черги — для тестів)
send_reminder_notifications()
```

У тестах ми використовуємо варіант 3 — викликаємо функцію напряму, без Worker і Redis. Це дозволяє тестувати логіку без запущеного Celery.

---

## Типові помилки та їх причини

### `ModuleNotFoundError: No module named 'celery'`

```
Рішення: додай celery до requirements.txt і перебудуй: docker compose up --build
```

### Worker не знаходить задачу: `[tasks]` порожній

```
Причина: notes_app не у INSTALLED_APPS або tasks.py містить синтаксичну помилку

Перевір:
  docker compose logs celery-worker | grep "tasks"
  docker compose run --rm web python -c "from notes_app.tasks import send_reminder_notifications; print('OK')"
```

### Beat не ставить задачі

```
Причина: REDIS_URL вказує не туди, або Beat не підключений до Redis

Перевір:
  docker compose logs celery-beat | grep "ERROR"
  docker compose exec redis redis-cli ping  # має відповісти PONG
```

### Email не надходить у dev

```
Причина: EMAIL_BACKEND не встановлений в console.EmailBackend

Перевір settings.py і логи celery-worker:
  docker compose logs celery-worker | grep "Subject"
```

---

## У книзі

- [Частина VI. Архітектура застосунку](../../06_application_architecture/README.md) — `@shared_task` design patterns, idempotency, retry logic
- [Частина III. Models, Database та ORM](../../03_database_and_orm/README.md) — `update_fields`, `select_related`, N+1 problem

---

## Офіційна документація

- [Celery: @shared_task](https://docs.celeryq.dev/en/stable/reference/celery.app.shared_tasks.html)
- [Celery: Calling Tasks (.delay vs .apply_async)](https://docs.celeryq.dev/en/stable/userguide/calling.html)
- [Celery: Beat Schedule](https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html#entries)
- [Django: send_mail](https://docs.djangoproject.com/en/5.2/topics/email/#send-mail)
- [Django: EMAIL_BACKEND](https://docs.djangoproject.com/en/5.2/topics/email/#email-backends)
- [python-dateutil: relativedelta](https://dateutil.readthedocs.io/en/stable/relativedelta.html)
- [Docker Compose: depends_on](https://docs.docker.com/compose/compose-file/05-services/#depends_on)
