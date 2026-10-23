# 🎓 How to use this course — A beginner's guide

## New to frontend?

If HTML, CSS, and Django are new concepts for you, don't worry. This course is built so that you can figure things out from scratch.

### The course's mental model

Imagine you are building a house:

| Layer | Technology | Analogy |
|-----|-----------|---------|
| Foundation + walls | HTML | The structure of the house — where the windows are, where the doors are |
| Paint + finishing | CSS | The appearance — colors, fonts, spacing |
| IKEA furniture | Bootstrap | Ready-made components — no need to build a table from scratch |
| Architect | Django Templates | Generates different houses from a single blueprint |
| Automated foreman | Django Ninja | API — the house can "talk" to other systems |
| Custom solutions | Advanced Templates | Complex systems for large projects |
| Property manager | Django Admin | An interface for managing the whole house |

### Three levels of understanding

Every topic has three levels:

1. **"What it is and how to use it"** — you can write code and it works
2. **"How it works inside"** — you understand what happens in the browser/Django
3. **"Architectural consequences"** — you know why it should be done exactly this way and not another

The goal of this course is to bring you to level 2-3.

### How the browser processes a web page (the main context)

Before you start, understand this general flow:

```
You type a URL into the browser
        ↓
DNS translates the domain into an IP address
        ↓
The HTTP request flies to the server
        ↓
Django receives the request → urls.py → view function
        ↓
The view takes data from the database
        ↓
Django Templates generates an HTML string (SSR)
        ↓
The HTTP response flies back to the browser
        ↓
The browser parses the HTML → builds the DOM
        ↓
The browser loads the CSS → builds the CSSOM
        ↓
DOM + CSSOM = Render Tree
        ↓
Layout: the browser calculates sizes and positions
        ↓
Paint: the browser draws the pixels
        ↓
Composite: the GPU combines the layers
        ↓
You see the page! 🎉
```

### Where things can go wrong (and how to debug)

| Symptom | Where to look | Tool |
|---------|-----------|-----------|
| The page is empty | HTML structure, Django view | F12 → Network → response |
| Styles are not applied | The CSS file was not loaded, specificity | F12 → Elements → Styles |
| The form is not submitted | csrf_token is missing, action is wrong | F12 → Network → POST request |
| Data is not displayed | The context was not passed to the template | Django Debug Toolbar → Templates |
| Too many SQL queries | The N+1 problem | Django Debug Toolbar → SQL |
| The API does not respond | The Ninja endpoint is not registered | /api/docs/ Swagger UI |

---

# HTML, CSS, and Bootstrap — Knowledge System

> A continuation of the Django architecture. From a bare `HttpResponse("текст")`
> to Bootstrap 5 SaaS interfaces, custom template tags, HTMX, and Unfold Admin.

**Previous lesson:** `lesson_Django_Network_Architecture` — MVT, ORM, HttpResponse
**This lesson:** frontend + templating + Django production architecture

---

## Module 5 navigation

| Lesson | Key concepts | Practical project |
|------|------------------|-------------------|
| [lesson_Django_Network_Architecture](../legacy_source/legacy_missing_reference.md) | MVT, URL routing, HttpResponse, simple views | simple_django_project, news_portal |
| [lesson_Django_ORM_Database](../legacy_source/legacy_missing_reference.md) | ORM, Services/Selectors, FBV, Bootstrap5 forms by hand | notes_chat_app, notes_chat_app |
| **lesson_HTML_CSS_Bootstrap** (this lesson) | HTML/CSS/Bootstrap, Advanced Templates, Crispy Forms, Design Foundations | django_bootstrap_project, crispy_notes_chat_app |

---

## File navigation

> **How to read this table:** Level 1 = absolute beginner, Level 3 = confident junior. The order matters — the files depend on each other.

## Lesson files

