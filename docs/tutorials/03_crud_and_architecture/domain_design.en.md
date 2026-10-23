# Domain design

> **"Design before code."**
> Mistake #1 is starting with `class Note(models.Model)` and adding fields "on the fly".
> A month later, refactoring the schema = a complex migration that is hard to roll back in prod.
> **30 minutes of design = weeks of saved time.**

---

## The 7-step methodology

| # | Step | What you do | Example |
|---|------|----------|---------|
| **1** | **DOMAIN** | Describe in words what you are building | "A user has notebooks. Notebooks contain notes. Notes have tags and reminders." |
| **2** | **ENTITIES** | Find the nouns in the description | `User`, `Notebook`, `Note`, `Tag`, `Reminder`, `TodoList`, `ShoppingList` |
| **3** | **ATTRIBUTES** | What do we know about each entity? | `Note` → `title`, `content`, `priority`, `is_pinned`, `is_archived` |
| **4** | **RELATIONSHIPS** | How are the entities related? | `1:1` User↔Profile · `1:N` Notebook→Notes · `M:N` Note↔Tag |
| **5** | **NORMALIZATION** | Remove duplication | `author_name` in Note? — No, only an FK to User |
| **6** | **on_delete** | What happens when the parent is deleted? | CASCADE / SET_NULL / PROTECT |
| **7** | **DJANGO MODEL** | _Only now_ do we write `models.py` | ← A typical mistake: starting here |

> **Anti-pattern.** Starting with `class Note(models.Model)` and adding fields "on the fly".
> An ER diagram is a **contract** between you and the database. Break it in code — and you pay with a migration.

---

## Where the "truth" lives

**Normalization — every fact is stored in exactly one place.**

```
DOMAIN    → "A user writes notes" — business language
SCHEMA    → ER diagram — the structure of tables and relationships
CODE      → models.py — the Python representation of the schema
MIGRATIONS → Git commits for the DB schema
ADMIN     → feedback: you see the structure in the browser
```

```
❌ DENORMALIZED SCHEMA (duplication):
NOTE table:
  author_name VARCHAR(150)  ← duplicates the user's name!
  author_email VARCHAR(254) ← and the email too!

Problem:
  1. The user changes their name → all of their notes need an UPDATE
  2. Mismatch: note.author_name ≠ user.username → DATA INCONSISTENCY
  3. Deleting the user → orphan records without an author

✅ NORMALIZED SCHEMA:
NOTE table:
  user_id BIGINT FK → auth_user  ← one fact: this note belongs to the user with this id

The user's name? → note.user.username (JOIN)
The user's email? → note.user.email (JOIN)
One source of truth → no mismatches
```

---

## Step 0 — From domain to schema

> **Mental model:** Database design is not "which table should I add". It is **modeling the real world**. First you think in business language: "a user can have notebooks, each notebook contains notes, notes can have tags". Then you translate that into data structures. Django models are the last step, not the first.
>
> **Where mistakes begin:** Most DB schema problems arise because the developer starts writing code right away without thinking about relationships. A month later it turns out a new relationship is needed — and adding it without a massive migration is impossible.
>
> **Typical mistake:** Starting by writing the model. The correct order: **domain → entities → attributes → relationships → normalization → Django model**.

### The design process (the correct order)

```
1. DOMAIN — describe in words what we are building
   "A user has notebooks. Notebooks contain notes.
    Notes can be in to-do lists. There are reminders with a date."

2. ENTITIES — find the "nouns" in the domain description
   User, Notebook, Note, To-do list, List item,
   Reminder, Shopping list, Item, Tag

3. ATTRIBUTES — for each entity: what do we know about it?
   Note: title, content, created_at, is_pinned, priority

4. RELATIONSHIPS — how are the entities related to each other?
   Note → Notebook: many notes in one notebook (FK)
   Note ↔ Tag: one note, many tags; one tag, many notes (M:N)

5. NORMALIZATION — check: is there duplication?
   If Note has an author_name field — that duplicates User. Replace it with an FK.

6. CHOOSING on_delete — what happens when the parent record is deleted?
   Deleting a Notebook → delete all its notes (CASCADE)?
   Or keep the notes without a notebook (SET_NULL)?

7. DJANGO MODEL — only after all of the above
```

---

## Step 1 — Designing the domain

