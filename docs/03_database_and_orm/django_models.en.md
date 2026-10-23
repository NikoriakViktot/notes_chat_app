# Django Models

> A model is both a Python class and a database table.
> Each class attribute → a column in the table. The Django ORM turns Python into SQL.

---

## Why models

Without an ORM you would write SQL by hand:

```python
# Without ORM — SQL by hand
cursor.execute(
    "INSERT INTO notes (title, content, user_id, priority) VALUES (%s, %s, %s, %s)",
    [title, content, user.id, priority]
)
```

With the Django ORM:

```python
# With ORM — a Python class
note = Note.objects.create(
    title=title, content=content, user=user, priority=Note.PRIORITY_MEDIUM
)
```

The ORM:
- generates SQL automatically (and efficiently)
- protects against SQL injection
- makes refactoring possible (rename a field → an ALTER TABLE is generated)
- supports PostgreSQL, SQLite, MySQL without code changes

---

## Anatomy of a Model class

```python
# notes_app/models.py

class Note(models.Model):
    # ── Constants for choices ─────────────────────────────────────────
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_URGENT = 4

    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    '🟢 Низький'),
        (PRIORITY_MEDIUM, '🟡 Середній'),
        (PRIORITY_HIGH,   '🟠 Високий'),
        (PRIORITY_URGENT, '🔴 Терміново'),
    ]

    # ── Fields (Field types) ──────────────────────────────────────────
    user     = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    group    = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True, blank=True, related_name='notes')
    notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True, related_name='notes')
    tags     = models.ManyToManyField(Tag, blank=True, related_name='notes')

    title      = models.CharField(max_length=200)
    content    = models.TextField(blank=True)
    priority   = models.PositiveSmallIntegerField(choices=PRIORITY_CHOICES, default=PRIORITY_LOW)
    is_pinned  = models.BooleanField(default=False)
    is_archived= models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)   # ← set once on CREATE
    updated_at = models.DateTimeField(auto_now=True)        # ← updated on every save()

    # ── Special methods ───────────────────────────────────────────────
    def __str__(self):
        pin = "📌 " if self.is_pinned else ""
        return f"{pin}{self.title}"

    # ── Meta class ────────────────────────────────────────────────────
    class Meta:
        ordering = ['-is_pinned', '-priority', '-updated_at']  # default ORDER BY
        verbose_name = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        indexes = [
            models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),
            models.Index(fields=['user', 'is_pinned'],   name='cnote_user_pinned_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='cnote_priority_valid_range'
            ),
        ]
```

---

## Field types

| Field type | PostgreSQL column | Usage in the project |
|-----------|-------------------|----------------------|
| `CharField(max_length=N)` | `VARCHAR(N)` | `title`, `name`, `color` |
| `TextField()` | `TEXT` | `content`, `bio`, `description` |
| `BooleanField()` | `BOOLEAN` | `is_pinned`, `is_archived`, `is_done` |
| `PositiveSmallIntegerField()` | `SMALLINT` | `priority` (1–4) |
| `DateTimeField(auto_now_add=True)` | `TIMESTAMPTZ` | `created_at` |
| `DateTimeField(auto_now=True)` | `TIMESTAMPTZ` | `updated_at` |
| `DateField()` | `DATE` | `due_date` in TodoItem |
| `DecimalField(max_digits, decimal_places)` | `NUMERIC` | `quantity`, `estimated_price` |
| `URLField()` | `VARCHAR(200)` | `avatar_url` |
| `ForeignKey()` | `INT` + FK constraint | `user`, `group`, `notebook` |
| `ManyToManyField()` | junction table | `tags`, `shared_with` |
| `OneToOneField()` | `INT` UNIQUE + FK | `UserProfile.user` |

### blank vs null

```python
# null=True  → NULL in the database
# blank=True → allows an empty value in the form (and '' in string fields)

notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True)
# null=True → the FK can be NULL in the DB (notebook is optional)
# blank=True → the form does not require notebook (validation)

content = models.TextField(blank=True)
# NOT null=True for strings — Django stores '' instead of NULL
# (an empty string is better than NULL for text fields)
```

---

## Relationships between models

### ForeignKey (1:N)

```python
# One Notebook → many Notes
class Note(models.Model):
    notebook = models.ForeignKey(
        Notebook,
        on_delete=models.SET_NULL,   # if the Notebook is deleted → Note.notebook = NULL
        null=True,
        blank=True,
        related_name='notes',        # notebook.notes.all() → all notes in this notebook
    )
```

**on_delete options:**

| `on_delete` | Behavior | Where it is used |
|-------------|-----------|---------------|
| `CASCADE` | deletes the child record | `Note.user`, `Reminder.note`, `ChatMessage.author` |
| `SET_NULL` | sets `NULL` | `Note.notebook`, `Note.group`, `ShoppingList.group` |
| `PROTECT` | forbids deletion | — (not used) |
| `DO_NOTHING` | does nothing (dangerous) | — (not used) |

### ManyToMany

```python
class Note(models.Model):
    tags = models.ManyToManyField(Tag, blank=True, related_name='notes')
    # Django automatically creates the table:
    # notes_app_note_tags (id, note_id, tag_id)
```

