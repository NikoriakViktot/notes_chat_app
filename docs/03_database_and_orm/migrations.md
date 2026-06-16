# Міграції

> Migration — це версійний файл змін схеми бази даних.
> Замість ALTER TABLE вручну — Django генерує і застосовує міграції автоматично.

---

## Навіщо міграції

Без міграцій при зміні моделі ти б писав SQL сам:

```sql
-- Додав поле is_archived у Note?
ALTER TABLE notes_app_note ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
-- А на production сервері? А у колеги? А як відкотити?
```

Django migration:
```bash
python manage.py makemigrations   # генерує файл зміни
python manage.py migrate          # застосовує SQL до БД
```

Переваги:
- Версійний контроль схеми (git history)
- Автоматичне застосування на нових середовищах
- Механізм відкоту (`migrate app 0003`)

---

## Workflow

```
models.py (зміна) → makemigrations → 0005_add_is_archived.py → migrate → БД
```

### Крок 1: Змінюємо модель

```python
# notes_app/models.py
class Note(models.Model):
    ...
    is_archived = models.BooleanField(default=False)  # ← нове поле
```

### Крок 2: Генеруємо міграцію

```bash
docker compose exec web python manage.py makemigrations
```

```
Migrations for 'notes_app':
  notes_app/migrations/0005_note_is_archived.py
    - Add field is_archived to note
```

### Крок 3: Переглядаємо SQL (опціонально)

```bash
docker compose exec web python manage.py sqlmigrate notes_app 0005
```

```sql
BEGIN;
--
-- Add field is_archived to note
--
ALTER TABLE "notes_app_note" ADD COLUMN "is_archived" boolean DEFAULT false NOT NULL;
COMMIT;
```

### Крок 4: Застосовуємо міграцію

```bash
docker compose exec web python manage.py migrate
```

```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, notes_app, sessions
Running migrations:
  Applying notes_app.0005_note_is_archived... OK
```

---

## Анатомія файлу міграції

```python
# notes_app/migrations/0004_chatmessage.py

from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):

    dependencies = [
        ('notes_app', '0003_note_group'),  # ← попередня міграція
        ('auth', '0012_alter_user_first_name_max_length'),  # ← залежність від auth
    ]

    operations = [
        migrations.CreateModel(
            name='ChatMessage',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True)),
                ('content', models.TextField(verbose_name='Повідомлення')),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('author', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to='auth.user',
                )),
                ('group', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    to='auth.group',
                )),
            ],
        ),
        migrations.AddIndex(
            model_name='chatmessage',
            index=models.Index(fields=['group', 'timestamp'], name='chat_group_ts_idx'),
        ),
    ]
```

**Ключові частини:**
- `dependencies` — список міграцій які мають бути застосовані перед цією
- `operations` — список змін: `CreateModel`, `AddField`, `AlterField`, `DeleteModel`, `AddIndex`

---

## Поточні міграції notes_chat_app

```
notes_app/migrations/
├── 0001_initial.py           ← UserProfile, Tag, Notebook, Note, Reminder,
│                                TodoList, TodoItem, ShoppingList, ShopItem
├── 0002_note_shared_with.py  ← пряме шарінг через ManyToMany
├── 0003_note_group.py        ← шарінг через Group (SET_NULL FK)
└── 0004_chatmessage.py       ← ChatMessage модель і індекс
```

Перевірити статус:

```bash
docker compose exec web python manage.py showmigrations
```

```
admin
 [X] 0001_initial
 ...
auth
 [X] 0001_initial
 ...
notes_app
 [X] 0001_initial
 [X] 0002_note_shared_with
 [X] 0003_note_group
 [X] 0004_chatmessage
```

`[X]` — застосовано, `[ ]` — не застосовано.

---

## Як міграції відстежуються

Django зберігає список застосованих міграцій у таблиці `django_migrations`:

```sql
SELECT app, name, applied
FROM django_migrations
WHERE app = 'notes_app';
```

```
notes_app | 0001_initial     | 2024-01-15 12:00:00
notes_app | 0002_...         | 2024-01-20 09:30:00
notes_app | 0003_...         | 2024-02-01 11:00:00
notes_app | 0004_chatmessage | 2024-02-10 15:00:00
```

`migrate` порівнює список файлів з таблицею і застосовує тільки нові.

---

## Data migrations — зміна даних

Окрім схемних змін можна писати **data migrations** — Python код що змінює дані при деплої:

```python
# notes_app/migrations/0005_set_default_notebook.py

from django.db import migrations

def set_default_notebook(apps, schema_editor):
    Note = apps.get_model('notes_app', 'Note')
    Notebook = apps.get_model('notes_app', 'Notebook')
    User = apps.get_model('auth', 'User')

    for user in User.objects.all():
        notebook, _ = Notebook.objects.get_or_create(
            user=user, is_default=True,
            defaults={'title': 'Основний'}
        )
        Note.objects.filter(user=user, notebook=None).update(notebook=notebook)

class Migration(migrations.Migration):
    dependencies = [('notes_app', '0004_chatmessage')]
    operations = [
        migrations.RunPython(set_default_notebook, migrations.RunPython.noop),
    ]
```

!!! warning "Завжди використовуй `apps.get_model()` у data migrations"
    Не імпортуй модель напряму (`from notes_app.models import Note`).
    `apps.get_model()` повертає версію моделі **на момент цієї міграції**, 
    а не поточну — що захищає від конфліктів якщо поля були перейменовані пізніше.

---

## Відкат міграції

```bash
# Повернутися до стану ПІСЛЯ 0003 (відкотити 0004)
docker compose exec web python manage.py migrate notes_app 0003
```

Django виконає `Migration.operations` у зворотньому порядку якщо операція це підтримує.

!!! danger "Відкат з видаленням таблиці — деструктивна операція"
    `CreateModel` → відкат = `DROP TABLE`. Всі дані цієї таблиці БУДУТЬ ВИДАЛЕНІ.
    Завжди роби бекап перед відкатом на production.

---

## Типові помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `InconsistentMigrationHistory` | міграції у БД не відповідають файлам | `showmigrations`, знайди конфлікт |
| `django.db.utils.ProgrammingError: relation does not exist` | `migrate` не запущено | `docker compose exec web python manage.py migrate` |
| `MigrationSyntaxError` | відредагував файл міграції неправильно | відредагуй або видали і перегенеруй |
| `No changes detected` | модель не змінена або app не в `INSTALLED_APPS` | перевір `INSTALLED_APPS` у settings.py |
| `ValueError: Field 'X' expected a number but got 'abc'` | data migration змінила тип поля з наявними даними | потрібна двоетапна міграція |

---

## entrypoint.sh — міграції при старті контейнера

У notes_chat_app міграції запускаються автоматично:

```bash
# entrypoint.sh
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

Кожен `docker compose up` автоматично застосовує нові міграції.

---

## У книзі

- [Django Models](django_models.md) — що таке моделі і типи полів
- [Крок 9. Deployment → PostgreSQL](../tutorials/09_deployment/postgresql.md) — БД у production

---

## Офіційна документація

- [Django: Migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/) — повний опис
- [Django: Data migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/#data-migrations) — RunPython
- [Django: Migration operations](https://docs.djangoproject.com/en/5.2/ref/migration-operations/) — всі типи операцій
- [Django: Squashing migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/#squashing-migrations) — squashmigrations
