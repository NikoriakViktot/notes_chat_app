# Part VII. Authentication and Security

**Authentication (AuthN):** who are you? → credential check → session.
**Authorization (AuthZ):** what are you allowed to do? → object-level permissions.

`@login_required` is only AuthN. Without an object-level permission → an IDOR vulnerability.

**Prerequisites:** Parts II, VI.
**Level:** Intermediate → Advanced.

---

## Chapters

| Document | What we'll learn |
|----------|-----------|
| [Authentication](auth_basics_full.md) | `authenticate()`, `login()`, `logout()`, `request.user`, password hashing |
| [Sessions](sessions_flow_full.md) | session engine, `SESSION_COOKIE_HTTPONLY`, `CSRF_COOKIE_SECURE`, lifecycle |
| [Permissions](permissions_full.md) | `@login_required`, object-level permission, `Q`-scoped QuerySet, IDOR |
| [Django security architecture](django_security_architecture_full.md) | middleware order, CSRF, clickjacking, XSS, SQL injection |
| [Security foundations](security_foundations_full.md) | CIA triad, threat modeling, principle of least privilege |
| [Common mistakes](security_misconceptions_full.md) | `@login_required` ≠ permission, public `pk`, mass assignment |
| [OWASP Top 10](owasp_top_10_full.md) | A01–A10: Injection, Broken Auth, XSS, IDOR, Misconfig, ... |
| [Zero Trust](zero_trust_full.md) | "never trust, always verify", network perimeter myth |
| [SIEM](siem_full.md) | security event logging, incident analysis |

---

## Key concepts

**IDOR (Insecure Direct Object Reference):**

```python
# ❌ VULNERABLE: any logged-in user can read someone else's note
@login_required
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk)  # pk=42 → someone else's note!
    return render(request, 'note_detail.html', {'note': note})

# ✅ SAFE: Q-scoped queryset
@login_required
def note_detail(request, pk):
    note = selectors.get_note_detail(user=request.user, note_id=pk)
    if not note:
        raise Http404
    return render(request, 'note_detail.html', {'note': note})
```

**A Q-filter in the selector — protection against IDOR:**

```python
# selectors.py
def get_note_detail(user, note_id):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        pk=note_id
    ).select_related('notebook', 'group').prefetch_related('tags').first()

def get_note_for_edit(user, pk):
    # edit/delete — owner only (not group members)
    return Note.objects.filter(user=user, pk=pk).first()
```

**Session lifecycle:**

```text
POST /accounts/login/ (username, password)
  → authenticate() → User or None
  → login(request, user)
      → create session: {_auth_user_id: 42, ...} → DB/cache
      → Set-Cookie: sessionid=abc123; HttpOnly; SameSite=Lax
  → redirect /

GET /notes/ (Cookie: sessionid=abc123)
  → SessionMiddleware: session['_auth_user_id'] = 42
  → AuthenticationMiddleware: request.user = User(pk=42)
  → @login_required → OK
```

**Notes Chat App permission matrix:**

| Object | Read | Edit/Delete |
|--------|---------|----------------------|
| Note | `owner OR group member` | `owner only` |
| Notebook / Tag | `owner` | `owner` |
| TodoList | `owner OR shared_with` | `owner` |
| ShoppingList | `owner OR shared_with OR group` | `owner` |
| ChatMessage | `group members (WS)` | — |

**Security settings in Notes Chat App:**

```python
# settings.py
SESSION_COOKIE_HTTPONLY = True    # JS cannot read the cookie
SESSION_COOKIE_SAMESITE = 'Lax'  # CSRF protection via the cookie
CSRF_COOKIE_SECURE      = True    # CSRF cookie over HTTPS only
X_FRAME_OPTIONS         = 'DENY'  # clickjacking protection
SECURE_SSL_REDIRECT     = True    # HTTP → HTTPS redirect (prod)
```

**WebSocket authentication:**

```python
# consumers.py
async def connect(self):
    user = self.scope['user']
    if not user.is_authenticated:
        await self.close()      # ← anonymous → rejected
        return
    group_pk = self.scope['url_route']['kwargs']['group_pk']
    is_member = await database_sync_to_async(self.check_membership)(group_pk, user)
    if not is_member:
        await self.close()      # ← not a group member → rejected
        return
    await self.accept()
```

---

## Where this lives in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_app/views.py` | `@login_required` on every view, `Http404` when the selector returns None |
| `notes_app/selectors.py` | `Q(user=user) \| Q(group__in=...)` — the core IDOR protection |
| `notes_app/consumers.py` | `check_membership()` in `connect()` |
| `notes_project/settings.py` | `SESSION_COOKIE_HTTPONLY`, `X_FRAME_OPTIONS`, `SECURE_SSL_REDIRECT` |
| `notes_app/tests/test_views.py` | IDOR tests: alice cannot read bob's note |

---

## Pedagogical connection

```text
Part VII: @login_required + Q-scoped selector
  → Part VIII: IDOR test (alice GET /notes/bob_pk/ → 404)
  → Part IX: WebSocket connect() → check_membership()
```

**Zero to Hero:** Step 5 — adding auth to notes_chat_app, the first IDOR test.

**Lab:** write a bug (no object-level permission) → write a test that catches it → fix it.

---

## Review questions

- What is the difference between AuthN and AuthZ? Which of them does `@login_required` check?
- What is IDOR? Give an example of vulnerable code and of the fixed version.
- Why does `Q(user=user) | Q(group__in=user_groups)` protect against IDOR when reading?
- Why is only `Q(user=user)` used for editing/deleting, without `Q(group...)`?
- What is `HttpOnly` on a cookie? Which attack does it protect against?
- What does Django check on every request via `CsrfViewMiddleware`?
- Why must `SecurityMiddleware` be first in `MIDDLEWARE`?

---

**Next →** [Part VIII. Testing and Quality](../08_testing_and_quality/README.md) — how to prove everything is correct.
