# Django моделі

> Після проектування домену (Крок 0–3) настає час писати код.
> `models.py` — це **Python-представлення ER-схеми**, яку ти вже намалював.

---

## Крок 4 — Пишемо Django моделі

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
    color = models.CharField(max_length=7, default='#6c757d')  # Hex колір

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

!!! note "PRIORITY_CHOICES у notes_chat_app"
    Ця модель використовує 3 рівні (1–3) для навчального проєкту.
    **`notes_chat_app`** (фінальний проєкт) має **4 рівні**: `PRIORITY_URGENT = 4` («Терміново»),
    `PositiveSmallIntegerField` замість `SmallIntegerField`, та `MaxValueValidator(4)`.
    Крім того, `notes_chat_app.Note` має поле `group = ForeignKey(Group)` для групового sharing
    (додається у Кроці 5 — Автентифікація та безпека).

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
    UNIT_PACK   = 'уп'
    UNIT_CHOICES = [
        (UNIT_PIECE, 'Штука'),
        (UNIT_KG,    'Кілограм'),
        (UNIT_LITER, 'Літр'),
        (UNIT_PACK,  'Упаковка'),
    ]

    shopping_list   = models.ForeignKey(ShoppingList, on_delete=models.CASCADE, related_name='items')
    name            = models.CharField(max_length=120)
    quantity        = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit            = models.CharField(max_length=20, choices=UNIT_CHOICES, default=UNIT_PIECE)
    is_purchased    = models.BooleanField(default=False)
    estimated_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    # DecimalField для грошей і кількості! FloatField → 0.1+0.2 = 0.30000000000000004

    def __str__(self):
        return f'{self.name} ({self.quantity} {self.unit})'
```

---

## Огляд зв'язків

```python
# Три типи зв'язків в одній моделі Note:
class Note(models.Model):
    user     = models.ForeignKey(User, on_delete=CASCADE, related_name='notes')
    # user: FK (обов'язковий, CASCADE)

    notebook = models.ForeignKey(Notebook, on_delete=SET_NULL, null=True, blank=True)
    # notebook: FK (необов'язковий, SET_NULL — нотатка може існувати без записника)

    tags = models.ManyToManyField(Tag, blank=True)
    # tags: M:N (Django автоматично створює junction table)
```

---

## ORM QuerySet API

### QuerySet — ліниві об'єкти

```python
# QuerySet LAZY: SQL не виконується поки не потрібні дані
qs = Note.objects.filter(user=alice)   # ← НІЧОГО не відбулось у БД!
qs = qs.filter(is_pinned=True)         # ← Тільки уточнення запиту
qs = qs.order_by('-priority')          # ← Все ще нічого у БД

# SQL ВИКОНУЄТЬСЯ тут — коли ітеруємо, рахуємо, конвертуємо:
notes = list(qs)           # ← SELECT NOW!
count = qs.count()         # ← SELECT COUNT(*)
first = qs.first()         # ← SELECT ... LIMIT 1
exists = qs.exists()       # ← SELECT 1 ... LIMIT 1 (дуже швидко)
for note in qs: ...        # ← SELECT і ітерація
note = qs.get(pk=1)        # ← SELECT WHERE pk=1

# ПЕРЕВАГА LAZY:
# Можна передати QuerySet у шаблон → SQL виконається тільки при рендерингу
# Можна chain фільтри: qs.filter(A).filter(B) = одне SELECT з двома WHERE
```

### Фільтрація — lookups

```python
# Точна рівність:
Note.objects.filter(priority=3)
# SQL: WHERE priority = 3

# Порівняння:
Note.objects.filter(priority__gt=1)    # greater than → > 1
Note.objects.filter(priority__gte=2)   # greater or equal → >= 2
Note.objects.filter(priority__lt=3)    # less than → < 3
Note.objects.filter(priority__lte=2)   # less or equal → <= 2

# Рядки:
Note.objects.filter(title__exact='Test')          # = 'Test' (case-sensitive)
Note.objects.filter(title__iexact='test')          # = 'test' (case-insensitive)
Note.objects.filter(title__contains='Django')      # LIKE '%Django%'
Note.objects.filter(title__icontains='django')     # ILIKE '%django%'
Note.objects.filter(title__startswith='Hello')     # LIKE 'Hello%'
Note.objects.filter(title__endswith='.md')         # LIKE '%.md'

# NULL:
Note.objects.filter(notebook__isnull=True)         # IS NULL
Note.objects.filter(notebook__isnull=False)        # IS NOT NULL

# Списки:
Note.objects.filter(priority__in=[1, 2])           # IN (1, 2)
Note.objects.exclude(priority__in=[3, 4])          # NOT IN (3, 4)

