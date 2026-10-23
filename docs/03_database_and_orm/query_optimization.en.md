# QuerySet Optimization

> A Django QuerySet is lazy: SQL runs only when you ask for the data.
> The N+1 problem is the most common performance mistake in Django.

---

## QuerySet — lazy by nature

```python
# This line does NOT run any SQL:
notes = Note.objects.filter(user=user)

# SQL runs here — on iteration or len():
for note in notes:         # ← SQL runs
    print(note.title)

count = notes.count()      # ← SQL: SELECT COUNT(*)
first = notes.first()      # ← SQL: SELECT ... LIMIT 1
list(notes)                # ← SQL: SELECT * FROM ...
```

**Chaining** — every `.filter()`, `.order_by()`, `.exclude()` returns a new QuerySet without SQL:

```python
qs = Note.objects.all()
qs = qs.filter(user=user)
qs = qs.filter(is_archived=False)
qs = qs.order_by('-priority')
# No SQL has run yet!

result = list(qs)          # ← only here: one SQL query with all conditions
```

---

## N+1 Problem

**The most common performance mistake in Django.**

Imagine: you display a list of 50 notes and show the notebook name for each one.

### The problem (N+1 queries)

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
SELECT * FROM notes_app_note WHERE user_id = 1;          -- 1 query
SELECT * FROM notes_app_notebook WHERE id = 5;           -- for note 1
SELECT * FROM notes_app_notebook WHERE id = 5;           -- for note 2
SELECT * FROM notes_app_notebook WHERE id = 7;           -- for note 3
... (50 separate queries for notebooks!)
```

**Total: 1 + 50 = 51 queries** for a single list.

### Solution: select_related

```python
# ForeignKey and OneToOne — a JOIN in a single SQL query
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

**Total: 1 query.** Django caches the JOIN results in memory.

### Solution: prefetch_related

```python
# ManyToMany and reverse FK — a separate SELECT with an IN lookup
notes = Note.objects.filter(user=user).prefetch_related('tags')
```

SQL:
```sql
SELECT * FROM notes_app_note WHERE user_id = 1;         -- query 1
SELECT * FROM notes_app_tag
  INNER JOIN notes_app_note_tags ON tag_id = notes_app_tag.id
  WHERE note_id IN (1, 2, 3, ..., 50);                  -- query 2
```

**Total: 2 queries** regardless of the number of notes.

---

## When to use what

| Relationship type | Method | Number of SQL queries |
|-------------|-------|--------------|
| ForeignKey (1 level) | `select_related('notebook')` | 1 JOIN |
| ForeignKey (2 levels) | `select_related('notebook__user')` | 1 JOIN |
| ManyToMany | `prefetch_related('tags')` | 2 queries |
| Reverse FK | `prefetch_related('reminders')` | 2 queries |
| Complex prefetch | `Prefetch('reminders', queryset=...)` | 2 queries with filters |

---

## Real examples from notes_chat_app

### `get_user_notes` — an optimized list

```python
# notes_app/selectors.py

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups), is_archived=archived
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ↑ select_related: FK → JOIN (notebook, group)
    # ↑ prefetch_related: M:N → separate SELECT IN (tags)

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if search:
        qs = qs.filter(Q(title__icontains=search) | Q(content__icontains=search))

    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

### `get_note_detail` — with Prefetch filtering

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
                remind_at__gte=timezone.now()   # ← only upcoming reminders
            ).order_by('remind_at'),
            to_attr='upcoming_reminders'        # ← note.upcoming_reminders instead of note.reminders.all()
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

Result: `notebook.note_count` is available as an attribute — with no extra queries in the template.

### `get_user_todo_lists` — two annotates

```python
def get_user_todo_lists(user):
    return TodoList.objects.filter(user=user).annotate(
        total_items=Count('items'),
        done_items=Count('items', filter=Q(items__is_done=True))
    ).order_by('is_completed', '-created_at')
```

This lets you write in the template:
```html
{{ todo.done_items }} / {{ todo.total_items }} виконано
```
— without a single extra SQL query.

---

## Debugging: number of queries

### django-debug-toolbar

```python
# settings.py — dev only
if DEBUG:
    INSTALLED_APPS += ['debug_toolbar']
    MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware'] + MIDDLEWARE
    INTERNAL_IPS = ['127.0.0.1']
```

It shows a panel with the number of SQL queries, their timing, and EXPLAIN.

### Shell + `connection.queries`

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection, reset_queries
from django.conf import settings

settings.DEBUG = True
reset_queries()

# Run the queryset
from notes_app import selectors
from django.contrib.auth.models import User
user = User.objects.get(username='demo_alice')
notes = list(selectors.get_user_notes(user))

# Check the number of queries
print(f"SQL queries: {len(connection.queries)}")
for q in connection.queries:
    print(q['sql'][:100], '→', q['time'])
```

### `.explain()`

```python
qs = Note.objects.filter(user=user).select_related('notebook')
print(qs.explain(verbose=True, analyze=True))
# EXPLAIN ANALYZE SELECT ...
# Seq Scan vs Index Scan — the key performance difference
```

---

## values() and values_list() — lighter queries

If you only need individual fields, do not load the whole Model:

```python
# Full model — unnecessary data
notes = Note.objects.filter(user=user)   # SELECT * (all columns)

# Only the fields you need
notes = Note.objects.filter(user=user).values('id', 'title', 'priority')
# → [{'id': 1, 'title': 'Note', 'priority': 2}, ...]

# For a JSON response or simple processing
ids = Note.objects.filter(user=user).values_list('id', flat=True)
# → [1, 2, 3, ...]
```

In `selectors.py` it is used for browser notifications:
```python
return list(
    Reminder.objects.filter(...).values('id', 'message', 'remind_at', 'note__title')
)
```

---

## In the book

- [Django Models](django_models.md) — model structure and relationships
- [Transactions and PostgreSQL](transactions_indexes_postgresql.md) — indexes, transactions
- [Part VI. Architecture](../06_application_architecture/README.md) — why selectors live separately

---

## Official documentation

- [Django: QuerySet API](https://docs.djangoproject.com/en/5.2/ref/models/querysets/) — full reference
- [Django: select_related](https://docs.djangoproject.com/en/5.2/ref/models/querysets/#select-related) — JOIN
- [Django: prefetch_related](https://docs.djangoproject.com/en/5.2/ref/models/querysets/#prefetch-related) — prefetch
- [Django: Database access optimization](https://docs.djangoproject.com/en/5.2/topics/db/optimization/) — a complete optimization guide
- [Django: annotate](https://docs.djangoproject.com/en/5.2/topics/db/aggregation/) — aggregation and annotate
