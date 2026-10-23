# Step 1. Hello Django

> You will go from an **empty folder** to a full-fledged Django site with view functions,
> URL routing, an admin panel and your first model.
>
> **Learning project:** `hello_project` — a standalone application (SQLite, no PostgreSQL).
> This is the first step of the evolution. The final architecture will appear later.

---

## Step outcome

```
http://localhost:8000/        →  Hello, Django!
http://localhost:8000/about/  →  Це моя перша сторінка на Django!
http://localhost:8000/notes/  →  Список нотаток з HTML-шаблоном
http://localhost:8000/admin/  →  Адмін-панель (superuser)
```

---

## What you will learn

- How Django handles an HTTP request (the Request/Response cycle)
- Project structure: `startproject` vs `startapp`
- `manage.py` commands: runserver, migrate, createsuperuser, shell
- View functions: `HttpResponse`, `render`
- URL routes: `path()`, `include()`, `app_name`
- Django Admin: Users, Groups, registering models
- Your first model: `models.Model`, migrations, the ORM shell

---

## Structure after completing the step

```
hello_django/
├── venv/                      ← virtual environment
├── db.sqlite3                 ← SQLite database
├── manage.py                  ← CLI orchestrator
├── requirements.txt
├── hello_project/             ← project configuration
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
└── hello_app/                 ← our first app
    ├── models.py              ← Note model
    ├── views.py               ← index, about, note_list
    ├── urls.py                ← /, /about/, /notes/
    ├── admin.py               ← NoteAdmin
    ├── migrations/
    └── templates/
        └── hello_app/
            └── note_list.html
```

---

## Learning state vs Notes Chat App

| | hello_project (this step) | notes_chat_app (the final goal) |
|-|--------------------------|-------------------------------|
| Database | SQLite | PostgreSQL |
| Running | `python manage.py runserver` | Docker Compose |
| Auth | Basic admin | `@login_required`, Groups, IDOR protection |
| Views | `HttpResponse` + `render` | 15+ FBVs with selectors/services |
| Templates | A single `note_list.html` | A full Bootstrap 5 SaaS hierarchy |

---

## Reading order for this step

1. **[Environment and first run](environment.md)** — venv, Django, startproject, the first run
2. **[Project structure](project_structure.md)** — anatomy of Request/Response, manage.py, settings.py
3. **[URLs and Views](urls_and_views.md)** — view functions, URL patterns, reverse()
4. **[Templates](templates.md)** — your first HTML template, render(), the MVT architecture
5. **[Django Admin](admin.md)** — the admin panel, your first model, the ORM shell
6. **[Checkpoint](checkpoint.md)** — checklist, common mistakes, practical exercises
