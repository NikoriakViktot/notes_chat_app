# Частина VII. Authentication і Security

**Authentication (AuthN):** хто ти? → перевірка credentials → сесія.
**Authorization (AuthZ):** що ти маєш право робити? → object-level permissions.

`@login_required` — це тільки AuthN. Без object-level permission → IDOR-вразливість.

**Передумови:** Частини II, VI.
**Рівень:** Intermediate → Advanced.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Автентифікація](auth_basics_full.md) | `authenticate()`, `login()`, `logout()`, `request.user`, password hashing |
| [Сесії](sessions_flow_full.md) | session engine, `SESSION_COOKIE_HTTPONLY`, `CSRF_COOKIE_SECURE`, lifecycle |
| [Права доступу](permissions_full.md) | `@login_required`, object-level permission, `Q`-scoped QuerySet, IDOR |
| [Архітектура безпеки Django](django_security_architecture_full.md) | middleware order, CSRF, clickjacking, XSS, SQL injection |
| [Основи безпеки](security_foundations_full.md) | CIA тріада, threat modeling, принцип найменших привілеїв |
| [Типові помилки](security_misconceptions_full.md) | `@login_required` ≠ permission, публічний `pk`, масове призначення |
| [OWASP Top 10](owasp_top_10_full.md) | A01–A10: Injection, Broken Auth, XSS, IDOR, Misconfig, ... |
| [Zero Trust](zero_trust_full.md) | "ніколи не довіряй, завжди перевіряй", network perimeter myth |
| [SIEM](siem_full.md) | логування подій безпеки, аналіз інцидентів |

---

## Ключові концепти

**IDOR (Insecure Direct Object Reference):**

```python
# ❌ ВРАЗЛИВО: будь-який залогінений user може читати чужу нотатку
@login_required
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk)  # pk=42 → чужа нотатка!
    return render(request, 'note_detail.html', {'note': note})

# ✅ БЕЗПЕЧНО: Q-scoped queryset
@login_required
def note_detail(request, pk):
    note = selectors.get_note_detail(user=request.user, pk=pk)
    if not note:
        raise Http404
    return render(request, 'note_detail.html', {'note': note})
```

**Q-filter у selector — захист від IDOR:**

```python
# selectors.py
def get_note_detail(user, note_id):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        pk=note_id
    ).select_related('notebook', 'group').prefetch_related('tags').first()

def get_note_for_edit(user, pk):
    # ред/видалення — тільки власник (не group members)
    return Note.objects.filter(user=user, pk=pk).first()
```

**Session lifecycle:**

```text
POST /accounts/login/ (username, password)
  → authenticate() → User або None
  → login(request, user)
      → create session: {_auth_user_id: 42, ...} → DB/cache
      → Set-Cookie: sessionid=abc123; HttpOnly; SameSite=Lax
  → redirect /

GET /notes/ (Cookie: sessionid=abc123)
  → SessionMiddleware: session['_auth_user_id'] = 42
  → AuthenticationMiddleware: request.user = User(pk=42)
  → @login_required → OK
```

**Матриця дозволів Notes Chat App:**

| Об'єкт | Читання | Редагування/Видалення |
|--------|---------|----------------------|
| Note | `owner OR group member` | `owner only` |
| Notebook / Tag | `owner` | `owner` |
| TodoList | `owner OR shared_with` | `owner` |
| ShoppingList | `owner OR shared_with OR group` | `owner` |
| ChatMessage | `group members (WS)` | — |

**Security settings у Notes Chat App:**

```python
# settings.py
SESSION_COOKIE_HTTPONLY = True    # JS не може читати cookie
SESSION_COOKIE_SAMESITE = 'Lax'  # захист від CSRF через cookie
CSRF_COOKIE_SECURE      = True    # CSRF cookie тільки по HTTPS
X_FRAME_OPTIONS         = 'DENY'  # clickjacking захист
SECURE_SSL_REDIRECT     = True    # HTTP → HTTPS redirect (prod)
```

**WebSocket аутентифікація:**

```python
# consumers.py
async def connect(self):
    user = self.scope['user']
    if not user.is_authenticated:
        await self.close()      # ← anonymous → відмова
        return
    group_pk = self.scope['url_route']['kwargs']['group_pk']
    is_member = await database_sync_to_async(self.check_membership)(group_pk, user)
    if not is_member:
        await self.close()      # ← не член групи → відмова
        return
    await self.accept()
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_app/views.py` | `@login_required` на всіх view, `Http404` при None з selector |
| `notes_app/selectors.py` | `Q(user=user) \| Q(group__in=...)` — core IDOR захист |
| `notes_app/consumers.py` | `check_membership()` у `connect()` |
| `notes_project/settings.py` | `SESSION_COOKIE_HTTPONLY`, `X_FRAME_OPTIONS`, `SECURE_SSL_REDIRECT` |
| `notes_app/tests/test_views.py` | IDOR-тести: alice не може читати bob's note |

---

## Педагогічний зв'язок

```text
Частина VII: @login_required + Q-scoped selector
  → Частина VIII: IDOR test (alice GET /notes/bob_pk/ → 404)
  → Частина IX: WebSocket connect() → check_membership()
```

**Zero to Hero:** Крок 5 — додавання auth до notes_chat_app, перший IDOR-тест.

**Lab:** написати bug (без object-level permission) → написати тест що його ловить → виправити.

---

## Контрольні питання

- Яка різниця між AuthN і AuthZ? Що з них перевіряє `@login_required`?
- Що таке IDOR? Наведи приклад вразливого коду і виправленого.
- Чому `Q(user=user) | Q(group__in=user_groups)` захищає від IDOR при читанні?
- Чому для редагування/видалення використовується тільки `Q(user=user)` без `Q(group...)`?
- Що таке `HttpOnly` у cookie? Від якої атаки захищає?
- Що Django перевіряє при кожному запиті через `CsrfViewMiddleware`?
- Чому `SecurityMiddleware` повинен бути першим у `MIDDLEWARE`?

---

**Далі →** [Частина VIII. Testing і Quality](../08_testing_and_quality/README.md) — як довести що все правильно.
