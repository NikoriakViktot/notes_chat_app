# Django Architecture — from request to response

> Django is not just a "framework". It is part of the network stack.
> This document is a general overview of Django architecture. For a detailed study of each component, see the extended documentation below.

---

## Documentation navigation

| Topic | File | What's inside |
|------|------|--------------|
| Network foundation | [network_foundation.md](../01_web_foundations/network_foundation_full.md) | IP, DNS, TCP, HTTP, HTTPS, sockets, REST |
| Network diagrams | [network_mermaid.md](../01_web_foundations/network_mermaid_full.md) | 11 Mermaid diagrams of the network stack |
| Project structure | [DJANGO_PROJECT_STRUCTURE.md](project_structure_full.md) | Every Django file with its role and common mistakes |
| Django commands | [DJANGO_COMMAND_SYSTEM.md](management_commands_full.md) | Table of all commands + lifecycle |
| Migrations | [DJANGO_MIGRATIONS.md](../03_database_and_orm/django_migrations_full.md) | makemigrations, migrate, dependency graph |
| ORM and DB | [Django_ORM.md](../03_database_and_orm/django_orm_full.md) | QuerySet API, N+1, transactions, MVCC |
| URL Routing | [Django_URL_Routing.md](url_routing_full.md) | path(), include(), GET/POST, Forms |
| Views | [Django_Views.md](views_full.md) | FBV, CBV, Generic Views, lifecycle |
| Templates | [Django_Templates.md](../05_frontend_and_templates/django_templates_full.md) | DTL, context, security, inheritance |
| Django diagrams | [django_mermaid.md](django_mermaid_full.md) | 15 Mermaid diagrams of Django architecture |
| **Services** | [DJANGO_SERVICES.md](../06_application_architecture/django_services_full.md) | Business logic: stateless functions, transactions, on_commit |
| **Selectors** | [DJANGO_SELECTORS.md](../06_application_architecture/django_selectors_full.md) | Reading data: named queries, N+1, CQRS-light |
| **Serializers** | [DJANGO_SERIALIZERS.md](../06_application_architecture/django_serializers_full.md) | Transport layer: InputSerializer, OutputSerializer |
| **Tasks** | [DJANGO_TASKS.md](../06_application_architecture/django_tasks_full.md) | Celery: broker, retry, on_commit, idempotency |
| The full picture | [DJANGO_SERVICES_SELECTORS.md](../06_application_architecture/services_selectors_full.md) | Services + Selectors + Serializers together |

---

## 1. What Django is and why it is a framework

A **framework** is not a library. A library gives you tools that you call.
A framework **calls your code** according to established rules (Inversion of Control).

Django provides:
- ready-made HTTP request handling
- an ORM for working with the database
- an authentication system
- an admin panel out of the box
- protection against XSS, CSRF, SQL injection
- a migration system

You write: **models** (DB schema), **views** (HTTP orchestration), **templates** (HTML), **services** (business logic), **selectors** (reading data). Django does everything else itself.

### Django vs Flask vs FastAPI

| Parameter | Django | Flask | FastAPI |
|----------|--------|-------|---------|
| Size | Large | Micro | Medium |
| Batteries | Included (ORM, auth, admin) | Minimal | Dependencies |
| Async | Django 3.1+ (partial) | Quart | Native |
| Development speed | High | Medium | High |
| Best suited for | Full-featured web applications | Microservices | API services |

---

## 2. MVT architecture

Django uses **MVT (Model-View-Template)** — a variant of classic MVC.

| Component | Role | MVC equivalent |
|-----------|------|-----------|
| **Model** | DB schema, relationships, ORM — no business logic | Model |
| **View** | HTTP orchestrator: validates the request, delegates to a service/selector, returns a Response | Controller |
| **Template** | HTML template for rendering | View |

> **In a production architecture**, business logic lives in `services.py` and reads live in `selectors.py`. MVT describes standard Django; for an API backend, Templates are usually replaced with DRF Serializers.

> **Key idea:** a View is not a "visual interface". A View is a Python function or class that handles a request.

### Why not MVC?

