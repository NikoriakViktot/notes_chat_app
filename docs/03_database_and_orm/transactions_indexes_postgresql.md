# Транзакції, Індекси та PostgreSQL

> Транзакції захищають цілісність даних при збоях.
> Індекси прискорюють пошук у таблицях з мільйонами рядків.
> PostgreSQL — виробнича БД проєкту: підтримує constraints, JSONB, spatial.

---

## Транзакції — навіщо

**Сценарій:** Студент створює нотатку з тегами. Без транзакції:

```
1. Note.objects.create(...)   ✓  ← нотатка у БД
2. Server crash!              ✗  ← теги не додані
→ Нотатка є, але без тегів. Неузгоджений стан.
```

З транзакцією все або нічого:

```
BEGIN;
  INSERT INTO notes_app_note ... → ✓
  INSERT INTO notes_app_note_tags ... → ✗ (crash)
ROLLBACK;
→ Нічого не збережено. Стан узгоджений.
```

---

## `transaction.atomic()` у notes_chat_app

### `create_note` — note + tags разом

```python
# notes_app/services.py

def create_note(*, user, title, content='', notebook=None, priority=1, group=None, tag_ids=None):
    with transaction.atomic():
        note = Note.objects.create(
            user=user, title=title, content=content,
            notebook=notebook, priority=priority, group=group
        )
        if tag_ids:
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)   # ← M:N операція всередині транзакції
    return note
```

Якщо `tags.set()` падає (наприклад, невалідні ID) — `create()` теж відкатується. Немає orphaned notes без тегів.

### `create_notebook` — зміна default notebook

```python
def create_notebook(*, user, title, color='#4A90E2', is_default=False):
    with transaction.atomic():
        if is_default:
            # Скасувати попередній default ПЕРЕД встановленням нового
            Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        return Notebook.objects.create(user=user, title=title, color=color, is_default=is_default)
```

Без транзакції: якщо `create()` падає після `update()` — жоден notebook не буде default.

### Вкладені транзакції (savepoints)

```python
# Django автоматично використовує SAVEPOINT для вкладених atomic блоків:
with transaction.atomic():        # BEGIN
    note = Note.objects.create(...)
    with transaction.atomic():    # SAVEPOINT sp1
        note.tags.set(tags)       # якщо тут виняток → ROLLBACK TO sp1
    # Зовнішня транзакція продовжується
```

---

## Декоратор `@transaction.atomic`

```python
from django.db import transaction

@transaction.atomic
def process_group_join(user, group):
    """Додає юзера до групи і надсилає повідомлення у чат."""
    group.user_set.add(user)
    ChatMessage.objects.create(
        group=group,
        author=user,
        content=f'{user.username} приєднався до групи'
    )
```

---

## Індекси — навіщо і коли

PostgreSQL без індексу шукає ПОВНІСТЮ по таблиці (Seq Scan):

```sql
-- Без індексу (таблиця 1M рядків):
SELECT * FROM notes_app_note WHERE user_id = 1 ORDER BY updated_at DESC;
-- → Seq Scan: читає ВСІ 1M рядків → 800ms

-- З індексом (user_id, updated_at):
-- → Index Scan: читає тільки рядки цього юзера → 2ms
```

### Індекси у Note моделі

```python
# notes_app/models.py

class Note(models.Model):
    ...
    class Meta:
        indexes = [
            # Покриває: Note.objects.filter(user=user).order_by('-updated_at')
            models.Index(fields=['user', '-updated_at'], name='cnote_user_updated_idx'),

            # Покриває: Note.objects.filter(user=user, is_pinned=True)
            models.Index(fields=['user', 'is_pinned'], name='cnote_user_pinned_idx'),
        ]
```

### Індекс у ChatMessage

```python
class ChatMessage(models.Model):
    ...
    class Meta:
        indexes = [
            # Покриває: ChatMessage.objects.filter(group=group).order_by('timestamp')
            # Єдиний query pattern у чаті — "останні N повідомлень для групи X"
            models.Index(fields=['group', 'timestamp'], name='chat_group_ts_idx'),
        ]
```

### Коли додавати індекс

