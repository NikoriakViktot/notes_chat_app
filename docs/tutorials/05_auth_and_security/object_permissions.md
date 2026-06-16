# Object Permissions — Захист від IDOR

> **Найпоширеніша вразливість у вебзастосунках (OWASP A01):**
> Broken Access Control — юзер отримує доступ до чужих даних.

---

## Що таке IDOR (Insecure Direct Object Reference)

```
Аліса зареєстрована. Вона бачить URL своєї нотатки: /notes/42/edit/
Вона думає: "А що буде якщо змінити 42 на 43?"
Аліса переходить на: /notes/43/edit/
Якщо view не перевіряє власника → Аліса редагує нотатку БОБА!

Це атака IDOR — Insecure Direct Object Reference.
OWASP A01 (Broken Access Control) — найчастіша причина витоків даних.
```

---

## AuthN vs AuthZ різниця (з прикладом SQL)

```python
# ─── ПРОБЛЕМА: @login_required — тільки AuthN, не AuthZ! ────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # ← IDOR вразливість!
    # Аліса залогінена → @login_required пропускає ✓
    # Але note(pk=43) належить Бобу → Аліса редагує чужі дані! ✗

# SQL генерований:
# SELECT * FROM note WHERE pk = 43
# → повертає нотатку Боба! Жодної перевірки user_id!


# ─── РІШЕННЯ: додай user= до get_object_or_404 ──────────────────────────────
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)   # ← AuthZ ✓
    # pk=43 + user=Alice
    # SQL: SELECT * FROM note WHERE pk=43 AND user_id=42
    # Боб має note(pk=43, user_id=99) → user_id=42 не збігається → 404
```

**Золоте правило:**
```
@login_required               = "ти залогінений?"        (AuthN)
get_object_or_404(            = "цей об'єкт — твій?"     (AuthZ)
    Note, pk=pk,
    user=request.user
)
```

**Чому 404, а не 403?**
```
403 Forbidden → повідомляємо: "Цей ресурс існує, але ти не маєш доступу"
                Хакер знає що id=43 існує → може спробувати інші атаки

404 Not Found  → повідомляємо: "Такого ресурсу не існує"
                Хакер не знає існує чи ні → менше інформації для атаки

Принцип: не розкривати факт існування чужих об'єктів.
```

---

## Патерн для власних об'єктів

```python
# Застосовується до: note_edit, note_delete, notebook_edit, notebook_delete,
# todolist_edit, shopping_edit, тощо

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    #      ↑ Якщо note.user != request.user → 404 (не 403!)
    if request.method == 'POST':
        services.delete_note(note)
        messages.warning(request, 'Нотатку видалено.')
        return redirect('notes_app:note_list')
    return render(request, 'notes_app/note_confirm_delete.html', {'note': note})


@login_required
def notebook_edit(request, pk):
    # Те саме — Notebook з user=request.user
    notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
    # ...
```

---

## Патерн для спільних об'єктів (власник АБО член групи)

```python
# Нотатки можуть бути груповими → перевірка складніша:
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
    # Аліса бачить нотатку якщо:
    #   note.user == Alice (особиста нотатка)
    #   АБО note.group in Alice.groups.all() (групова нотатка)
    #
    # SQL:
    # SELECT * FROM note
    # WHERE pk = 43
    #   AND (user_id = 42 OR group_id IN (1, 3))
    # → Якщо ні те, ні інше → 404
    return render(request, 'notes_app/note_detail.html', {'note': note})
```

---

## Повна реалізація note_edit з усіма перевірками

```python
# notes_app/views.py — повна реалізація note_edit:

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
    Редагування нотатки — два рівні перевірки:
    1. @login_required          → AuthN: залогінений?
    2. Q(user) | Q(group)       → read access: власна або групова нотатка?
    3. note.user == request.user → AuthZ write: редагувати може лише власник

    Чому Q-filter, а не get_object_or_404(..., user=request.user)?
      get_object_or_404(Note, pk=pk, user=request.user) блокував би
      членів групи від перегляду нотатки через URL /notes/<pk>/edit/.
      Реальна логіка: член групи може ЧИТАТИ нотатку (бачить її),
      але РЕДАГУВАТИ — лише власник.
    """
    user_groups = request.user.groups.all()
    note = get_object_or_404(
        Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
        pk=pk,
    )
    # ↑ SQL: SELECT * FROM note WHERE pk=<pk> AND (user_id=<uid> OR group_id IN (...))
    # → 404 якщо ані власник, ані член групи

    if note.user != request.user:
        # Член групи може ПЕРЕГЛЯДАТИ нотатку, але не редагувати чужу
        messages.error(request, 'Ти не можеш редагувати нотатку іншого користувача.')
        return redirect('notes_app:note_detail', pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            # tags — M2M поле; NoteForm.cleaned_data['tags'] → QuerySet об'єктів Tag
            # tag_ids потрібні сервісу окремо (не передаємо dict напряму!)
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
            # Не можна викликати як update_note(note, form.cleaned_data) → TypeError
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
    # Аналогічно: Q-filter для доступу + owner check перед видаленням
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

**До vs Після:**

```python
# ✗ ДО (IDOR вразливість):
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE pk=43
# Повертає нотатку Боба якщо pk=43 — жодної перевірки власника!

# ✓ ПІСЛЯ для особистих об'єктів (Notebook, TodoList, тощо):
notebook = get_object_or_404(Notebook, pk=pk, user=request.user)
# SQL: SELECT * FROM notebook WHERE pk=43 AND user_id=42
# pk=43 + user_id=42 → не знайдено → 404

# ✓ ПІСЛЯ для спільних об'єктів (Note — може бути груповою):
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
# SQL: SELECT * FROM note WHERE pk=43 AND (user_id=42 OR group_id IN (1,3))
# Власник АБО член групи — обидва отримують доступ для читання
# Для запису: ще перевіряємо note.user == request.user окремо
```

---

## Таблиця захищених views у notes_app

| View | Захист | Як реалізовано |
|------|--------|----------------|
| `note_list` | `@login_required` | Selector `Q(user=user) \| Q(group__in=...)` |
| `note_edit` | `@login_required` + owner | Q-filter для доступу, потім `note.user != request.user` для редагування |
| `note_delete` | `@login_required` + owner | Те саме |
| `notebook_edit` | `@login_required` + owner | `get_object_or_404(Notebook, pk=pk, user=request.user)` |
| `notebook_delete` | `@login_required` + owner | Те саме |
| `group_detail` | `@login_required` + membership | `get_group_with_members(pk, user)` → None якщо не член |
| `group_delete` | `@login_required` + membership | `group.user_set.filter(pk=user.pk).exists()` |

---

## Далі

Наступна глава: [Group Sharing](group_sharing.md) — Django Group, FK SET_NULL, Q-filter, Services, Views, Templates.
