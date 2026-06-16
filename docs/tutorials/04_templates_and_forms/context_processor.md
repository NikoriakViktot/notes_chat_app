# Context Processor

> **Проблема:** Sidebar показує список записників і тегів на КОЖНІЙ сторінці.
> Якщо передавати їх з кожного view — дублювання коду у 20 місцях.

---

## Як Context Processors працюють

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

---

## Написати Context Processor — повний код `context_processors.py`

```python
# hello_app/context_processors.py
from django.db import OperationalError
from django.db.models import Q
from .models import TodoList, ShoppingList
from . import selectors


def sidebar_context(request):
    """
    Автоматично додає sidebar_notebooks, sidebar_tags і лічильники задач у кожен шаблон.
    Виконується при кожному запиті для автентифікованих користувачів.
    """
    if not request.user.is_authenticated:
        return {
            'sidebar_notebooks': [], 'sidebar_tags': [],
            'sidebar_todo_count': 0, 'sidebar_shopping_count': 0,
        }

    user = request.user

    # try/except — захист якщо міграція ще не застосована (нові M2M таблиці)
    try:
        todo_count = TodoList.objects.filter(
            Q(user=user) | Q(shared_with=user), is_completed=False
        ).distinct().count()
        shopping_count = ShoppingList.objects.filter(
            Q(user=user) | Q(shared_with=user)
        ).distinct().count()
    except OperationalError:
        todo_count = 0
        shopping_count = 0

    return {
        'sidebar_notebooks': selectors.get_user_notebooks(user),
        'sidebar_tags': selectors.get_user_tags(user),
        'sidebar_todo_count': todo_count,       # ← badge у "Список справ"
        'sidebar_shopping_count': shopping_count,  # ← badge у "Покупки"
    }
```

> **Навіщо `try/except OperationalError`?**
> Context processor виконується при **кожному** запиті. Якщо міграція для нової таблиці
> ще не застосована (наприклад, під час розробки після `git pull`), QuerySet впаде з
> `OperationalError: no such table`. Guard дозволяє серверу продовжити роботу — лічильники
> просто повернуть 0 замість 500 помилки.

---

## Реєстрація в `settings.py`

```python
# hello_project/settings.py
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

**Використання у будь-якому шаблоні (без передачі з View):**

```html
{% for nb in sidebar_notebooks %}
  <a href="?notebook={{ nb.pk }}">{{ nb.title }}</a>
{% endfor %}
```

---

## Active nav state: `request.path`

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

## Коли НЕ використовувати context_processor

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

> **Важливо:** Context processor виконується при **кожному** HTTP запиті.
> Тому selector повинен бути ефективним — `select_related`, `annotate`, не N+1.

---

## Static Files: де Django шукає статику

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

## Навігація

- Попередня: [Dashboard Architecture](dashboard_architecture.md)
- Наступна: [Components](components.md)
