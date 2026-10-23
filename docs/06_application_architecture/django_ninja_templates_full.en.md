# Django Ninja + Rendering Architecture

> Django Ninja is a fast API framework on top of Django built around Python type hints.
> Even though it is API-oriented, it fully uses the Django rendering engine
> for HTML responses — the same `render()`, `TemplateResponse`, DTL, Jinja2.

---

---
- **🧠 Mental model:** Django Ninja is like FastAPI built into Django. It takes the best of both worlds: Django's powerful ecosystem (ORM, auth, admin, templates) and FastAPI's modern API style (type hints, Pydantic, automatic documentation). Imagine you have a Ferrari (FastAPI), but it drives on Django's mature city infrastructure.
- **📚 Why it exists:** Before Ninja, Django developers had to choose between "full Django" (views, forms, HTML — but building APIs is hard) or "pure DRF" (JSON API — but lots of boilerplate and configuration). Ninja filled this niche: a simple API + full Django support.
- **🌐 What happens under the hood:** Ninja registers itself as an ordinary Django URL route. Django does not know that Ninja is inside. Ninja receives the request, runs its own router, performs Pydantic validation, calls your function, and serializes the response. To Django it is just another view.
- **❌ Common beginner mistake:** Thinking that Ninja "replaces" Django views. No! Ninja and Django views live together. HTML pages go through Django views, the JSON API goes through Ninja. Together they form a complete application.
---

## 0. What is Django Ninja

> Before learning the syntax, it is critically important to understand WHY there are three different ways to build responses in the Django ecosystem and when to choose each of them.

**Django Views = "all in one"**
Traditional Django views handle HTML forms, redirects, messages (the messages framework), sessions — all of this is built in and convenient. They are ideal for classic web applications where the server builds a complete HTML page and the browser simply displays it. If you are building a blog, a CMS, or any site without a mobile app — Django views are the right choice.

**DRF (Django REST Framework) = "pure API"**
DRF ships with a powerful serializers mechanism, a browsable API, detailed permissions, ViewSets and Routers. It is designed for large teams where the frontend (React/Vue) is fully separated from the backend. A large amount of configuration is the price of flexibility. If you have separate frontend and backend teams — DRF is the mature choice.

**Django Ninja = "API with superpowers"**
Ninja uses Python type hints directly. There is no `serializers.py` — just Pydantic classes. There is no `APIView.get()` — just a function. Automatic validation, automatic documentation, high performance. It is ideal for hybrid applications that have both HTML pages (via Django templates) and a JSON API (for a mobile app or HTMX). **This is exactly the architecture we study.**

**When to use Ninja TOGETHER with templates?**
Imagine a notes application: the web browser receives full HTML pages via Django views, the mobile app receives JSON via the Ninja API, and HTMX requests receive HTML fragments via Ninja endpoints with `response=None`. One backend, one Django ORM, one set of models — three "windows" into the data.

### Comparison with Django REST Framework

| | Django (views) | Django Ninja | Django REST Framework |
|-|----------------|-------------|----------------------|
| **Response format** | HTML (SSR) | JSON + HTML | JSON |
| **Validation** | Django Forms | Pydantic v2 | DRF Serializers |
| **API documentation** | None | OpenAPI/Swagger (automatic) | None (requires drf-spectacular) |
| **Type hints** | None | Full support | Partial |
| **Performance** | Medium | High | Medium |
| **HTML templates** | Yes | Yes (via the Django engine) | Rarely |

### The architectural position of Django Ninja

> This diagram shows the most important concept: the same Django server can simultaneously respond with HTML pages (SSR), JSON (API) and HTML fragments (HTMX). Each request type follows its own route, but they all access the same Django models and business logic.

```
Browser/Client
    │
    ├── GET /notes/          →  Django View → render() → HTML (SSR)
    ├── GET /api/notes/      →  Ninja Router → Pydantic → JSON (API)
    ├── POST /api/notes/     →  Ninja Router → Pydantic validation → JSON
    └── GET /notes/42/partial →  Django View → TemplateResponse → HTML fragment (HTMX)
```

---

---
- **🧠 Mental model:** NinjaAPI is the "main dispatcher", and a Router is a "department". You register departments (routers) with the dispatcher, and it knows where to route requests. Django knows nothing at all about Ninja — it only sees `api.urls` as an ordinary set of URL patterns (like `admin.site.urls`).
- **📚 Why it exists:** Ninja has its own routing system, independent of Django URL patterns. This lets it add middleware for validation, automatically build the OpenAPI specification, and run Pydantic checks before the request reaches your code. Django receives an already-processed request.
- **🌐 What happens under the hood:** `api.urls` returns the tuple Django expects, `(list of URL patterns, app_name, namespace)` — the same format as `admin.site.urls`. Inside each URL is Ninja's view function, which runs the router, validates parameters via Pydantic, calls your function and serializes the result.
- **❌ Common beginner mistake:** Trying to add Ninja endpoints directly to `urls.py` as ordinary Django views. Ninja endpoints MUST be registered via `router.get()` / `router.post()` and attached to `NinjaAPI` via `api.add_router()`.
---

## 1. Installation and basic configuration

> Note the difference between `NinjaAPI` (the main object) and `Router` (a modular router for individual resources). There is one `NinjaAPI` per project and one `Router` per "bounded context" or resource (notes, users, tags, etc.). This provides scalability: each developer on the team works with their own router.

> The `path('api/', api.urls)` pattern is the key integration point. You do not add Ninja views to `urlpatterns` one by one. Instead, you hand Django the entire list of Ninja URLs in a single call. Why separate routers for each feature? Because they are "bounded contexts" — each router is responsible for one domain area and can live in a separate file, be tested independently, and be disabled without affecting the others.

```bash
pip install django-ninja
```

> Below is a minimal configuration for connecting Ninja to a Django project. Note: `path('api/', api.urls)` gives Django not one URL but a whole list of URLs (everything you registered in the Ninja routers). The `include_in_schema=False` line on some endpoints later will mean "do not show in Swagger" — useful for HTML endpoints that are not intended for API clients.

```python
# notes_chat_app/urls.py
from django.contrib import admin
from django.urls import path, include
from ninja import NinjaAPI

# Create the API instance
api = NinjaAPI(
    title="Notes API",
    version="1.0.0",
    description="API для управління нотатками",
)

# Attach routers (from separate files)
from notes_app.api import router as notes_router
api.add_router("/notes/", notes_router)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('notes_app.urls')),       # ← HTML views (SSR)
    path('api/', api.urls),                     # ← Ninja API (/api/docs/ — Swagger)
]
```

---

----
- **🧠 Mental model:** `render()` is a microwave: you put the food (context) in, press the button, and get a finished dish (HTML) immediately. `TemplateResponse` is a smart thermostat: it remembers the instructions (template + context) but executes them later, allowing someone along the way to change the settings.
- **📚 Why it exists:** `TemplateResponse` exists so that middleware can modify data BEFORE rendering. Context processors (which add `request.user`, `MEDIA_URL`, etc. to every template) are implemented precisely through this deferred rendering mechanism.
- **🌐 What happens under the hood:** When Django receives a `TemplateResponse` from a view, it checks `response.is_rendered`. If it is `False`, it runs `response.render()`, which calls `template.render(context)`. The entire middleware stack runs before this moment.
- **❌ Common beginner mistake:** Thinking that `TemplateResponse` is always "better" than `render()`. For most views `render()` is simpler and more correct. `TemplateResponse` is needed only when middleware or post-render callbacks must access the unrendered context.
---

