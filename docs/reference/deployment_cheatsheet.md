# Deployment Cheatsheet

---

## Перший запуск

```bash
cp .env.example .env
# Відредагуй: SECRET_KEY, POSTGRES_PASSWORD, NGROK_AUTHTOKEN, NGROK_DOMAIN

docker compose up --build
# Очікуй: "Uvicorn running on http://0.0.0.0:8001"

open http://localhost          # через nginx
open http://localhost:4040     # ngrok dashboard
```

---

## Production checklist

### Обов'язково

| Параметр | Вимога |
|----------|--------|
| `SECRET_KEY` | Унікальний, 50+ символів, не "django-insecure-..." |
| `DEBUG` | `False` |
| `ALLOWED_HOSTS` | Конкретні домени, не `['*']` |
| `CSRF_TRUSTED_ORIGINS` | Включає ngrok домен |
| `DATABASE_URL` | PostgreSQL з strong password |
| `REDIS_URL` | Redis (не InMemoryChannelLayer) |
| `.env` | У `.gitignore`, не в git |
| `entrypoint.sh` | Без `--reload` у Uvicorn |

### Перевірка

```bash
docker compose exec web python manage.py check --deploy
# Показує всі security warnings перед deploy
```

---

## Змінні середовища

```bash
# .env — обов'язкові:
SECRET_KEY=<50+ символів>
DEBUG=False
ALLOWED_HOSTS=localhost,your-domain.com
DATABASE_URL=postgres://user:pass@db:5432/dbname
REDIS_URL=redis://redis:6379/0
NGROK_AUTHTOKEN=<з ngrok dashboard>
NGROK_DOMAIN=<your-subdomain.ngrok-free.app>

# Генерувати SECRET_KEY:
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

---

## Docker Compose — типові команди

```bash
docker compose up --build       # перший запуск / після зміни Dockerfile
docker compose up -d            # background
docker compose down             # зупинити (volumes зберігаються)
docker compose down -v          # + видалити volumes (скинути БД)
docker compose logs -f web      # слідкувати за логами
docker compose exec web bash    # shell у контейнері
docker compose restart web      # перезапустити тільки web
```

---

## Nginx — ключові параметри для WebSocket

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 300s;
```

Без цих рядків WebSocket не відкриється.

---

## Redis — socket_timeout=None

```python
# settings.py — CRITICAL для idle WS з'єднань:
"CONFIG": {
    "hosts": [{
        "address": REDIS_URL,
        "socket_timeout": None,       # ← не 5 (default)
        "health_check_interval": 30,
    }]
}
```

---

## Типові помилки

| Симптом | Причина | Виправлення |
|---------|---------|-------------|
| `403 CSRF` через ngrok | `CSRF_TRUSTED_ORIGINS` не налаштовано | Додати домен у settings.py |
| `ERR_NGROK_8012` | ngrok і nginx на різних мережах | Явна `app-net` network |
| Static 404 | `collectstatic` не запущений | Перевірити entrypoint.sh |
| WS 400 через nginx | Відсутні Upgrade headers | `proxy_http_version 1.1` у nginx.conf |
| `TimeoutError: redis` | `socket_timeout=5` | `"socket_timeout": None` |
| web unhealthy | migrate або uvicorn падає | `docker compose logs web` |

---

## HTTPS у production

```python
# settings.py — після налаштування SSL:
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
```

```nginx
# nginx.conf — SSL termination:
server {
    listen 443 ssl;
    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
}
server {
    listen 80;
    return 301 https://$host$request_uri;
}
```
