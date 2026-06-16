# Testing Cheatsheet

---

## Запуск тестів у Docker

```bash
# ─── Всі тести (крім Selenium) ────────────────────────────────────────
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2

# ─── Окремий модуль ───────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_services -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_forms -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_views -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_consumers -v 2

# ─── Окремий клас ─────────────────────────────────────────────────────
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models.NoteModelTest -v 2

# ─── Selenium E2E — ТІЛЬКИ exec! ──────────────────────────────────────
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

---

## Структура тест-файлів

```
notes_app/tests/
├── __init__.py
├── test_models.py       ← TagModelTest, NoteModelTest, ChatMessageModelTest
├── test_services.py     ← NoteServiceTest, GroupServiceTest, BaseServiceTest
├── test_forms.py        ← NoteFormTest (IDOR prevention, queryset security)
├── test_views.py        ← NoteListViewTest, NoteDetailViewTest, IDOR checks
├── test_consumers.py    ← GroupChatConsumerTest (WebsocketCommunicator)
└── test_selenium.py     ← Selenium E2E (_DockerLiveServerMixin)
```

---

## Базові патерни

### TestCase + AAA

```python
from django.test import TestCase
from django.contrib.auth.models import User
from notes_app.models import Note

class NoteModelTest(TestCase):

    def setUp(self):
        self.user = User.objects.create_user('testuser', password='pass')

    def test_note_str_returns_title(self):
        # Arrange
        note = Note.objects.create(user=self.user, title='My note', content='...')

        # Act
        result = str(note)

        # Assert
        self.assertEqual(result, 'My note')
```

### BaseServiceTest

```python
class BaseServiceTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user('owner', password='pass')
        self.other = User.objects.create_user('other', password='pass')
```

### Перевірка двох речей у сервісних тестах

```python
def test_create_note(self):
    # 1. Перевіряємо return value
    note = create_note(user=self.user, title='Test', content='Body')
    self.assertIsInstance(note, Note)

    # 2. Перевіряємо персистентність
    self.assertEqual(Note.objects.filter(user=self.user).count(), 1)
```

---

## Consumer тести (WebsocketCommunicator)

```python
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.test import TransactionTestCase, override_settings  # не TestCase!
from notes_project.asgi import application

# TransactionTestCase: async consumer читає БД з окремого потоку.
# TestCase огортає тест у транзакцію — вона невидима цьому потоку.
@override_settings(CHANNEL_LAYERS={"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}})
class ConsumerTest(TransactionTestCase):

    def setUp(self):  # sync setUp, не asyncSetUp
        self.user = User.objects.create_user('testuser', password='pass')
        self.group = Group.objects.create(name='Test')
        self.group.user_set.add(self.user)

    async def test_member_can_connect(self):
        communicator = WebsocketCommunicator(
            application,
            f"/ws/groups/{self.group.pk}/chat/",
            headers=[(b"cookie", b"sessionid=...")]
        )
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        await communicator.disconnect()
```

---

## Selenium тести

```python
# ВАЖЛИВО: exec, не run!
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# Переглянути браузер живцем (VNC):
# http://localhost:7900  (пароль: secret)
```

---

## Корисні assert методи

| Метод | Що перевіряє |
|-------|-------------|
| `assertEqual(a, b)` | `a == b` |
| `assertNotEqual(a, b)` | `a != b` |
| `assertTrue(x)` | `bool(x) is True` |
| `assertFalse(x)` | `bool(x) is False` |
| `assertIsNone(x)` | `x is None` |
| `assertIsNotNone(x)` | `x is not None` |
| `assertIn(a, b)` | `a in b` |
| `assertNotIn(a, b)` | `a not in b` |
| `assertRaises(Exc, fn)` | `fn()` піднімає `Exc` |
| `assertContains(response, text)` | текст у HTTP response |
| `assertRedirects(response, url)` | redirect до url |
| `assertEqual(response.status_code, 200)` | HTTP 200 |
| `assertTemplateUsed(response, 'tmpl.html')` | використаний шаблон |

---

## HTTP client у тестах

```python
from django.test import TestCase, Client

class ViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user('u', password='p')

    def test_anonymous_redirected(self):
        response = self.client.get('/notes/')
        self.assertRedirects(response, '/accounts/login/?next=/notes/')

    def test_authenticated_can_see_list(self):
        self.client.force_login(self.user)   # bypass form login
        response = self.client.get('/notes/')
        self.assertEqual(response.status_code, 200)

    def test_post_creates_note(self):
        self.client.force_login(self.user)
        response = self.client.post('/notes/new/', {
            'title': 'Test Note',
            'content': 'Body',
        })
        self.assertRedirects(response, '/notes/')
        self.assertEqual(Note.objects.count(), 1)
```

---

## Coverage

```bash
docker compose run --rm web bash -c "
    coverage run manage.py test \
        notes_app.tests.test_models \
        notes_app.tests.test_services \
        notes_app.tests.test_forms \
        notes_app.tests.test_views \
        notes_app.tests.test_consumers
    coverage report --show-missing
    coverage html   # генерує htmlcov/index.html
"
```
