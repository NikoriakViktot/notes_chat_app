# Туторіал 01 — Мій перший Django-проєкт

**Мета:** з нуля підняти Django-сайт з view-функцією, URL-роутингом, адмін-панеллю та першою моделлю.

**Результат:**
```
http://localhost:8000/        →  Hello, Django!
http://localhost:8000/about/  →  Це моя перша сторінка на Django!
http://localhost:8000/admin/  →  Адмін-панель (superuser)
```

---

## Передумови

- Python 3.10–3.13 або 3.14+
- Вміти відкрити термінал і запускати команди

> **Сумісність:**
> | Python | Django |
> |--------|--------|
> | 3.10–3.13 | 5.1.x або 5.2.x |
> | 3.14+ | тільки 5.2+ |
>
> Перевір: `python --version`

---

## Крок 1 — Virtual environment

Virtual environment — ізольоване Python-середовище. Пакети які ти встановлюєш сюди не впливають на інші проєкти.

```bash
# Створити
python -m venv venv

# Активувати — Linux / macOS
source venv/bin/activate

# Активувати — Windows PowerShell
venv\Scripts\Activate.ps1
```

Після активації в рядку терміналу з'явиться `(venv)`. Активувати потрібно **кожного разу** при відкритті нового терміналу.

---

## Крок 2 — Встановити Django

```bash
python -m pip install --upgrade pip
pip install django
```

Перевір встановлення:
```bash
python -m django --version
# → 5.2.x
```

---

## Крок 3 — Створити проєкт

```bash
django-admin startproject hello_project .
```

> **Крапка `.` наприкінці — обов'язкова!**
> Вона означає "створити в поточній папці". Без крапки Django створить зайву вкладену директорію.

Результат:
```
./
├── hello_project/
│   ├── settings.py   ← конфігурація
│   ├── urls.py       ← головний маршрутизатор
│   └── wsgi.py
└── manage.py         ← CLI оркестратор
```

---

## Крок 4 — Застосувати міграції

```bash
python manage.py migrate
```

Django включає вбудовані додатки (`django.contrib.auth`, `django.contrib.admin` тощо). Кожен має таблиці в базі даних. `migrate` створює ці таблиці у файлі `db.sqlite3`.

> **БЕЗ цього кроку адмін-панель падає з помилкою:**
> `OperationalError: no such table: auth_user`

---

## Крок 5 — Створити суперкористувача

```bash
python manage.py createsuperuser
```

Django запитає username, email (необов'язковий), password. Цей логін/пароль — для входу в адмін-панель на `http://localhost:8000/admin/`.

---

## Крок 6 — Створити додаток

Django-проєкт складається з одного або кількох **додатків** (apps). Кожен відповідає за певну функціональність.

```bash
python manage.py startapp hello_app
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

> Django знає про додаток тільки якщо він є в `INSTALLED_APPS`. Без цього Django не шукає views, templates і команди в `hello_app/`.

---

## Крок 7 — Написати view-функції

Відкрий `hello_app/views.py`:

```python
from django.http import HttpResponse


def index(request):
    return HttpResponse("Hello, Django!")


def about(request):
    return HttpResponse("Це моя перша сторінка на Django!")
```

**Що таке view-функція?**
- Приймає `request` (HTTP-запит від браузера)
- Виконує логіку
- Повертає `HttpResponse` (відповідь браузеру)

---

## Крок 8 — URL-маршрути

Створи новий файл `hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = "hello_app"

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
]
```

`app_name` — простір імен (namespace) цього додатку. Дозволяє посилатись на маршрути як `hello_app:index`.

Підключи до головного `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
]
```

> `namespace=` вимагає `app_name` у `hello_app/urls.py` — інакше Django падає з `ImproperlyConfigured`.

---

## Крок 9 — Перевірити в браузері

```bash
python manage.py runserver
```

| URL | Результат |
|-----|-----------|
| http://localhost:8000/ | `Hello, Django!` |
| http://localhost:8000/about/ | `Це моя перша сторінка на Django!` |
| http://localhost:8000/admin/ | Адмін-панель |

---

## Адмін-панель Django

Django Admin — автоматично згенерований веб-інтерфейс для управління даними. Він вбудований: `django.contrib.admin` у `INSTALLED_APPS`.

### Таблиці які Django створює

| Таблиця | Що зберігає |
|---------|-------------|
| `auth_user` | Користувачі: username, password (хеш PBKDF2+SHA256), email, is_staff, is_superuser |
| `auth_group` | Групи/ролі: назва |
| `auth_permission` | Дозволи: назва + модель |
| `auth_user_groups` | Зв'язок: користувач ↔ група |
| `django_session` | Сесії (cookie → запис у БД) |
| `django_admin_log` | Журнал дій (хто що змінив) |
| `django_migrations` | Які міграції вже застосовані |

### Типи користувачів

```
Superuser  → is_superuser=True  → всі права, обходить перевірку
Staff user → is_staff=True      → вхід в /admin/, тільки призначені права
Regular    → обидва False        → немає доступу до /admin/
```

### Групи та дозволи

**Група = набір дозволів з назвою (роль).**

Формат дозволів Django: `<app>.<action>_<model>`

```
hello_app.add_note      ← створювати нотатки
hello_app.change_note   ← редагувати
hello_app.delete_note   ← видаляти
hello_app.view_note     ← переглядати
```

Django автоматично генерує 4 дозволи для кожної моделі.

---

## Бонус — Перша модель

### 1. Опиши модель у `hello_app/models.py`

```python
from django.db import models


