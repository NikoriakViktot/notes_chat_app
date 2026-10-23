# OWASP Top 10 — The 10 Most Dangerous Vulnerabilities

> **OWASP** (Open Web Application Security Project) is a non-profit organization that regularly publishes a list
> of the 10 most common vulnerabilities in web applications. It's a "blacklist" of attacks you **must** know.
>
> **Analogy:** The OWASP Top 10 is like a TOP-10 of ways to rob a bank. Bank guards must know
> all of these methods in order to prevent them.

---

## A01 — Broken Access Control

**The most widespread vulnerability** in 2021-2023.

**What it is:** A user can perform actions or access data they shouldn't have access to.

**Examples:**
- Alice changes the URL `/notes/42/edit/` to `/notes/43/edit/` and edits Bob's note
- The `/admin/` URL is accessible without an `is_staff` check
- An API returns the list of all users instead of only the user's own profile

**Django protection:**
```python
# BAD:
note = get_object_or_404(Note, pk=pk)  # anyone can get any note

# GOOD:
note = get_object_or_404(Note, pk=pk, user=request.user)  # only your own
```

**In our project:**
- `@login_required` on all views
- `get_object_or_404(..., user=request.user)` in note_edit, note_delete, etc.
- Groups: `Q(user=user) | Q(group__in=user_groups)` — you see only your own and group items

---

## A02 — Cryptographic Failures

**What it is:** Storing or transmitting sensitive data without proper encryption.

**Examples:**
- A password stored in plain text: `password = "secret123"` in the DB
- HTTP instead of HTTPS → passwords are sent in plain text
- A weak hashing algorithm (MD5, SHA-1) for passwords

**Django protection:**
```python
# Django automatically hashes passwords with PBKDF2:
user.set_password("new_password")
# → pbkdf2_sha256$1000000$salt$hash  (stored in the DB)

# Never store:
user.raw_password = "secret"    # NEVER!
Note.objects.create(content=request.POST['secret'])  # without encryption — bad
```

**Production settings:**
```python
# settings.py (uncomment in production):
SESSION_COOKIE_SECURE = True   # cookie over HTTPS only
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True     # HTTP → automatic redirect to HTTPS
```

---

## A03 — Injection

**What it is:** An attacker inserts malicious code into a request, and it is executed on the server.

**Types:**
- **SQL Injection** — malicious SQL in a query
- **XSS** — malicious JavaScript in HTML
- **Command Injection** — execution of system commands

### SQL Injection

```python
# DANGEROUS — string concatenation:
user_input = "'; DROP TABLE notes; --"
query = f"SELECT * FROM notes WHERE title = '{user_input}'"
# ↑ This code DELETES the whole notes table!

# SAFE — the Django ORM parameterizes queries automatically:
notes = Note.objects.filter(title=user_input)
# → SQL: SELECT * FROM notes WHERE title = %s  (with an escaped parameter)
```

### XSS (Cross-Site Scripting)

```html
<!-- DANGEROUS — no escaping: -->
<div>{{ note.content|safe }}</div>
<!-- If content = "<script>document.cookie</script>" → it runs in the browser -->

<!-- SAFE — Django escapes HTML automatically: -->
<div>{{ note.content }}</div>
<!-- Outputs: &lt;script&gt;document.cookie&lt;/script&gt; (safe) -->
```

**Django protection against XSS:**
- The template engine's `{{ variable }}` escapes everything automatically
- Use `|safe` **only** when you are SURE the content is safe (not user input!)

---

## A04 — Insecure Design

**What it is:** Architectural decisions with built-in vulnerabilities.

**Examples:**
- A registration form with no protection against bot sign-ups (needs a CAPTCHA or rate limiting)
- Password reset sends the password in plain text in an email (instead of a token)
- No limit on the number of login attempts (brute force is possible)

**Django solution:**
```python
# Rate limiting (limiting the number of requests):
# pip install django-axes

# settings.py:
INSTALLED_APPS += ['axes']
AXES_FAILURE_LIMIT = 5    # 5 failed attempts → lockout
AXES_COOLOFF_TIME = 1     # lockout for 1 hour

# Or: django-ratelimit
from django_ratelimit.decorators import ratelimit

@ratelimit(key='ip', rate='5/m', block=True)
def login_view(request):
    ...
```

---

## A05 — Security Misconfiguration

**What it is:** Unsafe settings left at their defaults or set incorrectly.

**Examples:**
- `DEBUG = True` in production → leaks of SECRET_KEY, stack traces, SQL queries
- The admin panel at the standard `/admin/` URL (easy to find)
- Default DB passwords (admin/admin)

