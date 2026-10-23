# ModelForm and CRUD

> On this page you will build a complete CRUD for `Note`:
> a create/edit form (ModelForm), protection against duplicates (PRG),
> flash messages, and Bootstrap templates.

---

## Theory: ModelForm

> `ModelForm` — Django automatically generates an HTML form from a Python model.
> One class replaces 50 lines of HTML.

### Without ModelForm vs With ModelForm

```python
# ❌ WITHOUT ModelForm: you describe every field by hand
class NoteFormManual(forms.Form):
    title   = forms.CharField(max_length=200, label='Title')
    content = forms.CharField(widget=forms.Textarea, required=False, label='Text')
    # + duplication with the model — when models.py changes → you must edit here too

# ✅ WITH ModelForm: a single line fields = [...]
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content']
        # Django looks at Note.title (CharField(max_length=200)) itself
        # and generates forms.CharField(max_length=200)
        # Synchronization is automatic when the model changes
```

### What ModelForm generates automatically

```
Note model                        NoteForm generates
──────────────────────────────────────────────────────────────────
CharField(max_length=200)     →   forms.CharField(max_length=200)
                                  widget=TextInput
                                  → <input type="text" maxlength="200">

TextField(blank=True)         →   forms.CharField(required=False)
                                  widget=Textarea
                                  → <textarea rows="10"></textarea>

SmallIntegerField(choices)    →   forms.TypedChoiceField(choices=...)
                                  widget=Select
                                  → <select><option>...</option></select>

BooleanField(default=False)   →   forms.BooleanField(required=False)
                                  widget=CheckboxInput
                                  → <input type="checkbox">

ForeignKey(Notebook)          →   forms.ModelChoiceField(
                                      queryset=Notebook.objects.all())
                                  widget=Select
                                  → <select> with all notebooks

ManyToManyField(Tag)          →   forms.ModelMultipleChoiceField(
                                      queryset=Tag.objects.all())
                                  widget=SelectMultiple
```

### The form cycle: GET → POST → redirect

```python
def note_create(request):

    if request.method == 'POST':
        form = NoteForm(request.POST)
        # request.POST: QueryDict {'title': ['Note'], 'content': ['']}
        # NoteForm is bound to the data → bound form

        if form.is_valid():
            # is_valid() does the following:
            # 1. Converts strings from request.POST into Python types
            # 2. Runs the validators of every field
            # 3. Runs clean_<field>() if present
            # 4. Runs form.clean() (cross-field validation)
            # If there are errors → is_valid() = False → form.errors is populated

            note = form.save()
            # form.save() = form.instance.save()
            # Executes INSERT INTO hello_app_note (...) VALUES (...)
            # Returns the saved object

            return redirect('hello_app:note_list')
    else:
        form = NoteForm()
        # Unbound form — empty

    return render(request, 'hello_app/note_form.html', {'form': form})
    # If is_valid() = False → we return THE SAME form with errors
    # form.errors: {'title': ['This field is required.']}
```

### form.save() and form.save(commit=False)

```python
# form.save() — saves and returns the object
note = form.save()   # INSERT INTO + return Note instance

# form.save(commit=False) — does not save, returns an unsaved object
note = form.save(commit=False)
note.user = request.user   # ← add fields that are not in the form
note.save()                # ← now we save

# Why commit=False?
# The NoteForm form does not include the user field (IDOR protection)
# So the view adds user = request.user manually before saving
# In notes_chat_app this is a mandatory pattern — without it you get IDOR
```

### A form with instance — editing

```python
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        # Bound form + existing object
        # form.save() → UPDATE instead of INSERT
    else:
        form = NoteForm(instance=note)
        # Form is filled with the current note data

    # Without instance: form.save() is always an INSERT (a duplicate!)
    # With instance: form.save() → UPDATE hello_app_note SET ... WHERE id=note.id
```

---

## Theory: the PRG pattern

