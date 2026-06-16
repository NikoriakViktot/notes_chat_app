# Проектування домену

> **"Design before code."**
> Помилка №1 — починати з `class Note(models.Model)` і додавати поля «на ходу».
> Через місяць — рефакторинг схеми = складна міграція, яку важко відкотити в prod.
> **30 хвилин на проектування = тижні зекономленого часу.**

---

## 7-крокова методологія

| # | Крок | Що робиш | Приклад |
|---|------|----------|---------|
| **1** | **ДОМЕН** | Описати словами що будуєш | «Користувач має записники. Записники містять нотатки. Нотатки мають теги і нагадування.» |
| **2** | **СУТНОСТІ** | Знайди іменники в описі | `User`, `Notebook`, `Note`, `Tag`, `Reminder`, `TodoList`, `ShoppingList` |
| **3** | **АТРИБУТИ** | Що ми знаємо про кожну сутність? | `Note` → `title`, `content`, `priority`, `is_pinned`, `is_archived` |
| **4** | **ЗВ'ЯЗКИ** | Як сутності пов'язані? | `1:1` User↔Profile · `1:N` Notebook→Notes · `M:N` Note↔Tag |
| **5** | **НОРМАЛІЗАЦІЯ** | Прибери дублювання | `author_name` у Note? — Ні, лише FK на User |
| **6** | **on_delete** | Що при видаленні батька? | CASCADE / SET_NULL / PROTECT |
| **7** | **DJANGO МОДЕЛЬ** | _Тільки тепер_ пишемо `models.py` | ← Типова помилка: починати звідси |

> **Anti-pattern.** Почати з `class Note(models.Model)` і додавати поля «на ходу».
> ER-діаграма — це **контракт** між тобою і базою. Порушиш його в коді — заплатиш міграцією.

---

## Де живе "правда"

**Нормалізація — кожен факт зберігається рівно в одному місці.**

```
DOMAIN    → "Юзер пише нотатки" — бізнес-мова
SCHEMA    → ER-діаграма — структура таблиць і зв'язків
CODE      → models.py — Python-представлення схеми
MIGRATIONS → Git-коміти для схеми БД
ADMIN     → зворотній зв'язок: бачиш структуру у браузері
```

```
❌ ДЕНОРМАЛІЗОВАНА СХЕМА (дублювання):
NOTE таблиця:
  author_name VARCHAR(150)  ← дублювання імені юзера!
  author_email VARCHAR(254) ← і email теж!

Проблема:
  1. Юзер змінює ім'я → треба UPDATE всіх його нотаток
  2. Розбіжність: note.author_name ≠ user.username → DATA INCONSISTENCY
  3. Видалення юзера → orphan записи без автора

✅ НОРМАЛІЗОВАНА СХЕМА:
NOTE таблиця:
  user_id BIGINT FK → auth_user  ← один факт: ця нотатка належить юзеру з id

Ім'я юзера? → note.user.username (JOIN)
Email юзера? → note.user.email (JOIN)
Одне місце правди → ніякої розбіжності
```

---

## Крок 0 — Від домену до схеми

> **Ментальна модель:** Проектування бази даних — це не "яку таблицю додати". Це **моделювання реального світу**. Спочатку думаєш мовою бізнесу: "користувач може мати записники, кожен записник містить нотатки, нотатки можуть мати теги". Потім переводиш це в структури даних. Django моделі — це останній крок, а не перший.
>
> **Де починаються помилки:** Більшість проблем зі схемою БД виникають тому що розробник одразу пише код, не думаючи про зв'язки. Через місяць виявляється що потрібен новий зв'язок — а додати його без масивної міграції неможливо.
>
> **Типова помилка:** Починати з написання моделі. Правильний порядок: **домен → сутності → атрибути → зв'язки → нормалізація → Django модель**.

### Процес проектування (правильний порядок)

