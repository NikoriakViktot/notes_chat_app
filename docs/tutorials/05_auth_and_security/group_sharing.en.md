# Group Sharing — Shared access via Django Groups

> **Idea:** Alice wants to share notes with her team.
> She creates a group "Dev team" and adds Bob.
> Both of them can see the notes and shopping lists assigned to this group.

---

## Django's built-in Group model

Django already has a ready-made `Group` model in `django.contrib.auth`:

```python
from django.contrib.auth.models import Group

# Every Group has:
#   id          — PK
#   name        — the name ('Family', 'Team', 'Class')
#   user_set    — M2N relation with User (via the auth_user_groups junction table)
#   permissions — M2N relation with Permission (for role-based access — not our case)

# In notes_app we use Group for SHARING DATA between users,
# not for the Django Permission System (is_staff, is_superuser, permissions).
```

### ER diagram: User, Group, Note, ShoppingList

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
│ user_id   (FK → User,  CASCADE)  ← required: who the owner is              │
│ group_id  (FK → Group, SET_NULL) ← optional: for sharing                   │
│ notebook_id (FK → Notebook, SET_NULL)                                       │
│ priority, is_pinned, is_archived ...                                        │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                                ShoppingList                                 │
│────────────────────────────────────────────────────────────────────────────│
│ user_id   (FK → User,  CASCADE)  ← owner                                   │
│ group_id  (FK → Group, SET_NULL) ← for sharing                             │
└────────────────────────────────────────────────────────────────────────────┘

If group_id = NULL  → personal note (only user_id sees it)
If group_id = 5     → group note (all members of group 5 see it)
```

---

## Group FK in the models: Note and ShoppingList

**Location:** `notes_app/models.py`

```python
from django.contrib.auth.models import User, Group


class Note(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notes'
    )
    # ── Group FK: for shared access ──────────────────────────────────────────
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,  # ← SET_NULL, not CASCADE!
        null=True,                   # ← NULL = personal note (default)
        blank=True,                  # ← the field is optional in the form
        related_name='notes',
    )
    # ── the remaining fields ──────────────────────────────────────────────────
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
    # ShoppingList also has a group FK for sharing:
    group = models.ForeignKey(
        Group,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='shopping_lists',
    )
    title = models.CharField(max_length=200)
    store_name = models.CharField(max_length=100, blank=True)
```

### Why `SET_NULL` and not `CASCADE`?

```
CASCADE:  deleting a group → ALL of the group's notes are deleted
          Alice deletes "Dev team" → Bob loses the shared notes!
          Unexpected and irreversible.

SET_NULL: deleting a group → the notes remain but become personal (group=NULL)
          Alice deletes the group → the notes move to their owners' personal spaces
          Safe behavior: no data is lost, only the sharing stops.

Django performs SET_NULL automatically as part of the cascading delete:
  DELETE FROM auth_group WHERE id=5
  → UPDATE note SET group_id=NULL WHERE group_id=5     ← automatically!
  → UPDATE shoppinglist SET group_id=NULL WHERE group_id=5  ← this too!
```

---

## Q-filter: "mine or the group's"

```python
# notes_app/selectors.py
from django.db.models import Q

def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """Returns the user's notes + notes of groups the user is a member of."""
    user_groups = user.groups.all()   # all of the user's groups (1 SQL)
    qs = Note.objects.filter(
        Q(user=user) |               # own notes
        Q(group__in=user_groups),    # notes of groups the user is a member of
        is_archived=archived,
    ).select_related('notebook', 'group').prefetch_related('tags')
    # ...
    return qs.order_by('-is_pinned', '-priority', '-updated_at')
```

```
Alice is in the groups: [Team(id=1), Family(id=3)]

SQL (simplified):
  SELECT * FROM note
  WHERE (user_id = 42)              -- Alice's personal notes
     OR (group_id IN (1, 3))        -- notes of her groups
  AND is_archived = FALSE
  ORDER BY is_pinned DESC, priority DESC, updated_at DESC
