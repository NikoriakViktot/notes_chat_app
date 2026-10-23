# test_forms.py — Testing forms

---

## Two form modes: bound vs unbound

> **A Django form is not just HTML.** It is validation, normalization and a security barrier.

```python
# UNBOUND form — without data (for displaying an empty form)
form = NoteForm(user=self.alice)
# form.is_bound → False
# Useful for testing queryset fields (security)

# BOUND form — with data (for processing a POST request)
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
# form.is_bound → True
# You can call form.is_valid(), form.cleaned_data, form.errors
```

### How to test a form without HTTP

```python
# A form can be tested directly, without client.post():

form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)

# Checking validity:
form.is_valid()              # True or False — this is what we check
form.cleaned_data['name']   # 'python' — the normalized value
form.errors                  # {'name': ['...']} — errors per field

# Checking a valid form:
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
# ↑ msg=form.errors — if it fails, we'll see WHY it is invalid

# Checking an invalid form:
form = NoteForm(data={'title': '', 'priority': 1}, user=self.alice)
self.assertFalse(form.is_valid())
self.assertIn('title', form.errors)
# ↑ We check that the error is in a SPECIFIC field (not a general one)
```

---

## Structure of test_forms.py

```python
# notes_app/tests/test_forms.py
from django.contrib.auth.models import Group, User
from django.test import TestCase

from notes_app.forms import GroupCreateForm, NoteForm, TagForm
from notes_app.models import Notebook, Tag


class BaseFormTest(TestCase):
    """Base class: alice and bob for security tests."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class TagFormTest(BaseFormTest):
    """Tests for TagForm normalization and basic validation."""

    def test_name_normalized_to_lowercase(self):
        """The tag name is stored in lowercase."""
        form = TagForm(data={'name': 'PYTHON', 'color': '#3776AB'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'python')

    def test_name_strips_whitespace(self):
        """'  work  ' → 'work' (leading/trailing spaces are removed)."""
        form = TagForm(data={'name': '  work  ', 'color': '#ff0000'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'work')

    def test_empty_name_is_invalid(self):
        form = TagForm(data={'name': '', 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
        self.assertIn('name', form.errors)

    def test_name_too_long_is_invalid(self):
        form = TagForm(data={'name': 'x' * 51, 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
```

---

## NoteFormSecurityTest — the full security block

```python
class NoteFormSecurityTest(BaseFormTest):
    """
    The most important block of form tests — we check that the queryset
    filters only the current user's objects (protection against IDOR).
    """

    def setUp(self):
        super().setUp()
        # Both users have their own notebooks
        self.alice_notebook = Notebook.objects.create(user=self.alice, title="Alice's")
        self.bob_notebook   = Notebook.objects.create(user=self.bob,   title="Bob's")
        # Alice has a tag
        self.alice_tag = Tag.objects.create(user=self.alice, name='my-tag')
        self.bob_tag   = Tag.objects.create(user=self.bob,   name='bob-secret')

    def test_notebook_queryset_contains_user_notebooks(self):
        """Alice sees HER notebook in the dropdown."""
        form = NoteForm(user=self.alice)
        self.assertIn(self.alice_notebook, form.fields['notebook'].queryset)

    def test_notebook_queryset_excludes_other_user_notebooks(self):
        """
        Alice does NOT see Bob's notebooks — IDOR is impossible.

        WITHOUT protection in the form:
            NoteForm().fields['notebook'].queryset = Notebook.objects.all()
            → Alice sees Bob's Private Notebook in the dropdown!
            → Alice picks Bob's notebook → Alice's note is written into Bob's
            → Bob sees someone else's notes in his notebook → DATA LEAK

        With protection (our NoteForm.__init__):
            queryset = Notebook.objects.filter(user=self.user)
            → Alice sees only her own notebooks → IDOR is impossible
        """
        form = NoteForm(user=self.alice)
        self.assertNotIn(self.bob_notebook, form.fields['notebook'].queryset)

    def test_tag_queryset_contains_user_tags(self):
        """Alice sees her tags in the dropdown."""
        form = NoteForm(user=self.alice)
        self.assertIn(self.alice_tag, form.fields['tags'].queryset)

    def test_tag_queryset_excludes_other_user_tags(self):
        """Alice does NOT see Bob's tags."""
        form = NoteForm(user=self.alice)
        self.assertNotIn(self.bob_tag, form.fields['tags'].queryset)

    def test_group_queryset_excludes_groups_user_not_in(self):
        """Alice doesn't see groups she is not a member of."""
        group = Group.objects.create(name="Bob's Team")
        self.bob.groups.add(group)        # only Bob is in the group

        form = NoteForm(user=self.alice)
        self.assertNotIn(group, form.fields['group'].queryset)

    def test_form_without_user_has_empty_querysets(self):
        """
        If the form is created without user= (a developer mistake):
            form = NoteForm(data=request.POST)  ← forgot user=request.user

        DANGEROUS: queryset = Notebook.objects.all() → all notebooks are visible
        SAFE (our code): queryset = Notebook.objects.none() → an empty list

        Better to show the user an empty dropdown than to leak all the data.
        """
        form = NoteForm()  # user not passed
        self.assertFalse(form.fields['notebook'].queryset.exists())
        self.assertFalse(form.fields['tags'].queryset.exists())
```

---

## Checking cleaned_data (normalization)

```python
class NoteFormValidationTest(BaseFormTest):

    def test_valid_form_with_required_fields(self):
        """The minimum required fields → the form is valid."""
        form = NoteForm(
            data={'title': 'My Note', 'priority': 1},
            user=self.alice,
        )
        self.assertTrue(form.is_valid(), msg=form.errors)

    def test_empty_title_is_invalid(self):
        """An empty title → ValidationError for the title field."""
        form = NoteForm(
            data={'title': '', 'priority': 1},
            user=self.alice,
        )
        self.assertFalse(form.is_valid())
        self.assertIn('title', form.errors)

    def test_priority_valid_range(self):
        """Priority from 1 to 4 is valid."""
        for p in [1, 2, 3, 4]:
            form = NoteForm(data={'title': 'Test', 'priority': p}, user=self.alice)
            self.assertTrue(form.is_valid(), msg=f'priority={p} should be valid')
```

---

## Checking errors in a specific field

```python
def test_specific_field_error(self):
    """We check that the error is in a SPECIFIC field, not a general one."""
    form = NoteForm(data={'title': '', 'priority': 99}, user=self.alice)
    self.assertFalse(form.is_valid())

    # Check a specific field:
    self.assertIn('title', form.errors)      # title: empty → required
    # or:
    self.assertIn('priority', form.errors)   # priority: 99 → out of range

    # We do NOT check only form.errors (there may be errors in all fields)
    # We check that it is exactly in the field we need
```

---

## Table: what we check in each form

| Form | What we test |
|-------|-------------|
| `TagForm` | `clean_name`: lowercase + strip, empty name → error |
| `NoteForm` | the queryset for notebook/tags/group is filtered by user |
| `NoteForm` | without user= → empty querysets (a safe fallback) |
| `NoteForm` | empty title → invalid, priority 1–4 → valid |
| `GroupCreateForm` | `clean_name`: duplicate → ValidationError, strip whitespace |

---

## Running the form tests

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_forms -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_forms -v 2

# A specific class:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_forms.NoteFormSecurityTest -v 2
```

---

## Next

- **[test_views.py](test_views.md)** — Test Client, force_login, three patterns, the access diagram
