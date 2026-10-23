# Checkpoint — Step 4

---

## File structure after step 4

```
crispy_notes_project/
│
├── requirements.txt              ← django-crispy-forms, crispy-bootstrap5, debug-toolbar
│
├── hello_project/
│   ├── settings.py               ← CRISPY_TEMPLATE_PACK, context_processors, MESSAGE_TAGS
│   └── urls.py                   ← accounts/ (login/logout) + hello_app/ + debug_toolbar
│
├── hello_app/
│   ├── models.py                 ← Note, Notebook, Tag, TodoList, TodoItem,
│   │                                ShoppingList, ShopItem, Reminder
│   ├── services.py               ← create/update/delete for all models
│   ├── selectors.py              ← get_user_notes, get_user_notebooks, get_user_tags,
│   │                                get_todo_lists, get_shopping_lists...
│   ├── context_processors.py     ← sidebar_context → notebooks, tags,
│   │                                todo_count, shopping_count (+ OperationalError guard)
│   ├── forms.py                  ← ★ NoteForm, NotebookForm, TagForm,
│   │                                TodoListForm, TodoItemForm (form_tag=False),
│   │                                ShoppingListForm, ShopItemForm (form_tag=False),
│   │                                ReminderForm, ShareForm
│   ├── views.py                  ← note CRUD + todo CRUD + shopping CRUD + reminders + register
│   ├── urls.py
│   ├── migrations/
│   │   ├── 0001_initial.py
│   │   └── 0002_shoppinglist_shared_with_todolist_shared_with.py  ← M2M shared_with
│   └── templates/hello_app/
│       ├── note_list.html            ← extends layouts/dashboard.html
│       ├── note_detail.html          ← with an inline ReminderForm (form_action in the view)
│       ├── note_form.html            ← Tier 3: {% crispy form %}  ★
│       ├── note_confirm_delete.html
│       ├── notebook_list.html
│       ├── notebook_form.html        ← {% crispy form %}
│       ├── tag_form.html             ← {% crispy form %}
│       ├── todo_list.html            ← my + shared to-do lists
│       ├── todo_detail.html          ← inline TodoItemForm (form_tag=False)
│       ├── todo_form.html            ← {% crispy form %}
│       ├── todo_confirm_delete.html
│       ├── shopping_list.html
│       ├── shopping_detail.html      ← inline ShopItemForm (form_tag=False)
│       ├── shopping_form.html        ← {% crispy form %}
│       ├── shopping_confirm_delete.html
│       └── share_form.html           ← ShareForm (add a user to shared_with)
│
└── templates/                    ← GLOBAL templates (DIRS in settings)
    ├── base.html                      ← Level 1: HTML5 + Bootstrap CDN
    ├── layouts/
    │   └── dashboard.html             ← Level 2: Sidebar (NOTES/TASKS/TAGS) + Topbar
    ├── registration/
    │   ├── login.html                 ← Bootstrap card, link to register
    │   └── register.html             ← new user registration
    └── components/
        ├── pagination.html            ← Bootstrap pagination
        ├── empty_state.html           ← "no data" placeholder
        └── confirm_modal.html         ← Bootstrap modal for delete
```

---

## Self-check checklist

- [ ] 3 levels: `base.html` → `layouts/dashboard.html` → page template
- [ ] `{% block body %}` in `base.html`, `{% block content %}` in `dashboard.html`
- [ ] The Context Processor is registered in `settings.py` → `context_processors`
- [ ] `sidebar_notebooks` and `sidebar_tags` are available in the template without passing them explicitly
- [ ] `{% crispy form %}` renders the form with Bootstrap classes
- [ ] `FormHelper.layout` describes the form structure in Python code
- [ ] Active state via `request.resolver_match.url_name`
- [ ] Logout is a POST form (not a GET link) for CSRF protection
- [ ] `DIRS = [BASE_DIR / 'templates']` in `TEMPLATES` — for global templates
- [ ] `form_tag = False` for inline forms (TodoItemForm, ShopItemForm)
- [ ] `try/except OperationalError` in the context processor
- [ ] `MESSAGE_TAGS` is configured in settings.py

