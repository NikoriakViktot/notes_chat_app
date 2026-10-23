# Transactions, Indexes and PostgreSQL

> Transactions protect data integrity when failures happen.
> Indexes speed up lookups in tables with millions of rows.
> PostgreSQL is the project's production DB: it supports constraints, JSONB, spatial data.

---

## Transactions — why

**Scenario:** A student creates a note with tags. Without a transaction:

```
1. Note.objects.create(...)   ✓  ← note is in the DB
2. Server crash!              ✗  ← tags were not added
→ The note exists, but without tags. Inconsistent state.
```

With a transaction it is all or nothing:

```
BEGIN;
  INSERT INTO notes_app_note ... → ✓
  INSERT INTO notes_app_note_tags ... → ✗ (crash)
ROLLBACK;
→ Nothing was saved. The state is consistent.
```

---

## `transaction.atomic()` in notes_chat_app

### `create_note` — note + tags together

```python
# notes_app/services.py

def create_note(*, user, title, content='', notebook=None, priority=1, group=None, tag_ids=None):
    with transaction.atomic():
        note = Note.objects.create(
            user=user, title=title, content=content,
            notebook=notebook, priority=priority, group=group
        )
        if tag_ids:
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)   # ← M:N operation inside the transaction
    return note
```

If `tags.set()` fails (for example, invalid IDs), `create()` is rolled back too. No orphaned notes without tags.

### `create_notebook` — changing the default notebook

```python
def create_notebook(*, user, title, color='#4A90E2', is_default=False):
    with transaction.atomic():
        if is_default:
            # Unset the previous default BEFORE setting the new one
            Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        return Notebook.objects.create(user=user, title=title, color=color, is_default=is_default)
```

Without a transaction: if `create()` fails after `update()`, no notebook will be the default.

### Nested transactions (savepoints)

```python
# Django automatically uses SAVEPOINT for nested atomic blocks:
with transaction.atomic():        # BEGIN
    note = Note.objects.create(...)
    with transaction.atomic():    # SAVEPOINT sp1
        note.tags.set(tags)       # if an exception happens here → ROLLBACK TO sp1
    # The outer transaction continues
```

---

## The `@transaction.atomic` decorator

```python
from django.db import transaction

@transaction.atomic
def process_group_join(user, group):
    """Adds the user to the group and posts a message to the chat."""
    group.user_set.add(user)
    ChatMessage.objects.create(
        group=group,
        author=user,
        content=f'{user.username} приєднався до групи'
    )
```

---

## Indexes — why and when

Without an index, PostgreSQL scans the ENTIRE table (Seq Scan):

```sql
-- Without an index (1M-row table):
SELECT * FROM notes_app_note WHERE user_id = 1 ORDER BY updated_at DESC;
-- → Seq Scan: reads ALL 1M rows → 800ms

-- With an index (user_id, updated_at):
-- → Index Scan: reads only this user's rows → 2ms
```

### Indexes in the Note model

```python
# notes_app/models.py

class Note(models.Model):
    ...
    class Meta:
        indexes = [
            # Covers: Note.objects.filter(user=user).order_by('-updated_at')
            models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),

            # Covers: Note.objects.filter(user=user, is_pinned=True)
            models.Index(fields=['user', 'is_pinned'], name='cnote_user_pinned_idx'),
        ]
```

### Index in ChatMessage

```python
class ChatMessage(models.Model):
    ...
    class Meta:
        indexes = [
            # Covers: ChatMessage.objects.filter(group=group).order_by('timestamp')
            # The only query pattern in the chat — "the last N messages for group X"
            models.Index(fields=['group', 'timestamp'], name='chat_group_ts_idx'),
        ]
```

### When to add an index

| Add an index | Not needed |
|--------------|------------|
| `filter()` on a frequently used field | Fields that are rarely filtered |
| `order_by()` on a large table | Small tables (< 10k rows) |
| FK fields (not ForeignKey — Django adds it automatically) | Text searches (needs GIN) |
| `unique=True` fields (Django adds it automatically) | Fields that are updated often |

!!! note "ForeignKey → automatic index"
    Django automatically adds `db_index=True` for every `ForeignKey` field. You do not need to add it manually for `note.user_id`, `note.notebook_id` etc.

---

## CheckConstraint — validation at the DB level

```python
class Note(models.Model):
    priority = models.PositiveSmallIntegerField(...)

    class Meta:
        constraints = [
            # The DB rejects priority < 1 or > 4 even if Django lets it through
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='cnote_priority_valid_range'
            ),
        ]
```

```python
class ShopItem(models.Model):
    quantity = models.DecimalField(...)

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=models.Q(quantity__gt=0),
                name='cshop_item_positive_qty'
            ),
        ]
```

A constraint is protection at the DB level. Even a direct SQL `UPDATE SET priority = 99` will be rejected by PostgreSQL.

---

## PostgreSQL vs SQLite

| Feature | SQLite | PostgreSQL |
|-----------|--------|-----------|
| Data types | limited | full (JSONB, ARRAY, UUID, hstore) |
| Concurrency | 1 writer at a time | full MVCC, many writers |
| Full-text search | basic | tsvector, GIN indexes |
| CheckConstraint | supported | supported |
| Size | a file on disk | server, network |
| Backup | `cp db.sqlite3` | `pg_dump`, WAL |

**In notes_chat_app:** `settings.py` automatically selects the DB from `DATABASE_URL`:

```python
# notes_project/settings.py
import dj_database_url

DATABASES = {
    'default': dj_database_url.config(
        default='sqlite:///db.sqlite3',  # fallback for tests without Docker
        conn_max_age=0,                  # IMPORTANT for ASGI: do not keep connections between requests
    )
}
```

`conn_max_age=0` is critical for ASGI/async. Persistent connections are not thread-safe in an async context.

---

## EXPLAIN ANALYZE — diagnosing slow queries

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection
from notes_app import selectors
from django.contrib.auth.models import User

user = User.objects.get(username='demo_alice')
qs = selectors.get_user_notes(user)

# Get EXPLAIN ANALYZE from PostgreSQL
print(qs.explain(verbose=True, analyze=True))
```

```
Seq Scan on notes_app_note  (cost=0.00..1234.56 rows=5 width=200)
  Filter: (user_id = 1)
Planning Time: 0.5 ms
Execution Time: 12.3 ms
```

vs. with an index:

```
Index Scan using cnote_user_updated_idx on notes_app_note
  Index Cond: (user_id = 1)
Planning Time: 0.3 ms
Execution Time: 0.2 ms
```

---

## In the book

- [Django Models](django_models.md) — where constraints and indexes are defined
- [Query Optimization](query_optimization.md) — select_related, prefetch_related, N+1
- [Step 9. PostgreSQL](../tutorials/09_deployment/postgresql.md) — PostgreSQL in Docker

---

## Official documentation

- [Django: Database transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/) — atomic(), savepoints
- [Django: Model indexes](https://docs.djangoproject.com/en/5.2/ref/models/indexes/) — Index, UniqueIndex
- [Django: Constraints](https://docs.djangoproject.com/en/5.2/ref/models/constraints/) — CheckConstraint, UniqueConstraint
- [PostgreSQL: EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html) — query diagnostics
- [dj-database-url](https://github.com/jazzband/dj-database-url) — DATABASE_URL parsing
