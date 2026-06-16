# Django ORM — від основ до глибокої механіки

> ORM (Object-Relational Mapping) — перекладач між Python і SQL.
> Ти пишеш `Note.objects.filter(user=user)` — Django генерує `SELECT ... WHERE user_id = ?`.
> Але ORM **розумний**: виконує SQL тільки коли потрібно, кешує результати, захищає від SQL injection.

---

## Чому ORM, а не сирий SQL

```python
# Без ORM — небезпечно і важко:
cursor.execute(f"SELECT * FROM notes WHERE user_id = {user.id}")
# ↑ SQL injection! title з ' OR 1=1-- зламає систему

# З ORM — безпечно і зрозуміло:
Note.objects.filter(user=user)
# ↑ автоматично: WHERE user_id = %s, [user.id]
# ↑ однаково на SQLite і PostgreSQL
# ↑ результат — Python об'єкти, не raw рядки
```

---

## Ментальна модель: QuerySet — рецепт, не страва

```
Note.objects.filter(status='published')
     ← це РЕЦЕПТ, а не SQL

.select_related('user')
     ← додаємо інгредієнт до рецепту

.order_by('-created_at')
     ← ще одне уточнення

list(qs)  ← ТУТ Django готує страву — виконує ОДИН SQL
```

**Тригери виконання SQL:**

```
for note in qs:          ← ітерація
list(qs)                 ← явне перетворення
qs.first()               ← LIMIT 1
qs[0]                    ← LIMIT 1 OFFSET 0
qs.count()               ← SELECT COUNT(*)
bool(qs)                 ← EXISTS()
len(qs)                  ← виконує і кешує
```

---

## 1. Models та Managers

**`Model` = клас ↔ таблиця. Екземпляр = рядок. `objects` = шлюз до БД.**

```python
# Базова модель з Custom Manager

class PublishedNoteManager(models.Manager):
    """Custom Manager — повертає тільки опубліковані нотатки."""
    def get_queryset(self):
        return super().get_queryset().filter(is_archived=False)

    def recent(self):
        """Останні 10 неархівованих нотаток."""
        return self.get_queryset().order_by('-updated_at')[:10]


class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_URGENT = 4
    PRIORITY_CHOICES = [(1, '🟢 Низький'), (2, '🟡 Середній'),
                        (3, '🟠 Високий'), (4, '🔴 Терміново')]

    user     = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    group    = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True, blank=True)
    notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True)
    tags     = models.ManyToManyField(Tag, blank=True, related_name='notes')

    title      = models.CharField(max_length=200)
    content    = models.TextField(blank=True)
    priority   = models.PositiveSmallIntegerField(choices=PRIORITY_CHOICES, default=PRIORITY_LOW)
    is_pinned  = models.BooleanField(default=False)
    is_archived= models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)  # одноразово при CREATE
    updated_at = models.DateTimeField(auto_now=True)       # оновлюється при кожному save()

    # Два Manager-а:
    objects  = models.Manager()         # стандартний
    active   = PublishedNoteManager()   # custom: Note.active.all()

    def __str__(self):
        return f"{'📌 ' if self.is_pinned else ''}{self.title}"

    class Meta:
        ordering = ['-is_pinned', '-priority', '-updated_at']
        indexes = [
            models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='cnote_priority_valid_range'
            ),
        ]
```

**Lifecycle об'єкта:**

```
note = Note(title='Test', user=user)  → Python об'єкт, note.id = None, 0 SQL

note.save()
SQL: INSERT INTO notes_app_note (...) VALUES (...) RETURNING id

note.title = 'Updated'
note.save(update_fields=['title'])    # ефективніше — UPDATE тільки title

note.delete()
SQL: DELETE FROM notes_app_note WHERE id=42
```

---

## 2. QuerySet — ланцюжок методів

