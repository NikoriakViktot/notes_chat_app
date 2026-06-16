# 7A. Async Views та ORM

Цей розділ — детальне порівняння sync і async шарів: `async_selectors.py`, `async_services.py`, `async_views.py` поруч із їхніми sync-аналогами.

---

## async_selectors.py: lazy vs evaluation

Відкрий файл: `hello_app/async_selectors.py`

Порівняй із оригінальним: `hello_app/selectors.py`

### Ключова ідея: lazy vs evaluation

```python
# selectors.py (sync) — оригінал
def get_user_notes(user, ...):
    qs = Note.objects.filter(Q(user=user) | ...)
    qs = qs.select_related('notebook', 'group')
    qs = qs.prefetch_related('tags')
    return qs.order_by('-is_pinned', ...)
    # ↑ SQL ЩЕ НЕ ВИКОНУВАВСЯ — повертає lazy QuerySet
    # SQL виконується у views.py коли: for note in notes: ...
```

```python
# async_selectors.py — async версія
def async_get_user_notes(user, ...):
    qs = Note.objects.filter(Q(user=user) | ...)
    qs = qs.select_related('notebook', 'group')
    qs = qs.prefetch_related('tags')
    return qs.order_by('-is_pinned', ...)
    # ↑ ТА САМА ЛОГІКА — теж lazy QuerySet
    # SQL виконується у async_views.py коли: async for note in notes_qs: ...
```

### Таблиця: коли SQL виконується

| Django ORM метод | Тип | SQL виконується? |
|-----------------|-----|-----------------|
| `.filter(...)` | Lazy | ❌ Ні |
| `.select_related(...)` | Lazy | ❌ Ні |
| `.prefetch_related(...)` | Lazy | ❌ Ні |
| `.annotate(...)` | Lazy | ❌ Ні |
| `.order_by(...)` | Lazy | ❌ Ні |
| `.get()` | Eval | ✅ Так (sync — блокує) |
| `.aget()` | Eval | ✅ Так (async — не блокує) |
| `.count()` | Eval | ✅ Так (sync) |
| `.acount()` | Eval | ✅ Так (async) |
| `for obj in qs` | Eval | ✅ Так (sync — блокує) |
| `async for obj in qs` | Eval | ✅ Так (async — не блокує) |

### async def тільки там де є реальний SQL

```python
# async_get_user_notes — звичайна def (lazy QuerySet, SQL не виконується)
def async_get_user_notes(user, ...):
    return Note.objects.filter(...).select_related(...).order_by(...)

# async_get_note_detail — async def (реальний SQL через .aget())
async def async_get_note_detail(user, note_id):
    return await Note.objects.filter(...).select_related(...).aget(id=note_id)
    #      ↑ await: SQL виконується асинхронно, event loop вільний поки чекаємо
```

**Правило:** якщо функція повертає lazy QuerySet без виконання SQL — вона може бути звичайною `def`, навіть якщо викликається з async view. `async def` потрібен лише коли всередині є реальний I/O (`.aget()`, `.acount()`, тощо).

---

## async_services.py: два підходи

Відкрий файл: `hello_app/async_services.py`

Порівняй із оригінальним: `hello_app/services.py`

### Sync оригінал

```python
# services.py (sync) — оригінал
def create_note(*, user, title, ...):
    with transaction.atomic():         # ← транзакція
        note = Note.objects.create(...)
        note.tags.set(valid_tags)
    return note
```

### Async через sync_to_async

```python
# async_services.py — async через sync_to_async
# Не можна просто зробити async def через transaction.atomic()
async_create_note = sync_to_async(create_note, thread_sensitive=True)
# ↑ Обгортає sync create_note для безпечного виклику з async view
# sync_to_async запускає create_note у виділеному OS-потоці
# event loop вільний поки потік виконує транзакцію
```

### Порівняння трьох підходів

