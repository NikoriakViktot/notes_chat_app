# Django Network Architecture — Knowledge System

> This file is the main learning map. Start here.
> The material is organized from network fundamentals up to Django production architecture.

---

## Learning map

```
LEVEL 1: Network fundamentals
    → What the Internet is
    → IP, DNS, TCP, HTTP, HTTPS
    → Sockets, Ports, Client/Server

LEVEL 2: How a request reaches Python
    → Nginx → WSGI/ASGI → Django
    → The full stack trace of a request

LEVEL 3: Django as a system
    → Project structure
    → MVT architecture
    → Request Lifecycle

LEVEL 4: Django components
    → URL Routing
    → Views (FBV/CBV)
    → Templates (DTL)
    → ORM + Migrations

LEVEL 5: Production architecture
    → Nginx + Gunicorn + Docker
    → PostgreSQL + Redis + Celery
    → Scaling, Security, Deployment
```

---

## Part 1 — Network fundamentals

### Must read before Django

| File | What it gives you |
|------|--------|
| [network_foundation.md](../../01_web_foundations/network_foundation_full.md) | A systematic understanding of the Internet: IP, DNS, TCP, HTTP, HTTPS, REST API |
| [network_mermaid.md](../../01_web_foundations/network_mermaid_full.md) | Visual diagrams: DNS resolving, TCP handshake, TLS, the full Browser→Server lifecycle |

### Key concepts

- **IP address** — a unique identifier of a computer on the network
- **DNS** — translates `github.com` into `140.82.121.4`
- **TCP** — guaranteed packet delivery (handshake, sequence numbers)
- **Port** — indicates which *program* the traffic goes to (80→Nginx, 5432→PostgreSQL)
- **HTTP** — a text protocol: method + path + headers + body
- **HTTPS** — HTTP + TLS encryption
- **Stateless** — HTTP does not remember anything between requests → Cookies + Sessions
- **Socket** — a bidirectional connection endpoint between programs

---

## Part 2 — How a request reaches Python

### The full path of an HTTP request

```
Browser
  │
  │ DNS: example.com → 203.0.113.10
  │ TCP + TLS Handshake
  │ HTTP GET /products/
  ▼
Nginx (Reverse Proxy :443)
  │ Static file? → serves it from disk (CSS, JS, PNG)
  │ Dynamic request? → forwarding
  ▼
Gunicorn (Process Manager)
  │ Manages Python workers
  ▼
Uvicorn Worker (ASGI) or uWSGI (WSGI)
  │ HTTP bytes → Python dict (environ)
  ▼
Django Application
  │ Middleware → URL Dispatcher → View → ORM → Template
  ▼
PostgreSQL / Redis
  │ SQL query → data
  ▼
HTTP Response → Gunicorn → Nginx → Browser
```

### Documentation

| File | What it gives you |
|------|--------|
| [django_architecture.md](../../02_django_core/django_architecture_full.md) | A general overview of Django as a system — MVT, middleware, ORM, WSGI/ASGI, production stack |
| [django_mermaid.md](../../02_django_core/django_mermaid_full.md) | 15 architecture diagrams: lifecycle, middleware chain, ORM, production deployment |

---

## Part 3 — Django project structure

| File | What it gives you |
|------|--------|
| [DJANGO_PROJECT_STRUCTURE.md](../../02_django_core/project_structure_full.md) | Every Django file with its exact role, mistakes and mental models |

### Quick file map

| File | Role | Level |
|------|------|--------|
| `manage.py` | CLI orchestrator | System |
| `settings.py` | Central configuration | System |
| `wsgi.py` / `asgi.py` | Entry point for servers | System |
| `urls.py` | Request router | Logic |
| `views.py` | Business logic (controller) | Logic |
| `apps.py` | Module registration | Logic |
| `models.py` | DB schema (ORM) | Data |
| `migrations/` | DB schema versions | Data |
| `admin.py` | Admin interface | Data |
| `templates/` | HTML templates | Presentation |
| `static/` | CSS, JS, images | Presentation |

