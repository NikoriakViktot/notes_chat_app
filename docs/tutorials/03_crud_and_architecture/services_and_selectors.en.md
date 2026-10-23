# Services and Selectors

> **Thin Views · Selectors Read · Services Write**
> Each layer has **one responsibility**. Breaking this rule is the main cause of the "fat view" anti-pattern.

---

## Layer architecture

```
HTTP REQUEST
     │
     ▼
┌─────────────────────────────────────────┐
│  views.py                               │
│  ✓ parses the request                   │
│  ✓ calls a selector / service           │
│  ✓ render / redirect                    │
│  ✗ no QuerySets                         │
└────────────┬───────────────┬────────────┘
             │ READ →        │ WRITE →
             ▼               ▼
┌────────────────────┐  ┌──────────────────────────────┐
│  selectors.py      │  │  services.py                 │
│  SELECT only       │  │  CREATE / UPDATE / DELETE    │
│                    │  │                              │
│  get_user_notes()  │  │  create_note()               │
│  get_note_detail() │  │  update_note()               │
│  get_notebooks()   │  │  toggle_todo_item()          │
│  get_reminders()   │  │  mark_reminder_sent()        │
│                    │  │                              │
│  select_related,   │  │  transaction.atomic,         │
│  prefetch_related, │  │  F(), select_for_update      │
│  annotate — here   │  │  — here                      │
└────────┬───────────┘  └───────────┬──────────────────┘
         │ SELECT                   │ INSERT/UPDATE/DELETE
         └──────────┬───────────────┘
                    ▼
             ┌─────────────┐
             │  PostgreSQL │
             │  Database   │
             └─────────────┘
```

> **Why separate them?** The same query is needed in a View, a Celery task, an API endpoint, a test.
> Without `selectors.py`, you copy the QuerySet into 10 places. Change the logic → 10 places to update.
> With `selectors.py` → **one function** that everyone uses.

---

## Responsibility matrix

| Layer | Does | Does NOT do |
|-----|--------|-----------|
| `models.py` | Structure · fields · relationships · constraints · indexes | Business logic, HTTP |
| `selectors.py` | SELECT QuerySets · annotate · prefetch · filters | INSERT / UPDATE / DELETE |
| `services.py` | CREATE / UPDATE / DELETE · transaction · F() · locks | HTTP, render, redirect |
| `views.py` | Parse the request · call a selector/service · render | QuerySets, business logic |
| `forms.py` | Validating HTTP input · `clean_*` | DB queries (except the queryset for choices) |
| `templates/` | HTML markup · context from the View | Any logic |

> **Check yourself:** if you see `Note.objects.filter(...)` in `views.py`, that is a signal to move it to `selectors.py`.
> If you see an access-permission check condition in a template, that is also a violation.

---

## The problem: a "Fat View"

```python
# ❌ ANTI-PATTERN: all the logic in the view
def note_list(request):
    # Does the View know about QuerySet optimization? Not its job!
    notes = Note.objects.filter(
        user=request.user,
        is_archived=False,
    ).select_related('notebook').prefetch_related('tags')

    # Does the View know about business rules? Not its job!
    if request.GET.get('q'):
        notes = notes.filter(
            Q(title__icontains=request.GET['q']) |
            Q(content__icontains=request.GET['q'])
        )

    # If this logic is needed in an API endpoint or a Celery task → do we copy it?!
    return render(request, 'note_list.html', {'notes': notes})
```

---

## READ flow — tracing GET /notes/?q=python

```
01 │ Browser      │ GET /notes/?q=python
02 │ urls.py      │ match → views.note_list
03 │ views.py     │ search = request.GET['q']
04 │ views.py     │ selectors.get_user_notes(user, search='python')
05 │ selectors.py │ QuerySet.filter().select_related('notebook').prefetch_related('tags')
06 │ ORM          │ SQLCompiler → 2 SQL (note + tags prefetch)
07 │ PostgreSQL   │ executes the plan, returns rows
08 │ ORM          │ ModelIterable → list[Note] with a filled _result_cache
09 │ views.py     │ render('note_list.html', {notes, tags, notebooks})
10 │ Browser      │ 200 OK · HTML
```

> **The View stays thin:** 3 lines of code (parse + delegate + render).
> All the complexity lives in `selectors.get_user_notes`: filters, JOINs, the prefetch cache.

---

## WRITE flow — tracing POST /notes/create/

