# Services і Selectors

> **Thin Views · Selectors Read · Services Write**
> Кожен шар має **одну відповідальність**. Порушення цього правила — головна причина "fat view" антипатерну.

---

## Архітектура шарів

```
HTTP REQUEST
     │
     ▼
┌─────────────────────────────────────────┐
│  views.py                               │
│  ✓ парсить request                      │
│  ✓ кличе selector / service             │
│  ✓ render / redirect                    │
│  ✗ жодних QuerySet                      │
└────────────┬───────────────┬────────────┘
             │ READ →        │ WRITE →
             ▼               ▼
┌────────────────────┐  ┌──────────────────────────────┐
│  selectors.py      │  │  services.py                 │
│  SELECT тільки     │  │  CREATE / UPDATE / DELETE    │
│                    │  │                              │
│  get_user_notes()  │  │  create_note()               │
│  get_note_detail() │  │  update_note()               │
│  get_notebooks()   │  │  toggle_todo_item()          │
│  get_reminders()   │  │  mark_reminder_sent()        │
│                    │  │                              │
│  select_related,   │  │  transaction.atomic,         │
│  prefetch_related, │  │  F(), select_for_update      │
│  annotate — тут    │  │  — тут                       │
└────────┬───────────┘  └───────────┬──────────────────┘
         │ SELECT                   │ INSERT/UPDATE/DELETE
         └──────────┬───────────────┘
                    ▼
             ┌─────────────┐
             │  PostgreSQL │
             │  Database   │
             └─────────────┘
```

> **Чому розділяти?** Один і той самий запит потрібен у View, Celery task, API endpoint, тесті.
> Без `selectors.py` — копіюєш QuerySet у 10 місцях. Зміниш логіку → 10 місць оновлювати.
> З `selectors.py` → **одна функція**, всі використовують.

---

## Матриця відповідальності

| Шар | Робить | НЕ робить |
|-----|--------|-----------|
| `models.py` | Структура · поля · зв'язки · constraints · indexes | Бізнес-логіка, HTTP |
| `selectors.py` | SELECT QuerySets · annotate · prefetch · фільтри | INSERT / UPDATE / DELETE |
| `services.py` | CREATE / UPDATE / DELETE · transaction · F() · locks | HTTP, render, redirect |
| `views.py` | Парсити request · викликати selector/service · render | QuerySet, бізнес-логіка |
| `forms.py` | Валідація вводу з HTTP · `clean_*` | БД запити (крім queryset для choices) |
| `templates/` | HTML розмітка · context з View | Будь-яка логіка |

> **Перевір себе:** якщо в `views.py` бачиш `Note.objects.filter(...)` — це сигнал перенести у `selectors.py`.
> Якщо в шаблоні бачиш умову перевірки прав доступу — це теж порушення.

---

## Проблема: "Товстий View"

```python
# ❌ АНТИПАТЕРН: вся логіка у view
def note_list(request):
    # View знає про QuerySet оптимізацію? Не його справа!
    notes = Note.objects.filter(
        user=request.user,
        is_archived=False,
    ).select_related('notebook').prefetch_related('tags')

    # View знає про бізнес-правила? Не його справа!
    if request.GET.get('q'):
        notes = notes.filter(
            Q(title__icontains=request.GET['q']) |
            Q(content__icontains=request.GET['q'])
        )

    # Якщо цю логіку потрібна в API endpoint або Celery task → копіюємо?!
    return render(request, 'note_list.html', {'notes': notes})
```

---

## READ flow — трасування GET /notes/?q=python

```
01 │ Browser      │ GET /notes/?q=python
02 │ urls.py      │ match → views.note_list
03 │ views.py     │ search = request.GET['q']
04 │ views.py     │ selectors.get_user_notes(user, search='python')
05 │ selectors.py │ QuerySet.filter().select_related('notebook').prefetch_related('tags')
06 │ ORM          │ SQLCompiler → 2 SQL (note + tags prefetch)
07 │ PostgreSQL   │ виконує план, повертає rows
08 │ ORM          │ ModelIterable → list[Note] з заповненим _result_cache
09 │ views.py     │ render('note_list.html', {notes, tags, notebooks})
10 │ Browser      │ 200 OK · HTML
```

