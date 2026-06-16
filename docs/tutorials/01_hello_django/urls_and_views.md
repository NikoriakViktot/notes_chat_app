# URLs та Views

> Тут ти напишеш перші view-функції та URL-маршрути.
> Це серце Django — код який приймає запит і повертає відповідь.

---

## Крок 7 — Написати view-функції

Відкрий `hello_app/views.py`:

```python
from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    """Головна сторінка."""
    return HttpResponse("Hello, Django!")


def about(request):
    """Сторінка про нас."""
    return HttpResponse("Це моя перша сторінка на Django!")
```

### Анатомія view-функції

```python
def index(request):
    #       ↑
    #  HttpRequest object — містить:
    #    request.method   → 'GET', 'POST', 'PUT', 'DELETE'
    #    request.GET      → QueryDict: параметри ?q=search&page=2
    #    request.POST     → QueryDict: тіло POST форми
    #    request.user     → залогінений User або AnonymousUser
    #    request.session  → dict-like: сесія юзера
    #    request.META     → HTTP заголовки: REMOTE_ADDR, HTTP_HOST...
    #    request.FILES    → завантажені файли
    #    request.COOKIES  → cookies браузера

    return HttpResponse("Hello!")
    #         ↑
    #  HttpResponse — відповідь браузеру:
    #    status_code=200 (за замовчуванням)
    #    content_type='text/html; charset=utf-8'
    #    тіло: 'Hello!'
```

### Типи відповідей

```python
from django.http import (
    HttpResponse,            # 200 OK з будь-яким вмістом
    HttpResponseRedirect,    # 302 Redirect
    Http404,                 # кидається як виняток → 404 сторінка
    JsonResponse,            # 200 OK з JSON тілом
)
from django.shortcuts import render, redirect, get_object_or_404

# Найчастіші у views.py:
return render(request, 'hello_app/index.html', {'key': value})
# → рендерить HTML шаблон з контекстом → 200

return redirect('hello_app:note_list')
# → 302 Redirect на URL з reverse()

return redirect('hello_app:note_detail', pk=42)
# → 302 Redirect з аргументом

raise Http404("Не знайдено")
# → Django повертає 404 сторінку

note = get_object_or_404(Note, pk=pk)
# → Note.objects.get(pk=pk) але замість DoesNotExist → Http404
```

---

## Крок 8 — URL-маршрути

Створи новий файл `hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = "hello_app"    # ← Простір імен (namespace)

urlpatterns = [
    path('', views.index, name='index'),        # → /
    path('about/', views.about, name='about'),  # → /about/
]
```

**Навіщо `app_name`?** Без нього посилання `{% url 'hello_app:index' %}` не працює.
Django кидає: `ImproperlyConfigured: Specifying a namespace in include() without providing an app_name`

Підключи до головного `hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
    #     ↑                              ↑
    #   порожній префікс →           простір імен для {% url %}
    #   URLs з hello_app починаються
    #   одразу від кореня /
]
```

### Як Django знаходить view для запиту GET /about/

```
GET /about/
    ↓
hello_project/urls.py:
  path('', include('hello_app.urls', ...))
  → prefix '' → PASS

hello_app/urls.py:
  path('about/', views.about, name='about')
  → 'about/' == 'about/' → MATCH!

views.about(request) викликається
  → HttpResponse("Це моя перша сторінка...")
```

---

## 05 · URL Patterns — детально

### Анатомія path()

```python
from django.urls import path, include, re_path
from . import views

urlpatterns = [
    # path(route, view, kwargs=None, name=None)
    path('about/', views.about, name='about'),
    #      ↑          ↑               ↑
    #   рядок URL   callable        унікальне ім'я маршруту
]
```

### Path Converters — захоплення значень з URL

```python
urlpatterns = [
    # <int:pk> — захопити ціле число
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    # /notes/42/ → view отримує pk=42

    # <str:username> — захопити рядок (не включає '/')
    path('users/<str:username>/', views.user_profile, name='user_profile'),
    # /users/alice/ → view отримує username='alice'

    # <slug:slug> — тільки букви, цифри, тире
    path('articles/<slug:slug>/', views.article, name='article'),
    # /articles/my-first-post/

    # <uuid:pk> — UUID формат
    path('orders/<uuid:pk>/', views.order_detail, name='order_detail'),

    # <path:file_path> — включає '/'
    path('files/<path:file_path>/', views.serve_file, name='serve_file'),
    # /files/images/2026/photo.jpg → file_path='images/2026/photo.jpg'
]
```

### Дворівнева URLconf — include()

```python
# hello_project/urls.py (головний)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    # include() підключає URLconf іншого додатку
    path('', include('hello_app.urls', namespace='hello_app')),
    # '' → всі URL без префікса йдуть в hello_app.urls
    # namespace='hello_app' → для {% url 'hello_app:index' %}

    # Або з префіксом:
    path('notes/', include('hello_app.urls', namespace='hello_app')),
    # Тоді /notes/ + '' (в hello_app.urls) = /notes/
]
```

```python
# hello_app/urls.py (модульний)
from django.urls import path
from . import views

app_name = 'hello_app'   # ← Обов'язково коли є namespace в include()!
# Без app_name: ImproperlyConfigured: Specifying a namespace in include() without providing an app_name

urlpatterns = [
    path('', views.index, name='index'),        # ← '' тут
    path('about/', views.about, name='about'),
]
```

### reverse() — програмна генерація URL

```python
# У view:
from django.urls import reverse
from django.shortcuts import redirect

def some_view(request):
    # Замість хардкоду '/notes/':
    url = reverse('hello_app:note_list')
    return redirect(url)

# Або напряму:
return redirect('hello_app:note_list')

# У шаблоні:
# {% url 'hello_app:note_detail' pk=note.pk %}
# → /notes/42/
```

**Навіщо `reverse()` замість хардкоду `/notes/`?**
Якщо змінити URL у `urls.py` — `reverse()` автоматично генерує новий URL.
З хардкодом `/notes/` → потрібно шукати і замінювати по всьому коду.

---

## Крок 9 — Перевірити в браузері

```bash
python manage.py runserver
```

| URL | Результат | HTTP код |
|-----|-----------|----------|
| `http://localhost:8000/` | `Hello, Django!` | 200 |
| `http://localhost:8000/about/` | `Це моя перша сторінка на Django!` | 200 |
| `http://localhost:8000/admin/` | Адмін-панель (сторінка логіну) | 200 |
| `http://localhost:8000/nonexistent/` | 404 Not Found | 404 |

### Таблиця змін у файлах після кроків 7-9

| Файл | Що ти зробив |
|------|-------------|
| `hello_project/settings.py` | Додав `'hello_app'` в `INSTALLED_APPS` |
| `hello_app/views.py` | Написав функції `index()` і `about()` |
| `hello_app/urls.py` | Створив файл з `app_name` і маршрутами |
| `hello_project/urls.py` | Підключив маршрути через `include()` |
