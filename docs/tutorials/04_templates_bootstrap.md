# Туторіал 04 — Templates, Crispy Forms і SaaS Dashboard

**Мета:** побудувати 3-рівневу Template Inheritance, перейти від ручного Bootstrap HTML до `{% crispy form %}`, реалізувати SaaS Dashboard із Sidebar Context Processor.

---

## Проблема: Template Soup

Коли Navbar, Bootstrap CDN і Footer скопійовані в кожному шаблоні — при зміні навігації правиш 20 файлів. Це «Template Soup».

**Рішення:** Template Inheritance — один файл визначає структуру, решта тільки заповнює `{% block content %}`.

---

## 3-рівнева Template Inheritance

```
base.html                        ← Рівень 1: HTML-оболонка + Bootstrap CDN
│
└── layouts/dashboard.html       ← Рівень 2: Sidebar + Topbar + Django Messages
        │
        ├── note_list.html       ← Рівень 3: Контент сторінки
        ├── note_form.html
        └── notebook_list.html
```

| | Без наслідування | З 3-рівневою ієрархією |
|--|-----------------|----------------------|
| Нова сторінка | Скопіювати весь HTML | 5 рядків `{% extends %}` + content |
| Зміна навігації | Правити всі файли | Тільки `dashboard.html` |
| Bootstrap CDN | Кожен файл | Тільки `base.html` |

---

## Крок 1 — Встановити Crispy Forms

```bash
pip install django-crispy-forms crispy-bootstrap5
```

`settings.py`:

```python
INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
    'hello_app',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'
```

---

## Крок 2 — Рівень 1: `base.html`

`templates/base.html` — тільки HTML-скелет:

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
</head>
<body>
    {% block body %}{% endblock %}

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

`base.html` не знає нічого про Sidebar або навігацію — тільки Bootstrap CDN і слот `{% block body %}`.

---

## Крок 3 — Рівень 2: `layouts/dashboard.html`

```
templates/
├── base.html
└── layouts/
    └── dashboard.html
```

`templates/layouts/dashboard.html`:

```html
{% extends 'base.html' %}

{% block body %}
<div class="d-flex vh-100 overflow-hidden">

    <!-- ══════════ SIDEBAR ══════════ -->
    <nav class="bg-dark text-white d-flex flex-column p-3"
         style="min-width: 240px; max-width: 240px;">

        <a href="{% url 'hello_app:note_list' %}"
           class="text-white text-decoration-none fw-bold fs-5 mb-4 d-block">
            <i class="bi bi-journal-text me-2"></i>CrispyNotes
        </a>

        <small class="text-uppercase text-secondary mb-1">Нотатки</small>
        <ul class="nav flex-column mb-3">
            <li class="nav-item">
                <a href="{% url 'hello_app:note_list' %}"
                   class="nav-link text-white {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
                    <i class="bi bi-list-ul me-1"></i>Всі нотатки
                </a>
            </li>
            <li class="nav-item">
                <a href="{% url 'hello_app:note_create' %}" class="nav-link text-white">
                    <i class="bi bi-plus-circle me-1"></i>Нова нотатка
                </a>
            </li>
        </ul>

        <!-- Записники з Context Processor (sidebar_notebooks) -->
        {% if sidebar_notebooks %}
        <small class="text-uppercase text-secondary mb-1">Записники</small>
        <ul class="nav flex-column mb-3">
            {% for nb in sidebar_notebooks %}
            <li class="nav-item">
                <a href="{% url 'hello_app:note_list' %}?notebook={{ nb.pk }}"
                   class="nav-link text-white-50 py-1 small">
                    <i class="bi bi-journal me-1"></i>{{ nb.title }}
                    <span class="badge bg-secondary ms-1">{{ nb.note_count }}</span>
                </a>
            </li>
            {% endfor %}
        </ul>
        {% endif %}

        <!-- Теги з Context Processor (sidebar_tags) -->
        {% if sidebar_tags %}
        <small class="text-uppercase text-secondary mb-1">Теги</small>
        <div class="d-flex flex-wrap gap-1">
            {% for tag in sidebar_tags %}
            <a href="{% url 'hello_app:note_list' %}?tag={{ tag.pk }}"
               class="badge text-decoration-none"
               style="background-color: {{ tag.color }}">
                {{ tag.name }}
            </a>
            {% endfor %}
        </div>
        {% endif %}

    </nav>
    <!-- ══════════ END SIDEBAR ══════════ -->

    <!-- ══════════ MAIN AREA ══════════ -->
    <div class="flex-grow-1 d-flex flex-column overflow-hidden">

        <!-- Topbar -->
        <header class="border-bottom bg-white px-4 py-2 d-flex align-items-center justify-content-between">
            <h1 class="h5 mb-0">{% block topbar_title %}{% endblock %}</h1>
            <div class="d-flex align-items-center gap-3">
                {% if request.user.is_authenticated %}
                <span class="text-muted small">{{ request.user.username }}</span>
                <a href="{% url 'logout' %}" class="btn btn-sm btn-outline-secondary">Вийти</a>
                {% endif %}
            </div>
        </header>

        <!-- Django Messages -->
        <div class="px-4 pt-2">
            {% if messages %}
                {% for message in messages %}
                <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-2" role="alert">
                    {{ message }}
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
                {% endfor %}
            {% endif %}
        </div>

        <!-- Page Content -->
        <main class="flex-grow-1 overflow-auto p-4">
            {% block content %}{% endblock %}
        </main>

    </div>
    <!-- ══════════ END MAIN AREA ══════════ -->

</div>
{% endblock %}
```

---

## Крок 4 — Рівень 3: сторінки

