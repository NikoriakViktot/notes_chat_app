# Туторіал 08 — Deployment: Docker, nginx, ngrok

**Мета:** зрозуміти як CrispyNotes запускається у Docker Compose, як nginx виступає reverse proxy, як ngrok відкриває публічний доступ, і що потрібно перевірити перед production deployment.

---

## Загальна картина стеку

```
Браузер (або інтернет через ngrok)
    │
    ▼
nginx :80  ← reverse proxy
    ├── /static/*   → staticfiles volume (без Django)
    └── /*          → web:8001 (Uvicorn/ASGI)
              │
              ├── HTTP → Django views
              └── WS  → Django Channels consumers
                    │
                    ├── PostgreSQL :5432
                    └── Redis :6379 (channel layer)

ngrok ← тунель від nginx до публічного URL
Selenium ← headless Chrome для E2E тестів
```

| Сервіс | Image | Порт | Роль |
|--------|-------|------|------|
| `db` | postgres:16-alpine | 5432 | База даних |
| `redis` | redis:7-alpine | 6379 | Channel layer (WebSocket) |
| `web` | Dockerfile | 8001 | Django + Uvicorn ASGI |
| `nginx` | nginx:1.27-alpine | 80 | Reverse proxy, статика |
| `ngrok` | ngrok/ngrok | 4040 | Публічний тунель |
| `selenium` | selenium/standalone-chrome | 4444 | E2E тести |

---

## Dockerfile — образ Django

```dockerfile
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=notes_project.settings \
    PYTHONPATH=/app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
```

| ENV | Навіщо |
|-----|--------|
| `PYTHONDONTWRITEBYTECODE=1` | Не створює `.pyc` файли в контейнері |
| `PYTHONUNBUFFERED=1` | Логи виводяться одразу (не буферизуються) |
| `DJANGO_SETTINGS_MODULE` | Django знає який settings.py використовувати |
| `PYTHONPATH=/app` | Python шукає модулі у `/app` (не у підпапках) |

---

## entrypoint.sh — що запускається при старті

```sh
#!/bin/sh
set -e   # ← зупинитись при будь-якій помилці

python manage.py migrate --noinput          # застосувати нові міграції
python manage.py collectstatic --noinput    # зібрати static у /app/staticfiles

if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force   # заповнити БД демо-даними
fi

exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 --port 8001 --reload
```

**Ланцюг залежностей:** кожен крок виконується тільки якщо попередній успішний (`set -e`). Якщо міграція падає — Uvicorn не стартує.

**`--reload`** — авто-перезапуск при зміні файлів. В production потрібно прибрати.

---

## docker-compose.yml — ланцюг залежностей зі health checks

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U notes_user -d notes_db"]
      interval: 5s
      retries: 5
    networks: [app-net]

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
    networks: [app-net]

  web:
    build: .
    ports: ["8001:8001"]    # dev access + Selenium
    environment:
      DATABASE_URL: postgres://notes_user:notes_pass@db:5432/notes_db
      REDIS_URL: redis://redis:6379/0
      NGROK_DOMAIN: ${NGROK_DOMAIN}   # ← для CSRF_TRUSTED_ORIGINS
      SEED_DEMO_DATA: "1"
    depends_on:
      db:    {condition: service_healthy}
      redis: {condition: service_healthy}
    healthcheck:
      test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8001/accounts/login/')\""]
      interval: 5s
      retries: 12
      start_period: 15s
    networks: [app-net]

  nginx:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - staticfiles:/staticfiles:ro
    depends_on:
      web: {condition: service_healthy}
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost/accounts/login/ || exit 1"]
    networks: [app-net]

  ngrok:
    image: ngrok/ngrok:latest
    command: http --url=${NGROK_DOMAIN} nginx:80
    environment:
      NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
    ports: ["4040:4040"]
    depends_on:
      nginx: {condition: service_healthy}   # ← чекає на nginx health check
    networks: [app-net]

networks:
  app-net:
    driver: bridge   # ← явна мережа: DNS-резолюція "nginx" → IP гарантована

volumes:
  postgres_data:
  staticfiles:
