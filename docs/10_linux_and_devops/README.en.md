# Part X. Linux, DevOps and Deployment

An application that runs only on a developer's laptop is not production. This part covers Linux basics, Docker, Docker Compose, Nginx and CI.

**Prerequisites:** a general understanding of the project.
**Level:** Intermediate → Production.

---

## Sections

### Linux

| Document | What we will learn |
|----------|-----------|
| [The Linux mental model](linux_01_mental_model_full.md) | kernel, userspace, files as an abstraction, PID, fd |
| [Terminal and shell](linux_02_terminal_and_shell_full.md) | bash, zsh, stdin/stdout/stderr, pipes, `>` `>>`, `$?` |
| [The file system](linux_03_filesystem_navigation_full.md) | FHS, `ls`, `find`, `tree`, `pwd`, `cd`, symlinks |
| [Files and permissions](linux_04_files_permissions_users_full.md) | `chmod`, `chown`, `umask`, `sudo`, users/groups |
| [Processes and ports](linux_05_processes_ports_services_full.md) | `ps`, `top`, `kill`, `lsof`, `netstat`, `ss`, `systemctl` |
| [Package managers](linux_06_package_managers_and_software_full.md) | `apt`, `pip`, `pyenv`, `nvm` |
| [SSH and servers](linux_07_ssh_and_remote_server_full.md) | `ssh`, `scp`, `rsync`, `authorized_keys`, jump host |
| [Environment variables](linux_08_environment_variables_and_secrets_full.md) | `export`, `.env`, `os.environ`, secrets management |
| [Bash scripts](linux_09_bash_scripts_full.md) | shebang, variables, conditions, loops, functions, exit codes |
| [Makefile](linux_10_makefile_basics_full.md) | targets, phony, `make test`, `make build` |

### Docker

| Document | What we will learn |
|----------|-----------|
| [Docker and Runtime](docker_and_runtime.md) | image, container, layer cache, volumes, networks |
| [Docker: the complete guide](docker_guide.md) | `Dockerfile`, `build`, `run`, `exec`, `logs`, compose integration |

### Deployment

| Document | What we will learn |
|----------|-----------|
| [Django on Linux](../11_deployment/deploy_11_django_on_linux_full.md) | virtualenv, `gunicorn`, `systemd` service, `collectstatic` |
| [Nginx + Gunicorn/Uvicorn](../11_deployment/deploy_12_nginx_gunicorn_uvicorn_full.md) | `proxy_pass`, WebSocket upgrade, SSL, static files |
| [Logs and monitoring](../11_deployment/deploy_13_logs_monitoring_debugging_full.md) | `journalctl`, `docker logs`, `LOGGING` in Django |
| [Docker basics](../11_deployment/deploy_14_docker_basics_full.md) | image layers, registry, `ENTRYPOINT`, multi-stage |
| [Docker Compose](../11_deployment/deploy_15_docker_compose_full.md) | services, volumes, networks, health checks, depends_on |
| [DevOps workflow](../11_deployment/deploy_16_devops_workflow_full.md) | CI/CD pipeline, blue-green deploy, rollback |
| [Kubernetes overview](../11_deployment/deploy_17_kubernetes_overview_full.md) | Pod, Deployment, Service, Ingress — conceptually |
| [Roadmap](../11_deployment/deploy_18_roadmap_next_steps_full.md) | what to learn next after the course |

---

## Key concepts

**The Notes Chat App Docker Compose stack:**

```yaml
# docker-compose.yml (simplified)
services:
  db:
    image: postgres:16-alpine
    volumes: [postgres_data:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

  web:
    build: .
    command: ["sh", "./entrypoint.sh"]
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/notes
      REDIS_URL: redis://redis:6379/0
    depends_on: [db, redis]
    ports: ["8001:8001"]

  nginx:
    image: nginx:1.27-alpine
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - staticfiles:/staticfiles:ro
    ports: ["80:80"]
    depends_on: [web]

  celery-worker:
    build: .
    command: ["celery", "-A", "notes_project", "worker", "--loglevel=info"]
    depends_on: [db, redis]

  celery-beat:
    build: .
    command: ["celery", "-A", "notes_project", "beat", "--loglevel=info"]
    depends_on: [db, redis]

  selenium:                  # profiles: ["test"]
    image: selenium/standalone-chrome
    ports: ["4444:4444"]

  selenium-tests:            # profiles: ["test"]
    build: .
    command: ["python", "manage.py", "test", "notes_app.tests.test_selenium", "-v", "2"]
    depends_on: [web, nginx, selenium]

volumes:
  postgres_data:
  redis_data:
  staticfiles:
  celerybeat_data:
```