| Операція | Підхід | Чому |
|----------|--------|------|
| `async_create_note` | `sync_to_async(create_note)` | `transaction.atomic()` не підтримується natively async |
| `async_delete_note` | `await note.adelete()` | Простий DELETE, native async ORM метод |
| `async_toggle_pin_note` | `await qs.aupdate(is_pinned=~F(...))` | Атомарний UPDATE, native async, без завантаження об'єкта |

### sync_to_async: як це виглядає в пам'яті

```
Async View (event loop thread)
    │
    │  await async_create_note(...)       ← view призупиняється
    │
    ├─→ sync_to_async: передає у worker thread
    │
    │  event loop обслуговує ІНШІ запити ←
    │
    │  Worker Thread: виконує create_note() + transaction.atomic()
    │
    │  Worker Thread: повертає note ─────┐
    │                                     │
    │  event loop відновлює view ─────────┘
    │
    └─→ note = <Note object>  ← view продовжується
```

---

## async_views.py: синтаксичні відмінності

Відкрий файл: `hello_app/async_views.py`

Порівняй із оригінальним: `hello_app/views.py`

### Ключові синтаксичні відмінності

```python
# views.py (sync) — оригінал
@login_required
def note_list(request):
    notes = selectors.get_user_notes(request.user)        # lazy QuerySet
    # Рядком нижче template evaluate QuerySet через for loop (sync)
    return render(request, 'hello_app/note_list.html', {'notes': notes})
```

```python
# async_views.py — async версія
async def async_note_list(request):
    if not request.user.is_authenticated:         # явна auth перевірка
        return redirect('login')

    notes_qs = async_selectors.async_get_user_notes(request.user)  # lazy (sync def)

    notes = [note async for note in notes_qs]     # async for → SQL виконується тут
    #        ↑ await відбувається всередині async for
    #          event loop вільний поки DB відповідає

    return render(request, 'hello_app/note_list.html', {'notes': notes})
    #     ↑ render() — sync, але безпечна у async def (Django 5.x)
```

### Де стоять `await`-и і чому

| Рядок | await | Навіщо |
|-------|-------|--------|
| `note = await async_selectors.async_get_note_detail(...)` | ✅ | Всередині aget() — реальний SQL |
| `notes = [note async for note in notes_qs]` | ✅ (implicit) | Ітерація по QuerySet = SQL |
| `note = await async_services.async_create_note(...)` | ✅ | sync_to_async — виконується у потоці |
| `await async_services.async_delete_note(note)` | ✅ | adelete() — реальний SQL |
| `await async_services.async_toggle_pin_note(note)` | ✅ | aupdate() — реальний SQL |
| `form = NoteForm(request.POST, user=request.user)` | ❌ | Форма lazy, без важкого I/O |
| `form.is_valid()` | ❌ | CPU-валідація, без I/O |
| `return render(...)` | ❌ | Django 5.x рендерить sync template безпечно |
| `return redirect(...)` | ❌ | Просто HttpResponse з 302, без I/O |

---

## Порівняння views.py vs async_views.py

### note_list vs async_note_list

| Sync рядок | Async рядок | Чому змінено |
|-----------|-------------|-------------|
| `@login_required` | `if not request.user.is_authenticated:` | `@login_required` не підтримує async views |
| `def note_list(request):` | `async def async_note_list(request):` | async def |
| `notes = selectors.get_user_notes(...)` | `notes_qs = async_selectors.async_get_user_notes(...)` | lazy qs залишається lazy |
| _(template evaluate qs)_ | `notes = [note async for note in notes_qs]` | explicit async iteration |
| `return render(...)` | `return render(...)` | однакова |

### Async ORM методи Django 4.1+

Django 4.1 додав нативні async методи ORM:

