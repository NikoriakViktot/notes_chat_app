# Оптимізація QuerySet

> QuerySet у Django — ледачий (lazy): SQL виконується тільки коли ти просиш дані.
> N+1 problem — найпоширеніша помилка продуктивності у Django.

---

## QuerySet — ледачий за природою

```python
# Цей рядок НЕ виконує SQL:
notes = Note.objects.filter(user=user)

# SQL виконується тут — при ітерації або len():
for note in notes:         # ← SQL виконується
    print(note.title)

count = notes.count()      # ← SQL: SELECT COUNT(*)
first = notes.first()      # ← SQL: SELECT ... LIMIT 1
list(notes)                # ← SQL: SELECT * FROM ...
```

**Ланцюгування** — кожен `.filter()`, `.order_by()`, `.exclude()` повертає новий QuerySet без SQL:

```python
qs = Note.objects.all()
qs = qs.filter(user=user)
qs = qs.filter(is_archived=False)
qs = qs.order_by('-priority')
# SQL ще не виконувався!

result = list(qs)          # ← тільки тут один SQL запит з всіма умовами
```

---

## N+1 Problem

**Найпоширеніша помилка продуктивності у Django.**

Уяви: відображаєш список 50 нотаток і показуєш ім'я ноутбуку кожної.

### Проблема (N+1 запитів)

```python
# view
notes = Note.objects.filter(user=user)

# template
{% for note in notes %}
  {{ note.title }} — {{ note.notebook.title }}
{% endfor %}
```

SQL:
```sql
SELECT * FROM notes_app_note WHERE user_id = 1;          -- 1 запит
SELECT * FROM notes_app_notebook WHERE id = 5;           -- для note 1
SELECT * FROM notes_app_notebook WHERE id = 5;           -- для note 2
SELECT * FROM notes_app_notebook WHERE id = 7;           -- для note 3
... (50 окремих запитів для notebooks!)
```

**Всього: 1 + 50 = 51 запит** для одного списку.

### Рішення: select_related

```python
# ForeignKey і OneToOne — JOIN в одному SQL запиті
notes = Note.objects.filter(user=user).select_related('notebook', 'group')
```

SQL:
```sql
SELECT notes.*, notebooks.*, groups.*
FROM notes_app_note notes
LEFT JOIN notes_app_notebook notebooks ON notes.notebook_id = notebooks.id
LEFT JOIN auth_group groups ON notes.group_id = groups.id
WHERE notes.user_id = 1;
```

**Всього: 1 запит.** Django кешує результати JOIN у пам'яті.

### Рішення: prefetch_related

```python
# ManyToMany і reverse FK — окремий SELECT з IN lookup
notes = Note.objects.filter(user=user).prefetch_related('tags')
```

SQL:
```sql
SELECT * FROM notes_app_note WHERE user_id = 1;         -- запит 1
SELECT * FROM notes_app_tag
  INNER JOIN notes_app_note_tags ON tag_id = notes_app_tag.id
  WHERE note_id IN (1, 2, 3, ..., 50);                  -- запит 2
```

**Всього: 2 запити** незалежно від кількості нотаток.

---

## Коли що використовувати

| Тип зв'язку | Метод | Кількість SQL |
|-------------|-------|--------------|
| ForeignKey (1 рівень) | `select_related('notebook')` | 1 JOIN |
| ForeignKey (2 рівні) | `select_related('notebook__user')` | 1 JOIN |
| ManyToMany | `prefetch_related('tags')` | 2 запити |
| Reverse FK | `prefetch_related('reminders')` | 2 запити |
| Складний prefetch | `Prefetch('reminders', queryset=...)` | 2 запити з фільтрами |

---

## Реальні приклади з notes_chat_app

### `get_user_notes` — оптимізований список

```python
# notes_app/selectors.py

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups), is_archived=archived
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ↑ select_related: FK → JOIN (notebook, group)
    # ↑ prefetch_related: M:N → окремий SELECT IN (tags)

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if search:
        qs = qs.filter(Q(title__icontains=search) | Q(content__icontains=search))

    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

### `get_note_detail` — з Prefetch фільтрацією

```python
def get_note_detail(user, note_id):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups)
    ).select_related(
        'notebook', 'user'
    ).prefetch_related(
        'tags',
        Prefetch(
            'reminders',
            queryset=Reminder.objects.filter(
                remind_at__gte=timezone.now()   # ← тільки майбутні нагадування
            ).order_by('remind_at'),
            to_attr='upcoming_reminders'        # ← note.upcoming_reminders замість note.reminders.all()
        )
    ).get(id=note_id)
