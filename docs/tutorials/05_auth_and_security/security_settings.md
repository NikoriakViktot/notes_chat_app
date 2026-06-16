# Security Settings — Що і Навіщо

> Django має безліч security налаштувань. Більшість "вимкнені" за замовчуванням
> щоб не ламати localhost розробку. У production їх треба увімкнути.

---

## Таблиця: кожна настройка і що захищає

| Настройка | Значення | Від чого захищає |
|-----------|----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | JS не читає sessionid | XSS → Session Hijacking |
| `SESSION_COOKIE_SAMESITE = "Lax"` | Cookie тільки з того ж сайту | CSRF через крос-сайтові форми |
| `CSRF_COOKIE_HTTPONLY = False` | JS читає csrftoken | (False = для fetch/axios у WebSocket чаті) |
| `X_FRAME_OPTIONS = "DENY"` | Заборона `<iframe>` вбудовування | Clickjacking атаки |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | Не "вгадувати" MIME тип | XSS через підроблені файли |
| `DEBUG = False` | Ховає stack traces | Витік SECRET_KEY та коду |
| `ALLOWED_HOSTS = ['mysite.com']` | Тільки цей домен | HTTP Host header attacks |
| `CSRF_TRUSTED_ORIGINS = [...]` | Дозволені HTTPS origins | CSRF через ngrok/proxy |

---

## Що витікає при `DEBUG = True` в production

```
Помилка сервера при DEBUG=True показує:
  ✗ Повний stack trace (шляхи до файлів, назви функцій, рядки коду)
  ✗ Значення ВСІХ локальних змінних у момент помилки
  ✗ SECRET_KEY витікає! (хакер може підробляти session cookies і CSRF токени)
  ✗ Всі SQL-запити зберігаються в пам'яті → memory leak під навантаженням
  ✗ INSTALLED_APPS, DATABASES, MIDDLEWARE — вся конфіга видима у браузері

DEBUG = False + ALLOWED_HOSTS = ['mysite.com'] обов'язково в production.
```

---

## ALLOWED_HOSTS і SECRET_KEY

```python
# settings.py

# ALLOWED_HOSTS — тільки ці хости можуть надсилати запити:
ALLOWED_HOSTS = ['localhost', '127.0.0.1']   # dev
# PROD:
ALLOWED_HOSTS = ['mysite.com', 'www.mysite.com']

# Без ALLOWED_HOSTS при DEBUG=False → Django відхиляє всі запити!
# SuspiciousOperation: Invalid HTTP_HOST header

# SECRET_KEY — основа безпеки сесій, CSRF і підписів:
SECRET_KEY = os.environ.get('SECRET_KEY', 'fallback-dev-key')
# НІКОЛИ не комітити реальний SECRET_KEY у репозиторій!
# Якщо SECRET_KEY витік → хакер може підробляти sessionid cookies
# → входити за будь-якого юзера без пароля
```

---

## Production HTTPS settings (розкоментувати на сервері)

```python
# settings.py — закоментовано у dev (щоб localhost працював по HTTP):

# SESSION_COOKIE_SECURE = True
# ↑ Cookie надсилається ТІЛЬКИ по HTTPS
# Без цього: Man-in-the-middle може перехопити sessionid по HTTP

# CSRF_COOKIE_SECURE = True
# ↑ Те саме для CSRF cookie

# SECURE_SSL_REDIRECT = True
# ↑ Будь-який HTTP запит → 301 Moved Permanently → HTTPS

# SECURE_HSTS_SECONDS = 31536000  # 1 рік
# ↑ Браузер запам'ятовує: ТІЛЬКИ HTTPS на 1 рік
# (HTTP Strict Transport Security заголовок)
# УВАГА: після увімкнення — важко відкотити! Браузер кешує і ігнорує HTTP.
```

---

## Повний security блок у settings.py

**Для crispy_notes_project:**

```python
# hello_project/settings.py:

# ── Auth redirects ─────────────────────────────────────────────────────────────
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True     # JS не читає sessionid (XSS захист)
CSRF_COOKIE_HTTPONLY = False       # JS читає csrftoken (для fetch/axios)
SESSION_COOKIE_SAMESITE = "Lax"   # CSRF захист для cookies
X_FRAME_OPTIONS = "DENY"          # Clickjacking захист
SECURE_CONTENT_TYPE_NOSNIFF = True # MIME sniffing захист

# Production HTTPS (розкоментуй на сервері):
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

**Для notes_chat_app (додаткові налаштування):**

```python
# notes_project/settings.py:

# ── ngrok CSRF ────────────────────────────────────────────────────────────────
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# ── Web Security ──────────────────────────────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True      # JS не читає sessionid (XSS захист)
CSRF_COOKIE_HTTPONLY = False        # JS читає csrftoken (для fetch у WebSocket чаті)
SESSION_COOKIE_SAMESITE = "Lax"    # CSRF захист для cookies
X_FRAME_OPTIONS = "DENY"           # Clickjacking захист
SECURE_CONTENT_TYPE_NOSNIFF = True  # MIME sniffing захист
```

---

## ngrok і `CSRF_TRUSTED_ORIGINS`

У `notes_chat_app` є ngrok для публічного доступу. Django перевіряє `Origin` заголовок при POST через HTTPS:

```python
# settings.py (вже реалізовано):
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []
# = ['https://fawn-natural-mayfly.ngrok-free.app']

