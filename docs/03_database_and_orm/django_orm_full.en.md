# Django ORM — From the Basics to the Deep Mechanics

> ORM (Object-Relational Mapping) is a translator between Python and SQL.
> You write `Note.objects.filter(user=user)` — Django generates `SELECT ... WHERE user_id = ?`.
> But the ORM is **smart**: it runs SQL only when needed, caches results, and protects against SQL injection.

---

## Why the ORM and Not Raw SQL

```python
# Without the ORM — dangerous and hard:
cursor.execute(f"SELECT * FROM notes WHERE user_id = {user.id}")
# ↑ SQL injection! a title with ' OR 1=1-- will break the system

# With the ORM — safe and clear:
Note.objects.filter(user=user)
# ↑ automatically: WHERE user_id = %s, [user.id]
# ↑ the same on SQLite and PostgreSQL
# ↑ the result is Python objects, not raw rows
```

---

## Mental Model: A QuerySet Is a Recipe, Not a Dish

```
Note.objects.filter(is_archived=False)
     ← this is a RECIPE, not SQL

.select_related('user')
     ← we add an ingredient to the recipe

.order_by('-created_at')
     ← one more refinement

list(qs)  ← HERE Django cooks the dish — runs ONE SQL query
```

**SQL execution triggers:**

```
for note in qs:          ← iteration
list(qs)                 ← explicit conversion
qs.first()               ← LIMIT 1
qs[0]                    ← LIMIT 1 OFFSET 0
qs.count()               ← SELECT COUNT(*)
bool(qs)                 ← EXISTS()
len(qs)                  ← executes and caches
```

---

## 1. Models and Managers

**`Model` = class ↔ table. Instance = row. `objects` = gateway to the DB.**

```python
# A basic model with a Custom Manager

class ActiveNoteManager(models.Manager):
    """Custom Manager — returns only non-archived notes."""
    def get_queryset(self):
        return super().get_queryset().filter(is_archived=False)

    def recent(self):
        """The last 10 non-archived notes."""
        return self.get_queryset().order_by('-updated_at')[:10]


class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_URGENT = 4
    PRIORITY_CHOICES = [(1, '🟢 Низький'), (2, '🟡 Середній'),
                        (3, '🟠 Високий'), (4, '🔴 Терміново')]

    user     = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    group    = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True, blank=True)
    notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True)
    tags     = models.ManyToManyField(Tag, blank=True, related_name='notes')

    title      = models.CharField(max_length=200)
    content    = models.TextField(blank=True)
    priority   = models.PositiveSmallIntegerField(choices=PRIORITY_CHOICES, default=PRIORITY_LOW)
    is_pinned  = models.BooleanField(default=False)
    is_archived= models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)  # set once on CREATE
    updated_at = models.DateTimeField(auto_now=True)       # updated on every save()

    # Two Managers:
    objects  = models.Manager()         # the standard one
    active   = ActiveNoteManager()      # custom: Note.active.all()

    def __str__(self):
        return f"{'📌 ' if self.is_pinned else ''}{self.title}"

    class Meta:
        ordering = ['-is_pinned', '-priority', '-updated_at']
        indexes = [
            models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='cnote_priority_valid_range'
            ),
        ]
```

**Object lifecycle:**

```
note = Note(title='Test', user=user)  → Python object, note.id = None, 0 SQL

note.save()
SQL: INSERT INTO notes_app_note (...) VALUES (...) RETURNING id

note.title = 'Updated'
note.save(update_fields=['title'])    # more efficient — UPDATE only title

note.delete()
SQL: DELETE FROM notes_app_note WHERE id=42
```

---

## 2. QuerySet — A Chain of Methods

```python
# filter / exclude
Note.objects.filter(user=user, is_archived=False)
Note.objects.exclude(is_pinned=True)

# Q objects — OR / AND / NOT
from django.db.models import Q

Note.objects.filter(Q(user=user) | Q(group__in=user_groups))
Note.objects.filter(Q(title__icontains=q) | Q(content__icontains=q))

# Ordering
Note.objects.order_by('-priority', '-updated_at')   # several fields

# Limiting
Note.objects.filter(user=user)[:10]                 # LIMIT 10
Note.objects.filter(user=user)[10:20]               # LIMIT 10 OFFSET 10

# Lookups across FKs via __ (Django does the JOIN automatically)
Note.objects.filter(user__username='demo_alice')
Note.objects.filter(notebook__title__icontains='django')
Note.objects.filter(tags__name='python').distinct()  # M:N → distinct because of the JOIN
```

### Field Lookups Table (__)