```

**Чому явна мережа `app-net`?** Без неї Docker Compose автоматично додає всі сервіси на дефолтну мережу, але ngrok-образ може це порушити → `ERR_NGROK_8012: no such host nginx`. Явна named network гарантує DNS-резолюцію між контейнерами.

---

## nginx.conf — reverse proxy з WebSocket підтримкою

```nginx
# nginx/nginx.conf
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;

    # Мапа для WebSocket upgrade (HTTP → WS upgrade headers)
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    upstream django {
        server web:8001;   # ← "web" — DNS ім'я сервісу у Docker
    }

    server {
        listen 80;

        # Статичні файли — nginx роздає напряму, Django не задіяний
        location /static/ {
            alias /staticfiles/;   # ← volume з collectstatic
            expires 7d;
            add_header Cache-Control "public, immutable";
        }

        # Все інше (HTTP + WebSocket) → uvicorn
        location / {
            proxy_pass http://django;

            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # WebSocket upgrade — обов'язково для Django Channels!
            proxy_http_version 1.1;
            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            proxy_read_timeout 300s;    # для довготривалих WS-з'єднань
            proxy_connect_timeout 75s;
        }
    }
}
```

**Чому WebSocket потребує `proxy_http_version 1.1`?**

WebSocket Upgrade handshake вимагає HTTP/1.1. Без цього nginx буде перемикатись на HTTP/1.0 і Upgrade заголовки будуть ігноровані → WS-з'єднання не відкриється.

**Статика через nginx (не Django):**

```
Без nginx:  браузер → Django/Uvicorn → читає файл → повертає
З nginx:    браузер → nginx → читає файл напряму → повертає
```

Nginx роздає статику у 5-10x швидше і не навантажує Python процес.

---

## .env — конфігурація

```bash
# .env (не комітити в git — є у .gitignore!)
# Скопіюй з .env.example: cp .env.example .env

# PostgreSQL
POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=change_me_strong_password

# Django
SECRET_KEY=generate-a-real-secret-key-here
DATABASE_URL=postgres://notes_user:change_me@db:5432/notes_db

# Redis (channel layer для WebSocket)
REDIS_URL=redis://redis:6379/0

# Selenium (E2E тести)
SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub
WEB_HOST=web

# ngrok (публічний тунель)
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
NGROK_DOMAIN=your-subdomain.ngrok-free.app
```

**Як згенерувати SECRET_KEY:**

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

---

## CSRF_TRUSTED_ORIGINS — чому виникає 403 через ngrok

**Симптом:** зайшов на сайт через ngrok, натискаєш "Увійти" → `403 Forbidden: CSRF verification failed`.

**Причина:** ngrok пересилає запити через HTTPS. Django перевіряє `Origin` header:

```
Запит до https://fawn-natural-mayfly.ngrok-free.app/accounts/login/
Origin: https://fawn-natural-mayfly.ngrok-free.app

Django: чи є "https://fawn-natural-mayfly.ngrok-free.app" у CSRF_TRUSTED_ORIGINS?
Якщо ні → 403
```

**Рішення у `settings.py`:**

```python
# settings.py
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []
```

**Рішення у `docker-compose.yml`:**

```yaml
  web:
    environment:
      NGROK_DOMAIN: ${NGROK_DOMAIN}   # ← передаємо з .env у web контейнер
```

Після `docker compose down && docker compose up --build` — проблема зникне.

---

## staticfiles volume — як статика потрапляє до nginx

```
entrypoint.sh:
  python manage.py collectstatic --noinput
  → копіює CSS/JS/images у /app/staticfiles/

docker-compose.yml:
  web:
    volumes:
      - staticfiles:/app/staticfiles   ← web пише сюди

  nginx:
    volumes:
      - staticfiles:/staticfiles:ro    ← nginx читає звідси (read-only)

nginx.conf:
  location /static/ {
    alias /staticfiles/;               ← nginx роздає файли напряму
  }
```

Обидва контейнери монтують **той самий** named volume — статика доступна nginx без Python.

---

## Запуск повного стеку

```bash
# 1. Скопіюй і заповни .env:
cp .env.example .env
# Відредагуй: NGROK_AUTHTOKEN і NGROK_DOMAIN

# 2. Запусти стек:
docker compose up --build

# 3. Перевір логи:
docker compose logs -f web    # Django/Uvicorn
docker compose logs -f nginx  # nginx access log
docker compose logs -f ngrok  # тунель

# 4. Відкрий у браузері:
#   http://localhost       ← через nginx (без ngrok)
#   http://localhost:4040  ← ngrok dashboard (traffic inspector)
#   https://your-domain.ngrok-free.app ← публічний URL

# 5. Зупинити:
docker compose down

# Зупинити і видалити дані (скинути БД):
docker compose down -v
```

---

## Корисні команди для дебагу

```bash
# Перевірити статус контейнерів
docker compose ps

# Відкрити shell у web контейнері
docker compose exec web bash

# Django команди у контейнері
docker compose exec web python manage.py shell
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py showmigrations

# Перевірити що nginx проксує правильно
docker compose exec nginx curl -I http://web:8001/accounts/login/

