# PostgreSQL Indexes — The Deep Mechanics

> Indexes exist to avoid reading every row on disk.
> This document explains WHY indexes are so effective (B-Tree, GIN),
> when to add them, when not to, and how to check their effectiveness with EXPLAIN ANALYZE.

---

> 🔬 **See EXPLAIN ANALYZE in action:**
> [`docs/reference/legacy_source/orm_laboratory_reference.md`](../reference/legacy_source/orm_laboratory_reference.md)
>
> ⚠️ The notebook itself is not part of this repository: the linked file only explains that. The section names in the table below point to the notebook's original structure, they are not anchors. You can run the same queries yourself in `python manage.py shell` or in the [ORM lab](../labs/orm_lab.md).
>
> | Concept | Notebook section |
> |-----------|-----------------|
> | `queryset.explain(analyze=True)` — Index Scan vs Seq Scan | `## 11. 🔬 SQL Inspection` |
> | `.query` — viewing the generated SQL | `## 11. 🔬 SQL Inspection` |
> | `connection.queries` — all SQL queries of the session | `## 11. 🔬 SQL Inspection` |
> | N+1 → indexes solve part of the problem | `## 8. ⚡ N+1 Problem` |



> **🧠 Mental model:** A database WITHOUT an index is like a library without a catalog. To find the book "Django ORM", you have to look through every shelf in order. With an index, you walk up to the card catalog, find "Django ORM" → "rack 7, row 3, spot 42". Seconds instead of hours.
>
> **📚 Why indexes are not "free":** An index = a separate data structure on disk. On every INSERT/UPDATE/DELETE → PostgreSQL updates both the table and all the indexes on it. 10 indexes on a table = every write costs 11 write operations (1 table + 10 indexes). Too many indexes → slow writes.
>
> **🌐 How PostgreSQL decides to use an index:** The Query Planner computes the cost: sequential scan (read the whole table) vs index scan (B-Tree traversal + heap fetch). If a SELECT returns >5-10% of the table's rows → a sequential scan may be cheaper! The Planner knows the table statistics and picks the optimal plan.
>
> **❌ A typical beginner mistake:** "I'll add an index on every field — it'll be faster." In reality, an unnecessary index slows down INSERT/UPDATE/DELETE, takes up disk space, and may not be used by the Planner if the condition is not selective. Indexes are a strategic decision, not "more is always better".

---

## 1. Sequential Scan vs Index Scan — The Physics

---
> **🧠 Mental model:** Sequential Scan = reading a book from the first page to the last to find one paragraph. Index Scan = first you look at the table of contents → find the page number → open it right away. The difference: O(N) vs O(log N).
>
> **📚 The physical level:** A PostgreSQL table is stored in 8KB "pages". Sequential Scan = read all the pages in a row. 1 million rows (≈10 rows per page → 100,000 pages × 8KB) = ~800MB to read. With an index: B-Tree traversal (3-4 disk I/Os) → get the heap tuple pointer → 1 heap read. In total: 4-5 I/O operations instead of a million.
>
> **🌐 When the Planner chooses a Sequential Scan instead of an index:** If the WHERE clause returns >10-15% of the rows, a sequential scan will be more efficient (one pass over the disk vs many random I/Os through the index). The Planner takes this into account.
>
> **❌ A typical mistake:** Adding an index and wondering why it is not used. `WHERE status = 'published'` on a table where 80% of rows = 'published' → the Planner correctly chooses a Sequential Scan. An index is useful when the condition is **selective** (returns a small % of rows).
---

```
Sequential Scan (O(N)):
Table notes_note: 1,000,000 rows

Disk: [ Page 1 ][ Page 2 ][ Page 3 ] ... [ Page 100,000 ]
          ↑──────────────────────────────────────────────────
          We read EVERYTHING to find WHERE user_id=5

Operations: 100,000 page reads (800MB!)
Time: ~500ms - 2s depending on the disk and cache
```

```
Index Scan (O(log N)):
B-Tree index on user_id:

                    [Root: 500]
                   /            \
          [250]                    [750]
         /     \                  /     \
    [125]      [375]          [625]      [875]
     / \        / \            / \        / \
  [100][150] [300][400]    [600][650] [800][900]
   ↑
   Leaf: [5] → pointer to heap page 42, slot 7

Operations: log₂(1,000,000) ≈ 20 comparisons → 3-4 disk I/O
Time: ~0.05ms - 1ms
```

