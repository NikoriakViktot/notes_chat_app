# Troubleshooting

## `ModuleNotFoundError: No module named 'django'`

Причина: dependencies не встановлені або virtual environment не активований.

```bash
python -m pip show Django
source .venv/bin/activate
pip install -r requirements.txt
```

## `ImportError: cannot import name async_views`

Ця помилка виникне, якщо повернути legacy async routes/import без відповідних files. У поточній активній документації async HTTP demo не подається як робоча feature.

Варіанти:

- відновити `notes_app/async_views.py`, `async_selectors.py`, `async_services.py`;
- або прибрати async import/routes з `notes_app/urls.py`.

## `no such table`

Причина: migrations не застосовані.

```bash
python manage.py migrate
```

## `NoReverseMatch`

Причина: неправильний URL name або namespace.

Перевірте `app_name = "notes_app"` і names у `notes_app/urls.py`.

## `TemplateDoesNotExist`

Перевірте:

- `templates/` на project level;
- `notes_app/templates/notes_app/` на app level;
- `TEMPLATES["DIRS"]` у `notes_project/settings.py`;
- `APP_DIRS=True`.

## WebSocket не підключається

Перевірте:

- server запущений через ASGI: `uvicorn notes_project.asgi:application --reload --port 8001`;
- user logged in;
- user є member group;
- URL має формат `/ws/groups/<pk>/chat/`;
- browser DevTools -> Network -> WS;
- якщо задано `REDIS_URL`, Redis доступний.

## Docker build падає на директорії `notes`

Поточний Docker setup згадує `notes`, але такої директорії в корені немає. Треба виправити build context і `COPY` paths перед використанням Docker як робочого сценарію.

<!-- django-validation-troubleshooting:start -->

## Django checks: `.venv`, `DATABASE_URL`, PostgreSQL

Поточна конфігурація проєкту очікує `DATABASE_URL`. Якщо запускати системний Python напряму, Django може не імпортуватися:

```bash
python3 manage.py check
```

Типова помилка:

```text
ModuleNotFoundError: No module named 'django'
```

Використовуй Python із `.venv`:

```bash
.venv/bin/python manage.py check
```

Якщо `DATABASE_URL` не встановлено, `notes_project/settings.py` зупиняє запуск:

```text
Exception: DATABASE_URL не встановлено. Запускай через docker compose.
```

Мінімальна перевірка конфігурації проходить із Postgres-style URL:

```bash
DATABASE_URL=postgres://notes_user:notes_pass@localhost:5432/notes_db .venv/bin/python manage.py check
```

Для тестів потрібен доступний PostgreSQL на `localhost:5432` або відповідний `DATABASE_URL` на запущений сервіс:

```bash
DATABASE_URL=postgres://notes_user:notes_pass@localhost:5432/notes_db .venv/bin/python manage.py test
```

Якщо PostgreSQL не запущено, Django знайде тести, але не створить test database:

```text
django.db.utils.OperationalError: connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
```

Рішення: запусти database service через Docker Compose або локальний PostgreSQL з такими самими credentials, після цього повтори `manage.py test`.

<!-- django-validation-troubleshooting:end -->

