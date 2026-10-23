# Forms Evolution

> Three levels of form evolution — from "it just works" to "beautiful and without duplication".
> The very same `NoteForm` is rendered differently depending on the approach.
> The difference is only in the **presentation** layer — the business logic (`services.create_note()`) does not change.

---

## Why learn three levels

Django forms solve **two independent tasks**:

1. **Input validation** — check that `title` is not empty and that `priority` is within the allowed range
2. **HTML rendering** — display fields, labels and errors in the browser

The three Tiers differ only in rendering (item 2). Validation (`is_valid()`, `cleaned_data`) is the same in all three.

| Tier | Method | Lines of HTML | Where the Bootstrap classes live |
|------|-------|------------|--------------------|
| **1 — Raw** | `{{ form.as_p }}` | ~5 | Nowhere (no styles) |
| **2 — Manual** | Hand-written HTML | ~80 | In the template, by hand |
| **3 — Crispy** | `{% crispy form %}` | **1** | In `forms.py` via Layout |

All three approaches pass **the same** `NoteForm`. The only difference is how it is rendered.

---

## A form as a Python class: anatomy of NoteForm

Before going through the levels, understand what `NoteForm` is.

```python
# notes_app/forms.py
from django import forms
from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

        # Meta.widgets — configure the HTML attributes of the fields.
        # This applies to Tier 2. For Tier 3 (Crispy) — similar, but via Layout.
        widgets = {
            'title': forms.TextInput(attrs={
                'class': 'form-control',      # Bootstrap: border, padding, focus ring
                'placeholder': 'Назва нотатки...',
                'autofocus': True,            # the browser focuses this field automatically
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 8,                    # textarea height in rows
            }),
            'priority': forms.Select(attrs={
                'class': 'form-select',       # Bootstrap: style for <select>
            }),
            'notebook': forms.Select(attrs={
                'class': 'form-select',
            }),
            'is_pinned': forms.CheckboxInput(attrs={
                'class': 'form-check-input',  # Bootstrap: checkbox style
            }),
        }

        labels = {
            'title':    'Заголовок',
            'content':  'Текст нотатки',
            'priority': 'Пріоритет',
            'notebook': 'Записник',
            'tags':     'Теги',
            'is_pinned': 'Закріпити',
        }

        help_texts = {
            'notebook': 'Залиш порожнім — нотатка буде без записника.',
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        # Filter choices by user — so that Alice cannot see Bob's notebooks
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
```

**Key components:**

| Component | Role |
|-----------|------|
| `Meta.model` | Which Django model — fields, types and validators come from here |
| `Meta.fields` | Which fields to include in the form (order matters) |
| `Meta.widgets` | How to render the HTML — class, placeholder, attributes |
| `Meta.labels` | The `<label>` text for each field |
| `Meta.help_texts` | A hint below the field (`<div class="form-text">`) |
| `__init__(user=)` | Custom queryset filtering by the current user |

---

## Tier 1: Raw Django — `{{ form.as_p }}`

> **Why:** The fastest way to display a form. Useful for debugging and prototypes. Validation works fully — only the appearance is minimal.

```python
# views.py
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect
from . import forms, services


@login_required
def note_create_raw(request):
    if request.method == 'POST':
        form = forms.NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', 2),
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.pk for t in form.cleaned_data.get('tags', [])],
                is_pinned=form.cleaned_data.get('is_pinned', False),
            )
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = forms.NoteForm(user=request.user)

    return render(request, 'notes_app/note_form_raw.html', {'form': form})
```

```html
<!-- templates/notes_app/note_form_raw.html -->
{% extends 'base.html' %}
{% block content %}

<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit" class="btn btn-primary">Зберегти</button>
</form>

{% endblock %}
```

**What `as_p` generates for the `title` field:**

```html
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" maxlength="200" required id="id_title">
</p>
```

Notice: **not a single** `class="form-control"`. No Bootstrap styles at all. The form looks like bare HTML. Django validation **works fully** — `is_valid()`, `cleaned_data`, errors — but the errors are also displayed without styles:

```html
<!-- On a validation error, as_p adds an ErrorList before the field: -->
<ul class="errorlist">
  <li>Це поле обов'язкове.</li>
</ul>
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" ...>
</p>
```

**When to use Tier 1:**
- Debugging and testing a form
- Internal admin tools where appearance does not matter
- **Never** in production for end users

---

## Tier 2: Manual Bootstrap HTML

> **Why:** Full control over the HTML markup. Lets you place fields in a Bootstrap Grid and add icons and custom hints. Expensive to maintain — every new field = adding it to the template by hand.

### forms.py — widget attrs for Tier 2

Django renders a field through its `Widget`. To add a Bootstrap class to the `<input>`, you need to pass it through `widget.attrs`:

