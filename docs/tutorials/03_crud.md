# Туторіал 03 — Domain Design, ORM і архітектура selectors/services

**Мета:** навчитись проектувати схему даних методично, написати Django-моделі з усіма типами зв'язків і організувати бізнес-логіку у шари `selectors.py` / `services.py`.

---

## 7-крокова методологія DOMAIN → SCHEMA

**Помилка №1:** починати з `class Note(models.Model)` і додавати поля «на ходу».
30 хвилин на проектування = тижні зекономленого часу на рефакторинг.

| # | Крок | Що робиш | Приклад |
|---|------|----------|---------|
| 1 | **ДОМЕН** | Описати словами що будуєш | «Користувач має записники. Записники містять нотатки. Нотатки мають теги і нагадування.» |
| 2 | **СУТНОСТІ** | Знайди іменники в описі | `User`, `Notebook`, `Note`, `Tag`, `Reminder` |
| 3 | **АТРИБУТИ** | Що ми знаємо про кожну сутність? | `Note` → `title`, `content`, `priority`, `is_pinned` |
| 4 | **ЗВ'ЯЗКИ** | Як сутності пов'язані? | `1:1` User↔Profile · `1:N` Notebook→Notes · `M:N` Note↔Tag |
| 5 | **НОРМАЛІЗАЦІЯ** | Прибери дублювання | `author_name` у Note? — Ні, лише FK на User |
| 6 | **on_delete** | Що при видаленні батька? | CASCADE / SET_NULL / PROTECT |
| 7 | **DJANGO МОДЕЛЬ** | Тільки тепер пишемо `models.py` | ← Типова помилка: починати звідси |

---

## Типи зв'язків між таблицями

### 1:1 — OneToOneField

```
USER ──────────► USER_PROFILE
  id PK              user_id UNIQUE FK
```

```python
class UserProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE,
        related_name='profile',
    )
    display_name = models.CharField(max_length=60)
    timezone = models.CharField(max_length=40, default='UTC')

# Використання:
user.profile.display_name    # реверс — атрибут, не QuerySet
```

**Коли:** "вертикальне партиціонування" — 5 базових полів у User, 20 опціональних у Profile.

---

### 1:N — ForeignKey

```
NOTEBOOK ──────► NOTE ◄── FK тут, на "Many" стороні
  id PK              notebook_id FK
```

```python
class Note(models.Model):
    notebook = models.ForeignKey(
        'Notebook', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='notes',
    )

# Використання:
notebook.notes.all()      # реверс → QuerySet
note.notebook.title       # пряме → атрибут
```

**Правило:** FK живе **на "Many"-стороні**. `Notebook` не зберігає список нотаток — `Note` зберігає `notebook_id`.

---

### M:N — ManyToManyField

```
NOTE ──► NOTE_TAGS (junction) ◄── TAG
 id PK     note_id FK                id PK
           tag_id FK
```

```python
class Note(models.Model):
    tags = models.ManyToManyField('Tag', blank=True)

# Django сам створює junction: hello_app_note_tags(note_id, tag_id)
note.tags.add(tag_py, tag_dj)    # INSERT × 2 у junction
note.tags.all()                  # SELECT * JOIN
tag_py.note_set.all()            # реверс
```

---

### on_delete — стратегії

