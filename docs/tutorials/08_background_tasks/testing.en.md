# Tests

## Unit tests for the task

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

**`@override_settings(EMAIL_BACKEND='...locmem...')`** captures email in `mail.outbox` without a real SMTP server. The standard Django pattern for testing email.

**`mail.outbox`** is a list of `EmailMessage` objects. Each has `.to`, `.subject`, `.body`. It is reset automatically after every test.

---

## JSON view tests

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

## A Selenium E2E test for notifications

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

        # checkReminders() runs right on DOMContentLoaded: wait at most 10 sec
        toast = WebDriverWait(self.driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, '.toast.show'))
        )
        self.assertIn('Selenium Reminder Note', toast.text)
```

**Why doesn't the Selenium test wait 60 seconds?**

`reminders.js` calls `checkReminders()` right on `DOMContentLoaded`, before the first interval cycle. The test waits only for the HTTP fetch (< 2 seconds).

---

## How to run them

### Unit tests (separately, without the full stack)

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_tasks -v 2
```

The unit tests for the task need neither Selenium nor a running celery-worker: `send_reminder_notifications()` is called directly like a regular Python function.

### Selenium tests (the stack must be running)

```bash
# First bring up the stack:
docker compose up -d

# Then run the test through exec (not run!):
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium.SeleniumReminderToastTest -v 2
```

!!! warning "exec, not run"
    Selenium tests are run through `docker compose exec`, not `docker compose run --rm`.
    `run` creates a separate container without the `web` network alias, which the Selenium container
    uses to reach the application.

---

## Why test the task as a regular function

> **Why:** when you call `send_reminder_notifications()` (without `.delay()`), no Celery Worker is needed: the task runs synchronously in the current process. This lets you test the business logic in isolation from the infrastructure.

```python
# In a test: call it directly, without the Worker and Redis
send_reminder_notifications()       # ← runs immediately, synchronously

# In production: Beat queues it through Redis
send_reminder_notifications.delay() # ← the Worker will run it asynchronously
```

This is the standard Celery testing pattern: we test the function's logic, not the queue infrastructure.

---

## In the book

- [Part VIII. Testing and Quality](../../08_testing_and_quality/README.md): `@override_settings`, `mail.outbox`, testing side effects, integration vs unit tests

---

## Official documentation

- [Django: Testing email](https://docs.djangoproject.com/en/5.2/topics/email/#in-memory-backend)
- [Django: override_settings](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#django.test.override_settings)
- [Celery: Testing](https://docs.celeryq.dev/en/stable/userguide/testing.html)
- [Django: StaticLiveServerTestCase](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#liveservertestcase)
- [Selenium: WebDriverWait](https://www.selenium.dev/documentation/webdriver/waits/)