## 2. HTML Response Pipeline — how Django Ninja returns HTML

> Before looking at code, let's examine the critical difference between two ways of returning HTML. This is not just a stylistic difference — it is an architectural difference in WHEN the template is compiled.

```
The CRITICAL difference:

render() = EAGER (immediate) — like a microwave
  1. Gets the template file
  2. Compiles it into a Node tree
  3. Renders with context (replaces {{ }}, {% %})
  4. Returns an HttpResponse (done, the HTML is already a string)
  Only after all 4 steps is the response object created

TemplateResponse = LAZY (deferred) — like a smart thermostat
  1. Creates a TemplateResponse object (fast, no rendering!)
  2. Stores template_name and context_data as attributes
  3. Returns the TemplateResponse (the template is NOT compiled YET)
  4. Django calls response.render() LATER (in the middleware stack)
  5. Now the template is compiled

WHY does this matter?
  Middleware gets a chance to CHANGE the context BEFORE rendering:

  render()         → response.content = b"<html>..." (already an HTML string)
  TemplateResponse → response.context_data = {...} (still a dict!)

  So with TemplateResponse:
    your GlobalContextMiddleware can add {'user_count': 42} to the context
    And this user_count will be available in the template via {{ user_count }}
    WITHOUT any changes to the view code

  With render(): too late — the HTML is already a byte string.
```

> Pay attention to the `response=None` line in the Ninja decorators. It tells Ninja: "do not try to serialize the response via Pydantic, I will return an HttpResponse myself". Without `response=None`, Ninja will try to serialize your HttpResponse object to JSON and break.

```python
# notes_app/api.py
from ninja import Router
from django.shortcuts import render, get_object_or_404
from django.http import HttpResponse
from django.template.response import TemplateResponse
from .models import Note

router = Router()
```

#### Path 1: `HttpResponse` with `render()` — immediate compilation

> This endpoint is the simplest way to return HTML from Ninja. `render()` does all the work: it finds the template, compiles it, replaces `{{ notes }}` with real data, and returns a finished HTML string. Note the `Content-Type: text/html` comment — the browser knows this is HTML, not JSON, thanks to this header.

```python
@router.get("/html/", response=None)
def note_list_html(request):
    """
    Returns a full HTML page.
    render() immediately compiles the template and returns a finished HTML string.
    """
    notes = Note.objects.all().order_by('-created_at')
    context = {'notes': notes}

    # render() = load template → compile → render with context → HttpResponse
    return render(request, 'notes_app/note_list.html', context)
    # Content-Type: text/html; charset=utf-8
```

#### Path 2: `TemplateResponse` — deferred compilation

> This endpoint does the same thing, but differently. `TemplateResponse` does NOT compile the template immediately. It stores `template_name` and `context` as attributes of the response object. The Django middleware stack receives this object and can add data (for example, `response.context_data['global_settings'] = ...`) before the template is compiled. To see it for yourself, add `print(response.is_rendered)` before and after `get_response(request)` in a middleware and you will see `False` → `True`.

```python
@router.get("/html/lazy/", response=None)
def note_list_lazy(request):
    """
    TemplateResponse defers the final compilation.
    Template + Context are stored separately until the very end of the pipeline.
    Middleware can modify the context before rendering.
    """
    notes = Note.objects.all()
    context = {'notes': notes}

    # TemplateResponse does NOT compile immediately
    # default content_type: text/html; charset=utf-8
    return TemplateResponse(request, 'notes_app/note_list.html', context)
```

### `render()` vs `TemplateResponse` — the difference under the hood

> This diagram is the most important thing to understand. Focus on the "Middleware stack" arrow: this is exactly where `TemplateResponse` gives middleware the chance to step in. Context processors in Django (the ones that add `request`, `user`, `messages` to every template) are this very mechanism.

```
render():
─────────
View → render(request, 'tmpl.html', context)
              │
              ├── 1. get_template('tmpl.html')  → reads the file from disk (or cache)
              ├── 2. template.render(context)    → compiles → HTML string
              └── 3. return HttpResponse(html)   → the response is ready NOW

TemplateResponse():
───────────────────
View → TemplateResponse(request, 'tmpl.html', context)
              │
              ├── 1. Stores template_name and context (does NOT compile!)
              │
              → Middleware stack (can change response.context_data)
              │
              ├── 2. render()  ← called automatically at the end
              └── 3. return HttpResponse(html)

Advantage of TemplateResponse:
middleware can add data to the context (for example, global settings,
A/B tests, analytics) — without changing the view code.
```

---

---
- **🧠 Mental model:** SSR (Server-Side Rendering) is like ordering a ready-made pizza (HTML) instead of buying ingredients (JSON) and cooking at home (JavaScript). Ninja adds a "bouncer at the door" to this process: Pydantic validation, which checks the request before your code even runs.
- **📚 Why it exists:** MVT (Model-View-Template) is Django's architectural pattern. The Model knows about data, the View knows about business logic, the Template knows about presentation. Ninja fits into this scheme as a "smart dispatcher" in front of the View — it handles validation so the View can focus only on business logic.
- **🌐 What happens under the hood:** Each step in the lifecycle is a separate Django module. Middleware is a chain of wrappers around `get_response` (it works under both WSGI and ASGI). The URL Dispatcher is `URLResolver` (formerly `RegexURLResolver`). The Template Engine is a separate module with its own cache. Understanding this pipeline will help you place logic correctly.
- **❌ Common beginner mistake:** Putting business logic in the template (via template tags or model methods that run queries). All logic belongs in the View. The template only displays ready data.
---

## 3. SSR Architecture — the MVT model in Django Ninja

> The key difference from ordinary Django views: Ninja adds **step 4a** — Pydantic validation of request parameters **before** your function runs. If the URL says `/api/notes/abc/` (a string instead of a number), Ninja returns `422 Unprocessable Entity` automatically — your function never even starts. It is like having a bouncer at a club entrance: without the right ID (the right data type) — you don't get in.

> Step 6 (Template Engine) is especially important for understanding performance. "Compile: HTML text → Node tree (cached after the first time)" means that Django parses `{% for %}`, `{% if %}`, `{{ var }}` only once per server start (in production with cached.Loader). Subsequent requests use the ready Node tree from memory.

### Request Lifecycle — the full path

```
1. Browser: HTTP GET /api/notes/html/
            │
2. Django Middleware Stack (SecurityMiddleware, SessionMiddleware, ...)
            │
3. URL Dispatcher: path('api/', api.urls)
            │
4. Ninja Router: GET "/notes/html/" → note_list_html(request)
            │
5. View (Ninja endpoint):
   ├── ORM: Note.objects.all()  → SQL → Python objects
   ├── context = {'notes': queryset, 'user': request.user}
   └── render(request, 'note_list.html', context)
            │
6. Template Engine:
   ├── Locate: APP_DIRS=True → notes_app/templates/notes_app/note_list.html
   ├── Load: reads the file from disk
   ├── Compile: HTML text → Node tree (cached after the first time)
   ├── Render: replaces {{ notes }}, {% for %}, {% url %} → HTML string
   └── Inherit: {% extends 'base.html' %} → recursive compilation
            │
7. HttpResponse(html_string)
   Content-Type: text/html; charset=utf-8
   Status: 200 OK
            │
8. Middleware Stack (response on the way back)
            │
9. Browser:
   ├── Parse HTML → DOM Tree
   ├── Parse CSS → CSSOM Tree
   ├── Render Tree → Layout → Paint
   └── Request static assets (CSS, JS)
```