**Django settings:**
```python
# settings.py — mandatory in production:
DEBUG = False                          # ← NEVER True in production!
SECRET_KEY = os.environ['SECRET_KEY']  # ← keep it in .env, not in the code!
ALLOWED_HOSTS = ['mysite.com']         # ← specific domains, not '*'

X_FRAME_OPTIONS = "DENY"              # protection against clickjacking
SECURE_CONTENT_TYPE_NOSNIFF = True    # the browser doesn't "guess" the file type
SESSION_COOKIE_HTTPONLY = True        # JS can't read sessionid
```

---

## A06 — Vulnerable and Outdated Components

**What it is:** Using libraries with known vulnerabilities.

**Checking Django:**
```bash
# Check dependencies for vulnerabilities:
pip install pip-audit
pip-audit

# Or with safety:
pip install safety
safety check

# Result:
# Found vulnerability in Django 3.2.0: CVE-2021-XXXXX
# Upgrade to: Django 3.2.14
```

**Rule:**
> Update Django and all libraries regularly. Follow the security releases on djangoproject.com.

---

## A07 — Identification and Authentication Failures

**What it is:** Weak authentication — easy passwords, no MFA, an unprotected password reset.

**Examples:**
- The password "123456" or "password" is allowed
- No limit on login attempts → a brute-force attack
- A password reset token that never expires

**Django protection:**
```python
# settings.py — password validators:
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
     'OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
# ↑ Django already has all these validators — just don't remove them!
```

**The password reset token in Django:**
- The token is single-use (it's invalidated after the first use)
- It's valid for 72 hours by default (`PASSWORD_RESET_TIMEOUT = 259200`)

---

## A08 — Software and Data Integrity Failures

**What it is:** Trusting data or code without verifying its integrity.

**Examples:**
- Loading JavaScript libraries without a hash check (CDN tampering)
- Django `pickle` serialization in sessions (vulnerable to RCE)

**Django protection:**
```html
<!-- SRI (Subresource Integrity) — hash check when loading from a CDN: -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-..."
        crossorigin="anonymous"></script>
```

---

## A09 — Security Logging and Monitoring Failures

**What it is:** Missing logs or monitoring of security events.

**What you need to log:**
- Failed login attempts (brute-force detection)
- Attempts to access other users' objects (IDOR attempts)
- Permission changes (who granted permissions to whom)
- Data deletion (who deleted what)

**Django logging:**
```python
# settings.py:
LOGGING = {
    'version': 1,
    'handlers': {
        'file': {
            'class': 'logging.FileHandler',
            'filename': 'logs/security.log',
        },
    },
    'loggers': {
        'django.security': {
            'handlers': ['file'],
            'level': 'WARNING',
        },
    },
}

# views.py — logging suspicious actions:
import logging
logger = logging.getLogger('django.security')

def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    logger.warning(f"User {request.user.pk} deleted note {pk}")
    note.delete()
```

---

## A10 — Server-Side Request Forgery (SSRF)

**What it is:** An attacker forces the server to make requests to internal resources.

**Example:**
```python
# A dangerous "upload an avatar from a URL" function:
def upload_avatar(request):
    url = request.POST.get('avatar_url')
    response = requests.get(url)      # SSRF!
    # The attacker sends: url = "http://169.254.169.254/latest/meta-data/"
    # → the server makes a request to the AWS metadata API → AWS credentials leak!
```

**Protection:**
```python
from urllib.parse import urlparse

ALLOWED_HOSTS_FOR_FETCH = ['i.imgur.com', 'avatars.githubusercontent.com']

def is_safe_url(url):
    parsed = urlparse(url)
    return parsed.hostname in ALLOWED_HOSTS_FOR_FETCH

def upload_avatar(request):
    url = request.POST.get('avatar_url')
    if not is_safe_url(url):
        raise PermissionDenied
    response = requests.get(url)
```

---

## Summary: Django vs the OWASP Top 10

| # | Vulnerability | Django protection |
|---|-------------|---------------|
| A01 | Broken Access Control | `@login_required` + `get_object_or_404(..., user=request.user)` |
| A02 | Cryptographic Failures | `set_password()` (PBKDF2), HTTPS settings |
| A03 | Injection | ORM (SQL), `{{ var }}` auto-escaping (XSS) |
| A04 | Insecure Design | `django-axes` (rate limiting), proper architecture |
| A05 | Security Misconfiguration | `DEBUG=False`, security settings in settings.py |
| A06 | Vulnerable Components | `pip-audit`, regular updates |
| A07 | Auth Failures | `AUTH_PASSWORD_VALIDATORS`, `@login_required`, MFA |
| A08 | Integrity Failures | SRI for CDN resources |
| A09 | Logging Failures | `django.security` logger, structured logs |
| A10 | SSRF | A whitelist of allowed URLs for outgoing requests |
