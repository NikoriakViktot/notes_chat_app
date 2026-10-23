# Checkpoint

> This section is the final check of Step 1.
> Complete the practical exercises, go through the checklist and review the table of common mistakes
> before moving on to Step 2.

---

## All commands in order

```bash
# 1. Create and activate a venv
python -m venv venv
source venv/bin/activate      # Linux/Mac
# or: venv\Scripts\activate  # Windows

# 2. Install Django
pip install -r requirements.txt
# or: pip install django

# 3. Create the project (the dot matters!)
django-admin startproject hello_project .

# 4. Apply the initial migrations
python manage.py migrate

# 5. Create an administrator
python manage.py createsuperuser

# 6. Check the admin panel
python manage.py runserver
# → http://localhost:8000/admin/

# 7. Create an app
python manage.py startapp hello_app

# 8. Register hello_app in settings.py
# (add 'hello_app' to INSTALLED_APPS)

# 9. Write view functions (views.py) and URL routes (urls.py)

# 10. Connect hello_app.urls to hello_project/urls.py (include)

# 11. Describe the model in models.py
# 12. Create a migration
python manage.py makemigrations

# 13. Apply the migration
python manage.py migrate

# 14. Register the model in admin.py (@admin.register)

# 15. Final check
python manage.py runserver
# http://localhost:8000/        → Hello, Django!
# http://localhost:8000/about/  → text
# http://localhost:8000/notes/  → list of notes
# http://localhost:8000/admin/  → admin panel
```

---

## Changes in files

| File | What you did |
|------|-------------|
| `hello_project/settings.py` | Added `'hello_app'` to `INSTALLED_APPS` |
| `hello_app/models.py` | Wrote the `Note` model (CharField, TextField, DateTimeField) |
| `hello_app/admin.py` | Registered `NoteAdmin` via `@admin.register` |
| `hello_app/migrations/0001_initial.py` | Generated automatically by `makemigrations` |
| `hello_app/views.py` | Wrote the functions `index()`, `about()`, `note_list()` |
| `hello_app/urls.py` | Created the file with `app_name` and the routes `/, /about/, /notes/` |
| `hello_project/urls.py` | Connected the routes via `include()` |
| `hello_app/templates/hello_app/note_list.html` | Your first HTML template |

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `AttributeError: 'super' object has no attribute 'dicts'` | Python 3.14 is incompatible with Django 5.1 | `pip install django --upgrade` (installs 5.2+) |
| `OperationalError: no such table: auth_user` | Migrations were not run | `python manage.py migrate` |
| `OperationalError: no such table: hello_app_note` | `migrate` was not run after `makemigrations` | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | The venv is not activated or Django is not installed | Activate the venv → `pip install -r requirements.txt` |
| `Page not found (404)` at `/` | The route is not registered | Check `urls.py` in both files |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` is set in `include()`, but `app_name` is missing from `hello_app/urls.py` | Add `app_name = "hello_app"` to `hello_app/urls.py` |
| `NameError: name 'Note' is not defined` | `views.py` does not import the model | Add `from .models import Note` to `views.py` |
| Django does not see `hello_app` | Not added to `INSTALLED_APPS` | Add `'hello_app'` to `settings.py` |
| `django-admin: command not found` | Django is not installed or the venv is not activated | Activate the venv, then `pip install django` |
| `ModuleNotFoundError: No module named 'hello_project'` | You are not running from the project root | Go to the folder that contains `manage.py` |
| `DisallowedHost` | ALLOWED_HOSTS does not contain the host | Add the host to `ALLOWED_HOSTS` in `settings.py` |
| `CSRF verification failed` | `{% csrf_token %}` is missing from the form | Add `{% csrf_token %}` inside the `<form>` |
| The server does not stop | — | Press `Ctrl + C` in the terminal |

---

## Practical exercises

1. Go through steps 1–9 on your own and get `Hello, Django!` in the browser.

2. Add a third route `/contact/` with a view function `contact()`
   that returns a string with your name and email.

3. Add a route `/greet/<str:name>/` that returns `"Привіт, {name}!"`.

4. Create the `Note` model, make a migration, open the admin panel and add 3 notes by hand.

5. In the Django shell: find the note with `id=2`, change its `title`, and save it.
   Check it in the admin panel.

6. (Bonus) Add the field `is_pinned = models.BooleanField(default=False)` to the `Note` model.
   Create a new migration. Make sure the field has appeared in the admin panel.

---

## Self-check checklist

- [ ] `http://localhost:8000/` → `Hello, Django!`
- [ ] `http://localhost:8000/about/` → text
- [ ] `http://localhost:8000/notes/` → HTML list of notes
- [ ] `http://localhost:8000/admin/` → admin panel (superuser login)
- [ ] I understand the difference between `startproject` and `startapp`
- [ ] I know why `makemigrations` and `migrate` are two separate steps
- [ ] The `Note` model appears in the admin panel
- [ ] I can perform CRUD through the Django shell (`create`, `filter`, `get`, `save`, `delete`)
- [ ] I understand how Django finds a view by URL (the URLconf chain)
- [ ] I know the difference between superuser / staff / regular user
- [ ] `render()` takes `request`, a template path and a `context` dict
- [ ] The template lives in `hello_app/templates/hello_app/` (the doubled folder is correct)

---

## Summary of concepts

| Concept | Where in the code |
|-----------|-----------|
| URL route | `hello_app/urls.py` → `path('about/', views.about)` |
| View function | `hello_app/views.py` → `def about(request): return HttpResponse(...)` |
| Connecting app URLs | `hello_project/urls.py` → `include('hello_app.urls')` |
| Namespace | `app_name = 'hello_app'` + `namespace='hello_app'` |
| Reverse URL | `reverse('hello_app:about')` or `{% url 'hello_app:about' %}` |
| Path converter | `path('notes/<int:pk>/', ...)` |
| Template | `hello_app/templates/hello_app/note_list.html` |
| Context | `render(request, 'шаблон.html', {'notes': queryset})` |
| Model → DB | `makemigrations` + `migrate` |
| ORM CRUD | `create`, `filter`, `get`, `.save()`, `.delete()` |
| Admin registration | `@admin.register(Note)` in `admin.py` |
| MVT | Model → View → Template |

---

## What's next

**Step 2 →** Bootstrap Notes — Bootstrap 5, ModelForm, full CRUD with the PRG pattern, the first `notes_project`.
