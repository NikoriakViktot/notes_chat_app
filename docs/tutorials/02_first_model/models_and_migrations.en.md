# Models and migrations

> In `bootstrap_notes` the `Note` model is already defined in `models.py` — you inherit it from Step 1.
> This page explains its anatomy, how Django turns a class into a database table,
> and how to run the project from scratch.

---

## What the project already has

`bootstrap_notes` is a continuation of `hello_project`. `hello_app/models.py` contains:

```python
from django.db import models


class Note(models.Model):
    title      = models.CharField(max_length=200, verbose_name='Title')
    content    = models.TextField(blank=True, verbose_name='Text')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Created')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name        = 'Note'
        verbose_name_plural = 'Notes'
        ordering            = ['-created_at']
```

And a simple view:

```python
def note_list(request):
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

The `/notes/` page displays notes in plain HTML without Bootstrap.
Our goal is to replace this template and add a full CRUD.

---

## bootstrap_notes dependencies

`requirements.txt`:

| Package | Why |
|-------|--------|
| `Django>=5.2,<6` | Web framework |
| `django-bootstrap5>=24.0` | Bootstrap 5 for Django Forms (`{% bootstrap_form form %}`) |
| `django-debug-toolbar>=4.0` | SQL panel for debugging (Step 4 — Templates) |
| `django-unfold>=0.40` | Tailwind-styled Django Admin (Step 4 — Templates) |

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Check:
```bash
python -m django --version  # → 5.2.x
```

---

## Running the project

```bash
# 1. Activate the venv
source venv/bin/activate          # Linux/Mac
# or: venv\Scripts\activate       # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Apply migrations
python manage.py migrate

# 4. Create an administrator
python manage.py createsuperuser

# 5. Start the server
python manage.py runserver
```

| URL | Result |
|-----|-----------|
| `http://localhost:8000/notes/` | List of notes (plain HTML) |
| `http://localhost:8000/admin/` | Admin panel |

Add a few notes through the admin — they will appear at `/notes/`.

---

## Anatomy of a model: from a Python class to an SQL table

```
Note (Python class)                hello_app_note (SQL table)
═══════════════════════════════════════════════════════════════
id (auto BigAutoField)          →  id bigint NOT NULL PRIMARY KEY
title (CharField(max_length=200)) →  title varchar(200) NOT NULL
content (TextField(blank=True)) →  content text NOT NULL  (no SQL DEFAULT)
created_at (DateTimeField(auto_now_add=True)) → created_at timestamp NOT NULL
```

```python
# models.Model — the base class for all Django models
class Note(models.Model):
    #           ↑ we inherit from models.Model → we get:
    #           - id (PRIMARY KEY AUTOINCREMENT) automatically
    #           - Note.objects (Manager) → ORM API
    #           - .save(), .delete() methods

    title = models.CharField(
        max_length=200,          # VARCHAR(200) in SQL
        verbose_name='Title'     # field name in the admin panel
    )

    content = models.TextField(
        blank=True,              # Can be empty in forms
        verbose_name='Text'      # null=False by default!
                                 # → TEXT NOT NULL (the empty string '' comes from the form/Python, not the DB)
    )

    created_at = models.DateTimeField(
        auto_now_add=True,       # Set automatically on CREATE
        verbose_name='Created'   # auto_now_add=True → editable=False!
                                 # Will not appear in forms
    )
```

### blank=True vs null=True

```python
# blank=True — form validation: the field is optional
content = models.TextField(blank=True)
# → the form accepts an empty string

# null=True — database: can store NULL
content = models.TextField(null=True, blank=True)
# → the DB stores NULL instead of ''

# For CharField/TextField — do not use null=True
# Django convention: an empty string '' instead of NULL in string fields
# Why: NULL and '' are different values, two states of "empty"

# null=True is useful for numeric fields:
age = models.IntegerField(null=True, blank=True)
# → "not specified" (NULL) vs "0" — different values
```

---

## auto_now_add vs auto_now

```python
# auto_now_add=True: CREATION time
created_at = models.DateTimeField(auto_now_add=True)
# Set once on INSERT → never changes
# editable=False → will not appear in forms

# auto_now=True: time of the LAST UPDATE
updated_at = models.DateTimeField(auto_now=True)
# Updated on EVERY save()
# editable=False → will not appear in forms

# Both:
class Note(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)  # creation time
    updated_at = models.DateTimeField(auto_now=True)      # update time
```

---

## __str__ and Meta

```python
def __str__(self):
    return self.title
    # String representation of the object:
    # Without __str__: "Note object (1)"  ← inconvenient
    # With __str__:    "Shopping list"    ← clear
    #
    # Used in: the admin panel, the Django shell,
    # ModelChoiceField (select) in forms

class Meta:
    verbose_name        = 'Note'
    verbose_name_plural = 'Notes'
    # These strings are displayed in the admin panel
    # Without them: "Note" / "Notes" (Django's English defaults)

    ordering = ['-created_at']
    # Default ordering: '-' means DESC (newest first)
    # Equivalent: Note.objects.order_by('-created_at')
    # Every QuerySet without .order_by() will use this ordering
```

---

## The migration cycle

```
models.py (Python class)
    ↓
python manage.py makemigrations
    ↓
hello_app/migrations/0001_initial.py  (a plan of changes in Python)
    ↓
python manage.py migrate
    ↓
DB: hello_app_note (a real table)
```

```bash
# Show the SQL the migration will execute:
python manage.py sqlmigrate hello_app 0001
```

```sql
-- Output (SQLite):
BEGIN;
CREATE TABLE "hello_app_note" (
    "id"         integer NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title"      varchar(200) NOT NULL,
    "content"    text NOT NULL,
    "created_at" datetime NOT NULL
);
COMMIT;
```

### The two-step rule

```bash
# After ANY change to models.py — always two steps:
python manage.py makemigrations   # Record the plan
python manage.py migrate          # Apply it to the DB

# makemigrations WITHOUT migrate:
# The Python class is updated, the table in the DB is old
# → OperationalError: column does not exist
```

---

## What to check after starting

```bash
python manage.py runserver
```

| URL | Result |
|-----|-----------|
| `http://localhost:8000/notes/` | List of notes (plain HTML without Bootstrap — for now) |
| `http://localhost:8000/admin/` | Admin panel |

Add a few notes through the admin before you continue — you will need them
to check the Bootstrap Cards in the next section.
