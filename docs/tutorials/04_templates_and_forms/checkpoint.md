# Checkpoint — Крок 4

---

## Структура файлів після кроку 4

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
│   ├── services.py               ← create/update/delete для всіх моделей
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
│       ├── note_detail.html          ← з inline ReminderForm (form_action у view)
│       ├── note_form.html            ← Tier 3: {% crispy form %}  ★
│       ├── note_confirm_delete.html
│       ├── notebook_list.html
│       ├── notebook_form.html        ← {% crispy form %}
│       ├── tag_form.html             ← {% crispy form %}
│       ├── todo_list.html            ← мої + спільні списки справ
│       ├── todo_detail.html          ← inline TodoItemForm (form_tag=False)
│       ├── todo_form.html            ← {% crispy form %}
│       ├── todo_confirm_delete.html
│       ├── shopping_list.html
│       ├── shopping_detail.html      ← inline ShopItemForm (form_tag=False)
│       ├── shopping_form.html        ← {% crispy form %}
│       ├── shopping_confirm_delete.html
│       └── share_form.html           ← ShareForm (додати юзера до shared_with)
│
└── templates/                    ← ГЛОБАЛЬНІ шаблони (DIRS в settings)
    ├── base.html                      ← Рівень 1: HTML5 + Bootstrap CDN
    ├── layouts/
    │   └── dashboard.html             ← Рівень 2: Sidebar (НОТАТКИ/ЗАДАЧІ/ТЕГИ) + Topbar
    ├── registration/
    │   ├── login.html                 ← Bootstrap card, посилання на register
    │   └── register.html             ← реєстрація нового користувача
    └── components/
        ├── pagination.html            ← Bootstrap pagination
        ├── empty_state.html           ← "немає даних" placeholder
        └── confirm_modal.html         ← Bootstrap modal для delete
```

---

## Чеклист самоперевірки

- [ ] 3 рівні: `base.html` → `layouts/dashboard.html` → page template
- [ ] `{% block body %}` у `base.html`, `{% block content %}` у `dashboard.html`
- [ ] Context Processor зареєстрований у `settings.py` → `context_processors`
- [ ] `sidebar_notebooks` і `sidebar_tags` доступні у шаблоні без явної передачі
- [ ] `{% crispy form %}` рендерить форму з Bootstrap-класами
- [ ] `FormHelper.layout` описує структуру форми Python-кодом
- [ ] Active state через `request.resolver_match.url_name`
- [ ] Logout — POST форма (не GET посилання) для захисту від CSRF
- [ ] `DIRS = [BASE_DIR / 'templates']` у `TEMPLATES` — для глобальних шаблонів
- [ ] `form_tag = False` для inline-форм (TodoItemForm, ShopItemForm)
- [ ] `try/except OperationalError` у context processor
- [ ] `MESSAGE_TAGS` налаштований у settings.py

---

## Типові помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` не там де Django шукає | Файл має бути в `templates/base.html` (з `DIRS`) або в `hello_app/templates/base.html` |
| `NoReverseMatch: 'note_create'` | URL name не зареєстровано або не той namespace | Перевір `hello_app/urls.py` і `app_name = 'hello_app'` |
| `403 Forbidden` після POST | Відсутній `{% csrf_token %}` у формі | Додай `{% csrf_token %}` всередину `<form>` |
| Crispy не застосовує Bootstrap стилі | Не вказано `CRISPY_TEMPLATE_PACK` | Додай `CRISPY_TEMPLATE_PACK = 'bootstrap5'` у settings.py |
| Sidebar порожній | Context Processor не зареєстрований | Перевір `TEMPLATES OPTIONS context_processors` |
| `AppRegistryNotReady` | Неправильний порядок імпортів | Перевір `INSTALLED_APPS` — crispy до hello_app |
| Active state не спрацьовує | `request` не в context | Додай `django.template.context_processors.request` |
| Debug Toolbar не з'являється | Не виконано умови | Перевір `DEBUG=True`, `INTERNAL_IPS`, `<body>` тег |
| Cards різної висоти | Немає `h-100` на `.card` | Додай `h-100` до `<div class="card">` |
| Футер посередині сторінки | Відсутні Sticky Footer класи | Додай `d-flex flex-column min-vh-100` на `<body>` |

---

## Практичне завдання

1. Відкрий `hello_app/templates/hello_app/note_list.html` → `templates/layouts/dashboard.html` → `templates/base.html`. Відслідкуй ланцюг `{% extends %}`.
2. Додай новий пункт у Sidebar для "Архів" (`/notes/?archived=1`).
3. Перепиши одну форму з ручного Bootstrap HTML на Crispy FormHelper + Layout.
4. Перевір active state: натискаючи різні пункти меню — підсвітка переміщається.
5. Додай Context Processor що передає кількість нових нотаток за сьогодні.

---

## Де читати теорію — швидкий довідник

| Концепція | Де у коді |
|-----------|-----------|
| **Template Inheritance** | `base.html` → `layouts/dashboard.html` → `note_list.html` |
| **`{% block %}`** | `{% block content %}{% endblock %}` у батьку + `{% block content %}...{% endblock %}` у дочірньому |
| **`{{ block.super }}`** | Додає вміст батьківського блоку замість заміни |
| **FormHelper** | `self.helper = FormHelper()` у `forms.py.__init__` |
| **Layout** | `Layout(Fieldset(...), Row(Column(...)), Submit(...))` |
| **`{% crispy form %}`** | У шаблоні — 1 рядок замість 90 |
| **Context Processor** | `hello_app/context_processors.py → sidebar_context(request)` |
| **Реєстрація процесора** | `settings.py TEMPLATES OPTIONS context_processors` |
| **Active nav** | `request.resolver_match.url_name == 'note_list'` |
| **Static files** | `{% load static %}{% static 'hello_app/css/custom.css' %}` |
| **form_tag = False** | `forms.py` — `TodoItemForm`, `ShopItemForm` (inline forms) |
| **OperationalError guard** | `context_processors.py` — `try/except` для нових таблиць |
| **M2M shared_with** | `models.py` `TodoList.shared_with` + міграція 0002 |
| **Django Messages** | `dashboard.html` блок `{% if messages %}` + `settings.py MESSAGE_TAGS` |
| **Components** | `templates/components/` + `{% include %}` у сторінках |

---

## Навігація

- Попередній: [Крок 3. CRUD і архітектура](../03_crud_and_architecture/index.md)
- Наступний: Крок 5. Auth і безпека
