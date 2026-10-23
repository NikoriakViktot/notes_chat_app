# 7A. Async Views and the ORM

This section is a detailed comparison of the sync and async layers: `async_selectors.py`, `async_services.py`, `async_views.py` side by side with their sync counterparts.

---

## async_selectors.py: lazy vs evaluation

Open the file: `hello_app/async_selectors.py`

Compare it with the original: `hello_app/selectors.py`

### The key idea: lazy vs evaluation

```python
# selectors.py (sync): the original
def get_user_notes(user, ...):
    qs = Note.objects.filter(Q(user=user) | ...)
    qs = qs.select_related('notebook', 'group')
    qs = qs.prefetch_related('tags')
    return qs.order_by('-is_pinned', ...)
    # ↑ SQL has NOT run YET: returns a lazy QuerySet
    # SQL runs in views.py when: for note in notes: ...
```

```python
# async_selectors.py: the async version
def async_get_user_notes(user, ...):
    qs = Note.objects.filter(Q(user=user) | ...)
    qs = qs.select_related('notebook', 'group')
    qs = qs.prefetch_related('tags')
    return qs.order_by('-is_pinned', ...)
    # ↑ THE SAME LOGIC: also a lazy QuerySet
    # SQL runs in async_views.py when: async for note in notes_qs: ...
```

### Table: when SQL runs

| Django ORM method | Type | Does SQL run? |
|-----------------|-----|-----------------|
| `.filter(...)` | Lazy | ❌ No |
| `.select_related(...)` | Lazy | ❌ No |
| `.prefetch_related(...)` | Lazy | ❌ No |
| `.annotate(...)` | Lazy | ❌ No |
| `.order_by(...)` | Lazy | ❌ No |
| `.get()` | Eval | ✅ Yes (sync, blocks) |
| `.aget()` | Eval | ✅ Yes (async, does not block) |
| `.count()` | Eval | ✅ Yes (sync) |
| `.acount()` | Eval | ✅ Yes (async) |
| `for obj in qs` | Eval | ✅ Yes (sync, blocks) |
| `async for obj in qs` | Eval | ✅ Yes (async, does not block) |

### async def only where there is real SQL

```python
# async_get_user_notes: a regular def (lazy QuerySet, no SQL runs)
def async_get_user_notes(user, ...):
    return Note.objects.filter(...).select_related(...).order_by(...)

# async_get_note_detail: async def (real SQL through .aget())
async def async_get_note_detail(user, note_id):
    return await Note.objects.filter(...).select_related(...).aget(id=note_id)
    #      ↑ await: SQL runs asynchronously, the event loop is free while we wait
```

**Rule:** if a function returns a lazy QuerySet without running SQL, it can be a regular `def`, even if it is called from an async view. `async def` is only needed when there is real I/O inside (`.aget()`, `.acount()`, and so on).

---

## async_services.py: two approaches

Open the file: `hello_app/async_services.py`

Compare it with the original: `hello_app/services.py`

### The sync original

```python
# services.py (sync): the original
def create_note(*, user, title, ...):
    with transaction.atomic():         # ← transaction
        note = Note.objects.create(...)
        note.tags.set(valid_tags)
    return note
```

### Async through sync_to_async

```python
# async_services.py: async through sync_to_async
# You can't simply make it async def because of transaction.atomic()
async_create_note = sync_to_async(create_note, thread_sensitive=True)
# ↑ Wraps the sync create_note so it can be called safely from an async view
# sync_to_async runs create_note in a dedicated OS thread
# the event loop is free while the thread runs the transaction
```

### Comparing the three approaches

| Operation | Approach | Why |
|----------|--------|------|
| `async_create_note` | `sync_to_async(create_note)` | `transaction.atomic()` is not supported natively in async |
| `async_delete_note` | `await note.adelete()` | A simple DELETE, a native async ORM method |
| `async_toggle_pin_note` | `await qs.aupdate(is_pinned=~F(...))` | Atomic UPDATE, native async, without loading the object |

### sync_to_async: what it looks like at runtime

```
Async View (event loop thread)
    │
    │  await async_create_note(...)       ← the view suspends
    │
    ├─→ sync_to_async: hands off to a worker thread
    │
    │  the event loop serves OTHER requests ←
    │
    │  Worker Thread: runs create_note() + transaction.atomic()
    │
    │  Worker Thread: returns note ──────┐
    │                                     │
    │  the event loop resumes the view ───┘
    │
    └─→ note = <Note object>  ← the view continues
```

---

## async_views.py: syntactic differences

Open the file: `hello_app/async_views.py`

Compare it with the original: `hello_app/views.py`

### Key syntactic differences

```python
# views.py (sync): the original
@login_required
def note_list(request):
    notes = selectors.get_user_notes(request.user)        # lazy QuerySet
    # On the next line the template evaluates the QuerySet in a for loop (sync)
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

```python
# async_views.py: the async version
async def async_note_list(request):
    if not request.user.is_authenticated:         # explicit auth check
        return redirect('login')

    notes_qs = async_selectors.async_get_user_notes(request.user)  # lazy (sync def)

    notes = [note async for note in notes_qs]     # async for → SQL runs here
    #        ↑ the await happens inside async for
    #          the event loop is free while the DB responds

    return render(request, 'hello_app/note_list.html', {'notes': notes})
    #     ↑ render() is sync, but safe inside async def (Django 5.x)
