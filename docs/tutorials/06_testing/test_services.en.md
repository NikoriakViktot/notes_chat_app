# test_services.py — Testing services

---

## Why services are easy to test

> **Services are the best layer for unit tests.** No HTTP, no templates, just logic.

```
VIEWS (HTTP layer):                    SERVICES (business logic):
  Receives the request                   create_note(user=alice, title='Test')
  Parses the form                        Takes Python objects
  Checks CSRF                            Returns a result
  Calls a service                        Saves to the database
  Renders a template                     No dependencies on HTTP!
  Depends on: HTTP, sessions,
  forms, templates, middleware         We test it directly:
  → Hard to test in isolation            result = services.create_note(...)
                                         self.assertEqual(result.title, 'Test')
```

---

## Two kinds of checks in service tests

```python
# KIND 1: checking the RETURNED OBJECT (return value)
def test_create_note_returns_note_object(self):
    note = services.create_note(user=self.alice, title='Test')
    self.assertIsInstance(note, Note)
    self.assertEqual(note.title, 'Test')
    self.assertEqual(note.user, self.alice)

# KIND 2: checking the DATABASE STATE (persistence test)
def test_create_note_saves_to_database(self):
    services.create_note(user=self.alice, title='Test')
    self.assertEqual(Note.objects.count(), 1)
    # ↑ We check what was SAVED, not only what was returned

# WHY BOTH?
# Bug: create_note() returns the note but doesn't call .save()
# Test 1 passes (the object exists), Test 2 fails (count=0)
# Together — full coverage
```

---

## The persistence test — "was it really saved to the database?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    IMPORTANT: we check that the change is saved to the database, not only in memory.

    Buggy code could do:
        def toggle_pin_note(note):
            note.is_pinned = True   ← changed it in Python memory
            return note             ← but didn't save it! (no note.save())

    The test EXPLICITLY reads from the database again:
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
    services.toggle_pin_note(note)

    # Load a NEW object from the database — ignore the one cached in memory
    note_from_db = Note.objects.get(pk=note.pk)
    self.assertTrue(note_from_db.is_pinned)
    #                ↑ really True in the database, not only in the object's memory
```

---

## Security test: Mass Assignment via tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Attack: the attacker sends a POST with a tag_id that belongs to Bob.
    POST /notes/new/ → tag_ids=[bob_secret_tag_id]

    WITHOUT PROTECTION (vulnerable):
        note.tags.set(Tag.objects.filter(id__in=tag_ids))
        → Bob's tag gets attached to Alice's note
        → Alice sees Bob's secret tag in her note → DATA LEAK

    WITH PROTECTION (our code in services.py):
        note.tags.set(Tag.objects.filter(id__in=tag_ids, user=user))
        → filter(user=user) blocks other users' tags
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)   # ← the other user's tag was not attached
```

---

## Testing transactional logic

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Business rule: a user has ONLY ONE default notebook.

    The code in services.py:
        with transaction.atomic():
            if is_default:
                Notebook.objects.filter(user=user, is_default=True)
                                .update(is_default=False)   ← RESET the old one
            return Notebook.objects.create(..., is_default=is_default)  ← CREATE the new one

    If you remove the .update() line → two notebooks with is_default=True
    → the note form picks the "first" one → unpredictable behavior

    This test will catch it IMMEDIATELY.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)

    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()       # ← read the fresh state of the old notebook
    self.assertFalse(old.is_default)  # the old one was reset ✓
    self.assertTrue(new.is_default)   # the new one was set ✓
```

---

## Testing isolation between users

```python
def test_create_notebook_default_does_not_affect_other_users(self):
    """
    A critical test for a multi-user system.

    BUGGY CODE (doesn't filter by user):
        Notebook.objects.filter(is_default=True).update(is_default=False)
        ↑ Resets the default FOR ALL USERS! Bob loses his default.

    CORRECT CODE:
        Notebook.objects.filter(user=user, is_default=True).update(...)
        ↑ Resets only for the specific user. Bob is safe.
    """
    alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
    bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

    # Alice creates another default:
    services.create_notebook(user=self.alice, title='Alice2', is_default=True)

    bob_nb.refresh_from_db()
    self.assertTrue(bob_nb.is_default)   # Bob's default was not touched ✓
