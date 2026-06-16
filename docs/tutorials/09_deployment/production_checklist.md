# Production Checklist

> Що перевірити перед тим як відкрити доступ реальним користувачам.

---

## Чому потрібен checklist

Dev і production — різні середовища. Django має безпечні defaults для dev (DEBUG=True, SQLite, InMemory channels), але вони абсолютно небезпечні для production. Checklist допомагає не пропустити жодну критичну зміну.

```
Dev:   DEBUG=True   → видно stack trace з SECRET_KEY → хакер підробляє cookies
Prod:  DEBUG=False  → пустий 500 error, SECRET_KEY прихований

Dev:   SQLite       → файл знищується при docker compose down
Prod:  PostgreSQL   → named volume, дані зберігаються між restartами

Dev:   InMemory     → WebSocket тільки в одному process
Prod:  Redis        → broadcast між кількома workers

Dev:   runserver    → WSGI, однопоточний, без статики
Prod:  Uvicorn + nginx → ASGI, кілька workers, static без Python
```

---

## Безпека (обов'язково)

- [ ] `SECRET_KEY` — унікальний, 50+ символів, згенерований `get_random_secret_key()`
- [ ] `DEBUG = False` — **НІКОЛИ True в production**
- [ ] `ALLOWED_HOSTS` — конкретні домени, не `['*']`
- [ ] `CSRF_TRUSTED_ORIGINS` — містить prod домен і ngrok домен
- [ ] `SESSION_COOKIE_SECURE = True` — cookie тільки HTTPS
- [ ] `CSRF_COOKIE_SECURE = True`
- [ ] `SECURE_SSL_REDIRECT = True` — HTTP → HTTPS redirect
- [ ] `SECURE_HSTS_SECONDS = 31536000` — HSTS на 1 рік
- [ ] `.env` у `.gitignore` — перевір `git status` перед push
- [ ] Паролі у `.env`, не у коді чи Dockerfile

### Налаштування HTTPS у settings.py

```python
# settings.py — розкоментуй коли є SSL сертифікат:
SESSION_COOKIE_SECURE = True    # cookie тільки через HTTPS
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True      # HTTP → HTTPS redirect
SECURE_HSTS_SECONDS = 31536000  # браузер запам'ятовує HTTPS на 1 рік
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
```

---

## Продуктивність

- [ ] `--reload` прибрати з `entrypoint.sh` (uvicorn)
- [ ] `--workers 4` додати до uvicorn (4 = 2 × CPU cores)
- [ ] `CONN_MAX_AGE = 0` для ASGI (async-compatible)
- [ ] nginx `expires 7d` для статики (кешування)
- [ ] PostgreSQL `max_connections` відповідає кількості uvicorn workers
- [ ] Redis `maxmemory-policy allkeys-lru` (не дозволяти Redis заповнити RAM)

### Production entrypoint.sh

```sh
# entrypoint.sh у production — прибираємо --reload, додаємо --workers:
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --workers 4
```

---

## Django deployment check

```bash
docker compose exec web python manage.py check --deploy
```

Показує попередження про security налаштування. У production — мають бути зеленими.

```
# З DEBUG=True (очікувано у dev):
WARNINGS:
?: (security.W004) You have not set a value for the SECURE_HSTS_SECONDS setting.
?: (security.W008) Your SECRET_KEY has less than 50 characters.
?: (security.W012) SESSION_COOKIE_SECURE is not set to True.
?: (security.W016) You have 'django.middleware.csrf.CsrfViewMiddleware' in your
   MIDDLEWARE, but you have not set CSRF_COOKIE_SECURE to True.

# З DEBUG=False і правильними налаштуваннями:
System check identified no issues (0 silenced).
```

---

## Генерація SECRET_KEY

```bash
# Варіант 1: Python (через Docker)
docker compose run --rm web python -c \
    "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Варіант 2: Python (локально)
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Варіант 3: OpenSSL
openssl rand -base64 50

# Варіант 4: Python secrets
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

!!! danger "НІКОЛИ не використовувати"
    ```
    SECRET_KEY=django-insecure-...   ← згенерований Django за замовчуванням
    SECRET_KEY=dev-secret-key-...    ← явно тестовий ключ
    ```
    Обидва ці значення є публічними і не захищають cookies та HMAC підписи.

---

## Pre-deploy перевірки

### 1. Перевірка тестів

```bash
docker compose run --rm web python manage.py test notes_app.tests --failfast
# Всі тести мають бути зеленими перед деплоєм
```

### 2. Перевірка міграцій

```bash
docker compose exec web python manage.py showmigrations
# Всі міграції мають мати [X]
# Якщо є [ ] → migrate не запустився або є нова міграція що не застосована

docker compose exec web python manage.py migrate --check
# Повертає exit code 1 якщо є непримінені міграції
```

### 3. Перевірка статики

```bash
docker compose exec nginx curl -I http://localhost/static/admin/css/base.css
# HTTP/1.1 200 OK → nginx роздає статику правильно
# HTTP/1.1 404    → collectstatic не запустився або volume не змонтований