> **POST/Redirect/Get** is the standard way to handle forms. It protects against duplicates when the user presses F5.

### The problem without PRG

```
User → POST /notes/new/ (create the note "Shopping")
  ↓ View saves the note, returns 200 with a confirmation
  ↓ Browser shows the page
  ↓ User presses F5 (refresh)
  ↓ Browser REPEATS the POST request ← PROBLEM!
  ↓ A second "Shopping" note is created!

Result: 2 identical notes. F5 again → 3 notes.
```

### The solution — PRG

```
User → POST /notes/new/
  ↓ View saves the note
  ↓ View returns 302 REDIRECT → /notes/
  ↓ Browser GET /notes/ (follows the redirect automatically)
  ↓ Browser shows the list of notes
  ↓ F5 → repeats GET /notes/ (safe!)

Result: only one note. F5 = reloading the list.
```

```python
# ✅ Correct — PRG:
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return redirect('hello_app:note_list')   # ← 302, not 200!
    else:
        form = NoteForm()
    return render(request, 'hello_app/note_form.html', {'form': form})

# ❌ Wrong — no redirect:
def note_create_bad(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return render(request, 'success.html', {'note': note})
            # ↑ The browser stays on the POST URL
            # F5 → browser: "Resend the POST request?" → duplicate!
```

---

## Theory: Django Messages

> Flash messages are one-time messages that disappear after being viewed once.
> Perfect for "Note saved" after a redirect.

### How Messages work

```
1. POST /notes/new/
   messages.success(request, "Note saved!")
   → the message is stored in the SESSION (not in the response)
   ↓
2. redirect → GET /notes/
   template: {% for message in messages %}{{ message }}{% endfor %}
   → the message is displayed
   → the SESSION is cleared (used once!)
   ↓
3. F5 → GET /notes/ again
   messages = empty → the message is gone
```

### Message levels and Bootstrap classes

```python
from django.contrib import messages

messages.debug(request, 'Debug message')
messages.info(request, 'Informational message')
messages.success(request, 'Note saved successfully!')
messages.warning(request, 'Note deleted.')
messages.error(request, 'Error while saving.')
```

Configure it in `hello_project/settings.py`:

```python
from django.contrib.messages import constants as messages

MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',   # → alert-secondary
    messages.INFO:    'info',        # → alert-info
    messages.SUCCESS: 'success',     # → alert-success
    messages.WARNING: 'warning',     # → alert-warning
    messages.ERROR:   'danger',      # → alert-danger (Bootstrap uses danger!)
}
```

### Messages in the template (base.html)

```html
{% if messages %}
    {% for message in messages %}
    <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-3" role="alert">
        {{ message }}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
    {% endfor %}
{% endif %}
```

---

## Theory: Template Inheritance

> A single `base.html` contains the Bootstrap CDN, Navbar, and Footer.
> All other pages only fill in blocks.

### How Django processes templates with {% extends %}

```
1. render(request, 'hello_app/note_list.html', context)

2. Django finds the template:
   APP_DIRS=True → hello_app/templates/hello_app/note_list.html

3. It encounters {% extends 'base.html' %}
   → loads base.html
   → finds all {% block name %}...{% endblock %}

4. For every block:
   → if the child template overrides it → uses the child's content
   → if not → uses the base content

5. {{ variable }} → replaced with the context value
```

### base.html blocks

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>
    <link rel="stylesheet" href="...bootstrap.min.css">
    {% block extra_css %}{% endblock %}
    <!--
        extra_css: an empty block — a child can add page-specific CSS
    -->
</head>
<body>
    <nav>...</nav>
    <main>
        {% block content %}{% endblock %}
        <!--
            content: the MAIN block — every page fills in its own
        -->
    </main>
    <footer>...</footer>
    <script src="...bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

### Child template

