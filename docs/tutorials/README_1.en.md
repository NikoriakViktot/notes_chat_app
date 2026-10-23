# My first Django project — Hello, Django!

A step-by-step guide for absolute beginners.
We will create a minimal site that shows the text **"Hello, Django!"** in the browser
and has a fully functional **admin panel**.

 **Python and Django compatibility:**
> | Python | Django |
> |--------|--------|
> | 3.10 – 3.13 | 5.1.x or 5.2.x |
> | **3.14** | **5.2+ only** (5.1 does not support Python 3.14) |
>
> Check your version: `python --version`
> If you have Python 3.14, `requirements.txt` is already configured correctly (`Django>=5.2`).

---

## What you will get in the end

```
http://localhost:8000/        →  Hello, Django!
http://localhost:8000/about/  →  This is my first Django page!
http://localhost:8000/admin/  →  Admin panel (superuser login)
```

---

## Final project structure

```
simple_django_project/        ← you are here now
├── venv/                     ← virtual environment (do not touch this folder)
├── db.sqlite3                ← SQLite database (appears after migrate)
├── hello_project/            ← Django settings package (settings, urls)
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── hello_app/                ← our application (views, urls)
│   ├── __init__.py
│   ├── views.py              ← this is WHERE we write handler functions
│   └── urls.py               ← this is WHERE we define the app's routes
├── manage.py                 ← CLI orchestrator
└── requirements.txt          ← this file already exists
```

---

## Step-by-step instructions

> **All commands are run from the `simple_django_project/` folder**
>
> Check where you are: the `pwd` command (Linux/Mac) or `cd` (Windows)

---

### Step 1 — Open a terminal in this folder

**PyCharm:**
`View → Tool Windows → Terminal` — opens a terminal already in the project folder.

**A regular terminal** (from the root of the `PY-Course-Victor-Nikoriak-23_02` repository):
```
cd module_5\lesson_Django_Network_Architecture\simple_django_project
```

---

### Step 2 — Create a virtual environment

A virtual environment is an isolated Python environment.
Packages you install here do not affect other projects.

```bash
python -m venv venv
```

After this, a `venv/` folder will appear.

---

### Step 3 — Activate the virtual environment

> You need to activate it **every time** you open a new terminal!

**Windows (Command Prompt):**
```
venv\Scripts\activate
```

**Windows (PowerShell):**
```
venv\Scripts\Activate.ps1
```

**Linux / Mac:**
```bash
source venv/bin/activate
```

After activation, `(venv)` will appear in the terminal prompt:
```
(venv) C:\...\simple_django_project>
```

---

### Step 4 — Install Django

upgrade pip
```bash
python -m pip install --upgrade pip
```
install the dependencies
```bash
pip install -r requirements.txt
```
or

```bash
python -m pip install -r requirements.txt
```


Check that Django was installed:
```bash
python -m django --version
```
It should show: `5.2.x` (if Python 3.14) or `5.1.x` / `5.2.x` (if Python 3.10–3.13)

If Django is already installed and you need to **upgrade** to 5.2:
```bash
pip install -r requirements.txt --upgrade
```

---

### Step 5 — Create a Django project

```bash
django-admin startproject hello_project .
```

> **The dot `.` at the end is required!**
> It means "create in the current folder".
> Without the dot, Django will create an extra nested directory.

After this command, the following will appear:
```
simple_django_project/
├── hello_project/    ← new settings package
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── manage.py         ← new file
```

### Step 5.1 — Check that the server starts

```bash
python manage.py runserver
```

---

### Step 6 — Apply migrations (create tables in the DB)

```bash
python manage.py migrate
```

> **What does this do?**
> Django includes built-in applications (`django.contrib.auth`, `django.contrib.admin`, etc.).
> Each of them has its own tables in the database.
> `migrate` creates these tables in the `db.sqlite3` file.
>
> **WITHOUT this step, the admin panel will crash with the error:**
> `OperationalError: no such table: auth_user`

