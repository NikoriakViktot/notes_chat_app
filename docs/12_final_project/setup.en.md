# Running Notes Chat App

## Docker: the only supported way

Notes Chat App requires PostgreSQL and Redis. `settings.py` raises an `Exception` if `DATABASE_URL` is not set; there is no SQLite fallback.

```bash
# First run (builds images, applies migrations, seeds demo data)
docker compose up --build

# Subsequent runs
docker compose up
```

The stack is available at **`http://localhost`** (Nginx → port 80 → Django on 8001).

### Docker Compose services

| Service | Image | Role |
|--------|-------|------|
| `db` | `postgres:16-alpine` | PostgreSQL — the main database |
| `redis` | `redis:7-alpine` | Redis — channel layer for WebSocket (DB 0) and Celery broker (DB 1) |
| `web` | Django ASGI (Uvicorn) | The application on port 8001 |
| `nginx` | `nginx:1.27-alpine` | Reverse proxy, port 80 |
| `celery-worker` | the same image as `web` | Runs Celery tasks |
| `celery-beat` | the same image as `web` | Celery scheduler (`CELERY_BEAT_SCHEDULE`) |
| `ngrok` | `ngrok/ngrok:latest` | Public tunnel (dev, profile `tunnel`) |
| `selenium` | `selenium/standalone-chrome` | E2E tests (profile `test`) |
| `selenium-tests` | the same image as `web` | Runs `test_selenium` against Selenium (profile `test`) |

### Automatic initialization (`entrypoint.sh`)

When the `web` container starts, it runs:

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py seed_demo_data --force   ← if SEED_DEMO_DATA=1 (+ --reset if SEED_DEMO_RESET=1)
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --proxy-headers --forwarded-allow-ips '*' --reload   ← --reload if UVICORN_RELOAD=1
```

### Demo data

```bash
# Seed demo data manually
docker compose run --rm web python manage.py seed_demo_data

# Reset and seed again
docker compose run --rm web python manage.py seed_demo_data --reset
```

---

## Environment variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Required variables:

| Variable | Example | Required |
|--------|---------|-------------|
| `DATABASE_URL` | `postgres://notes:notes@db:5432/notes_db` | ✅ always |
| `REDIS_URL` | `redis://redis:6379/0` | ✅ for WebSocket |
| `SECRET_KEY` | any string | ✅ |
| `DJANGO_DEBUG` | `1` | recommended for dev |
| `SEED_DEMO_DATA` | `1` | for automatic seeding |

---

## Running tests

### Unit, integration, and consumer tests

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2
```

### Selenium E2E tests

Selenium tests require a running container (`exec`, not `run`):

```bash
docker compose up -d
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium \
  -v 2
```

---

## Known limitation

The async HTTP demo files (`async_views.py`, `async_selectors.py`, `async_services.py`) are absent from the current working tree. The WebSocket chat is the active ASGI/async example.
