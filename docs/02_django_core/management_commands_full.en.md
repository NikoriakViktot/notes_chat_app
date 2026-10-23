# Django — The Command System

> `python manage.py` is Django's command line.
> Every command is a Python class with access to all of Django (ORM, settings, signals).

---

## Why commands

Django commands are scripts for tasks outside HTTP: migrations, loading data, cleaning up old records, sending newsletters.

```python
# A plain Python script has no access to the Django ORM without setup:
python scripts/seed_data.py     # ← ImportError or AppRegistryNotReady

# Django command — ORM, settings, all apps are ready automatically:
python manage.py seed_demo_data
```

---

## Cheat sheet — command table

| Command | Syntax | When |
|---------|-----------|------|
| Start the server | `python manage.py runserver` | Development |
| Generate migrations | `python manage.py makemigrations` | After changing `models.py` |
| Apply migrations | `python manage.py migrate` | After `makemigrations` |
| View SQL | `python manage.py sqlmigrate notes_app 0004` | Debug |
| Migration status | `python manage.py showmigrations` | DB audit |
| Roll back a migration | `python manage.py migrate notes_app 0003` | Rollback |
| Create a superuser | `python manage.py createsuperuser` | After the first migration |
| Collect static files | `python manage.py collectstatic` | Before deployment |
| Python shell | `python manage.py shell` | Debug ORM |
| SQL shell | `python manage.py dbshell` | Raw SQL |
| Run tests | `python manage.py test` | CI/CD |
| Check the project | `python manage.py check` | Configuration check |
| Security audit | `python manage.py check --deploy` | Before deployment |
| Custom command | `python manage.py seed_demo_data` | Automation |

---

## Anatomy of `manage.py`

```python
# manage.py — in the root of every Django project
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
```

When you run `python manage.py migrate`:
1. `os.environ` sets which `settings.py` to use
2. Django initializes (all `INSTALLED_APPS`, `DATABASES`, etc.)
3. `execute_from_command_line(['manage.py', 'migrate'])` looks for the `migrate` command among all `management/commands/` directories

---

## Where Django looks for commands

```
every INSTALLED_APP/
└── management/
    └── commands/
        └── *.py   ← each file = one command
```

`notes_app` has:

```
notes_app/
└── management/
    └── commands/
        └── seed_demo_data.py   ← python manage.py seed_demo_data
```

---

## Main built-in commands

### `makemigrations` — recording schema changes

Scans `models.py`, compares it with the saved state and generates a Python script:

```bash
python manage.py makemigrations
python manage.py makemigrations notes_app         # for a specific app
python manage.py makemigrations --name add_tags   # with a descriptive name
```

**Important:** The command **does not change the database** — it only creates a plan.

```python
# Example of a generated file migrations/0005_note_is_archived.py
class Migration(migrations.Migration):
    dependencies = [('notes_app', '0004_chatmessage')]
    operations = [
        migrations.AddField(
            model_name='note',
            name='is_archived',
            field=models.BooleanField(default=False),
        ),
    ]
```

### `migrate` — applying migrations

```bash
python manage.py migrate           # all apps
python manage.py migrate notes_app # only one app
python manage.py migrate notes_app 0003  # roll back to a specific version
```

**How it is tracked:** Django stores applied migrations in the `django_migrations` table.

```bash
# View the SQL before applying
python manage.py sqlmigrate notes_app 0004
# BEGIN;
# CREATE TABLE "notes_app_chatmessage" (...)
# CREATE INDEX chat_group_ts_idx ON ...
# COMMIT;
```

### `runserver` — the dev server

```bash
python manage.py runserver           # localhost:8000
python manage.py runserver 0.0.0.0:8001  # reachable on the network
```

!!! danger "Development only"
    `runserver` is a dev server: it is multithreaded by default (`--nothreading` turns that off), but it has no SSL, no buffering, and no security or performance hardening. In production use only Uvicorn or Gunicorn + nginx.

### `shell` — interactive ORM

```bash
python manage.py shell
```

```python
>>> from notes_app.models import Note
>>> from django.contrib.auth.models import User
>>> user = User.objects.get(username='demo_alice')
>>> notes = Note.objects.filter(user=user)
>>> notes.count()
5
>>> qs = notes.select_related('notebook')
>>> print(qs.query)   # ← shows the SQL
```