---

## Part 4 — Commands and Lifecycle

| File | What it gives you |
|------|--------|
| [DJANGO_COMMAND_SYSTEM.md](../../02_django_core/management_commands_full.md) | A table of all commands + a step-by-step lifecycle from zero to deployment |
| [DJANGO_MIGRATIONS.md](../../03_database_and_orm/django_migrations_full.md) | Migration mechanics, dependency graph, CI/CD |

### The critical order of commands

```bash
# New project
django-admin startproject myproject
python manage.py startapp myapp
# → register it in INSTALLED_APPS

# Development cycle
# (change models.py)
python manage.py makemigrations   # records the plan
python manage.py migrate          # applies it to the DB

# Admin
python manage.py createsuperuser

# Development
python manage.py runserver

# Before deployment
python manage.py check --deploy
python manage.py collectstatic
```

---

## Part 5 — Django components

### URL Routing

| File | What it gives you |
|------|--------|
| [Django_URL_Routing.md](../../02_django_core/url_routing_full.md) | URL Dispatcher, path converters, GET/POST params, Forms, ModelForms, CreateView |

**Key concepts:**
- Route lookup goes **top to bottom** and stops at the **first** match
- `include()` — splits routes into isolated modules
- `<int:pk>`, `<str:username>` — capture variables from the URL
- Static routes must come **before** dynamic ones

---

### Views

| File | What it gives you |
|------|--------|
| [Django_Views.md](../../02_django_core/views_full.md) | FBV vs CBV, Generic Views (ListView, DetailView, CreateView), lifecycle |

**Key concepts:**
- A view is the central orchestrator: receives a request → queries the DB → returns a response
- FBV (Function-Based Views) — simple, explicit, flexible
- CBV (Class-Based Views) — OOP, inheritance, less duplication
- Generic Views — `ListView`, `DetailView`, `CreateView` automate CRUD

---

### Templates (DTL)

| File | What it gives you |
|------|--------|
| [Django_Templates.md](../../05_frontend_and_templates/django_templates_full.md) | DTL syntax, context system, security (XSS), template inheritance |

**Key concepts:**
- `{{ variable }}` — outputs variables (with automatic HTML escaping)
- `{% tag %}` — logic: `for`, `if`, `extends`, `block`, `url`, `csrf_token`
- `{{ var|filter }}` — transformation: `|date`, `|truncatewords`, `|lower`
- Template inheritance: `base.html` → child templates via `{% extends %}`

---

### ORM and the database

| File | What it gives you |
|------|--------|
| [Django_ORM.md](../../03_database_and_orm/django_orm_full.md) | QuerySet API, the N+1 problem, transactions, MVCC, production pitfalls |

**Key concepts:**
- A QuerySet is **lazy**: SQL runs only on iteration
- `select_related` — a JOIN at the SQL level (for ForeignKey)
- `prefetch_related` — a separate query + a Python join (for ManyToMany)
- The N+1 problem — 1 query for the list + N queries in a loop → disaster
- `transaction.atomic()` — atomic DB operations
- MVCC — PostgreSQL keeps row versions for transaction isolation

---

### Migrations

| File | What it gives you |
|------|--------|
| [DJANGO_MIGRATIONS.md](../../03_database_and_orm/django_migrations_full.md) | Migration mechanics, dependency graph, common problems |

---

### Services, Selectors & Serializers