**entrypoint.sh — startup sequence:**

```bash
#!/bin/sh
set -eu

# 1. PostgreSQL and Redis are already healthy: depends_on + healthcheck in docker-compose.yml guarantee it

# 2. Apply migrations
if [ "${RUN_MIGRATIONS:-1}" = "1" ]; then
    python manage.py migrate --noinput
fi

# 3. Collect static files
if [ "${RUN_COLLECTSTATIC:-1}" = "1" ]; then
    python manage.py collectstatic --noinput
fi

# 4. Seed demo data (if SEED_DEMO_DATA=1)
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    python manage.py seed_demo_data ${seed_args}   # --force or --force --reset
fi

# 5. Start the Uvicorn ASGI server (with --reload in dev)
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --proxy-headers
```

**Nginx configuration for WebSocket:**

```nginx
# nginx/nginx.conf
upstream django {
    server web:8001;
}

server {
    listen 80;

    location / {
        proxy_pass http://django;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket upgrade
    location /ws/ {
        proxy_pass http://django;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;   # ← required for WS
        proxy_set_header Connection "upgrade";
    }

    # Static files — Nginx serves them directly (not Django)
    location /static/ {
        alias /staticfiles/;
    }
}
```

**Environment variables — secrets:**

```bash
# .env (never commit it to git)
SECRET_KEY=django-prod-secret-key-here
DATABASE_URL=postgres://user:pass@db:5432/notes
REDIS_URL=redis://redis:6379/0
DEBUG=False
ALLOWED_HOSTS=notes.example.com,www.notes.example.com

# In Python (the production approach):
import os
SECRET_KEY = os.environ['SECRET_KEY']   # ← Exception if missing (no default!)
# The teaching project currently uses os.environ.get("SECRET_KEY", "django-insecure-...")
# with a dev default — remove that default in production.
```

**Production checklist:**

```text
✓ DEBUG=False
✓ SECRET_KEY — from env, not in the code
✓ DATABASE_URL — missing → Exception (no SQLite fallback!)
✓ ALLOWED_HOSTS — specific domains
✓ HTTPS — CSRF_TRUSTED_ORIGINS, SESSION_COOKIE_SECURE
✓ Static files — Nginx, not Django
✓ DebugExceptionMiddleware — only if DEBUG
✓ Logrotate / log aggregation
✓ Health check endpoint
✓ CI: tests green before deploying
```

---

## Where this is in Notes Chat App

| File | What it shows |
|------|-----------|
| `docker-compose.yml` | the full stack: db, redis, web, nginx, celery-worker, celery-beat, selenium, selenium-tests, ngrok |
| `Dockerfile` | single-stage build: `FROM python:3.12-slim` |
| `entrypoint.sh` | startup: migrate → collectstatic → seed_demo_data → uvicorn |
| `nginx/nginx.conf` | proxy_pass, WebSocket upgrade, static alias |
| `.github/workflows/django-tests.yml` | GitHub Actions CI |
| `notes_project/settings.py` | `SECRET_KEY = os.environ.get("SECRET_KEY", ...)`, `DATABASE_URL` parsing |

---

## Teaching connection

```text
Linux basics → Docker → Docker Compose → Nginx → GitHub Actions CI
Part X covers the entire Notes Chat App deployment stack (Step 8 of Zero to Hero)
```

**Zero to Hero:** Step 8 — Docker Compose, Nginx, GitHub Actions.

---

## Practice

1. Run `docker compose ps` — review the state of all services.
2. Run `docker compose logs web --tail=50` — find the startup sequence.
3. Run `docker compose exec web python manage.py shell` → `from django.conf import settings; print(settings.DEBUG)`.
4. Change `SECRET_KEY` in `.env` → `docker compose up -d` → make sure the application restarted.
5. Run `docker compose exec web python manage.py check --deploy` — go through the production checklist.

---

## Review questions

- What are a Docker image and a Docker container? What is the difference between them?
- Why do you need `volumes:` in Docker Compose? What happens to the database data without a volume?
- Why does Nginx serve `/static/` directly rather than through Django?
- What is `ENTRYPOINT` in a Dockerfile?
- Why should a missing `DATABASE_URL` raise an `Exception` rather than fall back to SQLite?
- What is `proxy_set_header Upgrade $http_upgrade`? Why is it needed for WebSocket?
- What does `python manage.py check --deploy` check?

---

**Next →** [Notes Chat App Deep Dive](../12_final_project/README.md) — the final architectural walkthrough.
