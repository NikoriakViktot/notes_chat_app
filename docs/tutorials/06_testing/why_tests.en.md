# Why tests matter and how they work

---

## 01 · WHY TESTS

> **The key question:** How do you know nothing broke after your changes?
>
> The answer without tests: run it by hand, click around the site, and hope.
> The answer with tests: run one command and see everything in 30 seconds.

### Analogy: a fire alarm

A house without an alarm: you discover the fire when it is already burning.
A house with an alarm: you learn about the spark BEFORE everything goes up in flames.

**Tests = your code's alarm system.** They check "is everything still correct" on every change.

```
WITHOUT TESTS                           WITH TESTS
──────────────────────────────────────  ──────────────────────────────────────
You write a new feature                 You write a new feature
You click through 10+ pages by hand     You run: manage.py test
"Looks ok"                              FAIL: test_note_visible_only_to_owner
git push → deploy                       You see EXACTLY what broke
A week later: "Bug in production!"      You fix it BEFORE the deploy
You become a detective hunting the cause git push → deploy → all green
```

### A real scenario: you change `selectors.py`

```python
# OLD version (correct):
def get_user_notes(user, *, archived=False):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # ← own + group notes
        is_archived=archived,
    )

# NEW version after "refactoring" (bug!):
def get_user_notes(user, *, archived=False):
    return Note.objects.filter(
        user=user,    # ← forgot the Q filter for groups!
        is_archived=archived,
    )
```

**Without tests:** All group notes disappear for every user.
Customers discover it a week after the production deploy.

**With tests:** `test_selectors.py` immediately reports:
```
FAIL: test_group_notes_visible_to_members
AssertionError: <Note: Team meeting> not found in queryset for bob
```
You fix it in 2 minutes, before committing.

### What else tests give you

| Benefit | Explanation |
|----------|-----------|
| **Documentation** | `test_create_notebook_default_unsets_previous_default` explains the invariant better than a comment |
| **Fearless refactoring** | You change the implementation → the tests confirm the behavior is the same |
| **Finding edge cases** | While writing a test you think: "what if it's None? what if it's empty?" |
| **Protection against regressions** | Bug fixed + test written = the bug never comes back |
| **Security checks** | `test_notebook_queryset_excludes_other_user_notebooks`: IDOR is impossible |
| **CI signal** | GitHub Actions: FAIL before merge → you don't deploy broken code |

---

## 02 · THE TESTING PYRAMID

> **Not all tests are equal.** Different levels have different cost and speed.

```
              ╱╲
             ╱E2E╲          Selenium, Playwright
            ╱──────╲        Real browser, full scenario
           ╱ Integr. ╲      Slow (seconds/test), brittle
          ╱────────────╲    Django Test Client: request → DB → response
         ╱  Consumers   ╲   Medium (100ms/test)
        ╱────────────────╲  WebsocketCommunicator (notes_chat_app only)
       ╱       Unit        ╲ TestCase: function → result
      ╱──────────────────────╲ Fast (1-10ms/test), reliable

    60% Unit | 25% Integration | 10% Consumers | 5% E2E
```

### What we test at each level

**Unit tests** (models, services, forms):
```python
# Test the function in isolation from HTTP
def test_create_notebook_default_unsets_previous_default(self):
    old = services.create_notebook(user=alice, title='Old', is_default=True)
    new = services.create_notebook(user=alice, title='New', is_default=True)
    old.refresh_from_db()
    self.assertFalse(old.is_default)  # 1 is_default per user is an invariant
```

**Integration tests** (views through the Test Client):
```python
# Test through HTTP: view + DB + response
def test_note_list_shows_only_user_notes(self):
    self.client.force_login(alice)
    response = self.client.get(reverse('notes_app:note_list'))
    self.assertEqual(response.status_code, 200)
    self.assertNotContains(response, "Bob's Secret Note")
```

**Consumer tests** (WebSocket, notes_chat_app only):
```python
# WebsocketCommunicator → consumer → channel layer
async def test_non_member_cannot_connect(self):
    communicator = WebsocketCommunicator(application, f'/ws/groups/{pk}/chat/')
    communicator.scope['user'] = self.bob  # not a member of the group
    connected, code = await communicator.connect()
    self.assertFalse(connected)
```

**E2E tests** (Selenium):
```python
# Test through a real browser: clicks, forms, navigation
def test_user_can_login_and_see_dashboard(self):
    self.driver.get(f'{self.live_server_url}/accounts/login/')
    self.driver.find_element(By.NAME, 'username').send_keys('alice')
    self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
    self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()
    self.assertIn('/notes/', self.driver.current_url)
```

### Where our tests live

