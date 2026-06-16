# Template Inheritance

> **"Не повторюй HTML — успадковуй."**
> Django дозволяє будувати шаблони як дерево: батько визначає структуру, дитина — контент.

---

## Template Soup — проблема дублювання

> **"Template Soup"** — коли шаблони містять повторювані блоки HTML:
> `<nav>`, `<header>`, Bootstrap CDN — скопійовані в кожному файлі.
> При зміні навігації → правиш 20 файлів.

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

### Проблема дублювання на рівні шаблонів

```html
<!-- notes_form.html — 80 рядків для 5 полів -->
<div class="mb-3">
  <label for="id_title" class="form-label fw-semibold">
    Заголовок
    <span class="text-danger">*</span>
  </label>
  <input type="text"
         name="title"
         id="id_title"
         class="form-control {% if form.title.errors %}is-invalid{% endif %}"
         autofocus>
  {% if form.title.errors %}
    {% for error in form.title.errors %}
    <div class="invalid-feedback">{{ error }}</div>
    {% endfor %}
  {% endif %}
</div>

<!-- ... повторити для кожного поля ... -->
```

| Проблема | Приклад |
|----------|---------|
| Дублювання | 15 рядків на поле × 6 полів = 90 рядків тільки для форми |
| Зміна класу | Хочеш `form-control-lg` → правиш кожен `<input>` у кожному шаблоні |
| Синхронізація | Додав поле у `models.py` → не забудь оновити шаблон |
| Немає системи | Кожен розробник пише "трошки по-своєму" |

### Рішення: розподіл відповідальності

```
БУЛО (Tier 2):
  forms.py:    поля + widget attrs + validation
  template:    label + input + error + help_text   ← 80 рядків HTML

СТАЛО (Tier 3):
  forms.py:    поля + FormHelper + Layout           ← опис структури Python-кодом
  template:    {% crispy form %}                    ← 1 рядок
```

> **Ключова ідея:** Форма — це **Python об'єкт**. Її структура описується Python-кодом (Layout),
> а не HTML у шаблоні. Шаблон стає тонким — тільки вказує де рендерити.

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

## 3-рівнева ієрархія (SaaS Dashboard паттерн)

```
base.html                          ← Рівень 1: HTML-оболонка
│  Bootstrap CDN, meta, <body>
│  {% block body %}
│
└── layouts/dashboard.html        ← Рівень 2: Макет застосунку
       Sidebar + Topbar
       Django Messages
       {% block content %}
       {% block topbar_title %}
       │
       ├── hello_app/note_list.html       ← Рівень 3: Контент сторінки
       ├── hello_app/note_form.html
       ├── hello_app/notebook_list.html
       └── hello_app/tag_form.html
```

### Що кожен рівень відповідає

| Рівень | Файл | Відповідальність | Змінюється при... |
|--------|------|-----------------|-------------------|
| 1 | `base.html` | HTML5 структура, Bootstrap CDN, Bootstrap JS | Зміна CDN версії, додавання глобального CSS |
| 2 | `layouts/dashboard.html` | Sidebar, Topbar, Messages, SaaS layout | Зміна навігації, нові пункти меню, новий sidebar |
| 3 | `hello_app/*.html` | Специфічний контент сторінки | Логіка конкретної фічі |

---

## Як це виглядає в коді

**`base.html`** — тільки HTML-скелет:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CrispyNotes</title>

  <!-- Bootstrap 5 CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <!-- Bootstrap Icons -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">

  {% block extra_css %}{% endblock %}
</head>
<body>

  {% block body %}{% endblock %}    ← весь застосунок тут

  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  {% block extra_js %}{% endblock %}
</body>
</html>
```

> **Правило:** `base.html` не знає нічого про sidebar, навігацію або контент.
> Він відповідає тільки за: "я правильний HTML5 документ з Bootstrap".

**`layouts/dashboard.html`** — макет (extends base):

```html
{% extends 'base.html' %}
{% block body %}
  <div class="d-flex vh-100">
    <nav><!-- Sidebar --></nav>
    <div class="flex-grow-1">
      <header>{% block topbar_title %}{% endblock %}</header>
      <main>{% block content %}{% endblock %}</main>
    </div>
  </div>
{% endblock %}
```

**`note_list.html`** — сторінка (extends dashboard):

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Мої нотатки{% endblock %}
{% block content %}
  <!-- тільки контент, sidebar/topbar вже є з батька -->
{% endblock %}
```

---

## Потік наслідування

```
Запит /notes/
     │
     ▼
views.note_list()
  └─► render('hello_app/note_list.html', context)
           │
           ▼
      Django Template Engine
           │
      note_list.html extends dashboard.html
           │
      dashboard.html extends base.html
           │
      base.html — кореневий шаблон
           │
           ▼
      Зборка: base → dashboard → note_list → HTML
           │
           ▼
      200 OK  ·  повна HTML сторінка
```

### Як Django знаходить шаблон

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

## Порівняння: з наслідуванням vs без

