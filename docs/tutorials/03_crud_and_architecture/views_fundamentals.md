# Views детально — повний HTTP цикл

> View — це Python-функція (або клас), яка отримує HTTP-запит і повертає HTTP-відповідь.
> Це єдина точка входу для кожного URL у Django.

---

## Навіщо views — HTTP Request/Response цикл

```
Браузер → HTTP Request → Django → View → HTTP Response → Браузер
```

Кожен клік на посилання або submit форми — це HTTP запит. Django зіставляє URL з view функцією через `urls.py` і передає їй об'єкт `request`. View обробляє запит і повертає відповідь.

```python
# Найпростіший view — приймає request, повертає response
from django.http import HttpResponse

def hello(request):
    return HttpResponse("Hello, Django!")  # 200 OK + текст
```

```
GET /hello/  →  Django → hello(request)  →  200 OK "Hello, Django!"
```

Але у реальних застосунках view робить більше:
- Перевіряє автентифікацію (`@login_required`)
- Читає GET/POST параметри
- Викликає селектори (читання з БД) і сервіси (зміни у БД)
- Рендерить HTML шаблон або повертає JSON
- Редіректить після успішного POST (PRG паттерн)

---

## Об'єкт `request` — все що надійшло від браузера

`request` — екземпляр `HttpRequest`. Він містить все що браузер надіслав:

```python
@login_required
def note_create(request):
    # Метод HTTP запиту:
    request.method        # → 'GET', 'POST', 'PUT', 'DELETE'

    # Поточний авторизований юзер (заповнюється AuthMiddleware):
    request.user          # → User об'єкт або AnonymousUser
    request.user.is_authenticated  # → True/False

    # GET параметри (?q=python&tag=5):
    request.GET           # → QueryDict {'q': ['python'], 'tag': ['5']}
    request.GET.get('q', '')  # → 'python' (None якщо немає)
    request.GET.getlist('ids') # → ['1', '2', '3'] якщо ids=1&ids=2&ids=3

    # POST параметри (тіло форми):
    request.POST          # → QueryDict {'title': ['Нотатка'], 'priority': ['2']}
    request.POST.get('title', '')  # → 'Нотатка'

    # Завантажені файли:
    request.FILES         # → MultiValueDict {'avatar': [<InMemoryUploadedFile>]}

    # Cookies браузера (словник):
    request.COOKIES       # → {'sessionid': 'abc123', 'csrftoken': 'xyz456'}

    # HTTP заголовки:
    request.headers       # → {'Host': 'localhost', 'Accept': 'text/html', ...}
    request.META.get('HTTP_REFERER', '')  # → URL попередньої сторінки

    # Поточний URL (без GET параметрів):
    request.path          # → '/notes/new/'

    # AJAX перевірка (якщо fetch/axios надсилає заголовок):
    request.headers.get('X-Requested-With') == 'XMLHttpRequest'
```

**Чому `request.POST` а не `request.body.decode()`?**

`request.POST` — це вже розпарсений `QueryDict` з `application/x-www-form-urlencoded` тіла. `request.body` — сирий байтовий рядок. Для JSON API використовують `json.loads(request.body)`, але для HTML форм — завжди `request.POST`.

---

## Типи HTTP відповідей

### `render()` — HTML сторінка

```python
from django.shortcuts import render

def note_list(request):
    notes = Note.objects.filter(user=request.user)

    return render(
        request,                        # 1. request (обов'язковий)
        'notes_app/note_list.html',     # 2. шлях до шаблону
        {'notes': notes, 'count': notes.count()},  # 3. context (словник)
        # status=200,                   # 4. HTTP статус (за замовчуванням 200)
    )

# render() = TemplateResponse:
#   1. Знаходить шаблон за шляхом
#   2. Рендерить Django Template з context
#   3. Повертає HttpResponse з Content-Type: text/html
```

**Перевірка:**
```bash
curl -I http://localhost:8001/notes/
# HTTP/1.1 200 OK
# Content-Type: text/html; charset=utf-8
```

### `redirect()` — перенаправлення

```python
from django.shortcuts import redirect

# Редіректити за URL-назвою (рекомендовано — не залежить від реального URL)
return redirect('notes_app:note_list')
# → HTTP/1.1 302 Found + Location: /notes/

# Редіректити за URL з аргументами:
return redirect('notes_app:note_detail', pk=note.pk)
# → HTTP/1.1 302 Found + Location: /notes/42/

# Редіректити за рядком URL (хардкод — не рекомендовано):
return redirect('/notes/')

# Постійний редірект (301, для SEO):
return redirect('notes_app:note_list', permanent=True)
# → HTTP/1.1 301 Moved Permanently
```

