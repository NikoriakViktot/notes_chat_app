# Template Inheritance

> **"Don't repeat HTML — inherit it."**
> Django lets you build templates as a tree: the parent defines the structure, the child provides the content.

---

## Template Soup — the duplication problem

> **"Template Soup"** is when templates contain repeated blocks of HTML:
> `<nav>`, `<header>`, the Bootstrap CDN — copied into every file.
> Change the navigation → edit 20 files.

### Without Template Inheritance

```html
<!-- note_list.html — 150 lines! -->
<!DOCTYPE html>
<html>
<head>
    <title>Нотатки</title>
    <link rel="stylesheet" href="...bootstrap.css">  ← COPY-PASTE
    <link rel="stylesheet" href="...bootstrap-icons.css">
</head>
<body>
<nav class="navbar navbar-dark bg-dark">             ← COPY-PASTE
    <a class="navbar-brand" href="/">CrispyNotes</a>
    ...20 lines of navigation...
</nav>
<main class="container my-4">
    <!-- 30 lines of real content -->
</main>
<footer>CrispyNotes &copy; 2026</footer>            ← COPY-PASTE
<script src="...bootstrap.bundle.js"></script>       ← COPY-PASTE
</body>
</html>

<!-- note_form.html — another 150 lines! -->
<!DOCTYPE html>
<html>  ← An exact copy of the structure!
...
```

**Problem:** Changing the navbar → editing 20 files. One mistake (for example, a forgotten `</nav>`) → breaks all 20 pages.

### The duplication problem at the template level

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

| Problem | Example |
|----------|---------|
| Duplication | 15 lines per field × 6 fields = 90 lines just for the form |
| Changing a class | Want `form-control-lg` → edit every `<input>` in every template |
| Synchronization | Added a field in `models.py` → don't forget to update the template |
| No system | Every developer writes it "a little differently" |

### Solution: separation of responsibilities

```
BEFORE (Tier 2):
  forms.py:    fields + widget attrs + validation
  template:    label + input + error + help_text   ← 80 lines of HTML

AFTER (Tier 3):
  forms.py:    fields + FormHelper + Layout         ← structure described in Python code
  template:    {% crispy form %}                    ← 1 line
```

> **Key idea:** A form is a **Python object**. Its structure is described in Python code (Layout),
> not in HTML in the template. The template becomes thin — it only says where to render.

### With Template Inheritance

```html
<!-- note_list.html — 10 lines! -->
{% extends 'layouts/dashboard.html' %}
{% block title %}Нотатки{% endblock %}
{% block topbar_title %}Мої нотатки{% endblock %}
{% block content %}
    <!-- only the real content -->
{% endblock %}
```

**Advantage:** Changing the navbar — only `layouts/dashboard.html`. All 20 pages are updated automatically.

---

## The 3-level hierarchy (SaaS Dashboard pattern)

```
base.html                          ← Level 1: HTML shell
│  Bootstrap CDN, meta, <body>
│  {% block body %}
│
└── layouts/dashboard.html        ← Level 2: Application layout
       Sidebar + Topbar
       Django Messages
       {% block content %}
       {% block topbar_title %}
       │
       ├── hello_app/note_list.html       ← Level 3: Page content
       ├── hello_app/note_form.html
       ├── hello_app/notebook_list.html
       └── hello_app/tag_form.html
```

### What each level is responsible for

| Level | File | Responsibility | Changes when... |
|--------|------|-----------------|-------------------|
| 1 | `base.html` | HTML5 structure, Bootstrap CDN, Bootstrap JS | Changing the CDN version, adding global CSS |
| 2 | `layouts/dashboard.html` | Sidebar, Topbar, Messages, SaaS layout | Changing navigation, new menu items, a new sidebar |
| 3 | `hello_app/*.html` | Page-specific content | The logic of a specific feature |

---

## What it looks like in code

**`base.html`** — only the HTML skeleton:

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

  {% block extra_css %}{% endblock %}
</head>
<body>

  {% block body %}{% endblock %}    ← the whole application goes here

  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  {% block extra_js %}{% endblock %}
</body>
</html>
```

> **Rule:** `base.html` knows nothing about the sidebar, navigation or content.
> It is responsible only for: "I am a correct HTML5 document with Bootstrap".

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
  <!-- content only, the sidebar/topbar already come from the parent -->
{% endblock %}
```

---

## Inheritance flow

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
      200 OK  ·  full HTML page
```

### How Django finds a template

```
render(request, 'hello_app/note_list.html', context)
    ↓
Django searches DIRS:
  1. BASE_DIR/templates/hello_app/note_list.html → not found

Django searches APP_DIRS (each INSTALLED_APP):
  2. hello_app/templates/hello_app/note_list.html → FOUND ✓

Loads note_list.html:
  Encounters {% extends 'layouts/dashboard.html' %}

Django searches for layouts/dashboard.html:
  1. BASE_DIR/templates/layouts/dashboard.html → FOUND ✓