```

### `get_user_notebooks` — annotate Count

```python
def get_user_notebooks(user):
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    ).order_by('-is_default', 'title')
```

SQL:
```sql
SELECT notebooks.*, COUNT(notes.id) FILTER (WHERE notes.is_archived = false) AS note_count
FROM notes_app_notebook notebooks
LEFT JOIN notes_app_note notes ON notes.notebook_id = notebooks.id
WHERE notebooks.user_id = 1
GROUP BY notebooks.id
ORDER BY notebooks.is_default DESC, notebooks.title;
```

Результат: `notebook.note_count` доступний як атрибут — без додаткових запитів в шаблоні.

### `get_user_todo_lists` — два annotate

```python
def get_user_todo_lists(user):
    return TodoList.objects.filter(user=user).annotate(
        total_items=Count('items'),
        done_items=Count('items', filter=Q(items__is_done=True))
    ).order_by('is_completed', '-created_at')
```

Це дозволяє в шаблоні писати:
```html
{{ todo.done_items }} / {{ todo.total_items }} виконано
```
— без жодного додаткового SQL запиту.

---

## Дебаг: кількість запитів

### django-debug-toolbar

```python
# settings.py — тільки для dev
if DEBUG:
    INSTALLED_APPS += ['debug_toolbar']
    MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware'] + MIDDLEWARE
    INTERNAL_IPS = ['127.0.0.1']
```

Показує панель з кількістю SQL запитів, їх часом, та EXPLAIN.

### Shell + `connection.queries`

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection, reset_queries
from django.conf import settings

settings.DEBUG = True
reset_queries()

# Виконай queryset
from notes_app import selectors
from django.contrib.auth.models import User
user = User.objects.get(username='demo_alice')
notes = list(selectors.get_user_notes(user))

# Перевір кількість запитів
print(f"SQL запитів: {len(connection.queries)}")
for q in connection.queries:
    print(q['sql'][:100], '→', q['time'])
```

### `.explain()`

```python
qs = Note.objects.filter(user=user).select_related('notebook')
print(qs.explain(verbose=True, analyze=True))
# EXPLAIN ANALYZE SELECT ...
# Seq Scan vs Index Scan — ключова різниця у продуктивності
```

---

## values() і values_list() — легші запити

Якщо потрібні тільки окремі поля — не завантажуй весь Model:

```python
# Повна модель — зайві дані
notes = Note.objects.filter(user=user)   # SELECT * (всі колонки)

# Тільки потрібні поля
notes = Note.objects.filter(user=user).values('id', 'title', 'priority')
# → [{'id': 1, 'title': 'Нотатка', 'priority': 2}, ...]

# Для JSON відповіді або простого processing
ids = Note.objects.filter(user=user).values_list('id', flat=True)
# → [1, 2, 3, ...]
```

У `selectors.py` використовується для browser notifications:
```python
return list(
    Reminder.objects.filter(...).values('id', 'message', 'remind_at', 'note__title')
)
```

---

## У книзі

- [Django Models](django_models.md) — структура моделей і зв'язки
- [Transactions і PostgreSQL](transactions_indexes_postgresql.md) — indexes, transactions
- [Частина VI. Архітектура](../06_application_architecture/README.md) — чому селектори живуть окремо

---

## Офіційна документація

- [Django: QuerySet API](https://docs.djangoproject.com/en/5.2/ref/models/querysets/) — повний довідник
- [Django: select_related](https://docs.djangoproject.com/en/5.2/ref/models/querysets/#select-related) — JOIN
- [Django: prefetch_related](https://docs.djangoproject.com/en/5.2/ref/models/querysets/#prefetch-related) — prefetch
- [Django: Database access optimization](https://docs.djangoproject.com/en/5.2/topics/db/optimization/) — повний гайд по оптимізації
- [Django: annotate](https://docs.djangoproject.com/en/5.2/topics/db/aggregation/) — агрегація і annotate
