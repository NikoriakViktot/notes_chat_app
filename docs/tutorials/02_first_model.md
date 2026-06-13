# Туторіал 02 — Bootstrap Notes: форми, CRUD і шаблони

**Мета:** додати Bootstrap 5, написати ModelForm, реалізувати повний CRUD для нотаток із PRG-паттерном.

**Результат:**
```
http://localhost:8000/notes/           →  Список нотаток — Bootstrap Cards Grid
http://localhost:8000/notes/new/       →  Форма створення
http://localhost:8000/notes/1/         →  Деталь нотатки
http://localhost:8000/notes/1/edit/    →  Форма редагування
http://localhost:8000/notes/1/delete/  →  Підтвердження видалення
```

**Передумови:** пройдений [Туторіал 01](01_first_django_page.md) — у тебе є `Note` модель і Django-проєкт.

---

## Крок 1 — Встановити Bootstrap-залежності

```bash
pip install django-bootstrap5
```

Або якщо є `requirements.txt`:
```bash
pip install -r requirements.txt
```

Зареєструй у `settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_bootstrap5',    # ← ДОДАЙ: Bootstrap 5 для форм
    'hello_app',
]

# Маппінг Django Messages → Bootstrap Alert класи
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

## Крок 2 — Базовий шаблон `base.html`

**Template Inheritance** — ключовий принцип Django-шаблонів. Один файл `base.html` містить Bootstrap CDN, Navbar і Footer. Всі інші сторінки лише додають контент у слот `{% block content %}`.

Створи файл `hello_app/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>

    <!-- Bootstrap 5 CSS — підключаємо в <head> до рендерингу тіла -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          crossorigin="anonymous">

    <!-- Bootstrap Icons -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    {% block extra_css %}{% endblock %}
</head>

<!--
    Sticky Footer — три класи вирішують проблему «підвисаючого» футера:
    d-flex flex-column → body є вертикальним flex-контейнером
    min-vh-100 → body завжди мінімум 100% висоти вікна
    flex-grow-1 на <main> → main забирає весь вільний простір
-->
<body class="bg-light d-flex flex-column min-vh-100">

    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>
            <div class="collapse navbar-collapse">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_list' %}">Всі нотатки</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_create' %}">+ Нова</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <main class="container my-4 flex-grow-1">

        <!-- Django Messages → Bootstrap Alerts -->
        {% if messages %}
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
            {% endfor %}
        {% endif %}

        {% block content %}{% endblock %}

    </main>

    <footer class="bg-dark text-center text-white-50 py-3">
        <small>Bootstrap Notes &copy; 2026</small>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}

</body>
</html>
```

**Схема Sticky Footer:**
```
┌────────────── body (min-vh-100) ──────────────┐
│  <nav>    — фіксована висота                  │
│  <main>   — flex-grow-1 ↕ (займає решту)      │
│  <footer> — фіксована висота, завжди внизу    │
└───────────────────────────────────────────────┘
```

---

## Крок 3 — NoteForm (ModelForm)

Створи `hello_app/forms.py`:

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm автоматично генерує поля з моделі Note:
    CharField(max_length=200) → <input type="text">
    TextField → <textarea>
    """

    class Meta:
        model = Note
        fields = ['title', 'content']
        widgets = {
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

---

## Крок 4 — CRUD views із PRG-паттерном

**PRG (Post/Redirect/Get)** — стандартний паттерн для форм:
- `GET` → показати порожню/заповнену форму
- `POST` → обробити і зберегти → `redirect` на інший URL

Без `redirect` після `POST`: якщо натиснути F5 — браузер повторить POST і створить дублікат.

Відкрий `hello_app/views.py`:

```python
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages

from .models import Note
from .forms import NoteForm


def index(request):
    return redirect('hello_app:note_list')


def note_list(request):
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk)
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            messages.success(request, f'Нотатку "{note.title}" успішно створено!')
            return redirect('hello_app:note_list')    # ← PRG: redirect після POST
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'action': 'Створити',
        'title': 'Нова нотатка',
    })


def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)  # instance=note → оновлення
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
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title
        note.delete()
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

> `get_object_or_404(Note, pk=pk)` — якщо нотатки з таким pk не існує, повертає 404 (не 500).

---

## Крок 5 — URL-маршрути

`hello_app/urls.py`:

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

`<int:pk>` — path converter: захоплює ціле число з URL і передає у view як аргумент `pk`.
Наприклад: `/notes/42/` → `pk=42`.

---

## Крок 6 — Bootstrap Card Grid для списку

`hello_app/templates/hello_app/note_list.html`:

