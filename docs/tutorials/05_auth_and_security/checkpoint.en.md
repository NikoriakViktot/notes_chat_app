# Checkpoint — Knowledge check

---

## Self-check checklist

### AuthN and Sessions

- [ ] `@login_required` and `LOGIN_URL` in `settings.py` are configured
- [ ] `include("django.contrib.auth.urls")` is included in `urls.py`
- [ ] The `registration/login.html` and `registration/register.html` templates exist
- [ ] `{% csrf_token %}` in EVERY form with `method="post"` — no exceptions
- [ ] Logout is implemented as a POST request (not a GET link)
- [ ] `SESSION_COOKIE_HTTPONLY = True` in `settings.py`

### Password Security

- [ ] The Password Reset flow has been tested (the link is in `docker compose logs web` or the terminal)
- [ ] The `validlink` check is present in `password_reset_confirm.html`
- [ ] `AUTH_PASSWORD_VALIDATORS` are configured in `settings.py`
- [ ] `EMAIL_BACKEND = console.EmailBackend` for dev

### IDOR and Object Permissions

- [ ] Personal objects (Notebook, TodoList, etc.): `get_object_or_404(Model, pk=pk, user=request.user)`
- [ ] Shared objects (Note): Q-filter + `note.user != request.user` before writing
- [ ] 404 (not 403) is returned for other users' objects

### Group Sharing

- [ ] `Note.group` and `ShoppingList.group` have `on_delete=SET_NULL`
- [ ] The Q-filter `Q(user=user) | Q(group__in=user_groups)` is present in `selectors.py`
- [ ] `get_user_groups` uses `annotate(member_count=Count('user'))`
- [ ] `create_group` is wrapped in `transaction.atomic()`
- [ ] Group delete explains that notes become personal (they are not deleted)

### Security Settings

- [ ] `SESSION_COOKIE_HTTPONLY = True` and `X_FRAME_OPTIONS = "DENY"` in `settings.py`
- [ ] `DEBUG = False` in production
- [ ] `ALLOWED_HOSTS` contains only real domains in production
- [ ] Production HTTPS settings are commented out and ready to be enabled

---

## IDOR Test — manual check

Run this test to make sure the IDOR protection works:

```
1. Log in as alice (demo_alice/demo1234)

2. Go to any note: /notes/
   Remember the pk of one of your notes (for example pk=1)

3. Open a second tab or an incognito window
   Log in as bob (demo_bob/demo1234)

4. In the browser where you are bob, type the URL by hand:
   http://localhost/notes/1/edit/     ← alice's note pk!

5. Expected result:
   ✓ 404 Not Found  — IDOR protection works
   ✗ If the edit form is shown — IDOR vulnerability!

6. Also check:
   http://localhost/notes/1/delete/   ← alice's note pk
   → it must also return 404
```

---

## Common mistakes

### 403 Forbidden on POST forms

```
Symptom: after submitting the form — "403 Forbidden: CSRF verification failed"

Cause: {% csrf_token %} is missing from the form

Fix:
  <form method="post">
    {% csrf_token %}    ← REQUIRED!
    ...
  </form>
```

### Logout via GET does not work

```
Symptom: <a href="/accounts/logout/">Вийти</a> does not log you out (Django 4.1+)

Cause: LogoutView accepts only POST requests (Django 4.1+ security fix)

Fix:
  <form method="post" action="{% url 'logout' %}">
    {% csrf_token %}
    <button type="submit">Вийти</button>
  </form>
```

### `request.user = AnonymousUser` inside a view

```
Symptom: `request.user.is_authenticated` → False, even though the user is logged in

Cause 1: `SessionMiddleware` or `AuthenticationMiddleware` was removed from MIDDLEWARE
Cause 2: The middleware order is broken (Auth comes before Session)

Fix:
  # settings.py — check the order:
  MIDDLEWARE = [
      ...
      'django.contrib.sessions.middleware.SessionMiddleware',   # ← Session first
      ...
      'django.contrib.auth.middleware.AuthenticationMiddleware',  # ← then Auth
      ...
  ]
```

### The Password Reset email does not arrive (dev)