### The architectural boundary — where Python "dies"

> This concept is one of the most important in web development. Python objects exist only on the server, in RAM, while the request is being processed. After `render()` they turn into a string of characters (HTML). The browser never sees a Python object — it sees only text. If you need to pass "live" data to the browser (for JavaScript), you need either a JSON API or JSON embedded in the HTML (via `{{ data|json_script }}`).

```python
# View (Python World)
note = Note.objects.get(pk=1)   # Python object with methods
notes = Note.objects.all()       # QuerySet with ORM methods

# After render() this boundary is crossed:
# Python object → "{{ note.title }}" → "My first note"
# QuerySet      → "{% for n in notes %}" → HTML lines

# The browser receives only:
# <h1>My first note</h1>
# Python objects no longer exist in the response context
```

---

---
- **🧠 Mental model:** The same Django model, two "lenses". The JSON endpoint is a microscope for machines (structured data, precise types). The HTML endpoint is a shop window for people (a nice interface, navigation, styles). The "collection" itself (the database) is one.
- **📚 Why it exists:** Content negotiation is a concept where one resource can be served in different formats depending on who is asking. In some frameworks (for example DRF) one endpoint can return both HTML and JSON depending on the `Accept` header. Ninja deliberately splits them into separate endpoints — this is cleaner, easier to test, and less magical.
- **🌐 What happens under the hood:** When a Ninja endpoint returns `Note.objects.all()` (a QuerySet), Ninja calls Pydantic `NoteOut.from_orm(note)` for each object, then `json.dumps()` for the whole list. Content-Type is automatically set to `application/json`.
- **❌ Common beginner mistake:** Forgetting `response=None` for HTML endpoints. Without it, Ninja tries to serialize the `HttpResponse` object to JSON — and gets an error or an empty response. `response=None` tells Ninja: "trust me, I'll return an HttpResponse myself".
---

## 4. JSON API vs HTML Endpoints — comparison

> Note the key architectural idea: the mobile app and the web browser access one database, through the same Django models, but get different "windows" into the data. The mobile app receives clean JSON and builds its own UI (Swift/Kotlin). The browser receives ready HTML. Both endpoints can live in one `api.py` file and share common business logic.

> The notion of "content negotiation" matters here: in some systems the same URL returns JSON or HTML depending on the `Accept: application/json` vs `Accept: text/html` header. Ninja deliberately does not do this — each endpoint has its own URL. Explicit instead of implicit: easier to understand when debugging.

### The same resource, two formats

> Below is the most important example of this section. Note that both endpoints (`note_list_json` and `note_list_html`) access the same `Note.objects.all()` — one piece of business logic. But `note_list_json` returns `List[NoteOut]` (Pydantic serializes to JSON), while `note_list_html` returns `render(...)` (the Django Template Engine builds HTML). This is the essence of the hybrid architecture.

```python
# notes_app/api.py
from ninja import Router, Schema
from typing import List
from datetime import datetime

router = Router()

# Schema — a Pydantic model for JSON serialization
class NoteOut(Schema):
    id: int
    title: str
    content: str
    created_at: datetime

class NoteIn(Schema):
    title: str
    content: str = ""


# ─── JSON API endpoint ────────────────────────────────────────────
@router.get("/", response=List[NoteOut])
def note_list_json(request):
    """
    JSON API: returns structured data.
    Pydantic automatically serializes QuerySet → JSON.
    Swagger is available at /api/docs/
    """
    return Note.objects.all().order_by('-created_at')
    # Response: [{"id": 1, "title": "...", "content": "...", "created_at": "..."}]
    # Content-Type: application/json


@router.get("/{note_id}/", response=NoteOut)
def note_detail_json(request, note_id: int):
    """Path parameter — automatic validation (int, not string)"""
    note = get_object_or_404(Note, pk=note_id)
    return note


@router.post("/", response=NoteOut)
def note_create_json(request, data: NoteIn):
    """
    POST with Pydantic validation.
    data.title, data.content — already validated and typed.
    """
    note = Note.objects.create(
        title=data.title,
        content=data.content,
    )
    return note  # → automatically serialized via NoteOut


# ─── HTML endpoint ────────────────────────────────────────────────
@router.get("/html/", response=None)
def note_list_html(request):
    """HTML endpoint — returns a full page for the browser"""
    notes = Note.objects.all().order_by('-created_at')
    return render(request, 'notes_app/note_list.html', {'notes': notes})
```

### Comparison table

| | JSON API | HTML (SSR) |
|-|----------|-----------|
| **Content-Type** | `application/json` | `text/html` |
| **Who renders the UI** | JavaScript (React/Vue/HTMX) | Django Template Engine |
| **Navigation** | AJAX (no reload) | Full page reload |
| **SEO** | Poor (crawlers do not run JS) | Excellent (ready HTML) |
| **First Contentful Paint** | Slower (JS is needed) | Faster |
| **Interactivity** | High (SPA) | Limited (without JS) |
| **Caching** | CDNs cache JSON easily | CDNs cache HTML |
| **For mobile** | Saves traffic | Larger payload |

---

---
- **🧠 Mental model:** HTMX is "teleportation of HTML fragments". Instead of JavaScript requesting data (JSON) and building the DOM manually, HTMX asks the server "give me a ready HTML chunk" and puts it in place. You write Python + Django templates, and interactivity is added with HTML attributes, without a single line of JS code.
- **📚 Why it exists:** The traditional approach to interactivity requires: learning JavaScript, learning React/Vue, setting up a build (webpack/vite), keeping state synchronized between frontend and backend. HTMX offers an alternative: if your server already renders HTML (Django templates), let it render fragments for dynamic updates as well. Much less complexity.
- **🌐 What happens under the hood:** HTMX is a 14KB JavaScript library that listens to HTML attributes (`hx-get`, `hx-post`, `hx-target`, `hx-trigger`) and performs AJAX requests on your behalf. When it receives HTML in response, it replaces the DOM node specified in `hx-target`.
- **❌ Common beginner mistake:** Returning a full HTML page (with `<!DOCTYPE html>`, `<head>`, `<body>`) in response to an HTMX request. HTMX expects only a fragment — the part of the DOM to insert. A full page in the response results in "HTML inside HTML" and breaks the layout.
---

## 5. Hybrid architecture — SSR + API + HTMX

> Let's examine the key mental shift from traditional AJAX to HTMX:

```
Traditional AJAX (without HTMX):
  Step 1: The user types text
  Step 2: JavaScript listens for the 'input' event
  Step 3: JS performs fetch('/api/notes/search/?q=...') 
  Step 4: Receives JSON: [{"id":1, "title":"..."}, ...]
  Step 5: JS builds HTML: '<div class="card">...' + noteData.title + '...'
  Step 6: JS inserts: document.getElementById('results').innerHTML = html
  Problem: JavaScript knows about the data structure (JSON fields) and the UI structure (how to build HTML)
            → two places that need changes when the design is updated

HTMX approach:
  Step 1: The user types text
  Step 2: hx-trigger="input changed delay:300ms" fires automatically
  Step 3: HTMX performs GET /api/notes/search/?q=...
  Step 4: The Django Ninja view runs and renders the note_grid.html template
  Step 5: Receives a ready HTML fragment: '<div class="card">...'
  Step 6: HTMX inserts it into hx-target="#notes-container"
  Advantage: JavaScript (HTMX) knows nothing about the structure. The whole UI is in Python templates.
```

