# Tutorial 08 — Deployment: Docker, nginx, ngrok

**Goal:** understand how notes_chat_app runs in Docker Compose, how nginx acts as a reverse proxy, how ngrok opens public access, and what needs to be checked before a production deployment.

---

## Contents

1. [The big picture of the stack](#the-big-picture-of-the-stack)
2. [Dockerfile — the Django image](#dockerfile--the-django-image)
3. [entrypoint.sh — the startup chain](#entrypointsh--the-startup-chain)
4. [docker-compose.yml — services and dependencies](#docker-composeyml--services-and-dependencies)
5. [Health checks — why they matter](#health-checks--why-they-matter)
6. [PostgreSQL — from SQLite to a production DB](#postgresql--from-sqlite-to-a-production-db)
7. [Redis — the channel layer in Docker](#redis--the-channel-layer-in-docker)
8. [nginx.conf — reverse proxy with WebSocket](#nginxconf--reverse-proxy-with-websocket)
9. [.env — configuration and secrets](#env--configuration-and-secrets)
10. [CSRF_TRUSTED_ORIGINS — why you get 403 through ngrok](#csrf_trusted_origins--why-you-get-403-through-ngrok)
11. [staticfiles volume — how static files reach nginx](#staticfiles-volume--how-static-files-reach-nginx)
12. [ngrok — public access](#ngrok--public-access)
13. [Selenium — E2E tests in Docker](#selenium--e2e-tests-in-docker)
14. [GitHub Actions CI/CD](#github-actions-cicd)
15. [Running the full stack](#running-the-full-stack)
16. [Useful commands](#useful-commands)
17. [Production checklist](#production-checklist)
18. [Common mistakes](#common-mistakes)
19. [Practical exercise](#practical-exercise)

---

## The big picture of the stack

```
Internet (via ngrok)
    │
    ▼
nginx :80  ← reverse proxy, SSL termination, static files
    │
    ├── GET /static/*  →  /staticfiles/ volume (nginx serves directly)
    │
    └── everything else  →  web:8001
                         │
               Uvicorn ASGI :8001
                         │
              ProtocolTypeRouter (asgi.py)
                         │
              ├── HTTP  → Django views
              └── WS   → GroupChatConsumer
                              │
                  ├── PostgreSQL :5432  (data)
                  └── Redis :6379       (channel layer)

ngrok ← tunnel from nginx to a public URL
Selenium :4444 ← headless Chrome for E2E tests
```

### Services table

| Service | Image | Port | Role |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Relational DB |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, static files |
| `ngrok` | `ngrok/ngrok:latest` | 4040 | Public HTTPS tunnel |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome for E2E |

### Dev vs Production

| | Dev (previous lessons) | Production (notes_chat_app) |
|--|----------------------|---------------------------|
| **DB** | SQLite (file) | PostgreSQL (separate container) |
| **Server** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (static files, WebSocket headers) |
| **Channel layer** | InMemory | Redis (scales across workers) |
| **Public access** | — | ngrok (HTTPS tunnel) |
| **Startup** | `python manage.py runserver` | `docker compose up` |

---

## Dockerfile — the Django image

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app

# ENV variables — set once for all subsequent layers
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=notes_project.settings \
    PYTHONPATH=/app

# First only requirements.txt — the layer is cached if the file has not changed
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then all the code — this layer is rebuilt on every code change
COPY . .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
```

### ENV variables explained

| ENV | Why |
|-----|--------|
| `PYTHONDONTWRITEBYTECODE=1` | Does not create `.pyc` files (reduces image size) |
| `PYTHONUNBUFFERED=1` | Logs are printed immediately without buffering (visible in docker logs) |
| `DJANGO_SETTINGS_MODULE` | Django knows which settings.py to use |
| `PYTHONPATH=/app` | Python looks for modules in `/app` (not in subfolders) |

### Why requirements.txt is copied BEFORE the code

```
Layer 1: FROM python:3.12-slim         ← cached (rarely changes)
Layer 2: COPY requirements.txt .       ← cached if requirements.txt has not changed
Layer 3: RUN pip install ...           ← cached together with layer 2
Layer 4: COPY . .                      ← ALWAYS rebuilt (code changes often)
Layer 5: CMD [...]                     ← lightweight

If you copy all the code BEFORE pip install:
  → on every code change → pip install again → long rebuild (~2-3 min)

With the split shown above:
  → on a code change → only COPY . . → fast (~10 sec)
```

---

## entrypoint.sh — the startup chain

```sh
#!/bin/sh
set -e   # stop on any error (any command returns non-0)

# 1. Apply new migrations
python manage.py migrate --noinput

# 2. Collect static files into /app/staticfiles/ (nginx takes them from there)
python manage.py collectstatic --noinput

# 3. Seed with demo data if requested
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
fi

# 4. Start the ASGI server
# exec = replaces the shell process with uvicorn
# WITHOUT exec: shell (PID 1) → uvicorn (PID 2)
#    SIGTERM → to shell → shell ignores it → uvicorn does not receive it → container does not stop
# WITH exec: uvicorn (PID 1) 
#    SIGTERM → to uvicorn → graceful shutdown → container stops correctly
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload     # ← ONLY for dev! Remove in production
```

### The chain: set -e

```bash
set -e means:
  If migrate fails (for example, the DB is unavailable)
  → entrypoint.sh stops
  → collectstatic is not executed
  → uvicorn does not start
  → the container exits with an error code
  → Docker Compose marks web as failed
  → nginx does not start (depends_on: service_healthy)

Without set -e:
  → migrate fails, but entrypoint.sh continues
  → uvicorn starts without migrations
  → 500 errors on every page
  → hard to understand what went wrong
```

### exec vs no exec

```bash
# WITHOUT exec (bad):
python -m uvicorn ...
# Process tree:
#   PID 1: sh entrypoint.sh
#   PID 2: python uvicorn  ← SIGTERM does not reach it
#
# docker stop → SIGTERM → PID 1 (sh) → sh ignores it
#             → 10 sec → SIGKILL → hard kill

# WITH exec (correct):
exec python -m uvicorn ...
# Process tree:
#   PID 1: python uvicorn  ← SIGTERM arrives directly
#
# docker stop → SIGTERM → PID 1 (uvicorn) → graceful shutdown
#             → helps close active WebSocket connections
```

---

## docker-compose.yml — services and dependencies

### Full dependency diagram

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
            ngrok  (the tunnel opens only when nginx is alive)
            selenium (always ready — independent of web)
```

### Full docker-compose.yml

```yaml
services:

  # ─── PostgreSQL ────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data  # persists across restarts
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
      test: ["CMD", "redis-cli", "ping"]   # PONG = Redis is alive
      interval: 5s
    networks: [app-net]

  # ─── Web (Django) ──────────────────────────────────────────────────
  web:
    build: .
    ports:
      - "8001:8001"      # direct access for Selenium (tests do not go through nginx)
    environment:
      DATABASE_URL:  postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL:     redis://redis:6379/0
      SECRET_KEY:    ${SECRET_KEY}
      DEBUG:         ${DEBUG:-False}
      ALLOWED_HOSTS: ${ALLOWED_HOSTS:-localhost,127.0.0.1}
      NGROK_DOMAIN:  ${NGROK_DOMAIN}
      SEED_DEMO_DATA: ${SEED_DEMO_DATA:-0}
      WEB_HOST:      web         # Selenium uses this name to connect
      SELENIUM_REMOTE_URL: http://selenium:4444/wd/hub
    volumes:
      - staticfiles:/app/staticfiles   # web writes → nginx reads
    depends_on:
      db:    {condition: service_healthy}
      redis: {condition: service_healthy}
    healthcheck:
      test: >
        python -c "import urllib.request;
        urllib.request.urlopen('http://localhost:8001/accounts/login/')"
      interval: 5s
      retries: 12
      start_period: 15s   # first healthcheck after 15 sec (time for migrate)
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
      - "7900:7900"    # VNC (watch the browser live)
    shm_size: '2g'     # Chrome needs shared memory
    networks: [app-net]

# ─── Named volumes ───────────────────────────────────────────────────
volumes:
  postgres_data:    # PostgreSQL data (persists across docker compose down/up)
  staticfiles:      # Django collectstatic output → nginx

# ─── Named network ───────────────────────────────────────────────────
networks:
  app-net:
    driver: bridge
    # Explicit network: "nginx" → nginx IP, "redis" → redis IP
    # Without an explicit network ngrok may fail to find "nginx" → ERR_NGROK_8012
```

---

## Health checks — why they matter

### The problem without health checks

```
WITHOUT health checks:
  docker compose up
  → db starts (but PostgreSQL is still initializing for ~3 sec)
  → web starts (depends_on: db — but only "started", not "healthy")
  → entrypoint.sh: migrate → ERROR: could not connect to server
  → uvicorn does not start
  → nginx does not start (but keeps trying)
  → ngrok cannot reach it → ERR_NGROK_8012

With health checks (condition: service_healthy):
  → db starts → pg_isready → HEALTHY (only then is web allowed to start)
  → web starts → migrate → uvicorn → healthcheck pass → HEALTHY
  → nginx starts → HEALTHY
  → ngrok starts (nginx is already ready)
```

### start_period — explained

```yaml
web:
  healthcheck:
    interval: 5s
    retries: 12
    start_period: 15s
```

```
0s   → container started
0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
       start_period: healthcheck is not counted as a failure during this time
15s  → real checks begin every 5s
75s  → if all 12 attempts (5s × 12 = 60s) failed → UNHEALTHY
       nginx does not start

Without start_period:
  → healthcheck starts immediately
  → migrate takes 8–10s → healthcheck fails
  → after 12 × 5s = 60s → UNHEALTHY
  → nginx tries to start on a broken web → 502
```

### Types of healthcheck tests

```yaml
# PostgreSQL — pg_isready (official utility):
test: ["CMD-SHELL", "pg_isready -U myuser -d mydb"]

# Redis — redis-cli ping:
test: ["CMD", "redis-cli", "ping"]

# Web — HTTP request:
test: >
  python -c "import urllib.request;
  urllib.request.urlopen('http://localhost:8001/accounts/login/')"

# Nginx — curl HTTP:
test: ["CMD-SHELL", "curl -sf http://localhost/accounts/login/ || exit 1"]
# -s: silent (no progress bar), -f: fail on HTTP errors (4xx/5xx)
```

---

## PostgreSQL — from SQLite to a production DB

### Connecting via DATABASE_URL

```python
# notes_project/settings.py
import os
import re

_DATABASE_URL = os.environ.get('DATABASE_URL')
if not _DATABASE_URL:
    raise Exception("DATABASE_URL не встановлено. Запускай через docker compose.")

# Parse the URL manually — dj-database-url is not used in this project
_m = re.match(r'postgres://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', _DATABASE_URL)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME':     _m.group(5),
        'USER':     _m.group(1),
        'PASSWORD': _m.group(2),
        'HOST':     _m.group(3),   # ← Docker DNS: "db" → container IP
        'PORT':     _m.group(4),
        # CONN_MAX_AGE=0: disable persistent connections for async mode.
        # In async, one connection could serve several coroutines → race condition.
        'CONN_MAX_AGE': 0,
    }
}
```

!!! warning "Without DATABASE_URL — an Exception, not SQLite"
    `settings.py` does **not** have a SQLite fallback. If `DATABASE_URL` is not set,
    the app raises an `Exception` right at startup. Always run it through `docker compose`.
    More details → [Troubleshooting](../TROUBLESHOOTING.md)

### Why PostgreSQL and not SQLite

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **File** | A single `db.sqlite3` file | Separate server |
| **Concurrent writes** | Locks the file while writing | Real transactions, MVCC |
| **PostGIS** | — | Geospatial types (GEOMETRY, GEOGRAPHY) |
| **JSON** | Limited support | jsonb with indexes |
| **Production** | Not recommended | Standard |

### Internal DNS in the Docker network

```
docker-compose.yml:
  services:
    db:    ← service name = DNS name
    redis:
    web:
    nginx:

In the app-net network:
  "db"     → db container IP    (postgres)
  "redis"  → redis container IP
  "web"    → web container IP   (uvicorn)
  "nginx"  → nginx container IP

DATABASE_URL: postgres://user:pass@db:5432/notes_db
                                    ↑
                              Docker DNS resolution
```

### Data across restarts

```yaml
volumes:
  postgres_data:    # named volume

services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

```bash
docker compose down        # stops containers, the volume is kept
docker compose up          # postgres_data → data is preserved

docker compose down -v     # -v: removes volumes → DB is wiped
```

---

## Redis — the channel layer in Docker

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
                    "socket_timeout": None,          # ← critical
                    "socket_connect_timeout": 5,
                    "health_check_interval": 30,
                }],
            },
        }
    }
```

Redis in Docker is `redis://redis:6379/0`:
- `redis` — the DNS name of the service in the Docker network
- `6379` — the standard Redis port
- `/0` — database index (Redis supports 16 databases, 0–15)

**More on socket_timeout=None** → [07 — Async](07_async.md#inmemory-vs-redis-channel-layer)

---

## nginx.conf — reverse proxy with WebSocket

```nginx
# nginx/nginx.conf
worker_processes auto;  # automatic — based on the number of CPU cores

events {
    worker_connections 1024;  # max connections per worker
}

http {
    include /etc/nginx/mime.types;  # MIME types for static files

    # ─── WebSocket upgrade map ──────────────────────────────────────
    # Determines the value of the Connection header depending on Upgrade:
    #   Upgrade: websocket → Connection: upgrade
    #   (empty Upgrade) → Connection: close
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ─── Upstream (Django) ──────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — the DNS name of the service
    }

    server {
        listen 80;

        # ─── Static files ───────────────────────────────────────────
        # nginx serves static files directly, Django is not involved
        location /static/ {
            alias /staticfiles/;     # volume with collectstatic output
            expires 7d;
            add_header Cache-Control "public, immutable";
            # immutable: the browser does not check for updates for 7 days
        }

        # ─── Everything else (HTTP + WebSocket) → uvicorn ───────────
        location / {
            proxy_pass http://django;

            # Original headers from the browser → Django
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ─── WebSocket upgrade — REQUIRED ───────────────────────
            proxy_http_version 1.1;
            # ↑ The WebSocket Upgrade handshake requires HTTP/1.1
            #   Without this nginx uses HTTP/1.0 → Upgrade is ignored
            
            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ These headers enable WebSocket at the nginx level

            # Timeout for long-lived connections
            proxy_read_timeout 300s;     # 5 minutes — for idle WS
            proxy_connect_timeout 75s;
        }
    }
}
```

### Without nginx vs with nginx (static files)

```
Without nginx:
  Browser → Django/Uvicorn → reads CSS/JS from disk → returns it
  A Python process is involved for every static file

With nginx:
  Browser → nginx → reads CSS/JS from disk directly → returns it
  Django/Uvicorn is not involved at all

Nginx serves static files 5-10x faster and frees Python workers
to handle real requests.
```

### Why WebSocket needs HTTP/1.1

```
HTTP/1.0: every request = a new connection
HTTP/1.1: keepalive — the connection stays open

WebSocket Upgrade handshake:
  GET /ws/groups/7/chat/ HTTP/1.1  ← 1.1 REQUIRED
  Upgrade: websocket
  Connection: Upgrade

If nginx proxies as HTTP/1.0:
  the Upgrade header is ignored
  → the handshake fails
  → the WS connection is not established
  → the browser receives 400 or 404
```

---

## .env — configuration and secrets

```bash
# .env (NEVER commit to git — already in .gitignore)
# Copy from .env.example: cp .env.example .env

# ─── PostgreSQL ───────────────────────────────────────────────────
POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=change_me_very_strong_password_here

# ─── Django ───────────────────────────────────────────────────────
# Generate: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
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
# Get it at https://dashboard.ngrok.com/authtokens
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
# Reserve it at https://dashboard.ngrok.com/domains
NGROK_DOMAIN=your-subdomain.ngrok-free.app

# ─── Seed ─────────────────────────────────────────────────────────
SEED_DEMO_DATA=1   # 1 = seed demo data at startup
```

### How to generate SECRET_KEY

```bash
# Option 1: via Docker
docker compose run --rm web python -c \
    "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Option 2: locally
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Result: something like
# django-insecure-abc123xyz...   ← "insecure" only in the default key
# x#3k@!mz9...                   ← a properly generated one
```

### How .env gets into the containers

```yaml
# docker-compose.yml automatically reads .env from the current directory
# ${VAR} is substituted from .env:

services:
  db:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}  # ← from .env

  web:
    environment:
      SECRET_KEY: ${SECRET_KEY}                # ← from .env
      NGROK_DOMAIN: ${NGROK_DOMAIN}            # ← from .env
```

---

## CSRF_TRUSTED_ORIGINS — why you get 403 through ngrok

### Symptom

```
Opened https://fawn-natural-mayfly.ngrok-free.app/accounts/login/
You enter your login and click "Увійти"
→ 403 Forbidden: CSRF verification failed. Request aborted.
```

### Cause

```
POST /accounts/login/ HTTP/1.1
Host: fawn-natural-mayfly.ngrok-free.app
Origin: https://fawn-natural-mayfly.ngrok-free.app
X-CSRFToken: abc123...

Django checks the Origin header:
  Is "https://fawn-natural-mayfly.ngrok-free.app" in CSRF_TRUSTED_ORIGINS?
  CSRF_TRUSTED_ORIGINS = []   ← empty → 403
```

### Solution

```python
# notes_project/settings.py
import os

_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
CSRF_TRUSTED_ORIGINS = [f'https://{_ngrok_domain}'] if _ngrok_domain else []

# ALLOWED_HOSTS also needs to be configured:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

```yaml
# docker-compose.yml — pass NGROK_DOMAIN into the web container:
services:
  web:
    environment:
      NGROK_DOMAIN: ${NGROK_DOMAIN}   # ← from .env → settings.py
```

### The value propagation chain

```
.env:
  NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

docker-compose.yml:
  web.environment.NGROK_DOMAIN: ${NGROK_DOMAIN}
  → passes it into the container

settings.py:
  _ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
  CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']
  
Django:
  POST /login/ → Origin check → trusted → 200 OK
```

---

## staticfiles volume — how static files reach nginx

```
Step 1: entrypoint.sh
  python manage.py collectstatic --noinput
  → Collects all static files:
    - notes_app/static/notes_app/css/style.css
    - notes_app/static/notes_app/js/group_chat.js
    - django/contrib/admin/static/admin/...
    - crispy_forms/...
  → Copies them into /app/staticfiles/

Step 2: docker-compose.yml
  web:
    volumes:
      - staticfiles:/app/staticfiles   ← web WRITES here

  nginx:
    volumes:
      - staticfiles:/staticfiles:ro    ← nginx READS from here (read-only)

Step 3: nginx.conf
  location /static/ {
    alias /staticfiles/;   ← serves directly
  }

Result:
  GET /static/notes_app/css/style.css
  → nginx → /staticfiles/notes_app/css/style.css
  → the file is returned directly (Python is not involved)
```

### STATIC_ROOT in settings.py

```python
# settings.py
STATIC_URL = '/static/'

# collectstatic copies all static files here:
STATIC_ROOT = BASE_DIR / 'staticfiles'   # /app/staticfiles

# Where Django looks for static files (besides <app>/static/):
STATICFILES_DIRS = []  # usually empty — Django finds <app>/static/
```

---

## ngrok — public access

### How ngrok works

```
Browser on the Internet → ngrok servers → tunnel → Docker nginx → Django

Without ngrok:
  Django is available only on localhost — nobody else can access it

With ngrok:
  ngrok provides a public URL: https://fawn-natural-mayfly.ngrok-free.app
  All traffic from the Internet → ngrok → your nginx:80
```

### Configuration in Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ creates a tunnel:
  #   Public URL: https://${NGROK_DOMAIN}
  #   Target inside Docker: nginx:80
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

Shows:
  - All HTTP/WS requests in real time
  - Headers (Upgrade, Cookie, X-Forwarded-For)
  - Response status
  - Request/response body
  - CSRF token in the cookie and POST body

Useful for:
  - Debugging CSRF errors
  - Checking WebSocket handshake headers
  - Analyzing traffic from external users
```

### One domain — one connection

```bash
# ❌ Error: ngrok is already running locally + in Docker
ngrok http --url=my-domain.ngrok-free.app 80 &   # locally
docker compose up                                  # ngrok in Docker
# → ERR_NGROK_334: session limit exceeded

# ✅ One way at a time:
# Option A: only via Docker (recommended)
docker compose up -d

# Option B: only locally
ngrok http --url=my-domain.ngrok-free.app 80
```

---

## Selenium — E2E tests in Docker

### Configuration

```yaml
selenium:
  image: selenium/standalone-chrome:latest
  ports:
    - "4444:4444"    # WebDriver API (used by test_selenium.py)
    - "7900:7900"    # VNC (watch the browser: http://localhost:7900)
  shm_size: '2g'     # Chrome needs shared memory
  networks: [app-net]
```

### Why E2E tests run via exec, not run

```bash
# ❌ WRONG — docker compose run:
docker compose run --rm web python manage.py test notes_app.tests.test_selenium
# run creates a NEW container
# The new container does not have the DNS alias "web" in the network
# Selenium tries GET http://web:8001/... → Cannot resolve host

# ✅ CORRECT — docker compose exec:
docker compose up -d   # bring the stack up first
docker compose exec web python manage.py test notes_app.tests.test_selenium
# exec runs INSIDE the already running web container
# the web container is already registered in the Docker network with the alias "web"
# Selenium: GET http://web:8001/ → DNS resolution → web container IP
```

### _DockerLiveServerMixin

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Selenium LiveServerTestCase mixin for Docker Compose.
    
    Problem: LiveServerTestCase binds to 127.0.0.1 by default
    In Docker: 127.0.0.1 is not reachable from other containers.
    
    Solution: bind to 0.0.0.0 (all interfaces).
    WEB_HOST: env variable → Selenium uses "web" (DNS name) to connect.
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
        Fast login via the session cookie (without the form).
        Bypasses the login form → tests are faster.
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

  # ─── Job 1: Unit + Integration + Consumer tests ──────────────────
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

  # ─── Job 2: Selenium E2E tests ───────────────────────────────────
  selenium-e2e:
    runs-on: ubuntu-latest
    needs: test   # runs only after the test job succeeds

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

## Running the full stack

### First run

```bash
# 1. Copy and fill in .env:
cp .env.example .env
# Edit it in any editor:
#   SECRET_KEY   — generate it (instructions above)
#   NGROK_AUTHTOKEN — from https://dashboard.ngrok.com/authtokens
#   NGROK_DOMAIN — from https://dashboard.ngrok.com/domains

# 2. Start the stack:
docker compose up --build
# --build: rebuilds the image (needed when Dockerfile or requirements.txt changes)

# 3. View the logs:
# (in a separate terminal)
docker compose logs -f web    # Django/Uvicorn logs
docker compose logs -f nginx  # nginx access log
docker compose logs -f ngrok  # tunnel status
```

### Expected output of docker compose up

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

### Access after startup

```bash
# Local:
open http://localhost          # via nginx
open http://localhost:4040     # ngrok dashboard

# Public (via ngrok):
open https://your-domain.ngrok-free.app

# Demo accounts (password: demo1234):
# demo_alice, demo_bob, demo_carol
```

### Stopping and cleanup

```bash
docker compose down           # stops, keeps volumes (DB)
docker compose down -v        # stops + removes volumes (resets the DB)
docker compose down --rmi all # stops + removes images
docker compose restart web    # restart only the web service
```

---

## Useful commands

```bash
# ─── Status ──────────────────────────────────────────────────────────
docker compose ps                    # status of all services
docker compose top                   # processes in containers

# ─── Logs ─────────────────────────────────────────────────────────────
docker compose logs web              # all web logs
docker compose logs -f web           # follow in real time
docker compose logs --tail=50 web    # last 50 lines

# ─── Shell in a container ─────────────────────────────────────────────
docker compose exec web bash                    # shell in web
docker compose exec web python manage.py shell  # Django shell
docker compose exec web python manage.py check --deploy  # production audit
docker compose exec db psql -U notes_user notes_db       # PostgreSQL shell

# ─── Django commands ──────────────────────────────────────────────────
docker compose exec web python manage.py showmigrations
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py seed_demo_data --reset

# ─── Network debugging ────────────────────────────────────────────────
docker network ls
docker network inspect notes_chat_app_app-net
docker compose exec nginx curl -I http://web:8001/accounts/login/
docker compose exec web ping db    # check DNS between containers

# ─── Rebuild ──────────────────────────────────────────────────────────
docker compose up --build          # rebuild the image
docker compose build --no-cache web # without cache (after changing pip dependencies)
```

---

## Production checklist

### Required before production

- [ ] `SECRET_KEY` — unique, at least 50 characters, not "django-insecure-..."
- [ ] `DEBUG = False` — never `True` in production
- [ ] `ALLOWED_HOSTS` — specific domains, not `['*']`
- [ ] `CSRF_TRUSTED_ORIGINS` — includes your domain
- [ ] `DATABASE_URL` — PostgreSQL with a strong password (not `notes_password`)
- [ ] `REDIS_URL` — Redis for the channel layer (InMemory does not scale)
- [ ] `.env` in `.gitignore` — never commit credentials
- [ ] `entrypoint.sh` — remove `--reload` from Uvicorn
- [ ] `SEED_DEMO_DATA` — not set, or remove `--force`

### For HTTPS

```python
# settings.py — uncomment when you have an SSL certificate:
SESSION_COOKIE_SECURE = True    # cookie only over HTTPS
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True      # HTTP → HTTPS redirect
SECURE_HSTS_SECONDS = 31536000  # the browser remembers HTTPS for 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
```

### Nginx in production (with SSL)

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

# Shows what needs to be configured for production:
# WARNINGS:
# ?: (security.W004) You have not set SECURE_HSTS_SECONDS
# ?: (security.W008) Your SECRET_KEY has less than 50 characters
# ?: (security.W012) SESSION_COOKIE_SECURE is not set to True
# ...
```

---

## Common mistakes

| Error | Cause | Fix |
|---------|---------|-------------|
| `ERR_NGROK_8012: no such host nginx` | ngrok and nginx are not on the same network | Explicit `app-net` network |
| `403 CSRF verification failed` | the ngrok domain is not in `CSRF_TRUSTED_ORIGINS` | Add it in settings.py + pass NGROK_DOMAIN into web |
| `403 WebSocket` | the ngrok domain is not in `ALLOWED_HOSTS` | Add the domain to ALLOWED_HOSTS |
| `ERR_NGROK_334: session limit` | ngrok is running both locally and in Docker | Stop one of them |
| Static files 404 | `collectstatic` was not run or the volume is not mounted | Check entrypoint.sh and volumes |
| `web` unhealthy → nginx does not start | Migrate fails or uvicorn does not start | `docker compose logs web` |
| WS connection does not open through nginx | Missing `proxy_http_version 1.1` or Upgrade headers | Add them to nginx.conf |
| `TimeoutError reading from redis` | `socket_timeout=5` in RedisChannelLayer | `"socket_timeout": None` in settings.py |
| `CommandError: Demo data seeding disabled` | `seed_demo_data` without `--force` when `DEBUG=False` | `seed_demo_data --force` in entrypoint.sh |
| `SynchronousOnlyOperation` in a consumer | sync ORM in an async context | `@database_sync_to_async` |
| Data disappeared after `docker compose down` | `down -v` was used | Back up before `down -v` |

---

## Practical exercise

**Exercise 1 — first run:**
```bash
docker compose up --build
docker compose logs -f web
# Find the lines:
#   "Applying migrations"
#   "128 static files copied"
#   "Uvicorn running on http://0.0.0.0:8001"
```

**Exercise 2 — ngrok dashboard:**
```bash
# Open http://localhost:4040
# Go to https://your-domain.ngrok-free.app/accounts/login/
# Inspect the request in the dashboard:
#   - Headers from the browser
#   - Which headers ngrok adds (X-Forwarded-For, etc.)
#   - CSRF token in the cookie
```

**Exercise 3 — production check:**
```bash
docker compose exec web python manage.py check --deploy
# What does Django recommend for production?
# How many warnings?
```

**Exercise 4 — nginx WebSocket:**
```bash
# Find the WebSocket block in nginx.conf (proxy_http_version 1.1)
# Comment out the line: # proxy_http_version 1.1;
docker compose restart nginx
# Try opening the chat — what happened?
# Put the line back:
docker compose restart nginx
```

**Exercise 5 — static files:**
```bash
# Go inside the web container:
docker compose exec web bash

# Inspect the collected static files:
ls /app/staticfiles/
ls /app/staticfiles/notes_app/

# Run collectstatic manually:
python manage.py collectstatic --noinput

# Exit:
exit
```

**Exercise 6 — PostgreSQL directly:**
```bash
docker compose exec db psql -U notes_user notes_db

# List the tables:
\dt

# Look at the users:
SELECT id, username, email FROM auth_user;

# Exit:
\q
```

---

## Self-check checklist

- [ ] `.env` is filled in (copied from `.env.example`)
- [ ] `NGROK_AUTHTOKEN` and `NGROK_DOMAIN` are set
- [ ] `docker compose up --build` finishes without errors
- [ ] `http://localhost` opens and shows the site (nginx)
- [ ] `http://localhost:4040` opens (ngrok dashboard)
- [ ] Login via the ngrok URL (`https://...ngrok-free.app`) — without 403
- [ ] Group chat (WebSocket) via ngrok — messages go through
- [ ] `docker compose logs nginx` shows the access log
- [ ] `docker compose exec web python manage.py check --deploy` — reviewed
- [ ] Unit tests: `docker compose run --rm web python manage.py test notes_app.tests.test_models notes_app.tests.test_services notes_app.tests.test_consumers`

---

## Congratulations!

You have gone all the way from your first Django view to a production-ready deployment:

```
01 → First Django view (URL → View → Template)
02 → First model (ORM, forms, PRG)
03 → CRUD and business logic (selectors/services, N+1, transactions)
04 → Templates and Bootstrap (3-level inheritance, Crispy Forms)
05 → Authentication (login, register, UserProfile, decorators)
06 → Testing (test pyramid, TestCase, WebsocketCommunicator, Selenium)
07 → Async and WebSocket (ASGI, Channels, Consumer, channel layer)
08 → Deployment (Docker Compose, nginx, ngrok, production checklist)
```

Documentation modules:
- [Deployment](../11_deployment/README.md)
- [Final Project](../12_final_project/README.md)