# .env:
# NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

# Без CSRF_TRUSTED_ORIGINS:
# POST /accounts/login/ через ngrok → 403 Forbidden: CSRF verification failed
# Origin: https://fawn-natural-mayfly.ngrok-free.app — не в trusted origins!
```

---

## Атаки, від яких захищають ці налаштування — конкретні сценарії

### XSS → Session Hijacking (SESSION_COOKIE_HTTPONLY)

```
Атака:
1. Зловмисник знаходить XSS уразливість (наприклад, вставляє <script> у коментар)
2. JavaScript у браузері Alice виконує: document.cookie
3. Повертає: "sessionid=abc123; csrftoken=xyz..."
4. Відправляє cookie на evil.com → зловмисник входить під Alice

Захист SESSION_COOKIE_HTTPONLY = True:
document.cookie → "csrftoken=xyz..."  (sessionid ВІДСУТНІЙ — HttpOnly не читається JS)
Зловмисник не може вкрасти sessionid навіть при XSS.
```

### CSRF Attack (SESSION_COOKIE_SAMESITE + {% csrf_token %})

```
Атака (без захисту):
1. Alice залогінена в mysite.com → браузер зберігає sessionid cookie
2. Alice відкриває evil.com — там прихована форма:
   <form action="https://mysite.com/notes/delete/1/" method="post">
   <input type="hidden" name="confirm" value="yes">
   JavaScript: form.submit()
3. Браузер надсилає запит до mysite.com → автоматично додає cookie Alice!
4. Сервер бачить валідний sessionid → виконує дію як Alice

Захист SESSION_COOKIE_SAMESITE = "Lax":
  Cookie не надсилається з крос-сайтових POST запитів
  evil.com → form.submit() → cookie НЕ додається → 403

Захист {% csrf_token %}:
  POST без csrfmiddlewaretoken → 403 Forbidden
  evil.com не знає поточний токен Alice → атака неможлива
```

### Clickjacking (X_FRAME_OPTIONS)

```
Атака:
1. evil.com вбудовує mysite.com через <iframe>
2. Накладає прозорий div поверх кнопки "Видалити акаунт"
3. Alice думає що клікає на evil.com, насправді клікає по прихованому mysite.com
4. Дія виконується на mysite.com під сесією Alice

Захист X_FRAME_OPTIONS = "DENY":
Браузер відмовляється вбудовувати mysite.com у <iframe>
Content-Security-Policy: frame-ancestors 'none'  (еквівалент для HTTPS)
```

---

## Перевірка security headers у браузері

```
F12 → Network → будь-який запит → Response Headers:

X-Frame-Options: DENY                ← X_FRAME_OPTIONS = "DENY"
X-Content-Type-Options: nosniff      ← SECURE_CONTENT_TYPE_NOSNIFF = True

(При HTTPS, з _SECURE налаштуваннями:)
Strict-Transport-Security: max-age=31536000  ← SECURE_HSTS_SECONDS = 31536000
```

### Перевірити security deployment checklist Django

```bash
docker compose exec web python manage.py check --deploy
```

Показує попередження про security налаштування. В dev очікується частина попереджень (наприклад, HTTPS-специфічні). У production — мають бути зеленими.

Приклад виводу:
```
SystemCheckError: System check identified some issues:

WARNINGS:
?: (security.W004) You have not set a value for the SECURE_HSTS_SECONDS setting.
?: (security.W008) Your SECRET_KEY has less than 50 characters.
?: (security.W012) SESSION_COOKIE_SECURE is not set to True.
```

---

## У книзі

- [Частина VII. Auth і Security](../../07_auth_and_security/README.md) — OWASP Top 10, XSS, CSRF, IDOR, SQL Injection, Django захист на кожному рівні

---

## Офіційна документація

- [Django: Security in Django](https://docs.djangoproject.com/en/5.2/topics/security/) — огляд всіх механізмів
- [Django: Clickjacking protection](https://docs.djangoproject.com/en/5.2/ref/clickjacking/) — X_FRAME_OPTIONS
- [Django: CSRF protection](https://docs.djangoproject.com/en/5.2/ref/csrf/) — як працює `{% csrf_token %}`
- [Django: Security settings](https://docs.djangoproject.com/en/5.2/ref/settings/#security) — всі security-налаштування з description
- [Django: Deployment checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/) — `manage.py check --deploy`
- [MDN: HttpOnly](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#httponly) — Cookie HttpOnly attribute
- [MDN: SameSite](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#samesite) — SameSite Lax/Strict/None

---

## Далі

Наступна глава: [Notes Chat App Auth](notes_chat_app_auth.md) — специфіка notes_chat_app: Docker запуск, `DATABASE_URL`, реєстрація, URL конфігурація, перевірка у браузері.