```
1. ДОМЕН — описати словами що будуємо
   "Користувач має записники. Записники містять нотатки.
    Нотатки можуть бути в списках справ. Є нагадування з датою."

2. СУТНОСТІ — знайти "іменники" в описі домену
   Користувач, Записник, Нотатка, Список справ, Пункт списку,
   Нагадування, Список покупок, Товар, Тег

3. АТРИБУТИ — для кожної сутності: що ми знаємо про неї?
   Нотатка: title, content, created_at, is_pinned, priority

4. ЗВ'ЯЗКИ — як сутності пов'язані одна з одною?
   Нотатка → Записник: багато нотаток в одному записнику (FK)
   Нотатка ↔ Тег: одна нотатка, багато тегів; один тег, багато нотаток (M:N)

5. НОРМАЛІЗАЦІЯ — перевірити: чи є дублювання?
   Якщо в Нотатці є поле author_name — це дублювання з User. Замінити на FK.

6. ВИБІР on_delete — що відбувається при видаленні батьківського запису?
   Видалення Записника → видалити всі нотатки (CASCADE)?
   Або зберегти нотатки без записника (SET_NULL)?

7. DJANGO МОДЕЛЬ — тільки після всього вище
```

---

## Крок 1 — Проектуємо домен

Ми будуємо **персональний менеджер записів** — як Notion або Evernote, але спрощений.

### Що повинен вміти наш продукт

| Функція | Опис |
|---------|------|
| Записники | Колекції нотаток (як папки). Кожна нотатка в одному записнику |
| Нотатки | Текстові записи з заголовком, вмістом, тегами, пріоритетом |
| Теги | Мітки для нотаток. Одна нотатка = багато тегів. Один тег = багато нотаток |
| Списки справ | To-do list. Кожен список має пункти з галочкою |
| Списки покупок | Список товарів з кількістю та чи куплено |
| Нагадування | Повідомлення прив'язані до нотатки або дати |
| Пінінг | Нотатки можна закріпити зверху |
| Архів | Нотатки можна приховати без видалення |

---

## Крок 2 — Сутності та зв'язки

### Аналіз зв'язків по типах

```
ONE-TO-ONE (1:1) — "один має рівно одного":
  User ←→ UserProfile
  (кожен користувач має один профіль, один профіль у одного користувача)

ONE-TO-MANY (1:N) — "один має багато":
  User → Notebook          (один користувач, багато записників)
  Notebook → Note          (один записник, багато нотаток)
  User → Note              (нотатка має автора)
  User → TodoList          (один користувач, багато списків справ)
  TodoList → TodoItem      (один список, багато пунктів)
  User → ShoppingList      (один користувач, багато списків покупок)
  ShoppingList → ShopItem  (один список, багато товарів)
  Note → Reminder          (одна нотатка може мати кілька нагадувань)

MANY-TO-MANY (M:N) — "багато пов'язані з багатьма":
  Note ↔ Tag  (нотатка має теги, тег є у багатьох нотатках)
```

### Де живе FK — правило "Many side"

> **Навіщо:** помилка №2 — поставити FK на "One" сторону. Наприклад, зберігати `note_ids` у `Notebook`. SQL не підтримує масиви у стовпці (1NF). FK завжди на стороні "Many".

```
Notebook → Note (1:N):

  notebooks:                   notes:
  ┌────┬──────────┐            ┌────┬─────────────┬─────────────┐
  │ id │ title    │            │ id │ title        │ notebook_id │  ← FK тут
  ├────┼──────────┤            ├────┼─────────────┼─────────────┤
  │  1 │ Робота   │◄───────────│  1 │ Django ORM   │      1      │
  │  2 │ Особисте │◄───────────│  2 │ Python tips  │      1      │
  │    │          │◄───────────│  3 │ Рецепт борщу │      2      │
  └────┴──────────┘            └────┴─────────────┴─────────────┘

Notebook НЕ зберігає список нотаток.
Note зберігає ПОСИЛАННЯ на свій записник (notebook_id=1).
```

---

## Крок 3 — Повна схема: 11 таблиць Notes Platform

