# Views in detail — the full HTTP cycle

> A view is a Python function (or class) that receives an HTTP request and returns an HTTP response.
> It is the single entry point for every URL in Django.

---

## Why views — the HTTP Request/Response cycle

```
Browser → HTTP Request → Django → View → HTTP Response → Browser
```

Every click on a link or form submission is an HTTP request. Django matches the URL to a view function through `urls.py` and passes it the `request` object. The view processes the request and returns a response.

```python
# The simplest view — takes a request, returns a response
from django.http import HttpResponse

def hello(request):
    return HttpResponse("Hello, Django!")  # 200 OK + text
```

```
GET /hello/  →  Django → hello(request)  →  200 OK "Hello, Django!"
```

But in real applications, a view does more:
- Checks authentication (`@login_required`)
- Reads GET/POST parameters
- Calls selectors (reading from the DB) and services (changes in the DB)
- Renders an HTML template or returns JSON
- Redirects after a successful POST (the PRG pattern)

---

## The `request` object — everything that came from the browser

`request` is an instance of `HttpRequest`. It contains everything the browser sent:

```python
@login_required
def note_create(request):
    # The HTTP request method:
    request.method        # → 'GET', 'POST', 'PUT', 'DELETE'

    # The current authenticated user (filled in by AuthMiddleware):
    request.user          # → a User object or AnonymousUser
    request.user.is_authenticated  # → True/False

    # GET parameters (?q=python&tag=5):
    request.GET           # → QueryDict {'q': ['python'], 'tag': ['5']}
    request.GET.get('q', '')  # → 'python' (None if missing)
    request.GET.getlist('ids') # → ['1', '2', '3'] if ids=1&ids=2&ids=3

    # POST parameters (the form body):
    request.POST          # → QueryDict {'title': ['Нотатка'], 'priority': ['2']}
    request.POST.get('title', '')  # → 'Нотатка'

    # Uploaded files:
    request.FILES         # → MultiValueDict {'avatar': [<InMemoryUploadedFile>]}

    # Browser cookies (a dictionary):
    request.COOKIES       # → {'sessionid': 'abc123', 'csrftoken': 'xyz456'}

    # HTTP headers:
    request.headers       # → {'Host': 'localhost', 'Accept': 'text/html', ...}
    request.META.get('HTTP_REFERER', '')  # → URL of the previous page

    # The current URL (without GET parameters):
    request.path          # → '/notes/new/'

    # AJAX check (if fetch/axios sends the header):
    request.headers.get('X-Requested-With') == 'XMLHttpRequest'
```

**Why `request.POST` and not `request.body.decode()`?**

`request.POST` is an already parsed `QueryDict` from an `application/x-www-form-urlencoded` body. `request.body` is the raw byte string. JSON APIs use `json.loads(request.body)`, but for HTML forms it is always `request.POST`.

---

## Types of HTTP responses

### `render()` — an HTML page

```python
from django.shortcuts import render

def note_list(request):
    notes = Note.objects.filter(user=request.user)

    return render(
        request,                        # 1. request (required)
        'notes_app/note_list.html',     # 2. template path
        {'notes': notes, 'count': notes.count()},  # 3. context (a dictionary)
        # status=200,                   # 4. HTTP status (200 by default)
    )

# render() = TemplateResponse:
#   1. Finds the template by its path
#   2. Renders the Django Template with the context
#   3. Returns an HttpResponse with Content-Type: text/html
```

**Check:**
```bash
curl -I http://localhost:8001/notes/
# HTTP/1.1 200 OK
# Content-Type: text/html; charset=utf-8
```

### `redirect()` — redirection

```python
from django.shortcuts import redirect

# Redirect by URL name (recommended — does not depend on the actual URL)
return redirect('notes_app:note_list')
# → HTTP/1.1 302 Found + Location: /notes/

# Redirect by URL with arguments:
return redirect('notes_app:note_detail', pk=note.pk)
# → HTTP/1.1 302 Found + Location: /notes/42/

# Redirect by a URL string (hardcoded — not recommended):
return redirect('/notes/')

# Permanent redirect (301, for SEO):
return redirect('notes_app:note_list', permanent=True)
# → HTTP/1.1 301 Moved Permanently
```

**301 vs 302:**

| Code | Name | When |
|-----|-------|------|
| `302` | Found (temporary) | After a POST (PRG pattern), after login |
| `301` | Moved Permanently | The URL has changed permanently (SEO, old links) |

The browser caches a 301. If you make a 301 by accident, the browser will cache it forever. In development, always use 302.

### `HttpResponse` — an arbitrary response

