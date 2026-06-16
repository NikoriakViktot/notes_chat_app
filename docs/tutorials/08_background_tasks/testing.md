# Тести

## Unit тести задачі

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

---

## Тести JSON view

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

---

## Selenium E2E тест для notifications

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

---

## Як запускати

### Unit тести (окремо, без повного стеку)

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_tasks -v 2
```

Unit тести задачі не потребують Selenium і не потребують запущеного celery-worker — `send_reminder_notifications()` викликається напряму як звичайна Python-функція.

### Selenium тести (потрібен запущений стек)

```bash
# Спочатку підняти стек:
docker compose up -d

# Потім запустити тест через exec (не run!):
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium.SeleniumReminderToastTest -v 2
```

!!! warning "exec, не run"
    Selenium тести запускаються через `docker compose exec`, а не `docker compose run --rm`.
    `run` створює окремий контейнер без мережевого аліасу `web`, який Selenium-контейнер
    використовує щоб дістатися до додатку.

---

## Навіщо тестувати задачу як звичайну функцію

> **Навіщо:** при запуску через `send_reminder_notifications()` (без `.delay()`) Celery Worker не потрібен — задача виконується синхронно у поточному процесі. Це дозволяє тестувати бізнес-логіку ізольовано від інфраструктури.

```python
# У тесті — викликаємо напряму, без Worker і Redis
send_reminder_notifications()       # ← виконується одразу, синхронно

# У production — Beat ставить у чергу через Redis
send_reminder_notifications.delay() # ← Worker виконає асинхронно
```

Це стандартний патерн тестування Celery: тестуємо логіку функції, а не інфраструктуру черги.

---

## У книзі

- [Частина VIII. Testing та Quality](../../08_testing_and_quality/README.md) — `@override_settings`, `mail.outbox`, тестування side effects, integration vs unit tests

---

## Офіційна документація

- [Django: Testing email](https://docs.djangoproject.com/en/5.2/topics/email/#in-memory-backend)
- [Django: override_settings](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#django.test.override_settings)
- [Celery: Testing](https://docs.celeryq.dev/en/stable/userguide/testing.html)
- [Django: StaticLiveServerTestCase](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#liveservertestcase)
- [Selenium: WebDriverWait](https://www.selenium.dev/documentation/webdriver/waits/)