```

---

## Comparing sharing approaches

| | M2M `shared_with` (TodoList) | Group FK (Note, ShoppingList) |
|--|------------------------------|-------------------------------|
| **Where** | `TodoList.shared_with = ManyToManyField(User)` | `Note.group = ForeignKey(Group)` |
| **Shared with** | Specific users (a list of people) | All group members |
| **Management** | Via a form with checkboxes | Via `/groups/<pk>/` |
| **When it fits** | "Share with Bob specifically" | "Share with the whole team" |
| **Deletion** | The `ManyToMany` record is deleted | `SET_NULL` → the note becomes personal |

---

## Step 8 — Selectors update for Group

**Location:** `notes_app/selectors.py`

```python
from django.db.models import Q, Count
from django.contrib.auth.models import Group
from .models import Note, Notebook, Tag


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Returns the user's notes + notes of groups the user is a member of.

    Q(user=user) | Q(group__in=user_groups) — the key Q-filter.
    select_related/prefetch_related: minimum SQL queries (no N+1).
    """
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # own or the group's
        is_archived=archived,
    ).select_related(
        'notebook',   # JOIN → no +1 SQL when displaying the notebook color
        'group',      # JOIN → no +1 SQL when displaying the group name
    ).prefetch_related(
        'tags',       # IN query → no +1 SQL when displaying tags
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
    """The user's groups with the member count (annotate)."""
    return user.groups.annotate(
        member_count=Count('user')
        # annotate: adds a 'member_count' field to each Group object
        # SQL: SELECT g.*, COUNT(ug.user_id) as member_count
        #        FROM auth_group g
        #        JOIN auth_user_groups ug ON ug.group_id = g.id
        #        WHERE g.id IN (Alice's group ids)
        #        GROUP BY g.id
    ).order_by('name')


def get_group_with_members(group_id, user):
    """
    Returns the group with its members ONLY if the user is a member of it.
    If not a member → None (not Http404 — the view decides).
    """
    try:
        group = Group.objects.prefetch_related('user_set').get(pk=group_id)
        if not group.user_set.filter(pk=user.pk).exists():
            return None   # not a member → the view will return 404
        return group
    except Group.DoesNotExist:
        return None
```

**Explanation of `select_related` vs `prefetch_related`:**

```python
# select_related: JOIN → one SQL query
# Used for ForeignKey and OneToOne (N-to-1)
.select_related('notebook')
# SQL: SELECT note.*, nb.* FROM note LEFT JOIN notebook nb ON note.notebook_id = nb.id

# prefetch_related: a separate IN query → two SQL queries
# Used for ManyToMany (M-to-N)
.prefetch_related('tags')
# SQL 1: SELECT note.* FROM note WHERE ...
# SQL 2: SELECT tag.* FROM tag INNER JOIN note_tags ON ... WHERE note_id IN (1,2,3,...)

# Without select_related/prefetch_related → the N+1 problem:
# 10 notes → 10 queries for notebook + 10 for tags = 21 SQL queries!
# With optimization → 2 SQL queries (notes JOIN notebooks + tags)
```

---

## Step 9 — Services update for Group

**Location:** `notes_app/services.py`

```python
from django.contrib.auth.models import Group, User
from django.db import transaction


def create_group(*, name, creator):
    """
    Creates a group and automatically adds creator as the first member.

    Without a transaction: if add() fails → the Group exists with no members.
    With atomic(): both operations succeed, or both are rolled back.
    """
    with transaction.atomic():
        group = Group.objects.create(name=name)
        group.user_set.add(creator)   # M:N INSERT into auth_user_groups
    return group


