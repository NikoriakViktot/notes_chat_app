# Part IV. Forms and Validation

A form is a trust boundary: user input becomes safe only after server-side validation. Never trust data from the browser without checking it.

**Prerequisites:** Part III (Models).
**Level:** Intermediate.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [Django Forms](django_forms_full.md) | `Form`, `ModelForm`, `clean_<field>()`, `ValidationError`, the PRG pattern, CSRF |
| [Crispy Forms](crispy_forms_full.md) | `FormHelper`, `Layout`, Bootstrap 5 rendering, `{{ form\|crispy }}` |

---

## Key concepts

**Form validation pipeline:**

```
Browser POST
  → Django CsrfViewMiddleware (checks csrfmiddlewaretoken)
  → view: form = NoteForm(request.POST, user=request.user)
  → form.is_valid()
      → field-level validation (required, max_length, ...)
      → clean_<field>() — custom check
      → clean() — cross-field validation
  → if valid: form.cleaned_data → service → redirect
  → if invalid: form with errors → render
```

**ModelForm:**

```python
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'group']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        # restrict the choices: only the user's own notebooks and tags
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset     = Tag.objects.filter(user=user)

    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title.strip()) < 3:
            raise forms.ValidationError("Заголовок занадто короткий (мінімум 3 символи).")
        return title.strip()
```

**PRG — Post/Redirect/Get:**

```text
POST /notes/new/  →  create note  →  302 redirect /notes/42/
                                          ↓
                                    GET /notes/42/  →  200 OK

Without PRG: F5 after POST → the form is resubmitted (duplicate record).
With PRG: F5 after GET → a safe page reload.
```

**CSRF:**

```python
# REQUIRED in the template:
<form method="post">
    {% csrf_token %}   ← generates a hidden input with the token
    {{ form|crispy }}
    <button type="submit">Зберегти</button>
</form>

# CsrfViewMiddleware rejects a POST without a valid token
```

**Crispy Forms:**

```python
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit, Row, Column

class NoteForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            'title',
            Row(Column('priority', css_class='col-md-4'),
                Column('notebook', css_class='col-md-8')),
            'content',
            'tags',
            Submit('submit', 'Зберегти', css_class='btn btn-primary'),
        )
```

---

## Where this is in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_app/forms.py` | `NoteForm`, `NotebookForm`, `TagForm`, `GroupCreateForm`, `TodoListForm` |
| `notes_app/views.py` | `form.is_valid()` → `services.*` → `redirect()` |
| `notes_app/tests/test_forms.py` | tests for valid data, invalid data, `clean_*` |
| `templates/notes_app/note_form.html` | `{% csrf_token %}`, `{{ form\|crispy }}` |

---

## How it connects to the rest of the course

```text
Part IV: Form.is_valid() → cleaned_data
  → Part VI: service.create_note(**cleaned_data)  (mutation)
  → Part VIII: test_forms.py (form unit tests)

CSRF (Part IV) → Part VII: security (Cross-Site Request Forgery)
```

**Zero to Hero:** Step 4 (crispy_notes) — the first `ModelForm` and `crispy`.

**Lab:** [Forms Lab](../labs/forms_lab.md) — write a form with custom validation and a test for invalid data.

---

## Review questions

- What is a trust boundary in the context of forms? Why can't you trust `request.POST` directly?
- What is the difference between `Form` and `ModelForm`?
- What is a CSRF attack? How does `{% csrf_token %}` protect against it?
- What is the PRG pattern and why is it needed?
- When should you use `clean_<field>()`, and when `clean()`?
- Why does `ModelForm.__init__` accept `user` — what does that give us?
- Why is `form.cleaned_data` available only after `is_valid()` → `True`?

---

**Next →** [Part V. Templates and Frontend](../05_frontend_and_templates/README.md) — how the response is rendered into HTML.
