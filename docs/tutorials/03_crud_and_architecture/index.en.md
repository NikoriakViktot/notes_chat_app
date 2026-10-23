# Step 3. CRUD and architecture

> **Training project:** `notes_project` — a standalone application that starts with SQLite and moves to PostgreSQL.
> This is the third step of the evolution. You go through the full cycle: from domain design to a finished application with the Services & Selectors architecture.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 1. Hello Django](../01_hello_django/index.md) — a basic Django project, the first `HttpResponse`
    - [Step 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD

---

## Training state vs Notes Chat App

| | notes_project (this step) | notes_chat_app (the final goal) |
|-|--------------------------|-------------------------------|
| Project | Standalone (SQLite → PostgreSQL) | Docker + PostgreSQL |
| Auth | None / basic `@login_required` | `@login_required`, Groups, sharing |
| Models | 9 models: UserProfile, Tag, Notebook, Note, Reminder, TodoList, TodoItem, ShoppingList, ShopItem | The same + Group (Django built-in) + ChatMessage |
| Views | FBV + selectors + services | FBV/CBV + selectors + services |
| Architecture | Services & Selectors | Services & Selectors (identical) |
| Relationships | 1:1, 1:N, M:N — all types | The same + Group M:N for sharing |

---

## Result of the step

After you finish this step you will have:

```
http://localhost:8000/             →  Index
http://localhost:8000/notes/       →  List of notes (search, filters, tags)
http://localhost:8000/notes/new/   →  Note creation form
http://localhost:8000/notes/1/     →  Note detail (with reminders)
http://localhost:8000/notes/1/edit/   →  Edit form
http://localhost:8000/notes/1/delete/ →  Delete confirmation (POST only)
http://localhost:8000/notebooks/      →  List of notebooks
http://localhost:8000/notebooks/new/  →  New notebook
http://localhost:8000/tags/new/       →  New tag
http://localhost:8000/admin/          →  Django Admin (with select_related)
```

---

## What you will learn

- **The 7-step methodology** of database design: Domain → Entities → Attributes → Relationships → Normalization → on_delete → Django Model
- **ER diagrams** — all relationship types: 1:1, 1:N, M:N
- **Services & Selectors** — an architectural separation of responsibility layers
- `selectors.py` — only SELECT queries, with optimization
- `services.py` — CREATE / UPDATE / DELETE with `transaction.atomic()`
- **The N+1 problem** and its solution: `select_related`, `prefetch_related`
- `transaction.atomic()`, `F()`, `select_for_update()`
- **Class-Based Views (CBV)** — `LoginRequiredMixin`, `UserQuerySetMixin`, `ListView`, `CreateView`, `UpdateView`, `DeleteView`
- Moving from **SQLite to PostgreSQL** via Docker

---

## Reading order

1. **[Domain design](domain_design.md)** — the 7-step methodology, where the truth lives, requirements analysis
2. **[ER diagrams](er_diagrams.md)** — relationship types, the on_delete matrix, the full schema of 11 tables
3. **[Django models](models.md)** — the full code of all models, the ORM QuerySet API
4. **[Migrations](migrations.md)** — Migration Lifecycle, the dependency DAG, the first run with SQLite
5. **[Services and Selectors](services_and_selectors.md)** — layer architecture, READ/WRITE flow, full code
6. **[QuerySet in depth](queryset_deep.md)** — normalization, N+1, select_related, prefetch_related, F(), transactions
7. **[PostgreSQL](postgresql.md)** — Docker, configuring Django, moving data
8. **[Class-Based Views](cbv.md)** — CBV vs FBV, Generic Views, Mixins, hooks
9. **[Checkpoint](checkpoint.md)** — checklist, common mistakes, practical exercise
