# Крок 2. Bootstrap Notes

> **Навчальний проєкт:** `bootstrap_notes` — standalone застосунок (SQLite, без PostgreSQL).
> Це другий крок еволюції. Ти переходиш від `HttpResponse("текст")` до повноцінного CRUD з Bootstrap UI.
>
> **Передумови:** пройдений [Крок 1. Hello Django](../01_hello_django/index.md) — є `Note` модель і Django-проєкт.

---

## Результат кроку

```
http://localhost:8000/             →  Редирект на /notes/
http://localhost:8000/notes/       →  Список нотаток — Bootstrap Cards Grid
http://localhost:8000/notes/new/   →  Форма створення (ModelForm + PRG)
http://localhost:8000/notes/1/     →  Деталь нотатки
http://localhost:8000/notes/1/edit/   →  Форма редагування
http://localhost:8000/notes/1/delete/ →  Підтвердження видалення (POST only)
http://localhost:8000/admin/       →  Django Admin з кастомним NoteAdmin
```

---

## Що ти вивчиш

- `ModelForm` — автоматична форма з моделі
- PRG-паттерн (Post/Redirect/Get) — захист від дублікатів при F5
- Django Messages — Flash-повідомлення
- Template Inheritance — `base.html` і блоки `{% extends %}` / `{% block %}`
- Bootstrap 5 — Grid, Cards, Navbar, Sticky Footer
- CRUD views: `note_create`, `note_edit`, `note_delete`, `note_detail`
- `get_object_or_404` — безпечна заміна `objects.get()`

---

## Структура після завершення кроку

```
bootstrap_notes/
├── manage.py
├── requirements.txt           ← Django + django-bootstrap5
├── db.sqlite3
├── hello_project/
│   ├── settings.py            ← MESSAGE_TAGS, INSTALLED_APPS
│   └── urls.py
└── hello_app/
    ├── models.py              ← Note (з Кроку 1)
    ├── forms.py               ← NoteForm (ModelForm) ← НОВИЙ
    ├── views.py               ← 5 CRUD views ← РОЗШИРЕНО
    ├── urls.py                ← 6 маршрутів ← РОЗШИРЕНО
    ├── admin.py               ← NoteAdmin кастомний
    ├── migrations/
    └── templates/
        ├── base.html          ← Bootstrap CDN, Navbar, Messages ← НОВИЙ
        └── hello_app/
            ├── note_list.html     ← Card Grid ← ПЕРЕПИСАНИЙ
            ├── note_detail.html   ← Деталь + Breadcrumb ← НОВИЙ
            ├── note_form.html     ← Bootstrap Form ← НОВИЙ
            └── note_confirm_delete.html ← Видалення ← НОВИЙ
```

---

## Навчальний стан vs Notes Chat App

| | bootstrap_notes (цей крок) | notes_chat_app (кінцева мета) |
|-|---------------------------|-------------------------------|
| Проєкт | Standalone SQLite | Docker + PostgreSQL |
| Auth | Немає | `@login_required`, Groups |
| ModelForm | Базовий `NoteForm` | Складніші форми з `clean_*()` |
| Views | FBV без перевірки юзера | FBV + selectors + services |
| Templates | Bootstrap CDN, 4 шаблони | Bootstrap SaaS ієрархія: base → layout → page |
| Admin | `NoteAdmin(admin.ModelAdmin)` | `NoteAdmin` + Unfold Admin |

---

## Порядок читання цього кроку

1. **[Моделі і міграції](models_and_migrations.md)** — Note модель, makemigrations, migrate, запуск проєкту
2. **[Django Admin](django_admin.md)** — реєстрація моделей, кастомний ModelAdmin
3. **[ModelForm і CRUD](modelform_and_crud.md)** — ModelForm, PRG, Messages, base.html, всі CRUD views і шаблони
4. **[Контрольна точка](checkpoint.md)** — чеклист, типові помилки, практичні завдання
