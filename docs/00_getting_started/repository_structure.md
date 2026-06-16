# Структура репозиторію

> Розуміти де що лежить — базовий навик роботи з будь-яким Django проєктом.
> Тут — карта `notes_chat_app`: кожна директорія і найважливіші файли.

---

## Повне дерево

```
notes_chat_app/
│
├── notes_project/              ← Django project package
│   ├── settings.py             ← вся конфігурація (DB, INSTALLED_APPS, MIDDLEWARE...)
│   ├── urls.py                 ← головний URL router (підключає notes_app.urls)
│   ├── asgi.py                 ← ASGI entrypoint (HTTP + WebSocket)
│   ├── wsgi.py                 ← WSGI (НЕ використовується, тільки для сумісності)
│   ├── routing.py              ← WebSocket URL patterns
│   └── celery.py               ← Celery application instance
│
├── notes_app/                  ← Django app — вся бізнес-логіка
│   ├── models.py               ← 10 моделей (Note, Tag, Notebook, TodoList...)
│   ├── views.py                ← FBV view функції (note_list, note_create...)
│   ├── urls.py                 ← URL patterns для notes_app
│   ├── forms.py                ← ModelForm класи (NoteForm, TodoForm...)
│   ├── services.py             ← мутуючі операції (create_note, delete_tag...)
│   ├── selectors.py            ← read-only QuerySets (get_user_notes, ...)
│   ├── consumers.py            ← WebSocket Consumer (GroupChatConsumer)
│   ├── tasks.py                ← Celery tasks (reminder notifications...)
│   ├── admin.py                ← Django Admin реєстрація моделей
│   ├── apps.py                 ← AppConfig
│   ├── context_processors.py   ← глобальні контекстні змінні для шаблонів
│   ├── management/
│   │   └── commands/
│   │       └── seed_demo_data.py  ← команда для заповнення демо-даними
│   ├── migrations/             ← файли міграцій (автогенеровані)
│   ├── static/
│   │   └── notes_app/
│   │       ├── css/style.css
│   │       └── js/
│   │           ├── group_chat.js   ← WebSocket клієнт (JS)
│   │           └── reminders.js    ← SSE для нагадувань
│   └── tests/
│       ├── test_models.py      ← юніт тести моделей
│       ├── test_services.py    ← юніт тести сервісів
│       ├── test_forms.py       ← юніт тести форм
│       ├── test_views.py       ← інтеграційні тести views
│       ├── test_consumers.py   ← тести WebSocket Consumer
│       └── test_selenium.py    ← E2E Selenium тести
│
├── templates/                  ← project-level шаблони
│   ├── base.html               ← базовий layout (navbar, sidebar, messages)
│   └── notes_app/              ← app-level шаблони
│       ├── note_list.html
│       ├── note_detail.html
│       ├── note_form.html
│       └── ...
│
├── nginx/
│   └── nginx.conf              ← nginx конфігурація (static files, WebSocket proxy)
│
├── docs/                       ← вся документація (цей сайт!)
│   ├── 00_getting_started/     ← ти тут
│   ├── 01_web_foundations/ ... ← теоретичні розділи
│   ├── tutorials/              ← Zero to Hero кроки 1-9
│   └── 12_final_project/       ← документація фінального проєкту
│
├── Dockerfile                  ← образ Django контейнера
├── docker-compose.yml          ← весь стек (db, redis, web, nginx, ngrok, selenium)
├── entrypoint.sh               ← migrate → collectstatic → seed → uvicorn
├── requirements.txt            ← Python залежності
├── .env.example                ← шаблон змінних середовища
├── mkdocs.yml                  ← конфігурація документації (цей сайт)
└── manage.py                   ← Django CLI entrypoint
```

---

## Ключові файли і їх роль

### `notes_project/settings.py` — серце конфігурації

```python
# Тут живе все важливе:
DATABASES = {...}          # PostgreSQL підключення через DATABASE_URL
INSTALLED_APPS = [
    'daphne',              # ПЕРШИЙ — overrides runserver для ASGI
    'channels',
    'notes_app',
    ...
]
CHANNEL_LAYERS = {...}     # Redis для WebSocket broadcast
MIDDLEWARE = [...]         # ланцюг обробки запитів
TEMPLATES = [...]          # де шукати .html шаблони
STATIC_ROOT = ...          # куди collectstatic збирає файли
```

### `notes_project/asgi.py` — точка входу для ASGI

```python
# HTTP і WebSocket через один процес:
application = ProtocolTypeRouter({
    'http': django_asgi_app,           # → Django views
    'websocket': AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns) # → GroupChatConsumer
    ),
})
```

### `notes_app/models.py` — всі моделі проєкту

Тут живуть: `Note`, `Tag`, `Notebook`, `Reminder`, `TodoList`, `TodoItem`, `ShoppingList`, `ShopItem`, `UserProfile`, `ChatMessage`.

### `notes_app/views.py` + `selectors.py` + `services.py` — рівні архітектури

```
HTTP Request → views.py (координація) → selectors.py (читання з БД)
                                       → services.py (запис у БД)
                                       → render(template)
```

---

## Що НЕ редагувати

```
staticfiles/    ← результат collectstatic, автогенерований (ігнорується git)
.venv/          ← virtual environment (якщо є локальний), не для редагування
__pycache__/    ← Python bytecode, автогенерований
migrations/     ← не редагувати вручну, тільки через makemigrations
```

---

## Де шукати по темах

| Хочу знайти | Де дивитися |
|------------|------------|
| URL для конкретної сторінки | `notes_app/urls.py` |
| Логіку обробки запиту | `notes_app/views.py` |
| Запит до БД | `notes_app/selectors.py` |
| Операцію зміни даних | `notes_app/services.py` |
| Структуру моделі | `notes_app/models.py` |
| HTML сторінки | `templates/notes_app/` |
| WebSocket логіку | `notes_app/consumers.py` |
| JavaScript WebSocket клієнт | `notes_app/static/notes_app/js/group_chat.js` |
| Конфігурацію Docker | `docker-compose.yml` |
| Конфігурацію nginx | `nginx/nginx.conf` |

---

## Практичне завдання

Знайди в редакторі ці файли і відкрий кожен:

1. `notes_project/settings.py` → знайди `INSTALLED_APPS` і подивись порядок
2. `notes_app/models.py` → порахуй скільки моделей є
3. `notes_app/views.py` → знайди функцію `note_list`
4. `notes_app/selectors.py` → знайди `get_user_notes`
5. `docker-compose.yml` → порахуй скільки сервісів є

---

## Далі

→ [Крок 1. Hello Django](../tutorials/01_hello_django/index.md) — починаємо будувати