> The live search flow — step by step:
```
The user types "Django" into the search field
       ↓ hx-trigger="input changed delay:300ms" (300ms debounce — not every keystroke)
       ↓ HTMX builds GET /api/notes/search/?q=Django
       ↓ The Django Ninja router receives the request
       ↓ Pydantic validates: q: str = "" (always a string, even if empty)
       ↓ note_search() runs: Note.objects.filter(title__icontains='Django')
       ↓ render(request, 'components/note_grid.html', {'notes': results})
       ↓ The Django Template Engine renders ONLY the fragment (no <html>, <head>)
       ↓ Returns HTML: '<div class="row">...<h5>Django notes</h5>...</div>'
       ↓ hx-target="#notes-container" → HTMX replaces the innerHTML of this div
The user sees updated results WITHOUT a page reload
```

> Why this matters for Django developers: your Python templates are already a "component system". `{% include 'components/note_card.html' %}` is a component. By adding HTMX, these components become interactive without writing a single line of JavaScript.

### Concept

```
Full page (first request):
    Browser → /notes/ → Django View → render() → full HTML

Partial update (after interaction):
    Browser → /api/notes/partial/ → Ninja → render(fragment.html) → HTML fragment

JavaScript (HTMX or fetch) replaces only the needed DOM node:
    document.getElementById('notes-list').innerHTML = fragment
```

### HTMX — minimal JavaScript, maximum interactivity

> Pay attention to the HTMX HTML attributes: `hx-get` (where to send the request), `hx-target` (which DOM element to replace with the result), `hx-swap` (how to replace it: `innerHTML`, `outerHTML`, `beforeend`, etc.), `hx-trigger` (when to fire). The `delay:300ms` attribute in `hx-trigger="input changed delay:300ms"` is a debounce: HTMX waits 300ms after the last change before sending the request. Without it, every keystroke would send a request to the server.

```html
{# note_list.html — with HTMX #}
{% extends 'notes_app/base.html' %}

{% block extra_css %}
<!-- HTMX — 14KB, no build step -->
<script src="https://unpkg.com/htmx.org@1.9.12"></script>
{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3">Нотатки</h1>
    <button
        class="btn btn-primary"
        hx-get="{% url 'notes_app:note_create_partial' %}"
        hx-target="#modal-container"
        hx-swap="innerHTML"
    >
        + Нова нотатка
    </button>
</div>

{# Search — live search without a page reload #}
<input
    type="search"
    class="form-control mb-4"
    name="q"
    placeholder="Пошук нотаток..."
    hx-get="/api/notes/search/"
    hx-trigger="input changed delay:300ms"
    hx-target="#notes-container"
    hx-swap="innerHTML"
>

{# Notes list — replaced during search #}
<div id="notes-container">
    {% include 'notes_app/components/note_grid.html' %}
</div>

{# Container for a dynamic modal #}
<div id="modal-container"></div>
{% endblock %}
```

### A Ninja endpoint for HTMX (returns an HTML fragment)

> Note the key difference: `render(request, 'notes_app/components/note_grid.html', ...)` — here the template is a **fragment**, not a full page. `note_grid.html` has no `{% extends %}`, no `<html>`, no `<head>` — only a `<div>` with note cards. This is what HTMX will insert into `#notes-container`.

```python
# notes_app/api.py

@router.get("/search/", response=None)
def note_search(request, q: str = ""):
    """
    HTMX endpoint — returns only an HTML fragment (not a full page).
    HTMX will replace the innerHTML of #notes-container.
    """
    notes = Note.objects.filter(title__icontains=q).order_by('-created_at')
    return render(
        request,
        'notes_app/components/note_grid.html',  # ← a fragment, not a full page
        {'notes': notes, 'query': q}
    )


@router.get("/partial/{note_id}/", response=None)
def note_partial(request, note_id: int):
    """Returns an HTML note card for dynamic updates"""
    note = get_object_or_404(Note, pk=note_id)
    return render(
        request,
        'notes_app/components/note_card.html',
        {'note': note}
    )
```

> The fragment template below is a Django-style "component". It knows nothing about where it will be inserted. `hx-trigger="revealed"` on the card means: "when this card appears in the viewport (the visible area), perform a GET request and update yourself via `hx-swap="outerHTML"`". This is lazy loading of components without JavaScript.

```html
{# notes_app/components/note_grid.html — a FRAGMENT (no <!DOCTYPE>, no <html>) #}
{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 border-0 shadow-sm"
             id="note-{{ note.pk }}"
             hx-get="/api/notes/partial/{{ note.pk }}/"
             hx-trigger="revealed"
             hx-swap="outerHTML">
            <div class="card-body">
                <h5 class="card-title">
                    {% if query %}
                    {# Highlight the matched text #}
                    {{ note.title }}
                    {% else %}
                    {{ note.title }}
                    {% endif %}
                </h5>
                <p class="card-text text-muted">{{ note.content|truncatewords:20 }}</p>
            </div>
            <div class="card-footer bg-transparent border-0">
                <small class="text-muted">{{ note.created_at|date:"d.m.Y" }}</small>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% else %}
<div class="text-center py-5 text-muted">
    {% if query %}
    <p>За запитом "{{ query }}" нічого не знайдено.</p>
    {% else %}
    <p>Нотаток ще немає.</p>
    {% endif %}
</div>
{% endif %}
```

---

