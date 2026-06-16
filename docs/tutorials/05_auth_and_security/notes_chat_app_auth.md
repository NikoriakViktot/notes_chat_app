# Notes Chat App Auth — Специфіка проєкту

> Ця глава описує деталі реалізації автентифікації специфічно для `notes_chat_app` —
> production-like стеку з Docker, PostgreSQL, Redis і WebSocket чатом.
> Матеріал не дублює те що описане у попередніх главах — тут тільки унікальні деталі.

---

## Крок 0 — Docker запуск

```bash
# 1. Скопіювати конфігурацію
cp .env.example .env
# Відредагувати .env: SECRET_KEY, POSTGRES_*, за потреби NGROK_*

# 2. Підняти весь стек (PostgreSQL + Redis + Web + Nginx + ngrok + Selenium)
docker compose up --build

# 3. Переглянути логи (password reset email буде тут)
docker compose logs -f web

# 4. Відкрити у браузері
open http://localhost   # через nginx
# АБО
open http://localhost:8001   # напряму до Uvicorn

# 5. Демо-дані (3 юзери, групи, нотатки)
# Якщо SEED_DEMO_DATA=1 у .env → автоматично при старті
# Вручну:
docker compose exec web python manage.py seed_demo_data
# Логіни: demo_alice/demo1234, demo_bob/demo1234, demo_carol/demo1234
```

### Що дивитись у браузері

| URL | Що показує |
|-----|-----------|
| `http://localhost/accounts/login/` | Login форма |
| `http://localhost/register/` | Реєстрація нового акаунту |
| `http://localhost/accounts/password_reset/` | Форма відновлення пароля |
| `http://localhost/accounts/password_change/` | Зміна пароля (після входу) |
| `http://localhost/notes/` | Список нотаток (тільки залогінені) |
| `http://localhost/groups/` | Мої групи |
| `http://localhost/groups/new/` | Створити групу |
| `http://localhost/admin/` | Django Admin |

---

## Settings для Docker (settings.py)

На відміну від `crispy_notes_project` де `SECRET_KEY` може бути хардкодований для dev,
у `notes_chat_app` всі чутливі дані виносяться у `.env`:

```python
# notes_project/settings.py

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Зчитуємо з environment (Docker передає через .env / docker-compose.yml):
SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-insecure-key-change-in-production')
DEBUG = os.environ.get('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# DATABASE_URL — PostgreSQL у Docker:
# postgresql://notes_user:notes_pass@db:5432/notes_db
# 'db' — ім'я сервісу з docker-compose.yml (DNS резолюція в Docker network)
import dj_database_url
DATABASES = {
    'default': dj_database_url.config(
        default=os.environ.get('DATABASE_URL', 'sqlite:///db.sqlite3')
    )
}

# REDIS_URL для Channel Layer (WebSocket):
REDIS_URL = os.environ.get('REDIS_URL', '')
```

---

## Крок 2 — Реєстрація (Registration View)

`django.contrib.auth.urls` не включає реєстрацію — треба написати самому:

```python
# notes_app/views.py
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth import login
from django.shortcuts import redirect, render
from django.contrib import messages


def register(request):
    """
    Реєстрація нового юзера.
    Після успішної реєстрації — auto-login і redirect до note_list.
    """
    if request.user.is_authenticated:
        # Вже залогінений → не показуємо форму реєстрації
        return redirect('notes_app:note_list')

    if request.method == 'POST':
        form = UserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            # auto-login: не змушуємо юзера логінитись одразу після реєстрації
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
        {# crispy: автоматично Bootstrap 5 стилі #}
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

## Крок 3 — URL конфігурація

**Місце:** `notes_project/urls.py`

```python
from django.contrib import admin
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls

urlpatterns = [
    path("admin/", admin.site.urls),

    # Django built-in auth: login, logout, password change, password reset
    # Реєструє 8 URL одним рядком!
    path("accounts/", include("django.contrib.auth.urls")),

    # Наш застосунок: нотатки, групи, реєстрація, WebSocket chat
    path("", include("notes_app.urls", namespace="notes_app")),
] + debug_toolbar_urls()
```

**Місце:** `notes_app/urls.py`

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

    # ── Chat (WebSocket, через groups) ────────────────────────────────────
    path('groups/<int:pk>/chat/',    views.group_chat,    name='group_chat'),
]
```

---

## Структура файлів notes_chat_app після кроку

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
│   │                           + IDOR захист у note_edit, note_delete, etc.
│   ├── consumers.py         ★ GroupChatConsumer (WebSocket, membership check)
│   ├── urls.py              ★ /groups/ + /register/ URL patterns
│   ├── context_processors.py ← sidebar: notebooks + tags (без змін)
│   └── templates/notes_app/
│       ├── note_list.html       ← Q-filter нотатки (особисті + групові)
│       ├── note_form.html       ← group поле у формі
│       ├── group_list.html      ← картки груп з member_count  ★
│       ├── group_form.html      ← форма назви нової групи     ★
│       ├── group_detail.html    ← учасники, action=add/remove/leave ★
│       └── group_confirm_delete.html ← SET_NULL пояснення    ★
│
└── templates/
    ├── base.html                ← Bootstrap CDN, messages block
    ├── layouts/
    │   └── dashboard.html       ← "Групи" у sidebar + dropdown:
    │                               "Змінити пароль", "Вийти" (POST logout)
    ├── registration/
    │   ├── login.html           ★ CSRF токен, "next" hidden input
    │   ├── register.html        ★ UserCreationForm + crispy
    │   ├── password_reset_form.html    ★ email форма
    │   ├── password_reset_done.html    ★ DEV: підказка про docker logs
    │   ├── password_reset_confirm.html ★ validlink check + crispy form
    │   ├── password_reset_complete.html ★ успіх + посилання login
    │   ├── password_reset_email.html   ★ текст листа (protocol/domain/token)
    │   ├── password_change_form.html   ★ PasswordChangeForm + crispy
    │   └── password_change_done.html   ★ успіх
    └── components/
        ├── empty_state.html
        ├── pagination.html
        └── confirm_modal.html
```

---

## Перевірка у браузері: що тестувати

| Дія | URL | Що перевіряти |
|-----|-----|---------------|
| Реєстрація | `/register/` | Auto-login → redirect `/notes/` |
| Login | `/accounts/login/` | Session cookie у DevTools → Application → Cookies |
| Login CSRF | DevTools → Application → Cookies | `csrftoken` присутній |
| Logout | POST кнопка | Cookie `sessionid` видалено |
| Password Reset | `/accounts/password_reset/` | Email у `docker compose logs web` |
| Токен expired | `/accounts/reset/...` (стара URL) | `validlink=False` → "Посилання недійсне" |
| IDOR тест | `/notes/2/edit/` (чужа нотатка) | 404 (не 403!) |
| Password Change | `/accounts/password_change/` | `old_password` перевіряється |
| Група | `/groups/new/` → `/groups/<pk>/` | Creator є учасником |
| Групові нотатки | Позначити нотатку групою | Інший член бачить у `/notes/` |
| Group chat | `/groups/<pk>/chat/` | WebSocket підключення |
| DELETE group | `/groups/<pk>/delete/` → POST | Нотатки стають особистими (`group=NULL`) |

---

## Далі

Наступна глава: [Checkpoint](checkpoint.md) — чеклист самоперевірки, IDOR test вручну, типові помилки, практичне завдання.