```html
{% extends 'base.html' %}

{% block title %}My notes{% endblock %}

{% block content %}
<h1>Notes</h1>
...
{% endblock %}

{# Blocks we do not override → the base content is used #}
{# (extra_css, extra_js — stay empty) #}
```

---

## Theory: Bootstrap 5 Grid

```
Bootstrap Grid = 12 columns per row
Breakpoints:
  sm  → ≥576px   (larger phone)
  md  → ≥768px   (tablet)
  lg  → ≥992px   (laptop)
  xl  → ≥1200px  (monitor)
```

```html
<!-- Responsive Card Grid: 1 → 2 → 3 columns -->
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    <!--
        row-cols-1:    mobile        → 1 card per row
        row-cols-md-2: tablet        → 2 cards per row
        row-cols-lg-3: laptop/PC     → 3 cards per row
        g-4:           gap (spacing between cards) = 1.5rem
    -->
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <!-- h-100: height = 100% of the row (equal cards) -->
        </div>
    </div>
    {% endfor %}
</div>
```

---

## Step 1 — Bootstrap dependencies in settings.py

```bash
pip install django-bootstrap5
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
    'django_bootstrap5',    # ← Bootstrap 5 for forms ({% bootstrap_form form %})
    'hello_app',
]

from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',
    messages.INFO:    'info',
    messages.SUCCESS: 'success',
    messages.WARNING: 'warning',
    messages.ERROR:   'danger',
}
```

---

## Step 2 — base.html

```
hello_app/
└── templates/
    ├── base.html           ← Here (available to all apps in INSTALLED_APPS)
    └── hello_app/
        ├── note_list.html
        └── ...
```

`hello_app/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>

    <!-- Bootstrap 5 CSS — CDN (no npm/webpack needed) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          crossorigin="anonymous">

    <!-- Bootstrap Icons (bi bi-pencil, bi bi-trash, etc.) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    {% block extra_css %}{% endblock %}
</head>

<!--
    Sticky Footer:
    body.d-flex.flex-column.min-vh-100 + main.flex-grow-1 → the footer is always at the bottom
    even when the content is shorter than the window height
-->
<body class="bg-light d-flex flex-column min-vh-100">

    <!-- ═══════════════ NAVBAR ═══════════════ -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Hamburger for mobile (collapse) -->
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse" data-bs-target="#navMenu">
                <span class="navbar-toggler-icon"></span>
            </button>

            <div class="collapse navbar-collapse" id="navMenu">
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
            </div>
        </div>
    </nav>

    <!-- ═══════════════ MAIN ═══════════════ -->
    <main class="container my-4 flex-grow-1">

        <!-- Django Messages → Bootstrap Alerts -->
        {% if messages %}
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-3"
                 role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"
                        aria-label="Close"></button>
            </div>
            {% endfor %}
        {% endif %}

        {% block content %}{% endblock %}

    </main>

    <!-- ═══════════════ FOOTER ═══════════════ -->
    <footer class="bg-dark text-center text-white-50 py-3 mt-auto">
        <small>Bootstrap Notes &copy; 2026</small>
    </footer>

    <!-- Bootstrap 5 JS (the bundle includes Popper.js) -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}

</body>
</html>
```

---

## Step 3 — NoteForm (ModelForm)

