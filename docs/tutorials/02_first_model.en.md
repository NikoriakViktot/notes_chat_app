# Tutorial 02 — Bootstrap Notes: ModelForm, CRUD and Templates

> This tutorial turns a simple Django project into a full-fledged Bootstrap 5 application
> with a **Navbar, cards, forms and flash messages**.
>
> **Result:**
> ```
> http://localhost:8000/notes/           →  Notes list — Bootstrap Cards Grid
> http://localhost:8000/notes/new/       →  Create form (ModelForm)
> http://localhost:8000/notes/1/         →  Note detail
> http://localhost:8000/notes/1/edit/    →  Edit form (instance=note)
> http://localhost:8000/notes/1/delete/  →  Delete confirmation (POST only)
> ```
>
> **Prerequisites:** you have completed [Tutorial 01](01_first_django_page.md) — you have a `Note` model and a Django project.

---

## Contents

**Theory** _(read before the code)_
- [01 · ModelForm — an automatic form from a model](#01--modelform)
- [02 · The PRG pattern — why redirect after POST](#02--the-prg-pattern)
- [03 · Django Messages — flash messages](#03--django-messages)
- [04 · Template Inheritance — blocks and inheritance](#04--template-inheritance)
- [05 · Bootstrap 5 — Grid and components](#05--bootstrap-5)
- [06 · Django Template Filters and Tags](#06--template-filters-and-tags)

**Step-by-step implementation**
1. [Step 1 — Bootstrap dependencies](#step-1--bootstrap-dependencies)
2. [Step 2 — base.html — the base template](#step-2--basehtml)
3. [Step 3 — NoteForm (ModelForm)](#step-3--noteform)
4. [Step 4 — CRUD views with PRG](#step-4--crud-views)
5. [Step 5 — URL routes](#step-5--url-routes)
6. [Step 6 — The list template (Card Grid)](#step-6--the-list-template)
7. [Step 7 — The form template](#step-7--the-form-template)
8. [Step 8 — The delete template](#step-8--the-delete-template)
9. [Step 9 — The detail template](#step-9--the-detail-template)

---

## 01 · ModelForm

> `ModelForm` — Django automatically generates an HTML form from a Python model.
> One class replaces 50 lines of HTML.

### Without ModelForm vs With ModelForm

```python
# ❌ WITHOUT ModelForm: you describe every field by hand
class NoteFormManual(forms.Form):
    title   = forms.CharField(max_length=200, label='Заголовок')
    content = forms.CharField(widget=forms.Textarea, required=False, label='Текст')
    # + duplication with the model — when models.py changes → you must edit here too

# ✅ WITH ModelForm: one line fields = [...]
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content']
        # Django itself looks at Note.title (CharField(max_length=200))
        # and generates forms.CharField(max_length=200)
        # Synchronization is automatic when the model changes
```

### What ModelForm does automatically

```
Note model                      NoteForm generates
─────────────────────────       ────────────────────────────────────
CharField(max_length=200)   →   forms.CharField(max_length=200)
                                widget=TextInput
                                → <input type="text" maxlength="200">

TextField(blank=True)       →   forms.CharField(required=False)
                                widget=Textarea
                                → <textarea rows="10"></textarea>

SmallIntegerField(choices)  →   forms.TypedChoiceField(choices=...)
                                widget=Select
                                → <select><option>...</option></select>

BooleanField(default=False) →   forms.BooleanField(required=False)
                                widget=CheckboxInput
                                → <input type="checkbox">

ForeignKey(Notebook)        →   forms.ModelChoiceField(
                                    queryset=Notebook.objects.all())
                                widget=Select
                                → <select> with all notebooks

ManyToManyField(Tag)        →   forms.ModelMultipleChoiceField(
                                    queryset=Tag.objects.all())
                                widget=SelectMultiple
```

### The form cycle: GET → POST → redirect

```python
def note_create(request):

    # GET request → show an empty form
    if request.method == 'POST':
        # POST request → a filled-in form

        form = NoteForm(request.POST)
        # ↑ request.POST: QueryDict {'title': ['Нотатка'], 'content': ['']}
        # NoteForm is bound to the data → bound form

        if form.is_valid():
            # is_valid() does:
            # 1. Converts strings from request.POST into Python types
            # 2. Runs the validators of each field
            # 3. Runs clean_<field>() if present
            # 4. Runs form.clean() (cross-field validation)
            # If there are errors → is_valid() = False → form.errors is filled

            note = form.save()
            # form.save() = form.instance.save()
            # Executes INSERT INTO hello_app_note (...) VALUES (...)
            # Returns the saved object

            return redirect('hello_app:note_list')
    else:
        form = NoteForm()
        # ↑ Unbound form — empty

    return render(request, 'hello_app/note_form.html', {'form': form})
    # If is_valid() = False → we return THE SAME form with errors
    # form.errors: {'title': ['Це поле обов\'язкове.']}
    # The template shows errors under each field
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
# The NoteForm form does not include the user field (protection against IDOR)
# So the view adds user = request.user manually before saving
```

### A form with instance — editing

```python
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)

    # instance= passes an existing object into the form:
    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        # ↑ Bound form + existing object
        # form.save() → UPDATE instead of INSERT
    else:
        form = NoteForm(instance=note)
        # ↑ The form is filled with the current data of note

    # Without instance: form.save() always does INSERT (duplicate!)
    # With instance: form.save() → UPDATE hello_app_note SET ... WHERE id=note.id
```

---

## 02 · The PRG pattern

> **POST/Redirect/Get** — the standard for handling forms. Protects against duplicates on F5.

### The problem without PRG

```
User → POST /notes/new/ (create the note "Shopping")
  ↓ The view saves the note, returns 200 with a confirmation
  ↓ The browser shows the page
  ↓ The user presses F5 (refresh)
  ↓ The browser REPEATS the POST request ← PROBLEM!
  ↓ A second "Shopping" note is created!

Result: 2 identical notes.
Press F5 again → 3 notes. This is the "Double Submit" problem.
```

### The solution — PRG

```
User → POST /notes/new/
  ↓ The view saves the note
  ↓ The view returns 302 REDIRECT → /notes/
  ↓ The browser does GET /notes/ (follows the redirect automatically)
  ↓ The browser shows the list of notes
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

# ❌ Wrong — without redirect:
def note_create_bad(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return render(request, 'success.html', {'note': note})
            # ↑ The browser stays on the POST URL
            # F5 → browser: "Resubmit the POST request?" → duplicate!
```

---

## 03 · Django Messages

> Flash messages are one-time messages that disappear after a single view.
> Ideal for "Note saved" after a redirect.

### How Messages work

```
1. POST /notes/new/
   messages.success(request, "Нотатку збережено!")
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
# Django levels → Bootstrap Alert classes
from django.contrib import messages

messages.debug(request, 'Налагоджувальне повідомлення')
messages.info(request, 'Інформаційне повідомлення')
messages.success(request, 'Нотатку успішно збережено!')
messages.warning(request, 'Нотатку видалено.')
messages.error(request, 'Помилка при збереженні.')

# MESSAGE_TAGS in settings.py:
from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',   # → alert-secondary
    messages.INFO:    'info',        # → alert-info
    messages.SUCCESS: 'success',     # → alert-success
    messages.WARNING: 'warning',     # → alert-warning
    messages.ERROR:   'danger',      # → alert-danger (Bootstrap uses danger!)
}
```

### Messages in the template

```html
{% if messages %}
    {% for message in messages %}
    <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
        <!--
            message.tags → 'success' / 'warning' / 'danger'
            alert-{{ message.tags }} → Bootstrap class alert-success / alert-warning...
        -->
        {{ message }}
        <button type="button" class="btn-close" data-bs-dismiss="alert">
        </button>
        <!-- data-bs-dismiss="alert": Bootstrap JS closes the alert -->
    </div>
    {% endfor %}
{% endif %}
```

---

## 04 · Template Inheritance

> A single `base.html` contains the Bootstrap CDN, Navbar and Footer.
> All other pages only fill in blocks.

### How the Django template engine processes templates

```
1. render(request, 'hello_app/note_list.html', context)

2. Django finds the template:
   APP_DIRS=True → looks in hello_app/templates/hello_app/note_list.html
   (APP_DIRS looks for templates/ in every INSTALLED_APP)

3. Encounters {% extends 'base.html' %}
   → loads base.html
   → finds all {% block name %}...{% endblock %} in base.html

4. For each block:
   → if the child template overrides it → uses the child content
   → if not → uses the base content (if any)

5. {{ variable }} → replaced with the context value
   {% tag %} → executes the template tag
   {{ var|filter }} → applies the filter
```

### base.html blocks and their purpose

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <!-- The Bootstrap CDN is ALWAYS here -->
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>
    <!--
        block title: the child template overrides it:
        {% block title %}Мої нотатки{% endblock %}
        → <title>Мої нотатки</title>
    -->
    <link rel="stylesheet" href="...bootstrap.min.css">
    {% block extra_css %}{% endblock %}
    <!--
        extra_css: an empty block — a child can add page-specific CSS
        For example: <link rel="stylesheet" href="{% static 'css/editor.css' %}">
    -->
</head>
<body>
    <nav>...</nav>

    <main>
        {% block content %}{% endblock %}
        <!--
            content: the MAIN block — each page fills in its own
            base.html defines nothing here → empty by default
        -->
    </main>

    <footer>...</footer>
    <script src="...bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
    <!--
        extra_js: a child can add page-specific JS
        for example: <script>...</script> for a Leaflet map, Chart.js, etc.
    -->
</body>
</html>
```

### {{ block.super }} — inheriting block content

```html
{# Base template #}
{% block extra_css %}
<link rel="stylesheet" href="global-styles.css">
{% endblock %}

{# Child template #}
{% block extra_css %}
    {{ block.super }}  {# ← inserts the content from base.html #}
    <link rel="stylesheet" href="page-specific.css">
{% endblock %}

{# Result: BOTH CSS lines, not only page-specific #}
```

---

## 05 · Bootstrap 5

> Bootstrap 5 is a CSS framework. Classes → ready-made styles without writing CSS.

### Bootstrap Grid System

```
Bootstrap Grid = 12 columns in a row
Total width of columns = 12 (or less)

col-md-4 + col-md-4 + col-md-4 = 12 ✓  (3 equal columns)
col-md-6 + col-md-6 = 12 ✓              (2 equal halves)
col-md-8 + col-md-4 = 12 ✓              (sidebar layout)
col-md-12 = 12 ✓                         (full width)

Breakpoints:
  no suffix → always (from 0px)
  sm  → ≥576px   (larger phone)
  md  → ≥768px   (tablet)
  lg  → ≥992px   (laptop)
  xl  → ≥1200px  (monitor)
  xxl → ≥1400px  (large monitor)
```

```html
<!-- Card Grid — responsive: 1 column → 2 → 3 -->
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    <!--
        row-cols-1:    mobile      → 1 card per row
        row-cols-md-2: tablet      → 2 cards per row
        row-cols-lg-3: laptop/PC   → 3 cards per row
        g-4:           gap (spacing between cards) = 1.5rem
    -->
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <!-- h-100: height = 100% of the row (equal cards) -->
            <!-- shadow-sm: a light shadow -->
            <div class="card-body">
                <h5 class="card-title">{{ note.title }}</h5>
                <p class="card-text text-muted">{{ note.content|truncatechars:80 }}</p>
            </div>
            <div class="card-footer">
                <!-- Actions: edit / delete -->
            </div>
        </div>
    </div>
    {% endfor %}
</div>
```

### Common Bootstrap classes

```
Spacing:
  m-{n}   → margin all sides    mt-3 → margin-top: 1rem
  p-{n}   → padding all sides   px-4 → padding-left+right: 1.5rem
  mb-4    → margin-bottom: 1.5rem
  gap-2   → gap between flex elements

Flex:
  d-flex                  → display: flex
  justify-content-between → space-between
  align-items-center      → vertically center
  flex-grow-1             → takes up all free space

Text:
  text-muted   → gray color
  text-center  → text-align: center
  fw-bold      → font-weight: bold
  small        → font-size: 0.875em
  display-1    → large heading

Color:
  bg-dark   → background: dark
  text-white → color: white
  bg-primary → Bootstrap blue

Buttons:
  btn btn-primary      → blue button
  btn btn-outline-secondary → outlined gray
  btn-sm               → small button
  btn-group btn-group-sm → button group

Alerts:
  alert alert-success    → green
  alert alert-warning    → yellow
  alert alert-danger     → red
  alert-dismissible      → close button
  fade show              → appearance animation

Utilities:
  shadow-sm     → shadow
  border-0      → no border
  rounded       → rounded corners
  h-100         → height: 100%
  min-vh-100    → min-height: 100vh
  overflow-auto → overflow: auto
```

### Sticky Footer — a technical detail

```
Problem: with little content the footer moves up and does not stay at the bottom.

Solution with Flexbox:
  body {
    display: flex;         → body = flex container
    flex-direction: column → vertical axis
    min-height: 100vh;     → at least 100% of the window height
  }
  main {
    flex-grow: 1;          → main takes up all free space between nav and footer
  }
```

```html
<body class="d-flex flex-column min-vh-100">
    <nav>...</nav>
    <main class="container my-4 flex-grow-1">...</main>
    <footer>...</footer>  ← always at the bottom!
</body>
```

---

## 06 · Template Filters and Tags

### Filters — transform values

```html
{# Syntax: {{ variable|filter:argument }} #}

{{ note.title }}                      → "Дуже довга назва нотатки..."
{{ note.title|truncatechars:30 }}     → "Дуже довга назва нотатк..."

{{ note.content|truncatechars:100 }}  → the first 100 characters
{{ note.content|linebreaks }}         → \n → <br><p>
{{ note.content|safe }}               → do not escape HTML (CAREFUL: XSS)
{{ note.content|escape }}             → escape HTML (default)

{{ note.created_at }}                 → 2026-06-13 10:00:00
{{ note.created_at|date:"d.m.Y" }}   → 13.06.2026
{{ note.created_at|date:"H:i" }}      → 10:00
{{ note.created_at|timesince }}       → 5 hours ago
{{ note.created_at|naturalday }}      → today / yesterday

{{ notes|length }}                    → 42
{{ notes|first }}                     → the first element
{{ notes|last }}                      → the last element

{{ note.title|upper }}                → UPPERCASE TITLE
{{ note.title|lower }}                → lowercase title
{{ note.title|capfirst }}             → First letter capitalized

{{ note.priority|default:"не вказано" }}  → if None/False → the default
{{ note.priority|default_if_none:"—" }}   → only if None

{% load static %}
{% static 'css/style.css' %}          → /static/css/style.css
```

### Tags — logic in the template

```html
{# Conditions #}
{% if notes %}
    ...
{% elif archived_notes %}
    ...
{% else %}
    <p>Немає нотаток</p>
{% endif %}

{% if note.priority == 3 %}
    <span class="badge bg-danger">Високий</span>
{% elif note.priority == 2 %}
    <span class="badge bg-warning">Середній</span>
{% else %}
    <span class="badge bg-secondary">Низький</span>
{% endif %}

{# Loops #}
{% for note in notes %}
    {{ forloop.counter }}       ← 1, 2, 3... (from 1)
    {{ forloop.counter0 }}      ← 0, 1, 2... (from 0)
    {{ forloop.revcounter }}    ← N, N-1... (reverse)
    {{ forloop.first }}         ← True only in the first iteration
    {{ forloop.last }}          ← True only in the last iteration
    {{ note.title }}
{% empty %}
    <p>Список порожній</p>  ← if notes = [] or None
{% endfor %}

{# Blocks — Template Inheritance #}
{% extends 'base.html' %}
{% block content %}...{% endblock %}
{% block title %}Мої нотатки{% endblock %}

{# Including a sub-template #}
{% include 'hello_app/_note_card.html' with note=note %}

{# URL generation #}
{% url 'hello_app:note_detail' pk=note.pk %}

{# CSRF token (required in every POST form) #}
{% csrf_token %}
```

---

## Step 1 — Bootstrap dependencies

```bash
pip install django-bootstrap5
```

Register it in `hello_project/settings.py`:

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

# Django Messages → Bootstrap Alert classes
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
    ├── base.html           ← Here (available to all apps)
    └── hello_app/
        ├── note_list.html
        └── note_form.html
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
    Sticky Footer — body = flex column, main takes the free space
    body.d-flex.flex-column.min-vh-100 + main.flex-grow-1 → footer always at the bottom
-->
<body class="bg-light d-flex flex-column min-vh-100">

    <!-- ═══════════════ NAVBAR ═══════════════ -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Hamburger for mobile -->
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse" data-bs-target="#navMenu">
                <span class="navbar-toggler-icon"></span>
            </button>

            <div class="collapse navbar-collapse" id="navMenu">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_list' %}">
                            <i class="bi bi-list-ul me-1"></i>Всі нотатки
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_create' %}">
                            <i class="bi bi-plus-circle me-1"></i>Нова нотатка
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
                        aria-label="Закрити"></button>
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

## Step 3 — NoteForm

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
        # We do NOT include: created_at (auto_now_add), updated_at (auto_now)
        # Django sets them automatically — the user should not see them

        widgets = {
            'title': forms.TextInput(attrs={
                'class':       'form-control',     # Bootstrap class
                'placeholder': 'Введіть назву...',
                'autofocus':   True,               # Cursor goes straight to this field
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows':  6,
                'placeholder': 'Текст нотатки...',
            }),
        }
        labels = {
            'title':   'Заголовок',
            'content': 'Зміст',
        }
        help_texts = {
            'title':   'Коротка і описова назва (до 200 символів)',
            'content': 'Основний вміст нотатки. Поле необов\'язкове.',
        }

    def clean_title(self):
        """
        A custom validator for the title field.
        clean_<field_name>() is called after the standard validators.
        """
        title = self.cleaned_data.get('title', '').strip()
        if len(title) < 3:
            raise forms.ValidationError('Заголовок має бути мінімум 3 символи.')
        return title   # ← IMPORTANT: return the cleaned value!
```

### Rendering the form in a template (3 ways)

```html
{# Way 1 — as_p (fast, without Bootstrap) #}
{{ form.as_p }}
{# Generates: <p><label>...</label><input class="..."></p> #}

{# Way 2 — django-bootstrap5 #}
{% load django_bootstrap5 %}
{% bootstrap_form form %}
{# Generates: <div class="mb-3"><label class="form-label">...</label><input class="form-control">... #}

{# Way 3 — by hand (full control) #}
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

{# Non-field errors (from clean()) #}
{% if form.non_field_errors %}
<div class="alert alert-danger">
    {% for error in form.non_field_errors %}
    <p class="mb-0">{{ error }}</p>
    {% endfor %}
</div>
{% endif %}
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
            messages.success(request, f'Нотатку "{note.title}" успішно створено!')
            return redirect('hello_app:note_list')
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'action': 'Створити',
        'title':  'Нова нотатка',
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
            messages.success(request, f'Нотатку "{note.title}" оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)   # Fill with the current data

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'note':   note,
        'action': 'Зберегти зміни',
        'title':  f'Редагувати: {note.title}',
    })


def note_delete(request, pk):
    """
    GET  → confirmation page
    POST → deletion → redirect (DELETE only via POST!)

    Why only POST?
    If DELETE worked via GET: <img src="/notes/1/delete/"> or <a href=...>
    would delete the note when the page loads (CSRF attack, search bots).
    POST requires a form with csrf_token → protected.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title   # Save before deleting
        note.delete()
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### get_object_or_404 — protection against KeyError / DoesNotExist

```python
# ❌ Without get_object_or_404:
note = Note.objects.get(pk=pk)   # If not found → DoesNotExist → 500 Internal Error

# ✅ With get_object_or_404:
note = get_object_or_404(Note, pk=pk)   # If not found → Http404 → 404 page

# You can filter by several fields:
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 if the note either does not exist or belongs to another user
# This is protection against IDOR (Insecure Direct Object Reference)!
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

**Important: the order `notes/new/` before `notes/<int:pk>/`**

```
'notes/new/' → does not match <int:pk> because 'new' is not an int → OK
'notes/42/'  → <int:pk> → pk=42 → OK

If the order were reversed:
'notes/<int:pk>/' → 'new' → int('new') → ValueError → error!
Django checks urlpatterns FROM TOP TO BOTTOM → the first match wins.
More specific patterns — at the top!
```

`hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
]
```

---

## Step 6 — The list template

`hello_app/templates/hello_app/note_list.html`:

```html
{% extends 'base.html' %}

{% block title %}Мої нотатки{% endblock %}

{% block content %}

<!-- Heading with a counter and a button -->
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h2 mb-0">
        Мої нотатки
        <span class="badge bg-secondary fs-6">{{ notes|length }}</span>
    </h1>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>Нова нотатка
    </a>
</div>

{% if notes %}
    <!--
        Responsive grid:
        - Mobile: 1 column
        - Tablet (md): 2 columns
        - Laptop (lg): 3 columns
        g-4: spacing between cards
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
        {% for note in notes %}
        <div class="col">
            <div class="card h-100 shadow-sm hover-lift">

                <div class="card-body">
                    <h5 class="card-title mb-1">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark stretched-link">
                            {{ note.title }}
                        </a>
                    </h5>
                    <!--
                        stretched-link: the whole .card becomes clickable
                        (position:relative on the card + ::after on the link)
                    -->

                    <p class="card-text text-muted small mt-2">
                        {{ note.content|truncatechars:120 }}
                        <!--
                            truncatechars:120 → truncates to 120 characters
                            and adds "..." if longer
                        -->
                    </p>
                </div>

                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} тому
                    </small>
                    <!--
                        timesince: "2 hours", "5 days", "1 month"
                        Relative time — always up to date without refreshing
                    -->

                    <div class="btn-group btn-group-sm position-relative z-1">
                        <!-- z-1: above the stretched-link → buttons are clickable -->
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary"
                           title="Редагувати">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger"
                           title="Видалити">
                            <i class="bi bi-trash"></i>
                        </a>
                    </div>
                </div>

            </div>
        </div>
        {% endfor %}
    </div>

{% else %}
    <!-- Empty state — when there are no notes -->
    <div class="text-center py-5">
        <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>
        <h4 class="text-muted">Ще немає нотаток</h4>
        <p class="text-muted">Створи першу нотатку і вона з'явиться тут.</p>
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>Створити першу нотатку
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
                        novalidate: disables browser HTML5 validation
                        → Django validates on the server (more reliable)
                        → Browser validation can be bypassed with curl/Postman
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
                            <span class="text-danger" title="Обов'язкове поле">*</span>
                            {% endif %}
                        </label>
                        {{ field }}
                        {#
                            field.widget already has class="form-control" (from the widgets in forms.py)
                            → {{ field }} generates <input class="form-control"> or <textarea ...>
                        #}

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
                            <i class="bi bi-x-lg me-1"></i>Скасувати
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

{% block title %}Видалити: {{ note.title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-6 col-lg-5">
        <div class="card border-danger shadow-sm">

            <div class="card-header bg-danger text-white">
                <h1 class="h4 mb-0">
                    <i class="bi bi-exclamation-triangle me-2"></i>Видалити нотатку
                </h1>
            </div>

            <div class="card-body">
                <p class="mb-1">
                    Ви дійсно хочете видалити нотатку
                    <strong>«{{ note.title }}»</strong>?
                </p>
                <p class="text-muted small mb-3">Ця дія незворотна.</p>

                <form method="post">
                    <!--
                        DELETE via POST (not GET):
                        If GET: <img src="/notes/1/delete/"> would delete the note on page load
                        POST + csrf_token: protection against CSRF/accidental deletion
                    -->
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-danger">
                            <i class="bi bi-trash me-1"></i>Так, видалити
                        </button>
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary">
                            Скасувати
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
                    <a href="{% url 'hello_app:note_list' %}">Нотатки</a>
                </li>
                <li class="breadcrumb-item active">{{ note.title|truncatechars:40 }}</li>
            </ol>
        </nav>
        <h1 class="h2">{{ note.title }}</h1>
        <small class="text-muted">
            <i class="bi bi-calendar me-1"></i>
            Створено: {{ note.created_at|date:"d.m.Y о H:i" }}
            {% if note.updated_at != note.created_at %}
            · Оновлено: {{ note.updated_at|timesince }} тому
            {% endif %}
        </small>
    </div>

    <div class="btn-group">
        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
           class="btn btn-outline-primary">
            <i class="bi bi-pencil me-1"></i>Редагувати
        </a>
        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
           class="btn btn-outline-danger">
            <i class="bi bi-trash me-1"></i>Видалити
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
            <p class="text-muted fst-italic">Нотатка без вмісту.</p>
        {% endif %}
    </div>
</div>

{% endblock %}
```

---

## How it all connects — the full cycle

```
CRUD operations and HTTP methods:
─────────────────────────────────────────────────────────────────────────
CREATE:  GET  /notes/new/     → note_create view → empty form
         POST /notes/new/     → form.save() → redirect → flash message
         GET  /notes/         → list with the new note + flash message

READ:    GET  /notes/         → note_list view → QuerySet → template
         GET  /notes/42/      → note_detail view → get_object_or_404 → template

UPDATE:  GET  /notes/42/edit/ → note_edit view → form with instance=note
         POST /notes/42/edit/ → form.save(instance) → UPDATE → redirect

DELETE:  GET  /notes/42/delete/  → note_delete view → confirmation
         POST /notes/42/delete/  → note.delete() → redirect → flash message
─────────────────────────────────────────────────────────────────────────
```

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `NoReverseMatch: 'note_list'` | Namespace not specified | `{% url 'hello_app:note_list' %}` |
| `403 Forbidden` on POST | `{% csrf_token %}` is missing | Add it inside `<form>` |
| `TemplateSyntaxError: Invalid block tag 'url'` | Error in the URL tag | Check the name and namespace |
| The form does not validate but shows no errors | `novalidate` without server validation | Check `form.errors` in the view with `print(form.errors)` |
| Duplicate after F5 | No redirect after POST | PRG: always `return redirect(...)` after `form.save()` |
| Buttons not clickable because of stretched-link | z-index | Add `position-relative z-1` on the btn-group |
| `TemplateDoesNotExist: base.html` | Wrong path | `APP_DIRS=True` + `templates/base.html` in an installed app |

---

## Practical exercise

1. Run the project, open `/notes/` — make sure the page is styled with Bootstrap.
2. Create 3 notes through the `/notes/new/` form. Check the flash messages.
3. Edit one note. Check that it is an `UPDATE` (not a duplicate).
4. Delete a note — make sure the confirmation page is shown.
5. Add a `priority` field (choices: 1=Low, 2=Medium, 3=High) to the model, form and detail page.
6. In `note_list.html` show a Badge with the priority on each card.

---

## Self-check checklist

- [ ] `base.html` → `note_list.html` / `note_form.html`: Template Inheritance via `{% extends %}`
- [ ] Bootstrap CSS is included via CDN in `base.html`
- [ ] Flash messages are shown after POST and disappear after F5
- [ ] `{% csrf_token %}` is present in every POST form
- [ ] `redirect()` after `form.save()` (PRG pattern)
- [ ] `get_object_or_404` instead of `objects.get()` — 404 rather than 500
- [ ] Sticky Footer: `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1`
- [ ] The Card Grid is responsive: 1/2/3 columns depending on screen width

---

## Next

Next step: [03 — Domain Design and architecture](03_crud.md) — domain-driven design, the N+1 problem, the selectors/services layers.

Documentation modules:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