| File | Lines | Level | Topic |
|------|--------|--------|------|
| [DESIGN_FOUNDATIONS.md](../../05_frontend_and_templates/design_foundations_full.md) | ~650 | 0 | UX, CRAP, IA, the Bootstrap philosophy, Django Template Architecture, Crispy Forms, Tailwind vs Bootstrap, Static Files, React+Django |
| [CRISPY_FORMS.md](../../04_forms_and_validation/crispy_forms_full.md) | ~300 | 3 | A django-crispy-forms reference: FormHelper, all Layout components, template tags, examples |
| [HTML_BASICS.md](../../05_frontend_and_templates/html_basics_full.md) | 1038 | 1 | DOM pipeline, tags, forms, semantics, a11y, DevTools |
| [CSS_BASICS.md](../../05_frontend_and_templates/css_basics_full.md) | 1124 | 2 | Rendering Pipeline, Box Model, Flexbox, Grid, Holy Grail, Debugging |
| [BOOTSTRAP_5.md](../../05_frontend_and_templates/bootstrap_5_full.md) | 1388 | 3 | Grid, Breakpoints, Navbar, Card, Modal, Forms, JS API, Accessibility |
| [DJANGO_TEMPLATES_BOOTSTRAP.md](../../05_frontend_and_templates/django_templates_bootstrap_full.md) | 1015 | 4 | SSR lifecycle, DTL, Template Inheritance, Static Files, Bootstrap Forms |
| [DJANGO_NINJA_TEMPLATES.md](../../06_application_architecture/django_ninja_templates_full.md) | 960 | 5 | Django Ninja, TemplateResponse, Jinja2 intro, HTMX intro, Swagger |
| [ADVANCED_TEMPLATES.md](../../05_frontend_and_templates/advanced_templates_full.md) | 1506 | 6 | Context Processors, Custom Tags, crispy-forms, Vite, SaaS Dashboard, Jinja2 Deep Dive, HTMX lifecycle |
| [DJANGO_ADMIN_UNFOLD.md](../../05_frontend_and_templates/django_admin_unfold_full.md) | 2171 | 7 | Django Admin + Unfold: AdminSite, ModelAdmin, Dashboard, Widgets, Filters, Caching |

**Practical projects:**
- [django_bootstrap_project/README.md](../legacy_source/legacy_missing_reference.md) — CRUD notes: Navbar, Card Grid, Forms, Messages, Debug Toolbar
- [crispy_notes_chat_app/README.md](../../../README.md) — Notes CRUD with `django-crispy-forms` FormHelper+Layout, a SaaS Dashboard (`layouts/` + `components/`), a comparison of 3 levels of form rendering

---

## Section map

### HTML_BASICS.md
| § | Topic |
|---|------|
| 0 | The browser and HTML: DOM pipeline, Error Recovery, Design Principles |
| 1–2 | Anatomy of a document and of a tag |
| 3–6 | Headings, links, lists, tables |
| 7 | Forms — inputs, select, textarea, label, fieldset |
| 8–9 | HTML5 semantics: article, section, nav, aside, header, footer |
| 10–11 | id/class attributes, meta tags, SEO, Open Graph |
| 12 | Common beginner mistakes |
| 13 | Block vs Inline — the document flow model |
| 14 | Accessibility (ARIA, role, alt, tabindex, skip-link) |
| 15 | Data attributes — `data-*` |
| 16 | DevTools — source vs live DOM |
| 17 | A complete example — a semantic notes page |
| 18 | 10 self-check questions |

### CSS_BASICS.md
| § | Topic |
|---|------|
| 0 | Rendering Pipeline: DOM+CSSOM → Render Tree → Layout → Paint; Layout Thrashing |
| 1–3 | Including CSS, anatomy of a rule, selectors |
| 4 | Specificity: the (0,0,0,0) algorithm + prediction quiz |
| 5 | Box Model: margin/border/padding/content, `box-sizing` |
| 6 | Units: px, em, rem, %, vh/vw |
| 7 | `display`: block, inline, inline-block, none |
| 8 | Flexbox: `flex-direction`, `justify-content`, `align-items`, `flex-wrap` |
| 9 | CSS Grid: `grid-template-columns`, `fr`, `grid-area`, named areas |
| 10 | Positioning: static, relative, absolute, fixed, sticky |
| 11 | Media Queries + the Mobile First concept (min-width vs max-width) |
| 11b | Bootstrap Breakpoints: the xs–xxl table, quiz `col-12 col-md-6 col-lg-4` → [BOOTSTRAP_5.md §3] |
| 12 | CSS variables `--var`, `:root` |
| 13 | Typography |
| 14 | Holy Grail Layout: Grid macro + Flexbox micro |
| 15 | Practical patterns |
| 16 | Debugging CSS: margin collapse, stacking context, DevTools |
| 17 | CSS Performance: will-change, layer promotion |
| 18 | 10 self-check questions |

