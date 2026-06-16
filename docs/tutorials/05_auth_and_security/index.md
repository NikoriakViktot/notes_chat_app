# Крок 5. Auth і Безпека

> Цей крок охоплює два проєкти: **crispy_notes_project** (Кроки 1–6) та **notes_chat_app** (Кроки 7–11).
> Перший — standalone застосунок на SQLite без Docker.
> Другий — production-like стек з Docker, PostgreSQL, Redis, Group sharing і WebSocket чатом.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 1. Hello Django](../01_hello_django/index.md) — перший `HttpResponse`, URL routing
    - [Крок 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Крок 3. CRUD і архітектура](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL
    - [Крок 4. Templates і Forms](../04_templates_and_forms/index.md) — Crispy Forms, Dashboard, Context Processor

---

## Навчальний проєкт vs Notes Chat App

| | crispy_notes_project (Кроки 1–6) | notes_chat_app (Кроки 7–11) |
|-|----------------------------------|------------------------------|
| Запуск | `python manage.py runserver` | `docker compose up --build` |
| База даних | SQLite | PostgreSQL (Docker) |
| Auth | Login / Logout / Register / Password Reset | Те саме + UserCreationForm auto-login |
| Session storage | Файлова (SQLite) | БД (PostgreSQL) через Redis |
| Group FK | `Note.group`, `ShoppingList.group` | Те саме + `ChatMessage.group` |
| Docker | Немає | PostgreSQL + Redis + Web + Nginx + Selenium |
| ngrok | Немає | Так — публічний URL + `CSRF_TRUSTED_ORIGINS` |
| WebSocket | Немає | `GroupChatConsumer` через Redis |

---

## Що ти вивчиш

- **AuthN vs AuthZ** — різниця між "хто ти?" і "що тобі можна?", аналогія паспорт/квиток
- **Sessions** — як HTTP stateless стає stateful: cookie, `django_session`, middleware chain
- **Password Security** — PBKDF2 з 600 000 ітерацій, Password Reset flow, 4 вбудованих валідатори
- **IDOR** — Insecure Direct Object Reference: найпоширеніша вразливість (OWASP A01), як захиститись
- **Group Sharing** — Django вбудована модель Group, FK `SET_NULL`, Q-filter `Q(user=u) | Q(group__in=gs)`
- **Security Settings** — `SESSION_COOKIE_HTTPONLY`, `X_FRAME_OPTIONS`, `CSRF_TRUSTED_ORIGINS`, `DEBUG=False`

---

## Порядок читання

1. **[Auth Basics](auth_basics.md)** — паспорт/квиток, AuthN vs AuthZ, `authenticate()`, `login()`, middleware chain, Sessions, cookie
2. **[Password Security](password_security.md)** — `django.contrib.auth.urls`, Password Reset (5 кроків), PBKDF2, validators, Password Change
3. **[Object Permissions](object_permissions.md)** — IDOR, `get_object_or_404`, Q-filter для спільних об'єктів, таблиця захищених views
4. **[Group Sharing](group_sharing.md)** — Django Group, `SET_NULL`, Q-filter, Services, Views, Templates
5. **[Security Settings](security_settings.md)** — таблиця налаштувань, `DEBUG=True` витоки, HTTPS production settings
6. **[Notes Chat App Auth](notes_chat_app_auth.md)** — специфіка notes_chat_app: Docker, `DATABASE_URL`, реєстрація, URL конфігурація
7. **[Checkpoint](checkpoint.md)** — чеклист, IDOR test, типові помилки, практичне завдання
