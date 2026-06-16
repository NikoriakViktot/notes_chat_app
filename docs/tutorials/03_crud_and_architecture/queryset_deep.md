# QuerySet глибоко: N+1, нормалізація, транзакції

> Цей розділ охоплює три ключові концепції: нормалізацію схеми БД, вирішення N+1 проблеми та атомарні операції.

---

## Нормалізація: Before / After

> **"Одна правда для одного факту."**
> Нормалізація — це процес виявлення і усунення дублювання з реляційної схеми.
> Мета: кожен факт зберігається **рівно в одному місці**.

### 3NF на прикладі

**❌ ДО (1NF) — все в одній таблиці `employees`:**

| id | name  | dept_id | dept_name   | location | salary |
|----|-------|---------|-------------|----------|--------|
| 1  | Alice | 10      | **Engineering** | **Kyiv** | 50000  |
| 2  | Bob   | 10      | **Engineering** | **Kyiv** | 45000  |
| 3  | Carol | 20      | **Design**      | **Lviv** | 48000  |
| 4  | Dan   | 10      | **Engineering** | **Kyiv** | 52000  |
| 5  | Eva   | 20      | **Design**      | **Lviv** | 49000  |

**Проблема:** "Engineering / Kyiv" повторюється 3 рази.
Переїхали в Харків? `UPDATE` 1000 рядків. Помилився в назві? Inconsistency.

---  →  3NF: **винести в окрему таблицю**  ---

**✅ ПІСЛЯ — `employees` (FK → `departments.id`):**

| id | name  | dept_id | salary |
|----|-------|---------|--------|
| 1  | Alice | **10**  | 50000  |
| 2  | Bob   | **10**  | 45000  |
| 3  | Carol | **20**  | 48000  |
| 4  | Dan   | **10**  | 52000  |
| 5  | Eva   | **20**  | 49000  |

**✅ `departments` — одна правда:**

| id | name        | location |
|----|-------------|----------|
| 10 | Engineering | Kyiv     |
| 20 | Design      | Lviv     |

```python
# Django модель після нормалізації:
class Department(models.Model):
    name     = models.CharField(max_length=80)
    location = models.CharField(max_length=80)

class Employee(models.Model):
    name       = models.CharField(max_length=80)
    department = models.ForeignKey(Department, on_delete=models.PROTECT)
    salary     = models.DecimalField(max_digits=10, decimal_places=2)
```

> **Переїзд тепер:** `UPDATE departments SET location='Kharkiv' WHERE id=10;`
> **1 рядок замість 1000.** Неможлива inconsistency.

### Три нормальні форми — шпаргалка

| Форма | Правило | Порушення — приклад |
|-------|---------|---------------------|
| **1NF** | Всі значення атомарні, немає масивів у клітинці | `tags = "python,django,orm"` у одному стовпці |
| **2NF** | Всі неключові атрибути залежать від **цілого** PK | В таблиці `(order_id, product_id)` → `product_name` залежить тільки від `product_id` |
| **3NF** | Немає **транзитивних** залежностей (A→B→C де B не ключ) | `employee.dept_name` залежить від `dept_id`, а не від `employee.id` |

> **Практичне правило:** якщо при зміні одного факту треба `UPDATE` > 1 рядка — схема не нормалізована.

---

## N+1 Проблема

> Найпоширеніший перформанс-баг у Django — Django робить 1 + N SQL запитів замість 1.

### Чому виникає N+1

N+1 виникає **саме тому**, що QuerySet ліниий. Студент вже знає, що `for note in notes:` матеріалізує один SELECT. Але щойно в шаблоні з'являється `note.notebook` — Django не знає, що `notebook` буде потрібен для кожної нотатки, і робить окремий SELECT для кожного:

```
{% for note in notes %}
    {{ note.notebook.title }}   ← для кожного note: SELECT FROM notebooks WHERE id=?
{% endfor %}
```

50 нотаток → шаблон «запитує» notebook 50 разів → **51 SQL запит** замість очікуваного одного.

Це не баг Django — це закономірний наслідок lazy loading. Рішення — явно сказати Django заздалегідь, які зв'язки будуть потрібні.

```python
# 50 нотаток у базі. Кожна має ForeignKey на Notebook.
notes = Note.objects.all()          # Query 1: SELECT * FROM notes  ← 50 рядків

for note in notes:
    print(note.notebook.title)       # Query 2, 3, 4, ..., 51!
    # Кожен note.notebook.title → ОКРЕМИЙ SELECT FROM notebooks WHERE id=...
    # 50 нотаток → 50 додаткових запитів → 51 TOTAL!
```

---

## select_related — вирішення N+1 для FK

```python
# ❌ N+1: 100 нотаток + 100 запитів для user + 100 для category = 201 запит
notes = Note.objects.filter(is_archived=False)[:100]
for note in notes:
    print(note.user.username, note.notebook.title)  # нові SQL для кожного!

# ✅ select_related: 1 запит з JOIN
notes = Note.objects.select_related(
    'user', 'notebook'
).filter(is_archived=False)[:100]
for note in notes:
    print(note.user.username, note.notebook.title)  # вже в пам'яті
```