After it runs, a `db.sqlite3` file will appear, and in the terminal you will see:
```
Applying auth.0001_initial... OK
Applying admin.0001_initial... OK
...
```

---

### Step 7 — Create administrator credentials

```bash
python manage.py createsuperuser
```

Django will ask:
```
Username: admin
Email address: (you can leave it empty, press Enter)
Password: ****
Password (again): ****
Superuser created successfully.
```

> This username/password is used to log in to the admin panel
> at `http://localhost:8000/admin/`

---

### Step 8 — Check that the server and admin start

```bash
python manage.py runserver
```

Open the browser:
- **http://localhost:8000/** → Django start page (the rocket)
- **http://localhost:8000/admin/** → admin panel, enter the login from Step 7

if there are problems, check whether port 8000 on your machine is taken by other applications.

Stop the server: `Ctrl + C`

---

### Step 9 — Create an application

A Django project consists of one or more **applications** (apps).
Each application is responsible for a certain part of the functionality.

```bash
python manage.py startapp hello_app
```

A `hello_app/` folder with automatically generated files will appear.

---

### Step 10 — Register the application in settings.py

Open the `hello_project/settings.py` file.

Find the `INSTALLED_APPS` list and add `'hello_app'` at the end:

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

> **Why is this important?**
> Django knows about an application only if it is in `INSTALLED_APPS`.
> Without this, Django will not look for views, templates and commands in `hello_app/`.

---

### Step 11 — Write your first view functions

Open the `hello_app/views.py` file.

Instead of its current contents, write:

```python
from django.http import HttpResponse


def index(request):
    """Home page — returns a simple text message."""
    return HttpResponse("Hello, Django!")


def about(request):
    """The 'About us' page."""
    return HttpResponse("This is my first Django page!")
```

> **What is a view function?**
> - It accepts `request` (the HTTP request from the browser)
> - Performs some logic
> - Returns an `HttpResponse` (the response to the browser)
>
> `HttpResponse("text")` is the simplest response: just text.

---

### Step 12 — Create URL routes for the application

Create a **new file** `hello_app/urls.py` and write in it:

```python
from django.urls import path
from . import views

# app_name — required if namespace= is specified in the main urls.py
# Lets you refer to routes as: 'hello_app:index', 'hello_app:about'
app_name = "hello_app"

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
]
```

> **What is happening here?**
> - `app_name = "hello_app"` — the namespace name of this application
> - `path('', views.index)` — a request to `/` → calls `views.index`
> - `path('about/', views.about)` — a request to `/about/` → calls `views.about`
> - `name='index'` — the route name inside the namespace

---

### Step 13 — Connect the routes to the main urls.py

Open `hello_project/urls.py`.

It currently looks like this:
```python
from django.contrib import admin
from django.urls import path

urlpatterns = [
    path('admin/', admin.site.urls),
]
```

Replace it with:
```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),  # ← ADD THIS LINE
]
```

> **What is `include()`?**
> `include('hello_app.urls')` tells Django:
> "for this URL prefix, read the routes from the `hello_app/urls.py` file".
>
> `namespace='hello_app'` isolates the route names of this application.
> It **requires** `app_name = "hello_app"` in `hello_app/urls.py` — otherwise Django fails with `ImproperlyConfigured`.

---

### Step 14 — Run the server and check the result

```bash
python manage.py runserver
```

Open the browser:

| URL | Result |
|-----|-----------|
| http://localhost:8000/ | `Hello, Django!` |
| http://localhost:8000/about/ | `This is my first Django page!` |
| http://localhost:8000/admin/ | Admin panel — enter the login from Step 7 |

**Congratulations! Your first Django site with an admin panel works!** 🎉

---

## The Django admin panel — a full explanation

### What it is

Django Admin is an **automatically generated web interface** for managing data in the database.
It is built into Django and available right after `migrate` + `createsuperuser`.

It is not a "separate project" — it is a regular Django application, `django.contrib.admin`,
with its own models, views and templates. It is included in `INSTALLED_APPS` in `settings.py`.

