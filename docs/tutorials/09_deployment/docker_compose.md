# Docker Compose

> **Ключова концепція:** health checks і `depends_on: condition: service_healthy`
> гарантують що кожен сервіс чекає готовності попереднього перед стартом.

---

## Повна схема залежностей

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

---

## docker-compose.yml — детальний розбір

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

---

## Чому важливий `start_period` у healthcheck

```
start_period: 15s  для web:

  0s   → контейнер стартував
  0–15s → entrypoint.sh: migrate + collectstatic + seed_demo_data
         Healthcheck не враховується! (не вважається failure)
  15s  → починаються реальні перевірки кожні 5s
  75s  → якщо всі 12 спроб провалились → сервіс "unhealthy"
         nginx не стартує (depends_on: service_healthy)

Без start_period: healthcheck рахує 12 спроб з першої секунди.
Якщо migrate займає 10с → nginx намагається стартувати → 503 → ngrok не може достукатись.
```

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

## Named volumes і named network

### Named volumes

```yaml
volumes:
  postgres_data:    # PostgreSQL дані
  staticfiles:      # Django collectstatic output
```

```bash
docker compose down        # зупиняє контейнери, volumes зберігаються
docker compose up          # postgres_data → дані збережені

docker compose down -v     # -v: видаляє volumes → БД і staticfiles очищені
```

`postgres_data` монтується у `db` контейнер за шляхом `/var/lib/postgresql/data` — стандартне розташування даних PostgreSQL. При `docker compose down` без `-v` ці дані залишаються на диску і підхоплюються при наступному `up`.

`staticfiles` — спільний том між `web` (пише при `collectstatic`) і `nginx` (читає з `:ro`). Саме через цей механізм nginx роздає CSS, JS та зображення без участі Django.

### Named network

```yaml
networks:
  app-net:
    driver: bridge
```

Явна Docker мережа `app-net` забезпечує DNS резолюцію за іменами сервісів: `"db"` → IP контейнера PostgreSQL, `"redis"` → IP контейнера Redis, `"nginx"` → IP контейнера nginx тощо.

Без явної named network ngrok не знаходить nginx за DNS ім'ям → `ERR_NGROK_8012`.

---

## Dockerfile — образ Django

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app

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
| `DJANGO_SETTINGS_MODULE` | Django знає який `settings.py` використовувати |
| `PYTHONPATH=/app` | Python шукає модулі у `/app` |

### Чому `requirements.txt` копіюється ПЕРЕД кодом

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

## Очікуваний вивід при запуску

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

## У книзі

- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker, Docker Compose, образи, контейнери, volumes, networks, healthchecks
- [Частина XI. Deployment](../../11_deployment/README.md) — production стек, Dockerfile best practices, multi-service orchestration

---

## Офіційна документація

- [Docker Compose: Reference](https://docs.docker.com/reference/compose-file/) — повна специфікація docker-compose.yml
- [Docker Compose: depends_on](https://docs.docker.com/reference/compose-file/services/#depends_on) — `condition: service_healthy`, `service_started`
- [Docker Compose: healthcheck](https://docs.docker.com/reference/compose-file/services/#healthcheck) — `test`, `interval`, `retries`, `start_period`
- [Docker: Named volumes](https://docs.docker.com/engine/storage/volumes/) — data persistence між restartами
- [Docker: Networking](https://docs.docker.com/engine/network/bridge/) — bridge networks, DNS резолюція між контейнерами
- [Dockerfile: Best practices](https://docs.docker.com/build/building/best-practices/) — layer caching, COPY order, ENV