| Level | File | What it tests | Count |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Model: constraints, `__str__`, defaults, SET_NULL | ~23 |
| Unit | `tests/test_services.py` | Business logic: create, update, delete, security | ~36 |
| Unit | `tests/test_forms.py` | Validation, normalization, queryset filtering | ~23 |
| Integration | `tests/test_views.py` | Views through `self.client`: HTTP codes, ownership, redirects | ~41 |
| Consumer | `tests/test_consumers.py` | WebSocket auth, broadcast, disconnect | ~6 |
| E2E | `tests/test_selenium.py` | Browser: forms, navigation, DOM (skipped without geckodriver) | ~6 |

---

## 03 · DJANGO TESTCASE

> `django.test.TestCase` is `unittest.TestCase` + Django magic.

### What distinguishes Django TestCase from plain unittest

```python
import unittest
from django.test import TestCase

# unittest.TestCase: basic, no DB
class PureUnitTest(unittest.TestCase):
    def test_math(self):
        self.assertEqual(2 + 2, 4)   # OK, no DB

# django.test.TestCase: with the full Django stack
class DjangoTest(TestCase):
    def test_with_db(self):
        user = User.objects.create_user('alice')  # ← requires the test DB
        self.assertEqual(user.username, 'alice')
        # After the test → ROLLBACK → alice is gone automatically
```

### What Django TestCase gives you automatically

```
┌─────────────────────────────────────────────────────────────────────┐
│  Before ALL tests of the class (setUpClass):                        │
│    → Creates the test DB: CREATE DATABASE test_notes_db             │
│    → Applies all migrations (CREATE TABLE ...)                      │
│    → Loads fixtures if there are any                                │
│                                                                     │
│  Before EACH test:                                                  │
│    → BEGIN TRANSACTION                                              │
│    → Calls setUp()                                                  │
│                                                                     │
│    ┌─── THE TEST RUNS ─────────────────────────────────────────┐   │
│    │  User.objects.create(...)  ← INSERT INTO auth_user        │   │
│    │  Note.objects.create(...)  ← INSERT INTO notes_app_note   │   │
│    │  services.create_note(...) ← business logic + INSERT      │   │
│    │  self.assertEqual(...)     ← check                        │   │
│    └───────────────────────────────────────────────────────────┘   │
│                                                                     │
│  After EACH test:                                                   │
│    → ROLLBACK   ← every INSERT/UPDATE/DELETE disappears!            │
│    → Calls tearDown()                                               │
│                                                                     │
│  After ALL tests (tearDownClass):                                   │
│    → DROP DATABASE test_notes_db                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Why rollback is a good thing

```python
class MyTest(TestCase):
    def test_first(self):
        User.objects.create_user('alice')    # ← alice EXISTS
        self.assertEqual(User.objects.count(), 1)
        # After the test → ROLLBACK → alice is gone

    def test_second(self):
        # alice does NOT exist: every test starts from a clean state
        self.assertEqual(User.objects.count(), 0)  # ← 0, not 1!
```

**Without rollback** tests would affect each other:
- test 1 creates alice → test 2 sees alice → results are unpredictable
- The order in which tests run would affect the result

**With rollback** every test is isolated → the result does not depend on the order.

### setUp: preparation before each test

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        """Runs BEFORE each test. The DB is clean."""
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        # These users will exist in every test of this class
        # After each test → ROLLBACK → they disappear → the next setUp creates them again

    def test_something(self):
        # self.alice and self.bob already exist here
        note = services.create_note(user=self.alice, title='Test')
        ...
```

### BaseServiceTest: DRY for a shared setUp

```python
class BaseServiceTest(TestCase):
    """
    Base class with a shared setUp.
    All subclasses automatically get self.alice and self.bob.
    """
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() is NOT needed: it is inherited from BaseServiceTest
    # self.alice and self.bob are available in every test

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)
```

---

## 04 · THE TEST DATABASE

> **The most important rule:** Tests never touch your working DB.

### How Django creates the test DB

```bash
# crispy_notes_project (SQLite):
$ python manage.py test hello_app.tests

Creating test database for alias 'default' ...
#  ↑ Django creates test_<db_name> or an in-memory DB (SQLite)
#    All the data lives there, not in your db.sqlite3!

Found 129 test(s).
...

Destroying test database for alias 'default' ...
#  ↑ The test DB is deleted when the run finishes

# notes_chat_app (PostgreSQL in Docker):
$ docker compose run --rm web python manage.py test notes_app.tests

Creating test database for alias 'default' ...
# ↑ Django: CREATE DATABASE test_notes_db
#   A separate empty DB, distinct from notes_db!
```

### Three kinds of isolation at once