# Переглянути network і що підключено
docker network ls
docker network inspect notes_chat_app_app-net
```

---

## Deployment checklist — перед production

### Обов'язково:

- [ ] `SECRET_KEY` — унікальний, довгий, не "django-insecure-..."
- [ ] `DEBUG = False` — ніколи не True в production
- [ ] `ALLOWED_HOSTS` — конкретні домени, не `['*']`
- [ ] `CSRF_TRUSTED_ORIGINS` — включає твій домен
- [ ] `DATABASE_URL` — PostgreSQL з strong password
- [ ] `REDIS_URL` — Redis для channel layer (InMemory не масштабується)
- [ ] `.env` у `.gitignore` — ніколи не комітити credentials
- [ ] `entrypoint.sh` без `--reload` для Uvicorn
- [ ] `SEED_DEMO_DATA` не встановлено або `--force` прибрати

### Для HTTPS:

```python
# settings.py — розкоментуй коли є SSL-сертифікат:
# SESSION_COOKIE_SECURE = True   # cookie тільки через HTTPS
# CSRF_COOKIE_SECURE = True
# SECURE_SSL_REDIRECT = True     # HTTP → HTTPS redirect
# SECURE_HSTS_SECONDS = 31536000 # браузер запам'ятовує HTTPS на 1 рік
```

### Nginx у production:

```nginx
# Додай до nginx.conf:
server {
    listen 443 ssl;
    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    # ...
}

server {
    listen 80;
    return 301 https://$host$request_uri;  # HTTP → HTTPS
}
```

---

## Типові помилки і виправлення

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `ERR_NGROK_8012: no such host nginx` | ngrok не на тій самій мережі | Явна `app-net` + health check для nginx |
| `403 CSRF verification failed` | ngrok домен не в `CSRF_TRUSTED_ORIGINS` | Додати `NGROK_DOMAIN` у web environment і `CSRF_TRUSTED_ORIGINS` у settings |
| `CommandError: Demo data seeding is disabled when DEBUG=False` | `entrypoint.sh` не передає `--force` | `seed_demo_data --force` |
| `Static files not found` | `collectstatic` не запущений | Перевірити `entrypoint.sh`, volume `staticfiles` |
| `WebSocket 403` | `ALLOWED_HOSTS` не включає ngrok домен | Перевірити `ALLOWED_HOSTS = ['*']` або додати домен |
| `SynchronousOnlyOperation` | Sync ORM у async consumer | `@database_sync_to_async` |

---

## ngrok — публічний доступ

```bash
# Варіант 1: через Docker Compose (рекомендовано)
# Додай у .env:
NGROK_AUTHTOKEN=your_token
NGROK_DOMAIN=your-subdomain.ngrok-free.app

docker compose up -d
# ngrok сервіс стартує після nginx health check

# Варіант 2: локально (якщо не через Docker)
ngrok http --url=your-subdomain.ngrok-free.app 80

# ngrok dashboard (інспекція трафіку):
http://localhost:4040
```

**Один домен — одне з'єднання:** якщо ngrok вже запущений локально і ти запускаєш Docker — отримаєш `ERR_NGROK_334`. Зупини локальний ngrok перед `docker compose up`.

---

## Практичне завдання

1. Зупини поточний стек: `docker compose down`. Запусти знову: `docker compose up --build`. Переглянь логи: `docker compose logs -f web`. Знайди рядки `Applying migrations`, `collectstatic`, `seed_demo_data`, `Started server`.

2. Відкрий `http://localhost:4040` — ngrok dashboard. Зроби логін через `https://your-domain.ngrok-free.app`. Переглянь request у ngrok dashboard — які заголовки передає ngrok?

3. Спробуй відкрити `http://localhost:4040/inspect/http` і переглянути CSRF token у cookie та в POST body при login.

4. Зайди у контейнер: `docker compose exec web bash`. Запусти `python manage.py check --deploy` — переглянь що Django рекомендує для production.

5. У `nginx.conf` знайди блок WebSocket. Видали рядок `proxy_http_version 1.1` і перезапусти nginx (`docker compose restart nginx`). Спробуй відкрити чат. Що відбулось? Поверни рядок назад.

---

## Чеклист самоперевірки

- [ ] `.env` заповнений (скопійований з `.env.example`)
- [ ] `NGROK_AUTHTOKEN` і `NGROK_DOMAIN` встановлені
- [ ] `docker compose up --build` запускається без помилок
- [ ] `http://localhost` відкривається (nginx)
- [ ] `http://localhost:4040` відкривається (ngrok dashboard)
- [ ] Login через ngrok URL працює без 403
- [ ] Груповий чат (WebSocket) працює через ngrok
- [ ] `docker compose logs nginx` показує access log запитів

---

## Далі

Вітаю — ти пройшов весь маршрут від першого Django view до production-ready deployment з Docker, nginx, WebSocket і публічним тунелем!

Модулі документації:
- [Deployment](../11_deployment/README.md)
- [Final Project](../12_final_project/README.md)
