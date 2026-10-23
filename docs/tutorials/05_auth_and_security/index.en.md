# Step 5. Auth and Security

> This step covers two projects: **crispy_notes_project** (Steps 1–6) and **notes_chat_app** (Steps 7–11).
> The first is a standalone application on SQLite without Docker.
> The second is a production-like stack with Docker, PostgreSQL, Redis, Group sharing and a WebSocket chat.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 1. Hello Django](../01_hello_django/index.md) — the first `HttpResponse`, URL routing
    - [Step 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Step 3. CRUD and architecture](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL
    - [Step 4. Templates and Forms](../04_templates_and_forms/index.md) — Crispy Forms, Dashboard, Context Processor

---

## Tutorial project vs Notes Chat App

| | crispy_notes_project (Steps 1–6) | notes_chat_app (Steps 7–11) |
|-|----------------------------------|------------------------------|
| Running | `python manage.py runserver` | `docker compose up --build` |
| Database | SQLite | PostgreSQL (Docker) |
| Auth | Login / Logout / Register / Password Reset | The same + UserCreationForm auto-login |
| Session storage | File-based (SQLite) | DB (PostgreSQL), `django.contrib.sessions` |
| Group FK | `Note.group`, `ShoppingList.group` | The same + `ChatMessage.group` |
| Docker | None | PostgreSQL + Redis + Web + Nginx + Selenium |
| ngrok | None | Yes — a public URL + `CSRF_TRUSTED_ORIGINS` |
| WebSocket | None | `GroupChatConsumer` via Redis |

---

## What you will learn

- **AuthN vs AuthZ** — the difference between "who are you?" and "what are you allowed to do?", the passport/ticket analogy
- **Sessions** — how stateless HTTP becomes stateful: the cookie, `django_session`, the middleware chain
- **Password Security** — PBKDF2 with 600,000 iterations, the Password Reset flow, 4 built-in validators
- **IDOR** — Insecure Direct Object Reference: the most common vulnerability (OWASP A01), and how to protect against it
- **Group Sharing** — Django's built-in Group model, FK `SET_NULL`, the Q-filter `Q(user=u) | Q(group__in=gs)`
- **Security Settings** — `SESSION_COOKIE_HTTPONLY`, `X_FRAME_OPTIONS`, `CSRF_TRUSTED_ORIGINS`, `DEBUG=False`

---

## Reading order

1. **[Auth Basics](auth_basics.md)** — passport/ticket, AuthN vs AuthZ, `authenticate()`, `login()`, the middleware chain, Sessions, cookies
2. **[Password Security](password_security.md)** — `django.contrib.auth.urls`, Password Reset (5 steps), PBKDF2, validators, Password Change
3. **[Object Permissions](object_permissions.md)** — IDOR, `get_object_or_404`, the Q-filter for shared objects, a table of protected views
4. **[Group Sharing](group_sharing.md)** — Django Group, `SET_NULL`, Q-filter, Services, Views, Templates
5. **[Security Settings](security_settings.md)** — a settings table, `DEBUG=True` leaks, HTTPS production settings
6. **[Notes Chat App Auth](notes_chat_app_auth.md)** — notes_chat_app specifics: Docker, `DATABASE_URL`, registration, URL configuration
7. **[Checkpoint](checkpoint.md)** — checklist, IDOR test, common mistakes, practical exercise
