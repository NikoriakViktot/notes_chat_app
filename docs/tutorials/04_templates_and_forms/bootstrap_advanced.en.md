# Bootstrap Advanced

> This section covers material from `django_bootstrap_project` — a practical project where Bootstrap is included via a CDN, and Unfold Admin and the Debug Toolbar are configured.

---

## Phase B — Adding Bootstrap 5

### Step B1 — Updating settings.py

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
    'debug_toolbar.middleware.DebugToolbarMiddleware',  # ← ADD IT FIRST
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# At the end of the file, add:
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
> Django Messages (flash messages after a POST) have their own levels: `success`, `error`, and so on.
> Bootstrap Alert uses `alert-success`, `alert-danger`.
> `MESSAGE_TAGS` maps one to the other.

### Step B2 — Updating urls.py

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

## Phase C — The full `base.html` code

Django looks for templates in `<app>/templates/`.
Let's create `base.html` **outside** `hello_app/templates/hello_app/` —
directly in `hello_app/templates/`, so that it is available globally.

### Template folder structure

```
hello_app/templates/
├── base.html                    ← NEW — the Bootstrap shell for all pages
└── hello_app/
    ├── note_list.html           ← already exists — we will rewrite it
    ├── note_detail.html         ← NEW
    ├── note_form.html           ← NEW
    └── note_confirm_delete.html ← NEW
```

### `hello_app/templates/base.html`

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>

    <!--
        Bootstrap 5 CSS — we include it in <head>.
        Why: the browser reads CSS before rendering the page body.
        If you include it at the end, you get a "flash of unstyled content".
    -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
          crossorigin="anonymous">

    <!-- Bootstrap Icons — a separate icon library -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    <!-- A slot for extra CSS on specific pages -->
    {% block extra_css %}{% endblock %}
</head>
<body class="bg-light d-flex flex-column min-vh-100">
<!--
    Sticky Footer — three Bootstrap classes solve the problem of a "floating" footer.
    d-flex flex-column — body becomes a vertical flex container.
    min-vh-100 — body always takes at least 100% of the window height.
    flex-grow-1 on <main> below — main takes all the free space between nav and footer.
-->

    <!--
        NAVBAR — the Bootstrap navigation component.
        navbar-expand-lg: horizontal on large screens, a hamburger on small ones.
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
                    aria-label="Відкрити меню">
                <span class="navbar-toggler-icon"></span>
            </button>

            <!-- Navigation links (hidden on mobile) -->
            <div class="collapse navbar-collapse" id="navbarNav">
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
                <ul class="navbar-nav">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'admin:index' %}">
                            <i class="bi bi-gear me-1"></i>Адмін
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
            message.tags → 'success'/'danger'/'warning' (mapped via MESSAGE_TAGS in settings.py).
        -->
        {% if messages %}
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                <i class="bi bi-{% if message.tags == 'success' %}check-circle{% elif message.tags == 'danger' %}exclamation-triangle{% else %}info-circle{% endif %} me-2"></i>
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"
                        aria-label="Закрити"></button>
            </div>
            {% endfor %}
        {% endif %}

        {% block content %}{% endblock %}

    </main>

    <!-- Footer -->
    <footer class="bg-dark text-center text-white-50 py-3 mt-5">
        <small>Bootstrap Notes &copy; 2026 — навчальний проєкт</small>
    </footer>

    <!--
        Bootstrap JS Bundle (includes Popper.js).
        defer — loaded after the HTML.
        Why: Modal, Navbar collapse, Toast need JS.
    -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmAgD0SnMiKKmFClVgaFa11iGj0E"
            crossorigin="anonymous" defer></script>

    <!-- A slot for page-specific JS -->
    {% block extra_js %}{% endblock %}