In Django, the "View" is responsible for logic (like the Controller in MVC), and the "Template" is responsible for presentation (like the View in MVC). The names are different, but the essence is the same.

---

## 3. Django project structure

```
myproject/                    ← project root
├── manage.py                 ← CLI tool
├── myproject/                ← configuration package
│   ├── __init__.py
│   ├── settings.py           ← all settings
│   ├── urls.py               ← root URL router
│   ├── wsgi.py               ← WSGI entry point
│   └── asgi.py               ← ASGI entry point
└── myapp/                    ← Django application (bounded context)
    ├── models.py             ← DB schema (structure only, no business logic)
    ├── services.py           ← Business logic (mutations, transactions, side effects)
    ├── selectors.py          ← Reading data (named queries, ORM optimizations)
    ├── serializers.py        ← Transport layer (InputSerializer, OutputSerializer)
    ├── views.py              ← HTTP orchestrator (thin, delegates to services/selectors)
    ├── urls.py               ← application URL routes
    ├── tasks.py              ← Celery tasks (transport, not logic)
    ├── filters.py            ← django-filter
    ├── permissions.py        ← DRF permissions
    ├── admin.py              ← registering models in the admin
    ├── apps.py               ← application config
    ├── templates/            ← HTML templates (for SSR)
    ├── static/               ← CSS, JS, images
    ├── tests/                ← tests
    └── migrations/           ← DB migration files
```

---

## 4. Django Request Lifecycle — step by step

Here is what happens when the request `GET /books/42/` reaches Django:

### Step 1: WSGI/ASGI receives the request

Nginx passes the HTTP bytes to uWSGI or Gunicorn. The server turns them into a Python dictionary:

```python
# WSGI environ — what Django receives
{
    'REQUEST_METHOD': 'GET',
    'PATH_INFO': '/books/42/',
    'HTTP_HOST': 'example.com',
    'HTTP_COOKIE': 'sessionid=abc123',
    'wsgi.input': <BytesIO>,  # request body
    ...
}
```

### Step 2: Middleware (inbound path — top to bottom)

Imagine that middleware is a **series of checkpoints** (or layers) that every user request passes through, one after another, before it reaches your main program.

The order of these checkpoints is critical, because one checkpoint usually depends on the results of the previous one.

Here is how it works:
1. **`SessionMiddleware`** is like a security guard who checks the visitor and pulls out their "ID ticket" (the session data).
2. **`AuthenticationMiddleware`** is like an administrator who takes that ticket, looks it up in the database, and determines **exactly who** has arrived (authenticates the user).

If the administrator (`AuthenticationMiddleware`) tries to recognize the user *before* the guard (`SessionMiddleware`) has handed out the ticket, they simply won't know whom to look for. That is why session handling must always come higher in the list.

This is configured in your project's main configuration file — `settings.py`. That file contains a special list called `MIDDLEWARE`. To add, remove, or reorder middleware, you simply edit this list, placing the dotted paths to them in the required order from top to bottom.

```python
# settings.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',      # HTTPS redirect, HSTS
    'django.contrib.sessions.middleware.SessionMiddleware', # reads the session cookie
    'django.middleware.common.CommonMiddleware',           # normalizes the URL
    'django.middleware.csrf.CsrfViewMiddleware',           # CSRF protection
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # request.user
    'django.contrib.messages.middleware.MessageMiddleware',
]
```

Each middleware receives the `request`, can modify it, or can return an `HttpResponse` immediately (breaking the chain). The order is **critical**: `AuthenticationMiddleware` must come AFTER `SessionMiddleware`, because it reads the session data.

### Step 3: URL Dispatcher

Imagine that the **URL Dispatcher (router)** is the **main mail sorting office**.

When a user enters an address (for example, `/books/42/`), this "letter" (the request) goes through the following sorting stages:

1. **The main hub (`include`)**: First, the request arrives at your main `myproject/urls.py` file. The "sorter" sees the `books/` part and says: "Aha, this goes to the books department!", forwarding the request to the `books.urls` file for further processing.
2. **The books department (`<int:pk>`)**: The `books.urls` file looks at the rest of the address — `42/`. The `<int:pk>` expression works like a smart scanner: it understands that `42` is a numeric value (the primary key, or ID, of a book), "captures" it, and passes it directly to the class-based view `BookDetailView` (wired up via `.as_view()`) so that it can fetch exactly book No. 42 from the database.