Create `hello_app/forms.py`:

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm for Note.
    Django automatically generates fields from the model:
      title (CharField(max_length=200)) → TextInput
      content (TextField(blank=True))   → Textarea
    """

    class Meta:
        model  = Note
        fields = ['title', 'content']
        # NOT included: created_at (auto_now_add) — Django sets it automatically

        widgets = {
            'title': forms.TextInput(attrs={
                'class':       'form-control',
                'placeholder': 'Enter a title...',
                'autofocus':   True,
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows':  6,
                'placeholder': 'Note text...',
            }),
        }
        labels = {
            'title':   'Title',
            'content': 'Content',
        }
        help_texts = {
            'title':   'A short, descriptive title (up to 200 characters)',
            'content': 'The main content of the note. This field is optional.',
        }

    def clean_title(self):
        """
        Custom validator for the title field.
        clean_<field_name>() is called after the standard validators.
        """
        title = self.cleaned_data.get('title', '').strip()
        if len(title) < 3:
            raise forms.ValidationError('The title must be at least 3 characters long.')
        return title   # ← IMPORTANT: return the cleaned value!
```

### Three ways to render a form in a template

```html
{# Way 1 — as_p (quick, without Bootstrap) #}
{{ form.as_p }}

{# Way 2 — django-bootstrap5 #}
{% load django_bootstrap5 %}
{% bootstrap_form form %}

{# Way 3 — manually (full control over every field) #}
{% for field in form %}
<div class="mb-3">
    <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
        {{ field.label }}
        {% if field.field.required %}<span class="text-danger">*</span>{% endif %}
    </label>
    {{ field }}
    {% if field.help_text %}
    <div class="form-text text-muted">{{ field.help_text }}</div>
    {% endif %}
    {% for error in field.errors %}
    <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
</div>
{% endfor %}
```

---

## Step 4 — CRUD views

`hello_app/views.py`:

```python
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages

from .models import Note
from .forms import NoteForm


def index(request):
    """Home → redirect to the list."""
    return redirect('hello_app:note_list')


def note_list(request):
    """List of all notes."""
    notes = Note.objects.all()              # SELECT * FROM hello_app_note
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    """Detail of a single note."""
    note = get_object_or_404(Note, pk=pk)   # get() or 404
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    GET  → empty form
    POST → validation → saving → redirect (PRG)
    """
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            messages.success(request, f'Note "{note.title}" created successfully!')
            return redirect('hello_app:note_list')
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'action': 'Create',
        'title':  'New note',
    })


