# PostgreSQL Advanced — Architecture, Docker, and Production Patterns

> A continuation after [`django_orm_full.md`](django_orm_full.md).
> Here: the internal mechanics of PostgreSQL, why it is so fast, how to connect to it via Docker,
> PostgreSQL-specific fields, and production optimization.

---

> 🔬 **SQL inspection in the notebook:**
> [`docs/reference/legacy_source/orm_laboratory_reference.md`](../reference/legacy_source/orm_laboratory_reference.md)
>
> ⚠️ The notebook itself is not part of this repository: the linked file only explains that. The section names in the table below point to the notebook's original structure, they are not anchors. You can run the same queries yourself in `python manage.py shell` or in the [ORM lab](../labs/orm_lab.md).
>
> | Concept | Notebook section |
> |-----------|-----------------|
> | `queryset.explain(analyze=True)` — query plan | `## 11. 🔬 SQL Inspection` |
> | `connection.queries` — SQL logging | `## 11. 🔬 SQL Inspection` |
> | Raw SQL via `cursor.execute()` | `## 14. 🧪 Raw SQL` |



> **🧠 Mental model:** PostgreSQL is not just "a place to store things". It is a complex client-server system with a multi-process architecture, its own memory manager (Shared Buffers), an isolation mechanism (MVCC), and a fault-tolerance log (WAL). Understanding this = understanding why some queries are fast and others are not.
>
> **📚 Why this matters for a Django developer:** When you write `Note.objects.filter(user=user)`, Django sends SQL to PostgreSQL, PostgreSQL decides where to look for the data (disk or memory, index or sequential scan), executes the query, and returns the result. If you understand this process, you know where the bottleneck is and how to remove it.
>
> **🌐 Practical value:** Sooner or later every Django developer runs into "why does my page take 5 seconds to load?" The answer is always in PostgreSQL: a missing index, N+1 queries, a sequential scan on a large table. `EXPLAIN ANALYZE` + knowledge of the architecture = a diagnosis in 5 minutes.
>
> **❌ A typical mistake:** Thinking that PostgreSQL = "just storage". In reality, PostgreSQL is a powerful server with a query planner, a cache, and a transaction manager. The right configuration can give a 10-100x performance boost without changing any code.

---

## 1. PostgreSQL vs SQLite — Why We Switch in Production

---
> **🧠 Mental model:** SQLite is a "file database". All access goes through a single file descriptor. Only ONE process can write at any given moment. PostgreSQL is a separate server process. Hundreds of clients at once → each one gets its own backend process → MVCC provides isolation.
>
> **📚 A real scenario:** Gunicorn with 4 workers → 4 parallel Django requests → 4 simultaneous INSERTs. In SQLite: the first one writes, three wait. In PostgreSQL: all 4 write independently without locking (thanks to MVCC).
>
> **❌ A typical mistake:** Deploying to production with SQLite. Django even documents: "SQLite is not suitable for production". For real traffic (50+ concurrent users), SQLite = a bottleneck.
---

```
SQLite (Serverless):
  Django Process A ─────────────────┐
  Django Process B ─────────────────┤ → [db.sqlite3 file] ← ONE file
  Django Process C ─────────────────┘   (write lock on the whole file)

  Problem: Process A writes → B and C WAIT

PostgreSQL (Client-Server):
  Django + psycopg2 ──TCP──► [postmaster :5432]
                                 │  ─ fork()  ─► [backend process 1] ─► [Shared Buffers]
                                 │  ─ fork()  ─► [backend process 2] ─► [Shared Buffers]
                                 │  ─ fork()  ─► [backend process 3] ─► [Shared Buffers]

  All three backend processes run in parallel, each with its own transaction (MVCC).
```

| Characteristic | SQLite | PostgreSQL |
|----------------|--------|------------|
| **Architecture** | Serverless, a single file | Client-server, a separate daemon |
| **Concurrent writes** | Database-level lock | MVCC: thousands in parallel |
| **DB size** | Up to ~1 TB in practice | Unlimited (even petabytes) |
| **JSON/Arrays** | Basic | Full support + GIN indexes |
| **Full-text search** | Limited | GIN + tsvector, trigram |
| **DDL transactions** | Limited | Full support |
| **Connection** | Direct file | TCP socket (or Unix socket) |
| **For production** | ❌ Never | ✅ Always |