```
http://127.0.0.1:8000/admin/               ← home page (list of sections)
http://127.0.0.1:8000/admin/auth/user/     ← list of users
http://127.0.0.1:8000/admin/auth/user/add/ ← create a new user
http://127.0.0.1:8000/admin/auth/group/    ← list of groups (roles)
```

---

### Where the data is stored

In plain Django (without configuring PostgreSQL), the data is stored in the **`db.sqlite3`** file.

```
simple_django_project/
└── db.sqlite3    ← this is the entire database (a single file!)
```

SQLite is an embedded database that does not need a separate server.
The file is created automatically by the `python manage.py migrate` command.

**Tables Django creates in db.sqlite3:**

| Table | What it stores |
|---------|-------------|
| `auth_user` | Users: username, password (hash), email, is_staff, is_superuser |
| `auth_group` | Groups/roles: group name |
| `auth_permission` | Permissions: name + which model it belongs to |
| `auth_user_groups` | Relationship: which user is in which group |
| `auth_user_user_permissions` | Relationship: a user's individual permissions |
| `django_session` | Sessions: who is logged in (cookie → record in the DB) |
| `django_admin_log` | Log of actions in the admin panel (who changed what) |
| `django_content_type` | Registry of content types (for the permission system) |
| `django_migrations` | Which migrations have already been applied |

You can view the raw data with any SQLite viewer (for example, DB Browser for SQLite).

---

### The Users section — http://127.0.0.1:8000/admin/auth/user/

A list of all users in the system. Each user has:

| Field | What it means |
|------|------------|
| **Username** | Login name |
| **Email** | Email address (optional) |
| **Password** | Stored as a hash (PBKDF2+SHA256) — never stored in plain text |
| **First/Last name** | First name and last name |
| **Active** | Whether they can log in (False = blocked) |
| **Staff status** | Whether they have access to `/admin/` |
| **Superuser status** | Whether they have ALL permissions (bypasses permission checks) |
| **Groups** | Which groups (roles) are assigned |
| **User permissions** | Individual permissions (on top of group ones) |

**User types:**

```
Superuser  → is_superuser=True → all permissions, no restrictions
Staff user → is_staff=True     → access to /admin/, but only with the assigned permissions
Regular    → both False         → no access to /admin/
```

You created a superuser with the `python manage.py createsuperuser` command — it has all permissions.

---

### The Groups section — http://127.0.0.1:8000/admin/auth/group/

**A group = a named set of permissions (a role).**

Instead of assigning permissions to each user separately,
you create a group "Editors" with the required permissions and add people to it.

**An example of real usage:**

```
Group "News editors"
    ✅ news.add_article    ← can create articles
    ✅ news.change_article ← can edit articles
    ❌ news.delete_article ← can NOT delete
    ❌ news.view_user      ← does NOT see users

Group "Moderators"
    ✅ news.delete_article ← can delete
    ✅ auth.view_user      ← sees the list of users
```

When you add a user to a group, they automatically get all of its permissions.

**Django permission format:** `<app>.<action>_<model>`

```
news.add_article      ← add articles
news.change_article   ← edit articles
news.delete_article   ← delete articles
news.view_article     ← view articles
auth.add_user         ← add users
```

Django automatically generates 4 permissions for **each** model (`add`, `change`, `delete`, `view`).

---

### Action log (django_admin_log)

Every action in the admin panel is logged automatically:

```
http://127.0.0.1:8000/admin/ → Recent actions (right column)
```

It is stored in the `django_admin_log` table:
- who performed the action (user)
- what they did (added / changed / deleted)
- which object (content_type + object_id)
- when (action_time)

---

### How to add your own models to the admin

For your models (for example `Article`) to appear in the admin panel,
you need to register them in `hello_app/admin.py`:

```python
from django.contrib import admin
from .models import Article  # import the model

# The simple option — a single line
admin.site.register(Article)
```