### BOOTSTRAP_5.md
| § | Topic |
|---|------|
| 0 | Why Bootstrap; Bootstrap vs Tailwind — the philosophical difference |
| 1 | Including via CDN; django-bootstrap5; Bootstrap in Django Templates |
| 2 | Grid System: Container → Row → Column, the math of 12 units, nested grids |
| 3 | Breakpoints: the xs/sm/md/lg/xl/xxl table; reading classes Mobile First; quiz answer |
| 4 | Utilities: spacing scale, colors, display/flexbox, typography, borders/shadows |
| 5 | Navbar: `navbar-expand-lg`, collapse, toggler, ARIA |
| 6 | Card: anatomy, `row-cols-*`, `h-100`, hover effect |
| 7 | Forms: `form-control`, Bootstrap validation, `was-validated` |
| 8 | Alerts: `alert-{variant}`, dismissible, Django Messages → Bootstrap |
| 9 | Modal: architecture, the data-bs API, JS Event Lifecycle (`show.bs.modal`, `shown.bs.modal`) |
| 10 | Bootstrap JS: Data API vs JavaScript API, Popper.js, Event Lifecycle |
| 11 | Accessibility: ARIA in components, `visually-hidden`, focus management |
| 12 | Anti-patterns: overriding Bootstrap, JS conflicts, CDN in production |
| 13 | A complete Django example: base.html + note_list.html with all components |
| 14 | 10 self-check questions |

### DJANGO_TEMPLATES_BOOTSTRAP.md
| § | Topic |
|---|------|
| 0 | Server-Side Rendering lifecycle: HTTP → View → Template Engine → HTTP Response → Browser |
| 1 | `render()` internals: Template.render(), RequestContext, context processors |
| 2 | Context and Dot-Lookup: dict → attribute → method → index (lookup order) |
| 3 | DTL syntax: `{{ }}`, `{% %}`, `\|filter`; if/elif/else, for+forloop, url, csrf_token, with, comment |
| 4 | Template Inheritance: `{% extends %}`, `{% block %}`, `{{ block.super }}`, a 3-level hierarchy |
| 5 | Static Files: `{% load static %}`, `{% static 'path' %}`, `collectstatic`, `ManifestStaticFilesStorage` |
| 6 | HttpRequest attributes; the HTTP request/response structure |
| 7 | Bootstrap Forms: manual rendering, Widget attrs, django-bootstrap5 `{% bootstrap_form %}` |
| 8 | Django Debug Toolbar: SQL Panel (N+1), Templates Panel; the PRG pattern; CSRF; XSS and `\|safe` |
| 9 | Anti-patterns: HTML in Python, hardcoded URL/static, a missing csrf_token |
| 10 | 10 self-check questions |

### DJANGO_NINJA_TEMPLATES.md
| § | Topic |
|---|------|
| 0–1 | Django Ninja vs DRF vs Views; installation, NinjaAPI, Router |
| 2 | HTML Response Pipeline: `render()` vs `TemplateResponse` under the hood |
| 3 | SSR Architecture in Ninja: a full Request Lifecycle ASCII diagram |
| 4 | JSON API vs HTML Endpoints: the same resource, two formats |
| 5 | Hybrid architecture: SSR + Ninja API + HTMX live search (intro) → [ADVANCED_TEMPLATES.md §7] |
| 6 | Jinja2 intro: a DTL vs Jinja2 table, Settings dual-backend, `jinja2_env.py`, a Ninja+Jinja2 endpoint → [ADVANCED_TEMPLATES.md §6] |
| 7 | TemplateResponse: deferred rendering, `post_render_callback`, middleware interception |
| 8 | Production Patterns: `cached.Loader`, production settings, Query Optimization in the View, Ninja caching |
| 9 | Ninja Schemas: Pydantic in/out, ModelSchema, a full CRUD Router |
| 10 | Swagger UI: `/api/docs/`, protecting it in production |
| 11 | Django View vs Ninja Endpoint — a comparison table |
| 12 | Anti-patterns |
| 13 | 10 self-check questions |

