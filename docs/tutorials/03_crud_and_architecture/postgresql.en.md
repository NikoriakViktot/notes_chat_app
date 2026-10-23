# PostgreSQL

> Moving from SQLite to PostgreSQL is an important step before production.
> SQLite is ideal for development, but PostgreSQL provides: concurrent access, extended field types, ACID transactions with isolation levels, and performance with large volumes of data.

---

## 10.1 Running PostgreSQL with Docker

```bash
# Run with docker-compose:
docker-compose up -d

# Or directly with docker run:
docker run -d \
  --name notes_postgres \
  -e POSTGRES_DB=notes_db \
  -e POSTGRES_USER=notes_user \
  -e POSTGRES_PASSWORD=notes_pass \
  -p 5432:5432 \
  postgres:16-alpine
```

```yaml
# docker-compose.yml
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: notes_db
      POSTGRES_USER: notes_user
      POSTGRES_PASSWORD: notes_pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
volumes:
  postgres_data:
```

---

## 10.2 Configuring Django

```bash
pip install psycopg2-binary python-decouple
```

```python
# settings.py — after switching to PostgreSQL
from decouple import config

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='notes_db'),
        'USER': config('DB_USER', default='notes_user'),
        'PASSWORD': config('DB_PASSWORD', default='notes_pass'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
        'CONN_MAX_AGE': 60,  # keep the connection open between requests
    }
}
```

```
# .env (never commit it!)
DB_NAME=notes_db
DB_USER=notes_user
DB_PASSWORD=notes_pass
DB_HOST=localhost
DB_PORT=5432
```

After changing settings.py, run the migrations on the new DB:

```bash
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

---

## 10.3 Moving data from SQLite

```bash
# Step 1: Dump from SQLite (while it is still connected)
python manage.py dumpdata \
  --natural-foreign --natural-primary \
  --exclude=contenttypes --exclude=auth.permission \
  --indent=2 > data_backup.json

# Step 2: Switch settings.py to PostgreSQL

# Step 3: Migrations into the new DB
python manage.py migrate

# Step 4: Load the data
python manage.py loaddata data_backup.json

# Step 5: Verify
python manage.py shell -c "from hello_app.models import Note; print(f'Notes: {Note.objects.count()}')"
```

---

## 10.4 PostgreSQL-specific fields

After switching to PostgreSQL, unique field types become available:

```python
# PostgreSQL only — ArrayField, JSONField with full capabilities
from django.contrib.postgres.fields import ArrayField

class Note(models.Model):
    # An array of tags in a column (an alternative to M:N for simple scenarios)
    quick_labels = ArrayField(
        models.CharField(max_length=30),
        blank=True, default=list
    )
    # metadata as JSON (does not need a separate table)
    metadata = models.JSONField(default=dict, blank=True)

# Filtering by JSON/Array:
Note.objects.filter(quick_labels__contains=['python'])
Note.objects.filter(metadata__word_count__gte=100)
Note.objects.filter(metadata__language='uk')
```

### Comparing SQLite vs PostgreSQL

| Property | SQLite | PostgreSQL |
|-------------|--------|------------|
| Concurrent writes | Locks the whole DB | Row-level locking |
| `select_for_update()` | Not fully supported | Full support |
| ArrayField | Not available | Available |
| JSONField | Basic (string) | Full JSONB |
| Full-text search | Limited | `SearchVector`, `SearchQuery` |
| Triggers | Limited | Full support |
| Data volume | Up to ~1 GB | No practical limits |
| Setup | Nothing | Docker or a cloud service |

---

## Project file structure

```
notes_project/
├── notes_project/              ← Django project config
│   ├── settings.py             ← DATABASES, INSTALLED_APPS, AUTH
│   ├── urls.py                 ← root URL router
│   └── wsgi.py / asgi.py       ← production entry point
│
├── hello_app/                  ← Django application
│   ├── models.py               ← 9 models (UserProfile, Tag, Notebook, Note,
│   │                             Reminder, TodoList, TodoItem, ShoppingList, ShopItem)
│   ├── selectors.py            ← ALL SELECT queries here (reads)
│   ├── services.py             ← ALL business logic here (writes/changes)
│   ├── views.py                ← ONLY HTTP: parse request → selector/service → render
│   ├── forms.py                ← Django Forms for input validation
│   ├── admin.py                ← admin panel registration (with select_related)
│   ├── urls.py                 ← app URL routes
│   └── migrations/
│       ├── 0001_initial.py           ← initial Note model
│       └── 0002_extended_models.py   ← all extended models
│
├── hello_app/templates/hello_app/
│   ├── note_list.html          ← note list + sidebar filters
│   ├── note_detail.html        ← note detail + reminders
│   ├── note_form.html          ← create/edit form
│   └── note_confirm_delete.html ← delete confirmation page
│
├── templates/
│   └── base.html               ← base template (Bootstrap navbar, messages)
│
├── manage.py
├── requirements.txt            ← Django, psycopg2-binary, python-decouple
├── docker-compose.yml          ← PostgreSQL in Docker
└── .env                        ← secrets (never commit it!)
```

---

## Navigation

- Previous: [QuerySet in depth](queryset_deep.md)
- Next: [Class-Based Views](cbv.md)