```html
{% extends 'base.html' %}

{% block title %}Мої нотатки{% endblock %}

{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h2 mb-0">Мої нотатки <span class="badge bg-secondary">{{ notes|length }}</span></h1>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>Нова нотатка
    </a>
</div>

{% if notes %}
    <!--
        Bootstrap Grid:
        row-cols-1 → 1 колонка на мобільних
        row-cols-md-2 → 2 колонки на планшетах
        row-cols-lg-3 → 3 колонки на комп'ютерах
        g-4 → відступи між картками
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
        {% for note in notes %}
        <div class="col">
            <div class="card h-100 shadow-sm">
                <div class="card-body">
                    <h5 class="card-title">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark">
                            {{ note.title }}
                        </a>
                    </h5>
                    <p class="card-text text-muted small">
                        {{ note.content|truncatechars:100 }}
                    </p>
                </div>
                <div class="card-footer bg-transparent d-flex justify-content-between">
                    <small class="text-muted">{{ note.created_at|timesince }} тому</small>
                    <div class="btn-group btn-group-sm">
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary"><i class="bi bi-pencil"></i></a>
                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger"><i class="bi bi-trash"></i></a>
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
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">Створити першу</a>
    </div>
{% endif %}

{% endblock %}
```

---

## Крок 7 — Шаблон форми

`hello_app/templates/hello_app/note_form.html`:

```html
{% extends 'base.html' %}

{% block title %}{{ title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-8 col-lg-6">
        <div class="card shadow-sm">
            <div class="card-header"><h1 class="h4 mb-0">{{ title }}</h1></div>
            <div class="card-body">
                <form method="post" novalidate>
                    {% csrf_token %}
                    {% for field in form %}
                    <div class="mb-3">
                        <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
                            {{ field.label }}
                        </label>
                        {{ field }}
                        {% if field.errors %}
                            {% for error in field.errors %}
                            <div class="invalid-feedback d-block">{{ error }}</div>
                            {% endfor %}
                        {% endif %}
                    </div>
                    {% endfor %}
                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-primary">{{ action }}</button>
                        <a href="{% url 'hello_app:note_list' %}" class="btn btn-outline-secondary">Скасувати</a>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

> `{% csrf_token %}` — **обов'язково** в кожній POST-формі. Без нього Django повертає 403 Forbidden.

---

## Крок 8 — Шаблон підтвердження видалення

`hello_app/templates/hello_app/note_confirm_delete.html`:

```html
{% extends 'base.html' %}

{% block title %}Видалити: {{ note.title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-6">
        <div class="card border-danger shadow-sm">
            <div class="card-header bg-danger text-white">
                <h1 class="h4 mb-0"><i class="bi bi-trash me-2"></i>Видалити нотатку</h1>
            </div>
            <div class="card-body">
                <p>Ви дійсно хочете видалити нотатку <strong>«{{ note.title }}»</strong>?</p>
                <p class="text-muted small">Ця дія незворотна.</p>
                <form method="post">
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-danger">Видалити</button>
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary">Скасувати</a>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

---

## Як це все пов'язано

```
Browser → GET /notes/new/
    → note_create view → NoteForm() (порожня)
    → note_form.html (рендер форми)

Browser → POST /notes/new/ (з даними форми)
    → note_create view → NoteForm(request.POST)
    → form.is_valid() → form.save() → Note у БД
    → messages.success(...)
    → redirect('/notes/')

Browser → GET /notes/
    → note_list view → Note.objects.all()
    → note_list.html (показує flash-message + список)
```

---

## Практичне завдання

1. Запусти проєкт, відкрий `/notes/` — переконайся що сторінка оформлена Bootstrap.
2. Створи 3 нотатки через форму `/notes/new/`.
3. Відредагуй одну нотатку — переконайся що flash-повідомлення з'являється.
4. Видали нотатку — перевір що сторінка підтвердження показується перед видаленням.
5. Додай поле `priority` (CharField, choices: low/medium/high) до моделі, форми і шаблону.

---

## Чеклист самоперевірки

- [ ] `base.html` існує і Bootstrap CSS підключений через CDN
- [ ] `{% block content %}` у `base.html`, `{% extends %}` у дочірніх шаблонах
- [ ] Форма рендериться з Bootstrap-класами (`form-control`)
- [ ] `{% csrf_token %}` є в кожній POST-формі
- [ ] Після POST відбувається `redirect` (PRG-паттерн)
- [ ] Flash-повідомлення відображаються після redirect
- [ ] `get_object_or_404` використовується замість `Note.objects.get(pk=pk)`
- [ ] Sticky Footer: футер завжди внизу незалежно від кількості контенту

---

## Далі

Наступний крок: [03 — CRUD і архітектура](03_crud.md) — domain design, повна схема моделей, selectors/services.

Модулі документації:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
