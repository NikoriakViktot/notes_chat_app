# Lesson: Django Testing — Testing Django applications

> **Lesson project:** `crispy_notes_chat_app/` — a personal notes manager with authentication,  
> groups, and crispy forms. We will learn to test every layer of this application.

---

## Why test?

Imagine: you added groups to notes. Everything looks fine. But 3 weeks later, after refactoring
`selectors.py`, notes are no longer filtered by group — and you don't know about it, because
checking 34 views by hand takes too long.

**Tests are an automatic alarm system.** They check "does everything still work" in seconds.

```
WITHOUT TESTS:
  git push → CI green → deploy → users see other people's notes

WITH TESTS:
  git push → CI: FAIL test_note_visible_only_to_owner → we fix it before deploying
```

---

## 🏔 The testing pyramid

```
        /\
       /E2E\          ← Selenium: a real browser, a full scenario
      /──────\           (slow, fragile, expensive)
     /  Integr.\      ← Django TestClient: requests + responses + DB
    /────────────\       (medium speed, realistic)
   /    Unit      \   ← pytest/unittest: a single function/method/class
  /────────────────\     (instant, isolated, easy to write)
```

**Rule:** 70% unit → 20% integration → 10% E2E

---

## Lesson structure

```
lesson_Django_Testing/
│
├── README.md                     ← YOU ARE HERE — overview and quick start
│
├── basics/                       ← START HERE — Python tests without Django
│   ├── README.md                 # How to run the examples
│   ├── 01_first_test.py          # First test: assert + def test_
│   ├── 02_unittest_testcase.py   # unittest.TestCase, setUp, tearDown
│   ├── 03_assertions.py          # Full table of assertions
│   ├── 04_pytest_fixtures.py     # @pytest.fixture and scope
│   └── 05_parametrize.py         # @pytest.mark.parametrize
│
├── TESTING_FOUNDATIONS.md        ← Theory: the pyramid, principles, the AAA pattern
├── UNITTEST_BASICS.md            ← Python unittest: TestCase, methods, lifecycle
├── PYTEST_BASICS.md              ← pytest: fixtures, markers, configuration
├── DJANGO_TESTING.md             ← Django: TestCase, Client, the test DB
├── TEST_DATA_AND_FIXTURES.md     ← Fixtures, factory_boy, setUp strategies
├── MOCKING_AND_PATCHING.md       ← Mock, patch, external services
├── TESTING_PRACTICE_PROJECT.md  ← A full scenario + Selenium E2E
│
└── crispy_notes_chat_app/         ← A real Django project for practice
    └── notes_app/
        └── tests/                ← Our tests (written in this lesson)
            ├── test_models.py    # Unit: models, constraints, relationships
            ├── test_services.py  # Unit: business logic, transactions
            └── test_forms.py     # Unit: validation, security filtering
```

---

## ⚡ Quick start

### 1. Running basics/ (Django not needed)

```bash
cd docs/08_testing_and_quality

# Install pytest (if it is not installed)
pip install pytest

# Run all the examples
python -m pytest . -v

# Run a single file
python -m pytest 01_first_test.py -v
```

### 2. Running the Django tests

```bash
cd docs/08_testing_and_quality/crispy_notes_chat_app

# Activate the venv
.venv\Scripts\activate      # Windows
source .venv/bin/activate   # Linux/Mac

# Run all the tests
python manage.py test notes_app.tests -v 2

# Run a specific module
python manage.py test notes_app.tests.test_models -v 2

# Run a specific class
python manage.py test notes_app.tests.test_services.NoteServiceTest -v 2

# Run a specific test
python manage.py test notes_app.tests.test_services.NoteServiceTest.test_create_note_assigns_tags -v 2
```

---

## 01 · BASICS — What is a test?

A **test** is a function that:
1. Prepares the state (Arrange)
2. Performs an action (Act)
3. Checks the result (Assert)

```python
# The AAA pattern (Arrange / Act / Assert)
def test_capitalize():
    # Arrange — prepare the input data
    text = "hello world"

    # Act — perform the action we are testing
    result = text.capitalize()

    # Assert — check whether the result is correct
    assert result == "Hello world"
```

---

## 02 · APPROACHES — unittest vs pytest

| Criterion | `unittest.TestCase` | `pytest` |
|----------|---------------------|----------|
| Style | Class + methods | Functions or classes |
| Setup | `setUp()` / `tearDown()` | `@pytest.fixture` |
| Django | `django.test.TestCase` | `pytest-django` |
| Assertion | `assertEqual(a, b)` | `assert a == b` |
| Running | `manage.py test` | `pytest` |

**In Django you usually use `django.test.TestCase`** (a subclass of `unittest.TestCase`) — it
automatically wraps each test in a transaction and rolls back the changes after each test.

---

## 03 · DJANGO TESTCASE — Specifics

