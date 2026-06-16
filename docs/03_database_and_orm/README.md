# Частина III. Models, Database та ORM

Models — це Python-опис домену. ORM перетворює Python-виклики на SQL. Ця частина охоплює весь стек: реляційні БД → Django models → міграції → QuerySet API → PostgreSQL-специфіка → оптимізація.

**Передумови:** Частина II (Django Core).
**Рівень:** Beginner → Intermediate.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Реляційні БД](relational_db_foundations_full.md) | таблиці, ключі, JOIN, ACID, SQL основи |
| [Django Models](django_orm_full.md) | `models.Model`, поля, зв'язки, `Meta`, `__str__`, constraints |
| [ORM поглиблено](django_orm_deep_full.md) | `Q`, `F`, `annotate`, `values()`, `only()`, `defer()`, N+1 |
| [Міграції](django_migrations_full.md) | `makemigrations`, `migrate`, squash, data migrations |
| [PostgreSQL](postgresql_advanced_full.md) | типи даних, `jsonb`, повнотекстовий пошук, `EXPLAIN ANALYZE` |
| [Індекси](indexing_deep_full.md) | B-tree, частковий індекс, composite index, `db_index=True` |
| [Транзакції](transactions_concurrency_full.md) | `atomic()`, isolation levels, `select_for_update()`, race conditions |
| [ORM Діаграми](orm_mermaid_full.md) | Mermaid ER-діаграми, QuerySet pipeline |

---

## Ключові концепти

**Models — Python-опис таблиць:**

```python
class Note(models.Model):
    PRIORITY_LOW     = 1
    PRIORITY_MEDIUM  = 2
    PRIORITY_HIGH    = 3
    PRIORITY_URGENT  = 4
    PRIORITY_CHOICES = [(1,'🟢 Низький'),(2,'🟡 Середній'),(3,'🟠 Високий'),(4,'🔴 Терміново')]

    user      = models.ForeignKey(User, on_delete=models.CASCADE)
    group     = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True, blank=True)
    notebook  = models.ForeignKey(Notebook, on_delete=models.SET_NULL, null=True, blank=True)
    tags      = models.ManyToManyField(Tag, blank=True)
    title     = models.CharField(max_length=200)
    priority  = models.PositiveSmallIntegerField(default=1, validators=[MaxValueValidator(4)])
    is_pinned = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.CheckConstraint(check=Q(priority__gte=1) & Q(priority__lte=4), name='...')
        ]
```

**QuerySet API (ліниві запити):**

```python
# QuerySet — ще не SQL:
notes = Note.objects.filter(user=user).select_related('notebook').prefetch_related('tags')

# SQL виконується тільки при матеріалізації:
for note in notes:          # evaluate
    print(note.title)

list(notes)                 # evaluate
notes.count()               # SELECT COUNT(*)
notes.exists()              # SELECT 1 FROM ... LIMIT 1
```

**N+1 проблема і оптимізація:**

```python
# ❌ N+1: для 50 нотаток → 51 SQL запит
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)   # окремий SELECT на кожну нотатку

# ✅ select_related: 1 JOIN
notes = Note.objects.select_related('notebook').all()

# ✅ prefetch_related: 2 запити (для M2M і reverse FK)
notes = Note.objects.prefetch_related('tags').all()
```

**Q objects і складні умови:**

```python
from django.db.models import Q

# Власні нотатки АБО нотатки групи:
Note.objects.filter(Q(user=user) | Q(group__in=user.groups.all()))

# Пінені нотатки НЕ з архіву:
Note.objects.filter(Q(is_pinned=True) & ~Q(is_archived=True))
```

**on_delete — що відбувається при видаленні батьківського запису:**

| `on_delete` | Поведінка |
|-------------|-----------|
| `CASCADE` | видаляє залежні записи разом |
| `SET_NULL` | встановлює FK в `NULL` (потребує `null=True`) |
| `PROTECT` | блокує видалення, якщо є залежні записи |
| `DO_NOTHING` | нічого (небезпечно — може зламати FK constraint) |

---

## Lazy evaluation — покроковий розбір

QuerySet — це об'єкт-запит, а не результат. `filter()` лише додає умову; SQL надсилається до БД тільки при **матеріалізації**.

**Крок 1: filter() — SQL ще немає**

```python
notes = Note.objects.filter(user=request.user)
# Python-об'єкт QuerySet. До БД ще нічого не відправлено.
print(type(notes))  # <class 'django.db.models.query.QuerySet'>
```

**Крок 2: умови накопичуються без SQL**

```python
qs = Note.objects.filter(user=request.user)  # lazy
qs = qs.filter(is_pinned=True)               # lazy, умова додається
qs = qs.order_by('-updated_at')              # lazy
qs = qs.select_related('notebook')           # lazy

notes = list(qs)  # ← тільки тут: ONE SELECT з усіма умовами і JOIN
```

