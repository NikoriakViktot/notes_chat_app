# Deployment

---

## Current state

The project has a Docker stack configured for local development. Production-ready status requires further work.

### What is ready

| Component | Status |
|-----------|------|
| `Dockerfile` | present, base `python:3.12-slim` |
| `docker-compose.yml` | present, 9 services (selenium/selenium-tests in profile `test`, ngrok in profile `tunnel`) |
| `entrypoint.sh` | present (migrate → collectstatic → seed → uvicorn) |
| `.env.example` | present |
| `DATABASE_URL` switching | ✅ (raises Exception if not set) |
| `REDIS_URL` switching | ✅ (InMemory or Redis channel layer) |
| Nginx reverse proxy | ✅ (nginx:1.27-alpine, port 80) |
| ASGI server (Uvicorn) | ✅ |
| Static files | ✅ (`collectstatic` into the `staticfiles` volume, served by nginx) |

### What is needed for production

| Task | Detail |
|--------|--------|
| `SECRET_KEY` from the environment | currently may be hardcoded in dev |
| `DEBUG=False` | with a mandatory `ALLOWED_HOSTS` |
| HTTPS and secure cookies | `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` |
| Uvicorn without `--reload` | `--reload` is for dev only (`UVICORN_RELOAD=0`) |
| Remove `DebugExceptionMiddleware` | returns tracebacks to clients (security issue) |
| Backup / rollback plan | DB + media |
| Logging and monitoring | structured logs, health endpoint |

---

## Docker Compose services

```yaml
services:
  db:      postgres:16-alpine  # port 5432
  redis:   redis:7-alpine       # port 6379
  web:     Django ASGI (Uvicorn) # port 8001
  nginx:   nginx:1.27-alpine    # port 80 → web:8001
  celery-worker: celery -A notes_project worker  # background tasks
  celery-beat:   celery -A notes_project beat    # schedule (every minute)
  selenium: selenium/standalone-chrome  # E2E tests (profile test)
  selenium-tests: manage.py test notes_app.tests.test_selenium  # runs the Selenium tests (profile test)
  ngrok:   ngrok/ngrok          # public tunnel (dev) (profile tunnel)
```

Dependencies: `web` starts after the `db` and `redis` health checks.

---

## entrypoint.sh

```bash
#!/bin/sh
set -eu
# ... (the RUN_MIGRATIONS / RUN_COLLECTSTATIC / CREATE_SUPERUSER flags are shortened)
python manage.py migrate --noinput
python manage.py collectstatic --noinput
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    python manage.py seed_demo_data ${seed_args}   # --force or --force --reset
fi
set -- --host 0.0.0.0 --port "${PORT:-8001}" --proxy-headers --forwarded-allow-ips '*'
if [ "${UVICORN_RELOAD:-1}" = "1" ]; then
    set -- "$@" --reload   # dev; UVICORN_RELOAD=0 turns it off
fi
exec python -m uvicorn notes_project.asgi:application "$@"
```

---

## Nginx

Nginx (`nginx:1.27-alpine`) proxies:
- HTTP → `web:8001`
- WebSocket → `web:8001` (with `proxy_http_version 1.1` + `Upgrade/Connection` headers, `proxy_read_timeout 300s`)

`CSRF_TRUSTED_ORIGINS` must contain the domain the requests come from (the ngrok URL or the production domain).

---

## CI (GitHub Actions)

File: `.github/workflows/django-tests.yml`

Watches: `notes_app/**`, `notes_project/**`.

Job 1 (unit + integration, ubuntu-latest) → Job 2 (Selenium, only if Job 1 ✅).
