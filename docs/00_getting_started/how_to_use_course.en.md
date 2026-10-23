# How to Read This Course

> This course is both a hands-on tutorial and a theory book.
> There are two paths: **Zero to Hero** (practice) and **The Django Book** (theory).
> They complement each other.

---

## Two parallel paths

```
┌─────────────────────────────────────────────────────────────────┐
│                    NOTES CHAT APP COURSE                        │
├──────────────────────────┬──────────────────────────────────────┤
│   ZERO TO HERO           │   THE DJANGO BOOK                    │
│   (practice)             │   (theory)                           │
│                          │                                      │
│  Step 1 → Step 9         │  Part I → Part XI                    │
│  You build notes_chat_app│  Explains WHY                        │
│  Step-by-step tutorials  │  Deep concepts                       │
│  Real code               │  Diagrams and analogies              │
│                          │                                      │
│  Recommended for         │  Recommended for                     │
│  Django beginners        │  "why does it work this way?"        │
└──────────────────────────┴──────────────────────────────────────┘
```

**What to choose:**
- Never written Django before? → Start with **Zero to Hero**, Step 1
- Already know Django and want to deepen your knowledge? → Read **The Django Book** in any order
- Looking for a specific topic? → Use search (the `/` key in the documentation)

---

## Path 1: Zero to Hero (9 steps)

You build `notes_chat_app` from scratch. Each step adds a separate piece of functionality.

```
Step 1 → Hello Django
    First page, URL routing, templates, Django Admin

Step 2 → Bootstrap Notes
    First model (Note), migrations, Django Admin, basic CRUD

Step 3 → CRUD and architecture
    Full project model, selectors/services, FBV views, QuerySet

Step 4 → Templates and Forms
    Bootstrap, template inheritance, Crispy Forms, context processors

Step 5 → Auth and security
    Login/logout, registration, groups, object-level permissions, CSRF

Step 6 → Testing
    TestCase, unit/integration/E2E, Selenium, GitHub Actions CI

Step 7 → Async Django
    Async views, WebSocket, Django Channels, GroupChatConsumer

Step 8 → Background Tasks
    Celery, Redis, background tasks, browser notifications

Step 9 → Deployment
    Docker Compose, nginx, ngrok, PostgreSQL, production checklist
```

Each step ends with a **Checkpoint** — a list of what you should be able to do after it.

---

## Path 2: The Django Book (theory)

11 parts, each covering a separate area:

```
Part I.    Web Foundation      → HTTP, DNS, TCP, browser lifecycle
Part II.   Django Core         → MTV, URL routing, views, middleware
Part III.  Database and ORM    → Models, QuerySet, migrations, PostgreSQL
Part IV.   Forms and Validation → Django Forms, ModelForm, Crispy Forms
Part V.    Templates and Frontend → Template language, Bootstrap, Admin
Part VI.   Architecture        → Services, Selectors, thin views
Part VII.  Auth and Security   → Sessions, permissions, OWASP, CSRF
Part VIII. Testing             → Test pyramid, pytest, Selenium, CI
Part IX.   Async and Realtime  → asyncio, ASGI, Channels, WebSocket
Part X.    Linux and DevOps    → Linux, Docker, nginx, SSH
Part XI.   Deployment          → VPS, Gunicorn/Uvicorn, HTTPS, monitoring
```

You can read the parts in any order depending on what you need.

---

## How practice and theory are connected

Each practical chapter (Zero to Hero) contains an **"In the book"** section — links to the theory chapters that explain WHY something works the way it does.

```
Example:

Step 3 → "Services and Selectors" (tutorial — HOW to write it)
  ↓  "In the book" link
Part VI → "Services and Selectors" (book — WHY this architecture)
```

And the other way round — the theory chapters link to the tutorials where the concepts are applied in practice.

---

## Notes Chat App — the final project

The **"Notes Chat App"** section in the navigation is the documentation of the project itself:
- Architecture and domain model
- All URLs and view functions
- Tests and their structure
- Deployment and production settings

It is useful as a reference when you are building and want to understand where a specific piece of functionality lives.

---

## How to search

```
/              → search the whole documentation (Material MkDocs)
Ctrl+K         → alternative search shortcut
```

Search works across text, headings and code examples.

---

## Roles and focus

| Who you are | Recommended route |
|--------|----------------------|
| New to Django | Zero to Hero Steps 1→9, alongside book Parts I-II |
| Experienced in Python, first time with Django | Start with book Parts II-III, then Zero to Hero Steps 2-3 |
| You know Django and want production skills | Zero to Hero Steps 6-9 (tests, async, deployment) |
| Teacher | `TEACHING_GUIDE.md` in the root of `docs/` |
| DevOps focus | Parts X-XI, Step 9 (Deployment) |

---

## Practical exercise

1. Decide which role you are taking (beginner / experienced / DevOps)
2. Choose the matching route from the table above
3. Go to the first document of the route

---

## Next

→ [Repository structure](repository_structure.md) — where each part of the code lives