```python
# filter / exclude
Note.objects.filter(user=user, is_archived=False)
Note.objects.exclude(is_pinned=True)

# Q objects — OR / AND / NOT
from django.db.models import Q

Note.objects.filter(Q(user=user) | Q(group__in=user_groups))
Note.objects.filter(Q(title__icontains=q) | Q(content__icontains=q))

# Сортування
Note.objects.order_by('-priority', '-updated_at')   # кілька полів

# Обмеження
Note.objects.filter(user=user)[:10]                 # LIMIT 10
Note.objects.filter(user=user)[10:20]               # LIMIT 10 OFFSET 10

# Пошук по FK через __ (Django робить JOIN автоматично)
Note.objects.filter(user__username='demo_alice')
Note.objects.filter(notebook__title__icontains='django')
Note.objects.filter(tags__name='python').distinct()  # M:N → distinct від JOIN
```

### Таблиця Field Lookups (__)

```python
# Рядки
field__exact = 'val'        # WHERE field = 'val'
field__iexact = 'val'       # WHERE LOWER(field) = LOWER('val')
field__contains = 'val'     # WHERE field LIKE '%val%'
field__icontains = 'val'    # WHERE LOWER(field) LIKE '%val%'
field__startswith = 'val'   # WHERE field LIKE 'val%'
field__in = [1, 2, 3]       # WHERE field IN (1, 2, 3)

# Числа
field__gt = 5               # >
field__gte = 5              # >=
field__lt = 5               # <
field__lte = 5              # <=
field__range = (1, 10)      # BETWEEN 1 AND 10

# NULL
field__isnull = True        # WHERE field IS NULL

# Дати
field__year = 2024          # EXTRACT(YEAR FROM field) = 2024
field__date = date(2024,1,1)# DATE(field) = '2024-01-01'
```

---

## 3. N+1 Problem та select_related / prefetch_related

**N+1 — найпоширеніша помилка продуктивності у Django.**

```python
# ❌ ПРОБЛЕМА — N+1
notes = Note.objects.filter(user=user)
for note in notes:
    print(note.notebook.title)  # ← окремий SQL для кожної нотатки!
# 1 запит для нотаток + N запитів для ноутбуків = N+1

# ✅ РІШЕННЯ для ForeignKey — select_related (SQL JOIN)
notes = Note.objects.filter(user=user).select_related('notebook', 'group')
# 1 SQL запит з JOIN:
# SELECT notes.*, notebooks.*, groups.*
# FROM notes_app_note notes
# LEFT JOIN notes_app_notebook notebooks ON notes.notebook_id = notebooks.id
# LEFT JOIN auth_group groups ON notes.group_id = groups.id

# ✅ РІШЕННЯ для ManyToMany — prefetch_related (окремий IN запит)
notes = Note.objects.filter(user=user).prefetch_related('tags')
# Запит 1: SELECT * FROM notes_app_note WHERE user_id = 1
# Запит 2: SELECT * FROM notes_app_tag
#          INNER JOIN notes_app_note_tags ON ... WHERE note_id IN (1,2,...,50)
# Результат: 2 запити незалежно від кількості нотаток
```

### Коли що

| Тип зв'язку | Метод | SQL |
|-------------|-------|-----|
| ForeignKey | `select_related('notebook')` | 1 JOIN |
| OneToOne | `select_related('user__profile')` | 1 JOIN |
| ManyToMany | `prefetch_related('tags')` | 2 запити |
| Reverse FK | `prefetch_related('reminders')` | 2 запити |

### Prefetch з фільтром

```python
from django.db.models import Prefetch

# Завантажити тільки МАЙБУТНІ нагадування
Note.objects.prefetch_related(
    Prefetch(
        'reminders',
        queryset=Reminder.objects.filter(remind_at__gte=timezone.now()),
        to_attr='upcoming_reminders'   # note.upcoming_reminders замість note.reminders.all()
    )
)
```

---

## 4. F() Expressions — атомарні операції

**F() — посилання на значення стовпця в самій БД. Вирішує race condition.**