| | Без наслідування | З 3-рівневою ієрархією |
|--|-----------------|----------------------|
| Нова сторінка | Скопіювати весь HTML | 5 рядків `{% extends %}` + content |
| Зміна навігації | Правити всі файли | Тільки `dashboard.html` |
| Bootstrap CDN | Кожен файл | Тільки `base.html` |
| Sidebar | Копіювати у кожен файл | Один раз у `dashboard.html` |

---

## `{% block.super %}` — правило

```html
{# Якщо дочірній хоче РОЗШИРИТИ блок (не перезаписати): #}
{% block extra_css %}
    {{ block.super }}   {# ← вставляє вміст батьківського блоку #}
    <link rel="stylesheet" href="{% static 'css/notes-editor.css' %}">
{% endblock %}

{# Результат: CSS з layouts/dashboard.html + CSS цієї сторінки #}
{# Без block.super: CSS layouts/dashboard.html буде ЗАМІНЕНИЙ #}
```

> **Правило:** Якщо дочірній шаблон хоче **додати** до батьківського блоку (а не замінити) — використовуй `{{ block.super }}`.
> Якщо хочеш **повністю замінити** — просто пиши у `{% block %}` без `{{ block.super }}`.

---

## `{% block.super %}` — повна механіка

### Замінити vs розширити блок

```html
<!-- base.html -->
{% block extra_css %}
<link rel="stylesheet" href="{% static 'css/global.css' %}">
{% endblock %}

<!-- layouts/dashboard.html -->
{% extends 'base.html' %}
{% block extra_css %}
{{ block.super }}                              {# → вставляє global.css з base.html #}
<link rel="stylesheet" href="{% static 'css/dashboard.css' %}">
{% endblock %}

<!-- note_form.html -->
{% extends 'layouts/dashboard.html' %}
{% block extra_css %}
{{ block.super }}                              {# → global.css + dashboard.css з батьків #}
<link rel="stylesheet" href="{% static 'notes_app/css/editor.css' %}">
{% endblock %}
```

**Результат у браузері (порядок CSS):**
```html
<link rel="stylesheet" href="/static/css/global.css">       <!-- base.html -->
<link rel="stylesheet" href="/static/css/dashboard.css">    <!-- dashboard.html -->
<link rel="stylesheet" href="/static/notes_app/css/editor.css"> <!-- note_form.html -->
```

**Без `{{ block.super }}`:**
```html
<!-- note_form.html БЕЗ block.super: -->
{% block extra_css %}
<link rel="stylesheet" href="{% static 'notes_app/css/editor.css' %}">
{% endblock %}

{# Результат: тільки editor.css — global.css і dashboard.css ВІДСУТНІ! #}
```

### Коли НЕ потрібен block.super

```html
<!-- note_list.html — повністю замінюємо блок topbar_title -->
{% block topbar_title %}
    Мої нотатки
{% endblock %}
{# dashboard.html має {% block topbar_title %}Застосунок{% endblock %} — замінюємо повністю #}
{# block.super тут не потрібен — батьківський контент нас не цікавить #}
```

**Правило вибору:**

| Хочу... | Що писати |
|---------|-----------|
| Повністю замінити вміст блоку | Просто `{% block %}`...`{% endblock %}` |
| Додати до вмісту батька | `{{ block.super }}` + новий контент |
| Передати батьківський контент без змін | `{{ block.super }}` (весь блок) |

---

## Коли `{% extends %}` не спрацьовує — помилки та причини

### Помилка 1: TemplateSyntaxError — extends не перший тег

```
TemplateSyntaxError at /notes/
The 'extends' tag is the first tag in the template.
```

```html
<!-- ❌ ПРИЧИНА: перед {% extends %} є інший тег або навіть пробіл/рядок -->
{% load static %}   {# ← ЦЕ ПОМИЛКА! load перед extends #}
{% extends 'base.html' %}

<!-- ✅ РІШЕННЯ: extends завжди першим рядком -->
{% extends 'base.html' %}
{% load static %}   {# load — після extends #}
```

**Правило:** `{% extends %}` **мусить бути першим тегом** у шаблоні. Навіть `{% load %}` — після нього.

### Помилка 2: TemplateDoesNotExist

```
TemplateDoesNotExist: layouts/dashboard.html
```

**Можливі причини:**

```python
# 1. TEMPLATES не налаштовані правильно у settings.py
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # ← цей рядок обов'язковий для проектних шаблонів
    'APP_DIRS': True,                   # ← True = шукати у app/templates/
    'OPTIONS': {'context_processors': [...]}
}]

# 2. Файл є, але в неправильному місці
# ❌ НЕПРАВИЛЬНО:
myproject/hello_app/templates/layouts/dashboard.html  # ← шукається як 'layouts/dashboard.html' ✓

# ✅ ПРАВИЛЬНО для проектних шаблонів:
myproject/templates/layouts/dashboard.html   # ← якщо BASE_DIR/templates в DIRS

# 3. Тип ОС (Linux ≠ Windows): регістр має значення
# base.HTML ≠ base.html на Linux
```

### Помилка 3: Блоки не відображаються — вміст зникає