</body>
</html>
```

### Sticky Footer (the footer is always at the bottom)

**Problem:** if a page has little content (for example, 1–2 notes or an empty list),
the footer "hangs" in the middle of the page, with empty background below it.

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

| Class | Where | What it does |
|------|----|-----------|
| `d-flex` | `<body>` | Turns body into a flex container |
| `flex-column` | `<body>` | Flex direction: vertical (navbar → main → footer) |
| `min-vh-100` | `<body>` | Body takes at least 100% of the window height (`100vh`) |
| `flex-grow-1` | `<main>` | Main stretches across all the free space between the navbar and the footer |

**Visual diagram:**

```
┌────────────────────── body (min-vh-100) ──────────────────────┐
│  <nav>        — fixed height                                  │
│  <main>       — flex-grow-1: takes everything that is left ↕↕↕│
│  <footer>     — fixed height, always at the bottom            │
└───────────────────────────────────────────────────────────────┘
```

---

## Phase D — The note list with Bootstrap Cards

### `hello_app/templates/hello_app/note_list.html`

```html
{% extends 'base.html' %}
{% load django_bootstrap5 %}

{% block title %}Мої нотатки — Bootstrap Notes{% endblock %}

{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="h2 mb-1">
            <i class="bi bi-journal-text me-2 text-primary"></i>
            Мої нотатки
        </h1>
        <p class="text-muted mb-0">
            {{ notes|length }} нотаток
        </p>
    </div>

    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>
        Нова нотатка
    </a>
</div>

{% if notes %}

    <!--
        Bootstrap Grid:
        row-cols-1 — one column on small screens;
        row-cols-md-2 — two columns on medium screens;
        row-cols-lg-3 — three columns on large screens;
        g-4 — gaps between the cards.
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">

        {% for note in notes %}
        <div class="col">

            <!--
                Card — a Bootstrap component for a single note.
                h-100 makes cards the same height within a row.
                shadow-sm adds a light shadow.
            -->
            <div class="card h-100 shadow-sm">

                <div class="card-body">
                    <h5 class="card-title">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark">
                            {{ note.title }}
                        </a>
                    </h5>

                    {% if note.content %}
                    <p class="card-text text-muted small">
                        {{ note.content|truncatechars:100 }}
                    </p>
                    {% else %}
                    <p class="card-text text-muted small fst-italic">
                        Зміст відсутній.
                    </p>
                    {% endif %}

                </div>

                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} тому
                    </small>

                    <div class="btn-group btn-group-sm">
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

    <div class="text-center py-5">
        <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>
        <h4 class="text-muted">Ще немає нотаток</h4>
        <p class="text-muted">Створіть першу нотатку і вона з'явиться тут.</p>
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>Створити нотатку
        </a>
    </div>

{% endif %}

{% endblock %}
```

---

## Phase E — The note form with Bootstrap

### `hello_app/forms.py`

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm — automatically generates form fields from the Note model.
    Django takes field types from the model and generates the matching HTML inputs.
    CharField(max_length=200) → <input type="text" maxlength="200">
    TextField → <textarea>
    """

    class Meta:
        model = Note
        fields = ['title', 'content']  # which fields to include in the form
        widgets = {
            # Add the Bootstrap class='form-control' to every field
            # Without it, Django renders bare HTML without Bootstrap styles
            'title': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Введіть назву нотатки...',
                'autofocus': True,
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 6,
                'placeholder': 'Текст нотатки...',
            }),
        }
        labels = {
            'title': 'Заголовок',
            'content': 'Зміст',
        }
```

### `hello_app/views.py`