### `check --deploy` — security audit

```bash
python manage.py check --deploy
```

It checks: `DEBUG=False`, a non-default `SECRET_KEY`, `ALLOWED_HOSTS`, HTTPS headers, cookie security.

### `collectstatic` — preparing static files

```bash
python manage.py collectstatic
```

Collects all static files into `STATIC_ROOT`. In production, nginx serves them from there without Django.

---

## Custom command — `seed_demo_data`

Full implementation from `notes_app/management/commands/seed_demo_data.py`:

```python
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User, Group
from notes_app.models import Note, Tag, Notebook

class Command(BaseCommand):
    help = 'Seed demo data (users, groups, notes, todos, chats)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--reset',
            action='store_true',
            help='Delete existing demo data before seeding',
        )

    def handle(self, *args, **options):
        if options['reset']:
            self.stdout.write('Resetting demo data...')
            User.objects.filter(username__startswith='demo_').delete()

        # get_or_create → safe to run repeatedly
        alice, created = User.objects.get_or_create(
            username='demo_alice',
            defaults={'email': 'alice@demo.com'}
        )
        if created:
            alice.set_password('demo1234')
            alice.save()
            self.stdout.write(self.style.SUCCESS('✓ Created user: demo_alice'))
        else:
            self.stdout.write('  User demo_alice already exists, skipping')

        # Demo notes
        notebook, _ = Notebook.objects.get_or_create(
            user=alice, title='Мої нотатки', defaults={'is_default': True}
        )
        Note.objects.get_or_create(
            user=alice, title='Перша нотатка',
            defaults={
                'content': 'Привіт! Це демо-нотатка.',
                'notebook': notebook,
                'priority': Note.PRIORITY_MEDIUM,
            }
        )

        self.stdout.write(self.style.SUCCESS('Seeding complete!'))
```

**Key parts:**
- `BaseCommand` — the base class; provides `stdout`, `style`, `add_arguments`, `handle`
- `add_arguments` — command-line arguments (`--reset`)
- `handle` — all of the command's logic runs here
- `self.style.SUCCESS(...)` — green text in the output
- `get_or_create` — an idempotent operation (safe to run repeatedly)

---

## Running in Docker

```bash
# One-off container
docker compose run --rm web python manage.py seed_demo_data

# With an argument
docker compose run --rm web python manage.py seed_demo_data --reset

# In an already running container (exec, not run)
docker compose exec web python manage.py showmigrations
docker compose exec web python manage.py shell

# Configuration check
docker compose exec web python manage.py check
```

---

## Full lifecycle — from zero to production

```
Step 1: Initialization
  django-admin startproject notes_project
  python manage.py startapp notes_app
  # Add 'notes_app' to INSTALLED_APPS

Step 2: Models → DB
  # Write models.py
  python manage.py makemigrations
  python manage.py migrate

Step 3: The first admin
  python manage.py createsuperuser

Step 4: Development
  python manage.py runserver
  # Change models.py → makemigrations → migrate
  # Write views.py, urls.py, templates/

Step 5: Before deployment
  python manage.py check --deploy
  python manage.py collectstatic
  python manage.py test
```

---

## Common mistakes

| Error | Cause | Fix |
|---------|---------|---------|
| `No module named 'notes_app'` | Not in `INSTALLED_APPS` | Add `'notes_app'` to `INSTALLED_APPS` |
| `Table doesn't exist` | `migrate` was not run | `python manage.py migrate` |
| `InconsistentMigrationHistory` | A migration file was deleted after `migrate` | Restore the file or use `migrate --fake` |
| `Address already in use` | Port 8000/8001 is taken | `docker compose down` or change the port |
| `Non-nullable field` | You added a field without `default` | Add `default=` or `null=True` |
| `AppRegistryNotReady` | You import models before Django is initialized | Check the import order in `asgi.py` |

---

## In the book

- [Part X. Linux and DevOps](../10_linux_and_devops/README.md) — Docker, entrypoint.sh
- [Step 9. Deployment → Seed data](../tutorials/09_deployment/seed_data.md) — seeding in production

---

## Official documentation

- [Django: Writing custom management commands](https://docs.djangoproject.com/en/5.2/howto/custom-management-commands/) — the full API
- [Django: django-admin and manage.py](https://docs.djangoproject.com/en/5.2/ref/django-admin/) — all built-in commands