```
01 │ Browser      │ POST /notes/create/ form=...
02 │ views.py     │ form = NoteForm(POST, user=request.user) · is_valid?
03 │ views.py     │ services.create_note(user, title, tag_ids)
04 │ services.py  │ with transaction.atomic():
05 │ services.py  │ Note.objects.create(...) → BEGIN, INSERT note
06 │ services.py  │ Tag.objects.filter(user=user, id__in=...) · ownership check
07 │ services.py  │ note.tags.set(valid) → INSERT × N into the junction
08 │ PostgreSQL   │ COMMIT · on_commit callbacks
09 │ views.py     │ messages.success(...)  ·  return redirect('note_detail', pk)
10 │ Browser      │ 302 → GET /notes/42/  (PRG pattern: F5 is safe)
```

> **PRG (Post / Redirect / Get).** A POST does not render — it redirects.
> F5 repeats the GET, which is safe. Without PRG: F5 = a duplicate record.

> **Ownership through FK traversal.** `Tag.objects.filter(user=user, id__in=...)` —
> do not let a user attach someone else's tags to their own note.

---

## Step 7 — The `hello_app/selectors.py` file

```python
# hello_app/selectors.py
"""
Selectors — the data READ layer.
All SELECT queries live here.
Views, Tasks, API — everything uses selectors.
"""
from django.db.models import Count, Q, Prefetch
from django.utils import timezone

from .models import Note, Notebook, Tag, TodoList, TodoItem, ShoppingList, Reminder


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    The user's note list with filters.
    select_related + prefetch_related — solves the N+1 problem.

    Keyword-only kwargs (after *) — protection against positional arguments:
    get_user_notes(alice, True) → TypeError (unclear that True = archived)
    get_user_notes(alice, archived=True) → OK, explicit
    """
    qs = Note.objects.filter(
        user=user,
        is_archived=archived
    ).select_related(
        'notebook'           # FK → JOIN (1 query instead of N)
    ).prefetch_related(
        'tags'               # M:N → a 2nd query (not N+1)
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
    # Order: pinned first → priority → recently updated


def get_note_detail(user, note_id):
    """
    Note detail — with all its relationships.
    Raises Note.DoesNotExist if not found or not the owner.
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
            to_attr='upcoming_reminders'  # store them in a SEPARATE attribute!
        )
    ).get(id=note_id, user=user)


def get_user_notebooks(user):
    """All notebooks with their note counts."""
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    ).order_by('-is_default', 'title')


def get_user_tags(user):
    """Tags with their note counts."""
    return Tag.objects.filter(user=user).annotate(
        note_count=Count('notes')
    ).order_by('name')


def get_note_for_user(user, pk):
    """
    Returns the note if it belongs to the user, or None.
    Used in a view instead of get_object_or_404 when softer handling is needed.
    """
    return Note.objects.filter(user=user, pk=pk).select_related('notebook').first()


def get_user_todo_lists(user):
    """To-do lists with progress."""
    return TodoList.objects.filter(
        user=user
    ).annotate(
        total_items=Count('items'),
        done_items=Count('items', filter=Q(items__is_done=True))
    ).prefetch_related('items').order_by('is_completed', '-created_at')


def get_pending_reminders():
    """For the Celery worker: reminders that need to be sent."""
    return Reminder.objects.filter(
        is_sent=False,
        remind_at__lte=timezone.now()
    ).select_related('note__user')
```

---

## Step 8 — The `hello_app/services.py` file