| Sync метод | Async аналог | Що робить |
|------------|-------------|-----------|
| `qs.get(pk=x)` | `await qs.aget(pk=x)` | Один об'єкт або DoesNotExist |
| `Model.objects.create(...)` | `await Model.objects.acreate(...)` | Створення запису |
| `qs.update(...)` | `await qs.aupdate(...)` | Масове оновлення |
| `qs.delete()` | `await qs.adelete()` | Масове видалення |
| `obj.save()` | `await obj.asave()` | Збереження об'єкта |
| `obj.delete()` | `await obj.adelete()` | Видалення об'єкта |
| `for obj in qs:` | `async for obj in qs:` | Ітерація по QuerySet |
| `qs.exists()` | `await qs.aexists()` | Чи є хоч один |
| `qs.count()` | `await qs.acount()` | Кількість рядків |
| `qs.filter(...).first()` | `await qs.filter(...).afirst()` | Перший результат або None |

---

## Типові помилки студентів

### ❌ Помилка 1: Sync ORM у async view

```python
async def bad_note_detail(request, pk):
    note = Note.objects.get(pk=pk)  # ← SynchronousOnlyOperation!
    return render(request, 'note_detail.html', {'note': note})
```

**Помилка:** `.get()` — sync SQL. В async context Django кидає виняток.

```python
# ✅ Правильно
async def good_note_detail(request, pk):
    note = await Note.objects.aget(pk=pk)  # async аналог .get()
    return render(request, 'note_detail.html', {'note': note})
```

### ❌ Помилка 2: requests.get() в async view

```python
import requests

async def bad_view(request):
    # requests.get() — sync! Блокує весь event loop на час очікування відповіді
    data = requests.get("https://api.example.com/data").json()
    return JsonResponse(data)
```

**Помилка:** Весь сервер "завмирає" на час HTTP-запиту для всіх інших користувачів.

```python
# ✅ Правильно: httpx.AsyncClient
import httpx

async def good_view(request):
    async with httpx.AsyncClient() as client:
        # await: view призупиняється, event loop обслуговує інших
        response = await client.get("https://api.example.com/data")
    return JsonResponse(response.json())
```

### ❌ Помилка 3: time.sleep() в async view

```python
import time

async def bad_delay_view(request):
    time.sleep(2)  # Блокує весь event loop на 2 секунди!
    return HttpResponse("done")
```

```python
# ✅ Правильно: asyncio.sleep()
import asyncio

async def good_delay_view(request):
    await asyncio.sleep(2)  # Передає управління event loop'у
    return HttpResponse("done")
```

### ❌ Помилка 4: Переписати весь проєкт в async "бо модно"

```python
# ❌ Async тут не потрібен — зайвий overhead
async def simple_crud_view(request):
    note = await Note.objects.aget(pk=1)
    return render(request, 'note.html', {'note': note})

# ✅ Простіший і достатній для звичайного CRUD
def simple_crud_view(request):
    note = get_object_or_404(Note, pk=1)
    return render(request, 'note.html', {'note': note})
```

---

## Практичні завдання

### Завдання 1: Порівняй код

Відкрий поруч `views.py:note_list()` і `async_views.py:async_note_list()`.
Знайди всі рядки що змінились. Запиши їх у таблицю:

| Sync рядок | Async рядок | Чому змінено |
|-----------|-------------|-------------|
| `def note_list(request):` | `async def async_note_list(request):` | async def |
| `@login_required` | `if not request.user.is_authenticated:` | inline auth |
| `for note in notes_qs` | `[note async for note in notes_qs]` | async iteration |
| ... | ... | ... |

### Завдання 2: Додай async_get_pinned_notes

У `selectors.py` є `get_pinned_notes(user, limit=5)`.
Додай її async-аналог `async_get_pinned_notes(user, limit=5)` в `async_selectors.py`.

Питання: ця функція має бути `def` або `async def`? Чому?

### Завдання 3: Зрозумій sync_to_async

В `async_services.py` знайди:

```python
async_create_note = sync_to_async(create_note, thread_sensitive=True)
```

Відповідь на питання:
1. Чому `create_note` не можна зробити native async (без sync_to_async)?
2. Що означає `thread_sensitive=True`?
3. Що відбувається з event loop поки sync_to_async виконується?

---

## Далі

Наступна глава: **[7A. Benchmark та тестування](7a_benchmark.md)** — `AsyncClient`, тести sync vs async, Postman, benchmark, Docker Compose.