> **View залишається тонкою:** 3 рядки коду (parse + delegate + render).
> Уся складність — у `selectors.get_user_notes`: фільтри, JOIN-и, кеш prefetch.

---

## WRITE flow — трасування POST /notes/create/

```
01 │ Browser      │ POST /notes/create/ form=...
02 │ views.py     │ form = NoteForm(POST, user=request.user) · is_valid?
03 │ views.py     │ services.create_note(user, title, tag_ids)
04 │ services.py  │ with transaction.atomic():
05 │ services.py  │ Note.objects.create(...) → BEGIN, INSERT note
06 │ services.py  │ Tag.objects.filter(user=user, id__in=...) · перевірка ownership
07 │ services.py  │ note.tags.set(valid) → INSERT × N у junction
08 │ PostgreSQL   │ COMMIT · on_commit callbacks
09 │ views.py     │ messages.success(...)  ·  return redirect('note_detail', pk)
10 │ Browser      │ 302 → GET /notes/42/  (PRG pattern: F5 безпечний)
```

> **PRG (Post / Redirect / Get).** POST не рендерить — він робить redirect.
> F5 повторює GET — безпечно. Без PRG: F5 = дубль запису.

> **Ownership через FK traversal.** `Tag.objects.filter(user=user, id__in=...)` —
> не дай юзеру прикріпити чужі теги до своєї нотатки.

---

## Крок 7 — Файл `hello_app/selectors.py`

```python
# hello_app/selectors.py
"""
Selectors — шар ЧИТАННЯ даних.
Тут живуть всі SELECT запити.
View, Tasks, API — всі використовують selectors.
"""
from django.db.models import Count, Q, Prefetch
from django.utils import timezone

from .models import Note, Notebook, Tag, TodoList, TodoItem, ShoppingList, Reminder


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Список нотаток користувача з фільтрами.
    select_related + prefetch_related — вирішує N+1 проблему.

    Kwargs keyword-only (після *) — захист від позиційних аргументів:
    get_user_notes(alice, True) → TypeError (не зрозуміло що True = archived)
    get_user_notes(alice, archived=True) → OK, явно
    """
    qs = Note.objects.filter(
        user=user,
        is_archived=archived
    ).select_related(
        'notebook'           # FK → JOIN (1 запит замість N)
    ).prefetch_related(
        'tags'               # M:N → 2-й запит (не N+1)
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
    # Порядок: закріплені першими → пріоритет → нещодавно оновлені


def get_note_detail(user, note_id):
    """
    Деталь нотатки — з усіма зв'язками.
    Raises Note.DoesNotExist якщо не знайдено або не власник.
    """
    return Note.objects.select_related(
        'notebook', 'user'
    ).prefetch_related(
        'tags',
        Prefetch(
            'reminders',
            queryset=Reminder.objects.filter(
                remind_at__gte=timezone.now()
            ).order_by('remind_at'),
            to_attr='upcoming_reminders'  # зберігаємо у ОКРЕМИЙ атрибут!
        )
    ).get(id=note_id, user=user)


def get_user_notebooks(user):
    """Всі записники з кількістю нотаток."""
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    ).order_by('-is_default', 'title')


def get_user_tags(user):
    """Теги з кількістю нотаток."""
    return Tag.objects.filter(user=user).annotate(
        note_count=Count('notes')
    ).order_by('name')


def get_note_for_user(user, pk):
    """
    Повертає нотатку якщо belongs to user, або None.
    Використовується у view замість get_object_or_404 коли потрібна м'якша обробка.
    """
    return Note.objects.filter(user=user, pk=pk).select_related('notebook').first()


def get_user_todo_lists(user):
    """Списки справ з прогресом."""
    return TodoList.objects.filter(
        user=user
    ).annotate(
        total_items=Count('items'),
        done_items=Count('items', filter=Q(items__is_done=True))
    ).prefetch_related('items').order_by('is_completed', '-created_at')


def get_pending_reminders():
    """Для Celery worker: нагадування які треба відправити."""
    return Reminder.objects.filter(
        is_sent=False,
        remind_at__lte=timezone.now()
    ).select_related('note__user')
```

---

## Крок 8 — Файл `hello_app/services.py`