We are building a **personal notes manager** — like Notion or Evernote, but simplified.

### What our product should be able to do

| Feature | Description |
|---------|------|
| Notebooks | Collections of notes (like folders). Each note is in one notebook |
| Notes | Text records with a title, content, tags, priority |
| Tags | Labels for notes. One note = many tags. One tag = many notes |
| To-do lists | A to-do list. Each list has items with a checkbox |
| Shopping lists | A list of items with a quantity and whether it was bought |
| Reminders | Notifications tied to a note or a date |
| Pinning | Notes can be pinned to the top |
| Archive | Notes can be hidden without deleting them |

---

## Step 2 — Entities and relationships

### Analysis of relationships by type

```
ONE-TO-ONE (1:1) — "one has exactly one":
  User ←→ UserProfile
  (each user has one profile, one profile belongs to one user)

ONE-TO-MANY (1:N) — "one has many":
  User → Notebook          (one user, many notebooks)
  Notebook → Note          (one notebook, many notes)
  User → Note              (a note has an author)
  User → TodoList          (one user, many to-do lists)
  TodoList → TodoItem      (one list, many items)
  User → ShoppingList      (one user, many shopping lists)
  ShoppingList → ShopItem  (one list, many items)
  Note → Reminder          (one note can have several reminders)

MANY-TO-MANY (M:N) — "many related to many":
  Note ↔ Tag  (a note has tags, a tag is in many notes)
```

### Where the FK lives — the "Many side" rule

> **Why:** mistake #2 is putting the FK on the "One" side. For example, storing `note_ids` in `Notebook`. SQL does not support arrays in a column (1NF). The FK is always on the "Many" side.

```
Notebook → Note (1:N):

  notebooks:                   notes:
  ┌────┬──────────┐            ┌────┬─────────────┬─────────────┐
  │ id │ title    │            │ id │ title        │ notebook_id │  ← FK here
  ├────┼──────────┤            ├────┼─────────────┼─────────────┤
  │  1 │ Work     │◄───────────│  1 │ Django ORM   │      1      │
  │  2 │ Personal │◄───────────│  2 │ Python tips  │      1      │
  │    │          │◄───────────│  3 │ Soup recipe  │      2      │
  └────┴──────────┘            └────┴─────────────┴─────────────┘

Notebook does NOT store a list of notes.
Note stores a REFERENCE to its notebook (notebook_id=1).
```

---

## Step 3 — The full schema: 11 tables of the Notes Platform