**Коли матеріалізація відбувається:**

| Дія | SQL |
|-----|-----|
| `for note in notes:` | `SELECT *` |
| `list(notes)` | `SELECT *` |
| `notes[0]` | `SELECT * LIMIT 1` |
| `notes.count()` | `SELECT COUNT(*)` |
| `notes.exists()` | `SELECT 1 ... LIMIT 1` |
| `len(notes)` | `SELECT *` (завантажує все) |

---

### N+1 — прихована проблема у шаблоні

Саме тому, що QuerySet ліниий, N+1 непомітно виникає при рендерингу шаблону:

```python
# views.py — виглядає нормально: один filter()
def notes_list(request):
    notes = Note.objects.filter(user=request.user)   # 1 запит
    return render(request, 'notes_list.html', {'notes': notes})
```

```html
{# notes_list.html #}
{% for note in notes %}
    {{ note.user.username }}     {# ← Django матеріалізує окремий QuerySet для кожного note.user! #}
    {{ note.notebook.title }}    {# ← ще один SELECT для кожного note.notebook! #}
{% endfor %}
```

100 нотаток → **201 SQL запит** замість очікуваного одного. Django не знає наперед, що `note.user` буде потрібен для кожної нотатки — він отримує дані «на запит».

**Рішення: select_related і prefetch_related**

```python
# select_related — для ForeignKey і OneToOne (робить JOIN, залишається 1 запит)
notes = (
    Note.objects.filter(user=request.user)
    .select_related('user', 'notebook')      # FK → JOIN
    .prefetch_related('tags', 'reminders')   # M:N, reverse FK → 2 додаткових запити
)
# Всього: 1 + 2 = 3 запити замість 1 + 100 + 100
```

**Всі оптимізації живуть у `selectors.py`** — views лишаються тонкими:

```python
# notes_app/selectors.py
def get_user_notes(user):
    return (
        Note.objects.filter(Q(user=user) | Q(group__in=user.groups.all()))
        .select_related('user', 'notebook')
        .prefetch_related('tags', 'reminders')
        .order_by('-updated_at')
    )
```

Реальна реалізація: `notes_app/selectors.py` — 13 функцій, кожна з оптимізованими запитами.

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_app/models.py` | 9 моделей з ForeignKey, M2M, constraints |
| `notes_app/migrations/` | повна historія schema — `0001_initial.py` → `000N_*.py` |
| `notes_app/selectors.py` | `select_related`, `prefetch_related`, `Q` у production коді |
| `notes_app/tests/test_models.py` | тести на constraints, `__str__`, deletion behavior |

**Схема Notes Chat App (спрощено):**

```
User ──1:1──► UserProfile
User ──1:N──► Note ──M:N──► Tag
                  ──1:N──► Reminder
                  ──FK────► Group (SET_NULL)
                  ──FK────► Notebook (SET_NULL)
User ──1:N──► TodoList ──M:N──► User (shared_with)
                         ──1:N──► TodoItem
User ──1:N──► ShoppingList ──M:N──► User (shared_with)
                             ──FK──► Group (SET_NULL)
                             ──1:N──► ShopItem
Group ──1:N──► ChatMessage  (author CASCADE, group CASCADE)
```

---

## Педагогічний зв'язок

```text
Частина III: Models/ORM → Частина VI: Selectors (read-only ORM)
Частина III: Q objects  → Частина VII: IDOR protection
Частина III: Transactions → Частина VIII: test isolation (TransactionTestCase)
```

**Zero to Hero:** Крок 2 — перша модель і перша міграція. Крок 3 — ORM у CRUD через selectors.

**Lab:** [ORM Lab](../labs/orm_lab.md) — Q-запити, N+1 дослідження, `EXPLAIN ANALYZE`.

---

## Практика

1. Виконай у shell: `Note.objects.filter(user__username='demo').values('title', 'priority')`.
2. Знайди N+1 у `notes_app/selectors.py` — переконайся, що є `select_related`/`prefetch_related`.
3. Запусти `python manage.py dbshell` → `EXPLAIN ANALYZE SELECT * FROM notes_app_note WHERE user_id=1;`.
4. Додай нову модель → `makemigrations` → переглянь згенерований файл міграції.

---

## Контрольні питання

- Що таке lazy evaluation у QuerySet? Коли виконується SQL?
- Яка різниця між `CASCADE` і `SET_NULL`? Коли використовувати кожен?
- Що таке N+1 проблема? Як `select_related` та `prefetch_related` її вирішують?
- Навіщо `atomic()` і що відбувається при виключенні всередині нього?
- Чому `PositiveSmallIntegerField` з `MaxValueValidator(4)` краще ніж просто `IntegerField`?
- Що таке `CheckConstraint` і де він перевіряється — у Python чи БД?

---

**Далі →** [Частина IV. Forms і Validation](../04_forms_and_validation/README.md) — як дані потрапляють від користувача.
