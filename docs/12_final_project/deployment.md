# Deployment

---

## Поточний стан

Проєкт має Docker-стек, налаштований для локальної розробки. Production-ready статус потребує доопрацювань.

### Що готово

| Компонент | Стан |
|-----------|------|
| `Dockerfile` | є, base `python:3.12-slim` |
| `docker-compose.yml` | є, 9 сервісів (selenium/selenium-tests — profile `test`, ngrok — profile `tunnel`) |
| `entrypoint.sh` | є (migrate → collectstatic → seed → uvicorn) |
| `.env.example` | є |
| `DATABASE_URL` switching | ✅ (raise Exception якщо не встановлено) |
| `REDIS_URL` switching | ✅ (InMemory або Redis channel layer) |
| Nginx reverse proxy | ✅ (nginx:1.27-alpine, порт 80) |
| ASGI server (Uvicorn) | ✅ |
| Static files | ✅ (`collectstatic` у volume `staticfiles`, роздає nginx) |

### Що потрібно для production

| Задача | Деталь |
|--------|--------|
| `SECRET_KEY` з environment | наразі може бути hardcoded в dev |
| `DEBUG=False` | з обов'язковим `ALLOWED_HOSTS` |
| HTTPS і secure cookies | `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` |
| Uvicorn без `--reload` | `--reload` тільки для dev (`UVICORN_RELOAD=0`) |
| `DebugExceptionMiddleware` видалити | повертає traceback клієнтам (security issue) |
| Backup / rollback plan | БД + media |
| Logging і monitoring | structured logs, health endpoint |

---

## Docker Compose сервіси

```yaml
services:
  db:      postgres:16-alpine  # порт 5432
  redis:   redis:7-alpine       # порт 6379
  web:     Django ASGI (Uvicorn) # порт 8001
  nginx:   nginx:1.27-alpine    # порт 80 → web:8001
  celery-worker: celery -A notes_project worker  # фонові задачі
  celery-beat:   celery -A notes_project beat    # розклад (кожну хвилину)
  selenium: selenium/standalone-chrome  # E2E тести (profile test)
  selenium-tests: manage.py test notes_app.tests.test_selenium  # запуск Selenium-тестів (profile test)
  ngrok:   ngrok/ngrok          # публічний тунель (dev) (profile tunnel)
```

Залежності: `web` запускається після health check `db` і `redis`.

---

## entrypoint.sh

```bash
#!/bin/sh
set -eu
# ... (прапорці RUN_MIGRATIONS / RUN_COLLECTSTATIC / CREATE_SUPERUSER скорочено)
python manage.py migrate --noinput
python manage.py collectstatic --noinput
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    python manage.py seed_demo_data ${seed_args}   # --force або --force --reset
fi
set -- --host 0.0.0.0 --port "${PORT:-8001}" --proxy-headers --forwarded-allow-ips '*'
if [ "${UVICORN_RELOAD:-1}" = "1" ]; then
    set -- "$@" --reload   # dev; UVICORN_RELOAD=0 вимикає
fi
exec python -m uvicorn notes_project.asgi:application "$@"
```

---

## Nginx

Nginx (`nginx:1.27-alpine`) проксіює:
- HTTP → `web:8001`
- WebSocket → `web:8001` (з `proxy_http_version 1.1` + `Upgrade/Connection` headers, `proxy_read_timeout 300s`)

`CSRF_TRUSTED_ORIGINS` повинен містити домен, з якого приходять запити (ngrok URL або production domain).

---

## CI (GitHub Actions)

Файл: `.github/workflows/django-tests.yml`

Watches: `notes_app/**`, `notes_project/**`.

Job 1 (unit + integration, ubuntu-latest) → Job 2 (Selenium, тільки якщо Job 1 ✅).