**Why is the order so important?**
The router reads your `urlpatterns` list strictly from top to bottom and stops searching at the **very first match** that fits the rule. If it reaches the end of the list and no line matches, it returns a `404 Not Found` response (page not found).


```python
# myproject/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('books/', include('books.urls')),
]

# books/urls.py
from django.urls import path
from .views import BookListView, BookDetailView

urlpatterns = [
    path('', BookListView.as_view(), name='book-list'),
    path('<int:pk>/', BookDetailView.as_view(), name='book-detail'),  # ← pk=42
]
```

Django goes through `urlpatterns` from top to bottom. The first match calls the corresponding View. If there are no matches — `404 Not Found`.

> **Note:** Django does not look for the "best" match — it takes the **first** one.

### Step 4: View — the heart of the logic

Imagine that the **View** is the **head chef** in a restaurant who has received your order from the dispatcher.

Here is what happens in this code, step by step:

1. **Receiving the order (`request, pk`):** The "chef" receives the request object and the specific number of the requested book (for example, 42), which the router has just "captured" and passed on.
2. **Querying the database (`get_object_or_404`):** The function asks the ORM to find book No. 42 in the database. If no such book exists, the function immediately returns a `404 Not Found` error (page not found) instead of crashing the program because of missing data.
3. **Building the response (`render`):** The chef takes the book that was found and the information about the current user (which the `AuthenticationMiddleware` carefully added at the first stage). He packs them into a dictionary and passes it to the HTML template (`detail.html`) for the final presentation of the page.

```python
# books/views.py
from django.shortcuts import render, get_object_or_404
from .models import Book

def book_detail(request, pk):  # function-based equivalent of BookDetailView
    # ORM: SELECT * FROM books_book WHERE id=42
    book = get_object_or_404(Book, pk=pk)
    
    # Template rendering
    return render(request, 'books/detail.html', {
        'book': book,
        'user': request.user,  # added by AuthenticationMiddleware
    })
```

### Step 5: ORM → Database

Imagine that the **ORM** is your personal **translator-assistant**.

You give it an instruction in plain Python (`Book.objects.get(pk=42)`), and it instantly translates it into the database's language — SQL.

Here is how it works under the hood:
1. **`Book.objects`** — you are addressing the database, specifically the table of books.
2. **`get(...)`** — you give the command to find strictly *only one* specific record.
3. **`pk=42`** — `pk` means "primary key". The ORM understands that it needs to find the book whose unique identifier (`id`) equals 42.

The database finds the required row and returns it. The ORM then automatically wraps that row in a convenient Python object, `book`. Now your View has all the data about the book and can pass it on to be displayed on the page.


```python
book = Book.objects.get(pk=42)
# Generates: SELECT "books_book"."id", "books_book"."title", ... 
#           FROM "books_book" WHERE "books_book"."id" = 42 LIMIT 1
```

### Step 6: Template rendering

Imagine that the **Template** is the **beautiful plating of a dish** before it is served to the customer.

The View (the head chef) has passed the "raw" data here (the `book` and `user` objects), and the template engine simply inserts them into the HTML skeleton. 

Here is exactly what happens:

1. **`{{ book.title }}` (Variables):** Double curly braces mean "output data here". Django automatically replaces this with the book's actual title.
2. **`{{ book.author.name }}` and the "N+1" trap:** This line accesses a related object (the author). If your View did not "pull" the author from the database together with the book earlier (using the `select_related` optimization), this tiny line will make Django *quietly run one more separate database query* to find out the author's name. If you display a list of 100 books, Django will make 100 extra queries (this is the well-known "N+1" problem).
3. **`{% if user.is_authenticated %}` (Logic tags):** This is the template's built-in logic. It checks the user's status (yes, the very user our administrator `AuthenticationMiddleware` recognized at the first step).
4. **`{% url 'add-to-cart' book.pk %}`:** Instead of hardcoding a link (for example, `/cart/add/42`), this tag generates the correct path itself, based on the route name from your `urls.py`. This protects the site: if you ever change the URL structure in your settings, all links in the templates will update automatically.

