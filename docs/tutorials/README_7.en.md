# CrispyNotes — Django Testing from A to Z

> This tutorial walks you through the **full testing stack of a Django application**:
> unit tests → services → forms → integration (views) → E2E (Selenium).
>
> The project is **the same CrispyNotes** from the previous lessons (crispy forms + auth + groups).
> In this lesson we write tests for an application that is already finished.
> You will see how each level of tests protects a different layer of the system.
>
> **Result:** 129 tests — 123 pass + 6 Selenium

---

## Contents

**Theory** _(read before the code)_
- [01 · WHY TESTS — an alarm system instead of manual checking](#01--why-tests)
- [02 · THE PYRAMID — unit vs integration vs E2E](#02--the-testing-pyramid)
- [03 · DJANGO TESTCASE — how it works under the hood](#03--django-testcase)
- [04 · THE TEST DATABASE — isolation and rollback](#04--the-test-database)
- [05 · THE AAA PATTERN — the structure of every test](#05--the-aaa-pattern)
- [06 · READING THE OUTPUT — PASSED / FAILED / ERROR](#06--reading-the-output)

**What we test and why**
- [07 · MODELS — constraints, defaults, SET_NULL](#07--testing-models)
- [08 · SERVICES — business logic and security](#08--testing-services)
- [09 · FORMS — validation and queryset filtering](#09--testing-forms)
- [10 · DJANGO TEST CLIENT — integration tests](#10--django-test-client)
- [11 · SELENIUM — tests through the browser](#11--selenium)

**Step-by-step implementation**
1. [Step 0 — Running the project](#step-0--running-the-project)
2. [Step 1 — Structure of the tests/ package](#step-1--structure-of-tests)
3. [Step 2 — test_models.py](#step-2--test_modelspy)
4. [Step 3 — test_services.py](#step-3--test_servicespy)
5. [Step 4 — test_forms.py](#step-4--test_formspy)
6. [Step 5 — test_views.py](#step-5--test_viewspy)
7. [Step 6 — test_selenium.py](#step-6--test_seleniumpy)
8. [Step 7 — Running and understanding the results](#step-7--running-the-tests)
9. [Step 8 — GitHub Actions CI](#step-8--github-actions-ci)
10. [File structure](#step-1--structure-of-tests)

---

## 01 · WHY TESTS

> **The main question:** How do you know that nothing broke after your changes?
>
> The answer without tests: run it manually, click around the site, hope for the best.
> The answer with tests: run one command and see everything in 30 seconds.

### Analogy — a fire alarm

A house without an alarm: you discover the fire when it's already burning.
A house with an alarm: you learn about the spark BEFORE everything goes up in flames.

**Tests = your code's alarm system.** They check "is everything still correct" on every change.

```
WITHOUT TESTS                           WITH TESTS
──────────────────────────────────────  ──────────────────────────────────────
You write a new feature                 You write a new feature
You manually click through 10+ pages   You run: manage.py test
"Looks ok"                              FAIL: test_note_visible_only_to_owner
git push → deploy                       You see EXACTLY what broke
A week later: "Bug in production!"      You fix it BEFORE deploying
You turn detective — hunting the cause git push → deploy → all green
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
        user=user,    # ← forgot the Q-filter for groups!
        is_archived=archived,
    )
```

**Without tests:** All group notes disappear for all users.
Customers discover it a week after the production deployment.

**With tests:** `test_selectors.py` immediately reports:
```
FAIL: test_group_notes_visible_to_members
AssertionError: <Note: Team meeting> not found in queryset for bob
```
You fix it in 2 minutes before committing.

### What else tests give you

| Benefit | Explanation |
|----------|-----------|
| **Documentation** | `test_create_notebook_default_unsets_previous_default` explains the invariant better than a comment |
| **Fearless refactoring** | You changed the implementation → the tests confirm the behavior is the same |
| **Finding edge cases** | While writing a test you think: "what if it's None? what if it's empty?" |
| **Protection against regressions** | Bug fixed + test written = the bug never comes back |
| **Security checks** | `test_notebook_queryset_excludes_other_user_notebooks` — IDOR is impossible |

---

## 02 · THE TESTING PYRAMID

> **Not all tests are equal.** Different levels have different costs and speeds.

```
              ╱╲
             ╱E2E╲          Selenium, Playwright
            ╱──────╲        Real browser, full scenario
           ╱ Integr. ╲      Slow (seconds/test), brittle
          ╱────────────╲    Django Test Client: requests → DB → response
         ╱     Unit      ╲  Medium (100ms/test)
        ╱──────────────────╲ pytest/TestCase: function → result
       ╱────────────────────╲ Fast (1-10ms/test), reliable

      70% Unit | 20% Integration | 10% E2E
```

### What we test at each level

**Unit tests** (this lesson):
```python
# We test a function in isolation from HTTP
def test_create_notebook_default_unsets_previous_default(self):
    old = services.create_notebook(user=alice, title='Old', is_default=True)
    new = services.create_notebook(user=alice, title='New', is_default=True)
    old.refresh_from_db()
    self.assertFalse(old.is_default)  # 1 is_default per user — an invariant
```

**Integration tests** (the next level):
```python
# We test over HTTP — view + DB + response
def test_note_list_shows_only_user_notes(self):
    self.client.login(username='alice', password='pass')
    response = self.client.get('/notes/')
    self.assertEqual(response.status_code, 200)
    self.assertNotContains(response, "Bob's Secret Note")
```

**E2E tests** (Selenium):
```python
# We test through a real browser — clicks, forms, navigation
def test_user_can_create_and_share_note(self):
    self.browser.get('/accounts/login/')
    self.browser.find_element(By.NAME, 'username').send_keys('alice')
    # ...
```

### Where our tests live

| Level | File | What it tests | Count |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Model: constraints, __str__, defaults | 23 |
| Unit | `tests/test_services.py` | Business logic: create, update, delete, security | 36 |
| Unit | `tests/test_forms.py` | Validation, normalization, queryset filtering | 23 |
| Integration | `tests/test_views.py` | Views via self.client: HTTP codes, ownership, redirects | 41 |
| E2E | `tests/test_selenium.py` | Browser: forms, navigation, DOM (skipped without geckodriver) | 6 |

---

## 03 · DJANGO TESTCASE

> `django.test.TestCase` is `unittest.TestCase` + Django magic.

### What makes Django TestCase different

```python
import unittest
from django.test import TestCase

# unittest.TestCase — basic, no DB
class PureUnitTest(unittest.TestCase):
    def test_math(self):
        assert 2 + 2 == 4   # OK, no DB

# django.test.TestCase — with the full Django stack
class DjangoTest(TestCase):
    def test_with_db(self):
        user = User.objects.create_user('alice')  # ← requires the test DB
        self.assertEqual(user.username, 'alice')
```

### What Django TestCase gives you automatically

```
┌─────────────────────────────────────────────────────────────────┐
│  Before ALL tests of the class:                                 │
│    → Creates the test DB in memory                              │
│    → Applies all migrations                                     │
│                                                                 │
│  Before EACH test:                                              │
│    → Opens a transaction                                        │
│    → Calls setUp()                                              │
│                                                                 │
│    ┌─── THE TEST RUNS ─────────────────────────────────────┐   │
│    │  User.objects.create(...)  ← records in the test DB   │   │
│    │  Note.objects.create(...)  ← isolated from the real one│  │
│    └───────────────────────────────────────────────────────┘   │
│                                                                 │
│  After EACH test:                                               │
│    → ROLLBACK of the transaction (all records disappear!)       │
│    → Calls tearDown()                                           │
│                                                                 │
│  After ALL tests:                                               │
│    → Deletes the test DB                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Why rollback is a good thing

```python
class MyTest(TestCase):
    def test_first(self):
        User.objects.create_user('alice')    # ← alice EXISTS
        self.assertEqual(User.objects.count(), 1)
        # After the test → ROLLBACK → alice is gone

    def test_second(self):
        # alice does NOT exist — every test starts from a clean state
        self.assertEqual(User.objects.count(), 0)  # ← 0, not 1!
```

**Without rollback** tests would affect each other:
- test 1 creates alice → test 2 sees alice → results are unpredictable
- The order in which tests run would affect the result

**With rollback** every test is isolated → the result does not depend on the order.

### setUp — preparation before each test

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

---

## 04 · THE TEST DATABASE

> **The most important rule:** Tests never touch your working DB.

### How Django creates the test DB

```bash
$ python manage.py test hello_app.tests

Creating test database for alias 'default' ...
#  ↑ Django creates test_<db_name> or an in-memory one (SQLite)
#    All the data is there — not in your db.sqlite3!

Found 82 test(s).
...

Destroying test database for alias 'default' ...
#  ↑ The test DB is deleted after completion
```

### Three kinds of isolation at once

```
1. ISOLATION FROM THE REAL DB:
   db.sqlite3 (your working one) ≠ test DB (separate, temporary)
   Tests cannot break your real data.

2. ISOLATION BETWEEN TESTS:
   Each test — its own transaction → rollback.
   Test A does not see Test B's data.

3. ISOLATION FROM EXTERNAL SYSTEMS:
   Email: EMAIL_BACKEND = console (not actually sent)
   Files: not changed in production
   API: needs a mock (unittest.mock.patch)
```

---

## 05 · THE AAA PATTERN

> Every test has three distinct parts. This is the standard in all languages.

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: preparing the state ──────────────────────────────────────
    # What does the test need? We create the minimal required state.
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: we perform what we are testing ──────────────────────────────
    # One call — one action. What exactly are we testing? Only this.
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: we check the result ──────────────────────────────────────
    # What must be true after Act? We check specifically.
    note_tags = list(note.tags.all())
    self.assertIn(tag1, note_tags)
    self.assertIn(tag2, note_tags)
```

### Rules of a good test

| Rule | Explanation |
|---------|-----------|
| **One test — one behavior** | `test_create_note_sets_user` ≠ `test_create_note_saves_to_db` |
| **Name = specification** | `test_add_user_to_group_duplicate_returns_false` — the name explains everything |
| **Independence** | A test does not depend on the order or on other tests |
| **Speed** | A unit test < 50ms. If it's slow — check whether you're making unnecessary queries |
| **Determinism** | The same test under the same conditions = the same result |

---

## 06 · READING THE OUTPUT

> Understanding what pytest / manage.py test shows is a key skill.

### A successful run

```bash
$ python manage.py test hello_app.tests -v 2

Creating test database for alias 'default' ...
Found 82 test(s).

test_str_returns_hash_name (hello_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
test_create_note_assigns_tags (...) ... ok
...

----------------------------------------------------------------------
Ran 82 tests in 76.8s

OK   ← ALL GREEN! You can git push.
```

### A failed test

```bash
$ python manage.py test hello_app.tests

FAIL: test_create_notebook_default_unsets_previous_default
----------------------------------------------------------------------
Traceback (most recent call last):
  File "tests/test_services.py", line 179, in test_create_notebook_...
    self.assertFalse(old_default.is_default)
AssertionError: True is not false

----------------------------------------------------------------------
Ran 82 tests in 77.1s

FAILED (failures=1)
```

**How to read a failed test:**

```
FAIL: test_create_notebook_default_unsets_previous_default
 ↑ The test name → you immediately understand WHAT broke

File "tests/test_services.py", line 179
 ↑ Where exactly in the file

self.assertFalse(old_default.is_default)
AssertionError: True is not false
 ↑ We expected False, got True
   → The old default was NOT reset
   → The bug is in services.create_notebook()
```

### Result types

| Symbol | Means | Cause |
|--------|---------|---------|
| `.` | PASSED | The test passed |
| `F` | FAILED | An `assert` failed — wrong result |
| `E` | ERROR | An exception in the test (not AssertionError) — for example, AttributeError |
| `s` | SKIPPED | `@unittest.skip` — the test was skipped on purpose |
| `x` | XFAIL | Expected failure (`@unittest.expectedFailure`) |

### Verbosity levels (-v 0/1/2)

```bash
# -v 0: summary only
python manage.py test hello_app.tests
# OK or FAILED (failures=3)

# -v 1 (default): progress dots
python manage.py test hello_app.tests -v 1
# ...............F........ (82 tests)

# -v 2: each test separately
python manage.py test hello_app.tests -v 2
# test_str_returns_hash_name ... ok
# test_unique_together... ... ok
```

### Stopping at the first failure

```bash
python manage.py test hello_app.tests --failfast
# Stops immediately at the first FAIL
# Useful when there are many errors
```

---

## 07 · TESTING MODELS

> **Question:** Why test models? They're just fields and relations.

**Answer:** A model contains business rules. If they are broken, the application silently behaves incorrectly.

### What lives in the model (and what can break)

```
Note model
  ├── priority: validators=[MinValueValidator(1), MaxValueValidator(4)]
  │     If someone removes the validators → the form will accept priority=99
  │     → Displaying the priority will break (KeyError in PRIORITY_CHOICES)
  │
  ├── group: ForeignKey(Group, on_delete=SET_NULL)
  │     If you change it to CASCADE → deleting a group will delete all its notes!
  │     → Users will lose data
  │
  ├── is_pinned: BooleanField(default=False)
  │     If the default becomes True → all new notes will become pinned
  │     → Sorting will break
  │
  └── __str__: pin + title
        If the format changes → Django Admin and logs display it incorrectly
```

### Structure of test_models.py

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase
from hello_app.models import Note, Notebook, ShopItem, ShoppingList, Tag


class TagModelTest(TestCase):
    def setUp(self):
        self.user  = User.objects.create_user('alice', password='pass123')
        self.user2 = User.objects.create_user('bob',   password='pass123')

    # 1. __str__ method
    def test_str_returns_hash_name(self):
        tag = Tag.objects.create(user=self.user, name='python')
        self.assertEqual(str(tag), '#python')

    # 2. unique_together constraint
    def test_unique_together_same_user_same_name_raises(self):
        Tag.objects.create(user=self.user, name='work')
        with self.assertRaises(IntegrityError):
            Tag.objects.create(user=self.user, name='work')  # ← duplicate → error

    # 3. Different users — isolation
    def test_unique_together_different_users_same_name_ok(self):
        Tag.objects.create(user=self.user,  name='work')  # Alice's 'work'
        Tag.objects.create(user=self.user2, name='work')  # Bob's 'work' — OK
        self.assertEqual(Tag.objects.count(), 2)
```

### How to test validators via full_clean()

```python
# IMPORTANT: validators do not run on .save() or .objects.create()!
# They run only via full_clean() or a ModelForm.

# WRONG (validators won't be checked):
note = Note.objects.create(user=user, title='Test', priority=5)
# ← Django will simply save priority=5! (validators ignored)
# ← A CheckConstraint in the DB may fire, but not validators

# RIGHT — via full_clean():
note = Note(user=user, title='Test', priority=5)  # ← we do NOT save right away
note.full_clean()   # ← this is where validators run → ValidationError

# In a test:
def test_priority_above_4_raises_validation_error(self):
    note = Note(user=self.user, title='Test', priority=5)
    with self.assertRaises(ValidationError) as ctx:
        note.full_clean()
    self.assertIn('priority', ctx.exception.message_dict)
    #              ↑ we check that the error is specifically in the priority field
```

### Testing SET_NULL — protection against CASCADE

```python
def test_note_group_becomes_null_when_group_deleted(self):
    """
    We check that Note.group = ForeignKey(Group, on_delete=SET_NULL)
    works correctly: deleting the group → the note becomes personal.

    If someone changes it to CASCADE → this test will FAIL and show:
    DoesNotExist: Note matching query does not exist.
    → we find out BEFORE deploying that the change broke users' data.
    """
    group = Group.objects.create(name='Family')
    note  = Note.objects.create(user=self.user, title='Family note', group=group)

    group.delete()               # delete the group

    note.refresh_from_db()       # ← MANDATORY! read the fresh state from the DB
    self.assertIsNone(note.group)# the note survived, group = NULL
```

> **Why `refresh_from_db()`?** After `group.delete()` the `note` object in memory
> still holds the old reference. `refresh_from_db()` re-reads it from the DB.

---

## 08 · TESTING SERVICES

> **Services are the best layer for unit tests.** No HTTP, no templates, just logic.

### Why services are easy to test

```
VIEWS (HTTP layer):
  Receives a request → parses the form → calls a service → renders a template
  Depends on: HTTP, session, forms, templates
  Hard to test in isolation

SERVICES (business logic):
  create_note(user=alice, title='Test', tag_ids=[1,2])
  Takes Python objects → returns a result → saves to the DB
  No dependencies! We test directly:
    result = services.create_note(user=alice, title='Test')
    self.assertEqual(result.title, 'Test')
```

### Two kinds of checks in service tests

```python
# TYPE 1: checking the RETURNED OBJECT
def test_create_note_returns_note_object(self):
    note = services.create_note(user=self.alice, title='Test')
    self.assertIsInstance(note, Note)   # ← we check what was returned

# TYPE 2: checking the DB STATE (persistence test)
def test_create_note_saves_to_database(self):
    services.create_note(user=self.alice, title='Test')
    self.assertEqual(Note.objects.count(), 1)   # ← we check that it was saved

# WHY BOTH?
# create_note() could return an object but not save it (.save() forgotten)
# Or save it but return None
# The two tests together cover both scenarios
```

### Security test: Mass Assignment via tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Attack: an attacker sends a POST with a tag_id that belongs to Bob.
    POST /notes/new/ → tag_ids=[bob_secret_tag_id]

    WITHOUT PROTECTION (vulnerable):
        note.tags.set(Tag.objects.filter(id__in=tag_ids))
        → Bob's tag gets attached to Alice's note
        → Alice sees Bob's secret tag in her note

    WITH PROTECTION (our code):
        note.tags.set(Tag.objects.filter(id__in=tag_ids, user=user))
        → Filtering by user blocks other people's tags
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)   # ← the other user's tag was not attached
```

### Testing transactional logic

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Business invariant: a user can have only ONE default notebook.

    The code in services.py:
        with transaction.atomic():
            if is_default:
                Notebook.objects.filter(user=user, is_default=True)
                                .update(is_default=False)   ← RESET the old one
            return Notebook.objects.create(..., is_default=is_default)  ← CREATE the new one

    If you remove the line with .update() → two notebooks with is_default=True
    → the note form picks the "first" one → unpredictable behavior

    This test will catch it IMMEDIATELY.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)

    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()       # ← read the fresh state of the old notebook
    self.assertFalse(old.is_default)  # the old one is reset
    self.assertTrue(new.is_default)   # the new one is set
```

### Testing isolation between users

```python
def test_create_notebook_default_only_affects_same_user(self):
    """
    A critical test for a multi-user system.

    BUGGY CODE (doesn't filter by user):
        Notebook.objects.filter(is_default=True).update(is_default=False)
        ↑ Resets the default FOR ALL USERS! Bob will lose his default.

    CORRECT CODE:
        Notebook.objects.filter(user=user, is_default=True).update(...)
        ↑ Resets it only for the specific user. Bob is safe.
    """
    bob_default = services.create_notebook(user=self.bob,   title='Bob Default',   is_default=True)
    alice_def   = services.create_notebook(user=self.alice, title='Alice Default',  is_default=True)

    bob_default.refresh_from_db()
    self.assertTrue(bob_default.is_default)  # Bob is not affected!
```

### Testing the (True/False, message) pattern

```python
def test_add_user_to_group_duplicate_returns_false(self):
    """
    add_user_to_group() returns (bool, message).
    On a duplicate → (False, 'bob вже є членом').

    Why check twice? The function could return (True, '') but not add the user,
    or add the user but return (False, ''). We check both aspects.
    """
    group = services.create_group(name='Team', creator=self.alice)
    services.add_user_to_group(group, username='bob')  # 1st time — success

    success, message = services.add_user_to_group(group, username='bob')  # 2nd

    self.assertFalse(success)                    # ← the function returned False
    self.assertIn('bob', message)                # ← the message contains the name
    self.assertEqual(group.user_set.count(), 2)  # ← the DB didn't change (alice + bob, not 3)
```

---

## 09 · TESTING FORMS

> **A form in Django is not just HTML.** It is validation, normalization and a security barrier.

### How to test a form without HTTP

```python
# A form can be tested directly, without client.post():

form = TagForm(data={'name': 'Python', 'color': '#ff0000'})
form.is_valid()              # True or False — we check it
form.cleaned_data['name']   # 'python' — the normalized value
form.errors                  # {'name': ['...']} — errors per field
```

### Three categories of form tests

**1. Normalization (`clean_*` methods)**

```python
def test_clean_name_lowercases(self):
    """
    TagForm.clean_name(): 'Python' → 'python'

    WHY: without normalization a user could create:
        'python', 'Python', 'PYTHON' — three different tags!
    Unique_together considers them different.
    clean_name() normalizes before saving.
    """
    form = TagForm(data={'name': 'Python', 'color': '#ff0000'})
    self.assertTrue(form.is_valid())
    self.assertEqual(form.cleaned_data['name'], 'python')  # normalized

def test_clean_name_strips_whitespace(self):
    """'  work  ' → 'work' (leading and trailing spaces are removed)"""
    form = TagForm(data={'name': '  work  ', 'color': '#ff0000'})
    self.assertTrue(form.is_valid())
    self.assertEqual(form.cleaned_data['name'], 'work')
```

**2. Security — queryset filtering (the most important!)**

```python
# The vulnerability WITHOUT filtering:
#   NoteForm().fields['notebook'].queryset = Notebook.objects.all()
#   Alice sees in the dropdown: "Alice's Notes" and "Bob's Private Notes"!
#   Alice picks Bob's Private → Alice's note is written to Bob's notebook
#   Bob sees someone else's notes in his notebook → DATA LEAK

# The protection in our code:
#   NoteForm(user=alice).fields['notebook'].queryset = Notebook.objects.filter(user=alice)
#   Alice sees only her own notebooks → SAFE

def test_notebook_queryset_excludes_other_user_notebooks(self):
    """
    THE MAIN security test — IDOR through the form is impossible.
    """
    form = NoteForm(user=self.alice)
    queryset = form.fields['notebook'].queryset
    self.assertNotIn(self.bob_notebook, queryset)  # Bob's notebook is not visible!
```

**3. A safe fallback without user=**

```python
def test_form_without_user_has_empty_querysets(self):
    """
    If the form is created without user= (a developer mistake):
        form = NoteForm(data=request.POST)  ← forgot user=request.user

    DANGEROUS: queryset = Notebook.objects.all() → all notebooks are visible
    SAFE (our code): queryset = Notebook.objects.none() → an empty list

    It's better to show the user an empty dropdown than to leak all the data.
    """
    form = NoteForm()  # user not passed
    self.assertFalse(form.fields['notebook'].queryset.exists())
    self.assertFalse(form.fields['tags'].queryset.exists())
```

### Table: what we check in each form

| Form | What we test |
|-------|-------------|
| `TagForm` | `clean_name`: lowercase + strip, empty name → error |
| `NoteForm` | the queryset for notebook/tags/group is filtered by user |
| `NoteForm` | without user= → empty querysets (safe fallback) |
| `NoteForm` | empty title → invalid, priority 1-4 → valid, 99 → invalid |
| `GroupCreateForm` | `clean_name`: duplicate → ValidationError, strip whitespace |

---

## 10 · DJANGO TEST CLIENT

> **Question:** What does an integration test check that a unit test CANNOT?

### The difference between a unit and an integration test

```python
# UNIT TEST (test_services.py) — a direct Python call, no HTTP:
note = services.create_note(user=alice, title='Test')
self.assertEqual(note.user, alice)
# Checks: business logic in isolation

# INTEGRATION TEST (test_views.py) — over HTTP:
self.client.force_login(alice)
response = self.client.get(reverse('hello_app:note_list'))
self.assertEqual(response.status_code, 200)
# Checks: URL routing → @login_required → view → selectors → DB → HTML response
```

### What an integration test catches that a unit test will NOT

| What it checks | Unit (services) | Integration (views) |
|-------------|-----------------|---------------------|
| `@login_required` protects the view | ✗ | ✓ |
| URL routing (`/notes/` → note_list) | ✗ | ✓ |
| redirect after POST (302 → /notes/pk/) | ✗ | ✓ |
| form errors in the template context | ✗ | ✓ |
| Bob gets a 404 when trying to access | ✗ | ✓ |
| The page HTML contains the note title | ✗ | ✓ |
| The business logic of create_note() is correct | ✓ | ✓ |

### Django Test Client — what it is

`self.client` is `django.test.Client`, a built-in HTTP client for tests.

```python
# Automatically available in every TestCase as self.client
from django.test import TestCase

class MyTest(TestCase):
    def test_something(self):
        self.client  # ← ready to use
```

It does not open a real browser. It simulates an HTTP request **inside the Django process**: bypassing the network, but passing through the whole Django middleware stack.

### force_login vs login

```python
# force_login — fast, no password check
self.client.force_login(self.alice)
# ↑ Always use it in tests. It doesn't check the password,
#   doesn't run authentication backends — it just sets up the session.

# login — the full auth pipeline
self.client.login(username='alice', password='pass123')
# ↑ Use it only if you are testing the login process itself.
```

### Key response attributes

```python
response = self.client.get(reverse('hello_app:note_list'))

response.status_code      # → 200, 302, 404, 403, 500
response.context          # → the template context {'notes': queryset, 'form': form}
response.content          # → bytes of the HTML response
response['Location']      # → the redirect URL (if 302)
response.context['form'].errors  # → {'title': ['This field is required.']}
```

### Assert methods for HTTP tests

```python
# HTTP status codes
self.assertEqual(response.status_code, 200)    # OK
self.assertEqual(response.status_code, 302)    # redirect
self.assertEqual(response.status_code, 404)    # not found
self.assertEqual(response.status_code, 403)    # forbidden

# Checking a redirect
self.assertRedirects(response, reverse('hello_app:note_list'),
                     fetch_redirect_response=False)
# fetch_redirect_response=False — we don't make a second GET request

# Text in the HTML
self.assertContains(response, 'Alice Note')    # the string is in the HTML
self.assertNotContains(response, 'Bob Secret') # the string is NOT in the HTML

# Checking that the URL contains login
self.assertIn('/accounts/login/', response['Location'])

# Form errors
self.assertIn('title', response.context['form'].errors)
```

### What each test category in test_views.py checks

```
AuthenticationViewTest    ← @login_required on every view
NoteListViewTest          ← multi-tenant: alice sees only her own notes
NoteDetailViewTest        ← ownership + group-based access
NoteCreateViewTest        ← form valid/invalid, IDOR prevention, note.user = request.user
NoteEditViewTest          ← ownership: someone else's → 404; your own → 302
NoteDeleteViewTest        ← ownership + cascade: the note is deleted from the DB
NotebookViewTest          ← ownership: get_object_or_404(user=request.user)
GroupViewTest             ← membership check: someone else's → 404, non-member delete → 403
TodoListSharingViewTest   ← share/unshare workflow over HTTP
```

---

## 11 · SELENIUM

> **Selenium** is Python code that drives a real browser (Firefox / Chrome).

### The difference between the Django Test Client and Selenium

```
Django Test Client:
  Python → Django middleware → view → response
  We bypass the network and the browser.
  We don't see JavaScript, CSS, DOM rendering.

Selenium:
  Python → geckodriver → Firefox → real HTTP → Django server
  The full stack: the browser opens, the page loads, JS runs.
  We see everything the user sees.
```

### StaticLiveServerTestCase — a real server

```python
from django.contrib.staticfiles.testing import StaticLiveServerTestCase

class MySeleniumTest(StaticLiveServerTestCase):
    def test_something(self):
        self.live_server_url  # → 'http://127.0.0.1:PORT' (random port)
        self.driver.get(f'{self.live_server_url}/notes/')
```

`StaticLiveServerTestCase` starts a real Django HTTP server on a temporary port. Selenium connects to it like a real browser.

### Session Cookie Trick — login without the form

```python
def _login_via_cookie(self):
    """Logging in without filling in the login form in the browser."""
    # 1. The Test Client sets up the session
    self.client.force_login(self.user)
    session_cookie = self.client.cookies['sessionid']

    # 2. Open any page (the browser needs an active domain)
    self.driver.get(f'{self.live_server_url}/')

    # 3. Copy the session cookie into Selenium
    self.driver.add_cookie({
        'name': 'sessionid', 'value': session_cookie.value, 'path': '/'
    })
    # Now the driver is authenticated!
```

**Why:** a login form may have CSRF, JS validation, reCAPTCHA. All of this breaks E2E tests. The session cookie trick is more reliable and faster.

### Headless mode

```python
from selenium.webdriver.firefox.options import Options

options = Options()
options.add_argument('--headless')  # no GUI window
driver = webdriver.Firefox(options=options)
```

**headless** = the browser starts without a graphical interface. Needed for:
- CI/CD servers (GitHub Actions, Jenkins, Docker) — there is no display there
- Speed — no need to render pixels to a screen

### @unittest.skipUnless — graceful skip

```python
try:
    from selenium import webdriver
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class MySeleniumTest(StaticLiveServerTestCase):
    ...
```

If `selenium` is not installed → the tests are marked as `s` (skipped) and **don't fail**.

```
Ran 129 tests in 90.2s
OK (skipped=6)
```

This is important: `manage.py test` must always return OK, even without geckodriver.

### Why there are few Selenium tests

```
Unit test: 0.01s  ×  100 = 1 second
Selenium:  10s    ×  100 = 16 minutes

+ Selenium is brittle: changing a CSS class breaks the test even if the logic is correct
+ Requires geckodriver and a specific browser version
+ Unstable in CI without implicitly_wait

Rule: E2E tests only for CRITICAL user flows.
      Everything else — unit/integration.
```

---

## Step 0 — Running the project

!!! note "The paths in this section come from the course's original monorepo"
    The commands below are based on the structure of the original course monorepo,
    where this project is located at `module_5/lesson_Django_Testing/crispy_notes_project`.

    If you are working in the standalone **notes_chat_app** repository, run the commands
    from the repository root — `cd module_5/...` is not needed.
    This repository's CI workflow watches the `notes_app/**` and `notes_project/**` paths.

```bash
# 1. Go to the project folder
cd module_5/lesson_Django_Testing/crispy_notes_project

# 2. Install dependencies (if not installed yet)
pip install -r requirements.txt

# 3. Apply migrations
python manage.py migrate

# 4. Start the server (for manual checking)
python manage.py runserver
```

### What to look at in the browser

| URL | What it shows |
|-----|-----------|
| `http://127.0.0.1:8000/notes/` | List of notes (logged-in users only) |
| `http://127.0.0.1:8000/groups/` | The current user's groups |
| `http://127.0.0.1:8000/admin/` | Django Admin — the models we are testing |

---

## Step 1 — Structure of tests/

```
hello_app/
├── models.py
├── views.py
├── forms.py
├── services.py
├── selectors.py
└── tests/                      ← a package (a directory with __init__.py)
    ├── __init__.py              ← an empty file, makes tests/ a Python package
    ├── test_models.py           ← Unit: constraints, __str__, SET_NULL (23 tests)
    ├── test_services.py         ← Unit: business logic, security (36 tests)
    ├── test_forms.py            ← Unit: validation, queryset filtering (23 tests)
    ├── test_views.py            ← Integration: HTTP, ownership, redirects (41 tests)
    └── test_selenium.py         ← E2E: browser (6 tests, skipped without geckodriver)
```

### Why a `tests/` package rather than a single `tests.py`?

```
# Option 1: a single tests.py file
hello_app/tests.py   ← everything in one place → grows to 2000+ lines, hard to navigate

# Option 2: a tests/ package (our option)
hello_app/tests/
    test_models.py    ← models only     (23 tests)
    test_services.py  ← services only   (36 tests)
    test_forms.py     ← forms only      (23 tests)
    test_views.py     ← integration     (41 tests)
    test_selenium.py  ← E2E             (6 tests)
```

### `__init__.py` — it doesn't work without it

```python
# hello_app/tests/__init__.py
# The file is empty, but MANDATORY.
# Without it Django won't find the tests in this directory.
```

---

## Step 2 — test_models.py

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase
from hello_app.models import Note, Notebook, ShopItem, ShoppingList, Tag
```

### What we import and why

| Import | Why |
|--------|--------|
| `TestCase` | The Django base class — transaction + test DB |
| `IntegrityError` | For tests of `unique_together` and `CHECK constraint` |
| `ValidationError` | For `full_clean()` tests — validators |
| `Group, User` | Django built-in models (used in Note.group) |

### Key assert methods in model tests

```python
self.assertEqual(str(tag), '#python')     # string equality
self.assertFalse(note.is_pinned)          # check for False
self.assertIsNone(note.group)             # check for None
self.assertIsNotNone(note.created_at)     # check that it is not None
self.assertIn('Milk', str(item))          # substring in a string
self.assertGreaterEqual(updated, old)     # comparing dates

# For checking exceptions:
with self.assertRaises(IntegrityError):
    Tag.objects.create(user=user, name='duplicate')

with self.assertRaises(ValidationError) as ctx:
    note.full_clean()
self.assertIn('priority', ctx.exception.message_dict)
```

---

## Step 3 — test_services.py

```python
from django.contrib.auth.models import Group, User
from django.test import TestCase
from hello_app import services
from hello_app.models import Note, Notebook, Tag, TodoList
```

### BaseServiceTest — avoiding duplication

```python
class BaseServiceTest(TestCase):
    """
    A base class with a shared setUp.
    All subclasses automatically get self.alice and self.bob.
    """
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() is NOT needed — inherited from BaseServiceTest
    # self.alice and self.bob are available in every test

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)
```

### Persistence test — "was it really saved?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    IMPORTANT: we check that the change is saved in the DB, not only in memory.

    Buggy code could:
        note.is_pinned = True   ← changed it in memory
        return note             ← returned it, but didn't save it!

    The test EXPLICITLY reads from the DB again:
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
    services.toggle_pin_note(note)

    # Load a NEW object from the DB — ignore the one cached in memory
    note_from_db = Note.objects.get(pk=note.pk)
    self.assertTrue(note_from_db.is_pinned)
    #                ↑ really True in the DB, not only in the object's memory
```

### TodoListServiceTest — a setUp() that extends the base one

```python
class TodoListServiceTest(BaseServiceTest):

    def setUp(self):
        super().setUp()   # ← MANDATORY! Call the parent class's setUp
        # Additional preparation specific to this class:
        self.todo_list = services.create_todo_list(
            user=self.alice, title='Alice Shopping'
        )
        # Now self.alice, self.bob and self.todo_list are available in every test
```

---

## Step 4 — test_forms.py

```python
from django.contrib.auth.models import Group, User
from django.test import TestCase
from hello_app.forms import GroupCreateForm, NoteForm, TagForm
from hello_app.models import Notebook, Tag
```

### Testing a form without HTTP

```python
# A form without an HTTP request — just Python:

# Checking valid data:
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
# ↑ msg=form.errors — if it fails, we'll see WHY it is invalid

# Checking invalid data:
form = NoteForm(data={'title': '', 'priority': 1}, user=self.alice)
self.assertFalse(form.is_valid())
self.assertIn('title', form.errors)
# ↑ We check that the error is in a SPECIFIC field (not a general one)

# Checking cleaned_data (normalization):
form = TagForm(data={'name': 'Python', 'color': '#ff'})
form.is_valid()
self.assertEqual(form.cleaned_data['name'], 'python')
```

### NoteFormSecurityTest — the full security block

```python
class NoteFormSecurityTest(BaseFormTest):

    def setUp(self):
        super().setUp()
        # Both users have their own notebooks
        self.alice_notebook = Notebook.objects.create(user=self.alice, title="Alice's")
        self.bob_notebook   = Notebook.objects.create(user=self.bob,   title="Bob's")

    def test_notebook_queryset_contains_user_notebooks(self):
        """Alice sees HER OWN notebook in the dropdown."""
        form = NoteForm(user=self.alice)
        self.assertIn(self.alice_notebook, form.fields['notebook'].queryset)

    def test_notebook_queryset_excludes_other_user_notebooks(self):
        """Alice does NOT see Bob's notebooks — IDOR is impossible."""
        form = NoteForm(user=self.alice)
        self.assertNotIn(self.bob_notebook, form.fields['notebook'].queryset)

    def test_group_queryset_excludes_groups_user_not_in(self):
        """Alice doesn't see groups where she is not a member."""
        group = Group.objects.create(name="Bob's Team")
        self.bob.groups.add(group)        # only Bob is in the group

        form = NoteForm(user=self.alice)
        self.assertNotIn(group, form.fields['group'].queryset)
```

---

## Step 5 — test_views.py

### File structure

```python
from django.contrib.auth.models import Group, User
from django.test import TestCase
from django.urls import reverse
from hello_app.models import Note, Notebook, TodoList

class BaseViewTest(TestCase):         # ← shared setUp
class AuthenticationViewTest(...)     # ← login_required on all views
class NoteListViewTest(...)           # ← multi-tenant isolation
class NoteDetailViewTest(...)         # ← ownership + group access
class NoteCreateViewTest(...)         # ← form valid/invalid, IDOR prevention
class NoteEditViewTest(...)           # ← ownership check (someone else's → 404)
class NoteDeleteViewTest(...)         # ← ownership + cascade to the DB
class NotebookViewTest(...)           # ← ownership via get_object_or_404
class GroupViewTest(...)              # ← membership check
class TodoListSharingViewTest(...)    # ← share/unshare workflow
```

### The three most important patterns

**1. Checking login_required**

```python
def test_note_list_redirects_anonymous(self):
    """A user who is not logged in cannot view the note list."""
    response = self.client.get(reverse('hello_app:note_list'))
    # Not 200! → redirect to the login page
    self.assertEqual(response.status_code, 302)
    self.assertIn('/accounts/login/', response['Location'])
```

**2. Ownership check — Bob gets a 404**

```python
def test_non_owner_gets_404(self):
    """
    Bob (not the owner) tries to view Alice's note → 404.

    Why 404 and not 403?
    404 — nothing is known about the resource. Safer.
    403 — the resource exists, but access is forbidden. Reveals information.
    """
    self.client.force_login(self.bob)
    response = self.client.get(
        reverse('hello_app:note_detail', args=[self.alice_note.pk])
    )
    self.assertEqual(response.status_code, 404)
```

**3. IDOR prevention through the view**

```python
def test_form_rejects_other_users_notebook_idor_prevention(self):
    """
    Alice tries a POST with notebook=bob_notebook.id.
    The NoteForm(user=alice) queryset doesn't contain Bob's notebook → invalid choice.
    """
    bob_notebook = Notebook.objects.create(user=self.bob, title="Bob Notebook")
    self.client.force_login(self.alice)
    response = self.client.post(
        reverse('hello_app:note_create'),
        data={'title': 'Hack Note', 'notebook': bob_notebook.pk, 'priority': 1},
    )
    self.assertEqual(response.status_code, 200)  # ← the form is invalid, no redirect
    self.assertFalse(Note.objects.filter(title='Hack Note').exists())
```

### Access map: what each view returns for each user

```
                    alice     bob (not member)   bob (member of group)
note_list           200       200 (own notes)    200 (own notes)
note_detail (own)   200       404                404
note_detail (group) 200       404                200 ← group access!
note_edit           200       404                302+error
note_delete         302 ok    404                302+error
notebook_edit       200       404                404
group_detail        200       404                200 ← if member
group_delete        302 ok    403                403
```

---

## Step 6 — test_selenium.py

### File structure

```python
import unittest
try:
    from selenium import webdriver
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

from django.contrib.staticfiles.testing import StaticLiveServerTestCase

@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(StaticLiveServerTestCase):
    # test_login_page_renders
    # test_valid_login_redirects_to_notes
    # test_invalid_login_shows_error

@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumNoteFlowTest(StaticLiveServerTestCase):
    # test_note_list_page_loads
    # test_create_note_via_form
    # test_created_note_appears_in_list
```

### How to run Selenium

```bash
# 1. Install selenium
pip install selenium

# 2. Download geckodriver for Firefox
#    https://github.com/mozilla/geckodriver/releases
#    → unpack it and add it to PATH

# 3. Run
python manage.py test hello_app.tests.test_selenium -v 2
```

### If selenium is NOT installed

```bash
python manage.py test hello_app.tests -v 1

# Output:
# ...........s.s.s.s.s.s.........
# Ran 129 tests in 90.2s
# OK (skipped=6)   ← 6 Selenium tests skipped, but they didn't fail!
```

`s` = skipped. `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` — if the package is not installed, the tests are marked as skipped. The overall result is `OK`.

---

## Step 7 — Running the tests

### Commands for running

```bash
# All tests (unit + integration + E2E)
python manage.py test hello_app.tests

# Only unit tests (fast)
python manage.py test hello_app.tests.test_models
python manage.py test hello_app.tests.test_services
python manage.py test hello_app.tests.test_forms

# Only integration tests
python manage.py test hello_app.tests.test_views

# Only Selenium E2E
python manage.py test hello_app.tests.test_selenium

# A specific class
python manage.py test hello_app.tests.test_views.NoteDetailViewTest

# A specific test
python manage.py test hello_app.tests.test_views.NoteDetailViewTest.test_group_member_can_view_note

# With detailed output
python manage.py test hello_app.tests -v 2

# Stop at the first failure
python manage.py test hello_app.tests --failfast
```

### Expected result

```
$ python manage.py test hello_app.tests -v 1

Creating test database for alias 'default' ...
Found 129 test(s).
...........................................................................................................................ssssss
----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK (skipped=6)
Destroying test database for alias 'default' ...
```

### Output key

```
...........   ← dots = passed tests
s             ← s = skipped (Selenium without geckodriver)
F             ← F = failed (an assertion failed)
E             ← E = error (an exception in the test, not an assertion)

Ran 129 tests in 90.2s   ← 129 tests in total
OK (skipped=6)           ← all green, 6 skipped (expected)

If you see FAILED (failures=X, errors=Y) — read the Traceback.
The Traceback shows: the file, the line, what was expected, what was received.
```

### What the numbers mean

```
82  — unit tests (models + services + forms)
41  — integration tests (views via the Test Client)
 6  — E2E tests (Selenium, skipped without geckodriver)
───
129 — total
```

---

## Step 8 — GitHub Actions CI

> **Goal:** every `git push` automatically runs the same tests you have just learned to write.
> Without your involvement. On a clean server. With the result in GitHub in 2–3 minutes.

### Where the workflow lives

```
PY-Course-Victor-Nikoriak-23_02/          ← repository root
└── .github/
    └── workflows/
        └── django-tests.yml              ← ★ the REAL file, GitHub sees it
```

The file `crispy_notes_project/.github/workflows/django-tests.yml` is a **sample/reference**.
GitHub Actions reads workflows ONLY from the repository's root folder. Everything else is ignored.

---

### What happens on git push

```
You:     git push origin main
         │
         ▼
GitHub:  Detect event → push to main
         did paths change? module_5/lesson_Django_Testing/** → YES
         │
         ▼
Azure:   Provision Ubuntu 22.04 VM (new, clean)
         │
         ├── Job 1: unit-and-integration (~1-2 min)
         │     checkout → python 3.12 → pip install → manage.py check → manage.py test
         │     Result: ✅ or ❌
         │
         └── Job 2: selenium-e2e (~1-2 min) — only if Job 1 is ✅
               checkout → pip install → manage.py test test_selenium
               Chrome is installed on ubuntu-latest, Selenium Manager = chromedriver
               Result: ✅ or ❌
         │
         ▼
GitHub:  Green/red status on the commit + email if ❌
```

---

### The full workflow: line by line

!!! warning "This workflow comes from the course's original monorepo"
    The YAML code below describes the CI workflow written for the course monorepo,
    where the project is located at `module_5/lesson_Django_Testing/crispy_notes_project`.
    Accordingly, `paths:` and `working-directory:` point to that path.

    In the standalone **notes_chat_app** repository the workflow watches the paths
    `notes_app/**` and `notes_project/**` — without the `module_5/` prefix.
    The walkthrough below is a teaching example of GitHub Actions structure — the concepts
    (`on`, `paths`, `jobs`, `steps`, `needs`) apply to any project.

File: [`.github/workflows/django-tests.yml`](../../../../.github/workflows/django-tests.yml)

#### Name and triggers

```yaml
name: Django Tests (module_5/lesson_Django_Testing)
```

This name is displayed in the **Actions** tab on GitHub.

```yaml
on:
  push:
    branches: [ main, master ]
    paths:
      - 'module_5/lesson_Django_Testing/**'
      - '.github/workflows/django-tests.yml'
  pull_request:
    branches: [ main, master ]
    paths:
      - 'module_5/lesson_Django_Testing/**'
      - '.github/workflows/django-tests.yml'
  workflow_dispatch:
```

**`on`** — defines when to run the workflow.
📖 [Documentation: Events that trigger workflows](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows)

| Key | What it means |
|------|-----------|
| `push` | On every git push |
| `branches` | Only for the `main` or `master` branches |
| `paths` | **Only if these files changed.** If you edit module_1, the workflow doesn't run |
| `pull_request` | When a PR is opened or updated |
| `workflow_dispatch` | The "Run workflow" button in the GitHub UI → Actions |

**Why `paths`?**

Without `paths`, every push to any file in the course would run the Django lesson's tests. With `paths`, the workflow runs only when files of this particular lesson or the workflow itself have changed. It saves CI minutes.

---

#### Job 1: Unit & Integration Tests

```yaml
jobs:
  unit-and-integration:
    name: Unit & Integration Tests
    runs-on: ubuntu-latest
```

**`runs-on: ubuntu-latest`** — the runner type. It is a fresh Ubuntu 22.04 VM on Azure. After the job finishes, the VM is destroyed. No state is kept between runs.

📖 [Documentation: GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#standard-github-hosted-runners-for-public-repositories)

```yaml
    defaults:
      run:
        working-directory: module_5/lesson_Django_Testing/crispy_notes_project
```

**`defaults.run.working-directory`** — all `run:` commands in this job are executed from this directory. Without it, every command would start from the repository root and you would have to write `cd module_5/...` before every step.

📖 [Documentation: defaults.run](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#defaultsrun)

---

**Step 1 — Checkout**

```yaml
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
```

Clones the whole repository onto the VM. Without this step, the runner has none of your code's files.

📖 [actions/checkout on GitHub Marketplace](https://github.com/marketplace/actions/checkout)

---

**Step 2 — Setup Python**

```yaml
      - name: Set up Python 3.12
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
```

Installs the required Python version. Ubuntu-latest has several Python versions; this action selects and activates the one you need.

📖 [actions/setup-python on GitHub Marketplace](https://github.com/marketplace/actions/setup-up-a-specific-version-of-python)

---

**Step 3 — Cache pip**

```yaml
      - name: Cache pip dependencies
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('module_5/lesson_Django_Testing/crispy_notes_project/requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-
```

Caches the `~/.cache/pip` folder between workflow runs.

**How it works:**
1. On the first run — there is no cache, pip downloads the packages (~60 seconds), the cache is saved
2. On subsequent runs — if `requirements.txt` hasn't changed, the `key` matches → pip loads the packages from the cache (~5 seconds)
3. If `requirements.txt` has changed → the `key` is new → the cache is not found → `restore-keys` gives a partial match → the cache is updated

`${{ hashFiles(...) }}` is a GitHub Actions expression. It returns the file's SHA-256 hash. If the file hasn't changed, the hash is the same → cache hit.

📖 [actions/cache on GitHub Marketplace](https://github.com/marketplace/actions/cache)
📖 [Documentation: Caching dependencies](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows)

---

**Step 4 — Install dependencies**

```yaml
      - name: Install dependencies
        run: pip install -r requirements.txt
```

A simple shell command. It runs from the `working-directory` → that is, from `crispy_notes_project/`.

---

**Step 5 — Django system check**

```yaml
      - name: Django system check
        run: python manage.py check
```

`manage.py check` is a built-in Django command. It checks:
- The correctness of `settings.py`
- Model syntax
- Middleware configuration
- URL patterns

If there is a configuration error, you find out here in 3 seconds, not after 2 minutes of tests.

📖 [Documentation: Django system check framework](https://docs.djangoproject.com/en/5.2/topics/checks/)

---

**Step 6 — Run tests**

```yaml
      - name: Run unit and integration tests
        run: |
          python manage.py test \
            hello_app.tests.test_models \
            hello_app.tests.test_services \
            hello_app.tests.test_forms \
            hello_app.tests.test_views \
            -v 2
```

Runs 123 tests (unit + integration). The modules are listed explicitly without `test_selenium` — Selenium is in a separate job.

`-v 2` — verbose: each test is printed on its own line. In CI this is useful: you immediately see the name of the test that failed.

If any test returns `FAILED` → the step returns exit code 1 → GitHub Actions considers the step failed → the job stops → Job 2 (selenium) doesn't run.

---

**Step 7 — Coverage**

```yaml
      - name: Generate coverage report
        run: |
          coverage run manage.py test \
            hello_app.tests.test_models \
            hello_app.tests.test_services \
            hello_app.tests.test_forms \
            hello_app.tests.test_views
          coverage report --show-missing
          coverage xml -o coverage.xml
```

`coverage run` — runs the tests through `coverage`, tracking which lines of code are executed.

`coverage report --show-missing` — prints a table:

```
Name                          Stmts   Miss  Cover   Missing
-----------------------------------------------------------
hello_app/models.py             87      3    97%   45, 67, 89
hello_app/services.py          124      8    94%   34-41
hello_app/views.py             198     12    94%   ...
-----------------------------------------------------------
TOTAL                          409     23    94%
```

`coverage xml -o coverage.xml` — saves it as XML for integration with Codecov / SonarQube.

📖 [Coverage.py documentation](https://coverage.readthedocs.io/en/latest/)

---

**Step 8 — Upload artifact**

```yaml
      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-xml
          path: module_5/lesson_Django_Testing/crispy_notes_project/coverage.xml
```

Saves `coverage.xml` as an artifact — the file is attached to the workflow run and can be downloaded from the GitHub UI.

The path is given relative to the repository root (not the `working-directory`) — artifact upload does not inherit `defaults.run.working-directory`.

📖 [actions/upload-artifact on GitHub Marketplace](https://github.com/marketplace/actions/upload-a-build-artifact)

---

#### Job 2: Selenium E2E

```yaml
  selenium-e2e:
    name: Selenium E2E Tests
    runs-on: ubuntu-latest
    needs: unit-and-integration
```

**`needs: unit-and-integration`** — Job 2 runs only after Job 1 has finished successfully. If the unit tests failed, Selenium doesn't even start. This is right: there's no point checking the browser flow if the basic logic is already broken.

📖 [Documentation: needs](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)

---

**Why there is no service container for Selenium**

The sample inside the project (`crispy_notes_project/.github/...`) has a `services: selenium: image: selenium/standalone-chrome` section. The real workflow **does not use** it. Here's why:

```
The problem with a service container:

  Runner VM                     Docker container (selenium/standalone-chrome)
  ┌─────────────────────┐       ┌─────────────────────────────────────┐
  │ Django test server  │       │ Chrome                              │
  │ http://localhost:PORT│       │                                     │
  │                     │       │  Chrome opens                       │
  │                     │◄──────│  http://localhost:PORT              │
  └─────────────────────┘       │                                     │
                                │  BUT! the container's localhost ≠   │
                                │  the runner's localhost             │
                                │  → ERR_CONNECTION_REFUSED           │
                                └─────────────────────────────────────┘

The solution (the real workflow):

  Runner VM — everything on one machine
  ┌─────────────────────────────────────────────────────┐
  │ Django test server       Chrome (already installed) │
  │ http://localhost:PORT ◄─ http://localhost:PORT ✅    │
  │                                                     │
  │ Selenium Manager automatically downloads chromedriver│
  └─────────────────────────────────────────────────────┘
```

`ubuntu-latest` includes Chrome. `selenium>=4.6` has a built-in Selenium Manager — it finds the installed Chrome itself and downloads the matching `chromedriver` version. Nothing else is needed.

---

**Step — Run Selenium**

```yaml
      - name: Run Selenium E2E tests
        run: python manage.py test hello_app.tests.test_selenium -v 2
```

Without the `SELENIUM_REMOTE_URL` variable → `_make_driver()` in the test code uses the local Chrome in headless mode. Django's `StaticLiveServerTestCase` starts the server on a random port, and Chrome connects to it on the same `localhost`.

---

### How to view the results

**1. The Actions tab in the repository**

```
https://github.com/NikoriakViktot/PY-Course-Victor-Nikoriak-23_02/actions
```

Here is the list of all workflow runs. Green — all green. Red — something failed.

**2. The Jobs graph**

Click on a specific run → you see two boxes:

```
[Unit & Integration Tests] ──needs──► [Selenium E2E Tests]
      ✅ 1m 23s                              ✅ 1m 47s
```

**3. Logs of a specific step**

Click on the job → click on the step → expand it:

```
Run python manage.py test ...

Creating test database for alias 'default' ...
Found 123 test(s).
test_str_returns_hash_name (hello_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
...
----------------------------------------------------------------------
Ran 123 tests in 34.2s
OK
```

**4. Download artifacts**

Actions run → Artifacts (at the bottom of the page) → `coverage-xml` → download `coverage.xml`.

**5. Status on the commit**

Every commit in the commit list gets a badge:
- `✅` — all workflows passed
- `❌` — something failed
- `🟡` — running

---

### What each line in the log means on failure

```
FAIL: test_note_list_excludes_other_user_notes
      ↑ The test name → you immediately understand WHAT broke

(hello_app.tests.test_views.NoteListViewTest)
      ↑ The class and file → you can open it right away

Traceback (most recent call last):
  File ".../test_views.py", line 89, in test_note_list_excludes_other_user_notes
    self.assertNotContains(response, "Bob's Secret Note")
AssertionError: Response should not contain "Bob's Secret Note"
      ↑ We expected the string NOT to be there, but it is → Bob's notes are visible to Alice!
      → The bug is in selectors.get_user_notes() — the filter by user was forgotten

Process completed with exit code 1
      ↑ The Django test runner returned 1 → GitHub Actions considers the step failed
```

---

### The connection: tests ↔ CI/CD

```
You write:                 CI/CD runs:               You get:

test_models.py    ─────►   Job 1, Step 6         ──► ✅ or ❌ in 30 sec
test_services.py  ─────►   (unit + integration)  ──► Traceback right in GitHub
test_forms.py     ─────►
test_views.py     ─────►

test_selenium.py  ─────►   Job 2                 ──► ✅ or ❌ after Job 1
                            (E2E, needs: job1)    ──► Chrome headless on Azure
```

Every test you wrote in Steps 2–6 automatically runs in CI on every push.

---

### Documentation links

| Topic | Link |
|------|-----------|
| GitHub Actions — Quick Start | https://docs.github.com/en/actions/writing-workflows/quickstart |
| Understanding GitHub Actions | https://docs.github.com/en/actions/about-github-actions/understanding-github-actions |
| Events that trigger workflows | https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows |
| Workflow syntax (full reference) | https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions |
| Caching dependencies | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows |
| GitHub-hosted runners | https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners |
| actions/checkout | https://github.com/marketplace/actions/checkout |
| actions/setup-python | https://github.com/marketplace/actions/setup-up-a-specific-version-of-python |
| actions/cache | https://github.com/marketplace/actions/cache |
| actions/upload-artifact | https://github.com/marketplace/actions/upload-a-build-artifact |
| Monitoring workflows (live logs) | https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/monitoring-workflows |
| Coverage.py | https://coverage.readthedocs.io/en/latest/ |
| Django system check | https://docs.djangoproject.com/en/5.2/topics/checks/ |
| Selenium Manager | https://www.selenium.dev/documentation/selenium_manager/ |

---

### Practice: check that CI/CD works

1. Open in your browser: `https://github.com/NikoriakViktot/PY-Course-Victor-Nikoriak-23_02/actions`
2. Find the workflow **"Django Tests (module_5/lesson_Django_Testing)"**
3. Click on the latest run
4. Expand Job 1 → Step "Run unit and integration tests"
5. Find the line `Ran 123 tests in ... OK`
6. Go to Job 2 → see how Selenium runs on the Ubuntu runner

**On your own:** make a deliberate mistake in any test (`assertFalse(True)`), do a `git push`, and see how CI shows the FAIL and the Traceback.

---

```
crispy_notes_project/
│
├── README.md                         ← YOU ARE HERE — the full testing tutorial
│
├── requirements.txt                  ← Django>=5.2, crispy-forms, crispy-bootstrap5
│
├── hello_project/
│   ├── settings.py                   ← configuration (EMAIL_BACKEND=console for tests)
│   └── urls.py
│
├── hello_app/
│   ├── models.py                     ← Note, Tag, Notebook, ShopItem — what we test
│   ├── forms.py                      ← NoteForm, TagForm, GroupCreateForm — what we test
│   ├── services.py                   ← create_note, create_group — what we test
│   ├── selectors.py                  ← ORM queries (tested through the integration layer)
│   ├── views.py                      ← HTTP handlers — what we test via the Test Client
│   │
│   └── tests/                        ← ★ THE TESTS FOLDER (129 tests)
│       ├── __init__.py               ← empty — makes tests/ a package
│       ├── test_models.py            ←  23 unit tests: constraints, __str__, SET_NULL
│       ├── test_services.py          ←  36 unit tests: CRUD, security, transactions
│       ├── test_forms.py             ←  23 unit tests: validation, normalization, IDOR
│       ├── test_views.py             ←  41 integration: HTTP, ownership, redirects
│       └── test_selenium.py          ←   6 E2E: browser (skipped without geckodriver)
│
└── templates/                        ← HTML templates
```

---

## Summary: what to learn and where

### Unit tests

| Concept | Where to look in the code |
|-----------|-------------------|
| **Basic test structure** | Any test_* method — Arrange / Act / Assert |
| **setUp and tearDown** | `BaseServiceTest.setUp()` in `test_services.py` |
| **assertRaises** | `test_models.py` — `TagModelTest.test_unique_together_*` |
| **full_clean() vs save()** | `test_models.py` — `test_priority_above_4_raises_validation_error` |
| **refresh_from_db()** | `test_models.py` — `test_note_group_becomes_null_when_group_deleted` |
| **Persistence test** | `test_services.py` — `test_toggle_pin_note_persisted_in_db` |
| **Security (Mass Assignment)** | `test_services.py` — `test_create_note_ignores_other_users_tags` |
| **Transactional logic** | `test_services.py` — `test_create_notebook_default_unsets_previous_default` |
| **Isolation between users** | `test_services.py` — `test_create_notebook_default_only_affects_same_user` |
| **Form queryset security** | `test_forms.py` — `NoteFormSecurityTest` (7 tests) |

### Integration tests (test_views.py)

| Concept | Where to look in the code |
|-----------|-------------------|
| **force_login vs login** | `BaseViewTest.setUp()` — `self.client.force_login(alice)` |
| **@login_required check** | `AuthenticationViewTest` — 8 tests (all protected URLs) |
| **response.status_code** | `NoteListViewTest.test_authenticated_user_gets_200` |
| **assertContains / assertNotContains** | `NoteListViewTest.test_note_list_excludes_other_user_notes` |
| **Ownership: 404 for someone else's** | `NoteDetailViewTest.test_non_owner_gets_404` |
| **Group-based access** | `NoteDetailViewTest.test_group_member_can_view_note` |
| **IDOR through the view** | `NoteCreateViewTest.test_form_rejects_other_users_notebook_*` |
| **Form errors in the context** | `NoteCreateViewTest.test_empty_title_shows_form_error` |
| **assertRedirects** | `NoteDeleteViewTest.test_delete_redirects_to_note_list` |
| **403 Forbidden** | `GroupViewTest.test_non_member_delete_returns_403` |
| **Sharing workflow** | `TodoListSharingViewTest.test_shared_user_can_view_todo_list` |

### E2E tests (test_selenium.py)

| Concept | Where to look in the code |
|-----------|-------------------|
| **StaticLiveServerTestCase** | The base class of the Selenium tests |
| **Session cookie trick** | `SeleniumNoteFlowTest._login_via_cookie()` |
| **Headless Firefox** | `_make_headless_driver()` — `options.add_argument('--headless')` |
| **implicitly_wait** | `setUpClass` — `cls.driver.implicitly_wait(5)` |
| **skipUnless** | `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` |
| **find_element + send_keys** | `SeleniumLoginFlowTest.test_valid_login_redirects_to_notes` |
| **page_source check** | `SeleniumNoteFlowTest.test_created_note_appears_in_list` |

---

## Lesson documentation

| File | Topic |
|------|------|
| [`../README.md`](../README.md) | Navigation across the whole testing lesson |
| [`../TESTING_FOUNDATIONS.md`](../TESTING_FOUNDATIONS.md) | The pyramid, principles, AAA |
| [`../UNITTEST_BASICS.md`](../UNITTEST_BASICS.md) | Python unittest: TestCase, lifecycle |
| [`../PYTEST_BASICS.md`](../PYTEST_BASICS.md) | pytest: fixtures, parametrize |
| [`../DJANGO_TESTING.md`](../DJANGO_TESTING.md) | Django: TestCase, Client, the test DB |
| [`../TEST_DATA_AND_FIXTURES.md`](../TEST_DATA_AND_FIXTURES.md) | factory_boy, fixtures |
| [`../MOCKING_AND_PATCHING.md`](../MOCKING_AND_PATCHING.md) | Mock, patch, external services |
| [`../TESTING_PRACTICE_PROJECT.md`](../TESTING_PRACTICE_PROJECT.md) | E2E, Selenium, a full scenario |
| [`../SELENIUM.md`](../SELENIUM.md) | Selenium WebDriver: By strategies, waits, StaticLiveServerTestCase, session cookie trick |
| [`../CI_CD.md`](../CI_CD.md) | CI/CD theory, GitHub Actions components, events, runners |
| [`.github/workflows/django-tests.yml`](.github/workflows/django-tests.yml) | A sample workflow for this project |
| [`../../../../.github/workflows/django-tests.yml`](../../../../.github/workflows/django-tests.yml) | The real workflow (repo root) |
| [`../basics/`](../basics/) | Runnable Python test examples |