```html
<!-- ❌ ПРИЧИНА: назви блоків не збігаються -->

<!-- base.html -->
{% block main_content %}{% endblock %}   ← 'main_content'

<!-- note_list.html -->
{% extends 'base.html' %}
{% block content %}                       ← 'content' — інша назва!
    Цей вміст НІКОЛИ не відобразиться
{% endblock %}
```

```html
<!-- ✅ РІШЕННЯ: однакові назви у батьку і дитині -->
<!-- base.html -->
{% block content %}{% endblock %}

<!-- note_list.html -->
{% extends 'base.html' %}
{% block content %}
    Тепер відображається!
{% endblock %}
```

### Помилка 4: Контент поза блоками ігнорується

```html
{% extends 'base.html' %}

<h1>Цей заголовок НІКОЛИ не відобразиться</h1>   {# ← поза блоком = ігнорується #}

{% block content %}
    <p>Це відображається.</p>
{% endblock %}

<footer>Це теж ігнорується</footer>   {# ← поза блоком = ігнорується #}
```

> **Правило:** У шаблоні що uses `{% extends %}` — весь контент **мусить** бути всередині `{% block %}`. Все що поза блоками — ігнорується Django Template Engine.

---

## `{% include %}` vs `{% extends %}`

Два механізми повторного використання шаблонів — для різних задач.

| | `{% extends %}` | `{% include %}` |
|-|----------------|-----------------|
| **Для чого** | Сторінка успадковує структуру батька | Вставити шматок HTML у поточний шаблон |
| **Кількість** | Один батько (один `extends`) | Без обмежень |
| **Контекст** | Успадковується автоматично | Успадковується + можна передати окремий |
| **Блоки** | `{% block %}` / `{% endblock %}` | Немає |
| **Приклад** | `note_list.html extends dashboard.html` | Компонент картки нотатки у циклі |

```html
<!-- ✅ include — для повторюваних компонентів -->

{# note_list.html #}
{% for note in notes %}
    {% include 'notes_app/components/_note_card.html' with note=note %}
{% endfor %}

{# _note_card.html — ізольований компонент картки #}
<div class="card mb-3">
    <div class="card-body">
        <h5 class="card-title">{{ note.title }}</h5>
        <p class="card-text">{{ note.content|truncatewords:20 }}</p>
    </div>
</div>
```

**`with` у `{% include %}`** — передати додаткові змінні у контекст компоненту. Компонент також має доступ до загального контексту шаблону (всі змінні з `render(context)`).

---

## TEMPLATES налаштування у settings.py

```python
# settings.py
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',

    # DIRS — де шукати шаблони ПОЗА додатками (проектні шаблони)
    # Тут живуть: base.html, layouts/, registration/ тощо
    'DIRS': [BASE_DIR / 'templates'],

    # APP_DIRS = True — Django автоматично шукає у кожному INSTALLED_APP
    # в директорії: app_name/templates/
    # Тут живуть: notes_app/templates/notes_app/*.html
    'APP_DIRS': True,

    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ],
    },
}]
```

**Порядок пошуку шаблону `'notes_app/note_list.html'`:**

```
1. BASE_DIR/templates/notes_app/note_list.html   ← DIRS (перший)
2. notes_app/templates/notes_app/note_list.html  ← APP_DIRS (якщо не знайдено у DIRS)

Конвенція: app-шаблони → app/templates/app_name/file.html
           проектні шаблони → BASE_DIR/templates/file.html
```

---

## Структура директорій у проєкті

```
notes_chat_app/
├── templates/                ← DIRS у TEMPLATES[0]['DIRS']
│   ├── base.html             ← Рівень 1
│   ├── layouts/
│   │   └── dashboard.html   ← Рівень 2
│   └── registration/
│       ├── login.html
│       └── signup.html
│
└── notes_app/
    └── templates/
        └── notes_app/        ← namespace: щоб уникнути конфліктів між apps
            ├── note_list.html
            ├── note_detail.html
            ├── note_form.html
            └── components/
                └── _note_card.html
```

**Чому namespace `notes_app/templates/notes_app/`?**

Без namespace: якщо два додатки мають `note_list.html`, Django знайде перший з `INSTALLED_APPS`. З namespace `notes_app/note_list.html` — завжди правильний файл.

---

## У книзі

- [Частина V. Frontend і шаблони](../../05_frontend_and_templates/README.md) — Django Template Language повністю: теги, фільтри, `{% load %}`, `{% static %}`, context processors

---

## Офіційна документація

- [Django: Template inheritance](https://docs.djangoproject.com/en/5.2/ref/templates/language/#template-inheritance) — `{% extends %}`, `{% block %}`, `{{ block.super }}`
- [Django: Built-in template tags](https://docs.djangoproject.com/en/5.2/ref/templates/builtins/) — `{% include %}`, `{% load %}`, `{% static %}`
- [Django: TEMPLATES settings](https://docs.djangoproject.com/en/5.2/ref/settings/#templates) — DIRS, APP_DIRS, context_processors
- [Django: Template loaders](https://docs.djangoproject.com/en/5.2/ref/templates/api/#loader-types) — як Django знаходить шаблони
