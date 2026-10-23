# Django models

> After designing the domain (Steps 0–3), it is time to write code.
> `models.py` is the **Python representation of the ER schema** you have already drawn.

---

## Step 4 — Writing Django models

`hello_app/models.py`:

```python
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


class UserProfile(models.Model):
    user         = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    display_name = models.CharField(max_length=60, blank=True)
    timezone     = models.CharField(max_length=40, default='UTC')
    avatar_url   = models.URLField(blank=True)

    def __str__(self):
        return f'Profile({self.user.username})'


class Tag(models.Model):
    user  = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tags')
    name  = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#6c757d')  # Hex color

    class Meta:
        ordering    = ['name']
        constraints = [
            models.UniqueConstraint(fields=['user', 'name'], name='unique_user_tag'),
        ]

    def __str__(self):
        return f'#{self.name}'


class Notebook(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notebooks')
    title      = models.CharField(max_length=100)
    color      = models.CharField(max_length=7, default='#6c757d')
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_default', 'title']

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
        Notebook, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='notes',
    )
    tags = models.ManyToManyField(Tag, blank=True)

    title       = models.CharField(max_length=200)
    content     = models.TextField(blank=True)
    priority    = models.SmallIntegerField(
        choices=PRIORITY_CHOICES, default=PRIORITY_LOW,
        validators=[MinValueValidator(1), MaxValueValidator(3)],
    )
    is_pinned   = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)
    views_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-is_pinned', '-priority', '-updated_at']

    def __str__(self):
        return f'📌 {self.title}' if self.is_pinned else self.title
```

!!! note "PRIORITY_CHOICES in notes_chat_app"
    This model uses 3 levels (1–3) for the learning project.
    **`notes_chat_app`** (the final project) has **4 levels**: `PRIORITY_URGENT = 4` («Терміново», "Urgent"),
    `PositiveSmallIntegerField` instead of `SmallIntegerField`, and `MaxValueValidator(4)`.
    In addition, `notes_chat_app.Note` has a `group = ForeignKey(Group)` field for group sharing
    (added in Step 5 — Authentication and security).

```python
class Reminder(models.Model):
    note      = models.ForeignKey(Note, on_delete=models.CASCADE, related_name='reminders')
    remind_at = models.DateTimeField()
    is_sent   = models.BooleanField(default=False)

    class Meta:
        ordering = ['remind_at']

    def __str__(self):
        return f'Reminder({self.note.title}, {self.remind_at})'


class TodoList(models.Model):
    user         = models.ForeignKey(User, on_delete=models.CASCADE, related_name='todo_lists')
    title        = models.CharField(max_length=100)
    is_completed = models.BooleanField(default=False)
    created_at   = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class TodoItem(models.Model):
    todo_list      = models.ForeignKey(TodoList, on_delete=models.CASCADE, related_name='items')
    text           = models.CharField(max_length=500)
    is_done        = models.BooleanField(default=False)
    order_position = models.PositiveIntegerField(default=0)
    due_date       = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['order_position']

    def __str__(self):
        return self.text


class ShoppingList(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shopping_lists')
    title      = models.CharField(max_length=100)
    store_name = models.CharField(max_length=100, blank=True)

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

    shopping_list   = models.ForeignKey(ShoppingList, on_delete=models.CASCADE, related_name='items')
    name            = models.CharField(max_length=120)
    quantity        = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit            = models.CharField(max_length=5, choices=UNIT_CHOICES, default=UNIT_PIECE)
    is_purchased    = models.BooleanField(default=False)
    estimated_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    # DecimalField for money and quantities! FloatField → 0.1+0.2 = 0.30000000000000004

    def __str__(self):
        return f'{self.name} ({self.quantity} {self.unit})'
```

---

## Overview of relationships

```python
# Three relationship types in a single Note model:
class Note(models.Model):
    user     = models.ForeignKey(User, on_delete=CASCADE, related_name='notes')
    # user: FK (required, CASCADE)

    notebook = models.ForeignKey(Notebook, on_delete=SET_NULL, null=True, blank=True)
    # notebook: FK (optional, SET_NULL — a note can exist without a notebook)

    tags = models.ManyToManyField(Tag, blank=True)
    # tags: M:N (Django creates the junction table automatically)
```

---

## ORM QuerySet API

### QuerySet — lazy objects

```python
# QuerySet is LAZY: SQL is not executed until the data is needed
qs = Note.objects.filter(user=alice)   # ← NOTHING happened in the DB!
qs = qs.filter(is_pinned=True)         # ← Only refining the query
qs = qs.order_by('-priority')          # ← Still nothing in the DB

# SQL IS EXECUTED here — when we iterate, count, convert:
notes = list(qs)           # ← SELECT NOW!
count = qs.count()         # ← SELECT COUNT(*)
first = qs.first()         # ← SELECT ... LIMIT 1
exists = qs.exists()       # ← SELECT 1 ... LIMIT 1 (very fast)
for note in qs: ...        # ← SELECT and iteration
note = qs.get(pk=1)        # ← SELECT WHERE pk=1

# ADVANTAGE OF LAZINESS:
# You can pass a QuerySet to a template → SQL runs only during rendering
# You can chain filters: qs.filter(A).filter(B) = one SELECT with two WHERE conditions
```

### Filtering — lookups

