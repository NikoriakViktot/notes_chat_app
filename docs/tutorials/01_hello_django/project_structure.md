# Структура проєкту

> Ця сторінка пояснює **чому** Django виглядає саме так.
> Перш ніж писати код — зрозумій архітектуру.

---

## 01 · Як Django обробляє запит

> **Найголовніше питання:** що відбувається коли ти вводиш `http://localhost:8000/about/` у браузер?

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
```

### Як manage.py знає про твій проєкт?

```python
# manage.py — перший рядок після shebang:
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'hello_project.settings')
# ↑ Вказує Django де шукати settings.py
# При запуску в Docker це часто переозначається через ENV змінну
```

---

## 04 · settings.py — анатомія конфігурації

`settings.py` — мозок Django. Читай кожне налаштування, не просто копіюй.

```python
# hello_project/settings.py

# ── Безпека ──────────────────────────────────────────────────────────────────
SECRET_KEY = 'django-insecure-...'   # Секрет для CSRF, сесій, підписів
# В production: читати з os.environ або .env файлу!
# os.environ.get('SECRET_KEY') — ніколи не зберігати в git

DEBUG = True
# True:  детальні сторінки помилок з traceback → ТІЛЬКИ у розробці
# False: Production → загальна помилка без traceback

ALLOWED_HOSTS = []
# Список доменів що можуть звертатись до сайту
# DEBUG=True → ALLOWED_HOSTS не перевіряється (localhost завжди дозволений)
# Production: ['example.com', 'www.example.com']


# ── Встановлені додатки ──────────────────────────────────────────────────────
INSTALLED_APPS = [
    'django.contrib.admin',         # /admin/ — адмін-панель
    'django.contrib.auth',          # User модель, login/logout
    'django.contrib.contenttypes',  # ContentType framework (generic relations)
    'django.contrib.sessions',      # Сесії: django_session таблиця
    'django.contrib.messages',      # Flash-повідомлення
    'django.contrib.staticfiles',   # Статичні файли: /static/

    # Треті сторонні (встановлені через pip):
    # 'crispy_forms',
    # 'crispy_bootstrap5',

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


# ── Мова і часовий пояс ──────────────────────────────────────────────────────
LANGUAGE_CODE = 'uk'            # Мова адмін-панелі і вбудованих повідомлень
TIME_ZONE = 'Europe/Kyiv'
USE_I18N = True
USE_TZ = True                   # Зберігати datetime у UTC у БД
# USE_TZ=True: datetime у БД завжди в UTC → конвертація при відображенні

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# BigAutoField → id: bigint (64-bit)
```

### SQLite vs PostgreSQL

| | SQLite (цей крок) | PostgreSQL (Кроки 5–9) |
|-|-------------------|------------------------|
| **Запуск** | Нічого не потрібно, файл | Окремий сервер |
| **Де файл** | `db.sqlite3` в папці проєкту | На сервері БД |
| **Підходить для** | Розробка, навчання, прототипи | Продакшн |
| **Одночасні записи** | Блокує файл | Повна конкурентність |
| **Налаштування** | `'ENGINE': 'django.db.backends.sqlite3'` | `'ENGINE': 'django.db.backends.postgresql'` |

> У notes_chat_app (Крок 5 і далі) SQLite-fallback відсутній — використовується тільки PostgreSQL через Docker.
