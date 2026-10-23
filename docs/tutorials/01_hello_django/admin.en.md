# Django Admin

> Django Admin is an automatically generated web interface for managing data.
> It is a built-in Django app, `django.contrib.admin`, with its own models, views and templates.
> It is available right after `migrate` + `createsuperuser`.

---

## What you see after logging in

```
http://127.0.0.1:8000/admin/               ← main page (list of sections)
http://127.0.0.1:8000/admin/auth/user/     ← list of users
http://127.0.0.1:8000/admin/auth/user/add/ ← create a new user
http://127.0.0.1:8000/admin/auth/group/    ← list of groups (roles)
```

```
Django administration                         Logged in as: admin
  AUTHENTICATION AND AUTHORIZATION
    Groups    → add / edit groups
    Users     → all users, password changes, permissions
```

---

## The Users section

A list of all users in the system. Each user has:

| Field | What it means |
|------|------------|
| **Username** | Login name |
| **Email** | Email address (optional) |
| **Password** | A hash (PBKDF2+SHA256) — never stored in plain text |
| **First/Last name** | First name and last name |
| **Active** | Whether the user can log in (False = blocked) |
| **Staff status** | Whether the user has access to `/admin/` |
| **Superuser status** | Whether the user has ALL permissions (bypasses permission checks) |
| **Groups** | Which groups (roles) are assigned |
| **User permissions** | Individual permissions (on top of group permissions) |

---

## The Groups section (groups/roles)

**A group = a named set of permissions (a role).**

Instead of assigning permissions to each user separately,
you create an "Editors" group with the required permissions and add people to it.

```
Group "News editors"
    ✅ news.add_article    ← can create articles
    ✅ news.change_article ← can edit articles
    ❌ news.delete_article ← CANNOT delete
    ❌ news.view_user      ← CANNOT see users

Group "Moderators"
    ✅ news.delete_article ← can delete
    ✅ auth.view_user      ← sees the list of users
```

**Django permission format:** `<app>.<action>_<model>`

```
hello_app.add_note      ← add notes
hello_app.change_note   ← edit notes
hello_app.delete_note   ← delete notes
hello_app.view_note     ← view notes
auth.add_user           ← add users
```

Django **automatically generates** 4 permissions for every model (`add`, `change`, `delete`, `view`).

---

## Action log (django_admin_log)

Every action in the admin panel is logged automatically:

```
http://127.0.0.1:8000/admin/ → Recent actions (right column)
```

The `django_admin_log` table stores:
- who performed the action (user)
- what they did (added / changed / deleted)
- which object (content_type + object_id)
- when (action_time)

---

## Step B1 — Your first model in models.py

Open `hello_app/models.py` and write:

```python
from django.db import models


class Note(models.Model):
    """
    A model = a Python class that describes a database table.

    The Django ORM automatically:
        - creates the 'hello_app_note' table in db.sqlite3
        - generates the id field (PRIMARY KEY AUTOINCREMENT)
        - provides an API: Note.objects.all(), Note.objects.create(...) etc.
    """

    # CharField → VARCHAR in SQL, a string of limited length
    title = models.CharField(
        max_length=200,
        verbose_name='Заголовок'
    )

    # TextField → TEXT in SQL, unlimited text
    content = models.TextField(
        blank=True,
        verbose_name='Текст'
    )

    # DateTimeField with auto_now_add=True — set on CREATE, never changes
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Створено'
    )

    # auto_now=True — updated on every SAVE
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Оновлено'
    )

    def __str__(self):
        # String representation: shown in the admin panel
        # instead of "Note object (1)"
        return self.title

    class Meta:
        verbose_name = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        ordering = ['-created_at']   # newest notes first
```

### Field types and their SQL equivalents

```python
# CharField — a short string, max_length is required
title = models.CharField(max_length=200)
# SQL: title VARCHAR(200) NOT NULL

# TextField — long text, no length limit
content = models.TextField(blank=True)
# blank=True: not required in Django forms
# SQL: content TEXT NOT NULL   (Django fills in default='' in Python, not in the DB)

# DateTimeField with auto_now_add
created_at = models.DateTimeField(auto_now_add=True)
# SQL: created_at TIMESTAMP NOT NULL   (Django sets the time on the first save())

# BooleanField
is_pinned = models.BooleanField(default=False)
# SQL: is_pinned BOOLEAN NOT NULL   (default=False lives in Python, not as an SQL DEFAULT)

# IntegerField with choices
PRIORITY_CHOICES = [(1, 'Низький'), (2, 'Середній'), (3, 'Високий')]
priority = models.SmallIntegerField(choices=PRIORITY_CHOICES, default=1)
# SQL: priority SMALLINT NOT NULL   (default=1 lives in Python)

# ForeignKey — an N→1 relationship
user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
# SQL: user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE
```

