# Bootstrap Advanced

> Цей розділ охоплює матеріал з `django_bootstrap_project` — практичного проєкту де Bootstrap підключається через CDN, налаштовується Unfold Admin і Debug Toolbar.

---

## Фаза Б — Підключення Bootstrap 5

### Крок Б1 — Оновлення settings.py

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_bootstrap5',         # ← ДОДАЙ (Bootstrap 5 для форм)
    'debug_toolbar',             # ← ДОДАЙ (SQL debugger)
    'hello_app',
]

MIDDLEWARE = [
    'debug_toolbar.middleware.DebugToolbarMiddleware',  # ← ДОДАЙ ПЕРШИМ
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# В кінці файлу додай:
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

> **Що таке `MESSAGE_TAGS`?**
> Django Messages (флеш-повідомлення після POST) мають свої рівні: `success`, `error`, тощо.
> Bootstrap Alert використовує `alert-success`, `alert-danger`.
> `MESSAGE_TAGS` робить маппінг між ними.

### Крок Б2 — Оновлення urls.py

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

## Фаза В — `base.html` повний код

Django шукає шаблони в `<app>/templates/`.
Створимо `base.html` **за межами** `hello_app/templates/hello_app/` —
в `hello_app/templates/` напряму, щоб він був доступний глобально.

### Структура папок шаблонів

```
hello_app/templates/
├── base.html                    ← НОВИЙ — Bootstrap shell для всіх сторінок
└── hello_app/
    ├── note_list.html           ← вже є — будемо переписувати
    ├── note_detail.html         ← НОВИЙ
    ├── note_form.html           ← НОВИЙ
    └── note_confirm_delete.html ← НОВИЙ
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
        Bootstrap 5 CSS — підключаємо в <head>.
        Чому: браузер читає CSS перед рендерингом тіла сторінки.
        Якщо підключити в кінці — буде "flash of unstyled content".
    -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
          crossorigin="anonymous">

    <!-- Bootstrap Icons — окрема бібліотека іконок -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    <!-- Слот для додаткового CSS на конкретних сторінках -->
    {% block extra_css %}{% endblock %}
</head>
<body class="bg-light d-flex flex-column min-vh-100">
<!--
    Sticky Footer — три Bootstrap класи вирішують проблему «підвисання» футера.
    d-flex flex-column — body стає вертикальним flex-контейнером.
    min-vh-100 — body завжди займає мінімум 100% висоти вікна.
    flex-grow-1 на <main> нижче — main забирає весь вільний простір між nav і footer.
-->

    <!--
        NAVBAR — компонент навігації Bootstrap.
        navbar-expand-lg: на великих екранах горизонтальний, на малих — гамбургер.
    -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">

            <!-- Brand — назва сайту / логотип -->
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Кнопка гамбургер для мобільних (xs/sm/md) -->
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse"
                    data-bs-target="#navbarNav"
                    aria-controls="navbarNav"
                    aria-expanded="false"
                    aria-label="Відкрити меню">
                <span class="navbar-toggler-icon"></span>
            </button>

            <!-- Навігаційні посилання (ховаються на мобільних) -->
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

    <!-- Основний вміст — flex-grow-1 розтягує main між navbar і footer -->
    <main class="container my-4 flex-grow-1">

        <!--
            Django Messages → Bootstrap Alerts.
            messages — Context Processor що автоматично доступний у всіх шаблонах.
            message.tags → 'success'/'danger'/'warning' (маппінг з MESSAGE_TAGS у settings.py).
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
        Bootstrap JS Bundle (включає Popper.js).
        defer — завантажується після HTML.
        Навіщо: Modal, Navbar collapse, Toast потребують JS.
    -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmAgD0SnMiKKmFClVgaFa11iGj0E"
            crossorigin="anonymous" defer></script>

    <!-- Слот для JS конкретних сторінок -->
    {% block extra_js %}{% endblock %}

</body>
</html>
```

### Sticky Footer (футер завжди внизу)

**Проблема:** якщо на сторінці мало контенту (наприклад, 1–2 нотатки або порожній список),
футер «зависає» посередині сторінки, а нижче нього — порожній фон.

**Рішення — Sticky Footer через Bootstrap Flexbox:**

```html
<!-- БУЛО: -->
<body class="bg-light">
    ...
    <main class="container my-4">

<!-- СТАЛО: -->
<body class="bg-light d-flex flex-column min-vh-100">
    ...
    <main class="container my-4 flex-grow-1">
```

| Клас | Де | Що робить |
|------|----|-----------|
| `d-flex` | `<body>` | Перетворює body на flex-контейнер |
| `flex-column` | `<body>` | Flex-напрямок: вертикально (navbar → main → footer) |
| `min-vh-100` | `<body>` | Body займає мінімум 100% висоти вікна (`100vh`) |
| `flex-grow-1` | `<main>` | Main розтягується на весь вільний простір між navbar і footer |

**Візуальна схема:**

```
┌────────────────────── body (min-vh-100) ──────────────────────┐
│  <nav>        — фіксована висота                              │
│  <main>       — flex-grow-1: займає все що залишилось  ↕↕↕   │
│  <footer>     — фіксована висота, завжди внизу                │
└───────────────────────────────────────────────────────────────┘
```

---

## Фаза Г — Список нотаток з Bootstrap Cards

### `hello_app/templates/hello_app/note_list.html`

```html
{% extends 'hello_app/base.html' %}
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
        row-cols-1 — одна колонка на малих екранах;
        row-cols-md-2 — дві колонки на середніх екранах;
        row-cols-lg-3 — три колонки на великих екранах;
        g-4 — відступи між картками.
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">

        {% for note in notes %}
        <div class="col">

            <!--
                Card — компонент Bootstrap для окремої нотатки.
                h-100 робить картки однакової висоти в межах рядка.
                shadow-sm додає легку тінь.
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

## Фаза Д — Форма нотатки з Bootstrap

### `hello_app/forms.py`

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm — автоматично генерує поля форми з моделі Note.
    Django бере field types з моделі і генерує відповідні HTML inputs.
    CharField(max_length=200) → <input type="text" maxlength="200">
    TextField → <textarea>
    """

    class Meta:
        model = Note
        fields = ['title', 'content']  # які поля включати у форму
        widgets = {
            # Додаємо Bootstrap class='form-control' до кожного поля
            # Без цього Django рендерить bare HTML без Bootstrap стилів
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
from .forms import NoteForm           # ← наша форма


def index(request):
    """Редирект з / на /notes/."""
    return redirect('hello_app:note_list')


def note_list(request):
    """Список всіх нотаток."""
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    """
    Деталь нотатки.
    get_object_or_404: якщо note з цим pk не існує → повертає 404 (не 500).
    """
    note = get_object_or_404(Note, pk=pk)
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    PRG (Post/Redirect/Get) паттерн:
    GET  → показати порожню форму
    POST → обробити, зберегти → redirect на список (щоб F5 не дублював)
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
    """Редагування нотатки — та сама PRG, але форма ініціалізована instance=note."""
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Нотатку "{note.title}" оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)  # instance заповнює форму поточними даними

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'note': note,
        'action': 'Зберегти зміни',
        'title': f'Редагувати: {note.title}',
    })


def note_delete(request, pk):
    """
    Видалення через POST (не GET!).
    GET → сторінка підтвердження.
    POST → видалити → redirect.
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

> **Що таке `<int:pk>`?**
> Path converter — захоплює ціле число з URL і передає у view як аргумент `pk`.
> `/notes/42/` → `pk=42` → `Note.objects.get(pk=42)`.

---

## Фаза Е — Шаблони detail, form, confirm_delete

### `note_detail.html`

```html
{% extends 'hello_app/base.html' %}

{% block title %}{{ note.title }} — Bootstrap Notes{% endblock %}

{% block content %}

<!-- Breadcrumb — навігаційні хлібні крихти -->
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
                linebreaks — конвертує \n у <p> теги.
                Без нього весь текст буде в один рядок.
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
                    {% csrf_token %} — ОБОВ'ЯЗКОВО в кожній POST формі!
                    Без нього Django поверне 403 Forbidden.
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

> **Варіант 2 — автоматичний рендеринг через `django-bootstrap5`:**
>
> Замість ручного циклу `{% for field in form %}` можна написати одним рядком:
> ```html
> {% load django_bootstrap5 %}
> {% bootstrap_form form %}
> ```
> Пакет `django-bootstrap5` автоматично додає всі Bootstrap класи, label, помилки.

### `note_confirm_delete.html`

```html
{% extends 'hello_app/base.html' %}

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
                    Видалення через POST — ніколи не через GET.
                    GET може бути виконаний автоматично (prefetch, боти).
                    POST вимагає навмисної дії користувача + CSRF захист.
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

## Фаза Ж — Unfold Admin

> **Що таке django-unfold?**
> Бібліотека, що замінює стандартний Django Admin на Tailwind-CSS-стилізований інтерфейс.
> Не потребує змін у логіці — тільки змінює успадкування та додає `UNFOLD` словник у `settings.py`.

### Крок Ж1 — Оновлення `hello_project/settings.py`

Додай `UNFOLD` словник після `MESSAGE_TAGS`:

```python
from django.urls import reverse_lazy
from django.utils.translation import gettext_lazy as _

UNFOLD = {
    "SITE_TITLE": "Bootstrap Notes",       # заголовок у <title>
    "SITE_HEADER": "Bootstrap Notes",      # великий заголовок у сайдбарі
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

> **`icon`** — назва іконки з [Google Material Symbols](https://fonts.google.com/icons).
> Пиши назву в lowercase через underscore: `description`, `people`, `add_circle`.

### Крок Ж2 — Оновлення `hello_app/admin.py`

```python
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.models import User, Group
from django.utils.html import format_html

# unfold.admin.ModelAdmin замінює django.contrib.admin.ModelAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import Note


# Django реєструє User і Group без Unfold — знімаємо і додаємо знову
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

> **Ключова різниця від стандартного Django Admin:**
>
> | До (Django Admin) | Після (Unfold Admin) |
> |---|---|
> | `class NoteAdmin(admin.ModelAdmin)` | `class NoteAdmin(ModelAdmin)` |
> | Немає User/Group re-registration | `unregister` + `register` з Unfold формами |
> | Брендинг: `admin.site.site_header = ...` | Брендинг: `UNFOLD["SITE_HEADER"]` у settings.py |
> | Немає сайдбар-навігації | `UNFOLD["SIDEBAR"]["navigation"]` |

---

## Фаза З — Django Debug Toolbar

Toolbar вже підключений (ми додали в Settings і URLs).
Зайди на **http://localhost:8000/notes/** — справа з'явиться чорна панель DJDT.

**Що досліджувати:**

| Панель | Що шукати |
|--------|-----------|
| **SQL** | Скільки запитів для /notes/? Має бути 1–2 |
| **Templates** | Які шаблони використовувались (base.html + note_list.html) |
| **Headers** | Request/Response заголовки |
| **Time** | Час рендерингу шаблону |

> **Якщо toolbar не з'являється:**
> 1. `DEBUG = True` у settings.py?
> 2. `INTERNAL_IPS = ['127.0.0.1']` є у settings.py?
> 3. `'debug_toolbar'` в `INSTALLED_APPS`?
> 4. `debug_toolbar_urls()` в urls.py?
> 5. Сторінка має тег `<body>`? (Потрібен для вставки панелі)

---

## Часті помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` не там де Django шукає | Файл має бути в `hello_app/templates/base.html` (не в `hello_app/templates/hello_app/`) |
| `NoReverseMatch: 'note_create'` | URL name не зареєстровано або не той namespace | Перевір `hello_app/urls.py` і `app_name = 'hello_app'` |
| `403 Forbidden` після POST | Відсутній `{% csrf_token %}` у формі | Додай `{% csrf_token %}` всередину `<form>` |
| Bootstrap стилі не застосовуються | `class='form-control'` не додано до widget | Перевір `NoteForm.Meta.widgets` у `forms.py` |
| Debug Toolbar не з'являється | Не виконано всі умови | Перевір чеклист у Фазі З |
| `IntegrityError` при збереженні | `title` не може бути порожнім | Перевір валідацію форми: `form.is_valid()` |
| `ImproperlyConfigured: namespace` | `app_name` відсутній у `urls.py` | Додай `app_name = 'hello_app'` |
| Cards різної висоти | Немає `h-100` на `.card` | Додай клас `h-100` до `<div class="card">` |
| Футер посередині сторінки | `<body>` має висоту контенту, а не вікна | Додай `d-flex flex-column min-vh-100` на `<body>` і `flex-grow-1` на `<main>` |

---

## Навігація

- Попередня: [Components](components.md)
- Наступна: [Checkpoint](checkpoint.md)
