# Docker Compose

> **Key concept:** health checks and `depends_on: condition: service_healthy`
> guarantee that each service waits for the previous one to be ready before starting.

---

## Full dependency diagram

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

---

## docker-compose.yml — a detailed walkthrough

```yaml
services:

  # ─── PostgreSQL ──────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine     # minimal image (alpine = ~80 MB)
    volumes:
      - postgres_data:/var/lib/postgresql/data  # data persists across restarts
    environment:
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      # pg_isready: a PostgreSQL utility — checks whether the server accepts connections
      interval: 5s      # check every 5 seconds
      retries: 5         # consider "healthy" after 5 successful checks
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
      - "8001:8001"      # direct access for Selenium (tests do not go through nginx)
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
      start_period: 15s   # first health check 15 seconds after startup
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
    # ↑ tunnel from the public URL to nginx inside the Docker network
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
  postgres_data:    # PostgreSQL data (persists across docker compose down/up)
  staticfiles:      # Django collectstatic output (web → nginx)

# ─── Named network ───────────────────────────────────────────────────────
networks:
  app-net:
    driver: bridge
    # An explicit network guarantees DNS resolution between containers:
    # "nginx" → IP of the nginx container, "redis" → IP of the redis container, etc.
    # Without an explicit network ngrok may not find "nginx" → ERR_NGROK_8012
```

---

## Why `start_period` matters in a healthcheck

```
start_period: 15s  for web:

  0s   → the container has started
  0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
         The healthcheck is not counted! (not considered a failure)
  15s  → real checks start every 5s
  75s  → if all 12 attempts failed → the service is "unhealthy"
         nginx does not start (depends_on: service_healthy)

Without start_period: the healthcheck counts 12 attempts from the very first second.
If migrate takes 10s → nginx tries to start → 503 → ngrok cannot reach it.
```

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

WITH health checks (condition: service_healthy):
  → db starts → pg_isready → HEALTHY (only then is web allowed to start)
  → web starts → migrate → uvicorn → healthcheck pass → HEALTHY
  → nginx starts → HEALTHY
  → ngrok starts (nginx is already ready)
```

### Types of healthcheck tests

```yaml
# PostgreSQL — pg_isready (the official utility):
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

## Named volumes and named network

### Named volumes

```yaml
volumes:
  postgres_data:    # PostgreSQL data
  staticfiles:      # Django collectstatic output
```

```bash
docker compose down        # stops the containers, volumes are kept
docker compose up          # postgres_data → data is preserved

docker compose down -v     # -v: removes volumes → DB and staticfiles are wiped
```

`postgres_data` is mounted into the `db` container at `/var/lib/postgresql/data` — the standard location of PostgreSQL data. On `docker compose down` without `-v`, this data stays on disk and is picked up again on the next `up`.

`staticfiles` is a volume shared between `web` (which writes to it during `collectstatic`) and `nginx` (which reads it with `:ro`). This is exactly the mechanism that lets nginx serve CSS, JS and images without involving Django.

### Named network

```yaml
networks:
  app-net:
    driver: bridge
```

The explicit Docker network `app-net` provides DNS resolution by service name: `"db"` → IP of the PostgreSQL container, `"redis"` → IP of the Redis container, `"nginx"` → IP of the nginx container, and so on.

Without an explicit named network, ngrok cannot find nginx by its DNS name → `ERR_NGROK_8012`.

---

## Dockerfile — the Django image

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app

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
| `DJANGO_SETTINGS_MODULE` | Tells Django which `settings.py` to use |
| `PYTHONPATH=/app` | Python looks for modules in `/app` |

### Why `requirements.txt` is copied BEFORE the code

```
Layer 1: FROM python:3.12-slim         ← cached (rarely changes)
Layer 2: COPY requirements.txt .       ← cached if requirements.txt has not changed
Layer 3: RUN pip install ...           ← cached together with layer 2
Layer 4: COPY . .                      ← ALWAYS rebuilt (code changes often)
Layer 5: CMD [...]                     ← lightweight

If you copy all the code BEFORE pip install:
  → every code change → pip install again → long rebuild (~2-3 min)

With the split shown above:
  → on a code change → only COPY . . → fast (~10 sec)
```

---

## Expected output on startup

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

---

## In the book

- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker, Docker Compose, images, containers, volumes, networks, healthchecks
- [Part XI. Deployment](../../11_deployment/README.md) — the production stack, Dockerfile best practices, multi-service orchestration

---

## Official documentation

- [Docker Compose: Reference](https://docs.docker.com/reference/compose-file/) — the full docker-compose.yml specification
- [Docker Compose: depends_on](https://docs.docker.com/reference/compose-file/services/#depends_on) — `condition: service_healthy`, `service_started`
- [Docker Compose: healthcheck](https://docs.docker.com/reference/compose-file/services/#healthcheck) — `test`, `interval`, `retries`, `start_period`
- [Docker: Named volumes](https://docs.docker.com/engine/storage/volumes/) — data persistence across restarts
- [Docker: Networking](https://docs.docker.com/engine/network/bridge/) — bridge networks, DNS resolution between containers
- [Dockerfile: Best practices](https://docs.docker.com/build/building/best-practices/) — layer caching, COPY order, ENV
