# Tutorial 04 — Templates, Crispy Forms and a SaaS Dashboard

> This tutorial builds a **3-level Template Inheritance**, moves from hand-written Bootstrap HTML
> to `{% crispy form %}`, and implements a **SaaS Dashboard with a Sidebar** via a Context Processor.
>
> **Result:**
> ```
> notes_app/
>   templates/
>     base.html                ← Bootstrap CDN (level 1)
>     layouts/dashboard.html   ← Sidebar + Topbar (level 2)
>     notes_app/note_list.html ← Content (level 3, 8 lines of code)
> ```

---

## Contents

**Theory** _(read before the code)_
- [01 · TEMPLATE SOUP — the problem we are solving](#01--template-soup)
- [02 · THE 3-LEVEL HIERARCHY — base → dashboard → page](#02--the-3-level-hierarchy)
- [03 · CRISPY FORMS — three levels of form rendering](#03--crispy-forms)
- [04 · CONTEXT PROCESSORS — data for all templates](#04--context-processors)
- [05 · STATIC FILES — your own CSS/JS](#05--static-files)
- [06 · TEMPLATE TAGS and FILTERS — reference](#06--template-tags-and-filters--reference)

**Step-by-step implementation**
1. [Step 1 — Install Crispy Forms](#step-1--install-crispy-forms)
2. [Step 2 — Level 1: base.html](#step-2--level-1-basehtml)
3. [Step 3 — Level 2: layouts/dashboard.html](#step-3--level-2-layoutsdashboardhtml)
4. [Step 4 — Level 3: content pages](#step-4--level-3-pages)
5. [Step 5 — NoteForm with FormHelper and Layout](#step-5--noteform-with-formhelper)
6. [Step 6 — Context Processor for the Sidebar](#step-6--context-processor)
7. [Step 7 — Active state in navigation](#step-7--active-state-in-navigation)
8. [Step 8 — Registration in settings.py](#step-8--registration-in-settingspy)

---

## 01 · Template Soup

> What is Template Soup and why is it a problem?

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

## 02 · The 3-level hierarchy

```
base.html                    ← Level 1: HTML skeleton + Bootstrap CDN
│  {% block body %}
│
└── layouts/dashboard.html   ← Level 2: Sidebar + Topbar + Messages
        {% extends 'base.html' %}
        {% block body %}
            <div class="d-flex">
                <nav>Sidebar</nav>
                <main>{% block content %}{% endblock %}</main>
            </div>
        {% endblock %}
        │
        ├── note_list.html       ← Level 3: Content (5-10 lines)
        ├── note_form.html       ← {% crispy form %} — 1 line!
        ├── note_detail.html
        └── notebook_list.html
```

### What each level is responsible for

| Level | File | Responsibility | Changes when... |
|--------|------|-----------------|-------------------|
| 1 | `base.html` | HTML5 structure, Bootstrap CDN, Bootstrap JS | The CDN version changes, global CSS is added |
| 2 | `layouts/dashboard.html` | Sidebar, Topbar, Messages, SaaS layout | Navigation changes, new menu items, a new sidebar |
| 3 | `notes_app/*.html` | Page-specific content | The logic of a specific feature |

### The rule: batch.super

```html
{# If the child wants to EXTEND a block (not overwrite it): #}
{% block extra_css %}
    {{ block.super }}   {# ← inserts the content of the parent block #}
    <link rel="stylesheet" href="{% static 'css/notes-editor.css' %}">
{% endblock %}

{# Result: CSS from layouts/dashboard.html + CSS of this page #}
{# Without block.super: the CSS of layouts/dashboard.html will be REPLACED #}
```

---

## 03 · Crispy Forms

> Three levels of rendering Django forms: from primitive to elegant.

### Tier 1 — Raw Django (for debugging only)

```html
<form method="post">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">OK</button>
</form>
```

```html
<!-- What is generated: no Bootstrap classes, looks bad -->
<p><label for="id_title">Заголовок:</label>
   <input type="text" name="title" id="id_title" maxlength="200" required>
</p>
<p><label for="id_content">Зміст:</label>
   <textarea name="content" id="id_content" rows="10"></textarea>
</p>
```

---

### Tier 2 — Manual Bootstrap

```python
# forms.py — adding Bootstrap classes by hand
class NoteFormTier2(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({'class': 'form-control'})
        self.fields['is_pinned'].widget.attrs['class'] = 'form-check-input'
```

```html
<!-- note_form.html — 15+ lines for EACH field -->
<div class="mb-3">
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
        {{ form.title.label }}<span class="text-danger">*</span>
    </label>
    {{ form.title }}
    {% if form.title.help_text %}
        <div class="form-text">{{ form.title.help_text }}</div>
    {% endif %}
    {% for error in form.title.errors %}
        <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
</div>
<!-- × 6 fields = 90+ lines just for the form -->
```

---

### Tier 3 — Crispy Forms FormHelper + Layout

```python
# forms.py — the whole form structure in Python code
from crispy_forms.helper import FormHelper
from crispy_forms.layout import (
    Layout, Fieldset, Row, Column, Field, Submit, HTML, ButtonHolder
)


class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Restrict the notebook and tags querysets to this user only:
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset     = Tag.objects.filter(user=user)

        # FormHelper describes the <form> attributes and the layout
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id     = 'note-form'

        self.helper.layout = Layout(

            # Fieldset → <fieldset><legend>Основна інформація</legend>...</fieldset>
            Fieldset('Основна інформація',
                Field('title',
                    placeholder='Назва нотатки...',
                    autofocus=True,
                    css_class='form-control-lg',  # a larger input
                ),
                Row(
                    Column('priority', css_class='col-md-4'),
                    # → <div class="col-md-4">...</div>
                    Column('notebook', css_class='col-md-8'),
                ),
            ),

            # The second Fieldset — content and tags
            Fieldset('Зміст та організація',
                Field('content', rows=8, placeholder='Текст нотатки...'),
                Field('tags'),
                Field('is_pinned'),
            ),

            # HTML — arbitrary HTML in the layout
            HTML('<hr class="my-3">'),

            # Buttons
            ButtonHolder(
                Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
                HTML('<a href="{{ cancel_url }}" class="btn btn-outline-secondary">Скасувати</a>'),
            ),
        )
```

```html
{# note_form.html — 1 line instead of 90! #}
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block title %}{{ title }}{% endblock %}
{% block topbar_title %}{{ title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-10 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-body p-4">
                {% crispy form %}
                {#
                    crispy generates automatically:
                    <form method="post" id="note-form">
                      {% csrf_token %}
                      <fieldset>
                        <legend>Основна інформація</legend>
                        <div class="mb-3">
                          <label class="form-label">Назва *</label>
                          <input class="form-control form-control-lg" ...>
                        </div>
                        <div class="row">
                          <div class="col-md-4">...</div>
                          <div class="col-md-8">...</div>
                        </div>
                      </fieldset>
                      ...
                      <button class="btn btn-primary">Зберегти нотатку</button>
                    </form>
                #}
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

### Layout Elements — reference

```python
from crispy_forms.layout import *

# Basic elements:
Field('field_name')                        # A field with label and errors
Field('field_name', css_class='custom')   # + a custom class
Field('field_name', placeholder='...')    # + an HTML attribute
Field('field_name', rows=8)               # Textarea rows

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
# → a custom class

ButtonHolder(Submit('s', 'OK'), HTML('<a href="#">Cancel</a>'))
# → a wrapper for buttons
```

---

## 04 · Context Processors

> **Problem:** The Sidebar shows the list of notebooks and tags on EVERY page.
> If you pass them from every view — code duplication in 20 places.

### How Context Processors work

```
HTTP Request
    ↓
Middleware pipeline
    ↓
View function (view_func)
    ↓
render(request, 'template.html', {'notes': notes})  ← view context
    ↓
Django Template Engine:
    1. Collects the context from the view: {'notes': notes}
    2. AUTOMATICALLY runs each context_processor(request) from settings.py
    3. Merged context = view context + processor contexts
    4. Renders the template with the merged context

All context_processors:
  django.template.context_processors.debug  → {{ debug }}
  django.template.context_processors.request → {{ request }}
  django.contrib.auth.context_processors.auth → {{ user }}, {{ perms }}
  django.contrib.messages.context_processors.messages → {{ messages }}
  hello_app.context_processors.sidebar_context → {{ sidebar_notebooks }}, {{ sidebar_tags }}
```

### Writing a Context Processor

`hello_app/context_processors.py`:

```python
from . import selectors


def sidebar_context(request):
    """
    Automatically adds to EVERY template:
      sidebar_notebooks → QuerySet of the user's notebooks
      sidebar_tags      → QuerySet of the user's tags

    Condition: only for logged-in users.
    For AnonymousUser we return {} (an empty dictionary).
    """
    if not request.user.is_authenticated:
        return {}   # ← AnonymousUser has no notebooks/tags

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags':      selectors.get_user_tags(request.user),
    }
```

### When context_processors are NOT a good fit

```python
# Do not use a context_processor for:
# 1. Heavy SQL queries (they run on EVERY page)
# 2. Variables specific to a single page (pass them in the render context)
# 3. Data that needs URL parameters (url kwargs are not available)

# For a heavy sidebar: caching
from django.core.cache import cache

def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}

    cache_key = f'sidebar_notebooks_{request.user.id}'
    notebooks = cache.get(cache_key)
    if notebooks is None:
        notebooks = list(selectors.get_user_notebooks(request.user))
        cache.set(cache_key, notebooks, timeout=300)  # 5 minutes

    return {'sidebar_notebooks': notebooks}
```

---

## 05 · Static Files

> Your own CSS/JS/images are Django static files.

### Where Django looks for static files

```
1. APP_DIRS (STATICFILES_FINDERS):
   hello_app/static/hello_app/style.css
   → URL: /static/hello_app/style.css

2. STATICFILES_DIRS in settings.py:
   BASE_DIR / 'static'
   → The global static/ folder

3. collectstatic (production):
   python manage.py collectstatic
   → Copies into STATIC_ROOT → served by nginx
```

### Including your own CSS

```python
# settings.py:
STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']   # Global folder for development
STATIC_ROOT = BASE_DIR / 'staticfiles'     # Production: collectstatic
```

```html
{# In the template: #}
{% load static %}
<link rel="stylesheet" href="{% static 'hello_app/css/custom.css' %}">
<img src="{% static 'hello_app/images/logo.png' %}" alt="Logo">
<script src="{% static 'hello_app/js/notes.js' %}"></script>

{# {% static 'path' %} generates: /static/path #}
{# In production (with a CDN): it may generate https://cdn.example.com/static/path #}
```

---

## 06 · Template Tags and Filters — reference

### Built-in Filters

```html
{# Strings: #}
{{ title|truncatechars:50 }}        → The first 50 characters + "..."
{{ title|truncatewords:10 }}        → The first 10 words + "..."
{{ text|linebreaks }}               → \n → <br><p>
{{ text|linebreaksbr }}             → \n → <br>
{{ text|striptags }}                → Strip HTML tags
{{ html|safe }}                     → Do not escape (⚠️ XSS if it is user input!)
{{ value|escape }}                  → Escape HTML (default)
{{ email|urlize }}                  → URL/email → <a href>

{# Numbers: #}
{{ count|floatformat:2 }}           → 3.14159 → "3.14"
{{ count|filesizeformat }}          → 1024 → "1.0 KB"
{{ price|intcomma }}                → 1000000 → "1,000,000"

{# Dates: #}
{{ date|date:"d.m.Y" }}             → 13.06.2026
{{ date|date:"D, d M Y H:i" }}      → Fri, 13 Jun 2026 10:00
{{ date|time:"H:i" }}               → 10:00
{{ date|timesince }}                → "5 hours ago" / "2 days ago"
{{ date|timeuntil }}                → "3 days" (until a future date)
{{ date|naturalday }}               → "today" / "yesterday" (humanize)

{# Lists: #}
{{ items|length }}                  → 42
{{ items|first }}                   → the first element
{{ items|last }}                    → the last element
{{ items|join:", " }}               → "one, two, three"
{{ items|slice:":5" }}              → the first 5 elements
{{ items|dictsort:"name" }}         → sort by name

{# Logic: #}
{{ value|default:"Не вказано" }}    → if False/None/empty
{{ value|default_if_none:"—" }}     → only if None
{{ value|yesno:"так,ні,може" }}     → True→так, False→ні, None→може

{# URL: #}
{% load static %}
{% static 'hello_app/logo.png' %}
{% url 'hello_app:note_list' %}
{% url 'hello_app:note_detail' pk=note.pk %}
```

### Template Tags

```html
{# Conditionals: #}
{% if condition %}
{% elif other %}
{% else %}
{% endif %}

{% if user.is_authenticated %}
{% if note.priority == 3 %}
{% if note.is_pinned and not note.is_archived %}
{% if tag in note.tags.all %}

{# Loops: #}
{% for item in items %}
    {{ forloop.counter }}     ← 1-based
    {{ forloop.counter0 }}    ← 0-based
    {{ forloop.revcounter }}  ← reverse
    {{ forloop.first }}       ← True only for the first
    {{ forloop.last }}        ← True only for the last
    {{ forloop.parentloop }}  ← nested loops
{% empty %}
    <p>Немає елементів</p>
{% endfor %}

{# Templates: #}
{% extends 'base.html' %}
{% block name %}...{% endblock %}
{% block name %}{{ block.super }}...{% endblock %}
{% include 'hello_app/_card.html' with note=note only %}
{# only: pass only the specified variables, not the whole context #}

{# Loading libraries: #}
{% load static %}
{% load django_bootstrap5 %}
{% load crispy_forms_tags %}
{% load humanize %}
{# Needed for naturalday, intcomma, etc. #}

{# CSRF: #}
{% csrf_token %}
{# Generates: <input type="hidden" name="csrfmiddlewaretoken" value="...abc..."> #}

{# URL: #}
{% url 'hello_app:note_detail' pk=note.pk %}
{% url 'hello_app:note_list' %}

{# Comments (do not end up in the HTML): #}
{# A single-line comment #}
{% comment %}
    A multi-line comment
    It is not rendered!
{% endcomment %}
```

---

## Step 1 — Install Crispy Forms

```bash
pip install django-crispy-forms crispy-bootstrap5
```

`hello_project/settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'crispy_forms',         # ← the core package
    'crispy_bootstrap5',    # ← Bootstrap 5 template pack
    'hello_app',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK           = 'bootstrap5'
# ↑ Tells crispy_forms which template pack to use
# bootstrap5 → generates Bootstrap 5 HTML (mb-3, form-control, form-label...)
```

---

## Step 2 — Level 1: base.html

`templates/base.html` — only the HTML skeleton and the Bootstrap CDN. Nothing about the Sidebar.

```
templates/
├── base.html              ← Level 1 (not in hello_app/)
└── layouts/
    └── dashboard.html     ← Level 2
```

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}CrispyNotes{% endblock %}</title>

    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          crossorigin="anonymous">
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    {% block extra_css %}{% endblock %}
    {# A child can add page-specific CSS #}
</head>
<body>
    {% block body %}{% endblock %}
    {# The whole body = one big block → dashboard.html will fill in Sidebar+Topbar+Content #}

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}
    {# A child can add page-specific JS (Leaflet, Chart.js, etc.) #}
</body>
</html>
```

`base.html` knows nothing about the Sidebar or navigation — only the Bootstrap CDN and blocks.

---

## Step 3 — Level 2: layouts/dashboard.html

`templates/layouts/dashboard.html` — a SaaS layout with a fixed Sidebar.

```html
{% extends 'base.html' %}

{% block body %}
<!--
    d-flex: body = a flex row (sidebar | main)
    vh-100: takes 100% of the window height
    overflow-hidden: we control scrolling inside .flex-grow-1
-->
<div class="d-flex vh-100 overflow-hidden">

    <!-- ══════════════════ SIDEBAR ══════════════════ -->
    <nav id="sidebar"
         class="bg-dark text-white d-flex flex-column p-3 flex-shrink-0"
         style="width: 260px; min-width: 260px;">

        <!-- Brand -->
        <a href="{% url 'hello_app:note_list' %}"
           class="text-white text-decoration-none fw-bold fs-5 mb-4 d-block">
            <i class="bi bi-journal-text me-2 text-primary"></i>CrispyNotes
        </a>

        <!-- Navigation: notes -->
        <div class="mb-3">
            <small class="text-uppercase text-secondary d-block mb-1 px-2" style="font-size:.7rem">
                Нотатки
            </small>
            <ul class="nav flex-column">
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_list' %}"
                       class="nav-link text-white py-1
                              {% if request.resolver_match.url_name == 'note_list' %}
                              active bg-primary rounded
                              {% endif %}">
                        <i class="bi bi-list-ul me-2"></i>Всі нотатки
                    </a>
                    {#
                        request.resolver_match.url_name:
                        Returns the name= parameter of the current URL from urls.py.
                        'note_list' → highlights the item when the user is on /notes/
                    #}
                </li>
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_create' %}"
                       class="nav-link text-white py-1">
                        <i class="bi bi-plus-circle me-2"></i>Нова нотатка
                    </a>
                </li>
            </ul>
        </div>

        <!-- Notebooks (from the Context Processor) -->
        {% if sidebar_notebooks %}
        <div class="mb-3">
            <small class="text-uppercase text-secondary d-block mb-1 px-2" style="font-size:.7rem">
                Записники
            </small>
            <ul class="nav flex-column">
                {% for nb in sidebar_notebooks %}
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_list' %}?notebook={{ nb.pk }}"
                       class="nav-link text-white-50 py-1 small">
                        <i class="bi bi-journal me-2"></i>
                        {{ nb.title|truncatechars:18 }}
                        {% if nb.note_count %}
                        <span class="badge bg-secondary ms-1 float-end">{{ nb.note_count }}</span>
                        {% endif %}
                    </a>
                </li>
                {% endfor %}
            </ul>
        </div>
        {% endif %}

        <!-- Tags (from the Context Processor) -->
        {% if sidebar_tags %}
        <div class="mb-auto">
            <small class="text-uppercase text-secondary d-block mb-2 px-2" style="font-size:.7rem">
                Теги
            </small>
            <div class="d-flex flex-wrap gap-1 px-2">
                {% for tag in sidebar_tags %}
                <a href="{% url 'hello_app:note_list' %}?tag={{ tag.pk }}"
                   class="badge text-decoration-none"
                   style="background-color: {{ tag.color }}; font-size: .75rem;">
                    #{{ tag.name }}
                    {% if tag.note_count %}
                    <span class="ms-1">({{ tag.note_count }})</span>
                    {% endif %}
                </a>
                {% endfor %}
            </div>
        </div>
        {% endif %}

        <!-- The user at the bottom of the sidebar -->
        <div class="mt-auto pt-3 border-top border-secondary">
            {% if request.user.is_authenticated %}
            <div class="d-flex align-items-center gap-2">
                <div class="rounded-circle bg-primary d-flex align-items-center justify-content-center"
                     style="width:32px; height:32px; flex-shrink:0;">
                    <span class="text-white small fw-bold">
                        {{ request.user.username|first|upper }}
                    </span>
                </div>
                <div class="text-truncate">
                    <div class="text-white small fw-semibold">{{ request.user.username }}</div>
                    <div class="text-white-50" style="font-size:.7rem;">{{ request.user.email }}</div>
                </div>
            </div>
            <form method="post" action="{% url 'logout' %}" class="mt-2">
                {% csrf_token %}
                <button type="submit" class="btn btn-outline-secondary btn-sm w-100">
                    <i class="bi bi-box-arrow-right me-1"></i>Вийти
                </button>
            </form>
            {% endif %}
        </div>

    </nav>
    <!-- ══════════════════ END SIDEBAR ══════════════════ -->

    <!-- ══════════════════ MAIN AREA ══════════════════ -->
    <div class="flex-grow-1 d-flex flex-column overflow-hidden">

        <!-- Topbar -->
        <header class="border-bottom bg-white px-4 py-2 d-flex align-items-center justify-content-between flex-shrink-0">
            <h1 class="h5 mb-0 fw-semibold">
                {% block topbar_title %}CrispyNotes{% endblock %}
            </h1>
            <div class="d-flex align-items-center gap-2">
                <!-- Search (optional) -->
                {% block topbar_actions %}{% endblock %}
            </div>
        </header>

        <!-- Django Messages -->
        {% if messages %}
        <div class="px-4 pt-2">
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-2" role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
            {% endfor %}
        </div>
        {% endif %}

        <!-- Page content -->
        <main class="flex-grow-1 overflow-auto p-4">
            {% block content %}{% endblock %}
        </main>

    </div>
    <!-- ══════════════════ END MAIN AREA ══════════════════ -->

</div>
{% endblock %}
```

---

## Step 4 — Level 3: pages

A new page = **5 lines**. The Sidebar and Topbar come for free.

```html
{# hello_app/templates/hello_app/note_list.html #}
{% extends 'layouts/dashboard.html' %}

{% block title %}Мої нотатки{% endblock %}
{% block topbar_title %}Нотатки{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h2 class="h4 mb-0">
        Нотатки <span class="badge bg-secondary">{{ notes|length }}</span>
    </h2>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary btn-sm">
        <i class="bi bi-plus-lg me-1"></i>Нова
    </a>
</div>

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm border-0">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-start mb-1">
                    <h5 class="card-title mb-0 small fw-semibold">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark">
                            {% if note.is_pinned %}<i class="bi bi-pin-fill text-warning me-1"></i>{% endif %}
                            {{ note.title|truncatechars:45 }}
                        </a>
                    </h5>
                    {% if note.priority == 3 %}
                        <span class="badge bg-danger-subtle text-danger ms-1 flex-shrink-0">Важливо</span>
                    {% elif note.priority == 2 %}
                        <span class="badge bg-warning-subtle text-warning ms-1 flex-shrink-0">Середнє</span>
                    {% endif %}
                </div>
                <p class="card-text text-muted small mt-1">
                    {{ note.content|truncatechars:80 }}
                </p>
                {% if note.tags.all %}
                <div class="mt-2">
                    {% for tag in note.tags.all %}
                    <a href="?tag={{ tag.pk }}"
                       class="badge text-decoration-none me-1"
                       style="background-color: {{ tag.color }};">
                        #{{ tag.name }}
                    </a>
                    {% endfor %}
                </div>
                {% endif %}
            </div>
            <div class="card-footer bg-transparent border-0 pt-0 pb-2 px-3">
                <small class="text-muted">
                    <i class="bi bi-clock me-1"></i>{{ note.updated_at|timesince }} тому
                </small>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% else %}
<div class="text-center py-5">
    <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>
    <h4 class="text-muted">Ще немає нотаток</h4>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">Створити першу</a>
</div>
{% endif %}
{% endblock %}
```

---

## Step 5 — NoteForm with FormHelper

`hello_app/forms.py`:

```python
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Column, Field, Fieldset, HTML, Layout, Row, Submit
from django import forms

from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Restrict the queryset to this user only (IDOR protection)
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user).order_by('title')
            self.fields['tags'].queryset     = Tag.objects.filter(user=user).order_by('name')
            self.fields['notebook'].empty_label = '— без записника —'

        self.helper = FormHelper()
        self.helper.layout = Layout(
            Fieldset('',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
                Field('content', rows=8, placeholder='Текст нотатки...'),
            ),
            Fieldset('Організація',
                Field('tags'),
                Field('is_pinned'),
            ),
            HTML('<hr class="my-3">'),
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
            HTML('<a href="{% url \'hello_app:note_list\' %}" class="btn btn-outline-secondary">Скасувати</a>'),
        )
```

---

## Step 6 — Context Processor

`hello_app/context_processors.py`:

```python
from . import selectors


def sidebar_context(request):
    """
    Sidebar data for EVERY template.
    Runs automatically before every render.
    """
    if not request.user.is_authenticated:
        return {}   # AnonymousUser → an empty dict

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags':      selectors.get_user_tags(request.user),
    }
```

---

## Step 7 — Active state in navigation

```html
{# Highlight the current menu item: #}
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white
          {% if request.resolver_match.url_name == 'note_list' %}
          active bg-primary rounded
          {% endif %}">
    Всі нотатки
</a>

{# request.resolver_match.url_name = 'note_list' when the URL = /notes/ #}
{# = 'note_create' when /notes/new/ #}
{# = 'note_detail' when /notes/42/ #}

{# For a namespace-aware check: #}
{% if request.resolver_match.view_name == 'hello_app:note_list' %}
{# Includes the namespace, more precise #}

{# For a group of URLs (for example, all note_* URLs): #}
{% if 'note' in request.resolver_match.url_name %}
{# note_list, note_detail, note_edit → all highlighted #}
```

---

## Step 8 — Registration in settings.py

```python
# hello_project/settings.py

INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
    'hello_app',   # context_processors.sidebar_context is here
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK           = 'bootstrap5'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # Global templates/ (for base.html, layouts/)
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
            'hello_app.context_processors.sidebar_context',   # ← our processor
            # Now sidebar_notebooks and sidebar_tags are available in ALL templates!
        ],
    },
}]
```

---

## File locations

```
hello_project/                   ← Project root
├── hello_project/
│   ├── settings.py              ← CRISPY_*, TEMPLATES with context_processors
│   └── urls.py
│
├── templates/                   ← Global folder (DIRS in settings)
│   ├── base.html                ← Level 1: HTML + Bootstrap CDN
│   └── layouts/
│       └── dashboard.html       ← Level 2: Sidebar + Topbar
│
└── hello_app/
    ├── context_processors.py   ← sidebar_context()
    ├── forms.py                 ← NoteForm with FormHelper
    ├── selectors.py
    ├── services.py
    ├── views.py
    └── templates/
        └── hello_app/           ← Level 3: content pages
            ├── note_list.html
            ├── note_form.html   ← {% crispy form %} — 1 line!
            ├── note_detail.html
            └── note_confirm_delete.html
```

---

## How Django finds a template

```
render(request, 'hello_app/note_list.html', context)
    ↓
Django searches in DIRS:
  1. BASE_DIR/templates/hello_app/note_list.html → not found

Django searches in APP_DIRS (each INSTALLED_APP):
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
Blocks are filled from the specific to the general.
```

---

## Practical exercise

1. Open `hello_app/templates/hello_app/note_list.html` → `templates/layouts/dashboard.html` → `templates/base.html`. Trace the `{% extends %}` chain.
2. Add a new Sidebar item for "Archive" (`/notes/?archived=1`).
3. Rewrite one form from hand-written Bootstrap HTML to Crispy FormHelper + Layout.
4. Check the active state: as you click different menu items, the highlight moves.
5. Add a Context Processor that passes the number of new notes created today.

---

## Self-check checklist

- [ ] 3 levels: `base.html` → `layouts/dashboard.html` → page template
- [ ] `{% block body %}` in `base.html`, `{% block content %}` in `dashboard.html`
- [ ] The Context Processor is registered in `settings.py` → `context_processors`
- [ ] `sidebar_notebooks` and `sidebar_tags` are available in the template without passing them explicitly
- [ ] `{% crispy form %}` renders the form with Bootstrap classes
- [ ] `FormHelper.layout` describes the form structure in Python code
- [ ] Active state via `request.resolver_match.url_name`
- [ ] Logout — a POST form (not a GET link) for CSRF protection
- [ ] `DIRS = [BASE_DIR / 'templates']` in `TEMPLATES` — for global templates

---

## Summary

| Concept | Where in the code |
|-----------|-----------|
| 3-level hierarchy | `base.html` → `layouts/dashboard.html` → `note_list.html` |
| `{% block %}` | `{% block content %}{% endblock %}` in the parent + `{% block content %}...{% endblock %}` in the child |
| `{{ block.super }}` | Adds the content of the parent block instead of replacing it |
| FormHelper | `self.helper = FormHelper()` in `forms.py.__init__` |
| Layout | `Layout(Fieldset(...), Row(Column(...)), Submit(...))` |
| `{% crispy form %}` | In the template — 1 line instead of 90 |
| Context Processor | `hello_app/context_processors.py → sidebar_context(request)` |
| Registering the processor | `settings.py TEMPLATES OPTIONS context_processors` |
| Active nav | `request.resolver_match.url_name == 'note_list'` |
| Static files | `{% load static %}{% static 'hello_app/css/custom.css' %}` |

---

## Next

Next step: [05 — Authentication and Security](05_authentication.md) — Login/logout, sessions, password reset, IDOR, Groups.

Documentation modules:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
- [Application Architecture](../06_application_architecture/README.md)