### Як це працює всередині

```python
# Крок 1: Базовий QuerySet (ЛІНИВИЙ — SQL ще не виконаний!)
qs = Note.objects.filter(user=user, is_archived=archived)
#    SQL поки: WHERE note.user_id=? AND note.is_archived=?
#    Але SQL НЕ виконується — Django чекає поки хтось ітерує QuerySet!

# Крок 2: select_related('notebook') — приєднуємо FK одним JOIN
qs = qs.select_related('notebook')
#    SQL стане: LEFT JOIN hello_app_notebook nb ON note.notebook_id = nb.id
#    Наслідок: note.notebook.title → НЕ запускає новий SELECT (вже в пам'яті!)
#
#    БЕЗ select_related: for note in qs: print(note.notebook.title)
#                        → 1 SELECT + N SELECT = N+1 проблема!
#    З select_related: 1 SELECT з JOIN — завжди!
```

---

## prefetch_related — для M:N та reverse FK

```python
# ✅ 2 запити: один для notes, один для tags
notes = Note.objects.prefetch_related('tags').all()[:50]
for note in notes:
    print([t.name for t in note.tags.all()])  # вже в пам'яті!
```

### Як це працює всередині

```python
# Крок 3: prefetch_related('tags') — завантажуємо M:N
qs = qs.prefetch_related('tags')
#    ЗАПИТ 1: SELECT * FROM note WHERE ...
#    ЗАПИТ 2: SELECT tag.* ... WHERE note_id IN (1, 2, 3, ...)
#    Python: Django з'єднує самостійно
#    Наслідок: note.tags.all() → вже в кеші, НЕ новий SELECT!
```

### Prefetch з фільтром (to_attr)

```python
from django.db.models import Prefetch
from django.utils import timezone

notes = Note.objects.prefetch_related(
    'tags',
    Prefetch(
        'reminders',
        queryset=Reminder.objects.filter(
            remind_at__gte=timezone.now()   # тільки МАЙБУТНІ нагадування
        ).order_by('remind_at'),
        to_attr='upcoming_reminders'  # зберігаємо у ОКРЕМИЙ атрибут!
    )
)

# Чому Prefetch з to_attr?
# БЕЗ to_attr:  note.reminders.all()         → NEW QuerySet (ще один SELECT!)
#              note.reminders.filter(...)      → NEW QuerySet (інший SELECT!)
# З to_attr:   note.upcoming_reminders        → list[Reminder] (вже в пам'яті!)
#   У шаблоні: {% for r in note.upcoming_reminders %}  ← НЕ SELECT!
```

### Комбінування select_related і prefetch_related

```python
# Реальний приклад: note_list view
notes = (
    Note.objects
    .select_related('user', 'notebook')     # FK → SQL JOIN (1 запит)
    .prefetch_related('tags', 'reminders')  # M:N + reverse FK (2 запити)
    .filter(is_archived=False)
    .order_by('-is_pinned', '-priority', '-updated_at')
)
# TOTAL: 2 SQL запити для будь-якої кількості нотаток ✓
# БЕЗ оптимізації: 1 + N + N SQL (для N нотаток)
```

### Annotate замість N запитів

```python
# ❌ НЕПРАВИЛЬНО: N+1!
notebooks = Notebook.objects.filter(user=user)
for nb in notebooks:
    count = nb.notes.filter(is_archived=False).count()  # окремий SELECT!
# 10 записників → 11 SQL запитів!

# ✅ ПРАВИЛЬНО: один GROUP BY
notebooks = Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
)
# SQL: SELECT nb.*, COUNT(note.id) FILTER (WHERE note.is_archived=FALSE) AS note_count
#      FROM notebook nb LEFT JOIN note ON note.notebook_id=nb.id
#      WHERE nb.user_id=? GROUP BY nb.id
# 1 SQL! nb.note_count → число, вже в пам'яті!
```

### Подвійна анотація

```python
TodoList.objects.filter(user=user).annotate(
    total_items=Count('items'),                                    # всього пунктів
    done_items=Count('items', filter=Q(items__is_done=True))       # виконаних
)
# SQL: SELECT todolist.*,
#             COUNT(item.id) AS total_items,
#             COUNT(item.id) FILTER (WHERE item.is_done=TRUE) AS done_items
#      FROM todolist LEFT JOIN todoitem item ON item.todo_list_id = todolist.id
#      WHERE todolist.user_id = ? GROUP BY todolist.id
#
# У шаблоні:
# todo.total_items → 5 (без жодного SELECT!)
# todo.done_items  → 3 (без жодного SELECT!)
# Прогрес: 3/5 = 60%
```

### Як виявити N+1: Django Debug Toolbar

```bash
pip install django-debug-toolbar
```

```python
# settings.py:
INSTALLED_APPS = ['debug_toolbar', ...]
MIDDLEWARE = ['debug_toolbar.middleware.DebugToolbarMiddleware', ...MIDDLEWARE]
INTERNAL_IPS = ['127.0.0.1']

# urls.py:
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [path('__debug__/', include(debug_toolbar.urls))] + urlpatterns
```

