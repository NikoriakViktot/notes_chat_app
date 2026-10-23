# Security Settings — What and Why

> Django has plenty of security settings. Most of them are "off" by default
> so as not to break localhost development. In production you need to turn them on.

---

## Table: each setting and what it protects against

| Setting | Value | What it protects against |
|-----------|----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | JS cannot read sessionid | XSS → Session Hijacking |
| `SESSION_COOKIE_SAMESITE = "Lax"` | Cookie only from the same site | CSRF via cross-site forms |
| `CSRF_COOKIE_HTTPONLY = False` | JS can read csrftoken | (False = for fetch/axios in the WebSocket chat) |
| `X_FRAME_OPTIONS = "DENY"` | Forbids `<iframe>` embedding | Clickjacking attacks |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | Don't "guess" the MIME type | XSS via forged files |
| `DEBUG = False` | Hides stack traces | Leaking SECRET_KEY and code |
| `ALLOWED_HOSTS = ['mysite.com']` | Only this domain | HTTP Host header attacks |
| `CSRF_TRUSTED_ORIGINS = [...]` | Allowed HTTPS origins | CSRF via ngrok/proxy |

---

## What leaks with `DEBUG = True` in production

```
A server error with DEBUG=True shows:
  ✗ The full stack trace (file paths, function names, lines of code)
  ✗ The values of ALL local variables at the moment of the error
  ✗ SECRET_KEY leaks! (an attacker can forge session cookies and CSRF tokens)
  ✗ All SQL queries are kept in memory → memory leak under load
  ✗ INSTALLED_APPS, DATABASES, MIDDLEWARE — the whole config is visible in the browser

DEBUG = False + ALLOWED_HOSTS = ['mysite.com'] are mandatory in production.
```

---

## ALLOWED_HOSTS and SECRET_KEY

```python
# settings.py

# ALLOWED_HOSTS — only these hosts can send requests:
ALLOWED_HOSTS = ['localhost', '127.0.0.1']   # dev
# PROD:
ALLOWED_HOSTS = ['mysite.com', 'www.mysite.com']

# Without ALLOWED_HOSTS with DEBUG=False → Django rejects all requests!
# SuspiciousOperation: Invalid HTTP_HOST header

# SECRET_KEY — the foundation of session, CSRF and signing security:
SECRET_KEY = os.environ.get('SECRET_KEY', 'fallback-dev-key')
# NEVER commit the real SECRET_KEY to the repository!
# If SECRET_KEY leaks → an attacker can forge sessionid cookies
# → log in as any user without a password
```

---

## Production HTTPS settings (uncomment on the server)

```python
# settings.py — commented out in dev (so that localhost works over HTTP):

# SESSION_COOKIE_SECURE = True
# ↑ The cookie is sent ONLY over HTTPS
# Without it: a man-in-the-middle can intercept sessionid over HTTP

# CSRF_COOKIE_SECURE = True
# ↑ Same for the CSRF cookie

# SECURE_SSL_REDIRECT = True
# ↑ Any HTTP request → 301 Moved Permanently → HTTPS

# SECURE_HSTS_SECONDS = 31536000  # 1 year
# ↑ The browser remembers: HTTPS ONLY for 1 year
# (HTTP Strict Transport Security header)
# WARNING: once enabled, it's hard to roll back! The browser caches it and ignores HTTP.
```

---

## Full security block in settings.py

**For crispy_notes_project:**

```python
# hello_project/settings.py:

# ── Auth redirects ─────────────────────────────────────────────────────────────
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True     # JS cannot read sessionid (XSS protection)
CSRF_COOKIE_HTTPONLY = False       # JS can read csrftoken (for fetch/axios)
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

**For notes_chat_app (additional settings):**

```python
# notes_project/settings.py:

# ── ngrok CSRF ────────────────────────────────────────────────────────────────
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True      # JS cannot read sessionid (XSS protection)
CSRF_COOKIE_HTTPONLY = False        # JS can read csrftoken (for fetch in the WebSocket chat)
SESSION_COOKIE_SAMESITE = "Lax"    # CSRF protection for cookies
X_FRAME_OPTIONS = "DENY"           # Clickjacking protection
SECURE_CONTENT_TYPE_NOSNIFF = True  # MIME sniffing protection
```

---

## ngrok and `CSRF_TRUSTED_ORIGINS`

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

## Attacks these settings protect against — concrete scenarios

### XSS → Session Hijacking (SESSION_COOKIE_HTTPONLY)

```
Attack:
1. The attacker finds an XSS vulnerability (for example, injects <script> into a comment)
2. JavaScript in Alice's browser runs: document.cookie
3. It returns: "sessionid=abc123; csrftoken=xyz..."
4. Sends the cookie to evil.com → the attacker logs in as Alice

