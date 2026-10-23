# Advanced Django Templates — Production-Grade Architecture

> A continuation of `DJANGO_TEMPLATES_BOOTSTRAP.md` and `DJANGO_NINJA_TEMPLATES.md`.
> Here: Context Processors, Custom Template Tags, crispy-forms,
> the Vite asset pipeline, SaaS Dashboard Architecture.

---


## Contents

- [1. Context Processors — global context](#1-context-processors--global-context)
- [2. Custom Template Tags — simple_tag, inclusion_tag, filter](#2-custom-template-tags)
- [3. crispy-forms — Python form layouts](#3-crispy-forms--python-form-layouts)
- [4. Vite + ManifestStaticFilesStorage — a modern asset pipeline](#4-vite--manifeststaticfilesstorage--a-modern-asset-pipeline)
- [5. SaaS Dashboard Architecture — sidebar, CRUD, reusable components](#5-saas-dashboard-architecture)
- [6. Jinja2 Deep Dive — macros, Environment, bytecode cache](#6-jinja2-deep-dive)
- [7. HTMX Architecture — the full lifecycle, Server-Driven UI](#7-htmx-architecture--the-full-lifecycle)
- [8. Self-check questions](#8-self-check-questions)
---

---
- **🧠 Mental model:** Context Processors are "global variables" for templates. Imagine there is data that EVERY template in your project needs — the site name, the number of notifications, the current user. Without context processors you have to pass this data manually in every view. Context processors automatically "inject" this data into every template, as if it had always been there.
- **📚 Why it exists:** Django deliberately separates logic (views) from presentation (templates). Context processors are the official mechanism for passing "ambient" data (data from the surrounding environment) into templates without wiring up every view manually.
- **🌐 What happens under the hood:** On every call to `render(request, template, context)` Django collects all registered context processors, calls each of them with `request`, gets a dict from each one, and then MERGES all of these dicts together with the context you passed from the view. Only after that is the template rendered with the combined context.
- **❌ Common beginner mistake:** Forgetting to register a custom context processor in `settings.py` → the variable in the template is simply empty, with no errors. Even worse — running a heavy DB query in a context processor without caching. It runs on EVERY HTTP request.
---

## §1. Context Processors — Global Context

Context processors solve the classic DRY (Don't Repeat Yourself) problem in Django views. First, let's look at what happens WITHOUT them — and why that is bad.

Imagine that every view has to manually collect the data that every template needs:

```python
# ❌ Without context processors: every view has to do this:
def notes_view(request):
    return render(request, 'notes.html', {
        'user': request.user,
        'site_name': settings.SITE_NAME,
        'notifications_count': Notification.objects.filter(user=request.user).count(),
        # ... every view has to repeat this
    })

def dashboard_view(request):
    return render(request, 'dashboard.html', {
        'user': request.user,           # ← a copy
        'site_name': settings.SITE_NAME, # ← a copy
        'notifications_count': ...,      # ← a copy
    })
```

Context processors solve this: they run ONCE per request and automatically add the data to EVERY template. Here is what the call chain looks like:

```
Request arrives
     ↓
Django calls each context processor in CONTEXT_PROCESSORS list
     ↓
Each processor returns a dict
     ↓
All dicts are MERGED into the template context
     ↓
Template renders with merged context
```

Notice: the built-in `django.contrib.auth.context_processors.auth` adds `{{ user }}` and `{{ perms }}` to EVERY template — that is exactly why you can use `{{ user.username }}` in any template without adding it in every view.

### The problem without Context Processors

Below is a concrete demonstration of the problem: two ordinary views that are forced to repeat the same context-collecting code:

```python
# ❌ Repeating ourselves in every view
def notes_list(request):
    return render(request, 'notes/list.html', {
        'user': request.user,
        'site_name': 'MyApp',
        'unread_count': Notification.objects.filter(user=request.user, read=False).count(),
    })

def notes_detail(request, pk):
    return render(request, 'notes/detail.html', {
        'user': request.user,           # ← again
        'site_name': 'MyApp',           # ← again
        'unread_count': ...,            # ← again
    })
```

### Built-in Context Processors

Django ships with a set of built-in context processors. These lines in `settings.py` define which of them are active. Each processor is a Python function that takes `request` and returns a dict:

```python
# settings.py — TEMPLATES → OPTIONS → context_processors
'context_processors': [
    'django.template.context_processors.debug',      # {{ debug }}
    'django.template.context_processors.request',    # {{ request }}
    'django.contrib.auth.context_processors.auth',   # {{ user }}, {{ perms }}
    'django.contrib.messages.context_processors.messages',  # {{ messages }}
],
```

| Processor | What it adds to the context | When to use it |
|----------|---------------------|----------------------|
| `debug` | `{{ debug }}` — True/False | Conditionally showing debug blocks |
| `request` | `{{ request.user }}`, `{{ request.path }}` | A navbar with the current URL, breadcrumbs |
| `auth` | `{{ user }}`, `{{ perms.app.permission }}` | Auth checks in templates |
| `messages` | `{% for msg in messages %}` | Django Messages → Bootstrap Alert |

### A custom Context Processor

Here we write our own context processor. Notice its structure: it is an ordinary Python function that takes `request` and returns a dict. Django itself takes care of calling this function and merging the result into the template context:

```python
# notes_app/context_processors.py

from .models import Notification

def global_context(request):
    """Data for all of the app's templates."""
    context = {
        'site_name': 'Bootstrap Notes',
        'site_version': '2.0',
    }
    
    # Only for authenticated users
    if request.user.is_authenticated:
        context['unread_notifications'] = (
            Notification.objects
            .filter(user=request.user, read=False)
            .count()
        )
    
    return context
```

After writing the function, you have to register it in `settings.py`. Django does not "find" context processors automatically — each one must be added manually:

```python
# settings.py — registration
'context_processors': [
    ...
    'notes_app.context_processors.global_context',  # ← add this
],
```

After registration, the `unread_notifications` variable becomes available in ANY template of the project — without a single line of code in the view:

```html
{# base.html — now available everywhere without passing it from the view #}
<span class="badge bg-danger">{{ unread_notifications }}</span>
```

### The Context Processor call chain

This diagram shows the exact order in which Django assembles the context before rendering a template. Important: the view context OVERRIDES identical keys from context processors — the view always takes priority:

```
RequestFactory
    ↓ request
    ↓
Context Processors (all are called for every render())
    ↓ merged dict
    ↓
View context (overrides identical keys)
    ↓
Template Engine
```

> **Rule:** A Context Processor must not run heavy queries without caching.
> It runs for **every** HTTP request.

### Caching in a Context Processor

This is a critically important pattern for production. Because a context processor runs on EVERY request, a DB query in it without caching can cause hundreds of unnecessary queries per second. Here is the correct approach with a Redis/Memcached cache via the Django cache framework:

```python
from django.core.cache import cache

def global_context(request):
    if request.user.is_authenticated:
        cache_key = f'unread_count_{request.user.pk}'
        count = cache.get(cache_key)
        if count is None:
            count = Notification.objects.filter(
                user=request.user, read=False
            ).count()
            cache.set(cache_key, count, timeout=60)  # 1 minute
        return {'unread_notifications': count}
    return {}
```

---

---
- **🧠 Mental model:** Custom Template Tags are Python functions you can call DIRECTLY FROM TEMPLATES. The Django Template Language (DTL) is deliberately limited: you cannot call arbitrary Python functions in a template. Custom tags are the official "safe bridge" between a template and Python logic.
- **📚 Why it exists:** Separation of concerns: templates are responsible for display, Python for logic. But sometimes you need "light logic" right at render time (formatting a Badge, checking permissions, counting). Custom tags provide this safely, without breaking the architecture.
- **🌐 What happens under the hood:** `{% load hello_tags %}` makes Django find the `hello_tags.py` module in any `templatetags/` folder of the installed apps. Django AUTO-DISCOVERS `templatetags/` folders — if an app is in `INSTALLED_APPS`, Django scans its `templatetags/`. `register = template.Library()` registers functions as tags. During rendering Django calls the registered Python function and substitutes the result into the HTML.
- **❌ Common beginner mistake:** Forgetting `{% load hello_tags %}` at the top of the template — the tag simply will not work. Or running a DB query in a `simple_tag` that is called in a loop over 100 items — a classic source of N+1.
---

## §2. Custom Template Tags

### Why Custom Tags?

DTL is deliberately limited — no function calls, no complex logic.
Custom Tags let you extend DTL safely: logic in Python, presentation in the template.

The Django Template Language does not allow `{{ Note.objects.count() }}` — it is a syntax error. But what if you need to show the number of notes in the sidebar? Custom tags are the answer.

There are three types of custom tags, each for its own job:

```
simple_tag   → Python function → returns a VALUE (number, string)
inclusion_tag → Python function → returns a CONTEXT → renders a TEMPLATE
filter       → Python function → transforms a VALUE → returns the transformed VALUE
```

The `templatetags/` folder name is mandatory. Django automatically finds `templatetags/` folders in all installed apps. `__init__.py` makes the folder a Python package:

### Structure

```
notes_app/
├── templatetags/          ← mandatory directory name
│   ├── __init__.py        ← empty file
│   └── hello_tags.py      ← your tags
```

`register = template.Library()` is the tag registry. The decorators `@register.simple_tag`, `@register.inclusion_tag`, `@register.filter` register Python functions as DTL tags:

```python
# notes_app/templatetags/hello_tags.py
from django import template
from django.utils.html import format_html
from notes_app.models import Note

register = template.Library()
```

---
- **🧠 Mental model:** `simple_tag` = function → value. Think of it as `{{ variable }}`, except the value is computed by a Python function at render time instead of being passed from the view.
- **📚 Why it exists:** Sometimes a value depends on template parameters or needs a light computation. For example: `{% multiply price quantity %}` is clearer and safer than passing precomputed data from every view.
- **🌐 What happens under the hood:** When it meets `{% multiply 6 7 %}`, Django parses the arguments, finds the registered `multiply` function, calls `multiply(6, 7)` and substitutes the returned value into the HTML. `takes_context=True` passes the whole current template context as the first argument — that is how you can get `request`, `user` and everything else.
- **❌ Common beginner mistake:** Running a DB query in a `simple_tag` that is called inside a loop `{% for note in notes %}{% notes_count request.user %}{% endfor %}` — that is 100+ DB queries instead of one. Always count how many times a tag is called.
---

### simple_tag — returns a value

`simple_tag` is the simplest type. The function takes arguments and returns a value that is substituted into the HTML. `takes_context=True` gives access to the whole template context, including `request`:

```python
@register.simple_tag
def multiply(a, b):
    return a * b

@register.simple_tag(takes_context=True)
def current_user_name(context):
    user = context['request'].user
    return user.get_full_name() or user.username

@register.simple_tag
def notes_count(user=None):
    qs = Note.objects.all()
    if user:
        qs = qs.filter(author=user)
    return qs.count()
```

Note the call syntax: `{% tag_name arg1 arg2 %}`. The `as my_count` construct stores the result in a context variable instead of outputting it — that way you can use the value several times:

```html
{% load hello_tags %}

{# Basic call #}
{% multiply 6 7 %}           {# → 42 #}

{# Store in a variable #}
{% notes_count request.user as my_count %}
<span>Твоїх нотаток: {{ my_count }}</span>

{# With context #}
{% current_user_name %}      {# → "Victor Nikoriak" #}
```

---
- **🧠 Mental model:** `inclusion_tag` = a mini-view inside a template. The function returns a CONTEXT (dict), and Django renders a separate HTML template with that context and inserts the result into the current template. This is the closest thing to a "component system" in DTL.
- **📚 Why it exists:** For reusable UI components that have their own logic. For example: a notification badge is needed in the navbar of every page, but it has its own logic (counting, checking authentication). Moving this logic into every view breaks DRY.
- **🌐 What happens under the hood:** `@register.inclusion_tag('partial.html', takes_context=True)` tells Django: "call this function, get a dict, render `partial.html` with that dict as the context, and insert the resulting HTML into the parent template".
- **❌ Common beginner mistake:** Passing the parent template's full context (`return context`) instead of a minimal context for the sub-template. This can lead to unexpected variables and hard debugging.
---

### inclusion_tag — renders a sub-template

`inclusion_tag` returns a dict that becomes the context for a separate HTML template. It is a powerful mechanism for reusable components: badge, avatar, breadcrumbs, navigation. Real use cases: a notification badge in the navbar, a user avatar with a name, breadcrumb navigation:

```python
@register.inclusion_tag('notes_app/partials/notification_badge.html',
                         takes_context=True)
def notification_badge(context):
    request = context['request']
    if not request.user.is_authenticated:
        return {'count': 0}
    
    count = Notification.objects.filter(
        user=request.user, read=False
    ).count()
    return {'count': count, 'user': request.user}
```

This template is rendered SEPARATELY from the parent one, with its own context. It knows nothing about the parent template — only about what the function returned:

```html
{# notes_app/partials/notification_badge.html #}
{% if count %}
<a href="{% url 'notifications' %}" class="btn position-relative">
    <i class="bi bi-bell"></i>
    <span class="position-absolute top-0 start-100 translate-middle
                 badge rounded-pill bg-danger">
        {{ count }}
    </span>
</a>
{% endif %}
```

Calling the tag in a template looks like any other tag. Django itself finds the Python function, calls it, renders the sub-template and puts the result in place of the tag:

```html
{# base.html — usage #}
{% load hello_tags %}
<nav class="navbar navbar-dark bg-dark">
    ...
    {% notification_badge %}   {# ← inserts notification_badge.html #}
</nav>
```

---
- **🧠 Mental model:** `filter` = transforming a value in a pipeline. `{{ value|my_filter:arg }}` reads as "take `value`, pass it through `my_filter` with the argument `arg`, output the result". It is a Unix pipe for template values.
- **📚 Why it exists:** For transformations closely tied to presentation (formatting a date, shortening text, converting a status into a color). Filters are the "vocabulary" of your templates.
- **🌐 What happens under the hood:** Django auto-escapes all template output to protect against XSS. `format_html()` is the CORRECT way to build HTML strings in Python: it escapes the variables (XSS protection) but preserves your HTML structure. NEVER use string concatenation or `mark_safe` for user-provided content — that is an XSS vulnerability.
- **❌ Common beginner mistake:** Writing `return f'<span class="badge bg-{color}">{status}</span>'` instead of `format_html(...)`. If `status` contains `<script>alert('XSS')</script>`, the first version will execute the script in the browser. `format_html` automatically escapes all variables.
---

### filter — transforming a value

Django automatically escapes all template output to protect against XSS. `format_html` is the CORRECT way to build HTML strings in Python: it escapes variables but preserves your HTML structure. NEVER use string concatenation or `mark_safe` for user-provided content — that is an XSS vulnerability.

The first filter, `truncate_words`, is safe: it returns plain text without HTML. The second, `status_badge`, returns HTML, so `format_html` is mandatory:

```python
@register.filter(name='truncate_words')
def truncate_words(value, num_words):
    words = str(value).split()
    if len(words) <= num_words:
        return value
    return ' '.join(words[:num_words]) + '...'

@register.filter
def status_badge(status):
    """Note status → Bootstrap badge HTML."""
    colors = {
        'draft': 'secondary',
        'published': 'success',
        'archived': 'warning',
    }
    color = colors.get(status, 'primary')
    return format_html(
        '<span class="badge bg-{}">{}</span>',
        color,
        status.capitalize()
    )
```

Filter syntax in a template: `{{ value|filter_name:argument }}`. Filters can be chained: `{{ value|filter1|filter2:arg }}`:

```html
{% load hello_tags %}

{{ note.body|truncate_words:20 }}
{{ note.status|status_badge }}
```

### Comparing Template Tag types

| Type | Syntax in the template | Returns | When to use it |
|-----|---------------------|----------|----------------------|
| `simple_tag` | `{% my_tag arg %}` | A value | Computations, DB queries |
| `inclusion_tag` | `{% my_tag %}` | Renders HTML | Reusable components (badge, card) |
| `filter` | `{{ value\|my_filter }}` | A transformed value | Formatting strings, colors |
| `block tag` | `{% my_tag %}...{% end_my_tag %}` | An HTML block | Complex wrappers (permission check, cache) |

---

---
- **🧠 Mental model:** crispy-forms = Django forms + Bootstrap/Tailwind styling, through a Pythonic Layout API instead of HTML templates. Think of it this way: instead of writing Bootstrap HTML by hand for every form field, you describe the form's STRUCTURE in Python, and crispy-forms generates the Bootstrap HTML automatically.
- **📚 Why it exists:** Django forms generate minimal HTML (`<input>`, `<label>`) without Bootstrap classes. For every Bootstrap field you would have to write `<div class="mb-3"><label class="form-label">...</label><input class="form-control">...`. crispy-forms automates this boilerplate and lets you describe the form layout in Python.
- **🌐 What happens under the hood:** `FormHelper` does not change the form's validation — it ONLY changes how it is rendered to HTML. `Layout` is a tree of Python objects describing the structure: `Row(Column('field1'), Column('field2'))` = a Bootstrap 2-column layout. During rendering crispy-forms walks this tree and generates the matching Bootstrap HTML for each node.
- **❌ Common beginner mistake:** Thinking that crispy-forms affects the form's validation or behavior. It ONLY affects how the HTML looks. Also: using `{{ form.as_p }}` and `{{ form|crispy }}` at the same time — pick one approach.
---

## §3. crispy-forms — Python Form Layouts

Here is a concrete demonstration of the problem: the HTML you have to write BY HAND for every Bootstrap form without crispy-forms. Notice how many lines it takes for just a few fields:

### The problem with plain Django forms

```html
{# ❌ The template is overloaded with form HTML logic #}
<form method="post">
    {% csrf_token %}
    {% for field in form %}
        <div class="mb-3">
            <label for="{{ field.id_for_label }}" class="form-label">
                {{ field.label }}
                {% if field.field.required %}<span class="text-danger">*</span>{% endif %}
            </label>
            {{ field }}
            {% if field.errors %}
                {% for error in field.errors %}
                    <div class="invalid-feedback d-block">{{ error }}</div>
                {% endfor %}
            {% endif %}
        </div>
    {% endfor %}
    <button type="submit" class="btn btn-primary">Зберегти</button>
</form>
```

### crispy-forms + crispy-bootstrap5

Installing two packages: `django-crispy-forms` is the main package, `crispy-bootstrap5` is the template pack for Bootstrap 5. They are separate so that different CSS frameworks can be supported (Tailwind, Bootstrap 4/5):

```bash
pip install django-crispy-forms crispy-bootstrap5
```

`CRISPY_TEMPLATE_PACK` tells crispy-forms which HTML to generate. For Bootstrap 5 it knows the right classes, structure and attributes:

```python
# settings.py
INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"
```

#### Option 1 — quick (template tag)

The simplest option: the `|crispy` filter turns an ordinary Django form into Bootstrap-styled HTML automatically. This is the "quick start mode" — zero configuration:

```html
{% load crispy_forms_tags %}

<form method="post">
    {% csrf_token %}
    {{ form|crispy }}
    <button type="submit" class="btn btn-primary">Зберегти</button>
</form>
```

#### Option 2 — FormHelper (a Python layout)

`FormHelper` is defined right inside the form class — this matters. The layout logic lives in the same place as the form instead of being scattered across templates. `Layout` is a Python tree that describes the structure: `Fieldset` → `Row` → `Column` → fields. `{% crispy form %}` renders the whole `<form>` tag, including `action`, `method` and `id` from the `FormHelper`:

```python
# notes_app/forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import (
    Layout, Submit, Row, Column, Fieldset, HTML, Div
)
from .models import Note

class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'body', 'category', 'tags', 'is_public']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id = 'note-form'
        
        self.helper.layout = Layout(
            Fieldset(
                'Основна інформація',
                'title',
                Row(
                    Column('category', css_class='col-md-6'),
                    Column('tags', css_class='col-md-6'),
                ),
            ),
            Fieldset(
                'Зміст',
                'body',
            ),
            Div(
                'is_public',
                css_class='form-check mb-3',
            ),
            HTML("""
                <hr>
                <p class="text-muted">
                    <i class="bi bi-info-circle"></i>
                    Публічні нотатки видні всім користувачам.
                </p>
            """),
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary'),
        )
```

`{% crispy form %}` is all you need in the template. All the Bootstrap HTML is generated automatically from the `FormHelper` and `Layout` defined in the form class:

```html
{% load crispy_forms_tags %}

{% crispy form %}   {# ← renders the whole form from the helper, including the <form> tag #}
```

### FormHelper attributes

A complete reference of `FormHelper` attributes. `form_tag = False` is useful when you need to wrap the form in your own `<form>` tag (for example, for HTMX or multi-step forms). `error_text_inline = True` shows errors next to the field rather than at the top of the form:

```python
helper = FormHelper()

helper.form_method = 'post'           # GET or POST
helper.form_action = '/notes/create/' # action=""
helper.form_id = 'my-form'
helper.form_class = 'needs-validation' # Bootstrap validation class
helper.attrs = {'novalidate': ''}     # HTML attributes

helper.form_tag = False               # Do not render the <form> tag
helper.include_media = True           # Include {{ form.media }}
helper.error_text_inline = True       # Errors next to the field
helper.label_class = 'fw-bold'        # CSS for all labels
helper.field_class = 'col-lg-10'      # CSS for all fields
```

### Layout elements

These classes are the building blocks of a Layout. `Row`/`Column` generate a Bootstrap grid. `Field` lets you add HTML attributes to a specific field. `HTML` inserts arbitrary HTML unchanged — useful for separators, hints, icons:

```python
from crispy_forms.layout import (
    Layout,      # Root container
    Div,         # <div css_class="">
    Row,         # Bootstrap Row
    Column,      # Bootstrap Column
    Fieldset,    # <fieldset><legend>title</legend>...</fieldset>
    HTML,        # An arbitrary HTML string
    Field,       # A field with custom attributes
    Submit,      # <button type="submit">
    Reset,       # <button type="reset">
    Hidden,      # <input type="hidden">
    MultiField,  # Several fields on one line
)

# Field with attributes
Layout(
    Field('title', placeholder='Введіть назву', autofocus=True),
    Field('body', rows=5, css_class='font-monospace'),
)
```

---

---
- **🧠 Mental model:** Vite is a "build system" for frontend assets. It takes your SOURCE files (TypeScript, SCSS, ES modules) and produces OPTIMIZED output files for production. Think of it as `python manage.py collectstatic`, but for JavaScript and CSS — only far more powerful.
- **📚 Why it exists:** A modern frontend cannot simply be "wired together" with `<script>` tags. SCSS has to be compiled to CSS. TypeScript to JavaScript. ES modules have to be bundled. Files have to be minified and "content-hashed" for cache busting. Vite solves all of these tasks together.
- **🌐 What happens under the hood:** Development: Vite runs a dev server on port 5173 with Hot Module Replacement (HMR) — a CSS change updates the browser WITHOUT a reload. Production: `npm run build` generates a `dist/` folder with `manifest.json`. The manifest contains a mapping: `{"src/main.js": {"file": "assets/main-a4b3c2.js"}}`. Django reads this manifest, and `{% vite_asset 'src/main.js' %}` turns it into the correct URL with the hash.
- **❌ Common beginner mistake:** Running `npm run build` in development instead of `npm run dev`. Or forgetting to add `static_dist/` to `STATICFILES_DIRS` in `settings.py` — Django will not know where to look for the Vite output.
---

## §4. Vite + ManifestStaticFilesStorage — A Modern Asset Pipeline

Why not just `{% load static %}` and link the files directly? Here is why:
- Modern CSS: Sass/SCSS has to be compiled into plain CSS
- Modern JS: TypeScript has to be compiled, ES modules have to be bundled
- Production optimization: minification, code splitting, content hashing (cache busting)

The asset pipeline looks like this:

```
Development:
  Vite dev server on port 5173
  Hot Module Replacement (HMR): CSS change → browser updates instantly (no reload!)
  Django templates → {% vite_asset 'main.js' %} → URL of the Vite dev server

Production:
  npm run build → generates the dist/ folder
  dist/manifest.json: { "main.js": "assets/main-a4b3c2.js" }
  python manage.py collectstatic → copies dist/ into STATIC_ROOT
  Django templates → {% vite_asset 'main.js' %} → /static/assets/main-a4b3c2.js
```

Content hashing = cache busting: `main-a4b3c2.js` contains a hash of the file's contents. If you change the file, the hash changes and the browser downloads a fresh copy. If the file has not changed, the browser uses the cached version.

### Why Vite instead of webpack?

| | webpack | Vite |
|-|---------|------|
| Cold start | ~30-60 sec | <1 sec (ESM native) |
| HMR | Full recompilation | Targeted update |
| Production build | Good | Good (Rollup) |
| Django integration | `django-webpack-loader` | `django-vite` |

### Project structure

Note the separation: `frontend/` contains all the JavaScript/CSS source code and npm dependencies. `static_dist/` is the Vite output; it ends up in Git only if there is no CI/CD. In production this folder is generated by a Docker build stage:

```
django_bootstrap_project/
├── frontend/
│   ├── package.json
│   ├── vite.config.js
│   └── src/
│       ├── main.js           ← entry point
│       ├── main.scss         ← Bootstrap + custom CSS
│       └── components/       ← JS components
├── notes_app/
│   └── static/               ← Django static (legacy)
├── static_dist/              ← Vite output (collectstatic source)
└── manage.py
```

### vite.config.js

`base: '/static/'` is critical! Vite uses this path to generate URLs in the HTML. It must match Django's `STATIC_URL`. `manifest: true` generates `manifest.json`; without it Django will not know the real names of the hashed files:

```javascript
// frontend/vite.config.js
import { defineConfig } from 'vite'
import { resolve } from 'path'

export default defineConfig({
    base: '/static/',          // Django STATIC_URL

    build: {
        outDir: '../static_dist',
        manifest: true,        // ← generates manifest.json (needed by Django)
        rollupOptions: {
            input: {
                main: resolve(__dirname, 'src/main.js'),
            }
        }
    },

    server: {
        origin: 'http://localhost:5173',  // Vite dev server
        port: 5173,
    }
})
```

### main.js — Bootstrap via npm

Instead of a Bootstrap CDN, we now use npm. The benefit: tree-shaking — we import only the Bootstrap components we actually use, not the whole of Bootstrap. This reduces the size of the final bundle:

```javascript
// frontend/src/main.js

// Bootstrap JS (selectively — only what is needed)
import { Modal, Toast, Tooltip } from 'bootstrap'

// Bootstrap CSS via SCSS
import './main.scss'

// Your components
import './components/search'
import './components/delete-confirm'

// Initialize Tooltips
document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
    new Tooltip(el)
})
```

`:root` CSS variables defined BEFORE `@import 'bootstrap'` override the Bootstrap defaults — this is the official way to brand Bootstrap without forking it:

```scss
// frontend/src/main.scss

// Custom CSS variables BEFORE Bootstrap
:root {
    --bs-primary: #2563eb;      // Overriding a Bootstrap color
    --bs-border-radius: 0.5rem;
}

// You can include Bootstrap modules selectively
@import 'bootstrap/scss/bootstrap';

// Your styles
.note-card {
    transition: transform .2s ease;
    &:hover {
        transform: translateY(-4px);
    }
}
```

### settings.py — ManifestStaticFilesStorage

`ManifestStaticFilesStorage` reads `staticfiles.json` (the equivalent of Vite's `manifest.json`, but for Django) and automatically turns `{% static 'main.js' %}` → `/static/main.abc123.js`. This happens during `collectstatic`:

```python
# settings.py

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'  # collectstatic destination

# Vite build output — Django looks here
STATICFILES_DIRS = [
    BASE_DIR / 'static_dist',
]

# Production: files with a hash (main.abc123.js)
# Django 4.2+: the STORAGES setting (STATICFILES_STORAGE was removed in Django 5.1)
STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.ManifestStaticFilesStorage'},
}
# → generates staticfiles.json with the mapping main.js → main.abc123.js
# → {% static 'main.js' %} → /static/main.abc123.js
```

### django-vite integration (dev mode)

`django-vite` provides seamless switching between dev and production modes. In dev it connects to the Vite HMR server (live updates). In production it reads manifest.json and generates the correct hashed URLs. `DJANGO_VITE_DEV_MODE = DEBUG` switches automatically:

```bash
pip install django-vite
```

```python
# settings.py
INSTALLED_APPS = ['django_vite', ...]

DJANGO_VITE_ASSETS_PATH = BASE_DIR / 'static_dist'
DJANGO_VITE_DEV_MODE = DEBUG  # True in dev, False in prod
DJANGO_VITE_DEV_SERVER_URL = 'http://localhost:5173'
```

`{% vite_hmr_client %}` inserts the Vite HMR client script — it enables Hot Module Replacement. `{% vite_asset 'src/main.js' %}` generates a URL to the Vite server in dev, and a hashed URL to the built file in prod:

```html
{# base.html #}
{% load django_vite %}

<head>
    {% if debug %}
        {# Dev: connect via the Vite dev server with HMR #}
        {% vite_hmr_client %}
        {% vite_asset 'src/main.js' %}
    {% else %}
        {# Production: Vite manifest → hashed files #}
        {% vite_asset 'src/main.js' %}
    {% endif %}
</head>
```

### Multi-stage Dockerfile with Vite

A multi-stage build is a key pattern for production. Stage 1 (Node.js) builds the frontend assets. Stage 2 (Python) builds Django. `COPY --from=frontend-builder` copies only the Vite output between stages — the Node.js modules (hundreds of MB) do not end up in the final image:

```dockerfile
# Dockerfile

# Stage 1: Build frontend assets
FROM node:20-alpine AS frontend-builder
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build   # → ../static_dist/

# Stage 2: Django production image
FROM python:3.12-slim AS django
WORKDIR /app

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Django project
COPY . .

# Copy Vite output from frontend-builder
COPY --from=frontend-builder /static_dist/ ./static_dist/

# collectstatic
RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["gunicorn", "notes_chat_app.wsgi:application", "--bind", "0.0.0.0:8000"]
```

### Production asset pipeline

This diagram shows the full path from source code to the browser: dev mode (directly via Vite HMR) and production mode (via hashed files on nginx):

```
Frontend Dev                    Production
─────────────                   ─────────────
npm run dev                     npm run build
    ↓                               ↓
Vite HMR server             static_dist/
(port 5173)                     ├── main.abc123.js
    ↓                           ├── main.def456.css
Browser JS modules              └── manifest.json
(no bundling)                       ↓
                            python manage.py collectstatic
                                    ↓
                            staticfiles/
                                    ↓
                            nginx /static/ → hash files
```

---

---
- **🧠 Mental model:** The SaaS Dashboard architecture is a 3-level template inheritance tree. `base.html` (the HTML skeleton) → `layouts/dashboard.html` (sidebar + topbar) → `notes/list.html` (the page content). Each level adds its own layer without repeating the parent.
- **📚 Why it exists:** So that changing ONE line propagates to ALL pages. Changing the sidebar: you edit `layouts/dashboard.html` once — every dashboard page is updated. Changing the HTML skeleton: you edit `base.html` — the whole site is updated.
- **🌐 What happens under the hood:** Django template inheritance is a compile-time operation. On the first render Django compiles the template into a tree of nodes, where each `{% block %}` is an extension point. The child template "inserts" its content into the parent's blocks.
- **❌ Common beginner mistake:** Duplicating the navbar or sidebar in every template instead of moving it into `layouts/`. Or making the hierarchy too flat (all templates directly extend `base.html`) — then the sidebar has to be copied into every layout.
---

## §5. SaaS Dashboard Architecture

Three levels of template hierarchy work like an inheritance tree. The root level defines the skeleton, intermediate levels define the sections, and leaf templates define the content.

Why this architecture scales:
- Add a new page: just create a new leaf template that extends `layouts/dashboard.html`
- Change the sidebar: edit `layouts/dashboard.html` once — ALL pages are updated
- Change the HTML skeleton: edit `base.html` once — EVERY page is updated

The component philosophy: sidebar, topbar, pagination, empty_state, confirm_modal are COMPONENTS moved out into include files. Each has a single responsibility.

### A typical SaaS template hierarchy

```
templates/
├── base.html                   ← HTML5 shell, Bootstrap CDN/Vite
├── layouts/
│   ├── dashboard.html          ← base + sidebar + topbar
│   ├── auth.html               ← base + centered card (login/register)
│   └── landing.html            ← base + marketing nav
├── components/
│   ├── sidebar.html            ← inclusion_tag component
│   ├── topbar.html             ← with notification_badge
│   ├── breadcrumb.html         ← dynamic breadcrumb
│   ├── pagination.html         ← Bootstrap pagination
│   ├── empty_state.html        ← "No items yet" placeholder
│   └── confirm_modal.html      ← Delete confirmation modal
└── notes/
    ├── list.html               ← extends layouts/dashboard.html
    ├── detail.html
    ├── create.html
    └── edit.html
```

### base.html — HTML shell

`base.html` is an HTML5 skeleton with no content at all. Every `{% block %}` is an extension point for child templates. `data-bs-theme` is Bootstrap 5.3+ dark mode support through a CSS variable controlled by the child template:

```html
{# templates/base.html #}
<!DOCTYPE html>
<html lang="uk" data-bs-theme="{% block theme %}light{% endblock %}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="{% block meta_description %}Bootstrap Notes{% endblock %}">
    <title>{% block title %}Bootstrap Notes{% endblock %} — {{ site_name }}</title>

    {# Bootstrap CSS via CDN or Vite #}
    {% block css %}
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
    {% endblock %}

    {% block extra_css %}{% endblock %}
</head>
<body class="{% block body_class %}{% endblock %}">

    {% block body %}{% endblock %}

    {# Bootstrap JS #}
    {% block js %}
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            defer></script>
    {% endblock %}

    {% block extra_js %}{% endblock %}
</body>
</html>
```

### layouts/dashboard.html — sidebar layout

`layouts/dashboard.html` extends `base.html` and adds a sidebar + topbar layout. Note `request.resolver_match.url_name` — this is dynamic highlighting of the active menu item. `resolver_match` is available thanks to the built-in `context_processors.request`:

```html
{# templates/layouts/dashboard.html #}
{% extends 'base.html' %}
{% load hello_tags static %}

{% block body_class %}bg-light{% endblock %}

{% block body %}
<div class="d-flex" style="min-height: 100vh;">

    {# ===== SIDEBAR ===== #}
    <nav id="sidebar"
         class="d-flex flex-column flex-shrink-0 bg-dark text-white"
         style="width: 260px;">

        {# Brand #}
        <a href="{% url 'notes_app:dashboard' %}"
           class="d-flex align-items-center p-3 text-white text-decoration-none border-bottom border-secondary">
            <i class="bi bi-journal-text fs-4 me-2"></i>
            <span class="fs-5 fw-bold">{{ site_name }}</span>
        </a>

        {# Navigation links #}
        <ul class="nav nav-pills flex-column mb-auto p-3">
            <li class="nav-item mb-1">
                <a href="{% url 'notes_app:note_list' %}"
                   class="nav-link text-white {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
                    <i class="bi bi-file-text me-2"></i>Мої нотатки
                </a>
            </li>
            <li class="nav-item mb-1">
                <a href="{% url 'notes_app:note_create' %}"
                   class="nav-link text-white {% if request.resolver_match.url_name == 'note_create' %}active{% endif %}">
                    <i class="bi bi-plus-circle me-2"></i>Нова нотатка
                </a>
            </li>
            <li class="nav-item mb-1">
                <a href="{% url 'notes_app:category_list' %}"
                   class="nav-link text-white">
                    <i class="bi bi-tags me-2"></i>Категорії
                </a>
            </li>
        </ul>

        {# User section #}
        <div class="p-3 border-top border-secondary">
            <div class="d-flex align-items-center">
                <div class="flex-shrink-0">
                    <div class="rounded-circle bg-primary d-flex align-items-center
                                justify-content-center text-white"
                         style="width:36px; height:36px;">
                        {{ user.username|first|upper }}
                    </div>
                </div>
                <div class="flex-grow-1 ms-2 overflow-hidden">
                    <div class="fw-semibold text-truncate">{{ user.get_full_name|default:user.username }}</div>
                    <small class="text-muted">{{ user.email|truncatechars:20 }}</small>
                </div>
                <a href="{% url 'logout' %}" class="btn btn-sm btn-outline-secondary ms-1"
                   title="Вийти">
                    <i class="bi bi-box-arrow-right"></i>
                </a>
            </div>
        </div>
    </nav>

    {# ===== MAIN CONTENT ===== #}
    <div class="flex-grow-1 d-flex flex-column">

        {# Top bar #}
        <header class="navbar navbar-light bg-white border-bottom shadow-sm px-4 py-2">
            <div class="d-flex align-items-center gap-3">
                {# Mobile sidebar toggle #}
                <button class="btn btn-sm btn-outline-secondary d-lg-none"
                        data-bs-toggle="offcanvas" data-bs-target="#mobileSidebar">
                    <i class="bi bi-list"></i>
                </button>

                {# Breadcrumb #}
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0 small">
                        {% block breadcrumb %}
                        <li class="breadcrumb-item">
                            <a href="{% url 'notes_app:dashboard' %}">Головна</a>
                        </li>
                        {% endblock %}
                    </ol>
                </nav>
            </div>

            <div class="d-flex align-items-center gap-2">
                {# Search form #}
                <form class="d-flex" method="get" action="{% url 'notes_app:search' %}">
                    <div class="input-group input-group-sm">
                        <input type="search" name="q" class="form-control"
                               placeholder="Пошук..." value="{{ request.GET.q }}"
                               aria-label="Пошук нотаток">
                        <button class="btn btn-outline-secondary" type="submit">
                            <i class="bi bi-search"></i>
                        </button>
                    </div>
                </form>

                {# Notifications #}
                {% notification_badge %}
            </div>
        </header>

        {# Messages (Context Processor) #}
        {% if messages %}
        <div class="px-4 pt-3">
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"
                        aria-label="Закрити"></button>
            </div>
            {% endfor %}
        </div>
        {% endif %}

        {# Page content #}
        <main class="flex-grow-1 p-4">
            {% block content %}{% endblock %}
        </main>

        {# Footer #}
        <footer class="text-center text-muted small py-3 border-top">
            {{ site_name }} v{{ site_version }} &copy; {% now "Y" %}
        </footer>
    </div>

</div>
{% endblock %}
```

### notes/list.html — CRUD Interface

This template extends `layouts/dashboard.html` and defines only the page CONTENT. Note: there is neither an HTML skeleton nor a sidebar here — they are inherited automatically. `{{ note.status|status_badge }}` is our custom filter from §2. `{% include 'components/...' %}` is the component architecture:

```html
{# templates/notes/list.html #}
{% extends 'layouts/dashboard.html' %}
{% load hello_tags %}

{% block title %}Мої нотатки{% endblock %}

{% block breadcrumb %}
<li class="breadcrumb-item active">Нотатки</li>
{% endblock %}

{% block content %}

{# Page header #}
<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="h3 mb-0">Мої нотатки</h1>
        <small class="text-muted">{{ notes.paginator.count }} нотаток</small>
    </div>
    <a href="{% url 'notes_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>Нова нотатка
    </a>
</div>

{# Filters #}
<div class="card mb-4">
    <div class="card-body py-2">
        <form method="get" class="row g-2 align-items-center">
            <div class="col-auto">
                <select name="category" class="form-select form-select-sm">
                    <option value="">Всі категорії</option>
                    {% for cat in categories %}
                    <option value="{{ cat.pk }}"
                            {% if request.GET.category == cat.pk|stringformat:"s" %}selected{% endif %}>
                        {{ cat.name }}
                    </option>
                    {% endfor %}
                </select>
            </div>
            <div class="col-auto">
                <select name="sort" class="form-select form-select-sm">
                    <option value="-created_at">Спочатку нові</option>
                    <option value="created_at" {% if request.GET.sort == "created_at" %}selected{% endif %}>
                        Спочатку старі
                    </option>
                    <option value="title" {% if request.GET.sort == "title" %}selected{% endif %}>
                        За назвою
                    </option>
                </select>
            </div>
            <div class="col-auto">
                <button type="submit" class="btn btn-sm btn-outline-primary">
                    <i class="bi bi-funnel"></i> Застосувати
                </button>
            </div>
            {% if request.GET.category or request.GET.sort %}
            <div class="col-auto">
                <a href="{% url 'notes_app:note_list' %}" class="btn btn-sm btn-outline-secondary">
                    <i class="bi bi-x"></i> Скинути
                </a>
            </div>
            {% endif %}
        </form>
    </div>
</div>

{# Notes Grid #}
{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-3 g-4">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-start mb-2">
                    <h5 class="card-title mb-0">
                        <a href="{% url 'notes_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark stretched-link">
                            {{ note.title }}
                        </a>
                    </h5>
                    {{ note.status|status_badge }}
                </div>
                <p class="card-text text-muted small">
                    {{ note.body|truncate_words:25 }}
                </p>
            </div>
            <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                <small class="text-muted">
                    <i class="bi bi-clock me-1"></i>{{ note.created_at|timesince }} тому
                </small>
                <div class="btn-group btn-group-sm position-relative">
                    <a href="{% url 'notes_app:note_edit' pk=note.pk %}"
                       class="btn btn-outline-secondary" title="Редагувати">
                        <i class="bi bi-pencil"></i>
                    </a>
                    <button type="button" class="btn btn-outline-danger"
                            data-bs-toggle="modal"
                            data-bs-target="#deleteModal"
                            data-note-id="{{ note.pk }}"
                            data-note-title="{{ note.title }}"
                            title="Видалити">
                        <i class="bi bi-trash"></i>
                    </button>
                </div>
            </div>
        </div>
    </div>
    {% endfor %}
</div>

{# Pagination #}
{% include 'components/pagination.html' with page_obj=notes %}

{% else %}
{# Empty State #}
{# A DTL tag must be on ONE line: a multi-line {% include %} is not recognized #}
{% include 'components/empty_state.html' with icon='bi-journal-x' title='Ще немає нотаток' message='Створіть першу нотатку і вона з\'явиться тут.' action_url='notes_app:note_create' action_text='Створити нотатку' %}
{% endif %}

{# Delete Confirmation Modal #}
{% include 'components/confirm_modal.html' %}

{% endblock %}

{% block extra_js %}
<script>
document.addEventListener('DOMContentLoaded', function() {
    const deleteModal = document.getElementById('deleteModal');
    deleteModal.addEventListener('show.bs.modal', function(e) {
        const btn = e.relatedTarget;
        document.getElementById('noteToDelete').textContent = btn.dataset.noteTitle;
        document.getElementById('deleteForm').action =
            `/notes/${btn.dataset.noteId}/delete/`;
    });
});
</script>
{% endblock %}
```

### components/pagination.html

This component is a reusable Bootstrap pagination that receives `page_obj` (a Django Paginator object) via `{% include ... with page_obj=notes %}`. The "show only ±2 pages around the current one" logic keeps the pagination clean even with hundreds of pages:

```html
{# templates/components/pagination.html #}
{% if page_obj.has_other_pages %}
<nav aria-label="Навігація по сторінках" class="mt-4">
    <ul class="pagination justify-content-center">

        {# Previous: previous_page_number raises EmptyPage on the first page, hence the {% if %} #}
        {% if page_obj.has_previous %}
        <li class="page-item">
            <a class="page-link" href="?page={{ page_obj.previous_page_number }}">
                <i class="bi bi-chevron-left"></i>
            </a>
        </li>
        {% else %}
        <li class="page-item disabled">
            <span class="page-link" aria-disabled="true"><i class="bi bi-chevron-left"></i></span>
        </li>
        {% endif %}

        {# Page numbers #}
        {% for num in page_obj.paginator.page_range %}
            {% if page_obj.number == num %}
            <li class="page-item active" aria-current="page">
                <span class="page-link">{{ num }}</span>
            </li>
            {% elif num > page_obj.number|add:'-3' and num < page_obj.number|add:'3' %}
            <li class="page-item">
                <a class="page-link" href="?page={{ num }}">{{ num }}</a>
            </li>
            {% endif %}
        {% endfor %}

        {# Next: next_page_number raises EmptyPage on the last page, hence the {% if %} #}
        {% if page_obj.has_next %}
        <li class="page-item">
            <a class="page-link" href="?page={{ page_obj.next_page_number }}">
                <i class="bi bi-chevron-right"></i>
            </a>
        </li>
        {% else %}
        <li class="page-item disabled">
            <span class="page-link" aria-disabled="true"><i class="bi bi-chevron-right"></i></span>
        </li>
        {% endif %}

    </ul>
    <p class="text-center text-muted small">
        Сторінка {{ page_obj.number }} з {{ page_obj.paginator.num_pages }}
        ({{ page_obj.paginator.count }} елементів)
    </p>
</nav>
{% endif %}
```

### components/empty_state.html

The "empty state" is a standard UX pattern. Instead of an empty screen we show an icon, an explanation and a CTA button. The parameters are passed via `{% include ... with icon=... title=... %}`:

```html
{# templates/components/empty_state.html #}
<div class="text-center py-5">
    <i class="bi {{ icon }} display-1 text-muted d-block mb-3"></i>
    <h4 class="text-muted">{{ title }}</h4>
    <p class="text-muted">{{ message }}</p>
    {% if action_url %}
    <a href="{% url action_url %}" class="btn btn-primary mt-2">
        <i class="bi bi-plus-lg me-1"></i>{{ action_text }}
    </a>
    {% endif %}
</div>
```

### components/confirm_modal.html

A Bootstrap Modal for confirming deletion. The JavaScript in `notes/list.html` (the `extra_js` block) dynamically fills in the note title and the action URL before the modal is shown — using the button's `data-note-id` and `data-note-title` attributes:

```html
{# templates/components/confirm_modal.html #}
<div class="modal fade" id="deleteModal" tabindex="-1"
     aria-labelledby="deleteModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header border-0">
                <h5 class="modal-title text-danger" id="deleteModalLabel">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Підтвердіть видалення
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"
                        aria-label="Скасувати"></button>
            </div>
            <div class="modal-body">
                Ви справді хочете видалити
                <strong>"<span id="noteToDelete"></span>"</strong>?
                Цю дію не можна скасувати.
            </div>
            <div class="modal-footer border-0">
                <button type="button" class="btn btn-secondary"
                        data-bs-dismiss="modal">Скасувати</button>
                <form id="deleteForm" method="post">
                    {% csrf_token %}
                    <button type="submit" class="btn btn-danger">
                        <i class="bi bi-trash me-1"></i>Видалити
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>
```

---

---
- **🧠 Mental model:** Jinja2 is an "unchained" version of the Django Template Language. Where DTL is deliberately limited (no function calls, no complex expressions), Jinja2 allows almost everything. Jinja2 is power, DTL is safety.
- **📚 Why it exists:** Jinja2 is a separate template engine, considerably more powerful than DTL. Django supports both through a pluggable backend system. Jinja2 is chosen for complex templates with macros, high-performance rendering, and whenever you need more flexibility than DTL allows.
- **🌐 What happens under the hood:** The `environment()` factory is the equivalent of the Django template engine configuration. This is where globals (functions available in all templates) and filters are registered. Jinja2 compiles templates into Python bytecode — caching this bytecode saves recompiling on every request. For very large HTML documents, streaming sends the first bytes to the browser while Python is still generating the rest — the user sees content sooner.
- **❌ Common beginner mistake:** Mixing DTL and Jinja2 in the same template — they are incompatible. `{% load %}` is a DTL tag; Jinja2 does not have it. Also: `{{ csrf_token }}` does not work in Jinja2 — you need `{{ csrf_input }}` (which is an `<input type="hidden">` element).
---

## §6. Jinja2 Deep Dive

Key concepts before the code:
- The `environment()` factory is the equivalent of the Django template engine configuration. Register globals (functions available in all templates) and filters here.
- Macros are a powerful Jinja2 feature. A macro is a reusable HTML function with parameters, defined right in the template. It is similar to `inclusion_tag`, but without Python code.
- Bytecode cache — Jinja2 compiles templates into Python bytecode. Caching this bytecode saves recompiling on every request — a significant performance gain in production.
- Streaming — for very large HTML documents (reports, exports), streaming sends the first bytes to the browser while Python is still generating the rest. The user sees content sooner.

### Jinja2 Environment — configuring the engine

`environment()` is a factory function that configures Jinja2 for Django. `env.globals.update()` registers Python functions as global template variables — they are available in ALL templates without importing. Note: in Jinja2 you can call `len(notes)` and `range(10)` — this is not possible in DTL:

```python
# notes_app/jinja2_env.py

from django.templatetags.static import static
from django.urls import reverse
from jinja2 import Environment


def environment(**options):
    """Jinja2 Environment factory for Django."""
    env = Environment(**options)

    # Global functions (available in templates without import)
    env.globals.update({
        'static': static,           # {{ static('css/main.css') }}
        'url': reverse,             # {{ url('note_list') }}
        'len': len,                 # {{ len(notes) }}
        'range': range,             # {% for i in range(10) %}
        'zip': zip,                 # {% for a, b in zip(list1, list2) %}
    })

    # Custom filters
    env.filters['truncate_words'] = lambda s, n: ' '.join(str(s).split()[:n]) + '...'

    # Tests (is ... in templates)
    env.tests['divisibleby'] = lambda n, d: n % d == 0

    return env
```

Django supports SEVERAL template backends at once. The first backend in the list is searched first. DTL handles templates in `templates/`, Jinja2 handles those in `templates/jinja2/`. `auto_reload: DEBUG` — in production templates are not re-read from disk, only from the cache:

```python
# settings.py
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.jinja2.Jinja2',
        'DIRS': [BASE_DIR / 'templates' / 'jinja2'],
        'APP_DIRS': False,
        'OPTIONS': {
            'environment': 'notes_app.jinja2_env.environment',
            'auto_reload': DEBUG,       # False in prod (bytecode cache)
            'undefined': 'jinja2.Undefined',
        },
    },
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {'context_processors': [...]},
    },
]
```

### Macros — the Jinja2 super-feature

A macro in Jinja2 is like an `inclusion_tag`, but defined right in the template, without Python. `{% macro input_field(field, label=None, help_text=None) %}` is a function with parameters and default values. `{% from 'macros/forms.html' import input_field %}` imports specific macros from a file:

```jinja2
{# templates/jinja2/macros/forms.html #}
{% macro input_field(field, label=None, help_text=None) %}
<div class="mb-3">
    <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
        {{ label or field.label }}
        {% if field.field.required %}<span class="text-danger ms-1">*</span>{% endif %}
    </label>
    {{ field }}
    {% if help_text %}
        <div class="form-text text-muted">{{ help_text }}</div>
    {% endif %}
    {% if field.errors %}
        {% for error in field.errors %}
        <div class="invalid-feedback d-block">{{ error }}</div>
        {% endfor %}
    {% endif %}
</div>
{% endmacro %}

{% macro submit_btn(label='Зберегти', css_class='btn-primary') %}
<div class="d-grid gap-2 d-md-flex justify-content-md-end mt-4">
    <button type="submit" class="btn {{ css_class }}">
        <i class="bi bi-check-lg me-1"></i>{{ label }}
    </button>
</div>
{% endmacro %}
```

Note the key difference from DTL: `{{ Note.objects.count() }}` is valid Jinja2 syntax. In DTL it would cause an error. `{{ csrf_input }}` instead of `{% csrf_token %}` is a Jinja2-in-Django specific:

```jinja2
{# templates/jinja2/notes/create.html #}
{% from 'macros/forms.html' import input_field, submit_btn %}
{% extends 'layouts/dashboard.html' %}   {# the path is relative to DIRS = templates/jinja2 #}

{% block content %}
<div class="card shadow-sm">
    <div class="card-body">
        <form method="post">
            {{ csrf_input }}   {# Jinja2 — not a tag, but a variable #}

            {{ input_field(form.title, help_text='Коротка описова назва') }}
            {{ input_field(form.body) }}
            {{ input_field(form.category) }}

            {# A function call — fine in Jinja2, forbidden in DTL #}
            <p>Всього нотаток: {{ Note.objects.count() }}</p>

            {{ submit_btn('Створити нотатку') }}
        </form>
    </div>
</div>
{% endblock %}
```

### Jinja2 inheritance with `{{ super() }}`

`{{ super() }}` is the Jinja2 equivalent of DTL's `{{ block.super }}`. It inserts the CONTENT of the parent block and then lets the child template add its own. Useful for CSS/JS blocks — we add our own styles on top of the parent's without replacing them:

```jinja2
{# templates/jinja2/base.html #}
{% block css %}
<link rel="stylesheet" href="{{ static('css/bootstrap.min.css') }}">
{% endblock %}
```

```jinja2
{# templates/jinja2/notes/create.html #}
{% block css %}
{{ super() }}   {# ← includes the parent's CSS #}
<link rel="stylesheet" href="{{ static('css/codemirror.min.css') }}">
{% endblock %}
```

> In DTL, `{{ block.super }}` is a similar concept.

### Bytecode Cache — Jinja2 in production

The bytecode cache stores compiled templates on disk. On the next request Jinja2 loads the bytecode instead of compiling the template again. Important: if you clear the cache manually after changing a template in production without `auto_reload`, Django will load the fresh template:

```python
# settings.py — Jinja2 bytecode cache

from jinja2 import FileSystemBytecodeCache

JINJA2_BYTECODE_CACHE = FileSystemBytecodeCache(
    directory='/tmp/jinja2_cache/',
    pattern='__jinja2_%s.cache',
)

# notes_app/jinja2_env.py
from django.conf import settings

def environment(**options):
    if not settings.DEBUG and hasattr(settings, 'JINJA2_BYTECODE_CACHE'):
        options['bytecode_cache'] = settings.JINJA2_BYTECODE_CACHE
    env = Environment(**options)
    ...
    return env
```

### Jinja2 Streaming — for large responses

`StreamingHttpResponse` sends the HTTP response in parts. `template.stream()` generates the HTML incrementally. `Note.objects.iterator()` reads the QuerySet row by row without loading everything into RAM. Ideal for large reports and CSV/HTML exports where the data can be hundreds of MB:

```python
# views.py

from jinja2 import Environment
from django.http import StreamingHttpResponse

def large_export(request):
    """A streaming response — does not buffer the whole HTML in memory."""
    env = Environment(loader=...)
    template = env.get_template('export.html')

    notes = Note.objects.iterator()  # Django QuerySet iterator

    def generate():
        stream = template.stream({'notes': notes})
        stream.enable_buffering(5)  # 5 KB buffer
        yield from stream

    return StreamingHttpResponse(generate(), content_type='text/html')
```

---

---
- **🧠 Mental model:** HTMX is "Ajax for HTML". It gives any HTML element HTTP superpowers — not just `<a>` and `<form>`. Instead of JavaScript code to fetch and update the DOM, you write HTML attributes.
- **📚 Why it exists:** The classic approach: HTML is static and JavaScript makes it dynamic — which requires a separate JS framework (React/Vue), a separate API (JSON), and a separate build toolchain. The HTMX approach: HTML itself IS the API. HTML fragments ARE state changes. You stay in Python/Django templates — without context-switching into JavaScript.
- **🌐 What happens under the hood:** HTMX intercepts DOM events (click, submit, keyup), sends an HTTP request with special headers (`HX-Request: true`, `HX-Target`, `HX-Trigger`); the Django view detects the HTMX request by the header and returns an HTML fragment (not a full page); HTMX inserts this fragment into the DOM according to the `hx-swap` strategy. No page reload happens.
- **❌ Common beginner mistake:** Returning full HTML (with `base.html`) for an HTMX request instead of just the fragment. Result: the sidebar gets inserted inside the sidebar, a whole page appears inside a small div. Always check `request.headers.get('HX-Request')`.
---

## §7. HTMX Architecture — The Full Lifecycle

The philosophical shift that explains HTMX:

```
Traditional approach: HTML is STATIC, JavaScript makes it DYNAMIC
HTMX approach: HTML itself IS the API. HTML fragments ARE state changes.
```

Why this is revolutionary for Django developers:
- You stay in Python/Django templates — without context-switching into JavaScript
- Your Django views return HTML fragments instead of JSON
- No JavaScript framework to learn, no build system needed

The full HTMX request lifecycle:

```
1. The user interacts with an element that has hx-* attributes
2. HTMX intercepts the event (click, submit, keyup, etc.)
3. HTMX sends an HTTP request (GET/POST/PUT/DELETE)
4. The request has special headers: HX-Request: true, HX-Target: results, etc.
5. The Django view receives the request
6. It checks the HX-Request header
7. If it is an HTMX request → returns an HTML fragment (only the changed part)
8. If it is a normal request → returns the full page
9. HTMX receives the HTML fragment
10. HTMX inserts the fragment into the target element
11. No page reload happens
```

### HTMX Philosophy

```
Traditional SPA                 HTMX Server-Driven UI
─────────────────               ─────────────────────
Client renders HTML             Server renders HTML
JavaScript heavy               JavaScript minimal
Full JSON API needed           HTML fragments from server
State in JS (Redux, Zustand)   State on server / database
Complex build setup (webpack)  Zero build tooling
```

### HTMX attributes

| Attribute | What it does |
|---------|-----------|
| `hx-get="/path/"` | A GET request to `/path/` |
| `hx-post="/path/"` | A POST with the form data |
| `hx-trigger="click"` | Trigger: `click`, `change`, `keyup delay:300ms`, `load`, `revealed` |
| `hx-target="#id"` | Where to insert the response (CSS selector) |
| `hx-swap="innerHTML"` | How to insert it: `innerHTML`, `outerHTML`, `beforeend`, `afterend`, `delete` |
| `hx-include="#form-id"` | Include the data of another element |
| `hx-push-url="true"` | Update the URL in the browser |
| `hx-indicator="#spinner"` | Show a spinner during the request |
| `hx-confirm="Ви впевнені?"` | A confirmation dialog before the request |

### HTMX Request Lifecycle

```
1. User triggers event (click, keyup, etc.)
        ↓
2. HTMX reads attributes (hx-get, hx-target, hx-swap)
        ↓
3. htmx:configRequest event fired
   → you can modify the headers via JS
        ↓
4. HTTP Request (with HTMX headers):
   HX-Request: true
   HX-Current-URL: http://localhost:8000/notes/
   HX-Target: note-list-container
   HX-Trigger: search-input
        ↓
5. The Django View receives the request
   → Checks the HX-Request header
   → Returns an HTML fragment (not a full page)
        ↓
6. htmx:beforeSwap event
   → Can be intercepted and cancelled
        ↓
7. DOM update (hx-swap strategy)
        ↓
8. htmx:afterSwap → run scripts, init Bootstrap
        ↓
9. htmx:afterSettle → animations finished
```

### Django View — checking for HTMX

This is the key pattern: one view handles BOTH kinds of request. A normal request → the full page. An HTMX request → only the fragment. This provides progressive enhancement: the page works without JavaScript (full load) and with HTMX (dynamic updates):

```python
# views.py

def note_list(request):
    query = request.GET.get('q', '')
    notes = Note.objects.filter(author=request.user)
    if query:
        notes = notes.filter(title__icontains=query)

    # If this is an HTMX request — return only the fragment
    if request.headers.get('HX-Request'):
        return render(request, 'notes/partials/note_cards.html', {'notes': notes})

    # A normal request — the full page
    return render(request, 'notes/list.html', {'notes': notes, 'query': query})
```

The `django-htmx` package adds `request.htmx` — a convenient interface instead of checking headers by hand. It also provides `request.htmx.target`, `request.htmx.trigger` and other attributes:

```python
# Or via django-htmx (pip install django-htmx)
def note_list(request):
    notes = Note.objects.filter(author=request.user)
    if request.htmx:
        return render(request, 'notes/partials/note_cards.html', {'notes': notes})
    return render(request, 'notes/list.html', {'notes': notes})
```

### Live search — a complete example

`hx-trigger="keyup changed delay:300ms"` — let's break down each part:
- `keyup` — the event that triggers the request
- `changed` — only if the value has CHANGED (without it, a request is sent even when you press Shift)
- `delay:300ms` — debounce: waits 300 ms after the last keystroke. Without it, every letter = a separate request. With debounce, the request is sent only once the user has stopped typing

`hx-target="#note-list-container"` specifies which element to update. The value is a CSS selector.
`hx-swap="innerHTML"` replaces only the CONTENT of the target (not the container itself). `htmx-indicator` is a Bootstrap spinner that becomes visible automatically during an HTMX request:

```html
{# notes/list.html — the search input #}
<input type="search" name="q"
       class="form-control"
       placeholder="Пошук нотаток..."
       hx-get="{% url 'notes_app:note_list' %}"
       hx-trigger="keyup changed delay:300ms, search"
       hx-target="#note-list-container"
       hx-swap="innerHTML"
       hx-indicator="#search-spinner"
       aria-label="Живий пошук">

{# Spinner — visible only during an HTMX request #}
<span id="search-spinner"
      class="spinner-border spinner-border-sm text-primary htmx-indicator"
      role="status" aria-hidden="true"></span>

{# Container for the results #}
<div id="note-list-container">
    {% include 'notes/partials/note_cards.html' %}
</div>
```

The partial template `note_cards.html` renders ONLY the cards — no `{% extends %}`, no `{% block %}`. It is completely isolated and can be used both in the full page (via `{% include %}`) and returned for HTMX requests:

```html
{# notes/partials/note_cards.html — cards only, no base.html #}
{% if notes %}
    {% for note in notes %}
    <div class="col">
        {# ... card ... #}
    </div>
    {% endfor %}
{% else %}
<div class="col-12">
    <p class="text-center text-muted py-4">Нотаток не знайдено.</p>
</div>
{% endif %}
```

### Infinite Scroll with HTMX

`hx-trigger="revealed"` fires when the element becomes VISIBLE in the viewport (on scroll). This is the standard infinite scroll pattern: the last element is visible → load the next page. Much simpler than JavaScript `IntersectionObserver` implementations.

`hx-swap="outerHTML"` replaces the trigger element ITSELF with the new content (the next cards). If there are no more pages, the Django view returns an empty string or an "end of list" message, and the trigger disappears:

```html
{# The last element of the list — the load-more trigger #}
{% if page_obj.has_next %}
<div hx-get="{% url 'notes_app:note_list' %}?page={{ page_obj.next_page_number }}"
     hx-trigger="revealed"        {# ← fires when the element appears in the viewport #}
     hx-target="this"
     hx-swap="outerHTML"          {# ← replaces itself with the next cards #}
     class="text-center py-3">
    <span class="spinner-border text-primary htmx-indicator" role="status"></span>
    <span class="htmx-indicator-hide">Прокрутіть для завантаження...</span>
</div>
{% endif %}
```

### Optimistic UI with HTMX

Optimistic UI = assume success BEFORE the server confirms it. The interface feels instant. The risk: what if the server returns an error? HTMX replaces the element with the server's response (which contains the error state). So the "rollback" happens automatically through the server response.

`hx-swap="outerHTML"` replaces the WHOLE element (including the button) with the updated version of the card from the server. If the status has changed, the new card is shown without the "complete" button:

```html
{# Mark as completed — without reloading the page #}
<button hx-post="{% url 'note_complete' pk=note.pk %}"
        hx-target="closest .note-card"
        hx-swap="outerHTML"          {# ← replaces the card with the updated version #}
        hx-confirm="Відмітити як виконане?"
        class="btn btn-sm btn-outline-success">
    <i class="bi bi-check2"></i>
</button>
```

The view returns ONLY the card's HTML, not the full page. HTMX replaces the old card with this new response. If an error occurs, the view can return the card in an error state — HTMX will insert it automatically:

```python
# views.py
@require_POST
def note_complete(request, pk):
    note = get_object_or_404(Note, pk=pk, author=request.user)
    note.status = 'completed'
    note.save()
    # Return only the updated card
    return render(request, 'notes/partials/note_card.html', {'note': note})
```

### HTMX + Bootstrap Modal (server-rendered)

A dynamic Modal: its content is loaded from the server when it opens. There is no need to render forms for all notes in advance — only for the one that was opened. This significantly reduces the HTML size of the initial page:

```html
{# The button — opens the modal and loads its content #}
<button hx-get="{% url 'note_edit_modal' pk=note.pk %}"
        hx-target="#modal-container"
        hx-swap="innerHTML"
        data-bs-toggle="modal"
        data-bs-target="#dynamicModal"
        class="btn btn-sm btn-outline-primary">
    <i class="bi bi-pencil"></i>
</button>

{# Container for the Modal's dynamic content #}
<div id="modal-container"></div>
<div class="modal fade" id="dynamicModal" tabindex="-1"></div>
```

```python
# views.py
def note_edit_modal(request, pk):
    note = get_object_or_404(Note, pk=pk, author=request.user)
    form = NoteForm(instance=note)
    # Return only the modal-dialog HTML
    return render(request, 'notes/partials/edit_modal_body.html', {
        'note': note, 'form': form
    })
```

### HTMX Response Headers

HTMX Response Headers let the server control HTMX behavior after the response. `HX-Redirect` — a client-side redirect: the browser goes to the new URL with a full page reload (like `window.location`). `HX-Location` — navigation without a full page reload: HTMX loads the new page with an AJAX request and updates the history. `HX-Trigger` — sending custom JS events from the server to keep other parts of the UI in sync. The difference between `HX-Redirect` and a regular `redirect()`: the browser follows a regular 302 transparently inside the fetch/XHR request, and HTMX inserts the HTML of the target page into `hx-target` (a page inside a page), whereas `HX-Redirect` makes the browser actually navigate to the new page:

```python
# views.py — controlling HTMX behavior through response headers

from django.http import HttpResponse
from django.urls import reverse

def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save(commit=False)
            note.author = request.user
            note.save()

            response = HttpResponse(status=204)  # No Content
            # Redirect the browser to the notes list (a full page reload).
            # Without a full reload: response['HX-Location'] = reverse('notes_app:note_list')
            response['HX-Redirect'] = reverse('notes_app:note_list')
            # Or update only a particular element
            response['HX-Trigger'] = 'noteCreated'  # JS event
            return response

        return render(request, 'notes/partials/create_form.html', {'form': form})
```

`HX-Trigger: noteCreated` sends a custom DOM event. JavaScript on the page can listen for this event and perform additional actions — for example, update the notes counter in the sidebar without a reload:

```javascript
// Listen for the server-side event
document.addEventListener('noteCreated', function() {
    // Update the notes counter
    htmx.trigger('#notes-count', 'refresh');
});
```

---

## §8. Self-check Questions

1. A Context Processor runs a DB query (counting messages). A page makes 50 requests — how many times does the Context Processor run? How would you optimize it?
2. `@register.inclusion_tag` receives `takes_context=True`. Which template variable does it automatically receive? What is it needed for?
3. The crispy-forms `FormHelper` has `form_tag = False`. When is this useful?
4. Vite generates `manifest.json`. Why does Django need it? What is stored in it?
5. `ManifestStaticFilesStorage` adds a hash to files (`main.abc123.js`). Why? What does it give the browser?
6. In the SaaS Dashboard, `{% if request.resolver_match.url_name == 'note_list' %}active{% endif %}` — what is `resolver_match`? Where is it available?
7. Jinja2's `FileSystemBytecodeCache` stores compiled templates. What happens if a template changed but the cache was not cleared?
8. HTMX `hx-trigger="keyup changed delay:300ms"` — what does `changed` mean? Why `delay`?
9. An HTMX view returns `HttpResponse(status=204)` with an `HX-Redirect` header. How is that different from `redirect()`?
10. In what order does Django look for templates if there are both a DTL and a Jinja2 backend? How do you control which backend is used?
