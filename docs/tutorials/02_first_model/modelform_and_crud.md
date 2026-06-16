# ModelForm і CRUD

> На цій сторінці ти побудуєш повноцінний CRUD для `Note`:
> форму створення/редагування (ModelForm), захист від дублікатів (PRG),
> Flash-повідомлення і Bootstrap-шаблони.

---

## Теорія: ModelForm

> `ModelForm` — Django автоматично генерує HTML форму з Python моделі.
> Один клас замінює 50 рядків HTML.

### Без ModelForm vs З ModelForm

```python
# ❌ БЕЗ ModelForm: вручну описуєш кожне поле
class NoteFormManual(forms.Form):
    title   = forms.CharField(max_length=200, label='Заголовок')
    content = forms.CharField(widget=forms.Textarea, required=False, label='Текст')
    # + дублювання з моделлю — при зміні models.py → редагувати ще й тут

# ✅ З ModelForm: один рядок fields = [...]
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content']
        # Django сам дивиться на Note.title (CharField(max_length=200))
        # і генерує forms.CharField(max_length=200)
        # Синхронізація автоматична при зміні моделі
```

### Що ModelForm генерує автоматично

```
Note модель                       NoteForm генерує
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
                                  → <select> з усіма записниками

ManyToManyField(Tag)          →   forms.ModelMultipleChoiceField(
                                      queryset=Tag.objects.all())
                                  widget=SelectMultiple
```

### Цикл форми: GET → POST → redirect

```python
def note_create(request):

    if request.method == 'POST':
        form = NoteForm(request.POST)
        # request.POST: QueryDict {'title': ['Нотатка'], 'content': ['']}
        # NoteForm зв'язується з даними → bound form

        if form.is_valid():
            # is_valid() виконує:
            # 1. Конвертує рядки з request.POST у Python-типи
            # 2. Запускає validators кожного поля
            # 3. Запускає clean_<field>() якщо є
            # 4. Запускає form.clean() (cross-field validation)
            # Якщо є помилки → is_valid() = False → form.errors заповнений

            note = form.save()
            # form.save() = form.instance.save()
            # Виконує INSERT INTO hello_app_note (...) VALUES (...)
            # Повертає збережений об'єкт

            return redirect('hello_app:note_list')
    else:
        form = NoteForm()
        # Незв'язана (unbound) форма — порожня

    return render(request, 'hello_app/note_form.html', {'form': form})
    # Якщо is_valid() = False → повертаємо ТУ САМО форму з помилками
    # form.errors: {'title': ['Це поле обов\'язкове.']}
```

### form.save() і form.save(commit=False)

```python
# form.save() — зберігає і повертає об'єкт
note = form.save()   # INSERT INTO + return Note instance

# form.save(commit=False) — не зберігає, повертає несхоплений об'єкт
note = form.save(commit=False)
note.user = request.user   # ← додаємо поля які не у формі
note.save()                # ← тепер зберігаємо

# Чому commit=False?
# Форма NoteForm не включає поле user (захист від IDOR)
# Тому view додає user = request.user вручну перед збереженням
# У notes_chat_app це обов'язковий паттерн — без нього буде IDOR
```

### Форма з instance — редагування

```python
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        # Зв'язана форма + існуючий об'єкт
        # form.save() → UPDATE замість INSERT
    else:
        form = NoteForm(instance=note)
        # Форма заповнена поточними даними note

    # Без instance: form.save() завжди INSERT (дублікат!)
    # З instance: form.save() → UPDATE hello_app_note SET ... WHERE id=note.id
```

---

## Теорія: PRG-паттерн

> **POST/Redirect/Get** — стандарт обробки форм. Захищає від дублікатів при F5.

### Проблема без PRG

```
Користувач → POST /notes/new/ (створити нотатку "Shopping")
  ↓ View зберігає нотатку, повертає 200 з підтвердженням
  ↓ Браузер показує сторінку
  ↓ Користувач натискає F5 (оновити)
  ↓ Браузер ПОВТОРЮЄ POST запит ← ПРОБЛЕМА!
  ↓ Друга нотатка "Shopping" створена!

Результат: 2 однакові нотатки. F5 ще раз → 3 нотатки.
```

### Рішення — PRG

```
Користувач → POST /notes/new/
  ↓ View зберігає нотатку
  ↓ View повертає 302 REDIRECT → /notes/
  ↓ Браузер GET /notes/ (автоматично слідує redirect)
  ↓ Браузер показує список нотаток
  ↓ F5 → повторює GET /notes/ (безпечно!)

Результат: лише одна нотатка. F5 = перезавантаження списку.
```