| Додай індекс | Не потрібен |
|--------------|------------|
| `filter()` по полю, що часто використовується | Поля що рідко фільтруються |
| `order_by()` по великій таблиці | Маленькі таблиці (< 10k рядків) |
| FK поля (не ForeignKey — Django додає автоматично) | Текстові пошуки (потрібен GIN) |
| `unique=True` поля (Django додає автоматично) | Поля що часто оновлюються |

!!! note "ForeignKey → автоматичний індекс"
    Django автоматично додає `db_index=True` для кожного `ForeignKey` поля. Не потрібно додавати вручну для `note.user_id`, `note.notebook_id` etc.

---

## CheckConstraint — валідація на рівні БД

```python
class Note(models.Model):
    priority = models.PositiveSmallIntegerField(...)

    class Meta:
        constraints = [
            # БД відхилить priority < 1 або > 4 навіть якщо Django пропустить
            models.CheckConstraint(
                check=models.Q(priority__gte=1) & models.Q(priority__lte=4),
                name='cnote_priority_valid_range'
            ),
        ]
```

```python
class ShopItem(models.Model):
    quantity = models.DecimalField(...)

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=models.Q(quantity__gt=0),
                name='cshop_item_positive_qty'
            ),
        ]
```

Constraint — це захист на рівні БД. Навіть прямий SQL `UPDATE SET priority = 99` буде відхилений PostgreSQL.

---

## PostgreSQL vs SQLite

| Можливість | SQLite | PostgreSQL |
|-----------|--------|-----------|
| Типи даних | обмежені | повні (JSONB, ARRAY, UUID, hstore) |
| Конкурентність | одночасно 1 writer | повний MVCC, багато writers |
| Full-text search | базовий | tsvector, GIN індекси |
| CheckConstraint | підтримується | підтримується |
| Розмір | файл на диску | сервер, мережа |
| Backup | `cp db.sqlite3` | `pg_dump`, WAL |

**У notes_chat_app:** `settings.py` автоматично обирає БД по `DATABASE_URL`:

```python
# notes_project/settings.py
import dj_database_url

DATABASES = {
    'default': dj_database_url.config(
        default='sqlite:///db.sqlite3',  # fallback для тестів без Docker
        conn_max_age=0,                  # ВАЖЛИВО для ASGI: не тримати з'єднання між запитами
    )
}
```

`conn_max_age=0` — критично для ASGI/async. Постійні з'єднання (persistent connections) не thread-safe в async context.

---

## EXPLAIN ANALYZE — діагностика повільних запитів

```bash
docker compose exec web python manage.py shell
```

```python
from django.db import connection
from notes_app import selectors
from django.contrib.auth.models import User

user = User.objects.get(username='demo_alice')
qs = selectors.get_user_notes(user)

# Отримати EXPLAIN ANALYZE з PostgreSQL
print(qs.explain(verbose=True, analyze=True))
```

```
Seq Scan on notes_app_note  (cost=0.00..1234.56 rows=5 width=200)
  Filter: (user_id = 1)
Planning Time: 0.5 ms
Execution Time: 12.3 ms
```

vs з індексом:

```
Index Scan using cnote_user_updated_idx on notes_app_note
  Index Cond: (user_id = 1)
Planning Time: 0.3 ms
Execution Time: 0.2 ms
```

---

## У книзі

- [Django Models](django_models.md) — де визначаються constraints і indexes
- [Query Optimization](query_optimization.md) — select_related, prefetch_related, N+1
- [Крок 9. PostgreSQL](../tutorials/09_deployment/postgresql.md) — PostgreSQL у Docker

---

## Офіційна документація

- [Django: Database transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/) — atomic(), savepoints
- [Django: Model indexes](https://docs.djangoproject.com/en/5.2/ref/models/indexes/) — Index, UniqueIndex
- [Django: Constraints](https://docs.djangoproject.com/en/5.2/ref/models/constraints/) — CheckConstraint, UniqueConstraint
- [PostgreSQL: EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html) — діагностика запитів
- [dj-database-url](https://github.com/jazzband/dj-database-url) — DATABASE_URL parsing
