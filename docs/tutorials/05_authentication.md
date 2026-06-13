# Туторіал 05 — Django Автентифікація та Безпека

**Мета:** розібрати AuthN vs AuthZ, сесійний механізм, вбудовані auth URL, Password Reset flow, захист від IDOR та спільний доступ через Django Groups.

---

## AuthN vs AuthZ — два різних питання

| | Автентифікація (AuthN) | Авторизація (AuthZ) |
|--|------------------------|---------------------|
| **Питання** | Хто ти? | Що тобі можна? |
| **Django інструмент** | `authenticate()`, `login()` | `@login_required`, `get_object_or_404` |
| **Де перевіряється** | `AuthenticationMiddleware` | У кожному view окремо |

**Аналогія:** паспорт (AuthN) = підтверджує особу. Квиток (AuthZ) = підтверджує право на конкретне місце.

```python
from django.contrib.auth import authenticate, login, logout

# AuthN: перевірити credentials
user = authenticate(request, username='alice', password='secret')
# Django знаходить User з username='alice', перевіряє PBKDF2-хеш

if user is not None:
    login(request, user)   # ← INSERT у django_session + Set-Cookie: sessionid=...
    # Тепер request.user = alice у всіх наступних запитах

logout(request)   # ← DELETE з django_session + стирає cookie
```

---

## Як Django пам'ятає юзера: сесії

HTTP — stateless протокол. Кожен запит "перший". Сесія — це механізм зберігання стану.

```
Крок 1: POST /accounts/login/ {username: 'alice', password: 'secret'}
    Django authenticate() → User(id=42) ✓
    login() → INSERT INTO django_session (session_key='xK9mPq', user_id=42)
    Відповідь: 302 /notes/
    Header: Set-Cookie: sessionid=xK9mPq; HttpOnly; SameSite=Lax

Крок 2: Наступний запит GET /notes/
    Header: Cookie: sessionid=xK9mPq   ← браузер надсилає автоматично
    SessionMiddleware: SELECT * FROM django_session WHERE session_key='xK9mPq'
    AuthenticationMiddleware: request.user = User(id=42, username='alice')

Крок 3: POST /accounts/logout/
    logout() → DELETE FROM django_session WHERE session_key='xK9mPq'
    Відповідь: 302 /accounts/login/
    Header: Set-Cookie: sessionid=; expires=Thu, 01 Jan 1970...
```

---

## Вбудовані Django Auth URLs

```python
# urls.py
path("accounts/", include("django.contrib.auth.urls")),
```

Це реєструє **8 URL** автоматично — треба написати тільки шаблони:

| URL | Шаблон (треба створити) |
|-----|------------------------|
| `/accounts/login/` | `registration/login.html` |
| `/accounts/logout/` | (редирект, без шаблону) |
| `/accounts/password_change/` | `registration/password_change_form.html` |
| `/accounts/password_change/done/` | `registration/password_change_done.html` |
| `/accounts/password_reset/` | `registration/password_reset_form.html` |
| `/accounts/password_reset/done/` | `registration/password_reset_done.html` |
| `/accounts/reset/<uidb64>/<token>/` | `registration/password_reset_confirm.html` |
| `/accounts/reset/done/` | `registration/password_reset_complete.html` |

**8 URL + 7 views Django вже написав — ти пишеш тільки HTML шаблони.**

---

## Settings для Auth

```python
# settings.py
LOGIN_URL = '/accounts/login/'            # куди перенаправляти @login_required
LOGIN_REDIRECT_URL = '/notes/'            # куди ПІСЛЯ успішного входу
LOGOUT_REDIRECT_URL = '/accounts/login/'  # куди ПІСЛЯ виходу

# Email для Password Reset (dev — в консоль):
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Password Validators:
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Web Security:
SESSION_COOKIE_HTTPONLY = True      # JS не читає sessionid (XSS захист)
SESSION_COOKIE_SAMESITE = "Lax"    # CSRF захист для cookies
X_FRAME_OPTIONS = "DENY"           # Clickjacking захист
SECURE_CONTENT_TYPE_NOSNIFF = True  # MIME sniffing захист
```