```python
# Approach 1: via Meta.widgets (static attributes)
class Meta:
    widgets = {
        'title': forms.TextInput(attrs={'class': 'form-control'}),
    }

# Approach 2: via __init__ (dynamic attributes)
def __init__(self, *args, **kwargs):
    super().__init__(*args, **kwargs)
    self.fields['title'].widget.attrs.update({'class': 'form-control'})
```

Both approaches give the same result. The `Meta.widgets` approach is cleaner for static attributes. `__init__` is needed when an attribute depends on runtime data.

| Bootstrap class | HTML element | Effect |
|----------------|-------------|-------|
| `form-control` | `<input>`, `<textarea>` | Full width, border, padding, focus ring |
| `form-select` | `<select>` | Dropdown arrow, padding, border |
| `form-check-input` | `<input type="checkbox">` | Custom checkbox style |

### Anatomy of a BoundField in a template

`form.title` in a template is a `BoundField`: an object that knows the field + the current value + the form.

| Expression | Type | Example value |
|-------|-----|-----------------|
| `{{ form.title }}` | str (HTML) | `<input type="text" name="title" class="form-control" ...>` |
| `{{ form.title.id_for_label }}` | str | `'id_title'` |
| `{{ form.title.label }}` | str | `'Заголовок'` |
| `{{ form.title.help_text }}` | str | `'Залиш порожнім...'` |
| `{{ form.title.html_name }}` | str | `'title'` |
| `{{ form.title.errors }}` | ErrorList | `['Це поле обов'язкове.']` |
| `{% if form.title.errors %}` | bool | `True` / `False` |
| `form.title.value()` | str | `'Назва нотатки'` |

### Full template for a single field

```html
<!-- templates/notes_app/note_form.html — rendering the title field by hand -->

<div class="mb-3">
    <!--
      .id_for_label → 'id_title'
      Clicking <label for="id_title"> focuses <input id="id_title"> — standard HTML behavior
    -->
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
        {{ form.title.label }}
        {% if form.title.field.required %}
            <span class="text-danger ms-1">*</span>
        {% endif %}
    </label>

    <!--
      {{ form.title }} → Widget.render() → the full HTML <input> tag
      Attributes (class, placeholder, autofocus) come from Meta.widgets
    -->
    {{ form.title }}

    <!--
      help_text — a hint below the field. Present only if set in Meta.help_texts.
      Not set for title — the block is not shown.
    -->
    {% if form.title.help_text %}
    <div class="form-text text-muted">{{ form.title.help_text }}</div>
    {% endif %}

    <!--
      Validation errors. Empty on GET. Filled in if POST + is_valid() = False.
      Bootstrap: is-invalid + invalid-feedback show a red border and the error text.
    -->
    {% if form.title.errors %}
    {% for error in form.title.errors %}
    <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
    {% endif %}
</div>
```

### Bootstrap Grid in a form

Bootstrap Grid lets you place several fields in one row:

```html
<!--
  row + col-6 + col-6 = 12 Bootstrap Grid columns.
  g-3 = gutter (spacing between columns).
  The priority and notebook fields sit side by side in one row.
-->
<div class="row g-3 mb-3">

    <div class="col-6">
        <label for="{{ form.priority.id_for_label }}" class="form-label">
            {{ form.priority.label }}
        </label>
        {{ form.priority }}
        {% if form.priority.errors %}
        <div class="invalid-feedback d-block">{{ form.priority.errors|join:", " }}</div>
        {% endif %}
    </div>

    <div class="col-6">
        <label for="{{ form.notebook.id_for_label }}" class="form-label">
            {{ form.notebook.label }}
        </label>
        {{ form.notebook }}
        {% if form.notebook.help_text %}
        <div class="form-text">{{ form.notebook.help_text }}</div>
        {% endif %}
        {% if form.notebook.errors %}
        <div class="invalid-feedback d-block">{{ form.notebook.errors|join:", " }}</div>
        {% endif %}
    </div>

</div>
```

### Why `novalidate` on `<form>`

```html
<form method="post" novalidate>
    {% csrf_token %}
    <!-- form fields -->
</form>
```

`novalidate` **disables browser HTML5 validation** (`required`, `minlength`, `type="email"`).

**Why this is right for Django:**
- Browser validation looks different in Chrome, Firefox and Safari — there is no single style
- It does not know about Django-specific rules (`clean_title()`, custom validators)
- Django validates on the server: always the same way, with your own error messages
- After a POST with errors → the template is rendered again with `form.errors` → a single error style

**`{% csrf_token %}`** inserts a hidden input:
```html
<input type="hidden" name="csrfmiddlewaretoken" value="abc123XYZ...">
```
Django rejects a POST without this token with `403 Forbidden`. This is protection against Cross-Site Request Forgery.