```python
from django.db.models import F

# ❌ НЕБЕЗПЕЧНО — race condition при конкурентних запитах
note = Note.objects.get(id=1)
note.views_count += 1  # прочитали 100, 1000 process-ів роблять те саме одночасно
note.save()            # всі записують 101, хоча має бути 1100

# ✅ БЕЗПЕЧНО — атомарна операція на рівні БД
Note.objects.filter(id=1).update(views_count=F('views_count') + 1)
# SQL: UPDATE notes SET views_count = views_count + 1 WHERE id=1
# PostgreSQL виконує це атомарно, без race condition

# F() для toggle (використовується у notes_chat_app services.py!)
Note.objects.filter(pk=note.pk).update(is_pinned=~F('is_pinned'))
note.refresh_from_db(fields=['is_pinned'])  # ← Python об'єкт не знає про зміну у БД

# F() для порівняння двох стовпців
Note.objects.filter(priority__gt=F('is_pinned'))  # умовний приклад

# F() з арифметикою
Note.objects.update(views_count=F('views_count') * 2)
```

---

## 5. annotate() та aggregate()

```python
from django.db.models import Count, Sum, Avg, Max, Q

# aggregate() — одне значення для всього QuerySet
result = Note.objects.filter(user=user).aggregate(
    total=Count('id'),
    avg_priority=Avg('priority'),
    max_priority=Max('priority'),
)
# result = {'total': 42, 'avg_priority': 2.1, 'max_priority': 4}

# annotate() — розрахунковий стовпець для КОЖНОГО об'єкта
# Використовується у notes_chat_app selectors.py!
notebooks = Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
).order_by('-is_default', 'title')
# SQL: SELECT notebooks.*, COUNT(notes.id) AS note_count
#      FROM notebooks LEFT JOIN notes ON ... WHERE notes.is_archived = false
#      GROUP BY notebooks.id
# Використання: notebook.note_count → без жодного додаткового SQL!

# Два annotate разом
TodoList.objects.filter(user=user).annotate(
    total_items=Count('items'),
    done_items=Count('items', filter=Q(items__is_done=True))
)
# todo.total_items, todo.done_items — доступні в шаблоні без SQL

# alias() — обчислити для фільтрації, але не включати в SELECT
Note.objects.alias(
    tag_count=Count('tags')
).filter(tag_count__gt=3)
# WHERE COUNT(tags) > 3, але tag_count НЕ в SELECT
```

---

## 6. transaction.atomic()

**`atomic()` — "все або нічого" для групи операцій.**

```python
from django.db import transaction

# ✅ ПРАВИЛЬНО — пов'язані операції в одній транзакції
def create_note(*, user, title, content='', tag_ids=None):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title, content=content)
        if tag_ids:
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)   # ← M:N всередині транзакції
    return note
# Якщо tags.set() впаде → create() теж rollback'd. Немає orphaned notes.

# ❌ КРИТИЧНА ПОМИЛКА — try/except всередині atomic!
with transaction.atomic():
    try:
        note = Note.objects.create(...)
    except Exception:
        pass  # ← ТРАНЗАКЦІЯ "ЗЛАМАНА", TransactionManagementError!

# ✅ ПРАВИЛЬНО — exception catch ЗОВНІ
try:
    with transaction.atomic():
        note = Note.objects.create(...)
        note.tags.set(tags)
except Exception as e:
    logger.error(f"Failed: {e}")
    return None

# on_commit — виконати ПІСЛЯ успішного COMMIT
def create_note_and_notify(user, title):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title)
        # Celery task не запуститься якщо транзакція rollback'd
        transaction.on_commit(
            lambda: send_reminder_email.delay(note.id)
        )
```

### Вкладені atomic → Savepoints

```python
with transaction.atomic():         # BEGIN
    note = Note.objects.create(...)
    with transaction.atomic():     # SAVEPOINT sp_1
        note.tags.set(tags)        # якщо впаде → ROLLBACK TO sp_1
    # Note зберігається навіть якщо tags впали
```