```python
from django.shortcuts import render, redirect, get_object_or_404
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
    """
    note = get_object_or_404(Note, pk=pk)
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    The PRG (Post/Redirect/Get) pattern:
    GET  → show an empty form
    POST → process, save → redirect to the list (so that F5 does not duplicate)
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
        'form': form,
        'action': 'Створити',
        'title': 'Нова нотатка',
    })


def note_edit(request, pk):
    """Editing a note — the same PRG, but the form is initialized with instance=note."""
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Нотатку "{note.title}" оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)  # instance fills the form with the current data

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'note': note,
        'action': 'Зберегти зміни',
        'title': f'Редагувати: {note.title}',
    })


def note_delete(request, pk):
    """
    Deletion via POST (not GET!).
    GET → confirmation page.
    POST → delete → redirect.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title
        note.delete()
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### `hello_app/urls.py`

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
> A path converter — captures an integer from the URL and passes it to the view as the `pk` argument.
> `/notes/42/` → `pk=42` → `Note.objects.get(pk=42)`.

---

## Phase F — The detail, form, and confirm_delete templates

### `note_detail.html`

```html
{% extends 'base.html' %}

{% block title %}{{ note.title }} — Bootstrap Notes{% endblock %}

{% block content %}

<!-- Breadcrumb — navigation breadcrumbs -->
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item">
            <a href="{% url 'hello_app:note_list' %}">Нотатки</a>
        </li>
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
                <i class="bi bi-pencil me-1"></i>Редагувати
            </a>
            <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
               class="btn btn-sm btn-outline-danger">
                <i class="bi bi-trash me-1"></i>Видалити
            </a>
        </div>
    </div>

    <div class="card-body">
        {% if note.content %}
            <!--
                linebreaks — converts \n into <p> tags.
                Without it, all the text would be on a single line.
            -->
            <p class="card-text">{{ note.content|linebreaks }}</p>
        {% else %}
            <p class="text-muted fst-italic">Зміст відсутній.</p>
        {% endif %}
    </div>

    <div class="card-footer text-muted small">
        <i class="bi bi-clock me-1"></i>
        Створено {{ note.created_at|date:"d.m.Y" }} о {{ note.created_at|date:"H:i" }}
        ({{ note.created_at|timesince }} тому)
    </div>
</div>

<a href="{% url 'hello_app:note_list' %}" class="btn btn-link mt-3">
    <i class="bi bi-arrow-left me-1"></i>Назад до списку
</a>

{% endblock %}
```

### `note_form.html`

```html
{% extends 'base.html' %}

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
                    {% csrf_token %} — MANDATORY in every POST form!
                    Without it, Django returns 403 Forbidden.
                    CSRF: Cross-Site Request Forgery protection.
                -->
                <form method="post" novalidate>
                    {% csrf_token %}

                    {% for field in form %}
                    <div class="mb-3">
                        <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
                            {{ field.label }}
                            {% if field.field.required %}
                                <span class="text-danger" title="Обов'язкове поле">*</span>
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

                    <div class="d-flex justify-content-between align-items-center pt-2">
                        <a href="{% if note %}{% url 'hello_app:note_detail' pk=note.pk %}{% else %}{% url 'hello_app:note_list' %}{% endif %}"
                           class="btn btn-outline-secondary">
                            <i class="bi bi-x-lg me-1"></i>Скасувати
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
> The `django-bootstrap5` package automatically adds all the Bootstrap classes, labels, and errors.

### `note_confirm_delete.html`

```html
{% extends 'base.html' %}

{% block title %}Видалити нотатку — Bootstrap Notes{% endblock %}

{% block content %}

<div class="row justify-content-center">
    <div class="col-12 col-md-6">

        <div class="card border-danger shadow-sm">
            <div class="card-header bg-danger text-white">
                <h4 class="mb-0">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Підтвердіть видалення
                </h4>
            </div>
            <div class="card-body">
                <p class="mb-3">
                    Ви справді хочете видалити нотатку
                    <strong>"{{ note.title }}"</strong>?
                </p>
                <p class="text-danger small">
                    <i class="bi bi-info-circle me-1"></i>
                    Цю дію не можна скасувати.
                </p>

                <!--
                    Deletion via POST — never via GET.
                    A GET can be performed automatically (prefetch, bots).
                    A POST requires a deliberate user action + CSRF protection.
                -->
                <form method="post">
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary flex-fill">
                            <i class="bi bi-x-lg me-1"></i>Скасувати
                        </a>
                        <button type="submit" class="btn btn-danger flex-fill">
                            <i class="bi bi-trash me-1"></i>Видалити
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

### Step G1 — Updating `hello_project/settings.py`

Add the `UNFOLD` dictionary after `MESSAGE_TAGS`:

```python
from django.urls import reverse_lazy
from django.utils.translation import gettext_lazy as _

