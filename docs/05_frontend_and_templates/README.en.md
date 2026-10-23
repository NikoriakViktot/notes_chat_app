# Part V. Templates and Frontend

The Django Template Language (DTL) turns a Python context into HTML. Bootstrap 5 provides a ready-made UI system. This part covers the entire frontend stack of Notes Chat App: from `base.html` to the WebSocket JS client.

**Prerequisites:** Part II (Django Core).
**Level:** Beginner → Intermediate.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [HTML Basics](html_basics_full.md) | semantic markup, forms, tables, attributes |
| [CSS Basics](css_basics_full.md) | box model, flexbox, grid, variables, media queries |
| [Django Templates](django_templates_full.md) | DTL syntax, `{% extends %}`, `{% block %}`, `{% include %}`, `{{ var }}`, filters |
| [Advanced Templates](advanced_templates_full.md) | custom template tags, context processors, `{% load %}` |
| [Bootstrap 5](bootstrap_5_full.md) | grid, utilities, components (card, modal, navbar, alert) |
| [Django Admin](django_admin_full.md) | registering models, `list_display`, `search_fields`, `inlines` |
| [Django Admin Unfold](django_admin_unfold_full.md) | a modernized admin with Unfold |
| [Design Foundations](design_foundations_full.md) | color, typography, spacing, UX principles |

---

## Key concepts

**Three-level template inheritance in Notes Chat App:**

```
templates/base.html
  ← templates/layouts/dashboard.html
      ← notes_app/templates/notes_app/note_list.html

# base.html: DOCTYPE, head, navbar, messages, {% block content %}
# dashboard.html: {% extends 'base.html' %} + sidebar, content block
# note_list.html: {% extends 'layouts/dashboard.html' %} + the specific content
```

**DTL syntax:**

```django
{# Variable #}
{{ note.title }}
{{ note.title|truncatechars:50 }}
{{ note.created_at|date:"d M Y" }}

{# Control flow #}
{% if note.is_pinned %}📌{% endif %}
{% for note in notes %}{{ note.title }}{% empty %}Нотаток немає{% endfor %}

{# Template inheritance #}
{% extends 'layouts/dashboard.html' %}
{% block content %}
  <h1>{{ note.title }}</h1>
{% endblock %}

{# Include partial #}
{% include 'notes_app/_note_card.html' with note=note %}

{# URL reverse #}
<a href="{% url 'notes_app:note_edit' note.pk %}">Редагувати</a>
```

**Static files:**

```django
{% load static %}
<link rel="stylesheet" href="{% static 'notes_app/css/style.css' %}">
<script src="{% static 'notes_app/js/group_chat.js' %}"></script>
```

```python
# settings.py
STATIC_URL  = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'   # for collectstatic in prod
STATICFILES_DIRS = [BASE_DIR / 'notes_app' / 'static']  # dev
```

**Context processor — variables available automatically in every template:**

```python
# settings.py TEMPLATES → context_processors:
'django.contrib.auth.context_processors.auth',    # {{ user }}, {{ perms }}
'django.contrib.messages.context_processors.messages',  # {{ messages }}
'django.template.context_processors.request',     # {{ request }}
```

---

## Where this lives in Notes Chat App

| File / Folder | What it shows |
|--------------|-----------|
| `templates/base.html` | DOCTYPE, navbar, Bootstrap 5 CDN, messages |
| `templates/layouts/dashboard.html` | sidebar with links, `{% block content %}` |
| `notes_app/templates/notes_app/` | the specific templates: `note_list.html`, `note_detail.html`, ... |
| `notes_app/static/notes_app/js/group_chat.js` | WebSocket JS client: `new WebSocket()`, `onmessage` |
| `notes_app/static/notes_app/css/` | custom styles (if any) |

**WebSocket JS client (key fragment):**

```javascript
// group_chat.js
const ws = new WebSocket(`wss://${location.host}/ws/groups/${groupPk}/chat/`);

ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    if (data.type === 'history') {
        // render historical messages
    } else if (data.type === 'chat_message') {
        appendMessage(data.author, data.content, data.timestamp);
    }
};

function appendMessage(author, content, timestamp) {
    const div = document.createElement('div');
    // ✅ textContent — safe from XSS (not innerHTML!)
    div.textContent = `${author}: ${content}`;
    chatBox.appendChild(div);
}
```

---

## How it connects to the rest of the course

```text
Part V: Template render → HTML (static content)
Part IX: WebSocket → JS client → real-time updates (group_chat.js)

collectstatic (Part V) → Nginx serves /static/ (Part X)
```

**Zero to Hero:** Step 4 (crispy_notes) — a Bootstrap 5 SaaS dashboard, template inheritance.

---

## Practice

1. Open `templates/base.html` → trace the `{% block %}` chain down to `note_list.html`.
2. Add a new `{% block %}` in `dashboard.html` for a sidebar badge (the number of notes).
3. Create a custom template filter `{% load note_extras %}` → `{{ note.title|shorten }}`.
4. Run `docker compose exec web python manage.py collectstatic --noinput` → look through `staticfiles/`.

---

## Review questions

- What is the difference between `{% extends %}` and `{% include %}`?
- Why is `{% url 'notes_app:note_edit' note.pk %}` better than a hard-coded `/notes/42/edit/`?
- What is a context processor? Where does `{{ user }}` in a template come from?
- Why do you need `collectstatic` in production? Who serves static files in Notes Chat App?
- Why does `group_chat.js` use `textContent` rather than `innerHTML`? (XSS!)
- Where should templates live — in `templates/` or in `notes_app/templates/notes_app/`? What is the difference?

---

**Next →** [Part VI. Application Architecture](../06_application_architecture/README.md) — how to split responsibilities between layers.