---

## 7. Корисні патерни

```python
# get_or_create — CREATE якщо не існує (ідемпотентна операція)
notebook, created = Notebook.objects.get_or_create(
    user=user, is_default=True,
    defaults={'title': 'Основний', 'color': '#4A90E2'}
)
# Returns (object, bool) — bool=True якщо тільки що СТВОРЕНО

# update_or_create — UPDATE якщо існує, CREATE якщо ні
profile, _ = UserProfile.objects.update_or_create(
    user=user,
    defaults={'bio': new_bio, 'timezone': timezone_str}
)

# bulk_create — масове створення (1 SQL замість N)
tags = [Tag(name=name, user=user) for name in ['python', 'django', 'orm']]
Tag.objects.bulk_create(tags, ignore_conflicts=True)

# bulk_update — масове оновлення (1 SQL)
notes_to_archive = list(Note.objects.filter(user=user, is_archived=False))
for note in notes_to_archive:
    note.is_archived = True
Note.objects.bulk_update(notes_to_archive, ['is_archived'])

# values() та values_list() — dict/tuple замість Model об'єктів
Note.objects.filter(user=user).values('id', 'title', 'priority')
# → [{'id': 1, 'title': '...', 'priority': 2}, ...]

Note.objects.filter(user=user).values_list('id', flat=True)
# → QuerySet([1, 2, 3, ...])

# Використовується у selectors.py для JSON відповіді:
return list(
    Reminder.objects.filter(...).values('id', 'message', 'remind_at', 'note__title')
)

# only() / defer() — відкладене завантаження полів
Note.objects.only('id', 'title')    # тільки ці поля (менший SELECT)
Note.objects.defer('content')       # всі КРІМ content

# iterator() — стримінг для великих QuerySet (не завантажує все у RAM)
for note in Note.objects.filter(user=user).iterator(chunk_size=1000):
    process(note)
```

---

## 8. Архітектурне питання: чому ціну фіксують в замовленні

> Класичне питання на співбесіді. Розкриває розуміння незмінності транзакційних даних.

**Сценарій:** `Order` → `Product` через ForeignKey, ціна береться з `Product.current_price`.

```
1 травня: Студент купив книгу за $20. Order → Product (current_price=20)
10 травня: Ціну підняли до $25
15 травня: Студент дивиться замовлення → order.product.current_price = $25 (НЕПРАВИЛЬНО!)
```

**Рішення — денормалізація: зберігати ціну безпосередньо в замовленні:**

```python
class OrderItem(models.Model):
    order   = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.RESTRICT)
    quantity = models.PositiveIntegerField(default=1)
    # Зліпок ціни на момент покупки — ніколи не змінюється
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2)

    def get_cost(self):
        return self.purchase_price * self.quantity

# При оформленні замовлення:
OrderItem.objects.create(
    order=order,
    product=product,
    purchase_price=product.current_price,  # ← копіюємо поточну ціну
    quantity=1
)
```

**Принцип:** Каталог (Product) — змінний. Транзакція (OrderItem) — незмінний факт. Фінансова цілісність важливіша за нормалізацію.

---

## 9. MVCC — як PostgreSQL забезпечує конкурентність

**MVCC (Multi-Version Concurrency Control)** — PostgreSQL зберігає кілька версій рядка одночасно.

**Архітектурне правило:** "Читачі не блокують письменників, письменники не блокують читачів."

```
Транзакція A читає Notes:     [row_v1: id=1, title='Django', xmin=100]
Транзакція B оновлює:         [row_v2: id=1, title='Django ORM', xmin=101]
Транзакція A (ще активна):    ← бачить row_v1, не бачить row_v2
Транзакція A завершує COMMIT:
Транзакція B завершує COMMIT:
Новий читач: ← бачить row_v2
```

