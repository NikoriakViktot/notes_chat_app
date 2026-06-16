# Dashboard Architecture

> **SaaS Dashboard** — UI-паттерн для застосунків:
> фіксований sidebar зліва, topbar зверху, scrollable контент по центру.
> Gmail, Notion, Linear — всі побудовані на цьому паттерні.

---

## Структура Dashboard

```
┌──────────┬───────────────────────────────────────────────────┐
│          │  Topbar: заголовок / пошук / юзер-dropdown        │
│ Sidebar  ├───────────────────────────────────────────────────┤
│          │                                                   │
│ Бренд    │  ← {% block content %}                            │
│ ─────    │                                                   │
│ НОТАТКИ  │  Нотатки / Форма / Записники / Задачі...         │
│  Записн. │                                                   │
│  Всі     │                                                   │
│  + Нова  │                                                   │
│ ЗАДАЧІ   │                                                   │
│  Справи  │                                                   │
│  Покупки │                                                   │
│ ─────    │                                                   │
│ [Запис.] │  (якщо є)                                         │
│ ТЕГИ     │                                                   │
│  + Новий │                                                   │
└──────────┴───────────────────────────────────────────────────┘
```

### Дерево файлів Dashboard

```
crispy_notes_project/
└── templates/
    ├── base.html                   ← Рівень 1: HTML5 + Bootstrap CDN
    └── layouts/
        └── dashboard.html          ← Рівень 2: Sidebar + Topbar + Messages
```

---

## Sidebar Context Processor

Sidebar показує **записники** і **теги** — вони потрібні на КОЖНІЙ сторінці.
Але передавати їх з кожного view вручну — це дублювання:

```python
# ❌ Погано — дублювання у кожному view
def note_list(request):
    notes = selectors.get_user_notes(request.user)
    notebooks = selectors.get_user_notebooks(request.user)  # дублювання
    tags = selectors.get_user_tags(request.user)            # дублювання
    return render(request, '...', {'notes': notes, 'notebooks': notebooks, 'tags': tags})

def note_create(request):
    notebooks = selectors.get_user_notebooks(request.user)  # дублювання знову
    tags = selectors.get_user_tags(request.user)            # дублювання знову
    ...
```

**Рішення** — `context_processors.py`:

```python
# ✅ Добре — один раз, автоматично для всіх views
def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}
    return {
        'sidebar_notebooks': selectors.get_user_notebooks(request.user),
        'sidebar_tags': selectors.get_user_tags(request.user),
    }
```

```python
# settings.py — реєструємо процесор
TEMPLATES = [{
    'OPTIONS': {
        'context_processors': [
            ...
            'hello_app.context_processors.sidebar_context',  # ← тут
        ]
    }
}]
```

Тепер `{{ sidebar_notebooks }}` і `{{ sidebar_tags }}` доступні **в кожному шаблоні** автоматично.

---

## Active State у навігації

```html
<!-- Підсвічуємо активний пункт меню через request.resolver_match -->
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
  Всі нотатки
</a>
```

`request.resolver_match.url_name` повертає ім'я поточного URL — без додаткових змінних у View.

---

## Повний код `layouts/dashboard.html`

**Місце:** `crispy_notes_project/templates/layouts/dashboard.html`

Рівень 2 ієрархії. Він:

- Extends `base.html`
- Заповнює `{% block body %}` повною Dashboard-розміткою
- Надає два слоти для дочірніх шаблонів:
  - `{% block topbar_title %}` — заголовок у topbar
  - `{% block content %}` — основний контент сторінки

