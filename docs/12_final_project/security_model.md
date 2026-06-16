# Security Model

---

## Автентифікація

Django built-in auth: `django.contrib.auth`.

| URL | Механізм |
|-----|---------|
| `/accounts/login/` | `LoginView` (built-in) |
| `/accounts/logout/` | `LogoutView` (built-in) |
| `/accounts/password_change/` | `PasswordChangeView` (built-in) |
| `/register/` | кастомний view у `notes_app/views.py` |

`@login_required` або `LoginRequiredMixin` захищає всі views окрім `register`, `login`, `index`.

---

## Авторизація і IDOR захист

Всі об'єктні запити використовують scoped QuerySet — ніколи просто `Note.objects.get(pk=pk)`.

### Патерн доступу через selectors

```python
# selectors.py — read: owner або group member
def get_note_for_user(user, pk):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        pk=pk
    ).first()

# selectors.py — edit/delete: тільки owner
def get_note_for_edit(user, pk):
    return Note.objects.filter(user=user, pk=pk).first()
```

Якщо `None` → `Http404` або `PermissionDenied`.

### Що захищає

| Загроза | Захист |
|---------|--------|
| IDOR (чужа нотатка за pk) | scoped queryset по `user=user` |
| Читання чужих group notes | queryset включає `group__in=user_groups` |
| Редагування чужого об'єкту | тільки `Q(user=user)` для mutable ops |
| Масове призначення тегів | `tag_ids` фільтруються: `Tag.objects.filter(user=user, pk__in=tag_ids)` |

---

## Групове ділення

| Модель | Механізм |
|--------|---------|
| `Note` | `group = FK(Group, SET_NULL)` — члени групи бачать нотатку |
| `ShoppingList` | `group = FK(Group, SET_NULL)` **і** `shared_with = M2M(User)` |
| `TodoList` | `shared_with = M2M(User)` — пряме ділення з користувачами |
| `ChatMessage` | через Group — тільки члени групи підключаються до чату |

---

## WebSocket авторизація

`GroupChatConsumer.connect()` перевіряє:

1. `scope["user"].is_authenticated` — анонімний → `close(4003)`.
2. Чи є `scope["user"]` членом групи `group_pk` → не член → `close(4004)`.

Перевірка відбувається через `database_sync_to_async` до `accept()`.

---

## CSRF

Django CSRF middleware активна за замовчуванням (`CsrfViewMiddleware` у `MIDDLEWARE`).

WebSocket з'єднання не підлягають CSRF (окремий протокол); авторизація через session cookie.

---

## `DebugExceptionMiddleware`

!!! warning "Production security issue"
    `notes_project/middleware.py` реалізує `DebugExceptionMiddleware`, який повертає повний traceback у браузер **без перевірки `DEBUG`**.
    У production це розкриває деталі реалізації клієнтам.
    Залишається у навчальних цілях — перед деплоєм у production необхідно видалити або обмежити умовою `if settings.DEBUG`.

---

## Паролі та SECRET_KEY

- Паролі хешуються Django PBKDF2 за замовчуванням.
- `SECRET_KEY` читається з environment variable (`.env` → `docker-compose.yml`).
- `DEBUG=False` і `ALLOWED_HOSTS` потрібні перед production деплоєм.