У браузері → бокова панель показує всі SQL запити з підсвіченням дублікатів.

---

## F() — атомарні операції

```python
from django.db.models import F

# ✅ Атомарний інкремент (race-condition safe!)
# UPDATE hello_app_note SET views_count = views_count + 1 WHERE id = 42
Note.objects.filter(pk=42).update(views_count=F('views_count') + 1)

# ✅ Порівняння двох полів між собою
Note.objects.filter(views_count__gt=F('likes_count'))
# WHERE views_count > likes_count  (порівняння СТОВПЦІВ, не значень)

# ❌ Небезпечно при конкурентних запитах:
note = Note.objects.get(pk=42)
note.views_count += 1   # читає в Python
note.save()             # записує назад → race condition!
```

---

## transaction.atomic()

> Атомарна операція: або ВСІ зміни зберігаються, або ЖОДНОЇ.

### Проблема без atomic

```python
def create_note(user, title, tag_ids):
    note = Note.objects.create(user=user, title=title)
    # ← INSERT INTO note → id=42

    # ПОМИЛКА ТУТ (наприклад, tag не існує):
    tags = Tag.objects.filter(id__in=tag_ids, user=user)
    note.tags.set(tags)   # ← Виняток через неправильний tag_id!

    # СТАН БАЗИ:
    # Note з id=42 існує (INSERT вже відбувся)
    # Але теги не прикріплені
    # НЕКОНСИСТЕНТНИЙ СТАН! "Сирота" без тегів
```

### Рішення — transaction.atomic

```python
from django.db import transaction

def create_note(user, title, tag_ids):
    with transaction.atomic():
        note = Note.objects.create(user=user, title=title)
        # ← Поки в atomic блоці → BEGIN TRANSACTION

        tags = Tag.objects.filter(id__in=tag_ids, user=user)
        note.tags.set(tags)
        # ← Якщо виняток → ROLLBACK весь блок
        # Note НЕ збережений у БД!

    # ← Якщо все ОК → COMMIT
    return note
```

### Вкладені atomic блоки — savepoints

```python
def complex_operation():
    with transaction.atomic():      # ← BEGIN
        do_operation_1()            # ← INSERT ...

        with transaction.atomic():  # ← SAVEPOINT sp_1
            do_operation_2()        # ← INSERT ...
            # Якщо виняток тут → ROLLBACK TO sp_1
            # operation_1 залишається!

        do_operation_3()            # ← INSERT ...
    # ← COMMIT (якщо все ОК)
```

### @transaction.atomic як декоратор

```python
@transaction.atomic
def create_notebook(user, title, is_default=False):
    """
    Бізнес-правило: у юзера тільки ОДИН default записник.
    Ці два запити мають бути атомарними:
    1. Скинути попередній default
    2. Встановити новий
    """
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        # ← Якщо тут виняток → не буде ситуації "жоден default"
    return Notebook.objects.create(user=user, title=title, is_default=is_default)
    # ← Обидві операції або обидві відкатяться
```

---

## select_for_update() — запобігання race conditions

```python
with transaction.atomic():
    # SELECT ... FOR UPDATE → блокує рядок до кінця транзакції
    note = Note.objects.select_for_update().get(pk=note_id)
    if not note.is_archived:
        note.is_archived = True
        note.save(update_fields=['is_archived'])
    # COMMIT → lock знімається

# nowait=True: кидає DatabaseError замість чекання якщо рядок вже заблокований
try:
    note = Note.objects.select_for_update(nowait=True).get(pk=note_id)
except DatabaseError:
    return JsonResponse({'error': 'Ресурс зайнятий, спробуйте пізніше'}, status=409)
```

### Чому select_for_update потрібен при toggle

```python
# ЧОМУ select_for_update()?
# Проблема без блокування:
#   Thread A: SELECT item WHERE id=5 → is_done=False
#   Thread B: SELECT item WHERE id=5 → is_done=False  (ТЕ Ж ЗНАЧЕННЯ!)
#   Thread A: UPDATE item SET is_done=True
#   Thread B: UPDATE item SET is_done=True  ← обидва встановлюють True!
#   Помилка: другий клік мав би зняти відмітку!

with transaction.atomic():  # select_for_update ВИМАГАЄ atomic!
    item = TodoItem.objects.select_for_update().get(
        id=item_id,
        todo_list__user=user  # БЕЗПЕКА: перевіряємо право доступу через FK!
    )
    # SQL: SELECT ... FROM todoitem
    #      JOIN todolist ON todoitem.todo_list_id = todolist.id
    #      WHERE todoitem.id=? AND todolist.user_id=?
    #      FOR UPDATE  ← блокує рядок!

    item.is_done = not item.is_done
    item.save(update_fields=['is_done'])
# COMMIT → знімає блокування рядка
```

---

## Навігація

- Попередня: [Services і Selectors](services_and_selectors.md)
- Наступна: [PostgreSQL](postgresql.md)