docker compose exec web python manage.py collectstatic --dry-run --noinput
# Показує що буде зібрано без реального копіювання
```

### 4. Перевірка переліку environment variables

```bash
docker compose exec web env | sort | grep -vE 'PATH|HOME|USER|SHELL'
# Переконайся що є: SECRET_KEY, DATABASE_URL, REDIS_URL, ALLOWED_HOSTS
# Переконайся що DEBUG=False
# Переконайся що SECRET_KEY != 'dev-secret-key-...'
```

---

## Моніторинг і логування

- [ ] `LOGGING` у `settings.py` → файли або stdout для Docker
- [ ] nginx access log → analysis (Grafana Loki або ELK)
- [ ] Health check endpoints відповідають
- [ ] Uptime monitor (UptimeRobot, Better Stack)

```python
# settings.py — базова конфігурація логування:
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',   # stdout → docker logs → centralized logging
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django.request': {
            'handlers': ['console'],
            'level': 'WARNING',       # тільки 4xx і 5xx, не кожен GET
            'propagate': False,
        },
    },
}
```

```bash
# Переглянути логи по сервісах:
docker compose logs --since 1h web      # логи за останню годину
docker compose logs --since 1h nginx    # nginx access log
docker compose logs --since 1h --follow web  # live streaming
```

---

## Backup PostgreSQL

Перед будь-яким деплоєм що змінює схему — зроби backup:

```bash
# Backup БД у файл:
docker compose exec db pg_dump \
    -U notes_user \
    -d notes_db \
    -F c \
    -f /tmp/backup_$(date +%Y%m%d_%H%M%S).dump

# Скопіювати backup з контейнера на хост:
docker cp $(docker compose ps -q db):/tmp/backup_*.dump ./backups/

# Restore з backup:
docker compose exec db pg_restore \
    -U notes_user \
    -d notes_db \
    -F c \
    /tmp/backup.dump
```

---

## Rollback

Якщо деплой зламав застосунок — план відкату:

### 1. Відкат коду (попередній Docker image)

```bash
# Зупинити поточну версію:
docker compose down

# Зібрати попередній образ (якщо є tag):
git checkout v1.2.3
docker compose up --build

# Або використати закешований image:
docker compose up    # не --build, використає попередній збір
```

### 2. Відкат міграцій

```bash
# Переглянути список міграцій:
docker compose exec web python manage.py showmigrations notes_app

# Відкотити до конкретної міграції:
docker compose exec web python manage.py migrate notes_app 0005
# ↑ відкотить 0006, 0007, ... назад до стану після 0005
# УВАГА: видаляє дані з нових стовпців!
```

!!! danger "Міграції з даними"
    Відкат міграції що видаляла стовпець → **неможливо** (дані вже видалені).
    Відкат міграції що додавала стовпець → безпечно (просто видаляється порожній стовпець).
    Завжди роби backup перед деплоєм з міграціями.

---

## Типові помилки при першому деплої

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `403 CSRF verification failed` | Домен не в `CSRF_TRUSTED_ORIGINS` | Додати домен в `settings.py` + env |
| `DisallowedHost` | Домен не в `ALLOWED_HOSTS` | Додати домен + перезапустити |
| `WebSocket 403` | Auth не передається через nginx | Перевірити `proxy_set_header` у `nginx.conf` |
| `Static files 404` | `collectstatic` не запустився | Перевірити `entrypoint.sh` + volume mount |
| `ERR_NGROK_8012` | ngrok не знаходить nginx | Перевірити що обидва в `app-net` |
| `TimeoutError reading from redis` | `socket_timeout` у `RedisChannelLayer` | `socket_timeout=None` у `CONFIG` |
| `CommandError: Demo data disabled` | `seed_demo_data` вимкнений без `DEBUG=True` | Додати `--force` до команди |
| `SynchronousOnlyOperation` у consumer | sync ORM у async context | `@database_sync_to_async` |
| Дані зникли після `docker compose down` | Використано `down -v` | Backup перед `down -v` |
| `web` unhealthy → nginx не стартує | Migrate падає або uvicorn не стартує | `docker compose logs web` |
| WS з'єднання не відкривається через nginx | Відсутні WebSocket headers | Додати `proxy_http_version 1.1` у `nginx.conf` |
| `SECRET_KEY changed` → всі сесії недійсні | Зміна SECRET_KEY → Django інвалідує сесії | Не міняй SECRET_KEY без потреби |

---

## У книзі

- [Частина XI. Deployment](../../11_deployment/README.md) — production deploy pipeline, environment management, scaling
- [Частина VII. Auth і Security](../../07_auth_and_security/README.md) — OWASP Top 10, XSS, CSRF, SQL Injection, Django security settings

---

## Офіційна документація

- [Django: Deployment checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/) — `manage.py check --deploy`, всі security settings
- [Django: Security in Django](https://docs.djangoproject.com/en/5.2/topics/security/) — огляд всіх механізмів
- [Django: Logging](https://docs.djangoproject.com/en/5.2/topics/logging/) — `LOGGING` configuration
- [Uvicorn: Settings](https://www.uvicorn.org/settings/) — `--workers`, `--host`, `--port` flags
- [nginx: Reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) — proxy_pass, upstream
- [PostgreSQL: pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) — backup and restore