```python
from django.test import TestCase
from django.contrib.auth.models import User

class MyTest(TestCase):
    """
    django.test.TestCase:
    - Creates a test DB (separate from the working one!)
    - Each test is wrapped in a transaction → rollback after the test
    - So you can freely create/modify/delete objects
    - Provides self.client — an HTTP client for testing views
    """

    def setUp(self):
        # setUp() is called BEFORE each test
        self.user = User.objects.create_user('alice', password='pass123')

    def tearDown(self):
        # tearDown() is called AFTER each test (usually not needed)
        pass

    def test_user_created(self):
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(self.user.username, 'alice')
```

---

## 04 · ARCHITECTURE of crispy_notes_chat_app for testing

```
Views (HTTP layer)
    ↓ → test_views.py  (Integration: request → response → DB)
Services (business logic)
    ↓ → test_services.py  (Unit: function → result in the DB)
Selectors (queries)
    ↓ → test_selectors.py  (Unit: query → the correct objects)
Forms (validation)
    ↓ → test_forms.py  (Unit: data → valid/invalid + cleaned_data)
Models (data layer)
    ↓ → test_models.py  (Unit: constraints, relationships, __str__)
```

**The key advantage of the services architecture:** each layer can be tested in isolation.

---

## 05 · SECURITY — What you must test

### IDOR (Insecure Direct Object Reference)

IDOR is when user A can read/modify an object belonging to user B.

```python
# An example IDOR test (views):
def test_cannot_edit_other_users_note(self):
    """Alice must not edit Bob's notes."""
    bob_note = Note.objects.create(user=self.bob, title='Bob secret')

    # Alice tries to edit Bob's note
    self.client.login(username='alice', password='pass')
    response = self.client.get(f'/notes/{bob_note.pk}/edit/')

    # We expect 404 (not 200 and not 403!)
    self.assertEqual(response.status_code, 404)
```

### Form queryset filtering

```python
def test_note_form_filters_notebooks_by_user(self):
    """Alice must not see Bob's notebooks in her form."""
    bob_notebook = Notebook.objects.create(user=self.bob, title="Bob's notebook")

    form = NoteForm(user=self.alice)

    # Bob's notebook must not be in Alice's queryset
    self.assertNotIn(bob_notebook, form.fields['notebook'].queryset)
```

---

## 06 · TESTING VIEWS — Django Test Client

```python
from django.test import TestCase, Client

class NoteViewTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user('alice', password='pass123')
        self.client.login(username='alice', password='pass123')

    def test_note_list_requires_login(self):
        """An anonymous user is redirected to login."""
        self.client.logout()
        response = self.client.get('/notes/')
        self.assertRedirects(response, '/accounts/login/?next=/notes/')

    def test_note_create_post(self):
        """A POST to /notes/new/ creates a note and redirects."""
        response = self.client.post('/notes/new/', {
            'title': 'Test Note',
            'content': 'Content',
            'priority': 1,
        })
        self.assertRedirects(response, '/notes/')
        self.assertEqual(Note.objects.count(), 1)
        self.assertEqual(Note.objects.first().user, self.user)
```

---

## 07 · MOCKING — When is it needed?

When the code interacts with external systems:

```python
from unittest.mock import patch

class EmailTest(TestCase):
    @patch('django.core.mail.send_mail')
    def test_password_reset_sends_email(self, mock_send_mail):
        response = self.client.post('/accounts/password_reset/', {
            'email': 'alice@example.com'
        })
        # Check that send_mail was called
        mock_send_mail.assert_called_once()
```

---

## Learning route

```
① basics/01_first_test.py         — 10 minutes
② basics/02_unittest_testcase.py  — 15 minutes
③ basics/03_assertions.py         — 10 minutes
④ basics/04_pytest_fixtures.py    — 20 minutes
⑤ basics/05_parametrize.py        — 15 minutes
⑥ TESTING_FOUNDATIONS.md          — read the theory
⑦ UNITTEST_BASICS.md              — unittest in depth
⑧ DJANGO_TESTING.md               — Django specifics
⑨ tests/test_models.py            — look + understand
⑩ tests/test_services.py          — look + understand
⑪ tests/test_forms.py             — look + understand
⑫ TESTING_PRACTICE_PROJECT.md    — write views tests on your own
```

---

## Useful commands

```bash
# Run the tests with print() output (useful for debugging)
python manage.py test notes_app.tests --verbosity=2

# Stop at the first failure
python manage.py test notes_app.tests --failfast

# Run only the tests with a certain pattern in their name
python manage.py test notes_app.tests -k "note"  # (via pytest-django)

# pytest (if pytest-django is installed)
pytest notes_app/tests/ -v
pytest notes_app/tests/ -v -k "service"
pytest notes_app/tests/ --tb=short
```

---

*This lesson is part of the [Python course](legacy_missing_reference.md).  
Previous lesson: Django Auth | Next lesson: Django REST Framework*