**301 vs 302:**

| Код | Назва | Коли |
|-----|-------|------|
| `302` | Found (тимчасовий) | Після POST (PRG паттерн), після логіну |
| `301` | Moved Permanently | URL назавжди змінився (SEO, старі посилання) |

Браузер кешує 301. Якщо зробиш 301 випадково — браузер буде кешувати назавжди. У розробці завжди 302.

### `HttpResponse` — довільна відповідь

```python
from django.http import HttpResponse, HttpResponseNotFound, HttpResponseForbidden

# Простий текст:
return HttpResponse("OK", status=200)

# JSON (краще: JsonResponse):
import json
return HttpResponse(
    json.dumps({'status': 'ok'}),
    content_type='application/json',
    status=200,
)

# 404 вручну (краще: raise Http404):
return HttpResponseNotFound("Сторінку не знайдено")

# 403 вручну:
return HttpResponseForbidden("Доступ заборонено")
```

### `JsonResponse` — JSON API

```python
from django.http import JsonResponse

def api_notes(request):
    notes = Note.objects.filter(user=request.user).values('id', 'title', 'priority')
    return JsonResponse(
        {'notes': list(notes)},   # ← автоматично json.dumps()
        status=200,
    )
# → HTTP/1.1 200 OK + Content-Type: application/json
# → {"notes": [{"id": 1, "title": "Назва", "priority": 2}]}
```

### `Http404` — сторінка не знайдена

```python
from django.http import Http404

def note_detail(request, pk):
    try:
        note = Note.objects.get(pk=pk, user=request.user)
    except Note.DoesNotExist:
        raise Http404("Нотатку не знайдено")
    # → 404 Not Found + шаблон templates/404.html

# Або скорочено — get_object_or_404:
from django.shortcuts import get_object_or_404
note = get_object_or_404(Note, pk=pk, user=request.user)
# Якщо Note не існує → автоматично 404
```

---

## PRG Pattern — Post/Redirect/Get

**Проблема без PRG:**
```
POST /notes/new/ (форма)
→ View зберігає нотатку
→ render() 200 OK (HTML з "Збережено!")
→ Браузер показує сторінку
→ F5 (оновити)
→ Браузер запитує: "Повторити POST запит?"
→ Якщо "Так" → нотатка створюється ДВІЧІ! Дублікат.
```

**З PRG (Post/Redirect/Get):**
```
POST /notes/new/ (форма)
→ View зберігає нотатку
→ redirect() 302 → /notes/42/   ← REDIRECT після успішного POST!
→ Браузер виконує GET /notes/42/
→ View рендерить нотатку
→ F5 → повторює GET /notes/42/ → безпечно
```

```python
# PRG паттерн — обов'язковий стандарт для форм
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
        # is_valid() = False → fall through → render форму з помилками
    else:
        form = NoteForm(user=request.user)  # GET: порожня форма

    return render(request, 'notes_app/note_form.html', {
        'form': form,
        'title': 'Нова нотатка',
        'action': 'Створити',
    })
```

**Діаграма потоку:**

```
GET /notes/new/
    │
    ▼
form = NoteForm(user=request.user)  ← порожня форма
    │
    ▼
render(note_form.html, {'form': form})  ← 200 OK

Студент заповнює і натискає Submit:

POST /notes/new/
    │
    ▼
form = NoteForm(request.POST, user=request.user)
    │
    ├── is_valid() = False
    │       │
    │       └── render(note_form.html, {'form': form})  ← 200 OK з помилками
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

## `get_object_or_404()` — безпечне отримання об'єкта

```python
from django.shortcuts import get_object_or_404

# Базовий синтаксис:
note = get_object_or_404(Note, pk=pk)
# SQL: SELECT * FROM note WHERE id=42
# Якщо не знайдено → Http404 (403 = видно хто запитував неіснуючий запис)

# З перевіркою прав (ОБОВ'ЯЗКОВО для приватних даних!):
note = get_object_or_404(Note, pk=pk, user=request.user)
# SQL: SELECT * FROM note WHERE id=42 AND user_id=<current_user_id>
# Якщо Alice запитує нотатку Bob'а → 404 (не 403!) → Alice не знає чи є ця нотатка взагалі
```

**Чому 404 а не 403 для чужих об'єктів?**

```
403 Forbidden: "у тебе немає прав"
→ Alice знає що id=42 EXISTS (просто не має доступу)
→ Витік інформації: зловмисник перебирає id і знає які існують

