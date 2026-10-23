# Password Security — Resetting and Changing a Password

> Django provides a **complete password management system "out of the box"** through `django.contrib.auth`.
> You don't need to write a single view for login, logout, password reset or change.

## Why you shouldn't write your own password views

Password management is a security-critical task. Common mistakes when writing your own views:

- Passing the password in the URL (a GET parameter) → the password ends up in server logs and browser history
- One-time tokens without expiration → an old token can be reused
- Storing the password in plain text instead of a hash → a database breach = all passwords compromised
- No rate limiting → brute force attacks

Django `contrib.auth` does it **right**: PBKDF2 + salt, one-time HMAC tokens (72 h), protection against user enumeration (it does not reveal whether an email exists in the database).

---

## What `include('django.contrib.auth.urls')` wires up

```python
# notes_project/urls.py (or hello_project/urls.py in crispy_notes_project):
path("accounts/", include("django.contrib.auth.urls")),
```

This automatically registers 8 URLs:

| URL | View | Name (for `{% url %}`) | Template (you must create it) |
|-----|------|------------------------|------------------------|
| `/accounts/login/` | `LoginView` | `login` | `registration/login.html` |
| `/accounts/logout/` | `LogoutView` | `logout` | (redirect, no template) |
| `/accounts/password_change/` | `PasswordChangeView` | `password_change` | `registration/password_change_form.html` |
| `/accounts/password_change/done/` | `PasswordChangeDoneView` | `password_change_done` | `registration/password_change_done.html` |
| `/accounts/password_reset/` | `PasswordResetView` | `password_reset` | `registration/password_reset_form.html` |
| `/accounts/password_reset/done/` | `PasswordResetDoneView` | `password_reset_done` | `registration/password_reset_done.html` |
| `/accounts/reset/<uidb64>/<token>/` | `PasswordResetConfirmView` | `password_reset_confirm` | `registration/password_reset_confirm.html` |
| `/accounts/reset/done/` | `PasswordResetCompleteView` | `password_reset_complete` | `registration/password_reset_complete.html` |

**Takeaway:** 8 URLs + 8 views are already written by Django — you only write the HTML templates!

---

## Password Reset Flow — 5 steps

```
Step 1: /accounts/password_reset/
─────────────────────────────────────────────────────────────────────────
Alice forgot her password → enters her email in the form
→ password_reset_form.html

Step 2: Django handles the POST
─────────────────────────────────────────────────────────────────────────
Django looks for a User with that email (says nothing if not found —
safe behavior: we don't reveal whether such an email exists)
Generates a unique token (PasswordResetTokenGenerator): an HMAC keyed with SECRET_KEY over
user.pk + password hash + last_login + email + timestamp
(after a password change or a login the old token becomes invalid)
Sends an email with the link:
  /accounts/reset/<uidb64>/<token>/

[DEV: EMAIL_BACKEND = console → the email is printed to the terminal / docker logs]
[PROD: EMAIL_BACKEND = smtp → a real email via SMTP]

Step 3: /accounts/password_reset/done/
─────────────────────────────────────────────────────────────────────────
Django shows: "Check your inbox" (regardless of whether the email was found)
→ password_reset_done.html

Step 4: /accounts/reset/<uidb64>/<token>/
─────────────────────────────────────────────────────────────────────────
Alice follows the link from the email
Django: uidb64 → user_pk, token → verifies the signature
Is it valid? (72 h, single-use — invalidated after use)
If OK → a form for the new password + password validators
→ password_reset_confirm.html

Step 5: Success → /accounts/reset/done/
─────────────────────────────────────────────────────────────────────────
Password saved (hashed with PBKDF2 and a salt) → all of this user's sessions are reset
→ password_reset_complete.html
```

---

## Password Reset templates (crispy_notes_project, 5 files)

### `templates/registration/password_reset_form.html` — the email form

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

### `templates/registration/password_reset_done.html` — "check your inbox"

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

In `notes_chat_app` the DEV hint is adapted for Docker:

```html
<div class="alert alert-info text-start small mt-3">
  <strong><i class="bi bi-terminal me-1"></i>DEV режим:</strong>
  Email не надсилається реально. Знайди його у логах Docker:
  <code class="d-block mt-1">docker compose logs -f web</code>
  Скопіюй URL що починається з
  <code>/accounts/reset/...</code>
</div>
```

### `templates/registration/password_reset_confirm.html` — the new password form

```html
{% extends 'base.html' %}
{% load crispy_forms_tags %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 420px;">
    <div class="card-body p-4">

      {% if validlink %}
        {# validlink = True → the token is valid (not expired, not used) #}
        <h5 class="fw-bold mb-3">Новий пароль</h5>
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          {# SetPasswordForm: new_password1, new_password2 #}
          {# Django automatically runs PASSWORD_VALIDATORS on these fields #}
          <button type="submit" class="btn btn-primary w-100 mt-2">
            Зберегти пароль
          </button>
        </form>
      {% else %}
        {# The token is invalid (expired or already used) #}
        <div class="text-center py-3">
          <i class="bi bi-exclamation-triangle display-4 text-danger mb-3"></i>
          <h5>Посилання недійсне</h5>
          <p class="text-muted small">
            Термін дії посилання вийшов (72 год) або воно вже було використано.
          </p>
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

### `templates/registration/password_reset_complete.html` — success

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

### `templates/registration/password_reset_email.html` — the email text

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
- `{{ token }}` — an HMAC-signed one-time token

### How to find the link in the logs (dev)

**crispy_notes_project (runserver):**
```bash
# After submitting the password_reset form — look at the terminal:
Content-Type: text/plain; charset="utf-8"
...
http://127.0.0.1:8000/accounts/reset/Mg/abc123token456/   ← copy this URL!
```

**notes_chat_app (Docker):**
```bash
# After clicking "Надіслати посилання":
docker compose logs web | grep -A 10 "Subject: Password reset"

