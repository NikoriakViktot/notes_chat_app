# Templates

> `HttpResponse("text")` is the simplest response.
> But a real Django project uses **templates** (HTML files):
> ```python
> # Instead of HttpResponse("text")
> return render(request, 'hello_app/note_list.html', {'notes': notes})
> ```
> This page will teach you how to build public HTML pages with data from the DB.

---

## How data travels to the browser

```
Browser GET /notes/
    ↓ urls.py finds the route
    ↓ views.py gets data from the DB via the ORM
    ↓ templates/hello_app/note_list.html renders HTML
    ↓ HttpResponse → browser
```

This is Django's **MVT architecture**:
- **M** (Model) — `Note` in `models.py` — stores the data
- **V** (View) — `note_list` in `views.py` — gets the data and decides what to show
- **T** (Template) — `note_list.html` — renders HTML

---

## Step C1 — Create a folder for templates

Django looks for templates in the `<app>/templates/<app>/` folder.
This doubling (`hello_app/templates/hello_app/`) is needed to avoid
name conflicts between different apps.

The structure you need to create:

```
hello_app/
└── templates/
    └── hello_app/
        └── note_list.html    ← we will create this file below
```

**Command for creating the folders:**

```bash
# Windows PowerShell
mkdir hello_app\templates\hello_app

# Linux / Mac
mkdir -p hello_app/templates/hello_app
```

---

## Step C2 — Create the note_list.html template

Create the file `hello_app/templates/hello_app/note_list.html`:

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

    {# if notes — check whether there are notes in the list #}
    {# 'notes' — the name of the variable the view passes in (context['notes']) #}
    {% if notes %}

        {# for note in notes — loop over every note in the list #}
        {% for note in notes %}
        <div class="note">
            <!-- {{ note.title }} — outputs the value of the note object's title field -->
            <h2>{{ note.title }}</h2>

            {% if note.content %}
                <p>{{ note.content }}</p>
            {% endif %}

            <!--
                {{ note.created_at|date:"d.m.Y H:i" }}
                |date:"format" — a filter for formatting a date
            -->
            <p class="date">{{ note.created_at|date:"d.m.Y H:i" }}</p>
        </div>
        {% endfor %}

    {% else %}
        <!-- Shown if there are no notes -->
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

## Step C3 — Add a view function to views.py

Open `hello_app/views.py` and **add** a new function (do not replace the existing ones):

```python
from django.http import HttpResponse
from django.shortcuts import render   # ← add render to the import
from .models import Note              # ← import the model


def index(request):
    """Home page."""
    return HttpResponse("Hello, Django!")


def about(request):
    """The 'About us' page."""
    return HttpResponse("Це моя перша сторінка на Django!")


def note_list(request):
    """
    A page with the list of notes.

    What happens:
    1. Note.objects.all() — SELECT * FROM hello_app_note ORDER BY created_at DESC
       (the DESC order is set in class Meta: ordering = ['-created_at'])
    2. render() — takes the template, fills in the data (context) and returns HTML
    """

    # ORM query: get all notes from the DB
    # The result is a QuerySet: a lazy list of Note objects
    notes = Note.objects.all()

    # context — a dict of data we pass to the template
    # The key 'notes' → in the template: {{ notes }}, {% for note in notes %}
    context = {
        'notes': notes,
    }

    # render(request, 'path/to/template', context)
    # Django looks for the template in hello_app/templates/hello_app/note_list.html
    return render(request, 'hello_app/note_list.html', context)
```

---

## Step C4 — Add a URL route to hello_app/urls.py

```python
from django.urls import path
from . import views

app_name = "hello_app"

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
    path('notes/', views.note_list, name='note_list'),   # ← ADD THIS LINE
]
```

> `path('notes/', views.note_list)` — a request to `/notes/` → calls `views.note_list`

---

## Step C5 — Check it in the browser

```bash
python manage.py runserver
```

| URL | Result |
|-----|-----------|
| http://127.0.0.1:8000/notes/ | A styled list of notes |
| http://127.0.0.1:8000/admin/hello_app/note/add/ | Add a note via the admin |

**Add a few notes via the admin → refresh `/notes/` — they will appear on the page.**

---

## Final structure after templates

```
hello_app/
├── models.py          ← Note model
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

## The full path of a GET /notes/ request, step by step

```
1. Browser: GET http://127.0.0.1:8000/notes/

2. Django: reads ROOT_URLCONF = 'hello_project.urls'
           hello_project/urls.py → include('hello_app.urls')
           hello_app/urls.py → path('notes/', views.note_list)

3. views.note_list(request) is called:
           Note.objects.all()
           → SQL: SELECT * FROM hello_app_note ORDER BY created_at DESC
           → returns a QuerySet [<Note: ...>, ...]

4. render(request, 'hello_app/note_list.html', {'notes': queryset})
           Django finds the template: hello_app/templates/hello_app/note_list.html
           Fills in the data: {% for note in notes %} → HTML lines

5. HttpResponse(HTML) → the browser renders the page
```

---

## What's next with templates

At this step, the template is a single file with no hierarchy.
In **Step 4 (Templates and Forms)** you will build:

```
base.html              ← a shared HTML skeleton (navbar, footer)
layouts/dashboard.html ← a SaaS dashboard layout
pages/note_list.html   ← a specific page inherits from dashboard
```

Crispy Forms, Bootstrap 5, Context Processors — it is all there.