---

## 2. PostgreSQL Process Model — How the Server Handles Queries

---
> **🧠 Mental model:** When Django connects to PostgreSQL, the postmaster daemon fork()s a new process specifically for that connection. This backend process serves ONE connection while it is active. Shared Buffers is memory shared among all the backend processes: the data cache.
>
> **📚 Why fork() and not threads:** PostgreSQL uses processes (not threads) for isolation. If a backend process crashes, it does not kill the whole server. Shared Buffers is shared memory (not copies): all processes see one and the same cache.
>
> **🌐 CONN_MAX_AGE in Django:** Every new Python process → a new connection to PostgreSQL → a fork() on the PostgreSQL side. That is expensive (10-100ms). `CONN_MAX_AGE=60` → keep the connection between HTTP requests → no fork() every time → 5-10x less overhead on DB connections.
>
> **❌ A typical mistake:** `CONN_MAX_AGE=None` (persistent) without PgBouncer. With 100 Gunicorn workers = 100 permanent connections to PostgreSQL. PostgreSQL keeps 100 backend processes. With `max_connections=100` → the 101st client gets a "too many connections" error.
---

```
                ┌─────────────────────────────────────────────────────────┐
                │                 PostgreSQL Server                        │
                │                                                           │
  Django ────► │ Postmaster (port 5432)                                   │
  psycopg2     │   │                                                        │
               │   ├─ fork() ──► Backend Process 1 (your query)           │
               │   │              │  ← Query Parser                        │
               │   │              │  ← Query Planner & Optimizer            │
               │   │              │  ← Execution Engine                    │
               │   │              │                                         │
               │   │              └──► Shared Buffers (8GB RAM cache)     │
               │   │                     │                                  │
               │   │              WAL Writer ──► WAL Log (disk)           │
               │   │              Checkpointer ──► Data Files (disk)      │
               │   │                                                        │
               │   ├─ fork() ──► Backend Process 2 (another client)       │
               │   └─ fork() ──► Backend Process 3 (one more)             │
               └─────────────────────────────────────────────────────────┘
```

---

## 3. MVCC — Multi-Version Concurrency Control

---
> **🧠 Mental model:** Imagine that every row in a table has "versions". When you start a transaction, you see a snapshot of the DB state at the moment it began. Other transactions may change the same rows in parallel — you do not see those changes until they commit, and they do not see yours. It is like Google Docs: several people edit at the same time without conflicts.
>
> **📚 How PostgreSQL implements this:** Each row stores `xmin` (which transaction created it) and `xmax` (which transaction deleted or replaced it). On SELECT, PostgreSQL sees only rows where `xmin <= current_transaction` and `xmax` is either NULL (not deleted) or `xmax > current_transaction` (deleted later than your transaction started).
>
> **🌐 What this gives Django:** `READ COMMITTED` (the default) — every query in a transaction sees fresh committed data. No "dirty reads" (reading uncommitted changes). Parallel transactions do not block each other when reading.
>
> **❌ A typical mistake:** Thinking that PostgreSQL "locks the table" on every SELECT. **No.** Readers do not block writers, writers do not block readers (MVCC). Locking happens only with `SELECT FOR UPDATE` or with concurrent writes to one and the same row.
---

```
MVCC — tuple versioning:

the notes_note table (internal representation):
┌─────┬───────────┬──────────┬───────────┬──────────────┐
│ id  │ title     │ xmin     │ xmax      │ Visible to   │
├─────┼───────────┼──────────┼───────────┼──────────────┤
│  42 │ "Django"  │ txid=100 │ NULL      │ all ≥ 100    │ ← active version
│  42 │ "Django!" │ txid=200 │ NULL      │ all ≥ 200    │ ← new version (UPDATE)
│  42 │ "Django"  │ txid=100 │ txid=200  │ transactions │ ← old (xmax=200: deleted)
│     │           │          │           │  < 200       │
└─────┴───────────┴──────────┴───────────┴──────────────┘

Transaction txid=150 (started between 100 and 200):
  → sees the row with xmin=100, xmax=NULL (the old version)
  → does NOT see the row with xmin=200 (it did not exist yet when 150 started)

Transaction txid=250 (started after 200):
  → sees the row with xmin=200 (the new version)
  → the old version (xmax=200) is "deleted" for it

VACUUM cleans up "dead" tuples (xmax != NULL and not visible to any active transaction)
```