```python
# hello_app/services.py
"""
Services — шар ЗАПИСУ даних.
Тут живе вся бізнес-логіка: CREATE, UPDATE, DELETE.
Services можуть викликати selectors але не навпаки.
"""
from django.db import transaction
from django.db.models import F

from .models import Note, Notebook, Tag, TodoItem, Reminder


def create_note(*, user, title, content='', notebook=None, priority=1, tag_ids=None):
    """
    Створює нотатку з тегами атомарно.

    transaction.atomic(): або Note і теги зберігаються разом, або нічого.
    Захист тегів: filter(user=user) → чужі теги ігноруються (Mass Assignment захист).

    Чому зірочка * перед аргументами?
    → всі аргументи KEYWORD-ONLY (немає позиційних після *)
    → виклик: services.create_note(user=user, title="Test")  ✓
    → виклик: services.create_note(user, "Test")             ✗ TypeError!
    Навіщо? Читабельніше, менше помилок при рефакторингу.
    """
    with transaction.atomic():  # SQL: BEGIN;
        note = Note.objects.create(
            user=user,
            title=title,
            content=content,
            notebook=notebook,
            priority=priority,
        )
        if tag_ids:
            # Перевіряємо що теги належать цьому user (безпека!)
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            # filter(user=user): Захист! Юзер не може прикріпити чужі теги.
            note.tags.set(valid_tags)
        # COMMIT (або ROLLBACK якщо будь-яка операція впала!)

    return note


def update_note(note, *, title=None, content=None, notebook=..., priority=None,
                is_pinned=None, is_archived=None, tag_ids=None):
    """
    Оновлює тільки передані поля.
    update_fields → UPDATE тільки змінених стовпців (ефективніше).

    notebook=... (Ellipsis) = "не передано" (notebook не змінюється).
    notebook=None           = "прибрати записник" (SET_NULL).
    notebook=<Notebook>     = "встановити записник".
    Ellipsis відрізняє "не передано" від "передано None".
    """
    changed = []
    if title is not None:
        note.title = title
        changed.append('title')
    if content is not None:
        note.content = content
        changed.append('content')
    if notebook is not ...:              # Ellipsis = sentinel "не передано"
        note.notebook = notebook         # None → SET_NULL; <Notebook> → встановити
        changed.append('notebook')
    if priority is not None:
        note.priority = priority
        changed.append('priority')
    if is_pinned is not None:
        note.is_pinned = is_pinned
        changed.append('is_pinned')
    if is_archived is not None:
        note.is_archived = is_archived
        changed.append('is_archived')

    if changed:
        changed.append('updated_at')  # Завжди оновлювати timestamp
        note.save(update_fields=changed)
        # SQL: UPDATE hello_app_note SET title=..., updated_at=... WHERE id=...
        # НЕ: UPDATE hello_app_note SET ... (всі поля)

    if tag_ids is not None:
        valid_tags = Tag.objects.filter(id__in=tag_ids, user=note.user)
        note.tags.set(valid_tags)   # DELETE старих + INSERT нових

    return note


def archive_note(note):
    """Архівування нотатки (не видалення)."""
    Note.objects.filter(pk=note.pk).update(is_archived=True)


def toggle_pin_note(note):
    """Перемикає is_pinned і зберігає у БД."""
    note.is_pinned = not note.is_pinned
    note.save(update_fields=['is_pinned', 'updated_at'])
    return note


def delete_note(note):
    """
    Видаляє нотатку.
    CASCADE автоматично видалить пов'язані Reminder.
    """
    note.delete()


def toggle_todo_item(item_id, *, user):
    """
    Відмітити/зняти відмітку пункту списку.
    select_for_update() — запобігає race condition при одночасних кліках.
    """
    with transaction.atomic():
        item = TodoItem.objects.select_for_update().get(
            id=item_id,
            todo_list__user=user   # перевірка права доступу через FK traversal
        )
        # SQL: SELECT ... FROM todoitem
        #      JOIN todolist ON todoitem.todo_list_id = todolist.id
        #      WHERE todoitem.id=? AND todolist.user_id=?
        #      FOR UPDATE  ← блокує рядок!
        item.is_done = not item.is_done
        item.save(update_fields=['is_done'])
    return item


def mark_reminder_sent(reminder_id):
    """
    Атомарно позначаємо нагадування як відправлене.
    F() + update() — race condition safe.
    """
    Reminder.objects.filter(pk=reminder_id).update(is_sent=True)


def create_tag(*, user, name, color='#808080'):
    """Створення тегу з перевіркою унікальності."""
    tag, created = Tag.objects.get_or_create(
        user=user,
        name=name.lower().strip(),  # нормалізація: "Python" → "python"
        defaults={'color': color}   # color встановлюється ТІЛЬКИ при CREATE
    )
    return tag, created


@transaction.atomic
def create_notebook(user, title, is_default=False):
    """
    Бізнес-правило: у юзера ТІЛЬКИ ОДИН default записник.
    Атомарно скидаємо старий і встановлюємо новий.
    """
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        # UPDATE всіх default=False перед створенням нового
    return Notebook.objects.create(user=user, title=title, is_default=is_default)


def complete_todo_list(todo_list):
    """Масове позначення всіх пунктів як виконаних."""
    with transaction.atomic():
        # Крок 1: позначаємо список
        todo_list.is_completed = True
        todo_list.save(update_fields=['is_completed'])

        # Крок 2: масово позначаємо всі пункти
        todo_list.items.filter(is_done=False).update(is_done=True)
        # SQL: UPDATE todoitem SET is_done=TRUE
        #      WHERE todo_list_id=? AND is_done=FALSE
        #
        # НЕПРАВИЛЬНО:
        # for item in todo_list.items.all():
        #     item.is_done = True
        #     item.save()  # N запитів замість 1!
        #
        # ПРАВИЛЬНО: .update() → 1 SQL для всіх рядків!
```

