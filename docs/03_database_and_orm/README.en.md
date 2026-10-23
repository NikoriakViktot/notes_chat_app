# Part III. Models, Database and ORM

Models are a Python description of the domain. The ORM turns Python calls into SQL. This part covers the whole stack: relational DBs → Django models → migrations → QuerySet API → PostgreSQL specifics → optimization.

**Prerequisites:** Part II (Django Core).
**Level:** Beginner → Intermediate.

---

## Sections

| Document | What we will learn |
|----------|-----------|
| [Relational DBs](relational_db_foundations_full.md) | tables, keys, JOIN, ACID, SQL basics |
| [Django Models](django_orm_full.md) | `models.Model`, fields, relationships, `Meta`, `__str__`, constraints |
| [ORM in depth](django_orm_deep_full.md) | `Q`, `F`, `annotate`, `values()`, `only()`, `defer()`, N+1 |
| [Migrations](django_migrations_full.md) | `makemigrations`, `migrate`, squash, data migrations |
| [PostgreSQL](postgresql_advanced_full.md) | data types, `jsonb`, full-text search, `EXPLAIN ANALYZE` |
| [Indexes](indexing_deep_full.md) | B-tree, partial index, composite index, `db_index=True` |
| [Transactions](transactions_concurrency_full.md) | `atomic()`, isolation levels, `select_for_update()`, race conditions |
| [ORM Diagrams](orm_mermaid_full.md) | Mermaid ER diagrams, QuerySet pipeline |

---

## Key concepts

**Models — a Python description of tables:**

```python
class Note(models.Model):
    PRIORITY_LOW     = 1
    PRIORITY_MEDIUM  = 2
    PRIORITY_HIGH    = 3
    PRIORITY_URGENT  = 4
    PRIORITY_CHOICES = [(1,'🟢 Низький'),(2,'🟡 Середній'),(3,'🟠 Високий'),(4,'🔴 Терміново')]

    user      = models.ForeignKey(User, on_delete=models.CASCADE)
    group     = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True, blank=True)
    notebook  = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True)
    tags      = models.ManyToManyField(Tag, blank=True)
    title     = models.CharField(max_length=200)
    priority  = models.PositiveSmallIntegerField(default=1, validators=[MaxValueValidator(4)])
    is_pinned = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.CheckConstraint(check=Q(priority__gte=1) & Q(priority__lte=4), name='...')
        ]
```

**QuerySet API (lazy queries):**

```python
# A QuerySet is not SQL yet:
notes = Note.objects.filter(user=user).select_related('notebook').prefetch_related('tags')

# SQL runs only on materialization:
for note in notes:          # evaluate
    print(note.title)

list(notes)                 # evaluate
notes.count()               # SELECT COUNT(*)
notes.exists()              # SELECT 1 FROM ... LIMIT 1
```

**The N+1 problem and optimization:**

```python
# ❌ N+1: for 50 notes → 51 SQL queries
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)   # a separate SELECT for every note

# ✅ select_related: 1 JOIN
notes = Note.objects.select_related('notebook').all()

# ✅ prefetch_related: 2 queries (for M2M and reverse FK)
notes = Note.objects.prefetch_related('tags').all()
```

**Q objects and complex conditions:**

```python
from django.db.models import Q

# Your own notes OR the group's notes:
Note.objects.filter(Q(user=user) | Q(group__in=user.groups.all()))

# Pinned notes that are NOT archived:
Note.objects.filter(Q(is_pinned=True) & ~Q(is_archived=True))
```

**on_delete — what happens when the parent record is deleted:**

| `on_delete` | Behavior |
|-------------|-----------|
| `CASCADE` | deletes the dependent records along with it |
| `SET_NULL` | sets the FK to `NULL` (requires `null=True`) |
| `PROTECT` | blocks deletion if there are dependent records |
| `DO_NOTHING` | nothing (dangerous — can break the FK constraint) |

---

## Lazy evaluation — a step-by-step breakdown

A QuerySet is a query object, not a result. `filter()` only adds a condition; SQL is sent to the DB only on **materialization**.

**Step 1: filter() — no SQL yet**

```python
notes = Note.objects.filter(user=request.user)
# A Python QuerySet object. Nothing has been sent to the DB yet.
print(type(notes))  # <class 'django.db.models.query.QuerySet'>
```

**Step 2: conditions accumulate without SQL**

```python
qs = Note.objects.filter(user=request.user)  # lazy
qs = qs.filter(is_pinned=True)               # lazy, a condition is added
qs = qs.order_by('-updated_at')              # lazy
qs = qs.select_related('notebook')           # lazy

notes = list(qs)  # ← only here: ONE SELECT with all conditions and the JOIN
```