### Counting template lines for 5 fields

```
title:     14 lines
priority:  12 lines (select)
notebook:  14 lines (select + queryset)
content:   12 lines (textarea)
tags:      14 lines (multiple select / checkbox group)
is_pinned: 10 lines (checkbox)
buttons:    3 lines
─────────────────
TOTAL:    ~80 lines of HTML just for the form
```

**Tier 2 problems:**
- 80 lines of HTML for just one form
- Adding a field in `models.py` → add it by hand to every form template
- Changing the Bootstrap version → edit every template
- 10 forms in the application = 800 lines of duplication

---

## Tier 3: Crispy Forms — `{% crispy form %}`

> **Why:** Crispy moves all the Bootstrap markup from templates into `forms.py`. The template becomes one line. When you add a field, you edit only the `Layout` in `forms.py`; the template does not change.

### Installation

```bash
# requirements.txt
django-crispy-forms==2.3
crispy-bootstrap5==2024.10
```

```python
# settings.py
INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'
```

### forms.py with FormHelper and Layout

```python
# notes_app/forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Row, Column, Fieldset, Submit, Field

from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Queryset filtering — independent of the Tier
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)

        # FormHelper — describes the HTML wrapper and the Layout
        self.helper = FormHelper()
        self.helper.form_method = 'post'        # <form method="post">
        self.helper.form_novalidate = True      # novalidate attribute

        self.helper.layout = Layout(
            # Fieldset = <fieldset><legend>Text</legend>...</fieldset>
            Fieldset('Основна інформація',
                # Field() — renders a field with extra HTML attributes
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                # Row + Column = Bootstrap Grid
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
            ),
            Fieldset('Вміст',
                Field('content', rows=8),
                'tags',         # just the field name — rendered with default attributes
                'is_pinned',
            ),
            # Submit = the form's submit button
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary'),
        )
```

### Template — one line

```html
<!-- templates/notes_app/note_form.html -->
{% extends 'base.html' %}
{% load crispy_forms_tags %}

{% block content %}
{% crispy form %}
{% endblock %}
```

**What `{% crispy form %}` generates automatically:**

- `<form method="post" novalidate>` + `{% csrf_token %}`
- `<fieldset><legend>` for every `Fieldset`
- `<div class="row">` + `<div class="col-md-4">` for `Row` + `Column`
- `<div class="mb-3">` for every field
- `<label class="form-label">` with the required asterisk
- `<input class="form-control">` or `<select class="form-select">`
- `<div class="invalid-feedback">` for errors
- `<div class="form-text">` for `help_text`
- `<button type="submit" class="btn btn-primary">`

### Comparing views.py for all three Tiers

```python
# views.py — the VIEW IS THE SAME for all three Tiers!
# Crispy is purely a PRESENTATION layer, not business logic.

@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', 2),
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.pk for t in form.cleaned_data.get('tags', [])],
                is_pinned=form.cleaned_data.get('is_pinned', False),
            )
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(user=request.user)

    return render(request, 'notes_app/note_form.html', {'form': form})
```

The view is the same for Tier 1, 2 and 3. Crispy does not change the business logic. It changes only how the form **looks**.

---

## Debugging: why the form does not validate

### Symptom 1: a POST always shows the form again (never a redirect)

```python
# ❌ CAUSE — `is_valid()` returns False, but you are not displaying the errors
if form.is_valid():
    ...  # ← execution never gets here

# Quick diagnosis — add a print to the view (temporarily):
print("POST data:", request.POST)
print("Form errors:", form.errors)
```

Run the view, send a POST from the browser, and check `form.errors` in the Django console:

```
Form errors: {
    'title': ['Це поле обов'язкове.'],
    'notebook': ['Виберіть правильний варіант. Цього варіанту немає серед доступних.']
}
```

### Symptom 2: `notebook` or `tags` always says "Select a valid choice"

```python
# ❌ CAUSE — during the POST the field's queryset does not contain the submitted pks.
# A typical case: the default queryset is empty,
# and the real one is set only when user is passed:
class NoteForm(forms.ModelForm):
    tags = forms.ModelMultipleChoiceField(queryset=Tag.objects.none(), required=False)

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        if user is not None:
            self.fields['tags'].queryset = Tag.objects.filter(user=user)

form = NoteForm(user=request.user)   # GET  — the choices are visible
form = NoteForm(request.POST)        # POST — user forgotten → queryset = none()
                                     # → every choice is invalid

# ✅ SOLUTION — pass the same user in both GET and POST:
form = NoteForm(request.POST, user=request.user)
#               ↑ data        ↑ custom parameter
```

