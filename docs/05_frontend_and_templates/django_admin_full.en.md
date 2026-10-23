# Django Admin — Administration

> **Django Admin** is an automatically generated interface for managing the data in the database.
> It is available at: `http://127.0.0.1:8001/admin/` (the port of the `web` service in Docker)

---

## 1. What is Django Admin?

Imagine you have an application with 1000 notes. You need to find and delete spam notes or grant moderator permissions to a particular user. Without the Admin you would have to write separate views for that.

**Django Admin** is a ready-made interface where you can:
- View and edit any record in the database
- Search and filter data
- Manage users and their permissions
- Perform bulk operations (for example, delete 50 spam notes with one click)

---

## 2. Who has access to the Admin?

```python
# Two types of privileged users:

user.is_staff = True
# ↑ Can log in to /admin/
# ↑ But has NO permissions unless they are explicitly granted!

user.is_superuser = True  
# ↑ Automatically has ALL permissions in the system
# ↑ Even those that are not explicitly granted
# ↑ has_perm() always returns True
```

**Critical rule:**
> **Never use a superuser for everyday work!**
>
> Reason: if a superuser tests the functionality, has_perm() is always True.
> This masks authorization bugs. A real user without permissions may run into an error
> that you never saw while testing as a superuser.

### Differences:

| Attribute | Access to /admin/ | Permissions |
|---------|-------------------|-------|
| `is_staff=True` | ✓ | Only explicitly granted ones |
| `is_superuser=True` | ✓ | All permissions automatically |
| Regular user | ✗ | None |

---

## 3. How to register a model in the Admin

```python
# notes_app/admin.py — a teaching example.
# The real project currently uses only the simple way: admin.site.register(...)

from django.contrib import admin
from .models import Note

# Option 1. The simple way — basic registration:
admin.site.register(Note)

# Option 2. The extended way — with customization.
# Use it INSTEAD OF option 1: registering the same model twice
# raises admin.sites.AlreadyRegistered.
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ('title', 'user', 'group', 'priority', 'created_at')
    # ↑ Which columns to show in the list
    
    list_filter = ('priority', 'group', 'is_pinned')
    # ↑ Filters in the right-hand panel (/admin/notes_app/note/?priority=4)
    
    search_fields = ('title', 'content', 'user__username')
    # ↑ Search across these fields
    # user__username → search through an FK (notes of the user named 'alice')
    
    raw_id_fields = ('user', 'notebook')
    # ↑ For an FK, shows an ID input field instead of a select (faster with 1000+ records)
```

**What we get at /admin/:**
```
[ ] | Заголовок          | Юзер  | Група  | Пріоритет | Дата
[ ] | Зустріч з клієнтом | alice | Робота | Терміново | 2025-06-03
[ ] | Купити молоко      | alice | Сімя   | Низький   | 2025-06-02
```

---

## 4. Managing users and permissions through the Admin

```
/admin/auth/user/     ← list of all users
/admin/auth/group/    ← list of groups and their permissions
```

**How to grant permissions to a user through the Admin:**
1. `/admin/auth/user/42/change/`
2. The "Permissions" section → tick ✓ next to the required permissions
3. Or add the user to a Group that already has the required permissions

---

## 5. Creating a superuser (command line)

```bash
# First run (the stack is already up via docker compose up -d):
docker compose exec web python manage.py createsuperuser

# Django will ask:
Username: admin
Email: admin@example.com
Password: (at least 8 characters)

# Open your browser:
# http://127.0.0.1:8001/admin/
```

---

## Where is this in our project?

| File | What's there |
|------|------|
| `notes_app/admin.py` | Model registration via `admin.site.register()` (Note, Notebook, Tag, etc.) |
| `notes_project/urls.py` | `path('admin/', admin.site.urls)` |
| `notes_project/settings.py` | `django.contrib.admin` in INSTALLED_APPS |
