# Туторіал 09 — Celery та фонові задачі

**Мета:** зрозуміти чому Django не може виконувати довготривалі операції у HTTP-запиті, як Celery вирішує цю проблему, і реалізувати повну систему нагадувань з email-доставкою та browser-нотифікаціями у `notes_chat_app`.

---

## Зміст

1. [Проблема: Django і час запиту](#проблема-django-і-час-запиту)
2. [Що таке Celery](#що-таке-celery)
3. [Архітектура системи нагадувань](#архітектура-системи-нагадувань)
4. [Крок 1 — celery.py: ініціалізація додатку](#крок-1--celerypy-ініціалізація-додатку)
5. [Крок 2 — tasks.py: @shared_task](#крок-2--taskspy-shared_task)
6. [Крок 3 — settings.py: конфігурація CELERY_*](#крок-3--settingspy-конфігурація-celery_)
7. [Крок 4 — Docker Compose: два нових сервіси](#крок-4--docker-compose-два-нових-сервіси)
8. [Крок 5 — Browser notifications: fetch + Toast](#крок-5--browser-notifications-fetch--toast)
9. [Крок 6 — Тести для воркера і view](#крок-6--тести-для-воркера-і-view)
10. [Практичне завдання](#практичне-завдання)
11. [Чеклист самоперевірки](#чеклист-самоперевірки)

---

## Проблема: Django і час запиту

Django побудований за моделлю **Request → Response**. Кожен HTTP-запит має отримати відповідь якнайшвидше — бажано за < 200 мс.

Що відбудеться, якщо нагадування реалізувати прямо у view?

```python
# ❌ НЕ РОБИ ТАК
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    # Перевіряємо всі нагадування для всіх користувачів...
    for reminder in Reminder.objects.filter(remind_at__lte=now()):
        send_mail(...)   # 0.5 секунди на кожен email
        reminder.is_sent = True
        reminder.save()

    return render(request, 'notes_app/note_detail.html', {'note': note})
```

**Проблеми:**

| Проблема | Наслідок |
|----------|---------|
| `send_mail()` блокує потік | сторінка завантажується 5+ секунд |
| Виконується лише при HTTP-запиті | нагадування не спрацьовує, якщо ніхто не відкрив сторінку |
| Нагадування треба відправити рівно о заданому часі | неможливо без фонового планувальника |

**Правило:** Django-view не повинен виконувати операції, які залежать від часу або можуть тривати довше ніж 1 секунда.

---

## Що таке Celery

**Celery** — розподілена черга задач. Вона дозволяє Django передати роботу окремому процесу-воркеру і одразу повернути відповідь браузеру.

```
Django (view)
    │ .delay()  або  .apply_async()
    ▼
Redis (broker) ← повідомлення у черзі
    │
    ▼
Celery Worker ← окремий процес, виконує задачу
    │
    ▼
PostgreSQL / Email / будь-який сайд-ефект
```

**Компоненти:**

| Компонент | Роль |
|-----------|------|
| **Task** | Python-функція, позначена `@shared_task` |
| **Broker** | черга повідомлень (Redis DB 1 у нашому проєкті) |
| **Worker** | окремий процес, який читає задачі з брокера і виконує їх |
| **Beat** | планувальник: запускає задачі за розкладом (cron-подібно) |
| **Result Backend** | сховище результатів задач (Redis DB 1) |

**Чому не WebSocket для нагадувань?**

WebSocket вимагає активного браузерного з'єднання. Нагадування треба надіслати email незалежно від того, чи відкритий браузер. Celery Worker завжди активний.

---

## Архітектура системи нагадувань

```
Celery Beat (кожну хвилину)
        │
        ▼
@shared_task send_reminder_notifications()
        │
        ├─ Reminder.objects.filter(remind_at__lte=now, is_sent=False)
        │
        └─ for reminder:
               ├── send_mail()          ← email (у dev: console backend)
               ├── reminder.is_sent = True
               └── _schedule_next()    ← якщо repeat_pattern ≠ none

Browser (кожні 60 секунд, HTTP polling)
        │
        ▼
GET /reminders/check/  →  JSON [{id, note__title, message, remind_at}]
        │
        ▼
reminders.js  →  Bootstrap Toast (спливаюче повідомлення)
```

Два незалежних механізми:
- **Email** — Celery робить це у фоні, незалежно від браузера.
- **Browser Toast** — JS питає сервер кожну хвилину і показує спливаючий UI.

---

## Крок 1 — celery.py: ініціалізація додатку

Файл `notes_project/celery.py` ініціалізує Celery-додаток:

```python
# notes_project/celery.py
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

app = Celery('notes_project')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
```

`namespace='CELERY'` означає, що Celery читає лише ті налаштування з `settings.py`, які починаються з `CELERY_`. Наприклад, `CELERY_BROKER_URL`.

`autodiscover_tasks()` автоматично знаходить файли `tasks.py` у кожному встановленому Django-додатку.

Потім у `notes_project/__init__.py` реєструємо Celery-додаток при старті Django:

```python
# notes_project/__init__.py
from .celery import app as celery_app

__all__ = ('celery_app',)
```

Це забезпечує, що Celery-додаток завантажується до того, як будь-який код почне використовувати `@shared_task`.

---

## Крок 2 — tasks.py: @shared_task

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

**Важливі деталі:**

**`@shared_task` замість `@app.task`** — не потребує прямого імпорту Celery-додатку. Задача "прив'язується" до активного додатку під час виконання. Це стандарт для Django-проєктів.

**`select_related('note__user')`** — один SQL-запит замість N+1. Завдяки цьому для 100 нагадувань буде 1 запит, а не 201.

**`save(update_fields=['is_sent'])`** — оновлює лише одне поле, не весь запис. Ефективніше і безпечніше (уникає перезапису змін від інших процесів).

**`relativedelta` замість `timedelta` для місяців** — `timedelta(days=30)` дає неточний результат для лютого. `relativedelta(months=1)` правильно обробляє довжину місяця:

```python
# ❌ timedelta неточний для місяців
datetime(2024, 1, 31) + timedelta(days=30)  # → 2024-03-01 (лютий пропущений!)

# ✅ relativedelta зберігає логіку місяця
datetime(2024, 1, 31) + relativedelta(months=1)  # → 2024-02-29 (коректно)
```

**Відкладені імпорти моделей** (`from .models import Reminder` всередині функції) запобігають циклічним імпортам при ініціалізації Django.

---

## Крок 3 — settings.py: конфігурація CELERY_*

```python
# notes_project/settings.py (кінець файлу)

# Celery використовує Redis DB 1, щоб не конфліктувати з
# Channels channel layer (DB 0)
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
        "schedule": 60.0,   # кожні 60 секунд
    },
}
```

**Чому Redis DB 1?**

У проєкті Redis використовується двічі:

| Хто використовує | Redis DB | Призначення |
|-----------------|----------|-------------|
| Django Channels | `redis://redis:6379/0` | channel layer (WebSocket) |
| Celery | `redis://redis:6379/1` | broker + result backend |

Якщо обидва використовують DB 0, повідомлення Channels і задачі Celery можуть конфліктувати. Різні DB ізолюють їх.

**`CELERY_BEAT_SCHEDULE`** — визначає розклад без зовнішнього пакету `django-celery-beat`. Простіше для навчального проєкту.

---

## Крок 4 — Docker Compose: два нових сервіси

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

**Чому Worker і Beat — окремі сервіси?**

| Сервіс | Роль | Кількість екземплярів |
|--------|------|----------------------|
| `celery-worker` | виконує задачі | 1+ (scale out) |
| `celery-beat` | відправляє задачі у чергу за розкладом | рівно 1 (!)  |

Beat має бути в одному екземплярі — якщо запустити два, задачі потраплять у чергу двічі.

**`--concurrency=2`** — Worker запускає 2 паралельні процеси для виконання задач.

**Перевірка після старту:**

```bash
docker compose up -d

# Логи воркера — має з'явитись:
docker compose logs celery-worker
# celery@... ready.
# [tasks]
#   . notes_app.tasks.send_reminder_notifications

# Логи beat — має з'явитись:
docker compose logs celery-beat
# beat: Starting...
# Scheduler: Sending due task send-reminders-every-minute (...)
```

---

## Крок 5 — Browser notifications: fetch + Toast

Celery надсилає email у фоні. Але щоб показати нагадування прямо у браузері, потрібен окремий механізм.

### Чому не WebSocket?

WebSocket ідеально підходить для **живого двостороннього потоку** (чат). Для нагадувань достатньо **HTTP polling** — простіший механізм без постійного з'єднання.

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
            remind_at__gte=now - timedelta(hours=1),   # вікно 1 год
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

**Вікно 1 година** (`remind_at__gte=now - timedelta(hours=1)`) — якщо користувач відкрив браузер через 30 хвилин після нагадування, він все одно побачить Toast. Нагадування старші 1 години вже не актуальні.

### JavaScript polling

```javascript
// notes_app/static/notes_app/js/reminders.js
(function () {
  'use strict';

  var POLL_INTERVAL = 60_000;           // 60 секунд
  var STORAGE_KEY   = 'shown_reminders'; // sessionStorage — дедуплікація
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

  function escapeHtml(str) {   // XSS захист — завжди екранувати user content
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
    } catch (_) { /* тихий fail — мережа недоступна */ }
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!document.getElementById('reminder-toast-container')) return;
    checkReminders();                          // одразу при завантаженні
    setInterval(checkReminders, POLL_INTERVAL); // потім кожні 60 секунд
  });
})();
```

**Ключові рішення:**

| Рішення | Причина |
|---------|---------|
| `sessionStorage` для дедуплікації | Toast не з'явиться двічі в одній сесії |
| `escapeHtml()` для усього user content | XSS: зловмисник міг вставити `<script>` у назву нотатки |
| `checkReminders()` одразу на `DOMContentLoaded` | тест не чекає 60 секунд — перевірка при першому завантаженні |
| IIFE `(function () { ... })()` | модульна ізоляція — нема глобальних змінних |

### Toast container у base.html

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

<!-- ... решта body ... -->

{% if user.is_authenticated %}
<script src="{% static 'notes_app/js/reminders.js' %}"></script>
{% endif %}
```

`aria-live="polite"` — скрінрідер оголошує нові Toast після поточного речення (не перериває).

---

## Крок 6 — Тести для воркера і view

### Unit тести задачі

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

**`@override_settings(EMAIL_BACKEND='...locmem...')`** — перехоплює email у `mail.outbox` без реального SMTP. Стандартний Django-патерн для тестування email.

**`mail.outbox`** — список об'єктів `EmailMessage`. Кожен має `.to`, `.subject`, `.body`. Автоматично скидається після кожного тесту.

### Тести JSON view

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

### Selenium E2E тест

```python
# notes_app/tests/test_selenium.py (додатковий клас)
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

        # checkReminders() виконується одразу на DOMContentLoaded — чекаємо максимум 10 сек
        toast = WebDriverWait(self.driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, '.toast.show'))
        )
        self.assertIn('Selenium Reminder Note', toast.text)
```

**Чому Selenium тест не чекає 60 секунд?**

`reminders.js` викликає `checkReminders()` одразу на `DOMContentLoaded` — до першого циклу інтервалу. Тест чекає лише HTTP fetch (< 2 секунди).

**Запуск:**

```bash
# Unit тести (без Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_tasks -v 2

# Selenium тести (потрібен запущений стек):
docker compose up -d
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium.SeleniumReminderToastTest -v 2
```

---

## Практичне завдання

**Завдання 1 — перевірка воркера:**

```bash
docker compose up -d

# Переглянь логи beat:
docker compose logs -f celery-beat
# Має бути: "Sending due task send-reminders-every-minute"
```

**Завдання 2 — ручний тест через shell:**

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

**Завдання 3 — browser toast:**

1. Запусти `docker compose up -d` і увійди у браузері.
2. Виконай завдання 2 (створи нагадування в минулому).
3. Відкрий `/notes/` — Toast має з'явитись знизу-праворуч протягом 3 секунд.
4. Відкрий DevTools → Network → знайди запит `/reminders/check/` → перевір JSON відповідь.

**Завдання 4 — розуміння повторень:**

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

**Завдання 5 — масштабування (дослідницьке):**

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

## Далі

Наступний крок: [09 — Deployment](09_deployment.md) — Docker Compose production, nginx, GitHub Actions CI.

Поглиблена документація:
- [Background Tasks — розділ книги](../12_final_project/background_tasks.md)
- [Celery Tasks — теорія](../06_application_architecture/django_tasks_full.md)
- [Async та Real-Time](../09_async_and_realtime/README.md)
