# Context Processor

> **Problem:** The sidebar shows the list of notebooks and tags on EVERY page.
> If you pass them from every view, the code is duplicated in 20 places.

---

## How Context Processors work

```
HTTP Request
    ↓
Middleware pipeline
    ↓
View function (view_func)
    ↓
render(request, 'template.html', {'notes': notes})  ← view context
    ↓
Django Template Engine:
    1. Collects the context from the view: {'notes': notes}
    2. AUTOMATICALLY runs every context_processor(request) from settings.py
    3. Merged context = view context + processor contexts
    4. Renders the template with the merged context

All context_processors:
  django.template.context_processors.debug  → {{ debug }}
  django.template.context_processors.request → {{ request }}
  django.contrib.auth.context_processors.auth → {{ user }}, {{ perms }}
  django.contrib.messages.context_processors.messages → {{ messages }}
  hello_app.context_processors.sidebar_context → {{ sidebar_notebooks }}, {{ sidebar_tags }}
```

---

## Writing a Context Processor — the full `context_processors.py` code

```python
# hello_app/context_processors.py
from django.db import OperationalError
from django.db.models import Q
from .models import TodoList, ShoppingList
from . import selectors


def sidebar_context(request):
    """
    Automatically adds sidebar_notebooks, sidebar_tags and task counters to every template.
    Runs on every request for authenticated users.
    """
    if not request.user.is_authenticated:
        return {
            'sidebar_notebooks': [], 'sidebar_tags': [],
            'sidebar_todo_count': 0, 'sidebar_shopping_count': 0,
        }

    user = request.user

    # try/except — protection in case the migration has not been applied yet (new M2M tables)
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
        'sidebar_todo_count': todo_count,       # ← badge in "To-do lists"
        'sidebar_shopping_count': shopping_count,  # ← badge in "Shopping"
    }
```

> **Why `try/except OperationalError`?**
> A context processor runs on **every** request. If the migration for a new table
> has not been applied yet (for example, during development after `git pull`), the QuerySet fails with
> `OperationalError: no such table`. The guard lets the server keep working — the counters
> simply return 0 instead of a 500 error.

---

## Registering it in `settings.py`

```python
# hello_project/settings.py
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],   # Global templates/ (for base.html, layouts/)
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
            'hello_app.context_processors.sidebar_context',   # ← our processor
            # Now sidebar_notebooks and sidebar_tags are available in ALL templates!
        ],
    },
}]
```

**Usage in any template (without passing it from the View):**

```html
{% for nb in sidebar_notebooks %}
  <a href="?notebook={{ nb.pk }}">{{ nb.title }}</a>
{% endfor %}
```

---

## Active nav state: `request.path`

```html
{# Highlight the current menu item: #}
<a href="{% url 'hello_app:note_list' %}"
   class="nav-link text-white
          {% if request.resolver_match.url_name == 'note_list' %}
          active bg-primary rounded
          {% endif %}">
    Всі нотатки
</a>

{# request.resolver_match.url_name = 'note_list' when URL = /notes/ #}
{# = 'note_create' when /notes/new/ #}
{# = 'note_detail' when /notes/42/ #}

{# For a namespace-aware check: #}
{% if request.resolver_match.view_name == 'hello_app:note_list' %}
{# Includes the namespace, more precise #}

{# For a group of URLs (for example, all note_* URLs): #}
{% if 'note' in request.resolver_match.url_name %}
{# note_list, note_detail, note_edit → all highlighted #}
```

---

## When NOT to use a context_processor

```python
# Do not use a context_processor for:
# 1. Heavy SQL queries (they run on EVERY page)
# 2. Variables specific to a single page (pass them in the render context)
# 3. Data that needs URL parameters (url kwargs are not available)

# For a heavy sidebar: caching
from django.core.cache import cache

def sidebar_context(request):
    if not request.user.is_authenticated:
        return {}

    cache_key = f'sidebar_notebooks_{request.user.id}'
    notebooks = cache.get(cache_key)
    if notebooks is None:
        notebooks = list(selectors.get_user_notebooks(request.user))
        cache.set(cache_key, notebooks, timeout=300)  # 5 minutes

    return {'sidebar_notebooks': notebooks}
```

> **Important:** A context processor runs on **every** HTTP request.
> So the selector must be efficient — `select_related`, `annotate`, no N+1.

---

## Static Files: where Django looks for static files

```
1. APP_DIRS (STATICFILES_FINDERS):
   hello_app/static/hello_app/style.css
   → URL: /static/hello_app/style.css

2. STATICFILES_DIRS in settings.py:
   BASE_DIR / 'static'
   → The global static/ folder

3. collectstatic (production):
   python manage.py collectstatic
   → Copies into STATIC_ROOT → served by nginx
```

### Adding your own CSS

```python
# settings.py:
STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']   # Global folder for development
STATIC_ROOT = BASE_DIR / 'staticfiles'     # Production: collectstatic
```

```html
{# In the template: #}
{% load static %}
<link rel="stylesheet" href="{% static 'hello_app/css/custom.css' %}">
<img src="{% static 'hello_app/images/logo.png' %}" alt="Logo">
<script src="{% static 'hello_app/js/notes.js' %}"></script>

{# {% static 'path' %} generates: /static/path #}
{# In production (with a CDN): it may generate https://cdn.example.com/static/path #}
```

---

## Navigation

- Previous: [Dashboard Architecture](dashboard_architecture.md)
- Next: [Components](components.md)
