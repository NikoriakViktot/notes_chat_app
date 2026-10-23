# PostgreSQL

> **Key difference from SQLite:** PostgreSQL is a separate service on the network.
> Django connects through `DATABASE_URL` (we parse the connection string in `settings.py`).

---

## How Django connects to PostgreSQL

```python
# notes_project/settings.py
import os
import re

_DATABASE_URL = os.environ.get('DATABASE_URL')
if not _DATABASE_URL:
    raise Exception("DATABASE_URL не встановлено. Запускай через docker compose.")

# Parse the URL manually
_m = re.match(r'postgres://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', _DATABASE_URL)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME':     _m.group(5),
        'USER':     _m.group(1),
        'PASSWORD': _m.group(2),
        'HOST':     _m.group(3),   # ← Docker DNS: "db" → container IP
        'PORT':     _m.group(4),
        'CONN_MAX_AGE': 0,
    }
}
```

!!! warning "Without DATABASE_URL — an Exception, not SQLite"
    `settings.py` has **no** SQLite fallback. If `DATABASE_URL` is not set,
    the application raises an `Exception` immediately on startup. Always run it through `docker compose`.

`DATABASE_URL` in `docker-compose.yml` looks like this:

```yaml
web:
  environment:
    DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
    #                                                               ↑
    #                                          "db" — the service's DNS name in the Docker network app-net
```

### Internal DNS in the Docker network

```
docker-compose.yml:
  services:
    db:    ← service name = DNS name
    redis:
    web:
    nginx:

In the app-net network:
  "db"     → IP of the db container    (postgres)
  "redis"  → IP of the redis container
  "web"    → IP of the web container   (uvicorn)
  "nginx"  → IP of the nginx container

DATABASE_URL: postgres://user:pass@db:5432/notes_db
                                    ↑
                              Docker DNS resolution
```

---

## Why not SQLite in production

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **Concurrent writes** | One writer, file locking | MVCC — thousands of writers |
| **WebSocket + ORM** | Conflicts with concurrent WS | No conflicts |
| **Transactions** | Limited | Full ACID + SERIALIZABLE |
| **Indexing** | Basic | GIN, GiST, partial indexes |
| **Scale** | ~100K rows comfortably | Billions of rows |
| **Docker** | A file inside the container (gets lost!) | Separate service + volume |

**The critical SQLite problem in Docker:**

```
Without a named volume:
  docker compose down → container is removed → db.sqlite3 is removed
  docker compose up   → new DB → all data is lost!

With PostgreSQL + named volume:
  docker compose down → container is removed → the postgres_data volume remains
  docker compose up   → PostgreSQL attaches to the volume → data is preserved
```

---

## Migrations in Docker

Migrations run **automatically** on every `docker compose up` through `entrypoint.sh`:

```sh
python manage.py migrate --noinput
```

Other useful commands:

```bash
# Manually (if you need to apply them without restarting):
docker compose exec web python manage.py migrate

# Check the migration state:
docker compose exec web python manage.py showmigrations

# Create a new migration (after changing models.py):
docker compose exec web python manage.py makemigrations

# Connect to PostgreSQL directly:
docker compose exec db psql -U notes_user -d notes_db

# View the tables:
\dt
\d notes_app_note    # schema of a specific table
\q                   # quit
```

---

## CONN_MAX_AGE — persistent connections

```python
# settings.py
DATABASES = {
    'default': {
        ...,
        'CONN_MAX_AGE': 0,  # async-compatible: 0 = new connections every time
    }
}
```

**Why `CONN_MAX_AGE = 0` for ASGI:**

`CONN_MAX_AGE > 0` enables persistent connections through thread-local storage. In synchronous WSGI Django, each request is handled in its own thread, so a persistent connection is safe. In asynchronous Uvicorn, one thread serves several coroutines at the same time. If a persistent connection is shared between coroutines → a race condition at the DB connection level.

```
CONN_MAX_AGE = 60  (bad for ASGI):
  coroutine A → got a connection from the pool
  coroutine B → tries to use the same connection
  → Unpredictable errors or race conditions

CONN_MAX_AGE = 0  (correct for ASGI):
  coroutine A → opens a new connection → query → closes it
  coroutine B → opens a new connection → query → closes it
  → Isolated connections, no conflicts
```

The Django documentation recommends `CONN_MAX_AGE = 0` when using an ASGI server.

---

## Data across restarts

```bash
docker compose down        # stops the containers, the volume is kept
docker compose up          # postgres_data → data is preserved

docker compose down -v     # -v: removes volumes → the DB is wiped
```

```yaml
# docker-compose.yml
volumes:
  postgres_data:    # named volume

services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

!!! danger "`docker compose down -v`"
    The `-v` flag removes all named volumes, including `postgres_data`.
    **All data in the DB will be destroyed.** Use it only when you want a full reset.

---

## In the book

- [Part III. Database and ORM](../../03_database_and_orm/README.md) — Django ORM, QuerySet, migrations, transactions, PostgreSQL-specific features
- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker volumes, networks, named volumes vs bind mounts

---

## Official documentation

- [Django: Databases](https://docs.djangoproject.com/en/5.2/ref/databases/) — PostgreSQL-specific settings, `CONN_MAX_AGE`
- [Django: DATABASE_URL patterns](https://docs.djangoproject.com/en/5.2/ref/settings/#databases) — connection string format
- [PostgreSQL: Connection strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING) — URL format
- [PostgreSQL: pg_isready](https://www.postgresql.org/docs/current/app-pg-isready.html) — health check utility
- [Docker: Named volumes](https://docs.docker.com/engine/storage/volumes/) — when to use named vs anonymous volumes