```

### Where the `await`s are and why

| Line | await | Why |
|-------|-------|--------|
| `note = await async_selectors.async_get_note_detail(...)` | ✅ | Inside is aget(): real SQL |
| `notes = [note async for note in notes_qs]` | ✅ (implicit) | Iterating over a QuerySet = SQL |
| `note = await async_services.async_create_note(...)` | ✅ | sync_to_async: runs in a thread |
| `await async_services.async_delete_note(note)` | ✅ | adelete(): real SQL |
| `await async_services.async_toggle_pin_note(note)` | ✅ | aupdate(): real SQL |
| `form = NoteForm(request.POST, user=request.user)` | ❌ | The form is lazy, no heavy I/O |
| `form.is_valid()` | ❌ | CPU validation, no I/O |
| `return render(...)` | ❌ | Django 5.x renders a sync template safely |
| `return redirect(...)` | ❌ | Just an HttpResponse with 302, no I/O |

---

## Comparing views.py vs async_views.py

### note_list vs async_note_list

| Sync line | Async line | Why it changed |
|-----------|-------------|-------------|
| `@login_required` | `if not request.user.is_authenticated:` | `@login_required` does not support async views |
| `def note_list(request):` | `async def async_note_list(request):` | async def |
| `notes = selectors.get_user_notes(...)` | `notes_qs = async_selectors.async_get_user_notes(...)` | the lazy qs stays lazy |
| _(the template evaluates the qs)_ | `notes = [note async for note in notes_qs]` | explicit async iteration |
| `return render(...)` | `return render(...)` | identical |

### Django 4.1+ async ORM methods

Django 4.1 added native async ORM methods:

| Sync method | Async counterpart | What it does |
|------------|-------------|-----------|
| `qs.get(pk=x)` | `await qs.aget(pk=x)` | One object or DoesNotExist |
| `Model.objects.create(...)` | `await Model.objects.acreate(...)` | Creates a record |
| `qs.update(...)` | `await qs.aupdate(...)` | Bulk update |
| `qs.delete()` | `await qs.adelete()` | Bulk delete |
| `obj.save()` | `await obj.asave()` | Saves an object |
| `obj.delete()` | `await obj.adelete()` | Deletes an object |
| `for obj in qs:` | `async for obj in qs:` | Iterates over a QuerySet |
| `qs.exists()` | `await qs.aexists()` | Whether there is at least one |
| `qs.count()` | `await qs.acount()` | Number of rows |
| `qs.filter(...).first()` | `await qs.filter(...).afirst()` | The first result or None |

---

## Common student mistakes

### ❌ Mistake 1: Sync ORM in an async view

```python
async def bad_note_detail(request, pk):
    note = Note.objects.get(pk=pk)  # ← SynchronousOnlyOperation!
    return render(request, 'note_detail.html', {'note': note})
```

**The error:** `.get()` is sync SQL. In an async context Django raises an exception.

```python
# ✅ Correct
async def good_note_detail(request, pk):
    note = await Note.objects.aget(pk=pk)  # async counterpart of .get()
    return render(request, 'note_detail.html', {'note': note})
```

### ❌ Mistake 2: requests.get() in an async view

```python
import requests

async def bad_view(request):
    # requests.get() is sync! It blocks the whole event loop while waiting for the response
    data = requests.get("https://api.example.com/data").json()
    return JsonResponse(data)
```

**The error:** The whole server "freezes" for every other user for the duration of the HTTP request.

```python
# ✅ Correct: httpx.AsyncClient
import httpx

async def good_view(request):
    async with httpx.AsyncClient() as client:
        # await: the view suspends, the event loop serves others
        response = await client.get("https://api.example.com/data")
    return JsonResponse(response.json())
```

### ❌ Mistake 3: time.sleep() in an async view

```python
import time

async def bad_delay_view(request):
    time.sleep(2)  # Blocks the whole event loop for 2 seconds!
    return HttpResponse("done")
```

```python
# ✅ Correct: asyncio.sleep()
import asyncio

async def good_delay_view(request):
    await asyncio.sleep(2)  # Hands control back to the event loop
    return HttpResponse("done")
```

### ❌ Mistake 4: Rewriting the whole project in async "because it's trendy"

```python
# ❌ Async is not needed here: extra overhead
async def simple_crud_view(request):
    note = await Note.objects.aget(pk=1)
    return render(request, 'note.html', {'note': note})

# ✅ Simpler and sufficient for ordinary CRUD
def simple_crud_view(request):
    note = get_object_or_404(Note, pk=1)
    return render(request, 'note.html', {'note': note})
```

---

## Practical exercises

### Exercise 1: Compare the code

Open `views.py:note_list()` and `async_views.py:async_note_list()` side by side.
Find every line that changed. Write them down in a table:

| Sync line | Async line | Why it changed |
|-----------|-------------|-------------|
| `def note_list(request):` | `async def async_note_list(request):` | async def |
| `@login_required` | `if not request.user.is_authenticated:` | inline auth |
| `for note in notes_qs` | `[note async for note in notes_qs]` | async iteration |
| ... | ... | ... |

### Exercise 2: Add async_get_pinned_notes

`selectors.py` has `get_pinned_notes(user, limit=5)`.
Add its async counterpart `async_get_pinned_notes(user, limit=5)` to `async_selectors.py`.

Question: should this function be `def` or `async def`? Why?

### Exercise 3: Understand sync_to_async

In `async_services.py` find:

```python
async_create_note = sync_to_async(create_note, thread_sensitive=True)
```

Answer the questions:
1. Why can't `create_note` be made native async (without sync_to_async)?
2. What does `thread_sensitive=True` mean?
3. What happens to the event loop while sync_to_async is running?

---

## Next

Next chapter: **[7A. Benchmark and testing](7a_benchmark.md)**: `AsyncClient`, sync vs async tests, Postman, benchmark, Docker Compose.
