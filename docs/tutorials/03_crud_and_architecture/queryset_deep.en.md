# QuerySet in depth: N+1, normalization, transactions

> This section covers three key concepts: database schema normalization, solving the N+1 problem, and atomic operations.

---

## Normalization: Before / After

> **"One truth for one fact."**
> Normalization is the process of finding and removing duplication from a relational schema.
> Goal: every fact is stored in **exactly one place**.

### 3NF by example

**❌ BEFORE (1NF) — everything in a single `employees` table:**

| id | name  | dept_id | dept_name   | location | salary |
|----|-------|---------|-------------|----------|--------|
| 1  | Alice | 10      | **Engineering** | **Kyiv** | 50000  |
| 2  | Bob   | 10      | **Engineering** | **Kyiv** | 45000  |
| 3  | Carol | 20      | **Design**      | **Lviv** | 48000  |
| 4  | Dan   | 10      | **Engineering** | **Kyiv** | 52000  |
| 5  | Eva   | 20      | **Design**      | **Lviv** | 49000  |

**Problem:** "Engineering / Kyiv" is repeated 3 times.
Moved to Kharkiv? `UPDATE` 1000 rows. Made a typo in the name? Inconsistency.

---  →  3NF: **move it into a separate table**  ---

**✅ AFTER — `employees` (FK → `departments.id`):**

| id | name  | dept_id | salary |
|----|-------|---------|--------|
| 1  | Alice | **10**  | 50000  |
| 2  | Bob   | **10**  | 45000  |
| 3  | Carol | **20**  | 48000  |
| 4  | Dan   | **10**  | 52000  |
| 5  | Eva   | **20**  | 49000  |

**✅ `departments` — one truth:**

| id | name        | location |
|----|-------------|----------|
| 10 | Engineering | Kyiv     |
| 20 | Design      | Lviv     |

```python
# Django model after normalization:
class Department(models.Model):
    name     = models.CharField(max_length=80)
    location = models.CharField(max_length=80)

class Employee(models.Model):
    name       = models.CharField(max_length=80)
    department = models.ForeignKey(Department, on_delete=models.PROTECT)
    salary     = models.DecimalField(max_digits=10, decimal_places=2)
```

> **Moving now:** `UPDATE departments SET location='Kharkiv' WHERE id=10;`
> **1 row instead of 1000.** Inconsistency is impossible.

### The three normal forms — cheat sheet

| Form | Rule | Violation — example |
|-------|---------|---------------------|
| **1NF** | All values are atomic, no arrays in a cell | `tags = "python,django,orm"` in a single column |
| **2NF** | All non-key attributes depend on the **whole** PK | In the table `(order_id, product_id)` → `product_name` depends only on `product_id` |
| **3NF** | No **transitive** dependencies (A→B→C where B is not a key) | `employee.dept_name` depends on `dept_id`, not on `employee.id` |

> **Rule of thumb:** if changing one fact requires an `UPDATE` of > 1 row, the schema is not normalized.

---

## The N+1 Problem

> The most common performance bug in Django: Django makes 1 + N SQL queries instead of 1.

### Why N+1 happens

N+1 happens **precisely because** a QuerySet is lazy. The student already knows that `for note in notes:` materializes a single SELECT. But as soon as `note.notebook` appears in the template, Django does not know that `notebook` will be needed for every note, so it runs a separate SELECT for each one:

```
{% for note in notes %}
    {{ note.notebook.title }}   ← for each note: SELECT FROM notebooks WHERE id=?
{% endfor %}
```

50 notes → the template "asks for" the notebook 50 times → **51 SQL queries** instead of the expected one.

This is not a Django bug — it is a natural consequence of lazy loading. The solution is to tell Django explicitly, in advance, which relationships will be needed.

```python
# 50 notes in the database. Each has a ForeignKey to Notebook.
notes = Note.objects.all()          # Query 1: SELECT * FROM notes  ← 50 rows

for note in notes:
    print(note.notebook.title)       # Query 2, 3, 4, ..., 51!
    # Each note.notebook.title → a SEPARATE SELECT FROM notebooks WHERE id=...
    # 50 notes → 50 extra queries → 51 TOTAL!
```

---

## select_related — solving N+1 for FKs

```python
# ❌ N+1: 100 notes + 100 queries for user + 100 for notebook = 201 queries
notes = Note.objects.filter(is_archived=False)[:100]
for note in notes:
    print(note.user.username, note.notebook.title)  # new SQL for each one!

# ✅ select_related: 1 query with a JOIN
notes = Note.objects.select_related(
    'user', 'notebook'
).filter(is_archived=False)[:100]
for note in notes:
    print(note.user.username, note.notebook.title)  # already in memory
```