After this step, the fully generated HTML is packed into a response and sent back to the user's browser.


```html
<!-- books/templates/books/detail.html -->
<h1>{{ book.title }}</h1>
<p>Author: {{ book.author.name }}</p>  {# WARNING: this may be an N+1 query! #}
{% if user.is_authenticated %}
    <a href="{% url 'add-to-cart' book.pk %}">Buy</a>
{% endif %}
```

The Django Template Engine substitutes the values and automatically escapes HTML (protection against XSS).

### Step 7: Middleware (outbound path — bottom to top)
Imagine that our finished dish (the web page) is now going back to the customer. It has to pass through the same **checkpoints (middleware), but now in reverse order**.

At this stage, the middleware acts as a "packing service" before the final dispatch:

1. **Vacuum-packing (GZip):** They compress the finished page so it travels across the internet much faster.
2. **Attaching labels (`Content-Length`):** They calculate the exact size of the page and add this header so the user's browser knows exactly how much data it needs to download.
3. **Stamping the seal (Cookies/Session):** If something changed while the request was being processed (for example, the user logged in), the middleware commits these changes and asks the browser to save the updated session data or cookies.

After passing through the last middleware (the one highest in the list), the fully formed and packed response is handed to the web server, which delivers it to the browser.

> And that's the entire request lifecycle in Django!

---

## 5. Models and the ORM

Imagine that a **Model** is the blueprint of a database table, and the **ORM** is your personal translator that turns Python code into SQL queries. One class equals one table.

Here is what actually happens under the hood of your code:

**1. Field types (Fields)**
Each class attribute is a column in the database table.
*   `CharField` and `EmailField`: Create text columns. `EmailField` additionally checks whether the text is a valid email address, and `unique=True` guarantees that the database will never contain two authors with the same email.
*   `DateTimeField(auto_now_add=True)`: Django automatically records the exact date and time when the record is created; you don't need to pass this value manually.
*   `DecimalField`: A special field for financial data (prices) that preserves the precision of arithmetic operations, unlike ordinary floating-point numbers.

**2. Relationships between tables (ForeignKey)**
The line `author = models.ForeignKey(...)` creates a "one-to-many" relationship — one author can have many books.
*   `on_delete=models.CASCADE`: Protects the integrity of the database. If you delete an author, Django automatically (in a cascade) deletes all of their books so that they are not left "hanging" without an owner.
*   `related_name='books'`: This is the magic of reverse lookup. Thanks to it, you can take an author object and write `author.books.all()` to instantly get a list of all their works.

**3. Metadata (the Meta class)**
The `Meta` class contains model settings that are not table fields.
*   `ordering = ['name']`: Tells the database to always return the list of authors sorted alphabetically by default.
*   `db_table = 'library_authors'`: By default, Django would name the table `appname_author`. This parameter lets you set your own table name in the DBMS explicitly.

**4. The `__str__` method**
Instead of showing the system-generated and unhelpful `<Author object (1)>` in the admin panel, this method tells Django to display the object in a human-friendly way — simply by printing the author's name.

### Defining a model

```python
from django.db import models

class Author(models.Model):
    name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['name']
        db_table = 'library_authors'  # explicit table name
    
    def __str__(self):
        return self.name

class Book(models.Model):
    title = models.CharField(max_length=300)
    author = models.ForeignKey(Author, on_delete=models.CASCADE, related_name='books')
    published = models.DateField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_active = models.BooleanField(default=True)
```

### ORM QuerySet API
Imagine that a **QuerySet** is a smart list of instructions for the database that Django assembles but does not execute until the very last moment. 

Here is an in-depth breakdown of each stage of your code:

**1. CREATE**
The `create()` method is a convenient shortcut. Instead of creating an object in memory and then calling `save()` on it separately, `create()` does it in one step, immediately executing an SQL `INSERT` command.

**2. READ and Lazy Evaluation**
When you write `Book.objects.filter(...)`, Django does not touch the database at all. QuerySets are "lazy": they only accumulate your filters and conditions. The translation to SQL and the actual database access (`SELECT`) happen only when you start iterating over the results, for example in a `for book in books:` loop.