---

## Step B2 — Register the model in the admin panel

Open `hello_app/admin.py` and write:

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display    = ('title', 'created_at')          # Columns in the list
    search_fields   = ('title', 'content')             # Fields to search
    list_filter     = ('created_at',)                  # Filters on the right
    ordering        = ('-created_at',)                 # Sorting
    readonly_fields = ('created_at', 'updated_at')     # Not editable
```

**Result:** `http://localhost:8000/admin/hello_app/note/` — full CRUD for notes.

---

## Step B3 — Generate a migration

```bash
python manage.py makemigrations
```

```
Migrations for 'hello_app':
  hello_app/migrations/0001_initial.py
    + Create model Note
```

> `hello_app/migrations/0001_initial.py` is an automatically generated Python script
> that describes the SQL that needs to be executed. Do not edit it by hand.

---

## Step B4 — Apply the migration to the database

```bash
python manage.py migrate
```

```
Applying hello_app.0001_initial... OK
```

Now the `hello_app_note` table has appeared in `db.sqlite3`:

```sql
-- What Django executed for you:
CREATE TABLE "hello_app_note" (
    "id"         integer NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title"      varchar(200) NOT NULL,
    "content"    text NOT NULL,
    "created_at" datetime NOT NULL,
    "updated_at" datetime NOT NULL
);
```

### The two-step rule

```bash
# After ANY change to models.py — always two steps:
python manage.py makemigrations   # Record the plan of changes
python manage.py migrate          # Apply it to the DB

# makemigrations WITHOUT migrate:
# → the Python class exists, the DB table does not → OperationalError on the first query
```

### What happens between models.py and the DB

```
models.py (Python class)
    ↓ python manage.py makemigrations
hello_app/migrations/0001_initial.py  (plan of changes)
    ↓ python manage.py migrate
db.sqlite3 → hello_app_note table  (the real DB)
    ↓ @admin.register(Note)
http://127.0.0.1:8000/admin/hello_app/note/  (web interface)
```

---

## Step B5 — Check it in the browser

```bash
python manage.py runserver
```

Open `http://127.0.0.1:8000/admin/` — a new section **"Нотатки"** (the model's `verbose_name_plural`) has appeared.

1. Click **"Add note"** / **"Додати нотатку"**
2. Enter a title and text
3. Click **Save**
4. The note is saved in `db.sqlite3` → the `hello_app_note` table

---

## Django ORM — basic queries in the shell

```bash
python manage.py shell
```

```python
from hello_app.models import Note

# CREATE — INSERT INTO
Note.objects.create(title="Перша нотатка", content="Привіт Django!")
Note.objects.create(title="Django ORM", content="Дуже потужний!")

# READ — SELECT
Note.objects.all()                              # → QuerySet [<Note: Перша нотатка>, ...]
Note.objects.count()                            # → 2
Note.objects.filter(title__icontains='django')  # → case-insensitive search
Note.objects.get(id=1)                          # → <Note: Перша нотатка> or DoesNotExist
Note.objects.first()                            # → the first object
Note.objects.order_by('-created_at')            # → newest first

# UPDATE — UPDATE SET
note = Note.objects.get(id=1)
note.title = "Змінена нотатка"
note.save()                      # → UPDATE hello_app_note SET title=... WHERE id=1

# DELETE — DELETE FROM
note.delete()                                   # → delete one record
Note.objects.filter(id__gt=5).delete()         # → delete all with id > 5

# QuerySets are lazy:
qs = Note.objects.all()   # ← SQL is NOT EXECUTED YET
print(qs)                  # ← SQL runs only here!

# Useful lookups:
Note.objects.filter(title__icontains='перша')   # icontains = case-insensitive LIKE
Note.objects.filter(title__startswith='Django')
Note.objects.filter(created_at__year=2026)
Note.objects.filter(id__in=[1, 2, 3])
Note.objects.exclude(title='секрет')            # WHERE NOT (title = 'секрет')
```

> The Django shell is a regular Python interpreter, but with Django loaded.
> It is handy for quickly testing ORM queries without writing views.

---

## Full registration: admin.site.register vs @admin.register

```python
# Option 1: simple
admin.site.register(Note)

# Option 2: with configuration (better)
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_at')
```

Both do the same thing, but `@admin.register` is more readable and lets you
set `list_display`, `search_fields` and `list_filter` at the same time.