| File | What it gives you |
|------|--------|
| [DJANGO_SERVICES_SELECTORS.md](../../06_application_architecture/services_selectors_full.md) | The business layer: Services (mutations), Selectors (reads), Serializers as a transport boundary |
| [DJANGO_SERVICES.md](../../06_application_architecture/django_services_full.md) | Only `services.py`: stateless functions, transactions, `on_commit`, side effects, patterns |
| [DJANGO_SELECTORS.md](../../06_application_architecture/django_selectors_full.md) | Only `selectors.py`: CQRS-light, named queries, N+1, ORM optimizations, patterns |
| [DJANGO_SERIALIZERS.md](../../06_application_architecture/django_serializers_full.md) | Only `serializers.py`: Input/Output, `validate()`, fields, a pure Python function, errors |
| [DJANGO_TASKS.md](../../06_application_architecture/django_tasks_full.md) | Only `tasks.py`: Celery, broker, retry, `on_commit`, idempotency, patterns |

**Key concepts:**
- `services.py` — business logic, `@transaction.atomic`, `on_commit` for side effects
- `selectors.py` — read-only ORM queries, `select_related`, `prefetch_related`, CQRS-light
- `InputSerializer` / `OutputSerializer` — explicit contracts instead of `ModelSerializer`
- A service knows nothing about HTTP — it is called the same way from a View, Celery or the CLI
- N+1 is centralized in the Selector instead of spreading across Views and Tasks

**Key concepts:**
- `makemigrations` — generates a Python plan of changes (does not change the DB)
- `migrate` — executes SQL (changes the DB)
- Dependency graph — migrations run in the correct order automatically
- Migration files — committed to Git together with the code

---

## Part 6 — Production architecture

### Technology stack

| Component | Role |
|-----------|------|
| **Nginx** | Reverse proxy, SSL, serving static files |
| **Gunicorn** | Process manager for Python workers |
| **Uvicorn** | ASGI worker with an event loop (async) |
| **uWSGI** | WSGI worker (sync, traditional) |
| **PostgreSQL** | The main relational database |
| **Redis** | Cache, sessions, Celery broker |
| **Celery** | Background tasks (email, reports, processing) |
| **Docker** | Environment isolation and reproducibility |

### WSGI vs ASGI

| | WSGI | ASGI |
|-|------|------|
| **Synchronicity** | Synchronous | Asynchronous |
| **Worker** | 1 request per worker | Thousands of coroutines per worker |
| **Blocking** | Yes — waits for the DB | No — `await` frees the worker |
| **WebSockets** | No | Yes |
| **Server** | Gunicorn + uWSGI | Uvicorn + Daphne |
| **When** | Traditional sites | API, real-time, high-load |

---

## Common mistakes — Summary table

| Mistake | Component | Consequence | Solution |
|---------|-----------|----------|---------|
| N+1 queries | ORM | Thousands of SQL queries | `select_related`, `prefetch_related` |
| Blocking code in a View | Views/WSGI | Frozen worker | `async def view` + `await` |
| Logic in Templates | Templates | Impossible to test | Move it into the View or Model |
| Auth before Session in Middleware | Middleware | Empty `request.user` | Correct Middleware order |
| `runserver` in production | Deployment | Crash under load | Gunicorn + Nginx |
| No `collectstatic` | Deployment | 404 for static files | `collectstatic` + Nginx |
| `DEBUG=True` in production | Security | Configuration leak | `DEBUG=False` |
| Race condition on `save()` | ORM | Data loss | `F()` expressions |
| `atomic()` exception trap | ORM/DB | `TransactionManagementError` | Catch OUTSIDE the atomic block |
| Mutable price in Order | DB Design | Broken financial reporting | Store `purchase_price` in OrderItem |

---

## Quick lookup reference

