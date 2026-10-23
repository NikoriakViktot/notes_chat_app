# Part VI. Application architecture

A fat view is the first sign that an application has outgrown its initial structure. This part teaches you to separate HTTP coordination (the view) from reading data (the selector) and changing state (the service).

**Prerequisites:** Parts II, III, IV.
**Level:** Intermediate.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [Services and Selectors](services_selectors_full.md) | the thin-view + selector + service pattern, layers and their boundaries |
| [Services (in depth)](django_services_full.md) | signatures, transactions, return values, testing |
| [Selectors (in depth)](django_selectors_full.md) | scoped QuerySet, Q-filter, `select_related`, returning materialized data |
| [Serializers](django_serializers_full.md) | DRF-compatible serializers for the API layer |
| [Celery Tasks](django_tasks_full.md) | background tasks, broker, results, retry |

---

## Key concepts

**From fat view to thin view:**

```python
# ❌ FAT VIEW — everything in one place
def note_edit(request, pk):
    note = Note.objects.get(pk=pk)  # ← ORM in the view
    if note.user != request.user:   # ← permission check in the view
        raise Http404
    if request.method == 'POST':
        title = request.POST['title']  # ← no form
        note.title = title             # ← no validation
        note.save()
        return redirect('note_list')
    return render(request, 'note_edit.html', {'note': note})

# ✅ THIN VIEW — coordination between layers
@login_required
def note_edit(request, pk):
    note = selectors.get_note_for_edit(user=request.user, pk=pk)  # ← selector
    if not note:
        raise Http404
    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note, user=request.user)
        if form.is_valid():
            services.update_note(note, **form.cleaned_data)  # ← service
            return redirect('note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note, user=request.user)
    return render(request, 'notes_app/note_form.html', {'form': form})
```

**Layer rules:**

| Layer | File | Can | Cannot |
|-----|------|------|---------|
| View | `views.py` | call form/selector/service, render/redirect | ORM queries, mutations, business logic |
| Selector | `selectors.py` | read the DB, filter, `select_related` | mutate objects, `save()`, `delete()` |
| Service | `services.py` | `create`, `update`, `delete`, transactions | `render()`, `request`, know about HTTP |
| Form | `forms.py` | validate, `clean_*`, return `cleaned_data` | query the DB without a purpose (only for choices) |

**Selector — scoped reading:**

```python
# selectors.py
def get_note_for_edit(user, pk):
    """Only the owner can edit."""
    return Note.objects.filter(user=user, pk=pk)\
                       .select_related('notebook', 'group')\
                       .prefetch_related('tags')\
                       .first()

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """All of the user's notes, with filters."""
    qs = Note.objects.filter(user=user, is_archived=archived)\
                     .select_related('notebook')\
                     .prefetch_related('tags')\
                     .order_by('-is_pinned', '-updated_at')
    if notebook:
        qs = qs.filter(notebook=notebook)
    if tag:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(Q(title__icontains=search) | Q(content__icontains=search))
    return qs
```

**Service — atomic mutation:**

```python
# services.py
def create_note(*, user, title, content='', notebook=None, priority=1, group=None, tag_ids=None):
    note = Note.objects.create(
        user=user, title=title, content=content,
        notebook=notebook, priority=priority, group=group,
    )
    if tag_ids:
        tags = Tag.objects.filter(user=user, pk__in=tag_ids)
        note.tags.set(tags)
    return note

def update_note(note, *, title=None, content=None, priority=None,
                notebook=None, is_pinned=None, group=..., tag_ids=None):
    changed = []
    if title is not None:
        note.title = title; changed.append('title')
    if group is not ...:    # Ellipsis = "not passed"; None = "remove the group"
        note.group = group; changed.append('group')
    if changed:
        note.save(update_fields=changed)
    if tag_ids is not None:
        note.tags.set(Tag.objects.filter(user=note.user, pk__in=tag_ids))
    return note
```

---

## Where this lives in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_app/selectors.py` | 15 functions: `get_user_notes`, `get_note_detail`, `get_group_with_members`, ... |
| `notes_app/services.py` | 30+ functions: notes, notebooks, tags, todo, shopping, groups |
| `notes_app/views.py` | each view only coordinates: form → selector/service → render/redirect |
| `notes_app/tests/test_services.py` | tests without HTTP: `create_note()` → check the return value + persistence |

---

## Pedagogical connections

```text
Part VI: Selectors/Services
  → Part VII: Q-scoped selectors → IDOR protection
  → Part VIII: test_services.py without HTTP (pure unit tests)
  → Part IX: database_sync_to_async(self.save_message)(...)  (a service inside a consumer)
```

**Zero to Hero:** Step 3 — moving from ORM in the view to selector/service. Step 5 — Q-filter in the selector for auth.

---

## Practice

1. Find a view in `notes_app/views.py` that makes an ORM query directly (without a selector) — is there one?
2. Write `selector.get_archived_notes(user)` and `test_get_archived_notes` in `test_services.py`.
3. Refactor: move an ORM query from a view into a new selector.
4. Run `services.toggle_pin_note(note)` in `python manage.py shell` — check the result.

---

## Review questions

- What is a "fat view"? Name 3 signs of a fat view.
- What is the difference between a selector and a service? Which of them can mutate state?
- Why should a selector return materialized data (for example `list()`) if it is called from async code?
- What does `group=...` (Ellipsis) mean in `update_note`? Why is a sentinel needed instead of `None`?
- How do you test a service without an HTTP request?
- Why are `tag_ids` filtered through `Tag.objects.filter(user=note.user, ...)` rather than just using `tag_ids`?

---

**Next →** [Part VII. Authentication and Security](../07_auth_and_security/README.md) — who can do what.