---

## 4. WAL — Write-Ahead Logging

---
> **🧠 Mental model:** WAL is the database's "flight data recorder". Before making any change to the data, PostgreSQL writes the intent to the WAL log. If the server crashes, on restart PostgreSQL reads the WAL and restores all confirmed transactions. No data loss after COMMIT.
>
> **📚 Why "Write-Ahead":** "Write-Ahead" = "write the log BEFORE changing the data". If the question is what is more important to keep — the log or the data? The log! With the log → the data can be restored. Data without a log → we don't know which state to restore to.
>
> **🌐 WAL and performance:** PostgreSQL first writes changes to Shared Buffers (RAM) → then the WAL to disk. The Checkpointer syncs dirty pages to disk. `synchronous_commit=on` (the default) → COMMIT waits for the WAL to be written to disk. `synchronous_commit=off` → faster, but there is a risk of losing the latest transactions on a crash. For non-critical data (logs, analytics), `off` may be acceptable.
>
> **❌ A typical mistake:** Running PostgreSQL with `fsync=off` "to speed up development". That is OK for local development, but in production = guaranteed data corruption on a crash. Never in production.
---

```
The path of data from COMMIT to disk:

1. Django: leaving transaction.atomic() (or autocommit)
           │
2. SQL: COMMIT
           │
3. PostgreSQL WAL Writer:
   ┌─ WAL Buffer (in RAM) ────────────────────────────────┐
   │  LSN 0/1234ABC: BEGIN txid=200                        │
   │  LSN 0/1234DEF: INSERT notes_note (id=42, title=...)  │
   │  LSN 0/1235000: COMMIT txid=200                       │
   └──────────────────────────────────────────────────────┘
           │ fsync() — flush to disk
           ▼
   WAL file: pg_wal/000000010000000000000001
   (Now even after a crash, the transaction can be recovered!)
           │
4. COMMIT returns to the client (Django gets OK)
           │
5. Later: the Checkpointer writes dirty pages from Shared Buffers to the Data Files
   (asynchronously, without delaying the client)
```

---

## 5. Connecting Django to PostgreSQL via Docker

---
> **🧠 Mental model:** Docker for PostgreSQL is a "virtual server" that starts in 5 seconds. A PostgreSQL container = a separate network namespace → Django connects over TCP to `localhost:5432` as if it were a real server.
>
> **📚 Why Docker instead of installing PostgreSQL:** Versioning (easy to switch to postgres:15 or postgres:16), isolation (does not clutter your system), the same environment for the whole team, easy to clean up (`docker-compose down -v`).
>
> **🌐 docker-compose.yml for development:** `volumes: postgres_data` keeps the data between container restarts. Without a volume, a restart = a new empty DB. `healthcheck` — Django does not connect until PostgreSQL is ready to accept connections.
>
> **❌ A typical mistake:** Setting empty passwords or `POSTGRES_HOST_AUTH_METHOD=trust` in docker-compose. For local development, that is OK. But if port 5432 is exposed to the outside (for example, port forwarding in the cloud), someone can connect without a password.
---

### A Complete docker-compose.yml for Development:

```yaml
# docker-compose.yml

version: '3.9'

services:

  # ── PostgreSQL ────────────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine          # alpine = a minimal image (~25MB)
    restart: unless-stopped
    environment:
      POSTGRES_DB: notes_db            # database name
      POSTGRES_USER: notes_user        # user name
      POSTGRES_PASSWORD: notes_pass    # password (in an .env file in production!)
    volumes:
      - postgres_data:/var/lib/postgresql/data  # data is kept between restarts
    ports:
      - "5432:5432"                    # host:container
    healthcheck:
      # Django (app) will not start until PostgreSQL is ready
      test: ["CMD-SHELL", "pg_isready -U notes_user -d notes_db"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s

  # ── Django App (optional) ─────────────────────────────────────────────────
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://notes_user:notes_pass@db:5432/notes_db
    depends_on:
      db:
        condition: service_healthy    # wait until the db healthcheck = healthy
    command: >
      sh -c "python manage.py migrate &&
             python manage.py runserver 0.0.0.0:8000"

volumes:
  postgres_data:     # named volume — the data is kept outside the container
```

