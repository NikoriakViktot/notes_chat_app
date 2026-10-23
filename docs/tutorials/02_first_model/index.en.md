# Step 2. Bootstrap Notes

> **Learning project:** `bootstrap_notes` — a standalone application (SQLite, no PostgreSQL).
> This is the second step of the evolution. You move from `HttpResponse("text")` to full CRUD with a Bootstrap UI.
>
> **Prerequisites:** you have completed [Step 1. Hello Django](../01_hello_django/index.md) — you have the `Note` model and a Django project.

---

## Step outcome

```
http://localhost:8000/             →  Redirect to /notes/
http://localhost:8000/notes/       →  List of notes — Bootstrap Cards Grid
http://localhost:8000/notes/new/   →  Create form (ModelForm + PRG)
http://localhost:8000/notes/1/     →  Note detail
http://localhost:8000/notes/1/edit/   →  Edit form
http://localhost:8000/notes/1/delete/ →  Delete confirmation (POST only)
http://localhost:8000/admin/       →  Django Admin with a custom NoteAdmin
```

---

## What you will learn

- `ModelForm` — a form generated automatically from a model
- The PRG pattern (Post/Redirect/Get) — protection against duplicates on F5
- Django Messages — flash messages
- Template Inheritance — `base.html` and `{% extends %}` / `{% block %}` blocks
- Bootstrap 5 — Grid, Cards, Navbar, Sticky Footer
- CRUD views: `note_create`, `note_edit`, `note_delete`, `note_detail`
- `get_object_or_404` — a safe replacement for `objects.get()`

---

## Structure after completing the step

```
bootstrap_notes/
├── manage.py
├── requirements.txt           ← Django + django-bootstrap5
├── db.sqlite3
├── hello_project/
│   ├── settings.py            ← MESSAGE_TAGS, INSTALLED_APPS
│   └── urls.py
└── hello_app/
    ├── models.py              ← Note (from Step 1)
    ├── forms.py               ← NoteForm (ModelForm) ← NEW
    ├── views.py               ← 5 CRUD views ← EXTENDED
    ├── urls.py                ← 6 routes ← EXTENDED
    ├── admin.py               ← custom NoteAdmin
    ├── migrations/
    └── templates/
        ├── base.html          ← Bootstrap CDN, Navbar, Messages ← NEW
        └── hello_app/
            ├── note_list.html     ← Card Grid ← REWRITTEN
            ├── note_detail.html   ← Detail + Breadcrumb ← NEW
            ├── note_form.html     ← Bootstrap Form ← NEW
            └── note_confirm_delete.html ← Deletion ← NEW
```

---

## Learning state vs Notes Chat App

| | bootstrap_notes (this step) | notes_chat_app (the final goal) |
|-|---------------------------|-------------------------------|
| Project | Standalone SQLite | Docker + PostgreSQL |
| Auth | None | `@login_required`, Groups |
| ModelForm | A basic `NoteForm` | More complex forms with `clean_*()` |
| Views | FBVs without user checks | FBVs + selectors + services |
| Templates | Bootstrap CDN, 4 templates | Bootstrap SaaS hierarchy: base → layout → page |
| Admin | `NoteAdmin(admin.ModelAdmin)` | `NoteAdmin` + Unfold Admin |

---

## Reading order for this step

1. **[Models and migrations](models_and_migrations.md)** — the Note model, makemigrations, migrate, running the project
2. **[Django Admin](django_admin.md)** — registering models, a custom ModelAdmin
3. **[ModelForm and CRUD](modelform_and_crud.md)** — ModelForm, PRG, Messages, base.html, all CRUD views and templates
4. **[Checkpoint](checkpoint.md)** — checklist, common mistakes, practical exercises