```
Symptom: you filled in the password_reset form, but nothing happens

Cause: you are looking for the email in the browser rather than in the logs

Fix for crispy_notes_project:
  Look at the terminal where runserver is running — the email text will be there

Fix for notes_chat_app:
  docker compose logs -f web
  # Look for "Subject: Password reset on localhost"
```

### The IDOR vulnerability is still there

```
Symptom: another user can edit someone else's note

Cause: the view uses get_object_or_404(Note, pk=pk) without user=

Fix for personal objects:
  note = get_object_or_404(Note, pk=pk, user=request.user)

Fix for shared objects (Note with a group):
  user_groups = request.user.groups.all()
  note = get_object_or_404(
      Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
      pk=pk,
  )
  if note.user != request.user:
      messages.error(request, 'Ти не можеш редагувати чужу нотатку.')
      return redirect('notes_app:note_detail', pk=pk)
```

### Deleting a group deletes notes

```
Symptom: after a group is deleted, the members' notes disappear

Cause: Note.group = ForeignKey(Group, on_delete=CASCADE)

Fix:
  Note.group = ForeignKey(
      Group,
      on_delete=models.SET_NULL,   # ← SET_NULL, not CASCADE!
      null=True,
      blank=True,
  )
  # After this — a new migration: python manage.py makemigrations
```

---

## Summary: what to look for and where

| Concept | Where in the code |
|-----------|-----------|
| **AuthN vs AuthZ** | `views.py` — `@login_required` + Q-filter for access + `note.user != request.user` for editing |
| **Middleware chain** | `settings.py` — the `MIDDLEWARE` list + order |
| **Session flow** | `settings.py` — `SESSION_COOKIE_*` + Django session framework |
| **Login/Logout** | `templates/registration/login.html` + `urls.py` auth.urls |
| **POST logout** | `dashboard.html` — `<form method="post" action="{% url 'logout' %}">` |
| **Password Reset** | `templates/registration/password_reset_*.html` (5 files) |
| **DEV email** | `docker compose logs -f web` — find the `/accounts/reset/...` URL |
| **Password Change** | `templates/registration/password_change_*.html` + dashboard dropdown |
| **IDOR protection** | `views.py` — personal objects: `get_object_or_404(Model, pk=pk, user=...)`, shared ones: Q-filter + owner check |
| **404 not 403** | `views.py` — "do not reveal that someone else's object exists" |
| **Group FK SET_NULL** | `models.py` — `Note.group` + `ShoppingList.group` |
| **Q-filter** | `selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **N+1 protection** | `selectors.py` — `select_related('notebook', 'group')`, `prefetch_related('tags')` |
| **Group CRUD** | `services.py` — `create_group`, `add_user_to_group`, `delete_group` |
| **3-action POST** | `views.py group_detail` — `action='add'/'remove'/'leave'` |
| **SET_NULL cascade** | `group_confirm_delete.html` — explanation of the behavior |
| **Security settings** | `settings.py` — `HTTPONLY, SAMESITE, X_FRAME_OPTIONS, DEBUG=False` |
| **ngrok CSRF** | `settings.py` — `CSRF_TRUSTED_ORIGINS` from the `NGROK_DOMAIN` env |
| **PBKDF2 passwords** | the `auth_user.password` field — `pbkdf2_sha256$600000$salt$hash` |

---

## Practical exercise

Do it on your own:

1. **Basic:** Start `notes_chat_app` (`docker compose up --build`), register a new user, test Password Reset — find the email in `docker compose logs web` and change the password.

2. **Intermediate:** Create a group "My team" and add demo_bob to it. Create a note and assign it to this group. Log in as demo_bob and make sure the note is visible at `/notes/`.

3. **Advanced:** Run the IDOR test by hand (described above). Make sure you get a 404. Then temporarily change `get_object_or_404(Note.objects.filter(...), pk=pk)` to `get_object_or_404(Note, pk=pk)` and repeat the test — make sure the IDOR appears. Restore the protection.

4. **Exploratory:** Open DevTools → Application → Cookies after logging in. Find the `sessionid` cookie. Make sure that `HttpOnly = ✓`. Open the Console and run `document.cookie` — make sure `sessionid` is missing from the result.

---

## Navigation

- Previous: [Step 4. Templates and Forms](../04_templates_and_forms/index.md)
- Next: [Step 6. Testing](../06_testing/index.md)