```bash
# Commands for working with it:

# Start only PostgreSQL (for local development)
docker-compose up -d db

# Start the whole stack
docker-compose up -d

# Check that PostgreSQL is running
docker-compose ps
docker-compose logs db

# Connect to the psql console
docker-compose exec db psql -U notes_user -d notes_db

# Show all tables
docker-compose exec db psql -U notes_user -d notes_db -c "\dt notes_app*"

# Stop and keep the data
docker-compose stop

# Stop and DELETE the data (a full cleanup!)
docker-compose down -v
```

### Django settings.py for PostgreSQL:

```python
# settings.py

from decouple import config    # pip install python-decouple

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='notes_db'),
        'USER': config('DB_USER', default='notes_user'),
        'PASSWORD': config('DB_PASSWORD', default='notes_pass'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432', cast=int),

        # CONN_MAX_AGE: keep the connection between HTTP requests
        # None = persistent (never close)
        # 0 = always a new one (the default, inefficient)
        # 60 = keep it for 60 seconds (recommended for Gunicorn)
        'CONN_MAX_AGE': config('DB_CONN_MAX_AGE', default=60, cast=int),

        # OPTIONS for production:
        'OPTIONS': {
            # 'connect_timeout': 5,      # connection timeout
            # 'options': '-c search_path=myschema',  # PostgreSQL search_path
        },
    }
}
```

```bash
# .env file (NEVER commit it to git!)
DB_NAME=notes_db
DB_USER=notes_user
DB_PASSWORD=notes_pass
DB_HOST=localhost
DB_PORT=5432
DB_CONN_MAX_AGE=60
```

```bash
# .gitignore
.env
db.sqlite3
*.pyc
__pycache__/
```

---

## 6. psycopg2 and PgBouncer

---
> **🧠 Mental model:** psycopg2 is the "phone line" between Python and PostgreSQL. PgBouncer is the "telephone exchange": instead of each Django worker holding a direct line to PostgreSQL, they connect through an exchange that switches between a limited number of real lines.
>
> **📚 The problem without PgBouncer:** Gunicorn with 10 workers + 5 threads = 50 parallel connections. PostgreSQL fork()s 50 backend processes. With 100 workers → 100 backend processes → `max_connections=100` → the 101st gets an error. PgBouncer → 1000 Django connections → 20 real connections to PostgreSQL.
>
> **🌐 PgBouncer modes:** Session pooling (1 PostgreSQL connection per Django session), Transaction pooling (1 real PostgreSQL connection per transaction — the best balance for Django), Statement pooling (the most aggressive connection reuse, but does not support multi-statement transactions).
>
> **❌ A typical mistake:** Transaction pooling + `CONN_MAX_AGE` in Django. With Transaction pooling, each transaction may go through a different physical connection. Persistent connections to PostgreSQL then make no sense. With PgBouncer: `CONN_MAX_AGE=0`.
---

```
Without PgBouncer:
  Django w1 ──────────────────────────── TCP ──► PostgreSQL :5432
  Django w2 ──────────────────────────── TCP ──► PostgreSQL :5432
  Django w3 ──────────────────────────── TCP ──► PostgreSQL :5432
  ... (100 workers = 100 postgres backend processes)

With PgBouncer:
  Django w1 ──┐
  Django w2 ──┤── PgBouncer :6432 ──[ pool: 20 conns ]──► PostgreSQL :5432
  Django w3 ──┘  (100 Django connections → 20 real ones)
```

```python
# settings.py with PgBouncer:
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'notes_db',
        'USER': 'notes_user',
        'PASSWORD': 'notes_pass',
        'HOST': 'pgbouncer',  # the PgBouncer host, not PostgreSQL!
        'PORT': '6432',       # the PgBouncer port
        'CONN_MAX_AGE': 0,    # with PgBouncer, persistent connections are not needed
    }
}
```

---

## 7. PostgreSQL-Specific Django Fields

