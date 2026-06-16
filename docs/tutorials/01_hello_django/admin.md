# Django Admin

> Django Admin — автоматично згенерований веб-інтерфейс для управління даними.
> Це вбудований Django-додаток `django.contrib.admin` зі своїми моделями, views і шаблонами.
> Доступний одразу після `migrate` + `createsuperuser`.

---

## Що бачиш після логіну

```
http://127.0.0.1:8000/admin/               ← головна сторінка (список розділів)
http://127.0.0.1:8000/admin/auth/user/     ← список користувачів
http://127.0.0.1:8000/admin/auth/user/add/ ← створити нового користувача
http://127.0.0.1:8000/admin/auth/group/    ← список груп (ролей)
```

```
Django administration                         Logged in as: admin
  AUTHENTICATION AND AUTHORIZATION
    Groups    → додати / редагувати групи
    Users     → всі юзери, зміна паролів, права
```

---

## Розділ Users

Список всіх користувачів системи. Кожен користувач має:

| Поле | Що означає |
|------|------------|
| **Username** | Логін для входу |
| **Email** | Email адреса (необов'язковий) |
| **Password** | Хеш (PBKDF2+SHA256) — ніколи не зберігається у відкритому вигляді |
| **First/Last name** | Ім'я та прізвище |
| **Active** | Чи може логінитись (False = заблокований) |
| **Staff status** | Чи має доступ до `/admin/` |
| **Superuser status** | Чи має ВСІ права (обходить перевірку дозволів) |
| **Groups** | Які групи (ролі) призначено |
| **User permissions** | Індивідуальні дозволи (зверх групових) |

---

## Розділ Groups (групи/ролі)

**Група = набір дозволів з назвою (роль).**

Замість призначення дозволів кожному користувачу окремо —
створюєш групу "Редактори" з потрібними правами і додаєш туди людей.

```
Група "Редактори новин"
    ✅ news.add_article    ← може створювати статті
    ✅ news.change_article ← може редагувати статті
    ❌ news.delete_article ← НЕ може видаляти
    ❌ news.view_user      ← НЕ бачить користувачів

Група "Модератори"
    ✅ news.delete_article ← може видаляти
    ✅ auth.view_user      ← бачить список користувачів
```

**Формат дозволів Django:** `<app>.<action>_<model>`

```
hello_app.add_note      ← додавати нотатки
hello_app.change_note   ← редагувати нотатки
hello_app.delete_note   ← видаляти нотатки
hello_app.view_note     ← переглядати нотатки
auth.add_user           ← додавати користувачів
```

Django **автоматично генерує** 4 дозволи для кожної моделі (`add`, `change`, `delete`, `view`).

---

## Журнал дій (django_admin_log)

Кожна дія в адмін-панелі логується автоматично:

```
http://127.0.0.1:8000/admin/ → Recent actions (права колонка)
```

Таблиця `django_admin_log` зберігає:
- хто зробив дію (user)
- що зробив (added / changed / deleted)
- який об'єкт (content_type + object_id)
- коли (action_time)

---

## Крок Б1 — Перша модель у models.py

Відкрий `hello_app/models.py` і напиши:

```python
from django.db import models


class Note(models.Model):
    """
    Модель = Python-клас що описує таблицю в базі даних.

    Django ORM автоматично:
        - створює таблицю 'hello_app_note' в db.sqlite3
        - генерує поле id (PRIMARY KEY AUTOINCREMENT)
        - дає API: Note.objects.all(), Note.objects.create(...) тощо
    """

    # CharField → VARCHAR в SQL, обмежена довжина рядка
    title = models.CharField(
        max_length=200,
        verbose_name='Заголовок'
    )

    # TextField → TEXT в SQL, необмежений текст
    content = models.TextField(
        blank=True,
        verbose_name='Текст'
    )

    # DateTimeField з auto_now_add=True — встановлюється при CREATE, не змінюється
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Створено'
    )

    # auto_now=True — оновлюється при кожному SAVE
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Оновлено'
    )

    def __str__(self):
        # Рядкове представлення: відображається в адмін-панелі
        # замість "Note object (1)"
        return self.title

    class Meta:
        verbose_name = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        ordering = ['-created_at']   # нові нотатки — першими
```

### Типи полів і їх SQL-відповідники

```python
# CharField — короткий рядок, обов'язковий max_length
title = models.CharField(max_length=200)
# SQL: title VARCHAR(200) NOT NULL

# TextField — довгий текст, без обмеження довжини
content = models.TextField(blank=True)
# blank=True: не обов'язкове у Django формах
# SQL: content TEXT NOT NULL DEFAULT ''

# DateTimeField з auto_now_add
created_at = models.DateTimeField(auto_now_add=True)
# SQL: created_at TIMESTAMP NOT NULL DEFAULT NOW()

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

---

## Крок Б2 — Зареєструй модель в адмін-панелі

Відкрий `hello_app/admin.py` і напиши:

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display    = ('title', 'created_at')          # Колонки у списку
    search_fields   = ('title', 'content')             # Поля для пошуку
    list_filter     = ('created_at',)                  # Фільтри праворуч
    ordering        = ('-created_at',)                 # Сортування
    readonly_fields = ('created_at', 'updated_at')     # Не редагувати
```

**Результат:** `http://localhost:8000/admin/hello_app/note/` — повноцінний CRUD для нотаток.

---

## Крок Б3 — Згенеруй міграцію

```bash
python manage.py makemigrations
```

```
Migrations for 'hello_app':
  hello_app/migrations/0001_initial.py
    + Create model Note
```

> `hello_app/migrations/0001_initial.py` — автоматично згенерований Python-скрипт
> який описує SQL що потрібно виконати. Не редагуй вручну.

---

## Крок Б4 — Застосуй міграцію до бази даних

```bash
python manage.py migrate
```

```
Applying hello_app.0001_initial... OK
```

Тепер в `db.sqlite3` з'явилась таблиця `hello_app_note`:

```sql
-- Що Django виконав за тебе:
CREATE TABLE "hello_app_note" (
    "id"         bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "title"      VARCHAR(200) NOT NULL,
    "content"    TEXT NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL
);
```

### Правило двох кроків

```bash
# Після БУДЬ-ЯКОЇ зміни models.py — завжди два кроки:
python manage.py makemigrations   # Зафіксувати план змін
python manage.py migrate          # Застосувати до БД

# makemigrations БЕЗ migrate:
# → Python-клас є, таблиці в БД немає → OperationalError при першому запиті
```

### Що відбувається між models.py і БД

```
models.py (Python клас)
    ↓ python manage.py makemigrations
hello_app/migrations/0001_initial.py  (план змін)
    ↓ python manage.py migrate
db.sqlite3 → таблиця hello_app_note  (реальна БД)
    ↓ @admin.register(Note)
http://127.0.0.1:8000/admin/hello_app/note/  (веб-інтерфейс)
```

---

## Крок Б5 — Перевір у браузері

```bash
python manage.py runserver
```

Відкрий `http://127.0.0.1:8000/admin/` — з'явився новий розділ **"Нотатки"**.

1. Натисни **"Add note"** / **"Додати нотатку"**
2. Введи заголовок і текст
3. Натисни **Save**
4. Нотатка збережена в `db.sqlite3` → таблиця `hello_app_note`

---

## Django ORM — базові запити через shell

```bash
python manage.py shell
```

```python
from hello_app.models import Note

# CREATE — INSERT INTO
Note.objects.create(title="Перша нотатка", content="Привіт Django!")
Note.objects.create(title="Django ORM", content="Дуже потужний!")

# READ — SELECT
Note.objects.all()                              # → QuerySet [<Note: Перша нотатка>, ...]
Note.objects.count()                            # → 2
Note.objects.filter(title__icontains='django')  # → case-insensitive пошук
Note.objects.get(id=1)                          # → <Note: Перша нотатка> або DoesNotExist
Note.objects.first()                            # → перший об'єкт
Note.objects.order_by('-created_at')            # → нові першими

# UPDATE — UPDATE SET
note = Note.objects.get(id=1)
note.title = "Змінена нотатка"
note.save()                      # → UPDATE hello_app_note SET title=... WHERE id=1

# DELETE — DELETE FROM
note.delete()                                   # → видалити один запис
Note.objects.filter(id__gt=5).delete()         # → видалити всі з id > 5

# QuerySet — ліниві:
qs = Note.objects.all()   # ← SQL ЩЕ НЕ ВИКОНУЄТЬСЯ
print(qs)                  # ← Тільки тут SQL виконується!

# Корисні lookups:
Note.objects.filter(title__icontains='перша')   # icontains = case-insensitive LIKE
Note.objects.filter(title__startswith='Django')
Note.objects.filter(created_at__year=2026)
Note.objects.filter(id__in=[1, 2, 3])
Note.objects.exclude(title='секрет')            # NOT LIKE
```

> Django shell — звичайний Python інтерпретатор але з завантаженим Django.
> Зручно для швидкого тестування ORM-запитів без написання views.

---

## Повна реєстрація: admin.site.register vs @admin.register

```python
# Варіант 1: простий
admin.site.register(Note)

# Варіант 2: з конфігурацією (краще)
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_at')
```

Обидва роблять одне і те саме, але `@admin.register` читабельніший і дозволяє
задати `list_display`, `search_fields`, `list_filter` одночасно.