| Стратегія | Що робить | Коли вибирати |
|-----------|-----------|---------------|
| `CASCADE` | Видалити дочірні автоматично | `Reminder` після видалення `Note` — нагадування без нотатки безглузде |
| `SET_NULL` | FK → NULL, дочірні залишаються | `Note.notebook` — нотатка існує без записника (`null=True` обов'язково) |
| `PROTECT` | `ProtectedError`, видалення заборонено | Заборонити видалення тегу поки він використовується |
| `RESTRICT` | Заборонити (але дозволити каскад з вищого рівня) | Складні ієрархії |
| `DO_NOTHING` | Залишити orphan-запис | Майже ніколи — тільки при ручному управлінні |

> ⚠️ **Помилка:** CASCADE для всього → одне видалення User може стерти сотні рядків. Завжди свідомо вибирай стратегію — це бізнес-рішення.

---

## Django-моделі

```python
# hello_app/models.py
from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    display_name = models.CharField(max_length=60, blank=True)
    timezone = models.CharField(max_length=40, default='UTC')

    def __str__(self):
        return f'Profile({self.user.username})'


class Tag(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tags')
    name = models.CharField(max_length=50)
    color = models.CharField(max_length=7, default='#808080')

    class Meta:
        unique_together = ('user', 'name')
        ordering = ['name']

    def __str__(self):
        return self.name


class Notebook(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notebooks')
    title = models.CharField(max_length=100)
    color = models.CharField(max_length=7, default='#6c757d')
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_default', 'title']

    def __str__(self):
        return self.title


class Note(models.Model):
    PRIORITY_LOW = 1
    PRIORITY_MEDIUM = 2
    PRIORITY_HIGH = 3
    PRIORITY_CHOICES = [
        (PRIORITY_LOW, 'Низький'),
        (PRIORITY_MEDIUM, 'Середній'),
        (PRIORITY_HIGH, 'Високий'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notes')
    notebook = models.ForeignKey(
        Notebook, on_delete=models.SET_NULL,    # SET_NULL: нотатка без записника
        null=True, blank=True, related_name='notes'
    )
    tags = models.ManyToManyField(Tag, blank=True)  # M:N

    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)
    priority = models.SmallIntegerField(choices=PRIORITY_CHOICES, default=PRIORITY_LOW)
    is_pinned = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-priority', '-updated_at']

    def __str__(self):
        return self.title


class Reminder(models.Model):
    note = models.ForeignKey(Note, on_delete=models.CASCADE, related_name='reminders')
    remind_at = models.DateTimeField()
    is_sent = models.BooleanField(default=False)

    class Meta:
        ordering = ['remind_at']
```

Після написання моделей — обов'язково два кроки:
```bash
python manage.py makemigrations
python manage.py migrate
```

---

## Архітектура шарів: selectors/services

```
HTTP REQUEST
     │
     ▼
┌────────────────────────────┐
│  views.py                  │
│  ✓ парсить request         │
│  ✓ кличе selector/service  │
│  ✓ render / redirect       │
│  ✗ жодних QuerySet         │
└────┬───────────────┬───────┘
     │ READ →        │ WRITE →
     ▼               ▼
┌────────────┐  ┌───────────────────┐
│ selectors  │  │ services          │
│ SELECT only│  │ CREATE/UPDATE/DEL │
└─────┬──────┘  └──────┬────────────┘
      └────────┬────────┘
               ▼
          PostgreSQL
```

**Чому розділяти?** Один запит потрібен у View, Celery task, API endpoint, тесті. Без `selectors.py` — копіюєш QuerySet у 10 місцях.

### selectors.py

```python
# hello_app/selectors.py
from django.db.models import Count, Q

from .models import Note, Notebook, Tag


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Список нотаток.
    select_related + prefetch_related — вирішує N+1 проблему.
    """
    qs = Note.objects.filter(
        user=user,
        is_archived=archived,
    ).select_related(
        'notebook'       # FK → JOIN (1 запит замість N)
    ).prefetch_related(
        'tags'           # M:N → 2-й запит (не N запитів)
    )

    if notebook:
        qs = qs.filter(notebook=notebook)
    if tag:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(
            Q(title__icontains=search) | Q(content__icontains=search)
        )

    return qs.order_by('-is_pinned', '-priority', '-updated_at')


def get_user_notebooks(user):
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    ).order_by('-is_default', 'title')


def get_user_tags(user):
    return Tag.objects.filter(user=user).annotate(
        note_count=Count('notes')
    ).order_by('name')
```

### services.py

```python
# hello_app/services.py
from django.db import transaction

from .models import Note, Tag


def create_note(*, user, title, content='', notebook=None, priority=1, tag_ids=None):
    """
    transaction.atomic(): або Note і теги зберігаються разом, або нічого.
    """
    with transaction.atomic():
        note = Note.objects.create(
            user=user,
            title=title,
            content=content,
            notebook=notebook,
            priority=priority,
        )
        if tag_ids:
            # Перевіряємо що теги належать цьому user — безпека!
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)
    return note


def update_note(note, *, title=None, content=None, priority=None, is_pinned=None, tag_ids=None):
    """update_fields → UPDATE тільки змінених стовпців."""
    changed = []
    if title is not None:
        note.title = title; changed.append('title')
    if content is not None:
        note.content = content; changed.append('content')
    if priority is not None:
        note.priority = priority; changed.append('priority')
    if is_pinned is not None:
        note.is_pinned = is_pinned; changed.append('is_pinned')

    if changed:
        note.save(update_fields=changed)

    if tag_ids is not None:
        valid_tags = Tag.objects.filter(id__in=tag_ids, user=note.user)
        note.tags.set(valid_tags)

    return note


def delete_note(note):
    note.delete()   # CASCADE видалить Reminders автоматично
```

---

## Тонкі views

```python
# hello_app/views.py
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.contrib.auth.decorators import login_required

from .models import Note
from .forms import NoteForm
from . import selectors, services


@login_required
def note_list(request):
    search = request.GET.get('q', '')
    # View тільки парсить параметри і делегує selector
    notes = selectors.get_user_notes(request.user, search=search or None)
    tags = selectors.get_user_tags(request.user)
    notebooks = selectors.get_user_notebooks(request.user)

    return render(request, 'hello_app/note_list.html', {
        'notes': notes,
        'tags': tags,
        'notebooks': notebooks,
        'search': search,
    })


@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
            )
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {'form': form, 'title': 'Нова нотатка'})


@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            services.update_note(note, **form.cleaned_data)
            messages.success(request, 'Нотатку оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)

    return render(request, 'hello_app/note_form.html', {'form': form, 'note': note})


@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    if request.method == 'POST':
        title = note.title
        services.delete_note(note)
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

---

## N+1 проблема і як її вирішити

**N+1 проблема:** якщо у списку 50 нотаток, Django за замовчуванням виконає 51 SQL запит.

```python
# ❌ N+1 — 1 запит для списку + N для notebook кожної нотатки:
notes = Note.objects.filter(user=user)
for note in notes:
    print(note.notebook.title)   # ← кожен цикл = +1 SQL

# ✅ select_related — 1 JOIN, 1 запит:
notes = Note.objects.filter(user=user).select_related('notebook')

# ✅ prefetch_related для M:N (tags):
notes = Note.objects.filter(user=user).prefetch_related('tags')
# Django виконає 2 запити: 1 для notes, 1 для всіх tags відразу
```

---

## Матриця відповідальності

| Шар | Робить | НЕ робить |
|-----|--------|-----------|
| `models.py` | Структура, поля, зв'язки, constraints | Бізнес-логіка, HTTP |
| `selectors.py` | SELECT, filter, annotate, prefetch | INSERT / UPDATE / DELETE |
| `services.py` | CREATE / UPDATE / DELETE, transaction | HTTP, render, redirect |
| `views.py` | Парсити request, render, redirect | QuerySet, бізнес-логіка |

**Перевір себе:** якщо в `views.py` бачиш `Note.objects.filter(...)` — це сигнал перенести у `selectors.py`.

---

## Практичне завдання

1. Намалюй ER-діаграму для системи "Бібліотека": `Book`, `Author`, `Genre`, `Review`.
   Вкажи типи зв'язків і `on_delete` для кожного FK.
2. Реалізуй моделі з правильними `related_name`.
3. Напиши `get_books_by_author(author)` в `selectors.py` з `prefetch_related('genres')`.
4. Напиши `create_book(*, title, author_id, genre_ids)` в `services.py` з `transaction.atomic()`.
5. Переконайся що View не містить жодного `Model.objects.*` виклику напряму.

---

## Чеклист самоперевірки

- [ ] Я знаю різницю між `OneToOneField`, `ForeignKey` і `ManyToManyField`
- [ ] Я розумію де живе FK (на "Many"-стороні)
- [ ] Я свідомо вибираю `on_delete` стратегію для кожного FK
- [ ] `selectors.py` містить тільки SELECT операції
- [ ] `services.py` використовує `transaction.atomic()` для операцій запису
- [ ] `views.py` не містить `Model.objects.*` напряму
- [ ] Я розумію N+1 проблему і використовую `select_related` / `prefetch_related`

---

## Далі

Наступний крок: [04 — Templates and Bootstrap](04_templates_bootstrap.md) — 3-рівнева Template Inheritance, Crispy Forms, SaaS Dashboard.

Модулі документації:
- [Database and ORM](../03_database_and_orm/README.md)
- [Application Architecture](../06_application_architecture/README.md)
- [Application Architecture — Services & Selectors](../06_application_architecture/django_services_selectors.md)