```html
{# hello_app/note_list.html #}
{% extends 'layouts/dashboard.html' %}

{% block title %}Мої нотатки{% endblock %}
{% block topbar_title %}Нотатки{% endblock %}

{% block content %}
<div class="d-flex justify-content-between mb-4">
    <h2 class="h4">Нотатки <span class="badge bg-secondary">{{ notes|length }}</span></h2>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary btn-sm">
        <i class="bi bi-plus-lg me-1"></i>Нова
    </a>
</div>

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <div class="card-body">
                <h5 class="card-title">
                    <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                       class="text-decoration-none text-dark">{{ note.title }}</a>
                </h5>
                <p class="card-text text-muted small">{{ note.content|truncatechars:80 }}</p>
                <div>
                    {% for tag in note.tags.all %}
                    <span class="badge" style="background-color: {{ tag.color }}">{{ tag.name }}</span>
                    {% endfor %}
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

Нова сторінка = лише 5 рядків `{% extends %}` + контент. Sidebar і Topbar безкоштовно.

---

## Три рівні рендерингу форм

### Tier 1 — Raw Django (тільки для debug)

```html
<form method="post">{% csrf_token %}{{ form.as_p }}<button>OK</button></form>
```

Генерує `<p><label><input>` без Bootstrap-класів. Валідація є, але виглядає погано.

---

### Tier 2 — Ручний Bootstrap (80+ рядків)

```python
# forms.py
class NoteFormManual(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['title'].widget.attrs.update({'class': 'form-control'})
        self.fields['content'].widget.attrs.update({'class': 'form-control', 'rows': 8})
```

```html
<!-- 15 рядків на кожне поле × 5 полів = 75 рядків тільки для форми -->
<div class="mb-3">
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">{{ form.title.label }}</label>
    {{ form.title }}
    {% for error in form.title.errors %}<div class="invalid-feedback d-block">{{ error }}</div>{% endfor %}
</div>
```

---

### Tier 3 — Crispy Forms (1 рядок у шаблоні)

```python
# forms.py — ВСЯ структура описана Python-кодом
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Row, Column, Fieldset, Submit, Field


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # FormHelper описує атрибути <form> і структуру полів
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.layout = Layout(
            Fieldset('Основна інформація',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
            ),
            Fieldset('Зміст нотатки',
                Field('content', rows=8, placeholder='Текст нотатки...'),
                Field('tags'),
                Field('is_pinned'),
            ),
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
        )
```

```html
{# note_form.html — 1 рядок замість 80 #}
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block content %}
{% crispy form %}
{% endblock %}
```

**Що генерує `{% crispy form %}` автоматично:**
- `<form method="post">` + CSRF токен
- `<div class="mb-3">` для кожного поля
- `<label class="form-label">` з required-зірочкою (`*`)
- `<input class="form-control">` або `<select class="form-select">`
- `<div class="invalid-feedback">` для помилок
- `<fieldset>` + `<legend>` для `Fieldset`
- `<div class="row">` для `Row`, `<div class="col-md-4">` для `Column`

---

## Sidebar Context Processor

Sidebar показує записники і теги на **кожній** сторінці. Передавати їх з кожного view = дублювання.

**Рішення:** Context Processor — виконується автоматично перед кожним render.

`hello_app/context_processors.py`:

```python
from . import selectors


def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}
    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags': selectors.get_user_tags(request.user),
    }
```

Зареєструй у `settings.py`:

```python
TEMPLATES = [{
    ...
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
            'hello_app.context_processors.sidebar_context',  # ← тут
        ],
    },
}]
```

Тепер `{{ sidebar_notebooks }}` і `{{ sidebar_tags }}` доступні в **кожному шаблоні** без явної передачі з view.

---

## Active state у навігації

```html
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
    Всі нотатки
</a>
```

`request.resolver_match.url_name` повертає `name=` поточного URL (з `urls.py`).

---

## Розташування файлів

```
hello_app/
├── context_processors.py        ← Context Processor
├── forms.py                     ← NoteForm з FormHelper
└── templates/
    ├── base.html                ← Рівень 1: HTML + Bootstrap CDN
    └── layouts/
        └── dashboard.html       ← Рівень 2: Sidebar + Topbar
    └── hello_app/
        ├── note_list.html       ← Рівень 3: extends dashboard
        ├── note_form.html       ← {% crispy form %} — 1 рядок
        └── note_detail.html
```

---

## Практичне завдання

1. Відкрий `notes_app/templates/base.html` → `templates/layouts/dashboard.html` → `notes_app/templates/notes_app/note_list.html`. Відслідкуй ланцюг `{% extends %}`.
2. Додай новий пункт у Sidebar для "Архів" (`/notes/?archived=1`).
3. Перепиши одну форму з Tier 2 (ручний HTML) на Tier 3 (Crispy FormHelper + Layout).
4. Переконайся що active state підсвічується правильно при переході між сторінками.

---

## Чеклист самоперевірки

- [ ] `base.html` → `layouts/dashboard.html` → page-template: 3 рівні успадкування
- [ ] `{% block content %}` у батьку, `{% extends %}` у дочірніх
- [ ] Context Processor зареєстрований у `settings.py`
- [ ] `sidebar_notebooks` і `sidebar_tags` доступні в шаблоні без явної передачі
- [ ] `{% crispy form %}` рендерить форму з Bootstrap-класами
- [ ] `FormHelper.layout` описує структуру форми Python-кодом
- [ ] Active state у навігації через `request.resolver_match.url_name`

---

## Далі

Наступний крок: [05 — Authentication](05_authentication.md) — Login, logout, password reset, IDOR, групи доступу.

Модулі документації:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