class Note(models.Model):
    title = models.CharField(max_length=200, verbose_name='Заголовок')
    content = models.TextField(blank=True, verbose_name='Текст')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Створено')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        ordering = ['-created_at']
```

### 2. Зареєструй в адмін-панелі (`hello_app/admin.py`)

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_at')
    search_fields = ('title', 'content')
```

### 3. Зроби і застосуй міграцію

```bash
python manage.py makemigrations
python manage.py migrate
```

**Правило:** після будь-якої зміни `models.py` — завжди два кроки:
```bash
python manage.py makemigrations   # зафіксувати план
python manage.py migrate          # застосувати до БД
```

Django виконує за тебе:
```
models.py (Python клас)
    ↓ makemigrations
migrations/0001_initial.py  (план змін у вигляді SQL)
    ↓ migrate
db.sqlite3 → таблиця hello_app_note
    ↓ admin.site.register(Note)
http://127.0.0.1:8000/admin/hello_app/note/
```

### 4. Django shell — ORM запити

```bash
python manage.py shell
```

```python
from hello_app.models import Note

Note.objects.create(title="Перша нотатка", content="Привіт Django!")
Note.objects.all()       # → <QuerySet [<Note: Перша нотатка>]>
Note.objects.count()     # → 1
Note.objects.filter(title="Перша нотатка")
note = Note.objects.get(id=1)
note.title               # → "Перша нотатка"
```

---

## Часті помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `OperationalError: no such table: auth_user` | Міграції не запускались | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | venv не активований | Активуй venv |
| `Page not found (404)` | Маршрут не зареєстрований | Перевір `urls.py` в обох файлах |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` є, але `app_name` відсутній | Додай `app_name = "hello_app"` у `hello_app/urls.py` |
| Django не бачить `hello_app` | Не в `INSTALLED_APPS` | Додай `'hello_app'` у `settings.py` |

---

## Практичне завдання

1. Пройди кроки 1–9 самостійно, отримай `Hello, Django!` у браузері.
2. Додай третій маршрут `/contact/` з view-функцією `contact()`, яка повертає своє ім'я та email.
3. Створи модель `Note`, зроби міграцію, додай 3 нотатки через адмін-панель.
4. У Django shell виведи всі нотатки і знайди ту що має `id=2`.

---

## Чеклист самоперевірки

- [ ] `http://localhost:8000/` повертає `Hello, Django!`
- [ ] `http://localhost:8000/about/` повертає текст
- [ ] `http://localhost:8000/admin/` відкривається, я можу залогінитись
- [ ] Я розумію різницю між `startproject` і `startapp`
- [ ] Я розумію навіщо `makemigrations` і `migrate` — два окремі кроки
- [ ] Модель `Note` з'являється в адмін-панелі
- [ ] Я можу створити нотатку через `Note.objects.create(...)` у shell

---

## Далі

Наступний крок: [02 — First Model](02_first_model.md) — Bootstrap, форми і повноцінний CRUD для нотаток.

Модулі документації:
- [Django Core](../02_django_core/README.md)
- [Database and ORM](../03_database_and_orm/README.md)
