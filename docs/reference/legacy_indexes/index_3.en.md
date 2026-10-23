# Django ORM and Databases — Knowledge System

> This file is the main learning map. Start here.
> The material is organized from the foundations of relational databases to deep Django ORM patterns.

---

## Learning map

```
LEVEL 1: The relational foundation
    → Why databases exist
    → Tables, rows, columns, types
    → Primary Key, Foreign Key, Constraints
    → Normalization (1NF, 2NF, 3NF)

LEVEL 2: Architectural thinking for databases
    → Schema design: translating domains to relations
    → ACID properties and the CAP theorem
    → Relationship systems (1:1, 1:N, M:N, Referential Integrity)

LEVEL 3: SQL as a query language
    → SELECT, WHERE, JOIN (INNER/LEFT/RIGHT/FULL)
    → GROUP BY, Aggregations
    → How the database executes a query (Parsing → Planning → Execution)

LEVEL 4: Django ORM — internal mechanics
    → Models, Managers, QuerySets
    → Lazy Evaluation
    → SQL generation and traversal via __

LEVEL 5: The migration system
    → makemigrations → dependency graph → migrate
    → Schema version control

LEVEL 6: Django model architecture
    → The Field System and the object lifecycle
    → SQLite vs PostgreSQL

LEVEL 7: Debugging and performance
    → N+1 Query Problem
    → select_related vs prefetch_related
    → QuerySet.query introspection

LEVEL 8: Django Forms — the Trust Boundary
    → request.POST → QueryDict → is_valid() → cleaned_data
    → Validation Pipeline: to_python → validate → run_validators → clean_<field> → clean
    → ModelForm + save(commit=False) + M:N transactions
    → Widget architecture + Bootstrap CSS injection
    → CSRF protection + the PRG pattern

LEVEL 9: A real Django project
    → notes_chat_app/ — 9 models (User, Notebook, Note, Tag, Reminder,
                        TodoList, TodoItem, ShoppingList, ShopItem)
    → Services/Selectors architecture
    → QuerySet API: select_related, prefetch_related, F(), atomic()
```

---

## Documentation files

| File | Levels | What it gives you |
|------|-------|--------|
| [RELATIONAL_DB_FOUNDATIONS.md](../../03_database_and_orm/relational_db_foundations_full.md) | 1–3 | The foundation of relational databases: tables, keys, normalization, SQL, Query Execution Flow, Predicate Pushdown, JOIN algorithms, **SQL Injection + Trust Boundary Architecture** |
| [DJANGO_ORM_DEEP.md](../../03_database_and_orm/django_orm_deep_full.md) | 4–7 | Django ORM: QuerySets, Lazy Evaluation, Migrations, Field System, N+1, select_related, prefetch_related, F(), atomic() |
| [DJANGO_FORMS.md](../../04_forms_and_validation/django_forms_full.md) | 8 | Forms: Trust Boundary, Validation Pipeline, ModelForm, Widget/Bootstrap CSS injection, CSRF, the PRG pattern, Crispy Forms |
| [DJANGO_SERVICES_SELECTORS.md](../../06_application_architecture/services_selectors_full.md) | 9 | **The full business-layer architecture:** View→InputSerializer→Service→Selector→ORM→OutputSerializer. Data flow, anti-patterns, a responsibility table. Serializers as the transport layer. |
| [DJANGO_SELECTORS.md](../../06_application_architecture/django_selectors_full.md) | 9 | **Selector — the read layer:** CQRS-light (Reads vs Writes), centralizing N+1 fixes, QuerySet vs evaluated list, selector + django-filter without leaking the ORM, naming convention, template |
| [DJANGO_SERVICES.md](../../06_application_architecture/django_services_full.md) | 9 | **Service — the business-logic layer:** stateless functions, keyword-only args, @transaction.atomic, side effects via on_commit(), a Celery task as the transport layer, mapping domain errors → HTTP |
| [POSTGRESQL_ADVANCED.md](../../03_database_and_orm/postgresql_advanced_full.md) | — | PostgreSQL architecture (MVCC, WAL, Process Model), connecting via Docker, PostgreSQL-specific fields, PgBouncer, production stack |
| [INDEXING_DEEP.md](../../03_database_and_orm/indexing_deep_full.md) | — | The physics of B-Tree, composite/covering/GIN/Trigram indexes, EXPLAIN ANALYZE |
| [TRANSACTIONS_CONCURRENCY.md](../../03_database_and_orm/transactions_concurrency_full.md) | — | Transactions, row locking, deadlocks, race conditions, select_for_update(), on_commit() |
| [ORM_MERMAID.md](../../03_database_and_orm/orm_mermaid_full.md) | All | 20+ Mermaid diagrams: ER diagrams, ORM Flow, Migration Lifecycle, N+1, B-Tree, Deadlock, Transaction timelines, Services/Selectors |