```python
# ✅ Правильно — PRG:
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return redirect('hello_app:note_list')   # ← 302, не 200!
    else:
        form = NoteForm()
    return render(request, 'hello_app/note_form.html', {'form': form})

# ❌ Неправильно — без redirect:
def note_create_bad(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return render(request, 'success.html', {'note': note})
            # ↑ Браузер залишається на POST URL
            # F5 → browser: "Повторити POST запит?" → дублікат!
```

---

## Теорія: Django Messages

> Flash-повідомлення — одноразові повідомлення що зникають після одного перегляду.
> Ідеально для "Нотатку збережено" після redirect.

### Як Messages працюють

```
1. POST /notes/new/
   messages.success(request, "Нотатку збережено!")
   → повідомлення збереглося у SESSION (не в response)
   ↓
2. redirect → GET /notes/
   шаблон: {% for message in messages %}{{ message }}{% endfor %}
   → повідомлення відображається
   → SESSION очищається (використано одноразово!)
   ↓
3. F5 → GET /notes/ знову
   messages = порожній → повідомлення зникло
```

### Рівні Messages і Bootstrap класи

```python
from django.contrib import messages

messages.debug(request, 'Налагоджувальне повідомлення')
messages.info(request, 'Інформаційне повідомлення')
messages.success(request, 'Нотатку успішно збережено!')
messages.warning(request, 'Нотатку видалено.')
messages.error(request, 'Помилка при збереженні.')
```

Налаштуй у `hello_project/settings.py`:

```python
from django.contrib.messages import constants as messages

MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',   # → alert-secondary
    messages.INFO:    'info',        # → alert-info
    messages.SUCCESS: 'success',     # → alert-success
    messages.WARNING: 'warning',     # → alert-warning
    messages.ERROR:   'danger',      # → alert-danger (Bootstrap використовує danger!)
}
```

### Messages у шаблоні (base.html)

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

## Теорія: Template Inheritance

> Один `base.html` містить Bootstrap CDN, Navbar, Footer.
> Всі інші сторінки лише заповнюють блоки.

### Як Django обробляє шаблони з {% extends %}

```
1. render(request, 'hello_app/note_list.html', context)

2. Django знаходить шаблон:
   APP_DIRS=True → hello_app/templates/hello_app/note_list.html

3. Зустрічає {% extends 'base.html' %}
   → завантажує base.html
   → знаходить всі {% block name %}...{% endblock %}

4. Для кожного block:
   → якщо дочірній шаблон перевизначає → використовує дочірній вміст
   → якщо ні → використовує базовий вміст

5. {{ variable }} → замінює на context значення
```

### Блоки base.html

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>
    <link rel="stylesheet" href="...bootstrap.min.css">
    {% block extra_css %}{% endblock %}
    <!--
        extra_css: порожній блок — дочірній може додати CSS специфічний для сторінки
    -->
</head>
<body>
    <nav>...</nav>
    <main>
        {% block content %}{% endblock %}
        <!--
            content: ГОЛОВНИЙ блок — кожна сторінка заповнює своє
        -->
    </main>
    <footer>...</footer>
    <script src="...bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

### Дочірній шаблон

```html
{% extends 'base.html' %}

{% block title %}Мої нотатки{% endblock %}

{% block content %}
<h1>Нотатки</h1>
...
{% endblock %}

{# Блоки які не перевизначаємо → використовується базовий вміст #}
{# (extra_css, extra_js — залишаються порожніми) #}
```

---

## Теорія: Bootstrap 5 Grid

```
Bootstrap Grid = 12 колонок у рядку (row)
Breakpoints:
  sm  → ≥576px   (більший телефон)
  md  → ≥768px   (планшет)
  lg  → ≥992px   (ноутбук)
  xl  → ≥1200px  (монітор)
```

```html
<!-- Адаптивна Card Grid: 1 → 2 → 3 колонки -->
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    <!--
        row-cols-1:    мобільний   → 1 карточка в рядку
        row-cols-md-2: планшет     → 2 карточки в рядку
        row-cols-lg-3: ноутбук/PC  → 3 карточки в рядку
        g-4:           gap (відступи між карточками) = 1.5rem
    -->
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <!-- h-100: висота = 100% рядка (рівні картки) -->
        </div>
    </div>
    {% endfor %}
</div>
```

