# Forms Lab — Form validation and security

**Goal:** understand how Django Forms protect against invalid and malicious input, and learn to write custom validation and scoped querysets.

**Related files:** `notes_app/forms.py`, `notes_app/tests/test_forms.py`.

---

## Part 1 — Take apart `NoteForm`

Open `notes_app/forms.py` and find `class NoteForm(forms.ModelForm)`.

```python
class NoteForm(forms.ModelForm):
    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
            self.fields['group'].queryset = user.groups.all()
        else:
            self.fields['notebook'].queryset = Notebook.objects.none()
            self.fields['tags'].queryset = Tag.objects.none()
            self.fields['group'].queryset = Group.objects.none()
```

**Questions:**

1. What happens if you do not filter the queryset by `user`? What is the security threat?
2. Why `Notebook.objects.none()` instead of an empty list?
3. Why is `user` passed as a keyword-only argument (`*args, user=None`)?

**Answer to question 1:** without filtering, a student can put the `notebook_id` of someone else's notebook into the HTML request. By default Django accepts any existing pk, so without a scoped queryset this is IDOR through a form.

---

## Part 2 — Take apart `TagForm.clean_name()`

```python
class TagForm(forms.ModelForm):
    def clean_name(self):
        name = self.cleaned_data['name'].strip().lower()
        ...
```

**Task:** find the full implementation of `clean_name()` in `forms.py`. Determine:

- what `clean_name` checks;
- whether tag uniqueness per user is defined at the model level (`unique_together`) or only in the form;
- what happens if you remove `clean_name` and try to create two identical tags.

---

## Part 3 — Write a test for the scoped queryset

Goal: make sure `NoteForm` does not show another user's notebooks.

```python
# Add to notes_app/tests/test_forms.py
from django.test import TestCase
from django.contrib.auth.models import User
from notes_app.forms import NoteForm
from notes_app.models import Notebook

class NoteFormQuerysetScopeTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pw')
        self.bob = User.objects.create_user('bob', password='pw')
        self.alice_nb = Notebook.objects.create(user=self.alice, title="Alice NB")
        self.bob_nb = Notebook.objects.create(user=self.bob, title="Bob NB")

    def test_notebook_queryset_scoped_to_user(self):
        form = NoteForm(user=self.alice)
        notebook_qs = form.fields['notebook'].queryset
        self.assertIn(self.alice_nb, notebook_qs)
        self.assertNotIn(self.bob_nb, notebook_qs)

    def test_notebook_queryset_empty_without_user(self):
        form = NoteForm()
        self.assertEqual(form.fields['notebook'].queryset.count(), 0)
```

Run it:

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_forms -v 2
```

---

## Part 4 — Add your own validation

**Task:** add a `clean_title()` method to `NoteForm` that:

1. Strips spaces at the beginning and end.
2. Rejects titles shorter than 3 characters.
3. Rejects titles that start with `http://` or `https://`.

```python
def clean_title(self):
    title = self.cleaned_data['title'].strip()
    if len(title) < 3:
        raise forms.ValidationError("The title must be at least 3 characters long.")
    if title.lower().startswith(('http://', 'https://')):
        raise forms.ValidationError("The title cannot be a URL.")
    return title
```

Write a test that checks all three cases (short title, URL title, valid title).

**Criterion:** `form.is_valid()` returns `False` for invalid titles and `True` for valid ones.

---

## Part 5 — `ShareForm`

`forms.py` contains `ShareForm`, a form for sharing an object with another user by email/username.

**Task:**

1. Find `class ShareForm` in `forms.py`.
2. Determine which field it validates and where the User lookup happens.
3. Write a test: pass the username of a non-existent user; the form must return an error, not raise an exception.

---

## Summary

| Pattern | Where in the code |
|--------|-----------|
| Scoped queryset (only your own objects) | `NoteForm.__init__` |
| `clean_<field>()` — field-level validation | `TagForm.clean_name()` |
| Queryset security (IDOR through a form) | `NoteForm` — notebook, tags, group |
| Form without a user → queryset = none() | `NoteForm.__init__` fallback |

---

## Evaluate and choose (analysis and evaluation level)

### Q.1. Where is it more correct to check tag uniqueness: in the form or in the model?

```python
# Option A: only in the form's clean_name()
class TagForm(forms.ModelForm):
    def clean_name(self):
        # duplicate check here
        ...

# Option B: unique_together at the model level
class Tag(models.Model):
    class Meta:
        unique_together = [('user', 'name')]
```

**Evaluate:**
- What happens with Option A if someone bypasses the form and calls `Tag.objects.create(...)` directly with a duplicate?
- What happens with Option B if the form has no `try/except IntegrityError`?
- Find in `notes_app/models.py` which option (or both) is implemented.
- Formulate a rule: where should validation live, in the model or in the form? When do you need both?

---

### Q.2. `ModelForm` vs `Form`: when to choose which?

Notes Chat App uses `ModelForm` for most forms.

**Evaluate:**
- Find a form in `forms.py` that is **not** a `ModelForm`. Why is it not a ModelForm?
- When is `Form` (without a Model) the right choice?
- What would it cost to rewrite `ShareForm` as a `ModelForm`? What would get more complicated?
- Formulate a criterion: "I choose `ModelForm` when..., and `Form` when..."

---

### Q.3. Validation in the form vs validation in the service

```python
# Approach A: validation in the form's clean_title()
class NoteForm(forms.ModelForm):
    def clean_title(self):
        title = self.cleaned_data['title'].strip()
        if len(title) < 3:
            raise ValidationError("Title is too short.")
        return title

# Approach B: validation in the service
def create_note(user, title, content, ...):
    if len(title.strip()) < 3:
        raise ValueError("Title is too short.")
    ...
```

**Evaluate:**
- What happens if an API endpoint or a management command calls `create_note` directly (without the form)?
- Where is `title` validation implemented in Notes Chat App? Find it in `forms.py`.
- When is validation in the service **mandatory**?
- Does Notes Chat App need validation duplicated in both the form and the service?
