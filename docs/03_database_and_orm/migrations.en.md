# Migrations

> A migration is a versioned file of database schema changes.
> Instead of a manual ALTER TABLE, Django generates and applies migrations automatically.

---

## Why migrations

Without migrations, every time you changed a model you would write the SQL yourself:

```sql
-- Added an is_archived field to Note?
ALTER TABLE notes_app_note ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
-- And on the production server? And on a colleague's machine? And how do you roll it back?
```

Django migration:
```bash
python manage.py makemigrations   # generates the change file
python manage.py migrate          # applies the SQL to the DB
```

Advantages:
- Version control of the schema (git history)
- Automatic application in new environments
- A rollback mechanism (`migrate app 0003`)

---

## Workflow

```
models.py (change) → makemigrations → 0005_add_is_archived.py → migrate → DB
```

### Step 1: Change the model

```python
# notes_app/models.py
class Note(models.Model):
    ...
    is_archived = models.BooleanField(default=False)  # ← new field
```

### Step 2: Generate the migration

```bash
docker compose exec web python manage.py makemigrations
```

```
Migrations for 'notes_app':
  notes_app/migrations/0005_note_is_archived.py
    - Add field is_archived to note
```

### Step 3: Inspect the SQL (optional)

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

### Step 4: Apply the migration

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

## Anatomy of a migration file

```python
# notes_app/migrations/0004_chatmessage.py

from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):

    dependencies = [
        ('notes_app', '0003_note_group'),  # ← previous migration
        ('auth', '0012_alter_user_first_name_max_length'),  # ← dependency on auth
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

**Key parts:**
- `dependencies` — the list of migrations that must be applied before this one
- `operations` — the list of changes: `CreateModel`, `AddField`, `AlterField`, `DeleteModel`, `AddIndex`

---

## Current notes_chat_app migrations

```
notes_app/migrations/
├── 0001_initial.py           ← UserProfile, Tag, Notebook, Note, Reminder,
│                                TodoList, TodoItem, ShoppingList, ShopItem
├── 0002_note_shared_with.py  ← direct sharing via ManyToMany
├── 0003_note_group.py        ← sharing via Group (SET_NULL FK)
└── 0004_chatmessage.py       ← ChatMessage model and index
```

Check the status:

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

`[X]` — applied, `[ ]` — not applied.

---

## How migrations are tracked

Django stores the list of applied migrations in the `django_migrations` table:

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

`migrate` compares the list of files with the table and applies only the new ones.

---

## Data migrations — changing data

Besides schema changes you can write **data migrations** — Python code that changes data during deployment:

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

!!! warning "Always use `apps.get_model()` in data migrations"
    Do not import the model directly (`from notes_app.models import Note`).
    `apps.get_model()` returns the version of the model **as of this migration**, 
    not the current one — which protects against conflicts if fields were renamed later.

---

## Rolling back a migration

```bash
# Return to the state AFTER 0003 (roll back 0004)
docker compose exec web python manage.py migrate notes_app 0003
```

Django runs `Migration.operations` in reverse order if the operation supports it.

!!! danger "A rollback that drops a table is a destructive operation"
    `CreateModel` → rollback = `DROP TABLE`. All data in that table WILL BE DELETED.
    Always make a backup before rolling back in production.

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `InconsistentMigrationHistory` | the migrations in the DB do not match the files | `showmigrations`, find the conflict |
| `django.db.utils.ProgrammingError: relation does not exist` | `migrate` was not run | `docker compose exec web python manage.py migrate` |
| `MigrationSyntaxError` | a migration file was edited incorrectly | fix it, or delete it and regenerate |
| `No changes detected` | the model was not changed or the app is not in `INSTALLED_APPS` | check `INSTALLED_APPS` in settings.py |
| `ValueError: Field 'X' expected a number but got 'abc'` | a data migration changed the type of a field that already has data | a two-stage migration is needed |

---

## entrypoint.sh — migrations on container startup

In notes_chat_app, migrations run automatically:

```bash
# entrypoint.sh
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

Every `docker compose up` automatically applies new migrations.

---

## In the book

- [Django Models](django_models.md) — what models are and field types
- [Step 9. Deployment → PostgreSQL](../tutorials/09_deployment/postgresql.md) — the DB in production

---

## Official documentation

- [Django: Migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/) — full description
- [Django: Data migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/#data-migrations) — RunPython
- [Django: Migration operations](https://docs.djangoproject.com/en/5.2/ref/migration-operations/) — all operation types
- [Django: Squashing migrations](https://docs.djangoproject.com/en/5.2/topics/migrations/#squashing-migrations) — squashmigrations
