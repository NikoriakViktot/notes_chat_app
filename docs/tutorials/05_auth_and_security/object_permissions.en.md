# Object Permissions — Protecting Against IDOR

> **The most common vulnerability in web applications (OWASP A01):**
> Broken Access Control — a user gains access to someone else's data.

---

## What IDOR (Insecure Direct Object Reference) is

```
Alice is registered. She sees the URL of her note: /notes/42/edit/
She thinks: "What happens if I change 42 to 43?"
Alice navigates to: /notes/43/edit/
If the view does not check the owner → Alice edits BOB's note!

This is an IDOR attack — Insecure Direct Object Reference.
OWASP A01 (Broken Access Control) — the most frequent cause of data leaks.
```

---

## The AuthN vs AuthZ difference (with an SQL example)

```python
# ─── PROBLEM: @login_required is only AuthN, not AuthZ! ─────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR vulnerability!
    # Alice is logged in → @login_required lets her through ✓
    # But note(pk=43) belongs to Bob → Alice edits someone else's data! ✗

# Generated SQL:
# SELECT * FROM note WHERE pk = 43
# → returns Bob's note! No user_id check at all!


# ─── SOLUTION: add user= to get_object_or_404 ───────────────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)   # ← AuthZ ✓
    # pk=43 + user=Alice
    # SQL: SELECT * FROM note WHERE pk=43 AND user_id=42
    # Bob has note(pk=43, user_id=99) → user_id=42 does not match → 404
```

**The golden rule:**
```
@login_required               = "are you logged in?"        (AuthN)
get_object_or_404(            = "is this object yours?"     (AuthZ)
    Note, pk=pk,
    user=request.user
)
```

**Why 404 and not 403?**
```
403 Forbidden → we say: "This resource exists, but you have no access"
                The attacker knows id=43 exists → may try other attacks

404 Not Found  → we say: "No such resource exists"
                The attacker doesn't know whether it exists → less information for an attack

Principle: do not reveal that other people's objects exist.
```

---

## Pattern for owned objects

```python
# Applies to: note_edit, note_delete, notebook_edit, notebook_delete,
# todolist_edit, shopping_edit, etc.

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    #      ↑ If note.user != request.user → 404 (not 403!)
    if request.method == 'POST':
        services.delete_note(note)
        messages.warning(request, 'Нотатку видалено.')
        return redirect('notes_app:note_list')
    return render(request, 'notes_app/note_confirm_delete.html', {'note': note})


@login_required
def notebook_edit(request, pk):
    # Same thing — Notebook with user=request.user
    notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
    # ...
```

---

## Pattern for shared objects (owner OR group member)

```python
# Notes can belong to a group → the check is more complex:
from django.db.models import Q

@login_required
def note_detail(request, pk):
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(
            Q(user=request.user) | Q(group__in=user_groups)
        ),
        pk=pk
    )
    # Alice sees the note if:
    #   note.user == Alice (personal note)
    #   OR note.group in Alice.groups.all() (group note)
    #
    # SQL:
    # SELECT * FROM note
    # WHERE pk = 43
    #   AND (user_id = 42 OR group_id IN (1, 3))
    # → If neither → 404
    return render(request, 'notes_app/note_detail.html', {'note': note})
```

---

## Full note_edit implementation with all checks

```python
# notes_app/views.py — full note_edit implementation:

from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render
from django.contrib import messages
from django.db.models import Q
from .models import Note
from .forms import NoteForm
from . import services, selectors


@login_required
def note_edit(request, pk):
    """
    Editing a note — two levels of checks:
    1. @login_required          → AuthN: logged in?
    2. Q(user) | Q(group)       → read access: own note or group note?
    3. note.user == request.user → AuthZ write: only the owner can edit

    Why a Q-filter and not get_object_or_404(..., user=request.user)?
      get_object_or_404(Note, pk=pk, user=request.user) would block
      group members from viewing the note via the URL /notes/<pk>/edit/.
      The real logic: a group member can READ the note (sees it),
      but only the owner can EDIT it.
    """
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    # ↑ SQL: SELECT * FROM note WHERE pk=<pk> AND (user_id=<uid> OR group_id IN (...))
    # → 404 if neither the owner nor a group member

    if note.user != request.user:
        # A group member can VIEW the note but cannot edit someone else's
        messages.error(request, 'Ти не можеш редагувати нотатку іншого користувача.')
        return redirect('notes_app:note_detail', pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            # tags — an M2M field; NoteForm.cleaned_data['tags'] → QuerySet of Tag objects
            # the service needs tag_ids separately (we don't pass the dict directly!)
            tags = form.cleaned_data.get('tags')
            tag_ids = [t.id for t in tags] if tags else []
            services.update_note(
                note,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', note.priority),
                notebook=form.cleaned_data.get('notebook'),
                is_pinned=form.cleaned_data.get('is_pinned', note.is_pinned),
                group=form.cleaned_data.get('group'),
                tag_ids=tag_ids,
            )
            # update_note(note, *, title, content, ...) — keyword-only args
            # You can't call it as update_note(note, form.cleaned_data) → TypeError
            messages.success(request, f'✅ Нотатку "{note.title}" оновлено!')
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note, user=request.user)

    return render(request, 'notes_app/note_form.html', {
        'form': form,
        'title': f'Редагувати: {note.title}',
        'note': note,
        'action': 'Зберегти зміни',
    })


@login_required
def note_delete(request, pk):
    # Similarly: Q-filter for access + owner check before deleting
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    if note.user != request.user:
        messages.error(request, 'Ти не можеш видалити нотатку іншого користувача.')
        return redirect('notes_app:note_list')
    if request.method == 'POST':
        title = note.title
        services.delete_note(note)
        messages.warning(request, f'🗑️ Нотатку "{title}" видалено.')
        return redirect('notes_app:note_list')
    return render(request, 'notes_app/note_confirm_delete.html', {'note': note})
```

**Before vs After:**

```python
# ✗ BEFORE (IDOR vulnerability):
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE pk=43
# Returns Bob's note if pk=43 — no owner check at all!

# ✓ AFTER for owned objects (Notebook, TodoList, etc.):
notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
# SQL: SELECT * FROM notebook WHERE pk=43 AND user_id=42
# pk=43 + user_id=42 → not found → 404

# ✓ AFTER for shared objects (Note — can belong to a group):
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
# SQL: SELECT * FROM note WHERE pk=43 AND (user_id=42 OR group_id IN (1,3))
# Owner OR group member — both get read access
# For writes: we additionally check note.user == request.user
```

---

## Table of protected views in notes_app

| View | Protection | How it is implemented |
|------|--------|----------------|
| `note_list` | `@login_required` | Selector `Q(user=user) \| Q(group__in=...)` |
| `note_edit` | `@login_required` + owner | Q-filter for access, then `note.user != request.user` for editing |
| `note_delete` | `@login_required` + owner | Same |
| `notebook_edit` | `@login_required` + owner | `get_object_or_404(Notebook, pk=pk, user=request.user)` |
| `notebook_delete` | `@login_required` + owner | Same |
| `group_detail` | `@login_required` + membership | `get_group_with_members(pk, user)` → None if not a member |
| `group_delete` | `@login_required` + membership | `group.user_set.filter(pk=user.pk).exists()` |

---

## Next

Next chapter: [Group Sharing](group_sharing.md) — Django Group, FK SET_NULL, Q-filter, Services, Views, Templates.
