# Crispy Forms

> **FormHelper** is an object attached to a form that describes:
> - The attributes of the `<form>` tag (method, action, id, class)
> - Rendering behavior
> - Layout — the structure and order of fields

---

## FormHelper architecture

```
NoteForm
│
├── fields (Django standard)
│   ├── title     CharField
│   ├── content   TextField
│   └── ...
│
└── helper = FormHelper()          ← crispy adds this
    ├── form_method = 'post'       ← <form method="post">
    ├── form_id = 'note-form'      ← <form id="note-form">
    ├── form_tag = True            ← render <form>...</form>
    └── layout = Layout(...)       ← field structure
        ├── Fieldset(...)          ← <fieldset><legend>
        │   ├── Field('title')     ← a single field with attrs
        │   └── Row(...)           ← <div class="row">
        │       ├── Column(...)    ← <div class="col-md-4">
        │       └── Column(...)    ← <div class="col-md-8">
        ├── Submit(...)            ← <button type="submit">
        └── HTML('<hr>')           ← arbitrary HTML
```

---

## Rendering pipeline

```
{% crispy form %}
     │
     ▼
crispy_forms templatetag
     │  Finds form.helper
     │  Finds form.helper.layout
     ▼
Layout.render(form, context)
     │
     ├── Fieldset.render()
     │   ├── Field('title').render()  → field.html template
     │   └── Row.render()
     │       └── Column.render()
     ├── Submit.render()              → baseinput.html template
     └── HTML.render()               → direct string
     │
     ▼
Bootstrap 5 HTML
(form-control, mb-3, row, col-md-4, invalid-feedback...)
```

---

## Layout object attributes

```python
# kwargs → HTML attributes
Field('title', placeholder='Підказка')   # placeholder="Підказка"
Field('title', autofocus=True)           # autofocus
Field('title', data_custom="val")        # data-custom="val" (underscore → hyphen)
Field('title', css_class="extra")        # extra CSS class
Field('title', type="hidden")            # hidden input

# Wrapping div
Field('title', wrapper_class="mt-3")     # class for <div class="mb-3 mt-3">
```

---

## Where to use crispy vs. hand-written HTML — the rule

| Situation | Approach |
|----------|--------|
| The form takes up a whole page | `{% crispy form %}` — full control through Layout |
| Quick prototype | `{{ form\|crispy }}` — no FormHelper, just Bootstrap styles |
| A single field embedded in a page | `{{ form.title\|as_crispy_field }}` |
| A form without Bootstrap (API, email) | `{{ form.as_p }}` or `form.cleaned_data` directly |

---

## Full `NoteForm` code with FormHelper and Layout

```python
# hello_app/forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import (
    Layout, Submit, Row, Column,
    Fieldset, HTML, Div, Field
)
from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']
        # ↑ NO widget attrs at all — crispy adds Bootstrap classes automatically!

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Security: filter FKs by the current user
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
            self.fields['notebook'].empty_label = '— без записника —'

        # FormHelper — describe the form in Python code
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id = 'note-form'

        # Layout — field structure
        self.helper.layout = Layout(
            # Section 1: main information
            Fieldset('Основна інформація',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
            ),
            # Section 2: content
            Fieldset('Зміст нотатки',
                Field('content', rows=8, placeholder='Текст нотатки...'),
            ),
            # Section 3: tags and options
            Fieldset('Теги та параметри',
                'tags',
                Div(Field('is_pinned'), css_class='form-check mt-2'),
            ),
            # Divider
            HTML('<hr class="my-4">'),
            # Buttons
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
            HTML('<a href="javascript:history.back()" class="btn btn-outline-secondary">Скасувати</a>'),
        )
```

---

## `{% crispy form %}` step by step

