# Part II. Django Core

Django is a pipeline: an HTTP request passes through middleware → URL dispatcher → view → response. This part builds a mental model of that pipeline.

**Prerequisites:** Part I (HTTP).
**Level:** Beginner.

---

## Chapters

| Document | What we will learn |
|----------|-----------|
| [Django Architecture](django_architecture_full.md) | MTV pattern, settings, INSTALLED_APPS, lifecycle overview |
| [URL Routing](url_routing_full.md) | `urlpatterns`, `path()`, `include()`, `name=`, `reverse()`, namespace |
| [Views](views_full.md) | FBV vs CBV, `request` object, `HttpResponse`, `render()`, `redirect()` |
| [Request Lifecycle](request_lifecycle.md) | middleware pipeline, exception handling, response lifecycle |
| [WSGI vs ASGI](wsgi_vs_asgi.md) | sync vs async entrypoint, Daphne, ProtocolTypeRouter |
| [Project Structure](project_structure_full.md) | where things live, settings split, `manage.py` |
| [Management Commands](management_commands_full.md) | `runserver`, `migrate`, `shell`, `createsuperuser`, custom commands |
| [Diagrams](django_mermaid_full.md) | Mermaid diagrams of MTV, middleware, URL routing |

---

## Key concepts

**MTV (Model-Template-View):**

```
URL → View → Model (ORM)
           → Template (HTML render)
           → HttpResponse
```

**Request lifecycle through middleware:**

```python
# settings.py MIDDLEWARE (order matters)
[
    "django.middleware.security.SecurityMiddleware",   # HTTPS redirect, HSTS
    "django.contrib.sessions.middleware.SessionMiddleware",  # session → request.session
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",       # CSRF token check
    "django.contrib.auth.middleware.AuthenticationMiddleware",  # session → request.user
    "django.contrib.messages.middleware.MessageMiddleware",
]
```

**URL routing:**

```python
# notes_project/urls.py
urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),
    path('', include('notes_app.urls')),    # all notes_app routes
]

# notes_app/urls.py
path('notes/', views.note_list, name='note_list'),
path('notes/<int:pk>/edit/', views.note_edit, name='note_edit'),
```

**View:**

```python
# FBV — explicit GET/POST
@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(user=request.user, **form.cleaned_data)
            return redirect('note_detail', pk=note.pk)  # PRG
    else:
        form = NoteForm(user=request.user)
    return render(request, 'notes_app/note_form.html', {'form': form})
```

---

## WSGI vs ASGI in Notes Chat App

| | WSGI | ASGI |
|-|------|------|
| Entrypoint | `wsgi.py` | `asgi.py` |
| Server | Gunicorn, uWSGI | Daphne, Uvicorn |
| WebSocket | ❌ | ✅ |
| Async views | limited | ✅ |
| Notes Chat App | ❌ (`wsgi.py` is not used) | ✅ `notes_project/asgi.py` (Uvicorn in Docker) |

```python
# notes_project/asgi.py
application = ProtocolTypeRouter({
    "http":      get_asgi_application(),
    "websocket": AuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
```

---

## Where this lives in Notes Chat App

| File | What it shows |
|------|-----------|
| `notes_project/settings.py` | `INSTALLED_APPS`, `MIDDLEWARE`, `DATABASES`, `CHANNEL_LAYERS` |
| `notes_project/urls.py` | root URLconf — `admin`, `accounts`, `include(notes_app.urls)` |
| `notes_app/urls.py` | 35+ application routes |
| `notes_app/views.py` | 30+ FBVs, all with `@login_required` |
| `notes_project/asgi.py` | ASGI entrypoint with `ProtocolTypeRouter` |

---

## How it connects (teaching path)

```text
Part I: HTTP request → Django entrypoint (WSGI/ASGI)
Part II: middleware → URL → view → response
Part III: view → Model/ORM → DB
Part IV: view → Form → validation → service
Part V: view → Template → HTML
```

**Zero to Hero:** Step 1 — your first `urlpatterns` and your first `view`. Step 3 — understanding a thin view built on a selector + service.

---

## Practice

1. Add the URL `/hello/` → a view that returns `HttpResponse("Привіт!")` ("Hello!"). Check it in the browser.
2. Change the view so it returns `render(request, 'hello.html', {'name': 'World'})`. Create the template.
3. Run `python manage.py shell` → `from notes_app.models import Note; Note.objects.count()`.
4. Look at the CSRF token in a form's POST request in DevTools.

---

## Review questions

- What is MTV and how does it differ from MVC? Where is the "Controller" in Django?
- What happens if a middleware returns an `HttpResponse` without calling `get_response`?
- Why should `SecurityMiddleware` be first in `MIDDLEWARE`?
- What is PRG (Post-Redirect-Get)? Why is it needed?
- What is the difference between `render()` and `redirect()`?
- When should you use a CBV instead of an FBV?
- Why does Notes Chat App use ASGI instead of WSGI?

---

**Next →** [Part III. Models, Database, and ORM](../03_database_and_orm/README.md) — where the data is stored.
