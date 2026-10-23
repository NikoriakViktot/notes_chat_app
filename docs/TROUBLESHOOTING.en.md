# Troubleshooting

## `ModuleNotFoundError: No module named 'django'`

Cause: the dependencies are not installed or the virtual environment is not activated.

```bash
python -m pip show Django
source .venv/bin/activate
pip install -r requirements.txt
```

## `ImportError: cannot import name async_views`

This error occurs if you bring back the legacy async routes/import without the corresponding files. The current active documentation does not present the async HTTP demo as a working feature.

Options:

- restore `notes_app/async_views.py`, `async_selectors.py`, `async_services.py`;
- or remove the async import/routes from `notes_app/urls.py`.

## `no such table`

Cause: migrations have not been applied.

```bash
python manage.py migrate
```

## `NoReverseMatch`

Cause: a wrong URL name or namespace.

Check `app_name = "notes_app"` and the names in `notes_app/urls.py`.

## `TemplateDoesNotExist`

Check:

- `templates/` at the project level;
- `notes_app/templates/notes_app/` at the app level;
- `TEMPLATES["DIRS"]` in `notes_project/settings.py`;
- `APP_DIRS=True`.

## WebSocket does not connect

Check:

- the server is running through ASGI: `uvicorn notes_project.asgi:application --reload --port 8001`;
- the user is logged in;
- the user is a member of the group;
- the URL has the format `/ws/groups/<pk>/chat/`;
- browser DevTools -> Network -> WS;
- if `REDIS_URL` is set, Redis is reachable.

## Docker build fails on the `notes` directory

The current Docker setup mentions `notes`, but there is no such directory in the root. You need to fix the build context and the `COPY` paths before using Docker as a working scenario.

<!-- django-validation-troubleshooting:start -->

## Django checks: `.venv`, `DATABASE_URL`, PostgreSQL

The current project configuration expects `DATABASE_URL`. If you run the system Python directly, Django may fail to import:

```bash
python3 manage.py check
```

Typical error:

```text
ModuleNotFoundError: No module named 'django'
```

Use the Python from `.venv`:

```bash
.venv/bin/python manage.py check
```

If `DATABASE_URL` is not set, `notes_project/settings.py` stops the startup:

```text
Exception: DATABASE_URL не встановлено. Запускай через docker compose.
```

A minimal configuration check passes with a Postgres-style URL:

```bash
DATABASE_URL=postgres://notes_user:notes_pass@localhost:5432/notes_db .venv/bin/python manage.py check
```

Tests need a reachable PostgreSQL on `localhost:5432` or a matching `DATABASE_URL` pointing to a running service:

```bash
DATABASE_URL=postgres://notes_user:notes_pass@localhost:5432/notes_db .venv/bin/python manage.py test
```

If PostgreSQL is not running, Django will find the tests but will not create the test database:

```text
django.db.utils.OperationalError: connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
```

Solution: start the database service with Docker Compose or a local PostgreSQL with the same credentials, then rerun `manage.py test`.

<!-- django-validation-troubleshooting:end -->
