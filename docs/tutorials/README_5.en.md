# CrispyNotes — Django Templates + Crispy Forms

> This tutorial walks you through the **evolution of Django forms**:
> HTML by hand → widget attrs → FormHelper + Layout.
>
> The project is a **notes manager with a SaaS Dashboard**: the same `Note` model as in `notes_project`,
> but form rendering has been switched to `django-crispy-forms`.
> Three levels of form rendering — from `{{ form.as_p }}` to `{% crispy form %}` — show **why** crispy.

---

## Contents

**Architectural foundation** _(read before the code)_
- [01 · TEMPLATE SOUP — the problem of duplicated HTML](#01--template-soup)
- [02 · TEMPLATE INHERITANCE — a 3-level hierarchy](#02--template-inheritance)
- [03 · FORMS EVOLUTION — 3 levels of rendering](#03--forms-evolution)
- [04 · FORMHELPER + LAYOUT — crispy architecture](#04--formhelper--layout)
- [05 · DASHBOARD ARCHITECTURE — sidebar, topbar, context](#05--dashboard-architecture)

**Step-by-step implementation**
1. [Step 0 — Running the project](#step-0--launch)
2. [Step 1 — Settings: enabling crispy](#step-1--settings)
3. [Step 2 — Level 1: base.html (the HTML shell)](#step-2--basehtml)
4. [Step 3 — Level 2: layouts/dashboard.html (Sidebar + Topbar)](#step-3--layoutsdashboardhtml)
5. [Step 4 — Level 3: Pages (note_list, note_form...)](#step-4--pages)
6. [Step 5 — Forms Tier 1: form.as_p (Raw Django)](#step-5--tier-1-raw)
7. [Step 6 — Forms Tier 2: Manual Bootstrap HTML](#step-6--tier-2-manual)
8. [Step 7 — Forms Tier 3: FormHelper + Layout (Crispy)](#step-7--tier-3-crispy)
9. [Step 8 — Sidebar Context Processor](#step-8--context-processor)
10. [Step 9 — Components (pagination, empty_state, modal)](#step-9--components)
11. [Project file structure](#file-structure)

---

## 01 · TEMPLATE SOUP

> **"Template Soup"** is when templates contain repeated blocks of HTML:
> `<nav>`, `<header>`, the Bootstrap CDN — copied into every file.
> When the navigation changes → you edit 20 files.

### The problem: duplication at the template level

```html
<!-- notes_form.html — 80 lines for 5 fields -->
<div class="mb-3">
  <label for="id_title" class="form-label fw-semibold">
    Заголовок
    <span class="text-danger">*</span>
  </label>
  <input type="text"
         name="title"
         id="id_title"
         class="form-control {% if form.title.errors %}is-invalid{% endif %}"
         autofocus>
  {% if form.title.errors %}
    {% for error in form.title.errors %}
    <div class="invalid-feedback">{{ error }}</div>
    {% endfor %}
  {% endif %}
</div>

<!-- ... repeat for every field ... -->
```

This is **Tier 2** — manual Bootstrap HTML. The problems:

| Problem | Example |
|----------|---------|
| Duplication | 15 lines per field × 6 fields = 90 lines just for the form |
| Changing a class | Want `form-control-lg` → edit every `<input>` in every template |
| Synchronization | Added a field in `models.py` → don't forget to update the template |
| No system | Every developer writes it "a little differently" |

### The solution: separation of responsibilities

```
BEFORE (Tier 2):
  forms.py:    fields + widget attrs + validation
  template:    label + input + error + help_text   ← 80 lines of HTML

AFTER (Tier 3):
  forms.py:    fields + FormHelper + Layout           ← structure described in Python code
  template:    {% crispy form %}                    ← 1 line
```

> **Key idea:** A form is a **Python object**. Its structure is described in Python code (Layout),
> not in HTML in the template. The template becomes thin — it only says where to render.

---

## 02 · TEMPLATE INHERITANCE

> **"Don't repeat HTML — inherit it."**
> Django lets you build templates as a tree: the parent defines the structure, the child provides the content.

### A 3-level hierarchy (the SaaS Dashboard pattern)

```
base.html                          ← Level 1: the HTML shell
│  Bootstrap CDN, meta, <body>
│  {% block body %}
│
└── layouts/dashboard.html        ← Level 2: the application layout
       Sidebar + Topbar
       Django Messages
       {% block content %}
       {% block topbar_title %}
       │
       ├── hello_app/note_list.html       ← Level 3: page content
       ├── hello_app/note_form.html
       ├── hello_app/notebook_list.html
       └── hello_app/tag_form.html
```

### What it looks like in code

**`base.html`** — only the HTML skeleton:
```html
<!DOCTYPE html>
<html>
<head>
  <!-- Bootstrap CDN, CSS -->
</head>
<body>
  {% block body %}{% endblock %}   ← the whole application goes here
</body>
</html>
```

**`layouts/dashboard.html`** — the layout (extends base):
```html
{% extends 'base.html' %}
{% block body %}
  <div class="d-flex vh-100">
    <nav><!-- Sidebar --></nav>
    <div class="flex-grow-1">
      <header>{% block topbar_title %}{% endblock %}</header>
      <main>{% block content %}{% endblock %}</main>
    </div>
  </div>
{% endblock %}
```

**`note_list.html`** — a page (extends dashboard):
```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Мої нотатки{% endblock %}
{% block content %}
  <!-- only content, the sidebar/topbar already come from the parent -->
{% endblock %}
```

### The inheritance flow

```
Request /notes/
     │
     ▼
views.note_list()
  └─► render('hello_app/note_list.html', context)
           │
           ▼
      Django Template Engine
           │
      note_list.html extends dashboard.html
           │
      dashboard.html extends base.html
           │
      base.html — the root template
           │
           ▼
      Assembly: base → dashboard → note_list → HTML
           │
           ▼
      200 OK  ·  a full HTML page
```

> **Advantages:**
> - A navigation change → only `dashboard.html`, all pages are updated
> - A new page → you only write `{% block content %}`, the rest comes for free
> - No duplication of the Bootstrap CDN in every file

### Comparison: with inheritance vs without

| | Without inheritance | With a 3-level hierarchy |
|--|-----------------|----------------------|
| A new page | Copy all the HTML | 5 lines of `{% extends %}` + content |
| A navigation change | Edit every file | Only `dashboard.html` |
| Bootstrap CDN | In every file | Only `base.html` |
| Sidebar | Copy into every file | Once in `dashboard.html` |

---

## 03 · FORMS EVOLUTION

> Three levels of form evolution — from "it just works" to "beautiful and without duplication".

### Comparison table

| Tier | Where to look | Method | HTML in the template | Where the Bootstrap classes are |
|------|-------------|-------|----------------|--------------------|
| **1 — Raw** | [`notes_project/forms.py`](../../lesson_Django_ORM_Database/notes_project/hello_app/forms.py) | `{{ form.as_p }}` | ~5 lines | Nowhere (no styles) |
| **2 — Manual** | [`django_bootstrap_project/`](../django_bootstrap_project/) | Manual HTML | ~80 lines | In the template, by hand |
| **3 — Crispy** | **this project** `/notes/new/` | `{% crispy form %}` | **1 line** | In `forms.py` via Layout |

All three approaches pass **the same** `NoteForm`. The difference is only in how it's rendered.

---

### Tier 1: Raw Django — `{{ form.as_p }}`

```python
# views.py — nothing special
def note_create_raw(request):
    form = NoteForm(user=request.user)
    return render(request, 'hello_app/note_form_raw.html', {'form': form})
```

```html
<!-- note_form_raw.html -->
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}      ← Django generates <p><label><input></p> without classes
  <button type="submit">Зберегти</button>
</form>
```

**What gets generated:**
```html
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" id="id_title" required>
</p>
```

Not a single `class="form-control"`, no Bootstrap styles at all.
Validation **works**, but it looks bad.

> **When to use it:** only for debugging. Never in production.

---

### Tier 2: Manual Bootstrap HTML

```python
# forms.py — set Bootstrap classes via widget attrs
class NoteFormManual(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['title'].widget.attrs.update({'class': 'form-control'})
        self.fields['content'].widget.attrs.update({'class': 'form-control', 'rows': 8})
        self.fields['priority'].widget.attrs.update({'class': 'form-select'})
        # ... repeat for every field
```

```html
<!-- note_form_manual.html — ~80 lines of HTML for 5 fields -->
<form method="post">
  {% csrf_token %}

  <!-- Field: title -->
  <div class="mb-3">
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
      {{ form.title.label }}
      {% if form.title.field.required %}<span class="text-danger">*</span>{% endif %}
    </label>
    <input type="text"
           name="{{ form.title.html_name }}"
           id="{{ form.title.id_for_label }}"
           value="{{ form.title.value|default:'' }}"
           class="form-control {% if form.title.errors %}is-invalid{% endif %}"
           autofocus>
    {% if form.title.errors %}
      {% for error in form.title.errors %}<div class="invalid-feedback">{{ error }}</div>{% endfor %}
    {% endif %}
  </div>

  <!-- ... another ~60 lines for priority, notebook, content, tags, is_pinned ... -->
</form>
```

**Problems with Tier 2:**
- 80 lines of HTML just for the form
- When you add a field in `models.py` → you have to add it to the template by hand
- When the Bootstrap version changes → edit every template
- 10 forms in the application = 800 lines of duplication

> **Where this approach is used:** in `notes_project` (the previous lesson) — that's exactly how the forms are written there.
> It's a perfectly fine approach for small projects. Crispy is an upgrade for scale.

---

### Tier 3: Crispy Forms — `{% crispy form %}`

```python
# forms.py — ALL the Bootstrap markup is described here, in Python code
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Row, Column, Fieldset, Submit, Field

class NoteForm(forms.ModelForm):
    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.layout = Layout(
            Fieldset('Основна інформація',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8')),
            ),
            Fieldset('Зміст нотатки',
                Field('content', rows=8, placeholder='Текст нотатки...'),
            ),
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
        )
```

```html
<!-- note_form.html — 1 line instead of 80 -->
{% load crispy_forms_tags %}
{% crispy form %}
```

**What gets generated automatically:**
- `<form method="post">` + the CSRF token
- `<div class="mb-3">` for every field
- `<label class="form-label">` with the required asterisk
- `<input class="form-control">` or `<select class="form-select">`
- `<div class="invalid-feedback">` for errors
- `<div class="form-text">` for help_text
- `<fieldset>` with `<legend>` for a Fieldset
- `<div class="row">` for a Row, `<div class="col-md-4">` for a Column

---

## 04 · FORMHELPER + LAYOUT

> **FormHelper** is an object attached to the form that describes:
> - The attributes of the `<form>` tag (method, action, id, class)
> - The rendering behavior
> - The Layout — the structure and order of the fields

### FormHelper architecture

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
    └── layout = Layout(...)       ← the field structure
        ├── Fieldset(...)          ← <fieldset><legend>
        │   ├── Field('title')     ← an individual field with attrs
        │   └── Row(...)           ← <div class="row">
        │       ├── Column(...)    ← <div class="col-md-4">
        │       └── Column(...)    ← <div class="col-md-8">
        ├── Submit(...)            ← <button type="submit">
        └── HTML('<hr>')           ← arbitrary HTML
```

### The rendering pipeline

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

### Attributes of Layout objects

```python
# kwargs → HTML attributes
Field('title', placeholder='Підказка')   # placeholder="Підказка"
Field('title', autofocus=True)           # autofocus
Field('title', data_custom="val")        # data-custom="val" (underscore → hyphen)
Field('title', css_class="extra")        # an extra CSS class
Field('title', type="hidden")            # a hidden input

# The wrapping div
Field('title', wrapper_class="mt-3")     # class for <div class="mb-3 mt-3">
```

### Where crispy vs where manual HTML — the rule

| Situation | Approach |
|----------|--------|
| The form takes up the whole page | `{% crispy form %}` — full control via Layout |
| A quick prototype | `{{ form\|crispy }}` — no FormHelper, just Bootstrap styles |
| A single field embedded in a page | `{{ form.title\|as_crispy_field }}` |
| A form without Bootstrap (API, email) | `{{ form.as_p }}` or `form.cleaned_data` directly |

---

## 05 · DASHBOARD ARCHITECTURE

> **SaaS Dashboard** is a UI pattern for applications:
> a fixed sidebar on the left, a topbar at the top, scrollable content in the center.
> Gmail, Notion, Linear — all built on this pattern.

### Dashboard structure

```
┌──────────┬───────────────────────────────────────────────────┐
│          │  Topbar: title / search / user dropdown           │
│ Sidebar  ├───────────────────────────────────────────────────┤
│          │                                                   │
│ Brand    │  ← {% block content %}                            │
│ ─────    │                                                   │
│ NOTES    │  Notes / Form / Notebooks / Tasks...              │
│  Notebks │                                                   │
│  All     │                                                   │
│  + New   │                                                   │
│ TASKS    │                                                   │
│  To-dos  │                                                   │
│  Shopping│                                                   │
│ ─────    │                                                   │
│ [Notebk] │  (if any)                                         │
│ TAGS     │                                                   │
│  + New   │                                                   │
└──────────┴───────────────────────────────────────────────────┘
```

### Sidebar Context Processor

The sidebar shows **notebooks** and **tags** — they're needed on EVERY page.
But passing them from every view by hand is duplication:

```python
# ❌ Bad — duplication in every view
def note_list(request):
    notes = selectors.get_user_notes(request.user)
    notebooks = selectors.get_user_notebooks(request.user)  # duplication
    tags = selectors.get_user_tags(request.user)            # duplication
    return render(request, '...', {'notes': notes, 'notebooks': notebooks, 'tags': tags})

def note_create(request):
    notebooks = selectors.get_user_notebooks(request.user)  # duplication again
    tags = selectors.get_user_tags(request.user)            # duplication again
    ...
```

**The solution** — `context_processors.py`:

```python
# ✅ Good — once, automatically for all views
def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}
    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags': selectors.get_user_tags(request.user),
    }
```

```python
# settings.py — register the processor
TEMPLATES = [{
    'OPTIONS': {
        'context_processors': [
            ...
            'hello_app.context_processors.sidebar_context',  # ← here
        ]
    }
}]
```

Now `{{ sidebar_notebooks }}` and `{{ sidebar_tags }}` are available **in every template** automatically.

### Active state in the navigation

```html
<!-- Highlight the active menu item via request.resolver_match -->
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
  Всі нотатки
</a>
```

`request.resolver_match.url_name` returns the name of the current URL — without any extra variables in the View.

---

## Step 0 — Launch

```bash
# 1. Go to the folder
cd module_5/lesson_HTML_CSS_Bootstrap/crispy_notes_project

# 2. Install dependencies
pip install -r requirements.txt

# 3. Apply migrations
python manage.py migrate

# 4. Create a superuser
python manage.py createsuperuser

# 5. Start the server
python manage.py runserver
```

### What to look at in the browser

| URL | What it shows |
|-----|-----------|
| `http://127.0.0.1:8000/notes/` | Dashboard: list of notes + sidebar |
| `http://127.0.0.1:8000/notes/new/` | **Tier 3**: `{% crispy form %}` — a Bootstrap form with a Layout |
| `http://127.0.0.1:8000/notebooks/` | List of notebooks |
| `http://127.0.0.1:8000/todo/` | To-do lists (the TASKS section) |
| `http://127.0.0.1:8000/shopping/` | Shopping lists |
| `http://127.0.0.1:8000/register/` | New user registration |
| `http://127.0.0.1:8000/admin/` | Django Admin |

> **Tier 1 and Tier 2 as code for comparison** (not as live URLs):
> - Tier 1 (`form.as_p`): [`notes_project/hello_app/forms.py`](../../lesson_Django_ORM_Database/notes_project/hello_app/forms.py)
> - Tier 2 (manual Bootstrap): [`django_bootstrap_project/`](../django_bootstrap_project/)

---

## Step 1 — Settings

```python
# hello_project/settings.py

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    ...
    'crispy_forms',        # ← 1. the base package
    'crispy_bootstrap5',   # ← 2. the template pack for Bootstrap 5
    'debug_toolbar',
    'hello_app',
]

# Configure crispy
CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"
```

```python
# Where to look for templates — critical for the 3-level hierarchy
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # ← global templates (base.html, layouts/)
    'APP_DIRS': True,                   # ← templates in hello_app/templates/hello_app/
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.request',  # ← for request.user, request.resolver_match
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
            'hello_app.context_processors.sidebar_context', # ← sidebar notebooks/tags
        ],
    },
}]

# Django Messages → Bootstrap alert classes
from django.contrib.messages import constants as messages_constants
MESSAGE_TAGS = {
    messages_constants.DEBUG: 'secondary',
    messages_constants.INFO: 'info',
    messages_constants.SUCCESS: 'success',
    messages_constants.WARNING: 'warning',
    messages_constants.ERROR: 'danger',  # ← Bootstrap: alert-danger (not alert-error!)
}

LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'
```

> **Why `'DIRS': [BASE_DIR / 'templates']`?**
> `base.html` and `layouts/dashboard.html` are global templates, not tied to an app.
> Django looks for templates in two places: `DIRS` (global) and `APP_DIRS` (inside each app).

---

## Step 2 — base.html

**Location:** `crispy_notes_project/templates/base.html`

`base.html` is the HTML skeleton. It contains ONLY:
- DOCTYPE, `<head>`, `<body>`
- Bootstrap 5 CDN
- Bootstrap Icons CDN
- Global CSS
- A single `{% block body %}` — the whole application goes here

```html
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CrispyNotes</title>

  <!-- Bootstrap 5 CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <!-- Bootstrap Icons -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
</head>
<body>

  {% block body %}{% endblock %}    ← the whole application goes here

  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
```

> **Rule:** base.html knows nothing about the sidebar, navigation, or content.
> It is responsible only for: "I am a correct HTML5 document with Bootstrap".

---

## Step 3 — layouts/dashboard.html

**Location:** `crispy_notes_project/templates/layouts/dashboard.html`

Level 2 of the hierarchy. It:
- Extends `base.html`
- Fills `{% block body %}` with the full Dashboard markup
- Provides two slots for child templates:
  - `{% block topbar_title %}` — the title in the topbar
  - `{% block content %}` — the main page content

```html
{% extends 'base.html' %}
{% load static %}

{% block body %}
<div class="d-flex vh-100 overflow-hidden">

  <!-- ════════════════════ SIDEBAR ════════════════════ -->
  <nav id="sidebar" class="sidebar d-flex flex-column p-3 text-bg-dark" style="width: 260px;">

    <!-- Brand -->
    <a href="{% url 'hello_app:note_list' %}" class="d-flex align-items-center text-white mb-3">
      <i class="bi bi-journal-text fs-4 me-2"></i>
      <span class="fs-5 fw-semibold">CrispyNotes</span>
    </a>
    <hr>

    <!-- NOTES section -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Нотатки</p>
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:notebook_list' %}"
           class="nav-link {% if 'notebook' in request.resolver_match.url_name %}active{% endif %}">
          <i class="bi bi-collection me-2"></i>Записники
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:note_list' %}"
           class="nav-link {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
          <i class="bi bi-journal-text me-2"></i>Всі нотатки
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:note_create' %}"
           class="nav-link {% if request.resolver_match.url_name == 'note_create' %}active{% endif %}">
          <i class="bi bi-plus-circle me-2"></i>Нова нотатка
        </a>
      </li>
    </ul>

    <!-- TASKS section -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Задачі</p>
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:todo_list' %}"
           class="nav-link d-flex justify-content-between {% if 'todo' in request.resolver_match.url_name %}active{% endif %}">
          <span><i class="bi bi-check2-square me-2"></i>Список справ</span>
          {% if sidebar_todo_count %}
          <span class="badge bg-primary rounded-pill">{{ sidebar_todo_count }}</span>
          {% endif %}
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:shopping_list' %}"
           class="nav-link d-flex justify-content-between {% if 'shopping' in request.resolver_match.url_name %}active{% endif %}">
          <span><i class="bi bi-cart me-2"></i>Покупки</span>
          {% if sidebar_shopping_count %}
          <span class="badge bg-secondary rounded-pill">{{ sidebar_shopping_count }}</span>
          {% endif %}
        </a>
      </li>
    </ul>
    <hr>

    <!-- Notebooks (a list, from sidebar_context — a context processor!) -->
    {% if sidebar_notebooks %}
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Записники</p>
    <ul class="nav nav-pills flex-column mb-3">
      {% for nb in sidebar_notebooks %}
      <li>
        <a href="{% url 'hello_app:note_list' %}?notebook={{ nb.pk }}"
           class="nav-link py-1 d-flex justify-content-between">
          <span><span style="color: {{ nb.color }};">●</span> {{ nb.title|truncatechars:18 }}</span>
          <span class="badge bg-secondary">{{ nb.note_count }}</span>
        </a>
      </li>
      {% endfor %}
    </ul>
    {% endif %}

    <!-- TAGS section (header always visible) -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Теги</p>
    {% if sidebar_tags %}
    <div class="px-2 mb-2 d-flex flex-wrap gap-1">
      {% for tag in sidebar_tags %}
      <a href="{% url 'hello_app:note_list' %}?tag={{ tag.pk }}"
         class="badge text-decoration-none"
         style="background-color: {{ tag.color }}; color: white;">
        #{{ tag.name }}
      </a>
      {% endfor %}
    </div>
    {% endif %}
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:tag_create' %}" class="nav-link">
          <i class="bi bi-tags me-2"></i>Новий тег
        </a>
      </li>
    </ul>
  </nav>
  <!-- /SIDEBAR -->

  <!-- ════════════════════ MAIN ════════════════════ -->
  <div class="d-flex flex-column flex-grow-1 overflow-auto">

    <!-- TOPBAR: title | search | user dropdown -->
    <header class="topbar d-flex align-items-center px-4 py-2">
      <h6 class="mb-0 me-auto fw-semibold">
        {% block topbar_title %}Нотатки{% endblock %}   ← child templates fill in the title
      </h6>
      <form class="d-flex me-3" method="get" action="{% url 'hello_app:note_list' %}">
        <input type="search" name="q" class="form-control form-control-sm" placeholder="Пошук нотаток...">
        <button class="btn btn-sm btn-outline-secondary ms-1" type="submit">
          <i class="bi bi-search"></i>
        </button>
      </form>
      <!-- Profile / Logout (dropdown on the right) -->
      <div class="dropdown">
        <a href="#" class="d-flex align-items-center text-decoration-none dropdown-toggle"
           data-bs-toggle="dropdown">
          <i class="bi bi-person-circle fs-5 me-1"></i>
          <span class="small fw-semibold">{{ request.user.username }}</span>
        </a>
        <ul class="dropdown-menu dropdown-menu-dark dropdown-menu-end shadow">
          <li><a class="dropdown-item" href="{% url 'hello_app:notebook_list' %}">Мої записники</a></li>
          <li><hr class="dropdown-divider"></li>
          <li>
            <form method="post" action="{% url 'logout' %}">
              {% csrf_token %}
              <button type="submit" class="dropdown-item text-danger">Вийти</button>
            </form>
          </li>
        </ul>
      </div>
    </header>

    <!-- Django Messages → Bootstrap Alerts -->
    {% if messages %}
    <div class="px-4 pt-3">
      {% for message in messages %}
      <div class="alert alert-{{ message.tags }} alert-dismissible fade show">
        {{ message }}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
      {% endfor %}
    </div>
    {% endif %}

    <!-- PAGE CONTENT -->
    <main class="flex-grow-1 p-4">
      {% block content %}{% endblock %}   ← child templates fill in the content
    </main>

  </div>
  <!-- /MAIN -->

</div>
{% endblock %}
```

---

## Step 4 — Pages

**Location:** `hello_app/templates/hello_app/`

Child templates (level 3) write **only content**. The sidebar, topbar, and Bootstrap come for free.

**Example `note_list.html`:**

```html
{% extends 'layouts/dashboard.html' %}

{% block topbar_title %}Мої нотатки{% endblock %}    ← only the title

{% block content %}
{# Only the page content — the sidebar/topbar are already there #}

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 g-3">
  {% for note in notes %}
  <div class="col">
    <div class="card h-100">
      ...
    </div>
  </div>
  {% endfor %}
</div>
{% else %}
  {% include 'components/empty_state.html' with icon="bi-journal" message="Ще немає нотаток" %}
{% endif %}

{% endblock %}
```

---

## Step 5 — Tier 1: Raw

**Goal:** show what Django provides "out of the box", without any styles.

> Tier 1 is implemented in [`notes_project`](../../lesson_Django_ORM_Database/notes_project/) — the forms there have no crispy.
> The code below is for comparing the concepts.

```python
# views.py
@login_required
def note_create_raw(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            # the same service as in Tier 3
            note = services.create_note(
                user=request.user,
                **form.cleaned_data_for_service(),
            )
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(user=request.user)

    return render(request, 'hello_app/note_form_raw.html', {
        'form': form,
        'title': 'Нова нотатка (Raw)',
        'current_tier': 'raw',
    })
```

```html
<!-- note_form_raw.html -->
{% extends 'layouts/dashboard.html' %}
{% block content %}

<form method="post">
  {% csrf_token %}
  {{ form.as_p }}    ← Django generates <p><label><input></p> for every field
  <button type="submit" class="btn btn-warning">Зберегти</button>
</form>

{% endblock %}
```

**What `as_p` generates for `title`:**
```html
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" maxlength="200" required id="id_title">
</p>
```

No `class="form-control"`. No Bootstrap. It looks bad, but it **works correctly**.

---

## Step 6 — Tier 2: Manual

**Goal:** show the full Bootstrap HTML — to understand what Tier 3 saves you from.

> Tier 2 is implemented in [`django_bootstrap_project`](../django_bootstrap_project/) — the forms there use manual Bootstrap HTML.
> The code below is for comparing the concepts.

```html
<!-- note_form_manual.html — look how much code there is for ONE field -->
<form method="post">
  {% csrf_token %}

  <!-- Field: title  ← 14 lines of HTML for just one field -->
  <div class="mb-3">
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
      {{ form.title.label }}
      {% if form.title.field.required %}<span class="text-danger">*</span>{% endif %}
    </label>
    <input type="text"
           name="{{ form.title.html_name }}"
           id="{{ form.title.id_for_label }}"
           value="{{ form.title.value|default:'' }}"
           placeholder="Назва нотатки..."
           class="form-control {% if form.title.errors %}is-invalid{% endif %}"
           autofocus>
    {% if form.title.errors %}
      {% for error in form.title.errors %}
      <div class="invalid-feedback">{{ error }}</div>
      {% endfor %}
    {% endif %}
  </div>

  <!-- ... another ~65 lines for priority, notebook, content, tags, is_pinned ... -->

  <button type="submit" class="btn btn-secondary">Зберегти</button>
</form>
```

**Line count:**
```
title:     14 lines
priority:  12 lines (select)
notebook:  14 lines (select + queryset)
content:   12 lines (textarea)
tags:      14 lines (multiple select)
is_pinned: 10 lines (checkbox)
buttons:    3 lines
─────────────────
TOTAL:    ~80 lines of HTML just for the form
```

> Multiply by 5 forms in the application → **400 lines of duplication**.
> Changed the Bootstrap version → you edit 400 lines.

---

## Step 7 — Tier 3: Crispy

**Goal:** replace 80 lines of HTML with 10 lines of Python.

### forms.py — the full `NoteForm` code

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
        # ↑ NO widget attrs at all — crispy adds the Bootstrap classes automatically!

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Security: filter the FK by the current user
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)

        # FormHelper — describe the form in Python code
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id = 'note-form'

        # Layout — the field structure
        self.helper.layout = Layout(
            # Section 1: basic information
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

### note_form.html — the whole template

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
           FormHelper + Layout in forms.py describe ALL the Bootstrap markup. #}

      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### What `{% crispy form %}` does, step by step

```
1. {% load crispy_forms_tags %} — registers the tag

2. {% crispy form %} — calls do_uni_form() in crispy_forms_tags.py

3. Finds form.helper — our FormHelper with the Layout

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

### Comparing the views for Tier 3

```python
# views.py — the view for Tier 3 is no different from Tier 2!
# Crispy is purely the PRESENTATION layer, not business logic.

@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data['content'],
                priority=form.cleaned_data['priority'],
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.pk for t in form.cleaned_data.get('tags', [])],
                is_pinned=form.cleaned_data.get('is_pinned', False),
            )
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(user=request.user)

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'title': 'Нова нотатка',
        'current_tier': 'crispy',
    })
```

> **Conclusion:** `services.create_note()` is the same function as in `notes_project`.
> Crispy doesn't change the business logic. It only changes how the form **looks**.

### Pattern: `form_tag = False` — embedded forms

Sometimes a form is **part of a larger page**, not a separate page.
For example: a task list + an inline form for adding a new task on the same page.

**The problem:** if the template already has `<form action="/todo/5/items/add/">`, and crispy also renders
a `<form>` — you get a nested `<form>` — **invalid HTML**, and browsers ignore the inner `<form>`.

**The solution:** `self.helper.form_tag = False` — crispy renders only the fields and buttons,
but **not** the `<form>...</form>` wrapper. The template provides the form tag itself.

```python
# forms.py — TodoItemForm: embedded inside a <form> that exists in the template
class TodoItemForm(forms.Form):
    text = forms.CharField(max_length=500, label='Завдання')
    due_date = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = False          # ← don't render <form>...</form>
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
| The form takes a separate page (note_create, note_edit) | `True` (default) |
| The form is embedded in a page (inline add item) | `False` |

---

## Step 8 — Context Processor

```python
# hello_app/context_processors.py
from django.db import OperationalError
from django.db.models import Q
from .models import TodoList, ShoppingList
from . import selectors


def sidebar_context(request):
    """
    Automatically adds sidebar_notebooks, sidebar_tags and task counters to every template.
    Runs on every request for authenticated users.
    """
    if not request.user.is_authenticated:
        return {
            'sidebar_notebooks': [], 'sidebar_tags': [],
            'sidebar_todo_count': 0, 'sidebar_shopping_count': 0,
        }

    user = request.user

    # try/except — protection in case the migration hasn't been applied yet (new M2M tables)
    try:
        todo_count = TodoList.objects.filter(
            Q(user=user) | Q(shared_with=user), is_completed=False
        ).distinct().count()
        shopping_count = ShoppingList.objects.filter(
            Q(user=user) | Q(shared_with=user)
        ).distinct().count()
    except OperationalError:
        todo_count = 0
        shopping_count = 0

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(user),
        'sidebar_tags': selectors.get_user_tags(user),
        'sidebar_todo_count': todo_count,       # ← badge on "Список справ"
        'sidebar_shopping_count': shopping_count,  # ← badge on "Покупки"
    }
```

> **Why `try/except OperationalError`?**
> A context processor runs on **every** request. If the migration for a new table
> hasn't been applied yet (for example, during development after a `git pull`), the QuerySet will fail with
> `OperationalError: no such table`. The guard lets the server keep working — the counters
> simply return 0 instead of a 500 error.

**Registration in settings.py:**
```python
'context_processors': [
    'django.template.context_processors.request',
    'django.contrib.auth.context_processors.auth',
    'django.contrib.messages.context_processors.messages',
    'hello_app.context_processors.sidebar_context',   # ← ours
],
```

**Usage in any template (without passing it from the View):**
```html
{% for nb in sidebar_notebooks %}
  <a href="?notebook={{ nb.pk }}">{{ nb.title }}</a>
{% endfor %}
```

> **Important:** A context processor runs on **every** HTTP request.
> So the selector must be efficient — `select_related`, `annotate`, no N+1.

---

## Step 9 — Components

**Location:** `crispy_notes_project/templates/components/`

Components are reusable UI blocks used via `{% include %}`.

### `components/empty_state.html`

```html
{# Empty state — "you don't have any notes yet" #}
<div class="text-center py-5">
  <i class="bi {{ icon|default:'bi-inbox' }} display-1 text-muted"></i>
  <p class="text-muted mt-3">{{ message }}</p>
  {% if action_url %}
  <a href="{{ action_url }}" class="btn btn-primary">{{ action_label }}</a>
  {% endif %}
</div>
```

**Usage:**
```html
{% if not notes %}
  {% include 'components/empty_state.html' with
     icon="bi-journal"
     message="Ще немає нотаток"
     action_url=note_create_url
     action_label="Створити першу" %}
{% endif %}
```

### `components/pagination.html`

```html
{# Bootstrap Pagination #}
{% if page_obj.has_other_pages %}
<nav>
  <ul class="pagination justify-content-center">
    {% if page_obj.has_previous %}
    <li class="page-item">
      <a class="page-link" href="?page={{ page_obj.previous_page_number }}">←</a>
    </li>
    {% endif %}

    {% for num in page_obj.paginator.page_range %}
    <li class="page-item {% if page_obj.number == num %}active{% endif %}">
      <a class="page-link" href="?page={{ num }}">{{ num }}</a>
    </li>
    {% endfor %}

    {% if page_obj.has_next %}
    <li class="page-item">
      <a class="page-link" href="?page={{ page_obj.next_page_number }}">→</a>
    </li>
    {% endif %}
  </ul>
</nav>
{% endif %}
```

### `components/confirm_modal.html`

```html
{# Bootstrap Modal for confirming deletion #}
<div class="modal fade" id="confirmModal" tabindex="-1">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header bg-danger text-white">
        <h5 class="modal-title">Підтвердити видалення</h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        Ви впевнені що хочете видалити <strong id="deleteItemName"></strong>?
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Скасувати</button>
        <form id="deleteForm" method="post">
          {% csrf_token %}
          <button type="submit" class="btn btn-danger">Видалити</button>
        </form>
      </div>
    </div>
  </div>
</div>
```

---

## File structure

```
crispy_notes_project/
│
├── requirements.txt              ← django-crispy-forms, crispy-bootstrap5, debug-toolbar
│
├── hello_project/
│   ├── settings.py               ← CRISPY_TEMPLATE_PACK, context_processors, MESSAGE_TAGS
│   └── urls.py                   ← accounts/ (login/logout) + hello_app/ + debug_toolbar
│
├── hello_app/
│   ├── models.py                 ← Note, Notebook, Tag, TodoList, TodoItem,
│   │                                ShoppingList, ShopItem, Reminder
│   ├── services.py               ← create/update/delete for all models
│   ├── selectors.py              ← get_user_notes, get_user_notebooks, get_user_tags,
│   │                                get_todo_lists, get_shopping_lists...
│   ├── context_processors.py     ← sidebar_context → notebooks, tags,
│   │                                todo_count, shopping_count (+ OperationalError guard)
│   ├── forms.py                  ← ★ NoteForm, NotebookForm, TagForm,
│   │                                TodoListForm, TodoItemForm (form_tag=False),
│   │                                ShoppingListForm, ShopItemForm (form_tag=False),
│   │                                ReminderForm, ShareForm
│   ├── views.py                  ← note CRUD + todo CRUD + shopping CRUD + reminders + register
│   ├── urls.py
│   ├── migrations/
│   │   ├── 0001_initial.py
│   │   └── 0002_shoppinglist_shared_with_todolist_shared_with.py  ← M2M shared_with
│   └── templates/hello_app/
│       ├── note_list.html            ← extends layouts/dashboard.html
│       ├── note_detail.html          ← with inline ReminderForm (form_action in the view)
│       ├── note_form.html            ← Tier 3: {% crispy form %}  ★
│       ├── note_confirm_delete.html
│       ├── notebook_list.html
│       ├── notebook_form.html        ← {% crispy form %}
│       ├── tag_form.html             ← {% crispy form %}
│       ├── todo_list.html            ← my + shared to-do lists
│       ├── todo_detail.html          ← inline TodoItemForm (form_tag=False)
│       ├── todo_form.html            ← {% crispy form %}
│       ├── todo_confirm_delete.html
│       ├── shopping_list.html
│       ├── shopping_detail.html      ← inline ShopItemForm (form_tag=False)
│       ├── shopping_form.html        ← {% crispy form %}
│       ├── shopping_confirm_delete.html
│       └── share_form.html           ← ShareForm (add a user to shared_with)
│
└── templates/                    ← GLOBAL templates (DIRS in settings)
    ├── base.html                      ← Level 1: HTML5 + Bootstrap CDN
    ├── layouts/
    │   └── dashboard.html             ← Level 2: Sidebar (NOTES/TASKS/TAGS) + Topbar
    ├── registration/
    │   ├── login.html                 ← Bootstrap card, link to register
    │   └── register.html             ← new user registration
    └── components/
        ├── pagination.html            ← Bootstrap pagination
        ├── empty_state.html           ← "no data" placeholder
        └── confirm_modal.html         ← Bootstrap modal for delete
```

---

## Summary: what to learn and where

| Concept | Where to look in the code |
|-----------|-------------------|
| **Template Inheritance** | `base.html` → `layouts/dashboard.html` → `note_list.html` |
| **FormHelper + Layout** | `hello_app/forms.py` — `NoteForm.__init__` |
| **3 levels of forms** | `notes_project` (Tier 1) · `django_bootstrap_project` (Tier 2) · `/notes/new/` (Tier 3) |
| **form_tag = False** | `forms.py` — `TodoItemForm`, `ShopItemForm` (inline forms) |
| **Context Processor** | `hello_app/context_processors.py` + `settings.py TEMPLATES` |
| **OperationalError guard** | `context_processors.py` — `try/except` for new tables |
| **Active nav state** | `dashboard.html` — `request.resolver_match.url_name` |
| **Sidebar sections** | `dashboard.html` — NOTES / TASKS / TAGS with `sidebar-label` |
| **M2M shared_with** | `models.py` `TodoList.shared_with` + migration 0002 |
| **Django Messages** | `dashboard.html` the `{% if messages %}` block + `settings.py MESSAGE_TAGS` |
| **Components** | `templates/components/` + `{% include %}` in the pages |
| **Services/Selectors** | `services.py` / `selectors.py` (in detail in `notes_project/README.md`) |

---

## Documentation

| File | Description |
|------|------|
| [`../DESIGN_FOUNDATIONS.md`](../DESIGN_FOUNDATIONS.md) | UX, CRAP, Bootstrap, template hierarchy, Crispy — theory |
| [`../CRISPY_FORMS.md`](../CRISPY_FORMS.md) | Full reference: FormHelper, Layout, Bootstrap components, Dynamic API |
| [`../ADVANCED_TEMPLATES.md §3`](../ADVANCED_TEMPLATES.md) | FormHelper + Layout — details |
| [`../ADVANCED_TEMPLATES.md §5`](../ADVANCED_TEMPLATES.md) | SaaS Dashboard Architecture |
| [`../../lesson_Django_ORM_Database/notes_project/README.md`](../../lesson_Django_ORM_Database/notes_project/README.md) | ORM, Services/Selectors, migrations — the foundation of this project |
