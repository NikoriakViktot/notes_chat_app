# Part VIII. Testing and Quality

Tests turn a learning project into a system you can change without fear. Notes Chat App has ~205 tests in 6 files — from unit tests to Selenium E2E.

**Prerequisites:** Parts II–VII.
**Level:** Intermediate → Advanced.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [Testing foundations](testing_foundations_full.md) | AAA pattern, the test pyramid, what to test, what to mock |
| [unittest](unittest_basics_full.md) | `TestCase`, `setUp`, `assert*`, `subTest`, test isolation |
| [pytest](pytest_basics_full.md) | fixtures, parametrize, plugins, `pytest-django` |
| [Django Testing](django_testing_full.md) | `Client`, `force_login`, `RequestFactory`, `TestCase` vs `TransactionTestCase` |
| [Mocking](mocking_and_patching_full.md) | `unittest.mock`, `patch`, `MagicMock`, spy, when to mock |
| [Test Data](test_data_and_fixtures_full.md) | `setUp`, factories, fixtures, `seed_demo_data` |
| [Selenium](selenium_full.md) | `StaticLiveServerTestCase`, `WebDriver`, `find_element`, wait strategies |
| [CI/CD](ci_cd_full.md) | GitHub Actions, jobs, matrix, artifact upload, secrets |
| [Testing in practice](testing_practice_project_full.md) | an end-to-end example of a test suite for a Django project |

---

## Key concepts

**The Notes Chat App test pyramid:**

```
         E2E (Selenium)         ← 10 tests, slow, brittle
        Consumer Tests           ← 30 tests, TransactionTestCase!
       View Tests (Client)       ← 70 tests, status codes, redirects
      Service/Form Tests         ← 65 tests, no HTTP
    Model Tests                  ← 30 tests, constraints, __str__
```

**Test file structure:**

```
notes_app/tests/
├── test_models.py      ← TestCase: constraints, __str__, CASCADE
├── test_services.py    ← TestCase: return value + persistence
├── test_forms.py       ← TestCase: is_valid, invalid data, clean_*
├── test_views.py       ← TestCase: Client.force_login, status codes, IDOR
├── test_consumers.py   ← TransactionTestCase: WebsocketCommunicator
└── test_selenium.py    ← StaticLiveServerTestCase: real browser
```

**A typical service test (AAA):**

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

**An IDOR test in test_views.py:**

```python
def test_alice_cannot_read_bobs_note(self):
    bob  = User.objects.create_user('bob', password='pass')
    note = Note.objects.create(user=bob, title='Secret')

    self.client.force_login(self.user)  # alice logged in
    response = self.client.get(reverse('note_detail', args=[note.pk]))

    self.assertEqual(response.status_code, 404)   # not 200!
```

**CRITICAL: TransactionTestCase for consumer tests:**

```python
# ❌ TestCase for a consumer → setUp objects "disappear"
# Reason: TestCase wraps each test in a transaction → rollback afterwards.
# The async consumer reads the DB from a separate worker thread —
# that thread cannot see TestCase's uncommitted transaction.

# ✅ ALWAYS use TransactionTestCase for WebSocket tests
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

**Running the tests:**

```bash
# unit + integration + consumer
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium (requires a running stack)
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

## Where this lives in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_app/tests/test_models.py` | constraints, `__str__`, deletion (CASCADE/SET_NULL) |
| `notes_app/tests/test_services.py` | create/update/delete/toggle services |
| `notes_app/tests/test_forms.py` | valid data, invalid data, `clean_title` |
| `notes_app/tests/test_views.py` | IDOR, status codes, redirect targets, CSRF |
| `notes_app/tests/test_consumers.py` | connect, reject anonymous, reject non-member, message, history |
| `notes_app/tests/test_selenium.py` | login flow, create note, group chat |
| `.github/workflows/` | CI configuration |

---

## Pedagogical connections

```text
Part VIII: TestCase ← Part II (Django)
           TransactionTestCase ← Part IX (async consumer)
           Selenium ← Part V (templates, JS)
           CI ← Part X (Docker)
```

**Zero to Hero:** Step 6 — write your first test, an IDOR test, a consumer test, CI.

**Lab:** [Testing Lab](../labs/testing_lab.md) — service test + IDOR test + consumer test.

---

## Review questions

- What is the AAA pattern? Name its three parts and explain each one.
- Why can't `TestCase` be used for consumer tests? What happens?
- What is the difference between `Client.get()` and `RequestFactory.get()`?
- When should you mock, and when not? Should you mock the DB in service tests?
- What does `test_models.py` test? Give an example of an assertion for `on_delete=CASCADE`.
- What is `StaticLiveServerTestCase`? How does it differ from `TestCase`?
- Why CI? What happens if CI is not set up and someone pushes broken code?

---

**Next →** [Part IX. Async and Real-Time](../09_async_and_realtime/README.md) — WebSocket and Channels.