**Рівні ізоляції:**
- **Read Committed** (дефолт у PostgreSQL і Django): захист від dirty reads, але дозволяє non-repeatable reads
- **Repeatable Read**: заморожує snapshot для всієї транзакції
- **Serializable**: максимальна ізоляція, знижує throughput

**`select_for_update()` — явне блокування рядків:**

```python
with transaction.atomic():
    note = Note.objects.select_for_update().get(pk=pk)
    # SQL: SELECT ... FOR UPDATE
    # Блокує рядок до кінця транзакції
    note.title = new_title
    note.save()
    # Інші транзакції що намагаються змінити цей рядок — чекають
```

---

## 10. Дебаг запитів

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection, reset_queries
from django.conf import settings

settings.DEBUG = True
reset_queries()

from notes_app import selectors
from django.contrib.auth.models import User
user = User.objects.get(username='demo_alice')
notes = list(selectors.get_user_notes(user))

print(f"SQL запитів: {len(connection.queries)}")
for q in connection.queries[:5]:
    print(q['sql'][:100], '→', q['time'])

# EXPLAIN ANALYZE
qs = selectors.get_user_notes(user)
print(qs.explain(verbose=True, analyze=True))
# Seq Scan vs Index Scan — ключова різниця продуктивності

# Перегляд SQL будь-якого QuerySet
print(qs.query)
```

---

## Prediction Exercises

### Exercise 1: Lazy Evaluation

```python
qs = Note.objects.filter(user=user)
qs = qs.order_by('-priority')
qs = qs.select_related('notebook')
```

**Скільки SQL виконалось?** → **0 запитів.** QuerySet lazy — SQL тільки при ітерації.

### Exercise 2: N+1

```python
notes = Note.objects.all()[:10]
for note in notes:
    print(note.notebook.title)
```

**Скільки SQL?** → **1 + 10 = 11 запитів.** Виправлення: `.select_related('notebook')` → **1 запит**.

### Exercise 3: F() vs Python

```python
# Варіант A:
note = Note.objects.get(pk=1); note.is_pinned = True; note.save()

# Варіант B:
Note.objects.filter(pk=1).update(is_pinned=~F('is_pinned'))
```

**Різниця?** → A: 2 SQL + race condition. B: 1 атомарний SQL. B — завжди краще для toggles.

---

## Питання для самоперевірки

1. Що таке Lazy Evaluation і коли SQL фактично виконується?
2. Яка різниця між `select_related` і `prefetch_related`?
3. Що таке N+1 і як виявити через `connection.queries`?
4. Чому `F('views_count') + 1` безпечніший за `note.views_count + 1`?
5. Що станеться якщо зробити `try/except` всередині `atomic()`?
6. Яка різниця між `annotate()` і `aggregate()`?
7. Коли використовувати `bulk_create()` і яка перевага?
8. Чому ціна товару в замовленні має зберігатись окремо від `Product.price`?

---

## У книзі

- [Django Models](django_models.md) — поля, зв'язки, Meta
- [Migrations](migrations.md) — версійний контроль схеми
- [Query Optimization](query_optimization.md) — реальні приклади з notes_chat_app
- [Transactions і PostgreSQL](transactions_indexes_postgresql.md) — atomic, indexes, MVCC

---

## Офіційна документація

- [Django: Making queries](https://docs.djangoproject.com/en/5.2/topics/db/queries/) — QuerySet API
- [Django: QuerySet API reference](https://docs.djangoproject.com/en/5.2/ref/models/querysets/) — всі методи
- [Django: Database access optimization](https://docs.djangoproject.com/en/5.2/topics/db/optimization/) — best practices
- [Django: Aggregation](https://docs.djangoproject.com/en/5.2/topics/db/aggregation/) — annotate, aggregate
- [Django: Transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/) — atomic, on_commit
- [PostgreSQL: MVCC](https://www.postgresql.org/docs/current/mvcc.html) — як PostgreSQL ізолює транзакції