```
schema_v1 · 11 tables · 1 junction table · postgres-ready
─────────────────────────────────────────────────────────

USER (auth_user)                    USER_PROFILE  ←── 1:1 OneToOne
┌──────────────┬─────────────┐      ┌────────────────┬──────────────────┐
│ id           │ bigint PK   │──┐   │ id             │ bigint PK        │
│ username     │ varchar(150)│  └──►│ user_id        │ bigint UNIQUE FK │
│ email        │ varchar(254)│      │ display_name   │ varchar(60)      │
│ password     │ varchar(128)│      │ timezone       │ varchar(40)      │
│ date_joined  │ timestamp   │      │ avatar_url     │ text             │
└──────────────┴─────────────┘      └────────────────┴──────────────────┘
       │ owns 1:N              │ writes 1:N          │ owns tags 1:N
       ▼                       ▼                     ▼
NOTEBOOK                      NOTE (central)        TAG
┌─────────────┬──────────┐    ┌───────────────┬──────────────────┐    ┌──────────┬───────────────────┐
│ id          │ bigint PK│    │ id            │ bigint PK        │    │ id       │ bigint PK         │
│ user_id     │ bigint FK│    │ user_id       │ bigint FK        │    │ user_id  │ bigint FK         │
│ title       │ varchar  │    │ notebook_id   │ bigint NULL FK   │    │ name     │ varchar(50)       │
│ color       │ varchar  │    │ title         │ varchar(200)     │    │ color    │ varchar(7)        │
│ is_default  │ boolean  │    │ content       │ text             │    └──────────┴───────────────────┘
└─────────────┴──────────┘    │ priority      │ smallint         │     unique_together(user_id, name)
       │ contains 1:N         │ is_pinned     │ boolean          │
       └─────────────────────►│ is_archived   │ boolean          │◄──── M:N via NOTE_TAGS
                              │ created_at    │ timestamp        │
                              │ updated_at    │ timestamp        │
                              │ views_count   │ integer          │
                              └───────────────┴──────────────────┘
                                     │ reminds 1:N
                                     ▼
                              REMINDER                              NOTE_TAGS (junction)
                              ┌────────────────┬──────────────┐     ┌──────────┬────────────┐
                              │ id             │ bigint PK    │     │ note_id  │ bigint FK  │
                              │ note_id        │ bigint FK    │     │ tag_id   │ bigint FK  │
                              │ remind_at      │ timestamp    │     └──────────┴────────────┘
                              │ is_sent        │ boolean      │     UNIQUE(note_id, tag_id)
                              │ repeat_pattern │ varchar(20)  │     Django creates it automatically
                              └────────────────┴──────────────┘

TODO_LIST                     TODO_ITEM
┌─────────────┬──────────┐    ┌────────────────┬──────────────┐
│ id          │ bigint PK│    │ id             │ bigint PK    │
│ user_id     │ bigint FK│───►│ todo_list_id   │ bigint FK    │
│ title       │ varchar  │    │ text           │ varchar(500) │
│ is_completed│ boolean  │    │ is_done        │ boolean      │
└─────────────┴──────────┘    │ order_position │ integer      │
                              │ due_date       │ date NULL    │
                              └────────────────┴──────────────┘

SHOPPING_LIST                 SHOP_ITEM
┌─────────────┬──────────┐    ┌──────────────────┬──────────────────┐
│ id          │ bigint PK│    │ id               │ bigint PK        │
│ user_id     │ bigint FK│───►│ shopping_list_id │ bigint FK        │
│ title       │ varchar  │    │ name             │ varchar(120)     │
│ store_name  │ varchar  │    │ quantity         │ decimal(8,2)     │
└─────────────┴──────────┘    │ unit             │ varchar(5)       │
                              │ is_purchased     │ boolean          │
                              │ estimated_price  │ decimal(10,2)    │
                              └──────────────────┴──────────────────┘
                              ⚠️ DecimalField for money — not FloatField!
```

---

## Step 4 — Relationship types with code

### 1:1 — OneToOneField

> **Why:** We extend the built-in `User` without touching its code. All non-standard fields go into `UserProfile`. This is vertical partitioning: 5 basic fields in User, 20 optional ones in Profile.

```python
class UserProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,   # a profile without a user is meaningless → CASCADE
        related_name='profile',     # user.profile — access from User
    )
    display_name = models.CharField(max_length=60, blank=True)
    timezone     = models.CharField(max_length=40, default='UTC')
    avatar_url   = models.URLField(blank=True)

    def __str__(self):
        return f'Profile({self.user.username})'
```

**The SQL Django generates:**
```sql
CREATE TABLE "notes_app_userprofile" (
    "id"           bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "user_id"      bigint NOT NULL UNIQUE REFERENCES "auth_user" ("id") ON DELETE CASCADE,
    "display_name" varchar(60) NOT NULL DEFAULT '',
    "timezone"     varchar(40) NOT NULL DEFAULT 'UTC',
    "avatar_url"   varchar(200) NOT NULL DEFAULT ''
);
```

The key word here is `UNIQUE`. That is what distinguishes 1:1 from 1:N. Without `UNIQUE` one user could have several profiles.

**Access:**
```python
user = User.objects.get(username='alice')
user.profile              # → UserProfile (not a QuerySet! UNIQUE FK → a single object)
user.profile.timezone     # → 'Europe/Kyiv'
user.profile.display_name # → 'Alice'
```

---

### 1:N — ForeignKey

> **Why:** One notebook contains many notes. The FK is always placed on the "Many" side — in `Note`, not in `Notebook`. Notebook cannot store a list of `note_ids` — an SQL column holds a single value, not an array.

```python
class Notebook(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='notebooks')
    title      = models.CharField(max_length=100)
    color      = models.CharField(max_length=7, default='#6c757d')  # HEX color
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.title
```

