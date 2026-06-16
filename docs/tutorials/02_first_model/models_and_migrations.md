# Моделі і міграції

> У `bootstrap_notes` модель `Note` вже описана в `models.py` — ти успадковуєш її з Кроку 1.
> Ця сторінка пояснює її анатомію, як Django перетворює клас у таблицю БД,
> і як запустити проєкт з нуля.

---

## Що вже є у проєкті

`bootstrap_notes` — це продовження `hello_project`. `hello_app/models.py` містить:

```python
from django.db import models


class Note(models.Model):
    title      = models.CharField(max_length=200, verbose_name='Заголовок')
    content    = models.TextField(blank=True, verbose_name='Текст')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Створено')

    def __str__(self):
        return self.title

    class Meta:
        verbose_name        = 'Нотатка'
        verbose_name_plural = 'Нотатки'
        ordering            = ['-created_at']
```

І простий view:

```python
def note_list(request):
    notes = Note.objects.all()
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

Сторінка `/notes/` відображає нотатки у голому HTML без Bootstrap.
Наша мета — замінити цей шаблон і додати повноцінний CRUD.

---

## Залежності bootstrap_notes

`requirements.txt`:

| Пакет | Навіщо |
|-------|--------|
| `Django>=5.2,<6` | Веб-фреймворк |
| `django-bootstrap5>=24.0` | Bootstrap 5 для Django Forms (`{% bootstrap_form form %}`) |
| `django-debug-toolbar>=4.0` | SQL-панель для дебагу (Крок 4 — Templates) |
| `django-unfold>=0.40` | Tailwind-стилізований Django Admin (Крок 4 — Templates) |

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Перевір:
```bash
python -m django --version  # → 5.2.x
```

---

## Запуск проєкту

```bash
# 1. Активувати venv
source venv/bin/activate          # Linux/Mac
# або: venv\Scripts\activate      # Windows

# 2. Встановити залежності
pip install -r requirements.txt

# 3. Застосувати міграції
python manage.py migrate

# 4. Створити адміністратора
python manage.py createsuperuser

# 5. Запустити сервер
python manage.py runserver
```

| URL | Результат |
|-----|-----------|
| `http://localhost:8000/notes/` | Список нотаток (голий HTML) |
| `http://localhost:8000/admin/` | Адмін-панель |

Додай кілька нотаток через адмін — вони з'являться на `/notes/`.

---

## Анатомія моделі: від Python-класу до SQL-таблиці

```
Note (Python-клас)                 hello_app_note (таблиця SQL)
═══════════════════════════════════════════════════════════════
id (auto BigAutoField)          →  id bigint NOT NULL PRIMARY KEY
title (CharField(max_length=200)) →  title varchar(200) NOT NULL
content (TextField(blank=True)) →  content text NOT NULL DEFAULT ''
created_at (DateTimeField(auto_now_add=True)) → created_at timestamp NOT NULL
```

```python
# models.Model — базовий клас для всіх Django моделей
class Note(models.Model):
    #           ↑ успадковуємо від models.Model → отримуємо:
    #           - id (PRIMARY KEY AUTOINCREMENT) автоматично
    #           - Note.objects (Manager) → ORM API
    #           - .save(), .delete() методи

    title = models.CharField(
        max_length=200,          # VARCHAR(200) в SQL
        verbose_name='Заголовок' # назва поля в адмін-панелі
    )

    content = models.TextField(
        blank=True,              # Може бути порожнім у формах
        verbose_name='Текст'     # null=False за замовчуванням!
                                 # → TEXT NOT NULL DEFAULT ''
    )

    created_at = models.DateTimeField(
        auto_now_add=True,       # Встановлюється автоматично при CREATE
        verbose_name='Створено'  # auto_now_add=True → editable=False!
                                 # Не з'явиться у формах
    )
```

### blank=True vs null=True

```python
# blank=True — валідація форми: поле необов'язкове
content = models.TextField(blank=True)
# → форма приймає порожній рядок

# null=True — база даних: може зберігати NULL
content = models.TextField(null=True, blank=True)
# → БД зберігає NULL замість ''

# Для CharField/TextField — не використовуй null=True
# Django convention: порожній рядок '' замість NULL у рядкових полях
# Чому: NULL і '' — різні значення, два стани порожнього

# null=True корисне для числових полів:
age = models.IntegerField(null=True, blank=True)
# → "не вказано" (NULL) vs "0" — різні значення
```

---

## auto_now_add vs auto_now

```python
# auto_now_add=True: час СТВОРЕННЯ
created_at = models.DateTimeField(auto_now_add=True)
# Встановлюється один раз при INSERT → ніколи не змінюється
# editable=False → не з'явиться у формах

# auto_now=True: час ОСТАННЬОГО ОНОВЛЕННЯ
updated_at = models.DateTimeField(auto_now=True)
# Оновлюється при КОЖНОМУ save()
# editable=False → не з'явиться у формах

# Обидва:
class Note(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)  # час створення
    updated_at = models.DateTimeField(auto_now=True)      # час оновлення
```

---

## __str__ і Meta

```python
def __str__(self):
    return self.title
    # Рядкове представлення об'єкта:
    # Без __str__: "Note object (1)"  ← незручно
    # З __str__:   "Shopping list"    ← зрозуміло
    #
    # Використовується: в адмін-панелі, Django shell,
    # ModelChoiceField (select) у формах

class Meta:
    verbose_name        = 'Нотатка'
    verbose_name_plural = 'Нотатки'
    # Ці рядки відображаються в адмін-панелі
    # Без них: "Note" / "Notes" (англ.)

    ordering = ['-created_at']
    # Дефолтне сортування: '-' означає DESC (нові першими)
    # Еквівалент: Note.objects.order_by('-created_at')
    # Всі QuerySet без .order_by() використовуватимуть це сортування
```

---

## Цикл міграцій

```
models.py (Python-клас)
    ↓
python manage.py makemigrations
    ↓
hello_app/migrations/0001_initial.py  (план змін у Python)
    ↓
python manage.py migrate
    ↓
БД: hello_app_note (реальна таблиця)
```

```bash
# Показати SQL що виконає міграція:
python manage.py sqlmigrate hello_app 0001
```

```sql
-- Output:
BEGIN;
CREATE TABLE "hello_app_note" (
    "id"         bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "title"      varchar(200) NOT NULL,
    "content"    text NOT NULL,
    "created_at" timestamp with time zone NOT NULL
);
COMMIT;
```

### Правило двох кроків

```bash
# Після БУДЬ-ЯКОЇ зміни models.py — завжди два кроки:
python manage.py makemigrations   # Зафіксувати план
python manage.py migrate          # Застосувати до БД

# makemigrations БЕЗ migrate:
# Python-клас оновлений, таблиця в БД — стара
# → OperationalError: column does not exist
```

---

## Що перевірити після запуску

```bash
python manage.py runserver
```

| URL | Результат |
|-----|-----------|
| `http://localhost:8000/notes/` | Список нотаток (голий HTML без Bootstrap — поки що) |
| `http://localhost:8000/admin/` | Адмін-панель |

Додай кілька нотаток через адмін перед тим як продовжити — вони знадобляться
для перевірки Bootstrap Cards у наступному розділі.