# OR in real time:
docker compose logs -f web
# Look for lines like:
# Content-Type: text/plain; charset="utf-8"
# Subject: Password reset on localhost
# ...
# http://localhost/accounts/reset/Mg/abc123-token/   ← copy this URL!
```

---

## How PBKDF2 stores passwords

```python
# What is stored in the database (auth_user.password):
'pbkdf2_sha256$1000000$salt$hash'
#  ↑algorithm   ↑iterations  ↑salt ↑hash

# Plain text is never stored!
# Even Django doesn't know the original password — it only checks the hash.

# Verification:
# authenticate(request, username='alice', password='mysecret')
# → pbkdf2_sha256(1000000 iterations, 'mysecret' + stored_salt)
# → compares with stored_hash
# → returns a User or None

# Why 1 000 000 iterations (the default in Django 5.2)?
# If an attacker steals the database → brute force:
#   SHA-256 without stretching: 10 billion attempts/sec
#   PBKDF2 with 1000000 iter:  ~10 000 attempts/sec (1 000 000 times slower!)
```

---

## Password Validators — 4 built-in protections

```python
# settings.py — 4 built-in validators:
AUTH_PASSWORD_VALIDATORS = [
    # Is the password similar to the username / email / first_name?
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    # At least 8 characters (configurable: "OPTIONS": {"min_length": 10})
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    # Is it in the list of the 20 000 most common passwords? ("password", "123456", "qwerty"...)
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

## Password Change

Password change requires the user to be **already logged in** (unlike password reset).
`PasswordChangeView` checks `is_authenticated` itself — you don't need `@login_required`.

### `templates/registration/password_change_form.html`

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

### `templates/registration/password_change_done.html`

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

### Link in the navbar dropdown

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

> **Why is logout POST and not GET?**
> GET requests can be embedded in `<img src="/accounts/logout/">` on evil.com.
> Anyone who opens the attacker's page is automatically logged out.
> POST requires a CSRF token → it cannot be performed from another site.

---

## Email backend: dev vs production

```python
# settings.py

# DEV: email goes to the container's stdout/logs (not actually sent)
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# PROD: replace with SMTP:
# EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
# EMAIL_HOST = "smtp.gmail.com"
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = os.environ['EMAIL_HOST_USER']
# EMAIL_HOST_PASSWORD = os.environ['EMAIL_HOST_PASSWORD']
# DEFAULT_FROM_EMAIL = "noreply@mysite.com"
```

---

## Debugging: the password reset link doesn't arrive

### Check EMAIL_BACKEND

```python
# In the shell:
docker compose exec web python manage.py shell

>>> from django.conf import settings
>>> print(settings.EMAIL_BACKEND)
# dev: django.core.mail.backends.console.EmailBackend
# prod: django.core.mail.backends.smtp.EmailBackend
```

### Find the email in the Docker logs

```bash
# Right after clicking "Надіслати посилання":
docker compose logs web | grep -A 15 "Content-Type: text/plain"

# OR in real time (keep it open in a second terminal):
docker compose logs -f web

# Look for lines similar to:
# Subject: Password reset on localhost
# From: webmaster@localhost
# To: alice@test.com
# ...
# http://localhost/accounts/reset/Mg/abc123-token/  ← copy this URL!
```

### Check in the shell whether such a user exists

```python
from django.contrib.auth.models import User

# PasswordResetView doesn't tell you if the email was not found (safe behavior).
# We check manually:
User.objects.filter(email='alice@test.com').exists()  # → True or False

# If False → registered with a different email, or the email was left empty at registration
User.objects.get(username='alice').email  # → show a specific user's email
```

---

## In the book

- [Part VII. Auth and Security](../../07_auth_and_security/README.md) — `django.contrib.auth` architecture, `AbstractUser`, the `@login_required` decorator, `LoginRequiredMixin`, CSRF, XSS protection, PBKDF2 in detail

---

## Official documentation

- [Django: Password management](https://docs.djangoproject.com/en/5.2/topics/auth/passwords/) — PBKDF2, validators, `make_password`, `check_password`
- [Django: Password reset views](https://docs.djangoproject.com/en/5.2/topics/auth/default/#module-django.contrib.auth.views) — all 8 views, what they expect, how to customize them
- [Django: AUTH_PASSWORD_VALIDATORS](https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators) — the 4 built-in ones, how to write your own
- [Django: Email backends](https://docs.djangoproject.com/en/5.2/topics/email/#email-backends) — console, locmem, smtp, file
- [Django: Password reset tokens](https://docs.djangoproject.com/en/5.2/topics/auth/default/#django.contrib.auth.tokens.PasswordResetTokenGenerator) — how the token is generated and verified

---

## Next

Next chapter: [Object Permissions](object_permissions.md) — IDOR, `get_object_or_404`, Q-filter for shared objects.