```python
from django.http import HttpResponse, HttpResponseNotFound, HttpResponseForbidden

# Plain text:
return HttpResponse("OK", status=200)

# JSON (better: JsonResponse):
import json
return HttpResponse(
    json.dumps({'status': 'ok'}),
    content_type='application/json',
    status=200,
)

# 404 manually (better: raise Http404):
return HttpResponseNotFound("Сторінку не знайдено")

# 403 manually:
return HttpResponseForbidden("Доступ заборонено")
```

### `JsonResponse` — a JSON API

```python
from django.http import JsonResponse

def api_notes(request):
    notes = Note.objects.filter(user=request.user).values('id', 'title', 'priority')
    return JsonResponse(
        {'notes': list(notes)},   # ← json.dumps() automatically
        status=200,
    )
# → HTTP/1.1 200 OK + Content-Type: application/json
# → {"notes": [{"id": 1, "title": "Назва", "priority": 2}]}
```

### `Http404` — page not found

```python
from django.http import Http404

def note_detail(request, pk):
    try:
        note = Note.objects.get(pk=pk, user=request.user)
    except Note.DoesNotExist:
        raise Http404("Нотатку не знайдено")
    # → 404 Not Found + the templates/404.html template

# Or the shortcut — get_object_or_404:
from django.shortcuts import get_object_or_404
note = get_object_or_404(Note, pk=pk, user=request.user)
# If the Note does not exist → 404 automatically
```

---

## PRG Pattern — Post/Redirect/Get

**The problem without PRG:**
```
POST /notes/new/ (form)
→ The View saves the note
→ render() 200 OK (HTML with "Saved!")
→ The browser shows the page
→ F5 (refresh)
→ The browser asks: "Resend the POST request?"
→ If "Yes" → the note is created TWICE! A duplicate.
```

**With PRG (Post/Redirect/Get):**
```
POST /notes/new/ (form)
→ The View saves the note
→ redirect() 302 → /notes/42/   ← REDIRECT after a successful POST!
→ The browser performs GET /notes/42/
→ The View renders the note
→ F5 → repeats GET /notes/42/ → safe
```

```python
# The PRG pattern — a mandatory standard for forms
@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', 2),
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.id for t in form.cleaned_data.get('tags', [])],
            )
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('notes_app:note_detail', pk=note.pk)  # ← PRG: redirect!
        # is_valid() = False → fall through → render the form with errors
    else:
        form = NoteForm(user=request.user)  # GET: an empty form

    return render(request, 'notes_app/note_form.html', {
        'form': form,
        'title': 'Нова нотатка',
        'action': 'Створити',
    })
```

**Flow diagram:**

```
GET /notes/new/
    │
    ▼
form = NoteForm(user=request.user)  ← an empty form
    │
    ▼
render(note_form.html, {'form': form})  ← 200 OK

The student fills it in and clicks Submit:

POST /notes/new/
    │
    ▼
form = NoteForm(request.POST, user=request.user)
    │
    ├── is_valid() = False
    │       │
    │       └── render(note_form.html, {'form': form})  ← 200 OK with errors
    │
    └── is_valid() = True
            │
            ├── services.create_note(...)
            ├── messages.success(...)
            └── redirect('note_detail', pk=...)  ← 302 Found

GET /notes/42/
    │
    ▼
render(note_detail.html, {'note': note})  ← 200 OK
```

---

## `get_object_or_404()` — safely retrieving an object

```python
from django.shortcuts import get_object_or_404

# Basic syntax:
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE id=42
# If not found → Http404 (a 404 Not Found page)

# With a permission check (MANDATORY for private data!):
note = get_object_or_404(Note, pk=pk, user=request.user)
# SQL: SELECT * FROM note WHERE id=42 AND user_id=<current_user_id>
# If Alice requests Bob's note → 404 (not 403!) → Alice does not know whether this note exists at all
```

**Why 404 and not 403 for other users' objects?**

```
403 Forbidden: "you do not have permission"
→ Alice knows that id=42 EXISTS (she just has no access)
→ Information leak: an attacker iterates over ids and learns which ones exist

404 Not Found: "not found"  (but it actually exists, it is just not yours)
→ Alice does not know whether id=42 exists at all
→ No leak of information about other users' data
```

**Syntax variants:**

```python
# 1. By pk via a keyword argument:
note = get_object_or_404(Note, pk=pk)

# 2. By queryset — more flexible (allows filter, select_related):
note = get_object_or_404(
    Note.objects.select_related('notebook', 'user'),
    pk=pk,
    user=request.user,
)

# 3. With a Q filter (group notes — either mine or shared):
from django.db.models import Q
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
```

---

## Messages Framework — one-time messages

