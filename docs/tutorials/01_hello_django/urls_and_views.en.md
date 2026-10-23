# URLs and Views

> Here you will write your first view functions and URL routes.
> This is the heart of Django — the code that receives a request and returns a response.

---

## Step 7 — Write view functions

Open `hello_app/views.py`:

```python
from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    """Home page."""
    return HttpResponse("Hello, Django!")


def about(request):
    """About us page."""
    return HttpResponse("Це моя перша сторінка на Django!")
```

### Anatomy of a view function

```python
def index(request):
    #       ↑
    #  HttpRequest object — contains:
    #    request.method   → 'GET', 'POST', 'PUT', 'DELETE'
    #    request.GET      → QueryDict: parameters ?q=search&page=2
    #    request.POST     → QueryDict: the POST form body
    #    request.user     → the logged-in User or AnonymousUser
    #    request.session  → dict-like: the user's session
    #    request.META     → HTTP headers: REMOTE_ADDR, HTTP_HOST...
    #    request.FILES    → uploaded files
    #    request.COOKIES  → browser cookies

    return HttpResponse("Hello!")
    #         ↑
    #  HttpResponse — the response to the browser:
    #    status_code=200 (by default)
    #    content_type='text/html; charset=utf-8'
    #    body: 'Hello!'
```

### Response types

```python
from django.http import (
    HttpResponse,            # 200 OK with any content
    HttpResponseRedirect,    # 302 Redirect
    Http404,                 # raised as an exception → 404 page
    JsonResponse,            # 200 OK with a JSON body
)
from django.shortcuts import render, redirect, get_object_or_404

# The most common in views.py:
return render(request, 'hello_app/index.html', {'key': value})
# → renders an HTML template with a context → 200

return redirect('hello_app:note_list')
# → 302 Redirect to a URL from reverse()

return redirect('hello_app:note_detail', pk=42)
# → 302 Redirect with an argument

raise Http404("Не знайдено")
# → Django returns a 404 page

note = get_object_or_404(Note, pk=pk)
# → Note.objects.get(pk=pk), but instead of DoesNotExist → Http404
```

---

## Step 8 — URL routes

Create a new file `hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = "hello_app"    # ← Namespace

urlpatterns = [
    path('', views.index, name='index'),        # → /
    path('about/', views.about, name='about'),  # → /about/
]
```

**Why `app_name`?** Without it, the link `{% url 'hello_app:index' %}` does not work.
Django raises: `ImproperlyConfigured: Specifying a namespace in include() without providing an app_name`

Connect it to the main `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
    #     ↑                              ↑
    #   empty prefix →               namespace for {% url %}
    #   hello_app URLs start
    #   right from the root /
]
```

### How Django finds the view for a GET /about/ request

```
GET /about/
    ↓
hello_project/urls.py:
  path('', include('hello_app.urls', ...))
  → prefix '' → PASS

hello_app/urls.py:
  path('about/', views.about, name='about')
  → 'about/' == 'about/' → MATCH!

views.about(request) is called
  → HttpResponse("Це моя перша сторінка...")
```

---

## 05 · URL Patterns — in detail

### Anatomy of path()

```python
from django.urls import path, include, re_path
from . import views

urlpatterns = [
    # path(route, view, kwargs=None, name=None)
    path('about/', views.about, name='about'),
    #      ↑          ↑               ↑
    #   URL string  callable        unique route name
]
```

### Path Converters — capturing values from the URL

```python
urlpatterns = [
    # <int:pk> — capture an integer
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    # /notes/42/ → the view receives pk=42

    # <str:username> — capture a string (does not include '/')
    path('users/<str:username>/', views.user_profile, name='user_profile'),
    # /users/alice/ → the view receives username='alice'

    # <slug:slug> — only letters, digits, hyphens
    path('articles/<slug:slug>/', views.article, name='article'),
    # /articles/my-first-post/

    # <uuid:pk> — UUID format
    path('orders/<uuid:pk>/', views.order_detail, name='order_detail'),

    # <path:file_path> — includes '/'
    path('files/<path:file_path>/', views.serve_file, name='serve_file'),
    # /files/images/2026/photo.jpg → file_path='images/2026/photo.jpg'
]
```

### Two-level URLconf — include()

```python
# hello_project/urls.py (main)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    # include() connects another app's URLconf
    path('', include('hello_app.urls', namespace='hello_app')),
    # '' → all URLs without a prefix go to hello_app.urls
    # namespace='hello_app' → for {% url 'hello_app:index' %}

    # Or with a prefix:
    path('notes/', include('hello_app.urls', namespace='hello_app')),
    # Then /notes/ + '' (in hello_app.urls) = /notes/
]
```

```python
# hello_app/urls.py (modular)
from django.urls import path
from . import views

app_name = 'hello_app'   # ← Required when include() has a namespace!
# Without app_name: ImproperlyConfigured: Specifying a namespace in include() without providing an app_name

urlpatterns = [
    path('', views.index, name='index'),        # ← '' here
    path('about/', views.about, name='about'),
]
```

### reverse() — generating URLs programmatically

```python
# In a view:
from django.urls import reverse
from django.shortcuts import redirect

def some_view(request):
    # Instead of hardcoding '/notes/':
    url = reverse('hello_app:note_list')
    return redirect(url)

# Or directly:
return redirect('hello_app:note_list')

# In a template:
# {% url 'hello_app:note_detail' pk=note.pk %}
# → /notes/42/
```

**Why `reverse()` instead of hardcoding `/notes/`?**
If you change a URL in `urls.py`, `reverse()` automatically generates the new URL.
With a hardcoded `/notes/` → you have to search and replace throughout the code.

---

## Step 9 — Check it in the browser

```bash
python manage.py runserver
```

| URL | Result | HTTP code |
|-----|-----------|----------|
| `http://localhost:8000/` | `Hello, Django!` | 200 |
| `http://localhost:8000/about/` | `Це моя перша сторінка на Django!` | 200 |
| `http://localhost:8000/admin/` | Admin panel (login page) | 200 |
| `http://localhost:8000/nonexistent/` | 404 Not Found | 404 |

### Table of file changes after steps 7-9

| File | What you did |
|------|-------------|
| `hello_project/settings.py` | Added `'hello_app'` to `INSTALLED_APPS` |
| `hello_app/views.py` | Wrote the functions `index()` and `about()` |
| `hello_app/urls.py` | Created the file with `app_name` and routes |
| `hello_project/urls.py` | Connected the routes via `include()` |