---

## 2. B-Tree Index — The Internal Structure

---
> **🧠 Mental model:** A B-Tree (Balanced Tree) is an ordered tree-like structure where search, insertion and deletion are O(log N). "Balanced" means all leaves are at the same depth. For a table with 1 billion rows, a binary tree would be ≈ log₂(1,000,000,000) ≈ 30 levels deep. But a B-Tree node is a whole page holding hundreds of keys, so the real B-Tree depth is only 3–5 levels: a few page reads and ~30 comparisons instead of a billion!
>
> **📚 How a B-Tree is stored on disk:** Each node = one page (8KB). Each page holds ~200-400 entries. Root → Branch nodes → Leaf nodes. Leaf nodes store the values + TID (tuple identifier = pointer to a heap page + offset). Sequential reads across leaf nodes = an efficient range scan.
>
> **🌐 B-Tree for Django:** `db_index=True`, `unique=True`, and a standard `models.Index(fields=[...])` all create a B-Tree. Efficient for: `=`, `>`, `<`, `>=`, `<=`, `BETWEEN`, `ORDER BY`, `LIKE 'prefix%'`. NOT efficient for: `LIKE '%suffix'`, `LOWER()`, `UPPER()` (unless there is a functional index).
>
> **❌ A typical mistake:** Using `LIKE '%python%'` and expecting the index to work. A B-Tree index cannot efficiently search for "contains a substring" (only "starts with"). For `icontains` → you need a trigram index (GIN with pg_trgm).
---

```
B-Tree structure for index on notes_note(user_id):

                        ┌──────────────┐
                        │  Root Node   │
                        │   [250,500]  │
                        └──────────────┘
                        /       │       \
              ┌────────┐   ┌────────┐   ┌────────┐
              │ Branch │   │ Branch │   │ Branch │
              │ [5,50] │   │[251,350]│  │[501,750]│
              └────────┘   └────────┘   └────────┘
              /       \         ...         ...
      ┌──────┐   ┌──────┐
      │ Leaf │ ↔ │ Leaf │   ← leaves are DOUBLY linked!
      │ [1,2,│   │[6,7, │   (efficient for range scans: ORDER BY)
      │  3,4]│   │ 8,9] │
      │  TIDs│   │ TIDs │   TID = (page_number, slot_number) → pointer into the heap
      └──────┘   └──────┘

Searching for user_id=5:
  Root: 5 < 250 → go left
  Branch: 5 ≤ 50 → go to the first leaf
  Leaf: we find 5 → TID = (42, 7)
  Heap: read page 42, slot 7 → return the row

In total: 3-4 I/O operations for a billion rows.
```

---

## 3. Composite Index — The "Leading Column" Rule

---
> **🧠 Mental model:** A composite index is like a phone book sorted by **last name, then first name**. Searching by the last name "Shevchenko" → efficient. Searching by the first name "Taras" → you'll have to read the whole book (the last name isn't given → no idea where to look).
>
> **📚 The leading column rule:** A composite index `(A, B, C)` is efficient for: `WHERE A=`, `WHERE A= AND B=`, `WHERE A= AND B= AND C=`, `ORDER BY A, B`. NOT efficient for: `WHERE B=` (A not given), `WHERE C=` (A and B not given). Always start with the most selective or most frequently used field.
>
> **🌐 How this looks in Django:** `models.Index(fields=['user', '-updated_at'])` → `CREATE INDEX ON notes_note (user_id, updated_at DESC)`. Efficient for `filter(user=X).order_by('-updated_at')` — a typical query for a list of notes.
>
> **❌ A typical mistake:** Relying on a composite index where the leading column is not used. `Index(fields=['status', 'user'])` → `WHERE user=5` without `WHERE status=` → the index is NOT used (not the leading column!). You need a separate `Index(fields=['user'])`.
---

