# Частина II. Django Core

Django — це конвеєр: HTTP-запит проходить через middleware → URL dispatcher → view → response. Ця частина формує ментальну модель цього конвеєра.

**Передумови:** Частина I (HTTP).
**Рівень:** Beginner.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Архітектура Django](django_architecture_full.md) | MTV патерн, settings, INSTALLED_APPS, lifecycle overview |
| [URL Routing](url_routing_full.md) | `urlpatterns`, `path()`, `include()`, `name=`, `reverse()`, namespace |
| [Views](views_full.md) | FBV vs CBV, `request` object, `HttpResponse`, `render()`, `redirect()` |
| [Request Lifecycle](request_lifecycle.md) | middleware pipeline, exception handling, response lifecycle |
| [WSGI vs ASGI](wsgi_vs_asgi.md) | sync vs async entrypoint, Daphne, ProtocolTypeRouter |
| [Структура проєкту](project_structure_full.md) | де що лежить, settings split, `manage.py` |
| [Management Commands](management_commands_full.md) | `runserver`, `migrate`, `shell`, `createsuperuser`, кастомні команди |
| [Діаграми](django_mermaid_full.md) | Mermaid-схеми MTV, middleware, URL routing |

---

## Ключові концепти

**MTV (Model-Template-View):**

```
URL → View → Model (ORM)
           → Template (HTML render)
           → HttpResponse
```

**Request lifecycle через middleware:**

```python
# settings.py MIDDLEWARE (порядок має значення)
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
    path('', include('notes_app.urls')),    # всі маршрути notes_app
]

# notes_app/urls.py
path('notes/', views.note_list, name='note_list'),
path('notes/<int:pk>/edit/', views.note_edit, name='note_edit'),
```

**View:**

```python
# FBV — явний GET/POST
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

## WSGI vs ASGI у Notes Chat App

| | WSGI | ASGI |
|-|------|------|
| Entrypoint | `wsgi.py` | `asgi.py` |
| Server | Gunicorn, uWSGI | Daphne, Uvicorn |
| WebSocket | ❌ | ✅ |
| Async views | обмежено | ✅ |
| Notes Chat App | ✅ (використовує ASGI) | `notes_project/asgi.py` |

```python
# notes_project/asgi.py
application = ProtocolTypeRouter({
    "http":      get_asgi_application(),
    "websocket": AuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_project/settings.py` | `INSTALLED_APPS`, `MIDDLEWARE`, `DATABASES`, `CHANNEL_LAYERS` |
| `notes_project/urls.py` | root URLconf — `admin`, `accounts`, `include(notes_app.urls)` |
| `notes_app/urls.py` | 35+ маршрутів застосунку |
| `notes_app/views.py` | 30+ FBV, всі з `@login_required` |
| `notes_project/asgi.py` | ASGI entrypoint з `ProtocolTypeRouter` |

---

## Педагогічний зв'язок

```text
Частина I: HTTP request → Django entrypoint (WSGI/ASGI)
Частина II: middleware → URL → view → response
Частина III: view → Model/ORM → DB
Частина IV: view → Form → validation → service
Частина V: view → Template → HTML
```

**Zero to Hero:** Крок 1 — перший `urlpatterns` і перший `view`. Крок 3 — розуміння thin view через selector + service.

---

## Практика

1. Додай URL `/hello/` → view що повертає `HttpResponse("Привіт!")`. Перевір у браузері.
2. Змінити view щоб повертав `render(request, 'hello.html', {'name': 'World'})`. Створи шаблон.
3. Виконай `python manage.py shell` → `from notes_app.models import Note; Note.objects.count()`.
4. Подивись у DevTools на CSRF-token у POST-запиті до форми.

---

## Контрольні питання

- Що таке MTV і чим він відрізняється від MVC? Де у Django "Controller"?
- Що відбувається якщо middleware повертає `HttpResponse` без виклику `get_response`?
- Чому `SecurityMiddleware` повинен бути першим у `MIDDLEWARE`?
- Що таке PRG (Post-Redirect-Get)? Навіщо він потрібен?
- Яка різниця між `render()` і `redirect()`?
- Коли варто використовувати CBV замість FBV?
- Чому Notes Chat App використовує ASGI замість WSGI?

---

**Далі →** [Частина III. Models, Database та ORM](../03_database_and_orm/README.md) — де зберігаються дані.
