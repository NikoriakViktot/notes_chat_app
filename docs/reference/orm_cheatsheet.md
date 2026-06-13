# ORM Cheatsheet — Django QuerySet API

> Швидка довідка по всіх основних операціях Django ORM.
> Приклади адаптовані для `notes_chat_app` (моделі: `Note`, `Notebook`, `Tag`, `User`).

---

## Зміст

- [Базові CRUD](#базові-crud)
- [Фільтрація — filter / exclude](#фільтрація)
- [Lookup Types — подвійне підкреслення](#lookup-types)
- [Q об'єкти — OR / NOT умови](#q-обєкти)
- [F об'єкти — поля у виразах](#f-обєкти)
- [Агрегація та анотація](#агрегація-та-анотація)
- [select_related та prefetch_related](#select_related-та-prefetch_related)
- [values / values_list](#values--values_list)
- [order_by / distinct / only / defer](#order_by--distinct--only--defer)
- [Оновлення та видалення](#оновлення-та-видалення)
- [ManyToMany операції](#manytomany)
- [Ланцюгування та lazy evaluation](#ланцюгування)
- [get_object_or_404 та get_or_create](#get_object_or_404-та-get_or_create)
- [Транзакції](#транзакції)
- [Raw SQL (коли ORM не вистачає)](#raw-sql)

---

## Базові CRUD

### CREATE

```python
# objects.create() — INSERT + повертає об'єкт
note = Note.objects.create(user=alice, title='Test', priority=2)

# Або: __init__ + save()
note = Note(user=alice, title='Test', priority=2)
note.save()   # INSERT INTO hello_app_note ...

# bulk_create — вставити кілька рядків одним запитом
Note.objects.bulk_create([
    Note(user=alice, title='Note 1'),
    Note(user=alice, title='Note 2'),
    Note(user=alice, title='Note 3'),
])
# SQL: INSERT INTO hello_app_note (...) VALUES (...), (...), (...)
# УВАГА: не викликає .save() і не спрацьовують pre_save/post_save сигнали

# get_or_create — знайти або створити
tag, created = Tag.objects.get_or_create(
    user=alice, name='python',
    defaults={'color': '#3776AB'}
)
# created=True  → тег створено (не існував)
# created=False → тег знайдено (вже існував)
```

### READ

```python
# all() — всі записи (lazy!)
notes = Note.objects.all()
# SQL виконається тільки при ітерації/list()/count() тощо

# get() — рівно один об'єкт або виняток
note = Note.objects.get(pk=1)
# DoesNotExist  якщо не знайдено
# MultipleObjectsReturned  якщо знайдено більше одного

# first() / last() — перший/останній або None
note = Note.objects.filter(user=alice).first()   # None якщо не знайдено
note = Note.objects.filter(user=alice).last()

# count() — кількість (SELECT COUNT(*))
n = Note.objects.filter(user=alice).count()

# exists() — EXISTS запит (найшвидший для перевірки)
if Note.objects.filter(user=alice, is_pinned=True).exists():
    ...
# SQL: SELECT 1 FROM hello_app_note WHERE ... LIMIT 1   (дуже швидко!)

# filter() — вибірка (QuerySet)
notes = Note.objects.filter(user=alice, is_archived=False)
```

### UPDATE

```python
# Одиночний об'єкт
note = Note.objects.get(pk=1)
note.title = 'New title'
note.save()                              # UPDATE ... SET title=... (всі поля)

note.save(update_fields=['title', 'updated_at'])
# UPDATE ... SET title=..., updated_at=...  (тільки вказані → ефективніше)

# Масове оновлення (QuerySet.update)
Note.objects.filter(user=alice).update(is_archived=True)
# SQL: UPDATE hello_app_note SET is_archived=TRUE WHERE user_id=alice.id
# Повертає кількість оновлених рядків (int)
# УВАГА: не викликає .save() і не спрацьовують сигнали

# update_or_create
notebook, created = Notebook.objects.update_or_create(
    user=alice, title='Work',          # пошукові поля
    defaults={'color': '#0d6efd', 'is_default': True}   # що оновити/встановити
)
```

### DELETE

```python
# Одиночний об'єкт
note = Note.objects.get(pk=1)
note.delete()   # DELETE FROM hello_app_note WHERE id=1
# CASCADE автоматично видалить пов'язані Reminder

# Масове видалення
Note.objects.filter(user=alice, is_archived=True).delete()
# Повертає (кількість, {model: кількість})
# → (5, {'hello_app.Note': 5, 'hello_app.Reminder': 12})

# Видалити все (з ОБЕРЕЖНІСТЮ!)
Note.objects.all().delete()   # Видаляє ВСІ нотатки!
```

---

## Фільтрація

```python
# Декілька умов = AND
Note.objects.filter(user=alice, is_pinned=True, priority=3)
# SQL: WHERE user_id=... AND is_pinned=TRUE AND priority=3

# Ланцюгування filter() = AND
Note.objects.filter(user=alice).filter(is_pinned=True)
# SQL: WHERE user_id=... AND is_pinned=TRUE   (той самий результат)

# exclude() = NOT
Note.objects.exclude(is_archived=True)
# SQL: WHERE NOT is_archived=TRUE   (= WHERE is_archived=FALSE)

Note.objects.exclude(priority__in=[1, 2])
# SQL: WHERE priority NOT IN (1, 2)

# Комбінування filter + exclude
Note.objects.filter(user=alice).exclude(is_archived=True)
# SQL: WHERE user_id=... AND NOT is_archived=TRUE
```

---

## Lookup Types

```python
# ── Порівняння ────────────────────────────────────────────────────────────────
Note.objects.filter(priority__exact=3)         # = 3    (те саме що priority=3)
Note.objects.filter(priority__gt=1)            # > 1
Note.objects.filter(priority__gte=2)           # >= 2
Note.objects.filter(priority__lt=3)            # < 3
Note.objects.filter(priority__lte=2)           # <= 2
Note.objects.filter(priority__range=(1, 3))    # BETWEEN 1 AND 3

# ── Рядки ────────────────────────────────────────────────────────────────────
Note.objects.filter(title__exact='Django')     # = 'Django' (case-sensitive)
Note.objects.filter(title__iexact='django')    # = 'django' (case-insensitive)
Note.objects.filter(title__contains='ang')     # LIKE '%ang%'
Note.objects.filter(title__icontains='ang')    # ILIKE '%ang%'
Note.objects.filter(title__startswith='Dj')   # LIKE 'Dj%'
Note.objects.filter(title__istartswith='dj')  # ILIKE 'dj%'
Note.objects.filter(title__endswith='.md')    # LIKE '%.md'
Note.objects.filter(title__regex=r'^\d+')     # REGEXP (case-sensitive)
Note.objects.filter(title__iregex=r'^\d+')    # REGEXP (case-insensitive)

# ── NULL ─────────────────────────────────────────────────────────────────────
Note.objects.filter(notebook__isnull=True)     # IS NULL
Note.objects.filter(notebook__isnull=False)    # IS NOT NULL

# ── Списки ───────────────────────────────────────────────────────────────────
Note.objects.filter(priority__in=[1, 2])       # IN (1, 2)
Note.objects.filter(id__in=[1, 5, 10, 42])    # IN (1, 5, 10, 42)
# Також: передати QuerySet!
active_user_ids = User.objects.filter(is_active=True).values_list('id', flat=True)
Note.objects.filter(user_id__in=active_user_ids)   # Subquery!

# ── Дати ─────────────────────────────────────────────────────────────────────
Note.objects.filter(created_at__year=2026)
Note.objects.filter(created_at__month=6)
Note.objects.filter(created_at__day=13)
Note.objects.filter(created_at__hour=10)
Note.objects.filter(created_at__date=date(2026, 6, 13))
Note.objects.filter(created_at__gte=datetime(2026, 1, 1, tzinfo=timezone.utc))

# ── FK Traversal (подвійне __ = JOIN) ──────────────────────────────────────
Note.objects.filter(notebook__title='Work')          # JOIN notebooks WHERE title='Work'
Note.objects.filter(notebook__user=alice)            # 2 рівні JOIN
Note.objects.filter(notebook__title__icontains='w') # JOIN + ILIKE
Note.objects.filter(tags__name='python')             # JOIN через M:N junction

# ── Реверс FK ────────────────────────────────────────────────────────────────
# Знайти Notebook що мають хоча б одну нотатку:
Notebook.objects.filter(notes__isnull=False).distinct()
# Знайти Notebook з нотатками пріоритету HIGH:
Notebook.objects.filter(notes__priority=Note.PRIORITY_HIGH)
```

---

## Q об'єкти

```python
from django.db.models import Q

# OR
Note.objects.filter(Q(title__icontains='django') | Q(content__icontains='django'))
# SQL: WHERE (title ILIKE '%django%' OR content ILIKE '%django%')

# AND (явний)
Note.objects.filter(Q(is_pinned=True) & Q(priority=3))

# NOT
Note.objects.filter(~Q(is_archived=True))
# SQL: WHERE NOT is_archived = TRUE

# Комбінування Q і kwargs
Note.objects.filter(
    Q(user=alice) | Q(group__in=alice_groups),
    is_archived=False   # ← kwargs завжди AND
)
# SQL: WHERE (user_id=... OR group_id IN (...)) AND is_archived=FALSE

# Динамічні фільтри — збирати Q:
query = Q()
if search:
    query &= Q(title__icontains=search) | Q(content__icontains=search)
if tag:
    query &= Q(tags=tag)
notes = Note.objects.filter(query, user=alice)
```

---

## F об'єкти

```python
from django.db.models import F

# Порівнювати поле з полем
Note.objects.filter(updated_at__gt=F('created_at'))
# SQL: WHERE updated_at > created_at

# Атомарне оновлення без race condition:
Note.objects.all().update(views_count=F('views_count') + 1)
# SQL: UPDATE ... SET views_count = views_count + 1
# БЕЗ F: треба SELECT → Python → UPDATE (два запити + race condition!)

# Використання в annotate:
from django.db.models import ExpressionWrapper, DurationField
Note.objects.annotate(
    age=ExpressionWrapper(Now() - F('created_at'), output_field=DurationField())
)

# F у save():
note.views_count = F('views_count') + 1
note.save(update_fields=['views_count'])
# SQL: UPDATE ... SET views_count = views_count + 1
```

---

## Агрегація та анотація

```python
from django.db.models import Count, Avg, Max, Min, Sum

# ── aggregate() — одне значення на весь QuerySet ──────────────────────────
Note.objects.aggregate(total=Count('id'))
# → {'total': 42}

Note.objects.filter(user=alice).aggregate(
    total=Count('id'),
    pinned=Count('id', filter=Q(is_pinned=True)),
    avg_priority=Avg('priority'),
    max_priority=Max('priority'),
    min_priority=Min('priority'),
)
# → {'total': 42, 'pinned': 5, 'avg_priority': 1.8, 'max_priority': 3, 'min_priority': 1}

# ── annotate() — значення для КОЖНОГО рядка ──────────────────────────────
Notebook.objects.annotate(note_count=Count('notes'))
# SELECT *, COUNT(note.id) AS note_count FROM notebooks LEFT JOIN notes ...
# notebook.note_count доступний на кожному об'єкті!

# Фільтрований annotate:
Notebook.objects.annotate(
    active_notes=Count('notes', filter=Q(notes__is_archived=False)),
    pinned_notes=Count('notes', filter=Q(notes__is_pinned=True)),
)

# annotate + filter (фільтруємо ПО АНОТАЦІЇ):
Notebook.objects.annotate(
    note_count=Count('notes')
).filter(note_count__gt=5)
# Записники з більш ніж 5 нотатками

# annotate + order_by:
Notebook.objects.annotate(
    note_count=Count('notes')
).order_by('-note_count')
# Відсортовано за кількістю нотаток

# Tag з кількістю нотаток (реальний приклад з selectors.py):
Tag.objects.filter(user=user).annotate(
    note_count=Count('notes')
).order_by('name')
```

---

## select_related та prefetch_related

```python
# ── select_related: ForeignKey / OneToOne → JOIN (1 запит) ────────────────
# БЕЗ оптимізації: N+1
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)   # ← 1 SQL на кожну ітерацію!

# З select_related: 1 SQL JOIN
notes = Note.objects.select_related('notebook', 'user').all()
# SQL: SELECT notes.*, notebooks.*, auth_user.*
#      FROM notes
#      LEFT OUTER JOIN notebooks ON (notes.notebook_id = notebooks.id)
#      INNER JOIN auth_user ON (notes.user_id = auth_user.id)

# Глибина (вкладений FK):
notes = Note.objects.select_related('notebook__user')
# Доступ: note.notebook.user.username — без додаткових SQL!

# ── prefetch_related: ManyToMany / reverse FK → 2 запити ─────────────────
# БЕЗ оптимізації:
for note in notes:
    for tag in note.tags.all():   # ← 1 SQL на кожну нотатку!
        print(tag.name)

# З prefetch_related: 2 SQL total (незалежно від кількості нотаток)
notes = Note.objects.prefetch_related('tags')
# SQL 1: SELECT * FROM hello_app_note WHERE ...
# SQL 2: SELECT tags.* FROM tags
#         INNER JOIN hello_app_note_tags ON ...
#         WHERE hello_app_note_tags.note_id IN (1, 2, 3, ...)
# Django сам склеює у пам'яті

# Реверс FK:
notes = Note.objects.prefetch_related('reminders')
# Доступ: note.reminders.all() → з кешу, без SQL

# ── Комбінування ─────────────────────────────────────────────────────────
notes = Note.objects.filter(user=user, is_archived=False) \
    .select_related('notebook', 'user') \
    .prefetch_related('tags', 'reminders') \
    .order_by('-is_pinned', '-priority')
# TOTAL: 3 SQL запити для будь-якої кількості нотаток!

# ── Prefetch з фільтром (Prefetch об'єкт) ────────────────────────────────
from django.db.models import Prefetch

notes = Note.objects.prefetch_related(
    Prefetch('reminders', queryset=Reminder.objects.filter(is_sent=False))
    # Завантажити тільки не надіслані нагадування
)
# note.reminders.all() → тільки is_sent=False (з кешу)
```

---

## values / values_list

```python
# values() → список словників (швидше ніж повні об'єкти)
Note.objects.values('title', 'priority')
# → [{'title': 'Test', 'priority': 1}, {'title': 'Django', 'priority': 2}]
# SQL: SELECT title, priority FROM hello_app_note

# values() з FK traversal:
Note.objects.values('title', 'notebook__title')
# → [{'title': 'Test', 'notebook__title': 'Work'}, ...]
# SQL: SELECT notes.title, notebooks.title FROM ... JOIN ...

# values_list() → список кортежів (ще швидше)
Note.objects.values_list('title', 'priority')
# → [('Test', 1), ('Django', 2), ...]

# flat=True → один стовпець = плоский список
note_ids = Note.objects.filter(user=alice).values_list('id', flat=True)
# → [1, 5, 10, 42]  (не [(1,), (5,), ...])

# Корисне використання:
tag_ids = note.tags.values_list('id', flat=True)
# → [3, 7, 12] — ID тегів для форми

# Перевірка чи id в списку:
if request.user.id in group.user_set.values_list('id', flat=True):
    ...
```

---

## order_by / distinct / only / defer

```python
# ── Сортування ───────────────────────────────────────────────────────────
Note.objects.order_by('priority')              # ASC (зростання)
Note.objects.order_by('-priority')             # DESC (спадання)
Note.objects.order_by('-is_pinned', '-priority', '-updated_at')  # Множинне

Note.objects.order_by('?')                    # Випадковий (SLOW на великих таблицях!)
Note.objects.order_by()                       # Прибрати сортування

# Сортування з FK:
Note.objects.order_by('notebook__title')      # По назві записника

# ── distinct() ───────────────────────────────────────────────────────────
# JOIN через tags може дати дублікати → distinct прибирає:
Note.objects.filter(tags__name='python').distinct()
# SQL: SELECT DISTINCT * FROM notes JOIN note_tags JOIN tags WHERE ...

# ── Обмеження (slicing) ──────────────────────────────────────────────────
Note.objects.all()[:10]                       # LIMIT 10
Note.objects.all()[10:20]                     # LIMIT 10 OFFSET 10
Note.objects.all()[0]                         # Перший (LIMIT 1)
Note.objects.all()[-1]                        # ⚠️ НЕ ПІДТРИМУЄТЬСЯ! Використати .last()

# ── only() / defer() — завантажувати тільки потрібні поля ────────────────
# only(): завантажити ТІЛЬКИ вказані поля
Note.objects.only('id', 'title', 'priority')
# SQL: SELECT id, title, priority FROM hello_app_note
# УВАГА: доступ до іншого поля → додатковий SELECT!

# defer(): завантажити ВСІ КРІМ вказаних
Note.objects.defer('content')   # content = великий TextField
# SQL: SELECT id, title, priority, is_pinned, ... FROM ... (без content)
# Корисно коли content = великий текст не потрібний у списку

# iterator() — не кешувати QuerySet (для великих вибірок)
for note in Note.objects.filter(user=alice).iterator():
    process(note)   # Не завантажує всі в пам'ять одразу
```

---

## Оновлення та видалення

```python
# ── update() — масове оновлення одним SQL ─────────────────────────────────
Note.objects.filter(user=alice, is_archived=False).update(
    is_archived=True
)
# SQL: UPDATE hello_app_note SET is_archived=TRUE WHERE user_id=... AND is_archived=FALSE
# Повертає: int (кількість оновлених рядків)

# З F():
Note.objects.all().update(views_count=F('views_count') + 1)

# З умовою:
from django.utils import timezone
Note.objects.filter(
    created_at__lt=timezone.now() - timedelta(days=365)
).update(is_archived=True)
# Архівувати нотатки старші за рік

# ── delete() — масове видалення ──────────────────────────────────────────
deleted_count, breakdown = Note.objects.filter(
    user=alice, is_archived=True
).delete()
# deleted_count = 5
# breakdown = {'hello_app.Note': 5, 'hello_app.Reminder': 12}
# Django автоматично видаляє пов'язані об'єкти (CASCADE)

# ── bulk_update() — масове оновлення об'єктів ────────────────────────────
notes = list(Note.objects.filter(user=alice))
for note in notes:
    note.is_archived = True
Note.objects.bulk_update(notes, ['is_archived'])
# Один UPDATE замість N окремих .save()
```

---

## ManyToMany

```python
note = Note.objects.get(pk=1)
tag_py = Tag.objects.get(name='python', user=alice)
tag_dj = Tag.objects.get(name='django', user=alice)

# Додати
note.tags.add(tag_py)                    # INSERT INTO note_tags (note_id, tag_id)
note.tags.add(tag_py, tag_dj)           # Кілька одночасно

# Видалити конкретний
note.tags.remove(tag_py)                 # DELETE FROM note_tags WHERE note_id=... AND tag_id=...

# Перевірити наявність
note.tags.filter(pk=tag_py.pk).exists()

# Очистити всі
note.tags.clear()                        # DELETE FROM note_tags WHERE note_id=...

# Встановити рівно (замінити):
note.tags.set([tag_py, tag_dj])         # DELETE старих + INSERT нових
note.tags.set(Tag.objects.filter(user=alice, name__in=['python', 'django']))

# Реверс — нотатки з тегом:
tag_py.notes.all()                       # related_name='notes' на ManyToManyField
tag_py.notes.filter(user=alice)

# Кількість тегів на нотатці:
note.tags.count()                        # SELECT COUNT(*) FROM ...

# Всі теги:
note.tags.all()
note.tags.order_by('name')
note.tags.values_list('name', flat=True)  # → ['django', 'python']
```

---

## Ланцюгування

```python
# QuerySet LAZY — SQL не виконується при створенні
qs = Note.objects.filter(user=alice)    # Ще нічого!
qs = qs.filter(is_archived=False)       # Уточнення
qs = qs.select_related('notebook')      # Оптимізація
qs = qs.order_by('-priority')           # Сортування

# SQL виконається тільки тут:
result = list(qs)                       # ← SELECT тут!
count  = qs.count()                     # ← SELECT COUNT(*) тут!
first  = qs.first()                     # ← SELECT ... LIMIT 1 тут!
exists = qs.exists()                    # ← SELECT 1 ... LIMIT 1 тут!
for note in qs: ...                     # ← SELECT тут!

# QuerySet можна передати у шаблон — SQL виконається при рендерингу
return render(request, 'template.html', {'notes': qs})
# Django Template Engine ітерує qs → SQL тут!

# Зберегти результат у Python (виконати SQL зараз):
notes_list = list(qs)          # Завантажує всі в пам'ять
notes_tuple = tuple(qs)

# Клонування QuerySet (не виконує SQL):
cloned_qs = qs.all()           # Новий QuerySet з тими самими параметрами
```

---

## get_object_or_404 та get_or_create

```python
from django.shortcuts import get_object_or_404
from django.http import Http404

# get_object_or_404 — get() або Http404
note = get_object_or_404(Note, pk=pk)
# Якщо не знайдено → Http404 → Django 404 сторінка
# НЕ: DoesNotExist → 500 Internal Error

# З кількома умовами (IDOR захист!):
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 якщо нотатка не існує АБО belongs to іншого юзера

# get_list_or_404 — QuerySet або Http404
notes = get_list_or_404(Note, user=request.user, is_pinned=True)
# → Http404 якщо список порожній

# Кидати Http404 вручну:
if not Note.objects.filter(pk=pk, user=request.user).exists():
    raise Http404("Нотатку не знайдено")

# get_or_create — знайти або створити (atomic):
tag, created = Tag.objects.get_or_create(
    user=alice,
    name='python',                         # Пошукові поля
    defaults={'color': '#3776AB'}          # Значення тільки при CREATE
)
# Якщо 'python' вже є → created=False, tag = existing
# Якщо немає → created=True, tag = new

# update_or_create:
notebook, created = Notebook.objects.update_or_create(
    user=alice,
    title='Work',                          # Пошукові поля (lookup)
    defaults={'color': '#0d6efd'}          # Поновити ці поля (завжди)
)
```

---

## Транзакції

```python
from django.db import transaction

# Context manager:
with transaction.atomic():
    note = Note.objects.create(user=alice, title='Test')
    tags = Tag.objects.filter(id__in=tag_ids, user=alice)
    note.tags.set(tags)
    # Якщо виняток → ROLLBACK обох операцій
# COMMIT якщо все OK

# Декоратор:
@transaction.atomic
def create_notebook(user, title, is_default=False):
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
    return Notebook.objects.create(user=user, title=title, is_default=is_default)

# select_for_update — блокування рядка (SELECT ... FOR UPDATE):
with transaction.atomic():
    note = Note.objects.select_for_update().get(pk=1)
    # Інші транзакції чекають поки цей блок не завершиться
    note.views_count += 1
    note.save()
```

---

## Raw SQL

```python
# Коли ORM недостатньо:

# Manager.raw() — raw SQL, повертає RawQuerySet
notes = Note.objects.raw(
    "SELECT * FROM hello_app_note WHERE user_id = %s ORDER BY priority DESC",
    [alice.id]
)

# connection.cursor() — повний контроль
from django.db import connection

with connection.cursor() as cursor:
    cursor.execute(
        "SELECT notebook_id, COUNT(*) FROM hello_app_note WHERE user_id=%s GROUP BY notebook_id",
        [alice.id]
    )
    rows = cursor.fetchall()
    # → [(1, 5), (2, 12), ...]

# УВАГА: завжди використовуй параметризовані запити!
# ❌ cursor.execute(f"SELECT * WHERE id = {pk}")  → SQL injection!
# ✅ cursor.execute("SELECT * WHERE id = %s", [pk])  → безпечно
```

---

## Швидка шпаргалка

```python
# ЧИТАННЯ
Note.objects.all()                              # Всі (lazy)
Note.objects.filter(user=user)                  # WHERE
Note.objects.exclude(is_archived=True)          # NOT
Note.objects.get(pk=1)                          # Один або exception
Note.objects.first() / .last()                  # Перший/останній або None
Note.objects.count()                            # SELECT COUNT(*)
Note.objects.exists()                           # SELECT 1 LIMIT 1

# ОПТИМІЗАЦІЯ
.select_related('notebook', 'user')             # FK → JOIN
.prefetch_related('tags', 'reminders')          # M:N / reverse FK → 2 запити
.only('id', 'title')                            # Завантажити тільки ці поля
.defer('content')                               # Всі поля крім content

# ФІЛЬТРАЦІЯ
filter(priority__gt=1)                          # > 1
filter(title__icontains='django')               # ILIKE '%django%'
filter(notebook__isnull=True)                   # IS NULL
filter(tags__name='python')                     # M:N JOIN
filter(Q(a=1) | Q(b=2))                        # OR
filter(~Q(archived=True))                       # NOT

# СОРТУВАННЯ І ОБМЕЖЕННЯ
.order_by('-priority', '-updated_at')           # ORDER BY
.distinct()                                     # SELECT DISTINCT
[:10]                                           # LIMIT 10
[10:20]                                         # LIMIT 10 OFFSET 10

# АГРЕГАЦІЯ
.count()                                        # COUNT(*)
.aggregate(avg=Avg('priority'))                 # {'avg': 1.8}
.annotate(n=Count('notes'))                     # Per-row count

# ЗНАЧЕННЯ (без повних об'єктів)
.values('title', 'priority')                    # → [{'title': ...}, ...]
.values_list('id', flat=True)                   # → [1, 2, 3, ...]

# ЗАПИС
Note.objects.create(user=user, title='T')       # INSERT + return
Note.objects.filter(...).update(field=val)      # UPDATE (bulk)
Note.objects.filter(...).delete()               # DELETE (bulk)
note.save(update_fields=['title'])              # UPDATE (один запис, окремі поля)

# MANY-TO-MANY
note.tags.add(tag1, tag2)                       # INSERT
note.tags.remove(tag1)                          # DELETE
note.tags.set([tag1, tag2])                     # DELETE + INSERT
note.tags.clear()                               # DELETE all
note.tags.all()                                 # SELECT

# ТРАНЗАКЦІЇ
with transaction.atomic(): ...                  # ROLLBACK при виняток
```

---

## Дивись також

- [Туторіал 03 — Domain Design і ORM](../tutorials/03_crud.md)
- [Django ORM Документація](https://docs.djangoproject.com/en/5.2/topics/db/queries/)
- [QuerySet API Reference](https://docs.djangoproject.com/en/5.2/ref/models/querysets/)