```python
class Note(models.Model):
    user = models.ForeignKey(User, ...)
    status = models.CharField(max_length=20, ...)
    updated_at = models.DateTimeField(auto_now=True)
    views_count = models.PositiveIntegerField(default=0)

    class Meta:
        indexes = [
            # ✅ Index for a typical query: a user's notes sorted by date
            # Efficient for: filter(user=X).order_by('-updated_at')
            models.Index(
                fields=['user', '-updated_at'],
                name='note_user_updated_idx'
            ),

            # ✅ For: filter(user=X, status='published')
            models.Index(
                fields=['user', 'status'],
                name='note_user_status_idx'
            ),

            # ✅ For analytics: top by views
            models.Index(
                fields=['-views_count'],
                name='note_views_desc_idx'
            ),
        ]
```

```
Composite index (user_id, updated_at) usage table:

Query                                    | Index?
─────────────────────────────────────────┼─────────
filter(user=X).order_by('-updated_at')   | ✅ Yes
filter(user=X)                           | ✅ Yes (leading column)
filter(user=X, status='pub')             | ✅ Partially (only the user_id part)
filter(status='pub').order_by('-updated_at') | ❌ No (status is not leading!)
order_by('-updated_at')                  | ❌ No (user_id not given)
```

---

## 4. Covering Index — Index-Only Scan

