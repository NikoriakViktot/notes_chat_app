# Django Admin

> In Step 1 you already registered `NoteAdmin` with a simple `@admin.register(Note)`.
> Here we will extend it into a full-fledged admin class with custom columns,
> search, filters and computed fields.

---

## What you already have after Step 1

`hello_app/admin.py` after Step 1:

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display    = ('title', 'created_at')
    search_fields   = ('title', 'content')
    list_filter     = ('created_at',)
    ordering        = ('-created_at',)
    readonly_fields = ('created_at',)
```

This is already not bad. But let's look at each option separately.

---

## Extended NoteAdmin

```python
from django.contrib import admin
from django.utils.html import format_html
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    # ─── List ──────────────────────────────────────────────────────────────────
    list_display    = ['title', 'short_content', 'created_at']
    # Columns in the list table: title, text preview, date
    # The first column is always a link to the detail page

    search_fields   = ['^title', 'content']
    # '^title' → LIKE 'search%' (faster)  vs  'title' → LIKE '%search%'
    # 'content' → full-text search

    list_filter     = ['created_at']
    # Filters on the right: "Any date", "Today", "This week"...

    ordering        = ['-created_at']
    # Sorting: newest first (overrides the ordering from Meta)

    list_per_page   = 20
    # Pagination: 20 records per page

    # ─── Detail ─────────────────────────────────────────────────────────────────
    readonly_fields = ['created_at']
    # These fields are shown but not editable (auto_now_add → already editable=False)

    # ─── Computed column ─────────────────────────────────────────────────────────
    @admin.display(description='Зміст (preview)')
    def short_content(self, obj):
        """Shows the first 80 characters of content in the list."""
        if not obj.content:
            return '—'
        preview = obj.content[:80] + ('...' if len(obj.content) > 80 else '')
        return format_html('<span style="color:#6b7280">{}</span>', preview)
```

---

## Anatomy of ModelAdmin

### list_display

```python
list_display = ['title', 'short_content', 'created_at']
# ↑ Each item is either a model field, a NoteAdmin method, or a model method

# A model field:
list_display = ['title', 'created_at']

# A NoteAdmin method with @admin.display:
@admin.display(description='Зміст (preview)')
def short_content(self, obj):
    return obj.content[:80]

# A model method:
# In models.py:
def preview(self):
    return self.content[:80]
# In admin.py:
list_display = ['title', 'preview', 'created_at']
```

### search_fields — search syntax

```python
search_fields = ['^title', 'content', '=status']
# Prefix | SQL LIKE          | When to use
# ──────────────────────────────────────────────────
# (none) | LIKE '%query%'    | Full-text (slow on large tables)
# '^'    | LIKE 'query%'     | Search from the start (indexable, faster)
# '='    | = 'query'         | Exact match
# '@'    | Full-text         | PostgreSQL full-text (__search, needs django.contrib.postgres; not SQLite)
```

### list_filter — built-in filters

```python
list_filter = ['created_at', 'is_public']
# DateTimeField → automatic filters: "Any date", "Today", "This week"...
# BooleanField → "All", "Yes", "No"
```

---

## format_html — safe HTML in the admin

```python
from django.utils.html import format_html

@admin.display(description='Статус')
def status_badge(self, obj):
    color = 'green' if obj.is_active else 'red'
    label = 'Активна' if obj.is_active else 'Архів'
    # format_html inserts HTML safely:
    # → escaping for all {}  → protection against XSS
    return format_html(
        '<span style="color:{};font-weight:bold">{}</span>',
        color,   # ← escaped
        label,   # ← escaped
    )
    # Don't concatenate strings! f"<span>{obj.title}</span>" → XSS if title contains <script>
```

---

## admin.site.register vs @admin.register

```python
# Option 1: admin.site.register (old style)
admin.site.register(Note, NoteAdmin)

# Option 2: @admin.register (modern, a decorator)
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    ...

# The result is the same. @admin.register is more readable.
```

---

## Registering several models

```python
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    ...

@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug']
    prepopulated_fields = {'slug': ('name',)}
    # prepopulated_fields: automatically fills slug from name (via JS)
```

---

## Where to find a note's admin URL

```
/admin/hello_app/note/          ← list of notes
/admin/hello_app/note/add/      ← add a note
/admin/hello_app/note/42/       ← edit the note with id=42
/admin/hello_app/note/42/delete/ ← delete
```

URL format: `/admin/<app_label>/<model_name>/`

`app_label` is the name from `AppConfig.label` (by default = the app's folder name).

---

## What's next with Django Admin

At this step we use the standard `django.contrib.admin.ModelAdmin`.

In **Step 4 (Templates and Forms)** you will get:
- `django-unfold` — a Tailwind-styled admin instead of the standard one
- the `UNFOLD` config in settings.py (sidebar navigation, icons, branding)
- re-registering `User` and `Group` with Unfold forms