After this, the `/admin/hello_app/article/` section with automatic CRUD will appear.

---

### SQLite vs PostgreSQL

| | SQLite (default) | PostgreSQL |
|-|--------------------------|-----------|
| **Startup** | Nothing needed, it is a file | Separate server |
| **Where the file is** | `db.sqlite3` in the project folder | On the DB server |
| **Suitable for** | Development, learning, prototypes | Production |
| **Concurrent writes** | Locks the file | Full concurrency |
| **Configuration in settings.py** | `'ENGINE': 'django.db.backends.sqlite3'` | `'ENGINE': 'django.db.backends.postgresql'` |

In the `news_portal/` project, PostgreSQL is already configured via Docker.

---

## Summary: all commands in order

```bash
# 1. Go to the folder
cd module_5\lesson_Django_Network_Architecture\simple_django_project

# 2. Create and activate venv
python -m venv venv
venv\Scripts\activate

# 3. Install Django
pip install -r requirements.txt

# 4. Create the project
django-admin startproject hello_project .

# 5. Apply migrations (creates db.sqlite3 with tables)
python manage.py migrate

# 6. Create an administrator
python manage.py createsuperuser

# 7. Check the admin panel
python manage.py runserver
# → http://localhost:8000/admin/

# 8. Create the application
python manage.py startapp hello_app
# (then we edit the files manually — steps 10–13)

# 9. Final run
python manage.py runserver
```

---

## What you did (changes in files)

| File | What you did |
|------|-------------|
| `hello_project/settings.py` | Added `'hello_app'` to `INSTALLED_APPS` |
| `hello_app/views.py` | Wrote the `index()` and `about()` functions |
| `hello_app/urls.py` | Created the file with `app_name` and routes |
| `hello_project/urls.py` | Connected the routes via `include()` |

---

## Common beginner mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `AttributeError: 'super' object has no attribute 'dicts'` | Python 3.14 is incompatible with Django 5.1 | `pip install -r requirements.txt --upgrade` (installs Django 5.2+) |
| `OperationalError: no such table: auth_user` | Migrations were not run | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | venv is not activated or Django is not installed | Activate venv → `pip install -r requirements.txt` |
| `Page not found (404)` | The route is not registered | Check `urls.py` in both files |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` is in `include()`, but `app_name` is missing in `hello_app/urls.py` | Add `app_name = "hello_app"` to `hello_app/urls.py` |
| `NameError: name 'Note' is not defined` | `views.py` does not import the model | Add `from .models import Note` to `views.py` |
| `ImportError` in urls.py | Error in `from . import views` | Check that `views.py` exists in `hello_app/` |
| Django does not see `hello_app` | Not added to `INSTALLED_APPS` | Add `'hello_app'` to `settings.py` |
| The server does not stop | — | Press `Ctrl + C` in the terminal |

---

## Next steps

This project uses the simplest option: `HttpResponse` with text.
A real Django project uses **templates** (HTML files):

```python
# Instead of HttpResponse("text")
return render(request, 'hello_app/index.html', {'name': 'Dmytro'})
```

The full architecture with templates, models and a database is in the `news_portal/` project.

---

## Bonus: create your first model

Let's add a simple `Note` model — to understand how the Django ORM connects
a Python class with a database table.

### What we will get

```
http://127.0.0.1:8000/admin/hello_app/note/     ← list of notes
http://127.0.0.1:8000/admin/hello_app/note/add/ ← create a note
```

---

### Step B1 — Describe the model in models.py

Open `hello_app/models.py` and write:

```python
from django.db import models