UNFOLD = {
    "SITE_TITLE": "Bootstrap Notes",       # the title in <title>
    "SITE_HEADER": "Bootstrap Notes",      # the large header in the sidebar
    "SITE_SUBHEADER": "Управління нотатками",
    "SHOW_HISTORY": True,
    "SHOW_VIEW_ON_SITE": False,
    "SHOW_BACK_BUTTON": True,
    "SIDEBAR": {
        "show_search": False,
        "show_all_applications": False,
        "navigation": [
            {
                "title": _("Контент"),
                "separator": False,
                "collapsible": False,
                "items": [
                    {
                        "title": _("Нотатки"),
                        "icon": "description",  # Material Symbol icon
                        "link": reverse_lazy("admin:hello_app_note_changelist"),
                    },
                ],
            },
            {
                "title": _("Доступ"),
                "separator": True,
                "collapsible": False,
                "items": [
                    {
                        "title": _("Користувачі"),
                        "icon": "people",
                        "link": reverse_lazy("admin:auth_user_changelist"),
                    },
                    {
                        "title": _("Групи"),
                        "icon": "group",
                        "link": reverse_lazy("admin:auth_group_changelist"),
                    },
                ],
            },
        ],
    },
}
```

> **`icon`** — the icon name from [Google Material Symbols](https://fonts.google.com/icons).
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


# Django registers User and Group without Unfold — unregister them and register them again
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

    @admin.display(description='Зміст (preview)')
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

## Phase H — Django Debug Toolbar

The toolbar is already connected (we added it to Settings and URLs).
Go to **http://localhost:8000/notes/** — a black DJDT panel will appear on the right.

**What to explore:**

| Panel | What to look for |
|--------|-----------|
| **SQL** | How many queries for /notes/? It should be 1–2 |
| **Templates** | Which templates were used (base.html + note_list.html) |
| **Headers** | Request/Response headers |
| **Time** | Template rendering time |

> **If the toolbar does not appear:**
> 1. `DEBUG = True` in settings.py?
> 2. Is `INTERNAL_IPS = ['127.0.0.1']` in settings.py?
> 3. `'debug_toolbar'` in `INSTALLED_APPS`?
> 4. `debug_toolbar_urls()` in urls.py?
> 5. Does the page have a `<body>` tag? (Needed to inject the panel)

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` is not where Django looks for it | The file must be in `hello_app/templates/base.html` (not in `hello_app/templates/hello_app/`) |
| `NoReverseMatch: 'note_create'` | The URL name is not registered, or the namespace is wrong | Check `hello_app/urls.py` and `app_name = 'hello_app'` |
| `403 Forbidden` after a POST | `{% csrf_token %}` is missing from the form | Add `{% csrf_token %}` inside `<form>` |
| Bootstrap styles are not applied | `class='form-control'` was not added to the widget | Check `NoteForm.Meta.widgets` in `forms.py` |
| Debug Toolbar does not appear | Not all conditions are met | Check the checklist in Phase H |
| `IntegrityError` on save | `title` cannot be empty | Check form validation: `form.is_valid()` |
| `ImproperlyConfigured: namespace` | `app_name` is missing from `urls.py` | Add `app_name = 'hello_app'` |
| Cards of different heights | No `h-100` on `.card` | Add the `h-100` class to `<div class="card">` |
| Footer in the middle of the page | `<body>` has the height of its content, not of the window | Add `d-flex flex-column min-vh-100` to `<body>` and `flex-grow-1` to `<main>` |

---

## Navigation

- Previous: [Components](components.md)
- Next: [Checkpoint](checkpoint.md)