---

## Крок 8 — `forms.py` функція за функцією

### `NoteForm.__init__(self, *args, user=None, **kwargs)`

```python
def __init__(self, *args, user=None, **kwargs):
    # Крок 1: ініціалізуємо батьківський ModelForm
    super().__init__(*args, **kwargs)
    # Після super().__init__:
    #   self.fields = {
    #       'title': CharField(max_length=200),
    #       'notebook': ModelChoiceField(queryset=Notebook.objects.all()),  ← ALL!
    #       'tags': ModelMultipleChoiceField(queryset=Tag.objects.all()),    ← ALL!
    #       ...
    #   }

    # Крок 2: фільтруємо queryset по user (БЕЗПЕКА!)
    if user is not None:
        self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
        # Тепер dropdown показує ТІЛЬКИ записники цього юзера!
        self.fields['tags'].queryset = Tag.objects.filter(user=user)
        # Тепер чекбокси показують ТІЛЬКИ теги цього юзера!
    else:
        self.fields['notebook'].queryset = Notebook.objects.none()
        self.fields['tags'].queryset = Tag.objects.none()

    # Крок 3: кастомний label для порожнього варіанту
    self.fields['notebook'].empty_label = '── Без записника ──'
    self.fields['notebook'].required = False

# Виклики:
# GET: form = NoteForm(user=request.user)           → порожня форма
# GET: form = NoteForm(instance=note, user=request.user)  → форма для редагування
# POST: form = NoteForm(request.POST, user=request.user)  → валідація
```

### `TagForm.clean_name(self)` — кастомна очистка поля

```python
def clean_name(self):
    # Validation Pipeline:
    # 1. to_python("  Python  ") → str "  Python  "
    # 2. validate("  Python  ") → OK (required, max_length)
    # 3. run_validators → (жодних кастомних)
    # 4. clean_name(self) ← МИ ТУТ
    #    self.cleaned_data['name'] = "  Python  " (рядок що пройшов validate)

    name = self.cleaned_data['name']
    normalized = name.lower().strip()   # "  Python  " → "python"

    if not normalized:
        raise forms.ValidationError("Назва тегу не може бути порожньою.")

    return normalized  # ← ОБОВ'ЯЗКОВО повертати!
    # cleaned_data['name'] = "python" (нормалізовано!)
```

---

## Крок 8 — `views.py` функція за функцією

### `note_list(request)` — GET запит з фільтрами

```
URL: GET /notes/?q=python&notebook=3&tag=7
```