---
> **🧠 Mental model:** PostgreSQL supports data types that SQLite or MySQL do not have: arrays, JSONB, UUID, hstore, range types. Django provides fields for working with them. These fields are for the PostgreSQL backend only!
>
> **📚 JSONField vs a separate table:** A JSONField stores an arbitrary structure in a single column. When to use it: configuration, metadata, data whose structure changes often. When NOT to use it: data that needs complex JOINs, frequent updates of individual fields, a strict schema.
>
> **🌐 GIN index for JSON and arrays:** A regular B-Tree index cannot index JSON or an array (many values in one column). GIN (Generalized Inverted Index) indexes each array element or each JSON key. `GinIndex(fields=['metadata'])` → fast search by JSON keys.
>
> **❌ A typical mistake:** Using a JSONField as a "fallback" for a poorly thought-out schema. A JSONField without a GIN index + filtering with `filter(metadata__key=val)` → a sequential scan (a full table scan). Always add a GIN index if you filter on JSON.
---

### JSONField — Structured Data in a Column:

```python
from django.db import models

class Note(models.Model):
    # JSONField stores a Python dict/list in a PostgreSQL JSONB column
    # JSONB = binary JSON → faster than TEXT JSON
    metadata = models.JSONField(
        default=dict,
        blank=True,
        help_text='Arbitrary metadata: word_count, reading_time, language, etc.'
    )

# Filling it in:
note.metadata = {
    'word_count': 450,
    'reading_time_minutes': 3,
    'language': 'uk',
    'ai_tags': ['python', 'orm', 'database'],
    'last_spell_check': '2024-01-15'
}
note.save()

# Filtering by JSON fields:
Note.objects.filter(metadata__language='uk')
# WHERE metadata->>'language' = 'uk'

Note.objects.filter(metadata__word_count__gte=100)
# WHERE (metadata->>'word_count')::int >= 100

Note.objects.filter(metadata__ai_tags__contains=['python'])
# WHERE metadata->'ai_tags' @> '["python"]'

# Annotation with a JSON field:
from django.db.models import F
Note.objects.annotate(
    word_count=F('metadata__word_count')
).order_by('-word_count')
```

### ArrayField — Arrays in PostgreSQL:

```python
from django.contrib.postgres.fields import ArrayField

class Note(models.Model):
    # An array of strings — an alternative to M:N for simple tags
    quick_labels = ArrayField(
        base_field=models.CharField(max_length=50),
        blank=True,
        default=list,
        help_text='Quick labels (no FK, no junction table)'
    )

    # An array of IntegerField
    related_note_ids = ArrayField(
        base_field=models.IntegerField(),
        blank=True,
        default=list,
    )

# SQL: quick_labels TEXT[] DEFAULT '{}'

# Filtering:
Note.objects.filter(quick_labels__contains=['python'])
# WHERE quick_labels @> ARRAY['python']  (the array contains 'python')

Note.objects.filter(quick_labels__overlap=['python', 'django'])
# WHERE quick_labels && ARRAY['python', 'django']  (at least one match)

Note.objects.filter(quick_labels__len=3)
# WHERE array_length(quick_labels, 1) = 3  (an array of 3 elements)
```

### UniqueConstraint and CheckConstraint:

```python
class Note(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    slug = models.SlugField(max_length=200)
    views_count = models.PositiveIntegerField(default=0)
    priority = models.PositiveSmallIntegerField(default=1)

    class Meta:
        constraints = [
            # COMPOSITE UNIQUE: slug is unique within a single user
            # (alice can have /notes/python/, bob can too, but alice cannot have it twice)
            models.UniqueConstraint(
                fields=['user', 'slug'],
                name='unique_note_slug_per_user'
            ),

            # CHECK: views_count >= 0 (cannot be negative)
            # Checked even on a direct SQL INSERT (not only through Django)
            models.CheckConstraint(
                check=models.Q(views_count__gte=0),
                name='note_views_count_non_negative'
            ),

            # CHECK: priority from 1 to 4
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='note_priority_valid_range'
            ),
        ]
```

```sql
-- What gets generated in SQL:
ALTER TABLE notes_note
  ADD CONSTRAINT unique_note_slug_per_user UNIQUE (user_id, slug),
  ADD CONSTRAINT note_views_count_non_negative CHECK (views_count >= 0),
  ADD CONSTRAINT note_priority_valid_range CHECK (priority >= 1 AND priority <= 4);
```

