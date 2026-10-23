# Bootstrap Notes — Beautiful notes with Django + Bootstrap 5

A step-by-step guide for students.
We will turn a simple Django project (with bare HTML) into a full-fledged Bootstrap 5 application
with a **Navbar, cards, forms, alerts and an admin panel**.

> **Prerequisites:**
> This project is a continuation of `simple_django_project`.
> You should already understand what a View, URL, Model and Template are.
> If not, first go through `module_5/lesson_Django_Network_Architecture/simple_django_project/README.md`.

---

## Learning map

At each step you will read the corresponding theory file.
Here is how the steps relate to the documentation:

| Step | What we do | Read the theory |
|------|-----------|--------------|
| A | HTML structure, `<!DOCTYPE>`, semantics | [HTML_BASICS.md](../HTML_BASICS.md) §0–5 |
| B | Including Bootstrap via CDN | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §0–2 |
| C | `base.html` — Template Inheritance, Sticky Footer | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §3–5, CSS_BASICS.md §9 |
| D | Navbar + Grid | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §5–6 |
| E | Card Grid for notes | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §6 |
| F | Forms + django-bootstrap5 | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §9, [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §7 |
| G | Django Messages → Bootstrap Alerts | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §4 |
| H | Modal — delete confirmation | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §8 |
| I | Django Debug Toolbar | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §9 |
| J | Unfold Admin — a Tailwind-styled admin | [DJANGO_ADMIN_UNFOLD.md](../DJANGO_ADMIN_UNFOLD.md) §2, §7 |

---

## What you will get in the end

```
http://localhost:8000/             →  Home (redirect to /notes/)
http://localhost:8000/notes/       →  List of notes — Bootstrap Cards
http://localhost:8000/notes/new/   →  Create form — Bootstrap Form
http://localhost:8000/notes/1/     →  Note detail
http://localhost:8000/notes/1/edit/ →  Edit form
http://localhost:8000/notes/1/delete/ →  Deletion with a Modal
http://localhost:8000/admin/       →  Django Admin with a custom ModelAdmin
```

---

## Final project structure

```
django_bootstrap_project/        ← you are here now
├── venv/                        ← virtual environment (do not touch)
├── db.sqlite3                   ← SQLite DB (appears after migrate)
├── manage.py
├── requirements.txt             ← Django + Bootstrap + Debug Toolbar
├── hello_project/               ← settings package
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── hello_app/                   ← our application
    ├── admin.py                 ← NoteAdmin with list_display, search
    ├── models.py                ← Note model (already exists)
    ├── views.py                 ← CRUD views
    ├── urls.py                  ← routes
    ├── forms.py                 ← NoteForm (we will create it)
    ├── migrations/
    └── templates/
        ├── base.html            ← Bootstrap CDN, Navbar (we will create it)
        └── hello_app/
            ├── note_list.html   ← Cards Grid (already exists — we will improve it)
            ├── note_detail.html ← Note detail (we will create it)
            ├── note_form.html   ← Create/edit form (we will create it)
            └── note_confirm_delete.html  ← Deletion (we will create it)
```

---

## Step-by-step instructions

> **All commands are run from the `django_bootstrap_project/` folder**
>
> Check where you are: `pwd` (Linux/Mac) or `cd` (Windows)

---

### Step 1 — Open a terminal in this folder

**PyCharm:**
`View → Tool Windows → Terminal` — opens a terminal already in the project folder.

**A regular terminal** (from the repository root):
```bash
cd module_5\lesson_HTML_CSS_Bootstrap\django_bootstrap_project
```

---

### Step 2 — Create a virtual environment

```bash
python -m venv venv
```

---

### Step 3 — Activate the virtual environment

> You need to activate it **every time** you open a new terminal!

**Windows (Command Prompt):**
```
venv\Scripts\activate
```

**Windows (PowerShell):**
```
venv\Scripts\Activate.ps1
```

**Linux / Mac:**
```bash
source venv/bin/activate
```

After activation, `(venv)` will appear in the terminal prompt.

---

### Step 4 — Install the dependencies

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

What will be installed (from `requirements.txt`):

| Package | Why |
|-------|--------|
| `Django>=5.2,<6` | Web framework |
| `django-debug-toolbar>=4.0` | SQL panel for debugging |
| `django-bootstrap5>=24.0` | Bootstrap 5 for Django Forms |
| `django-unfold>=0.40` | Tailwind-styled Django Admin |

Check:
```bash
python -m django --version  # → 5.2.x
```

---

### Step 5 — Apply migrations

```bash
python manage.py migrate
```

The `db.sqlite3` database will get the `hello_app_note` table (already described in `models.py`)
and all the standard Django tables (`auth_user`, `django_session`, etc.).

> **Theory:** [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §0 —
> the Django SSR lifecycle and where the model sits in MVT.

---

### Step 6 — Create an administrator

```bash
python manage.py createsuperuser
```

```
Username: admin
Email: (Enter — skip)
Password: ****
```

---

### Step 7 — Check that the base project works

```bash
python manage.py runserver
```

| URL | Result |
|-----|-----------|
| http://localhost:8000/notes/ | List of notes (bare HTML, no Bootstrap) |
| http://localhost:8000/admin/ | Admin panel |

Add a few notes via the admin — they will appear on `/notes/`.

**Stop the server:** `Ctrl + C`

> The `/notes/` page looks plain for now. Our goal is to make it beautiful.
> Here is what we will do next.

---

## Phase A — Understanding the existing code

> **Theory before you start:**
> Read [HTML_BASICS.md](../HTML_BASICS.md) §0–3 —
> how the browser reads HTML, the DOM pipeline, the basic document structure.

### What the project already has

**`hello_app/models.py`** — the `Note` model:

```python
class Note(models.Model):
    title = models.CharField(max_length=200, verbose_name='Title')
    content = models.TextField(blank=True, verbose_name='Text')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Created')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = 'Note'
        verbose_name_plural = 'Notes'
        ordering = ['-created_at']
```

**`hello_app/views.py`** — the view for the list:
```python
def note_list(request):
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

**`hello_app/templates/hello_app/note_list.html`** — simple HTML without Bootstrap:
```html
<!DOCTYPE html>
<html lang="uk">
...
{% for note in notes %}
<div class="note">
    <h2>{{ note.title }}</h2>
    ...
</div>
{% endfor %}
```

We will completely rewrite the templates and add new ones. We will extend the `models.py` and `views.py` code.

---

## Phase B — Including Bootstrap 5

> **Theory:**
> Read [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §0–2 —
> why Bootstrap, the Mobile First philosophy, how to include it via CDN.
> Read [CSS_BASICS.md](../CSS_BASICS.md) §0 —
> the CSS Rendering Pipeline, to understand why Bootstrap CSS is included in `<head>`.

### Step B1 — Updating settings.py

Open `hello_project/settings.py` and make these changes:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_bootstrap5',         # ← ADD (Bootstrap 5 for forms)
    'debug_toolbar',             # ← ADD (SQL debugger)
    'hello_app',
]

MIDDLEWARE = [
    'debug_toolbar.middleware.DebugToolbarMiddleware',  # ← ADD AS THE FIRST ONE
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# At the end of the file add:
INTERNAL_IPS = ['127.0.0.1']

# Bootstrap 5 messages integration
from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',
    messages.INFO:    'info',
    messages.SUCCESS: 'success',
    messages.WARNING: 'warning',
    messages.ERROR:   'danger',
}
```

> **What is `MESSAGE_TAGS`?**
> Django Messages (flash messages after a POST) have their own levels: `success`, `error`, etc.
> A Bootstrap Alert uses `alert-success`, `alert-danger`.
> `MESSAGE_TAGS` maps between them.
> More details: [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §4 — Bootstrap Alerts.

### Step B2 — Updating urls.py

Open `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
] + debug_toolbar_urls()
```

---

## Phase C — Creating base.html

> **Theory:**
> Read [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §3–5 —
> Template Inheritance, `{% extends %}`, `{% block %}`.
> Read [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §5 — the Navbar component.

Django looks for templates in `<app>/templates/`.
We will create `base.html` **outside** `hello_app/templates/hello_app/` —
directly in `hello_app/templates/`, so that it is available globally.

### Step C1 — Template folder structure

```
hello_app/templates/
├── base.html                    ← NEW — Bootstrap shell for all pages
└── hello_app/
    ├── note_list.html           ← already exists — we will rewrite it
    ├── note_detail.html         ← NEW
    ├── note_form.html           ← NEW
    └── note_confirm_delete.html ← NEW
```

### Step C2 — Create `hello_app/templates/base.html`

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>

    <!--
        Bootstrap 5 CSS — included in <head>.
        Why: the browser reads CSS before rendering the page body.
        If you include it at the end, you get a "flash of unstyled content".
        Theory: CSS_BASICS.md §0 — Rendering Pipeline.
    -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
          crossorigin="anonymous">

    <!-- Bootstrap Icons — a separate icon library -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    <!-- Slot for additional CSS on specific pages -->
    {% block extra_css %}{% endblock %}
</head>
<body class="bg-light d-flex flex-column min-vh-100">
<!--
    Sticky Footer — three Bootstrap classes solve the "floating" footer problem.
    d-flex flex-column — body becomes a vertical flex container.
    min-vh-100 — body always takes at least 100% of the window height.
    flex-grow-1 on <main> below — main takes all the free space between nav and footer.
    Theory: CSS_BASICS.md §9 — Flexbox, Bootstrap §3 — Utility Classes.
-->

    <!--
        NAVBAR — the Bootstrap navigation component.
        navbar-expand-lg: horizontal on large screens, a hamburger on small ones.
        Theory: BOOTSTRAP_5.md §5 — Navbar, Responsive collapse.
    -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">

            <!-- Brand — site name / logo -->
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Hamburger button for mobile (xs/sm/md) -->
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse"
                    data-bs-target="#navbarNav"
                    aria-controls="navbarNav"
                    aria-expanded="false"
                    aria-label="Open menu">
                <span class="navbar-toggler-icon"></span>
            </button>

            <!-- Navigation links (hidden on mobile) -->
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_list' %}">
                            <i class="bi bi-list-ul me-1"></i>All notes
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_create' %}">
                            <i class="bi bi-plus-circle me-1"></i>New note
                        </a>
                    </li>
                </ul>
                <ul class="navbar-nav">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'admin:index' %}">
                            <i class="bi bi-gear me-1"></i>Admin
                        </a>
                    </li>
                </ul>
            </div>

        </div>
    </nav>

    <!-- Main content — flex-grow-1 stretches main between the navbar and the footer -->
    <main class="container my-4 flex-grow-1">

        <!--
            Django Messages → Bootstrap Alerts.
            messages — a Context Processor that is automatically available in all templates.
            message.tags → 'success'/'danger'/'warning' (mapping from MESSAGE_TAGS in settings.py).
            Theory: BOOTSTRAP_5.md §4 — Alert, DJANGO_TEMPLATES_BOOTSTRAP.md §8 — Bootstrap Forms.
        -->
        {% if messages %}
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                <i class="bi bi-{% if message.tags == 'success' %}check-circle{% elif message.tags == 'danger' %}exclamation-triangle{% else %}info-circle{% endif %} me-2"></i>
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"
                        aria-label="Close"></button>
            </div>
            {% endfor %}
        {% endif %}

        <!--
    Slot for the content of a specific page.
    Each child page inserts its own content here.
    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §4 — Template Inheritance.
         -->
        {% block content %}{% endblock %}

    </main>

    <!-- Footer -->
    <footer class="bg-dark text-center text-white-50 py-3 mt-5">
        <small>Bootstrap Notes &copy; 2026 — a learning project</small>
    </footer>

    <!--
        Bootstrap JS Bundle (includes Popper.js).
        defer — loaded after the HTML.
        Why: Modal, Navbar collapse and Toast need JS.
        Theory: BOOTSTRAP_5.md §8 — Bootstrap JS Architecture.
    -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmAgD0SnMiKKmFClVgaFa11iGj0E"
            crossorigin="anonymous" defer></script>

    <!-- Slot for page-specific JS -->
    {% block extra_js %}{% endblock %}

</body>
</html>
```

> **The key idea of `base.html`:**
> One file contains the Bootstrap CDN, Navbar, Footer and Messages.
> All other templates only write `{% extends 'base.html' %}` and fill in `{% block content %}`.
> Changing the Navbar or Footer in **one place** — automatically applies everywhere.

### Step C3 — Sticky Footer (the footer is always at the bottom)

**Problem:** if a page has little content (for example, 1–2 notes or an empty list),
the footer "hangs" in the middle of the page, with empty background below it.

**Cause:** by default `<body>` is exactly as tall as its content.
When the content is shorter than the window height, the body ends, the footer comes after it, and the rest of the window is empty background.

**Solution — a Sticky Footer with Bootstrap Flexbox:**

```html
<!-- BEFORE: -->
<body class="bg-light">
    ...
    <main class="container my-4">

<!-- AFTER: -->
<body class="bg-light d-flex flex-column min-vh-100">
    ...
    <main class="container my-4 flex-grow-1">
```

**What these classes do:**

| Class | Where | What it does |
|------|----|-----------|
| `d-flex` | `<body>` | Turns body into a flex container |
| `flex-column` | `<body>` | Flex direction: vertical (navbar → main → footer) |
| `min-vh-100` | `<body>` | Body takes at least 100% of the window height (`100vh`) |
| `flex-grow-1` | `<main>` | Main stretches over all the free space between the navbar and footer |

**Visual diagram:**

```
┌────────────────────── body (min-vh-100) ──────────────────────┐
│  <nav>        — fixed height                                  │
│  <main>       — flex-grow-1: takes all that is left    ↕↕↕   │
│  <footer>     — fixed height, always at the bottom            │
└───────────────────────────────────────────────────────────────┘
```

> **Theory:** CSS_BASICS.md §9 — Flexbox: `flex-direction`, `flex-grow`, `min-height`.
> This is a standard pattern for any site where the footer must be at the bottom of the page.

---

## Phase D — The list of notes with Bootstrap Cards

> **Theory:**
> Read [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §6 — Card Grid, `row-cols-*`, `h-100`.
> Read [CSS_BASICS.md](../CSS_BASICS.md) §9–10 — Flexbox and Grid (Bootstrap is built on them).

### Step D1 — Rewrite `hello_app/templates/hello_app/note_list.html`

```html
{% extends 'hello_app/base.html' %}
{% load django_bootstrap5 %}

{% block title %}My notes — Bootstrap Notes{% endblock %}

{% block content %}

<!--
    Page Header.
    Here we show the page title, the number of notes
    and the button for creating a new note.
-->
<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="h2 mb-1">
            <i class="bi bi-journal-text me-2 text-primary"></i>
            My notes
        </h1>

        <!--
            The length filter counts the number of items in the notes list.
            We do not write Django syntax in curly braces here, because HTML comments
            are still processed by the Django template engine.
        -->
        <p class="text-muted mb-0">
            {{ notes|length }} notes
        </p>
    </div>

    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>
        New note
    </a>
</div>

<!--
    Condition: if the notes list is not empty, show the card grid.
    If the list is empty, the Empty State below will be shown.
-->
{% if notes %}

    <!--
        Bootstrap Grid:
        row-cols-1 — one column on small screens;
        row-cols-md-2 — two columns on medium screens;
        row-cols-lg-3 — three columns on large screens;
        g-4 — gaps between cards.
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">

        <!--
            The loop over notes starts below.
            Each note is rendered as a separate Bootstrap Card.
            IMPORTANT: do not write a Django for tag in this comment.
        -->
        {% for note in notes %}
        <div class="col">

            <!--
                Card — the Bootstrap component for a single note.
                h-100 makes cards the same height within a row.
                shadow-sm adds a light shadow.
            -->
            <div class="card h-100 shadow-sm">

                <div class="card-body">

                    <!--
                        The note title is a link to the detail page.
                    -->
                    <h5 class="card-title">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark">
                            {{ note.title }}
                        </a>
                    </h5>

                    <!--
                        If the note has content, show a short preview.
                        truncatechars cuts long text to the given number of characters.
                    -->
                    {% if note.content %}
                    <p class="card-text text-muted small">
                        {{ note.content|truncatechars:100 }}
                    </p>
                    {% else %}
                    <p class="card-text text-muted small fst-italic">
                        No content.
                    </p>
                    {% endif %}

                </div>

                <!--
                    Card footer: creation date and action buttons.
                    timesince shows how much time has passed since creation.
                -->
                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} ago
                    </small>

                    <!--
                        A group of small buttons: edit and delete.
                    -->
                    <div class="btn-group btn-group-sm">
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary"
                           title="Edit">
                            <i class="bi bi-pencil"></i>
                        </a>

                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger"
                           title="Delete">
                            <i class="bi bi-trash"></i>
                        </a>
                    </div>
                </div>

            </div>
        </div>
        {% endfor %}

    </div>

{% else %}

    <!--
        Empty State.
        Shown when there are no notes in the database yet.
    -->
    <div class="text-center py-5">
        <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>

        <h4 class="text-muted">
            No notes yet
        </h4>

        <p class="text-muted">
            Create your first note and it will appear here.
        </p>

        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>
            Create a note
        </a>
    </div>

{% endif %}

{% endblock %}
```

---

## Phase E — The note form with Bootstrap

> **Theory:**
> Read [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §9 — Bootstrap Forms.
> Read [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §7 — Bootstrap Forms in Django.
> Read [HTML_BASICS.md](../HTML_BASICS.md) §5 — HTML Forms, input types.

### Step E1 — Create `hello_app/forms.py`

Create a **new file** `hello_app/forms.py`:

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm — automatically generates form fields from the Note model.
    Django takes the field types from the model and generates the matching HTML inputs.
    CharField(max_length=200) → <input type="text" maxlength="200">
    TextField → <textarea>

    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §7 — ModelForm internals.
    """

    class Meta:
        model = Note
        fields = ['title', 'content']  # which fields to include in the form
        widgets = {
            # Add the Bootstrap class='form-control' to each field
            # Without this Django renders bare HTML without Bootstrap styles
            'title': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Enter the note title...',
                'autofocus': True,
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 6,
                'placeholder': 'Note text...',
            }),
        }
        labels = {
            'title': 'Title',
            'content': 'Content',
        }
```

### Step E2 — Updating views.py

Open `hello_app/views.py` and add the new view functions:

```python
from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse
from django.contrib import messages   # ← Django Messages

from .models import Note
from .forms import NoteForm           # ← our form


def index(request):
    """Redirect from / to /notes/."""
    return redirect('hello_app:note_list')


def note_list(request):
    """List of all notes."""
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    """
    Note detail.
    get_object_or_404: if a note with this pk does not exist → returns 404 (not 500).
    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §6 — HttpRequest/Response.
    """
    note = get_object_or_404(Note, pk=pk)
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    The PRG (Post/Redirect/Get) pattern:
    GET  → show an empty form
    POST → process, save → redirect to the list (so that F5 does not duplicate)
    Without a redirect: F5 after a POST repeats the save → a duplicate note.
    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §8 — PRG Pattern.
    """
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            # Django Message — the flash message is displayed after the redirect
            messages.success(request, f'Note "{note.title}" created successfully!')
            return redirect('hello_app:note_list')
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'action': 'Create',
        'title': 'New note',
    })


def note_edit(request, pk):
    """Editing a note — the same PRG, but the form is initialized with instance=note."""
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Note "{note.title}" updated!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)  # instance fills the form with the current data

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'note': note,
        'action': 'Save changes',
        'title': f'Edit: {note.title}',
    })


def note_delete(request, pk):
    """
    Deletion via POST (not GET!).
    GET → confirmation page.
    POST → delete → redirect.
    Never delete via GET — it is dangerous (CSRF, prefetch).
    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §8 — Security, CSRF.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title
        note.delete()
        messages.warning(request, f'Note "{title}" deleted.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### Step E3 — Updating urls.py

Open `hello_app/urls.py` and replace its contents:

```python
from django.urls import path
from . import views

app_name = 'hello_app'

urlpatterns = [
    path('', views.index, name='index'),
    path('notes/', views.note_list, name='note_list'),
    path('notes/new/', views.note_create, name='note_create'),
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    path('notes/<int:pk>/edit/', views.note_edit, name='note_edit'),
    path('notes/<int:pk>/delete/', views.note_delete, name='note_delete'),
]
```

> **What is `<int:pk>`?**
> A path converter — it captures an integer from the URL and passes it to the view as the `pk` argument.
> `/notes/42/` → `pk=42` → `Note.objects.get(pk=42)`.

---

## Phase F — Templates for detail, form and deletion

> **Theory:**
> Read [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §9 — Form validation, invalid-feedback.
> Read [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §7 — the django-bootstrap5 tag.

### Step F1 — `hello_app/templates/hello_app/note_detail.html`

```html
{% extends 'hello_app/base.html' %}

{% block title %}{{ note.title }} — Bootstrap Notes{% endblock %}

{% block content %}

<!-- Breadcrumb — navigation breadcrumbs -->
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item">
            <a href="{% url 'hello_app:note_list' %}">Notes</a>
        </li>
        <!--
            truncatechars:30 — shorten a long title in the breadcrumb
            Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §3 — Filters.
        -->
        <li class="breadcrumb-item active" aria-current="page">
            {{ note.title|truncatechars:30 }}
        </li>
    </ol>
</nav>

<div class="card shadow-sm">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h1 class="h4 mb-0">{{ note.title }}</h1>
        <div class="btn-group">
            <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
               class="btn btn-sm btn-outline-secondary">
                <i class="bi bi-pencil me-1"></i>Edit
            </a>
            <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
               class="btn btn-sm btn-outline-danger">
                <i class="bi bi-trash me-1"></i>Delete
            </a>
        </div>
    </div>

    <div class="card-body">
        {% if note.content %}
            <!--
                linebreaks — converts \n into <p> tags.
                Without it all the text will be on one line.
                Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §3 — linebreaks filter.
            -->
            <p class="card-text">{{ note.content|linebreaks }}</p>
        {% else %}
            <p class="text-muted fst-italic">No content.</p>
        {% endif %}
    </div>

    <div class="card-footer text-muted small">
        <i class="bi bi-clock me-1"></i>
        Created on {{ note.created_at|date:"d.m.Y" }} at {{ note.created_at|date:"H:i" }}
        ({{ note.created_at|timesince }} ago)
    </div>
</div>

<a href="{% url 'hello_app:note_list' %}" class="btn btn-link mt-3">
    <i class="bi bi-arrow-left me-1"></i>Back to the list
</a>

{% endblock %}
```

### Step F2 — `hello_app/templates/hello_app/note_form.html`

```html
{% extends 'hello_app/base.html' %}

{% load django_bootstrap5 %}

{% block title %}{{ title }} — Bootstrap Notes{% endblock %}

{% block content %}

<div class="row justify-content-center">
    <div class="col-12 col-md-8 col-lg-6">

        <div class="card shadow-sm">
            <div class="card-header">
                <h1 class="h4 mb-0">
                    <i class="bi bi-{% if note %}pencil{% else %}plus-circle{% endif %} me-2"></i>
                    {{ title }}
                </h1>
            </div>

            <div class="card-body">
                <!--
                    {% csrf_token %} — REQUIRED in every POST form!
                    Without it Django returns 403 Forbidden.
                    CSRF: Cross-Site Request Forgery protection.
                    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §8 — CSRF.
                -->
                <form method="post" novalidate>
                    {% csrf_token %}

                    <!--
                        Option 1 — manual form rendering (Bootstrap classes explicitly).
                        Each field: label → input → errors.
                        Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §7 — Manual Form.
                    -->
                    {% for field in form %}
                    <div class="mb-3">
                        <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
                            {{ field.label }}
                            {% if field.field.required %}
                                <span class="text-danger" title="Required field">*</span>
                            {% endif %}
                        </label>

                        <!--
                            field is a Django BoundField.
                            When rendered, it uses the widget from forms.py.
                            We already added class='form-control' in NoteForm.
                            Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §7 — Widget attrs.
                        -->
                        {{ field }}

                        {% if field.help_text %}
                            <div class="form-text text-muted">{{ field.help_text }}</div>
                        {% endif %}

                        <!--
                            Validation errors — the Bootstrap is-invalid class.
                            field.errors — a list of error strings.
                        -->
                        {% for error in field.errors %}
                            <div class="invalid-feedback d-block">
                                <i class="bi bi-exclamation-circle me-1"></i>{{ error }}
                            </div>
                        {% endfor %}
                    </div>
                    {% endfor %}

                    <!-- Form buttons -->
                    <div class="d-flex justify-content-between align-items-center pt-2">
                        <a href="{% if note %}{% url 'hello_app:note_detail' pk=note.pk %}{% else %}{% url 'hello_app:note_list' %}{% endif %}"
                           class="btn btn-outline-secondary">
                            <i class="bi bi-x-lg me-1"></i>Cancel
                        </a>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>{{ action }}
                        </button>
                    </div>
                </form>
            </div>
        </div>

    </div>
</div>

{% endblock %}
```

> **Option 2 — automatic rendering with `django-bootstrap5`:**
>
> Instead of the manual `{% for field in form %}` loop, you can write a single line:
> ```html
> {% load django_bootstrap5 %}
> {% bootstrap_form form %}
> ```
> The `django-bootstrap5` package automatically adds all Bootstrap classes, labels and errors.
> Theory: [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §7 — django-bootstrap5.

### Step F3 — `hello_app/templates/hello_app/note_confirm_delete.html`

```html
{{% extends 'hello_app/base.html' %}

{% block title %}Delete note — Bootstrap Notes{% endblock %}

{% block content %}

<div class="row justify-content-center">
    <div class="col-12 col-md-6">

        <!--
            A Bootstrap Alert with the danger class — a warning.
            Theory: BOOTSTRAP_5.md §4 — Alerts.
        -->
        <div class="card border-danger shadow-sm">
            <div class="card-header bg-danger text-white">
                <h4 class="mb-0">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Confirm deletion
                </h4>
            </div>
            <div class="card-body">
                <p class="mb-3">
                    Do you really want to delete the note
                    <strong>"{{ note.title }}"</strong>?
                </p>
                <p class="text-danger small">
                    <i class="bi bi-info-circle me-1"></i>
                    This action cannot be undone.
                </p>

                <!--
                    Deletion via POST — never via GET.
                    A GET can be executed automatically (prefetch, bots).
                    A POST requires a deliberate user action + CSRF protection.
                    Theory: DJANGO_TEMPLATES_BOOTSTRAP.md §8 — HTTP Methods.
                -->
                <form method="post">
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary flex-fill">
                            <i class="bi bi-x-lg me-1"></i>Cancel
                        </a>
                        <button type="submit" class="btn btn-danger flex-fill">
                            <i class="bi bi-trash me-1"></i>Delete
                        </button>
                    </div>
                </form>
            </div>
        </div>

    </div>
</div>

{% endblock %}
```

---

## Phase G — Unfold Admin

> **What is django-unfold?**
> A library that replaces the standard Django Admin with a Tailwind-CSS-styled interface.
> It requires no changes to the logic — it only changes inheritance and adds an `UNFOLD` dictionary to `settings.py`.
>
> **Theory:**
> Read [DJANGO_ADMIN_UNFOLD.md](../DJANGO_ADMIN_UNFOLD.md) §2 — ModelAdmin,
> §7 — `UNFOLD` config, sidebar navigation.

### Step G1 — Updating `hello_project/settings.py`

Add the `UNFOLD` dictionary after `MESSAGE_TAGS`:

```python
from django.urls import reverse_lazy
from django.utils.translation import gettext_lazy as _

UNFOLD = {
    "SITE_TITLE": "Bootstrap Notes",       # title in <title>
    "SITE_HEADER": "Bootstrap Notes",      # large header in the sidebar
    "SITE_SUBHEADER": "Notes management",
    "SHOW_HISTORY": True,
    "SHOW_VIEW_ON_SITE": False,
    "SHOW_BACK_BUTTON": True,
    "SIDEBAR": {
        "show_search": False,
        "show_all_applications": False,
        "navigation": [
            {
                "title": _("Content"),
                "separator": False,
                "collapsible": False,
                "items": [
                    {
                        "title": _("Notes"),
                        "icon": "description",  # Material Symbol icon
                        "link": reverse_lazy("admin:hello_app_note_changelist"),
                    },
                ],
            },
            {
                "title": _("Access"),
                "separator": True,
                "collapsible": False,
                "items": [
                    {
                        "title": _("Users"),
                        "icon": "people",
                        "link": reverse_lazy("admin:auth_user_changelist"),
                    },
                    {
                        "title": _("Groups"),
                        "icon": "group",
                        "link": reverse_lazy("admin:auth_group_changelist"),
                    },
                ],
            },
        ],
    },
}
```

> **`icon`** — the name of an icon from [Google Material Symbols](https://fonts.google.com/icons).
> Write the name in lowercase with underscores: `description`, `people`, `add_circle`.

### Step G2 — Updating `hello_app/admin.py`

```python
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.models import User, Group
from django.utils.html import format_html

# unfold.admin.ModelAdmin replaces django.contrib.admin.ModelAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import Note


# Django registers User and Group without Unfold — unregister them and register again
admin.site.unregister(User)
admin.site.unregister(Group)


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm


@admin.register(Group)
class GroupAdmin(BaseGroupAdmin, ModelAdmin):
    pass


@admin.register(Note)
class NoteAdmin(ModelAdmin):
    list_display = ['title', 'short_content', 'created_at']
    search_fields = ['^title', 'content']
    list_filter = ['created_at']
    readonly_fields = ['created_at']
    ordering = ['-created_at']
    list_per_page = 20

    @admin.display(description='Content (preview)')
    def short_content(self, obj):
        if not obj.content:
            return '—'
        preview = obj.content[:80] + ('...' if len(obj.content) > 80 else '')
        return format_html('<span style="color:#6b7280">{}</span>', preview)
```

> **The key difference from the standard Django Admin:**
>
> | Before (Django Admin) | After (Unfold Admin) |
> |---|---|
> | `class NoteAdmin(admin.ModelAdmin)` | `class NoteAdmin(ModelAdmin)` |
> | No User/Group re-registration | `unregister` + `register` with Unfold forms |
> | Branding: `admin.site.site_header = ...` | Branding: `UNFOLD["SITE_HEADER"]` in settings.py |
> | No sidebar navigation | `UNFOLD["SIDEBAR"]["navigation"]` |

---

## Step 8 — Check migrations (if you changed models.py)

If you **did not change** `models.py`, skip this step.
If you added fields, run:

```bash
python manage.py makemigrations
python manage.py migrate
```

---

## Step 9 — Run and check

```bash
python manage.py runserver
```

| URL | What to check |
|-----|---------------|
| http://localhost:8000/ | Redirect to /notes/ |
| http://localhost:8000/notes/ | List with Bootstrap Cards |
| http://localhost:8000/notes/new/ | Create form with Bootstrap styles |
| http://localhost:8000/notes/1/ | Note detail |
| http://localhost:8000/notes/1/edit/ | Edit form (filled with data) |
| http://localhost:8000/notes/1/delete/ | Delete confirmation page |
| http://localhost:8000/admin/ | Admin panel with the custom NoteAdmin |

> **What to check in the browser:**
> 1. List: Cards have equal height (`h-100`)
> 2. Mobile (DevTools → Toggle Device, Ctrl+Shift+M): 1 column, hamburger Navbar
> 3. Tablet: 2 columns, horizontal Navbar
> 4. Desktop: 3 columns
> 5. Form: with an empty title, a Bootstrap validation error appears
> 6. After creating → a success flash message

---

## Phase H — Django Debug Toolbar (SQL panel)

> **Theory:**
> Read [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §9 — DjDT.
> Read [DJANGO_ADMIN_UNFOLD.md](../DJANGO_ADMIN_UNFOLD.md) §5 — Query Architecture, N+1.

The toolbar is already connected (we added it in Settings and URLs).
Go to **http://localhost:8000/notes/** — a black DJDT panel will appear on the right.

**What to explore:**

| Panel | What to look for |
|--------|-----------|
| **SQL** | How many queries for /notes/? There should be 1–2 |
| **Templates** | Which templates were used (base.html + note_list.html) |
| **Headers** | Request/Response headers |
| **Time** | Template rendering time |

> **If the toolbar does not appear:**
> 1. `DEBUG = True` in settings.py?
> 2. Is `INTERNAL_IPS = ['127.0.0.1']` present in settings.py?
> 3. `'debug_toolbar'` in `INSTALLED_APPS`?
> 4. `debug_toolbar_urls()` in urls.py?
> 5. Does the page have a `<body>` tag? (Needed to inject the panel)

---

## Summary: all commands in order

```bash
# 1. Open the project folder
cd module_5\lesson_HTML_CSS_Bootstrap\django_bootstrap_project

# 2. Create and activate venv
python -m venv venv
venv\Scripts\activate       # Windows
# source venv/bin/activate  # Linux/Mac

# 3. Install dependencies
pip install -r requirements.txt

# 4. Apply migrations
python manage.py migrate

# 5. Create an administrator
python manage.py createsuperuser

# 6. Run the server
python manage.py runserver
# → http://localhost:8000/notes/
```

---

## What you did — changes in files

| File | What was done |
|------|-------------|
| `hello_project/settings.py` | `django_bootstrap5`, `debug_toolbar`, `MESSAGE_TAGS`, `UNFOLD` config |
| `hello_project/urls.py` | Connected `debug_toolbar_urls()` |
| `hello_app/admin.py` | `NoteAdmin(ModelAdmin)` with Unfold, re-registration of User/Group |
| `hello_app/forms.py` | `NoteForm` with Bootstrap widgets (new file) |
| `hello_app/views.py` | CRUD views: `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| `hello_app/urls.py` | 6 URL routes for CRUD |
| `hello_app/templates/base.html` | Bootstrap CDN, Navbar, Messages, Footer, Sticky Footer (new file) |
| `hello_app/templates/hello_app/note_list.html` | Bootstrap Card Grid, Empty State |
| `hello_app/templates/hello_app/note_detail.html` | Detail with a Breadcrumb (new file) |
| `hello_app/templates/hello_app/note_form.html` | Bootstrap Form with validation (new file) |
| `hello_app/templates/hello_app/note_confirm_delete.html` | Delete confirmation (new file) |

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` is not where Django looks for it | The file must be in `hello_app/templates/base.html` (not in `hello_app/templates/hello_app/`) |
| `NoReverseMatch: 'note_create'` | The URL name is not registered or the namespace is wrong | Check `hello_app/urls.py` and `app_name = 'hello_app'` |
| `403 Forbidden` after a POST | `{% csrf_token %}` is missing in the form | Add `{% csrf_token %}` inside the `<form>` |
| Bootstrap styles are not applied | `class='form-control'` was not added to the widget | Check `NoteForm.Meta.widgets` in `forms.py` |
| Debug Toolbar does not appear | Not all conditions are met | Check the checklist in Phase H |
| `IntegrityError` on save | `title` cannot be empty | Check form validation: `form.is_valid()` |
| `ImproperlyConfigured: namespace` | `app_name` is missing in `urls.py` | Add `app_name = 'hello_app'` |
| Cards of different heights | No `h-100` on `.card` | Add the `h-100` class to `<div class="card">` |
| Footer in the middle of the page | `<body>` has the height of its content, not of the window | Add `d-flex flex-column min-vh-100` to `<body>` and `flex-grow-1` to `<main>` |

---

## Next steps

You have built a full-fledged Bootstrap application. What's next:

### Level 1 — Extending the model
Add fields to `Note`: `is_public`, `category`, `tags`.
Read: [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §2 — Context, Dot-Lookup.

### Level 2 — Search and filtering
Add a search box to the `note_list` view (`request.GET.get('q')`).
Read: [ADVANCED_TEMPLATES.md](../ADVANCED_TEMPLATES.md) §5 — SaaS Dashboard, filter form.

### Level 3 — Pagination
Split the list into pages with Django's `Paginator`.
Read: [ADVANCED_TEMPLATES.md](../ADVANCED_TEMPLATES.md) §5 — `components/pagination.html`.

### Level 4 — A Modal for deletion
Instead of a separate delete page — a Bootstrap Modal right from the list.
Read: [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §8 — Modal, JS Event Lifecycle.

### Level 5 — Django Ninja API
Add a REST endpoint `/api/notes/` with Django Ninja.
Read: [DJANGO_NINJA_TEMPLATES.md](../DJANGO_NINJA_TEMPLATES.md) §1–4.

### Level 6 — Unfold Admin ✓ (already implemented)
`django-unfold` is connected. The next step is to extend the `UNFOLD` config:
a custom dashboard (`DASHBOARD_CALLBACK`), colors (`COLORS`), a logo (`SITE_LOGO`).
Read: [DJANGO_ADMIN_UNFOLD.md](../DJANGO_ADMIN_UNFOLD.md) §7–12.

### Level 7 — HTMX live search
Replace page reloads with HTMX partial renders.
Read: [ADVANCED_TEMPLATES.md](../ADVANCED_TEMPLATES.md) §7 — HTMX Architecture.

---

## Where to read the theory — a quick reference

| Question | File |
|---------|------|
| How does the browser read HTML? | [HTML_BASICS.md](../HTML_BASICS.md) §0 |
| What is the Box Model? | [CSS_BASICS.md](../CSS_BASICS.md) §6 |
| How does the Bootstrap Grid work? | [BOOTSTRAP_5.md](../BOOTSTRAP_5.md) §2–3 |
| What is Template Inheritance? | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §4 |
| How does Django generate HTML? | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §0 |
| What is CSRF? | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §8 |
| How do I connect django-bootstrap5? | [DJANGO_TEMPLATES_BOOTSTRAP.md](../DJANGO_TEMPLATES_BOOTSTRAP.md) §7 |
| What is an N+1 query? | [DJANGO_ADMIN_UNFOLD.md](../DJANGO_ADMIN_UNFOLD.md) §5 |
| What is a Context Processor? | [ADVANCED_TEMPLATES.md](../ADVANCED_TEMPLATES.md) §1 |
| How do I build HTMX search? | [ADVANCED_TEMPLATES.md](../ADVANCED_TEMPLATES.md) §7 |