Protection SESSION_COOKIE_HTTPONLY = True:
document.cookie → "csrftoken=xyz..."  (sessionid is MISSING — HttpOnly is not readable by JS)
The attacker cannot steal sessionid even with XSS.
```

### CSRF Attack (SESSION_COOKIE_SAMESITE + {% csrf_token %})

```
Attack (without protection):
1. Alice is logged in to mysite.com → the browser stores the sessionid cookie
2. Alice opens evil.com — it has a hidden form:
   <form action="https://mysite.com/notes/delete/1/" method="post">
   <input type="hidden" name="confirm" value="yes">
   JavaScript: form.submit()
3. The browser sends the request to mysite.com → automatically adds Alice's cookie!
4. The server sees a valid sessionid → performs the action as Alice

Protection SESSION_COOKIE_SAMESITE = "Lax":
  The cookie is not sent with cross-site POST requests
  evil.com → form.submit() → the cookie is NOT added → 403

Protection {% csrf_token %}:
  POST without csrfmiddlewaretoken → 403 Forbidden
  evil.com doesn't know Alice's current token → the attack is impossible
```

### Clickjacking (X_FRAME_OPTIONS)

```
Attack:
1. evil.com embeds mysite.com via an <iframe>
2. Places a transparent div over the "Delete account" button
3. Alice thinks she is clicking on evil.com, but she is actually clicking the hidden mysite.com
4. The action is performed on mysite.com under Alice's session

Protection X_FRAME_OPTIONS = "DENY":
The browser refuses to embed mysite.com in an <iframe>
Content-Security-Policy: frame-ancestors 'none'  (the modern CSP alternative, works over both HTTP and HTTPS)
```

---

## Checking security headers in the browser

```
F12 → Network → any request → Response Headers:

X-Frame-Options: DENY                ← X_FRAME_OPTIONS = "DENY"
X-Content-Type-Options: nosniff      ← SECURE_CONTENT_TYPE_NOSNIFF = True

(Over HTTPS, with the _SECURE settings:)
Strict-Transport-Security: max-age=31536000  ← SECURE_HSTS_SECONDS = 31536000
```

### Run Django's security deployment checklist

```bash
docker compose exec web python manage.py check --deploy
```

It shows warnings about security settings. In dev some warnings are expected (for example, HTTPS-specific ones). In production they should all be green.

Example output:
```
SystemCheckError: System check identified some issues:

WARNINGS:
?: (security.W004) You have not set a value for the SECURE_HSTS_SECONDS setting.
?: (security.W008) Your SECRET_KEY has less than 50 characters.
?: (security.W012) SESSION_COOKIE_SECURE is not set to True.
```

---

## In the book

- [Part VII. Auth and Security](../../07_auth_and_security/README.md) — OWASP Top 10, XSS, CSRF, IDOR, SQL Injection, Django protection at every level

---

## Official documentation

- [Django: Security in Django](https://docs.djangoproject.com/en/5.2/topics/security/) — an overview of all mechanisms
- [Django: Clickjacking protection](https://docs.djangoproject.com/en/5.2/ref/clickjacking/) — X_FRAME_OPTIONS
- [Django: CSRF protection](https://docs.djangoproject.com/en/5.2/ref/csrf/) — how `{% csrf_token %}` works
- [Django: Security settings](https://docs.djangoproject.com/en/5.2/ref/settings/#security) — all security settings with descriptions
- [Django: Deployment checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/) — `manage.py check --deploy`
- [MDN: HttpOnly](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#httponly) — Cookie HttpOnly attribute
- [MDN: SameSite](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#samesite) — SameSite Lax/Strict/None

---

## Next

Next chapter: [Notes Chat App Auth](notes_chat_app_auth.md) — notes_chat_app specifics: running with Docker, `DATABASE_URL`, registration, URL configuration, checking in the browser.