### ADVANCED_TEMPLATES.md
| § | Topic |
|---|------|
| 1 | Context Processors: built-in (`auth`, `request`, `messages`), a custom one with caching |
| 2 | Custom Template Tags: `simple_tag`, `inclusion_tag`, `filter`; the `templatetags/` structure |
| 3 | crispy-forms: `FormHelper`, `Layout`, `Row/Column/Fieldset/HTML/Submit` |
| 4 | Vite: `vite.config.js`, Bootstrap via npm/SCSS, `ManifestStaticFilesStorage`, a multi-stage Dockerfile |
| 5 | SaaS Dashboard: `base.html` → `layouts/dashboard.html` → `notes/list.html`; sidebar, topbar, pagination, empty_state, confirm_modal |
| 6 | Jinja2 Deep Dive: the `Environment` factory, macros `{% macro %}`, `{{ super() }}`, `FileSystemBytecodeCache`, streaming |
| 7 | HTMX lifecycle: a request lifecycle diagram, live search, infinite scroll, optimistic UI, a server-rendered Modal, the `HX-Redirect` response header |
| 8 | 10 self-check questions |

### DJANGO_ADMIN_UNFOLD.md
| § | Topic |
|---|------|
| 0 | Django Admin vs Unfold: architectural position, why Unfold |
| 1 | AdminSite: a singleton, several AdminSites for different roles, `each_context()` |
| 2 | ModelAdmin: `list_display`, `list_filter`, `fieldsets`, `inlines`, custom columns (`format_html`), actions, custom URLs |
| 3 | Admin Request Lifecycle: Middleware → `change_view` → permissions → form → `save_model` → `response_change` |
| 4 | ChangeList: a custom class, `ShowFacets` (Django 5.0+) |
| 5 | Query Architecture: N+1 in `list_display`, `list_select_related`, `search_fields` prefixes (`^`, `=`, `@`), `get_search_results()`, `prefetch_related` |
| 6 | Admin Rendering Pipeline: `TemplateResponse`, the template hierarchy (global/app/model), `base_site.html` |
| 7 | Unfold setup: `INSTALLED_APPS` order, the `UNFOLD` config, `COLORS`, `THEME`, `UnfoldModelAdmin` |
| 8 | Sidebar + Navigation: `SITE_DROPDOWN`, badge callbacks, `TABS` (static + dynamic callback) |
| 9 | Dashboard: `DASHBOARD_CALLBACK`, `templates/admin/index.html`, `unfold/layouts/base_simple.html` |
| 10 | Widget Systems: Card, Chart (line/bar), Tracker (heatmap), Cohort (retention table) |
| 11 | Information Hierarchy: Fieldset tabs, Conditional fields (Alpine.js), SortableStackedInline, Expandable Rows |
| 12 | Enterprise Patterns: a parallel `UnfoldAdminSite`, `InfinitePaginator`, crispy+Unfold, import/export, Command Palette |
| 13 | Anti-patterns: the admin as a frontend, State Leakage, XSS via `mark_safe`, slow search |
| 14 | 10 self-check questions |
| 15 | Advanced Filtering: `AutocompleteSelectFilter`, `RangeDateTimeFilter`, `TextFilter`, `list_filter_submit` |
| 16 | Bulk Actions + Dialog Actions: `BaseDialogForm`, row-level actions |
| 17 | Component Classes: `@register_component`, `get_context_data()` |
| 18 | Custom Pages: `UnfoldModelAdminViewMixin`, registering in the sidebar |
| 19 | Advanced Widgets: `WysiwygWidget`, `ArrayWidget`, `autocomplete_fields` |
| 20 | Performance: Redis caching, `{% cache %}`, `cached.Loader`, PostgreSQL Full-Text Search + GIN index |
| 21 | Datasets — an embedded ChangeList in the ChangeForm |
| 22 | Production Checklist (22 items: security, performance, architecture, UX) |

---

---

## 🗺️ The student's path — A detailed guide

> **How to use this path:**
> - Go through the steps in order — each step builds on the previous one
> - For each step: **read** → **write the code by hand** → **open it in the browser** → **play with DevTools**
> - Don't move on to the next step until you can explain the previous one "in simple words"