class Note(models.Model):
    """
    Model = a Python class that describes a database table.

    The Django ORM automatically:
        - creates the 'hello_app_note' table in db.sqlite3
        - generates the id field (PRIMARY KEY AUTOINCREMENT) automatically
        - provides an API: Note.objects.all(), Note.objects.create(...) etc.
    """

    # CharField → VARCHAR in SQL, limited string length
    title = models.CharField(
        max_length=200,          # maximum 200 characters
        verbose_name='Title'     # field name in the admin panel
    )

    # TextField → TEXT in SQL, unlimited text
    content = models.TextField(
        blank=True,              # the field is optional in the form
        verbose_name='Text'
    )

    # DateTimeField with auto_now_add=True → TIMESTAMP
    # automatically records the creation time of the record
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Created'
    )

    def __str__(self):
        # This is the string representation of the object.
        # Displayed in the admin panel instead of "Note object (1)"
        return self.title

    class Meta:
        verbose_name = 'Note'
        verbose_name_plural = 'Notes'
        ordering = ['-created_at']  # newest notes first
```

---

### Step B2 — Register the model in the admin panel

Open `hello_app/admin.py` and write:

```python
from django.contrib import admin
from .models import Note  # import our model


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    # Which columns to show in the list table
    list_display = ('title', 'created_at')

    # Fields for the search box
    search_fields = ('title', 'content')
```

---

### Step B3 — Generate a migration

```bash
python manage.py makemigrations
```

Django compares `models.py` with the current DB state and generates a file with the changes:

```
Migrations for 'hello_app':
  hello_app/migrations/0001_initial.py
    + Create model Note
```

> **What was created?**
> The `hello_app/migrations/0001_initial.py` file is a Python script
> that describes the SQL that needs to be executed.
> It is generated automatically and does not need editing.

---

### Step B4 — Apply the migration to the database

```bash
python manage.py migrate
```

```
Applying hello_app.0001_initial... OK
```

Now the `hello_app_note` table has appeared in `db.sqlite3`:

```sql
-- What Django executed for you:
CREATE TABLE "hello_app_note" (
    "id"         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title"      VARCHAR(200) NOT NULL,
    "content"    TEXT NOT NULL,
    "created_at" DATETIME NOT NULL
);
```

---

### Step B5 — Check in the browser

```bash
python manage.py runserver
```

Open `http://127.0.0.1:8000/admin/` — a new section **"Notes"** has appeared.

1. Click **"Add note"**
2. Enter a title and text
3. Click **Save**
4. The note is saved in `db.sqlite3` → the `hello_app_note` table

---

### What happened under the hood

```
models.py (Python class)
    ↓  python manage.py makemigrations
hello_app/migrations/0001_initial.py  (plan of changes)
    ↓  python manage.py migrate
db.sqlite3 → hello_app_note table  (the real DB)
    ↓  admin.site.register(Note)
http://127.0.0.1:8000/admin/hello_app/note/  (web interface)
```

**Rule:** after any change to `models.py`, always do two steps:
```bash
python manage.py makemigrations   # record the plan
python manage.py migrate          # apply it to the DB
```

---

### Django ORM — basic queries against the model

After you create a model, Django gives you a full API for working with data.
Try it in the Django shell:

```bash
python manage.py shell
```

```python
from hello_app.models import Note

# Create a note
Note.objects.create(title="First note", content="Hello Django!")

# Get all notes
Note.objects.all()
# → <QuerySet [<Note: First note>]>

# Filter
Note.objects.filter(title="First note")

# Count
Note.objects.count()
# → 1

# Get one
note = Note.objects.get(id=1)
note.title
# → 'First note'

# Delete
note.delete()

# Exit the shell
exit()
```

> The Django shell is a regular Python interpreter, but with Django loaded.
> Very handy for quickly testing DB queries.

---

## Bonus 2: displaying notes on a site page

The admin is for staff only. Now let's make a public page
where visitors see the list of notes.

**Route:** `http://127.0.0.1:8000/notes/` → list of all notes

The full request path:
```
Browser GET /notes/
    ↓ urls.py finds the route
    ↓ views.py gets the data from the DB via the ORM
    ↓ templates/hello_app/note_list.html renders the HTML
    ↓ HttpResponse → browser
```

---

### Step C1 — Create a folder for templates

