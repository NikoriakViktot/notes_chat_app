# Group Sharing — Спільний доступ через Django Groups

> **Ідея:** Аліса хоче ділитись нотатками з командою.
> Вона створює групу "Команда розробки" і додає Боба.
> Нотатки та списки покупок позначені цією групою бачать обидва.

---

## Django вбудована модель Group

Django вже має готову модель `Group` у `django.contrib.auth`:

```python
from django.contrib.auth.models import Group

# Кожна Group має:
#   id          — PK
#   name        — назва ('Сімя', 'Команда', 'Клас')
#   user_set    — M2N зв'язок з User (через auth_user_groups junction table)
#   permissions — M2N зв'язок з Permission (для role-based access — не наш випадок)

# У notes_app ми використовуємо Group для ШЕРИНГУ ДАНИХ між юзерами,
# а не для Django Permission System (is_staff, is_superuser, permissions).
```

### ER-Діаграма: User, Group, Note, ShoppingList

```
┌──────────────┐         ┌──────────────────────┐         ┌──────────────┐
│    User      │         │  auth_user_groups     │         │    Group     │
│──────────────│         │──────────────────────│         │──────────────│
│ id (PK)      │◄───────►│ user_id  (FK → User) │◄───────►│ id (PK)      │
│ username     │   M:N   │ group_id (FK → Group)│   M:N   │ name         │
│ password     │         └──────────────────────┘         └──────┬───────┘
│ email        │                                                  │
└──────┬───────┘                                                  │ 1:N (FK SET_NULL)
       │                                                          │
       │ 1:N (FK CASCADE)                                         │
       │                                                          │
       ▼                                                          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                                   Note                                      │
│────────────────────────────────────────────────────────────────────────────│
│ id (PK)                                                                     │
│ title                                                                       │
│ content                                                                     │
│ user_id   (FK → User,  CASCADE)  ← обов'язковий: хто власник               │
│ group_id  (FK → Group, SET_NULL) ← необов'язковий: для шерингу             │
│ notebook_id (FK → Notebook, SET_NULL)                                       │
│ priority, is_pinned, is_archived ...                                        │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                                ShoppingList                                 │
│────────────────────────────────────────────────────────────────────────────│
│ user_id   (FK → User,  CASCADE)  ← власник                                 │
│ group_id  (FK → Group, SET_NULL) ← для шерингу                             │
└────────────────────────────────────────────────────────────────────────────┘

Якщо group_id = NULL  → особиста нотатка (тільки user_id бачить)
Якщо group_id = 5     → групова нотатка (всі члени групи 5 бачать)
```

---

## Group FK у моделях: Note і ShoppingList

**Місце:** `notes_app/models.py`

```python
from django.contrib.auth.models import User, Group


class Note(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notes'
    )
    # ── Group FK: для спільного доступу ──────────────────────────────────────
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,  # ← SET_NULL, не CASCADE!
        null=True,                   # ← NULL = особиста нотатка (за замовчуванням)
        blank=True,                  # ← у формі поле необов'язкове
        related_name='notes',
    )
    # ── решта полів ───────────────────────────────────────────────────────────
    notebook = models.ForeignKey(
        'Notebook', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='notes'
    )
    title    = models.CharField(max_length=200)
    content  = models.TextField(blank=True)
    priority = models.PositiveSmallIntegerField(default=1)
    is_pinned    = models.BooleanField(default=False)
    is_archived  = models.BooleanField(default=False)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)
    tags = models.ManyToManyField('Tag', blank=True)


class ShoppingList(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    # ShoppingList теж має group FK для шерингу:
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='shopping_lists',
    )
    title = models.CharField(max_length=200)
    store_name = models.CharField(max_length=100, blank=True)
```

### Чому `SET_NULL`, а не `CASCADE`?

```
CASCADE:  видалення групи → видаляються ВСІ нотатки групи
          Аліса видаляє "Команда розробки" → Боб втрачає спільні нотатки!
          Несподівано і незворотньо.

SET_NULL: видалення групи → нотатки залишаються, але стають особистими (group=NULL)
          Аліса видаляє групу → нотатки переходять до особистих просторів власників
          Безпечна поведінка: дані не губляться, тільки шерінг зупиняється.

Django виконує SET_NULL автоматично в CASCADE delete:
  DELETE FROM auth_group WHERE id=5
  → UPDATE note SET group_id=NULL WHERE group_id=5     ← автоматично!
  → UPDATE shoppinglist SET group_id=NULL WHERE group_id=5  ← теж!
```

