# Крок 1. Hello Django

> Ти пройдеш від **порожньої папки** до повноцінного Django-сайту з view-функціями,
> URL-роутингом, адмін-панеллю та першою моделлю.
>
> **Навчальний проєкт:** `hello_project` — standalone застосунок (SQLite, без PostgreSQL).
> Це перший крок еволюції. Фінальна архітектура з'явиться пізніше.

---

## Результат кроку

```
http://localhost:8000/        →  Hello, Django!
http://localhost:8000/about/  →  Це моя перша сторінка на Django!
http://localhost:8000/notes/  →  Список нотаток з HTML-шаблоном
http://localhost:8000/admin/  →  Адмін-панель (superuser)
```

---

## Що ти вивчиш

- Як Django обробляє HTTP-запит (Request/Response цикл)
- Структура проєкту: `startproject` vs `startapp`
- Команди `manage.py`: runserver, migrate, createsuperuser, shell
- View-функції: `HttpResponse`, `render`
- URL-маршрути: `path()`, `include()`, `app_name`
- Django Admin: Users, Groups, реєстрація моделей
- Перша модель: `models.Model`, міграції, ORM shell

---

## Структура після завершення кроку

```
hello_django/
├── venv/                      ← virtual environment
├── db.sqlite3                 ← SQLite база даних
├── manage.py                  ← CLI оркестратор
├── requirements.txt
├── hello_project/             ← конфігурація проєкту
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
└── hello_app/                 ← наш перший додаток
    ├── models.py              ← Note модель
    ├── views.py               ← index, about, note_list
    ├── urls.py                ← /, /about/, /notes/
    ├── admin.py               ← NoteAdmin
    ├── migrations/
    └── templates/
        └── hello_app/
            └── note_list.html
```

---

## Навчальний стан vs Notes Chat App

| | hello_project (цей крок) | notes_chat_app (кінцева мета) |
|-|--------------------------|-------------------------------|
| База даних | SQLite | PostgreSQL |
| Запуск | `python manage.py runserver` | Docker Compose |
| Auth | Базовий admin | `@login_required`, Groups, IDOR protection |
| Views | `HttpResponse` + `render` | 15+ FBV з selectors/services |
| Шаблони | Один `note_list.html` | Повна Bootstrap 5 SaaS ієрархія |

---

## Порядок читання цього кроку

1. **[Середовище та запуск](environment.md)** — venv, Django, startproject, перший запуск
2. **[Структура проєкту](project_structure.md)** — анатомія Request/Response, manage.py, settings.py
3. **[URLs та Views](urls_and_views.md)** — view-функції, url patterns, reverse()
4. **[Шаблони](templates.md)** — перший HTML-шаблон, render(), MVT архітектура
5. **[Django Admin](admin.md)** — адмін-панель, перша модель, ORM shell
6. **[Контрольна точка](checkpoint.md)** — чеклист, часті помилки, практичні завдання