```
schema_v1 · 11 tables · 1 junction table · postgres-ready
─────────────────────────────────────────────────────────

USER (auth_user)                    USER_PROFILE  ←── 1:1 OneToOne
┌──────────────┬─────────────┐      ┌────────────────┬──────────────────┐
│ id           │ bigint PK   │──┐   │ id             │ bigint PK        │
│ username     │ varchar(150)│  └──►│ user_id        │ bigint UNIQUE FK │
│ email        │ varchar(254)│      │ display_name   │ varchar(60)      │
│ password     │ varchar(128)│      │ timezone       │ varchar(40)      │
│ date_joined  │ timestamp   │      │ avatar_url     │ text             │
└──────────────┴─────────────┘      └────────────────┴──────────────────┘
       │ owns 1:N              │ writes 1:N          │ owns tags 1:N
       ▼                       ▼                     ▼
NOTEBOOK                      NOTE (центральна)     TAG
┌─────────────┬──────────┐    ┌───────────────┬──────────────────┐    ┌──────────┬───────────────────┐
│ id          │ bigint PK│    │ id            │ bigint PK        │    │ id       │ bigint PK         │
│ user_id     │ bigint FK│    │ user_id       │ bigint FK        │    │ user_id  │ bigint FK         │
│ title       │ varchar  │    │ notebook_id   │ bigint NULL FK   │    │ name     │ varchar(50)       │
│ color       │ varchar  │    │ title         │ varchar(200)     │    │ color    │ varchar(7)        │
│ is_default  │ boolean  │    │ content       │ text             │    └──────────┴───────────────────┘
└─────────────┴──────────┘    │ priority      │ smallint         │     unique_together(user_id, name)
       │ contains 1:N         │ is_pinned     │ boolean          │
       └─────────────────────►│ is_archived   │ boolean          │◄──── M:N через NOTE_TAGS
                              │ created_at    │ timestamp        │
                              │ updated_at    │ timestamp        │
                              │ views_count   │ integer          │
                              └───────────────┴──────────────────┘
                                     │ reminds 1:N
                                     ▼
                              REMINDER                         NOTE_TAGS (junction)
                              ┌───────────┬──────────────┐     ┌──────────┬────────────┐
                              │ id        │ bigint PK    │     │ note_id  │ bigint FK  │
                              │ note_id   │ bigint FK    │     │ tag_id   │ bigint FK  │
                              │ remind_at │ timestamp    │     └──────────┴────────────┘
                              │ is_sent   │ boolean      │     UNIQUE(note_id, tag_id)
                              │ repeat    │ varchar(20)  │     Django створює авто
                              └───────────┴──────────────┘

TODO_LIST                     TODO_ITEM
┌─────────────┬──────────┐    ┌────────────────┬──────────────┐
│ id          │ bigint PK│    │ id             │ bigint PK    │
│ user_id     │ bigint FK│───►│ todo_list_id   │ bigint FK    │
│ title       │ varchar  │    │ text           │ varchar(500) │
│ is_completed│ boolean  │    │ is_done        │ boolean      │
└─────────────┴──────────┘    │ order_position │ integer      │
                              │ due_date       │ date NULL    │
                              └────────────────┴──────────────┘

SHOPPING_LIST                 SHOP_ITEM
┌─────────────┬──────────┐    ┌──────────────────┬──────────────────┐
│ id          │ bigint PK│    │ id               │ bigint PK        │
│ user_id     │ bigint FK│───►│ shopping_list_id │ bigint FK        │
│ title       │ varchar  │    │ name             │ varchar(120)     │
│ store_name  │ varchar  │    │ quantity         │ decimal(8,2)     │
└─────────────┴──────────┘    │ unit             │ varchar(20)      │
                              │ is_purchased     │ boolean          │
                              │ estimated_price  │ decimal(10,2)    │
                              └──────────────────┴──────────────────┘
                              ⚠️ DecimalField для грошей — не FloatField!
```

---

## Крок 4 — Типи зв'язків з кодом

### 1:1 — OneToOneField