```python
class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    'Низький'),
        (PRIORITY_MEDIUM, 'Середній'),
        (PRIORITY_HIGH,   'Високий'),
    ]

    user     = models.ForeignKey(User, on_delete=models.CASCADE,
                                 related_name='notes')
    notebook = models.ForeignKey(
        Notebook,
        on_delete=models.SET_NULL,  # deleting the notebook → the note lives on
        null=True, blank=True,      # null=True is required when on_delete=SET_NULL
        related_name='notes',
    )
    tags = models.ManyToManyField('Tag', blank=True)  # M:N — a separate junction table

    title       = models.CharField(max_length=200)
    content     = models.TextField(blank=True)
    priority    = models.PositiveSmallIntegerField(
        choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM
    )
    is_pinned   = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)  # set once on CREATE
    updated_at  = models.DateTimeField(auto_now=True)      # updated on every SAVE
    views_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-is_pinned', '-updated_at']  # pinned on top, then by date

    def __str__(self):
        return self.title
```

**Why is `notebook` `SET_NULL` and not `CASCADE`?**

A business decision: when a user deletes the "Work" (`Робота`) notebook, its notes should not disappear — they move to the "no notebook" state. `CASCADE` would mean losing all the notes together with the notebook.

**Access:**
```python
notebook = Notebook.objects.get(title='Робота')
notebook.notes.all()        # → QuerySet[Note] (reverse access via related_name)
notebook.notes.count()      # → 5

note = Note.objects.get(pk=1)
note.notebook               # → Notebook or None (after SET_NULL)
note.notebook.title         # → 'Робота'
note.user.username          # → 'alice'
```

---

### M:N — ManyToManyField

> **Why:** One note can have several tags. One tag can be in several notes. This is an M:N relationship. SQL implements it via a separate junction table — Django creates it automatically.

```python
class Tag(models.Model):
    user  = models.ForeignKey(User, on_delete=models.CASCADE,
                               related_name='tags')
    name  = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#6c757d')

    class Meta:
        unique_together = [('user', 'name')]
        # Alice and Bob can both have a 'python' tag — the constraint is on (user_id, name)

    def __str__(self):
        return self.name
```

Django automatically creates the junction table `notes_app_note_tags`:

```sql
CREATE TABLE "notes_app_note_tags" (
    "id"      bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "note_id" bigint NOT NULL REFERENCES "notes_app_note" ("id") ON DELETE CASCADE,
    "tag_id"  bigint NOT NULL REFERENCES "notes_app_tag" ("id") ON DELETE CASCADE,
    UNIQUE ("note_id", "tag_id")
);
```

**Access:**
```python
note = Note.objects.get(pk=1)
note.tags.all()                      # → QuerySet[Tag]
note.tags.add(tag_py, tag_django)    # INSERT × 2 into the junction table
note.tags.remove(tag_py)             # DELETE from the junction table
note.tags.set([tag_django])          # synchronize — remove extras, add new ones

# Reverse access:
tag = Tag.objects.get(name='python')
tag.note_set.all()                   # → QuerySet[Note] that have this tag
# or via related_name if you set one:
# tags = models.ManyToManyField('Tag', blank=True, related_name='notes')
# tag.notes.all()
```

---

## Step 5 — The on_delete matrix

> **Why:** `on_delete` is not a technical decision but a **business decision**. What happens to the data when a related object is deleted? The wrong choice = data loss or orphan records.

| Strategy | What it does | When to choose it | Example |
|-----------|-----------|---------------|---------|
| `CASCADE` | Delete the children automatically | A note without an author is meaningless | `Reminder → Note` |
| `SET_NULL` | FK → NULL, the children live on | A note can exist without a notebook | `Note.notebook → Notebook` |
| `SET_DEFAULT` | FK → the `default` value | Move to the "default" one | `Note → DefaultNotebook` |
| `PROTECT` | `ProtectedError`, forbidden | Prevent deletion if there are dependents | Not built into our project |
| `RESTRICT` | Forbid, but with nuances | Complex domains | Rarely |
| `DO_NOTHING` | The DB decides by itself → orphans | Almost never | Dangerous |

**Notes Platform — the decision table:**

| Relationship | on_delete | Rationale |
|---------|-----------|--------------|
| `UserProfile.user` | `CASCADE` | A profile without a user makes no sense |
| `Notebook.user` | `CASCADE` | Notebooks belong to the user; deleting the user = deleting everything |
| `Note.user` | `CASCADE` | Notes without an author are meaningless |
| `Note.notebook` | `SET_NULL` | A note can exist without a notebook (it moves to "no folder") |
| `Tag.user` | `CASCADE` | Tags are tied to the user |
| `Reminder.note` | `CASCADE` | A reminder without a note is meaningless |
| `TodoItem.todo_list` | `CASCADE` | An item without a list is not needed |
| `ShopItem.shopping_list` | `CASCADE` | A product without a list is not needed |