**3. Optimization and `select_related`**
By default, if you call `book.author.name` in a loop over 100 books, Django will make 100 additional queries to find the author of each book (this is the well-known N+1 problem). The `select_related('author')` method solves this by using an SQL `JOIN`. It fetches both the book and its author in a single, more complex query, significantly improving performance. This method is ideal for foreign key (ForeignKey) relationships.

**4. UPDATE (Bulk update)**
The `update()` method translates directly into an SQL `UPDATE` command and is applied immediately to all filtered records. This is a very efficient approach, because Django updates the data directly in the database and does not load these objects into Python's memory.

**5. DELETE**
Calling `delete()` immediately executes an SQL `DELETE` query. An important architectural nuance: if you delete an object (for example, an Author), Django uses `CASCADE` behavior by default and automatically deletes all objects related to it (their Books), so that no "orphaned" data is left in the database.

**6. AGGREGATE**
Instead of loading all the books into Python and calculating the average price manually with a loop, `aggregate()` makes the database itself (which is optimized for this) do the math. Unlike `filter()`, which returns a QuerySet, `aggregate()` is a final (terminal) operation that immediately returns a regular Python dictionary with the computed results.

```python
# CREATE
author = Author.objects.create(name="Frank Herbert", email="frank@dune.com")

# READ — lazy! The database has not been queried yet
books = Book.objects.filter(is_active=True)  
books = books.select_related('author')  # JOIN — avoids N+1

# The database is queried here (iteration)
for book in books:
    print(f"{book.title} by {book.author.name}")  # author is already loaded!

# UPDATE
Book.objects.filter(author=author).update(is_active=False)

# DELETE
Book.objects.get(pk=42).delete()

# AGGREGATE
from django.db.models import Avg, Count
stats = Book.objects.aggregate(avg_price=Avg('price'), total=Count('id'))
```

### The N+1 problem — the most common ORM mistake

```python
# BAD: N+1 queries — 1 query for books + N queries for authors
books = Book.objects.all()
for book in books:
    print(book.author.name)  # an SQL query every time!

# GOOD: 2 queries (JOIN or IN)
books = Book.objects.select_related('author').all()  # for ForeignKey
books = Book.objects.prefetch_related('tags').all()  # for ManyToMany
```

---

## 6. Middleware — the request onion

### How to write your own middleware

```python
class LoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # --- BEFORE the View ---
        print(f"→ {request.method} {request.path}")
        
        response = self.get_response(request)  # all of Django is inside
        
        # --- AFTER the View ---
        print(f"← {response.status_code}")
        response['X-Processing-Time'] = '42ms'
        
        return response
```

### Where middleware is useful

| Task | Middleware |
|--------|------------|
| Rate limiting (DDoS protection) | Custom or `django-ratelimit` |
| JWT authentication | Custom + `djangorestframework-simplejwt` |
| Request logging | Custom or `django-request` |
| CORS headers | `django-cors-headers` |
| GZip compression | `GZipMiddleware` (built-in) |

---

## 7. Authentication and Sessions

### How Django stores a session

1. After login, Django creates a record in the `django_session` table:
   ```
   session_key: "abc123xyz"
   session_data: {base64-encoded: {"_auth_user_id": "42", "_auth_user_backend": "..."}}
   expire_date: 2025-06-01 10:00:00
   ```
2. It sends the client a cookie: `Set-Cookie: sessionid=abc123xyz; HttpOnly; Secure`
3. On subsequent requests, `SessionMiddleware` reads `sessionid` from the cookie
4. `AuthenticationMiddleware` loads the user: `request.user = User.objects.get(id=42)`

### Login/Logout

```python
from django.contrib.auth import authenticate, login, logout

def login_view(request):
    if request.method == 'POST':
        user = authenticate(
            request,
            username=request.POST['username'],
            password=request.POST['password']
        )
        if user:
            login(request, user)           # creates the session
            return redirect('dashboard')
        return render(request, 'login.html', {'error': 'Invalid credentials'})
    return render(request, 'login.html')

def logout_view(request):
    logout(request)                        # deletes the session from the DB
    return redirect('home')
```

