# ORM Cheatsheet — Django QuerySet API

> A quick reference for all the main Django ORM operations.
> The examples are adapted for `notes_chat_app` (models: `Note`, `Notebook`, `Tag`, `TodoItem`, `User`).

---

## Contents

- [Basic CRUD](#basic-crud)
- [Filtering — filter / exclude](#filtering)
- [Lookup Types — double underscore](#lookup-types)
- [Q objects — OR / NOT conditions](#q-objects)
- [F objects — fields in expressions](#f-objects)
- [Aggregation and annotation](#aggregation-and-annotation)
- [select_related and prefetch_related](#select_related-and-prefetch_related)
- [values / values_list](#values--values_list)
- [order_by / distinct / only / defer](#order_by--distinct--only--defer)
- [Updating and deleting](#updating-and-deleting)
- [ManyToMany operations](#manytomany)
- [Chaining and lazy evaluation](#chaining)
- [get_object_or_404 and get_or_create](#get_object_or_404-and-get_or_create)
- [Transactions](#transactions)
- [Raw SQL (when the ORM is not enough)](#raw-sql)

---

## Basic CRUD

### CREATE

```python
# objects.create() — INSERT + returns the object
note = Note.objects.create(user=alice, title='Test', priority=2)

# Or: __init__ + save()
note = Note(user=alice, title='Test', priority=2)
note.save()   # INSERT INTO notes_app_note ...

# bulk_create — insert several rows in one query
Note.objects.bulk_create([
    Note(user=alice, title='Note 1'),
    Note(user=alice, title='Note 2'),
    Note(user=alice, title='Note 3'),
])
# SQL: INSERT INTO notes_app_note (...) VALUES (...), (...), (...)
# WARNING: does not call .save(), and pre_save/post_save signals do not fire

# get_or_create — find or create
tag, created = Tag.objects.get_or_create(
    user=alice, name='python',
    defaults={'color': '#3776AB'}
)
# created=True  → the tag was created (did not exist)
# created=False → the tag was found (already existed)
```

### READ

```python
# all() — all records (lazy!)
notes = Note.objects.all()
# The SQL runs only on iteration/list()/count() etc.

# get() — exactly one object or an exception
note = Note.objects.get(pk=1)
# DoesNotExist  if not found
# MultipleObjectsReturned  if more than one is found

# first() / last() — first/last or None
note = Note.objects.filter(user=alice).first()   # None if not found
note = Note.objects.filter(user=alice).last()

# count() — number of rows (SELECT COUNT(*))
n = Note.objects.filter(user=alice).count()

# exists() — EXISTS query (the fastest way to check)
if Note.objects.filter(user=alice, is_pinned=True).exists():
    ...
# SQL: SELECT 1 FROM notes_app_note WHERE ... LIMIT 1   (very fast!)

# filter() — a selection (QuerySet)
notes = Note.objects.filter(user=alice, is_archived=False)
```

### UPDATE

```python
# A single object
note = Note.objects.get(pk=1)
note.title = 'New title'
note.save()                              # UPDATE ... SET title=... (all fields)

note.save(update_fields=['title', 'updated_at'])
# UPDATE ... SET title=..., updated_at=...  (only the listed ones → more efficient)

# Bulk update (QuerySet.update)
Note.objects.filter(user=alice).update(is_archived=True)
# SQL: UPDATE notes_app_note SET is_archived=TRUE WHERE user_id=alice.id
# Returns the number of updated rows (int)
# WARNING: does not call .save(), and signals do not fire

# update_or_create
notebook, created = Notebook.objects.update_or_create(
    user=alice, title='Work',          # lookup fields
    defaults={'color': '#0d6efd', 'is_default': True}   # what to update/set
)
```

### DELETE

```python
# A single object
note = Note.objects.get(pk=1)
note.delete()   # DELETE FROM notes_app_note WHERE id=1
# CASCADE automatically deletes the related Reminder objects

# Bulk delete
Note.objects.filter(user=alice, is_archived=True).delete()
# Returns (count, {model: count})
# → (5, {'notes_app.Note': 5, 'notes_app.Reminder': 12})

# Delete everything (CAREFULLY!)
Note.objects.all().delete()   # Deletes ALL notes!
```

---

## Filtering

```python
# Several conditions = AND
Note.objects.filter(user=alice, is_pinned=True, priority=3)
# SQL: WHERE user_id=... AND is_pinned=TRUE AND priority=3

# Chaining filter() = AND
Note.objects.filter(user=alice).filter(is_pinned=True)
# SQL: WHERE user_id=... AND is_pinned=TRUE   (same result)

# exclude() = NOT
Note.objects.exclude(is_archived=True)
# SQL: WHERE NOT is_archived=TRUE   (= WHERE is_archived=FALSE)

Note.objects.exclude(priority__in=[1, 2])
# SQL: WHERE priority NOT IN (1, 2)

# Combining filter + exclude
Note.objects.filter(user=alice).exclude(is_archived=True)
# SQL: WHERE user_id=... AND NOT is_archived=TRUE
```

---

## Lookup Types

```python
# ── Comparison ───────────────────────────────────────────────────────────────
Note.objects.filter(priority__exact=3)         # = 3    (same as priority=3)
Note.objects.filter(priority__gt=1)            # > 1
Note.objects.filter(priority__gte=2)           # >= 2
Note.objects.filter(priority__lt=3)            # < 3
Note.objects.filter(priority__lte=2)           # <= 2
Note.objects.filter(priority__range=(1, 3))    # BETWEEN 1 AND 3

# ── Strings ──────────────────────────────────────────────────────────────────
Note.objects.filter(title__exact='Django')     # = 'Django' (case-sensitive)
Note.objects.filter(title__iexact='django')    # = 'django' (case-insensitive)
Note.objects.filter(title__contains='ang')     # LIKE '%ang%'
Note.objects.filter(title__icontains='ang')    # ILIKE '%ang%'
Note.objects.filter(title__startswith='Dj')   # LIKE 'Dj%'
Note.objects.filter(title__istartswith='dj')  # ILIKE 'dj%'
Note.objects.filter(title__endswith='.md')    # LIKE '%.md'
Note.objects.filter(title__regex=r'^\d+')     # REGEXP (case-sensitive)
Note.objects.filter(title__iregex=r'^\d+')    # REGEXP (case-insensitive)

# ── NULL ─────────────────────────────────────────────────────────────────────
Note.objects.filter(notebook__isnull=True)     # IS NULL
Note.objects.filter(notebook__isnull=False)    # IS NOT NULL

# ── Lists ────────────────────────────────────────────────────────────────────
Note.objects.filter(priority__in=[1, 2])       # IN (1, 2)
Note.objects.filter(id__in=[1, 5, 10, 42])    # IN (1, 5, 10, 42)
# Also: you can pass a QuerySet!
active_user_ids = User.objects.filter(is_active=True).values_list('id', flat=True)
Note.objects.filter(user_id__in=active_user_ids)   # Subquery!

# ── Dates ────────────────────────────────────────────────────────────────────
Note.objects.filter(created_at__year=2026)
Note.objects.filter(created_at__month=6)
Note.objects.filter(created_at__day=13)
Note.objects.filter(created_at__hour=10)
Note.objects.filter(created_at__date=date(2026, 6, 13))
Note.objects.filter(created_at__gte=datetime(2026, 1, 1, tzinfo=timezone.utc))

# ── FK Traversal (double __ = JOIN) ────────────────────────────────────────
Note.objects.filter(notebook__title='Work')          # JOIN notebooks WHERE title='Work'
Note.objects.filter(notebook__user=alice)            # 2 levels of JOIN
Note.objects.filter(notebook__title__icontains='w') # JOIN + ILIKE
Note.objects.filter(tags__name='python')             # JOIN through the M:N junction table

# ── Reverse FK ───────────────────────────────────────────────────────────────
# Find Notebooks that have at least one note:
Notebook.objects.filter(notes__isnull=False).distinct()
# Find Notebooks with HIGH-priority notes:
Notebook.objects.filter(notes__priority=Note.PRIORITY_HIGH)
```

---

## Q objects

```python
from django.db.models import Q

# OR
Note.objects.filter(Q(title__icontains='django') | Q(content__icontains='django'))
# SQL: WHERE (title ILIKE '%django%' OR content ILIKE '%django%')

# AND (explicit)
Note.objects.filter(Q(is_pinned=True) & Q(priority=3))

# NOT
Note.objects.filter(~Q(is_archived=True))
# SQL: WHERE NOT is_archived = TRUE

# Combining Q and kwargs
Note.objects.filter(
    Q(user=alice) | Q(group__in=alice_groups),
    is_archived=False   # ← kwargs are always AND
)
# SQL: WHERE (user_id=... OR group_id IN (...)) AND is_archived=FALSE

# Dynamic filters — build up Q:
query = Q()
if search:
    query &= Q(title__icontains=search) | Q(content__icontains=search)
if tag:
    query &= Q(tags=tag)
notes = Note.objects.filter(query, user=alice)
```

---

## F objects

```python
from django.db.models import F

# Compare a field with a field
Note.objects.filter(updated_at__gt=F('created_at'))
# SQL: WHERE updated_at > created_at

# Atomic update without a race condition:
TodoItem.objects.filter(todo_list=todo_list).update(order_position=F('order_position') + 1)
# SQL: UPDATE ... SET order_position = order_position + 1
# WITHOUT F: you need SELECT → Python → UPDATE (two queries + a race condition!)

# Using it in annotate:
from django.db.models import ExpressionWrapper, DurationField
from django.db.models.functions import Now
Note.objects.annotate(
    age=ExpressionWrapper(Now() - F('created_at'), output_field=DurationField())
)

# F in save():
item.order_position = F('order_position') + 1
item.save(update_fields=['order_position'])
# SQL: UPDATE ... SET order_position = order_position + 1
```

---

## Aggregation and annotation

```python
from django.db.models import Count, Avg, Max, Min, Sum

# ── aggregate() — one value for the whole QuerySet ────────────────────────
Note.objects.aggregate(total=Count('id'))
# → {'total': 42}

Note.objects.filter(user=alice).aggregate(
    total=Count('id'),
    pinned=Count('id', filter=Q(is_pinned=True)),
    avg_priority=Avg('priority'),
    max_priority=Max('priority'),
    min_priority=Min('priority'),
)
# → {'total': 42, 'pinned': 5, 'avg_priority': 1.8, 'max_priority': 3, 'min_priority': 1}

# ── annotate() — a value for EACH row ────────────────────────────────────
Notebook.objects.annotate(note_count=Count('notes'))
# SELECT *, COUNT(note.id) AS note_count FROM notebooks LEFT JOIN notes ...
# notebook.note_count is available on every object!

# Filtered annotate:
Notebook.objects.annotate(
    active_notes=Count('notes', filter=Q(notes__is_archived=False)),
    pinned_notes=Count('notes', filter=Q(notes__is_pinned=True)),
)

# annotate + filter (filtering BY THE ANNOTATION):
Notebook.objects.annotate(
    note_count=Count('notes')
).filter(note_count__gt=5)
# Notebooks with more than 5 notes

# annotate + order_by:
Notebook.objects.annotate(
    note_count=Count('notes')
).order_by('-note_count')
# Sorted by the number of notes

# Tags with a note count (a real example from selectors.py):
Tag.objects.filter(user=user).annotate(
    note_count=Count('notes')
).order_by('name')
```

---

## select_related and prefetch_related

```python
# ── select_related: ForeignKey / OneToOne → JOIN (1 query) ────────────────
# WITHOUT optimization: N+1
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)   # ← 1 SQL query per iteration!

# With select_related: 1 SQL JOIN
notes = Note.objects.select_related('notebook', 'user').all()
# SQL: SELECT notes.*, notebooks.*, auth_user.*
#      FROM notes
#      LEFT OUTER JOIN notebooks ON (notes.notebook_id = notebooks.id)
#      INNER JOIN auth_user ON (notes.user_id = auth_user.id)

# Depth (nested FK):
notes = Note.objects.select_related('notebook__user')
# Access: note.notebook.user.username — no extra SQL!

# ── prefetch_related: ManyToMany / reverse FK → 2 queries ────────────────
# WITHOUT optimization:
for note in notes:
    for tag in note.tags.all():   # ← 1 SQL query per note!
        print(tag.name)

# With prefetch_related: 2 SQL queries total (regardless of the number of notes)
notes = Note.objects.prefetch_related('tags')
# SQL 1: SELECT * FROM notes_app_note WHERE ...
# SQL 2: SELECT tags.* FROM tags
#         INNER JOIN notes_app_note_tags ON ...
#         WHERE notes_app_note_tags.note_id IN (1, 2, 3, ...)
# Django joins them in memory itself

# Reverse FK:
notes = Note.objects.prefetch_related('reminders')
# Access: note.reminders.all() → from the cache, no SQL

# ── Combining ────────────────────────────────────────────────────────────
notes = Note.objects.filter(user=user, is_archived=False) \
    .select_related('notebook', 'user') \
    .prefetch_related('tags', 'reminders') \
    .order_by('-is_pinned', '-priority')
# TOTAL: 3 SQL queries for any number of notes!

# ── Prefetch with a filter (Prefetch object) ─────────────────────────────
from django.db.models import Prefetch

notes = Note.objects.prefetch_related(
    Prefetch('reminders', queryset=Reminder.objects.filter(is_sent=False))
    # Load only reminders that have not been sent
)
# note.reminders.all() → only is_sent=False (from the cache)
```

---

## values / values_list

```python
# values() → a list of dicts (faster than full objects)
Note.objects.values('title', 'priority')
# → [{'title': 'Test', 'priority': 1}, {'title': 'Django', 'priority': 2}]
# SQL: SELECT title, priority FROM notes_app_note

# values() with FK traversal:
Note.objects.values('title', 'notebook__title')
# → [{'title': 'Test', 'notebook__title': 'Work'}, ...]
# SQL: SELECT notes.title, notebooks.title FROM ... JOIN ...

# values_list() → a list of tuples (even faster)
Note.objects.values_list('title', 'priority')
# → [('Test', 1), ('Django', 2), ...]

# flat=True → one column = a flat list
note_ids = Note.objects.filter(user=alice).values_list('id', flat=True)
# → [1, 5, 10, 42]  (not [(1,), (5,), ...])

# A useful application:
tag_ids = note.tags.values_list('id', flat=True)
# → [3, 7, 12] — tag IDs for a form

# Checking whether an id is in the list:
if request.user.id in group.user_set.values_list('id', flat=True):
    ...
```

---

## order_by / distinct / only / defer

```python
# ── Sorting ──────────────────────────────────────────────────────────────
Note.objects.order_by('priority')              # ASC (ascending)
Note.objects.order_by('-priority')             # DESC (descending)
Note.objects.order_by('-is_pinned', '-priority', '-updated_at')  # Multiple

Note.objects.order_by('?')                    # Random (SLOW on large tables!)
Note.objects.order_by()                       # Remove ordering

# Sorting by FK:
Note.objects.order_by('notebook__title')      # By notebook title

# ── distinct() ───────────────────────────────────────────────────────────
# A JOIN through tags can produce duplicates → distinct removes them:
Note.objects.filter(tags__name='python').distinct()
# SQL: SELECT DISTINCT * FROM notes JOIN note_tags JOIN tags WHERE ...

# ── Limiting (slicing) ───────────────────────────────────────────────────
Note.objects.all()[:10]                       # LIMIT 10
Note.objects.all()[10:20]                     # LIMIT 10 OFFSET 10
Note.objects.all()[0]                         # The first one (LIMIT 1)
Note.objects.all()[-1]                        # ⚠️ NOT SUPPORTED! Use .last()

# ── only() / defer() — load only the fields you need ─────────────────────
# only(): load ONLY the listed fields
Note.objects.only('id', 'title', 'priority')
# SQL: SELECT id, title, priority FROM notes_app_note
# WARNING: accessing another field → an extra SELECT!

# defer(): load ALL fields EXCEPT the listed ones
Note.objects.defer('content')   # content = a large TextField
# SQL: SELECT id, title, priority, is_pinned, ... FROM ... (without content)
# Useful when content = a large text not needed in the list

# iterator() — do not cache the QuerySet (for large selections)
for note in Note.objects.filter(user=alice).iterator():
    process(note)   # Does not load everything into memory at once
```

---

## Updating and deleting

```python
# ── update() — bulk update with one SQL query ─────────────────────────────
Note.objects.filter(user=alice, is_archived=False).update(
    is_archived=True
)
# SQL: UPDATE notes_app_note SET is_archived=TRUE WHERE user_id=... AND is_archived=FALSE
# Returns: int (number of updated rows)

# With F():
TodoItem.objects.filter(todo_list=todo_list).update(order_position=F('order_position') + 1)

# With a condition:
from datetime import timedelta
from django.utils import timezone
Note.objects.filter(
    created_at__lt=timezone.now() - timedelta(days=365)
).update(is_archived=True)
# Archive notes older than a year

# ── delete() — bulk delete ───────────────────────────────────────────────
deleted_count, breakdown = Note.objects.filter(
    user=alice, is_archived=True
).delete()
# deleted_count = 5
# breakdown = {'notes_app.Note': 5, 'notes_app.Reminder': 12}
# Django automatically deletes related objects (CASCADE)

# ── bulk_update() — bulk update of objects ───────────────────────────────
notes = list(Note.objects.filter(user=alice))
for note in notes:
    note.is_archived = True
Note.objects.bulk_update(notes, ['is_archived'])
# One UPDATE instead of N separate .save() calls
```

---

## ManyToMany

```python
note = Note.objects.get(pk=1)
tag_py = Tag.objects.get(name='python', user=alice)
tag_dj = Tag.objects.get(name='django', user=alice)

# Add
note.tags.add(tag_py)                    # INSERT INTO note_tags (note_id, tag_id)
note.tags.add(tag_py, tag_dj)           # Several at once

# Remove a specific one
note.tags.remove(tag_py)                 # DELETE FROM note_tags WHERE note_id=... AND tag_id=...

# Check whether it is present
note.tags.filter(pk=tag_py.pk).exists()

# Clear all
note.tags.clear()                        # DELETE FROM note_tags WHERE note_id=...

# Set exactly (replace):
note.tags.set([tag_py, tag_dj])         # DELETE old + INSERT new
note.tags.set(Tag.objects.filter(user=alice, name__in=['python', 'django']))

# Reverse — notes with a tag:
tag_py.notes.all()                       # related_name='notes' on the ManyToManyField
tag_py.notes.filter(user=alice)

# Number of tags on a note:
note.tags.count()                        # SELECT COUNT(*) FROM ...

# All tags:
note.tags.all()
note.tags.order_by('name')
note.tags.values_list('name', flat=True)  # → ['django', 'python']
```

---

## Chaining

```python
# A QuerySet is LAZY — SQL does not run when it is created
qs = Note.objects.filter(user=alice)    # Nothing yet!
qs = qs.filter(is_archived=False)       # Refinement
qs = qs.select_related('notebook')      # Optimization
qs = qs.order_by('-priority')           # Sorting

# The SQL runs only here:
result = list(qs)                       # ← SELECT here!
count  = qs.count()                     # ← SELECT COUNT(*) here!
first  = qs.first()                     # ← SELECT ... LIMIT 1 here!
exists = qs.exists()                    # ← SELECT 1 ... LIMIT 1 here!
for note in qs: ...                     # ← SELECT here!

# A QuerySet can be passed to a template — the SQL runs during rendering
return render(request, 'template.html', {'notes': qs})
# The Django Template Engine iterates over qs → SQL here!

# Store the result in Python (run the SQL now):
notes_list = list(qs)          # Loads everything into memory
notes_tuple = tuple(qs)

# Cloning a QuerySet (does not run SQL):
cloned_qs = qs.all()           # A new QuerySet with the same parameters
```

---

## get_object_or_404 and get_or_create

```python
from django.shortcuts import get_object_or_404, get_list_or_404
from django.http import Http404

# get_object_or_404 — get() or Http404
note = get_object_or_404(Note, pk=pk)
# If not found → Http404 → Django 404 page
# NOT: DoesNotExist → 500 Internal Error

# With several conditions (IDOR protection!):
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 if the note does not exist OR belongs to another user

# get_list_or_404 — QuerySet or Http404
notes = get_list_or_404(Note, user=request.user, is_pinned=True)
# → Http404 if the list is empty

# Raising Http404 manually:
if not Note.objects.filter(pk=pk, user=request.user).exists():
    raise Http404("Нотатку не знайдено")

# get_or_create — find or create (atomic):
tag, created = Tag.objects.get_or_create(
    user=alice,
    name='python',                         # Lookup fields
    defaults={'color': '#3776AB'}          # Values used only on CREATE
)
# If 'python' already exists → created=False, tag = existing
# If not → created=True, tag = new

# update_or_create:
notebook, created = Notebook.objects.update_or_create(
    user=alice,
    title='Work',                          # Lookup fields
    defaults={'color': '#0d6efd'}          # Update these fields (always)
)
```

---

## Transactions

```python
from django.db import transaction

# Context manager:
with transaction.atomic():
    note = Note.objects.create(user=alice, title='Test')
    tags = Tag.objects.filter(id__in=tag_ids, user=alice)
    note.tags.set(tags)
    # On an exception → ROLLBACK of both operations
# COMMIT if everything is OK

# Decorator:
@transaction.atomic
def create_notebook(user, title, is_default=False):
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
    return Notebook.objects.create(user=user, title=title, is_default=is_default)

# select_for_update — row locking (SELECT ... FOR UPDATE):
with transaction.atomic():
    note = Note.objects.select_for_update().get(pk=1)
    # Other transactions wait until this block finishes
    note.is_pinned = not note.is_pinned
    note.save()
```

---

## Raw SQL

```python
# When the ORM is not enough:

# Manager.raw() — raw SQL, returns a RawQuerySet
notes = Note.objects.raw(
    "SELECT * FROM notes_app_note WHERE user_id = %s ORDER BY priority DESC",
    [alice.id]
)

# connection.cursor() — full control
from django.db import connection

with connection.cursor() as cursor:
    cursor.execute(
        "SELECT notebook_id, COUNT(*) FROM notes_app_note WHERE user_id=%s GROUP BY notebook_id",
        [alice.id]
    )
    rows = cursor.fetchall()
    # → [(1, 5), (2, 12), ...]

# WARNING: always use parameterized queries!
# ❌ cursor.execute(f"SELECT * WHERE id = {pk}")  → SQL injection!
# ✅ cursor.execute("SELECT * WHERE id = %s", [pk])  → safe
```

---

## Quick cheatsheet

```python
# READING
Note.objects.all()                              # All (lazy)
Note.objects.filter(user=user)                  # WHERE
Note.objects.exclude(is_archived=True)          # NOT
Note.objects.get(pk=1)                          # One or an exception
Note.objects.first() / .last()                  # First/last or None
Note.objects.count()                            # SELECT COUNT(*)
Note.objects.exists()                           # SELECT 1 LIMIT 1

# OPTIMIZATION
.select_related('notebook', 'user')             # FK → JOIN
.prefetch_related('tags', 'reminders')          # M:N / reverse FK → 2 queries
.only('id', 'title')                            # Load only these fields
.defer('content')                               # All fields except content

# FILTERING
filter(priority__gt=1)                          # > 1
filter(title__icontains='django')               # ILIKE '%django%'
filter(notebook__isnull=True)                   # IS NULL
filter(tags__name='python')                     # M:N JOIN
filter(Q(a=1) | Q(b=2))                        # OR
filter(~Q(archived=True))                       # NOT

# SORTING AND LIMITING
.order_by('-priority', '-updated_at')           # ORDER BY
.distinct()                                     # SELECT DISTINCT
[:10]                                           # LIMIT 10
[10:20]                                         # LIMIT 10 OFFSET 10

# AGGREGATION
.count()                                        # COUNT(*)
.aggregate(avg=Avg('priority'))                 # {'avg': 1.8}
.annotate(n=Count('notes'))                     # Per-row count

# VALUES (without full objects)
.values('title', 'priority')                    # → [{'title': ...}, ...]
.values_list('id', flat=True)                   # → [1, 2, 3, ...]

# WRITING
Note.objects.create(user=user, title='T')       # INSERT + return
Note.objects.filter(...).update(field=val)      # UPDATE (bulk)
Note.objects.filter(...).delete()               # DELETE (bulk)
note.save(update_fields=['title'])              # UPDATE (one record, selected fields)

# MANY-TO-MANY
note.tags.add(tag1, tag2)                       # INSERT
note.tags.remove(tag1)                          # DELETE
note.tags.set([tag1, tag2])                     # DELETE + INSERT
note.tags.clear()                               # DELETE all
note.tags.all()                                 # SELECT

# TRANSACTIONS
with transaction.atomic(): ...                  # ROLLBACK on an exception
```

---

## See also

- [Tutorial 03 — Domain Design and the ORM](../tutorials/03_crud.md)
- [Django ORM Documentation](https://docs.djangoproject.com/en/5.2/topics/db/queries/)
- [QuerySet API Reference](https://docs.djangoproject.com/en/5.2/ref/models/querysets/)
