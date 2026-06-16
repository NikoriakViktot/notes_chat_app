# Password Security — Скидання і Зміна Пароля

> Django надає **повну систему управління паролями "з коробки"** через `django.contrib.auth`.
> Не треба писати жодного view для login, logout, password reset або change.

## Навіщо не писати власні views для паролів

Управління паролями — критична з точки зору безпеки задача. Типові помилки при написанні власних view:

- Передача пароля у URL (GET параметр) → пароль у логах сервера і браузерній історії
- Одноразові токени без термінації → старий токен можна використати повторно
- Збереження пароля у plain text замість хешу → злом БД = злом всіх паролів
- Відсутність rate limiting → brute force атаки

Django `contrib.auth` реалізує **правильно**: PBKDF2 + salt, одноразові HMAC-токени (72 год), захист від user enumeration (не повідомляє чи є email у БД).

---

## Що `include('django.contrib.auth.urls')` підключає

```python
# notes_project/urls.py (або hello_project/urls.py у crispy_notes_project):
path("accounts/", include("django.contrib.auth.urls")),
```

Це автоматично реєструє 8 URL:

| URL | View | Назва (для `{% url %}`) | Шаблон (треба створити) |
|-----|------|------------------------|------------------------|
| `/accounts/login/` | `LoginView` | `login` | `registration/login.html` |
| `/accounts/logout/` | `LogoutView` | `logout` | (redirect, без шаблону) |
| `/accounts/password_change/` | `PasswordChangeView` | `password_change` | `registration/password_change_form.html` |
| `/accounts/password_change/done/` | `PasswordChangeDoneView` | `password_change_done` | `registration/password_change_done.html` |
| `/accounts/password_reset/` | `PasswordResetView` | `password_reset` | `registration/password_reset_form.html` |
| `/accounts/password_reset/done/` | `PasswordResetDoneView` | `password_reset_done` | `registration/password_reset_done.html` |
| `/accounts/reset/<uidb64>/<token>/` | `PasswordResetConfirmView` | `password_reset_confirm` | `registration/password_reset_confirm.html` |
| `/accounts/reset/done/` | `PasswordResetCompleteView` | `password_reset_complete` | `registration/password_reset_complete.html` |

**Висновок:** 8 URL + 7 views вже написані Django — ти пишеш тільки HTML шаблони!

---

## Password Reset Flow — 5 кроків

```
Крок 1: /accounts/password_reset/
─────────────────────────────────────────────────────────────────────────
Аліса забула пароль → вводить email у форму
→ password_reset_form.html

Крок 2: Django обробляє POST
─────────────────────────────────────────────────────────────────────────
Django шукає User з таким email (нічого не повідомляє якщо не знайдено —
безпечна поведінка: не розкриваємо чи є такий email)
Генерує унікальний токен: sha256(user_pk + timestamp + SECRET_KEY)
Надсилає email з посиланням:
  /accounts/reset/<uidb64>/<token>/

[DEV: EMAIL_BACKEND = console → email виводиться в термінал / docker logs]
[PROD: EMAIL_BACKEND = smtp → реальний email через SMTP]

Крок 3: /accounts/password_reset/done/
─────────────────────────────────────────────────────────────────────────
Django показує: "Перевірте пошту" (незалежно від того чи знайдено email)
→ password_reset_done.html

Крок 4: /accounts/reset/<uidb64>/<token>/
─────────────────────────────────────────────────────────────────────────
Аліса переходить за посиланням з email
Django: uidb64 → user_pk, token → перевіряє підпис
Чи дійсний? (72 год, одноразовий — після використання інвалідується)
Якщо OK → форма для нового пароля + password validators
→ password_reset_confirm.html

Крок 5: Успіх → /accounts/reset/done/
─────────────────────────────────────────────────────────────────────────
Пароль збережено (хешований PBKDF2 з salt) → всі сесії цього юзера скинуто
→ password_reset_complete.html
```

---

## Шаблони Password Reset (crispy_notes_project, 5 файлів)

### `templates/registration/password_reset_form.html` — форма email

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

### `templates/registration/password_reset_done.html` — "перевір пошту"

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

В `notes_chat_app` підказка DEV адаптована під Docker:

