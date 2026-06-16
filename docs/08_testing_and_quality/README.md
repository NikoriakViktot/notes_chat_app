# Частина VIII. Testing і Quality

Тести перетворюють навчальний проєкт на систему, яку можна змінювати без страху. Notes Chat App має ~205 тестів у 6 файлах — від unit до Selenium E2E.

**Передумови:** Частини II–VII.
**Рівень:** Intermediate → Advanced.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Основи тестування](testing_foundations_full.md) | AAA патерн, piраміда тестів, що тестувати, що мокувати |
| [unittest](unittest_basics_full.md) | `TestCase`, `setUp`, `assert*`, `subTest`, test isolation |
| [pytest](pytest_basics_full.md) | fixtures, parametrize, plugins, `pytest-django` |
| [Django Testing](django_testing_full.md) | `Client`, `force_login`, `RequestFactory`, `TestCase` vs `TransactionTestCase` |
| [Mocking](mocking_and_patching_full.md) | `unittest.mock`, `patch`, `MagicMock`, spy, when to mock |
| [Test Data](test_data_and_fixtures_full.md) | `setUp`, factories, fixtures, `seed_demo_data` |
| [Selenium](selenium_full.md) | `StaticLiveServerTestCase`, `WebDriver`, `find_element`, wait strategies |
| [CI/CD](ci_cd_full.md) | GitHub Actions, jobs, matrix, artifact upload, secrets |
| [Практика тестування](testing_practice_project_full.md) | наскрізний приклад тест-suite для Django проєкту |

---

## Ключові концепти

**Тестова піраміда Notes Chat App:**

```
         E2E (Selenium)         ← 10 тестів, повільно, brittle
        Consumer Tests           ← 30 тестів, TransactionTestCase!
       View Tests (Client)       ← 70 тестів, status codes, redirects
      Service/Form Tests         ← 65 тестів, без HTTP
    Model Tests                  ← 30 тестів, constraints, __str__
```

**Структура тест-файлів:**

```
notes_app/tests/
├── test_models.py      ← TestCase: constraints, __str__, CASCADE
├── test_services.py    ← TestCase: return value + persistence
├── test_forms.py       ← TestCase: is_valid, invalid data, clean_*
├── test_views.py       ← TestCase: Client.force_login, status codes, IDOR
├── test_consumers.py   ← TransactionTestCase: WebsocketCommunicator
└── test_selenium.py    ← StaticLiveServerTestCase: реальний браузер
```

**Типовий service test (AAA):**

```python
class CreateNoteTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user('alice', password='pass')

    def test_create_note_returns_note_instance(self):
        # Arrange
        title, content = 'Test', 'Body'
        # Act
        note = services.create_note(user=self.user, title=title, content=content)
        # Assert
        self.assertIsInstance(note, Note)
        self.assertEqual(note.title, title)

    def test_create_note_persists_to_db(self):
        services.create_note(user=self.user, title='Test', content='')
        self.assertEqual(Note.objects.filter(user=self.user).count(), 1)
```

**IDOR test у test_views.py:**

```python
def test_alice_cannot_read_bobs_note(self):
    bob  = User.objects.create_user('bob', password='pass')
    note = Note.objects.create(user=bob, title='Secret')

    self.client.force_login(self.user)  # alice logged in
    response = self.client.get(reverse('note_detail', args=[note.pk]))

    self.assertEqual(response.status_code, 404)   # не 200!
```

**КРИТИЧНО: TransactionTestCase для consumer tests:**

```python
# ❌ TestCase для consumer → setUp-об'єкти "зникають"
# Причина: TestCase загортає кожен тест у транзакцію → rollback після.
# Async consumer читає БД з окремого worker-потоку —
# цей потік не бачить незакомічену транзакцію TestCase.

# ✅ ЗАВЖДИ TransactionTestCase для WebSocket-тестів
class GroupChatConsumerTest(TransactionTestCase):
    def setUp(self):
        self.user  = User.objects.create_user('alice', password='pass')
        self.group = Group.objects.create(name='Chat')
        self.group.user_set.add(self.user)

    async def test_member_can_connect(self):
        comm = _make_communicator(self.group.pk, self.user)
        connected, _ = await comm.connect()
        self.assertTrue(connected)
        await comm.disconnect()
```

**Запуск тестів:**

```bash
# unit + integration + consumer
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium (потрібен запущений стек)
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

**GitHub Actions CI:**

```yaml
# .github/workflows/django-tests.yml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      db:    # PostgreSQL
      redis: # Redis channel layer
    steps:
      - uses: actions/checkout@v4
      - run: docker compose run --rm web python manage.py test ...
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_app/tests/test_models.py` | constraints, `__str__`, deletion (CASCADE/SET_NULL) |
| `notes_app/tests/test_services.py` | create/update/delete/toggle services |
| `notes_app/tests/test_forms.py` | valid data, invalid data, `clean_title` |
| `notes_app/tests/test_views.py` | IDOR, status codes, redirect targets, CSRF |
| `notes_app/tests/test_consumers.py` | connect, reject anonymous, reject non-member, message, history |
| `notes_app/tests/test_selenium.py` | login flow, create note, group chat |
| `.github/workflows/` | CI конфігурація |

---

## Педагогічний зв'язок

```text
Частина VIII: TestCase ← Частина II (Django)
             TransactionTestCase ← Частина IX (async consumer)
             Selenium ← Частина V (templates, JS)
             CI ← Частина X (Docker)
```

**Zero to Hero:** Крок 6 — написати перший тест, IDOR-тест, consumer тест, CI.

**Lab:** [Testing Lab](../labs/testing_lab.md) — service test + IDOR test + consumer test.

---

## Контрольні питання

- Що таке AAA патерн? Назви три частини і поясни кожну.
- Чому `TestCase` не можна використовувати для consumer-тестів? Що відбувається?
- Яка різниця між `Client.get()` і `RequestFactory.get()`?
- Коли варто мокувати, а коли ні? Чи варто мокувати БД у service-тестах?
- Що тестує `test_models.py`? Наведи приклад assertion для `on_delete=CASCADE`.
- Що таке `StaticLiveServerTestCase`? Чим він відрізняється від `TestCase`?
- Навіщо CI? Що відбувається якщо CI не налаштовано і хтось пушить broken code?

---

**Далі →** [Частина IX. Async і Real-Time](../09_async_and_realtime/README.md) — WebSocket і Channels.