---

## Password Reset Flow

```
1. /accounts/password_reset/
   Аліса вводить email → password_reset_form.html

2. Django обробляє POST:
   Генерує токен: sha1(user_pk + timestamp + SECRET_KEY)
   Надсилає email: /accounts/reset/<uidb64>/<token>/

3. /accounts/password_reset/done/
   Показує: "Перевірте пошту" → password_reset_done.html

4. /accounts/reset/<uidb64>/<token>/
   Аліса переходить за посиланням
   Django перевіряє токен (72 год, одноразовий)
   Форма для нового пароля → password_reset_confirm.html

5. /accounts/reset/done/
   Пароль збережено (PBKDF2) → password_reset_complete.html
```

DEV: email виводиться в консоль (`runserver`). Шукай рядок вигляду:
```
Subject: Password reset on localhost
...
http://127.0.0.1:8000/accounts/reset/MQ/abc123-xyz.../
```

---

## Захист від IDOR (Insecure Direct Object Reference)

IDOR — OWASP A01: найпоширеніша вразливість. Аліса бачить URL `/notes/42/edit/` і замінює `42` на `43` — редагує нотатку Боба.

```python
# ❌ ВРАЗЛИВІСТЬ: @login_required перевіряє тільки "ти залогінений?",
# але НЕ перевіряє чи нотатка належить тобі
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR!
    # Аліса залогінена → пропускає. Але note 43 — чужа!

# ✅ ПРАВИЛЬНО: додати user= до get_object_or_404
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # pk=43 + user=Alice → SELECT WHERE pk=43 AND user_id=Alice.id
    # Такого запису немає → 404
```

**Золоте правило:**
```
@login_required                    = "ти залогінений?"      (AuthN)
get_object_or_404(Note, pk=pk,
    user=request.user)             = "цей об'єкт — твій?"   (AuthZ)
```

> Повертаємо 404 (не 403), щоб не розкривати факт існування об'єкта.

Застосовується до **всіх** mutating views: `note_edit`, `note_delete`, `notebook_edit`, `notebook_delete`, `shopping_edit`.

---

## Спільний доступ через Django Groups

Django вже має вбудовану модель `Group`. Використовуємо її для шерингу даних між користувачами.

### Модель: FK на Group

```python
# models.py
from django.contrib.auth.models import Group

class Note(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    group = models.ForeignKey(
        Group, on_delete=models.SET_NULL,   # SET_NULL: нотатка стає особистою
        null=True, blank=True, related_name='notes'
    )
    # ...

# group = NULL  → особиста нотатка (тільки user бачить)
# group = id=5  → групова нотатка (всі члени групи 5 бачать)
```

### Q-filter: "мої або групові"

```python
# selectors.py
from django.db.models import Q

def get_user_notes(user, *, archived=False):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) |                  # власні нотатки
        Q(group__in=user_groups),       # нотатки груп де user є членом
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
```

SQL (спрощено):
```sql
SELECT * FROM note
WHERE (user_id = 42)           -- особисті Аліси
   OR (group_id IN (1, 3))     -- нотатки її груп
```

### Views для груп

```python
# views.py
@login_required
def group_create(request):
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        if name:
            group = Group.objects.create(name=name)
            group.user_set.add(request.user)   # автор стає членом групи
            messages.success(request, f'Групу "{group.name}" створено!')
            return redirect('hello_app:group_detail', pk=group.pk)
    return render(request, 'hello_app/group_form.html')


@login_required
def group_detail(request, pk):
    # Перевіряємо що user є членом групи (AuthZ)
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise Http404("Ти не є членом цієї групи")
    members = group.user_set.all()
    notes = Note.objects.filter(group=group)
    return render(request, 'hello_app/group_detail.html', {
        'group': group, 'members': members, 'notes': notes
    })
```

---

## Registration view

`django.contrib.auth.urls` не включає реєстрацію — треба написати самому:

```python
# views.py
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth import login

def register(request):
    if request.method == 'POST':
        form = UserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)   # auto-login після реєстрації
            messages.success(request, f'Вітаємо, {user.username}!')
            return redirect('hello_app:note_list')
    else:
        form = UserCreationForm()
    return render(request, 'registration/register.html', {'form': form})
```