### A checkpoint question for each level

Before moving on, ask yourself:

**HTML level (steps 0-4):** Can I explain how the browser turns HTML text into a visual element?

**CSS level (steps 5-7):** Do I understand why `position: absolute` behaves differently depending on the parent element?

**Bootstrap level (steps 8-10):** Can I explain why Bootstrap uses `min-width` (not `max-width`) in media queries?

**Django Templates level (steps 11-14):** Do I understand the difference between `{{ }}` and `{% %}`? Can I explain when Python dies and only HTML lives on?

**Advanced level (steps 15-22):** Do I understand when to use HTMX instead of JavaScript, and why?

## The student's path

```
1.  HTML_BASICS.md §0         ← DOM pipeline: bytes → parser → DOM → CSSOM → paint
2.  HTML_BASICS.md §1–12      ← tags, forms, semantics, attributes, meta
3.  HTML_BASICS.md §13–18     ← Block/Inline, Accessibility, data-*, DevTools
    ↓
4.  CSS_BASICS.md §0          ← Rendering Pipeline: why CSS blocks rendering
5.  CSS_BASICS.md §1–11       ← syntax, specificity, Box Model, Flexbox, Grid
6.  CSS_BASICS.md §11b        ← Mobile First + Bootstrap quiz
7.  CSS_BASICS.md §14–18      ← Holy Grail Layout, Debugging, Performance
    ↓
8.  BOOTSTRAP_5.md §0–3       ← why Bootstrap, CDN, Grid architecture, Breakpoints
9.  BOOTSTRAP_5.md §4–7       ← utilities, Navbar, Card, Forms
10. BOOTSTRAP_5.md §8–11      ← Modal, JS API, Event Lifecycle, Accessibility
11. BOOTSTRAP_5.md §12–13     ← Anti-patterns, a full Django example
    ↓
    [Practice: django_bootstrap_project/README.md — steps 1–9]
    ↓
12. DJANGO_TEMPLATES_BOOTSTRAP.md §0–2  ← SSR lifecycle, render(), Context, Dot-Lookup
13. DJANGO_TEMPLATES_BOOTSTRAP.md §3–5  ← DTL syntax, Template Inheritance, Static
14. DJANGO_TEMPLATES_BOOTSTRAP.md §6–9  ← HttpRequest/Response, Bootstrap Forms, DjDT
    ↓
15. DJANGO_NINJA_TEMPLATES.md §0–4   ← Ninja API, HTML Pipeline, TemplateResponse
16. DJANGO_NINJA_TEMPLATES.md §5–8   ← HTMX intro, Jinja2 intro, Production Patterns
17. DJANGO_NINJA_TEMPLATES.md §9–13  ← Schemas, Swagger, anti-patterns
    ↓
18. ADVANCED_TEMPLATES.md §1–3  ← Context Processors, Custom Tags, crispy-forms
19. ADVANCED_TEMPLATES.md §4–5  ← Vite pipeline, SaaS Dashboard Architecture
20. ADVANCED_TEMPLATES.md §6–7  ← Jinja2 Deep Dive (macros, bytecode), HTMX lifecycle
    ↓
21. DJANGO_ADMIN_UNFOLD.md §0–6   ← Django Admin architecture, Query Optimization
22. DJANGO_ADMIN_UNFOLD.md §7–14  ← Unfold setup, Sidebar, Dashboard, Widgets
23. DJANGO_ADMIN_UNFOLD.md §15–22 ← Filters, Actions, Component Classes, Production
```

---

## ⚡ Quick start — for those in a hurry

If your time is limited:

### Minimal path (1 week):
1. HTML_BASICS §0-§8 (structure, forms)
2. CSS_BASICS §5, §8 (Box Model, Flexbox)
3. BOOTSTRAP_5 §2-§4 (Grid, Breakpoints, Utilities)
4. DJANGO_TEMPLATES_BOOTSTRAP §0-§4 (SSR, render(), DTL, Inheritance)

After this you will be able to build basic Django web pages.

### Full path (3-4 weeks):
All 23 steps of "The student's path" above.

After this you will be able to build production-ready Django applications with a modern UI.

