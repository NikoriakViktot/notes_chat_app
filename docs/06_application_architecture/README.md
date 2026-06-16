# Частина VI. Архітектура застосунку

Fat view — це перший симптом того, що застосунок переріс початкову структуру. Ця частина вчить відділяти HTTP-координацію (view) від читання даних (selector) і зміни стану (service).

**Передумови:** Частини II, III, IV.
**Рівень:** Intermediate.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Services та Selectors](services_selectors_full.md) | патерн thin-view + selector + service, шари та їх межі |
| [Services (поглиблено)](django_services_full.md) | сигнатури, транзакції, повернення значень, тестування |
| [Selectors (поглиблено)](django_selectors_full.md) | scoped QuerySet, Q-filter, `select_related`, повернення матеріалізованих даних |
| [Serializers](django_serializers_full.md) | DRF-сумісні серіалізатори для API-шару |
| [Celery Tasks](django_tasks_full.md) | background tasks, broker, результати, retry |

---

## Ключові концепти

**Від fat view до thin view:**

```python
# ❌ FAT VIEW — все в одному місці
def note_edit(request, pk):
    note = Note.objects.get(pk=pk)  # ← ORM у view
    if note.user != request.user:   # ← permission у view
        raise Http404
    if request.method == 'POST':
        title = request.POST['title']  # ← без форми
        note.title = title             # ← без validation
        note.save()
        return redirect('note_list')
    return render(request, 'note_edit.html', {'note': note})

# ✅ THIN VIEW — координація між шарами
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

**Правила шарів:**

| Шар | Файл | Може | Не може |
|-----|------|------|---------|
| View | `views.py` | викликати form/selector/service, render/redirect | ORM-запити, мутації, бізнес-логіка |
| Selector | `selectors.py` | читати БД, фільтрувати, `select_related` | мутувати об'єкти, `save()`, `delete()` |
| Service | `services.py` | `create`, `update`, `delete`, транзакції | `render()`, `request`, знати про HTTP |
| Form | `forms.py` | validate, `clean_*`, повернути `cleaned_data` | запити до БД без мети (тільки для choices) |

**Selector — scoped читання:**

```python
# selectors.py
def get_note_for_edit(user, pk):
    """Тільки власник може редагувати."""
    return Note.objects.filter(user=user, pk=pk)\
                       .select_related('notebook', 'group')\
                       .prefetch_related('tags')\
                       .first()

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Всі нотатки користувача з фільтрами."""
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

**Service — атомарна мутація:**

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
    if group is not ...:    # Ellipsis = "не передано"; None = "прибрати групу"
        note.group = group; changed.append('group')
    if changed:
        note.save(update_fields=changed)
    if tag_ids is not None:
        note.tags.set(Tag.objects.filter(user=note.user, pk__in=tag_ids))
    return note
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_app/selectors.py` | 13 функцій: `get_user_notes`, `get_note_detail`, `get_group_with_members`, ... |
| `notes_app/services.py` | 30+ функцій: notes, notebooks, tags, todo, shopping, groups |
| `notes_app/views.py` | кожен view — тільки координація: form → selector/service → render/redirect |
| `notes_app/tests/test_services.py` | тести без HTTP: `create_note()` → перевірка return + persistence |

---

## Педагогічний зв'язок

```text
Частина VI: Selectors/Services
  → Частина VII: Q-scoped selectors → IDOR-захист
  → Частина VIII: test_services.py без HTTP (чисті unit tests)
  → Частина IX: database_sync_to_async(self.save_message)(...)  (service у consumer)
```

**Zero to Hero:** Крок 3 — перехід від ORM у view до selector/service. Крок 5 — Q-filter у selector для auth.

---

## Практика

1. Знайди у `notes_app/views.py` view де є ORM-запит напряму (без selector) — чи є такий?
2. Напиши `selector.get_archived_notes(user)` і `test_get_archived_notes` у `test_services.py`.
3. Рефактор: перенеси ORM-запит з view у новий selector.
4. Виконай `services.toggle_pin_note(note)` у `python manage.py shell` — перевір результат.

---

## Контрольні питання

- Що таке "fat view"? Назви 3 ознаки fat view.
- Яка різниця між selector і service? Що з них може мутувати стан?
- Чому selector повинен повертати матеріалізовані дані (наприклад `list()`) якщо викликається з async-коду?
- Що означає `group=...` (Ellipsis) у `update_note`? Навіщо потрібен sentinel замість `None`?
- Як протестувати service без HTTP-запиту?
- Чому `tag_ids` фільтруються через `Tag.objects.filter(user=note.user, ...)` а не просто `tag_ids`?

---

**Далі →** [Частина VII. Authentication і Security](../07_auth_and_security/README.md) — хто і що може робити.
