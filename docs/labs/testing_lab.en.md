# Testing Lab — A regression test for a permission bug

**Goal:** learn to write a test that catches a permission bug before it reaches production. Understand the difference between `TestCase` and `TransactionTestCase`.

**Related files:** `notes_app/tests/test_views.py`, `notes_app/tests/test_services.py`, `notes_app/tests/test_consumers.py`.

---

## Part 1 — Read the existing IDOR test

Open `notes_app/tests/test_views.py` and find the IDOR test (an attempt to access someone else's note).

A typical pattern:

```python
def test_cannot_access_other_users_note(self):
    alice = User.objects.create_user('alice', password='pw')
    bob = User.objects.create_user('bob', password='pw')
    note = Note.objects.create(user=bob, title="Bob's note", content="secret")

    self.client.force_login(alice)
    response = self.client.get(reverse('notes_app:note_detail', kwargs={'pk': note.pk}))
    self.assertEqual(response.status_code, 404)
```

**Questions:**

1. Why is `404` expected rather than `403`?
2. What happens if the selector returns `Note.objects.get(pk=pk)` without filtering by user?
3. How does `force_login` differ from `client.login(username=..., password=...)`?

---

## Part 2 — Write a regression test

**Scenario:** you suspect that ownership is not checked when a note is edited. Write a test that confirms the bug and then proves it has been fixed.

```python
# notes_app/tests/test_views.py — add the class
class NoteEditPermissionTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice_edit', password='pw')
        self.bob = User.objects.create_user('bob_edit', password='pw')
        self.bob_note = Note.objects.create(
            user=self.bob, title="Bob's private note", content="top secret"
        )

    def test_alice_cannot_edit_bobs_note(self):
        """Alice must not be able to edit Bob's note."""
        self.client.force_login(self.alice)
        url = reverse('notes_app:note_edit', kwargs={'pk': self.bob_note.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 404)

    def test_alice_cannot_post_to_bobs_note(self):
        """A POST to someone else's note must also return 404."""
        self.client.force_login(self.alice)
        url = reverse('notes_app:note_edit', kwargs={'pk': self.bob_note.pk})
        response = self.client.post(url, {'title': 'hacked', 'content': 'x', 'priority': 1})
        self.assertEqual(response.status_code, 404)
        # the note has not changed
        self.bob_note.refresh_from_db()
        self.assertEqual(self.bob_note.title, "Bob's private note")
```

Run it:

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_views -v 2
```

---

## Part 3 — A test for deletion behavior

**Task:** write a test that checks the behavior when a note is deleted: its Reminders are deleted (CASCADE), but the Notebook remains.

```python
# notes_app/tests/test_models.py — add the method
def test_note_deletion_cascades_to_reminders(self):
    from django.utils import timezone
    note = Note.objects.create(user=self.user, title="Test", content="")
    from notes_app.models import Reminder
    Reminder.objects.create(note=note, remind_at=timezone.now())
    note_pk = note.pk
    note.delete()
    self.assertFalse(Reminder.objects.filter(note_id=note_pk).exists())
```

---

## Part 4 — `TransactionTestCase` vs `TestCase`

**Task:** explore the difference in practice.

Copy any test from `test_consumers.py` and try changing `TransactionTestCase` to `TestCase`. Run:

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

**Expected result:** the test either fails with `DoesNotExist` or shows unexpected behavior: the setUp objects are not available to the consumer's worker thread.

**Explain in a code comment why this happens.**

---

## Part 5 — A test for mass assignment security

`services.py` receives `tag_ids` and filters them by the current user:

```python
# services.py (approximate pattern)
tags = Tag.objects.filter(user=user, pk__in=tag_ids)
note.tags.set(tags)
```

**Task:** write a test that checks that even if the request passes `tag_ids` of someone else's tags, they are not assigned:

```python
def test_cannot_assign_other_users_tags(self):
    other_user = User.objects.create_user('other_tag_test', password='pw')
    alien_tag = Tag.objects.create(user=other_user, name='alien')

    # try passing alien_tag.pk in tag_ids
    # after calling the service, the note must not have this tag
    ...
```

**Criterion:** the test passes and confirms that the other user's tag is not assigned.

---

## Summary: test types in the project

| Type | Class | File |
|-----|------|------|
| Unit (model, constraint) | `TestCase` | `test_models.py` |
| Unit (service, security) | `TestCase` | `test_services.py` |
| Unit (form, queryset) | `TestCase` | `test_forms.py` |
| Integration (HTTP, IDOR) | `TestCase` | `test_views.py` |
| Async (WebSocket) | `TransactionTestCase` | `test_consumers.py` |
| E2E (browser) | `StaticLiveServerTestCase` | `test_selenium.py` |

---

## Evaluate and choose (analysis and evaluation level)

### Q.1. `TestCase` vs `TransactionTestCase`: which one to choose and when?

**Scenario:** you are writing a test for a new feature, reminders (Reminder). A reminder is created through a service, and then a Celery task (hypothetically) saves the result to the DB in a separate worker process.

**Evaluate:**
- Why might `TestCase` fail to work for this scenario?
- Find a comment or pattern in `test_consumers.py` that explains the difference.
- If you were testing the `create_reminder` service without a Celery worker, which class would you choose? Why?
- Is there a performance trade-off between `TestCase` and `TransactionTestCase`? Where is it noticeable?

---

### Q.2. Mock vs a real DB in service tests

Two approaches to testing `create_note`:

```python
# Approach A: a real DB (TestCase)
class CreateNoteTest(TestCase):
    def test_note_is_saved(self):
        note = services.create_note(user=self.user, title='T', content='')
        self.assertEqual(Note.objects.count(), 1)

# Approach B: mocked ORM
from unittest.mock import patch
class CreateNoteTest(TestCase):
    @patch('notes_app.services.Note.objects.create')
    def test_note_save_called(self, mock_create):
        mock_create.return_value = MagicMock(pk=1)
        services.create_note(user=self.user, title='T', content='')
        mock_create.assert_called_once()
```

**Evaluate:**
- What does each approach actually test? What does each miss?
- Approach B will pass even if `create_note` is broken (saves to the wrong table). Why?
- Find in `test_services.py` which approach was chosen. Why is it the right decision for Django?
- Formulate a rule: "I mock when..., and I do not mock when..."

---

### Q.3. Where does test coverage matter most?

Notes Chat App has 200+ tests in 7 files. Imagine you have 10 hours to write new tests.

**Evaluate:**
- Which two files/modules need tests the most? Justify through the risk of failure and its cost.
- In which situations does 100% code coverage not guarantee security? Give a concrete example from the project.
- Compare the value of one IDOR test (`test_views.py`) and one `__str__` test (`test_models.py`). Which is more critical?
- Write a list of 5 tests you would add first, and explain the priority of each.