> **Навіщо:** Розширюємо вбудований `User` не торкаючись його коду. Всі нестандартні поля — в `UserProfile`. Це вертикальне партиціонування: 5 базових полів у User, 20 опціональних у Profile.

```python
class UserProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,   # профіль без юзера безглуздий → CASCADE
        related_name='profile',     # user.profile — доступ з User
    )
    display_name = models.CharField(max_length=60, blank=True)
    timezone     = models.CharField(max_length=40, default='UTC')
    avatar_url   = models.URLField(blank=True)

    def __str__(self):
        return f'Profile({self.user.username})'
```

**SQL що генерує Django:**
```sql
CREATE TABLE "notes_app_userprofile" (
    "id"           bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "user_id"      bigint NOT NULL UNIQUE REFERENCES "auth_user" ("id") ON DELETE CASCADE,
    "display_name" varchar(60) NOT NULL DEFAULT '',
    "timezone"     varchar(40) NOT NULL DEFAULT 'UTC',
    "avatar_url"   varchar(200) NOT NULL DEFAULT ''
);
```

Ключове слово тут — `UNIQUE`. Це те що відрізняє 1:1 від 1:N. Без `UNIQUE` один юзер міг би мати кілька профілів.

**Доступ:**
```python
user = User.objects.get(username='alice')
user.profile              # → UserProfile (не QuerySet! UNIQUE FK → один об'єкт)
user.profile.timezone     # → 'Europe/Kyiv'
user.profile.display_name # → 'Alice'
```

---

### 1:N — ForeignKey

> **Навіщо:** Один записник містить багато нотаток. FK завжди ставиться на сторону "Many" — у `Note`, а не у `Notebook`. Notebook не може зберігати список `note_ids` — SQL-стовпець містить одне значення, не масив.

```python
class Notebook(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='notebooks')
    title      = models.CharField(max_length=100)
    color      = models.CharField(max_length=7, default='#6c757d')  # HEX колір
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.title
```

```python
class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    'Низький'),
        (PRIORITY_MEDIUM, 'Середній'),
        (PRIORITY_HIGH,   'Високий'),
    ]

    user     = models.ForeignKey(User, on_delete=models.CASCADE,
                                 related_name='notes')
    notebook = models.ForeignKey(
        Notebook,
        on_delete=models.SET_NULL,  # видалення записника → нотатка живе далі
        null=True, blank=True,      # null=True обов'язковий коли on_delete=SET_NULL
        related_name='notes',
    )
    tags = models.ManyToManyField('Tag', blank=True)  # M:N — окрема junction table

    title       = models.CharField(max_length=200)
    content     = models.TextField(blank=True)
    priority    = models.PositiveSmallIntegerField(
        choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM
    )
    is_pinned   = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)  # встановлюється один раз при CREATE
    updated_at  = models.DateTimeField(auto_now=True)      # оновлюється при кожному SAVE
    views_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-is_pinned', '-updated_at']  # закріплені зверху, потім за датою

    def __str__(self):
        return self.title
```

**Чому `notebook` з `SET_NULL`, а не `CASCADE`?**

Бізнес-рішення: коли користувач видаляє записник "Робота", його нотатки не повинні зникнути — вони переходять у стан "без записника". `CASCADE` означав би втрату всіх нотаток разом із записником.

**Доступ:**
```python
notebook = Notebook.objects.get(title='Робота')
notebook.notes.all()        # → QuerySet[Note] (зворотній доступ через related_name)
notebook.notes.count()      # → 5

note = Note.objects.get(pk=1)
note.notebook               # → Notebook або None (після SET_NULL)
note.notebook.title         # → 'Робота'
note.user.username          # → 'alice'
```

---

### M:N — ManyToManyField

> **Навіщо:** Одна нотатка може мати кілька тегів. Один тег може бути у кількох нотатках. Це M:N зв'язок. SQL реалізує його через окрему junction-таблицю — Django створює її автоматично.