```python
# Strings
field__exact = 'val'        # WHERE field = 'val'
field__iexact = 'val'       # WHERE LOWER(field) = LOWER('val')
field__contains = 'val'     # WHERE field LIKE '%val%'
field__icontains = 'val'    # WHERE LOWER(field) LIKE '%val%'
field__startswith = 'val'   # WHERE field LIKE 'val%'
field__in = [1, 2, 3]       # WHERE field IN (1, 2, 3)

# Numbers
field__gt = 5               # >
field__gte = 5              # >=
field__lt = 5               # <
field__lte = 5              # <=
field__range = (1, 10)      # BETWEEN 1 AND 10

# NULL
field__isnull = True        # WHERE field IS NULL

# Dates
field__year = 2024          # EXTRACT(YEAR FROM field) = 2024
field__date = date(2024,1,1)# DATE(field) = '2024-01-01'
```

---

## 3. The N+1 Problem and select_related / prefetch_related

**N+1 is the most common performance mistake in Django.**

```python
# ❌ PROBLEM — N+1
notes = Note.objects.filter(user=user)
for note in notes:
    print(note.notebook.title)  # ← a separate SQL query for every note!
# 1 query for the notes + N queries for the notebooks = N+1

# ✅ SOLUTION for ForeignKey — select_related (SQL JOIN)
notes = Note.objects.filter(user=user).select_related('notebook', 'group')
# 1 SQL query with a JOIN:
# SELECT notes.*, notebooks.*, groups.*
# FROM notes_app_note notes
# LEFT JOIN notes_app_notebook notebooks ON notes.notebook_id = notebooks.id
# LEFT JOIN auth_group groups ON notes.group_id = groups.id

# ✅ SOLUTION for ManyToMany — prefetch_related (a separate IN query)
notes = Note.objects.filter(user=user).prefetch_related('tags')
# Query 1: SELECT * FROM notes_app_note WHERE user_id = 1
# Query 2: SELECT * FROM notes_app_tag
#          INNER JOIN notes_app_note_tags ON ... WHERE note_id IN (1,2,...,50)
# Result: 2 queries regardless of the number of notes
```

### When to Use Which

| Relationship type | Method | SQL |
|-------------|-------|-----|
| ForeignKey | `select_related('notebook')` | 1 JOIN |
| OneToOne | `select_related('user__profile')` | 1 JOIN |
| ManyToMany | `prefetch_related('tags')` | 2 queries |
| Reverse FK | `prefetch_related('reminders')` | 2 queries |

### Prefetch with a Filter

```python
from django.db.models import Prefetch

# Load only UPCOMING reminders
Note.objects.prefetch_related(
    Prefetch(
        'reminders',
        queryset=Reminder.objects.filter(remind_at__gte=timezone.now()),
        to_attr='upcoming_reminders'   # note.upcoming_reminders instead of note.reminders.all()
    )
)
```

---

## 4. F() Expressions — Atomic Operations

**F() is a reference to a column's value inside the DB itself. It solves race conditions.**

```python
from django.db.models import F

# An illustrative example: suppose Note has a views_count counter
# (the project's model has no such field)

# ❌ DANGEROUS — race condition under concurrent requests
note = Note.objects.get(id=1)
note.views_count += 1  # we read 100, 1000 processes do the same thing at once
note.save()            # all of them write 101, though it should be 1100

# ✅ SAFE — an atomic operation at the DB level
Note.objects.filter(id=1).update(views_count=F('views_count') + 1)
# SQL: UPDATE notes SET views_count = views_count + 1 WHERE id=1
# PostgreSQL executes this atomically, without a race condition

# F() for a toggle (used in notes_chat_app services.py!)
Note.objects.filter(pk=note.pk).update(is_pinned=~F('is_pinned'))
note.refresh_from_db(fields=['is_pinned'])  # ← the Python object does not know about the change in the DB

# F() for comparing two columns
Note.objects.filter(priority__gt=F('is_pinned'))  # a hypothetical example

# F() with arithmetic
Note.objects.update(views_count=F('views_count') * 2)
```

---

## 5. annotate() and aggregate()

