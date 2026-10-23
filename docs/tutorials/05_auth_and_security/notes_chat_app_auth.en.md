# Notes Chat App Auth — Project specifics

> This chapter describes authentication implementation details specific to `notes_chat_app` —
> a production-like stack with Docker, PostgreSQL, Redis and a WebSocket chat.
> The material does not duplicate what was described in previous chapters — only the unique details are here.

---

## Step 0 — Running with Docker

```bash
# 1. Copy the configuration
cp .env.example .env
# Edit .env: SECRET_KEY, POSTGRES_*, NGROK_* if needed

# 2. Bring up the whole stack (PostgreSQL + Redis + Web + Nginx + ngrok + Selenium)
docker compose up --build

# 3. View the logs (the password reset email will be here)
docker compose logs -f web

# 4. Open in the browser
open http://localhost   # via nginx
# OR
open http://localhost:8001   # directly to Uvicorn

# 5. Demo data (3 users, groups, notes)
# If SEED_DEMO_DATA=1 in .env → automatically on startup
# Manually:
docker compose exec web python manage.py seed_demo_data
# Logins: demo_alice/demo1234, demo_bob/demo1234, demo_carol/demo1234
```

### What to look at in the browser

| URL | What it shows |
|-----|-----------|
| `http://localhost/accounts/login/` | Login form |
| `http://localhost/register/` | New account registration |
| `http://localhost/accounts/password_reset/` | Password recovery form |
| `http://localhost/accounts/password_change/` | Password change (after logging in) |
| `http://localhost/notes/` | Note list (logged-in users only) |
| `http://localhost/groups/` | My groups |
| `http://localhost/groups/new/` | Create a group |
| `http://localhost/admin/` | Django Admin |

---

## Step 1 — Settings for Docker (settings.py)

Unlike `crispy_notes_project`, where `SECRET_KEY` may be hard-coded for dev,
in `notes_chat_app` all sensitive data is moved to `.env`:

```python
# notes_project/settings.py

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Read from the environment (Docker passes it via .env / docker-compose.yml):
SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-insecure-key-change-in-production')
DEBUG = os.environ.get('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# DATABASE_URL — PostgreSQL in Docker:
# postgresql://notes_user:notes_pass@db:5432/notes_db
# 'db' — the service name from docker-compose.yml (DNS resolution in the Docker network)
import dj_database_url
DATABASES = {
    'default': dj_database_url.config(
        default=os.environ.get('DATABASE_URL', 'sqlite:///db.sqlite3')
    )
}

# REDIS_URL for the Channel Layer (WebSocket):
REDIS_URL = os.environ.get('REDIS_URL', '')
```

---

## Step 2 — Registration (Registration View)

`django.contrib.auth.urls` does not include registration — you have to write it yourself:

```python
# notes_app/views.py
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth import login
from django.shortcuts import redirect, render
from django.contrib import messages


def register(request):
    """
    Registering a new user.
    After successful registration — auto-login and redirect to note_list.
    """
    if request.user.is_authenticated:
        # Already logged in → don't show the registration form
        return redirect('notes_app:note_list')

    if request.method == 'POST':
        form = UserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            # auto-login: don't make the user log in right after registering
            login(request, user)
            messages.success(request, f'Вітаємо, {user.username}! Акаунт створено.')
            return redirect('notes_app:note_list')
    else:
        form = UserCreationForm()

    return render(request, 'registration/register.html', {'form': form})
```

### `templates/registration/register.html`

```html
{% extends 'base.html' %}
{% load crispy_forms_tags %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 440px;">
    <div class="card-body p-4">

      <div class="text-center mb-4">
        <i class="bi bi-person-plus-fill display-4 text-success"></i>
        <h5 class="fw-bold mt-2 mb-0">Реєстрація</h5>
        <p class="text-muted small">Створи новий акаунт</p>
      </div>

      <form method="post">
        {% csrf_token %}
        {{ form|crispy }}
        {# UserCreationForm: username, password1, password2 #}
        {# crispy: Bootstrap 5 styles automatically #}
        <button type="submit" class="btn btn-success w-100 mt-2 py-2">
          <i class="bi bi-check-circle me-2"></i>Зареєструватись
        </button>
      </form>

      <hr class="my-3">
      <p class="text-center text-muted small mb-0">
        Вже є акаунт? <a href="{% url 'login' %}">Увійти</a>
      </p>

    </div>
  </div>
</div>
{% endblock %}
```

---

## Step 3 — URL configuration

**Location:** `notes_project/urls.py`

```python
from django.contrib import admin
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls

urlpatterns = [
    path("admin/", admin.site.urls),

    # Django built-in auth: login, logout, password change, password reset
    # Registers 8 URLs in a single line!
    path("accounts/", include("django.contrib.auth.urls")),

    # Our application: notes, groups, registration, WebSocket chat
    path("", include("notes_app.urls", namespace="notes_app")),
] + debug_toolbar_urls()
```

**Location:** `notes_app/urls.py`