```python
class Tag(models.Model):
    user  = models.ForeignKey(User, on_delete=models.CASCADE,
                               related_name='tags')
    name  = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#6c757d')

    class Meta:
        unique_together = [('user', 'name')]
        # Alice і Bob можуть мати тег 'python' — constraint на (user_id, name)

    def __str__(self):
        return self.name
```

Django автоматично створює junction table `notes_app_note_tags`:

```sql
CREATE TABLE "notes_app_note_tags" (
    "id"      bigint NOT NULL PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "note_id" bigint NOT NULL REFERENCES "notes_app_note" ("id") ON DELETE CASCADE,
    "tag_id"  bigint NOT NULL REFERENCES "notes_app_tag" ("id") ON DELETE CASCADE,
    UNIQUE ("note_id", "tag_id")
);
```

**Доступ:**
```python
note = Note.objects.get(pk=1)
note.tags.all()                      # → QuerySet[Tag]
note.tags.add(tag_py, tag_django)    # INSERT × 2 у junction table
note.tags.remove(tag_py)             # DELETE з junction table
note.tags.set([tag_django])          # синхронізувати — видалити зайві, додати нові

# Зворотній доступ:
tag = Tag.objects.get(name='python')
tag.note_set.all()                   # → QuerySet[Note] що мають цей тег
# або через related_name якщо задати:
# tags = models.ManyToManyField('Tag', blank=True, related_name='notes')
# tag.notes.all()
```

---

## Крок 5 — on_delete матриця

> **Навіщо:** `on_delete` — не технічне, а **бізнес-рішення**. Що відбувається з даними при видаленні пов'язаного об'єкта? Неправильний вибір = втрата даних або orphan-записи.

| Стратегія | Що робить | Коли вибирати | Приклад |
|-----------|-----------|---------------|---------|
| `CASCADE` | Видалити дочірні автоматично | Нотатка без автора безглузда | `Reminder → Note` |
| `SET_NULL` | FK → NULL, дочірні живуть | Нотатка може існувати без записника | `Note.notebook → Notebook` |
| `SET_DEFAULT` | FK → значення `default` | Перенести в "за замовчуванням" | `Note → DefaultNotebook` |
| `PROTECT` | `ProtectedError`, заборонено | Не дати видалити якщо є залежні | Не вбудований у наш проєкт |
| `RESTRICT` | Заборонити, але з нюансами | Складні домени | Рідко |
| `DO_NOTHING` | БД сама вирішує → orphan | Майже ніколи | Небезпечно |

**Notes Platform — таблиця рішень:**

| Зв'язок | on_delete | Обґрунтування |
|---------|-----------|--------------|
| `UserProfile.user` | `CASCADE` | Профіль без юзера не має сенсу |
| `Notebook.user` | `CASCADE` | Записники належать юзеру, видалення юзера = видалення всього |
| `Note.user` | `CASCADE` | Нотатки без автора безглузді |
| `Note.notebook` | `SET_NULL` | Нотатка може існувати без записника (переходить у "без папки") |
| `Tag.user` | `CASCADE` | Теги прив'язані до юзера |
| `Reminder.note` | `CASCADE` | Нагадування без нотатки безглузде |
| `TodoItem.todo_list` | `CASCADE` | Пункт без списку не потрібен |
| `ShopItem.shopping_list` | `CASCADE` | Товар без списку не потрібен |

---

## Крок 6 — Повний код models.py

> **Навіщо:** Тільки після того як проектування завершено (кроки 1-5) — пишемо код. Кожне рішення вище відображається в одному рядку `models.py`.

