# Середовище та запуск

> **Сумісність Python і Django:**
>
> | Python | Django | Примітка |
> |--------|--------|----------|
> | 3.10 – 3.13 | 5.1.x або 5.2.x | Стабільна пара |
> | 3.14+ | тільки 5.2+ | 5.1 не підтримує Python 3.14 |
> | 3.9 | 4.2.x (LTS) | Старий, але підтримується |
>
> Перевір: `python --version`

---

## Крок 1 — Virtual Environment

Virtual environment — ізольоване Python-середовище.
Пакети які ти встановлюєш сюди не впливають на інші проєкти і на системний Python.

```bash
# Створити venv у поточній папці
python -m venv venv
```

Після цього з'явиться папка `venv/`.

### Активація

```bash
# Linux / macOS
source venv/bin/activate

# Windows PowerShell
venv\Scripts\Activate.ps1

# Windows Command Prompt
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

# Встановити з requirements.txt (для іншого розробника):
pip install -r requirements.txt
```

Перевір встановлення:
```bash
python -m django --version
# → 5.2.2
```

---

## Крок 3 — Створити проєкт

```bash
django-admin startproject hello_project .
```

> **Крапка `.` наприкінці — обов'язкова!**
>
> З крапкою: `hello_project/` і `manage.py` у поточній папці ✓
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

Перевір що сервер запускається:
```bash
python manage.py runserver
```

---

## Крок 4 — Застосувати міграції

```bash
python manage.py migrate
```

Django включає вбудовані додатки (`django.contrib.auth`, `django.contrib.admin` тощо).
Кожен має таблиці в базі даних. `migrate` створює ці таблиці у `db.sqlite3`.

Вивід команди:
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK
  Applying auth.0001_initial... OK
  Applying admin.0001_initial... OK
  Applying sessions.0001_initial... OK
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

Перевір у браузері:
- `http://localhost:8000/` → стартова сторінка Django (ракета)
- `http://localhost:8000/admin/` → адмін-панель, введи логін з цього кроку

---

## Крок 6 — Створити додаток

Django-проєкт складається з одного або кількох **додатків** (apps).
Кожен додаток відповідає за певну частину функціональності.

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
├── tests.py        ← Тести
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

## Всі команди по порядку

```bash
# 1. Створити і активувати venv
python -m venv venv
source venv/bin/activate      # Linux/Mac
# або: venv\Scripts\activate  # Windows

# 2. Встановити Django
pip install -r requirements.txt
# або: pip install django

# 3. Створити проєкт (крапка важлива!)
django-admin startproject hello_project .

# 4. Застосувати початкові міграції
python manage.py migrate

# 5. Створити адміністратора
python manage.py createsuperuser

# 6. Перевірити адмін-панель
python manage.py runserver
# → http://localhost:8000/admin/

# 7. Створити додаток
python manage.py startapp hello_app
# (далі редагуємо файли вручну — наступні сторінки)
```