**When materialization happens:**

| Action | SQL |
|-----|-----|
| `for note in notes:` | `SELECT *` |
| `list(notes)` | `SELECT *` |
| `notes[0]` | `SELECT * LIMIT 1` |
| `notes.count()` | `SELECT COUNT(*)` |
| `notes.exists()` | `SELECT 1 ... LIMIT 1` |
| `len(notes)` | `SELECT *` (loads everything) |

---

### N+1 — a hidden problem in the template

Precisely because a QuerySet is lazy, N+1 quietly appears when a template is rendered:

```python
# views.py — looks fine: a single filter()
def notes_list(request):
    notes = Note.objects.filter(user=request.user)   # 1 query
    return render(request, 'notes_list.html', {'notes': notes})
```

```html
{# notes_list.html #}
{% for note in notes %}
    {{ note.user.username }}     {# ← Django materializes a separate QuerySet for every note.user! #}
    {{ note.notebook.title }}    {# ← another SELECT for every note.notebook! #}
{% endfor %}
```

100 notes → **201 SQL queries** instead of the expected one. Django does not know in advance that `note.user` will be needed for every note — it fetches the data "on demand".

**Solution: select_related and prefetch_related**

```python
# select_related — for ForeignKey and OneToOne (does a JOIN, still 1 query)
notes = (
    Note.objects.filter(user=request.user)
    .select_related('user', 'notebook')      # FK → JOIN
    .prefetch_related('tags', 'reminders')   # M:N, reverse FK → 2 extra queries
)
# Total: 1 + 2 = 3 queries instead of 1 + 100 + 100
```

**All optimizations live in `selectors.py`** — views stay thin:

```python
# notes_app/selectors.py
def get_user_notes(user):
    return (
        Note.objects.filter(Q(user=user) | Q(group__in=user.groups.all()))
        .select_related('user', 'notebook')
        .prefetch_related('tags', 'reminders')
        .order_by('-updated_at')
    )
```

The real implementation: `notes_app/selectors.py` — 13 functions, each with optimized queries.

---

## Where this is in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_app/models.py` | 9 models with ForeignKey, M2M, constraints |
| `notes_app/migrations/` | the full schema history — `0001_initial.py` → `000N_*.py` |
| `notes_app/selectors.py` | `select_related`, `prefetch_related`, `Q` in production code |
| `notes_app/tests/test_models.py` | tests for constraints, `__str__`, deletion behavior |

**Notes Chat App schema (simplified):**

```
User ──1:1──► UserProfile
User ──1:N──► Note ──M:N──► Tag
                  ──1:N──► Reminder
                  ──FK────► Group (SET_NULL)
                  ──FK────► Notebook (SET_NULL)
User ──1:N──► TodoList ──M:N──► User (shared_with)
                         ──1:N──► TodoItem
User ──1:N──► ShoppingList ──M:N──► User (shared_with)
                             ──FK──► Group (SET_NULL)
                             ──1:N──► ShopItem
Group ──1:N──► ChatMessage  (author CASCADE, group CASCADE)
```

---

## How this connects to the rest of the course

```text
Part III: Models/ORM → Part VI: Selectors (read-only ORM)
Part III: Q objects  → Part VII: IDOR protection
Part III: Transactions → Part VIII: test isolation (TransactionTestCase)
```

**Zero to Hero:** Step 2 — the first model and the first migration. Step 3 — ORM in CRUD via selectors.

**Lab:** [ORM Lab](../labs/orm_lab.md) — Q queries, investigating N+1, `EXPLAIN ANALYZE`.

---

## Practice

1. Run in the shell: `Note.objects.filter(user__username='demo').values('title', 'priority')`.
2. Look for N+1 in `notes_app/selectors.py` — make sure `select_related`/`prefetch_related` are there.
3. Run `python manage.py dbshell` → `EXPLAIN ANALYZE SELECT * FROM notes_app_note WHERE user_id=1;`.
4. Add a new model → `makemigrations` → look at the generated migration file.

---

## Review questions

- What is lazy evaluation in a QuerySet? When does the SQL run?
- What is the difference between `CASCADE` and `SET_NULL`? When should you use each one?
- What is the N+1 problem? How do `select_related` and `prefetch_related` solve it?
- Why do we need `atomic()`, and what happens when an exception is raised inside it?
- Why is `PositiveSmallIntegerField` with `MaxValueValidator(4)` better than a plain `IntegerField`?
- What is a `CheckConstraint`, and where is it checked — in Python or in the DB?

---

**Next →** [Part IV. Forms and Validation](../04_forms_and_validation/README.md) — how data arrives from the user.
