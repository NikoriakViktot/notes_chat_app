# Крок 3. CRUD і архітектура

> **Навчальний проєкт:** `notes_project` — standalone застосунок, що починає з SQLite і переходить на PostgreSQL.
> Це третій крок еволюції. Ти проходиш повний цикл: від проектування домену до готового застосунку з архітектурою Services & Selectors.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 1. Hello Django](../01_hello_django/index.md) — базовий Django-проєкт, перший `HttpResponse`
    - [Крок 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD

---

## Навчальний стан vs Notes Chat App

| | notes_project (цей крок) | notes_chat_app (кінцева мета) |
|-|--------------------------|-------------------------------|
| Проєкт | Standalone (SQLite → PostgreSQL) | Docker + PostgreSQL |
| Auth | Немає / базовий `@login_required` | `@login_required`, Groups, sharing |
| Моделі | 9 моделей: UserProfile, Tag, Notebook, Note, Reminder, TodoList, TodoItem, ShoppingList, ShopItem | Ті самі + Group (Django built-in) + ChatMessage |
| Views | FBV + selectors + services | FBV/CBV + selectors + services |
| Архітектура | Services & Selectors | Services & Selectors (ідентично) |
| Зв'язки | 1:1, 1:N, M:N — всі типи | Ті самі + Group M:N для sharing |

---

## Результат кроку

Після завершення цього кроку в тебе буде:

```
http://localhost:8000/             →  Index
http://localhost:8000/notes/       →  Список нотаток (пошук, фільтри, теги)
http://localhost:8000/notes/new/   →  Форма створення нотатки
http://localhost:8000/notes/1/     →  Деталь нотатки (з нагадуваннями)
http://localhost:8000/notes/1/edit/   →  Форма редагування
http://localhost:8000/notes/1/delete/ →  Підтвердження видалення (POST only)
http://localhost:8000/notebooks/      →  Список записників
http://localhost:8000/notebooks/new/  →  Новий записник
http://localhost:8000/tags/new/       →  Новий тег
http://localhost:8000/admin/          →  Django Admin (з select_related)
```

---

## Що ти вивчиш

- **7-крокова методологія** проектування БД: Домен → Сутності → Атрибути → Зв'язки → Нормалізація → on_delete → Django Модель
- **ER-діаграми** — усі типи зв'язків: 1:1, 1:N, M:N
- **Services & Selectors** — архітектурний поділ шарів відповідальності
- `selectors.py` — тільки SELECT-запити з оптимізацією
- `services.py` — CREATE / UPDATE / DELETE з `transaction.atomic()`
- **N+1 проблема** і вирішення: `select_related`, `prefetch_related`
- `transaction.atomic()`, `F()`, `select_for_update()`
- **Class-Based Views (CBV)** — `LoginRequiredMixin`, `UserQuerySetMixin`, `ListView`, `CreateView`, `UpdateView`, `DeleteView`
- Перехід з **SQLite на PostgreSQL** через Docker

---

## Порядок читання

1. **[Проектування домену](domain_design.md)** — 7-крокова методологія, де живе правда, аналіз вимог
2. **[ER-діаграми](er_diagrams.md)** — типи зв'язків, on_delete матриця, повна схема 11 таблиць
3. **[Django моделі](models.md)** — повний код усіх моделей, ORM QuerySet API
4. **[Міграції](migrations.md)** — Migration Lifecycle, DAG залежностей, перший запуск з SQLite
5. **[Services і Selectors](services_and_selectors.md)** — архітектура шарів, READ/WRITE flow, повний код
6. **[QuerySet глибоко](queryset_deep.md)** — нормалізація, N+1, select_related, prefetch_related, F(), transactions
7. **[PostgreSQL](postgresql.md)** — Docker, налаштування Django, перенесення даних
8. **[Class-Based Views](cbv.md)** — CBV vs FBV, Generic Views, Mixins, хуки
9. **[Чекпоінт](checkpoint.md)** — чеклист, типові помилки, практичне завдання
