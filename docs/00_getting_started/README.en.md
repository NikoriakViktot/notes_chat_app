# 00. Getting Started — Where Django Begins

> This section answers the main question: **why learn Django, and what will you have by the end?**
> Before running any code, understand what you are building and why it matters.

---

## Django is more than just a framework

Django is a "batteries included" web framework for Python.
This means that instead of assembling a system from dozens of libraries,
you get a single tool that already contains **everything** you need for a production application.

```
A typical project WITHOUT a framework:
  requests + urllib → HTTP parsing
  + Jinja2           → templates
  + SQLAlchemy       → database
  + WTForms          → form validation
  + bcrypt           → passwords
  + itsdangerous     → sessions/CSRF
  + pytest           → testing
  = 8 libraries, 8 sets of docs, 8 places where things may not fit together

Django:
  ORM + templates + forms + auth + admin + sessions + CSRF + testing
  = one tool, one set of docs, everything consistent with each other
```

### Where Django is used in the real world

- **Instagram** — the largest Django project in the world (billions of requests per day)
- **Pinterest** — a social network (250+ million active users)
- **Disqus** — comments on 2 billion websites
- **Mozilla** — Firefox Add-ons, bugzilla
- **Washington Post** — a media outlet with millions of readers
- **Eventbrite** — ticket sales
- **Spotify** (partially) — backend services
- Thousands of startups and SaaS products

**Why Django?** It lets a small team (or a single person) quickly build
a reliable, secure and scalable product. Instagram was launched by two developers in 8 weeks.

---

## What you will learn in this course

By the end of the course you will build **notes_chat_app** — a complete, production-ready application:

```
notes_chat_app — what it can do:
  ✓ Registration and authentication (sessions, cookies, CSRF)
  ✓ Notes with tags, notebooks, reminders
  ✓ Todo lists and Shopping lists
  ✓ Groups with shared access to data
  ✓ Real-time group chat (WebSocket)
  ✓ E2E tests with Selenium (headless Chrome)
  ✓ Public access via ngrok (HTTPS tunnel)
  ✓ PostgreSQL, Redis, nginx — a production stack
  ✓ Docker Compose — one command starts everything
```

### Course modules

| Module | Topic | What you will learn |
|--------|------|-------------|
| 01 | First Django view | HTTP, URL, View, Template — the basic cycle |
| 02 | First model | ORM, ModelForm, PRG, Django Messages |
| 03 | CRUD and business logic | selectors/services, N+1, transactions |
| 04 | Templates and Bootstrap | 3-level inheritance, Crispy Forms |
| 05 | Authentication | login, register, UserProfile, decorators |
| 06 | Testing | the test pyramid, TestCase, WebSocket, Selenium |
| 07 | Async and WebSocket | ASGI, Channels, channel layer |
| 08 | Deployment | Docker Compose, nginx, ngrok |

---

## Django's philosophy: "Convention over Configuration"

Django is built on the principle that there is one right way to do a typical task,
and the framework guides you toward it.

### MTV, not MVC

Django uses a variation of MVC called MTV:

```
MVC (classic):          Django MTV:
  Model                   Model       (ORM, models.py)
  View                    Template    (HTML templates)
  Controller              View        (views.py — business logic + HTTP)
```

The names differ, but the concept is the same. The division of responsibilities:

```
models.py     → WHAT we store (data schema, business rules)
views.py      → HOW we handle a request (logic, response)
templates/    → HOW we display it (HTML, CSS, JS)
urls.py       → WHICH URL → which view
forms.py      → HOW we validate input data
```

### Don't Repeat Yourself (DRY)

Django avoids duplication as much as possible:

```python
# The model is defined ONCE:
class Note(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()

# ModelForm generates the form AUTOMATICALLY from the model:
class NoteForm(ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content']
# → HTML form, validation, saving — all from a single description

# The admin is generated AUTOMATICALLY from the model:
admin.site.register(Note)
# → full CRUD in the admin panel
```

### Batteries Included — what Django already has

```
django.contrib.admin          → auto-generated admin panel
django.contrib.auth           → authentication, sessions, passwords (PBKDF2 by default)
django.contrib.contenttypes   → generic relationships
django.contrib.messages       → flash messages (one-time notifications)
django.contrib.staticfiles    → collecting and serving static files
django.contrib.humanize       → filters: "3 days ago", "1,000", etc.
django.test                   → TestCase, Client, RequestFactory
```

