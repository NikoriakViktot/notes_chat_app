# Environment and first run

> **Python and Django compatibility:**
>
> | Python | Django | Note |
> |--------|--------|----------|
> | 3.10 – 3.13 | 5.1.x or 5.2.x | A stable pair |
> | 3.14+ | 5.2+ only | 5.1 does not support Python 3.14 |
> | 3.9 | 4.2.x (LTS) | Old, but still supported |
>
> Check: `python --version`

---

## Step 1 — Virtual Environment

A virtual environment is an isolated Python environment.
The packages you install into it do not affect other projects or the system Python.

```bash
# Create a venv in the current folder
python -m venv venv
```

After this, a `venv/` folder appears.

### Activation

```bash
# Linux / macOS
source venv/bin/activate

# Windows PowerShell
venv\Scripts\Activate.ps1

# Windows Command Prompt
venv\Scripts\activate.bat
```

After activation, `(venv)` appears in the terminal prompt:
```
(venv) ~/projects/hello_django $
```

> **Activate it every time** you open a new terminal in the project.
> Forgot to activate it? `pip install django` will install into the system Python → version conflicts.

```bash
# Deactivate (return to the system Python):
deactivate

# Check that the right Python is being used:
which python    # macOS/Linux → should be .../venv/bin/python
where python    # Windows
```

---

## Step 2 — Install Django

```bash
# Upgrade pip (recommended)
python -m pip install --upgrade pip

# Install Django (latest stable)
pip install django

# Or a specific version:
pip install django==5.2.2
```

```bash
# Save the dependencies to requirements.txt
pip freeze > requirements.txt

# Install from requirements.txt (for another developer):
pip install -r requirements.txt
```

Check the installation:
```bash
python -m django --version
# → 5.2.2
```

---

## Step 3 — Create the project

```bash
django-admin startproject hello_project .
```

> **The dot `.` at the end is required!**
>
> With the dot: `hello_project/` and `manage.py` are in the current folder ✓
> Without the dot: Django creates `hello_project/hello_project/` → unnecessary nesting ✗

Result:
```
./
├── hello_project/
│   ├── __init__.py
│   ├── settings.py   ← configuration
│   ├── urls.py       ← main router
│   ├── asgi.py       ← for uvicorn/daphne
│   └── wsgi.py       ← for gunicorn
└── manage.py         ← CLI orchestrator
```

Check that the server starts:
```bash
python manage.py runserver
```

---

## Step 4 — Apply migrations

```bash
python manage.py migrate
```

Django includes built-in apps (`django.contrib.auth`, `django.contrib.admin` etc.).
Each of them has tables in the database. `migrate` creates these tables in `db.sqlite3`.

Command output:
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK
  Applying auth.0001_initial... OK
  Applying admin.0001_initial... OK
  Applying sessions.0001_initial... OK
```

### Tables Django creates automatically

| Table | What it stores |
|---------|-------------|
| `auth_user` | Users: username, password (PBKDF2+SHA256 hash), email, is_staff, is_superuser |
| `auth_group` | Groups/roles: name |
| `auth_permission` | Permissions: name + model (`add_note`, `change_note`, `delete_note`, `view_note`) |
| `auth_user_groups` | M:N: user ↔ group |
| `auth_user_user_permissions` | M:N: user ↔ permission |
| `django_session` | Sessions (the `sessionid` cookie → a DB record) |
| `django_admin_log` | Log of actions in the admin panel (who changed what and when) |
| `django_migrations` | Which migrations have already been applied (so they are not repeated) |
| `django_content_type` | Registry of all models (for generic FKs) |

> **Without `migrate`, the admin panel crashes:**
> `OperationalError: no such table: auth_user`

---

## Step 5 — Create a superuser

```bash
python manage.py createsuperuser
```

Django will ask:
```
Username (leave blank to use 'niko'): admin
Email address: admin@example.com
Password:
Password (again):
Superuser created successfully.
```

### User types in Django

```
Superuser  → is_superuser=True, is_staff=True
             All permissions automatically.
             Bypasses permission checks.
             Access to /admin/ and all objects.

Staff user → is_staff=True, is_superuser=False
             Can log in to /admin/, but only with assigned permissions.
             Does not see models without explicit permissions.

Regular    → is_staff=False, is_superuser=False
             An ordinary user. No access to /admin/.
             Can use the application's frontend.
```

Check in the browser:
- `http://localhost:8000/` → the Django start page (the rocket)
- `http://localhost:8000/admin/` → the admin panel; enter the login from this step

---

## Step 6 — Create an app

A Django project consists of one or more **apps**.
Each app is responsible for a specific part of the functionality.

```bash
python manage.py startapp hello_app
```

This command creates:
```
hello_app/
├── __init__.py
├── admin.py        ← Registering models for Django Admin
├── apps.py         ← HelloAppConfig — the app configuration
├── models.py       ← Models (empty)
├── tests.py        ← Tests
├── views.py        ← View functions (empty)
└── migrations/
    └── __init__.py
```

Register the app in `hello_project/settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'hello_app',    # ← ADD THIS LINE
]
```

> **Why do you need to register it?**
> Django knows about an app only if it is in `INSTALLED_APPS`.
> Without this:
> - Django does not look for templates in `hello_app/templates/`
> - `python manage.py makemigrations` ignores `hello_app/models.py`
> - Django Admin does not know about the models from `hello_app/`
> - management commands from `hello_app/management/` are not available

---

## All commands in order

```bash
# 1. Create and activate a venv
python -m venv venv
source venv/bin/activate      # Linux/Mac
# or: venv\Scripts\activate  # Windows

# 2. Install Django
pip install -r requirements.txt
# or: pip install django

# 3. Create the project (the dot matters!)
django-admin startproject hello_project .

# 4. Apply the initial migrations
python manage.py migrate

# 5. Create an administrator
python manage.py createsuperuser

# 6. Check the admin panel
python manage.py runserver
# → http://localhost:8000/admin/

# 7. Create an app
python manage.py startapp hello_app
# (next, we edit the files by hand — on the following pages)
```