Usage:
```python
note.tags.add(tag)              # add a tag
note.tags.remove(tag)           # remove a tag
note.tags.set([tag1, tag2])     # replace the tags
note.tags.all()                 # all tags of the note
tag.notes.all()                 # all notes with this tag (related_name)
```

### OneToOne

```python
class UserProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile',
    )
```

Each `User` has exactly one `UserProfile`. Access:
```python
user.profile.display_name   # via related_name
user.profile.timezone
```

---

## ER diagram (full)

```mermaid
erDiagram
    AUTH_USER ||--o| USER_PROFILE : "1:1"
    AUTH_USER ||--o{ NOTEBOOK : owns
    AUTH_USER ||--o{ NOTE : owns
    AUTH_USER ||--o{ TAG : owns
    AUTH_USER ||--o{ TODO_LIST : owns
    AUTH_USER ||--o{ SHOPPING_LIST : owns

    NOTEBOOK ||--o{ NOTE : "groups (SET_NULL)"
    AUTH_GROUP ||--o{ NOTE : "shared_with (SET_NULL)"
    NOTE }o--o{ TAG : "M:N"
    NOTE ||--o{ REMINDER : "CASCADE"

    TODO_LIST ||--o{ TODO_ITEM : "CASCADE"
    AUTH_GROUP ||--o{ SHOPPING_LIST : "shared_with (SET_NULL)"

    AUTH_GROUP ||--o{ CHAT_MESSAGE : "CASCADE"
    AUTH_USER ||--o{ CHAT_MESSAGE : "CASCADE"
```

---

## The Meta class — model configuration

```python
class Meta:
    # Default ordering for the queryset (without .order_by())
    ordering = ['-is_pinned', '-priority', '-updated_at']

    # Names in Django Admin and for verbose output
    verbose_name = 'Нотатка'
    verbose_name_plural = 'Нотатки'

    # Composite unique constraint
    unique_together = [('user', 'name')]   # in Tag: each tag has a unique name per user

    # Indexes (more details → query_optimization.md)
    indexes = [
        models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),
    ]

    # Database-level CHECK constraints
    constraints = [
        models.CheckConstraint(
            check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
            name='cnote_priority_valid_range'
        ),
    ]
```

---

## choices — enum-like fields

```python
class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2

    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    '🟢 Низький'),
        (PRIORITY_MEDIUM, '🟡 Середній'),
    ]

    priority = models.PositiveSmallIntegerField(
        choices=PRIORITY_CHOICES,
        default=PRIORITY_LOW,
    )
```

The database stores `1`, `2` (integer). Django knows how to display `'🟢 Низький'` in forms and the Admin.

```python
# Access in code
note.priority                     # 2 (integer)
note.get_priority_display()       # '🟡 Середній' (human-readable string)
note.priority == Note.PRIORITY_MEDIUM  # True (constants instead of magic numbers)
```

---

## auto_now_add vs auto_now

```python
created_at = models.DateTimeField(auto_now_add=True)
# Set ONCE on the first save
# Cannot be overwritten from code — the field is read-only
# SQL: DEFAULT CURRENT_TIMESTAMP on INSERT

updated_at = models.DateTimeField(auto_now=True)
# Updated on EVERY .save()
# SQL: UPDATE SET updated_at = NOW() on every UPDATE
```

---

## Where in notes_chat_app

| File | Contents |
|------|-------|
| `notes_app/models.py` | all 10 models |
| `notes_app/migrations/` | auto-generated migrations |
| `notes_app/admin.py` | model registration in Django Admin |
| `notes_app/selectors.py` | read-only QuerySets through these models |
| `notes_app/services.py` | create/update/delete through these models |

---

## Practical exercise

```bash
docker compose exec web python manage.py shell
```

```python
from notes_app.models import Note, Tag, Notebook
from django.contrib.auth.models import User

# Find the user
user = User.objects.get(username='demo_alice')

# All of their notes
notes = Note.objects.filter(user=user)
print(f"Notes: {notes.count()}")

# The first note and its tags
note = notes.first()
print(note.title)
print(note.get_priority_display())
print([t.name for t in note.tags.all()])

# How many notes are in each notebook
from django.db.models import Count
Notebook.objects.filter(user=user).annotate(n=Count('notes')).values('title', 'n')
```

---

## In the book

- [Migrations](migrations.md) — how Django turns model changes into SQL
- [Query Optimization](query_optimization.md) — select_related, prefetch_related, N+1
- [Transactions and PostgreSQL](transactions_indexes_postgresql.md) — data integrity

---

## Official documentation

- [Django: Models](https://docs.djangoproject.com/en/5.2/topics/db/models/) — full description
- [Django: Field types](https://docs.djangoproject.com/en/5.2/ref/models/fields/) — all field types with options
- [Django: Relationships](https://docs.djangoproject.com/en/5.2/topics/db/examples/) — examples of all relationships
- [Django: Meta options](https://docs.djangoproject.com/en/5.2/ref/models/options/) — ordering, constraints, indexes