Django looks for templates in the `<app>/templates/<app>/` folder.
This duplication (`hello_app/templates/hello_app/`) is needed to avoid
name conflicts between different applications.

The structure you need to create:

```
hello_app/
└── templates/
    └── hello_app/
        └── note_list.html    ← we will create this file below
```

**Command to create the folders:**

```bash
# Windows PowerShell
mkdir hello_app\templates\hello_app
```
```bash
# Linux / Mac
mkdir -p hello_app/templates/hello_app
```
---

### Step C2 — Create the note_list.html template

Create the file `hello_app/templates/hello_app/note_list.html`:
```text
note_list.html
```

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <title>My notes</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 40px auto; }
        .note { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 4px; }
        .date { color: #888; font-size: 0.85em; }
    </style>
</head>
<body>

    <h1>Notes</h1>

    {# if notes — check whether there are notes in the list #}
    {# 'notes' is the name of the variable passed by the view (context['notes']) #}
    {% if notes %}

        {# for note in notes — loop over each note in the list #}
        {# Django renders this block for each object #}
        {% for note in notes %}
        <div class="note">
            <!-- {{ note.title }} — outputs the value of the title field of the note object -->
            <h2>{{ note.title }}</h2>

            <!--
                {{ note.content }} — the note text.
                If content is empty, nothing is output.
            -->
            {% if note.content %}
                <p>{{ note.content }}</p>
            {% endif %}

            <!--
                {{ note.created_at|date:"d.m.Y H:i" }}
                |date:"format" — a filter for formatting the date
            -->
            <p class="date">{{ note.created_at|date:"d.m.Y H:i" }}</p>
        </div>
        {% endfor %}

    {% else %}
        <!-- Shown if there are no notes -->
        <p>No notes yet.
           <a href="/admin/hello_app/note/add/">Add one in the admin panel →</a>
        </p>
    {% endif %}

    <hr>
    <a href="/admin/">← Admin panel</a>

</body>
</html>
```

---

### Step C3 — Add a view function to views.py

Open `hello_app/views.py` and **add** a new function (do not replace the existing ones):

```python
from django.http import HttpResponse
from django.shortcuts import render   # ← add render to the import
from .models import Note              # ← import the model


def index(request):
    """Home page."""
    return HttpResponse("Hello, Django!")


def about(request):
    """The 'About us' page."""
    return HttpResponse("This is my first Django page!")

def note_list(request):
    """
    Page with the list of notes.

    What happens:
    1. Note.objects.all() — runs SELECT * FROM hello_app_note ORDER BY created_at DESC
       (the DESC order is set in class Meta: ordering = ['-created_at'])
    2. render() — takes the template, fills in the data (context) and returns HTML
    """

    # ORM query: get all notes from the DB
    # The result is a QuerySet: a lazy list of Note objects
    notes = Note.objects.all()

    # context — a dictionary of data we pass to the template
    # Key 'notes' → in the template: {{ notes }}, {% for note in notes %}
    context = {
        'notes': notes,
    }

    # render(request, 'path/to/template', context)
    # Django looks for the template in hello_app/templates/hello_app/note_list.html
    return render(request, 'hello_app/note_list.html', context)
```


---

### Step C4 — Add a URL route to hello_app/urls.py

Open `hello_app/urls.py` and add a new route:

```python
from django.urls import path
from . import views

app_name = "hello_app"

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
    path('notes/', views.note_list, name='note_list'),   # ← ADD THIS LINE
]
```
```python
    path('notes/', views.note_list, name='note_list'),
```


> `path('notes/', views.note_list)` — a request to `/notes/` → calls `views.note_list`

---

### Step C5 — Check in the browser

```bash
python manage.py runserver
```

| URL | Result |
|-----|-----------|
| http://127.0.0.1:8000/notes/ | List of notes with styles |
| http://127.0.0.1:8000/admin/hello_app/note/add/ | Add a note via the admin |

**Add a few notes via the admin → refresh `/notes/` — they will appear on the page.**

---

### Final structure after all the bonuses

```
simple_django_project/
├── db.sqlite3
├── manage.py
├── requirements.txt
├── hello_project/
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── hello_app/
    ├── models.py          ← Note model
    ├── views.py           ← index, about, note_list
    ├── urls.py            ← /, /about/, /notes/
    ├── admin.py           ← NoteAdmin
    ├── migrations/
    │   └── 0001_initial.py
    └── templates/
        └── hello_app/
            └── note_list.html
```

---

### The full path of the GET /notes/ request, step by step

```
1. Browser: GET http://127.0.0.1:8000/notes/

2. Django: reads ROOT_URLCONF = 'hello_project.urls'
           hello_project/urls.py → include('hello_app.urls')
           hello_app/urls.py → path('notes/', views.note_list)

3. views.note_list(request) is called:
           Note.objects.all()
           → SQL: SELECT * FROM hello_app_note ORDER BY created_at DESC
           → returns QuerySet [<Note: ...>, ...]

4. render(request, 'hello_app/note_list.html', {'notes': queryset})
           Django finds the template: hello_app/templates/hello_app/note_list.html
           Fills in the data: {% for note in notes %} → HTML lines

5. HttpResponse(HTML) → the browser renders the page
```

This is Django's **MVT architecture**:
- **M** (Model) — `Note` in `models.py` — stores the data
- **V** (View) — `note_list` in `views.py` — gets the data, decides what to show
- **T** (Template) — `note_list.html` — renders the HTML


---


## Bonus 3:  Django Debug Toolbar — Runtime Introspection for the Django ORM

### What Django Debug Toolbar is

`django-debug-toolbar` is a middleware-based debugging system for Django
that lets you see:

- SQL queries
- ORM performance
- timings
- middleware execution
- template rendering
- cache usage
- headers
- signals
- profiling information

The toolbar is added right into the browser as a floating debug panel.

---

### The architectural idea

Django Debug Toolbar is:

```text
Runtime Introspection Layer
```

That is, a system that:

- intercepts the request/response lifecycle
- listens to ORM queries
- measures performance
- shows the internal state of the Django runtime

---

### Workflow

```text
Browser Request
    ↓
Django Middleware Stack
    ↓
DebugToolbarMiddleware
    ↓
Intercept:
    - SQL
    - Templates
    - Cache
    - Signals
    - Headers
    - Timings
    ↓
Browser Debug Panel
```

---

### Why this is very important

The ORM in Django is "lazy".

For example:

```python
posts = Post.objects.all()
```

The SQL is NOT executed yet.

The toolbar lets you see:

- when the SQL was actually executed
- how many queries there were
- which joins there were
- where the N+1 problem occurs

---

### ORM → SQL Visibility

Without the toolbar:

```python
posts = Post.objects.all()
```

looks like "magic".

---

### With the toolbar

You see the real SQL:

```sql
SELECT * FROM posts;
```

---

### N+1 Problem

For example:

```python
for post in posts:
    print(post.author.name)
```

The toolbar will show:

```text
101 queries executed
```

---

### What this means

The ORM runs:

```sql
SELECT * FROM author WHERE id=...
```

for each post separately.

---

### Solution

```python
Post.objects.select_related("author")
```

---

### This is already ORM optimization engineering

The toolbar effectively teaches:

- select_related()
- prefetch_related()
- annotate()
- lazy evaluation
- query planning

---

### Installation

#### 1. Install package

```bash
pip install django-debug-toolbar
```

---

#### 2. Add to INSTALLED_APPS

```python
INSTALLED_APPS = [
    ...
    "debug_toolbar",
]
```

---

#### 3. Add middleware

```python
MIDDLEWARE = [
    ...
    "debug_toolbar.middleware.DebugToolbarMiddleware",
]
```

---

#### Middleware Order Important

The toolbar middleware should be placed:

- as early as possible
- but AFTER middleware that changes the response encoding

For example:

```python
GZipMiddleware
↓
DebugToolbarMiddleware
```

---

#### 4. Add URLs

```python
from django.urls import include, path
from debug_toolbar.toolbar import debug_toolbar_urls

urlpatterns = [
    ...
] + debug_toolbar_urls()
```

---

#### Toolbar Routes

By default:

```text
/__debug__/
```

---

#### 5. INTERNAL_IPS

The toolbar is shown only for internal IPs.

```python
INTERNAL_IPS = [
    "127.0.0.1",
]
```

---
### What the toolbar shows

#### SQL Panel

Shows:

- all SQL queries
- execution time
- duplicated queries
- stack traces

---

#### Templates Panel

Shows:

- which templates were rendered
- inheritance chain
- context variables

---

#### Cache Panel

Shows:

- cache hits
- cache misses

---

#### Headers Panel

Shows:

- request headers
- response headers

---

#### Signals Panel

Shows Django signals.

---

### The most important panel

#### SQL Panel

It is the one that makes the ORM "visible".

---

#### Lazy QuerySets

```python
posts = Post.objects.all()
```

The SQL is not executed yet.

---

### SQL trigger

The SQL is executed only when:

```python
list(posts)

for p in posts

posts[0]
```

---

### The toolbar helps you understand

```text
Python code
↓
ORM
↓
REAL SQL
↓
Database Cost
```

---

---

### Full configuration — the final state of the files

#### Step 1 — Install the package

```bash
pip install django-debug-toolbar
```

#### Step 2 — `hello_project/settings.py` — three changes

```python
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    'hello_app',
    "debug_toolbar",       # ← 1. ADD
]

MIDDLEWARE = [
    "debug_toolbar.middleware.DebugToolbarMiddleware",  # ← 2. ADD AS THE FIRST ONE
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

INTERNAL_IPS = [           # ← 3. ADD A NEW BLOCK (at the end of the file)
    "127.0.0.1",
]
```

#### Step 3 — `hello_project/urls.py`

```python
from django.contrib import admin
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls  # ← ADD THE IMPORT

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
] + debug_toolbar_urls()  # ← ADD AT THE END
```

#### Step 4 — Run the server

```bash
python manage.py runserver
```

Open `http://127.0.0.1:8000/notes/` — a black **DJDT** panel will appear on the right.

> **Important:** the toolbar is shown only on pages with full HTML
> (the `<body>` tag). The `/` and `/about/` routes return `HttpResponse("text")` without `<body>` —
> the toolbar will NOT appear there. Check on `/notes/`.

---

### Checklist — why the toolbar does not connect

| # | Check | What to check |
|---|-----------|--------------|
| 1 | Is the package installed? | `pip show django-debug-toolbar` — should show the version |
| 2 | `"debug_toolbar"` in `INSTALLED_APPS`? | settings.py |
| 3 | `DebugToolbarMiddleware` in `MIDDLEWARE`? | settings.py |
| 4 | Is `INTERNAL_IPS = ["127.0.0.1"]` present? | settings.py |
| 5 | `debug_toolbar_urls()` in urls.py? | hello_project/urls.py |
| 6 | Does the page have a `<body>` tag? | HttpResponse("text") will not work, you need a template |
| 7 | `DEBUG = True`? | settings.py — the toolbar is shown only in debug mode |
| 8 | Windows: MIME error? | Add to settings.py: `import mimetypes` + `mimetypes.add_type("application/javascript", ".js", True)` |

---

### Production Warning

Django Debug Toolbar is a DEV TOOL.

Do NOT use it in production.

---

### What is used for production

- logging
- metrics
- tracing
- APM systems

For example:

- Sentry
- Prometheus
- Grafana
- Jaeger

---

### django-silk

An alternative:

```text
django-silk
```

More profiling-oriented.

Shows:

- request history
- profiling
- timings
- SQL analysis

---

### The most important thing

The toolbar teaches:

```text
ORM ≠ magic
```

but rather:

```text
Python
↓
ORM
↓
SQL
↓
Query Planner
↓
Database Cost
```

---