```
1. ISOLATION FROM THE REAL DB:
   db.sqlite3 or notes_db (your working one) ≠ the test DB (separate, temporary)
   Tests cannot break your real data.

2. ISOLATION BETWEEN TESTS:
   Each test has its own transaction → rollback.
   Test A does not see Test B's data.
   The execution order does not affect the result.

3. ISOLATION FROM EXTERNAL SYSTEMS:
   Email: EMAIL_BACKEND = console (nothing is actually sent)
   Redis: InMemoryChannelLayer (tests without a real Redis)
   API: needs a mock (unittest.mock.patch)
```

### --keepdb: speeding things up with many migrations (notes_chat_app)

```bash
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# First run: CREATE + migrate (slow)
# Subsequent runs: only new migrations (fast)
# Useful when there are many migrations
```

---

## 05 · THE AAA PATTERN

> Every test has three clear parts. This is the standard in every language.

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: prepare the state ──────────────────────────────────────
    # What does the test need? Create the minimal required state.
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: perform what we are testing ────────────────────────────────
    # One call, one action. What exactly are we testing? Only this.
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: check the result ────────────────────────────────────────
    # What must be true after Act? Check it precisely.
    note_tags = list(note.tags.all())
    self.assertIn(tag1, note_tags)
    self.assertIn(tag2, note_tags)
```

### Rules of a good test

| Rule | Explanation |
|---------|-----------|
| **One test, one behavior** | `test_create_note_sets_user` ≠ `test_create_note_saves_to_db` |
| **Name = specification** | `test_add_user_to_group_duplicate_returns_false`: the name explains everything |
| **Independence** | A test does not depend on the order or on other tests |
| **Speed** | Unit test < 50ms. If it is slow, check whether you are making unnecessary queries |
| **Determinism** | The same test under the same conditions = the same result |

### Common mistakes in test names

```python
# ✗ BAD: unclear what exactly is being tested
def test_note(self): ...
def test_service(self): ...
def test_1(self): ...

# ✓ GOOD: name = what we check → which result we expect
def test_create_note_sets_correct_user(self): ...
def test_note_group_becomes_null_when_group_deleted(self): ...
def test_non_owner_gets_404_on_note_edit(self): ...
def test_notebook_queryset_excludes_other_user_notebooks(self): ...
```

---

## 06 · READING THE OUTPUT

> Understanding what `manage.py test` shows is a key skill.

### A successful run

```bash
# crispy_notes_project:
$ python manage.py test hello_app.tests -v 2

Creating test database for alias 'default' ...
Found 129 test(s).

test_str_returns_hash_name (hello_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
test_create_note_assigns_tags (...) ... ok
...

----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK   ← ALL GREEN! You can git push.

# notes_chat_app (in Docker):
$ docker compose run --rm web python manage.py test notes_app.tests -v 2
...
OK (skipped=6)
#  ↑ 123 passed, 6 skipped (Selenium without geckodriver): ALL GREEN!
```

### A failed test

```bash
FAIL: test_create_notebook_default_unsets_previous_default
----------------------------------------------------------------------
Traceback (most recent call last):
  File "tests/test_services.py", line 179, in test_create_notebook_...
    self.assertFalse(old_default.is_default)
AssertionError: True is not false

----------------------------------------------------------------------
Ran 129 tests in 77.1s

FAILED (failures=1)
```

**How to read a failed test:**

```
FAIL: test_create_notebook_default_unsets_previous_default
 ↑ Test name → immediately clear WHAT broke

File "tests/test_services.py", line 179
 ↑ Where exactly in the file

self.assertFalse(old_default.is_default)
AssertionError: True is not false
 ↑ We expected False, got True
   → The old default was NOT reset
   → Bug in services.create_notebook()
```

### Result types

| Symbol | Meaning | Cause |
|--------|---------|---------|
| `.` | PASSED | The test passed |
| `F` | FAILED | An `assert` did not hold: wrong result |
| `E` | ERROR | An exception in the test (not AssertionError), for example AttributeError |
| `s` | SKIPPED | `@unittest.skip` or `@unittest.skipUnless`: the test was skipped on purpose |
| `x` | XFAIL | Expected failure (`@unittest.expectedFailure`) |

### Verbosity levels (-v 0/1/2)

```bash
# -v 0: summary only
python manage.py test hello_app.tests
# OK or FAILED (failures=3)

# -v 1 (default): progress dots
python manage.py test hello_app.tests -v 1
# ...............F........ (129 tests)

# -v 2: each test separately (recommended)
python manage.py test hello_app.tests -v 2
# test_str_returns_hash_name ... ok
# test_unique_together... ... ok
```

### Stop at the first failure

```bash
python manage.py test hello_app.tests --failfast
# Stops right at the first FAIL
# Useful when there are many errors

# notes_chat_app:
docker compose run --rm web python manage.py test notes_app.tests --failfast
```

---

## Next

- **[test_models.py](test_models.md)**: what lives in the model, the tests/ structure, validators, SET_NULL