### Protecting a view from anonymous users

```python
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin

@login_required                    # → redirects to /accounts/login/
def my_profile(request):
    return render(request, 'profile.html')

class DashboardView(LoginRequiredMixin, View):
    login_url = '/login/'
    def get(self, request):
        return render(request, 'dashboard.html')
```

---

## 8. WSGI vs ASGI

### WSGI (synchronous, traditional)

```
Browser → Nginx → Gunicorn (8 workers) → Django WSGI App
```

- Each worker is a separate Python process
- A worker handles 1 request at a time
- If a view does `time.sleep(5)`, the worker is blocked for 5 seconds
- 8 workers = at most 8 concurrent requests

```python
# wsgi.py
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')
application = get_wsgi_application()
```

### ASGI (asynchronous, modern)

```
Browser → Nginx → Uvicorn (8 workers with an event loop) → Django ASGI App
```

- Each worker is an event loop (asyncio)
- A worker can handle **thousands** of concurrent connections
- While `await db.query()` is running, the worker handles other requests
- Support for WebSockets and Server-Sent Events

```python
# asgi.py
import os
from django.core.asgi import get_asgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')
application = get_asgi_application()
```

```python
# Async view (Django 3.1+)
from django.http import JsonResponse
import asyncio

async def async_view(request):
    await asyncio.sleep(1)         # does not block the server!
    return JsonResponse({'status': 'ok'})
```

### When to use what

| Scenario | Recommendation |
|----------|-------------|
| Traditional website | WSGI + Gunicorn |
| REST API (lots of requests) | ASGI + Uvicorn |
| WebSockets (chat, real-time) | ASGI + Django Channels |
| Mixed (both) | Gunicorn + Uvicorn workers |

---

## 9. Migrations — evolving the DB schema

Imagine that **Migrations** are a **version control system (like Git), but for your database**.

Django does not require you to write SQL queries by hand to create or change tables. Instead, you change Python classes (models), and Django takes care of all the database work.

Here is what the full workflow looks like:

**1. Changing the code (models.py)**
You add, remove, or change fields in your models. 

**2. Recording the changes (`makemigrations`)**
The `python manage.py makemigrations` command scans your models, finds the changes, and creates a new migration file (for example, `0002_book_add_isbn.py`). This file is just a "blueprint" or record of *exactly what* changed. The database itself has not been touched yet at this stage.

**3. Applying the changes (`migrate`)**
The `python manage.py migrate` command reads these blueprints and executes real SQL commands to change the database structure (create a new column, table, and so on). Django keeps a special internal table (`django_migrations`) to remember which migrations have already been applied and which have not.

**Additional useful commands:**

*   **`python manage.py showmigrations`**: Shows a list of all existing migrations in your project. Those that have already been successfully applied to the database are marked with an `[X]`.
*   **`python manage.py sqlmigrate app_name migration_number`**: Shows the "raw" SQL that Django plans to execute. This command changes nothing in the database, but it is very useful when you want to check exactly what will happen under the hood.



```bash
# After changing models.py — generates a migration file
python manage.py makemigrations

# Applies the migrations to the DB
python manage.py migrate

# View the SQL that will be executed
python manage.py sqlmigrate myapp 0002
```

**A migration file** is Python code that describes schema changes:

```python
# migrations/0002_book_add_isbn.py
from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('books', '0001_initial')]
    
    operations = [
        migrations.AddField(
            model_name='book',
            name='isbn',
            field=models.CharField(max_length=13, blank=True),
        ),
    ]
```

> Never edit migration files by hand if they have already been applied to a production DB.

**Why can't you edit migration files that have already been applied?**
Because Django tracks the history precisely, manually tampering with old files will cause the real database structure to fall out of sync with your Python code, and later attempts to update the database will produce errors.

---

## 10. Static Files and Media

```python
# settings.py
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'   # where collectstatic gathers the files
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'          # where uploaded files are stored
```

```bash
# Gathers all static files from the apps into STATIC_ROOT (for production)
python manage.py collectstatic
```