Django Messages lets you pass a message **through a redirect**. The message is stored in the session and displayed once on the next render.

```python
from django.contrib import messages

# Message types:
messages.success(request, 'Нотатку створено!')       # green
messages.error(request, 'Помилка при збереженні.')   # red
messages.warning(request, 'Нотатку видалено.')        # yellow
messages.info(request, 'Для початку — авторизуйся.') # blue

# In the template (base.html or layouts/dashboard.html):
```

```html
{% if messages %}
{% for message in messages %}
<div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
    {{ message }}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
</div>
{% endfor %}
{% endif %}
```

```python
# settings.py — mapping levels to Bootstrap classes:
from django.contrib.messages import constants as messages_constants
MESSAGE_TAGS = {
    messages_constants.DEBUG:   'secondary',
    messages_constants.INFO:    'info',
    messages_constants.SUCCESS: 'success',
    messages_constants.WARNING: 'warning',
    messages_constants.ERROR:   'danger',   # Bootstrap: alert-danger
}
```

**How messages pass through a redirect:**

```
POST /notes/42/delete/
    │
    ├── messages.warning(request, 'Видалено.')   ← stored in the SESSION
    └── redirect('notes_app:note_list')           ← 302

GET /notes/
    │
    ├── Django inserts messages from the SESSION into the context
    └── render(note_list.html)
            │
            └── {% for message in messages %} ← shown ONCE, then deleted
```

---

## Decorators for view functions

### `@login_required`

```python
from django.contrib.auth.decorators import login_required

@login_required
def note_list(request):
    # request.user is guaranteed to be authenticated here
    ...

# What happens if the user is not logged in:
# → redirect '/accounts/login/?next=/notes/'
# After login → redirect back to '/notes/'
```

```python
# Change the login URL (if it is non-standard):
@login_required(login_url='/auth/login/')
def note_list(request):
    ...

# Or globally in settings.py:
LOGIN_URL = '/accounts/login/'
```

### `@require_http_methods` / `@require_POST`

```python
from django.views.decorators.http import require_POST, require_GET, require_http_methods

# POST only (for example, for deletion or a toggle):
@login_required
@require_POST
def note_pin(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    services.toggle_pin_note(note)
    return redirect('notes_app:note_detail', pk=pk)

# A GET request to this view → 405 Method Not Allowed

# Or with the methods decorator:
@require_http_methods(['GET', 'POST'])
def note_create(request):
    ...
# PUT, DELETE → 405
```

### Decorator order

```python
# ❌ WRONG: login_required checks after require_POST
@require_POST
@login_required
def note_delete(request, pk):
    ...

# Anonymous GET → require_POST: 405 (not a 302 to login!)

# ✅ RIGHT: login_required first → checks authentication before the method
@login_required
@require_POST
def note_delete(request, pk):
    ...

# Anonymous GET → login_required: 302 to login ✓
```

Decorators are applied from the bottom up. `@login_required` above `@require_POST` means that `login_required` runs FIRST when the view is called.

---

## The full request → response cycle

```
Browser: POST /notes/new/

     │
     ▼
1. nginx (reverse proxy)
   → proxies to Django/Uvicorn

     │
     ▼
2. Django Middleware (a chain, ordered as in MIDDLEWARE in settings.py)
   → SecurityMiddleware: checks HTTPS, CSP
   → SessionMiddleware: loads the session from DB/Redis → request.session
   → AuthenticationMiddleware: session → request.user
   → CsrfViewMiddleware: checks csrfmiddlewaretoken
   → MessageMiddleware: loads messages from the session

     │
     ▼
3. URL Router (urls.py)
   → path('notes/new/', views.note_create, name='note_create')
   → calls views.note_create(request)

     │
     ▼
4. View: note_create(request)
   → request.method == 'POST'
   → NoteForm(request.POST, user=request.user)
   → form.is_valid()
   → services.create_note(...)
   → messages.success(request, '...')
   → redirect('notes_app:note_detail', pk=note.pk)
   → HttpResponse(status=302, Location='/notes/42/')

     │
     ▼
5. Response Middleware (reverse order)
   → MessageMiddleware: saves messages to the session
   → SessionMiddleware: saves the session

     │
     ▼
6. HTTP Response → nginx → browser
   302 Found
   Location: /notes/42/
```

---

## Debugging views

### Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `302` instead of `200` on GET | `@login_required` and the user is not logged in | Log in or check `request.user.is_authenticated` |
| `403 Forbidden` on POST | CSRF token missing or invalid | Add `{% csrf_token %}` to the form |
| `404 Not Found` | `get_object_or_404` found nothing or the URL is wrong | Check the pk and user in the request |
| `405 Method Not Allowed` | Wrong HTTP method (e.g. GET instead of POST) | Check the form's `method` attribute |
| `500 Internal Server Error` | An error in the view's Python code | Read the stack trace in the Django logs |
| The form is not saved, no redirect | `is_valid()` returns False | Temporarily add `print(form.errors)` |