---
> **🧠 Mental model:** A covering index is a catalog that contains not only the "rack" number but also the information itself. Instead of: catalog → "rack 42, spot 7" → walk to the rack → read the book. Now: catalog → all the needed information is already there → no need to go anywhere.
>
> **📚 Index-Only Scan:** If all the fields in SELECT and WHERE are in the index, PostgreSQL reads only the index, without the heap (the table's main data). This is `Index Only Scan` in EXPLAIN — very efficient for aggregations and analytics.
>
> **🌐 The `include` parameter in Django:** `Index(fields=['user', 'status'], include=['title', 'updated_at'])` → PostgreSQL INCLUDE syntax. Fields in `include` are stored in the index leaves but are not part of the sort key. SELECT title, updated_at WHERE user=X AND status='pub' → Index Only Scan.
>
> **❌ A typical mistake:** Covering too many fields. A wide covering index takes more space and slows down writes. Cover only the fields that are DEFINITELY needed for a specific "hot" query.
---

```python
# Covering index: include fields that are often SELECTed but are not in WHERE
class Note(models.Model):
    class Meta:
        indexes = [
            # index (user_id, status) INCLUDE (title, updated_at)
            # SELECT title, updated_at WHERE user_id=X AND status='published'
            # → Index Only Scan (does not read the heap!)
            models.Index(
                fields=['user', 'status'],
                include=['title', 'updated_at'],  # PostgreSQL 11+ syntax
                name='note_user_status_cover_idx'
            ),
        ]
```

```sql
-- EXPLAIN ANALYZE will show the difference:

-- WITHOUT a covering index:
Seq Scan / Index Scan on notes_note
  + Heap Fetch (reading data pages)
  → 2 I/O operations: index + heap

-- WITH a covering index:
Index Only Scan using note_user_status_cover_idx
  → 1 I/O operation: index only
  (the heap is still visited for the "visibility check", but much less often)
```

---

## 5. GIN Index — For JSON and Arrays

---
> **🧠 Mental model:** A B-Tree is efficient for comparing one value with another (`user_id = 5`). GIN (Generalized Inverted Index) is efficient for "contains" (`tags @> ['python']`, `metadata ? 'word_count'`). GIN is like the index at the back of a book: "python → pages 5, 42, 100". One index entry can point to THOUSANDS of rows.
>
> **📚 How GIN works:** GIN breaks each value into "elements" (JSON keys, array elements, words of text) and for each element stores a list of TIDs (pointers to the rows containing that element). Searching `WHERE tags @> ['python']` → find 'python' in the GIN → get the list of TIDs → return the rows.
>
> **🌐 GIN in Django:** `GinIndex(fields=['tags'])` for an ArrayField, `GinIndex(fields=['metadata'])` for a JSONField. For full-text search: `GinIndex(fields=['content'], opclasses=['gin_trgm_ops'])` requires the `pg_trgm` extension.
>
> **❌ A typical mistake:** Not adding a GIN index for a JSONField and filtering by JSON fields. `Note.objects.filter(metadata__language='uk')` without GIN → a sequential scan over billions of rows. With GIN → milliseconds.
---

```python
from django.contrib.postgres.fields import ArrayField
from django.contrib.postgres.indexes import GinIndex

class Note(models.Model):
    tags = models.ManyToManyField(Tag, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    quick_labels = ArrayField(
        models.CharField(max_length=50), blank=True, default=list
    )

    class Meta:
        indexes = [
            # GIN for an ArrayField — searching by array elements
            GinIndex(
                fields=['quick_labels'],
                name='note_labels_gin_idx'
            ),
            # GIN for a JSONField — searching by JSON keys and values
            GinIndex(
                fields=['metadata'],
                name='note_metadata_gin_idx'
            ),
        ]

# Efficient queries with a GIN index:
Note.objects.filter(quick_labels__contains=['python'])
# WHERE quick_labels @> ARRAY['python']  → GIN O(log N)

Note.objects.filter(metadata__language='uk')
# WHERE metadata @> '{"language": "uk"}'  → GIN O(log N)

Note.objects.filter(metadata__has_key='word_count')
# WHERE metadata ? 'word_count'  → GIN O(log N)
```

---

## 6. Trigram Index — Fuzzy Search

---
> **🧠 Mental model:** A trigram is a split of text into groups of 3 characters. "Django" → ["Dja", "jan", "ang", "ngo"]. A trigram GIN index stores each trigram → the list of rows that contain it. `LIKE '%django%'` → find all rows that have the trigrams "dja", "jan", "ang", "ngo" → intersect the lists → result. Without trigrams: a sequential scan.
>
> **📚 Enabling pg_trgm:** `CREATE EXTENSION IF NOT EXISTS pg_trgm;` — or via a Django migration: `TrigramExtension()` (`BtreeGinExtension()` enables a different extension, `btree_gin`, not `pg_trgm`).
>
> **🌐 icontains with trigrams:** `Note.objects.filter(title__icontains='python')` without trigrams → `LIKE '%python%'` → a sequential scan. With a trigram GIN → an O(log N) search over trigrams.
>
> **❌ A typical mistake:** Expecting `db_index=True` + `icontains` = fast search. A regular B-Tree does NOT help with `%contains%`. Only a trigram GIN does.
---

```python
# First you need to activate the pg_trgm extension:

# migrations/0010_trigram_extension.py
from django.contrib.postgres.operations import TrigramExtension

class Migration(migrations.Migration):
    operations = [
        TrigramExtension(),  # CREATE EXTENSION pg_trgm
    ]


# Then we add a trigram index:
from django.contrib.postgres.indexes import GinIndex

class Note(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)

    class Meta:
        indexes = [
            # GIN trigram for title — fast LIKE '%...%'
            GinIndex(
                fields=['title'],
                opclasses=['gin_trgm_ops'],  # trigram operator class
                name='note_title_trgm_idx'
            ),
            # GIN trigram for content (large text — useful)
            GinIndex(
                fields=['content'],
                opclasses=['gin_trgm_ops'],
                name='note_content_trgm_idx'
            ),
        ]

# Now these queries will use the trigram GIN:
Note.objects.filter(title__icontains='python')
# WHERE title ILIKE '%python%' → trigram GIN O(log N)

Note.objects.filter(
    Q(title__icontains='django') | Q(content__icontains='django')
)
```

---

## 7. AddIndexConcurrently — No Downtime in Production

---
> **🧠 Mental model:** A regular `CREATE INDEX` locks the table for the whole time the index is being built. On a table with 50 million rows, that is 10-30 minutes without being able to insert or update data. `CREATE INDEX CONCURRENTLY` builds the index without locking the table — at the cost of two passes and a somewhat slower build.
>
> **📚 How CONCURRENTLY works:** Two table scans: the first collects a snapshot, the second catches the changes that happened during the first. Between the scans, the table remains available for reads and writes. Build time: a bit longer. Locking: minimal (only a few Share Update Exclusive Locks for milliseconds).
>
> **🌐 In Django:** `migrations.AddIndexConcurrently` (in `django.contrib.postgres.operations`). It requires `atomic = False` in the migration (CONCURRENTLY cannot run inside a transaction).
>
> **❌ A typical mistake:** Adding a large index through a regular `migrations.AddIndex` on a production table with millions of rows. 10-30 minutes of downtime. Always use `AddIndexConcurrently` in production.
---

```python
# notes_app/migrations/0015_add_concurrent_index.py
from django.contrib.postgres.operations import AddIndexConcurrently
from django.db import migrations, models

class Migration(migrations.Migration):
    # REQUIRED: atomic=False — CONCURRENTLY is not allowed inside a transaction!
    atomic = False

    dependencies = [
        ('notes_app', '0014_previous_migration'),
    ]

    operations = [
        AddIndexConcurrently(
            model_name='note',
            index=models.Index(
                fields=['user', '-updated_at'],
                name='note_user_updated_concurrent_idx'
            ),
        ),
    ]

# The SQL that gets executed:
# CREATE INDEX CONCURRENTLY note_user_updated_concurrent_idx
# ON notes_app_note (user_id, updated_at DESC)
# (without locking the table!)
```

---

## 8. When to Add an Index (and When Not To)

```
✅ ADD AN INDEX:

  1. Fields in the WHERE clause (filtering)
     filter(user=X) → index on user_id

  2. Fields in ORDER BY (sorting without a sort operation)
     order_by('-updated_at') → index on updated_at DESC

  3. Foreign Key fields
     Django automatically creates an index on an FK (ForeignKey has db_index=True by default).
     Don't turn it off (db_index=False) without a reason; for composite conditions use Meta.indexes

  4. Fields in JOIN conditions
     JOIN ... ON note.user_id = user.id → index on user_id

  5. Fields in UNIQUE constraints
     Django adds it automatically with unique=True

  6. JSON/Array fields that are filtered on
     GinIndex(fields=['metadata'])

❌ DO NOT ADD AN INDEX:

  1. Fields with low selectivity
     Boolean (only 2 values)
     Status with 2-3 values where 80% = one value
     The Planner will choose a Sequential Scan (correctly!)

  2. Small tables (< 1000 rows)
     A Sequential Scan is more efficient (everything is in cache)

  3. Fields that are rarely used in WHERE/ORDER BY
     It only takes up space and slows down writes

  4. Fields that are updated very often
     UPDATE → rewrite the index → overhead

  5. "Just in case" fields
     Every unnecessary index = slower INSERT/UPDATE/DELETE
```

---

## 9. REINDEX and Index Maintenance

```sql
-- Check index sizes
SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Bloat: how many dead entries are in the index (after bulk DELETE/UPDATE)
-- PostgreSQL VACUUM cleans them up automatically

-- REINDEX CONCURRENTLY (PostgreSQL 12+): rebuild an index without locking
REINDEX INDEX CONCURRENTLY note_user_updated_idx;

-- Or via Django:
# python manage.py shell
# from django.db import connection
# connection.cursor().execute('REINDEX INDEX CONCURRENTLY note_user_updated_idx')
```

---

## Prediction Exercises

### Exercise 1: Selectivity

```python
class Order(models.Model):
    status = models.CharField(max_length=20)  # 'pending', 'completed', 'cancelled'
    # Distribution: 5% pending, 90% completed, 5% cancelled
```

**Question:** Is it worth adding `db_index=True` on `status`?

> Answer: **It depends on the query.** `filter(status='pending')` → 5% of rows → the index is useful. `filter(status='completed')` → 90% of rows → the Planner will correctly choose a Sequential Scan. Solution: partial indexes or leave it without an index.

### Exercise 2: Composite index

```python
Index(fields=['user', 'status', 'updated_at'])
```

**Question:** For which WHERE conditions will this index be effective?

> Answer: `filter(user=X)`, `filter(user=X, status='pub')`, `filter(user=X, status='pub', updated_at__gte=date)`. NOT for: `filter(status='pub')`, `filter(updated_at__gte=date)`, `filter(status='pub', updated_at__gte=date)` — the leading column `user` is missing.

---

## Self-Check Questions

1. What is a Sequential Scan, and when is it better than an Index Scan?
2. What does a B-Tree look like, and what is its asymptotic search complexity?
3. What is the "leading column" in a composite index, and why does it matter?
4. When do you need a GIN index rather than a B-Tree?
5. Why does `LIKE '%text%'` not use a B-Tree index?
6. What is a trigram, and how does it enable efficient fuzzy search?
7. How does `AddIndexConcurrently` differ from `AddIndex`, and when should you use it?
8. How do you check whether a specific query uses an index?
9. Why use `include` in `models.Index`, and what is an Index-Only Scan?
10. Why do too many indexes slow the system down?