```python
from django.db.models import Count, Sum, Avg, Max, Q

# aggregate() — one value for the whole QuerySet
result = Note.objects.filter(user=user).aggregate(
    total=Count('id'),
    avg_priority=Avg('priority'),
    max_priority=Max('priority'),
)
# result = {'total': 42, 'avg_priority': 2.1, 'max_priority': 4}

# annotate() — a computed column for EACH object
# Used in notes_chat_app selectors.py!
notebooks = Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
).order_by('-is_default', 'title')
# SQL: SELECT notebooks.*, COUNT(notes.id) AS note_count
#      FROM notebooks LEFT JOIN notes ON ... WHERE notes.is_archived = false
#      GROUP BY notebooks.id
# Usage: notebook.note_count → without a single extra SQL query!

# Two annotations together
TodoList.objects.filter(user=user).annotate(
    total_items=Count('items'),
    done_items=Count('items', filter=Q(items__is_done=True))
)
# todo.total_items, todo.done_items — available in the template without SQL

# alias() — compute for filtering, but do not include in SELECT
Note.objects.alias(
    tag_count=Count('tags')
).filter(tag_count__gt=3)
# WHERE COUNT(tags) > 3, but tag_count is NOT in SELECT
```

---

## 6. transaction.atomic()

**`atomic()` is "all or nothing" for a group of operations.**

```python
from django.db import transaction

# ✅ CORRECT — related operations in a single transaction
def create_note(*, user, title, content='', tag_ids=None):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title, content=content)
        if tag_ids:
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)   # ← M:N inside the transaction
    return note
# If tags.set() fails → create() is rolled back too. No orphaned notes.

# ❌ CRITICAL MISTAKE — try/except inside atomic!
with transaction.atomic():
    try:
        note = Note.objects.create(...)
    except Exception:
        pass  # ← the TRANSACTION IS "BROKEN", TransactionManagementError!

# ✅ CORRECT — catch the exception OUTSIDE
try:
    with transaction.atomic():
        note = Note.objects.create(...)
        note.tags.set(tags)
except Exception as e:
    logger.error(f"Failed: {e}")
    return None

# on_commit — run AFTER a successful COMMIT
def create_note_and_notify(user, title):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title)
        # The Celery task will not start if the transaction is rolled back
        transaction.on_commit(
            lambda: send_reminder_email.delay(note.id)
        )
```

### Nested atomic → Savepoints

```python
with transaction.atomic():         # BEGIN
    note = Note.objects.create(...)
    with transaction.atomic():     # SAVEPOINT sp_1
        note.tags.set(tags)        # if it fails → ROLLBACK TO sp_1
    # The Note is kept even if tags failed
```

---

## 7. Useful Patterns

```python
# get_or_create — CREATE if it does not exist (an idempotent operation)
notebook, created = Notebook.objects.get_or_create(
    user=user, is_default=True,
    defaults={'title': 'Основний', 'color': '#4A90E2'}
)
# Returns (object, bool) — bool=True if it was JUST CREATED

# update_or_create — UPDATE if it exists, CREATE if not
profile, _ = UserProfile.objects.update_or_create(
    user=user,
    defaults={'bio': new_bio, 'timezone': timezone_str}
)

# bulk_create — bulk creation (1 SQL query instead of N)
tags = [Tag(name=name, user=user) for name in ['python', 'django', 'orm']]
Tag.objects.bulk_create(tags, ignore_conflicts=True)

# bulk_update — bulk update (1 SQL query)
notes_to_archive = list(Note.objects.filter(user=user, is_archived=False))
for note in notes_to_archive:
    note.is_archived = True
Note.objects.bulk_update(notes_to_archive, ['is_archived'])

# values() and values_list() — dict/tuple instead of Model objects
Note.objects.filter(user=user).values('id', 'title', 'priority')
# → [{'id': 1, 'title': '...', 'priority': 2}, ...]

Note.objects.filter(user=user).values_list('id', flat=True)
# → QuerySet([1, 2, 3, ...])

# Used in selectors.py for a JSON response:
return list(
    Reminder.objects.filter(...).values('id', 'message', 'remind_at', 'note__title')
)

# only() / defer() — deferred field loading
Note.objects.only('id', 'title')    # only these fields (a smaller SELECT)
Note.objects.defer('content')       # everything EXCEPT content

# iterator() — streaming for large QuerySets (does not load everything into RAM)
for note in Note.objects.filter(user=user).iterator(chunk_size=1000):
    process(note)
```

---

## 8. An Architecture Question: Why the Price Is Fixed in the Order

> A classic interview question. It reveals an understanding of the immutability of transactional data.

**Scenario:** `Order` → `Product` via a ForeignKey, and the price is taken from `Product.current_price`.

```
May 1: A student bought a book for $20. Order → Product (current_price=20)
May 10: The price was raised to $25
May 15: The student views the order → order.product.current_price = $25 (WRONG!)
```

**The solution is denormalization: store the price directly in the order:**

```python
class OrderItem(models.Model):
    order   = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.RESTRICT)
    quantity = models.PositiveIntegerField(default=1)
    # A snapshot of the price at the moment of purchase — never changes
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2)

    def get_cost(self):
        return self.purchase_price * self.quantity

# When placing an order:
OrderItem.objects.create(
    order=order,
    product=product,
    purchase_price=product.current_price,  # ← copy the current price
    quantity=1
)
```

