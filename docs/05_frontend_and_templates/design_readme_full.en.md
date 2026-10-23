# DESIGN_README — Designing a Django Application from Scratch

> **This tutorial** takes you from an empty `<html>` to a full-featured SaaS Dashboard
> with a dark theme, sidebar navigation and note cards — step by step.
>
> Language: **CrispyNotes** (`crispy_notes_chat_app`) — the course's real project.
> Every code example is a **live line** from the project files.

---

## Contents

1. [How to connect Bootstrap to Django](#1--how-to-connect-bootstrap-to-django)
2. [Bootstrap 5 Dark Mode](#2--bootstrap-5-dark-mode)
3. [Django static files](#3--django-static-files)
4. [CSS Custom Properties — design tokens](#4--css-custom-properties--design-tokens)
5. [Layout: a SaaS Dashboard with Flexbox](#5--layout-a-saas-dashboard-with-flexbox)
6. [Sidebar: styles, hover, active state](#6--sidebar-styles-hover-active-state)
7. [Cards and typography](#7--cards-and-typography)
8. [Bootstrap vs Custom CSS — what goes where](#8--bootstrap-vs-custom-css--what-goes-where)
9. [Course documentation](#9--course-documentation)

---

## 1 · How to connect Bootstrap to Django

> **Bootstrap** is a library of ready-made CSS classes and JavaScript components.
> Instead of writing `button { background: blue; padding: 8px 16px; border-radius: 4px; ... }`
> you simply write `class="btn btn-primary"` — and the style is already there.

### Two ways: CDN vs npm

| | CDN (for learning) | npm/Vite (for production) |
|--|-------------------|--------------------------|
| Installation | Copy two lines into the HTML | `npm install bootstrap` + build |
| Time to start | Instant | ~30 minutes of setup |
| Customization | Limited (CSS variables only) | Full (Sass variables) |
| Offline work | ❌ Requires internet | ✅ |
| File size | The CDN is cached by the browser | Only the code you need (tree-shaking) |

**For learning projects — always CDN.** The goal is to learn Django, not build tooling.

### What to copy into `<head>`

```html
<!-- Bootstrap 5 CSS — REQUIRED in <head> -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
      rel="stylesheet"
      integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
      crossorigin="anonymous">

<!-- Bootstrap Icons — a separate icon library (bi-journal-text, bi-trash...) -->
<link rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
```

```html
<!-- Bootstrap JS — BEFORE </body>, not in <head> -->
<!-- Needed for: Dropdown, Modal, Collapse, Carousel... -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
```

> **Why JS before `</body>` and not in `<head>`?**
> HTML loads from top to bottom. JS in `<head>` blocks page rendering —
> the user sees a white screen while the JS loads. With JS before `</body>`,
> the HTML is displayed first, then interactivity is added.

### Where this is in our project

**File:** `crispy_notes_chat_app/templates/base.html`

```html
<!DOCTYPE html>
<html lang="uk" data-bs-theme="dark">   <!-- ← dark mode here -->
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}Notes{% endblock %} — CrispyNotes</title>

  <!-- 1. Bootstrap CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
        rel="stylesheet" integrity="sha384-..." crossorigin="anonymous">

  <!-- 2. Bootstrap Icons -->
  <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">

  <!-- 3. Our custom CSS (on top of Bootstrap) -->
  {% load static %}
  <link rel="stylesheet" href="{% static 'notes_app/css/app.css' %}">

  {% block extra_css %}{% endblock %}   <!-- ← slot for page-specific CSS -->
</head>
<body>
  {% block body %}{% endblock %}

  <!-- Bootstrap JS (before </body>) -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  {% block extra_js %}{% endblock %}   <!-- ← slot for page-specific JS -->
</body>
</html>
```

> **CSS order matters:** Bootstrap CSS → then our CSS.
> Our `app.css` overrides Bootstrap styles where needed.
> If you include them the other way around, Bootstrap will overwrite our styles.

### Bootstrap Icons — how to use them

```html
<!-- An icon is added with an <i> tag with a bi-* class -->
<i class="bi bi-journal-text"></i>         <!-- notes -->
<i class="bi bi-trash me-1"></i>Видалити   <!-- + me-1 spacing on the right -->
<i class="bi bi-plus-lg fs-5"></i>          <!-- larger size fs-5 -->
<i class="bi bi-person-circle text-primary"></i>  <!-- with a Bootstrap color -->
```

Full list of icons: **https://icons.getbootstrap.com/** — search by name.

---

## 2 · Bootstrap 5 Dark Mode

> Bootstrap 5.3+ has a **built-in** dark theme. You do not need to write any CSS —
> a single attribute on `<html>` turns on dark mode for ALL Bootstrap components.

### Turn on the dark theme

```html
<!-- Instead of: -->
<html lang="uk">

<!-- We write: -->
<html lang="uk" data-bs-theme="dark">
```

**What changes automatically:**

| Component | Light theme | Dark theme |
|-----------|-------------|-----------|
| `<body>` | white `#fff` | dark gray `#212529` |
| `.card` | white background | gray `#2b2d31` |
| `.form-control` | white input | dark input |
| `.btn-outline-*` | colored border | the same border + dark background |
| `.dropdown-menu` | white | dark |
| `.nav-link` | dark text | light text |
| `<hr>` | gray | semi-transparent white |

### Dark/light toggle (JavaScript)

```html
<!-- Toggle button -->
<button id="themeToggle" class="btn btn-sm btn-outline-secondary">
  <i class="bi bi-moon-stars"></i>
</button>

<script>
  document.getElementById('themeToggle').addEventListener('click', () => {
    const html = document.documentElement;
    const current = html.getAttribute('data-bs-theme');
    html.setAttribute('data-bs-theme', current === 'dark' ? 'light' : 'dark');
  });
</script>
```

### Our project — the dark theme is fixed

In CrispyNotes the theme is **fixed** to dark (`base.html` line 2).
In addition, we override the Bootstrap colors with our own palette via `app.css` (section 4).

---

## 3 · Django static files

> **Static files** are CSS, JavaScript, images. Django does not "understand" them as templates —
> it simply serves them to the browser. But Django needs to know **where to look for them**.

### Two places for static files

```
crispy_notes_chat_app/
│
├── static/                          ← PROJECT-LEVEL static (STATICFILES_DIRS)
│   └── css/
│       └── project.css              ← global variables (--sidebar-width: 260px)
│
└── notes_app/
    └── static/
        └── notes_app/               ← APP-LEVEL static (APP_DIRS=True)
            └── css/
                └── app.css          ← the main CSS of our application ★
```

### settings.py — configuration

```python
# settings.py

STATIC_URL = '/static/'

# Project-level static (in addition to app/static/)
STATICFILES_DIRS = [
    BASE_DIR / 'static',   # ← the crispy_notes_chat_app/static/ folder
]

# With APP_DIRS=True Django automatically finds notes_app/static/
# No need to add each app separately
```

### In the template: `{% load static %}`

```html
{% load static %}   <!-- ← REQUIRED at the top of the template (or in base.html) -->

<!-- Including CSS -->
<link rel="stylesheet" href="{% static 'notes_app/css/app.css' %}">
<!--                                   ↑ path relative to notes_app/static/ -->

<!-- Including an image -->
<img src="{% static 'notes_app/img/logo.png' %}" alt="Logo">
```

### `collectstatic` — for production

```bash
# Collects all static files into STATIC_ROOT for Nginx/Apache
python manage.py collectstatic
```

In development (`DEBUG=True`) Django serves static files itself.
In production (`DEBUG=False`) static files should be served by Nginx, not Django.

> **Why two levels of static (project vs app)?**
> App-level static — each app is responsible for its own files. When you move the app to another project,
> its static files go with it. Project-level — for shared files (favicon, fonts, the shared palette).

---

## 4 · CSS Custom Properties — design tokens

> **CSS Custom Properties** (or CSS variables) are named values in CSS
> that can be reused throughout the code.
>
> A **design token** is one "named color" instead of dozens of hex codes all over the CSS.
> Want to change the sidebar color? Edit one variable — it changes everywhere.

### Syntax

```css
/* Declaration — in :root{} (global scope) */
:root {
  --accent: #7c6efa;          /* the name starts with -- */
  --text-primary: #e2e8f0;
  --card-bg: #1e1e2e;
}

/* Usage — the var() function */
.card {
  background: var(--card-bg);      /* substitutes #1e1e2e */
  color: var(--text-primary);      /* substitutes #e2e8f0 */
}

.btn-accent {
  background: var(--accent);       /* #7c6efa */
}

/* Fallback (backup value) */
color: var(--text-primary, #ffffff);  /* if the variable is not declared → #ffffff */
```

### All tokens of our project

**File:** `notes_app/static/notes_app/css/app.css`

```css
:root {
  /* ── SIDEBAR ───────────────────────────────── */
  --sidebar-bg:          #16161e;   /* sidebar background (the darkest) */
  --sidebar-hover:       rgba(255,255,255,0.06);  /* nav-link hover highlight */
  --sidebar-border:      rgba(255,255,255,0.07);  /* thin dividers */
  --sidebar-label:       #6060a0;   /* color of the NOTES / TASKS / TAGS headings */
  --sidebar-accent:      #7c6efa;   /* accent purple (not used directly) */
  --sidebar-active-bg:   rgba(124,110,250,0.15);  /* background of the active nav-link */

  /* ── LAYOUT ────────────────────────────────── */
  --topbar-bg:           #0f0f18;   /* topbar background (the darkest of all) */
  --main-bg:             #1a1a27;   /* main content background */
  --card-bg:             #1e1e2e;   /* note card background */

  /* ── BORDERS ───────────────────────────────── */
  --card-border:         rgba(255,255,255,0.08);  /* thin card border at rest */
  --card-hover-border:   rgba(124,110,250,0.55);  /* card border on hover */

  /* ── TEXT ──────────────────────────────────── */
  --text-primary:        #e2e8f0;   /* main text (headings, content) */
  --text-secondary:      #9a9ac0;   /* secondary text (date, hints) */
                                    /* WCAG 4.5:1 on #1e1e2e — accessible contrast */

  /* ── INTERACTIVITY ─────────────────────────── */
  --accent:              #7c6efa;   /* main accent color (buttons, links) */
  --focus-ring:          0 0 0 3px rgba(124,110,250,0.35);  /* outline on focus */
}
```

**File:** `static/css/project.css` (project-level)

```css
:root {
  --sidebar-width:  260px;  /* sidebar width */
  --topbar-height:  56px;   /* topbar height */
}
```

### Why split into two files?

`project.css` — structural values (sizes, spacing). They rarely change.
`app.css` — color tokens. If you change the theme, you edit only `app.css`.

### Bootstrap uses CSS variables too

Bootstrap has its own `--bs-*` variables:

```css
/* Bootstrap generates these on load */
:root {
  --bs-primary: #0d6efd;
  --bs-secondary: #6c757d;
  --bs-body-bg: #212529;    /* in dark mode */
  --bs-body-color: #dee2e6;
}
```

You can **override** Bootstrap variables in your own CSS:

```css
:root {
  --bs-primary: #7c6efa;   /* now btn-primary will be purple */
}
```

---

## 5 · Layout: a SaaS Dashboard with Flexbox

> A **SaaS Dashboard** is a UI pattern: a fixed sidebar on the left + scrollable content on the right.
> Notion, Gmail, Linear, Figma — they are all built this way.

### HTML structure (3 levels)

```
base.html                  ← Bootstrap CDN, app.css
└── layouts/dashboard.html ← Sidebar + Topbar
    └── note_list.html      ← Page content
```

### The full HTML structure of the dashboard

**File:** `templates/layouts/dashboard.html`

```html
<!-- Level 1: Outer wrapper — the whole viewport -->
<div class="d-flex vh-100 overflow-hidden">
  <!--
    d-flex        — display: flex (horizontal placement of sidebar + main)
    vh-100        — height: 100vh (takes the full screen height)
    overflow-hidden — so the scroll happens inside, not on body
  -->

  <!-- Level 2a: SIDEBAR — fixed width on the left -->
  <nav id="sidebar"
       class="sidebar d-flex flex-column p-3"
       style="width: 260px; min-height: 100vh;">
    <!--
      sidebar       — our CSS class (background, border-right)
      d-flex        — flex container for a vertical stack
      flex-column   — flex-direction: column (children stack from top to bottom)
      p-3           — padding: 1rem on all sides
      width:260px   — fixed width (the --sidebar-width token)
      min-height    — stretches to the full height even if the content is short
    -->

    <!-- Brand, navigation, tags... -->
  </nav>

  <!-- Level 2b: MAIN — takes the remaining width -->
  <div class="d-flex flex-column flex-grow-1 overflow-auto">
    <!--
      d-flex        — flex container for a vertical stack (topbar + content)
      flex-column   — topbar on top, content below
      flex-grow-1   — takes all available width (100% - 260px sidebar)
      overflow-auto — scrolling here, not on the whole page
    -->

    <!-- Level 3a: TOPBAR — fixed height at the top -->
    <header class="topbar d-flex align-items-center px-4 py-2">
      <!--
        topbar            — our CSS class (background, border-bottom)
        d-flex            — horizontal flex (title | search | user)
        align-items-center — vertical centering
        px-4              — horizontal padding 1.5rem
        py-2              — vertical padding 0.5rem
      -->

      <h6 class="mb-0 me-auto fw-semibold">
        <!--
          me-auto — margin-right: auto → pushes everything else to the right
          fw-semibold — font-weight: 600
        -->
        {% block topbar_title %}Нотатки{% endblock %}
      </h6>

      <!-- Search: me-3 = margin-right 1rem, spacing from the user dropdown -->
      <form class="d-flex me-3" method="get">...</form>

      <!-- User dropdown: the last element — sticks to the right edge -->
      <div class="dropdown">...</div>
    </header>

    <!-- Level 3b: PAGE CONTENT — scrolls -->
    <main class="flex-grow-1 p-4 overflow-auto">
      {% block content %}{% endblock %}
      <!--
        flex-grow-1   — takes the full height (100% - topbar height)
        p-4           — padding 1.5rem (spacing from the edges)
        overflow-auto — scrolls if the content does not fit
      -->
    </main>

  </div>
</div>
```

### Flexbox visualization

```
┌─ d-flex vh-100 overflow-hidden ──────────────────────────────────┐
│                                                                    │
│  ┌─ sidebar ──────┐  ┌─ flex-grow-1 flex-column ────────────────┐│
│  │  width: 260px  │  │                                           ││
│  │  flex-shrink:0 │  │  ┌─ topbar ──────────────────────────┐   ││
│  │                │  │  │  min-height: 56px                  │   ││
│  │  NOTES         │  │  │  h6 me-auto | search | dropdown    │   ││
│  │  TASKS         │  │  └────────────────────────────────────┘   ││
│  │  TAGS          │  │                                           ││
│  │                │  │  ┌─ main flex-grow-1 overflow-auto ───┐   ││
│  │                │  │  │  p-4                               │   ││
│  │                │  │  │  {% block content %}               │   ││
│  │                │  │  │                                    │   ││
│  └────────────────┘  │  └────────────────────────────────────┘   ││
│                       └───────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────┘
```

### Why Flexbox and not Grid?

| Flexbox | CSS Grid |
|---------|---------|
| One-dimensional (a row OR a column) | Two-dimensional (rows AND columns) |
| Sidebar + main → **Flexbox** | A complex grid of cards → **Grid** |
| `d-flex`, `flex-grow-1` | `row`, `col-md-4` |

In Bootstrap `d-flex` = Flexbox, `row/col-*` = Grid.

---

## 6 · Sidebar: styles, hover, active state

### Sidebar CSS classes (from app.css)

```css
/* Sidebar background and border */
.sidebar {
    background: var(--sidebar-bg) !important;  /* #16161e */
    border-right: 1px solid var(--sidebar-border);  /* thin line on the right */
    flex-shrink: 0;  /* does not shrink when the window gets smaller */
}
```

### Section labels (NOTES / TASKS / TAGS)

```css
.sidebar-label {
    font-size: 0.7rem;       /* small — does not compete with the links */
    font-weight: 700;        /* bold */
    letter-spacing: 0.08em;  /* spaced-out letters — classic uppercase style */
    color: var(--sidebar-label) !important;  /* #6060a0 — muted purple */
}
```

In the HTML (dashboard.html):
```html
<p class="sidebar-label text-uppercase fw-semibold mb-1 px-2">Нотатки</p>
<!--
  sidebar-label  — our CSS class (font-size, letter-spacing, color)
  text-uppercase — Bootstrap: text-transform: uppercase
  fw-semibold    — Bootstrap: font-weight: 600
  mb-1           — Bootstrap: margin-bottom: 0.25rem
  px-2           — Bootstrap: padding-left/right: 0.5rem
-->
```

### Nav-links: hover and active

```css
/* Resting state */
.sidebar .nav-link {
    color: #9898c8 !important;   /* muted purple-gray */
    padding: 0.42rem 1rem;
    border-radius: 5px;
    margin: 1px 6px;
    transition: background 0.12s, color 0.12s;  /* smooth hover */
    font-size: 0.875rem;  /* 14px — slightly smaller than the main text */
}

/* Hover */
.sidebar .nav-link:hover {
    background: var(--sidebar-hover);  /* rgba(255,255,255,0.06) — barely visible */
    color: #d8d8f8;  /* becomes lighter */
}

/* Active (current page) */
.sidebar .nav-link.active {
    background: var(--sidebar-active-bg) !important;  /* rgba(124,110,250,0.15) */
    color: var(--accent) !important;  /* #7c6efa — bright purple */
    border-left: 3px solid var(--accent);  /* accent stripe on the left ← */
    padding-left: calc(1rem - 3px);  /* compensate for the 3px border */
}
```

### Active state via Django

```html
<!-- dashboard.html — the active item is determined by the URL -->
<a href="{% url 'notes_app:note_list' %}"
   class="nav-link {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}">
  <i class="bi bi-journal-text me-2"></i>Всі нотатки
</a>
```

`request.resolver_match.url_name` — Django returns the **name of the current URL**:
- On `/notes/` → `'note_list'` → the `active` class is added
- On `/notes/new/` → `'note_create'` → the `active` class is NOT added for "Всі нотатки"

To check by **part** of the name (for example, all todo pages):
```html
class="nav-link {% if 'todo' in request.resolver_match.url_name %}active{% endif %}"
<!-- todo_list, todo_create, todo_detail — all of them will be highlighted -->
```

### Bootstrap nav-pills

```html
<ul class="nav nav-pills flex-column mb-3">
<!--
  nav         — Bootstrap: base nav styles (removes bullet points)
  nav-pills   — Bootstrap: pills (pill shape for the active item)
  flex-column — Bootstrap: vertical flex (list from top to bottom)
  mb-3        — Bootstrap: margin-bottom: 1rem (spacing between sections)
-->
  <li class="nav-item">
    <a href="..." class="nav-link">...</a>
  </li>
</ul>
```

### Separator and dividers

```html
<hr>
<!-- .sidebar hr in CSS: -->
/* border-color: var(--sidebar-border); margin: 0.4rem 0; */
```

---

## 7 · Cards and typography

### Note Cards — hover animation

```css
/* Resting state */
.note-card {
    background: var(--card-bg) !important;         /* #1e1e2e */
    border: 1px solid var(--card-border) !important;  /* rgba(255,255,255,0.08) */
    border-radius: 10px;
    /* transition — what is animated and how fast */
    transition: transform 0.18s ease,
                border-color 0.18s ease,
                box-shadow 0.18s ease;
}

/* On hover */
.note-card:hover {
    transform: translateY(-2px);  /* lifts 2px up */
    border-color: var(--card-hover-border) !important;  /* purple border */
    box-shadow: 0 6px 24px rgba(124,110,250,0.15) !important;  /* shadow */
}
```

> **Why `translateY(-2px)`?**
> A small lift without changing the size — the card "detaches" from the surface.
> `transform` does not affect layout (it does not shift neighboring elements).

### Typography — 3 levels of text

```css
/* Page title (h5 in note_list.html) */
.page-title {
    font-size: 1.2rem;    /* 19.2px */
    font-weight: 600;
    color: var(--text-primary);  /* #e2e8f0 — bright */
}

/* Card title */
.note-card .card-title a {
    font-size: 0.95rem;      /* 15.2px */
    font-weight: 600;
    letter-spacing: -0.01em; /* slightly condensed — looks modern */
    color: var(--text-primary);
}
.note-card .card-title a:hover {
    color: var(--accent);    /* purple on hover */
}

/* Note text preview */
.note-card .card-text {
    color: var(--text-secondary) !important;  /* #9a9ac0 — muted */
    font-size: 0.85rem;   /* 13.6px */
    line-height: 1.55;
}
```

### WCAG — accessible contrast

```
--text-primary  #e2e8f0  on  --card-bg  #1e1e2e  → contrast 11.5:1  ✅ (norm 4.5:1)
--text-secondary #9a9ac0 on  --card-bg  #1e1e2e  → contrast ~4.5:1  ✅ (norm 4.5:1)
```

> **WCAG** — Web Content Accessibility Guidelines. Minimum contrast of 4.5:1 between text
> and background. If the contrast is lower, people with visual impairments will not be able to read it.
> Check it: **https://webaim.org/resources/contrastchecker/**

### Bootstrap Badges

```html
<!-- In the sidebar (task counter) -->
<span class="badge bg-primary rounded-pill">{{ sidebar_todo_count }}</span>
<!--
  badge         — Bootstrap: base badge styles (padding, font-size)
  bg-primary    — Bootstrap: blue background (#0d6efd in light, an equivalent in dark)
  rounded-pill  — Bootstrap: border-radius: 50rem (pill)
-->

<!-- In note_list.html (number of notes) -->
<span class="badge rounded-pill bg-primary bg-opacity-10 text-primary"
      style="font-size: 0.72rem;">{{ notes|length }}</span>
<!--
  bg-opacity-10 — Bootstrap: opacity 10% → a very transparent background
  text-primary  — Bootstrap: blue text
  Together: a "ghost badge" — only color, no bright background
-->
```

### Crispy Forms — styling the fieldset

```css
/* app.css — styling the <fieldset><legend> that crispy generates */
fieldset legend {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    padding-bottom: 0.4rem;
    border-bottom: 1px solid var(--card-border);  /* thin line under the section */
    margin-bottom: 1rem;
}
```

Crispy generates `<fieldset><legend>Основна інформація</legend>` —
our CSS automatically styles them as section dividers.

### Custom Scrollbar

```css
/* A thin custom scrollbar for Webkit (Chrome, Edge, Safari) */
::-webkit-scrollbar       { width: 6px; }  /* thinner than the default */
::-webkit-scrollbar-track { background: transparent; }  /* transparent track */
::-webkit-scrollbar-thumb {
    background: rgba(255,255,255,0.12);  /* semi-transparent */
    border-radius: 3px;
}
::-webkit-scrollbar-thumb:hover {
    background: rgba(255,255,255,0.2);  /* becomes more visible */
}
```

Firefox: `scrollbar-width: thin;` (without color customization).

### Focus Ring — accessibility

```css
/* Instead of the browser's default blue outline */
:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);  /* 0 0 0 3px rgba(124,110,250,0.35) */
    border-radius: 4px;
}
```

`:focus-visible` — triggers only during keyboard navigation (Tab),
not on a mouse click. Important for accessibility.

---

## 8 · Bootstrap vs Custom CSS — what goes where

> Bootstrap is the **foundation**, our CSS is the **customization**.
> Bootstrap provides structure and components; we add the brand and the details.

### Division of responsibility

| What Bootstrap provides | What we write in app.css |
|--------------------|---------------------|
| `d-flex`, `vh-100`, `flex-grow-1` | `.sidebar`, `.topbar`, `.note-card` |
| `data-bs-theme="dark"` (base dark theme) | CSS tokens (`--sidebar-bg`, `--accent`...) |
| `btn`, `btn-primary`, `btn-sm` | Hover animations `.note-card:hover` |
| `card`, `card-body`, `card-footer` | Active state `border-left: 3px solid accent` |
| `nav`, `nav-pills`, `nav-link` | `.sidebar-label` (section headers) |
| `badge`, `rounded-pill` | Custom scrollbar `::-webkit-scrollbar` |
| `dropdown`, `dropdown-menu-dark` | `fieldset legend` styles for crispy |
| `p-4`, `me-3`, `px-2`, `mb-3` | `:focus-visible` ring |
| Bootstrap Icons (`bi-*`) | `--focus-ring`, `--card-hover-border` |
| `form-control`, `form-select` | `transition` animations |
| `alert`, `alert-dismissible` | Typography `.page-title`, `.card-text` |

### Where these classes are in the project

```
templates/base.html
├── data-bs-theme="dark"         ← Bootstrap dark mode
├── bootstrap.min.css CDN        ← all Bootstrap classes
├── bootstrap-icons CDN          ← bi-* icons
└── {% static 'app.css' %}       ← our custom CSS

notes_app/static/notes_app/css/app.css
├── :root {}                     ← CSS tokens (--accent, --card-bg...)
├── body                         ← base font, antialiasing
├── .sidebar                     ← sidebar background
├── .sidebar-label               ← section headers
├── .sidebar .nav-link           ← hover + transition
├── .sidebar .nav-link.active    ← active state + border-left
├── .topbar                      ← topbar background
├── .note-card                   ← card styles + hover animation
└── fieldset legend              ← crispy form sections

static/css/project.css
└── :root {}                     ← --sidebar-width, --topbar-height

templates/layouts/dashboard.html
├── d-flex vh-100 overflow-hidden ← layout wrapper
├── nav.sidebar d-flex flex-column ← sidebar container
├── header.topbar d-flex align-items-center ← topbar
└── main flex-grow-1 p-4         ← content area
```

---

## 9 · Course documentation

> The complete learning material for this module. Read in order from left to right.

| File | Level | What's inside |
|------|--------|-------------|
| [`HTML_BASICS.md`](html_basics_full.md) | Beginner | HTML5 tags, semantics, document structure |
| [`CSS_BASICS.md`](css_basics_full.md) | Beginner | Selectors, box model, flexbox, grid, media queries |
| [`BOOTSTRAP_5.md`](bootstrap_5_full.md) | Beginner+ | Grid, Flexbox utilities, components, themes |
| [`DESIGN_FOUNDATIONS.md`](design_foundations_full.md) | Intermediate | UX/UI principles, CRAP, typography, design systems |
| [`DJANGO_TEMPLATES_BOOTSTRAP.md`](django_templates_bootstrap_full.md) | Intermediate | Django templates + Bootstrap — integration and patterns |
| [`ADVANCED_TEMPLATES.md`](advanced_templates_full.md) | Intermediate+ | Context Processors, Dashboard Architecture, Crispy Forms |
| [`CRISPY_FORMS.md`](../04_forms_and_validation/crispy_forms_full.md) | Intermediate+ | FormHelper, Layout, Bootstrap 5 pack — full reference |
| [`DJANGO_NINJA_TEMPLATES.md`](../06_application_architecture/django_ninja_templates_full.md) | Advanced | Django Ninja REST API + templates, HTMX |
| [`DJANGO_ADMIN_UNFOLD.md`](django_admin_unfold_full.md) | Advanced | Customizing Django Admin with Unfold |

### Where to look for what — quick reference

| Question | File |
|---------|------|
| How do I connect Bootstrap? | **this file**, section 1 |
| What are CDN/npm? | **this file**, section 1 |
| How is dark mode turned on? | **this file**, section 2 |
| What are CSS variables? | **this file**, section 4 |
| How is the sidebar built? | **this file**, section 6 |
| Which Bootstrap classes do we use? | **this file**, section 8 |
| UX principles, CRAP | [`DESIGN_FOUNDATIONS.md`](design_foundations_full.md) §1-2 |
| Bootstrap Grid in detail | [`BOOTSTRAP_5.md`](bootstrap_5_full.md) |
| FormHelper + Layout | [`CRISPY_FORMS.md`](../04_forms_and_validation/crispy_forms_full.md) |
| Django template inheritance | [`ADVANCED_TEMPLATES.md`](advanced_templates_full.md) §2 |
| Context Processor | [`ADVANCED_TEMPLATES.md`](advanced_templates_full.md) §3 |

---

## Summary

```
To build the CrispyNotes Dashboard:

1. base.html
   └── Bootstrap CDN (CSS + Icons + JS)
   └── data-bs-theme="dark"
   └── {% static 'app.css' %}

2. app.css
   └── :root {} → CSS tokens (colors, spacing)
   └── .sidebar, .topbar, .note-card → custom components
   └── transitions, hover effects, scrollbar

3. dashboard.html
   └── d-flex vh-100            → full-screen layout
   └── nav.sidebar 260px        → fixed column
   └── flex-grow-1              → main takes the rest
   └── nav-pills flex-column    → vertical menu
   └── request.resolver_match   → active state without JS

4. Pages
   └── {% extends 'layouts/dashboard.html' %}
   └── Only {% block content %} — sidebar/topbar for free
```

> **Key idea:** Bootstrap gives you ~80% ready-made — Grid, buttons, forms, dark mode.
> The remaining 20% — CSS tokens and a few custom classes — and the project looks like a product.