---

## Common mistakes

| Error | Cause | Solution |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` is not where Django looks for it | The file must be in `templates/base.html` (via `DIRS`) or in `hello_app/templates/base.html` |
| `NoReverseMatch: 'note_create'` | The URL name is not registered, or the namespace is wrong | Check `hello_app/urls.py` and `app_name = 'hello_app'` |
| `403 Forbidden` after a POST | `{% csrf_token %}` is missing from the form | Add `{% csrf_token %}` inside `<form>` |
| Crispy does not apply Bootstrap styles | `CRISPY_TEMPLATE_PACK` is not set | Add `CRISPY_TEMPLATE_PACK = 'bootstrap5'` to settings.py |
| The sidebar is empty | The Context Processor is not registered | Check `TEMPLATES OPTIONS context_processors` |
| `AppRegistryNotReady` | Models are imported before Django finishes initializing (e.g. in `settings.py` or `hello_app/__init__.py`) | Remove module-level model imports from those files; the `crispy_forms`/`hello_app` order in `INSTALLED_APPS` does not cause this error |
| Active state does not work | `request` is not in the context | Add `django.template.context_processors.request` |
| Debug Toolbar does not appear | Conditions are not met | Check `DEBUG=True`, `INTERNAL_IPS`, the `<body>` tag |
| Cards of different heights | No `h-100` on `.card` | Add `h-100` to `<div class="card">` |
| Footer in the middle of the page | Sticky Footer classes are missing | Add `d-flex flex-column min-vh-100` to `<body>` |

---

## Practical exercise

1. Open `hello_app/templates/hello_app/note_list.html` → `templates/layouts/dashboard.html` → `templates/base.html`. Trace the `{% extends %}` chain.
2. Add a new Sidebar item for "Archive" (`/notes/?archived=1`).
3. Rewrite one form from hand-written Bootstrap HTML to a Crispy FormHelper + Layout.
4. Check the active state: as you click different menu items, the highlight moves.
5. Add a Context Processor that passes the number of new notes created today.

---

## Where to read the theory — quick reference

| Concept | Where in the code |
|-----------|-----------|
| **Template Inheritance** | `base.html` → `layouts/dashboard.html` → `note_list.html` |
| **`{% block %}`** | `{% block content %}{% endblock %}` in the parent + `{% block content %}...{% endblock %}` in the child |
| **`{{ block.super }}`** | Adds the parent block's content instead of replacing it |
| **FormHelper** | `self.helper = FormHelper()` in `forms.py.__init__` |
| **Layout** | `Layout(Fieldset(...), Row(Column(...)), Submit(...))` |
| **`{% crispy form %}`** | In the template — 1 line instead of 90 |
| **Context Processor** | `hello_app/context_processors.py → sidebar_context(request)` |
| **Registering the processor** | `settings.py TEMPLATES OPTIONS context_processors` |
| **Active nav** | `request.resolver_match.url_name == 'note_list'` |
| **Static files** | `{% load static %}{% static 'hello_app/css/custom.css' %}` |
| **form_tag = False** | `forms.py` — `TodoItemForm`, `ShopItemForm` (inline forms) |
| **OperationalError guard** | `context_processors.py` — `try/except` for new tables |
| **M2M shared_with** | `models.py` `TodoList.shared_with` + migration 0002 |
| **Django Messages** | `dashboard.html` block `{% if messages %}` + `settings.py MESSAGE_TAGS` |
| **Components** | `templates/components/` + `{% include %}` in pages |

---

## Navigation

- Previous: [Step 3. CRUD and architecture](../03_crud_and_architecture/index.md)
- Next: Step 5. Auth and security
