# Deployment Cheatsheet

---

## First run

```bash
cp .env.example .env
# Edit: SECRET_KEY, POSTGRES_PASSWORD, NGROK_AUTHTOKEN, NGROK_DOMAIN

docker compose up --build
# Expect: "Uvicorn running on http://0.0.0.0:8001"

open http://localhost          # via nginx
open http://localhost:4040     # ngrok dashboard
```

---

## Production checklist

### Required

| Parameter | Requirement |
|----------|--------|
| `SECRET_KEY` | Unique, 50+ characters, not "django-insecure-..." |
| `DEBUG` | `False` |
| `ALLOWED_HOSTS` | Specific domains, not `['*']` |
| `CSRF_TRUSTED_ORIGINS` | Includes the ngrok domain |
| `DATABASE_URL` | PostgreSQL with a strong password |
| `REDIS_URL` | Redis (not InMemoryChannelLayer) |
| `.env` | In `.gitignore`, not in git |
| `entrypoint.sh` | No `--reload` for Uvicorn |

### Verification

```bash
docker compose exec web python manage.py check --deploy
# Shows all security warnings before deploying
```

---

## Environment variables

```bash
# .env — required:
SECRET_KEY=<50+ characters>
DEBUG=False
ALLOWED_HOSTS=localhost,your-domain.com
DATABASE_URL=postgres://user:pass@db:5432/dbname
REDIS_URL=redis://redis:6379/0
NGROK_AUTHTOKEN=<from the ngrok dashboard>
NGROK_DOMAIN=<your-subdomain.ngrok-free.app>

# Generate a SECRET_KEY:
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

---

## Docker Compose — common commands

```bash
docker compose up --build       # first run / after changing the Dockerfile
docker compose up -d            # background
docker compose down             # stop (volumes are kept)
docker compose down -v          # + remove volumes (reset the DB)
docker compose logs -f web      # follow the logs
docker compose exec web bash    # shell in the container
docker compose restart web      # restart web only
```

---

## Nginx — key parameters for WebSocket

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 300s;
```

Without these lines, the WebSocket will not open.

---

## Redis — socket_timeout=None

```python
# settings.py — CRITICAL for idle WS connections:
"CONFIG": {
    "hosts": [{
        "address": REDIS_URL,
        "socket_timeout": None,       # ← not 5 (default)
        "health_check_interval": 30,
    }]
}
```

---

## Common mistakes

| Symptom | Cause | Fix |
|---------|---------|-------------|
| `403 CSRF` via ngrok | `CSRF_TRUSTED_ORIGINS` is not configured | Add the domain in settings.py |
| `ERR_NGROK_8012` | ngrok and nginx are on different networks | Explicit `app-net` network |
| Static 404 | `collectstatic` was not run | Check entrypoint.sh |
| WS 400 via nginx | Missing Upgrade headers | `proxy_http_version 1.1` in nginx.conf |
| `TimeoutError: redis` | `socket_timeout=5` | `"socket_timeout": None` |
| web unhealthy | migrate or uvicorn crashes | `docker compose logs web` |

---

## HTTPS in production

```python
# settings.py — after configuring SSL:
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
