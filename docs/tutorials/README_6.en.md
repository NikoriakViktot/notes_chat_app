# CrispyNotes — Django Authentication and Security

> This tutorial walks you through the **full security stack of a Django application**:
> login/logout → password reset → object protection → groups for shared access.
>
> The project is **the same notes manager** from the previous lesson (crispy forms + SaaS Dashboard).
> In this lesson we add security layers on top of a finished application.
> You will see how security is "woven into" real code rather than existing separately.

---

## Contents

**Architectural foundation** _(read before the code)_
- [01 · AUTH BASICS — Authentication vs Authorization](#01--auth-basics)
- [02 · SESSIONS — How Django remembers the user](#02--sessions)
- [03 · PASSWORD SECURITY — Resetting and changing a password](#03--password-security)
- [04 · OBJECT-LEVEL PERMISSIONS — Protection against IDOR](#04--object-level-permissions)
- [05 · GROUP SHARING — Shared access via Django Groups](#05--group-sharing)
- [06 · SECURITY SETTINGS — What and why](#06--security-settings)

**Step-by-step implementation**
1. [Step 0 — Running the project](#step-0--running-the-project)
2. [Step 1 — Settings: auth + security](#step-1--settings)
3. [Step 2 — URLs: wiring up the built-in auth views](#step-2--urls)
4. [Step 3 — Login / Register templates](#step-3--login--register)
5. [Step 4 — Password Reset Flow (5 templates)](#step-4--password-reset)
6. [Step 5 — Password Change](#step-5--password-change)
7. [Step 6 — Object-Level Permissions in views.py](#step-6--object-level-permissions)
8. [Step 7 — Models: Group FK](#step-7--models-group-fk)
9. [Step 8 — Selectors: Q-filter for group access](#step-8--selectors)
10. [Step 9 — Services: Group CRUD](#step-9--services)
11. [Step 10 — Group Views + URLs](#step-10--group-views)
12. [Step 11 — Group Templates](#step-11--group-templates)
13. [Project file structure](#project-file-structure)

---

## 01 · AUTH BASICS

> **The main question:** Who are you and what are you allowed to do?
>
> These two questions are the foundation of any security system.
> Django answers them with two different systems.

### Analogy — a passport and a concert ticket

- **Passport** = **Authentication (AuthN)**: "Who are you?" — confirms identity.
  The security guard checks the document and makes sure it is genuine.
- **Ticket** = **Authorization (AuthZ)**: "Where are you allowed to go?" — defines rights.
  The cashier checks the ticket and decides where you can sit (VIP or the stalls).

At the airport: security checks your passport (AuthN), then your boarding pass (AuthZ).
A passport without a ticket — you won't get in. A ticket without a passport — neither.

### Table: AuthN vs AuthZ

| | Authentication (AuthN) | Authorization (AuthZ) |
|--|------------------------|---------------------|
| **Question** | Who are you? | What are you allowed to do? |
| **Answer** | Password check | Permission check |
| **Django tool** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Where it is checked** | `AuthenticationMiddleware` | In each view separately |
| **What if it fails** | Form with an error | 302 Redirect or 404/403 |

### Django Auth components

```python
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required

# 1. Check credentials (AuthN):
user = authenticate(request, username='alice', password='secret')
# → Django: looks up a User with username='alice'
# → Checks the PBKDF2 password hash in the DB
# → Returns the User object if it matches, or None

# 2. Start a session after a successful login:
if user is not None:
    login(request, user)   # ← creates a session_id in the DB + a cookie in the browser
    # Now request.user = alice in all subsequent requests

# 3. End the session:
logout(request)   # ← deletes the session record from the DB + forcibly clears the cookie
```

### Middleware chain: who sets `request.user`

```
Every request passes through the ENTIRE middleware chain:

1. SecurityMiddleware       — HTTPS redirect, HTTP security headers
2. SessionMiddleware        — reads Cookie: sessionid=... → loads the session from the DB
3. CommonMiddleware         — trailing slash, Content-Type
4. CsrfViewMiddleware       — checks csrfmiddlewaretoken in POST
5. AuthenticationMiddleware — reads the session → sets request.user
   │                          If there is a session → request.user = User(id=42)
   │                          If not                → request.user = AnonymousUser
6. MessageMiddleware        — Django messages flash framework
7. XFrameOptionsMiddleware  — X-Frame-Options: DENY header
   │
   ▼
View function (request.user is already set!)
```

### `@login_required` — what it does and where it lives

```python
# hello_app/views.py
from django.contrib.auth.decorators import login_required

@login_required   # ← decorator, checks request.user.is_authenticated
def note_list(request):
    # If request.user = AnonymousUser:
    #   → redirect to LOGIN_URL (settings.py) + ?next=/notes/
    #   → 302 /accounts/login/?next=/notes/
    # If request.user = User(id=42):
    #   → runs the view normally
    notes = selectors.get_user_notes(request.user)
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

```python
# settings.py — where to redirect users who are not logged in:
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'         # where to go AFTER a successful login
LOGOUT_REDIRECT_URL = '/accounts/login/'  # where to go AFTER logout
```

> **Important:** `@login_required` is only AuthN ("are you logged in?").
> It does NOT check whether this particular note belongs to you.
> That requires a separate AuthZ step in the view.

---

## 02 · SESSIONS

> **The problem:** HTTP is a stateless protocol. Every request is as if it were the "first".
> The server does not know who you are unless you send proof.

### Analogy — a loyalty card at a café

Imagine a café where you earn points for every coffee. Without a card, the waiter forgets you
after every visit. With a card, the points add up.

**Session cookie = loyalty card**: the browser stores it and automatically presents it with every request.

### Step-by-step flow: Login → Cookie → Next request

```
STEP 1: Alice clicks "Log in"
─────────────────────────────────────────────────────────────────
Browser:  POST /accounts/login/  {username: 'alice', password: 'secret'}
Django:   authenticate('alice', 'secret') → User(id=42) ✓
          login(request, user)
            → INSERT INTO django_session (session_key='xK9mPq', user_id=42, expire=...)
          Response: 302 /notes/
          Header:    Set-Cookie: sessionid=xK9mPq; HttpOnly; SameSite=Lax; Path=/

STEP 2: The browser stores the cookie. Alice sees /notes/
─────────────────────────────────────────────────────────────────
Browser stores: sessionid=xK9mPq (in protected storage)

STEP 3: Alice's next request (/notes/)
─────────────────────────────────────────────────────────────────
Browser:  GET /notes/
Header:   Cookie: sessionid=xK9mPq   ← automatically!
          Django SessionMiddleware:
            SELECT * FROM django_session WHERE session_key='xK9mPq'
            → user_id = 42
          Django AuthenticationMiddleware:
            SELECT * FROM auth_user WHERE id=42
            → request.user = User(id=42, username='alice')
View:     request.user.is_authenticated → True ✓
          notes = Note.objects.filter(user=request.user)

STEP 4: Logging out (Logout)
─────────────────────────────────────────────────────────────────
Browser:  POST /accounts/logout/  (with the CSRF token)
Django:   logout(request)
            → DELETE FROM django_session WHERE session_key='xK9mPq'
          Response: 302 /accounts/login/
          Header:    Set-Cookie: sessionid=; expires=Thu, 01 Jan 1970...
Browser:  Deletes the cookie. request.user → AnonymousUser.
```

### Cookie settings in settings.py

```python
# settings.py:

SESSION_COOKIE_HTTPONLY = True
# ↑ JS cannot read sessionid via document.cookie
#   Protection against XSS attacks that try to steal the cookie

SESSION_COOKIE_SAMESITE = "Lax"
# ↑ "Lax": the cookie is sent only from the same site
#   Protection against CSRF (evil.com cannot send a request with your cookie)
#   "Strict" — stricter, but can break OAuth flows
#   "None" — dangerous without the Secure flag

CSRF_COOKIE_HTTPONLY = False
# ↑ False: JS can read csrftoken (needed for fetch/axios requests)
#   If you don't use JS for forms → True for strict protection

# Production HTTPS (uncomment when you have an SSL certificate):
# SESSION_COOKIE_SECURE = True   # cookie only over HTTPS
# CSRF_COOKIE_SECURE = True
```

---

## 03 · PASSWORD SECURITY

> Django provides a **complete password management system "out of the box"** via `django.contrib.auth`.
> You don't need to write a single view for login, logout, password reset or change.

### What `include('django.contrib.auth.urls')` wires up

```python
# hello_project/urls.py:
path("accounts/", include("django.contrib.auth.urls")),
```

This automatically registers the following URLs:

| URL | View | Name | Template (you must create it) |
|-----|------|-------|------------------------|
| `/accounts/login/` | `LoginView` | `login` | `registration/login.html` |
| `/accounts/logout/` | `LogoutView` | `logout` | (redirect) |
| `/accounts/password_change/` | `PasswordChangeView` | `password_change` | `registration/password_change_form.html` |
| `/accounts/password_change/done/` | `PasswordChangeDoneView` | `password_change_done` | `registration/password_change_done.html` |
| `/accounts/password_reset/` | `PasswordResetView` | `password_reset` | `registration/password_reset_form.html` |
| `/accounts/password_reset/done/` | `PasswordResetDoneView` | `password_reset_done` | `registration/password_reset_done.html` |
| `/accounts/reset/<uidb64>/<token>/` | `PasswordResetConfirmView` | `password_reset_confirm` | `registration/password_reset_confirm.html` |
| `/accounts/reset/done/` | `PasswordResetCompleteView` | `password_reset_complete` | `registration/password_reset_complete.html` |

**Conclusion:** 8 URLs + 7 views = you only write the templates!

### Password Reset Flow — 5 steps

```
Step 1: /accounts/password_reset/
─────────────────────────────────────────────────────────────────
Alice forgot her password → enters her email in the form
→ password_reset_form.html

Step 2: Django processes the POST
─────────────────────────────────────────────────────────────────
Django looks up a User with that email
Generates a unique token: sha1(user_pk + timestamp + SECRET_KEY)
Sends an email with the link:
  /accounts/reset/<uidb64>/<token>/

[DEV: email → console (EMAIL_BACKEND = console)]
[PROD: email → SMTP server]

Step 3: /accounts/password_reset/done/
─────────────────────────────────────────────────────────────────
Django shows: "Check your email"
→ password_reset_done.html

Step 4: /accounts/reset/<uidb64>/<token>/
─────────────────────────────────────────────────────────────────
Alice follows the link from the email
Django: checks the token (valid? 72 hours, single-use?)
If OK → form for the new password
→ password_reset_confirm.html

Step 5: Success → /accounts/reset/done/
─────────────────────────────────────────────────────────────────
Password saved (PBKDF2-hashed) → sessions reset
→ password_reset_complete.html
```

### Password Validators — Django protects against weak passwords

```python
# settings.py — 4 built-in validators:
AUTH_PASSWORD_VALIDATORS = [
    # Is the password similar to the username / email / name?
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    # At least 8 characters (by default):
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    # Is it in the list of the 20,000 most common passwords? ("password", "123456"...)
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    # Does it consist only of digits?
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
```

---

## 04 · OBJECT-LEVEL PERMISSIONS

> **The most common vulnerability in web applications (OWASP A01):**
> Broken Access Control — a user gains access to someone else's data.

### What IDOR (Insecure Direct Object Reference) is

```
Alice is registered. She sees the URL of her note: /notes/42/edit/
She thinks: "What happens if I change 42 to 43?"
Alice navigates to: /notes/43/edit/
If the view doesn't check the owner → Alice edits BOB's note!
```

This is an **IDOR** attack — direct access to an object by ID without a permission check.

### The difference between AuthN and AuthZ (by example)

```python
# PROBLEM: @login_required is only AuthN, not AuthZ!
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR vulnerability!
    # Alice is logged in → @login_required lets her through
    # But note 43 belongs to Bob → Alice edits someone else's data!

# SOLUTION: add user= to get_object_or_404
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)   # ← AuthZ ✓
    # pk=43 + user=Alice → Django looks for Note WHERE pk=43 AND user_id=Alice.id
    # No such record (43 belongs to Bob) → 404 for Alice
```

**Golden rule:**
```
@login_required        = "are you logged in?"     (AuthN)
get_object_or_404(     = "is this object yours?"  (AuthZ)
    Note, pk=pk,
    user=request.user
)
```

### Pattern for your own objects

```python
# Applies to: note_edit, note_delete, note_detail,
# notebook_edit, notebook_delete, shopping_edit, shopping_delete, etc.

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    #      ↑ If note.user != request.user → 404 (not 403, so as not to reveal that it exists)
    if request.method == 'POST':
        note.delete()
        messages.warning(request, 'Нотатку видалено.')
        return redirect('hello_app:note_list')
    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### Pattern for shared objects (owner OR group member)

```python
# For notes with a group — a more complex check:
from django.core.exceptions import PermissionDenied
from django.db.models import Q

@login_required
def note_detail(request, pk):
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(
            Q(user=request.user) | Q(group__in=user_groups)
        ),
        pk=pk
    )
    # Alice sees the note if:
    #   note.user == Alice (personal)
    #   OR note.group in Alice.groups.all() (group)
    return render(request, 'hello_app/note_detail.html', {'note': note})
```

### Table of protected views in the project

| View | Protection | How |
|------|--------|----|
| `note_list` | `@login_required` | Shows only your own + group ones (selector) |
| `note_edit` | `@login_required` + owner check | `get_object_or_404(Note, pk=pk, user=request.user)` |
| `note_delete` | `@login_required` + owner check | Same |
| `group_detail` | `@login_required` + membership | `get_group_with_members(pk, request.user)` → None if not a member |
| `group_delete` | `@login_required` + membership | `group.user_set.filter(pk=request.user.pk).exists()` |

---

## 05 · GROUP SHARING

> **The idea:** Alice wants to share notes with her family.
> She creates the group "Family" and adds Bob to it.
> Notes tagged with this group are visible to both.

### Django's built-in Group model

Django already has a ready-made `Group` model in `django.contrib.auth`:

```python
from django.contrib.auth.models import Group

# Every Group has:
#   id       — PK
#   name     — name ('Сімя', 'Команда', 'Клас')
#   users    — M2N relation to User (via django_auth_user_groups)
#   permissions — M2N relation to Permission (for role-based access — NOT our case)

# In our project we use Group for DATA SHARING,
# not for the Django Permission System.
```

### ER diagram: User, Group, Note

```
┌─────────────┐        ┌──────────────────┐        ┌─────────────┐
│    User     │        │auth_user_groups  │        │    Group    │
│─────────────│        │──────────────────│        │─────────────│
│ id (PK)     │◄──────►│ user_id (FK)     │◄──────►│ id (PK)     │
│ username    │  M:N   │ group_id (FK)    │  M:N   │ name        │
│ password    │        └──────────────────┘        └──────┬──────┘
│ email       │                                           │
└──────┬──────┘                                           │ 1:N
       │ 1:N                                              │
       ▼                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                             Note                                 │
│─────────────────────────────────────────────────────────────────│
│ id (PK)                                                         │
│ title                                                           │
│ content                                                         │
│ user_id  (FK → User, CASCADE)    ← required, owner              │
│ group_id (FK → Group, SET_NULL)  ← optional, sharing            │
└─────────────────────────────────────────────────────────────────┘

If group_id = NULL  → personal note (only user_id sees it)
If group_id = 5     → group note (all members of group 5 see it)
```

### Q-filter: "mine or the group's"

```python
# selectors.py — a clever query:
from django.db.models import Q

def get_user_notes(user, *, archived=False, ...):
    user_groups = user.groups.all()   # all of Alice's groups
    qs = Note.objects.filter(
        Q(user=user) |               # own notes OR
        Q(group__in=user_groups),    # notes of groups where Alice is a member
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

```
Alice is in the groups: [Сімя(id=1), Робота(id=3)]

SQL (simplified):
  SELECT * FROM note
  WHERE (user_id = 42)                          -- Alice's personal ones
     OR (group_id IN (1, 3))                    -- notes of her groups
  AND is_archived = FALSE
  ORDER BY is_pinned DESC, priority DESC, updated_at DESC
```

### Comparing approaches to sharing

| | M2M `shared_with` (previous lesson) | Group FK (this lesson) |
|--|-------------------------------------|---------------------|
| **Where** | `TodoList.shared_with = ManyToManyField(User)` | `Note.group = ForeignKey(Group)` |
| **Shared with** | Specific users (a list of people) | All group members |
| **Management** | Via `/todo/<pk>/share/` | Via `/groups/<pk>/` |
| **When it fits** | "Share with Bob and Kara" | "Share with the whole family" |
| **Deletion** | The ManyToMany join is deleted | `SET_NULL` → the note becomes personal |

---

## 06 · SECURITY SETTINGS

> Django has many security settings. Most of them are "off" by default
> so as not to break localhost development. In production they must be turned on.

### Table: each setting and what it protects against

| Setting | Value | What it protects against |
|-----------|----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | JS doesn't read the cookie | XSS attacks for session hijacking |
| `SESSION_COOKIE_SAMESITE = "Lax"` | Cookie only from the same site | CSRF via cross-site forms |
| `CSRF_COOKIE_HTTPONLY = False` | JS reads csrftoken | (False = for fetch/axios) |
| `X_FRAME_OPTIONS = "DENY"` | Bans `<iframe>` | Clickjacking attacks |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | Don't "guess" MIME | XSS via forged files |
| `DEBUG = False` | Hides stack traces | Leaking SECRET_KEY and code |
| `ALLOWED_HOSTS = ['mysite.com']` | Only this domain | HTTP Host header attacks |

### What leaks with `DEBUG = True` in production

```
A server error with DEBUG=True shows:
  ✗ The full stack trace (file paths, function names)
  ✗ The values of ALL local variables at the moment of the error
  ✗ SECRET_KEY (a leak = anyone can forge session cookies!)
  ✗ All SQL queries are kept in memory → memory leak
  ✗ INSTALLED_APPS, DATABASES, MIDDLEWARE — the whole config is visible

Rule: DEBUG = False ALWAYS in production.
```

### Production HTTPS (uncomment on the server)

```python
# settings.py — commented out in dev, enable in production:

# SESSION_COOKIE_SECURE = True
# ↑ The cookie is sent ONLY over HTTPS (not over HTTP)
# Without this, a man-in-the-middle attacker can intercept sessionid

# CSRF_COOKIE_SECURE = True
# ↑ The same for the CSRF cookie

# SECURE_SSL_REDIRECT = True
# ↑ Any HTTP request → 301 Moved Permanently → HTTPS

# SECURE_HSTS_SECONDS = 31536000  # 1 year
# ↑ The browser remembers: this site is HTTPS ONLY, never HTTP
# (Strict-Transport-Security header)
```

---

## Step 0 — Running the project

```bash
# 1. Go to the project folder
cd module_5/lesson_Django_authentication_and_security/crispy_notes_project

# 2. Install dependencies
pip install -r requirements.txt
# Django>=5.2, django-crispy-forms>=2.3, crispy-bootstrap5, django-debug-toolbar

# 3. Apply migrations (including 0003 — Group FK)
python manage.py migrate

# 4. Create a superuser for /admin/
python manage.py createsuperuser

# 5. Start the server
python manage.py runserver
```

### What to look at in the browser

| URL | What it shows |
|-----|-----------|
| `http://127.0.0.1:8000/accounts/login/` | Login form with "Забули пароль?" (Forgot password?) |
| `http://127.0.0.1:8000/register/` | Registering a new account |
| `http://127.0.0.1:8000/accounts/password_reset/` | Password recovery form |
| `http://127.0.0.1:8000/accounts/password_change/` | Changing the password (after login) |
| `http://127.0.0.1:8000/notes/` | List of notes (logged-in users only) |
| `http://127.0.0.1:8000/groups/` | My groups |
| `http://127.0.0.1:8000/groups/new/` | Create a group |
| `http://127.0.0.1:8000/admin/` | Django Admin |

---

## Step 1 — Settings

**Location:** `hello_project/settings.py`

```python
# ── Auth redirects ─────────────────────────────────────────────────────────────
LOGIN_URL = '/accounts/login/'           # where @login_required redirects to
LOGIN_REDIRECT_URL = '/notes/'           # where to go AFTER a successful login
LOGOUT_REDIRECT_URL = '/accounts/login/' # where to go AFTER logout

# ── Password Validators ────────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ── Email (password reset) ─────────────────────────────────────────────────────
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
# ↑ DEV: the email is printed in the terminal (runserver), not actually sent
# PROD: replace with:
# EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
# EMAIL_HOST = "smtp.gmail.com"
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = os.environ['EMAIL_HOST_USER']
# EMAIL_HOST_PASSWORD = os.environ['EMAIL_HOST_PASSWORD']

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True     # JS doesn't read sessionid (XSS protection)
CSRF_COOKIE_HTTPONLY = False       # JS reads csrftoken (for fetch/axios)
SESSION_COOKIE_SAMESITE = "Lax"   # CSRF protection for cookies
X_FRAME_OPTIONS = "DENY"          # Clickjacking protection
SECURE_CONTENT_TYPE_NOSNIFF = True # MIME sniffing protection

# Production HTTPS (uncomment on the server):
# SESSION_COOKIE_SECURE = True
# CSRF_COOKIE_SECURE = True
# SECURE_SSL_REDIRECT = True
# SECURE_HSTS_SECONDS = 31536000

# ── Messages → Bootstrap alert variants ────────────────────────────────────────
from django.contrib.messages import constants as messages_constants
MESSAGE_TAGS = {
    messages_constants.DEBUG:   'secondary',
    messages_constants.INFO:    'info',
    messages_constants.SUCCESS: 'success',
    messages_constants.WARNING: 'warning',
    messages_constants.ERROR:   'danger',
}
```

---

## Step 2 — URLs

**Location:** `hello_project/urls.py`

```python
from django.contrib import admin
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls

urlpatterns = [
    path("admin/", admin.site.urls),

    # Django built-in auth: login, logout, password change, password reset
    # Registers 8 URLs with a single line!
    path("accounts/", include("django.contrib.auth.urls")),

    # Our application: notes, groups, registration
    path("", include("hello_app.urls", namespace="hello_app")),
] + debug_toolbar_urls()
```

`hello_app/urls.py` — custom URLs (registration and groups):

```python
urlpatterns = [
    # ... notes, notebooks, todo, shopping ...

    # Registration (Django doesn't provide it — we write it ourselves)
    path('register/', views.register, name='register'),

    # Groups — 4 URLs for group CRUD
    path('groups/',                  views.group_list,    name='group_list'),
    path('groups/new/',              views.group_create,  name='group_create'),
    path('groups/<int:pk>/',         views.group_detail,  name='group_detail'),
    path('groups/<int:pk>/delete/',  views.group_delete,  name='group_delete'),
]
```

---

## Step 3 — Login / Register

**Location:** `templates/registration/login.html`

Django automatically looks for the `registration/login.html` template for `LoginView`.

```html
{% extends 'base.html' %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 380px;">
    <div class="card-body p-4">

      <!-- Brand -->
      <div class="text-center mb-4">
        <i class="bi bi-journal-text display-4 text-primary"></i>
        <h5 class="fw-bold mt-2 mb-0">CrispyNotes</h5>
        <p class="text-muted small">Увійди до свого акаунту</p>
      </div>

      <!-- Login error -->
      {% if form.errors %}
      <div class="alert alert-danger py-2 small">
        Невірний логін або пароль.
      </div>
      {% endif %}

      <!-- Login form (the CSRF token is mandatory!) -->
      <form method="post">
        {% csrf_token %}   {# ← MANDATORY! without it Django will reject the POST #}
        <div class="mb-3">
          <label class="form-label fw-semibold">Логін</label>
          <input type="text" name="{{ form.username.html_name }}"
                 class="form-control" autofocus>
        </div>
        <div class="mb-4">
          <label class="form-label fw-semibold">Пароль</label>
          <input type="password" name="{{ form.password.html_name }}"
                 class="form-control">
        </div>
        <input type="hidden" name="next" value="{{ next }}">
        {# ↑ next: where to return after login (for example /notes/42/) #}
        <button type="submit" class="btn btn-primary w-100">Увійти</button>
      </form>

      <hr class="my-3">
      <p class="text-center text-muted small mb-1">
        Немає акаунту? <a href="{% url 'hello_app:register' %}">Зареєструватись</a>
      </p>
      <p class="text-center text-muted small mb-0">
        <a href="{% url 'password_reset' %}">Забули пароль?</a>
        {# ↑ 'password_reset' — a built-in URL from django.contrib.auth.urls #}
      </p>
    </div>
  </div>
</div>
{% endblock %}
```

---

## Step 4 — Password Reset

Django provides 4 views for password reset. You only need to write the templates.

### password_reset_form.html — email form

```html
{% extends 'base.html' %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 420px;">
    <div class="card-body p-4">
      <h5 class="fw-bold mb-1">Відновлення паролю</h5>
      <p class="text-muted small mb-3">
        Введіть ваш email — надішлемо посилання для скидання пароля.
      </p>
      <form method="post">
        {% csrf_token %}
        <div class="mb-3">
          <label class="form-label fw-semibold">Email</label>
          <input type="email" name="email" class="form-control" autofocus>
        </div>
        <button type="submit" class="btn btn-primary w-100">
          Надіслати посилання
        </button>
      </form>
      <div class="text-center mt-3">
        <a href="{% url 'login' %}" class="text-muted small">← Назад до входу</a>
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### password_reset_done.html — "check your email"

```html
{% extends 'base.html' %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 420px;">
    <div class="card-body p-4 text-center">
      <i class="bi bi-envelope-check display-4 text-success mb-3"></i>
      <h5 class="fw-bold">Посилання надіслано!</h5>
      <p class="text-muted">Перевірте вашу пошту і перейдіть за посиланням.</p>
      <div class="alert alert-info text-start small mt-3">
        <strong>DEV режим:</strong> Лист не надсилається на пошту.
        Відкрийте термінал з <code>runserver</code> — там буде текст листа.
        Скопіюйте <code>/accounts/reset/...</code> URL і відкрийте у браузері.
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### password_reset_confirm.html — new password form

```html
{% extends 'base.html' %}
{% load crispy_forms_tags %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 420px;">
    <div class="card-body p-4">

      {% if validlink %}
        <h5 class="fw-bold mb-3">Новий пароль</h5>
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          <button type="submit" class="btn btn-primary w-100 mt-2">
            Зберегти пароль
          </button>
        </form>
      {% else %}
        {# The token is invalid (expired or already used) #}
        <div class="text-center py-3">
          <i class="bi bi-exclamation-triangle display-4 text-danger mb-3"></i>
          <h5>Посилання недійсне</h5>
          <p class="text-muted small">Термін дії посилання вийшов або воно вже використано.</p>
          <a href="{% url 'password_reset' %}" class="btn btn-outline-primary">
            Запросити нове посилання
          </a>
        </div>
      {% endif %}

    </div>
  </div>
</div>
{% endblock %}
```

### password_reset_complete.html

```html
{% extends 'base.html' %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 380px;">
    <div class="card-body p-4 text-center">
      <i class="bi bi-check-circle display-4 text-success mb-3"></i>
      <h5 class="fw-bold">Пароль змінено!</h5>
      <p class="text-muted">Тепер ви можете увійти з новим паролем.</p>
      <a href="{% url 'login' %}" class="btn btn-primary mt-2">Увійти</a>
    </div>
  </div>
</div>
{% endblock %}
```

### password_reset_email.html — the email text

```html
{# This is a plain-text email — no HTML tags! #}
Привіт!

Ви запросили скидання пароля для акаунту на CrispyNotes.
Перейдіть за посиланням щоб встановити новий пароль:

{{ protocol }}://{{ domain }}{% url 'password_reset_confirm' uidb64=uid token=token %}

Посилання дійсне 72 години.

Якщо ви не запитували скидання пароля — просто проігноруйте цей лист.

— CrispyNotes
```

### How to find the link in the console (dev)

```bash
# After submitting the password_reset form — look in the terminal:

Content-Type: text/plain; charset="utf-8"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Subject: ...
...

Привіт!

Ви запросили скидання пароля...
http://127.0.0.1:8000/accounts/reset/Mg/abc123token456/   ← copy this URL!
```

---

## Step 5 — Password Change

Password change requires that the user is **already logged in** (unlike password reset).

### password_change_form.html

```html
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block topbar_title %}Зміна пароля{% endblock %}

{% block content %}
<div class="row">
  <div class="col-md-6">
    <div class="card shadow-sm">
      <div class="card-header py-3">
        <h6 class="mb-0 fw-semibold">
          <i class="bi bi-key me-2"></i>Зміна пароля
        </h6>
      </div>
      <div class="card-body">
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          {# The form automatically contains: old_password, new_password1, new_password2 #}
          <hr>
          <button type="submit" class="btn btn-primary">Змінити пароль</button>
          <a href="{% url 'hello_app:note_list' %}" class="btn btn-outline-secondary ms-2">
            Скасувати
          </a>
        </form>
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### Links in the dropdown (dashboard.html)

```html
{# templates/layouts/dashboard.html — the user dropdown: #}
<ul class="dropdown-menu dropdown-menu-dark dropdown-menu-end shadow">
  <li><a class="dropdown-item" href="{% url 'hello_app:group_list' %}">
    <i class="bi bi-people me-2"></i>Мої групи
  </a></li>
  <li><a class="dropdown-item" href="{% url 'password_change' %}">
    <i class="bi bi-key me-2"></i>Змінити пароль
  </a></li>
  <li><hr class="dropdown-divider"></li>
  <li>
    <form method="post" action="{% url 'logout' %}">
      {% csrf_token %}
      <button type="submit" class="dropdown-item text-danger">Вийти</button>
    </form>
  </li>
</ul>
```

---

## Step 6 — Object-Level Permissions

The pattern is applied **in every view** that takes a `pk` parameter.

```python
# hello_app/views.py — the general pattern for your OWN objects:

@login_required
def note_edit(request, pk):
    # get_object_or_404 with user=request.user:
    #   1. Looks for Note WHERE pk=<pk> AND user_id=<request.user.id>
    #   2. If not found → 404 (not 403! — we don't reveal that the object exists)
    note = get_object_or_404(Note, pk=pk, user=request.user)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            cd = form.cleaned_data
            services.update_note(
                note,
                title=cd['title'],
                content=cd.get('content', ''),
                priority=cd.get('priority', note.priority),
                notebook=cd.get('notebook'),
                is_pinned=cd.get('is_pinned', False),
                tag_ids=[t.pk for t in cd.get('tags', [])],
            )
            messages.success(request, 'Нотатку оновлено.')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note, user=request.user)

    return render(request, 'hello_app/note_form.html', {
        'form': form, 'title': 'Редагування нотатки',
    })
```

```python
# Before (vulnerable to IDOR):
note = get_object_or_404(Note, pk=pk)   # ← any pk!

# After (protected):
note = get_object_or_404(Note, pk=pk, user=request.user)  # ← only your own pk!
```

---

## Step 7 — Models: Group FK

**Location:** `hello_app/models.py`

```python
from django.contrib.auth.models import User, Group

class Note(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notes'
    )
    # ── Group FK (new in this lesson) ──────────────────────────────────────
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,  # ← if the group is deleted → the note becomes personal
        null=True,                   # ← NULL = personal note (by default)
        blank=True,                  # ← the field is optional in the form
        related_name='notes',
    )
    # ── the rest of the fields ──────────────────────────────────────────────
    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)
    priority = models.PositiveSmallIntegerField(default=1)
    # ...
```

### Why `SET_NULL` and not `CASCADE`?

```
CASCADE: deleting a group → ALL of the group's notes are deleted
         → Alice deletes the group → Bob loses all shared notes!

SET_NULL: deleting a group → the notes remain, but become personal (group=NULL)
          → Alice deletes the group → the notes move to the owner's personal space
          → Bob sees that there are no more shared notes, but the original owners kept theirs
```

### Migration 0003

```python
# hello_app/migrations/0003_note_group_shoppinglist_group.py

from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [
        ('auth', '0012_alter_user_first_name_max_length'),  # ← Group from auth
        ('hello_app', '0002_shoppinglist_shared_with_todolist_shared_with'),
    ]
    operations = [
        migrations.AddField(
            model_name='note',
            name='group',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='notes',
                to='auth.group',
            ),
        ),
        migrations.AddField(
            model_name='shoppinglist',
            name='group',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='shopping_lists',
                to='auth.group',
            ),
        ),
    ]
```

---

## Step 8 — Selectors

**Location:** `hello_app/selectors.py`

```python
from django.db.models import Q, Count
from django.contrib.auth.models import Group


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Returns the user's notes + notes of groups where they are a member."""
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # ← the key Q-filter
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if tag is not None:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(Q(title__icontains=search) | Q(content__icontains=search))

    return qs.order_by('-is_pinned', '-priority', '-updated_at')


def get_user_groups(user):
    """The user's groups with the member count (for display on group_list)."""
    return user.groups.annotate(
        member_count=Count('user')   # ← annotate = we add a member_count field to the queryset
    ).order_by('name')


def get_group_with_members(group_id, user):
    """Returns the group with its members ONLY if the user is a member of it."""
    try:
        group = Group.objects.prefetch_related('user_set').get(pk=group_id)
        # Membership check — if the user is not in the group → return None
        if not group.user_set.filter(pk=user.pk).exists():
            return None
        return group
    except Group.DoesNotExist:
        return None
```

---

## Step 9 — Services

**Location:** `hello_app/services.py`

```python
from django.contrib.auth.models import Group, User


def create_group(*, name, creator):
    """Creates a group and automatically adds the creator as the first member."""
    group = Group.objects.create(name=name)
    group.user_set.add(creator)   # ← the creator becomes the first member
    return group


def add_user_to_group(group, username):
    """Adds a user to the group by username. Returns (True, '') or (False, 'message')."""
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return False, f'Користувача «{username}» не знайдено.'

    if group.user_set.filter(pk=user.pk).exists():
        return False, f'«{username}» вже є членом цієї групи.'

    group.user_set.add(user)
    return True, ''


def remove_user_from_group(group, user):
    """Removes a user from the group."""
    group.user_set.remove(user)


def delete_group(group):
    """Deletes the group. The group's notes become personal (group=NULL via SET_NULL)."""
    group.delete()
    # Django automatically performs SET_NULL for Note.group and ShoppingList.group
```

---

## Step 10 — Group Views

**Location:** `hello_app/views.py`

```python
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied
from . import selectors, services
from .forms import GroupCreateForm, GroupAddMemberForm


@login_required
def group_list(request):
    """List of the groups the current user belongs to."""
    groups = selectors.get_user_groups(request.user)
    return render(request, 'hello_app/group_list.html', {'groups': groups})


@login_required
def group_create(request):
    """Creating a new group. The creator automatically becomes the first member."""
    if request.method == 'POST':
        form = GroupCreateForm(request.POST)
        if form.is_valid():
            group = services.create_group(
                name=form.cleaned_data['name'],
                creator=request.user,       # ← request.user = the first member
            )
            messages.success(request, f'Групу «{group.name}» створено!')
            return redirect('hello_app:group_detail', pk=group.pk)
    else:
        form = GroupCreateForm()
    return render(request, 'hello_app/group_form.html', {
        'form': form, 'title': 'Нова група',
    })


@login_required
def group_detail(request, pk):
    """Group view: members, add/remove, leave."""
    group = selectors.get_group_with_members(pk, request.user)
    if group is None:
        raise Http404('Групу не знайдено або у вас немає доступу.')
    # ↑ If the user is not a member → Http404 (not 403, so as not to reveal that the group exists)

    add_form = GroupAddMemberForm()
    error = None

    if request.method == 'POST':
        action = request.POST.get('action')   # 'add' / 'remove' / 'leave'

        if action == 'add':
            add_form = GroupAddMemberForm(request.POST)
            if add_form.is_valid():
                ok, msg = services.add_user_to_group(
                    group, add_form.cleaned_data['username']
                )
                if ok:
                    messages.success(request, 'Користувача додано до групи.')
                    return redirect('hello_app:group_detail', pk=pk)
                else:
                    error = msg   # ← "Not found" or "already a member"

        elif action == 'remove':
            remove_pk = request.POST.get('user_pk')
            try:
                target = User.objects.get(pk=remove_pk)
                services.remove_user_from_group(group, target)
                messages.success(request, f'«{target.username}» видалено.')
            except User.DoesNotExist:
                pass
            return redirect('hello_app:group_detail', pk=pk)

        elif action == 'leave':
            services.remove_user_from_group(group, request.user)
            messages.info(request, f'Ви покинули групу «{group.name}».')
            return redirect('hello_app:group_list')

    return render(request, 'hello_app/group_detail.html', {
        'group': group,
        'members': group.user_set.all(),
        'add_form': add_form,
        'error': error,
    })


@login_required
def group_delete(request, pk):
    """Deleting a group (only if the user is a member)."""
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise PermissionDenied   # ← 403 (we know the group exists, but the user is not a member)
    if request.method == 'POST':
        name = group.name
        services.delete_group(group)
        messages.warning(request, f'Групу «{name}» видалено. Спільні нотатки стали особистими.')
        return redirect('hello_app:group_list')
    return render(request, 'hello_app/group_confirm_delete.html', {'group': group})
```

**The key pattern in `group_detail`:**

```
One view — three actions through a single POST:

action = request.POST.get('action')

'add'    → add a member by username
'remove' → remove a specific member (by user_pk)
'leave'  → the current user leaves the group

Why a single view? All the group logic is in one place — easier to read and maintain.
```

---

## Step 11 — Group Templates

**Location:** `hello_app/templates/hello_app/`

### group_list.html — group cards

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Мої групи{% endblock %}
{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
  <h5 class="fw-semibold mb-0">Мої групи</h5>
  <a href="{% url 'hello_app:group_create' %}" class="btn btn-primary btn-sm">
    <i class="bi bi-person-plus me-1"></i>Нова група
  </a>
</div>

{% if groups %}
<div class="row row-cols-1 row-cols-md-3 g-3">
  {% for group in groups %}
  <div class="col">
    <div class="card h-100 shadow-sm">
      <div class="card-body">
        <h6 class="fw-semibold">{{ group.name }}</h6>
        <p class="text-muted small">{{ group.member_count }} учасників</p>
        {# member_count — annotate from the get_user_groups selector #}
      </div>
      <div class="card-footer">
        <a href="{% url 'hello_app:group_detail' group.pk %}"
           class="btn btn-outline-primary btn-sm">Відкрити</a>
      </div>
    </div>
  </div>
  {% endfor %}
</div>
{% else %}
  {# No groups — empty state #}
  {% include 'components/empty_state.html' with icon="bi-people" message="Груп ще немає" %}
{% endif %}

{% endblock %}
```

### group_detail.html — members and actions

```html
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}
{% block topbar_title %}Група: {{ group.name }}{% endblock %}
{% block content %}

<div class="row g-4">
  <!-- Member list -->
  <div class="col-md-6">
    <div class="card shadow-sm">
      <div class="card-header">
        <h6 class="mb-0">Учасники ({{ members.count }})</h6>
      </div>
      <ul class="list-group list-group-flush">
        {% for member in members %}
        <li class="list-group-item d-flex justify-content-between align-items-center">
          <span>
            {{ member.username }}
            {% if member == request.user %}
              <span class="badge bg-success ms-1">Ти</span>
            {% endif %}
          </span>
          {% if member != request.user %}
          <!-- Remove a member (action=remove) -->
          <form method="post">
            {% csrf_token %}
            <input type="hidden" name="action" value="remove">
            <input type="hidden" name="user_pk" value="{{ member.pk }}">
            <button type="submit" class="btn btn-outline-danger btn-sm">
              <i class="bi bi-x"></i>
            </button>
          </form>
          {% endif %}
        </li>
        {% endfor %}
      </ul>
    </div>
  </div>

  <!-- Actions: add a member, leave, delete -->
  <div class="col-md-6">
    <!-- Add a member (action=add) -->
    <div class="card shadow-sm mb-3">
      <div class="card-header"><h6 class="mb-0">Додати учасника</h6></div>
      <div class="card-body">
        {% if error %}<div class="alert alert-danger small">{{ error }}</div>{% endif %}
        <form method="post">
          {% csrf_token %}
          <input type="hidden" name="action" value="add">
          {% crispy add_form %}
        </form>
      </div>
    </div>

    <!-- Danger zone: leave or delete -->
    <div class="card border-danger shadow-sm">
      <div class="card-body">
        <h6 class="text-danger mb-3">Небезпечна зона</h6>
        <!-- Leave the group (action=leave) -->
        <form method="post" class="d-inline">
          {% csrf_token %}
          <input type="hidden" name="action" value="leave">
          <button type="submit" class="btn btn-outline-danger btn-sm me-2"
                  onclick="return confirm('Покинути групу?')">
            Покинути групу
          </button>
        </form>
        <!-- Delete the group (separate URL) -->
        <a href="{% url 'hello_app:group_delete' group.pk %}"
           class="btn btn-danger btn-sm">
          Видалити групу
        </a>
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### group_confirm_delete.html

```html
{% extends 'layouts/dashboard.html' %}
{% block content %}
<div class="card border-danger shadow-sm" style="max-width: 480px;">
  <div class="card-header bg-danger text-white">
    <h6 class="mb-0">Видалення групи «{{ group.name }}»</h6>
  </div>
  <div class="card-body">
    <div class="alert alert-warning">
      <strong>Увага!</strong> Після видалення:
      <ul class="mb-0 mt-2">
        <li>Група та список учасників видаляться назавжди.</li>
        <li>Нотатки і списки покупок <strong>НЕ видаляються</strong> —
            вони стають особистими (group = NULL через <code>SET_NULL</code>).</li>
      </ul>
    </div>
    <form method="post">
      {% csrf_token %}
      <button type="submit" class="btn btn-danger me-2">Так, видалити</button>
      <a href="{% url 'hello_app:group_detail' group.pk %}"
         class="btn btn-outline-secondary">Скасувати</a>
    </form>
  </div>
</div>
{% endblock %}
```

---

## Project file structure

```
crispy_notes_project/
│
├── requirements.txt               ← Django>=5.2, crispy-forms, crispy-bootstrap5
│
├── hello_project/
│   ├── settings.py                ← ★ LOGIN_URL, EMAIL_BACKEND, security block
│   └── urls.py                    ← include('django.contrib.auth.urls') + hello_app
│
├── hello_app/
│   ├── models.py                  ← Note.group FK, ShoppingList.group FK  ★ NEW
│   ├── forms.py                   ← GroupCreateForm, GroupAddMemberForm    ★ NEW
│   ├── services.py                ← create_group, add_user_to_group,       ★ NEW
│   │                                 remove_user_from_group, delete_group
│   ├── selectors.py               ← get_user_notes (Q filter), get_user_groups ★ NEW
│   ├── views.py                   ← group_list, group_create,              ★ NEW
│   │                                 group_detail, group_delete
│   ├── urls.py                    ← /groups/ URL patterns                  ★ NEW
│   ├── context_processors.py      ← sidebar_context (unchanged)
│   ├── admin.py                   ← registration of all models
│   ├── migrations/
│   │   ├── 0001_initial.py
│   │   ├── 0002_shoppinglist_shared_with_todolist_shared_with.py  ← M2M
│   │   └── 0003_note_group_shoppinglist_group.py                  ★ NEW
│   └── templates/hello_app/
│       ├── note_list.html         ← unchanged
│       ├── note_form.html         ← + group field in the form   ★ NEW
│       ├── group_list.html        ←                         ★ NEW
│       ├── group_form.html        ← {% crispy form %}        ★ NEW
│       ├── group_detail.html      ← members, action=add/remove/leave ★ NEW
│       └── group_confirm_delete.html ← SET_NULL explanation  ★ NEW
│
└── templates/                     ← global templates
    ├── base.html                      ← Bootstrap CDN (unchanged)
    ├── layouts/
    │   └── dashboard.html             ← + "Groups" in the sidebar, "Change password" dropdown ★
    ├── registration/
    │   ├── login.html                 ← + "Forgot password?" link  ★ UPDATED
    │   ├── register.html              ← registration (unchanged)
    │   ├── password_reset_form.html   ← email form              ★ NEW
    │   ├── password_reset_done.html   ← "check your email"      ★ NEW
    │   ├── password_reset_confirm.html← new password form       ★ NEW
    │   ├── password_reset_complete.html← success                ★ NEW
    │   ├── password_reset_email.html  ← email text              ★ NEW
    │   ├── password_change_form.html  ← password change         ★ NEW
    │   └── password_change_done.html  ← success                 ★ NEW
    └── components/
        ├── empty_state.html       ← unchanged
        ├── pagination.html        ← unchanged
        └── confirm_modal.html     ← unchanged
```

---

## Summary: what to learn and where

| Concept | Where to look in the code |
|-----------|-------------------|
| **AuthN vs AuthZ** | `views.py` — `@login_required` + `get_object_or_404(Note, pk=pk, user=request.user)` |
| **Session flow** | `settings.py` — `SESSION_COOKIE_*` + `django.contrib.sessions` |
| **Login/Logout** | `templates/registration/login.html` + `urls.py` auth.urls include |
| **Password Reset** | `templates/registration/password_reset_*.html` (5 files) |
| **Password Change** | `templates/registration/password_change_*.html` + `dashboard.html` dropdown |
| **IDOR protection** | `views.py` — all `get_object_or_404` calls with `user=request.user` |
| **Group model** | `models.py` — `Note.group FK(Group, SET_NULL)` |
| **Q-filter** | `selectors.py` — `get_user_notes` + `Q(user=user) | Q(group__in=user_groups)` |
| **Group CRUD** | `services.py` — `create_group`, `add_user_to_group`, `delete_group` |
| **Group views** | `views.py` — `group_list`, `group_create`, `group_detail`, `group_delete` |
| **3-action POST** | `views.py group_detail` — one view handles 'add'/'remove'/'leave' |
| **SET_NULL pattern** | `models.py` + `group_confirm_delete.html` — explanation of the behavior |
| **Security settings** | `settings.py` — the Web Security block (HTTPONLY, SAMESITE, X_FRAME_OPTIONS) |
| **EMAIL_BACKEND** | `settings.py` — `console.EmailBackend` for dev |

---

## Lesson documentation

| File | Topic |
|------|------|
| [`../AUTH_BASICS.md`](../AUTH_BASICS.md) | authenticate(), @login_required, middleware — in detail |
| [`../SESSIONS_FLOW.md`](../SESSIONS_FLOW.md) | cookies, sessions, login/logout, password reset |
| [`../PERMISSIONS.md`](../PERMISSIONS.md) | IDOR, object-level permissions, Q-filter for groups |
| [`../SECURITY_FOUNDATIONS.md`](../SECURITY_FOUNDATIONS.md) | CIA Triad, Trust Boundary, password hashing, CSRF |
| [`../SECURITY_MISCONCEPTIONS.md`](../SECURITY_MISCONCEPTIONS.md) | 6 common security mistakes |
| [`../DJANGO_ADMIN.md`](../DJANGO_ADMIN.md) | is_staff, is_superuser, ModelAdmin |
| [`../DJANGO_SECURITY_ARCHITECTURE.md`](../DJANGO_SECURITY_ARCHITECTURE.md) | middleware pipeline, ORM, CSRF/XSS |
| [`../OWASP_TOP_10.md`](../OWASP_TOP_10.md) | 10 vulnerabilities and Django protection |
| [`../ZERO_TRUST.md`](../ZERO_TRUST.md) | Zero Trust architecture with Django code |
| [`../SIEM.md`](../SIEM.md) | logging, rsyslog, ELK Stack |
| [`../INDEX.md`](../INDEX.md) | navigation across all files |