```python
# hello_app/services.py
"""
Services — the data WRITE layer.
All the business logic lives here: CREATE, UPDATE, DELETE.
Services may call selectors, but not the other way around.
"""
from django.db import transaction
from django.db.models import F

from .models import Note, Notebook, Tag, TodoItem, Reminder


def create_note(*, user, title, content='', notebook=None, priority=1, tag_ids=None):
    """
    Creates a note with tags atomically.

    transaction.atomic(): either the Note and the tags are saved together, or nothing is.
    Tag protection: filter(user=user) → other users' tags are ignored (Mass Assignment protection).

    Why the asterisk * before the arguments?
    → all arguments are KEYWORD-ONLY (no positional ones after *)
    → call: services.create_note(user=user, title="Test")  ✓
    → call: services.create_note(user, "Test")             ✗ TypeError!
    Why? More readable, fewer mistakes during refactoring.
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
            # Check that the tags belong to this user (security!)
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            # filter(user=user): Protection! The user cannot attach someone else's tags.
            note.tags.set(valid_tags)
        # COMMIT (or ROLLBACK if any operation failed!)

    return note


def update_note(note, *, title=None, content=None, notebook=..., priority=None,
                is_pinned=None, is_archived=None, tag_ids=None):
    """
    Updates only the fields that were passed.
    update_fields → UPDATE only the changed columns (more efficient).

    notebook=... (Ellipsis) = "not passed" (the notebook does not change).
    notebook=None           = "remove the notebook" (SET_NULL).
    notebook=<Notebook>     = "set the notebook".
    Ellipsis distinguishes "not passed" from "passed None".
    """
    changed = []
    if title is not None:
        note.title = title
        changed.append('title')
    if content is not None:
        note.content = content
        changed.append('content')
    if notebook is not ...:              # Ellipsis = sentinel "not passed"
        note.notebook = notebook         # None → SET_NULL; <Notebook> → set it
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
        changed.append('updated_at')  # Always update the timestamp
        note.save(update_fields=changed)
        # SQL: UPDATE hello_app_note SET title=..., updated_at=... WHERE id=...
        # NOT: UPDATE hello_app_note SET ... (all fields)

    if tag_ids is not None:
        valid_tags = Tag.objects.filter(id__in=tag_ids, user=note.user)
        note.tags.set(valid_tags)   # DELETE the old ones + INSERT the new ones

    return note


def archive_note(note):
    """Archive a note (not delete it)."""
    Note.objects.filter(pk=note.pk).update(is_archived=True)


def toggle_pin_note(note):
    """Toggles is_pinned and saves it to the DB."""
    note.is_pinned = not note.is_pinned
    note.save(update_fields=['is_pinned', 'updated_at'])
    return note


def delete_note(note):
    """
    Deletes a note.
    CASCADE automatically deletes the related Reminder objects.
    """
    note.delete()


def toggle_todo_item(item_id, *, user):
    """
    Check/uncheck a list item.
    select_for_update() — prevents a race condition on simultaneous clicks.
    """
    with transaction.atomic():
        item = TodoItem.objects.select_for_update().get(
            id=item_id,
            todo_list__user=user   # access-permission check via FK traversal
        )
        # SQL: SELECT ... FROM todoitem
        #      JOIN todolist ON todoitem.todo_list_id = todolist.id
        #      WHERE todoitem.id=? AND todolist.user_id=?
        #      FOR UPDATE  ← locks the row!
        item.is_done = not item.is_done
        item.save(update_fields=['is_done'])
    return item


def mark_reminder_sent(reminder_id):
    """
    Atomically mark a reminder as sent.
    F() + update() — race condition safe.
    """
    Reminder.objects.filter(pk=reminder_id).update(is_sent=True)


def create_tag(*, user, name, color='#808080'):
    """Create a tag with a uniqueness check."""
    tag, created = Tag.objects.get_or_create(
        user=user,
        name=name.lower().strip(),  # normalization: "Python" → "python"
        defaults={'color': color}   # color is set ONLY on CREATE
    )
    return tag, created


@transaction.atomic
def create_notebook(user, title, is_default=False):
    """
    Business rule: a user has ONLY ONE default notebook.
    Atomically reset the old one and set the new one.
    """
    if is_default:
        Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
        # UPDATE all to default=False before creating the new one
    return Notebook.objects.create(user=user, title=title, is_default=is_default)


def complete_todo_list(todo_list):
    """Bulk-mark all items as completed."""
    with transaction.atomic():
        # Step 1: mark the list
        todo_list.is_completed = True
        todo_list.save(update_fields=['is_completed'])

        # Step 2: bulk-mark all items
        todo_list.items.filter(is_done=False).update(is_done=True)
        # SQL: UPDATE todoitem SET is_done=TRUE
        #      WHERE todo_list_id=? AND is_done=FALSE
        #
        # WRONG:
        # for item in todo_list.items.all():
        #     item.is_done = True
        #     item.save()  # N queries instead of 1!
        #
        # RIGHT: .update() → 1 SQL for all rows!
```

---

## Step 9 — `forms.py` function by function

### `NoteForm.__init__(self, *args, user=None, **kwargs)`

```python
def __init__(self, *args, user=None, **kwargs):
    # Step 1: initialize the parent ModelForm
    super().__init__(*args, **kwargs)
    # After super().__init__:
    #   self.fields = {
    #       'title': CharField(max_length=200),
    #       'notebook': ModelChoiceField(queryset=Notebook.objects.all()),  ← ALL!
    #       'tags': ModelMultipleChoiceField(queryset=Tag.objects.all()),    ← ALL!
    #       ...
    #   }

    # Step 2: filter the queryset by user (SECURITY!)
    if user is not None:
        self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
        # Now the dropdown shows ONLY this user's notebooks!
        self.fields['tags'].queryset = Tag.objects.filter(user=user)
        # Now the checkboxes show ONLY this user's tags!
    else:
        self.fields['notebook'].queryset = Notebook.objects.none()
        self.fields['tags'].queryset = Tag.objects.none()

    # Step 3: a custom label for the empty option
    self.fields['notebook'].empty_label = '── Без записника ──'
    self.fields['notebook'].required = False

# Calls:
# GET: form = NoteForm(user=request.user)           → an empty form
# GET: form = NoteForm(instance=note, user=request.user)  → a form for editing
# POST: form = NoteForm(request.POST, user=request.user)  → validation
```

