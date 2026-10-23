# Step 4. Templates and Forms

> **Tutorial project:** `crispy_notes` — a standalone application on SQLite, without authentication.
> This is the fourth step of the evolution: we build a SaaS Dashboard with 3-level Template Inheritance, move from hand-written Bootstrap HTML to `{% crispy form %}`, and implement a Context Processor for the Sidebar.

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 1. Hello Django](../01_hello_django/index.md) — the first `HttpResponse`, URL routing
    - [Step 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Step 3. CRUD and architecture](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL

---

## Tutorial project vs Notes Chat App

| | crispy_notes (this step) | notes_chat_app (final goal) |
|-|-------------------------|-------------------------------|
| Project | Standalone (SQLite) | Docker + PostgreSQL |
| Auth | Basic registration/login | `@login_required`, Groups, sharing |
| Models | Note, Notebook, Tag, TodoList, ShoppingList | The same + ChatMessage |
| Template hierarchy | 3-level: base → dashboard → page | The same hierarchy |
| Forms | Crispy Forms + FormHelper + Layout | The same + WebSocket forms |
| Sidebar | Context Processor | Context Processor (identical) |
| Admin | Unfold Admin | Unfold Admin |

---

## Result of this step

After completing this step you will have:

```
http://127.0.0.1:8000/notes/           →  Dashboard: note list + sidebar
http://127.0.0.1:8000/notes/new/       →  Tier 3: {% crispy form %} — Bootstrap form
http://127.0.0.1:8000/notebooks/       →  Notebook list
http://127.0.0.1:8000/todo/            →  Todo lists (TASKS section)
http://127.0.0.1:8000/shopping/        →  Shopping lists
http://127.0.0.1:8000/register/        →  New user registration
http://127.0.0.1:8000/admin/           →  Django Admin (Unfold)
```

---

## What you will learn

- **Template Inheritance** — the 3-level SaaS Dashboard hierarchy: `base.html` → `layouts/dashboard.html` → page
- **Template Soup** — the duplication problem and why inheritance solves it
- **`{% block %}` and `{% block.super %}`** — how to extend parent blocks
- **Forms Evolution** — three rendering levels: `{{ form.as_p }}` → hand-written Bootstrap HTML → `{% crispy form %}`
- **FormHelper + Layout** — describing the form structure in Python code
- **Layout Elements** — `Field`, `Row`, `Column`, `Fieldset`, `Submit`, `Div`, `HTML`
- **Context Processor** — automatically passing data to every template
- **Active Nav State** — `request.resolver_match.url_name`
- **Bootstrap Advanced** — Cards, Sticky Footer, Navbar, Messages, Unfold Admin, Debug Toolbar
- **Components** — `empty_state.html`, `pagination.html`, `confirm_modal.html`

---

## Reading order

1. **[Template Inheritance](template_inheritance.md)** — Template Soup, the 3-level hierarchy, `{% block %}`, `{% block.super %}`
2. **[Forms Evolution](forms_evolution.md)** — Tier 1 (Raw) / Tier 2 (Manual Bootstrap) / Tier 3 (Crispy)
3. **[Crispy Forms](crispy_forms.md)** — FormHelper, Layout, Layout Elements, `form_tag = False`
4. **[Dashboard Architecture](dashboard_architecture.md)** — Dashboard structure, Sidebar, Topbar, pages
5. **[Context Processor](context_processor.md)** — how it works, the `context_processors.py` code, Static Files
6. **[Components](components.md)** — `empty_state`, `pagination`, `confirm_modal`, Template Tags/Filters
7. **[Bootstrap Advanced](bootstrap_advanced.md)** — Adding Bootstrap 5, `base.html`, Cards, Unfold Admin, Debug Toolbar
8. **[Checkpoint](checkpoint.md)** — file structure, checklist, common mistakes, practical exercise