```python
# notes_app/models.py
from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    user         = models.OneToOneField(User, on_delete=models.CASCADE,
                                        related_name='profile')
    display_name = models.CharField(max_length=60, blank=True)
    timezone     = models.CharField(max_length=40, default='UTC')
    avatar_url   = models.URLField(blank=True)

    def __str__(self):
        return f'Profile({self.user.username})'


class Tag(models.Model):
    user  = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tags')
    name  = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#6c757d')

    class Meta:
        unique_together = [('user', 'name')]

    def __str__(self):
        return self.name


class Notebook(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='notebooks')
    title      = models.CharField(max_length=100)
    color      = models.CharField(max_length=7, default='#6c757d')
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.title


class Note(models.Model):
    PRIORITY_LOW    = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH   = 3
    PRIORITY_CHOICES = [
        (PRIORITY_LOW,    'Низький'),
        (PRIORITY_MEDIUM, 'Середній'),
        (PRIORITY_HIGH,   'Високий'),
    ]

    user     = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    notebook = models.ForeignKey(
        Notebook, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='notes',
    )
    tags = models.ManyToManyField(Tag, blank=True)

    title       = models.CharField(max_length=200)
    content     = models.TextField(blank=True)
    priority    = models.PositiveSmallIntegerField(
        choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM,
    )
    is_pinned   = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)
    views_count = models.PositiveIntegerField(default=0)
    group       = models.ForeignKey(
        'auth.Group', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='notes',
    )

    class Meta:
        ordering = ['-is_pinned', '-updated_at']

    def __str__(self):
        return self.title


class Reminder(models.Model):
    REPEAT_CHOICES = [
        ('none',    'Одноразово'),
        ('daily',   'Щодня'),
        ('weekly',  'Щотижня'),
        ('monthly', 'Щомісяця'),
    ]

    note           = models.ForeignKey(Note, on_delete=models.CASCADE,
                                       related_name='reminders')
    remind_at      = models.DateTimeField()
    message        = models.TextField(blank=True)
    is_sent        = models.BooleanField(default=False)
    repeat_pattern = models.CharField(
        max_length=10, choices=REPEAT_CHOICES, default='none',
    )

    class Meta:
        ordering = ['remind_at']

    def __str__(self):
        return f'Reminder({self.note.title}, {self.remind_at})'


class TodoList(models.Model):
    user         = models.ForeignKey(User, on_delete=models.CASCADE,
                                     related_name='todo_lists')
    title        = models.CharField(max_length=100)
    is_completed = models.BooleanField(default=False)

    def __str__(self):
        return self.title


class TodoItem(models.Model):
    todo_list      = models.ForeignKey(TodoList, on_delete=models.CASCADE,
                                       related_name='items')
    text           = models.CharField(max_length=500)
    is_done        = models.BooleanField(default=False)
    order_position = models.PositiveIntegerField(default=0)
    due_date       = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['order_position']

    def __str__(self):
        return self.text


class ShoppingList(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE,
                                   related_name='shopping_lists')
    title      = models.CharField(max_length=100)
    store_name = models.CharField(max_length=100, blank=True)
    group      = models.ForeignKey(
        'auth.Group', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='shopping_lists',
    )

    def __str__(self):
        return self.title


class ShopItem(models.Model):
    UNIT_PIECE  = 'pcs'
    UNIT_KG     = 'kg'
    UNIT_LITER  = 'l'
    UNIT_CHOICES = [
        (UNIT_PIECE, 'шт'),
        (UNIT_KG,    'кг'),
        (UNIT_LITER, 'л'),
    ]

    shopping_list   = models.ForeignKey(ShoppingList, on_delete=models.CASCADE,
                                        related_name='items')
    name            = models.CharField(max_length=120)
    quantity        = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit            = models.CharField(max_length=20, choices=UNIT_CHOICES,
                                       default=UNIT_PIECE)
    is_purchased    = models.BooleanField(default=False)
    estimated_price = models.DecimalField(max_digits=10, decimal_places=2,
                                          null=True, blank=True)

    def __str__(self):
        return self.name
```

**Чому `DecimalField`, а не `FloatField` для цін і кількостей?**

```python
# FloatField — IEEE 754 binary floating point
0.1 + 0.2  # → 0.30000000000000004  ← округлення CPU

# DecimalField — десяткова арифметика (Python Decimal)
Decimal('0.1') + Decimal('0.2')  # → Decimal('0.3')  ← точно
```

Гроші завжди `DecimalField`. `FloatField` призводить до копійчаних розбіжностей у розрахунках.

