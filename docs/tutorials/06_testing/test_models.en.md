# test_models.py — Testing models

---

## What lives in a model (and what can break)

> **Question:** Why test models? They are just fields and relations.
>
> **Answer:** A model contains business rules. If they are violated, the application silently misbehaves.

```
Note model
  ├── priority: validators=[MinValueValidator(1), MaxValueValidator(4)]
  │     If someone removes the validators → the form will accept priority=99
  │     → Priority display will break (KeyError in PRIORITY_CHOICES)
  │
  ├── group: ForeignKey(Group, on_delete=SET_NULL)
  │     If changed to CASCADE → deleting a group will delete all notes!
  │     → Users lose data, and you find out in production
  │
  ├── notebook: ForeignKey(Notebook, on_delete=SET_NULL)
  │     If CASCADE → deleting a notebook deletes its notes
  │
  ├── is_pinned: BooleanField(default=False)
  │     If the default becomes True → all new notes become pinned
  │     → Sorting breaks
  │
  ├── __str__: "📌 {title}" or "{title}"
  │     If the format changes → Django Admin and logs display it incorrectly
  │
  └── Tag: UniqueConstraint(fields=['user', 'name'])
        If removed → two 'python' tags for one user → bugs in forms
```

---

## Structure of the tests/ package

```
notes_app/
├── models.py
├── views.py
├── forms.py
├── services.py
├── selectors.py
├── consumers.py
└── tests/                          ← a package (a directory with __init__.py)
    ├── __init__.py                  ← REQUIRED! Empty.
    │                                  Without it Django won't find the tests → "Found 0 test(s)"
    ├── test_models.py               ← Unit: constraints, __str__, SET_NULL
    ├── test_services.py             ← Unit: business logic, security
    ├── test_forms.py                ← Unit: validation, queryset filtering
    ├── test_views.py                ← Integration: HTTP, ownership, redirects
    ├── test_consumers.py            ← Consumer: WebSocket lifecycle
    └── test_selenium.py             ← E2E: browser
```

**Why a `tests/` package and not a single `tests.py`?**

```
# Option 1: a single tests.py file
notes_app/tests.py   ← everything in one place → grows to 3000+ lines, hard to navigate

# Option 2: a tests/ package (our option)
notes_app/tests/
    test_models.py    ← models only
    test_services.py  ← services only
    test_forms.py     ← forms only
    test_views.py     ← integration
    test_consumers.py ← WebSocket
    test_selenium.py  ← E2E
```

Advantages:
- Run them separately: `manage.py test notes_app.tests.test_services`
- Each file = one layer of the system → easy to find a test
- CI can run different files in parallel

---

## How to test validators with `full_clean()`

```python
# IMPORTANT: validators do not run on .save() or .objects.create()!
# They run only through full_clean() or a ModelForm.

# WRONG (validators won't be checked):
note = Note.objects.create(user=user, title='Test', priority=5)
# ← Django will simply save priority=5! (validators are ignored)
# ← A CheckConstraint in the database might fire → IntegrityError
# ← But validators (MinValueValidator, MaxValueValidator) won't!

# RIGHT — via full_clean():
note = Note(user=user, title='Test', priority=5)  # ← we DON'T save right away
note.full_clean()   # ← validators run here → ValidationError

# full_clean() performs:
# 1. clean_fields()    — field validators (MinValueValidator, MaxValueValidator...)
# 2. clean()           — custom model validation
# 3. validate_unique() — unique / unique_together
# 4. validate_constraints() — Meta.constraints (UniqueConstraint, CheckConstraint)

# In a test:
def test_priority_above_4_raises_validation_error(self):
    note = Note(user=self.user, title='Test', priority=5)
    with self.assertRaises(ValidationError) as ctx:
        note.full_clean()
    self.assertIn('priority', ctx.exception.message_dict)
    #              ↑ we check that the error is exactly in the priority field
```

---

## The SET_NULL test — protection against CASCADE

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

    note.refresh_from_db()       # ← REQUIRED! read the fresh state from the database
    self.assertIsNone(note.group)# the note survived, group = NULL
```

> **Why `refresh_from_db()`?** After `group.delete()` the `note` object in memory
> still holds the old reference. `refresh_from_db()` re-reads it from the database.

---

## Full test_models.py code (notes_chat_app)

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
        """Different users can have tags with the same name."""
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
        """Deleting a notebook → its notes are left without a notebook (not deleted)."""
        nb   = Notebook.objects.create(user=self.alice, title='Work')
        note = Note.objects.create(user=self.alice, title='Work note', notebook=nb)

        nb.delete()

        note.refresh_from_db()
        self.assertIsNone(note.notebook)   # SET_NULL on the notebook FK ✓

    # ── __str__ ────────────────────────────────────────────────────────────

    def test_str_pinned_note_has_pin_emoji(self):
        note = Note.objects.create(user=self.alice, title='Important', is_pinned=True)
        self.assertEqual(str(note), '📌 Important')

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
    """Specific to notes_chat_app: ChatMessage and GROUP CASCADE."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.group = Group.objects.create(name='Team')

    def test_chat_message_cleared_when_group_deleted(self):
        """
        ChatMessage.group = FK(Group, CASCADE):
        Deleting the group → all chat messages are deleted.
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
        Deleting a user → all their messages are deleted along with them.
        """
        ChatMessage.objects.create(
            group=self.group, author=self.alice, content='I will be deleted'
        )
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.alice.delete()

        # CASCADE: the message was deleted along with its author
        self.assertEqual(ChatMessage.objects.count(), 0)
```

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

## Running the model tests

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_models -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2
```

---

## Next

- **[test_services.py](test_services.md)** — business logic, persistence, security, transactions
