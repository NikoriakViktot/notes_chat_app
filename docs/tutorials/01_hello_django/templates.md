# Шаблони

> `HttpResponse("текст")` — найпростіша відповідь.
> Але реальний Django-проєкт використовує **шаблони** (HTML-файли):
> ```python
> # Замість HttpResponse("текст")
> return render(request, 'hello_app/note_list.html', {'notes': notes})
> ```
> Ця сторінка навчить робити публічні HTML-сторінки з даними з БД.

---

## Маршрут даних до браузера

```
Браузер GET /notes/
    ↓ urls.py знаходить маршрут
    ↓ views.py отримує дані з БД через ORM
    ↓ templates/hello_app/note_list.html рендерить HTML
    ↓ HttpResponse → браузер
```

Це і є **MVT архітектура** Django:
- **M** (Model) — `Note` у `models.py` — зберігає дані
- **V** (View) — `note_list` у `views.py` — отримує дані, вирішує що показати
- **T** (Template) — `note_list.html` — рендерить HTML

---

## Крок В1 — Створи папку для шаблонів

Django шукає шаблони в папці `<app>/templates/<app>/`.
Таке подвоєння (`hello_app/templates/hello_app/`) потрібно щоб уникнути
конфліктів назв між різними додатками.

Структура яку потрібно створити:

```
hello_app/
└── templates/
    └── hello_app/
        └── note_list.html    ← цей файл створимо нижче
```

**Команда для створення папок:**

```bash
# Windows PowerShell
mkdir hello_app\templates\hello_app

# Linux / Mac
mkdir -p hello_app/templates/hello_app
```

---

## Крок В2 — Створи шаблон note_list.html

Створи файл `hello_app/templates/hello_app/note_list.html`:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <title>Мої нотатки</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 40px auto; }
        .note { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 4px; }
        .date { color: #888; font-size: 0.85em; }
    </style>
</head>
<body>

    <h1>Нотатки</h1>

    {# if notes — перевіряємо чи є нотатки в списку #}
    {# 'notes' — це ім'я змінної яку передає view (context['notes']) #}
    {% if notes %}

        {# for note in notes — цикл по кожній нотатці зі списку #}
        {% for note in notes %}
        <div class="note">
            <!-- {{ note.title }} — виводить значення поля title об'єкта note -->
            <h2>{{ note.title }}</h2>

            {% if note.content %}
                <p>{{ note.content }}</p>
            {% endif %}

            <!--
                {{ note.created_at|date:"d.m.Y H:i" }}
                |date:"формат" — фільтр для форматування дати
            -->
            <p class="date">{{ note.created_at|date:"d.m.Y H:i" }}</p>
        </div>
        {% endfor %}

    {% else %}
        <!-- Показуємо якщо нотаток немає -->
        <p>Нотаток поки немає.
           <a href="/admin/hello_app/note/add/">Додати в адмін-панелі →</a>
        </p>
    {% endif %}

    <hr>
    <a href="/admin/">← Адмін-панель</a>

</body>
</html>
```

---

## Крок В3 — Додай view функцію у views.py

Відкрий `hello_app/views.py` і **додай** нову функцію (не замінюй існуючі):

```python
from django.http import HttpResponse
from django.shortcuts import render   # ← додай render до імпорту
from .models import Note              # ← імпортуємо модель


def index(request):
    """Головна сторінка."""
    return HttpResponse("Hello, Django!")


def about(request):
    """Сторінка 'Про нас'."""
    return HttpResponse("Це моя перша сторінка на Django!")


def note_list(request):
    """
    Сторінка зі списком нотаток.

    Що відбувається:
    1. Note.objects.all() — SELECT * FROM hello_app_note ORDER BY created_at DESC
       (порядок DESC заданий в class Meta: ordering = ['-created_at'])
    2. render() — бере шаблон, підставляє дані (context) і повертає HTML
    """

    # ORM запит: отримати всі нотатки з БД
    # Результат — QuerySet: лінивий список об'єктів Note
    notes = Note.objects.all()

    # context — словник даних які передаємо в шаблон
    # Ключ 'notes' → в шаблоні: {{ notes }}, {% for note in notes %}
    context = {
        'notes': notes,
    }

    # render(request, 'шлях/до/шаблону', context)
    # Django шукає шаблон в hello_app/templates/hello_app/note_list.html
    return render(request, 'hello_app/note_list.html', context)
```

---

## Крок В4 — Додай URL маршрут у hello_app/urls.py

```python
from django.urls import path
from . import views

app_name = "hello_app"

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
    path('notes/', views.note_list, name='note_list'),   # ← ДОДАЙ ЦЮ СТРОКУ
]
```

> `path('notes/', views.note_list)` — запит на `/notes/` → виклик `views.note_list`

---

## Крок В5 — Перевір у браузері

```bash
python manage.py runserver
```

| URL | Результат |
|-----|-----------|
| http://127.0.0.1:8000/notes/ | Список нотаток зі стилями |
| http://127.0.0.1:8000/admin/hello_app/note/add/ | Додати нотатку через адмін |

**Додай кілька нотаток через адмін → оновлюй `/notes/` — вони з'являться на сторінці.**

---

## Кінцева структура після шаблонів

```
hello_app/
├── models.py          ← Note модель
├── views.py           ← index, about, note_list
├── urls.py            ← /, /about/, /notes/
├── admin.py           ← NoteAdmin
├── migrations/
│   └── 0001_initial.py
└── templates/
    └── hello_app/
        └── note_list.html
```

---

## Повний шлях запиту GET /notes/ крок за кроком

```
1. Браузер: GET http://127.0.0.1:8000/notes/

2. Django: читає ROOT_URLCONF = 'hello_project.urls'
           hello_project/urls.py → include('hello_app.urls')
           hello_app/urls.py → path('notes/', views.note_list)

3. views.note_list(request) викликається:
           Note.objects.all()
           → SQL: SELECT * FROM hello_app_note ORDER BY created_at DESC
           → повертає QuerySet [<Note: ...>, ...]

4. render(request, 'hello_app/note_list.html', {'notes': queryset})
           Django знаходить шаблон: hello_app/templates/hello_app/note_list.html
           Підставляє дані: {% for note in notes %} → HTML рядки

5. HttpResponse(HTML) → браузер рендерить сторінку
```

---

## Що далі з шаблонами

На цьому кроці шаблон — один файл без ієрархії.
У **Кроці 4 (Templates і Forms)** ти побудуєш:

```
base.html              ← спільний HTML-каркас (navbar, footer)
layouts/dashboard.html ← SaaS-dashboard layout
pages/note_list.html   ← конкретна сторінка успадковує dashboard
```

Crispy Forms, Bootstrap 5, Context Processors — все там.