---

## How notes_chat_app is organized

```
notes_chat_app/
├── Dockerfile              ← Docker image (python:3.12-slim + requirements)
├── docker-compose.yml      ← Orchestration: db + redis + web + nginx + ngrok + selenium
├── entrypoint.sh           ← Container startup script
├── requirements.txt        ← Python dependencies
├── .env.example            ← Configuration template (copy to .env)
│
├── notes_project/          ← Django project (configuration)
│   ├── settings.py         ← All settings (DB, apps, static, channels)
│   ├── urls.py             ← Root URL dispatcher
│   ├── asgi.py             ← ASGI entry point (HTTP + WebSocket)
│   ├── wsgi.py             ← WSGI (not used in production)
│   └── routing.py          ← WebSocket URL patterns
│
├── notes_app/              ← Django app (main logic)
│   ├── models.py           ← 10 models: Note, Notebook, Tag, UserProfile, ChatMessage...
│   ├── views.py            ← HTTP views (thin layer)
│   ├── consumers.py        ← WebSocket consumer (async)
│   ├── selectors.py        ← SELECT only (read-only ORM)
│   ├── services.py         ← Mutations (CREATE, UPDATE, DELETE)
│   ├── forms.py            ← Django ModelForms
│   ├── urls.py             ← HTTP URL patterns
│   ├── admin.py            ← Admin panel registration
│   ├── templates/          ← HTML templates
│   ├── static/             ← CSS, JavaScript
│   └── tests/              ← Tests (models, services, forms, views, consumers, selenium)
│
├── nginx/
│   └── nginx.conf          ← Reverse proxy + WebSocket configuration
│
└── docs/                   ← All documentation (MkDocs)
```

### Data schema (in brief)

```
User ──1:1──► UserProfile
User ──1:N──► Notebook, Note, Tag, TodoList, ShoppingList
Notebook ──1:N──► Note
Note ──M:N──► Tag
Note ──1:N──► Reminder
TodoList ──1:N──► TodoItem
ShoppingList ──1:N──► ShopItem
Group ──1:N──► ChatMessage
```

More details: [03 — CRUD and models](../tutorials/03_crud.md)

---

## Materials in this section

| Document | What's inside |
|----------|-------------|
| [Prerequisites](prerequisites.md) | What to install: Python, Docker, Git, VSCode |
| [Local setup](local_setup.md) | How to run it: `docker compose up --build` |
| [Repository structure](repository_structure.md) | What lives where in the repository |
| [How to use course](how_to_use_course.md) | How to read the materials effectively |

---

## Minimal start — three commands

```bash
# 1. Copy the config:
cp .env.example .env

# 2. Start the stack:
docker compose up --build

# 3. Open the browser:
# http://localhost
#
# Demo accounts (password: demo1234):
# demo_alice, demo_bob, demo_carol
```

---

## What "production-ready" means

Most tutorials show Django on `runserver` with SQLite.
`notes_chat_app` is on a different level:

| Component | Typical tutorial | notes_chat_app |
|-----------|-----------------|---------------|
| **DB** | SQLite | PostgreSQL 16 |
| **Server** | `runserver` | Uvicorn ASGI |
| **Proxy** | — | nginx 1.27 |
| **Channel layer** | — | Redis 7 |
| **WebSocket** | — | Django Channels |
| **Tests** | Minimal | Unit + Integration + Consumer + Selenium E2E |
| **Startup** | `python manage.py runserver` | `docker compose up` |
| **Public URL** | localhost | ngrok HTTPS tunnel |

You are learning not "how to get something running", but "how it really works in production".

---

## Self-check questions before you start

- What are an HTTP request and response?
- What is Docker and what is it for?
- What is a relational database?
- What is Git and how do you clone a repository?

If you have gaps, take a look at [Prerequisites](prerequisites.md).

## Next

[01 — Web foundations](../01_web_foundations/README.md) → HTTP, the browser, DNS.

Or go straight to the tutorials: [01 — First Django view](../tutorials/01_first_django_page.md)
