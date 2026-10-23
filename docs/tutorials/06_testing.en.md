# Tutorial 06 — Django Testing from A to Z

> This tutorial walks you through the **full testing stack of a Django application**:
> unit tests → services → forms → integration (views) → WebSocket consumers → E2E (Selenium).
>
> The project — **`notes_chat_app`** — is a notes manager with group chat.
> In this section we go through the tests that already cover the application.
> You will see how each level protects a different layer of the system.
>
> **Result:** 129+ tests — unit + integration + consumer + Selenium

---

## Contents

**Theory** _(read before the code)_
- [01 · WHY TESTS — an alarm system instead of manual checking](#01--why-tests)
- [02 · PYRAMID — unit vs integration vs E2E](#02--testing-pyramid)
- [03 · DJANGO TESTCASE — how it works under the hood](#03--django-testcase)
- [04 · TEST DATABASE — isolation and rollback](#04--test-database)
- [05 · AAA PATTERN — the structure of every test](#05--aaa-pattern)
- [06 · READING THE OUTPUT — PASSED / FAILED / ERROR](#06--reading-the-output)

**What we test and why**
- [07 · MODELS — constraints, defaults, SET_NULL](#07--testing-models)
- [08 · SERVICES — business logic and security](#08--testing-services)
- [09 · FORMS — validation and queryset filtering](#09--testing-forms)
- [10 · DJANGO TEST CLIENT — integration tests](#10--django-test-client)
- [11 · CONSUMERS — WebSocket tests](#11--consumers)
- [12 · SELENIUM — tests through a real browser in Docker](#12--selenium)

**Step-by-step implementation**
1. [Step 0 — Running the tests in Docker](#step-0--running)
2. [Step 1 — Structure of the tests/ package](#step-1--tests-structure)
3. [Step 2 — test_models.py](#07--testing-models)
4. [Step 3 — test_services.py](#08--testing-services)
5. [Step 4 — test_forms.py](#09--testing-forms)
6. [Step 5 — test_views.py](#10--django-test-client)
7. [Step 6 — test_consumers.py](#11--consumers)
8. [Step 7 — test_selenium.py](#12--selenium)
9. [Step 8 — GitHub Actions CI](#step-8--github-actions-ci)
10. [File structure](#file-structure)

---

## 01 · WHY TESTS

> **The main question:** How do you find out that nothing broke after your changes?
>
> The answer without tests: run it manually, click around the site, hope for the best.
> The answer with tests: run one command and see everything in 30 seconds.

### Analogy — a fire alarm

A house without an alarm: you discover the fire when it is already burning.
A house with an alarm: you learn about the spark BEFORE everything goes up in flames.

**Tests = an alarm system for your code.** They check "is everything still correct" on every change.

```
WITHOUT TESTS                           WITH TESTS
──────────────────────────────────────  ──────────────────────────────────────
You write a new feature                 You write a new feature
Manually click through 10+ pages        docker compose run --rm web manage.py test
"Looks ok"                              FAIL: test_group_notes_visible_to_members
git push → deploy                       AssertionError: Note not found for bob
A week later: "Group notes vanished"    You fix it in 2 minutes before the commit
You turn detective — hunting the cause  git push → CI green → deploy is safe
```

### A real scenario: refactoring selectors.py

```python
# OLD version (correct):
def get_user_notes(user, *, archived=False):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # ← own + group notes
        is_archived=archived,
    )

# NEW version after the "refactoring" (bug!):
def get_user_notes(user, *, archived=False):
    return Note.objects.filter(
        user=user,        # ← forgot the Q-filter for groups!
        is_archived=archived,
    )
```

**Without tests:** all group notes disappear for all users.
Clients find out a week after the deploy to production.

**With tests:** `test_group_notes_visible_to_members` immediately:

```
FAIL: test_group_notes_visible_to_members
AssertionError: <Note: Team meeting> not found in queryset for bob
```

You fix it in 2 minutes before the commit.

### What else tests give you

| Benefit | Explanation |
|----------|-----------|
| **Documentation** | `test_create_notebook_default_unsets_previous_default` explains the invariant better than a comment |
| **Fearless refactoring** | You changed the implementation → the tests confirm the behavior is the same |
| **Edge cases** | While writing a test you think: "what if it's None? what if it's empty?" |
| **Regression protection** | Bug fixed + test written = the bug never comes back |
| **Security check** | `test_notebook_queryset_excludes_other_user_notebooks` — IDOR is impossible |
| **CI signal** | GitHub Actions: FAIL before merge → you don't deploy broken code |

---

## 02 · TESTING PYRAMID

> **Not all tests are equal.** Different levels have different cost and speed.

```
              ╱╲
             ╱E2E╲          Selenium — a real browser
            ╱──────╲        Slow (~10 s/test), brittle
           ╱ Integr. ╲      Django Test Client: HTTP → DB → response
          ╱────────────╲    Medium (~100ms/test)
         ╱ Consumers    ╲   WebsocketCommunicator: WS lifecycle
        ╱────────────────╲  Medium (~200ms/test)
       ╱       Unit        ╲ TestCase: function → result
      ╱──────────────────────╲ Fast (1-10ms/test), reliable

    60% Unit | 25% Integration | 10% Consumers | 5% E2E
```

### Where our tests live

| Level | File | What it tests | Count |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Constraints, `__str__`, defaults, SET_NULL | ~23 |
| Unit | `tests/test_services.py` | CRUD, security, transactions, business rules | ~36 |
| Unit | `tests/test_forms.py` | Validation, normalization, queryset filtering | ~23 |
| Integration | `tests/test_views.py` | HTTP codes, ownership, redirects, IDOR | ~41 |
| Consumer | `tests/test_consumers.py` | WebSocket auth, broadcast, disconnect | ~6 |
| E2E | `tests/test_selenium.py` | Browser: login, forms, navigation | ~6 |

### What each level tests

**Unit tests** — we test a function in isolation:

```python
# Direct call — no HTTP, no templates
def test_create_notebook_default_unsets_previous_default(self):
    old = services.create_notebook(user=alice, title='Old', is_default=True)
    new = services.create_notebook(user=alice, title='New', is_default=True)
    old.refresh_from_db()
    self.assertFalse(old.is_default)   # ← business invariant: 1 default per user
```

**Integration tests** — through the HTTP stack:

```python
# Test Client → middleware → view → DB → response
def test_note_list_shows_only_user_notes(self):
    self.client.force_login(self.alice)
    response = self.client.get(reverse('notes_app:note_list'))
    self.assertNotContains(response, "Bob's Secret Note")
```

**Consumer tests** — the WebSocket lifecycle:

```python
# WebsocketCommunicator → consumer → channel layer
async def test_non_member_cannot_connect(self):
    communicator = WebsocketCommunicator(application, f'/ws/groups/{pk}/chat/')
    communicator.scope['user'] = self.bob  # not a member of the group
    connected, code = await communicator.connect()
    self.assertFalse(connected)
```

**E2E tests** — Selenium:

```python
# Real Chrome → DOM → forms → navigation
def test_user_can_login_and_see_dashboard(self):
    self.driver.get(f'{self.live_server_url}/accounts/login/')
    self.driver.find_element(By.NAME, 'username').send_keys('alice')
    self.driver.find_element(By.NAME, 'password').send_keys('pass123')
    self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()
    self.assertIn('/notes/', self.driver.current_url)
```

---

## 03 · DJANGO TESTCASE

> `django.test.TestCase` is `unittest.TestCase` + Django magic.

### What sets Django TestCase apart from plain unittest

```python
import unittest
from django.test import TestCase

# unittest.TestCase — basic, without a DB and Django
class PureUnitTest(unittest.TestCase):
    def test_math(self):
        self.assertEqual(2 + 2, 4)   # OK, no DB

# django.test.TestCase — with the full Django stack
class DjangoTest(TestCase):
    def test_with_db(self):
        user = User.objects.create_user('alice')   # ← needs the test DB
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
│    → ROLLBACK   ← all INSERT/UPDATE/DELETE disappear!               │
│    → Calls tearDown()                                               │
│                                                                     │
│  After ALL tests (tearDownClass):                                   │
│    → DROP DATABASE test_notes_db                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Why rollback between tests is a good thing

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_first(self):
        Note.objects.create(user=self.alice, title='Test Note')
        self.assertEqual(Note.objects.count(), 1)
        # After the test → ROLLBACK → the Note is gone

    def test_second(self):
        # The Note does NOT exist — each test starts from a clean state
        self.assertEqual(Note.objects.count(), 0)   # ← 0, not 1!
        # Regardless of the order in which tests run!
```

**Without rollback** tests would affect each other:
- test 1 creates a Note → test 2 sees someone else's Note → `count()` = 1 instead of 0
- The order of test execution would affect the result → flaky tests

**With rollback** each test is isolated → the result is deterministic.

### `setUp` — preparation before each test

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        """
        Runs BEFORE EACH test. The DB is clean.
        No tearDown needed — ROLLBACK happens automatically.
        """
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        # self.alice and self.bob will be available in every test
        # After each test → ROLLBACK → they disappear
        # Before the next test → setUp again → new objects

    def test_something(self):
        note = services.create_note(user=self.alice, title='Test')
        # self.alice and self.bob are already here!
```

### BaseServiceTest — DRY for a shared setUp

```python
class BaseServiceTest(TestCase):
    """Base class for all service tests."""
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() is inherited → self.alice and self.bob exist automatically
    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)


class NotebookServiceTest(BaseServiceTest):
    # The same setUp, different test logic
    def test_create_notebook_returns_notebook(self):
        nb = services.create_notebook(user=self.alice, title='Work')
        self.assertIsInstance(nb, Notebook)
```

---

## 04 · TEST DATABASE

> **The most important rule:** tests never touch your working PostgreSQL.

### How Django creates the test DB (PostgreSQL)

```bash
$ docker compose run --rm web python manage.py test notes_app.tests

Creating test database for alias 'default' ...
# ↑ Django: CREATE DATABASE test_notes_db
#   A separate empty DB, different from notes_db!

System check identified no issues.
Found 129 test(s).
...............F...
FAILED (failures=1)

Destroying test database for alias 'default' ...
# ↑ DROP DATABASE test_notes_db
```

### Three levels of isolation at once

```
1. ISOLATION FROM THE WORKING DB:
   notes_db (your prod) ≠ test_notes_db (temporary)
   Tests cannot corrupt real data.

2. ISOLATION BETWEEN TESTS:
   Each test → BEGIN TRANSACTION → code → ROLLBACK
   Test A does not see Test B's data.
   The order of tests does not affect the result.

3. ISOLATION FROM EXTERNAL SYSTEMS:
   Email: EMAIL_BACKEND = console (nothing is sent)
   Redis: InMemoryChannelLayer (tests without Redis)
   API:   needs a mock via unittest.mock.patch
```

### In Docker — PostgreSQL for tests

```bash
# Tests use the same PostgreSQL container (db)
# but create a separate DB: test_<POSTGRES_DB>
#
# To speed things up: keepdb — don't delete it between runs
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# First run: CREATE + migrate (slow)
# Subsequent runs: only migrate new ones (fast)
# Useful when there are many migrations
```

---

## 05 · AAA PATTERN

> Every test has three clear parts. This is a standard across all languages and frameworks.

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: prepare the state ────────────────────────────────────────
    # What does the test need? The minimum required state.
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: perform what we are testing ─────────────────────────────────
    # One call. What exactly are we testing?
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: check the result ─────────────────────────────────────────
    # What must be true after Act? Be specific.
    note_tags = list(note.tags.all())
    self.assertIn(tag1, note_tags)
    self.assertIn(tag2, note_tags)
```

### Rules of a good test

| Rule | Explanation |
|---------|-----------|
| **One test — one behavior** | `test_create_note_sets_user` ≠ `test_create_note_saves_to_db` — different asserts |
| **Name = specification** | `test_add_user_to_group_duplicate_returns_false` explains everything without comments |
| **Independence** | Does not depend on order or on other tests (no global state) |
| **Speed** | A unit test < 50ms. If it is slow — check for unnecessary DB queries |
| **Determinism** | The same test under the same conditions = the same result, always |

### Common mistakes in test names

```python
# ✗ BAD: unclear what exactly is being tested
def test_note(self): ...
def test_service(self): ...
def test_1(self): ...

# ✓ GOOD: name = what we check → what result we expect
def test_create_note_sets_correct_user(self): ...
def test_note_group_becomes_null_when_group_deleted(self): ...
def test_non_owner_gets_404_on_note_edit(self): ...
def test_notebook_queryset_excludes_other_user_notebooks(self): ...
```

---

## 06 · READING THE OUTPUT

> Understanding the output of manage.py test is a key skill.

### A successful run (-v 2)

```bash
$ docker compose run --rm web python manage.py test notes_app.tests -v 2

Creating test database for alias 'default' ...
Found 129 test(s).

test_str_returns_hash_name (notes_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
test_unique_together_different_users_same_name_ok (...) ... ok
test_note_group_becomes_null_when_group_deleted (...) ... ok
test_create_note_sets_correct_user (...) ... ok
...
test_login_flow_redirects_to_notes (notes_app.tests.test_selenium.SeleniumLoginFlowTest) ... skipped 'selenium not installed'
...

----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK (skipped=6)
#  ↑ 123 passed, 6 skipped (Selenium without geckodriver) — ALL GREEN!
```

### A failed test

```bash
FAIL: test_create_notebook_default_unsets_previous_default
----------------------------------------------------------------------
Traceback (most recent call last):
  File "notes_app/tests/test_services.py", line 179, in test_create_notebook...
    self.assertFalse(old.is_default)
AssertionError: True is not false
#                  ↑ Expected False, got True

----------------------------------------------------------------------
Ran 129 tests in 77.1s
FAILED (failures=1)
```

**How to read it:**

```
FAIL: test_create_notebook_default_unsets_previous_default
 ↑ The name → what broke (invariant: only 1 default per user)

File "tests/test_services.py", line 179
 ↑ The exact place in the file

self.assertFalse(old.is_default)
AssertionError: True is not false
 ↑ Expected False (the old default reset)
   Got True (it was not reset)
   → Bug in services.create_notebook(): missing .update(is_default=False)
```

### Result types

| Symbol | Name | Cause |
|--------|-------|---------|
| `.` | PASSED | The test passed |
| `F` | FAILED | An `assert` did not hold — wrong result |
| `E` | ERROR | An exception in the test (not AssertionError) — AttributeError, ImportError, etc. |
| `s` | SKIPPED | `@unittest.skip` or `@unittest.skipUnless` — skipped on purpose |
| `x` | XFAIL | `@unittest.expectedFailure` — an expected failure (a known bug) |

### Verbosity levels

```bash
# -v 0: summary only
docker compose run --rm web python manage.py test notes_app.tests
# → OK  or  FAILED (failures=3, errors=1)

# -v 1 (default): progress dots
docker compose run --rm web python manage.py test notes_app.tests -v 1
# → ...............F....s...... (129 tests)

# -v 2: each test separately (recommended)
docker compose run --rm web python manage.py test notes_app.tests -v 2
# → test_str_returns_hash_name ... ok
# → test_unique_together... ... ok
```

### Stop at the first failure

```bash
docker compose run --rm web python manage.py test notes_app.tests --failfast
# With many errors — it stops immediately
# You focus on the first bug, not on all of them at once
```

---

## 07 · TESTING MODELS

> **Question:** Why test models? They are just fields and relations.
>
> **Answer:** A model contains business rules. If they are violated, the application silently behaves incorrectly.

### What lives in the model and what can break

```
Note model
  ├── priority: validators=[MinValueValidator(1), MaxValueValidator(4)]
  │     If someone removes the validators → the form accepts priority=99
  │     → PRIORITY_CHOICES won't find 99 → KeyError in the template
  │
  ├── group: ForeignKey(Group, on_delete=SET_NULL)
  │     If changed to CASCADE → deleting a group deletes all its notes!
  │     → Users lose data and find out in production
  │
  ├── notebook: ForeignKey(Notebook, on_delete=SET_NULL)
  │     If CASCADE → deleting a notebook deletes its notes
  │
  ├── is_pinned: BooleanField(default=False)
  │     If default=True → all new notes are pinned → sorting is broken
  │
  ├── __str__: "📌 {title}" or "{title}"
  │     If the format changes → Admin and logs show it incorrectly
  │
  └── Tag: UniqueConstraint(fields=['user', 'name'])
        If removed → two 'python' tags for one user → bugs in forms
```

### The full structure of test_models.py

```python
# notes_app/tests/test_models.py
from django.contrib.auth.models import Group, User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase

from notes_app.models import (
    ChatMessage, Note, Notebook, Reminder,
    ShopItem, ShoppingList, Tag, TodoItem, TodoList,
)


class TagModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')

    # ── __str__ ────────────────────────────────────────────────────────────

    def test_str_returns_hash_name(self):
        tag = Tag.objects.create(user=self.alice, name='python')
        self.assertEqual(str(tag), '#python')

    # ── UniqueConstraint ───────────────────────────────────────────────────

    def test_unique_constraint_same_user_same_name_raises(self):
        """Two identical tags for one user → IntegrityError."""
        Tag.objects.create(user=self.alice, name='work')
        with self.assertRaises(IntegrityError):
            Tag.objects.create(user=self.alice, name='work')

    def test_unique_constraint_different_users_same_name_ok(self):
        """Different users may have tags with the same name."""
        Tag.objects.create(user=self.alice, name='work')
        Tag.objects.create(user=self.bob,   name='work')   # ← OK
        self.assertEqual(Tag.objects.count(), 2)


class NoteModelTest(TestCase):

    def setUp(self):
        self.alice  = User.objects.create_user('alice', password='pass123')
        self.group  = Group.objects.create(name='Family')

    # ── Defaults ───────────────────────────────────────────────────────────

    def test_default_priority_is_1(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertEqual(note.priority, 1)

    def test_default_is_pinned_is_false(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertFalse(note.is_pinned)

    def test_default_is_archived_is_false(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertFalse(note.is_archived)

    # ── Validators (only via full_clean!) ─────────────────────────────────

    def test_priority_above_4_raises_validation_error(self):
        """
        validators=[MinValueValidator(1), MaxValueValidator(4)] are checked by full_clean().
        NOT checked by .objects.create() — Django bypasses validators on a direct write.
        """
        note = Note(user=self.alice, title='Test', priority=5)
        with self.assertRaises(ValidationError) as ctx:
            note.full_clean()
        self.assertIn('priority', ctx.exception.message_dict)

    def test_priority_0_raises_validation_error(self):
        note = Note(user=self.alice, title='Test', priority=0)
        with self.assertRaises(ValidationError):
            note.full_clean()

    def test_priority_4_is_valid(self):
        """The boundary value 4 is valid."""
        note = Note(user=self.alice, title='Test', priority=4)
        note.full_clean()   # ← must not raise an exception

    # ── SET_NULL: protection against CASCADE ──────────────────────────────

    def test_note_group_becomes_null_when_group_deleted(self):
        """
        Documents and protects the SET_NULL behavior:
        if someone changes it to CASCADE → group notes get deleted → users' data is lost.
        This test will fail (DoesNotExist) and prevent the deploy.
        """
        note = Note.objects.create(user=self.alice, title='Family note', group=self.group)

        self.group.delete()

        note.refresh_from_db()         # ← REQUIRED! The Python object is stale
        self.assertIsNone(note.group)  # the note survived, group = NULL ✓

    def test_note_notebook_becomes_null_when_notebook_deleted(self):
        """Deleting a notebook → notes become notebook-less (they are not deleted)."""
        nb   = Notebook.objects.create(user=self.alice, title='Work')
        note = Note.objects.create(user=self.alice, title='Work note', notebook=nb)

        nb.delete()

        note.refresh_from_db()
        self.assertIsNone(note.notebook)   # SET_NULL on the notebook FK ✓

    # ── __str__ ────────────────────────────────────────────────────────────

    def test_str_pinned_note_has_pin_emoji(self):
        note = Note.objects.create(user=self.alice, title='Important', is_pinned=True)
        self.assertIn('Important', str(note))

    def test_str_unpinned_note(self):
        note = Note.objects.create(user=self.alice, title='Normal')
        self.assertEqual(str(note), 'Normal')


class NotebookModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_default_is_not_default(self):
        nb = Notebook.objects.create(user=self.alice, title='Work')
        self.assertFalse(nb.is_default)

    def test_str_returns_title(self):
        nb = Notebook.objects.create(user=self.alice, title='My Notebook')
        self.assertEqual(str(nb), 'My Notebook')


class ChatMessageModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.group = Group.objects.create(name='Team')

    def test_chat_message_cleared_when_group_deleted(self):
        """
        ChatMessage.group = FK(Group, CASCADE):
        Deleting a group → all chat messages are deleted.
        (Unlike Note.group = SET_NULL)
        """
        ChatMessage.objects.create(
            group=self.group, author=self.alice, content='Hello!'
        )
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.group.delete()

        self.assertEqual(ChatMessage.objects.count(), 0)   # CASCADE ✓

    def test_chat_message_deleted_when_author_deleted(self):
        """
        ChatMessage.author = FK(User, CASCADE):
        Deleting a user → all of their messages are deleted along with them.
        """
        ChatMessage.objects.create(
            group=self.group, author=self.alice, content='I will be deleted'
        )
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.alice.delete()

        # CASCADE: the messages are deleted together with the author
        self.assertEqual(ChatMessage.objects.count(), 0)
```

### Why `full_clean()` and not `.save()` for validators

```python
# ❌ WRONG — validators are ignored:
note = Note.objects.create(user=user, title='Test', priority=99)
# Django will save priority=99! Validators are bypassed on a direct write.
# A CheckConstraint in PostgreSQL may fire → IntegrityError
# But validators (MinValueValidator, MaxValueValidator) — won't!

# ✅ RIGHT — via full_clean():
note = Note(user=user, title='Test', priority=99)  # ← we don't save
with self.assertRaises(ValidationError):
    note.full_clean()   # ← validators run here!

# full_clean() performs:
# 1. validate_unique() — UniqueConstraint
# 2. clean_fields()    — field validators (MinValueValidator, MaxValueValidator...)
# 3. clean()           — custom model validation
```

---

## 08 · TESTING SERVICES

> **Services are the best layer for unit tests.** No HTTP, no templates, only logic.

### Why services are easy to test

```
VIEWS (HTTP layer):                    SERVICES (business logic):
  Accepts the request                    create_note(user=alice, title='Test')
  Parses the form                        Accepts Python objects
  Checks CSRF                            Returns a result
  Calls the service                      Saves to the DB
  Renders the template                   No dependencies on HTTP!
  Depends on: HTTP, sessions,
  forms, templates, middleware         We test directly:
  → Hard to test in isolation            result = services.create_note(...)
                                         self.assertEqual(result.title, 'Test')
```

### Two kinds of checks in every test

```python
# KIND 1: checking the RETURNED OBJECT (return value)
def test_create_note_returns_note_object(self):
    note = services.create_note(user=self.alice, title='Test')
    self.assertIsInstance(note, Note)
    self.assertEqual(note.title, 'Test')
    self.assertEqual(note.user, self.alice)

# KIND 2: checking the DB STATE (persistence test)
def test_create_note_saves_to_database(self):
    services.create_note(user=self.alice, title='Test')
    self.assertEqual(Note.objects.count(), 1)
    # ↑ We check what was SAVED, not just what was returned

# WHY BOTH?
# Bug: create_note() returns a note but doesn't call .save()
# Test 1 passes (the object exists), Test 2 fails (count=0)
# Together — full coverage
```

### Persistence test — "was it really saved to the DB?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    Buggy code could do:
        def toggle_pin_note(note):
            note.is_pinned = True   ← changed it in Python memory
            return note             ← but didn't save it! (no note.save())

    The test explicitly re-reads from the DB with a separate SELECT — it doesn't rely on the cached object.
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)

    services.toggle_pin_note(note)

    # Read a NEW object from the DB:
    note_from_db = Note.objects.get(pk=note.pk)
    self.assertTrue(note_from_db.is_pinned)
    # If toggle_pin_note() didn't save → note_from_db.is_pinned=False → FAIL
```

### Security test — Mass Assignment via tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Attack: an attacker sends POST /notes/new/ with a tag_id that belongs to Bob.
    tag_ids=[bob_secret_tag_id]

    WITHOUT PROTECTION (vulnerable):
        note.tags.set(Tag.objects.filter(id__in=tag_ids))
        → Bob's tag gets attached to Alice's note!
        → Alice sees Bob's secret tag on her note → DATA LEAK

    WITH PROTECTION (our code in services.py):
        note.tags.set(Tag.objects.filter(id__in=tag_ids, user=user))
        → filter(user=user) blocks other users' tags
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)   # the foreign tag was not attached ✓
```

### Transactional invariant — one default notebook

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Business rule: a user has ONLY ONE default notebook.

    If you remove .update(is_default=False) in services.create_notebook():
      → two notebooks with is_default=True
      → unpredictable sidebar behavior (shows both as default)
      → the note form picks the "first" default → chaotic

    This test will detect the violation IMMEDIATELY, before the deploy.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)
    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()          # ← read the fresh state from the DB!
    self.assertFalse(old.is_default)  # the old one is reset ✓
    self.assertTrue(new.is_default)   # the new one is set ✓


def test_create_notebook_default_does_not_affect_other_users(self):
    """
    The invariant is reset for ONE user only.
    Without filter(user=user) in services.py → the defaults of ALL users get reset.
    """
    alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
    bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

    # Alice creates another default:
    services.create_notebook(user=self.alice, title='Alice2', is_default=True)

    bob_nb.refresh_from_db()
    self.assertTrue(bob_nb.is_default)   # Bob's default was not touched ✓
```

### Group services tests

```python
class GroupServiceTest(BaseServiceTest):

    def test_create_group_adds_creator_as_member(self):
        """The creator automatically becomes the first member."""
        group = services.create_group(name='Team', creator=self.alice)
        self.assertIn(self.alice, group.user_set.all())

    def test_add_user_to_group_returns_true_on_success(self):
        group = services.create_group(name='Team', creator=self.alice)
        ok, msg = services.add_user_to_group(group, self.bob.username)
        self.assertTrue(ok)
        self.assertEqual(msg, '')

    def test_add_user_to_group_returns_false_for_unknown_username(self):
        group = services.create_group(name='Team', creator=self.alice)
        ok, msg = services.add_user_to_group(group, 'ghost_user_xyz')
        self.assertFalse(ok)
        self.assertIn('не знайдено', msg)

    def test_add_user_to_group_returns_false_for_duplicate(self):
        """Adding an existing member → False, not an exception."""
        group = services.create_group(name='Team', creator=self.alice)
        services.add_user_to_group(group, self.bob.username)   # first time ✓
        ok, msg = services.add_user_to_group(group, self.bob.username)  # second time
        self.assertFalse(ok)
        self.assertIn('вже є членом', msg)

    def test_delete_group_sets_note_group_to_null(self):
        """Deleting a group → Note.group = NULL (SET_NULL)."""
        group = services.create_group(name='Fam', creator=self.alice)
        note  = Note.objects.create(user=self.alice, title='Family note', group=group)

        services.delete_group(group)

        note.refresh_from_db()
        self.assertIsNone(note.group)   # the note survived ✓
```

---

## 09 · TESTING FORMS

### How to test a form without HTTP

```python
# We test the form directly — no Test Client, no HTTP:
from notes_app.forms import TagForm, NoteForm

# A valid form:
form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
#                                ↑ msg=form.errors: if it fails → we see WHY

# An invalid form:
form = TagForm(data={'name': '', 'color': '#ff0000'}, user=self.alice)
self.assertFalse(form.is_valid())
self.assertIn('name', form.errors)

# Checking cleaned_data (the normalized value):
form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)
form.is_valid()
self.assertEqual(form.cleaned_data['name'], 'python')   # lowercase normalization
```

### The most important form test — queryset security

```python
def test_notebook_queryset_excludes_other_user_notebooks(self):
    """
    WITHOUT protection in the form:
        NoteForm().fields['notebook'].queryset = Notebook.objects.all()
        → Alice sees Bob's Private Notebook in the dropdown!
        → Alice picks Bob's notebook → Alice's note shows up in Bob's notebook
        → DATA LEAK

    WITH protection (our NoteForm.__init__):
        queryset = Notebook.objects.filter(user=self.user)
        → Alice sees only her own notebooks → IDOR is impossible
    """
    alice_nb = Notebook.objects.create(user=self.alice, title="Alice's")
    bob_nb   = Notebook.objects.create(user=self.bob,   title="Bob's Private")

    form = NoteForm(user=self.alice)

    self.assertIn(alice_nb, form.fields['notebook'].queryset)
    self.assertNotIn(bob_nb, form.fields['notebook'].queryset)   # Bob's is not visible ✓

def test_tag_queryset_excludes_other_user_tags(self):
    """The same check for tags in NoteForm."""
    alice_tag = Tag.objects.create(user=self.alice, name='my-tag')
    bob_tag   = Tag.objects.create(user=self.bob,   name='bob-secret')

    form = NoteForm(user=self.alice)

    self.assertIn(alice_tag, form.fields['tags'].queryset)
    self.assertNotIn(bob_tag, form.fields['tags'].queryset)   # Bob's is not visible ✓
```

### Normalization and validation tests

```python
class TagFormTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_name_normalized_to_lowercase(self):
        """The tag name is stored in lowercase."""
        form = TagForm(data={'name': 'PYTHON', 'color': '#3776AB'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'python')

    def test_empty_name_is_invalid(self):
        form = TagForm(data={'name': '', 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
        self.assertIn('name', form.errors)

    def test_name_too_long_is_invalid(self):
        form = TagForm(data={'name': 'x' * 51, 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
```

---

## 10 · DJANGO TEST CLIENT

> The Test Client simulates an HTTP request **inside the Django process** — no network, but through the whole middleware stack.

### What passes through the Test Client

```
self.client.get('/notes/')
    ↓
SecurityMiddleware         → checks HTTPS headers
SessionMiddleware          → loads the session from the test DB
AuthenticationMiddleware   → sets request.user
CsrfViewMiddleware         → CSRF check (disabled for test client POST)
note_list view             → @login_required → selectors → QuerySet
HTML Response              ← the template is rendered with real data
    ↓
response.status_code       → 200 / 302 / 404
response.content           → HTML bytes
response.context           → the template context (for assertContains)
```

### A base class for integration tests

```python
# notes_app/tests/test_views.py
from django.contrib.auth.models import Group, User
from django.test import TestCase
from django.urls import reverse

from notes_app.models import Note, Notebook, Tag


class BaseViewTest(TestCase):
    """Base class with alice and bob for all view tests."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
```

### force_login vs login

```python
# force_login — fast, without a password check (the standard in tests)
self.client.force_login(self.alice)
# → doesn't run the auth pipeline, doesn't check the password
# → simply sets the session cookie → request.user = alice
# → ideal for tests where we don't care about the login process itself

# login — the full auth pipeline (only if you are testing the login process itself)
success = self.client.login(username='alice', password='pass123')
# → authenticate() + login() + session
# → Use only in test_selenium or test_login_flow
```

### Pattern 1 — @login_required: redirecting anonymous users

```python
class NoteListViewTest(BaseViewTest):

    def test_anonymous_redirects_to_login(self):
        """An anonymous user → redirect to /accounts/login/?next=/notes/"""
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 302)
        self.assertIn('/accounts/login/', response['Location'])

    def test_authenticated_gets_200(self):
        self.client.force_login(self.alice)
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 200)

    def test_note_list_shows_only_user_notes(self):
        """Multi-tenant: Alice doesn't see Bob's notes."""
        Note.objects.create(user=self.bob, title="Bob's Secret Note")
        self.client.force_login(self.alice)

        response = self.client.get(reverse('notes_app:note_list'))

        self.assertNotContains(response, "Bob's Secret Note")
```

### Pattern 2 — Ownership check: 404 for other users' objects

```python
class NoteDetailViewTest(BaseViewTest):

    def test_owner_gets_200(self):
        note = Note.objects.create(user=self.alice, title='Alice Note')
        self.client.force_login(self.alice)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)

    def test_non_owner_gets_404(self):
        """
        Bob tries to open Alice's note.
        get_object_or_404(Note, pk=pk, user=request.user):
          → SELECT WHERE pk=alice_note.pk AND user_id=bob.id
          → Not found → 404

        Why 404 and not 403?
          403: "the resource exists, but access is forbidden" → the attacker knows the id exists
          404: "no such resource"                             → less information for an attack
        """
        alice_note = Note.objects.create(user=self.alice, title='Alice Private')
        self.client.force_login(self.bob)

        response = self.client.get(
            reverse('notes_app:note_detail', args=[alice_note.pk])
        )

        self.assertEqual(response.status_code, 404)

    def test_group_member_can_view_shared_note(self):
        """A group member sees a group note."""
        group = Group.objects.create(name='Team')
        group.user_set.add(self.alice, self.bob)
        note = Note.objects.create(user=self.alice, title='Team Note', group=group)

        self.client.force_login(self.bob)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)
```

### Pattern 3 — POST form: redirect after success

```python
class NoteCreateViewTest(BaseViewTest):

    def setUp(self):
        super().setUp()
        self.url = reverse('notes_app:note_create')

    def test_valid_post_creates_note_and_redirects(self):
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': 'New Note',
            'content': 'Content',
            'priority': 2,
        })

        # Check the redirect after a successful POST
        self.assertEqual(response.status_code, 302)

        # Check that the record exists in the DB
        self.assertTrue(Note.objects.filter(title='New Note', user=self.alice).exists())

    def test_invalid_post_returns_form_with_errors(self):
        """Empty title → the form is invalid → 200 (not a redirect)."""
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': '',    # empty → invalid
            'priority': 1,
        })

        self.assertEqual(response.status_code, 200)
        self.assertFalse(Note.objects.exists())   # the note was not created
```

### Pattern 4 — IDOR via a form: someone else's notebook

```python
class NoteCreateIDORTest(BaseViewTest):

    def test_note_create_with_bobs_notebook_fails(self):
        """
        Alice tries POST /notes/new/ with notebook=bob_notebook.id

        WITHOUT protection in the form: Alice could write a note into Bob's notebook
        WITH protection (NoteForm queryset): the form is invalid → 200, the note is not created
        """
        bob_nb = Notebook.objects.create(user=self.bob, title="Bob's Private")
        self.client.force_login(self.alice)

        response = self.client.post(
            reverse('notes_app:note_create'),
            data={
                'title': 'IDOR Attack',
                'notebook': bob_nb.pk,   # ← someone else's notebook
                'priority': 1,
            }
        )

        # Form invalid → 200 (not a redirect)
        self.assertEqual(response.status_code, 200)
        # The note was not created → IDOR blocked ✓
        self.assertFalse(Note.objects.filter(title='IDOR Attack').exists())
```

### Key assert methods

```python
# ── HTTP statuses ───────────────────────────────────────────────────────────
self.assertEqual(response.status_code, 200)
self.assertEqual(response.status_code, 302)
self.assertEqual(response.status_code, 404)

# ── Redirect ────────────────────────────────────────────────────────────────
self.assertRedirects(
    response,
    reverse('notes_app:note_list'),
    fetch_redirect_response=False,   # doesn't make a second request to the redirect URL
)

# ── Response content ────────────────────────────────────────────────────────
self.assertContains(response, 'Alice Note')          # text is present
self.assertNotContains(response, "Bob's Secret")     # text is absent

# ── Location header (redirect) ──────────────────────────────────────────────
self.assertIn('/accounts/login/', response['Location'])

# ── Template context ────────────────────────────────────────────────────────
self.assertIn('title', response.context['form'].errors)
self.assertEqual(len(response.context['notes']), 3)

# ── Presence in the DB ──────────────────────────────────────────────────────
self.assertTrue(Note.objects.filter(title='New Note').exists())
self.assertEqual(Note.objects.count(), 1)
```

---

## 11 · CONSUMERS

> **WebSocket tests** — how to test `GroupChatConsumer` without a browser.
> `channels.testing.WebsocketCommunicator` simulates a WebSocket connection.

### How WebsocketCommunicator works

```
WebsocketCommunicator
    ↓
ASGI application (asgi.py)
    ↓
ProtocolTypeRouter → WebSocket scope
    ↓
AuthMiddlewareStack (but we set scope['user'] manually in tests)
    ↓
URLRouter → /ws/groups/<pk>/chat/
    ↓
GroupChatConsumer.connect()
              .receive()
              .disconnect()
```

### test_consumers.py

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TransactionTestCase  # not TestCase!

from notes_app.models import ChatMessage
from notes_project.asgi import application   # ← the ASGI app for WebSocket tests


class GroupChatConsumerTest(TransactionTestCase):
    # WHY TransactionTestCase AND NOT TestCase?
    # TestCase wraps each test in a transaction that is rolled back after the test.
    # The async consumer reads the DB from a separate worker thread via database_sync_to_async.
    # That thread doesn't see TestCase's uncommitted transaction → the setUp objects "disappear".
    # TransactionTestCase doesn't wrap in a transaction → the data is visible to all threads.
    # asyncSetUp() is not supported in TransactionTestCase before Django 5.1 — use a sync setUp.

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob is not a member of the group (for the non-member test)

    async def test_authenticated_member_can_connect(self):
        """A logged-in group member can connect to the chat."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice   # AuthMiddlewareStack bypass

        connected, subprotocol = await communicator.connect()
        self.assertTrue(connected)

        await communicator.disconnect()

    async def test_non_member_cannot_connect(self):
        """Bob is not a member of the group → the consumer closes the WS (code 4404)."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.bob   # not a member

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_anonymous_cannot_connect(self):
        """AnonymousUser → the consumer closes (code 4403)."""
        from django.contrib.auth.models import AnonymousUser
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = AnonymousUser()

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_connected_member_receives_history(self):
        """After connect — the consumer sends the message history."""
        # Arrange: add a message to the DB
        await database_sync_to_async(ChatMessage.objects.create)(
            group=self.group,
            author=self.alice,
            content='Hello world'
        )

        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice

        await communicator.connect()

        # Act: receive the first message
        response = await communicator.receive_json_from()

        # Assert: it's the history
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Hello world')
        self.assertEqual(response['author'], 'alice')

        await communicator.disconnect()

    async def test_send_message_saves_to_db_and_broadcasts(self):
        """A message is saved to the DB and sent back."""
        self.group.user_set.add(self.bob)   # bob is in the group too

        comm_alice = WebsocketCommunicator(
            application, f'/ws/groups/{self.group.pk}/chat/'
        )
        comm_bob = WebsocketCommunicator(
            application, f'/ws/groups/{self.group.pk}/chat/'
        )
        comm_alice.scope['user'] = self.alice
        comm_bob.scope['user']   = self.bob

        await comm_alice.connect()
        await comm_bob.connect()

        # Alice sends a message
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob receives the broadcast
        bob_msg = await comm_bob.receive_json_from()
        self.assertEqual(bob_msg['type'], 'message')
        self.assertEqual(bob_msg['content'], 'Hello Bob!')
        self.assertEqual(bob_msg['author'], 'alice')

        # Check that it was saved to the DB
        count = await database_sync_to_async(ChatMessage.objects.count)()
        self.assertEqual(count, 1)

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

---

## 12 · SELENIUM

> The Django Test Client doesn't see JS and CSS. Selenium sees everything the user sees.

### What Selenium tests that the Test Client can't

```
Test Client (integration):                Selenium (E2E):
  ✓ HTTP statuses                          ✓ JavaScript behavior
  ✓ HTML content (assertContains)          ✓ CSS visibility of elements
  ✓ Redirect                               ✓ Form submit via the button
  ✓ Template context                       ✓ WebSocket connection in the browser
  ✗ JavaScript events                      ✓ Bootstrap dropdown
  ✗ CSS display:none                       ✓ Real navigation between pages
  ✗ form.submit() via the button           ✓ Ajax requests
  ✗ WebSocket in the browser               ✗ Very slow (~10s/test)
```

### Selenium architecture in Docker

```
[test runner — web container]
  │
  │ HTTP  →  StaticLiveServerTestCase  →  Django live server :PORT
  │
  │ WebDriver protocol  →  http://selenium:4444/wd/hub
  │                            │
  │                     [selenium container]
  │                       standalone-chrome
  │                            │
  │                     Chrome → GET http://web:PORT/
  │
  │ ← DOM / assertions
```

**The key problem without Docker:** `localhost` in the Chrome container ≠ `localhost` in the test runner.
**The solution:** bind to `0.0.0.0`, Chrome connects via `http://web:PORT`.

### `_DockerLiveServerMixin` — a universal solution

```python
# notes_app/tests/test_selenium.py
import os
import unittest

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

from django.contrib.auth.models import User
from django.contrib.staticfiles.testing import StaticLiveServerTestCase


class _DockerLiveServerMixin:
    """
    Adapts StaticLiveServerTestCase to work with Selenium in Docker.

    Problem: LiveServerTestCase binds to 127.0.0.1 by default.
    In Docker: the selenium container can't reach 127.0.0.1 of the web container.

    Solution:
      1. host = '0.0.0.0' → bind to all interfaces
      2. live_server_url: replace '0.0.0.0' with 'web' (Docker DNS)
         http://0.0.0.0:PORT → http://web:PORT

    WEB_HOST env var: docker-compose.yml → web.environment.WEB_HOST = "web"
    Without Docker (locally): WEB_HOST is not set → the url stays localhost
    """
    host = '0.0.0.0'

    @property
    def live_server_url(self):
        url = super().live_server_url   # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')
        if web_host:
            return url.replace('0.0.0.0', web_host)   # http://web:PORT
        return url


def _make_driver():
    """
    Returns a Chrome WebDriver depending on the environment:
      - SELENIUM_REMOTE_URL is set → Remote WebDriver (Docker selenium container)
      - Not set → local Chrome (headless)
    """
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = 'http://selenium:4444/wd/hub' (from docker-compose.yml)

    options = webdriver.ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    # --disable-dev-shm-usage: Chrome in Docker uses /tmp instead of /dev/shm
    # (by default /dev/shm in Docker = 64MB → Chrome crashes)

    if remote_url:
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        options.add_argument('--headless')   # locally: no GUI window
        return webdriver.Chrome(options=options)
```

### Session Cookie Trick — logging in without the form

```python
def _login_via_cookie(self, user):
    """
    Log in without filling in the login form in the browser.
    Much faster and more reliable than filling in the form.

    Method:
    1. The Test Client (server side) creates a session in the test DB
    2. We copy the sessionid cookie into Selenium's Chrome
    3. Chrome sends this cookie → Django considers Chrome logged in

    Why:
    - The login form may have CSRF, JS validation, a reCAPTCHA
    - The session cookie trick is always reliable
    - Faster: 1 HTTP request instead of a form
    """
    self.client.force_login(user)                     # ← server: session in the DB
    session_cookie = self.client.cookies['sessionid'] # ← extract the cookie value

    # Chrome must be on our domain before add_cookie
    self.driver.get(f'{self.live_server_url}/')        # ← any URL of the site

    self.driver.add_cookie({
        'name':  'sessionid',
        'value': session_cookie.value,
        'path':  '/',
    })
    # Now Chrome is logged in as user ✓
```

### A full selenium test

```python
@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(_DockerLiveServerMixin, StaticLiveServerTestCase):
    """E2E test: login form → dashboard."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)   # wait up to 5 sec for an element

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def setUp(self):
        self.user = User.objects.create_user(
            username='alice', password='testpass123'
        )

    def test_login_form_and_redirect(self):
        """Filling in the login form → redirect to /notes/."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        # Fill in the form
        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # After a successful login → redirect to /notes/
        WebDriverWait(self.driver, 5).until(
            EC.url_contains('/notes/')
        )
        self.assertIn('/notes/', self.driver.current_url)

    def test_dashboard_shows_username(self):
        """After login the navbar shows the username."""
        self._login_via_cookie(self.user)
        self.driver.get(f'{self.live_server_url}/notes/')

        # Look for the username in the navbar
        page_text = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertIn('alice', page_text)

    def test_invalid_login_shows_error(self):
        """Wrong password → the form with an error."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('wrongpassword')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # We stayed on the login page (no redirect)
        self.assertIn('/accounts/login/', self.driver.current_url)

        # The error message
        body = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertTrue(
            'Невірний' in body or 'Please enter' in body or 'wrong' in body.lower()
        )
```

### `@unittest.skipUnless` — graceful skip

```python
@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumTests(StaticLiveServerTestCase):
    ...

# If selenium is not installed (or SELENIUM_REMOTE_URL is unavailable):
# → the tests are marked 's' (skipped), they do NOT fail as 'E' (error)

# Output:
# ...........ssssss
# Ran 129 tests in 90.2s
# OK (skipped=6)     ← a green result even without Selenium!
```

---

## Step 0 — Running

```bash
# ─── Start the stack ────────────────────────────────────────────────────────
docker compose up -d              # bring up all services in the background

# ─── Unit + Integration + Consumer tests (via a new container) ──────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# ─── Selenium E2E tests (EXEC, not RUN!) ────────────────────────────────────
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec → runs inside the RUNNING container that has the DNS alias "web"
# run  → a NEW container without the "web" alias → Selenium can't find the Django server!

# ─── All tests at once ────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests -v 2
# Selenium is automatically skipped if SELENIUM_REMOTE_URL is unavailable

# ─── A specific class ─────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# ─── A specific test ──────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_services.NoteServiceTest.test_create_note_sets_correct_user -v 2

# ─── Stop at the first failure ────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests --failfast

# ─── Fast re-run (keep the DB between runs) ─────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# Doesn't re-create the test DB → faster with many migrations

# ─── Coverage ─────────────────────────────────────────────────────────────────
docker compose run --rm web sh -c "
  coverage run manage.py test \
    notes_app.tests.test_models notes_app.tests.test_services \
    notes_app.tests.test_forms notes_app.tests.test_views \
    notes_app.tests.test_consumers &&
  coverage report --show-missing
"
```

---

## Step 1 — tests/ structure

```
notes_app/
├── models.py
├── views.py
├── services.py
├── selectors.py
├── consumers.py
└── tests/
    ├── __init__.py          ← REQUIRED! Empty. Makes tests/ a Python package.
    │                          Without it: Django won't find the tests → "Found 0 test(s)"
    ├── test_models.py       ← Unit: constraints, defaults, SET_NULL, __str__
    ├── test_services.py     ← Unit: business logic, security, transactions
    ├── test_forms.py        ← Unit: validation, normalization, queryset filtering
    ├── test_views.py        ← Integration: HTTP, ownership, redirects, IDOR
    ├── test_consumers.py    ← Consumer: WebSocket lifecycle, auth, broadcast
    └── test_selenium.py     ← E2E: browser, forms, navigation, DOM
```

**Why a package and not a single `tests.py`?**

```
tests.py → 3000+ lines in a large project, hard to navigate

tests/ package:
  test_models.py   ← models only (~150 lines)
  test_services.py ← services only (~300 lines)
  test_forms.py    ← forms only (~150 lines)
  test_views.py    ← integration (~400 lines)
  test_consumers.py ← WebSocket (~150 lines)
  test_selenium.py ← E2E (~200 lines)

Benefits:
  → Run separately: manage.py test notes_app.tests.test_services
  → Each file = one layer of the system → easy to find a test
  → CI can run different files in parallel
```

---

## Step 8 — GitHub Actions CI

### The full workflow for notes_chat_app

```yaml
# .github/workflows/ci.yml
name: CI — Test Suite

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    name: Unit + Integration + Consumer tests
    runs-on: ubuntu-latest

    services:
      # PostgreSQL in GitHub Actions (a separate container)
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user -d test_notes_db"
          --health-interval 5s
          --health-retries 5

      # Redis for the channel layer
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s

    env:
      DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:    redis://localhost:6379/0
      SECRET_KEY:   ci-secret-key-not-for-production
      DEBUG:        "False"
      ALLOWED_HOSTS: localhost,127.0.0.1

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run Unit + Integration tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2

  selenium-e2e:
    name: Selenium E2E tests
    runs-on: ubuntu-latest
    needs: test          # ← runs AFTER the unit tests succeed

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user"
          --health-interval 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ['6379:6379']

      selenium:
        image: selenium/standalone-chrome:latest
        ports: ['4444:4444']
        options: --shm-size=2g   # Chrome needs shared memory

    env:
      DATABASE_URL:        postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:           redis://localhost:6379/0
      SECRET_KEY:          ci-secret-key
      DEBUG:               "False"
      ALLOWED_HOSTS:       localhost,127.0.0.1
      SELENIUM_REMOTE_URL: http://localhost:4444/wd/hub
      WEB_HOST:            localhost

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run migrations
        run: python manage.py migrate --noinput

      - name: Run Selenium E2E tests
        run: python manage.py test notes_app.tests.test_selenium -v 2

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: selenium-screenshots
          path: /tmp/selenium-*.png
          # If a test fails and saves a screenshot → we'll see it in Artifacts
```

### What `needs` and `if: failure()` mean

```yaml
selenium-e2e:
  needs: test
  # ↑ Runs only if the 'test' job succeeded.
  #   If the unit tests failed → Selenium doesn't run.
  #   The logic: there's no point testing the browser if the unit tests are red.

- name: Upload screenshots on failure
  if: failure()
  # ↑ Runs ONLY if a previous step failed.
  #   A Selenium test fails → save a screenshot for diagnostics.
  #   Available in GitHub Actions → Artifacts → selenium-screenshots.zip
```

---

## File structure

```
notes_chat_app/
│
├── .github/
│   └── workflows/
│       └── ci.yml              ← GitHub Actions: test + selenium jobs
│
├── notes_app/
│   ├── models.py               ← Note, Notebook, Tag, ChatMessage, ...
│   ├── services.py             ← Business logic (we test it directly)
│   ├── selectors.py            ← Read-only queries (Q-filter)
│   ├── forms.py                ← NoteForm, TagForm, GroupCreateForm, ...
│   ├── views.py                ← HTTP layer (@login_required + IDOR protection)
│   ├── consumers.py            ← GroupChatConsumer (WebSocket)
│   └── tests/
│       ├── __init__.py         ← ★ REQUIRED! Empty.
│       ├── test_models.py      ← Unit: constraints, SET_NULL, validators
│       ├── test_services.py    ← Unit: create/update/delete, security
│       ├── test_forms.py       ← Unit: validation, queryset security
│       ├── test_views.py       ← Integration: HTTP, ownership, redirects
│       ├── test_consumers.py   ← Consumer: WebSocket auth, broadcast
│       └── test_selenium.py    ← E2E: Chrome via Docker Remote WebDriver
│
└── docker-compose.yml          ← selenium service on ports 4444 and 7900 (VNC)
```

---

## Summary: what to look for and where

| Concept | Where in the code |
|-----------|-----------|
| **TestCase + setUp** | `test_models.py`, `test_services.py` — `class BaseServiceTest` |
| **ROLLBACK between tests** | Automatic — Django TestCase transactions |
| **AAA pattern** | Any test: `# ARRANGE / ACT / ASSERT` comments |
| **full_clean() for validators** | `test_models.py` — `test_priority_above_4_raises_validation_error` |
| **refresh_from_db()** | `test_models.py` — `test_note_group_becomes_null_when_group_deleted` |
| **SET_NULL test** | `test_models.py` — protection against CASCADE |
| **Persistence test** | `test_services.py` — `test_toggle_pin_note_persisted_in_db` |
| **Security test** | `test_services.py` — `test_create_note_ignores_other_users_tags` |
| **Transactional invariant** | `test_services.py` — `test_create_notebook_default_unsets_previous_default` |
| **Form queryset security** | `test_forms.py` — `test_notebook_queryset_excludes_other_user_notebooks` |
| **force_login vs login** | `test_views.py` — `self.client.force_login(self.alice)` |
| **404 not 403** | `test_views.py` — `test_non_owner_gets_404` + explanation |
| **WebSocket tests** | `test_consumers.py` — `WebsocketCommunicator` |
| **database_sync_to_async** | `test_consumers.py` — `await database_sync_to_async(...)()` |
| **_DockerLiveServerMixin** | `test_selenium.py` — `host = '0.0.0.0'`, `live_server_url` |
| **Session cookie trick** | `test_selenium.py` — `_login_via_cookie()` |
| **@skipUnless** | `test_selenium.py` — graceful skip without geckodriver |
| **CI/CD workflow** | `.github/workflows/ci.yml` — `needs:`, `services:`, `if: failure()` |

---

## Self-check checklist

- [ ] `tests/__init__.py` exists (an empty file — without it Django won't find the tests)
- [ ] Every test method starts with `test_`
- [ ] A child class's `setUp()` that overrides the parent's calls `super().setUp()`
- [ ] `full_clean()` is used for validators, not `.objects.create()`
- [ ] After `delete()` of a related object → `refresh_from_db()` before checking
- [ ] Integration tests use `force_login()`, not `login()`
- [ ] WebSocket tests: `await communicator.disconnect()` in every test
- [ ] Selenium tests have `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)`
- [ ] Selenium: `exec`, not `run`, for running in Docker
- [ ] `manage.py test` returns `OK` (even with `skipped=6`)

---

## Next

Next step: [07 — Async and WebSocket](07_async.md) — ASGI, Django Channels, GroupChatConsumer, channel layer.

Documentation modules:
- [README_7.md](README_7.md) — Testing: a detailed tutorial with a CI/CD pipeline (crispy_notes_project)
- [README_9.md](README_9.md) — Production Stack: Docker Selenium Remote WebDriver details
- [docs/08_testing_and_quality/](../08_testing_and_quality/) — theory materials: pytest, Selenium, CI/CD