```
1. {% load crispy_forms_tags %} — registers the tag

2. {% crispy form %} — calls do_uni_form() in crispy_forms_tags.py

3. Finds form.helper — our FormHelper with its Layout

4. Renders form.helper.layout:
   ├── Fieldset('Основна інформація', ...) →
   │     <fieldset>
   │       <legend>Основна інформація</legend>
   │       ...fields...
   │     </fieldset>
   │
   ├── Field('title', placeholder='...') →
   │     <div class="mb-3">
   │       <label for="id_title" class="form-label">Заголовок *</label>
   │       <input type="text" name="title" id="id_title"
   │              class="form-control" placeholder="Назва нотатки..."
   │              autofocus>
   │     </div>
   │
   ├── Row(Column('priority', css_class='col-md-4'), ...) →
   │     <div class="row">
   │       <div class="col-md-4">...priority field...</div>
   │       <div class="col-md-8">...notebook field...</div>
   │     </div>
   │
   └── Submit('submit', 'Зберегти') →
         <input type="submit" value="Зберегти" class="btn btn-primary me-2">

5. Adds <form method="post"> and {% csrf_token %} automatically
```

### Template with `{% crispy form %}`

```html
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block topbar_title %}{{ title }}{% endblock %}

{% block content %}
<div class="row">
  <div class="col-lg-8">
    <div class="card shadow-sm">
      <div class="card-header bg-primary text-white">
        <h6 class="mb-0"><i class="bi bi-journal-plus me-2"></i>{{ title }}</h6>
      </div>
      <div class="card-body">

        {% crispy form %}

        {# ↑ One tag instead of 80 lines of HTML.
           FormHelper + Layout in forms.py describe ALL of the Bootstrap markup. #}

      </div>
    </div>
  </div>
</div>
{% endblock %}
```

---

## The `form_tag = False` pattern — embedded forms

Sometimes a form is **part of a larger page** rather than a page of its own.
For example: a todo list + an inline form for adding a new task on the same page.

**Problem:** if the template already has `<form action="/todo/5/items/add/">` and crispy also renders
a `<form>`, you end up with a nested `<form>` — **invalid HTML**; browsers ignore the inner `<form>`.

**Solution:** `self.helper.form_tag = False` — crispy renders only the fields and buttons,
but **not** the `<form>...</form>` wrapper. The template provides the form tag itself.

```python
# forms.py — TodoItemForm: embedded inside a <form> that exists in the template
class TodoItemForm(forms.Form):
    text = forms.CharField(max_length=500, label='Завдання')
    due_date = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = False          # ← do not render <form>...</form>
        self.helper.form_show_labels = False  # ← no labels (compact look)
        self.helper.layout = Layout(
            Row(
                Column(Field('text', placeholder='Нове завдання...'), css_class='col-md-7'),
                Column(Field('due_date'), css_class='col-md-3'),
                Column(Submit('submit', '+ Додати', css_class='btn btn-primary w-100'),
                       css_class='col-md-2'),
            ),
        )
```

```html
<!-- todo_detail.html — the template provides the <form> tag, crispy only the fields -->
<form method="post" action="{% url 'hello_app:todo_item_add' list.pk %}">
  {% csrf_token %}
  {% crispy item_form %}   ← renders a Row with fields and a button, but WITHOUT <form>
</form>
```

| Scenario | `form_tag` |
|----------|-----------|
| The form takes up its own page (note_create, note_edit) | `True` (default) |
| The form is embedded in a page (inline add item) | `False` |

---

## Layout Elements — reference

```python
from crispy_forms.layout import *

# Basic elements:
Field('field_name')                        # Field with label and errors
Field('field_name', css_class='custom')   # + custom class
Field('field_name', placeholder='...')    # + HTML attribute
Field('field_name', rows=8)               # Textarea rows
Field('field_name', type='hidden')        # Hidden input

# Structural:
Row(Column('f1', css_class='col-6'), Column('f2', css_class='col-6'))
# → <div class="row"><div class="col-6">f1</div><div class="col-6">f2</div></div>

Fieldset('Заголовок', Field('f1'), Field('f2'))
# → <fieldset><legend>Заголовок</legend>f1 f2</fieldset>

Div(Field('f1'), css_class='custom-div')
# → <div class="custom-div">f1</div>

HTML('<hr><p>Довільний HTML</p>')

# Buttons:
Submit('submit', 'Зберегти')
# → <input type="submit" class="btn btn-primary" value="Зберегти">

Submit('submit', 'Зберегти', css_class='btn btn-success')
# → custom class

ButtonHolder(Submit('s', 'OK'), HTML('<a href="#">Cancel</a>'))
# → wrapper for buttons
```

---

## Navigation

- Previous: [Forms Evolution](forms_evolution.md)
- Next: [Dashboard Architecture](dashboard_architecture.md)