### Add `print` for debugging (temporarily)

```python
@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        print("POST data:", request.POST)     # ← what came from the browser
        print("Form errors:", form.errors)    # ← why the form is invalid
        if form.is_valid():
            ...
```

```bash
# View in the Docker logs:
docker compose logs -f web
# → POST data: <QueryDict: {'title': [''], 'priority': ['2'], ...}>
# → Form errors: {'title': ['Це поле обов'язкове.']}
```

### Check in the Django shell

```bash
docker compose exec web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.forms import NoteForm

user = User.objects.get(username='demo_alice')

# Simulate is_valid() with POST data:
data = {
    'title': '',        # empty → error
    'priority': '2',
    'csrfmiddlewaretoken': 'fake',  # not checked in the shell
}
form = NoteForm(data, user=user)
print(form.is_valid())   # → False
print(form.errors)       # → {'title': ['Це поле обов'язкове.']}

# A valid POST:
data['title'] = 'Тест'
form = NoteForm(data, user=user)
print(form.is_valid())         # → True
print(form.cleaned_data)       # → {'title': 'Тест', 'priority': 2, ...}
```

---

## Example: full CRUD for tags (a simple case)

Tags are a good example of a minimal view: no complex filters, no M:N relationships in the form.

```python
# notes_app/views.py

@login_required
def tag_list(request):
    tags = selectors.get_user_tags(request.user)
    return render(request, 'notes_app/tag_list.html', {'tags': tags})


@login_required
def tag_create(request):
    if request.method == 'POST':
        form = TagForm(request.POST)
        if form.is_valid():
            tag = services.create_or_get_tag(
                user=request.user,
                name=form.cleaned_data['name'],
                color=form.cleaned_data.get('color', '#6c757d'),
            )
            messages.success(request, f'Тег "{tag.name}" створено.')

            # Support for ?next= — if we came from a note page, go back there
            next_url = request.GET.get('next') or request.POST.get('next')
            return redirect(next_url or 'notes_app:note_list')
    else:
        # Support for ?name=python — pre-fills the field
        initial = {}
        if name := request.GET.get('name'):
            initial['name'] = name
        form = TagForm(initial=initial)

    return render(request, 'notes_app/tag_form.html', {
        'form': form,
        'title': 'Новий тег',
    })


@login_required
def tag_delete(request, pk):
    tag = get_object_or_404(Tag, pk=pk, user=request.user)
    if request.method == 'POST':
        name = tag.name
        tag.delete()   # a simple case — there is no services.delete_tag()
        messages.warning(request, f'Тег "{name}" видалено.')
        return redirect('notes_app:tag_list')
    return render(request, 'notes_app/tag_confirm_delete.html', {'tag': tag})
```

**Two interesting patterns:**

1. `?next=` for a redirect after an action:
```html
<!-- In the note form template — add a tag and come back: -->
<a href="{% url 'notes_app:tag_create' %}?next={{ request.path }}">
    Новий тег
</a>
```

2. `?name=python` for pre-filling:
```html
<!-- Quickly create a tag with a name from the search: -->
<a href="{% url 'notes_app:tag_create' %}?name={{ search }}">
    Створити тег "{{ search }}"
</a>
```

---

## In the book

- [Part II. Django Core](../../02_django_core/README.md) — MTV architecture, URL routing, view functions, templates, request/response
- [Part VI. Application architecture](../../06_application_architecture/README.md) — thin views, services/selectors, the PRG pattern, decorators

---

## Official documentation

- [Django: Request and response objects](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest, HttpResponse, all attributes
- [Django: Writing views](https://docs.djangoproject.com/en/5.2/topics/http/views/) — the basics
- [Django: Shortcuts](https://docs.djangoproject.com/en/5.2/topics/http/shortcuts/) — render, redirect, get_object_or_404
- [Django: Decorators](https://docs.djangoproject.com/en/5.2/topics/http/decorators/) — login_required, require_http_methods
- [Django: Messages framework](https://docs.djangoproject.com/en/5.2/ref/contrib/messages/) — success, error, warning, info
- [Django: URL dispatcher](https://docs.djangoproject.com/en/5.2/topics/http/urls/) — path(), re_path(), reverse()
- [MDN: HTTP redirects](https://developer.mozilla.org/en-US/docs/Web/HTTP/Redirections) — the difference between 301 and 302