```html
{% extends 'base.html' %}
{% load static %}

{% block body %}
<div class="d-flex vh-100 overflow-hidden">

  <!-- ════════════════════ SIDEBAR ════════════════════ -->
  <nav id="sidebar" class="sidebar d-flex flex-column p-3 text-bg-dark" style="width: 260px;">

    <!-- Бренд -->
    <a href="{% url 'hello_app:note_list' %}" class="d-flex align-items-center text-white mb-3">
      <i class="bi bi-journal-text fs-4 me-2"></i>
      <span class="fs-5 fw-semibold">CrispyNotes</span>
    </a>
    <hr>

    <!-- НОТАТКИ section -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Нотатки</p>
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:notebook_list' %}"
           class="nav-link {% if 'notebook' in request.resolver_match.url_name %}active{% endif %}">
          <i class="bi bi-collection me-2"></i>Записники
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:note_list' %}"
           class="nav-link {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
          <i class="bi bi-journal-text me-2"></i>Всі нотатки
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:note_create' %}"
           class="nav-link {% if request.resolver_match.url_name == 'note_create' %}active{% endif %}">
          <i class="bi bi-plus-circle me-2"></i>Нова нотатка
        </a>
      </li>
    </ul>

    <!-- ЗАДАЧІ section -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Задачі</p>
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:todo_list' %}"
           class="nav-link d-flex justify-content-between {% if 'todo' in request.resolver_match.url_name %}active{% endif %}">
          <span><i class="bi bi-check2-square me-2"></i>Список справ</span>
          {% if sidebar_todo_count %}
          <span class="badge bg-primary rounded-pill">{{ sidebar_todo_count }}</span>
          {% endif %}
        </a>
      </li>
      <li>
        <a href="{% url 'hello_app:shopping_list' %}"
           class="nav-link d-flex justify-content-between {% if 'shopping' in request.resolver_match.url_name %}active{% endif %}">
          <span><i class="bi bi-cart me-2"></i>Покупки</span>
          {% if sidebar_shopping_count %}
          <span class="badge bg-secondary rounded-pill">{{ sidebar_shopping_count }}</span>
          {% endif %}
        </a>
      </li>
    </ul>
    <hr>

    <!-- Записники (список, з sidebar_context — context processor!) -->
    {% if sidebar_notebooks %}
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Записники</p>
    <ul class="nav nav-pills flex-column mb-3">
      {% for nb in sidebar_notebooks %}
      <li>
        <a href="{% url 'hello_app:note_list' %}?notebook={{ nb.pk }}"
           class="nav-link py-1 d-flex justify-content-between">
          <span><span style="color: {{ nb.color }};">●</span> {{ nb.title|truncatechars:18 }}</span>
          <span class="badge bg-secondary">{{ nb.note_count }}</span>
        </a>
      </li>
      {% endfor %}
    </ul>
    {% endif %}

    <!-- ТЕГИ section (завжди видимий header) -->
    <p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Теги</p>
    {% if sidebar_tags %}
    <div class="px-2 mb-2 d-flex flex-wrap gap-1">
      {% for tag in sidebar_tags %}
      <a href="{% url 'hello_app:note_list' %}?tag={{ tag.pk }}"
         class="badge text-decoration-none"
         style="background-color: {{ tag.color }}; color: white;">
        #{{ tag.name }}
      </a>
      {% endfor %}
    </div>
    {% endif %}
    <ul class="nav nav-pills flex-column mb-3">
      <li>
        <a href="{% url 'hello_app:tag_create' %}" class="nav-link">
          <i class="bi bi-tags me-2"></i>Новий тег
        </a>
      </li>
    </ul>
  </nav>
  <!-- /SIDEBAR -->

  <!-- ════════════════════ MAIN ════════════════════ -->
  <div class="d-flex flex-column flex-grow-1 overflow-auto">

    <!-- TOPBAR: заголовок | пошук | юзер-dropdown -->
    <header class="topbar d-flex align-items-center px-4 py-2">
      <h6 class="mb-0 me-auto fw-semibold">
        {% block topbar_title %}Нотатки{% endblock %}   ← дочірні шаблони підставляють заголовок
      </h6>
      <form class="d-flex me-3" method="get" action="{% url 'hello_app:note_list' %}">
        <input type="search" name="q" class="form-control form-control-sm" placeholder="Пошук нотаток...">
        <button class="btn btn-sm btn-outline-secondary ms-1" type="submit">
          <i class="bi bi-search"></i>
        </button>
      </form>
      <!-- Профіль / Вихід (dropdown праворуч) -->
      <div class="dropdown">
        <a href="#" class="d-flex align-items-center text-decoration-none dropdown-toggle"
           data-bs-toggle="dropdown">
          <i class="bi bi-person-circle fs-5 me-1"></i>
          <span class="small fw-semibold">{{ request.user.username }}</span>
        </a>
        <ul class="dropdown-menu dropdown-menu-dark dropdown-menu-end shadow">
          <li><a class="dropdown-item" href="{% url 'hello_app:notebook_list' %}">Мої записники</a></li>
          <li><hr class="dropdown-divider"></li>
          <li>
            <form method="post" action="{% url 'logout' %}">
              {% csrf_token %}
              <button type="submit" class="dropdown-item text-danger">Вийти</button>
            </form>
          </li>
        </ul>
      </div>
    </header>

    <!-- Django Messages → Bootstrap Alerts -->
    {% if messages %}
    <div class="px-4 pt-3">
      {% for message in messages %}
      <div class="alert alert-{{ message.tags }} alert-dismissible fade show">
        {{ message }}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
      {% endfor %}
    </div>
    {% endif %}

    <!-- PAGE CONTENT -->
    <main class="flex-grow-1 p-4">
      {% block content %}{% endblock %}   ← дочірні шаблони підставляють контент
    </main>

  </div>
  <!-- /MAIN -->

</div>
{% endblock %}
```

---

## Сторінки (Рівень 3)

**Місце:** `hello_app/templates/hello_app/`

Дочірні шаблони (рівень 3) пишуть **тільки контент**. Sidebar, topbar, Bootstrap — безкоштовно.

**Приклад `note_list.html`:**

```html
{% extends 'layouts/dashboard.html' %}

{% block topbar_title %}Мої нотатки{% endblock %}    ← тільки заголовок

{% block content %}
{# Тільки контент сторінки — sidebar/topbar вже є #}

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 g-3">
  {% for note in notes %}
  <div class="col">
    <div class="card h-100">
      ...
    </div>
  </div>
  {% endfor %}
</div>
{% else %}
  {% include 'components/empty_state.html' with icon="bi-journal" message="Ще немає нотаток" %}
{% endif %}

{% endblock %}
```

**Приклад `note_list.html` повний:**

```html
{% extends 'layouts/dashboard.html' %}

{% block topbar_title %}Мої нотатки{% endblock %}

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

## Навігація

- Попередня: [Crispy Forms](crispy_forms.md)
- Наступна: [Context Processor](context_processor.md)