# Дати:
Note.objects.filter(created_at__year=2026)
Note.objects.filter(created_at__date=date(2026, 6, 13))
Note.objects.filter(created_at__gte=datetime(2026, 1, 1))

# FK:
Note.objects.filter(notebook=my_notebook)          # WHERE notebook_id = X
Note.objects.filter(notebook__title='Work')        # JOIN: WHERE notebook.title = 'Work'
Note.objects.filter(notebook__user=request.user)   # 2 JOIN рівні

# M:N:
Note.objects.filter(tags=tag_python)               # нотатки з тегом python
Note.objects.filter(tags__name='python')           # JOIN на Tag
Note.objects.filter(tags__name__icontains='py')    # JOIN + LIKE
```

### Q об'єкти — складні умови

```python
from django.db.models import Q

# OR умова:
Note.objects.filter(Q(title__icontains='django') | Q(content__icontains='django'))
# SQL: WHERE (title ILIKE '%django%' OR content ILIKE '%django%')

# AND (за замовчуванням кілька filter = AND):
Note.objects.filter(Q(is_pinned=True) & Q(priority=3))
# SQL: WHERE is_pinned = TRUE AND priority = 3

# NOT:
Note.objects.filter(~Q(is_archived=True))
# SQL: WHERE NOT is_archived = TRUE  (= WHERE is_archived = FALSE)

# Комбінування:
Note.objects.filter(
    Q(user=alice) | Q(group__in=alice_groups)
).filter(
    is_archived=False
)
# SQL: WHERE (user_id = 1 OR group_id IN (...)) AND is_archived = FALSE
```

### Анотації і агрегати

```python
from django.db.models import Count, Avg, Max, Min, Sum, F

# Count — кількість пов'язаних об'єктів
Notebook.objects.annotate(note_count=Count('notes'))
# SQL: SELECT *, COUNT(notes.id) AS note_count FROM notebooks LEFT JOIN notes ...
# notebook.note_count доступний на кожному об'єкті

# Фільтрований Count
Notebook.objects.annotate(
    active_count=Count('notes', filter=Q(notes__is_archived=False))
)

# Aggregate — одне значення на весь QuerySet
Note.objects.aggregate(avg_priority=Avg('priority'))
# → {'avg_priority': 1.8}

Note.objects.filter(user=alice).aggregate(
    total=Count('id'),
    pinned=Count('id', filter=Q(is_pinned=True)),
    max_priority=Max('priority'),
)
# → {'total': 42, 'pinned': 5, 'max_priority': 3}

# F об'єкти — посилання на поле у SQL (без завантаження в Python)
Note.objects.filter(views_count__gt=F('priority') * 100)
# SQL: WHERE views_count > priority * 100
# Без F: треба завантажити всі об'єкти в Python і фільтрувати в циклі!

# update з F():
Note.objects.all().update(views_count=F('views_count') + 1)
# SQL: UPDATE ... SET views_count = views_count + 1
# Атомарна операція! Без race condition.
```

### values() і values_list()

```python
# Повертає словники замість об'єктів (швидше при великих QuerySets)
Note.objects.values('title', 'priority')
# → [{'title': 'Test', 'priority': 1}, ...]

# Повертає кортежі (ще швидше)
Note.objects.values_list('title', 'priority')
# → [('Test', 1), ('Django', 2), ...]

# flat=True: одна колонка → плоский список
Note.objects.values_list('id', flat=True)
# → [1, 2, 3, 4, ...]

# Зберегти всі id у список:
note_ids = list(Note.objects.filter(user=alice).values_list('id', flat=True))
```

### order_by, distinct, only, defer

```python
# Сортування:
Note.objects.order_by('priority')           # ASC
Note.objects.order_by('-priority')          # DESC
Note.objects.order_by('-is_pinned', '-priority', '-updated_at')  # Множинне

# Прибрати дублікати (при JOIN):
Note.objects.filter(tags__name='python').distinct()

# Завантажити тільки певні поля (оптимізація):
Note.objects.only('id', 'title', 'priority')   # Інші поля → додатковий SELECT при доступі
Note.objects.defer('content')                   # Всі поля КРІМ content

# Обмеження (LIMIT / OFFSET):
Note.objects.all()[:10]                        # LIMIT 10
Note.objects.all()[10:20]                      # LIMIT 10 OFFSET 10
Note.objects.all()[0]                          # LIMIT 1 (= .first() але не None)
```

---

## Навігація

- Попередня: [ER-діаграми](er_diagrams.md)
- Наступна: [Міграції](migrations.md)
