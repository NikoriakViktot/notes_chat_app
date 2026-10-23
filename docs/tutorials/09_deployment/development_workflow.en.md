# Development Workflow

> A practical guide to day-to-day work with the `notes_chat_app` production stack.
> This section contains unique content: real workflows, debug tips and useful commands.

---

## Typical workflow: first run

```bash
# 1. Copy the configuration:
cp .env.example .env

# 2. Edit .env:
#   - SECRET_KEY  — generate it (instructions below)
#   - NGROK_AUTHTOKEN — from https://dashboard.ngrok.com/authtokens
#   - NGROK_DOMAIN — from https://dashboard.ngrok.com/domains
#   - SEED_DEMO_DATA=1 — to have demo data right away

# 3. Build and start:
docker compose up --build
# --build: rebuilds the image (needed on the first run or after changing Dockerfile/requirements)

# 4. Make sure everything is up:
docker compose ps

# 5. Open the application:
# http://localhost — through nginx (login: demo_alice / demo1234)
# http://localhost:4040 — ngrok dashboard
```

### Expected output

```
db-1       | database system is ready to accept connections
redis-1    | Ready to accept connections
web-1      |   Applying notes_app.0001_initial... OK
web-1      | 128 static files copied to '/app/staticfiles'
web-1      | Seeding demo data...
web-1      | INFO:     Uvicorn running on http://0.0.0.0:8001
nginx-1    | Starting nginx
ngrok-1    | started tunnel session ... url=https://your-domain.ngrok-free.app
```

---

## Day-to-day development

```bash
# Start the stack (no rebuild if the Dockerfile hasn't changed):
docker compose up

# Follow Django logs in real time:
docker compose logs -f web

# Follow nginx logs:
docker compose logs -f nginx
```

---

## After changing `requirements.txt` or `Dockerfile`

```bash
# Rebuild the web container:
docker compose up --build

# Without cache (after changing pip dependencies that may have been cached):
docker compose build --no-cache web
docker compose up
```

---

## Changing Python code — uvicorn `--reload`

`uvicorn` is started with `--reload` in `entrypoint.sh`. When any `.py` file changes, uvicorn restarts automatically:

```bash
# Log on auto-restart:
web-1  | WARNING:  Detected file change in 'notes_app/views.py'. Reloading...
web-1  | INFO:     Started server process [1]
web-1  | INFO:     Application startup complete.
```

For templates (`.html`) and static files (`.css`, `.js`) — reload the browser manually.

---

## A new migration

```bash
# 1. Changed models.py → create a migration:
docker compose exec web python manage.py makemigrations

# 2. Apply the migration:
docker compose exec web python manage.py migrate

# 3. Check the state:
docker compose exec web python manage.py showmigrations
# All migrations should have [X]
```

---

## Django shell

```bash
docker compose exec web python manage.py shell

# Examples in the shell:
>>> from notes_app.models import Note, User
>>> User.objects.count()
4
>>> Note.objects.filter(user__username='demo_alice').count()
8
>>> from notes_app import selectors
>>> selectors.get_user_tags(User.objects.get(username='demo_alice'))
<QuerySet [<Tag: django>, <Tag: python>, <Tag: ідеї>]>
```

---

## Stopping

```bash
docker compose down           # stop (data in volumes is kept)
docker compose down -v        # stop + delete volumes (resets the DB!)
docker compose down --rmi all # stop + delete images
docker compose restart web    # restart only the web service
```

---

## Debug tips

```bash
# Status of all containers:
docker compose ps

# View detailed state and health:
docker compose ps -a

# Open a shell in the web container:
docker compose exec web bash

# View environment variables in the container:
docker compose exec web env | grep -E 'DEBUG|SECRET|REDIS|DATABASE|NGROK'

# Inspect the network:
docker network inspect notes_chat_app_app-net

# Test connectivity between containers:
docker compose exec web ping db
docker compose exec web ping redis
docker compose exec nginx curl -I http://web:8001/accounts/login/

# Production readiness check:
docker compose exec web python manage.py check --deploy
```

---

## Useful commands: Django management

```bash
docker compose exec web python manage.py check --deploy    # production readiness check
docker compose exec web python manage.py showmigrations     # migration state
docker compose exec web python manage.py createsuperuser    # admin access
docker compose exec web python manage.py dbshell           # psql into PostgreSQL
docker compose exec web python manage.py collectstatic     # collect static manually
docker compose exec web python manage.py seed_demo_data --reset  # reset demo data
```

---

## Useful commands: PostgreSQL

```bash
# Connect to PostgreSQL directly:
docker compose exec db psql -U notes_user -d notes_db

# Commands in psql:
\dt          # list tables
\d note      # schema of the note table
SELECT id, username, email FROM auth_user;
SELECT count(*) FROM notes_app_note;
\q           # quit
```

---

## Useful commands: Redis

```bash
# Connect to Redis directly:
docker compose exec redis redis-cli

# Commands in redis-cli:
KEYS *            # all keys (careful on large DBs!)
TYPE channels:*   # key type
TTL channels:*    # key TTL
MONITOR           # live stream of all commands (Ctrl+C to stop)
```

---

## Useful commands: nginx

```bash
# Check the nginx config:
docker compose exec nginx nginx -t

# Restart nginx (after changing nginx.conf):
docker compose restart nginx

# Test the upstream from inside the nginx container:
docker compose exec nginx curl -I http://web:8001/accounts/login/
```

---

## Reading nginx logs

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          Client IP     Time                            Method+URL    Status  Bytes

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (browser cache)

nginx-1  | "POST /accounts/login/ HTTP/1.1" 302 0
                                              ↑ 302 = Redirect after a successful login
```

---

## Access after startup

```bash
# Local:
http://localhost          # through nginx
http://localhost:8001     # directly to uvicorn (for Selenium tests)
http://localhost:4040     # ngrok dashboard
http://localhost:7900     # VNC (watch the Selenium Chrome browser live)

# Public (through ngrok):
https://your-domain.ngrok-free.app

# Demo accounts (password: demo1234):
# demo_alice, demo_bob, demo_carol
```

---

## In the book

- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker Compose commands, logs, debugging containers, docker exec, docker logs
- [Part XI. Deployment](../../11_deployment/README.md) — development vs production workflow, environment management

---

## Official documentation

- [Docker Compose: CLI reference](https://docs.docker.com/reference/cli/docker/compose/) — up, down, exec, run, logs, ps, restart
- [Docker: docker logs](https://docs.docker.com/reference/cli/docker/container/logs/) — `--since`, `--follow`, `--tail`
- [Django: Management commands](https://docs.djangoproject.com/en/5.2/ref/django-admin/) — check, showmigrations, makemigrations, migrate, shell, dbshell