404 Not Found: "не знайдено"  (але насправді exists, просто не твій)
→ Alice не знає чи є id=42 взагалі
→ Немає витоку інформації про чужі дані
```

**Варіанти синтаксису:**

```python
# 1. За pk через позиційний аргумент:
note = get_object_or_404(Note, pk=pk)

# 2. За queryset — більш гнучко (дозволяє filter, select_related):
note = get_object_or_404(
    Note.objects.select_related('notebook', 'user'),
    pk=pk,
    user=request.user,
)

# 3. З Q-фільтром (групові нотатки — або мої, або спільні):
from django.db.models import Q
user_groups = request.user.groups.all()
note = get_object_or_404(
    Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
    pk=pk,
)
```

---

## Messages Framework — одноразові повідомлення

Django Messages дозволяє передати повідомлення **через redirect**. Повідомлення зберігається у сесії і відображається один раз при наступному рендері.

```python
from django.contrib import messages

# Типи повідомлень:
messages.success(request, 'Нотатку створено!')       # зелений
messages.error(request, 'Помилка при збереженні.')   # червоний
messages.warning(request, 'Нотатку видалено.')        # жовтий
messages.info(request, 'Для початку — авторизуйся.') # синій

# В шаблоні (base.html або layouts/dashboard.html):
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
# settings.py — маппінг рівнів на Bootstrap класи:
from django.contrib.messages import constants as messages_constants
MESSAGE_TAGS = {
    messages_constants.DEBUG:   'secondary',
    messages_constants.INFO:    'info',
    messages_constants.SUCCESS: 'success',
    messages_constants.WARNING: 'warning',
    messages_constants.ERROR:   'danger',   # Bootstrap: alert-danger
}
```

**Як messages проходять через redirect:**

```
POST /notes/42/delete/
    │
    ├── messages.warning(request, 'Видалено.')   ← зберігається у SESSION
    └── redirect('notes_app:note_list')           ← 302

GET /notes/
    │
    ├── Django вставляє messages з SESSION у context
    └── render(note_list.html)
            │
            └── {% for message in messages %} ← показується ОДИН раз потім видаляється
```

---

## Декоратори для view функцій

### `@login_required`

```python
from django.contrib.auth.decorators import login_required

@login_required
def note_list(request):
    # request.user гарантовано автентифікований тут
    ...

# Що відбувається якщо неавторизований:
# → redirect '/accounts/login/?next=/notes/'
# Після логіну → redirect назад до '/notes/'
```

```python
# Змінити URL логіну (якщо не стандартний):
@login_required(login_url='/auth/login/')
def note_list(request):
    ...

# Або глобально в settings.py:
LOGIN_URL = '/accounts/login/'
```

### `@require_http_methods` / `@require_POST`

```python
from django.views.decorators.http import require_POST, require_GET, require_http_methods