```python
from django.urls import path
from . import views

app_name = 'notes_app'

urlpatterns = [
    # ── Notes ──────────────────────────────────────────────────────────────
    path('notes/',              views.note_list,    name='note_list'),
    path('notes/new/',          views.note_create,  name='note_create'),
    path('notes/<int:pk>/',     views.note_detail,  name='note_detail'),
    path('notes/<int:pk>/edit/',   views.note_edit,   name='note_edit'),
    path('notes/<int:pk>/delete/', views.note_delete, name='note_delete'),

    # ── Notebooks ──────────────────────────────────────────────────────────
    path('notebooks/',               views.notebook_list,   name='notebook_list'),
    path('notebooks/new/',           views.notebook_create, name='notebook_create'),
    path('notebooks/<int:pk>/edit/', views.notebook_edit,   name='notebook_edit'),
    path('notebooks/<int:pk>/delete/', views.notebook_delete, name='notebook_delete'),

    # ── Auth (custom — registration not in auth.urls) ──────────────────────
    path('register/', views.register, name='register'),

    # ── Groups ─────────────────────────────────────────────────────────────
    path('groups/',                  views.group_list,    name='group_list'),
    path('groups/new/',              views.group_create,  name='group_create'),
    path('groups/<int:pk>/',         views.group_detail,  name='group_detail'),
    path('groups/<int:pk>/delete/',  views.group_delete,  name='group_delete'),

    # ── Chat (WebSocket, via groups) ──────────────────────────────────────
    path('groups/<int:pk>/chat/',    views.group_chat,    name='group_chat'),
]
```

---

## notes_chat_app file structure after this step

```
notes_chat_app/
│
├── notes_project/
│   ├── settings.py          ★ LOGIN_URL, EMAIL_BACKEND, CSRF_TRUSTED_ORIGINS,
│   │                           SESSION_COOKIE_HTTPONLY, X_FRAME_OPTIONS
│   └── urls.py              ★ include('django.contrib.auth.urls') + notes_app
│
├── notes_app/
│   ├── models.py            ★ Note.group FK(Group, SET_NULL)
│   │                           ShoppingList.group FK(Group, SET_NULL)
│   │                           ChatMessage.group FK(Group, CASCADE)
│   ├── selectors.py         ★ get_user_notes (Q filter)
│   │                           get_user_groups (annotate member_count)
│   │                           get_group_with_members (membership check)
│   ├── services.py          ★ create_group, add_user_to_group,
│   │                           remove_user_from_group, delete_group
│   ├── views.py             ★ register, group_list, group_create,
│   │                           group_detail (3-action POST), group_delete
│   │                           + IDOR protection in note_edit, note_delete, etc.
│   ├── consumers.py         ★ GroupChatConsumer (WebSocket, membership check)
│   ├── urls.py              ★ /groups/ + /register/ URL patterns
│   ├── context_processors.py ← sidebar: notebooks + tags (unchanged)
│   └── templates/notes_app/
│       ├── note_list.html       ← Q-filter notes (personal + group)
│       ├── note_form.html       ← group field in the form
│       ├── group_list.html      ← group cards with member_count ★
│       ├── group_form.html      ← form for the new group name  ★
│       ├── group_detail.html    ← members, action=add/remove/leave ★
│       └── group_confirm_delete.html ← SET_NULL explanation  ★
│
└── templates/
    ├── base.html                ← Bootstrap CDN, messages block
    ├── layouts/
    │   └── dashboard.html       ← "Groups" in the sidebar + dropdown:
    │                               "Change password", "Log out" (POST logout)
    ├── registration/
    │   ├── login.html           ★ CSRF token, "next" hidden input
    │   ├── register.html        ★ UserCreationForm + crispy
    │   ├── password_reset_form.html    ★ email form
    │   ├── password_reset_done.html    ★ DEV: hint about docker logs
    │   ├── password_reset_confirm.html ★ validlink check + crispy form
    │   ├── password_reset_complete.html ★ success + login link
    │   ├── password_reset_email.html   ★ email text (protocol/domain/token)
    │   ├── password_change_form.html   ★ PasswordChangeForm + crispy
    │   └── password_change_done.html   ★ success
    └── components/
        ├── empty_state.html
        ├── pagination.html
        └── confirm_modal.html
```

---

## Checking in the browser: what to test

| Action | URL | What to check |
|-----|-----|---------------|
| Registration | `/register/` | Auto-login → redirect `/notes/` |
| Login | `/accounts/login/` | Session cookie in DevTools → Application → Cookies |
| Login CSRF | DevTools → Application → Cookies | `csrftoken` is present |
| Logout | POST button | The `sessionid` cookie is deleted |
| Password Reset | `/accounts/password_reset/` | Email in `docker compose logs web` |
| Token expired | `/accounts/reset/...` (old URL) | `validlink=False` → "invalid link" message |
| IDOR test | `/notes/2/edit/` (someone else's note) | 404 (not 403!) |
| Password Change | `/accounts/password_change/` | `old_password` is checked |
| Group | `/groups/new/` → `/groups/<pk>/` | Creator is a member |
| Group notes | Assign a note to a group | Another member sees it at `/notes/` |
| Group chat | `/groups/<pk>/chat/` | WebSocket connection |
| DELETE group | `/groups/<pk>/delete/` → POST | Notes become personal (`group=NULL`) |

---

## Next

Next chapter: [Checkpoint](checkpoint.md) — self-check checklist, manual IDOR test, common mistakes, practical exercise.