```python
# Exact equality:
Note.objects.filter(priority=3)
# SQL: WHERE priority = 3

# Comparison:
Note.objects.filter(priority__gt=1)    # greater than → > 1
Note.objects.filter(priority__gte=2)   # greater or equal → >= 2
Note.objects.filter(priority__lt=3)    # less than → < 3
Note.objects.filter(priority__lte=2)   # less or equal → <= 2

# Strings:
Note.objects.filter(title__exact='Test')          # = 'Test' (case-sensitive)
Note.objects.filter(title__iexact='test')          # = 'test' (case-insensitive)
Note.objects.filter(title__contains='Django')      # LIKE '%Django%'
Note.objects.filter(title__icontains='django')     # ILIKE '%django%'
Note.objects.filter(title__startswith='Hello')     # LIKE 'Hello%'
Note.objects.filter(title__endswith='.md')         # LIKE '%.md'

# NULL:
Note.objects.filter(notebook__isnull=True)         # IS NULL
Note.objects.filter(notebook__isnull=False)        # IS NOT NULL

# Lists:
Note.objects.filter(priority__in=[1, 2])           # IN (1, 2)
Note.objects.exclude(priority__in=[3, 4])          # NOT IN (3, 4)

# Dates:
Note.objects.filter(created_at__year=2026)
Note.objects.filter(created_at__date=date(2026, 6, 13))
Note.objects.filter(created_at__gte=datetime(2026, 1, 1))

# FK:
Note.objects.filter(notebook=my_notebook)          # WHERE notebook_id = X
Note.objects.filter(notebook__title='Work')        # JOIN: WHERE notebook.title = 'Work'
Note.objects.filter(notebook__user=request.user)   # 2 JOIN levels

# M:N:
Note.objects.filter(tags=tag_python)               # notes with the python tag
Note.objects.filter(tags__name='python')           # JOIN on Tag
Note.objects.filter(tags__name__icontains='py')    # JOIN + LIKE
```

### Q objects — complex conditions

```python
from django.db.models import Q

# OR condition:
Note.objects.filter(Q(title__icontains='django') | Q(content__icontains='django'))
# SQL: WHERE (title ILIKE '%django%' OR content ILIKE '%django%')

# AND (by default, multiple filters = AND):
Note.objects.filter(Q(is_pinned=True) & Q(priority=3))
# SQL: WHERE is_pinned = TRUE AND priority = 3

# NOT:
Note.objects.filter(~Q(is_archived=True))
# SQL: WHERE NOT is_archived = TRUE  (= WHERE is_archived = FALSE)

# Combining:
Note.objects.filter(
    Q(user=alice) | Q(group__in=alice_groups)
).filter(
    is_archived=False
)
# SQL: WHERE (user_id = 1 OR group_id IN (...)) AND is_archived = FALSE
```

### Annotations and aggregates

```python
from django.db.models import Count, Avg, Max, Min, Sum, F

# Count — number of related objects
Notebook.objects.annotate(note_count=Count('notes'))
# SQL: SELECT *, COUNT(notes.id) AS note_count FROM notebooks LEFT JOIN notes ...
# notebook.note_count is available on every object

# Filtered Count
Notebook.objects.annotate(
    active_count=Count('notes', filter=Q(notes__is_archived=False))
)

# Aggregate — a single value for the whole QuerySet
Note.objects.aggregate(avg_priority=Avg('priority'))
# → {'avg_priority': 1.8}

Note.objects.filter(user=alice).aggregate(
    total=Count('id'),
    pinned=Count('id', filter=Q(is_pinned=True)),
    max_priority=Max('priority'),
)
# → {'total': 42, 'pinned': 5, 'max_priority': 3}

# F objects — a reference to a field in SQL (without loading into Python)
Note.objects.filter(views_count__gt=F('priority') * 100)
# SQL: WHERE views_count > priority * 100
# Without F: you would have to load all objects into Python and filter in a loop!

# update with F():
Note.objects.all().update(views_count=F('views_count') + 1)
# SQL: UPDATE ... SET views_count = views_count + 1
# An atomic operation! No race condition.
```

### values() and values_list()

```python
# Returns dictionaries instead of objects (faster for large QuerySets)
Note.objects.values('title', 'priority')
# → [{'title': 'Test', 'priority': 1}, ...]

# Returns tuples (even faster)
Note.objects.values_list('title', 'priority')
# → [('Test', 1), ('Django', 2), ...]

# flat=True: one column → a flat list
Note.objects.values_list('id', flat=True)
# → [1, 2, 3, 4, ...]

# Save all ids into a list:
note_ids = list(Note.objects.filter(user=alice).values_list('id', flat=True))
```

### order_by, distinct, only, defer

```python
# Ordering:
Note.objects.order_by('priority')           # ASC
Note.objects.order_by('-priority')          # DESC
Note.objects.order_by('-is_pinned', '-priority', '-updated_at')  # Multiple

# Remove duplicates (with JOIN):
Note.objects.filter(tags__name='python').distinct()

# Load only certain fields (optimization):
Note.objects.only('id', 'title', 'priority')   # Other fields → an extra SELECT on access
Note.objects.defer('content')                   # All fields EXCEPT content

# Limiting (LIMIT / OFFSET):
Note.objects.all()[:10]                        # LIMIT 10
Note.objects.all()[10:20]                      # LIMIT 10 OFFSET 10
Note.objects.all()[0]                          # LIMIT 1 (= .first() but not None)
```

---

## Navigation

- Previous: [ER diagrams](er_diagrams.md)
- Next: [Migrations](migrations.md)