# Тільки POST (наприклад, для видалення або toggle):
@login_required
@require_POST
def note_pin(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    services.toggle_pin(note)
    return redirect('notes_app:note_detail', pk=pk)

# GET запит до цього view → 405 Method Not Allowed

# Або через декоратор методів:
@require_http_methods(['GET', 'POST'])
def note_create(request):
    ...
# PUT, DELETE → 405
```

### Порядок декораторів

```python
# ❌ НЕПРАВИЛЬНО: login_required перевіряє після require_POST
@require_POST
@login_required
def note_delete(request, pk):
    ...

# Анонімний GET → require_POST: 405 (не 302 до логіну!)

# ✅ ПРАВИЛЬНО: login_required перший → перевіряє автентифікацію до методу
@login_required
@require_POST
def note_delete(request, pk):
    ...

# Анонімний GET → login_required: 302 до логіну ✓
```

Декоратори застосовуються знизу вгору. `@login_required` над `@require_POST` означає що `login_required` виконується ПЕРШИМ при виклику.

---

## Повний цикл request → response

```
Браузер: POST /notes/new/

     │
     ▼
1. nginx (reverse proxy)
   → проксує до Django/Uvicorn

     │
     ▼
2. Django Middleware (ланцюг, порядок з MIDDLEWARE в settings.py)
   → SecurityMiddleware: перевіряє HTTPS, CSP
   → SessionMiddleware: завантажує session з DB/Redis → request.session
   → AuthenticationMiddleware: session → request.user
   → CsrfViewMiddleware: перевіряє csrfmiddlewaretoken
   → MessageMiddleware: завантажує messages з session

     │
     ▼
3. URL Router (urls.py)
   → path('notes/new/', views.note_create, name='note_create')
   → виклик views.note_create(request)

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
5. Response Middleware (зворотній порядок)
   → MessageMiddleware: зберігає messages у session
   → SessionMiddleware: зберігає session

     │
     ▼
6. HTTP Response → nginx → браузер
   302 Found
   Location: /notes/42/
```

---

## Debugging views

### Типові помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `302` замість `200` на GET | `@login_required` і юзер не залогінений | Залогінитись або перевірити `request.user.is_authenticated` |
| `403 Forbidden` на POST | CSRF токен відсутній або неправильний | Додати `{% csrf_token %}` у форму |
| `404 Not Found` | `get_object_or_404` не знайшов або URL неправильний | Перевірити pk і user у запиті |
| `405 Method Not Allowed` | Неправильний HTTP метод (напр. GET замість POST) | Перевірити `method` атрибут форми |
| `500 Internal Server Error` | Помилка у Python коді view | Читати stack trace у логах Django |
| Форма не зберігається, redirect немає | `is_valid()` повертає False | Додати `print(form.errors)` тимчасово |

### Додати `print` для debugging (тимчасово)

```python
@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        print("POST data:", request.POST)     # ← що надійшло від браузера
        print("Form errors:", form.errors)    # ← чому форма невалідна
        if form.is_valid():
            ...
```

```bash
# Переглянути в логах Docker:
docker compose logs -f web
# → POST data: <QueryDict: {'title': [''], 'priority': ['2'], ...}>
# → Form errors: {'title': ['Це поле обов'язкове.']}
```

### Перевірити у Django shell

```bash
docker compose exec web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.forms import NoteForm

user = User.objects.get(username='demo_alice')

# Симулюємо is_valid() з POST даними:
data = {
    'title': '',        # порожній → помилка
    'priority': '2',
    'csrfmiddlewaretoken': 'fake',  # у shell не перевіряється
}
form = NoteForm(data, user=user)
print(form.is_valid())   # → False
print(form.errors)       # → {'title': ['Це поле обов'язкове.']}

# Валідний POST:
data['title'] = 'Тест'
form = NoteForm(data, user=user)
print(form.is_valid())         # → True
print(form.cleaned_data)       # → {'title': 'Тест', 'priority': 2, ...}
```

---

## Приклад: повний CRUD для тегів (простий case)

Теги — хороший приклад мінімального view: без складних фільтрів, без M:N зв'язків у формі.

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

            # Підтримка ?next= — якщо прийшли зі сторінки нотатки, повертаємось туди
            next_url = request.GET.get('next') or request.POST.get('next')
            return redirect(next_url or 'notes_app:note_list')
    else:
        # Підтримка ?name=python — попередньо заповнює поле
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
        tag.delete()   # простий case — немає services.delete_tag()
        messages.warning(request, f'Тег "{name}" видалено.')
        return redirect('notes_app:tag_list')
    return render(request, 'notes_app/tag_confirm_delete.html', {'tag': tag})
```

**Два цікаві паттерни:**

1. `?next=` для redirect після дії:
```html
<!-- У шаблоні форми нотатки — додаємо тег і повертаємось: -->
<a href="{% url 'notes_app:tag_create' %}?next={{ request.path }}">
    Новий тег
</a>
```

2. `?name=python` для попереднього заповнення:
```html
<!-- Швидке створення тегу з назвою з пошуку: -->
<a href="{% url 'notes_app:tag_create' %}?name={{ search }}">
    Створити тег "{{ search }}"
</a>
```

---

## У книзі

- [Частина II. Django Core](../../02_django_core/README.md) — MTV архітектура, URL routing, view functions, templates, request/response
- [Частина VI. Архітектура застосунку](../../06_application_architecture/README.md) — thin views, services/selectors, PRG паттерн, декоратори

---

## Офіційна документація

- [Django: Request and response objects](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest, HttpResponse, всі атрибути
- [Django: Writing views](https://docs.djangoproject.com/en/5.2/topics/http/views/) — основи
- [Django: Shortcuts](https://docs.djangoproject.com/en/5.2/topics/http/shortcuts/) — render, redirect, get_object_or_404
- [Django: Decorators](https://docs.djangoproject.com/en/5.2/topics/http/decorators/) — login_required, require_http_methods
- [Django: Messages framework](https://docs.djangoproject.com/en/5.2/ref/contrib/messages/) — success, error, warning, info
- [Django: URL dispatcher](https://docs.djangoproject.com/en/5.2/topics/http/urls/) — path(), re_path(), reverse()
- [MDN: HTTP redirects](https://developer.mozilla.org/en-US/docs/Web/HTTP/Redirections) — 301 vs 302 різниця
