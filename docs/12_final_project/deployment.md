# Deployment

---

## Поточний стан

Проєкт має Docker-стек, налаштований для локальної розробки. Production-ready статус потребує доопрацювань.

### Що готово

| Компонент | Стан |
|-----------|------|
| `Dockerfile` | є, base `python:3.12-slim` |
| `docker-compose.yml` | є, 6 сервісів |
| `entrypoint.sh` | є (migrate → collectstatic → seed → uvicorn) |
| `.env.example` | є |
| `DATABASE_URL` switching | ✅ (raise Exception якщо не встановлено) |
| `REDIS_URL` switching | ✅ (InMemory або Redis channel layer) |
| Nginx reverse proxy | ✅ (nginx:1.27-alpine, порт 80) |
| ASGI server (Uvicorn) | ✅ |
| Static files | ✅ (`collectstatic`, nginx або whitenoise) |

### Що потрібно для production

| Задача | Деталь |
|--------|--------|
| `SECRET_KEY` з environment | наразі може бути hardcoded в dev |
| `DEBUG=False` | з обов'язковим `ALLOWED_HOSTS` |
| HTTPS і secure cookies | `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` |
| Uvicorn без `--reload` | `--reload` тільки для dev |
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
  ngrok:   ngrok/ngrok          # публічний тунель (dev)
  selenium: selenium/standalone-chrome  # E2E тести
```

Залежності: `web` запускається після health check `db` і `redis`.

---

## entrypoint.sh

```bash
#!/bin/sh
python manage.py migrate
python manage.py collectstatic --no-input
if [ "$SEED_DEMO_DATA" = "1" ]; then
    python manage.py seed_demo_data
fi
exec uvicorn notes_project.asgi:application \
    --host 0.0.0.0 --port 8001 --reload
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
