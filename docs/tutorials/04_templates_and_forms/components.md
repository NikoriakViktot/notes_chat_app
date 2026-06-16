# Components

> Компоненти — повторювані блоки UI, що використовуються через `{% include %}`.

**Місце:** `crispy_notes_project/templates/components/`

---

## `components/empty_state.html`

```html
{# Порожній стан — "у вас ще немає нотаток" #}
<div class="text-center py-5">
  <i class="bi {{ icon|default:'bi-inbox' }} display-1 text-muted"></i>
  <p class="text-muted mt-3">{{ message }}</p>
  {% if action_url %}
  <a href="{{ action_url }}" class="btn btn-primary">{{ action_label }}</a>
  {% endif %}
</div>
```

**Використання:**

```html
{% if not notes %}
  {% include 'components/empty_state.html' with
     icon="bi-journal"
     message="Ще немає нотаток"
     action_url=note_create_url
     action_label="Створити першу" %}
{% endif %}
```

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
{# Bootstrap Modal для підтвердження видалення #}
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

## Template Tags і Filters — довідник

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

## Навігація

- Попередня: [Context Processor](context_processor.md)
- Наступна: [Bootstrap Advanced](bootstrap_advanced.md)