### How it works inside

```python
# Step 1: The base QuerySet (LAZY — the SQL has not been executed yet!)
qs = Note.objects.filter(user=user, is_archived=archived)
#    SQL so far: WHERE note.user_id=? AND note.is_archived=?
#    But the SQL is NOT executed — Django waits until someone iterates the QuerySet!

# Step 2: select_related('notebook') — join the FK with a single JOIN
qs = qs.select_related('notebook')
#    The SQL becomes: LEFT JOIN hello_app_notebook nb ON note.notebook_id = nb.id
#    Consequence: note.notebook.title → does NOT run a new SELECT (already in memory!)
#
#    WITHOUT select_related: for note in qs: print(note.notebook.title)
#                        → 1 SELECT + N SELECT = the N+1 problem!
#    WITH select_related: 1 SELECT with a JOIN — always!
```

---

## prefetch_related — for M:N and reverse FKs

```python
# ✅ 2 queries: one for notes, one for tags
notes = Note.objects.prefetch_related('tags').all()[:50]
for note in notes:
    print([t.name for t in note.tags.all()])  # already in memory!
```

### How it works inside

```python
# Step 3: prefetch_related('tags') — load the M:N relationship
qs = qs.prefetch_related('tags')
#    QUERY 1: SELECT * FROM note WHERE ...
#    QUERY 2: SELECT tag.* ... WHERE note_id IN (1, 2, 3, ...)
#    Python: Django joins them on its own
#    Consequence: note.tags.all() → already in the cache, NOT a new SELECT!
```

### Prefetch with a filter (to_attr)

```python
from django.db.models import Prefetch
from django.utils import timezone

notes = Note.objects.prefetch_related(
    'tags',
    Prefetch(
        'reminders',
        queryset=Reminder.objects.filter(
            remind_at__gte=timezone.now()   # only FUTURE reminders
        ).order_by('remind_at'),
        to_attr='upcoming_reminders'  # store them in a SEPARATE attribute!
    )
)

# Why Prefetch with to_attr?
# WITHOUT to_attr:  note.reminders.all()         → NEW QuerySet (another SELECT!)
#              note.reminders.filter(...)      → NEW QuerySet (a different SELECT!)
# WITH to_attr:   note.upcoming_reminders        → list[Reminder] (already in memory!)
#   In the template: {% for r in note.upcoming_reminders %}  ← NO SELECT!
```

### Combining select_related and prefetch_related

```python
# A real example: the note_list view
notes = (
    Note.objects
    .select_related('user', 'notebook')     # FK → SQL JOIN (1 query)
    .prefetch_related('tags', 'reminders')  # M:N + reverse FK (2 queries)
    .filter(is_archived=False)
    .order_by('-is_pinned', '-priority', '-updated_at')
)
# TOTAL: 2 SQL queries for any number of notes ✓
# WITHOUT optimization: 1 + N + N SQL (for N notes)
```

### Annotate instead of N queries

```python
# ❌ WRONG: N+1!
notebooks = Notebook.objects.filter(user=user)
for nb in notebooks:
    count = nb.notes.filter(is_archived=False).count()  # a separate SELECT!
# 10 notebooks → 11 SQL queries!

# ✅ RIGHT: a single GROUP BY
notebooks = Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
)
# SQL: SELECT nb.*, COUNT(note.id) FILTER (WHERE note.is_archived=FALSE) AS note_count
#      FROM notebook nb LEFT JOIN note ON note.notebook_id=nb.id
#      WHERE nb.user_id=? GROUP BY nb.id
# 1 SQL! nb.note_count → a number, already in memory!
```

### Double annotation

```python
TodoList.objects.filter(user=user).annotate(
    total_items=Count('items'),                                    # total items
    done_items=Count('items', filter=Q(items__is_done=True))       # completed
)
# SQL: SELECT todolist.*,
#             COUNT(item.id) AS total_items,
#             COUNT(item.id) FILTER (WHERE item.is_done=TRUE) AS done_items
#      FROM todolist LEFT JOIN todoitem item ON item.todo_list_id = todolist.id
#      WHERE todolist.user_id = ? GROUP BY todolist.id
#
# In the template:
# todo.total_items → 5 (without a single SELECT!)
# todo.done_items  → 3 (without a single SELECT!)
# Progress: 3/5 = 60%
```

### How to detect N+1: Django Debug Toolbar

```bash
pip install django-debug-toolbar
```

```python
# settings.py:
INSTALLED_APPS = ['debug_toolbar', ...]
MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware', ...MIDDLEWARE]
INTERNAL_IPS = ['127.0.0.1']

# urls.py:
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [path('__debug__/', include(debug_toolbar.urls))] + urlpatterns
```