```

---

## Testing the (True/False, message) pattern

```python
def test_add_user_to_group_duplicate_returns_false(self):
    """
    add_user_to_group() returns (bool, message).
    On a duplicate → (False, 'bob вже є членом').

    Why check twice? The function could return (True, '') but not add the user,
    or add the user but return (False, ''). We check both aspects.
    """
    group = services.create_group(name='Team', creator=self.alice)
    services.add_user_to_group(group, self.bob.username)   # first time ✓

    ok, message = services.add_user_to_group(group, self.bob.username)  # second time

    self.assertFalse(ok)                       # ← the function returned False
    self.assertIn('вже є членом', message)     # ← the message contains the text
    self.assertEqual(group.user_set.count(), 2) # ← the database didn't change (alice + bob, not 3)
```

---

## Full test_services.py code

```python
# notes_app/tests/test_services.py
from django.contrib.auth.models import Group, User
from django.test import TestCase

from notes_app import services
from notes_app.models import Note, Notebook, Tag, TodoList


class BaseServiceTest(TestCase):
    """
    Base class for all service tests.
    All subclasses automatically get self.alice and self.bob.
    """
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)

    def test_create_note_returns_note_object(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertIsInstance(note, Note)

    def test_create_note_saves_to_database(self):
        services.create_note(user=self.alice, title='Test')
        self.assertEqual(Note.objects.count(), 1)

    def test_create_note_assigns_tags(self):
        tag1 = Tag.objects.create(user=self.alice, name='work')
        tag2 = Tag.objects.create(user=self.alice, name='python')

        note = services.create_note(
            user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
        )

        note_tags = list(note.tags.all())
        self.assertIn(tag1, note_tags)
        self.assertIn(tag2, note_tags)

    def test_create_note_ignores_other_users_tags(self):
        """
        Attack: the attacker sends POST /notes/new/ with a tag_id that belongs to Bob.
        Protection: filter(id__in=tag_ids, user=user) blocks other users' tags.
        """
        bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

        note = services.create_note(
            user=self.alice, title='Note', tag_ids=[bob_tag.id]
        )

        self.assertEqual(note.tags.count(), 0)

    def test_toggle_pin_note_persisted_in_db(self):
        """We check that the change is saved to the database, not only in memory."""
        note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
        services.toggle_pin_note(note)

        note_from_db = Note.objects.get(pk=note.pk)
        self.assertTrue(note_from_db.is_pinned)


class NotebookServiceTest(BaseServiceTest):

    def setUp(self):
        super().setUp()   # ← REQUIRED! Call the parent class setUp

    def test_create_notebook_returns_notebook(self):
        nb = services.create_notebook(user=self.alice, title='Work')
        self.assertIsInstance(nb, Notebook)

    def test_create_notebook_default_unsets_previous_default(self):
        """Business rule: a user has ONLY ONE default notebook."""
        old = services.create_notebook(user=self.alice, title='Old', is_default=True)
        new = services.create_notebook(user=self.alice, title='New', is_default=True)

        old.refresh_from_db()
        self.assertFalse(old.is_default)
        self.assertTrue(new.is_default)

    def test_create_notebook_default_does_not_affect_other_users(self):
        """The invariant is reset for only ONE user."""
        alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
        bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

        services.create_notebook(user=self.alice, title='Alice2', is_default=True)

        bob_nb.refresh_from_db()
        self.assertTrue(bob_nb.is_default)


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
        services.add_user_to_group(group, self.bob.username)      # first time ✓
        ok, msg = services.add_user_to_group(group, self.bob.username)  # second time

        self.assertFalse(ok)
        self.assertIn('вже є членом', msg)

    def test_delete_group_sets_note_group_to_null(self):
        """Deleting a group → Note.group = NULL (SET_NULL)."""
        group = services.create_group(name='Fam', creator=self.alice)
        note  = Note.objects.create(user=self.alice, title='Family note', group=group)

        services.delete_group(group)

        note.refresh_from_db()
        self.assertIsNone(note.group)
```

---

## Running the service tests

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_services -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_services -v 2

# A specific test:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_services.NoteServiceTest.test_create_note_sets_correct_user -v 2
```

---

## Next

- **[test_forms.py](test_forms.md)** — bound/unbound forms, queryset security, cleaned_data
