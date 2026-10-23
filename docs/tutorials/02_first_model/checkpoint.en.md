# Checkpoint

> The final check of Step 2.
> Complete the practical exercises, go through the checklist and review the common mistakes.

---

## All commands in order

```bash
# 1. Activate the venv
source venv/bin/activate          # Linux/Mac
# or: venv\Scripts\activate      # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Apply migrations
python manage.py migrate

# 4. Create an administrator
python manage.py createsuperuser

# 5. Start the server
python manage.py runserver
# → http://localhost:8000/notes/

# If you changed models.py:
python manage.py makemigrations
python manage.py migrate
```

---

## What to check in the browser

| URL | What to check |
|-----|---------------|
| `http://localhost:8000/` | Redirect to `/notes/` |
| `http://localhost:8000/notes/` | List with Bootstrap Cards |
| `http://localhost:8000/notes/new/` | Create form with Bootstrap styles |
| `http://localhost:8000/notes/1/` | Note detail |
| `http://localhost:8000/notes/1/edit/` | Edit form (filled in with data) |
| `http://localhost:8000/notes/1/delete/` | Delete confirmation page |
| `http://localhost:8000/admin/` | Admin panel with a custom NoteAdmin |

**Detailed check:**

1. List: Cards have equal height (`h-100`)
2. Mobile (DevTools → Toggle Device, Ctrl+Shift+M): 1 column, hamburger Navbar
3. Tablet: 2 columns; Desktop: 3 columns
4. Form: with an empty `title`, a validation error appears
5. After creating → a `success` flash message with the title text
6. F5 after POST → you stay on `/notes/` (PRG works)

---

## Changes in files

| File | What you did |
|------|-------------|
| `hello_project/settings.py` | `django_bootstrap5` in INSTALLED_APPS, `MESSAGE_TAGS` |
| `hello_app/forms.py` | `NoteForm(ModelForm)` — NEW |
| `hello_app/views.py` | 6 views (index + 5 CRUD): `index`, `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| `hello_app/urls.py` | 6 URL routes |
| `hello_app/admin.py` | `NoteAdmin` with `list_display`, `search_fields`, `@admin.display` |
| `hello_app/templates/base.html` | Bootstrap CDN, Navbar, Messages, Footer — NEW |
| `hello_app/templates/hello_app/note_list.html` | Bootstrap Card Grid — REWRITTEN |
| `hello_app/templates/hello_app/note_detail.html` | Detail + Breadcrumb — NEW |
| `hello_app/templates/hello_app/note_form.html` | Bootstrap Form — NEW |
| `hello_app/templates/hello_app/note_confirm_delete.html` | Deletion — NEW |

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` is not where Django looks for it | The file must be in `hello_app/templates/base.html` (not in `hello_app/templates/hello_app/`) |
| `NoReverseMatch: 'note_create'` | The URL name is not registered or the namespace is wrong | Check `hello_app/urls.py` and `app_name = 'hello_app'` |
| `NoReverseMatch: 'note_list'` | The namespace is not specified | `{% url 'hello_app:note_list' %}` (with a colon) |
| `403 Forbidden` after POST | `{% csrf_token %}` is missing from the form | Add `{% csrf_token %}` inside the `<form>` |
| Bootstrap styles are not applied | `class='form-control'` was not added to the widget | Check `NoteForm.Meta.widgets` in `forms.py` |
| `IntegrityError` on save | `title` cannot be empty | Check the validation: `form.is_valid()` |
| Duplicate after F5 | No redirect after POST | PRG: always `return redirect(...)` after `form.save()` |
| Cards of different heights | No `h-100` on `.card` | Add `h-100` to `<div class="card">` |
| Footer in the middle of the page | No Flexbox body | `d-flex flex-column min-vh-100` on `<body>` + `flex-grow-1` on `<main>` |
| Buttons are not clickable (there is a stretched-link) | z-index | Add `position-relative z-1` to the `btn-group` |
| Flash messages do not appear | `MESSAGE_TAGS` is not configured or the template is wrong | Check `settings.py` → `MESSAGE_TAGS` and `base.html` → `{% if messages %}` |
| `ImproperlyConfigured: namespace` | `app_name` is missing from `urls.py` | Add `app_name = 'hello_app'` |

---

## Practical exercises

1. Run the project and open `/notes/` — make sure the page is styled with Bootstrap.
2. Create 3 notes through the `/notes/new/` form. Check the flash messages.
3. Edit one note. Make sure it is an `UPDATE` and not a duplicate (the id did not change).
4. Delete a note — make sure the confirmation page is shown before deletion.
5. Add a `priority` field (choices: 1=Low, 2=Medium, 3=High) to the model, NoteForm and the note detail page.
6. (Bonus) In `note_list.html`, show a Bootstrap Badge with the priority on each card.

---

## Self-check checklist

- [ ] `base.html` → `note_list.html` / `note_form.html`: Template Inheritance via `{% extends %}`
- [ ] Bootstrap CSS is included via CDN in `base.html`
- [ ] Flash messages are displayed after POST and disappear after F5
- [ ] `{% csrf_token %}` is present in every POST form
- [ ] `redirect()` after `form.save()` (PRG pattern)
- [ ] `get_object_or_404` instead of `objects.get()` — 404 rather than 500
- [ ] Sticky Footer: `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1`
- [ ] The Card Grid is responsive: 1/2/3 columns depending on width
- [ ] `note_create` — `form.save()` → INSERT; `note_edit` — `NoteForm(request.POST, instance=note)` + `form.save()` → UPDATE
- [ ] I understand what PRG is and why F5 after PRG is safe

---

## Summary of concepts

| Concept | Where in the code |
|-----------|-----------|
| ModelForm | `hello_app/forms.py` → `class NoteForm(forms.ModelForm)` |
| PRG pattern | `note_create`: `return redirect(...)` after `form.save()` |
| Messages | `messages.success(request, ...)` + `{% if messages %}` in `base.html` |
| Template Inheritance | `{% extends 'base.html' %}` + `{% block content %}` |
| CRUD views | `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| Bootstrap Grid | `row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4` |
| Sticky Footer | `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1` |
| Protecting DELETE | POST, not GET + `{% csrf_token %}` |

---

## What's next

**Step 3 →** CRUD and architecture — notes_project: Selectors, Services, ER diagrams, PostgreSQL, CBVs.
