# Туторіал 01 — Мій перший Django-проєкт

> Цей туторіал проводить тебе від **порожньої папки** до повноцінного Django-сайту
> з view-функціями, URL-роутингом, адмін-панеллю та першою моделлю.
>
> **Результат:**
> ```
> http://localhost:8000/        →  Hello, Django!
> http://localhost:8000/about/  →  Це моя перша сторінка на Django!
> http://localhost:8000/admin/  →  Адмін-панель (superuser)
> ```

---

## Зміст

**Теорія** _(читати перед кодом)_
- [01 · ЯК DJANGO ОБРОБЛЯЄ ЗАПИТ — від браузера до відповіді](#01--як-django-обробляє-запит)
- [02 · СТРУКТУРА ПРОЄКТУ — що означає кожен файл](#02--структура-проєкту)
- [03 · MANAGE.PY — командний центр Django](#03--managepy)
- [04 · SETTINGS.PY — анатомія конфігурації](#04--settingspy)
- [05 · URL PATTERNS — як Django знаходить view](#05--url-patterns)

**Покрокова реалізація**
1. [Крок 1 — Virtual environment](#крок-1--virtual-environment)
2. [Крок 2 — Встановити Django](#крок-2--встановити-django)
3. [Крок 3 — Створити проєкт](#крок-3--створити-проєкт)
4. [Крок 4 — Застосувати міграції](#крок-4--застосувати-міграції)
5. [Крок 5 — Створити суперкористувача](#крок-5--створити-суперкористувача)
6. [Крок 6 — Створити додаток](#крок-6--створити-додаток)
7. [Крок 7 — Написати view-функції](#крок-7--написати-view-функції)
8. [Крок 8 — URL-маршрути](#крок-8--url-маршрути)
9. [Крок 9 — Перевірити в браузері](#крок-9--перевірити-в-браузері)
10. [Бонус — Перша модель і Django shell](#бонус--перша-модель)

---

## 01 · Як Django обробляє запит

> **Найголовніше питання:** що відбувається коли ти вводиш `http://localhost:8000/` у браузер?

### Повний цикл Request/Response

```
Браузер                    runserver (manage.py)              Django
   │                              │                              │
   │  GET /about/  ───────────────►                              │
   │                              │  ProtocolTypeRouter          │
   │                              │  (WSGI або ASGI)             │
   │                              │         │                    │
   │                              │  SecurityMiddleware          │
   │                              │  SessionMiddleware           │
   │                              │  CommonMiddleware            │
   │                              │  CsrfViewMiddleware          │
   │                              │  AuthenticationMiddleware    │
   │                              │  MessageMiddleware           │
   │                              │         │                    │
   │                              │  URLconf → hello_project/urls.py
   │                              │         │                    │
   │                              │  include → hello_app/urls.py │
   │                              │         │                    │
   │                              │  path('about/', about_view)  │
   │                              │         │                    │
   │                              │  about(request)              │
   │                              │         │                    │
   │                              │  HttpResponse("Це моя...")   │
   │                              │         │                    │
   │  ◄───────────── 200 OK  ─────│         │                    │
   │  (тіло: "Це моя перша...")   │                              │
```

### Три учасники

```
URLS.PY           → "Хто відповість?"     path('about/', views.about)
VIEWS.PY          → "Що відповісти?"      return HttpResponse("...")
ШАБЛОН/ВІДПОВІДЬ  → "Як виглядатиме?"     рядок або HTML
```

**Аналогія з рестораном:**
- `urls.py` = хостес: "Столик 5 — ваш офіціант Марко"
- `views.py` = кухар: отримує замовлення і готує страву
- `HttpResponse` = тарілка що повертається до гостя

---

## 02 · Структура проєкту

Після `django-admin startproject hello_project .` і `startapp hello_app` у тебе буде:

```
./
├── manage.py               ← CLI: запуск сервера, міграції, shell, тести
│
├── hello_project/          ← Конфігурація проєкту (один на весь проєкт)
│   ├── __init__.py         ← Порожній: робить папку Python-пакетом
│   ├── settings.py         ← Всі налаштування: БД, INSTALLED_APPS, TEMPLATES...
│   ├── urls.py             ← Головний URLconf: включає urls.py від додатків
│   ├── wsgi.py             ← Точка входу для WSGI-серверів (Gunicorn, uWSGI)
│   └── asgi.py             ← Точка входу для ASGI-серверів (Uvicorn, Daphne)
│
├── hello_app/              ← Додаток (один з можливих кількох)
│   ├── __init__.py
│   ├── admin.py            ← Реєстрація моделей у Django Admin
│   ├── apps.py             ← Конфігурація AppConfig
│   ├── models.py           ← Моделі: Python-клас → таблиця БД
│   ├── views.py            ← View-функції: request → response
│   ├── urls.py             ← URLs додатку (треба створити вручну)
│   ├── forms.py            ← ModelForm і Form класи (треба створити)
│   ├── migrations/         ← Автоматично генеровані файли міграцій
│   │   └── __init__.py
│   └── templates/          ← HTML-шаблони (треба створити)
│       └── hello_app/
│           └── index.html
│
└── db.sqlite3              ← БД файл (з'являється після migrate)
```

### Чому `hello_project/` і `hello_app/` — різні речі?

```
hello_project/   = КОНФІГУРАЦІЯ
  Один на весь сайт.
  settings.py, urls.py, wsgi.py.
  Не містить бізнес-логіки.
  Ти рідко правиш його після початкового налаштування.

hello_app/       = ФУНКЦІОНАЛЬНІСТЬ
  Може бути кілька (notes_app, users_app, chat_app).
  models.py, views.py, forms.py, templates/.
  Тут живе весь код застосунку.
  Кожен app = ізольована одиниця функціональності.
```

**Правило:** один `app` = одна відповідальність.
`notes_app` → нотатки. `users_app` → профілі. Не мішати в один великий app.

---

## 03 · manage.py

`manage.py` — це CLI-оркестратор Django. Всі взаємодії з проєктом через нього.

### Найважливіші команди

```bash
# ── Сервер розробки ─────────────────────────────────────────────────────────
python manage.py runserver                 # http://localhost:8000/
python manage.py runserver 0.0.0.0:8080   # інший порт і хост (для мережі)

# ── Міграції ────────────────────────────────────────────────────────────────
python manage.py makemigrations            # Генерує план міграції з models.py
python manage.py makemigrations hello_app  # Тільки для одного додатку
python manage.py migrate                   # Застосовує всі міграції до БД
python manage.py migrate hello_app 0002    # Відкотити до конкретної міграції
python manage.py showmigrations            # Показати стан всіх міграцій

# ── Адміністрування ──────────────────────────────────────────────────────────
python manage.py createsuperuser           # Створити суперюзера інтерактивно
python manage.py changepassword alice      # Змінити пароль юзера

# ── Генерація коду ───────────────────────────────────────────────────────────
python manage.py startapp blog_app         # Новий додаток
python manage.py startproject config .     # Нова конфігурація проєкту

# ── Інтерактивна оболонка ────────────────────────────────────────────────────
python manage.py shell                     # Python shell з Django контекстом
python manage.py shell -i bpython          # Або ipython/bpython якщо встановлені

# ── SQL ──────────────────────────────────────────────────────────────────────
python manage.py sqlmigrate hello_app 0001 # Показати SQL що виконає міграція
python manage.py dbshell                   # psql / sqlite3 shell

# ── Перевірка ────────────────────────────────────────────────────────────────
python manage.py check                     # Перевірити конфігурацію без запуску
python manage.py check --deploy            # Перевірка production-налаштувань

# ── Тести ────────────────────────────────────────────────────────────────────
python manage.py test                      # Всі тести
python manage.py test hello_app            # Тести конкретного app
python manage.py test hello_app.tests.test_models -v 2

# ── Статичні файли ───────────────────────────────────────────────────────────
python manage.py collectstatic             # Зібрати статику в STATIC_ROOT

# ── Дані ────────────────────────────────────────────────────────────────────
python manage.py dumpdata hello_app.Note   # Експорт даних у JSON
python manage.py loaddata fixtures.json   # Імпорт даних
```

### Як manage.py знає про твій проєкт?

```python
# manage.py — перший рядок після shebang:
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'hello_project.settings')
# ↑ Вказує Django де шукати settings.py
# При запуску в Docker це часто переозначається через ENV змінну
```

---

## 04 · settings.py

`settings.py` — мозок Django. Читай кожне налаштування, не просто копіюй.

### Повна анатомія settings.py

```python
# hello_project/settings.py

# ── Безпека ──────────────────────────────────────────────────────────────────
SECRET_KEY = 'django-insecure-...'   # Секрет для CSRF, сесій, підписів
# В production: читати з os.environ або .env файлу!
# os.environ.get('SECRET_KEY') — ніколи не зберігати в git

DEBUG = True
# True:  детальні сторінки помилок з traceback → ТІЛЬКИ у розробці
# False: Production → загальна помилка без traceback → налаштуй LOGGING

ALLOWED_HOSTS = []
# Список доменів що можуть звертатись до сайту
# DEBUG=True → ALLOWED_HOSTS не перевіряється (localhost завжди дозволений)
# Production: ['example.com', 'www.example.com']
# ngrok/Docker: додавати їх домен сюди або через env


# ── Встановлені додатки ──────────────────────────────────────────────────────
INSTALLED_APPS = [
    # Django вбудовані — ПОРЯДОК МАЄ ЗНАЧЕННЯ для деяких операцій:
    'django.contrib.admin',         # /admin/ — адмін-панель
    'django.contrib.auth',          # User модель, login/logout
    'django.contrib.contenttypes',  # ContentType framework (generic relations)
    'django.contrib.sessions',      # Сесії: django_session таблиця
    'django.contrib.messages',      # Flash-повідомлення
    'django.contrib.staticfiles',   # Статичні файли: /static/

    # Третьосторонні (встановлені через pip):
    'django_bootstrap5',
    'crispy_forms',
    'crispy_bootstrap5',

    # Твої додатки — завжди НАПРИКІНЦІ:
    'hello_app',
]
# Якщо додаток є тут → Django шукає в ньому models, views, templates, static


# ── Middleware — ланцюг обробки запиту ───────────────────────────────────────
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    # ↑ HTTPS redirect, HSTS, XSS protection заголовки

    'django.contrib.sessions.middleware.SessionMiddleware',
    # ↑ Завантажує сесію з БД → request.session

    'django.middleware.common.CommonMiddleware',
    # ↑ Додає trailing slash, APPEND_SLASH

    'django.middleware.csrf.CsrfViewMiddleware',
    # ↑ Перевіряє CSRF токен у POST запитах → 403 якщо відсутній

    'django.contrib.auth.middleware.AuthenticationMiddleware',
    # ↑ Читає session → встановлює request.user
    # ВАЖЛИВО: після SessionMiddleware!

    'django.contrib.messages.middleware.MessageMiddleware',
    # ↑ Flash-повідомлення: messages.success(request, ...)

    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # ↑ X-Frame-Options: DENY → захист від clickjacking
]
# Порядок критичний! Middleware викликаються по черзі (request↓, response↑)


# ── URL конфігурація ─────────────────────────────────────────────────────────
ROOT_URLCONF = 'hello_project.urls'
# Відносно DJANGO_SETTINGS_MODULE


# ── Шаблони ──────────────────────────────────────────────────────────────────
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],  # Глобальні шаблони (не в app/)
    'APP_DIRS': True,                  # Шукати templates/ в кожному app
    # APP_DIRS: True → django шукає hello_app/templates/hello_app/*.html
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            # ↑ request доступний у шаблоні як {{ request }}
            'django.contrib.auth.context_processors.auth',
            # ↑ {{ user }} і {{ perms }} доступні у всіх шаблонах
            'django.contrib.messages.context_processors.messages',
            # ↑ {{ messages }} доступний у всіх шаблонах
        ],
    },
}]


# ── База даних ───────────────────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
# SQLite: один файл, ідеально для розробки, не для production
# PostgreSQL (production): ENGINE = 'django.db.backends.postgresql'


# ── Статичні файли ───────────────────────────────────────────────────────────
STATIC_URL = '/static/'
# URL prefix для статичних файлів: CSS, JS, зображення
# У шаблоні: {% load static %} + {% static 'css/style.css' %}


# ── Мова і часовий пояс ──────────────────────────────────────────────────────
LANGUAGE_CODE = 'uk'            # Мова адмін-панелі і вбудованих повідомлень
TIME_ZONE = 'Europe/Kyiv'       # Часовий пояс для DateTimeField
USE_I18N = True                 # Internationalization
USE_TZ = True                   # Зберігати datetime у UTC у БД
# USE_TZ=True: datetime у БД завжди в UTC → конвертація при відображенні
# USE_TZ=False: datetime зберігається "як є" → небезпечно при зміні TZ


# ── Auto primary key ─────────────────────────────────────────────────────────
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# BigAutoField → id: bigint (64-bit)
# AutoField     → id: int (32-bit, може переповнитись при мільярдах записів)
```

---

## 05 · URL Patterns

> `urls.py` — карта сайту. Кожен URL веде до конкретної view-функції.

### Анатомія path()

```python
from django.urls import path, include, re_path
from . import views

urlpatterns = [
    # path(route, view, kwargs=None, name=None)
    path('about/', views.about, name='about'),
    #      ↑          ↑               ↑
    #   рядок URL   callable        унікальне ім'я маршруту
    #   (без / на початку  (функція або CBV.as_view())
    #   якщо включений через include)
]
```

### Path Converters — захоплення значень з URL

```python
urlpatterns = [
    # <int:pk> — захопити ціле число
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    # /notes/42/ → view отримує pk=42

    # <str:username> — захопити рядок (не включає '/')
    path('users/<str:username>/', views.user_profile, name='user_profile'),
    # /users/alice/ → view отримує username='alice'

    # <slug:slug> — тільки букви, цифри, тире
    path('articles/<slug:slug>/', views.article, name='article'),
    # /articles/my-first-post/

    # <uuid:pk> — UUID формат
    path('orders/<uuid:pk>/', views.order_detail, name='order_detail'),

    # <path:file_path> — включає '/'
    path('files/<path:file_path>/', views.serve_file, name='serve_file'),
    # /files/images/2026/photo.jpg → file_path='images/2026/photo.jpg'
]
```

### Дворівнева URLconf — include()

```python
# hello_project/urls.py (головний)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    # include() підключає URLconf іншого додатку
    path('', include('hello_app.urls', namespace='hello_app')),
    # '' → всі URL без префікса йдуть в hello_app.urls
    # namespace='hello_app' → для {% url 'hello_app:index' %}

    # Або з префіксом:
    path('notes/', include('hello_app.urls', namespace='hello_app')),
    # Тоді /notes/ + '' (в hello_app.urls) = /notes/
]
```

```python
# hello_app/urls.py (модульний)
from django.urls import path
from . import views

app_name = 'hello_app'   # ← Обов'язково коли є namespace в include()!
# Без app_name: ImproperlyConfigured: Specifying a namespace in include() without providing an app_name

urlpatterns = [
    path('', views.index, name='index'),        # ← '' тут
    path('about/', views.about, name='about'),
]
```

### reverse() — програмна генерація URL

```python
# У view:
from django.urls import reverse
from django.shortcuts import redirect

def some_view(request):
    # Замість хардкоду '/notes/':
    url = reverse('hello_app:note_list')
    return redirect(url)

# Або напряму:
return redirect('hello_app:note_list')

# У шаблоні:
# {% url 'hello_app:note_detail' pk=note.pk %}
# → /notes/42/
```

**Навіщо `reverse()` замість хардкоду `/notes/`?**
Якщо змінити URL у `urls.py` — `reverse()` автоматично генерує новий URL.
З хардкодом `/notes/` → потрібно шукати і замінювати по всьому коду.

---

## Крок 1 — Virtual environment

Virtual environment — ізольоване Python-середовище. Пакети які ти встановлюєш сюди не впливають на інші проєкти і на системний Python.

```bash
# Створити venv у поточній папці
python -m venv venv

# Активувати — Linux / macOS
source venv/bin/activate

# Активувати — Windows PowerShell
venv\Scripts\Activate.ps1

# Активувати — Windows Command Prompt
venv\Scripts\activate.bat
```

Після активації в рядку терміналу з'явиться `(venv)`:
```
(venv) ~/projects/hello_django $
```

> **Активуй кожного разу** при відкритті нового терміналу в проєкті.
> Забув активувати? `pip install django` встановить у системний Python → конфлікти версій.

```bash
# Деактивувати (повернутись до системного Python):
deactivate

# Перевірити що використовується правильний Python:
which python    # macOS/Linux → повинно бути .../venv/bin/python
where python    # Windows
```

---

## Крок 2 — Встановити Django

```bash
# Оновити pip (рекомендовано)
python -m pip install --upgrade pip

# Встановити Django (остання стабільна)
pip install django

# Або конкретну версію:
pip install django==5.2.2
```

```bash
# Зберегти залежності у requirements.txt
pip freeze > requirements.txt
# Вміст: Django==5.2.2 (та інші залежності)

# Встановити з requirements.txt (для іншого розробника):
pip install -r requirements.txt
```

Перевір встановлення:
```bash
python -m django --version
# → 5.2.2
```

### Сумісність Python і Django

| Python | Django | Примітка |
|--------|--------|----------|
| 3.10 – 3.13 | 5.1.x або 5.2.x | Стабільна пара |
| 3.14+ | тільки 5.2+ | 5.1 не підтримує Python 3.14 |
| 3.9 | 4.2.x (LTS) | Старий, але підтримується |

Перевір: `python --version`

---

## Крок 3 — Створити проєкт

```bash
django-admin startproject hello_project .
```

> **Крапка `.` наприкінці — обов'язкова!**
>
> З крапкою:           `hello_project/` і `manage.py` у поточній папці ✓
> Без крапки: Django створить `hello_project/hello_project/` → зайва вкладеність ✗

Результат:
```
./
├── hello_project/
│   ├── __init__.py
│   ├── settings.py   ← конфігурація
│   ├── urls.py       ← головний маршрутизатор
│   ├── asgi.py       ← для uvicorn/daphne
│   └── wsgi.py       ← для gunicorn
└── manage.py         ← CLI оркестратор
```

---

## Крок 4 — Застосувати міграції

```bash
python manage.py migrate
```

Django включає вбудовані додатки (`django.contrib.auth`, `django.contrib.admin` тощо).
Кожен має таблиці в базі даних. `migrate` створює ці таблиці у `db.sqlite3`.

### Що саме Django створює

```bash
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK        # ← Django ContentType framework
  Applying auth.0001_initial... OK                # ← auth_user, auth_group, auth_permission
  Applying admin.0001_initial... OK               # ← django_admin_log
  Applying sessions.0001_initial... OK            # ← django_session
```

### Таблиці які Django створює автоматично

| Таблиця | Що зберігає |
|---------|-------------|
| `auth_user` | Юзери: username, password (хеш PBKDF2+SHA256), email, is_staff, is_superuser |
| `auth_group` | Групи/ролі: назва |
| `auth_permission` | Дозволи: назва + модель (`add_note`, `change_note`, `delete_note`, `view_note`) |
| `auth_user_groups` | M:N: юзер ↔ група |
| `auth_user_user_permissions` | M:N: юзер ↔ дозвіл |
| `django_session` | Сесії (cookie `sessionid` → запис у БД) |
| `django_admin_log` | Журнал дій в адмін-панелі (хто, що, коли змінив) |
| `django_migrations` | Які міграції вже застосовані (щоб не повторювати) |
| `django_content_type` | Реєстр всіх моделей (для generic FK) |

> **Без `migrate` адмін-панель падає:**
> `OperationalError: no such table: auth_user`

---

## Крок 5 — Створити суперкористувача

```bash
python manage.py createsuperuser
```

Django запитає:
```
Username (leave blank to use 'niko'): admin
Email address: admin@example.com
Password:
Password (again):
Superuser created successfully.
```

### Типи користувачів у Django

```
Superuser  → is_superuser=True, is_staff=True
             Всі права автоматично.
             Обходить перевірку дозволів.
             Доступ до /admin/ і всіх об'єктів.

Staff user → is_staff=True, is_superuser=False
             Вхід в /admin/, але тільки з призначеними дозволами.
             Не бачить моделі без явних прав.

Regular    → is_staff=False, is_superuser=False
             Звичайний юзер. Немає доступу до /admin/.
             Може використовувати frontend застосунку.
```

### Дозволи Django (автоматичні)

Django автоматично генерує 4 дозволи для кожної моделі:

```
hello_app.add_note      ← може створювати нотатки
hello_app.change_note   ← може редагувати
hello_app.delete_note   ← може видаляти
hello_app.view_note     ← може переглядати

# У шаблоні:
{% if perms.hello_app.add_note %}
    <a href="{% url 'hello_app:note_create' %}">+ Нова</a>
{% endif %}

# У view:
from django.contrib.auth.decorators import permission_required
@permission_required('hello_app.add_note')
def note_create(request): ...

# Перевірка в Python:
request.user.has_perm('hello_app.add_note')
```

---

## Крок 6 — Створити додаток

```bash
python manage.py startapp hello_app
```

Ця команда створює:
```
hello_app/
├── __init__.py
├── admin.py        ← Реєстрація моделей для Django Admin
├── apps.py         ← HelloAppConfig — конфігурація додатку
├── models.py       ← Моделі (порожній)
├── tests.py        ← Тести (краще перетворити у пакет tests/)
├── views.py        ← View-функції (порожній)
└── migrations/
    └── __init__.py
```

Зареєструй додаток у `hello_project/settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'hello_app',    # ← ДОДАЙ ЦЮ СТРОКУ
]
```

> **Чому потрібно реєструвати?**
> Django знає про додаток тільки якщо він є в `INSTALLED_APPS`.
> Без цього:
> - Django не шукає templates в `hello_app/templates/`
> - `python manage.py makemigrations` ігнорує `hello_app/models.py`
> - Django Admin не знає про моделі з `hello_app/`
> - management commands з `hello_app/management/` не доступні

---

## Крок 7 — Написати view-функції

Відкрий `hello_app/views.py`:

```python
from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    """Головна сторінка."""
    return HttpResponse("Hello, Django!")


def about(request):
    """Сторінка про нас."""
    return HttpResponse("Це моя перша сторінка на Django!")
```

### Анатомія view-функції

```python
def index(request):
    #       ↑
    #  HttpRequest object — містить:
    #    request.method   → 'GET', 'POST', 'PUT', 'DELETE'
    #    request.GET      → QueryDict: параметри ?q=search&page=2
    #    request.POST     → QueryDict: тіло POST форми
    #    request.user     → залогінений User або AnonymousUser
    #    request.session  → dict-like: сесія юзера
    #    request.META     → HTTP заголовки: REMOTE_ADDR, HTTP_HOST...
    #    request.FILES    → завантажені файли
    #    request.COOKIES  → cookies браузера

    return HttpResponse("Hello!")
    #         ↑
    #  HttpResponse — відповідь браузеру:
    #    status_code=200 (за замовчуванням)
    #    content_type='text/html; charset=utf-8'
    #    тіло: 'Hello!'
```

### Типи відповідей

```python
from django.http import (
    HttpResponse,            # 200 OK з будь-яким вмістом
    HttpResponseRedirect,    # 302 Redirect
    Http404,                 # кидається як виняток → 404 сторінка
    JsonResponse,            # 200 OK з JSON тілом
)
from django.shortcuts import render, redirect, get_object_or_404

# Найчастіші у views.py:
return render(request, 'hello_app/index.html', {'key': value})
# → рендерить HTML шаблон з контекстом → 200

return redirect('hello_app:note_list')
# → 302 Redirect на URL з reverse()

return redirect('hello_app:note_detail', pk=42)
# → 302 Redirect з аргументом

raise Http404("Не знайдено")
# → Django повертає 404 сторінку

note = get_object_or_404(Note, pk=pk)
# → Note.objects.get(pk=pk) але замість DoesNotExist → Http404
```

---

## Крок 8 — URL-маршрути

Створи новий файл `hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = "hello_app"    # ← Простір імен (namespace)

urlpatterns = [
    path('', views.index, name='index'),        # → /
    path('about/', views.about, name='about'),  # → /about/
]
```

**Навіщо `app_name`?** Без нього посилання `{% url 'hello_app:index' %}` не працює.
Django кидає: `ImproperlyConfigured: Specifying a namespace in include() without providing an app_name`

Підключи до головного `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
    #     ↑                              ↑
    #   порожній префікс →           простір імен для {% url %}
    #   URLs з hello_app починаються
    #   одразу від кореня /
]
```

### Як Django знаходить view для запиту GET /about/

```
GET /about/
    ↓
hello_project/urls.py:
  path('', include('hello_app.urls', ...))
  → prefix '' → PASS

hello_app/urls.py:
  path('about/', views.about, name='about')
  → 'about/' == 'about/' → MATCH!

views.about(request) викликається
  → HttpResponse("Це моя перша сторінка...")
```

---

## Крок 9 — Перевірити в браузері

```bash
python manage.py runserver
```

Очікуваний вивід:
```
Watching for file changes with StatReloader
Performing system checks...

System check identified no issues (0 silenced).
June 13, 2026 - 10:00:00
Django version 5.2.2, using settings 'hello_project.settings'
Starting development server at http://127.0.0.1:8000/
Quit the server with CONTROL-C.
```

| URL | Результат | HTTP код |
|-----|-----------|----------|
| `http://localhost:8000/` | `Hello, Django!` | 200 |
| `http://localhost:8000/about/` | `Це моя перша сторінка на Django!` | 200 |
| `http://localhost:8000/admin/` | Адмін-панель (сторінка логіну) | 200 |
| `http://localhost:8000/admin/` (після логіну) | Dashboard з моделями | 200 |
| `http://localhost:8000/nonexistent/` | 404 Not Found | 404 |

### Адмін-панель Django

Django Admin — автоматично згенерований веб-інтерфейс для управління даними.
Вбудований у Django: `django.contrib.admin` у `INSTALLED_APPS`.

**Що бачиш після логіну:**
```
Django administration                         Logged in as: admin
  AUTHENTICATION AND AUTHORIZATION
    Groups    → додати / редагувати групи
    Users     → всі юзери, зміна паролів, права
```

---

## Бонус — Перша модель

### 1. Опиши модель у `hello_app/models.py`

```python
from django.db import models


class Note(models.Model):
    title      = models.CharField(max_length=200, verbose_name='Заголовок')
    content    = models.TextField(blank=True, verbose_name='Текст')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Створено')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Оновлено')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name        = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        ordering            = ['-created_at']   # Нові першими
```

### Типи полів і що вони означають

```python
# CharField — короткий рядок, обов'язковий max_length
title = models.CharField(max_length=200)
# SQL: title VARCHAR(200) NOT NULL

# TextField — довгий рядок, без обмеження довжини
content = models.TextField(blank=True)
# blank=True: не обов'язкове у Django формах
# SQL: content TEXT NOT NULL DEFAULT ''

# DateTimeField — дата і час
created_at = models.DateTimeField(auto_now_add=True)
# auto_now_add=True: встановлюється при CREATE, ніколи не змінюється
# SQL: created_at TIMESTAMP NOT NULL DEFAULT NOW()

updated_at = models.DateTimeField(auto_now=True)
# auto_now=True: оновлюється при кожному SAVE

# BooleanField
is_pinned = models.BooleanField(default=False)
# SQL: is_pinned BOOLEAN NOT NULL DEFAULT FALSE

# IntegerField з choices
PRIORITY_CHOICES = [(1, 'Низький'), (2, 'Середній'), (3, 'Високий')]
priority = models.SmallIntegerField(choices=PRIORITY_CHOICES, default=1)
# SQL: priority SMALLINT NOT NULL DEFAULT 1

# ForeignKey — зв'язок N→1
user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
# SQL: user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE
```

### 2. Зареєструй в адмін-панелі (`hello_app/admin.py`)

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display   = ('title', 'created_at')     # Колонки у списку
    search_fields  = ('title', 'content')        # Пошук по полях
    list_filter    = ('created_at',)             # Фільтри праворуч
    ordering       = ('-created_at',)            # Сортування
    readonly_fields = ('created_at', 'updated_at') # Не редагувати
```

**Результат:** `http://localhost:8000/admin/hello_app/note/` — повноцінний CRUD для нотаток.

### 3. Зроби і застосуй міграцію

```bash
python manage.py makemigrations
```

Вивід:
```
Migrations for 'hello_app':
  hello_app/migrations/0001_initial.py
    - Create model Note
```

```bash
python manage.py migrate
```

Вивід:
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, hello_app, sessions
Running migrations:
  Applying hello_app.0001_initial... OK
```

### Правило двох кроків

```bash
# Після БУДЬ-ЯКОЇ зміни models.py → завжди два кроки:
python manage.py makemigrations   # Зафіксувати план змін
python manage.py migrate          # Застосувати до БД

# makemigrations БЕЗ migrate:
# → Python-клас є, таблиці в БД немає → OperationalError при першому запиті
```

### Що відбувається між models.py і БД

```
models.py (Python клас)
    ↓ python manage.py makemigrations
migrations/0001_initial.py  (план змін у вигляді Python операцій)
    ↓ python manage.py migrate
     ↓ sqlmigrate показує реальний SQL:
CREATE TABLE "hello_app_note" (
    "id"         bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "title"      varchar(200) NOT NULL,
    "content"    text NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL
);
    ↓
http://localhost:8000/admin/hello_app/note/   ← тепер доступна модель
```

### 4. Django shell — ORM запити

```bash
python manage.py shell
```

```python
from hello_app.models import Note

# CREATE — INSERT INTO
Note.objects.create(title="Перша нотатка", content="Привіт Django!")
Note.objects.create(title="Django ORM", content="Дуже потужний!")

# READ — SELECT
Note.objects.all()                          # → QuerySet [<Note: Перша нотатка>, ...]
Note.objects.count()                        # → 2
Note.objects.filter(title__icontains='django')  # → QuerySet (case-insensitive)
Note.objects.get(id=1)                      # → <Note: Перша нотатка> або DoesNotExist
Note.objects.first()                        # → перший об'єкт
Note.objects.order_by('-created_at')        # → сортування: нові першими

# UPDATE — UPDATE SET
note = Note.objects.get(id=1)
note.title = "Змінена нотатка"
note.save()                                 # → UPDATE hello_app_note SET title=... WHERE id=1

# DELETE — DELETE FROM
note.delete()                               # → DELETE FROM hello_app_note WHERE id=1
Note.objects.filter(id__gt=5).delete()     # → Видалити всі з id > 5

# QuerySet ліниві:
qs = Note.objects.all()   # ← SQL ЩЕ НЕ ВИКОНУЄТЬСЯ
print(qs)                  # ← Тільки тут SQL виконується!
# SELECT * FROM hello_app_note

# Корисні lookups:
Note.objects.filter(title__icontains='перша')   # icontains = case-insensitive
Note.objects.filter(title__startswith='Django')
Note.objects.filter(created_at__year=2026)
Note.objects.filter(id__in=[1, 2, 3])
Note.objects.exclude(title='секрет')            # exclude = NOT
```

---

## Часті помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `OperationalError: no such table: auth_user` | Міграції не запускались | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | venv не активований | Активуй: `source venv/bin/activate` |
| `Page not found (404)` на `/` | Маршрут не зареєстрований | Перевір `urls.py` в обох файлах |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` є, але `app_name` відсутній | Додай `app_name = "hello_app"` у `hello_app/urls.py` |
| Django не бачить `hello_app` | Не в `INSTALLED_APPS` | Додай `'hello_app'` у `settings.py` |
| `django-admin: command not found` | Django не встановлений або venv не активований | Активуй venv, потім `pip install django` |
| `ModuleNotFoundError: No module named 'hello_project'` | Запускаєш не з кореня проєкту | Перейди у папку де є `manage.py` |
| `DisallowedHost` | ALLOWED_HOSTS не містить хост | Додай хост до `ALLOWED_HOSTS` у settings.py |
| `CSRF verification failed` | `{% csrf_token %}` відсутній у формі | Додай `{% csrf_token %}` всередині `<form>` |

---

## Практичне завдання

1. Пройди кроки 1–9 самостійно, отримай `Hello, Django!` у браузері.
2. Додай третій маршрут `/contact/` з view-функцією `contact()`, яка повертає рядок з твоїм ім'ям та email.
3. Додай маршрут `/greet/<str:name>/` який повертає "Привіт, {name}!".
4. Створи модель `Note`, зроби міграцію, відкрий адмін-панель і додай 3 нотатки вручну.
5. У Django shell: знайди нотатку з `id=2`, зміни її `title`, збережи. Перевір в адмін-панелі.

---

## Чеклист самоперевірки

- [ ] `http://localhost:8000/` → `Hello, Django!`
- [ ] `http://localhost:8000/about/` → текст
- [ ] `http://localhost:8000/admin/` → адмін-панель (логін superuser)
- [ ] Я розумію різницю між `startproject` і `startapp`
- [ ] Я знаю навіщо `makemigrations` і `migrate` — два окремі кроки
- [ ] Модель `Note` з'являється в адмін-панелі
- [ ] Я можу виконати CRUD через Django shell (`create`, `filter`, `get`, `save`, `delete`)
- [ ] Я розумію як Django знаходить view за URL (URLconf ланцюг)
- [ ] Я знаю різницю між superuser / staff / regular user

---

## Підсумок

| Концепція | Де у коді |
|-----------|-----------|
| URL маршрут | `hello_app/urls.py` → `path('about/', views.about)` |
| View-функція | `hello_app/views.py` → `def about(request): return HttpResponse(...)` |
| Підключення app URLs | `hello_project/urls.py` → `include('hello_app.urls')` |
| Namespace | `app_name = 'hello_app'` + `namespace='hello_app'` |
| Зворотний URL | `reverse('hello_app:about')` або `{% url 'hello_app:about' %}` |
| Path converter | `path('notes/<int:pk>/', ...)` |
| Модель → БД | `makemigrations` + `migrate` |
| ORM CRUD | `create`, `filter`, `get`, `.save()`, `.delete()` |
| Адмін реєстрація | `@admin.register(Note)` у `admin.py` |

---

## Далі

Наступний крок: [02 — Bootstrap Notes](02_first_model.md) — Bootstrap 5, ModelForm, повноцінний CRUD з PRG-паттерном.

Модулі документації:
- [Django Core](../02_django_core/README.md)
- [Database and ORM](../03_database_and_orm/README.md)