---

## Крок 1 — Bootstrap залежності у settings.py

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
    'django_bootstrap5',    # ← Bootstrap 5 для форм ({% bootstrap_form form %})
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

## Крок 2 — base.html

```
hello_app/
└── templates/
    ├── base.html           ← Тут (доступний всім apps в INSTALLED_APPS)
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

    <!-- Bootstrap 5 CSS — CDN (не потрібен npm/webpack) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          crossorigin="anonymous">

    <!-- Bootstrap Icons (bi bi-pencil, bi bi-trash тощо) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    {% block extra_css %}{% endblock %}
</head>

<!--
    Sticky Footer:
    body.d-flex.flex-column.min-vh-100 + main.flex-grow-1 → footer завжди внизу
    навіть коли контент менший за висоту вікна
-->
<body class="bg-light d-flex flex-column min-vh-100">

    <!-- ═══════════════ NAVBAR ═══════════════ -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Hamburger для мобільних (collapse) -->
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

    <!-- Bootstrap 5 JS (bundle включає Popper.js) -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}

</body>
</html>
```

---

## Крок 3 — NoteForm (ModelForm)

Створи `hello_app/forms.py`:

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm для Note.
    Django автоматично генерує поля з моделі:
      title (CharField(max_length=200)) → TextInput
      content (TextField(blank=True))   → Textarea
    """

    class Meta:
        model  = Note
        fields = ['title', 'content']
        # НЕ включаємо: created_at (auto_now_add) — встановлює Django автоматично

        widgets = {
            'title': forms.TextInput(attrs={
                'class':       'form-control',
                'placeholder': 'Введіть назву...',
                'autofocus':   True,
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
        Кастомний validator для поля title.
        clean_<field_name>() викликається після стандартних validators.
        """
        title = self.cleaned_data.get('title', '').strip()
        if len(title) < 3:
            raise forms.ValidationError('Заголовок має бути мінімум 3 символи.')
        return title   # ← ВАЖЛИВО: повернути очищене значення!
