# Checkpoint: CRUD and architecture

> You have gone through the full cycle from domain design to a finished application with PostgreSQL and CBVs.
> Time to make sure everything is clear.

---

## What you can do after this step

### Design

- [ ] I can describe a domain in words before writing code
- [ ] I know the 7 steps of the methodology: Domain → Entities → Attributes → Relationships → Normalization → on_delete → Django Model
- [ ] I understand the difference between `OneToOneField`, `ForeignKey`, `ManyToManyField`
- [ ] I know where the FK lives (on the "Many" side)
- [ ] I deliberately choose `on_delete` for every FK (not just CASCADE)
- [ ] I can draw an ER diagram in Mermaid

### Models and migrations

- [ ] I can write models with `related_name`, `__str__`, `Meta.ordering`
- [ ] I understand `null=True` vs `blank=True` (DB vs form)
- [ ] I know the migration lifecycle: `makemigrations` → `sqlmigrate` → `migrate`
- [ ] I never edit a migration that has already been applied
- [ ] I always give migrations descriptive names (`--name`)

### Architecture

- [ ] `selectors.py` contains only SELECTs (filter, annotate, prefetch_related)
- [ ] `services.py` uses `transaction.atomic()` where atomicity is needed
- [ ] `views.py` does not contain `Model.objects.*` directly
- [ ] I understand the READ flow and the WRITE flow

### ORM

- [ ] I understand N+1 and use `select_related`/`prefetch_related`
- [ ] `Q` objects — for OR conditions in filter
- [ ] `F()` — for atomic operations and comparing fields
- [ ] `select_for_update()` — for preventing race conditions
- [ ] `transaction.atomic()` — for atomic groups of operations
- [ ] `annotate()` — for computing in SQL instead of Python

### CBV

- [ ] I understand the difference between FBV and CBV
- [ ] I know why `.as_view()` is needed in `urls.py`
- [ ] I know the MRO order: `LoginRequiredMixin` FIRST
- [ ] `UserQuerySetMixin` — DRY data isolation per user
- [ ] `form_valid()` instead of `super().form_valid()` (so as not to bypass services)
- [ ] `reverse_lazy` instead of `reverse` in class attributes

### PostgreSQL

- [ ] I can run PostgreSQL via Docker
- [ ] I can configure `DATABASE_URL` via `python-decouple`
- [ ] I can move data from SQLite via `dumpdata`/`loaddata`

---

## Common mistakes

### Mistake 1: Starting with `models.py`

```
❌ WRONG: we immediately write class Note(models.Model)
✅ CORRECT: first describe the domain in words, then the ER diagram, then the code
```

### Mistake 2: A QuerySet in the View

```python
# ❌ WRONG:
def note_list(request):
    notes = Note.objects.filter(user=request.user).select_related(...)
    return render(...)

# ✅ CORRECT:
def note_list(request):
    notes = selectors.get_user_notes(request.user)
    return render(...)
```

### Mistake 3: Direct mutation in the View

```python
# ❌ WRONG:
def note_create(request):
    if form.is_valid():
        note = form.save()  # bypasses services!

# ✅ CORRECT:
def note_create(request):
    if form.is_valid():
        note = services.create_note(user=request.user, ...)
```

### Mistake 4: N+1 when accessing an FK

```python
# ❌ WRONG:
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)  # N+1!

# ✅ CORRECT:
notes = Note.objects.select_related('notebook').all()
for note in notes:
    print(note.notebook.title)  # 1 query!
```

### Mistake 5: SET_NULL without null=True

```python
# ❌ WRONG:
notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL)
# Django system check: fields.E320 — SET_NULL requires null=True on the field!

# ✅ CORRECT:
notebook = models.ForeignKey(
    Notebook, on_delete=models.SET_NULL,
    null=True, blank=True,
)
```

### Mistake 6: `super().form_valid()` in a CBV

```python
# ❌ WRONG in a CBV with services:
def form_valid(self, form):
    super().form_valid(form)  # form.save() is in there — bypasses services!

# ✅ CORRECT:
def form_valid(self, form):
    note = services.create_note(user=self.request.user, ...)
    return redirect('hello_app:note_detail', pk=note.pk)
```

### Mistake 7: `reverse()` instead of `reverse_lazy()` in a class attribute

```python
# ❌ WRONG: executed when the class is loaded
class NoteDeleteView(DeleteView):
    success_url = reverse('hello_app:note_list')  # NoReverseMatch!

# ✅ CORRECT: executed lazily during the request
class NoteDeleteView(DeleteView):
    success_url = reverse_lazy('hello_app:note_list')
```

---

## Practical exercise

1. Draw an ER diagram for a "Library" system: `Book`, `Author`, `Genre`, `Review`.
   Specify the relationship types and `on_delete` for every FK.
2. Implement the models with correct `related_name`, `__str__`, `ordering`.
3. Write `get_books_by_genre(genre)` in `selectors.py` with `select_related('author').prefetch_related('genres')`.
4. Write `create_book(*, title, author_id, genre_ids)` in `services.py` with `transaction.atomic()`.
5. Check in the Django shell: change the `author` of a book and verify that `updated_at` was updated.
6. Rewrite `BookListView` and `BookCreateView` from FBV to CBV with `LoginRequiredMixin` and `UserQuerySetMixin`.
7. Make sure there is no N+1: install `django-debug-toolbar` and check the number of queries on the book list page.

---

## Navigation

- Previous: [Class-Based Views](cbv.md)
- Back to the index: [Step 3. CRUD and architecture](index.md)
- Next step: [Step 4. Templates and Forms](../04_templates_bootstrap/index.md)