---

## Practical projects

| Project | Folder | What's inside |
|--------|-------|--------------|
| [Notes Platform — FBV](../../../README.md) | `notes_chat_app/` | A notes platform: 9 models (UserProfile, Notebook, Tag, Note, Reminder, TodoList, TodoItem, ShoppingList, ShopItem). Services/Selectors architecture. All relationship types. QuerySet API. SQLite→PostgreSQL migration. |
| [Notes Platform — CBV](../../../README.md) | `notes_chat_app/` | The same platform, but `views.py` and `urls.py` are rewritten as Class-Based Views: `ListView`, `DetailView`, `CreateView`, `UpdateView`, `DeleteView`, `LoginRequiredMixin`, `UserQuerySetMixin`. |

### Recommended project order

```
notes_chat_app/     ← first: FBV, ORM, Services/Selectors, PostgreSQL
      ↓
notes_chat_app/ ← then: the same models/services, but views → CBV
```

### Key files of notes_chat_app (FBV)

| File | What it does | Where in the tutorial |
|------|-----------|----------------|
| [`notes_app/orm_laboratory.ipynb`](../legacy_source/orm_laboratory_reference.md) | 🔬 **Interactive lab** — 48 cells: QuerySet laziness, field lookups, Q()/F(), aggregation, N+1, select_related, prefetch_related, bulk ops, raw SQL, transactions, SQL inspection | Levels 4–7 |
| `notes_app/models.py` | 9 models with all relationships + Meta.indexes + constraints | README Steps 3–5 |
| `notes_app/selectors.py` | The SELECT layer — all QuerySets with optimization | README Step 7 |
| `notes_app/services.py` | Business logic — CREATE/UPDATE/DELETE in transactions | README Step 7 |
| `notes_app/views.py` | A thin HTTP layer — only request/response | README Step 8 |
| `notes_app/forms.py` | Forms with a Trust Boundary + user-filtered QuerySets | README Step 8 |
| `notes_app/admin.py` | Admin with select_related, TabularInline, annotate | — |
| `notes_app/migrations/` | The auto-generated migration graph | README Step 5 |

### Key files of notes_chat_app (CBV)

| File | What changed |
|------|--------------|
| [`notes_app/views.py`](../../../notes_app/views.py) | ★ Rewritten as CBV: `LoginRequiredMixin`, `UserQuerySetMixin`, `ListView`/`DetailView`/`CreateView`/`UpdateView`/`DeleteView` |
| [`notes_app/urls.py`](../../../notes_app/urls.py) | ★ `.as_view()` in every `path()` instead of functions |
| [`notes_app/views_fbv_backup.py`](../legacy_source/legacy_missing_reference.md) | The FBV original for comparison (with CBV equivalents in every function) |
| [`notes_app/forms_views_laboratory.ipynb`](../legacy_source/forms_views_laboratory_reference.md) | 🔬 **Interactive lab** — 45 cells: Trust Boundary, Validation Pipeline, user= queryset, instance= edit, Widget HTML, RequestFactory, django.test.Client, reverse(), CSRF |
| All other files | Unchanged — the same models, forms, selectors, services, templates |

---

## Key concepts — quick reference

### The relational foundation
- **Primary Key** — a unique row identifier (cannot repeat)
- **Foreign Key** — a column that stores the PK of another table (a link between tables)
- **1NF** — all attributes are atomic; **2NF** — they depend on the PK; **3NF** — no transitive dependencies
- **ACID** — Atomicity, Consistency, Isolation, Durability (PostgreSQL guarantees this)
- **CAP** — Consistency, Availability, Partition Tolerance (you can only have 2 of 3 in a distributed system)