| Question | Where to look |
|---------|-----------|
| How do I configure a URL? | [Django_URL_Routing.md](../../02_django_core/url_routing_full.md) |
| How do I write a View? | [Django_Views.md](../../02_django_core/views_full.md) |
| How do I write a Template? | [Django_Templates.md](../../05_frontend_and_templates/django_templates_full.md) |
| How do I write a Model? | [Django_ORM.md](../../03_database_and_orm/django_orm_full.md) |
| What is a migration? | [DJANGO_MIGRATIONS.md](../../03_database_and_orm/django_migrations_full.md) |
| Which command does what? | [DJANGO_COMMAND_SYSTEM.md](../../02_django_core/management_commands_full.md) |
| What is each file? | [DJANGO_PROJECT_STRUCTURE.md](../../02_django_core/project_structure_full.md) |
| How does DNS work? | [network_foundation.md](../../01_web_foundations/network_foundation_full.md) |
| What is TCP? | [network_foundation.md](../../01_web_foundations/network_foundation_full.md) |
| Architecture diagrams | [django_mermaid.md](../../02_django_core/django_mermaid_full.md) |
| Network diagrams | [network_mermaid.md](../../01_web_foundations/network_mermaid_full.md) |
| Where does business logic live? | [DJANGO_SERVICES.md](../../06_application_architecture/django_services_full.md) |
| What is a Service? | [DJANGO_SERVICES.md](../../06_application_architecture/django_services_full.md) |
| What is a Selector? | [DJANGO_SELECTORS.md](../../06_application_architecture/django_selectors_full.md) |
| How do I avoid duplicating ORM queries? | [DJANGO_SELECTORS.md](../../06_application_architecture/django_selectors_full.md) |
| How do I send a Celery task correctly? | [DJANGO_TASKS.md](../../06_application_architecture/django_tasks_full.md) |
| What are a Celery broker and worker? | [DJANGO_TASKS.md](../../06_application_architecture/django_tasks_full.md) |
| How do I make a task idempotent? | [DJANGO_TASKS.md](../../06_application_architecture/django_tasks_full.md) |
| What are InputSerializer / OutputSerializer? | [DJANGO_SERIALIZERS.md](../../06_application_architecture/django_serializers_full.md) |
| How do I validate input data? | [DJANGO_SERIALIZERS.md](../../06_application_architecture/django_serializers_full.md) |

---

## The student's path — recommended reading order

```
1. network_foundation.md          ← You understand the Internet
2. network_mermaid.md             ← You see the diagrams
3. django_architecture.md         ← You understand Django as a system
4. DJANGO_PROJECT_STRUCTURE.md    ← You know every file
5. DJANGO_COMMAND_SYSTEM.md       ← You can use the CLI
6. DJANGO_MIGRATIONS.md           ← You understand DB evolution
7. Django_ORM.md                  ← You write DB queries
8. Django_URL_Routing.md          ← You route requests
9. Django_Views.md                ← You write business logic
10. Django_Templates.md           ← You render HTML
11. django_mermaid.md             ← You see the full architecture
12. DJANGO_SERVICES_SELECTORS.md  ← Business-layer architecture (Services, Selectors, Serializers)
13. DJANGO_SERVICES.md            ← services.py in detail: transactions, on_commit, side effects
14. DJANGO_SELECTORS.md           ← selectors.py in detail: CQRS-light, named queries, N+1
15. DJANGO_SERIALIZERS.md         ← serializers.py in detail: Input/Output, validate(), fields
16. DJANGO_TASKS.md               ← tasks.py in detail: Celery, retry, on_commit, idempotency
```

> After this path you think like a backend engineer instead of just "writing Django code".

---

## Practical projects

| Project | Folder | Level | What's inside |
|--------|-------|--------|--------------|
| [Hello, Django!](../legacy_source/legacy_missing_reference.md) | `simple_django_project/` | Beginner | Step-by-step instructions: venv → the first page in the browser. Only README + requirements.txt |
| [News portal](../legacy_source/legacy_missing_reference.md) | `news_portal/` | Basic | A full-featured site: models, views, templates, admin panel, rbc.ua parser, Docker + PostgreSQL |

### Recommended order

```
Theory (steps 1–11 above)
       ↓
simple_django_project/   ← your first hands-on Django run
       ↓
news_portal/             ← real architecture: ORM, CBV, Admin, management command
```