**Principle:** The catalog (Product) is mutable. The transaction (OrderItem) is an immutable fact. Financial integrity matters more than normalization.

---

## 9. MVCC — How PostgreSQL Provides Concurrency

**MVCC (Multi-Version Concurrency Control)** — PostgreSQL keeps several versions of a row at the same time.

**Architectural rule:** "Readers do not block writers, writers do not block readers."

```
Transaction A reads Notes:     [row_v1: id=1, title='Django', xmin=100]
Transaction B updates:         [row_v2: id=1, title='Django ORM', xmin=101]
Transaction A (still active):  ← sees row_v1, does not see row_v2
Transaction A finishes COMMIT:
Transaction B finishes COMMIT:
New reader: ← sees row_v2
```

**Isolation levels:**
- **Read Committed** (the default in PostgreSQL and Django): protects against dirty reads, but allows non-repeatable reads
- **Repeatable Read**: freezes the snapshot for the whole transaction
- **Serializable**: maximum isolation, lowers throughput

**`select_for_update()` — explicit row locking:**

```python
with transaction.atomic():
    note = Note.objects.select_for_update().get(pk=pk)
    # SQL: SELECT ... FOR UPDATE
    # Locks the row until the end of the transaction
    note.title = new_title
    note.save()
    # Other transactions trying to change this row wait
```

---

## 10. Debugging Queries

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection, reset_queries
from django.conf import settings

settings.DEBUG = True
reset_queries()

from notes_app import selectors
from django.contrib.auth.models import User
user = User.objects.get(username='demo_alice')
notes = list(selectors.get_user_notes(user))

print(f"SQL queries: {len(connection.queries)}")
for q in connection.queries[:5]:
    print(q['sql'][:100], '→', q['time'])

# EXPLAIN ANALYZE
qs = selectors.get_user_notes(user)
print(qs.explain(verbose=True, analyze=True))
# Seq Scan vs Index Scan — the key performance difference

# View the SQL of any QuerySet
print(qs.query)
```

---

## Prediction Exercises

### Exercise 1: Lazy Evaluation

```python
qs = Note.objects.filter(user=user)
qs = qs.order_by('-priority')
qs = qs.select_related('notebook')
```

**How many SQL queries were executed?** → **0 queries.** A QuerySet is lazy — SQL runs only on iteration.

### Exercise 2: N+1

```python
notes = Note.objects.all()[:10]
for note in notes:
    print(note.notebook.title)
```

**How many SQL queries?** → **1 + 10 = 11 queries.** Fix: `.select_related('notebook')` → **1 query**.

### Exercise 3: F() vs Python

```python
# Option A:
note = Note.objects.get(pk=1); note.is_pinned = not note.is_pinned; note.save()

# Option B:
Note.objects.filter(pk=1).update(is_pinned=~F('is_pinned'))
```

**The difference?** → A: 2 SQL queries + a race condition. B: 1 atomic SQL query. B is always better for toggles.

---

## Self-Check Questions

1. What is Lazy Evaluation, and when is SQL actually executed?
2. What is the difference between `select_related` and `prefetch_related`?
3. What is N+1, and how do you detect it with `connection.queries`?
4. Why is `F('views_count') + 1` safer than `note.views_count + 1`?
5. What happens if you put a `try/except` inside `atomic()`?
6. What is the difference between `annotate()` and `aggregate()`?
7. When should you use `bulk_create()`, and what is its advantage?
8. Why should the product price in an order be stored separately from `Product.price`?

---

## In the Book

- [Django Models](django_models.md) — fields, relationships, Meta
- [Migrations](migrations.md) — schema version control
- [Query Optimization](query_optimization.md) — real examples from notes_chat_app
- [Transactions and PostgreSQL](transactions_indexes_postgresql.md) — atomic, indexes, MVCC

---

## Official Documentation

- [Django: Making queries](https://docs.djangoproject.com/en/5.2/topics/db/queries/) — the QuerySet API
- [Django: QuerySet API reference](https://docs.djangoproject.com/en/5.2/ref/models/querysets/) — all methods
- [Django: Database access optimization](https://docs.djangoproject.com/en/5.2/topics/db/optimization/) — best practices
- [Django: Aggregation](https://docs.djangoproject.com/en/5.2/topics/db/aggregation/) — annotate, aggregate
- [Django: Transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/) — atomic, on_commit
- [PostgreSQL: MVCC](https://www.postgresql.org/docs/current/mvcc.html) — how PostgreSQL isolates transactions