```

### Три способи виведення форми у шаблоні

```html
{# Спосіб 1 — as_p (швидко, без Bootstrap) #}
{{ form.as_p }}

{# Спосіб 2 — django-bootstrap5 #}
{% load django_bootstrap5 %}
{% bootstrap_form form %}

{# Спосіб 3 — вручну (повний контроль над кожним полем) #}
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

## Крок 4 — CRUD views

`hello_app/views.py`:

```python
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages

from .models import Note
from .forms import NoteForm


def index(request):
    """Головна → redirect на список."""
    return redirect('hello_app:note_list')


def note_list(request):
    """Список всіх нотаток."""
    notes = Note.objects.all()              # SELECT * FROM hello_app_note
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    """Деталь однієї нотатки."""
    note = get_object_or_404(Note, pk=pk)   # get() або 404
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    GET  → порожня форма
    POST → валідація → збереження → redirect (PRG)
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
    GET  → форма заповнена поточними даними (instance=note)
    POST → оновлення (UPDATE, не INSERT)
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Нотатку "{note.title}" оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)   # Заповнити поточними даними

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'note':   note,
        'action': 'Зберегти зміни',
        'title':  f'Редагувати: {note.title}',
    })


def note_delete(request, pk):
    """
    GET  → сторінка підтвердження
    POST → видалення → redirect (DELETE тільки через POST!)

    Чому тільки POST?
    Якщо DELETE через GET: <a href="/notes/1/delete/"> або <img src=...>
    видалить нотатку при завантаженні сторінки.
    POST вимагає форму з csrf_token → захищено.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title   # Зберегти перед видаленням
        note.delete()
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### get_object_or_404 — захист від DoesNotExist

```python
# ❌ Без get_object_or_404:
note = Note.objects.get(pk=pk)
# Якщо не знайдено → DoesNotExist виняток → 500 Internal Server Error

# ✅ З get_object_or_404:
note = get_object_or_404(Note, pk=pk)
# Якщо не знайдено → Http404 → 404 Not Found сторінка (правильно!)

# Фільтрація за кількома полями (захист від IDOR):
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 якщо нотатка не існує АБО belongs to іншого юзера
```

---

## Крок 5 — URL-маршрути

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

**Важливо: порядок `notes/new/` перед `notes/<int:pk>/`**

```
'notes/new/' → не співпадає з <int:pk> бо 'new' не є int → OK
'notes/42/'  → <int:pk> → pk=42 → OK

Якщо б порядок був зворотним:
'notes/<int:pk>/' → 'new' → int('new') → ValueError → помилка!
Django перевіряє urlpatterns ЗВЕРХУ ДОНИЗУ → перший match виграє.
Конкретніші патерни — вгору!
```

---

## Крок 6 — Шаблон списку

`hello_app/templates/hello_app/note_list.html`:

```html
{% extends 'base.html' %}

{% block title %}Мої нотатки{% endblock %}

{% block content %}

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
                            stretched-link: весь .card стає кліковим
                            (position:relative на card + ::after на link)
                        -->
                    </h5>
                    <p class="card-text text-muted small mt-2">
                        {{ note.content|truncatechars:120 }}
                        <!--
                            truncatechars:120 → обрізає до 120 символів і додає "..."
                        -->
                    </p>
                </div>

                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} тому
                    </small>

                    <div class="btn-group btn-group-sm position-relative z-1">
                        <!-- z-1: вище за stretched-link → кнопки кліковні -->
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary" title="Редагувати">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger" title="Видалити">
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
        <p class="text-muted">Створи першу нотатку і вона з'явиться тут.</p>
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>Створити першу нотатку
        </a>
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

            <div class="card-header bg-white border-bottom">
                <h1 class="h4 mb-0">
                    <i class="bi bi-journal-plus me-2"></i>{{ title }}
                </h1>
            </div>

            <div class="card-body">
                <form method="post" novalidate>
                    <!--
                        novalidate: вимикає браузерну HTML5 валідацію
                        → Django робить валідацію на сервері (надійніше)
                    -->
                    {% csrf_token %}
                    <!--
                        csrf_token: ОБОВ'ЯЗКОВО для кожної POST форми!
                        Django генерує: <input type="hidden" name="csrfmiddlewaretoken" value="...">
                        Без нього: 403 Forbidden від CsrfViewMiddleware
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

## Крок 8 — Шаблон видалення

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
                        DELETE через POST (не GET):
                        GET: <img src="/notes/1/delete/"> видалить при завантаженні
                        POST + csrf_token: захист від CSRF/ненавмисного видалення
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

## Крок 9 — Шаблон деталі

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
                white-space: pre-wrap: зберігає переноси рядків з TextField
                Без цього \n → пробіл у HTML
                Альтернатива: {{ note.content|linebreaks }}
            -->
        {% else %}
            <p class="text-muted fst-italic">Нотатка без вмісту.</p>
        {% endif %}
    </div>
</div>

{% endblock %}
```

---

## Повний CRUD цикл

```
CREATE:  GET  /notes/new/        → note_create view → порожня форма
         POST /notes/new/        → form.save() → redirect → flash message
         GET  /notes/            → список з новою нотаткою + flash message

READ:    GET  /notes/            → note_list view → QuerySet → шаблон
         GET  /notes/42/         → note_detail view → get_object_or_404 → шаблон

UPDATE:  GET  /notes/42/edit/    → note_edit view → форма з instance=note
         POST /notes/42/edit/    → form.save(instance) → UPDATE → redirect

DELETE:  GET  /notes/42/delete/  → note_delete view → підтвердження
         POST /notes/42/delete/  → note.delete() → redirect → flash message
```

---

## Зміни у файлах після цього кроку

| Файл | Що зроблено |
|------|-------------|
| `hello_project/settings.py` | `django_bootstrap5` у INSTALLED_APPS, `MESSAGE_TAGS` |
| `hello_app/forms.py` | `NoteForm(ModelForm)` з widgets і `clean_title()` — **НОВИЙ** |
| `hello_app/views.py` | 5 CRUD views: `index`, `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| `hello_app/urls.py` | 6 URL маршрутів для CRUD |
| `hello_app/templates/base.html` | Bootstrap CDN, Navbar, Messages, Footer — **НОВИЙ** |
| `hello_app/templates/hello_app/note_list.html` | Bootstrap Card Grid — **ПЕРЕПИСАНИЙ** |
| `hello_app/templates/hello_app/note_detail.html` | Деталь з Breadcrumb — **НОВИЙ** |
| `hello_app/templates/hello_app/note_form.html` | Bootstrap Form — **НОВИЙ** |
| `hello_app/templates/hello_app/note_confirm_delete.html` | Видалення — **НОВИЙ** |