---
- **🧠 Mental model:** DTL (Django Template Language) is "safety scissors" (limited, but you can't cut yourself). Jinja2 is a "Swiss Army knife" (powerful, but requires care). DTL deliberately forbids calling functions with arguments so that developers don't write business logic in templates. Jinja2 does not set this boundary.
- **📚 Why it exists:** Django was designed around the idea of "logic-less templates" — templates should display data, not process it. DTL implements this idea through restrictions. Jinja2 comes from a different philosophy (Flask) — the full power of Python in templates. Django has supported both backends since Django 1.8.
- **🌐 What happens under the hood:** Django checks the file extension and the template directory to decide which backend to use. `.html` → DTL (from `templates/`), `.html.j2` → Jinja2 (from `jinja2/`). You can have both in one project without conflicts.
- **❌ Common beginner mistake:** Trying to use Jinja2 for django-admin templates. The admin requires DTL — it uses specific DTL template tags (`{% admin_list_filter %}`, etc.) that do not exist in Jinja2. Use Jinja2 only for your own templates, not for the admin.
---

## 6. Jinja2 — an alternative template engine

> Before choosing between DTL and Jinja2, ask yourself: "Does my template require complex logic?" If the answer is "yes", that is a signal the logic is in the wrong place. The right solution is to move the logic into the View, not to switch to Jinja2. If you really need macros, groupby filters, or performance is critical — then Jinja2 is justified.

> When to choose **Jinja2**:
> - Complex template logic (macros, loops with Python functions, `{{ items|groupby('category') }}`)
> - Critical performance (Jinja2 compiles to Python bytecode — faster rendering of complex templates)
> - The team is already familiar with Jinja2 (Flask, FastAPI background)
>
> When to stay with **DTL**:
> - django-admin (ALWAYS DTL — never use Jinja2 for admin templates)
> - Simple applications where DTL's restrictions do not get in the way
> - When "no business logic in templates" guarantees matter
> - When you want maximum compatibility with third-party Django packages (most of them ship DTL templates)

### DTL vs Jinja2 — comparison

| | Django Template Language (DTL) | Jinja2 |
|-|-------------------------------|--------|
| **Syntax** | `{% for %}`, `{{ var\|filter }}` | `{% for %}`, `{{ var\|filter }}` (similar) |
| **Function calls** | Forbidden with arguments | Allowed: `{{ my_func(arg) }}` |
| **Performance** | Standard | Higher (compiles to Python bytecode) |
| **Autoescape** | Yes (by default) | Yes (must be enabled) |
| **Tests** | `{% if val %}` | `{% if val is defined %}` |
| **Macros** | `{% include %}` | `{% macro %}` (more powerful) |
| **Filters** | Built-in + custom | Built-in + custom |
| **When to choose** | Django standard, the team knows DTL | High performance, complex templates |

### How Django decides which backend to use

Before looking at the configuration, understand the backend selection algorithm:

```
render(request, 'notes_app/note_list.html', context)
         ↓
Django iterates over the TEMPLATES list (order matters!):
         ↓
Backend 1 (DjangoTemplates):
  Looks for 'notes_app/note_list.html' in templates/ directories
  → Found? → Renders DTL → STOP
  → Not found? → Moves on to Backend 2

Backend 2 (Jinja2):
  Looks for 'notes_app/note_list.html' in jinja2/ directories
  → Found? → Renders Jinja2 → STOP
  → Not found? → TemplateDoesNotExist error
```

**The .html.j2 vs .html convention:** Technically you can name a Jinja2 template `.html` — if it is in a `jinja2/` directory, Django will find it with the correct backend. But the `.html.j2` extension helps: editors (PyCharm, VS Code) understand that it is Jinja2 and enable the right syntax highlighting.

### Connecting Jinja2 in Django

> Note the configuration below: `TEMPLATES` contains **two** backends at once. The first (DTL) serves `templates/` directories. The second (Jinja2) serves `jinja2/` directories. `environment` points to your Jinja2 Environment initialization function, where you register `static()` and `url()` — without it, Jinja2 would not know about Django-specific functions.

```bash
pip install jinja2
```

```python
# settings.py
TEMPLATES = [
    {
        # 1. Standard Django Template Language (we keep it)
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,  # looks in app/templates/
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
    {
        # 2. Jinja2 (additional backend)
        'BACKEND': 'django.template.backends.jinja2.Jinja2',
        'DIRS': [BASE_DIR / 'jinja2'],  # looks in the /jinja2/ folder
        'APP_DIRS': True,               # looks in app/jinja2/
        'OPTIONS': {
            'environment': 'notes_app.jinja2_env.environment',
        },
    },
]
```

> The `jinja2_env.py` file is the "bridge" between Django and Jinja2. Django knows about `staticfiles` and `reverse()` (the URL resolver). Jinja2 does not. Here you explicitly register these functions in the Jinja2 `globals` so that templates can use `{{ static('path') }}` and `{{ url('name') }}` just like in DTL.

```python
# notes_app/jinja2_env.py
from jinja2 import Environment
from django.contrib.staticfiles.storage import staticfiles_storage
from django.urls import reverse

def environment(**options):
    env = Environment(**options)

    # Add Django functions to Jinja2
    env.globals.update({
        'static': staticfiles_storage.url,   # {{ static('path') }} → url
        'url': reverse,                        # {{ url('name') }} → url
    })

    # Autoescape for HTML (XSS protection)
    env.autoescape = True

    return env
```

### Jinja2 file structure

> This directory structure is critically important. Django determines which backend to use based on WHERE the file is located. A file in `templates/` → DTL. A file in `jinja2/` → Jinja2. The `.html.j2` extension is a convention (not mandatory) that helps code editors highlight the syntax correctly.

```
notes_app/
├── templates/           ← DTL templates (*.html)
│   └── notes_app/
│       ├── base.html
│       └── note_list.html
└── jinja2/              ← Jinja2 templates (a separate folder!)
    └── notes_app/
        ├── base.html.j2
        └── note_list.html.j2
```

> **Jinja2 syntax, macros, `Environment`, bytecode cache and streaming** are covered in detail
> in [ADVANCED_TEMPLATES.md §6](../05_frontend_and_templates/advanced_templates_full.md) — Jinja2 Deep Dive.

### Ninja + Jinja2 endpoint

> Note: `render()` is exactly the same. Django itself decides which backend to use based on the file name and configuration. Your Ninja endpoint does not know, and should not know, whether it is DTL or Jinja2 — that is a configuration detail hidden from the business logic.

```python
# notes_app/api.py

@router.get("/jinja/", response=None)
def note_list_jinja(request):
    """
    Django automatically picks the right backend:
    - template.html     → DTL (django.template.backends.django)
    - template.html.j2  → Jinja2 (django.template.backends.jinja2)
    """
    notes = Note.objects.all()
    # render() looks for the template in all configured backends
    return render(request, 'notes_app/note_list.html.j2', {'notes': notes})
```

---

---
- **🧠 Mental model:** Middleware with `TemplateResponse` is a conveyor belt of transformers. Each middleware is a workstation on the conveyor that can add something to the "semi-finished product" (the unrendered TemplateResponse) before it becomes the finished product (an HTML string).
- **📚 Why it exists:** Context processors in Django (the mechanism that automatically adds `user`, `messages`, `MEDIA_URL` to every template) are implemented through this very principle of deferred rendering. Without `TemplateResponse`, you would have to add this data manually to every `render()` call.
- **🌐 What happens under the hood:** The "deferred rendering" pattern is the foundation for: context processors (add to the context before render), template caching (caches the compiled HTML, not the TemplateResponse), A/B testing (modifies the context depending on the user segment before rendering), analytics injection (middleware adds tracking data to every page).
- **❌ Common beginner mistake:** Calling `response.render()` manually in a view, or trying to change `response.context_data` AFTER `response.render()` has already been called. After rendering, `response.is_rendered = True` and changes to the context no longer affect the HTML.
---

## 7. TemplateResponse — deferred rendering

> Let's look at a real use case: a middleware that adds global data to EVERY page without changing a single view. This is a classic example of a Cross-Cutting Concern — logic that applies to all pages and that would be wrong to duplicate in every view. Middleware + TemplateResponse = an elegant solution.

> Note the `if hasattr(response, 'context_data')` check. This is important: not every response is a `TemplateResponse`. JSON API endpoints, redirects, static files — they return ordinary `HttpResponse` objects without `context_data`. The `hasattr` check protects against AttributeError.

### When TemplateResponse is critically important

```python
# Scenario: a middleware that adds a global context

# notes_chat_app/middleware.py
class GlobalContextMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # TemplateResponse is NOT compiled YET → the context can be changed!
        if hasattr(response, 'context_data'):
            response.context_data['site_name'] = 'MySite'
            response.context_data['nav_items'] = get_nav_items()
            # Now the template has access to {{ site_name }} and {{ nav_items }}

        return response

# With HttpResponse this is IMPOSSIBLE — the HTML was already compiled in the view
```

> Post-render callbacks are another powerful feature of `TemplateResponse`. A callback runs AFTER the template has been compiled into an HTML string. This is the ideal place to cache the finished HTML, log the response size, or compress the HTML. Note: `response.content` in the callback is already `bytes`, not a string.

```python
# views.py
from django.template.response import TemplateResponse

def note_list(request):
    notes = Note.objects.all()
    context = {'notes': notes}

    # TemplateResponse — middleware can add to context_data
    response = TemplateResponse(request, 'notes_app/note_list.html', context)

    # You can add callbacks that run after render()
    def post_render_callback(response):
        # response.content — the already compiled HTML string
        # Handy for caching or logging
        cache.set(f'page_{request.path}', response.content, timeout=300)

    response.add_post_render_callback(post_render_callback)

    return response
```

### `render()` vs `TemplateResponse` — summary

> A practical rule: start with `render()`. Switch to `TemplateResponse` only if you need one of two things: (1) a middleware must modify the context, or (2) you need post-render callbacks. For 90% of views `render()` is the right choice.

```python
# render() — the simplest, for most cases
return render(request, 'template.html', context)
# ✓ Simple code   ✓ Immediate compilation   ✗ Middleware cannot change the context

# TemplateResponse — for complex middleware pipelines
return TemplateResponse(request, 'template.html', context)
# ✓ Middleware can change the context   ✓ Post-render callbacks   ✗ More complex code
```

---

---
- **🧠 Mental model:** Production settings are the difference between "a test drive" (development) and "driving on a race track" (production). In development convenience matters more than speed (we see changes right away). In production speed is critical (thousands of requests per second).
- **📚 Why it exists:** By default Django is configured for development convenience: `DEBUG=True`, templates are read from disk on every request, Swagger is open to everyone. For production each of these settings is dangerous or inefficient.
- **🌐 What happens under the hood:** `cached.Loader` stores the template's compiled "Node tree" in a dictionary in process memory. The key is the template file name. On a request, Django checks the dictionary first and reads the file from disk only if it is missing. In production the server usually does not restart between requests, so the cache lives for the whole lifetime of the server.
- **❌ Common beginner mistake:** Enabling `cached.Loader` in development. Then template changes will not be visible without restarting the server — very inconvenient during development. `cached.Loader` is for production ONLY.
---

## 8. Production Patterns

> The two most important production optimizations: **cached.Loader** (for HTML) and **select_related** (for SQL). The first eliminates repeated reading of files from disk. The second eliminates the N+1 query problem. Without them, even a simple notes list can generate hundreds of SQL queries and hundreds of disk reads on every HTTP request.

> The N+1 problem in an API context is especially dangerous because a Ninja endpoint looks "clean":
> ```
> A Ninja endpoint returns 100 notes with author names:
> Without optimization:
>   1 SQL: SELECT * FROM notes (100 rows)
>   100 SQL: SELECT * FROM users WHERE id=X (for each note)
>   = 101 SQL queries for ONE API call!
> With select_related:
>   1 SQL: SELECT notes.*, users.* FROM notes JOIN users ON notes.user_id = users.id
>   = 1 SQL query!
> ```
> This is not a Python bug — it is the correct behavior of the Django ORM. A QuerySet is lazy: `note.user` runs a separate SQL query on first access. `select_related` tells the ORM to do the JOIN in advance.

### 1. Cached Template Loader — the most important optimization

> This configuration is most often the difference between a "slow site" and a "fast site" for Django in production. Note: `APP_DIRS=False` when you use `loaders` manually — these two options are incompatible. With `APP_DIRS=True` Django already adds `app_directories.Loader`, and duplicating it in `loaders` will raise an error.

```python
# settings.py — DEVELOPMENT
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'APP_DIRS': True,   # reads the template from disk on EVERY request
    ...
}]

# settings.py — PRODUCTION
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],
    'APP_DIRS': False,  # disable APP_DIRS if we use loaders manually
    'OPTIONS': {
        'loaders': [
            # cached.Loader caches the compiled Node tree in memory
            ('django.template.loaders.cached.Loader', [
                'django.template.loaders.filesystem.Loader',
                'django.template.loaders.app_directories.Loader',
            ]),
        ],
        'context_processors': [...],
    },
}]
```

**What happens with cached.Loader:**

```
Without cache (development):
  Request 1: disk → read → parse → Node tree → render  (slow)
  Request 2: disk → read → parse → Node tree → render  (slow)
  Request N: disk → read → parse → Node tree → render  (slow)

With cached.Loader (production):
  Request 1: disk → read → parse → Node tree → RAM cache → render
  Request 2: RAM cache → render  (fast, no disk and no parsing!)
  Request N: RAM cache → render  (fast)
```

### 2. Production environment settings

> `docs_url=None if not settings.DEBUG else '/docs/'` protects against a dangerously open Swagger. In production the Swagger UI is a detailed map of all your API endpoints with example requests and responses. An attacker can use it to understand the API structure and look for vulnerabilities. Disable it in production or protect it with an nginx IP restriction or Django `login_required`.

```python
# settings/production.py
import os

DEBUG = False

# Cached template loader
TEMPLATES[0]['APP_DIRS'] = False
TEMPLATES[0]['OPTIONS']['loaders'] = [
    ('django.template.loaders.cached.Loader', [
        'django.template.loaders.filesystem.Loader',
        'django.template.loaders.app_directories.Loader',
    ]),
]

# Static files
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATIC_URL = '/static/'

# Django Ninja — disable Swagger in production (optional)
NINJA_PAGINATION_PER_PAGE = 20
```

```python
# notes_chat_app/urls.py — production config
from django.conf import settings
from ninja import NinjaAPI

api = NinjaAPI(
    title="Notes API",
    docs_url=None if not settings.DEBUG else '/docs/',   # ← disable Swagger
)
```

### 3. Query Optimization — do it in the View, not in the template

> The N+1 problem is the most common performance problem in Django projects. It is invisible during development (3-5 notes in the test database → 4-6 queries, unnoticeable). But in production (1000 notes → 1001 SQL queries for one HTTP request!) it kills the server. Always use `select_related` for ForeignKey, `prefetch_related` for ManyToMany, `annotate` for aggregations.

```python
# ❌ BAD: N+1 via a lazy QuerySet in the template
def note_list(request):
    notes = Note.objects.all()   # the QuerySet has not been executed yet
    return render(request, 'note_list.html', {'notes': notes})
# Template: {% for note in notes %} → {{ note.user.username }} ← N+1!

# ✅ GOOD: select_related before passing to the template
def note_list(request):
    notes = Note.objects.select_related('user').order_by('-created_at')
    return render(request, 'note_list.html', {'notes': notes})
# One SQL JOIN instead of N separate queries

# ✅ GOOD: prefetch_related for ManyToMany
def note_list(request):
    notes = (
        Note.objects
        .select_related('user')
        .prefetch_related('tags')
        .annotate(comment_count=Count('comments'))
        .order_by('-created_at')
    )
    return render(request, 'note_list.html', {'notes': notes})
```

### 4. Ninja API — caching JSON responses

> Caching API responses is critical for read-heavy endpoints (the notes list is read much more often than it is updated). `cache_key` includes `request.user.id` — different users see different notes, so their caches must be isolated. `timeout=60` — 60 seconds of freshness. When a note is updated, you also need to clear the cache: `cache.delete(cache_key)`.

```python
from django.views.decorators.cache import cache_page
from django.utils.decorators import method_decorator
from ninja import Router

router = Router()

# Caching via the Django cache framework
@router.get("/", response=List[NoteOut])
def note_list_cached(request):
    from django.core.cache import cache

    cache_key = f'notes_list_user_{request.user.id}'
    cached = cache.get(cache_key)

    if cached is not None:
        return cached

    notes = list(Note.objects.all().values('id', 'title', 'content', 'created_at'))
    cache.set(cache_key, notes, timeout=60)  # 60 seconds
    return notes
```

---

---
- **🧠 Mental model:** A Pydantic Schema is a "contract for data". Just as a Django Form validates HTML forms, a Pydantic Schema validates JSON. But Pydantic does it automatically, through type hints, without writing `clean_` methods.
- **📚 Why it exists:** The "mass assignment vulnerability" is a classic attack: if an API accepts JSON and directly updates model fields (`Note.objects.create(**data)`), an attacker can send `{"is_admin": true}` and become an administrator. An Input Schema solves this: you explicitly specify which fields are ALLOWED to be received from the user. An Output Schema solves the "data leak" problem: you explicitly specify which fields are ALLOWED to be sent.
- **🌐 What happens under the hood:** Ninja receives the request's JSON body and passes it to Pydantic `NoteCreateSchema(**json_data)`. Pydantic checks the types, calls validators, and either returns a valid object or raises `ValidationError`. Ninja catches the `ValidationError` and returns `422 Unprocessable Entity` with error details. Your function does not even run when validation fails.
- **❌ Common beginner mistake:** Using `ModelSchema` with `fields = '__all__'` for input data. This automatically adds ALL model fields to the Input Schema — including `is_staff`, `is_superuser`, `password_hash`. Always list the fields explicitly or use separate `CreateSchema` and `OutSchema`.
---

## 9. Ninja Schemas — validation and serialization

> The "separate schemas for input and output" pattern is not just code style, it is architectural security. `NoteCreateSchema` defines "what the user can SEND" (a minimum of fields, no system ones). `NoteOutSchema` defines "what the API SHOWS to the outside" (it may include computed fields, but no secrets such as password hashes). Separating these two concepts protects against a whole class of vulnerabilities.

> Why `ModelSchema` is not always better than a plain `Schema`: `ModelSchema` generates the schema automatically from a Django model. Convenient — but dangerous for Input schemas. If the model has an `is_admin: bool = False` field, `ModelSchema` will allow the user to send `{"is_admin": true}` in the request. An explicit `Schema` with only the necessary fields is safer than a convenient `ModelSchema`.

### Pydantic Schemas for input and output data

> Pay attention to `@field_validator('title')` — this is Pydantic v2 syntax, which Django Ninja 1.x runs on (Pydantic v1 used `@validator`; in v2 it still works but is deprecated). The validator is called automatically during validation and either returns the cleaned value or raises a `ValueError` with a human-readable message. This message automatically ends up in the `422` response.

```python
# notes_app/schemas.py
from ninja import Schema, ModelSchema
from typing import Optional, List
from datetime import datetime
from pydantic import ConfigDict, field_validator
from .models import Note


# Input schema — validation of input data
class NoteCreateSchema(Schema):
    title: str
    content: str = ""

    @field_validator('title')
    @classmethod
    def title_min_length(cls, v):
        if len(v.strip()) < 3:
            raise ValueError('Мінімум 3 символи')
        return v.strip()


class NoteUpdateSchema(Schema):
    title: Optional[str] = None
    content: Optional[str] = None


# Output schema — serialization of output data
class NoteOutSchema(Schema):
    id: int
    title: str
    content: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)  # Pydantic v2: read from ORM objects


# ModelSchema — automatically from a Django Model
class NoteModelSchema(ModelSchema):
    class Meta:
        model = Note
        fields = ['id', 'title', 'content', 'created_at']
        # or: fields = '__all__'
        # or: exclude = ['user']
```

### Architectural diagram of a CRUD Router

Before reading the code, understand the big picture. A single `Router` object handles all five HTTP operations for one resource. This is REST architecture in its purest form:

```
HTTP Method + URL Pattern → Action         → SQL
─────────────────────────────────────────────────────
GET    /api/notes/          → list         → SELECT *
GET    /api/notes/{id}/     → details      → SELECT WHERE id=X
POST   /api/notes/          → create       → INSERT
PUT    /api/notes/{id}/     → update       → UPDATE WHERE id=X
DELETE /api/notes/{id}/     → delete       → DELETE WHERE id=X
```

Every endpoint in Ninja is an ordinary Python function with a decorator. The Pydantic Schema (`NoteOutSchema`) says what to return, `NoteCreateSchema` says what to accept. Ninja itself performs: JSON deserialization → Pydantic validation → passing to the function → response serialization.

**Pay attention to `data.dict(exclude_unset=True)` in `note_update`** — this is the key to "partial updates" (PATCH-like behavior). If the client sent only `{"title": "New title"}`, only `title` is updated and `content` is left untouched. Without `exclude_unset=True`, Pydantic would substitute the default value `content=None` and overwrite the existing content.

### Full CRUD Router

> This CRUD router demonstrates all the main HTTP methods. Note `data.dict(exclude_unset=True)` in `note_update` — this is the key detail for PATCH-like behavior: `exclude_unset=True` includes only the fields the client ACTUALLY sent, not all schema fields with default values. This lets you update only `title` without touching `content`.

```python
# notes_app/api.py
from ninja import Router
from django.shortcuts import get_object_or_404
from typing import List
from .models import Note
from .schemas import NoteCreateSchema, NoteUpdateSchema, NoteOutSchema

router = Router(tags=["Notes"])

@router.get("/", response=List[NoteOutSchema], summary="Список нотаток")
def note_list(request):
    return Note.objects.all().order_by('-created_at')


@router.get("/{note_id}/", response=NoteOutSchema, summary="Деталі нотатки")
def note_detail(request, note_id: int):
    return get_object_or_404(Note, pk=note_id)


@router.post("/", response=NoteOutSchema, summary="Створити нотатку")
def note_create(request, data: NoteCreateSchema):
    note = Note.objects.create(**data.dict())
    return note


@router.put("/{note_id}/", response=NoteOutSchema, summary="Оновити нотатку")
def note_update(request, note_id: int, data: NoteUpdateSchema):
    note = get_object_or_404(Note, pk=note_id)
    for attr, value in data.dict(exclude_unset=True).items():
        setattr(note, attr, value)
    note.save()
    return note


@router.delete("/{note_id}/", summary="Видалити нотатку")
def note_delete(request, note_id: int):
    note = get_object_or_404(Note, pk=note_id)
    note.delete()
    return {"success": True}


# HTML endpoint for the browser
@router.get("/html/", response=None, include_in_schema=False)
def note_list_html(request):
    from django.shortcuts import render
    notes = Note.objects.all().order_by('-created_at')
    return render(request, 'notes_app/note_list.html', {'notes': notes})
```

---

---
- **🧠 Mental model:** Swagger UI is a free "Postman" generated automatically straight from your code. You wrote Pydantic schemas and Ninja endpoints — Swagger already knows which fields each endpoint accepts and which responses it returns, and can test them in the browser.
- **📚 Why it exists:** OpenAPI (formerly Swagger) is a standard for describing REST APIs. Ninja generates the `openapi.json` specification automatically from type hints and schemas. Swagger UI reads this specification and renders an interactive interface. Third-party tools (Postman, code generators for mobile SDKs, API gateways) can also read this specification.
- **🌐 What happens under the hood:** When Django starts, Ninja introspects all registered endpoints and schemas. It builds the `openapi.json` specification in memory. On a request to `/api/docs/`, it returns the Swagger UI HTML with an embedded link to `/api/openapi.json`. Swagger UI (JavaScript) loads the spec and renders interactive forms.
- **❌ Common beginner mistake:** Leaving Swagger open in production. Swagger UI shows the names of all endpoints, parameter types, example requests — a detailed API map for an attacker. Additionally, Swagger lets anyone execute real API requests straight from the browser — without any authorization.
---

## 10. Swagger UI — automatic documentation

> The two URLs Ninja generates automatically solve different problems: `/api/docs/` is for developers (interactive testing), `/api/openapi.json` is for tools (Postman, mobile SDK generators, API Gateway). Not a single line of configuration is needed — only type hints and Pydantic schemas.

> Protecting Swagger in production is not an optional recommendation but a security requirement. Protection options:
> 1. `docs_url=None` — disable it completely
> 2. Nginx `allow 192.168.1.0/24; deny all;` in front of `/api/docs/` — office network only
> 3. The Django `@login_required` decorator on the docs URL — authenticated users only
> 4. Custom `auth` in NinjaAPI — documentation only after API authorization

**How to read the automatic documentation:** Ninja collects information about each endpoint from three sources: (1) the HTTP method and path (`@router.get("/{note_id}/")`), (2) Pydantic schemas (`response=NoteOutSchema`, `data: NoteCreateSchema`), (3) the Python docstring and the `summary=` parameter. From these it generates the OpenAPI specification — a standard JSON format for describing APIs.

```
How Swagger UI appears automatically:
  Your code: @router.get("/", response=List[NoteOutSchema])
       ↓
  Ninja: introspection → OpenAPI spec JSON
       ↓
  GET /api/openapi.json → {"paths": {"/api/notes/": {"get": {...}}}}
       ↓
  GET /api/docs/ → Swagger UI HTML with an embedded link to openapi.json
       ↓
  Browser: Swagger UI (JavaScript) loads the spec → renders the forms
```

Django Ninja automatically generates Swagger UI:

```
http://localhost:8000/api/docs/
→ Interactive documentation
→ You can test endpoints right from the browser
→ Automatically from NoteOutSchema, NoteCreateSchema

http://localhost:8000/api/openapi.json
→ OpenAPI JSON specification (for Postman, code generators)
```

> `description` supports Markdown — `##` headings, `- item` lists, `**bold**` text. Use it for structured documentation right in the code. The version `version="2.0.0"` is displayed in Swagger UI and lets clients know which API version they are working with.

```python
# Customizing Swagger
api = NinjaAPI(
    title="Notes API",
    version="2.0.0",
    description="""
    ## Система нотаток

    API для управління нотатками.

    ### Автентифікація
    Використовується Bearer Token.
    """,
    docs_url="/docs/",
)
```

---

---
- **🧠 Mental model:** This comparison shows the evolution of the same functionality. Both approaches are correct — they are optimized for different contexts. Like a hammer and a screwdriver: both are tools, each for its own job.
- **📚 Why it exists:** Django Class-Based Views (ListView, DetailView) are "batteries included". They implement 80% of typical patterns (pagination, queryset, context) for you. Ninja endpoints are a "blank sheet" with explicit control. CBVs mean less code for typical cases. A Ninja endpoint gives more flexibility and control.
- **🌐 What happens under the hood:** Django's CBV `ListView` does behind the scenes the same thing your Ninja endpoint does manually: `paginator = Paginator(queryset, paginate_by)`, `page_obj = paginator.get_page(page)`, `context = {'object_list': page_obj, ...}`, `return TemplateResponse(request, template_name, context)`. The Ninja endpoint does it explicitly — you see every step.
- **❌ Common beginner mistake:** Thinking that Ninja endpoints "replace" Django views or that CBVs are "obsolete". The choice depends on the task: CBVs are excellent for CRUD with HTML, Ninja is excellent for JSON APIs and hybrid HTML+JSON endpoints.
---

## 11. Comparison: Django View vs Ninja Endpoint for HTML

> Both approaches below do the same thing: a paginated list of notes. But they are optimized for different scenarios. CBV `ListView` — less code, more "magic" (Django does the pagination for you). The Ninja endpoint — more code, but full control and the ability to have a JSON endpoint with the same logic right next to it. When reading the code below, note that the Ninja endpoint shows every step explicitly, while the CBV hides them.

```python
# ── DJANGO VIEW (traditional) ──────────────────────────────────────
# notes_app/views.py
from django.views.generic import ListView

class NoteListView(ListView):
    model = Note
    template_name = 'notes_app/note_list.html'
    context_object_name = 'notes'
    ordering = ['-created_at']
    paginate_by = 12

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['title'] = 'Мої нотатки'
        return context


# notes_app/urls.py
urlpatterns = [
    path('notes/', NoteListView.as_view(), name='note_list'),
]


# ── NINJA ENDPOINT (API style) ─────────────────────────────────────
# notes_app/api.py
@router.get("/html/", response=None, include_in_schema=False)
def note_list_html(request, page: int = 1, per_page: int = 12):
    from django.core.paginator import Paginator

    notes_all = Note.objects.all().order_by('-created_at')
    paginator = Paginator(notes_all, per_page)
    page_obj = paginator.get_page(page)

    return render(request, 'notes_app/note_list.html', {
        'notes': page_obj,
        'title': 'Мої нотатки',
        'page_obj': page_obj,
    })

# Advantage of a Ninja HTML endpoint:
# The same router can have both JSON (/api/notes/) and HTML (/api/notes/html/)
# A single place for business logic
```

---

## 12. Anti-patterns

> The anti-patterns below are the most common mistakes that make Django projects hard to maintain, slow, or dangerous. Each of them looks "convenient" at first glance and becomes a problem when scaling.

```python
# ❌ HTML in Python code (breaks MVT)
@router.get("/bad/", response=None)
def bad_view(request):
    return HttpResponse("<h1>Hello</h1><ul>" +
                        "".join(f"<li>{n.title}</li>" for n in Note.objects.all()) +
                        "</ul>")

# ✅ Always via a template
@router.get("/good/", response=None)
def good_view(request):
    return render(request, 'notes_app/note_list.html', {'notes': Note.objects.all()})


# ❌ Queries in the template (via a Template Tag or methods)
# note_list.html: {{ note.user.profile.avatar.url }}
# → 1 query for profile per note = N+1

# ✅ Optimization in the View
notes = Note.objects.select_related('user__profile').all()


# ❌ Hardcoded URL in the template
<a href="/notes/{{ note.pk }}/">...</a>

# ✅ Named URL
<a href="{% url 'notes_app:note_detail' pk=note.pk %}">...</a>


# ❌ Hardcoded static URL
<img src="/static/notes_app/img/logo.png">

# ✅ {% static %}
{% load static %}
<img src="{% static 'notes_app/img/logo.png' %}">


# ❌ Swagger in production without protection
api = NinjaAPI(docs_url='/docs/')  # Open to everyone

# ✅ Swagger only in DEBUG or behind a password
api = NinjaAPI(docs_url='/docs/' if settings.DEBUG else None)
```

---

## 13. Self-check questions

1. What is the key difference between `render()` and `TemplateResponse()`? When should each be used?
2. A Django Ninja endpoint returns `Note.objects.all()`. What happens automatically to this QuerySet?
3. Why is `cached.Loader` critical for production and unnecessary for development?
4. Jinja2 allows `{{ my_list.append('item') }}` in a template. DTL does not. Why does DTL deliberately restrict this?
5. A Ninja endpoint returns an `HttpResponse` with HTML. Will Swagger `/api/docs/` show this endpoint? How do you hide it?
6. What is the advantage of the HTMX approach over traditional SSR for live search?
7. `TemplateResponse` allows middleware to change the context. How is this related to post_render_callback?
8. The Ninja Schema `NoteOutSchema` has a `created_at: datetime` field. How is it serialized to JSON?
9. Why do you need to disable `APP_DIRS=True` in production when using `cached.Loader`?
10. An HTMX request returns an HTML fragment without `<!DOCTYPE html>`. Why is this correct and when is it a problem?