**Production:** Nginx serves static files directly, bypassing Python:
```nginx
location /static/ {
    alias /app/staticfiles/;
}
location /media/ {
    alias /app/media/;
}
```

---

## 11. Production: Nginx + Gunicorn + Django + PostgreSQL + Redis

### Running Gunicorn

```bash
# Synchronous (WSGI)
gunicorn myproject.wsgi:application \
    --workers 4 \
    --bind unix:/run/django.sock \
    --timeout 30

# Asynchronous (ASGI with Uvicorn workers)
gunicorn myproject.asgi:application \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind unix:/run/django.sock
```

### Nginx configuration

```nginx
upstream django {
    server unix:/run/django.sock;
}

server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /etc/ssl/certs/example.com.crt;
    ssl_certificate_key /etc/ssl/private/example.com.key;
    
    # Static files — Django is not involved
    location /static/ {
        alias /app/staticfiles/;
        expires 30d;
    }
    
    # Dynamic requests → Gunicorn → Django
    location / {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Compose

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

  web:
    build: .
    command: gunicorn myproject.asgi:application --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    depends_on:
      - db
      - redis

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    depends_on:
      - web

  celery:
    build: .
    command: celery -A myproject worker -l info
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
  static_volume:
  media_volume:
```

---

## 12. Celery — background tasks

```python
# tasks.py — the task only transports the call to a service
from celery import shared_task

@shared_task
def send_welcome_email_task(user_id: int) -> None:
    from .selectors import user_get_by_id
    from .services import user_send_welcome_email

    user = user_get_by_id(user_id=user_id)
    user_send_welcome_email(user=user)   # the logic lives in the service


# services.py — the logic is here, not in the task
from django.db import transaction

@transaction.atomic
def user_register(*, email: str, password: str):
    user = User(email=email)
    user.set_password(password)
    user.full_clean()
    user.save()
    # the task is launched AFTER the commit — safe
    transaction.on_commit(lambda: send_welcome_email_task.delay(user.id))
    return user


# views.py — thin, delegates to the service
def register_view(request):
    serializer = UserRegisterInputSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = user_register(**serializer.validated_data)
    return Response({'id': user.id}, status=201)
```

---

## 13. Common mistakes and how to avoid them

### N+1 queries

```python
# BAD
for book in Book.objects.all():  # 1 query
    print(book.author.name)      # N queries

# GOOD  
for book in Book.objects.select_related('author'):  # 1 JOIN query
    print(book.author.name)
```

### Blocking calls in a view

```python
# BAD: blocks the entire WSGI worker
import time
def slow_view(request):
    time.sleep(10)  # 10 seconds — the worker is unavailable
    return HttpResponse("done")

# GOOD: async view
async def slow_view(request):
    await asyncio.sleep(10)  # the event loop is free for other requests
    return HttpResponse("done")
```

### Logic in Templates

```html
<!-- BAD: business logic in the template -->
{% if user.subscription.expires_at > now and user.subscription.plan.price > 0 %}

<!-- GOOD: logic in the View or Model -->
{% if user.has_active_paid_subscription %}
```

### Wrong Middleware order

```python
# BAD: AuthenticationMiddleware before SessionMiddleware
MIDDLEWARE = [
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # ← ERROR!
    'django.contrib.sessions.middleware.SessionMiddleware',
]

# GOOD
MIDDLEWARE = [
    'django.contrib.sessions.middleware.SessionMiddleware',     # session first
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # then auth
]
```

### Static file mistakes in production

```python
# BAD: Django serves static files in production (slow, unsafe)
# DEBUG = True in production

# GOOD
# DEBUG = False
# python manage.py collectstatic
# Nginx serves /static/ directly
```

---

## Self-check questions

1. What is the difference between `select_related` and `prefetch_related`, and when should each be used?
2. What happens if you put `AuthenticationMiddleware` above `SessionMiddleware`?
3. Why is `collectstatic` needed, and why shouldn't Django serve static files in production?
4. What is the difference between WSGI and ASGI in terms of handling 1,000 concurrent requests?
5. What is a "lazy QuerySet", and when is the SQL query actually executed?