Loads dashboard.html:
  Encounters {% extends 'base.html' %}

Django searches for base.html:
  1. BASE_DIR/templates/base.html → FOUND ✓

Rendering from base.html → dashboard.html → note_list.html
Blocks are filled from the most specific to the most general.
```

---

## Comparison: with inheritance vs without

| | Without inheritance | With the 3-level hierarchy |
|--|-----------------|----------------------|
| New page | Copy all the HTML | 5 lines: `{% extends %}` + content |
| Changing navigation | Edit every file | Only `dashboard.html` |
| Bootstrap CDN | Every file | Only `base.html` |
| Sidebar | Copy into every file | Once, in `dashboard.html` |

---

## `{% block.super %}` — the rule

```html
{# If the child wants to EXTEND a block (not overwrite it): #}
{% block extra_css %}
    {{ block.super }}   {# ← inserts the content of the parent block #}
    <link rel="stylesheet" href="{% static 'css/notes-editor.css' %}">
{% endblock %}

{# Result: CSS from layouts/dashboard.html + this page's CSS #}
{# Without block.super: the CSS of layouts/dashboard.html will be REPLACED #}
```

> **Rule:** If a child template wants to **add** to a parent block (rather than replace it), use `{{ block.super }}`.
> If you want to **replace it completely**, just write inside `{% block %}` without `{{ block.super }}`.

---

## `{% block.super %}` — the full mechanics

### Replacing vs extending a block

```html
<!-- base.html -->
{% block extra_css %}
<link rel="stylesheet" href="{% static 'css/global.css' %}">
{% endblock %}

<!-- layouts/dashboard.html -->
{% extends 'base.html' %}
{% block extra_css %}
{{ block.super }}                              {# → inserts global.css from base.html #}
<link rel="stylesheet" href="{% static 'css/dashboard.css' %}">
{% endblock %}

<!-- note_form.html -->
{% extends 'layouts/dashboard.html' %}
{% block extra_css %}
{{ block.super }}                              {# → global.css + dashboard.css from the parents #}
<link rel="stylesheet" href="{% static 'notes_app/css/editor.css' %}">
{% endblock %}
```

**Result in the browser (CSS order):**
```html
<link rel="stylesheet" href="/static/css/global.css">       <!-- base.html -->
<link rel="stylesheet" href="/static/css/dashboard.css">    <!-- dashboard.html -->
<link rel="stylesheet" href="/static/notes_app/css/editor.css"> <!-- note_form.html -->
```

**Without `{{ block.super }}`:**
```html
<!-- note_form.html WITHOUT block.super: -->
{% block extra_css %}
<link rel="stylesheet" href="{% static 'notes_app/css/editor.css' %}">
{% endblock %}

{# Result: only editor.css — global.css and dashboard.css are MISSING! #}
```

### When block.super is NOT needed

```html
<!-- note_list.html — completely replace the topbar_title block -->
{% block topbar_title %}
    Мої нотатки
{% endblock %}
{# dashboard.html has {% block topbar_title %}Застосунок{% endblock %} — we replace it completely #}
{# block.super is not needed here — we don't care about the parent content #}
```

**How to choose:**

| I want to... | What to write |
|---------|-----------|
| Completely replace the block content | Just `{% block %}`...`{% endblock %}` |
| Add to the parent's content | `{{ block.super }}` + new content |
| Pass the parent content through unchanged | `{{ block.super }}` (the whole block) |

---

## When `{% extends %}` doesn't work — errors and causes

### Error 1: TemplateSyntaxError — extends is not the first tag

```
TemplateSyntaxError at /notes/
<ExtendsNode: extends 'base.html'> must be the first tag in the template.
```

```html
<!-- ❌ CAUSE: there is another tag before {% extends %} (text, whitespace and {# comments #} are allowed) -->
{% load static %}   {# ← THIS IS AN ERROR! load before extends #}
{% extends 'base.html' %}

<!-- ✅ SOLUTION: extends is always the first line -->
{% extends 'base.html' %}
{% load static %}   {# load — after extends #}
```

**Rule:** `{% extends %}` **must be the first tag** in the template. Even `{% load %}` goes after it.

### Error 2: TemplateDoesNotExist

```
TemplateDoesNotExist: layouts/dashboard.html
```

**Possible causes:**

```python
# 1. TEMPLATES is not configured correctly in settings.py
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # ← this line is required for project-level templates
    'APP_DIRS': True,                   # ← True = search in app/templates/
    'OPTIONS': {'context_processors': [...]}
}]

# 2. The file exists, but in the wrong place
# ⚠️ ALSO FOUND (APP_DIRS=True), but this is an app template, not a project one:
myproject/hello_app/templates/layouts/dashboard.html  # ← found as 'layouts/dashboard.html' ✓

# ✅ RECOMMENDED for project-level templates:
myproject/templates/layouts/dashboard.html   # ← if BASE_DIR/templates is in DIRS

# 3. OS type (Linux ≠ Windows): case matters
# base.HTML ≠ base.html on Linux
```

### Error 3: Blocks are not displayed — the content disappears

```html
<!-- ❌ CAUSE: the block names do not match -->

<!-- base.html -->
{% block main_content %}{% endblock %}   ← 'main_content'

<!-- note_list.html -->
{% extends 'base.html' %}
{% block content %}                       ← 'content' — a different name!
    This content will NEVER be displayed
{% endblock %}
```

```html
<!-- ✅ SOLUTION: the same names in the parent and the child -->
<!-- base.html -->
{% block content %}{% endblock %}

<!-- note_list.html -->
{% extends 'base.html' %}
{% block content %}
    Now it is displayed!
{% endblock %}
```

### Error 4: Content outside blocks is ignored

```html
{% extends 'base.html' %}

<h1>This heading will NEVER be displayed</h1>   {# ← outside a block = ignored #}

{% block content %}
    <p>This is displayed.</p>
{% endblock %}

<footer>This is ignored too</footer>   {# ← outside a block = ignored #}
```

> **Rule:** In a template that uses `{% extends %}`, all content **must** be inside a `{% block %}`. Everything outside blocks is ignored by the Django Template Engine.

---

## `{% include %}` vs `{% extends %}`

Two mechanisms for reusing templates — for different tasks.

| | `{% extends %}` | `{% include %}` |
|-|----------------|-----------------|
| **What for** | A page inherits the parent's structure | Insert a piece of HTML into the current template |
| **How many** | One parent (one `extends`) | Unlimited |
| **Context** | Inherited automatically | Inherited + you can pass a separate one |
| **Blocks** | `{% block %}` / `{% endblock %}` | None |
| **Example** | `note_list.html extends dashboard.html` | A note card component in a loop |

```html
<!-- ✅ include — for repeated components -->

{# note_list.html #}
{% for note in notes %}
    {% include 'notes_app/components/_note_card.html' with note=note %}
{% endfor %}

{# _note_card.html — an isolated card component #}
<div class="card mb-3">
    <div class="card-body">
        <h5 class="card-title">{{ note.title }}</h5>
        <p class="card-text">{{ note.content|truncatewords:20 }}</p>
    </div>
</div>
```

**`with` in `{% include %}`** — passes extra variables into the component's context. The component also has access to the template's overall context (all variables from `render(context)`).

---

## TEMPLATES settings in settings.py

```python
# settings.py
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',

    # DIRS — where to look for templates OUTSIDE the apps (project-level templates)
    # This is where these live: base.html, layouts/, registration/ etc.
    'DIRS': [BASE_DIR / 'templates'],

    # APP_DIRS = True — Django automatically searches in each INSTALLED_APP
    # in the directory: app_name/templates/
    # This is where these live: notes_app/templates/notes_app/*.html
    'APP_DIRS': True,

    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ],
    },
}]
```

**Search order for the template `'notes_app/note_list.html'`:**

```
1. BASE_DIR/templates/notes_app/note_list.html   ← DIRS (first)
2. notes_app/templates/notes_app/note_list.html  ← APP_DIRS (if not found in DIRS)

Convention: app templates → app/templates/app_name/file.html
            project templates → BASE_DIR/templates/file.html
```

---

## Directory structure in the project

```
notes_chat_app/
├── templates/                ← DIRS in TEMPLATES[0]['DIRS']
│   ├── base.html             ← Level 1
│   ├── layouts/
│   │   └── dashboard.html   ← Level 2
│   └── registration/
│       ├── login.html
│       └── signup.html
│
└── notes_app/
    └── templates/
        └── notes_app/        ← namespace: to avoid conflicts between apps
            ├── note_list.html
            ├── note_detail.html
            ├── note_form.html
            └── components/
                └── _note_card.html
```

**Why the `notes_app/templates/notes_app/` namespace?**

Without a namespace: if two apps have `note_list.html`, Django will find the first one from `INSTALLED_APPS`. With the `notes_app/note_list.html` namespace, it is always the right file.

---

## In the book

- [Part V. Frontend and templates](../../05_frontend_and_templates/README.md) — the Django Template Language in full: tags, filters, `{% load %}`, `{% static %}`, context processors

---

## Official documentation

- [Django: Template inheritance](https://docs.djangoproject.com/en/5.2/ref/templates/language/#template-inheritance) — `{% extends %}`, `{% block %}`, `{{ block.super }}`
- [Django: Built-in template tags](https://docs.djangoproject.com/en/5.2/ref/templates/builtins/) — `{% include %}`, `{% load %}`, `{% static %}`
- [Django: TEMPLATES settings](https://docs.djangoproject.com/en/5.2/ref/settings/#templates) — DIRS, APP_DIRS, context_processors
- [Django: Template loaders](https://docs.djangoproject.com/en/5.2/ref/templates/api/#loader-types) — how Django finds templates