---

## 🔧 Tools you need from day one

| Tool | Why | How to open it |
|-----------|--------|------------|
| Chrome DevTools | Debugging HTML/CSS, viewing the DOM | F12 or Ctrl+Shift+I |
| Django Debug Toolbar | SQL queries, template context | Install it in settings.py |
| Swagger UI | Testing the Django Ninja API | /api/docs/ |
| VS Code + Emmet | Writing HTML quickly | built into VS Code |

---

## 📊 Dependency map between concepts

> **Read from left to right:** if a concept is on the left, you need to understand it to understand the concept on the right.

```
HTML DOM
   ├──→ CSS Rendering Pipeline (CSSOM + DOM = Render Tree)
   │        └──→ Bootstrap Grid (uses Flexbox/CSS)
   │                 └──→ Bootstrap Components (Card, Modal, Navbar)
   └──→ HTML Forms (method, action, enctype)
            └──→ Django Forms (request.POST, is_valid(), save())
                     └──→ crispy-forms (forms + Bootstrap styling)

Django Templates (DTL)
   ├──→ Template Inheritance ({% extends %}, {% block %})
   │        └──→ SaaS Dashboard Architecture (3-level hierarchy)
   ├──→ Context Processors (global template variables)
   ├──→ Custom Template Tags (Python functions in templates)
   └──→ Jinja2 (alternative template engine, macros)

Django Ninja
   ├──→ Pydantic Schemas (data validation)
   ├──→ render() vs TemplateResponse (SSR)
   └──→ HTMX (server-driven UI, HTML fragments)
            └──→ Infinite Scroll, Live Search, Optimistic UI

Django Admin
   ├──→ ModelAdmin (list_display, fieldsets)
   ├──→ N+1 Problem (select_related, list_select_related)
   ├──→ Unfold (modern UI framework for admin)
   └──→ Dashboard Widgets (Chart, Card, Tracker, Cohort)
```

---

## 🆘 Stuck? Use this algorithm

```
A problem with HTML?
  → F12 → Elements → check the DOM (not the source! the DOM may differ)
  → HTML_BASICS §12 (common mistakes), §16 (DevTools)

A problem with CSS?
  → F12 → Elements → Styles (is the rule crossed out?)
  → F12 → Elements → Computed (which value is ACTUALLY applied?)
  → CSS_BASICS §16 (debugging algorithm), §4 (specificity)

A problem with the Bootstrap Grid?
  → Temporarily add: .row { background: rgba(255,0,0,0.1) }
  → BOOTSTRAP_5 §2 (Grid math), §3 (breakpoints)

A problem with a Django Template?
  → Django Debug Toolbar → Templates → context
  → Check: did you pass the context to render()?
  → DJANGO_TEMPLATES_BOOTSTRAP §2 (dot-lookup), §9 (anti-patterns)

A problem with a form (CSRF)?
  → F12 → Network → POST request → headers → is there a csrfmiddlewaretoken?
  → DJANGO_TEMPLATES_BOOTSTRAP §3 (csrf_token)

Way too many SQL queries?
  → Django Debug Toolbar → SQL panel
  → DJANGO_TEMPLATES_BOOTSTRAP §8, DJANGO_ADMIN_UNFOLD §5

HTMX doesn't work?
  → F12 → Network → is a request sent on interaction?
  → F12 → Console → are there any JavaScript errors?
  → ADVANCED_TEMPLATES §7

Django Admin is slow?
  → Django Debug Toolbar on the Admin list → check the SQL count
  → DJANGO_ADMIN_UNFOLD §5 (N+1), §12 (InfinitePaginator)
```

---

## Where to find what

