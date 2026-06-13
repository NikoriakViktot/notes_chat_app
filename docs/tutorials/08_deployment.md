# Туторіал 08 — Deployment: Docker, nginx, ngrok

**Мета:** зрозуміти як notes_chat_app запускається у Docker Compose, як nginx виступає reverse proxy, як ngrok відкриває публічний доступ, і що потрібно перевірити перед production deployment.

---

## Зміст

1. [Загальна картина стеку](#загальна-картина-стеку)
2. [Dockerfile — образ Django](#dockerfile--образ-django)
3. [entrypoint.sh — ланцюг запуску](#entrypointsh--ланцюг-запуску)
4. [docker-compose.yml — сервіси і залежності](#docker-composeyml--сервіси-і-залежності)
5. [Health checks — чому важливо](#health-checks--чому-важливо)
6. [PostgreSQL — від SQLite до production БД](#postgresql--від-sqlite-до-production-бд)
7. [Redis — channel layer у Docker](#redis--channel-layer-у-docker)
8. [nginx.conf — reverse proxy з WebSocket](#nginxconf--reverse-proxy-з-websocket)
9. [.env — конфігурація і secrets](#env--конфігурація-і-secrets)
10. [CSRF_TRUSTED_ORIGINS — чому виникає 403 через ngrok](#csrf_trusted_origins--чому-виникає-403-через-ngrok)
11. [staticfiles volume — як статика потрапляє до nginx](#staticfiles-volume--як-статика-потрапляє-до-nginx)
12. [ngrok — публічний доступ](#ngrok--публічний-доступ)
13. [Selenium — E2E тести у Docker](#selenium--e2e-тести-у-docker)
14. [GitHub Actions CI/CD](#github-actions-cicd)
15. [Запуск повного стеку](#запуск-повного-стеку)
16. [Корисні команди](#корисні-команди)
17. [Production checklist](#production-checklist)
18. [Типові помилки](#типові-помилки)
19. [Практичне завдання](#практичне-завдання)

---

## Загальна картина стеку

```
Інтернет (через ngrok)
    │
    ▼
nginx :80  ← reverse proxy, SSL termination, static files
    │
    ├── GET /static/*  →  /staticfiles/ volume (nginx роздає напряму)
    │
    └── все інше  →  web:8001
                         │
               Uvicorn ASGI :8001
                         │
              ProtocolTypeRouter (asgi.py)
                         │
              ├── HTTP  → Django views
              └── WS   → GroupChatConsumer
                              │
                  ├── PostgreSQL :5432  (дані)
                  └── Redis :6379       (channel layer)

ngrok ← тунель від nginx до публічного URL
Selenium :4444 ← headless Chrome для E2E тестів
```

### Таблиця сервісів

| Сервіс | Image | Порт | Роль |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Реляційна БД |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, статика |
| `ngrok` | `ngrok/ngrok:latest` | 4040 | Публічний HTTPS тунель |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome для E2E |

### Dev vs Production

| | Dev (попередні уроки) | Production (notes_chat_app) |
|--|----------------------|---------------------------|
| **БД** | SQLite (файл) | PostgreSQL (окремий контейнер) |
| **Сервер** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (статика, WebSocket headers) |
| **Channel layer** | InMemory | Redis (масштабується між workers) |
| **Публічний доступ** | — | ngrok (HTTPS тунель) |
| **Запуск** | `python manage.py runserver` | `docker compose up` |

---

## Dockerfile — образ Django

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app

# ENV змінні — встановлюємо один раз для всіх наступних шарів
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=notes_project.settings \
    PYTHONPATH=/app

# Спочатку тільки requirements.txt — шар кешується якщо файл не змінився
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Потім весь код — цей шар перебудовується при кожній зміні коду
COPY . .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
```

### Пояснення ENV змінних

| ENV | Навіщо |
|-----|--------|
| `PYTHONDONTWRITEBYTECODE=1` | Не створює `.pyc` файли (зменшує розмір образу) |
| `PYTHONUNBUFFERED=1` | Логи виводяться одразу без буферизації (видно у docker logs) |
| `DJANGO_SETTINGS_MODULE` | Django знає який settings.py використовувати |
| `PYTHONPATH=/app` | Python шукає модулі у `/app` (не у підпапках) |

### Чому requirements.txt копіюється ПЕРЕД кодом

```
Шар 1: FROM python:3.12-slim         ← кешується (рідко змінюється)
Шар 2: COPY requirements.txt .       ← кешується якщо requirements.txt не змінився
Шар 3: RUN pip install ...           ← кешується разом з шаром 2
Шар 4: COPY . .                      ← ЗАВЖДИ перебудовується (код змінюється часто)
Шар 5: CMD [...]                     ← легкий

Якщо скопіювати весь код ПЕРЕД pip install:
  → при кожній зміні коду → pip install знову → довга перебудова (~2-3 хв)

З розподілом як вище:
  → при зміні коду → тільки COPY . . → швидко (~10 сек)
```

---

## entrypoint.sh — ланцюг запуску

```sh
#!/bin/sh
set -e   # зупинитись при будь-якій помилці (будь-яка команда повертає не-0)

# 1. Застосовуємо нові міграції
python manage.py migrate --noinput

# 2. Збираємо static files у /app/staticfiles/ (звідти nginx бере)
python manage.py collectstatic --noinput

# 3. Seed демо-даними якщо вказано
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
fi

# 4. Запускаємо ASGI сервер
# exec = замінює shell процес uvicorn
# БЕЗ exec: shell (PID 1) → uvicorn (PID 2)
#    SIGTERM → до shell → shell ігнорує → uvicorn не отримує → контейнер не зупиняється
# З exec: uvicorn (PID 1) 
#    SIGTERM → до uvicorn → graceful shutdown → контейнер зупиняється коректно
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload     # ← ТІЛЬКИ для dev! Прибрати в production
```

### Ланцюг: set -e

```bash
set -e означає:
  Якщо migrate завершиться з помилкою (наприклад, БД недоступна)
  → entrypoint.sh зупиняється
  → collectstatic не виконується
  → uvicorn не стартує
  → контейнер виходить з кодом помилки
  → Docker Compose позначає web як failed
  → nginx не стартує (depends_on: service_healthy)

Без set -e:
  → migrate падає, але entrypoint.sh продовжується
  → uvicorn стартує без міграцій
  → 500 помилки на всіх сторінках
  → важко зрозуміти що пішло не так
```

### exec vs не-exec

```bash
# БЕЗ exec (погано):
python -m uvicorn ...
# Process tree:
#   PID 1: sh entrypoint.sh
#   PID 2: python uvicorn  ← SIGTERM не доходить до нього
#
# docker stop → SIGTERM → PID 1 (sh) → sh ігнорує
#             → 10 сек → SIGKILL → hard kill

# З exec (правильно):
exec python -m uvicorn ...
# Process tree:
#   PID 1: python uvicorn  ← SIGTERM приходить напряму
#
# docker stop → SIGTERM → PID 1 (uvicorn) → graceful shutdown
#             → допомагає завершити активні WebSocket з'єднання
```

---

## docker-compose.yml — сервіси і залежності

### Повна схема залежностей

```
db          → healthy?
redis       → healthy?
                 │
                 ▼
            web (migrate → collectstatic → seed → uvicorn)
                 │
            web healthy?
                 │
            nginx
                 │
            nginx healthy?
                 │
            ngrok  (тунель відкривається тільки коли nginx живий)
            selenium (завжди готовий — незалежно від web)
```

### Повний docker-compose.yml

```yaml
services:

  # ─── PostgreSQL ────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data  # зберігається між restart
    environment:
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      retries: 5
    networks: [app-net]

  # ─── Redis ─────────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]   # PONG = Redis живий
      interval: 5s
    networks: [app-net]

  # ─── Web (Django) ──────────────────────────────────────────────────
  web:
    build: .
    ports:
      - "8001:8001"      # прямий доступ для Selenium (тести не через nginx)
    environment:
      DATABASE_URL:  postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL:     redis://redis:6379/0
      SECRET_KEY:    ${SECRET_KEY}
      DEBUG:         ${DEBUG:-False}
      ALLOWED_HOSTS: ${ALLOWED_HOSTS:-localhost,127.0.0.1}
      NGROK_DOMAIN:  ${NGROK_DOMAIN}
      SEED_DEMO_DATA: ${SEED_DEMO_DATA:-0}
      WEB_HOST:      web         # Selenium використовує це ім'я для підключення
      SELENIUM_REMOTE_URL: http://selenium:4444/wd/hub
    volumes:
      - staticfiles:/app/staticfiles   # web пише → nginx читає
    depends_on:
      db:    {condition: service_healthy}
      redis: {condition: service_healthy}
    healthcheck:
      test: >
        python -c "import urllib.request;
        urllib.request.urlopen('http://localhost:8001/accounts/login/')"
      interval: 5s
      retries: 12
      start_period: 15s   # перший healthcheck через 15 сек (час для migrate)
    networks: [app-net]

  # ─── Nginx ─────────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro   # read-only
      - staticfiles:/staticfiles:ro                   # read-only
    depends_on:
      web: {condition: service_healthy}
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost/accounts/login/ || exit 1"]
      interval: 10s
    networks: [app-net]

  # ─── Ngrok ─────────────────────────────────────────────────────────
  ngrok:
    image: ngrok/ngrok:latest
    command: http --url=${NGROK_DOMAIN} nginx:80
    environment:
      NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
    ports: ["4040:4040"]   # dashboard: http://localhost:4040
    depends_on:
      nginx: {condition: service_healthy}
    networks: [app-net]

  # ─── Selenium ──────────────────────────────────────────────────────
  selenium:
    image: selenium/standalone-chrome:latest
    ports:
      - "4444:4444"    # WebDriver API
      - "7900:7900"    # VNC (переглянути браузер живцем)
    shm_size: '2g'     # Chrome потребує shared memory
    networks: [app-net]

# ─── Named volumes ───────────────────────────────────────────────────
volumes:
  postgres_data:    # PostgreSQL дані (зберігаються між docker compose down/up)
  staticfiles:      # Django collectstatic output → nginx

# ─── Named network ───────────────────────────────────────────────────
networks:
  app-net:
    driver: bridge
    # Явна мережа: "nginx" → IP nginx, "redis" → IP redis
    # Без явної мережі ngrok може не знайти "nginx" → ERR_NGROK_8012
```

---

## Health checks — чому важливо

### Проблема без health checks

```
БЕЗ health checks:
  docker compose up
  → db стартує (але PostgreSQL ще ініціалізується ~3 сек)
  → web стартує (depends_on: db — але тільки "started", не "healthy")
  → entrypoint.sh: migrate → ERROR: could not connect to server
  → uvicorn не стартує
  → nginx не стартує (але починає спроби)
  → ngrok не може достукатись → ERR_NGROK_8012

З health checks (condition: service_healthy):
  → db стартує → pg_isready → HEALTHY (тільки тоді web дозволяється запускати)
  → web стартує → migrate → uvicorn → healthcheck pass → HEALTHY
  → nginx стартує → HEALTHY
  → ngrok стартує (nginx вже готовий)
```

### start_period — пояснення

```yaml
web:
  healthcheck:
    interval: 5s
    retries: 12
    start_period: 15s
```

```
0s   → контейнер стартував
0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
       start_period: healthcheck не вважається failure в цей час
15s  → починаються реальні перевірки кожні 5s
75s  → якщо всі 12 спроб (5s × 12 = 60s) провалились → UNHEALTHY
       nginx не стартує

Без start_period:
  → healthcheck стартує відразу
  → migrate займає 8–10с → healthcheck fails
  → через 12 × 5s = 60s → UNHEALTHY
  → nginx намагається стартувати на broken web → 502
```

### Типи healthcheck тестів

```yaml
# PostgreSQL — pg_isready (офіційна утиліта):
test: ["CMD-SHELL", "pg_isready -U myuser -d mydb"]

# Redis — redis-cli ping:
test: ["CMD", "redis-cli", "ping"]

# Web — HTTP запит:
test: >
  python -c "import urllib.request;
  urllib.request.urlopen('http://localhost:8001/accounts/login/')"

# Nginx — curl HTTP:
test: ["CMD-SHELL", "curl -sf http://localhost/accounts/login/ || exit 1"]
# -s: silent (no progress bar), -f: fail on HTTP errors (4xx/5xx)
```

---

## PostgreSQL — від SQLite до production БД

### Підключення через DATABASE_URL

```python
# notes_project/settings.py
import dj_database_url
import os

DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    # Production: PostgreSQL
    DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
    # dj_database_url.parse('postgres://user:pass@db:5432/notes_db') →
    # {
    #     'ENGINE': 'django.db.backends.postgresql',
    #     'NAME': 'notes_db',
    #     'USER': 'user',
    #     'PASSWORD': 'pass',
    #     'HOST': 'db',     ← Docker DNS: "db" → IP контейнера
    #     'PORT': '5432',
    # }
else:
    # Dev: SQLite
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
```

### Чому PostgreSQL, а не SQLite

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **Файл** | Один файл `db.sqlite3` | Окремий сервер |
| **Конкурентні записи** | Блокує файл при записі | Справжні транзакції, MVCC |
| **PostGIS** | — | Геопросторові типи (GEOMETRY, GEOGRAPHY) |
| **JSON** | Обмежена підтримка | jsonb з індексами |
| **Production** | Не рекомендовано | Стандарт |

### Внутрішня DNS у Docker мережі

```
docker-compose.yml:
  services:
    db:    ← ім'я сервісу = DNS ім'я
    redis:
    web:
    nginx:

У мережі app-net:
  "db"     → IP контейнера db    (postgres)
  "redis"  → IP контейнера redis
  "web"    → IP контейнера web   (uvicorn)
  "nginx"  → IP контейнера nginx

DATABASE_URL: postgres://user:pass@db:5432/notes_db
                                    ↑
                              Docker DNS резолюція
```

### Дані між restartами

```yaml
volumes:
  postgres_data:    # named volume

services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

```bash
docker compose down        # зупиняє контейнери, volume зберігається
docker compose up          # postgres_data → дані збережені

docker compose down -v     # -v: видаляє volumes → БД очищена
```

---

## Redis — channel layer у Docker

```yaml
redis:
  image: redis:7-alpine
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
  networks: [app-net]
```

```python
# settings.py
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,           # redis://redis:6379/0
                    "socket_timeout": None,          # ← критично
                    "socket_connect_timeout": 5,
                    "health_check_interval": 30,
                }],
            },
        }
    }
```

Redis у Docker — це `redis://redis:6379/0`:
- `redis` — DNS ім'я сервісу у Docker мережі
- `6379` — стандартний порт Redis
- `/0` — database index (Redis підтримує 16 баз, 0–15)

**Детально про socket_timeout=None** → [07 — Async](07_async.md#inmemory-vs-redis-channel-layer)

---

## nginx.conf — reverse proxy з WebSocket

```nginx
# nginx/nginx.conf
worker_processes auto;  # автоматично — по кількості CPU cores

events {
    worker_connections 1024;  # макс. з'єднань на один worker
}

http {
    include /etc/nginx/mime.types;  # MIME types для static files

    # ─── WebSocket upgrade map ──────────────────────────────────────
    # Визначає значення Connection header залежно від Upgrade:
    #   Upgrade: websocket → Connection: upgrade
    #   (пустий Upgrade) → Connection: close
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ─── Upstream (Django) ──────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — DNS ім'я сервісу
    }

    server {
        listen 80;

        # ─── Static files ───────────────────────────────────────────
        # nginx роздає статику напряму, Django не задіяний
        location /static/ {
            alias /staticfiles/;     # volume з collectstatic
            expires 7d;
            add_header Cache-Control "public, immutable";
            # immutable: браузер не перевіряє оновлення протягом 7 днів
        }

        # ─── Все інше (HTTP + WebSocket) → uvicorn ──────────────────
        location / {
            proxy_pass http://django;

            # Оригінальні headers від браузера → Django
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ─── WebSocket upgrade — ОБОВ'ЯЗКОВО ────────────────────
            proxy_http_version 1.1;
            # ↑ WebSocket Upgrade handshake вимагає HTTP/1.1
            #   Без цього nginx використовує HTTP/1.0 → Upgrade ігнорується
            
            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ Ці headers включають WebSocket на рівні nginx

            # Timeout для довготривалих з'єднань
            proxy_read_timeout 300s;     # 5 хвилин — для idle WS
            proxy_connect_timeout 75s;
        }
    }
}
```

### Без nginx vs з nginx (static files)

```
Без nginx:
  Browser → Django/Uvicorn → читає CSS/JS з disk → повертає
  Python process задіяний для кожного статичного файлу

З nginx:
  Browser → nginx → читає CSS/JS з disk напряму → повертає
  Django/Uvicorn не задіяний взагалі

Nginx роздає статику у 5-10x швидше і звільняє Python workers
для обробки реальних запитів.
```

### Чому WebSocket потребує HTTP/1.1

```
HTTP/1.0: кожен запит = нове з'єднання
HTTP/1.1: keepalive — з'єднання залишається відкритим

WebSocket Upgrade handshake:
  GET /ws/groups/7/chat/ HTTP/1.1  ← ОБОВ'ЯЗКОВО 1.1
  Upgrade: websocket
  Connection: Upgrade

Якщо nginx проксує як HTTP/1.0:
  Upgrade заголовок ігнорується
  → handshake не проходить
  → WS з'єднання не встановлюється
  → браузер отримує 400 або 404
```

---

## .env — конфігурація і secrets

```bash
# .env (НІКОЛИ не комітити в git — вже у .gitignore)
# Копіювати з .env.example: cp .env.example .env

# ─── PostgreSQL ───────────────────────────────────────────────────
POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=change_me_very_strong_password_here

# ─── Django ───────────────────────────────────────────────────────
# Генерувати: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
SECRET_KEY=your-very-long-random-secret-key-here

DATABASE_URL=postgres://notes_user:change_me@db:5432/notes_db
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1

# ─── Redis ────────────────────────────────────────────────────────
REDIS_URL=redis://redis:6379/0

# ─── Selenium ─────────────────────────────────────────────────────
SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub
WEB_HOST=web

# ─── ngrok ────────────────────────────────────────────────────────
# Отримати на https://dashboard.ngrok.com/authtokens
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
# Зарезервувати на https://dashboard.ngrok.com/domains
NGROK_DOMAIN=your-subdomain.ngrok-free.app

# ─── Seed ─────────────────────────────────────────────────────────
SEED_DEMO_DATA=1   # 1 = засіяти демо-даними при старті
```

### Як генерувати SECRET_KEY

```bash
# Варіант 1: через Docker
docker compose run --rm web python -c \
    "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Варіант 2: локально
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Результат: щось на зразок
# django-insecure-abc123xyz...   ← "insecure" тільки у дефолтному ключі
# x#3k@!mz9...                   ← правильно згенерований
```

### Як .env потрапляє у контейнери

```yaml
# docker-compose.yml автоматично читає .env з поточної директорії
# ${VAR} підставляється з .env:

services:
  db:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}  # ← з .env

  web:
    environment:
      SECRET_KEY: ${SECRET_KEY}                # ← з .env
      NGROK_DOMAIN: ${NGROK_DOMAIN}            # ← з .env
```

---

## CSRF_TRUSTED_ORIGINS — чому виникає 403 через ngrok

### Симптом

```
Зайшов на https://fawn-natural-mayfly.ngrok-free.app/accounts/login/
Вводиш логін, натискаєш "Увійти"
→ 403 Forbidden: CSRF verification failed. Request aborted.
```

### Причина

```
POST /accounts/login/ HTTP/1.1
Host: fawn-natural-mayfly.ngrok-free.app
Origin: https://fawn-natural-mayfly.ngrok-free.app
X-CSRFToken: abc123...

Django перевіряє Origin header:
  Чи є "https://fawn-natural-mayfly.ngrok-free.app" у CSRF_TRUSTED_ORIGINS?
  CSRF_TRUSTED_ORIGINS = []   ← пусто → 403
```

### Рішення

```python
# notes_project/settings.py
import os

_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# ALLOWED_HOSTS також потрібно налаштувати:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

```yaml
# docker-compose.yml — передаємо NGROK_DOMAIN у web контейнер:
services:
  web:
    environment:
      NGROK_DOMAIN: ${NGROK_DOMAIN}   # ← з .env → settings.py
```

### Ланцюг передачі значення

```
.env:
  NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

docker-compose.yml:
  web.environment.NGROK_DOMAIN: ${NGROK_DOMAIN}
  → передає у контейнер

settings.py:
  _ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
  CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']
  
Django:
  POST /login/ → Origin check → trusted → 200 OK
```

---

## staticfiles volume — як статика потрапляє до nginx

```
Крок 1: entrypoint.sh
  python manage.py collectstatic --noinput
  → Збирає всі static files:
    - notes_app/static/notes_app/css/style.css
    - notes_app/static/notes_app/js/group_chat.js
    - django/contrib/admin/static/admin/...
    - crispy_forms/...
  → Копіює у /app/staticfiles/

Крок 2: docker-compose.yml
  web:
    volumes:
      - staticfiles:/app/staticfiles   ← web ПИШЕ сюди

  nginx:
    volumes:
      - staticfiles:/staticfiles:ro    ← nginx ЧИТАЄ звідси (read-only)

Крок 3: nginx.conf
  location /static/ {
    alias /staticfiles/;   ← роздає напряму
  }

Результат:
  GET /static/notes_app/css/style.css
  → nginx → /staticfiles/notes_app/css/style.css
  → файл повертається напряму (Python не задіяний)
```

### STATIC_ROOT у settings.py

```python
# settings.py
STATIC_URL = '/static/'

# collectstatic копіює всі static files сюди:
STATIC_ROOT = BASE_DIR / 'staticfiles'   # /app/staticfiles

# Де Django шукає static files (окрім <app>/static/):
STATICFILES_DIRS = []  # зазвичай пусто — Django знаходить <app>/static/
```

---

## ngrok — публічний доступ

### Як ngrok працює

```
Браузер у Інтернеті → ngrok servers → тунель → Docker nginx → Django

Без ngrok:
  Django доступний тільки на localhost — ніхто інший не може зайти

З ngrok:
  ngrok надає публічний URL: https://fawn-natural-mayfly.ngrok-free.app
  Весь трафік з Інтернету → ngrok → твій nginx:80
```

### Конфігурація у Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ створює тунель:
  #   Публічний URL: https://${NGROK_DOMAIN}
  #   Ціль всередині Docker: nginx:80
  environment:
    NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
  ports:
    - "4040:4040"   # ngrok dashboard
  depends_on:
    nginx: {condition: service_healthy}
  networks: [app-net]
```

### ngrok dashboard

```
http://localhost:4040   ← ngrok dashboard

Показує:
  - Всі HTTP/WS запити в реальному часі
  - Headers (Upgrade, Cookie, X-Forwarded-For)
  - Response status
  - Request/response body
  - CSRF token у cookie та POST body

Корисно для:
  - Debugging CSRF помилок
  - Перевірки WebSocket handshake headers
  - Аналізу трафіку від зовнішніх юзерів
```

### Один домен — одне з'єднання

```bash
# ❌ Помилка: ngrok вже запущений локально + у Docker
ngrok http --url=my-domain.ngrok-free.app 80 &   # локально
docker compose up                                  # ngrok у Docker
# → ERR_NGROK_334: session limit exceeded

# ✅ Один спосіб за раз:
# Варіант A: тільки через Docker (рекомендовано)
docker compose up -d

# Варіант B: тільки локально
ngrok http --url=my-domain.ngrok-free.app 80
```

---

## Selenium — E2E тести у Docker

### Конфігурація

```yaml
selenium:
  image: selenium/standalone-chrome:latest
  ports:
    - "4444:4444"    # WebDriver API (використовується test_selenium.py)
    - "7900:7900"    # VNC (переглянути браузер: http://localhost:7900)
  shm_size: '2g'     # Chrome потребує shared memory
  networks: [app-net]
```

### Чому E2E тести запускаються через exec, не run

```bash
# ❌ НЕПРАВИЛЬНО — docker compose run:
docker compose run --rm web python manage.py test notes_app.tests.test_selenium
# run створює НОВИЙ контейнер
# Новий контейнер не має DNS alias "web" у мережі
# Selenium намагається GET http://web:8001/... → Cannot resolve host

# ✅ ПРАВИЛЬНО — docker compose exec:
docker compose up -d   # спочатку підняти стек
docker compose exec web python manage.py test notes_app.tests.test_selenium
# exec виконується У вже запущеному контейнері web
# web контейнер вже зареєстрований у Docker network з alias "web"
# Selenium: GET http://web:8001/ → DNS resolution → IP контейнера web
```

### _DockerLiveServerMixin

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Selenium LiveServerTestCase мікс для Docker Compose.
    
    Проблема: LiveServerTestCase за замовчуванням прив'язується до 127.0.0.1
    У Docker: 127.0.0.1 не доступний для інших контейнерів.
    
    Рішення: прив'язуємось до 0.0.0.0 (всі інтерфейси).
    WEB_HOST: env змінна → Selenium використовує "web" (DNS ім'я) для підключення.
    """
    host = '0.0.0.0'

    @classmethod
    def _make_driver(cls):
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options

        options = Options()
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')

        selenium_url = os.environ.get('SELENIUM_REMOTE_URL', 'http://selenium:4444/wd/hub')
        return webdriver.Remote(
            command_executor=selenium_url,
            options=options,
        )

    def _login_via_cookie(self, user):
        """
        Швидкий логін через session cookie (без форми).
        Обходить форму логіну → тести швидші.
        """
        from django.contrib.sessions.backends.db import SessionStore
        
        session = SessionStore()
        session[settings.AUTH_USER_SESSION_KEY] = user.pk
        session['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
        session['_auth_user_hash'] = user.get_session_auth_hash()
        session.save()

        web_host = os.environ.get('WEB_HOST', 'web')
        self.driver.get(f'http://{web_host}:{self.server_thread.port}/')
        self.driver.add_cookie({
            'name': settings.SESSION_COOKIE_NAME,
            'value': session.session_key,
        })
```

---

## GitHub Actions CI/CD

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:

  # ─── Job 1: Unit + Integration + Consumer тести ──────────────────
  test:
    runs-on: ubuntu-latest

    services:
      db:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: notes_db
          POSTGRES_USER: notes_user
          POSTGRES_PASSWORD: notes_password
        options: >-
          --health-cmd "pg_isready -U notes_user -d notes_db"
          --health-interval 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
        ports:
          - 6379:6379

    env:
      DATABASE_URL: postgres://notes_user:notes_password@localhost:5432/notes_db
      REDIS_URL: redis://localhost:6379/0
      SECRET_KEY: ci-test-secret-key-not-for-production
      DEBUG: "True"
      ALLOWED_HOSTS: "localhost,127.0.0.1"

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run migrations
        run: python manage.py migrate --noinput

      - name: Run tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2

  # ─── Job 2: Selenium E2E тести ───────────────────────────────────
  selenium-e2e:
    runs-on: ubuntu-latest
    needs: test   # запускається тільки після успіху job test

    steps:
      - uses: actions/checkout@v4

      - name: Start stack
        run: |
          cp .env.example .env
          echo "SECRET_KEY=ci-secret" >> .env
          echo "SEED_DEMO_DATA=1" >> .env
          docker compose up -d --build
          docker compose ps

      - name: Wait for web to be healthy
        run: |
          timeout 120 bash -c \
            'until docker compose exec web python -c \
              "import urllib.request; urllib.request.urlopen(\"http://localhost:8001/accounts/login/\")" \
            2>/dev/null; do sleep 3; done'

      - name: Run Selenium tests
        run: docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

      - name: Upload failure screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: selenium-screenshots
          path: /tmp/selenium-screenshots/
          retention-days: 3

      - name: Cleanup
        if: always()
        run: docker compose down -v
```

---

## Запуск повного стеку

### Перший запуск

```bash
# 1. Скопіюй і заповни .env:
cp .env.example .env
# Відредагуй у будь-якому редакторі:
#   SECRET_KEY   — згенеруй (інструкція вище)
#   NGROK_AUTHTOKEN — з https://dashboard.ngrok.com/authtokens
#   NGROK_DOMAIN — з https://dashboard.ngrok.com/domains

# 2. Запусти стек:
docker compose up --build
# --build: перезбирає образ (потрібно при зміні Dockerfile або requirements.txt)

# 3. Переглянь логи:
# (у окремому терміналі)
docker compose logs -f web    # Django/Uvicorn логи
docker compose logs -f nginx  # nginx access log
docker compose logs -f ngrok  # тунель статус
```

### Очікуваний вивід у docker compose up

```
db-1       | PostgreSQL init process complete; ready for start up
db-1       | database system is ready to accept connections
redis-1    | Ready to accept connections
web-1      | Operations to perform: Apply all migrations: ...
web-1      |   Applying notes_app.0001_initial... OK
web-1      | 128 static files copied to '/app/staticfiles'
web-1      | Seeding demo data...
web-1      | INFO:     Application startup complete.
web-1      | INFO:     Uvicorn running on http://0.0.0.0:8001
nginx-1    | Starting nginx
ngrok-1    | started tunnel session ... url=https://your-domain.ngrok-free.app
```

### Доступ після запуску

```bash
# Local:
open http://localhost          # через nginx
open http://localhost:4040     # ngrok dashboard

# Public (через ngrok):
open https://your-domain.ngrok-free.app

# Демо-облікові записи (пароль: demo1234):
# demo_alice, demo_bob, demo_carol
```

### Зупинка і очищення

```bash
docker compose down           # зупиняє, зберігає volumes (БД)
docker compose down -v        # зупиняє + видаляє volumes (скидає БД)
docker compose down --rmi all # зупиняє + видаляє images
docker compose restart web    # перезапустити тільки web сервіс
```

---

## Корисні команди

```bash
# ─── Стан ────────────────────────────────────────────────────────────
docker compose ps                    # статус всіх сервісів
docker compose top                   # процеси у контейнерах

# ─── Логи ─────────────────────────────────────────────────────────────
docker compose logs web              # всі логи web
docker compose logs -f web           # слідкувати у реальному часі
docker compose logs --tail=50 web    # останні 50 рядків

# ─── Shell у контейнері ───────────────────────────────────────────────
docker compose exec web bash                    # shell у web
docker compose exec web python manage.py shell  # Django shell
docker compose exec web python manage.py check --deploy  # production аудит
docker compose exec db psql -U notes_user notes_db       # PostgreSQL shell

# ─── Django команди ───────────────────────────────────────────────────
docker compose exec web python manage.py showmigrations
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py seed_demo_data --reset

# ─── Дебаг мережі ─────────────────────────────────────────────────────
docker network ls
docker network inspect notes_chat_app_app-net
docker compose exec nginx curl -I http://web:8001/accounts/login/
docker compose exec web ping db    # перевірка DNS між контейнерами

# ─── Перебудова ───────────────────────────────────────────────────────
docker compose up --build          # перебудувати образ
docker compose build --no-cache web # без кешу (після зміни pip dependencies)
```

---

## Production checklist

### Обов'язково перед production

- [ ] `SECRET_KEY` — унікальний, мінімум 50 символів, не "django-insecure-..."
- [ ] `DEBUG = False` — ніколи не `True` в production
- [ ] `ALLOWED_HOSTS` — конкретні домени, не `['*']`
- [ ] `CSRF_TRUSTED_ORIGINS` — включає твій домен
- [ ] `DATABASE_URL` — PostgreSQL з strong password (не `notes_password`)
- [ ] `REDIS_URL` — Redis для channel layer (InMemory не масштабується)
- [ ] `.env` у `.gitignore` — ніколи не комітити credentials
- [ ] `entrypoint.sh` — прибрати `--reload` у Uvicorn
- [ ] `SEED_DEMO_DATA` — не встановлено або прибрати `--force`

### Для HTTPS

```python
# settings.py — розкоментуй коли є SSL сертифікат:
SESSION_COOKIE_SECURE = True    # cookie тільки через HTTPS
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True      # HTTP → HTTPS redirect
SECURE_HSTS_SECONDS = 31536000  # браузер запам'ятовує HTTPS на 1 рік
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
```

### Nginx у production (з SSL)

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /static/ {
        alias /staticfiles/;
        expires 7d;
    }

    location / {
        proxy_pass http://django;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;  # HTTP → HTTPS redirect
}
```

### `python manage.py check --deploy`

```bash
docker compose exec web python manage.py check --deploy

# Показує що потрібно налаштувати для production:
# WARNINGS:
# ?: (security.W004) You have not set SECURE_HSTS_SECONDS
# ?: (security.W008) Your SECRET_KEY has less than 50 characters
# ?: (security.W012) SESSION_COOKIE_SECURE is not set to True
# ...
```

---

## Типові помилки

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `ERR_NGROK_8012: no such host nginx` | ngrok і nginx не на одній мережі | Явна `app-net` network |
| `403 CSRF verification failed` | ngrok домен не у `CSRF_TRUSTED_ORIGINS` | Додати у settings.py + передати NGROK_DOMAIN у web |
| `403 WebSocket` | ngrok домен не у `ALLOWED_HOSTS` | Додати домен у ALLOWED_HOSTS |
| `ERR_NGROK_334: session limit` | ngrok запущений і локально і у Docker | Зупинити один з них |
| Static files 404 | `collectstatic` не запущений або volume не змонтований | Перевірити entrypoint.sh і volumes |
| `web` unhealthy → nginx не стартує | Migrate падає або uvicorn не стартує | `docker compose logs web` |
| WS з'єднання не відкривається через nginx | Відсутні `proxy_http_version 1.1` або Upgrade headers | Додати у nginx.conf |
| `TimeoutError reading from redis` | `socket_timeout=5` у RedisChannelLayer | `"socket_timeout": None` у settings.py |
| `CommandError: Demo data seeding disabled` | `seed_demo_data` без `--force` коли `DEBUG=False` | `seed_demo_data --force` у entrypoint.sh |
| `SynchronousOnlyOperation` у consumer | sync ORM у async context | `@database_sync_to_async` |
| Дані зникли після `docker compose down` | Використано `down -v` | Backup перед `down -v` |

---

## Практичне завдання

**Завдання 1 — перший запуск:**
```bash
docker compose up --build
docker compose logs -f web
# Знайди рядки:
#   "Applying migrations"
#   "128 static files copied"
#   "Uvicorn running on http://0.0.0.0:8001"
```

**Завдання 2 — ngrok dashboard:**
```bash
# Відкрий http://localhost:4040
# Зайди на https://your-domain.ngrok-free.app/accounts/login/
# Переглянь запит у dashboard:
#   - Headers від браузера
#   - Які заголовки додає ngrok (X-Forwarded-For, etc.)
#   - CSRF token у cookie
```

**Завдання 3 — production check:**
```bash
docker compose exec web python manage.py check --deploy
# Що Django рекомендує для production?
# Скільки warnings?
```

**Завдання 4 — nginx WebSocket:**
```bash
# Знайди у nginx.conf блок WebSocket (proxy_http_version 1.1)
# Закоментуй рядок: # proxy_http_version 1.1;
docker compose restart nginx
# Спробуй відкрити чат — що сталось?
# Поверни рядок назад:
docker compose restart nginx
```

**Завдання 5 — статика:**
```bash
# Зайди всередину web контейнера:
docker compose exec web bash

# Переглянь зібрану статику:
ls /app/staticfiles/
ls /app/staticfiles/notes_app/

# Виконай collectstatic вручну:
python manage.py collectstatic --noinput

# Вийди:
exit
```

**Завдання 6 — PostgreSQL напряму:**
```bash
docker compose exec db psql -U notes_user notes_db

# Переглянь таблиці:
\dt

# Подивись юзерів:
SELECT id, username, email FROM auth_user;

# Вийди:
\q
```

---

## Чеклист самоперевірки

- [ ] `.env` заповнений (скопійований з `.env.example`)
- [ ] `NGROK_AUTHTOKEN` і `NGROK_DOMAIN` встановлені
- [ ] `docker compose up --build` завершується без помилок
- [ ] `http://localhost` відкривається і показує сайт (nginx)
- [ ] `http://localhost:4040` відкривається (ngrok dashboard)
- [ ] Login через ngrok URL (`https://...ngrok-free.app`) — без 403
- [ ] Груповий чат (WebSocket) через ngrok — повідомлення проходять
- [ ] `docker compose logs nginx` показує access log
- [ ] `docker compose exec web python manage.py check --deploy` — переглянуто
- [ ] Unit тести: `docker compose run --rm web python manage.py test notes_app.tests.test_models notes_app.tests.test_services notes_app.tests.test_consumers`

---

## Вітаємо!

Ти пройшов весь маршрут від першого Django view до production-ready deployment:

```
01 → Перший Django view (URL → View → Template)
02 → Перша модель (ORM, форми, PRG)
03 → CRUD та бізнес-логіка (selectors/services, N+1, транзакції)
04 → Шаблони та Bootstrap (3-рівневе наслідування, Crispy Forms)
05 → Автентифікація (login, register, UserProfile, декоратори)
06 → Тестування (піраміда тестів, TestCase, WebsocketCommunicator, Selenium)
07 → Async та WebSocket (ASGI, Channels, Consumer, channel layer)
08 → Deployment (Docker Compose, nginx, ngrok, production checklist)
```

Модулі документації:
- [Deployment](../11_deployment/README.md)
- [Final Project](../12_final_project/README.md)