---

## Step 6 — The full models.py code

> **Why:** Only after the design is finished (steps 1-5) do we write code. Every decision above is reflected in one line of `models.py`.

```python
# notes_app/models.py
from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    user         = models.OneToOneField(User, on_delete=models.CASCADE,
                                        related_name='profile')
    display_name = models.CharField(max_length=60, blank=True)
    timezone     = models.CharField(max_length=40, default='UTC')
    avatar_url   = models.URLField(blank=True)

    def __str__(self):
        return f'Profile({self.user.username})'


class Tag(models.Model):
    user  = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tags')
    name  = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#6c757d')

    class Meta:
        unique_together = [('user', 'name')]

    def __str__(self):
        return self.name


class Notebook(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='notebooks')
    title      = models.CharField(max_length=100)
    color      = models.CharField(max_length=7, default='#6c757d')
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.title


class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    'Низький'),
        (PRIORITY_MEDIUM, 'Середній'),
        (PRIORITY_HIGH,   'Високий'),
    ]

    user     = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    notebook = models.ForeignKey(
        Notebook, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='notes',
    )
    tags = models.ManyToManyField(Tag, blank=True)

    title       = models.CharField(max_length=200)
    content     = models.TextField(blank=True)
    priority    = models.PositiveSmallIntegerField(
        choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM,
    )
    is_pinned   = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)
    views_count = models.PositiveIntegerField(default=0)
    group       = models.ForeignKey(
        'auth.Group', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='notes',
    )

    class Meta:
        ordering = ['-is_pinned', '-updated_at']

    def __str__(self):
        return self.title


class Reminder(models.Model):
    REPEAT_CHOICES = [
        ('none',    'Одноразово'),
        ('daily',   'Щодня'),
        ('weekly',  'Щотижня'),
        ('monthly', 'Щомісяця'),
    ]

    note           = models.ForeignKey(Note, on_delete=models.CASCADE,
                                       related_name='reminders')
    remind_at      = models.DateTimeField()
    message        = models.TextField(blank=True)
    is_sent        = models.BooleanField(default=False)
    repeat_pattern = models.CharField(
        max_length=20, choices=REPEAT_CHOICES, default='none',
    )

    class Meta:
        ordering = ['remind_at']

    def __str__(self):
        return f'Reminder({self.note.title}, {self.remind_at})'


class TodoList(models.Model):
    user         = models.ForeignKey(User, on_delete=models.CASCADE,
                                     related_name='todo_lists')
    title        = models.CharField(max_length=100)
    is_completed = models.BooleanField(default=False)

    def __str__(self):
        return self.title


class TodoItem(models.Model):
    todo_list      = models.ForeignKey(TodoList, on_delete=models.CASCADE,
                                       related_name='items')
    text           = models.CharField(max_length=500)
    is_done        = models.BooleanField(default=False)
    order_position = models.PositiveIntegerField(default=0)
    due_date       = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['order_position']

    def __str__(self):
        return self.text


class ShoppingList(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='shopping_lists')
    title      = models.CharField(max_length=100)
    store_name = models.CharField(max_length=100, blank=True)
    group      = models.ForeignKey(
        'auth.Group', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='shopping_lists',
    )

    def __str__(self):
        return self.title


class ShopItem(models.Model):
    UNIT_PIECE  = 'шт'
    UNIT_KG     = 'кг'
    UNIT_LITER  = 'л'
    UNIT_GRAM   = 'г'
    UNIT_CHOICES = [
        (UNIT_PIECE, 'Штуки'),
        (UNIT_KG,    'Кілограми'),
        (UNIT_LITER, 'Літри'),
        (UNIT_GRAM,  'Грами'),
    ]

    shopping_list   = models.ForeignKey(ShoppingList, on_delete=models.CASCADE,
                                        related_name='items')
    name            = models.CharField(max_length=120)
    quantity        = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit            = models.CharField(max_length=5, choices=UNIT_CHOICES,
                                       default=UNIT_PIECE)
    is_purchased    = models.BooleanField(default=False)
    estimated_price = models.DecimalField(max_digits=10, decimal_places=2,
                                          null=True, blank=True)

    def __str__(self):
        return self.name
```