### `TagForm.clean_name(self)` — custom field cleaning

```python
def clean_name(self):
    # Validation Pipeline:
    # 1. to_python("  Python  ") → str "  Python  "
    # 2. validate("  Python  ") → OK (required, max_length)
    # 3. run_validators → (no custom ones)
    # 4. clean_name(self) ← WE ARE HERE
    #    self.cleaned_data['name'] = "  Python  " (the string that passed validate)

    name = self.cleaned_data['name']
    normalized = name.lower().strip()   # "  Python  " → "python"

    if not normalized:
        raise forms.ValidationError("Назва тегу не може бути порожньою.")

    return normalized  # ← you MUST return it!
    # cleaned_data['name'] = "python" (normalized!)
```

---

## Step 10 — `views.py` function by function

### `note_list(request)` — a GET request with filters

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


@login_required   # ← AnonymousUser → redirect to /accounts/login/?next=...
def note_list(request):
    # Step 1: Read the filters from the URL
    search = request.GET.get('q', '').strip()  # '' if missing
    tag_id = request.GET.get('tag')            # '7' or None

    # Step 2: Convert id → objects (with a permission check!)
    tag = None
    if tag_id:
        try:
            tag = Tag.objects.get(id=int(tag_id), user=request.user)
            #                          ↑                ↑
            #              string→int conversion    only your own tag!
        except (Tag.DoesNotExist, ValueError):
            pass  # invalid id → simply ignore it

    # Step 3: Get the data through a selector
    notes     = selectors.get_user_notes(request.user, search=search or None, tag=tag)
    tags      = selectors.get_user_tags(request.user)
    notebooks = selectors.get_user_notebooks(request.user)

    # Step 4: Render (this is where the QuerySet is executed!)
    return render(request, 'hello_app/note_list.html', {
        'notes':     notes,
        'tags':      tags,
        'notebooks': notebooks,
        'search':    search,
    })
    # During rendering: {% for note in notes %} → the SQL SELECT is executed!
```

### `note_create(request)` — the PRG pattern

```
GET  /notes/new/  → show an empty form
POST /notes/new/  → process the form → redirect
```

```python
@login_required
def note_create(request):
    if request.method == 'POST':
        # 1. Bind the POST data to the form (the form becomes "bound")
        form = NoteForm(request.POST, user=request.user)

        # 2. Validation Pipeline:
        #    to_python → validate → run_validators → clean_<field> → clean
        if form.is_valid():
            # 3. Extract tag_ids from the M:N field
            tags = form.cleaned_data.get('tags')   # QuerySet[Tag] or None
            tag_ids = [t.id for t in tags] if tags else None  # [1, 3] or None

            # 4. Business logic → Service (not here in the View!)
            note = services.create_note(
                user     = request.user,
                title    = form.cleaned_data['title'],  # a typed str (validated!)
                content  = form.cleaned_data.get('content', ''),
                notebook = form.cleaned_data.get('notebook'),
                priority = form.cleaned_data.get('priority', 1),
                tag_ids  = tag_ids,
            )

            # 5. PRG: messages + redirect (not render!)
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('hello_app:note_detail', pk=note.pk)
            # HTTP 302 → GET /notes/42/ → safe, F5 does not duplicate!

    else:  # GET
        form = NoteForm(user=request.user)  # an empty form

    # Render for GET and for a POST with errors:
    return render(request, 'hello_app/note_form.html', {
        'form': form,
        'title': 'Нова нотатка',
        'action': 'Створити',
    })
```

### `note_edit(request, pk)` — editing

```python
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # pk + user=request.user → 404 if it is someone else's note (IDOR protection)

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

### `note_delete(request, pk)` — why POST only

```
GET  /notes/42/delete/  → confirmation page
POST /notes/42/delete/  → deletion → redirect
```

```python
# Why can't GET delete?
# Browsers, bots, antivirus software make GET requests AUTOMATICALLY
# (prefetching links, availability checks, etc.)
# If GET /notes/42/delete/ deleted things → notes would disappear "by themselves"!

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # SQL: SELECT WHERE id=42 AND user_id=request.user.id
    # 404 if not found → Alice cannot delete Bob's notes!

    if request.method == 'POST':  # the form in the confirmation template
        title = note.title  # save it BEFORE deleting
        services.delete_note(note)
        # CASCADE: deleting a note → automatically deletes its Reminder objects
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    # GET → show the page with a warning and a confirmation form
    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

---

## Navigation

- Previous: [Migrations](migrations.md)
- Next: [QuerySet in depth](queryset_deep.md)
