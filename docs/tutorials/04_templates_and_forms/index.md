# Крок 4. Templates і Forms

> **Навчальний проєкт:** `crispy_notes` — standalone застосунок на SQLite, без автентифікації.
> Це четвертий крок еволюції: будуємо SaaS Dashboard з 3-рівневою Template Inheritance, переходимо від ручного Bootstrap HTML до `{% crispy form %}`, реалізуємо Context Processor для Sidebar.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 1. Hello Django](../01_hello_django/index.md) — перший `HttpResponse`, URL routing
    - [Крок 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Крок 3. CRUD і архітектура](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL

---

## Навчальний проєкт vs Notes Chat App

| | crispy_notes (цей крок) | notes_chat_app (кінцева мета) |
|-|-------------------------|-------------------------------|
| Проєкт | Standalone (SQLite) | Docker + PostgreSQL |
| Auth | Базова реєстрація/логін | `@login_required`, Groups, sharing |
| Моделі | Note, Notebook, Tag, TodoList, ShoppingList | Ті самі + ChatMessage |
| Template hierarchy | 3-рівнева: base → dashboard → page | Та сама ієрархія |
| Forms | Crispy Forms + FormHelper + Layout | Ті самі + WebSocket форми |
| Sidebar | Context Processor | Context Processor (ідентично) |
| Admin | Unfold Admin | Unfold Admin |

---

## Результат кроку

Після завершення цього кроку в тебе буде:

```
http://127.0.0.1:8000/notes/           →  Dashboard: список нотаток + sidebar
http://127.0.0.1:8000/notes/new/       →  Tier 3: {% crispy form %} — Bootstrap форма
http://127.0.0.1:8000/notebooks/       →  Список записників
http://127.0.0.1:8000/todo/            →  Списки справ (ЗАДАЧІ секція)
http://127.0.0.1:8000/shopping/        →  Списки покупок
http://127.0.0.1:8000/register/        →  Реєстрація нового користувача
http://127.0.0.1:8000/admin/           →  Django Admin (Unfold)
```

---

## Що ти вивчиш

- **Template Inheritance** — 3-рівнева ієрархія SaaS Dashboard: `base.html` → `layouts/dashboard.html` → page
- **Template Soup** — проблема дублювання і чому наслідування вирішує її
- **`{% block %}` і `{% block.super %}`** — як розширювати батьківські блоки
- **Forms Evolution** — три рівні рендерингу: `{{ form.as_p }}` → ручний Bootstrap HTML → `{% crispy form %}`
- **FormHelper + Layout** — описуємо структуру форми Python-кодом
- **Layout Elements** — `Field`, `Row`, `Column`, `Fieldset`, `Submit`, `Div`, `HTML`
- **Context Processor** — автоматична передача даних у кожен шаблон
- **Active Nav State** — `request.resolver_match.url_name`
- **Bootstrap Advanced** — Cards, Sticky Footer, Navbar, Messages, Unfold Admin, Debug Toolbar
- **Компоненти** — `empty_state.html`, `pagination.html`, `confirm_modal.html`

---

## Порядок читання

1. **[Template Inheritance](template_inheritance.md)** — Template Soup, 3-рівнева ієрархія, `{% block %}`, `{% block.super %}`
2. **[Forms Evolution](forms_evolution.md)** — Tier 1 (Raw) / Tier 2 (Manual Bootstrap) / Tier 3 (Crispy)
3. **[Crispy Forms](crispy_forms.md)** — FormHelper, Layout, Layout Elements, `form_tag = False`
4. **[Dashboard Architecture](dashboard_architecture.md)** — структура Dashboard, Sidebar, Topbar, сторінки
5. **[Context Processor](context_processor.md)** — як працює, код `context_processors.py`, Static Files
6. **[Components](components.md)** — `empty_state`, `pagination`, `confirm_modal`, Template Tags/Filters
7. **[Bootstrap Advanced](bootstrap_advanced.md)** — Підключення Bootstrap 5, `base.html`, Cards, Unfold Admin, Debug Toolbar
8. **[Checkpoint](checkpoint.md)** — структура файлів, чеклист, типові помилки, практичне завдання