During validation, `ModelChoiceField` / `ModelMultipleChoiceField` checks that the submitted pk is in `field.queryset` **at the time of the POST**. If the POST queryset is narrower than the one the choices were rendered from, you get "Select a valid choice". The opposite situation is more dangerous because it is silent: without a filter in `__init__` the queryset is `Tag.objects.all()` — validation accepts the pk of any tag, and Bob can see and attach Alice's tags. Therefore: **always filter the queryset by user and pass `user` in both branches of the view**.

### Symptom 3: CSRF 403 Forbidden

```
Forbidden (403)
CSRF verification failed. Request aborted.
```

**Cause:** the template does not contain `{% csrf_token %}`.

```html
<!-- ✅ REQUIRED in every form with method="post" -->
<form method="post">
    {% csrf_token %}
    {{ form.as_p }}
</form>
```

For Crispy: `{% crispy form %}` adds the CSRF token automatically.

### Symptom 4: `'NoneType' object has no attribute` on GET

```
AttributeError: 'NoneType' object has no attribute 'tags'
```

```python
# ❌ CAUSE — user=None, and __init__ has no protection against None
form = NoteForm()   # user not passed → user=None

def __init__(self, *args, user=None, **kwargs):
    super().__init__(*args, **kwargs)
    self.fields['tags'].queryset = user.tags.all()   # None.tags → AttributeError

# ✅ Protection in __init__ — the if user is not None check:
def __init__(self, *args, user=None, **kwargs):
    super().__init__(*args, **kwargs)
    if user is not None:           # ← protection against None
        self.fields['tags'].queryset = Tag.objects.filter(user=user)

# ✅ For authenticated views there is always request.user:
form = NoteForm(user=request.user)
```

### Checking the form in the Django shell

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.forms import NoteForm

user = User.objects.get(username='demo_alice')

# Simulate a GET (empty form)
form = NoteForm(user=user)
print(form.fields['tags'].queryset)   # → QuerySet[Tag] for alice only

# Simulate a POST with invalid data
data = {'title': '', 'priority': '2'}  # title is empty
form = NoteForm(data, user=user)
print(form.is_valid())   # → False
print(form.errors)       # → {'title': ['Це поле обов'язкове.']}

# Simulate a valid POST
data = {'title': 'Тестова нотатка', 'priority': '2', 'tags': []}
form = NoteForm(data, user=user)
print(form.is_valid())          # → True
print(form.cleaned_data)        # → {'title': 'Тестова нотатка', 'priority': 2, ...}
```

---

## Common mistakes

| Mistake | Symptom | Solution |
|---------|---------|---------|
| No `{% csrf_token %}` | `403 Forbidden` on POST | Add `{% csrf_token %}` inside the `<form>` |
| `user=` not passed | Choices include other users' objects | `NoteForm(request.POST, user=request.user)` |
| `method="get"` instead of `"post"` | Data ends up in the URL, the form is not processed | `<form method="post">` |
| `if request.method == 'GET':` instead of `'POST':` | The form is never processed | Check the condition in the view |
| CRISPY_TEMPLATE_PACK is not set | `TemplateDoesNotExist: bootstrap5/uni_form.html` | Add `CRISPY_TEMPLATE_PACK = 'bootstrap5'` to settings.py |
| Forgot `{% load crispy_forms_tags %}` | `Invalid block tag: 'crispy'` | Add `{% load %}` to the template |

---

## In the book

- [Part IV. Forms and validation](../../04_forms_and_validation/README.md) — `ModelForm`, `clean_*` methods, custom validators, `ValidationError`, forms for M:N fields
- [Part V. Frontend and templates](../../05_frontend_and_templates/README.md) — Bootstrap Grid, template tags, `{% load %}`, filters

---

## Official documentation

- [Django: Forms](https://docs.djangoproject.com/en/5.2/topics/forms/) — the full form cycle
- [Django: ModelForm](https://docs.djangoproject.com/en/5.2/topics/forms/modelforms/) — `Meta.widgets`, `Meta.labels`, `__init__`
- [Django: BoundField](https://docs.djangoproject.com/en/5.2/ref/forms/api/#django.forms.BoundField) — all the attributes available in a template
- [Django: CSRF](https://docs.djangoproject.com/en/5.2/ref/csrf/) — how CSRF protection works
- [django-crispy-forms: docs](https://django-crispy-forms.readthedocs.io/en/latest/) — FormHelper, Layout, Field, Row, Column
- [crispy-bootstrap5: docs](https://crispy-bootstrap5.readthedocs.io/en/latest/) — the Bootstrap 5 package for crispy-forms
- [Bootstrap: Forms](https://getbootstrap.com/docs/5.3/forms/overview/) — `form-control`, `form-select`, `form-check`, `invalid-feedback`