In the browser → the side panel shows all SQL queries with duplicates highlighted.

---

## F() — atomic operations

```python
from django.db.models import F

# ✅ Atomic increment (race-condition safe!)
# UPDATE hello_app_note SET views_count = views_count + 1 WHERE id = 42
Note.objects.filter(pk=42).update(views_count=F('views_count') + 1)

# ✅ Comparing two fields with each other
Note.objects.filter(views_count__gt=F('likes_count'))
# WHERE views_count > likes_count  (comparing COLUMNS, not values)

# ❌ Unsafe with concurrent requests:
note = Note.objects.get(pk=42)
note.views_count += 1   # reads in Python
note.save()             # writes back → race condition!
```

---

## transaction.atomic()

> An atomic operation: either ALL changes are saved, or NONE.

### The problem without atomic

```python
def create_note(user, title, tag_ids):
    note = Note.objects.create(user=user, title=title)
    # ← INSERT INTO note → id=42

    # AN ERROR HERE (for example, a tag does not exist):
    tags = Tag.objects.filter(id__in=tag_ids, user=user)
    note.tags.set(tags)   # ← An exception because of an invalid tag_id!

    # DATABASE STATE:
    # The Note with id=42 exists (the INSERT already happened)
    # But the tags are not attached
    # AN INCONSISTENT STATE! An "orphan" without tags
```

### The solution — transaction.atomic

```python
from django.db import transaction

def create_note(user, title, tag_ids):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title)
        # ← While inside the atomic block → BEGIN TRANSACTION

        tags = Tag.objects.filter(id__in=tag_ids, user=user)
        note.tags.set(tags)
        # ← If there is an exception → ROLLBACK of the whole block
        # The Note is NOT saved in the DB!

    # ← If everything is OK → COMMIT
    return note
```

### Nested atomic blocks — savepoints

```python
def complex_operation():
    with transaction.atomic():      # ← BEGIN
        do_operation_1()            # ← INSERT ...

        with transaction.atomic():  # ← SAVEPOINT sp_1
            do_operation_2()        # ← INSERT ...
            # If there is an exception here → ROLLBACK TO sp_1
            # operation_1 is kept!

        do_operation_3()            # ← INSERT ...
    # ← COMMIT (if everything is OK)
```

### @transaction.atomic as a decorator

```python
@transaction.atomic
def create_notebook(user, title, is_default=False):
    """
    Business rule: a user has only ONE default notebook.
    These two queries must be atomic:
    1. Reset the previous default
    2. Set the new one
    """
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        # ← If there is an exception here → there will be no "no default" situation
    return Notebook.objects.create(user=user, title=title, is_default=is_default)
    # ← Both operations succeed, or both are rolled back
```

---

## select_for_update() — preventing race conditions

```python
with transaction.atomic():
    # SELECT ... FOR UPDATE → locks the row until the end of the transaction
    note = Note.objects.select_for_update().get(pk=note_id)
    if not note.is_archived:
        note.is_archived = True
        note.save(update_fields=['is_archived'])
    # COMMIT → the lock is released

# nowait=True: raises DatabaseError instead of waiting if the row is already locked
try:
    note = Note.objects.select_for_update(nowait=True).get(pk=note_id)
except DatabaseError:
    return JsonResponse({'error': 'Ресурс зайнятий, спробуйте пізніше'}, status=409)
```

### Why select_for_update is needed for a toggle

```python
# WHY select_for_update()?
# The problem without locking:
#   Thread A: SELECT item WHERE id=5 → is_done=False
#   Thread B: SELECT item WHERE id=5 → is_done=False  (THE SAME VALUE!)
#   Thread A: UPDATE item SET is_done=True
#   Thread B: UPDATE item SET is_done=True  ← both set True!
#   Bug: the second click should have removed the checkmark!

with transaction.atomic():  # select_for_update REQUIRES atomic!
    item = TodoItem.objects.select_for_update().get(
        id=item_id,
        todo_list__user=user  # SECURITY: check access rights through the FK!
    )
    # SQL: SELECT ... FROM todoitem
    #      JOIN todolist ON todoitem.todo_list_id = todolist.id
    #      WHERE todoitem.id=? AND todolist.user_id=?
    #      FOR UPDATE  ← locks the row!

    item.is_done = not item.is_done
    item.save(update_fields=['is_done'])
# COMMIT → releases the row lock
```

---

## Navigation

- Previous: [Services and Selectors](services_and_selectors.md)
- Next: [PostgreSQL](postgresql.md)
