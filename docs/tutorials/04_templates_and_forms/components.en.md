# Components

> Components are reusable UI blocks that are used via `{% include %}`.

**Location:** `crispy_notes_project/templates/components/`

---

## `components/empty_state.html`

```html
{# Empty state — "you don't have any notes yet" #}
<div class="text-center py-5">
  <i class="bi {{ icon|default:'bi-inbox' }} display-1 text-muted"></i>
  <p class="text-muted mt-3">{{ message }}</p>
  {% if action_url %}
  <a href="{{ action_url }}" class="btn btn-primary">{{ action_label }}</a>
  {% endif %}
</div>
```

**Usage:**

```html
{% if not notes %}
  {% include 'components/empty_state.html' with icon="bi-journal" message="Ще немає нотаток" action_url=note_create_url action_label="Створити першу" %}
{% endif %}
```

> A Django template tag (`{% ... %}`) must be written on a single line — a multi-line `{% include ... with %}` is not recognized.

---

## `components/pagination.html`

```html
{# Bootstrap Pagination #}
{% if page_obj.has_other_pages %}
<nav>
  <ul class="pagination justify-content-center">
    {% if page_obj.has_previous %}
    <li class="page-item">
      <a class="page-link" href="?page={{ page_obj.previous_page_number }}">←</a>
    </li>
    {% endif %}

    {% for num in page_obj.paginator.page_range %}
    <li class="page-item {% if page_obj.number == num %}active{% endif %}">
      <a class="page-link" href="?page={{ num }}">{{ num }}</a>
    </li>
    {% endfor %}

    {% if page_obj.has_next %}
    <li class="page-item">
      <a class="page-link" href="?page={{ page_obj.next_page_number }}">→</a>
    </li>
    {% endif %}
  </ul>
</nav>
{% endif %}
```

---

## `components/confirm_modal.html`

```html
{# Bootstrap Modal for delete confirmation #}
<div class="modal fade" id="confirmModal" tabindex="-1">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header bg-danger text-white">
        <h5 class="modal-title">Підтвердити видалення</h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        Ви впевнені що хочете видалити <strong id="deleteItemName"></strong>?
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Скасувати</button>
        <form id="deleteForm" method="post">
          {% csrf_token %}
          <button type="submit" class="btn btn-danger">Видалити</button>
        </form>
      </div>
    </div>
  </div>
</div>
```

---

## Template Tags and Filters — reference

### Built-in Filters

```html
{# Strings: #}
{{ title|truncatechars:50 }}        → First 50 characters + "..."
{{ title|truncatewords:10 }}        → First 10 words + "..."
{{ text|linebreaks }}               → \n → <br><p>
{{ text|linebreaksbr }}             → \n → <br>
{{ text|striptags }}                → Strip HTML tags
{{ html|safe }}                     → Do not escape (⚠️ XSS if it is user input!)
{{ value|escape }}                  → Escape HTML (the default)
{{ email|urlize }}                  → URL/email → <a href>

{# Numbers: #}
{{ count|floatformat:2 }}           → 3.14159 → "3.14"
{{ count|filesizeformat }}          → 1024 → "1.0 KB"
{{ price|intcomma }}                → 1000000 → "1,000,000"

{# Dates: #}
{{ date|date:"d.m.Y" }}             → 13.06.2026
{{ date|date:"D, d M Y H:i" }}      → Fri, 13 Jun 2026 10:00
{{ date|time:"H:i" }}               → 10:00
{{ date|timesince }}                → "5 hours ago" / "2 days ago"
{{ date|timeuntil }}                → "3 days" (until a future date)
{{ date|naturalday }}               → "today" / "yesterday" (humanize)

{# Lists: #}
{{ items|length }}                  → 42
{{ items|first }}                   → the first element
{{ items|last }}                    → the last element
{{ items|join:", " }}               → "one, two, three"
{{ items|slice:":5" }}              → the first 5 elements
{{ items|dictsort:"name" }}         → sort by name

{# Logic: #}
{{ value|default:"Не вказано" }}    → if False/None/empty
{{ value|default_if_none:"—" }}     → only if None
{{ value|yesno:"так,ні,може" }}     → True→так, False→ні, None→може

{# URL: #}
{% load static %}
{% static 'hello_app/logo.png' %}
{% url 'hello_app:note_list' %}
{% url 'hello_app:note_detail' pk=note.pk %}
```

### Template Tags

```html
{# Conditionals: #}
{% if condition %}
{% elif other %}
{% else %}
{% endif %}

{% if user.is_authenticated %}
{% if note.priority == 3 %}
{% if note.is_pinned and not note.is_archived %}
{% if tag in note.tags.all %}

{# Loops: #}
{% for item in items %}
    {{ forloop.counter }}     ← 1-based
    {{ forloop.counter0 }}    ← 0-based
    {{ forloop.revcounter }}  ← reverse
    {{ forloop.first }}       ← True only for the first
    {{ forloop.last }}        ← True only for the last
    {{ forloop.parentloop }}  ← nested loops
{% empty %}
    <p>Немає елементів</p>
{% endfor %}

{# Templates: #}
{% extends 'base.html' %}
{% block name %}...{% endblock %}
{% block name %}{{ block.super }}...{% endblock %}
{% include 'hello_app/_card.html' with note=note only %}
{# only: pass only the specified variables, not the whole context #}

{# Loading libraries: #}
{% load static %}
{% load django_bootstrap5 %}
{% load crispy_forms_tags %}
{% load humanize %}
{# Needed for naturalday, intcomma, etc. #}

{# CSRF: #}
{% csrf_token %}
{# Generates: <input type="hidden" name="csrfmiddlewaretoken" value="...abc..."> #}

{# URL: #}
{% url 'hello_app:note_detail' pk=note.pk %}
{% url 'hello_app:note_list' %}

{# Comments (do not end up in the HTML): #}
{# Single-line comment #}
{% comment %}
    Multi-line comment
    Not rendered!
{% endcomment %}
```

---

## Navigation

- Previous: [Context Processor](context_processor.md)
- Next: [Bootstrap Advanced](bootstrap_advanced.md)
