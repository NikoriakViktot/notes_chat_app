# Туторіал 04 — Templates, Crispy Forms і SaaS Dashboard

> Цей туторіал будує **3-рівневу Template Inheritance**, переходить від ручного Bootstrap HTML
> до `{% crispy form %}`, реалізує **SaaS Dashboard із Sidebar** через Context Processor.
>
> **Результат:**
> ```
> notes_app/
>   templates/
>     base.html                ← Bootstrap CDN (рівень 1)
>     layouts/dashboard.html   ← Sidebar + Topbar (рівень 2)
>     notes_app/note_list.html ← Контент (рівень 3, 8 рядків коду)
> ```

---

## Зміст

**Теорія** _(читати перед кодом)_
- [01 · TEMPLATE SOUP — проблема яку вирішуємо](#01--template-soup)
- [02 · 3-РІВНЕВА ІЄРАРХІЯ — base → dashboard → page](#02--3-рівнева-ієрархія)
- [03 · CRISPY FORMS — три рівні рендерингу форм](#03--crispy-forms)
- [04 · CONTEXT PROCESSORS — дані для всіх шаблонів](#04--context-processors)
- [05 · STATIC FILES — власні CSS/JS](#05--static-files)
- [06 · TEMPLATE TAGS і FILTERS — довідник](#06--template-tags-і-filters)

**Покрокова реалізація**
1. [Крок 1 — Встановити Crispy Forms](#крок-1--встановити-crispy-forms)
2. [Крок 2 — Рівень 1: base.html](#крок-2--рівень-1-basehtml)
3. [Крок 3 — Рівень 2: layouts/dashboard.html](#крок-3--рівень-2-layoutsdashboardhtml)
4. [Крок 4 — Рівень 3: сторінки контенту](#крок-4--рівень-3-сторінки)
5. [Крок 5 — NoteForm з FormHelper і Layout](#крок-5--noteform-з-formhelper)
6. [Крок 6 — Context Processor для Sidebar](#крок-6--context-processor)
7. [Крок 7 — Active state у навігації](#крок-7--active-state)
8. [Крок 8 — Реєстрація в settings.py](#крок-8--реєстрація)

---

## 01 · Template Soup

> Що таке Template Soup і чому це проблема?

### Без Template Inheritance

```html
<!-- note_list.html — 150 рядків! -->
<!DOCTYPE html>
<html>
<head>
    <title>Нотатки</title>
    <link rel="stylesheet" href="...bootstrap.css">  ← COPY-PASTE
    <link rel="stylesheet" href="...bootstrap-icons.css">
</head>
<body>
<nav class="navbar navbar-dark bg-dark">             ← COPY-PASTE
    <a class="navbar-brand" href="/">CrispyNotes</a>
    ...20 рядків навігації...
</nav>
<main class="container my-4">
    <!-- 30 рядків реального контенту -->
</main>
<footer>CrispyNotes &copy; 2026</footer>            ← COPY-PASTE
<script src="...bootstrap.bundle.js"></script>       ← COPY-PASTE
</body>
</html>

<!-- note_form.html — ще 150 рядків! -->
<!DOCTYPE html>
<html>  ← Точна копія структури!
...
```

**Проблема:** Зміна navbar → правити 20 файлів. Одна помилка (наприклад, забув `</nav>`) → ламає всі 20 сторінок.

### З Template Inheritance

```html
<!-- note_list.html — 10 рядків! -->
{% extends 'layouts/dashboard.html' %}
{% block title %}Нотатки{% endblock %}
{% block topbar_title %}Мої нотатки{% endblock %}
{% block content %}
    <!-- тільки реальний контент -->
{% endblock %}
```

**Перевага:** Зміна navbar — тільки `layouts/dashboard.html`. Всі 20 сторінок оновились автоматично.

---

## 02 · 3-рівнева ієрархія

```
base.html                    ← Рівень 1: HTML скелет + Bootstrap CDN
│  {% block body %}
│
└── layouts/dashboard.html   ← Рівень 2: Sidebar + Topbar + Messages
        {% extends 'base.html' %}
        {% block body %}
            <div class="d-flex">
                <nav>Sidebar</nav>
                <main>{% block content %}{% endblock %}</main>
            </div>
        {% endblock %}
        │
        ├── note_list.html       ← Рівень 3: Контент (5-10 рядків)
        ├── note_form.html       ← {% crispy form %} — 1 рядок!
        ├── note_detail.html
        └── notebook_list.html
```

### Що кожен рівень відповідає

| Рівень | Файл | Відповідальність | Змінюється при... |
|--------|------|-----------------|-------------------|
| 1 | `base.html` | HTML5 структура, Bootstrap CDN, Bootstrap JS | Зміна CDN версії, додавання глобального CSS |
| 2 | `layouts/dashboard.html` | Sidebar, Topbar, Messages, SaaS layout | Зміна навігації, нові пункти меню, новий sidebar |
| 3 | `notes_app/*.html` | Специфічний контент сторінки | Логіка конкретної фічі |

### Правило: batch.super

```html
{# Якщо дочірній хоче РОЗШИРИТИ блок (не перезаписати): #}
{% block extra_css %}
    {{ block.super }}   {# ← вставляє вміст батьківського блоку #}
    <link rel="stylesheet" href="{% static 'css/notes-editor.css' %}">
{% endblock %}

{# Результат: CSS з layouts/dashboard.html + CSS цієї сторінки #}
{# Без block.super: CSS layouts/dashboard.html буде ЗАМІНЕНИЙ #}
```

---

## 03 · Crispy Forms

> Три рівні рендерингу Django форм: від примітивного до elegant.

### Tier 1 — Raw Django (для debug тільки)

```html
<form method="post">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">OK</button>
</form>
```

```html
<!-- Що генерується: без Bootstrap класів, виглядає погано -->
<p><label for="id_title">Заголовок:</label>
   <input type="text" name="title" id="id_title" maxlength="200" required>
</p>
<p><label for="id_content">Зміст:</label>
   <textarea name="content" id="id_content" rows="10"></textarea>
</p>
```

---

### Tier 2 — Ручний Bootstrap

```python
# forms.py — додаємо Bootstrap класи вручну
class NoteFormTier2(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({'class': 'form-control'})
        self.fields['is_pinned'].widget.attrs['class'] = 'form-check-input'
```

```html
<!-- note_form.html — 15+ рядків на КОЖНЕ поле -->
<div class="mb-3">
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
        {{ form.title.label }}<span class="text-danger">*</span>
    </label>
    {{ form.title }}
    {% if form.title.help_text %}
        <div class="form-text">{{ form.title.help_text }}</div>
    {% endif %}
    {% for error in form.title.errors %}
        <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
</div>
<!-- × 6 полів = 90+ рядків тільки для форми -->
```

---

### Tier 3 — Crispy Forms FormHelper + Layout

```python
# forms.py — вся структура форми у Python-коді
from crispy_forms.helper import FormHelper
from crispy_forms.layout import (
    Layout, Fieldset, Row, Column, Field, Submit, HTML, ButtonHolder
)


class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Обмежити queryset notebook і tags тільки цим юзером:
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset     = Tag.objects.filter(user=user)

        # FormHelper описує <form> атрибути і layout
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id     = 'note-form'

        self.helper.layout = Layout(

            # Fieldset → <fieldset><legend>Основна інформація</legend>...</fieldset>
            Fieldset('Основна інформація',
                Field('title',
                    placeholder='Назва нотатки...',
                    autofocus=True,
                    css_class='form-control-lg',  # більший input
                ),
                Row(
                    Column('priority', css_class='col-md-4'),
                    # → <div class="col-md-4">...</div>
                    Column('notebook', css_class='col-md-8'),
                ),
            ),

            # Другий Fieldset — зміст і теги
            Fieldset('Зміст та організація',
                Field('content', rows=8, placeholder='Текст нотатки...'),
                Field('tags'),
                Field('is_pinned'),
            ),

            # HTML — довільний HTML у layout
            HTML('<hr class="my-3">'),

            # Кнопки
            ButtonHolder(
                Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
                HTML('<a href="{{ cancel_url }}" class="btn btn-outline-secondary">Скасувати</a>'),
            ),
        )
```

```html
{# note_form.html — 1 рядок замість 90! #}
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block title %}{{ title }}{% endblock %}
{% block topbar_title %}{{ title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-10 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-body p-4">
                {% crispy form %}
                {#
                    crispy генерує автоматично:
                    <form method="post" id="note-form">
                      {% csrf_token %}
                      <fieldset>
                        <legend>Основна інформація</legend>
                        <div class="mb-3">
                          <label class="form-label">Назва *</label>
                          <input class="form-control form-control-lg" ...>
                        </div>
                        <div class="row">
                          <div class="col-md-4">...</div>
                          <div class="col-md-8">...</div>
                        </div>
                      </fieldset>
                      ...
                      <button class="btn btn-primary">Зберегти нотатку</button>
                    </form>
                #}
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

### Layout Elements — довідник

```python
from crispy_forms.layout import *

# Базові елементи:
Field('field_name')                        # Поле з label і errors
Field('field_name', css_class='custom')   # + кастомний клас
Field('field_name', placeholder='...')    # + HTML атрибут
Field('field_name', rows=8)               # Textarea rows

# Структурні:
Row(Column('f1', css_class='col-6'), Column('f2', css_class='col-6'))
# → <div class="row"><div class="col-6">f1</div><div class="col-6">f2</div></div>

Fieldset('Заголовок', Field('f1'), Field('f2'))
# → <fieldset><legend>Заголовок</legend>f1 f2</fieldset>

Div(Field('f1'), css_class='custom-div')
# → <div class="custom-div">f1</div>

HTML('<hr><p>Довільний HTML</p>')

# Кнопки:
Submit('submit', 'Зберегти')
# → <input type="submit" class="btn btn-primary" value="Зберегти">

Submit('submit', 'Зберегти', css_class='btn btn-success')
# → кастомний клас

ButtonHolder(Submit('s', 'OK'), HTML('<a href="#">Cancel</a>'))
# → обгортка для кнопок
```

---

## 04 · Context Processors

> **Проблема:** Sidebar показує список записників і тегів на КОЖНІЙ сторінці.
> Якщо передавати їх з кожного view — дублювання коду у 20 місцях.

### Як Context Processors працюють

```
HTTP Request
    ↓
Middleware pipeline
    ↓
View функція (view_func)
    ↓
render(request, 'template.html', {'notes': notes})  ← view context
    ↓
Django Template Engine:
    1. Збирає context з view: {'notes': notes}
    2. АВТОМАТИЧНО виконує кожен context_processor(request) із settings.py
    3. Merged context = view context + processor contexts
    4. Рендерить шаблон з merged context

Всі context_processors:
  django.template.context_processors.debug  → {{ debug }}
  django.template.context_processors.request → {{ request }}
  django.contrib.auth.context_processors.auth → {{ user }}, {{ perms }}
  django.contrib.messages.context_processors.messages → {{ messages }}
  hello_app.context_processors.sidebar_context → {{ sidebar_notebooks }}, {{ sidebar_tags }}
```

### Написати Context Processor

`hello_app/context_processors.py`:

```python
from . import selectors


def sidebar_context(request):
    """
    Автоматично додає до КОЖНОГО шаблону:
      sidebar_notebooks → QuerySet записників юзера
      sidebar_tags      → QuerySet тегів юзера

    Умова: тільки для залогінених юзерів.
    Для AnonymousUser повертаємо {} (порожній словник).
    """
    if not request.user.is_authenticated:
        return {}   # ← AnonymousUser не має записників/тегів

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags':      selectors.get_user_tags(request.user),
    }
```

### Коли context_processors НЕ підходять

```python
# Не використовуй context_processor для:
# 1. Тяжких SQL запитів (виконуються на КОЖНІЙ сторінці)
# 2. Змінних специфічних для однієї сторінки (pass in render context)
# 3. Даних що потребують параметрів URL (url kwargs недоступні)

# Для важкого sidebar: кешування
from django.core.cache import cache

def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}

    cache_key = f'sidebar_notebooks_{request.user.id}'
    notebooks = cache.get(cache_key)
    if notebooks is None:
        notebooks = list(selectors.get_user_notebooks(request.user))
        cache.set(cache_key, notebooks, timeout=300)  # 5 хвилин

    return {'sidebar_notebooks': notebooks}
```

---

## 05 · Static Files

> Власні CSS/JS/зображення — статичні файли Django.

### Де Django шукає статику

```
1. APP_DIRS (STATICFILES_FINDERS):
   hello_app/static/hello_app/style.css
   → URL: /static/hello_app/style.css

2. STATICFILES_DIRS у settings.py:
   BASE_DIR / 'static'
   → Глобальна папка static/

3. collectstatic (production):
   python manage.py collectstatic
   → Копіює в STATIC_ROOT → nginx serve
```

### Підключення власного CSS

```python
# settings.py:
STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']   # Глобальна папка для розробки
STATIC_ROOT = BASE_DIR / 'staticfiles'     # Production: collectstatic
```

```html
{# У шаблоні: #}
{% load static %}
<link rel="stylesheet" href="{% static 'hello_app/css/custom.css' %}">
<img src="{% static 'hello_app/images/logo.png' %}" alt="Logo">
<script src="{% static 'hello_app/js/notes.js' %}"></script>

{# {% static 'path' %} генерує: /static/path #}
{# В production (з CDN): може генерувати https://cdn.example.com/static/path #}
```

---

## 06 · Template Tags і Filters — довідник

### Built-in Filters

```html
{# Рядки: #}
{{ title|truncatechars:50 }}        → Перші 50 символів + "..."
{{ title|truncatewords:10 }}        → Перші 10 слів + "..."
{{ text|linebreaks }}               → \n → <br><p>
{{ text|linebreaksbr }}             → \n → <br>
{{ text|striptags }}                → Прибрати HTML теги
{{ html|safe }}                     → Не екранувати (⚠️ XSS якщо user input!)
{{ value|escape }}                  → Екранувати HTML (за замовчуванням)
{{ email|urlize }}                  → URL/email → <a href>

{# Числа: #}
{{ count|floatformat:2 }}           → 3.14159 → "3.14"
{{ count|filesizeformat }}          → 1024 → "1.0 KB"
{{ price|intcomma }}                → 1000000 → "1,000,000"

{# Дати: #}
{{ date|date:"d.m.Y" }}             → 13.06.2026
{{ date|date:"D, d M Y H:i" }}      → Fri, 13 Jun 2026 10:00
{{ date|time:"H:i" }}               → 10:00
{{ date|timesince }}                → "5 годин тому" / "2 дні тому"
{{ date|timeuntil }}                → "3 дні" (до майбутнього)
{{ date|naturalday }}               → "сьогодні" / "вчора" (humanize)

{# Списки: #}
{{ items|length }}                  → 42
{{ items|first }}                   → перший елемент
{{ items|last }}                    → останній елемент
{{ items|join:", " }}               → "one, two, three"
{{ items|slice:":5" }}              → перші 5 елементів
{{ items|dictsort:"name" }}         → відсортувати за name

{# Логіка: #}
{{ value|default:"Не вказано" }}    → якщо False/None/empty
{{ value|default_if_none:"—" }}     → тільки якщо None
{{ value|yesno:"так,ні,може" }}     → True→так, False→ні, None→може

{# URL: #}
{% load static %}
{% static 'hello_app/logo.png' %}
{% url 'hello_app:note_list' %}
{% url 'hello_app:note_detail' pk=note.pk %}
```

### Template Tags

```html
{# Умовні: #}
{% if condition %}
{% elif other %}
{% else %}
{% endif %}

{% if user.is_authenticated %}
{% if note.priority == 3 %}
{% if note.is_pinned and not note.is_archived %}
{% if tag in note.tags.all %}

{# Цикли: #}
{% for item in items %}
    {{ forloop.counter }}     ← 1-based
    {{ forloop.counter0 }}    ← 0-based
    {{ forloop.revcounter }}  ← зворотній
    {{ forloop.first }}       ← True тільки перший
    {{ forloop.last }}        ← True тільки останній
    {{ forloop.parentloop }}  ← вкладені цикли
{% empty %}
    <p>Немає елементів</p>
{% endfor %}

{# Шаблони: #}
{% extends 'base.html' %}
{% block name %}...{% endblock %}
{% block name %}{{ block.super }}...{% endblock %}
{% include 'hello_app/_card.html' with note=note only %}
{# only: передати тільки вказані змінні, не весь context #}

{# Завантаження бібліотек: #}
{% load static %}
{% load django_bootstrap5 %}
{% load crispy_forms_tags %}
{% load humanize %}
{# Потрібно для naturalday, intcomma тощо #}

{# CSRF: #}
{% csrf_token %}
{# Генерує: <input type="hidden" name="csrfmiddlewaretoken" value="...abc..."> #}

{# URL: #}
{% url 'hello_app:note_detail' pk=note.pk %}
{% url 'hello_app:note_list' %}

{# Коментарі (не потрапляють у HTML): #}
{# Однорядковий коментар #}
{% comment %}
    Багаторядковий коментар
    Не рендериться!
{% endcomment %}
```

---

## Крок 1 — Встановити Crispy Forms

```bash
pip install django-crispy-forms crispy-bootstrap5
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
    'crispy_forms',         # ← core пакет
    'crispy_bootstrap5',    # ← Bootstrap 5 template pack
    'hello_app',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK           = 'bootstrap5'
# ↑ Вказує crispy_forms який template pack використовувати
# bootstrap5 → генерує Bootstrap 5 HTML (mb-3, form-control, form-label...)
```

---

## Крок 2 — Рівень 1: base.html

`templates/base.html` — тільки HTML скелет і Bootstrap CDN. Нічого про Sidebar.

```
templates/
├── base.html              ← Рівень 1 (не в hello_app/)
└── layouts/
    └── dashboard.html     ← Рівень 2
```

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
    {# Дочірній може додати специфічний CSS для сторінки #}
</head>
<body>
    {% block body %}{% endblock %}
    {# Весь body = один великий блок → dashboard.html заповнить Sidebar+Topbar+Content #}

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}
    {# Дочірній може додати специфічний JS (Leaflet, Chart.js тощо) #}
</body>
</html>
```

`base.html` не знає нічого про Sidebar або навігацію — тільки Bootstrap CDN і блоки.

---

## Крок 3 — Рівень 2: layouts/dashboard.html

`templates/layouts/dashboard.html` — SaaS-layout з фіксованим Sidebar.

```html
{% extends 'base.html' %}

{% block body %}
<!--
    d-flex: body = flex рядок (sidebar | main)
    vh-100: займає 100% висоти вікна
    overflow-hidden: контролюємо scroll всередині .flex-grow-1
-->
<div class="d-flex vh-100 overflow-hidden">

    <!-- ══════════════════ SIDEBAR ══════════════════ -->
    <nav id="sidebar"
         class="bg-dark text-white d-flex flex-column p-3 flex-shrink-0"
         style="width: 260px; min-width: 260px;">

        <!-- Brand -->
        <a href="{% url 'hello_app:note_list' %}"
           class="text-white text-decoration-none fw-bold fs-5 mb-4 d-block">
            <i class="bi bi-journal-text me-2 text-primary"></i>CrispyNotes
        </a>

        <!-- Навігація: нотатки -->
        <div class="mb-3">
            <small class="text-uppercase text-secondary d-block mb-1 px-2" style="font-size:.7rem">
                Нотатки
            </small>
            <ul class="nav flex-column">
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_list' %}"
                       class="nav-link text-white py-1
                              {% if request.resolver_match.url_name == 'note_list' %}
                              active bg-primary rounded
                              {% endif %}">
                        <i class="bi bi-list-ul me-2"></i>Всі нотатки
                    </a>
                    {#
                        request.resolver_match.url_name:
                        Повертає name= параметр поточного URL з urls.py.
                        'note_list' → підсвічує пункт коли юзер на /notes/
                    #}
                </li>
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_create' %}"
                       class="nav-link text-white py-1">
                        <i class="bi bi-plus-circle me-2"></i>Нова нотатка
                    </a>
                </li>
            </ul>
        </div>

        <!-- Записники (з Context Processor) -->
        {% if sidebar_notebooks %}
        <div class="mb-3">
            <small class="text-uppercase text-secondary d-block mb-1 px-2" style="font-size:.7rem">
                Записники
            </small>
            <ul class="nav flex-column">
                {% for nb in sidebar_notebooks %}
                <li class="nav-item">
                    <a href="{% url 'hello_app:note_list' %}?notebook={{ nb.pk }}"
                       class="nav-link text-white-50 py-1 small">
                        <i class="bi bi-journal me-2"></i>
                        {{ nb.title|truncatechars:18 }}
                        {% if nb.note_count %}
                        <span class="badge bg-secondary ms-1 float-end">{{ nb.note_count }}</span>
                        {% endif %}
                    </a>
                </li>
                {% endfor %}
            </ul>
        </div>
        {% endif %}

        <!-- Теги (з Context Processor) -->
        {% if sidebar_tags %}
        <div class="mb-auto">
            <small class="text-uppercase text-secondary d-block mb-2 px-2" style="font-size:.7rem">
                Теги
            </small>
            <div class="d-flex flex-wrap gap-1 px-2">
                {% for tag in sidebar_tags %}
                <a href="{% url 'hello_app:note_list' %}?tag={{ tag.pk }}"
                   class="badge text-decoration-none"
                   style="background-color: {{ tag.color }}; font-size: .75rem;">
                    #{{ tag.name }}
                    {% if tag.note_count %}
                    <span class="ms-1">({{ tag.note_count }})</span>
                    {% endif %}
                </a>
                {% endfor %}
            </div>
        </div>
        {% endif %}

        <!-- Юзер знизу sidebar -->
        <div class="mt-auto pt-3 border-top border-secondary">
            {% if request.user.is_authenticated %}
            <div class="d-flex align-items-center gap-2">
                <div class="rounded-circle bg-primary d-flex align-items-center justify-content-center"
                     style="width:32px; height:32px; flex-shrink:0;">
                    <span class="text-white small fw-bold">
                        {{ request.user.username|first|upper }}
                    </span>
                </div>
                <div class="text-truncate">
                    <div class="text-white small fw-semibold">{{ request.user.username }}</div>
                    <div class="text-white-50" style="font-size:.7rem;">{{ request.user.email }}</div>
                </div>
            </div>
            <form method="post" action="{% url 'logout' %}" class="mt-2">
                {% csrf_token %}
                <button type="submit" class="btn btn-outline-secondary btn-sm w-100">
                    <i class="bi bi-box-arrow-right me-1"></i>Вийти
                </button>
            </form>
            {% endif %}
        </div>

    </nav>
    <!-- ══════════════════ END SIDEBAR ══════════════════ -->

    <!-- ══════════════════ MAIN AREA ══════════════════ -->
    <div class="flex-grow-1 d-flex flex-column overflow-hidden">

        <!-- Topbar -->
        <header class="border-bottom bg-white px-4 py-2 d-flex align-items-center justify-content-between flex-shrink-0">
            <h1 class="h5 mb-0 fw-semibold">
                {% block topbar_title %}CrispyNotes{% endblock %}
            </h1>
            <div class="d-flex align-items-center gap-2">
                <!-- Пошук (опціонально) -->
                {% block topbar_actions %}{% endblock %}
            </div>
        </header>

        <!-- Django Messages -->
        {% if messages %}
        <div class="px-4 pt-2">
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-2" role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
            {% endfor %}
        </div>
        {% endif %}

        <!-- Контент сторінки -->
        <main class="flex-grow-1 overflow-auto p-4">
            {% block content %}{% endblock %}
        </main>

    </div>
    <!-- ══════════════════ END MAIN AREA ══════════════════ -->

</div>
{% endblock %}
```

---

## Крок 4 — Рівень 3: сторінки

Нова сторінка = **5 рядків**. Sidebar і Topbar з'являються безкоштовно.

```html
{# hello_app/templates/hello_app/note_list.html #}
{% extends 'layouts/dashboard.html' %}

{% block title %}Мої нотатки{% endblock %}
{% block topbar_title %}Нотатки{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h2 class="h4 mb-0">
        Нотатки <span class="badge bg-secondary">{{ notes|length }}</span>
    </h2>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary btn-sm">
        <i class="bi bi-plus-lg me-1"></i>Нова
    </a>
</div>

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm border-0">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-start mb-1">
                    <h5 class="card-title mb-0 small fw-semibold">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark">
                            {% if note.is_pinned %}<i class="bi bi-pin-fill text-warning me-1"></i>{% endif %}
                            {{ note.title|truncatechars:45 }}
                        </a>
                    </h5>
                    {% if note.priority == 3 %}
                        <span class="badge bg-danger-subtle text-danger ms-1 flex-shrink-0">Важливо</span>
                    {% elif note.priority == 2 %}
                        <span class="badge bg-warning-subtle text-warning ms-1 flex-shrink-0">Середнє</span>
                    {% endif %}
                </div>
                <p class="card-text text-muted small mt-1">
                    {{ note.content|truncatechars:80 }}
                </p>
                {% if note.tags.all %}
                <div class="mt-2">
                    {% for tag in note.tags.all %}
                    <a href="?tag={{ tag.pk }}"
                       class="badge text-decoration-none me-1"
                       style="background-color: {{ tag.color }};">
                        #{{ tag.name }}
                    </a>
                    {% endfor %}
                </div>
                {% endif %}
            </div>
            <div class="card-footer bg-transparent border-0 pt-0 pb-2 px-3">
                <small class="text-muted">
                    <i class="bi bi-clock me-1"></i>{{ note.updated_at|timesince }} тому
                </small>
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

## Крок 5 — NoteForm з FormHelper

`hello_app/forms.py`:

```python
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Column, Field, Fieldset, HTML, Layout, Row, Submit
from django import forms

from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Обмежуємо queryset тільки даним юзером (IDOR захист)
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user).order_by('title')
            self.fields['tags'].queryset     = Tag.objects.filter(user=user).order_by('name')
            self.fields['notebook'].empty_label = '— без записника —'

        self.helper = FormHelper()
        self.helper.layout = Layout(
            Fieldset('',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
                Field('content', rows=8, placeholder='Текст нотатки...'),
            ),
            Fieldset('Організація',
                Field('tags'),
                Field('is_pinned'),
            ),
            HTML('<hr class="my-3">'),
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
            HTML('<a href="{% url \'hello_app:note_list\' %}" class="btn btn-outline-secondary">Скасувати</a>'),
        )
```

---

## Крок 6 — Context Processor

`hello_app/context_processors.py`:

```python
from . import selectors


def sidebar_context(request):
    """
    Sidebar дані для КОЖНОГО шаблону.
    Виконується автоматично перед кожним render.
    """
    if not request.user.is_authenticated:
        return {}   # AnonymousUser → порожній dict

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags':      selectors.get_user_tags(request.user),
    }
```

---

## Крок 7 — Active state у навігації

```html
{# Підсвітити поточний пункт меню: #}
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white
          {% if request.resolver_match.url_name == 'note_list' %}
          active bg-primary rounded
          {% endif %}">
    Всі нотатки
</a>

{# request.resolver_match.url_name = 'note_list' коли URL = /notes/ #}
{# = 'note_create' коли /notes/new/ #}
{# = 'note_detail' коли /notes/42/ #}

{# Для namespace aware перевірки: #}
{% if request.resolver_match.view_name == 'hello_app:note_list' %}
{# Включає namespace, більш точно #}

{# Для групи URL (наприклад, всі note_* URLs): #}
{% if 'note' in request.resolver_match.url_name %}
{# note_list, note_detail, note_edit → всі підсвічені #}
```

---

## Крок 8 — Реєстрація в settings.py

```python
# hello_project/settings.py

INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
    'hello_app',   # context_processors.sidebar_context тут
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK           = 'bootstrap5'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # Глобальна templates/ (для base.html, layouts/)
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
            'hello_app.context_processors.sidebar_context',   # ← наш processor
            # Тепер sidebar_notebooks і sidebar_tags доступні у ВСІХ шаблонах!
        ],
    },
}]
```

---

## Розташування файлів

```
hello_project/                   ← Корінь проєкту
├── hello_project/
│   ├── settings.py              ← CRISPY_*, TEMPLATES з context_processors
│   └── urls.py
│
├── templates/                   ← Глобальна папка (DIRS у settings)
│   ├── base.html                ← Рівень 1: HTML + Bootstrap CDN
│   └── layouts/
│       └── dashboard.html       ← Рівень 2: Sidebar + Topbar
│
└── hello_app/
    ├── context_processors.py   ← sidebar_context()
    ├── forms.py                 ← NoteForm з FormHelper
    ├── selectors.py
    ├── services.py
    ├── views.py
    └── templates/
        └── hello_app/           ← Рівень 3: сторінки контенту
            ├── note_list.html
            ├── note_form.html   ← {% crispy form %} — 1 рядок!
            ├── note_detail.html
            └── note_confirm_delete.html
```

---

## Як Django знаходить шаблон

```
render(request, 'hello_app/note_list.html', context)
    ↓
Django шукає у DIRS:
  1. BASE_DIR/templates/hello_app/note_list.html → не знайдено

Django шукає у APP_DIRS (кожен INSTALLED_APP):
  2. hello_app/templates/hello_app/note_list.html → ЗНАЙДЕНО ✓

Завантажує note_list.html:
  Зустрічає {% extends 'layouts/dashboard.html' %}

Django шукає layouts/dashboard.html:
  1. BASE_DIR/templates/layouts/dashboard.html → ЗНАЙДЕНО ✓

Завантажує dashboard.html:
  Зустрічає {% extends 'base.html' %}

Django шукає base.html:
  1. BASE_DIR/templates/base.html → ЗНАЙДЕНО ✓

Рендеринг від base.html → dashboard.html → note_list.html
Блоки заповнюються від конкретного до загального.
```

---

## Практичне завдання

1. Відкрий `hello_app/templates/hello_app/note_list.html` → `templates/layouts/dashboard.html` → `templates/base.html`. Відслідкуй ланцюг `{% extends %}`.
2. Додай новий пункт у Sidebar для "Архів" (`/notes/?archived=1`).
3. Перепиши одну форму з ручного Bootstrap HTML на Crispy FormHelper + Layout.
4. Перевір active state: натискаючи різні пункти меню — підсвітка переміщається.
5. Додай Context Processor що передає кількість нових нотаток за сьогодні.

---

## Чеклист самоперевірки

- [ ] 3 рівні: `base.html` → `layouts/dashboard.html` → page template
- [ ] `{% block body %}` у `base.html`, `{% block content %}` у `dashboard.html`
- [ ] Context Processor зареєстрований у `settings.py` → `context_processors`
- [ ] `sidebar_notebooks` і `sidebar_tags` доступні у шаблоні без явної передачі
- [ ] `{% crispy form %}` рендерить форму з Bootstrap-класами
- [ ] `FormHelper.layout` описує структуру форми Python-кодом
- [ ] Active state через `request.resolver_match.url_name`
- [ ] Logout — POST форма (не GET посилання) для захисту від CSRF
- [ ] `DIRS = [BASE_DIR / 'templates']` у `TEMPLATES` — для глобальних шаблонів

---

## Підсумок

| Концепція | Де у коді |
|-----------|-----------|
| 3-рівнева ієрархія | `base.html` → `layouts/dashboard.html` → `note_list.html` |
| `{% block %}` | `{% block content %}{% endblock %}` у батьку + `{% block content %}...{% endblock %}` у дочірньому |
| `{{ block.super }}` | Додає вміст батьківського блоку замість заміни |
| FormHelper | `self.helper = FormHelper()` у `forms.py.__init__` |
| Layout | `Layout(Fieldset(...), Row(Column(...)), Submit(...))` |
| `{% crispy form %}` | У шаблоні — 1 рядок замість 90 |
| Context Processor | `hello_app/context_processors.py → sidebar_context(request)` |
| Реєстрація процесора | `settings.py TEMPLATES OPTIONS context_processors` |
| Active nav | `request.resolver_match.url_name == 'note_list'` |
| Static files | `{% load static %}{% static 'hello_app/css/custom.css' %}` |

---

## Далі

Наступний крок: [05 — Автентифікація та Безпека](05_authentication.md) — Login/logout, sessions, password reset, IDOR, Groups.

Модулі документації:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
- [Application Architecture](../06_application_architecture/README.md)