---

## Крок 7 — Перевірка у Django shell

> **Навіщо:** До того як писати views і шаблони — перевіряємо що моделі і зв'язки працюють правильно через shell. Це найшвидший спосіб зловити помилки у проектуванні.

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.models import (
    UserProfile, Tag, Notebook, Note, Reminder,
    TodoList, TodoItem, ShoppingList, ShopItem
)

# --- 1:1 OneToOneField ---
user = User.objects.create_user('alice', 'alice@test.com', 'pass123')
profile = UserProfile.objects.create(user=user, display_name='Alice', timezone='Europe/Kyiv')

print(user.profile)            # → Profile(alice)
print(user.profile.timezone)   # → Europe/Kyiv

# --- 1:N ForeignKey ---
notebook = Notebook.objects.create(user=user, title='Робота', is_default=True)
tag_py = Tag.objects.create(user=user, name='python', color='#3776AB')
tag_dj = Tag.objects.create(user=user, name='django', color='#092E20')

note = Note.objects.create(
    user=user, notebook=notebook,
    title='Django ORM', content='QuerySet — лінива оцінка.',
    priority=Note.PRIORITY_HIGH, is_pinned=True,
)

# Зворотній доступ через related_name:
print(notebook.notes.count())  # → 1
print(notebook.notes.all())    # → <QuerySet [<Note: Django ORM>]>

# --- M:N ManyToManyField ---
note.tags.add(tag_py, tag_dj)                         # INSERT × 2 у junction table
print(note.tags.all())                                 # → <QuerySet [<Tag: python>, <Tag: django>]>
print(note.tags.count())                               # → 2

# Зворотній бік M:N:
print(tag_py.note_set.all())                           # → <QuerySet [<Note: Django ORM>]>

# --- Reminder (CASCADE від Note) ---
reminder = Reminder.objects.create(
    note=note,
    remind_at='2026-06-20 09:00:00+00:00',
    message='Завершити розділ про ORM',
)
print(note.reminders.count())   # → 1

# --- TodoList ---
todo = TodoList.objects.create(user=user, title='Вивчити ORM')
TodoItem.objects.bulk_create([
    TodoItem(todo_list=todo, text='Прочитати docs', order_position=1),
    TodoItem(todo_list=todo, text='Зробити shell-демо', order_position=2),
    TodoItem(todo_list=todo, text='Написати тести', order_position=3),
])
print(todo.items.count())       # → 3

# Перевіряємо CASCADE: видалення нотатки → видалення нагадувань
note_id = note.pk
note.delete()
print(Reminder.objects.filter(pk=reminder.pk).exists())  # → False (CASCADE спрацював)

# Перевіряємо SET_NULL: видалення записника → notebook_id у нотатках стає NULL
note2 = Note.objects.create(user=user, notebook=notebook, title='Нотатка 2', content='')
notebook.delete()
note2.refresh_from_db()
print(note2.notebook)  # → None (SET_NULL спрацював)
```

---

## У книзі

- [Частина III. База даних і ORM](../../03_database_and_orm/README.md) — N+1 проблема, `select_related`, `prefetch_related`, QuerySet API, `transaction.atomic`, indexes
- [Частина VI. Архітектура застосунку](../../06_application_architecture/README.md) — selectors/services паттерн, thin views, CQRS-light підхід

---

## Офіційна документація

- [Django: Models](https://docs.djangoproject.com/en/5.2/topics/db/models/) — поля, зв'язки, Meta
- [Django: ForeignKey](https://docs.djangoproject.com/en/5.2/ref/models/fields/#django.db.models.ForeignKey) — on_delete варіанти
- [Django: OneToOneField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#onetoonefield)
- [Django: ManyToManyField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#manytomanyfield)
- [Django: DecimalField](https://docs.djangoproject.com/en/5.2/ref/models/fields/#decimalfield) — чому не FloatField для грошей
- [Django: Making queries](https://docs.djangoproject.com/en/5.2/topics/db/queries/) — add, set, remove для M:N