def note_edit(request, pk):
    """
    GET  → form filled with the current data (instance=note)
    POST → update (UPDATE, not INSERT)
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Note "{note.title}" updated!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)   # Fill with the current data

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'note':   note,
        'action': 'Save changes',
        'title':  f'Edit: {note.title}',
    })


def note_delete(request, pk):
    """
    GET  → confirmation page
    POST → deletion → redirect (DELETE only via POST!)

    Why only POST?
    If DELETE worked via GET: <a href="/notes/1/delete/"> or <img src=...>
    would delete the note when the page loads.
    POST requires a form with csrf_token → protected.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title   # Save it before deleting
        note.delete()
        messages.warning(request, f'Note "{title}" deleted.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### get_object_or_404 — protection against DoesNotExist

```python
# ❌ Without get_object_or_404:
note = Note.objects.get(pk=pk)
# If not found → DoesNotExist exception → 500 Internal Server Error

# ✅ With get_object_or_404:
note = get_object_or_404(Note, pk=pk)
# If not found → Http404 → 404 Not Found page (correct!)

# Filtering by several fields (IDOR protection):
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 if the note does not exist OR belongs to another user
```

---

## Step 5 — URL routes

`hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = 'hello_app'

urlpatterns = [
    path('',                        views.index,       name='index'),
    path('notes/',                  views.note_list,   name='note_list'),
    path('notes/new/',              views.note_create, name='note_create'),
    path('notes/<int:pk>/',         views.note_detail, name='note_detail'),
    path('notes/<int:pk>/edit/',    views.note_edit,   name='note_edit'),
    path('notes/<int:pk>/delete/',  views.note_delete, name='note_delete'),
]
```

**Important: `notes/new/` comes before `notes/<int:pk>/`**

```
'notes/new/' → does not match <int:pk> because 'new' is not an int → OK
'notes/42/'  → <int:pk> → pk=42 → OK

The <int:pk> converter accepts only digits ([0-9]+), so 'new' does not
match it even if the order is reversed — there is no ValueError.
But with a broader pattern the order is critical:
'notes/<slug:slug>/' placed higher → 'new' → slug='new' → the wrong view!
Django checks urlpatterns FROM TOP TO BOTTOM → the first match wins.
More specific patterns go higher!
```

---

## Step 6 — The list template

`hello_app/templates/hello_app/note_list.html`:

```html
{% extends 'base.html' %}

{% block title %}My notes{% endblock %}

{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h2 mb-0">
        My notes
        <span class="badge bg-secondary fs-6">{{ notes|length }}</span>
    </h1>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>New note
    </a>
</div>

{% if notes %}
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
        {% for note in notes %}
        <div class="col">
            <div class="card h-100 shadow-sm">

                <div class="card-body">
                    <h5 class="card-title mb-1">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark stretched-link">
                            {{ note.title }}
                        </a>
                        <!--
                            stretched-link: the whole .card becomes clickable
                            (position:relative on the card + ::after on the link)
                        -->
                    </h5>
                    <p class="card-text text-muted small mt-2">
                        {{ note.content|truncatechars:120 }}
                        <!--
                            truncatechars:120 → truncates to 120 characters and adds "..."
                        -->
                    </p>
                </div>

                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} ago
                    </small>

                    <div class="btn-group btn-group-sm position-relative z-1">
                        <!-- z-1: above the stretched-link → the buttons are clickable -->
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary" title="Edit">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger" title="Delete">
                            <i class="bi bi-trash"></i>
                        </a>
                    </div>
                </div>

            </div>
        </div>
        {% endfor %}
    </div>

{% else %}
    <div class="text-center py-5">
        <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>
        <h4 class="text-muted">No notes yet</h4>
        <p class="text-muted">Create your first note and it will appear here.</p>
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>Create your first note
        </a>
    </div>
{% endif %}

{% endblock %}
```

---

## Step 7 — The form template

`hello_app/templates/hello_app/note_form.html`:

```html
{% extends 'base.html' %}

{% block title %}{{ title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-8 col-lg-6">
        <div class="card shadow-sm">

            <div class="card-header bg-white border-bottom">
                <h1 class="h4 mb-0">
                    <i class="bi bi-journal-plus me-2"></i>{{ title }}
                </h1>
            </div>

            <div class="card-body">
                <form method="post" novalidate>
                    <!--
                        novalidate: disables the browser's HTML5 validation
                        → Django does the validation on the server (more reliable)
                    -->
                    {% csrf_token %}
                    <!--
                        csrf_token: REQUIRED for every POST form!
                        Django generates: <input type="hidden" name="csrfmiddlewaretoken" value="...">
                        Without it: 403 Forbidden from CsrfViewMiddleware
                    -->

                    {% for field in form %}
                    <div class="mb-3">
                        <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
                            {{ field.label }}
                            {% if field.field.required %}
                            <span class="text-danger" title="Required field">*</span>
                            {% endif %}
                        </label>
                        {{ field }}

                        {% if field.help_text %}
                        <div class="form-text text-muted">{{ field.help_text }}</div>
                        {% endif %}

                        {% for error in field.errors %}
                        <div class="invalid-feedback d-block">
                            <i class="bi bi-exclamation-circle me-1"></i>{{ error }}
                        </div>
                        {% endfor %}
                    </div>
                    {% endfor %}

                    <div class="d-flex gap-2 mt-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>{{ action }}
                        </button>
                        <a href="{% url 'hello_app:note_list' %}"
                           class="btn btn-outline-secondary">
                            <i class="bi bi-x-lg me-1"></i>Cancel
                        </a>
                    </div>

                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

---

## Step 8 — The delete template

`hello_app/templates/hello_app/note_confirm_delete.html`:

```html
{% extends 'base.html' %}

{% block title %}Delete: {{ note.title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-6 col-lg-5">
        <div class="card border-danger shadow-sm">

            <div class="card-header bg-danger text-white">
                <h1 class="h4 mb-0">
                    <i class="bi bi-exclamation-triangle me-2"></i>Delete note
                </h1>
            </div>

            <div class="card-body">
                <p class="mb-1">
                    Do you really want to delete the note
                    <strong>“{{ note.title }}”</strong>?
                </p>
                <p class="text-muted small mb-3">This action cannot be undone.</p>

                <form method="post">
                    <!--
                        DELETE via POST (not GET):
                        GET: <img src="/notes/1/delete/"> would delete on page load
                        POST + csrf_token: protection against CSRF/accidental deletion
                    -->
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-danger">
                            <i class="bi bi-trash me-1"></i>Yes, delete
                        </button>
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary">
                            Cancel
                        </a>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
{% endblock %}
```

---

## Step 9 — The detail template

`hello_app/templates/hello_app/note_detail.html`:

```html
{% extends 'base.html' %}

{% block title %}{{ note.title }}{% endblock %}

{% block content %}

<div class="d-flex justify-content-between align-items-start mb-3">
    <div>
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item">
                    <a href="{% url 'hello_app:note_list' %}">Notes</a>
                </li>
                <li class="breadcrumb-item active">{{ note.title|truncatechars:40 }}</li>
            </ol>
        </nav>
        <h1 class="h2">{{ note.title }}</h1>
        <small class="text-muted">
            <i class="bi bi-calendar me-1"></i>
            Created: {{ note.created_at|date:"d.m.Y о H:i" }}
        </small>
    </div>

    <div class="btn-group">
        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
           class="btn btn-outline-primary">
            <i class="bi bi-pencil me-1"></i>Edit
        </a>
        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
           class="btn btn-outline-danger">
            <i class="bi bi-trash me-1"></i>Delete
        </a>
    </div>
</div>

<div class="card shadow-sm">
    <div class="card-body">
        {% if note.content %}
            <p class="card-text" style="white-space: pre-wrap;">{{ note.content }}</p>
            <!--
                white-space: pre-wrap: preserves line breaks from the TextField
                Without it \n → a space in HTML
                Alternative: {{ note.content|linebreaks }}
            -->
        {% else %}
            <p class="text-muted fst-italic">Note has no content.</p>
        {% endif %}
    </div>
</div>

{% endblock %}
```

---

## The full CRUD cycle

```
CREATE:  GET  /notes/new/        → note_create view → empty form
         POST /notes/new/        → form.save() → redirect → flash message
         GET  /notes/            → list with the new note + flash message

READ:    GET  /notes/            → note_list view → QuerySet → template
         GET  /notes/42/         → note_detail view → get_object_or_404 → template

UPDATE:  GET  /notes/42/edit/    → note_edit view → form with instance=note
         POST /notes/42/edit/    → NoteForm(POST, instance=note).save() → UPDATE → redirect

DELETE:  GET  /notes/42/delete/  → note_delete view → confirmation
         POST /notes/42/delete/  → note.delete() → redirect → flash message
```

---

## File changes after this step

| File | What was done |
|------|-------------|
| `hello_project/settings.py` | `django_bootstrap5` in INSTALLED_APPS, `MESSAGE_TAGS` |
| `hello_app/forms.py` | `NoteForm(ModelForm)` with widgets and `clean_title()` — **NEW** |
| `hello_app/views.py` | 6 views (index + 5 CRUD): `index`, `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| `hello_app/urls.py` | 6 URL routes for CRUD |
| `hello_app/templates/base.html` | Bootstrap CDN, Navbar, Messages, Footer — **NEW** |
| `hello_app/templates/hello_app/note_list.html` | Bootstrap Card Grid — **REWRITTEN** |
| `hello_app/templates/hello_app/note_detail.html` | Detail with Breadcrumb — **NEW** |
| `hello_app/templates/hello_app/note_form.html` | Bootstrap Form — **NEW** |
| `hello_app/templates/hello_app/note_confirm_delete.html` | Deletion — **NEW** |