```python
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render

from .forms import NoteForm
from .models import Note
from . import selectors, services


@login_required   # ← AnonymousUser → redirect до /accounts/login/?next=...
def note_list(request):
    # Крок 1: Читаємо фільтри з URL
    search = request.GET.get('q', '').strip()  # '' якщо відсутній
    tag_id = request.GET.get('tag')            # '7' або None

    # Крок 2: Конвертуємо id → об'єкти (з перевіркою прав!)
    tag = None
    if tag_id:
        try:
            tag = Tag.objects.get(id=int(tag_id), user=request.user)
            #                          ↑                ↑
            #              конвертація рядка→int    тільки свій тег!
        except (Tag.DoesNotExist, ValueError):
            pass  # некоректний id → просто ігноруємо

    # Крок 3: Отримуємо дані через selector
    notes     = selectors.get_user_notes(request.user, search=search or None, tag=tag)
    tags      = selectors.get_user_tags(request.user)
    notebooks = selectors.get_user_notebooks(request.user)

    # Крок 4: Render (тут QuerySet виконається!)
    return render(request, 'hello_app/note_list.html', {
        'notes':     notes,
        'tags':      tags,
        'notebooks': notebooks,
        'search':    search,
    })
    # Під час рендеру: {% for note in notes %} → SQL SELECT виконується!
```

### `note_create(request)` — PRG патерн

```
GET  /notes/new/  → показати порожню форму
POST /notes/new/  → обробити форму → redirect
```

```python
@login_required
def note_create(request):
    if request.method == 'POST':
        # 1. Прив'язуємо POST дані до форми (форма стає "bound")
        form = NoteForm(request.POST, user=request.user)

        # 2. Validation Pipeline:
        #    to_python → validate → run_validators → clean_<field> → clean
        if form.is_valid():
            # 3. Витягуємо tag_ids з M:N поля
            tags = form.cleaned_data.get('tags')   # QuerySet[Tag] або None
            tag_ids = [t.id for t in tags] if tags else None  # [1, 3] або None

            # 4. Бізнес-логіка → Service (не тут у View!)
            note = services.create_note(
                user     = request.user,
                title    = form.cleaned_data['title'],  # типізований str (validated!)
                content  = form.cleaned_data.get('content', ''),
                notebook = form.cleaned_data.get('notebook'),
                priority = form.cleaned_data.get('priority', 1),
                tag_ids  = tag_ids,
            )

            # 5. PRG: messages + redirect (не render!)
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('hello_app:note_detail', pk=note.pk)
            # HTTP 302 → GET /notes/42/ → безпечно, F5 не дублює!

    else:  # GET
        form = NoteForm(user=request.user)  # порожня форма

    # Рендер для GET і для POST з помилками:
    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'title': 'Нова нотатка',
        'action': 'Створити',
    })
```

### `note_edit(request, pk)` — редагування

```python
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # pk + user=request.user → 404 якщо чужа нотатка (IDOR захист)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            services.update_note(
                note,
                title    = form.cleaned_data['title'],
                content  = form.cleaned_data.get('content', ''),
                notebook = form.cleaned_data.get('notebook'),
                priority = form.cleaned_data.get('priority'),
                tag_ids  = [t.id for t in form.cleaned_data.get('tags', [])],
            )
            messages.success(request, 'Нотатку оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note, user=request.user)

    return render(request, 'hello_app/note_form.html', {
        'form': form, 'note': note, 'title': f'Редагувати: {note.title}'
    })
```

### `note_delete(request, pk)` — чому тільки POST

```
GET  /notes/42/delete/  → сторінка підтвердження
POST /notes/42/delete/  → видалення → redirect
```

```python
# Чому GET не може видаляти?
# Браузер, боти, антивіруси АВТОМАТИЧНО роблять GET запити
# (prefetch links, перевірка доступності тощо)
# GET /notes/42/delete/ якби видаляв → нотатки зникали б "самі"!

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # SQL: SELECT WHERE id=42 AND user_id=request.user.id
    # 404 якщо не знайдено → Alice не може видалити нотатки Bob'а!

    if request.method == 'POST':  # форма в шаблоні підтвердження
        title = note.title  # зберігаємо ПЕРЕД видаленням
        services.delete_note(note)
        # CASCADE: видалення note → автоматично видаляє Reminder
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    # GET → показуємо сторінку з попередженням і формою підтвердження
    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

---

## Навігація

- Попередня: [Міграції](migrations.md)
- Наступна: [QuerySet глибоко](queryset_deep.md)
