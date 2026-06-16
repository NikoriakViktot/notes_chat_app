# Частина V. Templates і Frontend

Django Template Language (DTL) перетворює Python-контекст на HTML. Bootstrap 5 дає готову UI-систему. Ця частина охоплює весь frontend-стек Notes Chat App: від `base.html` до WebSocket JS-клієнта.

**Передумови:** Частина II (Django Core).
**Рівень:** Beginner → Intermediate.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [HTML основи](html_basics_full.md) | семантична розмітка, форми, таблиці, атрибути |
| [CSS основи](css_basics_full.md) | box model, flexbox, grid, змінні, media queries |
| [Django Templates](django_templates_full.md) | DTL синтаксис, `{% extends %}`, `{% block %}`, `{% include %}`, `{{ var }}`, фільтри |
| [Advanced Templates](advanced_templates_full.md) | custom template tags, context processors, `{% load %}` |
| [Bootstrap 5](bootstrap_5_full.md) | grid, утиліти, компоненти (card, modal, navbar, alert) |
| [Django Admin](django_admin_full.md) | реєстрація моделей, `list_display`, `search_fields`, `inlines` |
| [Django Admin Unfold](django_admin_unfold_full.md) | модернізований admin з Unfold |
| [Дизайн-основи](design_foundations_full.md) | колір, типографіка, відступи, UX-принципи |

---

## Ключові концепти

**Трирівнева template inheritance у Notes Chat App:**

```
templates/base.html
  ← templates/layouts/dashboard.html
      ← notes_app/templates/notes_app/note_list.html

# base.html: DOCTYPE, head, navbar, messages, {% block content %}
# dashboard.html: {% extends 'base.html' %} + sidebar, content block
# note_list.html: {% extends 'layouts/dashboard.html' %} + конкретний контент
```

**DTL синтаксис:**

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
<a href="{% url 'note_edit' note.pk %}">Редагувати</a>
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
STATIC_ROOT = BASE_DIR / 'staticfiles'   # для collectstatic в prod
STATICFILES_DIRS = [BASE_DIR / 'notes_app' / 'static']  # dev
```

**Context processor — автоматичні змінні у всіх шаблонах:**

```python
# settings.py TEMPLATES → context_processors:
'django.contrib.auth.context_processors.auth',    # {{ user }}, {{ perms }}
'django.contrib.messages.context_processors.messages',  # {{ messages }}
'django.template.context_processors.request',     # {{ request }}
```

---

## Де це у Notes Chat App

| Файл / Папка | Що показує |
|--------------|-----------|
| `templates/base.html` | DOCTYPE, navbar, Bootstrap 5 CDN, messages |
| `templates/layouts/dashboard.html` | sidebar з посиланнями, `{% block content %}` |
| `notes_app/templates/notes_app/` | конкретні шаблони: `note_list.html`, `note_detail.html`, ... |
| `notes_app/static/notes_app/js/group_chat.js` | WebSocket JS-клієнт: `new WebSocket()`, `onmessage` |
| `notes_app/static/notes_app/css/` | кастомні стилі (якщо є) |

**WebSocket JS-клієнт (key fragment):**

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
    // ✅ textContent — безпечно від XSS (не innerHTML!)
    div.textContent = `${author}: ${content}`;
    chatBox.appendChild(div);
}
```

---

## Педагогічний зв'язок

```text
Частина V: Template render → HTML (статичний контент)
Частина IX: WebSocket → JS-клієнт → real-time оновлення (group_chat.js)

collectstatic (Частина V) → Nginx роздає /static/ (Частина X)
```

**Zero to Hero:** Крок 4 (crispy_notes) — Bootstrap 5 SaaS dashboard, template inheritance.

---

## Практика

1. Відкрий `templates/base.html` → прослідкуй `{% block %}` ланцюжок до `note_list.html`.
2. Додай новий `{% block %}` у `dashboard.html` для sidebar badge (кількість нотаток).
3. Створи custom template filter `{% load note_extras %}` → `{{ note.title|shorten }}`.
4. Запусти `docker compose exec web python manage.py collectstatic --noinput` → переглянь `staticfiles/`.

---

## Контрольні питання

- Яка різниця між `{% extends %}` і `{% include %}`?
- Чому `{% url 'note_edit' note.pk %}` краще ніж hard-coded `/notes/42/edit/`?
- Що таке context processor? Де визначається `{{ user }}` у шаблоні?
- Навіщо `collectstatic` у production? Хто роздає static файли у Notes Chat App?
- Чому у `group_chat.js` використовується `textContent` а не `innerHTML`? (XSS!)
- Де зберігати шаблони — у `templates/` чи в `notes_app/templates/notes_app/`? Яка різниця?

---

**Далі →** [Частина VI. Архітектура застосунку](../06_application_architecture/README.md) — як розділити відповідальність між шарами.