### Django ORM
- **QuerySet** — **lazy**: SQL is executed only on iteration/slice/len/list()
- **select_related** — a JOIN at the SQL level (for ForeignKey, OneToOne) → 1 query
- **prefetch_related** — a separate query + a Python join (for ManyToMany, reverse FK) → 2 queries
- **The N+1 problem** — 1 query for the list + N queries in a loop = disaster
- **F()** — operations at the database level (no race condition)
- **transaction.atomic()** — atomic blocks: all or nothing

### Relationship types in Django
| Relationship | Django field | SQL mechanism |
|---------|-------------|--------------|
| 1:N | `ForeignKey` | An FK in the "many" table |
| 1:1 | `OneToOneField` | FK + UNIQUE constraint |
| M:N | `ManyToManyField` | A junction table, automatically |

---

## Common mistakes

| Mistake | Consequence | Solution |
|---------|----------|---------|
| N+1 queries | 1000+ SQL queries per page | `select_related`, `prefetch_related` |
| `save()` instead of `F()` when incrementing | Race condition: data loss | `F('views_count') + 1` |
| `atomic()` exception trap | `TransactionManagementError` | Catch exceptions OUTSIDE the block |
| `DecimalField` instead of `FloatField` for money | Rounding errors | Always `DecimalField` for currency |
| No `select_related` in a ListView | N+1 when rendering the template | Always `select_related` for FKs |
| `cursor.execute(f"...{user_input}...")` | SQL injection | `cursor.execute("...%s", [user_input])` |
| `Note.objects.filter(...)` directly in a View | Violates Services/Selectors | All QuerySets → into `selectors.py` |
| `request.POST[key]` directly into the ORM | Trust boundary violation | Via `form.cleaned_data` after `is_valid()` |

---

## Recommended reading order

```
 1. RELATIONAL_DB_FOUNDATIONS.md      ← You understand the relational model, SQL, execution flow
 2. ORM_MERMAID.md (ER diagrams)      ← You see the relationships visually before the code
 3. DJANGO_ORM_DEEP.md                ← ORM: QuerySets, lazy eval, N+1, F(), atomic()
 4. DJANGO_FORMS.md                   ← Forms: Trust Boundary, Validation Pipeline, PRG
 5. POSTGRESQL_ADVANCED.md            ← MVCC, WAL, connecting via Docker, prod stack
 6. INDEXING_DEEP.md                  ← B-Tree, GIN, EXPLAIN ANALYZE
 7. TRANSACTIONS_CONCURRENCY.md       ← Deadlocks, race conditions, select_for_update()
 8. ORM_MERMAID.md (all diagrams)     ← You consolidate the whole architecture
 9. DJANGO_SERVICES_SELECTORS.md      ← The full architecture: View→Service→Selector→ORM, data flow, anti-patterns
10. DJANGO_SELECTORS.md               ← In depth: CQRS-light, N+1 in one place, naming convention
11. DJANGO_SERVICES.md                ← In depth: stateless, atomic, on_commit, Celery as transport
12. notes_chat_app/README.md           ← Step-by-step tutorial: design → PostgreSQL
13. notes_app/models.py    ← Read it as learning material with comments
14. notes_app/selectors.py ← The SELECT layer: N+1 solutions, Prefetch, annotate
15. notes_app/services.py  ← Business logic: atomic(), F(), select_for_update()
16. notes_app/forms.py     ← The Trust Boundary in practice: user-filtered FK/M:N
17. docs/reference/legacy_source/orm_laboratory_reference.md ← Interactive lab: run every cell and look at the SQL
18. notes_chat_app/README.md          ← CBV tutorial: as_view(), dispatch(), Generic Views, Mixins
19. notes_app/views.py ← CBV code: compare each class with the FBV original
20. docs/reference/legacy_source/forms_views_laboratory_reference.md ← Forms & Views lab: Trust Boundary, RequestFactory, Client
```

> After this path you understand not just "how to write a QuerySet",
> but *why* the Django ORM works exactly the way it does, how forms protect against XSS/CSRF,
> how MVCC guarantees isolation, why deadlocks happen, and how to avoid them in production.