def add_user_to_group(group, username):
    """
    Adds a user to the group by username.
    Returns (True, '') or (False, 'error message').

    Why not raise Exception?
    The view expects a tuple (ok, msg) so it can show the error in the form without a 500.
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
    """Removes a user from the group. M:N DELETE from auth_user_groups."""
    group.user_set.remove(user)


def delete_group(group):
    """
    Deletes the group.
    Django automatically applies SET_NULL to Note.group and ShoppingList.group.
    No notes are lost.
    """
    group.delete()
```

---

## Step 10 — Group Views

**Location:** `notes_app/views.py`

```python
from django.contrib.auth.models import Group, User
from django.core.exceptions import PermissionDenied
from django.http import Http404
from . import selectors, services


@login_required
def group_list(request):
    """The list of groups the current user belongs to."""
    groups = selectors.get_user_groups(request.user)
    return render(request, 'notes_app/group_list.html', {'groups': groups})


@login_required
def group_create(request):
    """
    Creating a new group. The creator automatically becomes the first member.

    Validation — via the GroupCreateForm form, not by hand via request.POST.get().
    Advantages of forms over raw POST:
      • clean_name() checks name uniqueness automatically
      • All errors are available via form.errors → we render them in the template
      • Consistent with the other views — one approach across the whole project
      • DRY: validation logic in one place (forms.py), not in every view
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
    Group view: members + actions (add/remove/leave).

    One view — three actions through a single POST:
      action='add'    → add a member by username
      action='remove' → remove a specific member (by user_pk)
      action='leave'  → the current user leaves the group
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
    Deleting a group.
    Only a group member may delete it; a non-member → 403 (we know the group exists).
    """
    group = get_object_or_404(Group, pk=pk)
    if not group.user_set.filter(pk=request.user.pk).exists():
        raise PermissionDenied   # 403: we know it exists, but we have no access
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

**Key pattern — one view, three actions:**

```
POST /groups/5/   {action: 'add',    username: 'bob'}     → add Bob
POST /groups/5/   {action: 'remove', user_pk: 99}         → remove user.pk=99
POST /groups/5/   {action: 'leave'}                       → the current user leaves

Why one view rather than three URLs?
  - All group management logic is in one place
  - A shared membership check in the view
  - Easier to test (one TestCase test class)
  - Fewer URL patterns
```

---

## Step 11 — Group Templates

**Location:** `notes_app/templates/notes_app/`

### `group_list.html` — group cards

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
          {# member_count = annotate from the get_user_groups selector #}
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

### `group_detail.html` — members and actions

```html
{% extends 'layouts/dashboard.html' %}
{% block topbar_title %}Група: {{ group.name }}{% endblock %}
{% block content %}

<div class="row g-4">

  <!-- ── Member list ── -->
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
          <!-- Remove a member — action=remove -->
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

  <!-- ── Actions panel ── -->
  <div class="col-md-6">

    <!-- Add a member — action=add -->
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

    <!-- Group chat -->
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

    <!-- Danger zone: leave or delete -->
    <div class="card border-danger shadow-sm">
      <div class="card-header border-danger">
        <h6 class="text-danger mb-0">
          <i class="bi bi-exclamation-triangle me-2"></i>Небезпечна зона
        </h6>
      </div>
      <div class="card-body">
        <!-- Leave the group — action=leave -->
        <form method="post" class="d-inline">
          {% csrf_token %}
          <input type="hidden" name="action" value="leave">
          <button type="submit"
                  class="btn btn-outline-danger btn-sm me-2"
                  onclick="return confirm('Покинути групу «{{ group.name }}»?')">
            <i class="bi bi-door-open me-1"></i>Покинути групу
          </button>
        </form>
        <!-- Delete the group — a separate URL (GET → confirm page) -->
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

> **Note on `ChatMessage`:** `notes_chat_app` also has `ChatMessage.group FK(Group, CASCADE)`. So when a group is deleted, the chat and all its messages are deleted (not `SET_NULL`). Notes and shopping lists are protected via `SET_NULL`.

---

## Next

Next chapter: [Security Settings](security_settings.md) — a table of security settings, `DEBUG=True` leaks, HTTPS production settings.