---

## Q-filter: "мої або групові"

```python
# notes_app/selectors.py
from django.db.models import Q

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Повертає нотатки юзера + нотатки груп де він є членом."""
    user_groups = user.groups.all()   # всі групи юзера (1 SQL)
    qs = Note.objects.filter(
        Q(user=user) |               # власні нотатки
        Q(group__in=user_groups),    # нотатки груп де user є членом
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ...
    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

```
Аліса є в групах: [Команда(id=1), Сімя(id=3)]

SQL (спрощено):
  SELECT * FROM note
  WHERE (user_id = 42)              -- особисті нотатки Аліси
     OR (group_id IN (1, 3))        -- нотатки її груп
  AND is_archived = FALSE
  ORDER BY is_pinned DESC, priority DESC, updated_at DESC
```

---

## Порівняння підходів до шерингу

| | M2M `shared_with` (TodoList) | Group FK (Note, ShoppingList) |
|--|------------------------------|-------------------------------|
| **Де** | `TodoList.shared_with = ManyToManyField(User)` | `Note.group = ForeignKey(Group)` |
| **Кому шерити** | Конкретним юзерам (список осіб) | Всім членам групи |
| **Управління** | Через форму з чекбоксами | Через `/groups/<pk>/` |
| **Коли підходить** | "Поділитись з конкретним Бобом" | "Поділитись з усією командою" |
| **Видалення** | `ManyToMany` запис видаляється | `SET_NULL` → нотатка стає особистою |

---

## Крок 8 — Selectors update для Group

**Місце:** `notes_app/selectors.py`

```python
from django.db.models import Q, Count
from django.contrib.auth.models import Group
from .models import Note, Notebook, Tag


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Повертає нотатки юзера + нотатки груп де він є членом.

    Q(user=user) | Q(group__in=user_groups) — ключовий Q-фільтр.
    select_related/prefetch_related: мінімум SQL запитів (без N+1).
    """
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # власні або групові
        is_archived=archived,
    ).select_related(
        'notebook',   # JOIN → без +1 SQL при відображенні кольору записника
        'group',      # JOIN → без +1 SQL при відображенні назви групи
    ).prefetch_related(
        'tags',       # IN query → без +1 SQL при відображенні тегів
    )

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if tag is not None:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(
            Q(title__icontains=search) | Q(content__icontains=search)
        )

    return qs.order_by('-is_pinned', '-priority', '-updated_at')


def get_user_groups(user):
    """Групи юзера з кількістю учасників (annotate)."""
    return user.groups.annotate(
        member_count=Count('user')
        # annotate: додає поле 'member_count' до кожного Group об'єкта
        # SQL: SELECT g.*, COUNT(ug.user_id) as member_count
        #        FROM auth_group g
        #        JOIN auth_user_groups ug ON ug.group_id = g.id
        #        WHERE g.id IN (Alice's group ids)
        #        GROUP BY g.id
    ).order_by('name')


def get_group_with_members(group_id, user):
    """
    Повертає групу з учасниками ТІЛЬКИ якщо юзер є її членом.
    Якщо не член → None (не Http404 — вирішує view).
    """
    try:
        group = Group.objects.prefetch_related('user_set').get(pk=group_id)
        if not group.user_set.filter(pk=user.pk).exists():
            return None   # не член → view поверне 404
        return group
    except Group.DoesNotExist:
        return None
```

**Пояснення `select_related` vs `prefetch_related`:**

```python
# select_related: JOIN → один SQL запит
# Використовується для ForeignKey і OneToOne (N-to-1)
.select_related('notebook')
# SQL: SELECT note.*, nb.* FROM note LEFT JOIN notebook nb ON note.notebook_id = nb.id

# prefetch_related: окремий IN запит → два SQL запити
# Використовується для ManyToMany (M-to-N)
.prefetch_related('tags')
# SQL 1: SELECT note.* FROM note WHERE ...
# SQL 2: SELECT tag.* FROM tag INNER JOIN note_tags ON ... WHERE note_id IN (1,2,3,...)

# Без select_related/prefetch_related → N+1 проблема:
# 10 нотаток → 10 запитів для notebook + 10 для tags = 21 SQL запит!
# З оптимізацією → 3 SQL запити (notes + notebooks + tags)
```

---

## Крок 9 — Services update для Group

**Місце:** `notes_app/services.py`

```python
from django.contrib.auth.models import Group, User
from django.db import transaction


def create_group(*, name, creator):
    """
    Створює групу і автоматично додає creator як першого учасника.

    Без транзакції: якщо add() провалиться → Group існує без учасників.
    З atomic(): обидві операції або обидві rollback.
    """
    with transaction.atomic():
        group = Group.objects.create(name=name)
        group.user_set.add(creator)   # M:N INSERT у auth_user_groups
    return group


def add_user_to_group(group, username):
    """
    Додає юзера до групи за username.
    Повертає (True, '') або (False, 'повідомлення про помилку').

    Чому не raise Exception?
    View очікує tuple (ok, msg) щоб відобразити помилку у формі без 500.
    """
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return False, f'Користувача «{username}» не знайдено.'

    if group.user_set.filter(pk=user.pk).exists():
        return False, f'«{username}» вже є членом цієї групи.'

    group.user_set.add(user)
    return True, ''


def remove_user_from_group(group, user):
    """Видаляє юзера з групи. M:N DELETE з auth_user_groups."""
    group.user_set.remove(user)


def delete_group(group):
    """
    Видаляє групу.
    Django автоматично SET_NULL для Note.group і ShoppingList.group.
    Жодних нотаток не втрачається.
    """
    group.delete()
```

---

## Крок 10 — Group Views

**Місце:** `notes_app/views.py`

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import PermissionDenied
from django.http import Http404
from . import selectors, services


@login_required
def group_list(request):
    """Список груп до яких належить поточний юзер."""
    groups = selectors.get_user_groups(request.user)
    return render(request, 'notes_app/group_list.html', {'groups': groups})


@login_required
def group_create(request):
    """
    Створення нової групи. Creator автоматично стає першим учасником.

    Валідація — через форму GroupCreateForm, а не вручну через request.POST.get().
    Переваги форм над raw POST:
      • clean_name() перевіряє унікальність назви автоматично
      • Всі помилки доступні через form.errors → рендеримо в шаблоні
      • Узгоджено з іншими view — один підхід у всьому проєкті
      • DRY: логіка валідації в одному місці (forms.py), не в кожному view
    """
    if request.method == 'POST':
        form = GroupCreateForm(request.POST)
        if form.is_valid():
            group = services.create_group(
                name=form.cleaned_data['name'],
                creator=request.user,
            )
            messages.success(request, f'✅ Групу «{group.name}» створено! Ви перший учасник.')
            return redirect('notes_app:group_detail', pk=group.pk)
    else:
        form = GroupCreateForm()
    return render(request, 'notes_app/group_form.html', {
        'form': form, 'title': 'Нова група', 'action': 'Створити',
    })


@login_required
def group_detail(request, pk):
    """
    Перегляд групи: учасники + дії (додати/видалити/покинути).

    Один view — три дії через один POST:
      action='add'    → додати учасника за username
      action='remove' → видалити конкретного учасника (по user_pk)
      action='leave'  → поточний юзер покидає групу
    """
    group = selectors.get_group_with_members(pk, request.user)
    if group is None:
        raise Http404('Групу не знайдено або у вас немає доступу.')

    error = None

    if request.method == 'POST':
        action = request.POST.get('action')

        if action == 'add':
            username = request.POST.get('username', '').strip()
            ok, msg = services.add_user_to_group(group, username)
            if ok:
                messages.success(request, f'«{username}» додано до групи.')
                return redirect('notes_app:group_detail', pk=pk)
            else:
                error = msg

        elif action == 'remove':
            remove_pk = request.POST.get('user_pk')
            try:
                target = User.objects.get(pk=remove_pk)
                if target == request.user:
                    messages.error(request, 'Щоб покинути групу — використай кнопку "Покинути".')
                else:
                    services.remove_user_from_group(group, target)
                    messages.success(request, f'«{target.username}» видалено з групи.')
            except User.DoesNotExist:
                pass
            return redirect('notes_app:group_detail', pk=pk)

        elif action == 'leave':
            group_name = group.name
            services.remove_user_from_group(group, request.user)
            messages.info(request, f'Ви покинули групу «{group_name}».')
            return redirect('notes_app:group_list')

    return render(request, 'notes_app/group_detail.html', {
        'group':   group,
        'members': group.user_set.all(),
        'error':   error,
    })


@login_required
def group_delete(request, pk):
    """
    Видалення групи.
    Тільки якщо request.user є членом → 403 (ми знаємо що група існує).
    """
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise PermissionDenied   # 403: знаємо що існує, але не маємо доступу
    if request.method == 'POST':
        name = group.name
        services.delete_group(group)
        messages.warning(
            request,
            f'Групу «{name}» видалено. Спільні нотатки і списки стали особистими.'
        )
        return redirect('notes_app:group_list')
    return render(request, 'notes_app/group_confirm_delete.html', {'group': group})
```

**Ключовий патерн — один view, три дії:**

```
POST /groups/5/   {action: 'add',    username: 'bob'}     → додати Боба
POST /groups/5/   {action: 'remove', user_pk: 99}         → видалити user.pk=99
POST /groups/5/   {action: 'leave'}                       → поточний юзер іде

Навіщо один view а не три URL?
  - Вся логіка управління групою в одному місці
  - Спільний middleware check (membership)
  - Простіше для тестування (один тест класу TestCase)
  - Менше URL patterns
```

---

## Крок 11 — Group Templates

**Місце:** `notes_app/templates/notes_app/`

### `group_list.html` — картки груп

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Мої групи{% endblock %}
{% block content %}

<div class="d-flex justify-content-between align-items-center mb-4">
  <h5 class="fw-semibold mb-0">
    <i class="bi bi-people me-2 text-primary"></i>Мої групи
  </h5>
  <a href="{% url 'notes_app:group_create' %}" class="btn btn-primary btn-sm">
    <i class="bi bi-person-plus me-1"></i>Нова група
  </a>
</div>

{% if groups %}
<div class="row row-cols-1 row-cols-md-3 g-3">
  {% for group in groups %}
  <div class="col">
    <div class="card h-100 shadow-sm border-0">
      <div class="card-body">
        <h6 class="fw-semibold mb-1">{{ group.name }}</h6>
        <p class="text-muted small mb-0">
          <i class="bi bi-person me-1"></i>
          {{ group.member_count }} учасник{{ group.member_count|pluralize:",и,ів" }}
          {# member_count = annotate з get_user_groups selector #}
        </p>
      </div>
      <div class="card-footer bg-transparent border-0 pt-0">
        <a href="{% url 'notes_app:group_detail' group.pk %}"
           class="btn btn-outline-primary btn-sm">
          <i class="bi bi-arrow-right me-1"></i>Відкрити
        </a>
        <a href="{% url 'notes_app:group_chat' group.pk %}"
           class="btn btn-outline-success btn-sm ms-1">
          <i class="bi bi-chat me-1"></i>Чат
        </a>
      </div>
    </div>
  </div>
  {% endfor %}
</div>

{% else %}
<div class="text-center py-5 text-muted">
  <i class="bi bi-people display-4 mb-3"></i>
  <h6>Груп ще немає</h6>
  <p class="small">Створи групу і додай учасників для спільного доступу до нотаток.</p>
  <a href="{% url 'notes_app:group_create' %}" class="btn btn-primary btn-sm">
    Створити першу групу
  </a>
</div>
{% endif %}

{% endblock %}
```

### `group_detail.html` — учасники і дії

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Група: {{ group.name }}{% endblock %}
{% block content %}

<div class="row g-4">

  <!-- ── Список учасників ── -->
  <div class="col-md-6">
    <div class="card shadow-sm">
      <div class="card-header d-flex justify-content-between align-items-center">
        <h6 class="mb-0">
          <i class="bi bi-people me-2"></i>Учасники ({{ members.count }})
        </h6>
      </div>
      <ul class="list-group list-group-flush">
        {% for member in members %}
        <li class="list-group-item d-flex justify-content-between align-items-center">
          <span>
            <i class="bi bi-person-circle me-2 text-muted"></i>
            {{ member.username }}
            {% if member == request.user %}
              <span class="badge bg-success rounded-pill ms-1">Ти</span>
            {% endif %}
          </span>
          <!-- Видалити учасника — action=remove -->
          {% if member != request.user %}
          <form method="post" class="d-inline">
            {% csrf_token %}
            <input type="hidden" name="action" value="remove">
            <input type="hidden" name="user_pk" value="{{ member.pk }}">
            <button type="submit"
                    class="btn btn-outline-danger btn-sm"
                    onclick="return confirm('Видалити {{ member.username }} з групи?')">
              <i class="bi bi-x-lg"></i>
            </button>
          </form>
          {% endif %}
        </li>
        {% endfor %}
      </ul>
    </div>
  </div>

  <!-- ── Панель дій ── -->
  <div class="col-md-6">

    <!-- Додати учасника — action=add -->
    <div class="card shadow-sm mb-3">
      <div class="card-header">
        <h6 class="mb-0"><i class="bi bi-person-plus me-2"></i>Додати учасника</h6>
      </div>
      <div class="card-body">
        {% if error %}
        <div class="alert alert-danger py-2 small mb-3">
          <i class="bi bi-exclamation-circle me-1"></i>{{ error }}
        </div>
        {% endif %}
        <form method="post" class="d-flex gap-2">
          {% csrf_token %}
          <input type="hidden" name="action" value="add">
          <input type="text"
                 name="username"
                 class="form-control form-control-sm"
                 placeholder="username учасника"
                 required>
          <button type="submit" class="btn btn-primary btn-sm">
            <i class="bi bi-plus-lg"></i>
          </button>
        </form>
      </div>
    </div>

    <!-- Чат групи -->
    <div class="card shadow-sm mb-3">
      <div class="card-body d-flex align-items-center gap-3">
        <i class="bi bi-chat-dots-fill text-success fs-4"></i>
        <div>
          <h6 class="mb-0">Груповий чат</h6>
          <p class="text-muted small mb-0">WebSocket чат у реальному часі</p>
        </div>
        <a href="{% url 'notes_app:group_chat' group.pk %}"
           class="btn btn-outline-success btn-sm ms-auto">
          Відкрити чат
        </a>
      </div>
    </div>

    <!-- Небезпечна зона: покинути або видалити -->
    <div class="card border-danger shadow-sm">
      <div class="card-header border-danger">
        <h6 class="text-danger mb-0">
          <i class="bi bi-exclamation-triangle me-2"></i>Небезпечна зона
        </h6>
      </div>
      <div class="card-body">
        <!-- Покинути групу — action=leave -->
        <form method="post" class="d-inline">
          {% csrf_token %}
          <input type="hidden" name="action" value="leave">
          <button type="submit"
                  class="btn btn-outline-danger btn-sm me-2"
                  onclick="return confirm('Покинути групу «{{ group.name }}»?')">
            <i class="bi bi-door-open me-1"></i>Покинути групу
          </button>
        </form>
        <!-- Видалити групу — окремий URL (GET → confirm page) -->
        <a href="{% url 'notes_app:group_delete' group.pk %}"
           class="btn btn-danger btn-sm">
          <i class="bi bi-trash me-1"></i>Видалити групу
        </a>
      </div>
    </div>

  </div>
</div>
{% endblock %}
```

### `group_confirm_delete.html`

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Видалення групи{% endblock %}
{% block content %}

<div class="card border-danger shadow-sm" style="max-width: 500px;">
  <div class="card-header bg-danger text-white">
    <h6 class="mb-0">
      <i class="bi bi-trash me-2"></i>Видалення групи «{{ group.name }}»
    </h6>
  </div>
  <div class="card-body">
    <div class="alert alert-warning">
      <strong><i class="bi bi-exclamation-triangle me-1"></i>Після видалення:</strong>
      <ul class="mb-0 mt-2 ps-3">
        <li>Група та список учасників видаляться <strong>назавжди</strong>.</li>
        <li>Нотатки і списки покупок <strong>НЕ видаляються</strong> —
            вони стають особистими (<code>group = NULL</code>
            через <code>on_delete=SET_NULL</code>).</li>
        <li>Чат групи і всі повідомлення <strong>видаляться</strong>
            (<code>ChatMessage.group FK CASCADE</code>).</li>
      </ul>
    </div>
    <form method="post">
      {% csrf_token %}
      <button type="submit" class="btn btn-danger me-2">
        <i class="bi bi-trash me-1"></i>Так, видалити
      </button>
      <a href="{% url 'notes_app:group_detail' group.pk %}"
         class="btn btn-outline-secondary">
        Скасувати
      </a>
    </form>
  </div>
</div>

{% endblock %}
```

> **Примітка щодо `ChatMessage`:** у `notes_chat_app` є ще `ChatMessage.group FK(Group, CASCADE)`. Тому при видаленні групи — чат і всі повідомлення видаляються (не `SET_NULL`). Нотатки і списки покупок захищені через `SET_NULL`.

---

## Далі

Наступна глава: [Security Settings](security_settings.md) — таблиця security налаштувань, `DEBUG=True` витоки, HTTPS production settings.