---

## 8. EXPLAIN ANALYZE — Diagnosing Queries

---
> **🧠 Mental model:** `EXPLAIN ANALYZE` is an MRI scan for your SQL query. It shows which plan the Planner chose, how long each step took, and how many rows were processed. With it, you see where the bottleneck is: a missing index, a JOIN that is too wide, suboptimal sorting.
>
> **📚 EXPLAIN vs EXPLAIN ANALYZE:** `EXPLAIN` shows the plan without executing it (fast). `EXPLAIN ANALYZE` executes the query and shows real metrics (slow, but accurate). For production, always test on a copy — `EXPLAIN ANALYZE` really executes the query!
>
> **🌐 How to read a plan:** `Seq Scan` = reads the whole table, O(N). `Index Scan` = uses a B-Tree, O(log N). `Index Only Scan` = a covering index (does not read the heap). `Hash Join` = an efficient JOIN for large tables. `Nested Loop Join` = efficient for small tables with an index.
>
> **❌ A typical mistake:** Ignoring a `Seq Scan` on large tables. `Seq Scan on notes_note (cost=0.00..5000.00 rows=100000)` = reading all ~100,000 rows. You need an index on the field in the WHERE clause.
---

```python
# Django: qs.explain(analyze=True) — sends EXPLAIN ANALYZE to PostgreSQL
from notes_app.models import Note

qs = Note.objects.filter(user_id=5, is_archived=False).order_by('-updated_at')
print(qs.explain(analyze=True))
```

```sql
-- Typical EXPLAIN ANALYZE output:

-- A GOOD query (there is an index):
Index Scan using note_user_updated_idx on notes_note  (cost=0.29..8.31 rows=1 width=100)
                                                       (actual time=0.023..0.025 rows=1 loops=1)
  Index Cond: ((user_id = 5) AND (is_archived = false))
Planning Time: 0.150 ms
Execution Time: 0.045 ms   ← milliseconds!

-- A BAD query (Seq Scan without an index):
Seq Scan on notes_note  (cost=0.00..25000.00 rows=500000 width=100)
                         (actual time=0.050..1500.000 rows=150 loops=1)
  Filter: ((user_id = 5) AND (is_archived = false))
  Rows Removed by Filter: 499850    ← 500K rows scanned to find 150!
Planning Time: 0.250 ms
Execution Time: 1500.000 ms   ← 1.5 seconds!
```

```sql
-- Reading the plan:
-- cost=0.00..8.31      → cost: estimated start..total cost (in PostgreSQL units)
-- rows=1               → estimated number of rows
-- actual time=0.023..0.025 → real time: first row..last row (ms)
-- rows=1 loops=1       → rows actually returned, number of iterations

-- Operations:
-- Seq Scan            → ❌ full table scan O(N)
-- Index Scan          → ✅ B-Tree index O(log N)
-- Index Only Scan     → ✅✅ covering index (no heap reads)
-- Bitmap Index Scan   → ✅ for a large number of rows via an index
-- Hash Join           → JOIN via a hash table (efficient for large tables)
-- Nested Loop         → JOIN via a loop (efficient when there is an index on the inner table)
-- Sort                → ORDER BY without an index (can be slow)
```

---

## 9. CONN_MAX_AGE and Connection Pooling

---
> **🧠 Mental model:** Connecting to PostgreSQL is an expensive operation: TCP handshake, authentication, fork() of a backend process — 5-50ms. `CONN_MAX_AGE` tells Django: "keep the connection between HTTP requests instead of opening/closing it every time".
>
> **📚 How CONN_MAX_AGE works with Gunicorn:** Each Gunicorn worker = a separate process = a separate connection. With `CONN_MAX_AGE=60`, a worker keeps the connection for 60 seconds after the last request. On the next HTTP request to that worker, the connection is already ready.
>
> **🌐 A rule for production:** Gunicorn + `CONN_MAX_AGE=60` + no PgBouncer: number of connections = number of workers * threads. 10 workers * 2 threads = 20 connections max. If `max_connections=100`, that is safe. If there are more workers, either reduce `CONN_MAX_AGE` or add PgBouncer.
>
> **❌ A typical mistake:** `CONN_MAX_AGE=None` (infinite). The connection is never closed. When a new version is deployed, the old connections remain. Over time, PostgreSQL accumulates "hanging" connections. Better to use `CONN_MAX_AGE=60` or `300`.
---