```html
<div class="alert alert-info text-start small mt-3">
  <strong><i class="bi bi-terminal me-1"></i>DEV режим:</strong>
  Email не надсилається реально. Знайди його у логах Docker:
  <code class="d-block mt-1">docker compose logs -f web</code>
  Скопіюй URL що починається з
  <code>/accounts/reset/...</code>
</div>
```

### `templates/registration/password_reset_confirm.html` — нова форма пароля

```html
{% extends 'base.html' %}
{% load crispy_forms_tags %}
{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center">
  <div class="card shadow-sm" style="width: 420px;">
    <div class="card-body p-4">

      {% if validlink %}
        {# validlink = True → токен дійсний (не прострочений, не використаний) #}
        <h5 class="fw-bold mb-3">Новий пароль</h5>
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          {# SetPasswordForm: new_password1, new_password2 #}
          {# Django автоматично запускає PASSWORD_VALIDATORS на цих полях #}
          <button type="submit" class="btn btn-primary w-100 mt-2">
            Зберегти пароль
          </button>
        </form>
      {% else %}
        {# Токен недійсний (прострочений або вже використаний) #}
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

### `templates/registration/password_reset_complete.html` — успіх

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

### `templates/registration/password_reset_email.html` — текст листа

```
{# Це ТЕКСТОВИЙ email — без HTML тегів! Django шукає цей шаблон автоматично. #}
Привіт!

Ви запросили скидання пароля для акаунту на Notes Chat App.

Перейдіть за посиланням щоб встановити новий пароль:

{{ protocol }}://{{ domain }}{% url 'password_reset_confirm' uidb64=uid token=token %}

Посилання дійсне 72 години. Після використання воно більше не працюватиме.

Якщо ви не запитували скидання пароля — просто проігноруйте цей лист.
Ваш пароль залишається незмінним.

— Notes Chat App
```

**Змінні у листі:**

- `{{ protocol }}` — `http` або `https`
- `{{ domain }}` — `localhost:8001` або `mysite.com`
- `{{ uid }}` — base64-encoded user PK
- `{{ token }}` — HMAC-підписаний одноразовий токен

### Як знайти посилання у логах (dev)

**crispy_notes_project (runserver):**
```bash
# Після надсилання форми password_reset — дивись в термінал:
Content-Type: text/plain; charset="utf-8"
...
http://127.0.0.1:8000/accounts/reset/Mg/abc123token456/   ← скопіюй цей URL!
```

**notes_chat_app (Docker):**
```bash
# Після натискання "Надіслати посилання":
docker compose logs web | grep -A 10 "Subject: Password reset"

# АБО в реальному часі:
docker compose logs -f web
# Шукай рядки:
# Content-Type: text/plain; charset="utf-8"
# Subject: Password reset on localhost
# ...
# http://localhost/accounts/reset/Mg/abc123-token/   ← цей URL копіюй!
```

---

## Як PBKDF2 зберігає паролі

```python
# Що зберігається у БД (auth_user.password):
'pbkdf2_sha256$600000$salt$hash'
#  ↑алгоритм   ↑ітерації  ↑сіль ↑хеш

# Ніколи не зберігається plain text!
# Навіть Django не знає оригінальний пароль — тільки перевіряє хеш.

# Перевірка:
# authenticate(request, username='alice', password='mysecret')
# → pbkdf2_sha256(600000 iterations, 'mysecret' + stored_salt)
# → порівнює з stored_hash
# → повертає User або None

# Чому 600000 ітерацій?
# Якщо хакер вкрав БД → brute force:
#   SHA-256 без stretching: 10 мільярдів спроб/сек
#   PBKDF2 з 600000 ітер:  ~10 000 спроб/сек (у 1 000 000 разів повільніше!)
```

---

## Password Validators — 4 вбудованих захисти

```python
# settings.py — 4 вбудованих валідатори:
AUTH_PASSWORD_VALIDATORS = [
    # Пароль схожий на username / email / first_name?
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    # Мінімум 8 символів (можна налаштувати: "OPTIONS": {"min_length": 10})
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    # Є у списку 20 000 найпоширеніших паролів? ("password", "123456", "qwerty"...)
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    # Складається тільки з цифр?
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Валідатори запускаються:
# 1. При реєстрації (UserCreationForm)
# 2. При зміні пароля (PasswordChangeForm, PasswordResetConfirmView)
# 3. При set_password() → validate_password()
#    НЕ при User.objects.create_user() якщо не викликати validate_password()!
```

---

## Крок 5 — Password Change

Password change вимагає що юзер **вже залогінений** (на відміну від password reset).
`PasswordChangeView` сам перевіряє `is_authenticated` — не треба `@login_required`.

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

### Посилання у navbar dropdown

```html
{# templates/layouts/dashboard.html — dropdown юзера у navbar: #}
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
      {# 'password_change' — вбудована URL з django.contrib.auth.urls #}
      <i class="bi bi-key me-2"></i>Змінити пароль
    </a>
  </li>
  <li><hr class="dropdown-divider border-secondary"></li>
  <li>
    <!-- Logout — POST запит (захист від CSRF logout attack) -->
    <form method="post" action="{% url 'logout' %}">
      {% csrf_token %}
      <button type="submit" class="dropdown-item text-danger">
        <i class="bi bi-box-arrow-right me-2"></i>Вийти
      </button>
    </form>
  </li>
</ul>
```

> **Чому logout — POST, а не GET?**
> GET запити можна вбудувати в `<img src="/accounts/logout/">` на evil.com.
> Будь-хто хто відкрив сторінку зловмисника — автоматично розлогінеться.
> POST вимагає CSRF токен → неможливо виконати з іншого сайту.

---

## Email backend: dev vs production

```python
# settings.py

# DEV: email у stdout/logs контейнера (не надсилається реально)
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# PROD: замінити на SMTP:
# EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
# EMAIL_HOST = "smtp.gmail.com"
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = os.environ['EMAIL_HOST_USER']
# EMAIL_HOST_PASSWORD = os.environ['EMAIL_HOST_PASSWORD']
# DEFAULT_FROM_EMAIL = "noreply@mysite.com"
```

---

## Debugging: не приходить посилання для скидання пароля

### Перевірити EMAIL_BACKEND

```python
# У shell:
docker compose exec web python manage.py shell

>>> from django.conf import settings
>>> print(settings.EMAIL_BACKEND)
# dev: django.core.mail.backends.console.EmailBackend
# prod: django.core.mail.backends.smtp.EmailBackend
```

### Знайти email у логах Docker

```bash
# Одразу після натискання "Надіслати посилання":
docker compose logs web | grep -A 15 "Content-Type: text/plain"

# АБО в реальному часі (тримай відкритим у другому терміналі):
docker compose logs -f web

# Шукай рядки схожі на:
# Subject: Password reset on localhost
# From: webmaster@localhost
# To: alice@test.com
# ...
# http://localhost/accounts/reset/Mg/abc123-token/  ← цей URL скопіюй!
```

### Перевірити в shell чи є такий user

```python
from django.contrib.auth.models import User

# PasswordResetView не повідомляє якщо email не знайдено (безпечна поведінка).
# Перевіряємо вручну:
User.objects.filter(email='alice@test.com').exists()  # → True або False

# Якщо False → зареєстрований з іншим email або email не заповнений при реєстрації
User.objects.get(username='alice').email  # → показати email конкретного user'а
```

---

## У книзі

- [Частина VII. Auth і Security](../../07_auth_and_security/README.md) — `django.contrib.auth` архітектура, `AbstractUser`, decorator `@login_required`, `LoginRequiredMixin`, CSRF, XSS захист, PBKDF2 детально

---

## Офіційна документація

- [Django: Password management](https://docs.djangoproject.com/en/5.2/topics/auth/passwords/) — PBKDF2, validators, `make_password`, `check_password`
- [Django: Password reset views](https://docs.djangoproject.com/en/5.2/topics/auth/default/#module-django.contrib.auth.views) — всі 8 views, що вони очікують, як кастомізувати
- [Django: AUTH_PASSWORD_VALIDATORS](https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators) — 4 вбудованих, як писати свій
- [Django: Email backends](https://docs.djangoproject.com/en/5.2/topics/email/#email-backends) — console, locmem, smtp, file
- [Django: Password reset tokens](https://docs.djangoproject.com/en/5.2/topics/auth/default/#django.contrib.auth.tokens.PasswordResetTokenGenerator) — як генерується і перевіряється токен

---

## Далі

Наступна глава: [Object Permissions](object_permissions.md) — IDOR, `get_object_or_404`, Q-filter для спільних об'єктів.
