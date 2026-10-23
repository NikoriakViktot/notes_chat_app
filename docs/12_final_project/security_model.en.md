# Security Model

---

## Authentication

Django built-in auth: `django.contrib.auth`.

| URL | Mechanism |
|-----|---------|
| `/accounts/login/` | `LoginView` (built-in) |
| `/accounts/logout/` | `LogoutView` (built-in) |
| `/accounts/password_change/` | `PasswordChangeView` (built-in) |
| `/register/` | a custom view in `notes_app/views.py` |

`@login_required` or `LoginRequiredMixin` protects all views except `register`, `login`, `index`.

---

## Authorization and IDOR protection

All object queries use a scoped QuerySet, never a bare `Note.objects.get(pk=pk)`.

### Access pattern through selectors

```python
# selectors.py — read: owner or group member
def get_note_for_user(user, pk):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        pk=pk
    ).first()

# selectors.py — edit/delete: owner only
def get_note_for_edit(user, pk):
    return Note.objects.filter(user=user, pk=pk).first()
```

If the result is `None` → `Http404` or `PermissionDenied`.

### What it protects against

| Threat | Protection |
|---------|--------|
| IDOR (someone else's note by pk) | queryset scoped by `user=user` |
| Reading other people's group notes | the queryset includes `group__in=user_groups` |
| Editing someone else's object | only `Q(user=user)` for mutating ops |
| Mass assignment of tags | `tag_ids` are filtered: `Tag.objects.filter(user=user, pk__in=tag_ids)` |

---

## Group sharing

| Model | Mechanism |
|--------|---------|
| `Note` | `group = FK(Group, SET_NULL)` — group members can see the note |
| `ShoppingList` | `group = FK(Group, SET_NULL)` **and** `shared_with = M2M(User)` |
| `TodoList` | `shared_with = M2M(User)` — direct sharing with users |
| `ChatMessage` | through a Group — only group members can connect to the chat |

---

## WebSocket authorization

`GroupChatConsumer.connect()` checks:

1. `scope["user"].is_authenticated` — anonymous → `close(4003)`.
2. Whether `scope["user"]` is a member of group `group_pk` → not a member → `close(4004)`.

The check runs through `database_sync_to_async` before `accept()`.

---

## CSRF

Django's CSRF middleware is active by default (`CsrfViewMiddleware` in `MIDDLEWARE`).

WebSocket connections are not subject to CSRF (a separate protocol); authorization uses the session cookie.

---

## `DebugExceptionMiddleware`

!!! warning "Production security issue"
    `notes_project/middleware.py` implements `DebugExceptionMiddleware`, which returns the full traceback to the browser **without checking `DEBUG`**.
    In production this exposes implementation details to clients.
    It is kept for teaching purposes; before deploying to production you must remove it or restrict it with an `if settings.DEBUG` condition.

---

## Passwords and SECRET_KEY

- Passwords are hashed with Django's PBKDF2 by default.
- `SECRET_KEY` is read from an environment variable (`.env` → `docker-compose.yml`).
- `DEBUG=False` and `ALLOWED_HOSTS` are required before a production deployment.