```python
# urls.py
path('register/', views.register, name='register'),
```

---

## Шаблон Login

```html
{# registration/login.html #}
{% extends 'base.html' %}
{% load crispy_forms_tags %}

{% block content %}
<div class="row justify-content-center mt-5">
    <div class="col-12 col-md-5">
        <div class="card shadow-sm">
            <div class="card-header text-center">
                <h1 class="h4 mb-0"><i class="bi bi-lock me-2"></i>Вхід</h1>
            </div>
            <div class="card-body">
                <form method="post">
                    {% csrf_token %}
                    {{ form|crispy }}
                    <button type="submit" class="btn btn-primary w-100 mt-2">Увійти</button>
                </form>
                <hr>
                <div class="text-center">
                    <a href="{% url 'password_reset' %}">Забули пароль?</a>
                    &nbsp;·&nbsp;
                    <a href="{% url 'hello_app:register' %}">Реєстрація</a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

---

## Перевірка у браузері

| URL | Що перевіряти |
|-----|---------------|
| `/register/` | Реєстрація нового юзера → auto-login → redirect до `/notes/` |
| `/accounts/login/` | Вхід → session cookie у DevTools → Application → Cookies |
| `/accounts/logout/` | Вихід → cookie видалено → redirect до `/accounts/login/` |
| `/accounts/password_reset/` | Введи email → перевір консоль runserver → знайди посилання |
| `/notes/42/edit/` | Спробуй редагувати чужу нотатку → отримай 404 |

---

## Security налаштування production

| Настройка | Від чого захищає |
|-----------|-----------------|
| `SESSION_COOKIE_HTTPONLY = True` | XSS — JS не краде sessionid |
| `SESSION_COOKIE_SAMESITE = "Lax"` | CSRF — крос-сайтові запити |
| `X_FRAME_OPTIONS = "DENY"` | Clickjacking — iframe заборонено |
| `SECURE_CONTENT_TYPE_NOSNIFF = True` | MIME type sniffing XSS |
| `DEBUG = False` | Ховає SECRET_KEY і stack traces |
| `ALLOWED_HOSTS = ['mysite.com']` | HTTP Host header атаки |

Production HTTPS (розкоментуй на сервері):
```python
# SESSION_COOKIE_SECURE = True   # cookie тільки по HTTPS
# CSRF_COOKIE_SECURE = True
# SECURE_SSL_REDIRECT = True     # HTTP → HTTPS redirect
```

---

## Практичне завдання

1. Запусти проєкт, відкрий `/accounts/login/`. Встав неправильний пароль — переконайся що помилка відображається.
2. Залогінись і відкрий DevTools → Application → Cookies. Знайди `sessionid`.
3. Спробуй відкрити `/notes/` без авторизації — переконайся що перенаправляє на login.
4. Протестуй Password Reset: введи email, знайди посилання у консолі runserver, встанови новий пароль.
5. Залогінись як Аліса, відкрий `/notes/43/edit/` де `43` — нотатка Боба. Переконайся що отримуєш 404.
6. Створи групу, додай другого юзера, познач нотатку цією групою — переконайся що другий юзер її бачить.

---

## Чеклист самоперевірки

- [ ] `@login_required` + `LOGIN_URL` у `settings.py` налаштовані
- [ ] `include("django.contrib.auth.urls")` підключено
- [ ] Шаблони `registration/login.html` і `registration/register.html` існують
- [ ] `get_object_or_404(Note, pk=pk, user=request.user)` у mutating views
- [ ] Password Reset flow протестований (посилання у консолі runserver)
- [ ] Q-filter `Q(user=user) | Q(group__in=user_groups)` у selectors.py
- [ ] `SESSION_COOKIE_HTTPONLY = True` і `X_FRAME_OPTIONS = "DENY"` у settings.py

---

## Далі

Наступний крок: [06 — Testing](06_testing.md) — TestCase, AAA паттерн, service/view тести, Selenium E2E.

Модулі документації:
- [Auth and Security](../07_auth_and_security/README.md)