| Question | File | § |
|---------|------|---|
| How does the browser read HTML? | HTML_BASICS.md | §0 |
| `<div>` vs `<section>` — the difference? | HTML_BASICS.md | §8 |
| ARIA and accessibility | HTML_BASICS.md | §14 |
| How to debug the DOM in DevTools? | HTML_BASICS.md | §16 |
| What is the Box Model? | CSS_BASICS.md | §5 |
| Flexbox vs Grid — when to use which? | CSS_BASICS.md | §8–9 |
| Mobile First: min-width or max-width? | CSS_BASICS.md | §11 |
| The Bootstrap breakpoints table | BOOTSTRAP_5.md | §3 |
| Bootstrap Grid — 3 columns | BOOTSTRAP_5.md | §2–3 |
| A Navbar with a hamburger | BOOTSTRAP_5.md | §5 |
| A Modal with dynamic data | BOOTSTRAP_5.md | §9 |
| Django Messages → Bootstrap Alert | BOOTSTRAP_5.md | §8 |
| `{% extends %}` and `{% block %}` | DJANGO_TEMPLATES_BOOTSTRAP.md | §4 |
| Dot-Lookup `{{ user.profile.name }}` | DJANGO_TEMPLATES_BOOTSTRAP.md | §2 |
| Bootstrap Forms in Django | DJANGO_TEMPLATES_BOOTSTRAP.md | §7 |
| CSRF token — why | DJANGO_TEMPLATES_BOOTSTRAP.md | §8 |
| Django Debug Toolbar SQL Panel | DJANGO_TEMPLATES_BOOTSTRAP.md | §8 |
| `render()` vs `TemplateResponse` | DJANGO_NINJA_TEMPLATES.md | §2, §7 |
| Django Ninja vs DRF | DJANGO_NINJA_TEMPLATES.md | §0 |
| HTMX hx-trigger, hx-target | ADVANCED_TEMPLATES.md | §7 |
| Context Processor — a global context | ADVANCED_TEMPLATES.md | §1 |
| `inclusion_tag` — a reusable component | ADVANCED_TEMPLATES.md | §2 |
| crispy-forms FormHelper Python layout | ADVANCED_TEMPLATES.md | §3 |
| Vite + Django setup | ADVANCED_TEMPLATES.md | §4 |
| SaaS sidebar layout | ADVANCED_TEMPLATES.md | §5 |
| Jinja2 macros and the bytecode cache | ADVANCED_TEMPLATES.md | §6 |
| ModelAdmin `list_display`, actions | DJANGO_ADMIN_UNFOLD.md | §2 |
| N+1 in the admin — `list_select_related` | DJANGO_ADMIN_UNFOLD.md | §5 |
| The Unfold UNFOLD config in settings.py | DJANGO_ADMIN_UNFOLD.md | §7 |
| Unfold Dashboard + DASHBOARD_CALLBACK | DJANGO_ADMIN_UNFOLD.md | §9 |
| InfinitePaginator — without COUNT(*) | DJANGO_ADMIN_UNFOLD.md | §12 |
| A Dialog Action with a Bootstrap form | DJANGO_ADMIN_UNFOLD.md | §16 |
| Full-text Search (PostgreSQL SearchVector) | DJANGO_ADMIN_UNFOLD.md | §20 |

---

## Relationships between the files

```
HTML_BASICS ──────────────────► CSS_BASICS
(DOM tree)                       (CSSOM, Rendering Pipeline)
     │                                │
     └──────────┬─────────────────────┘
                ▼
           BOOTSTRAP_5
           (Grid, Navbar, Modal — built on HTML+CSS)
                │
                ▼
     DJANGO_TEMPLATES_BOOTSTRAP
     (DTL renders Bootstrap HTML on the server)
                │
                ├──► DJANGO_NINJA_TEMPLATES
                │    (API + Jinja2 + HTMX intro)
                │
                └──► ADVANCED_TEMPLATES
                     (Context Processors, Custom Tags,
                      crispy-forms, Vite, Jinja2 deep dive,
                      HTMX lifecycle)
                          │
                          ▼
                  DJANGO_ADMIN_UNFOLD
                  (internal tools — a separate layer)
```

**Where there are cross-references between files:**
- `CSS_BASICS.md §11b` → the Bootstrap breakpoints table in detail in `BOOTSTRAP_5.md §3`
- `CSS_BASICS.md §11b` → Bootstrap utilities → `BOOTSTRAP_5.md §4`
- `DJANGO_NINJA_TEMPLATES.md §5` → the full HTMX lifecycle → `ADVANCED_TEMPLATES.md §7`
- `DJANGO_NINJA_TEMPLATES.md §6` → Jinja2 macros/bytecode → `ADVANCED_TEMPLATES.md §6`