**Why `DecimalField` and not `FloatField` for prices and quantities?**

```python
# FloatField — IEEE 754 binary floating point
0.1 + 0.2  # → 0.30000000000000004  ← CPU rounding

# DecimalField — decimal arithmetic (Python Decimal)
Decimal('0.1') + Decimal('0.2')  # → Decimal('0.3')  ← exact
```

Money is always `DecimalField`. `FloatField` leads to penny-level discrepancies in calculations.

---

## Step 7 — Checking in the Django shell

> **Why:** Before writing views and templates, we check through the shell that the models and relationships work correctly. It is the fastest way to catch design mistakes.

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.models import (
    UserProfile, Tag, Notebook, Note, Reminder,
    TodoList, TodoItem, ShoppingList, ShopItem
)

# --- 1:1 OneToOneField ---
user = User.objects.create_user('alice', 'alice@test.com', 'pass123')
profile = UserProfile.objects.create(user=user, display_name='Alice', timezone='Europe/Kyiv')

print(user.profile)            # → Profile(alice)
print(user.profile.timezone)   # → Europe/Kyiv

# --- 1:N ForeignKey ---
notebook = Notebook.objects.create(user=user, title='Робота', is_default=True)
tag_py = Tag.objects.create(user=user, name='python', color='#3776AB')
tag_dj = Tag.objects.create(user=user, name='django', color='#092E20')

note = Note.objects.create(
    user=user, notebook=notebook,
    title='Django ORM', content='QuerySet — лінива оцінка.',
    priority=Note.PRIORITY_HIGH, is_pinned=True,
)

# Reverse access via related_name:
print(notebook.notes.count())  # → 1
print(notebook.notes.all())    # → <QuerySet [<Note: Django ORM>]>

# --- M:N ManyToManyField ---
note.tags.add(tag_py, tag_dj)                         # INSERT × 2 into the junction table
print(note.tags.all())                                 # → <QuerySet [<Tag: python>, <Tag: django>]>
print(note.tags.count())                               # → 2

# The reverse side of M:N:
print(tag_py.note_set.all())                           # → <QuerySet [<Note: Django ORM>]>

# --- Reminder (CASCADE from Note) ---
reminder = Reminder.objects.create(
    note=note,
    remind_at='2026-06-20 09:00:00+00:00',
    message='Завершити розділ про ORM',
)
print(note.reminders.count())   # → 1

# --- TodoList ---
todo = TodoList.objects.create(user=user, title='Вивчити ORM')
TodoItem.objects.bulk_create([
    TodoItem(todo_list=todo, text='Прочитати docs', order_position=1),
    TodoItem(todo_list=todo, text='Зробити shell-демо', order_position=2),
    TodoItem(todo_list=todo, text='Написати тести', order_position=3),
])
print(todo.items.count())       # → 3

# Checking CASCADE: deleting a note → deleting its reminders
note_id = note.pk
note.delete()
print(Reminder.objects.filter(pk=reminder.pk).exists())  # → False (CASCADE worked)

# Checking SET_NULL: deleting a notebook → notebook_id in its notes becomes NULL
note2 = Note.objects.create(user=user, notebook=notebook, title='Нотатка 2', content='')
notebook.delete()
note2.refresh_from_db()
print(note2.notebook)  # → None (SET_NULL worked)
```

---

## In the book

- [Part III. Database and ORM](../../03_database_and_orm/README.md) — the N+1 problem, `select_related`, `prefetch_related`, the QuerySet API, `transaction.atomic`, indexes
- [Part VI. Application architecture](../../06_application_architecture/README.md) — the selectors/services pattern, thin views, a CQRS-light approach

---

## Official documentation

- [Django: Models](https://docs.djangoproject.com/en/5.2/topics/db/models/) — fields, relationships, Meta
- [Django: ForeignKey](https://docs.djangoproject.com/en/5.2/ref/models/fields/#django.db.models.ForeignKey) — on_delete options
- [Django: OneToOneField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#onetoonefield)
- [Django: ManyToManyField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#manytomanyfield)
- [Django: DecimalField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#decimalfield) — why not FloatField for money
- [Django: Making queries](https://docs.djangoproject.com/en/5.2/topics/db/queries/) — add, set, remove for M:N