```
Connections without CONN_MAX_AGE (CONN_MAX_AGE=0):

HTTP Request 1 → [open connection] → [SQL] → [close connection]   +50ms overhead
HTTP Request 2 → [open connection] → [SQL] → [close connection]   +50ms overhead
HTTP Request 3 → [open connection] → [SQL] → [close connection]   +50ms overhead

Connections with CONN_MAX_AGE=60:

HTTP Request 1 → [open connection] → [SQL] → [keep open]   +50ms (the first time)
HTTP Request 2 → [reuse connection] → [SQL] → [keep open]  +0ms!
HTTP Request 3 → [reuse connection] → [SQL] → [keep open]  +0ms!
... (after 60 seconds without requests → it is closed)
```

---

## 10. The Production Stack

```
Internet
    │
    ▼
[nginx] (port 443, SSL termination, static files)
    │
    ▼
[Gunicorn] (4-8 workers, Unix socket)
    │
    │  Django WSGI app
    │  CONN_MAX_AGE=60
    ▼
[PgBouncer] (port 6432, transaction pooling)
    │
    │  pool_size=20
    ▼
[PostgreSQL 16] (port 5432)
    │
    ├── Shared Buffers: 25% RAM
    ├── WAL: pg_wal/
    └── Data Files: /var/lib/postgresql/data/
```

```python
# settings/production.py

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='pgbouncer'),  # pgbouncer host
        'PORT': config('DB_PORT', default='6432'),        # pgbouncer port
        'CONN_MAX_AGE': 0,        # with PgBouncer, a persistent conn is not needed
        'OPTIONS': {
            'connect_timeout': 10,
            'options': '-c lock_timeout=3s',   # timeout for locks
        },
    }
}

# SQL query logging: django.db.backends emits it only when DEBUG=True,
# so in production this block shows nothing — keep it in dev settings
LOGGING = {
    'version': 1,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG',    # shows all SQL queries
        },
    },
}
```

---

## Prediction Exercises

### Exercise 1: Connections

```python
# settings.py:
DATABASES = {'default': {'CONN_MAX_AGE': 0, ...}}
# Gunicorn: 4 workers, each handles 100 requests per minute
```

**Question:** How many connections to PostgreSQL are opened per minute?

> Answer: **400 connections** (100 req/minute × 4 workers). Each request = open + close. With `CONN_MAX_AGE=60` → **4 connections** (one per worker, kept for 60 seconds).

### Exercise 2: MVCC

```
Transaction T1 starts at 10:00:00
Transaction T2 inserts a new row and COMMITs at 10:00:01
T1 runs a SELECT at 10:00:02
```

**Question:** Does T1 see T2's new row?

> Answer (depends on the isolation level):
> - `READ COMMITTED` (the default in PostgreSQL) → **YES**, it sees it. Each query in T1 sees fresh committed data.
> - `REPEATABLE READ` or `SERIALIZABLE` → **does NOT see it**. T1's snapshot is taken at the first query in the transaction (not at BEGIN/START TRANSACTION). So T1 does not see the row if it already ran at least one query before T2's COMMIT at 10:00:01; if the SELECT at 10:00:02 is its first query, it will see it.

---

## Self-Check Questions

1. Why does PostgreSQL not lock the table on every SELECT (MVCC)?
2. What is WAL, and why is it needed?
3. What is CONN_MAX_AGE, and which values are recommended?
4. When should you use a JSONField, and when a separate table?
5. Why does a JSONField need a GIN index?
6. What does `Seq Scan` in EXPLAIN ANALYZE show, and when is it a problem?
7. Why PgBouncer, and when is it needed?
8. What is the difference between `EXPLAIN` and `EXPLAIN ANALYZE`?
9. What do `xmin` and `xmax` mean in PostgreSQL's internal representation?
10. Why is `POSTGRES_HOST_AUTH_METHOD=trust` dangerous in production?
