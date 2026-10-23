# Частина X. Linux, DevOps і Deployment

Застосунок, який працює тільки на ноутбуці розробника — не production. Ця частина охоплює Linux-основи, Docker, Docker Compose, Nginx і CI.

**Передумови:** загальне розуміння проєкту.
**Рівень:** Intermediate → Production.

---

## Розділи

### Linux

| Документ | Що вивчимо |
|----------|-----------|
| [Ментальна модель Linux](linux_01_mental_model_full.md) | kernel, userspace, файли як абстракція, PID, fd |
| [Термінал та shell](linux_02_terminal_and_shell_full.md) | bash, zsh, stdin/stdout/stderr, pipes, `>` `>>`, `$?` |
| [Файлова система](linux_03_filesystem_navigation_full.md) | FHS, `ls`, `find`, `tree`, `pwd`, `cd`, symlinks |
| [Файли та права](linux_04_files_permissions_users_full.md) | `chmod`, `chown`, `umask`, `sudo`, users/groups |
| [Процеси та порти](linux_05_processes_ports_services_full.md) | `ps`, `top`, `kill`, `lsof`, `netstat`, `ss`, `systemctl` |
| [Пакетні менеджери](linux_06_package_managers_and_software_full.md) | `apt`, `pip`, `pyenv`, `nvm` |
| [SSH та сервери](linux_07_ssh_and_remote_server_full.md) | `ssh`, `scp`, `rsync`, `authorized_keys`, jump host |
| [Змінні середовища](linux_08_environment_variables_and_secrets_full.md) | `export`, `.env`, `os.environ`, secrets management |
| [Bash скрипти](linux_09_bash_scripts_full.md) | shebang, змінні, умови, цикли, функції, exit codes |
| [Makefile](linux_10_makefile_basics_full.md) | targets, phony, `make test`, `make build` |

### Docker

| Документ | Що вивчимо |
|----------|-----------|
| [Docker та Runtime](docker_and_runtime.md) | image, container, layer cache, volumes, networks |
| [Docker: повний посібник](docker_guide.md) | `Dockerfile`, `build`, `run`, `exec`, `logs`, compose integration |

### Deployment

| Документ | Що вивчимо |
|----------|-----------|
| [Django на Linux](../11_deployment/deploy_11_django_on_linux_full.md) | virtualenv, `gunicorn`, `systemd` service, `collectstatic` |
| [Nginx + Gunicorn/Uvicorn](../11_deployment/deploy_12_nginx_gunicorn_uvicorn_full.md) | `proxy_pass`, WebSocket upgrade, SSL, static files |
| [Логи та моніторинг](../11_deployment/deploy_13_logs_monitoring_debugging_full.md) | `journalctl`, `docker logs`, `LOGGING` в Django |
| [Docker основи](../11_deployment/deploy_14_docker_basics_full.md) | image layers, registry, `ENTRYPOINT`, multi-stage |
| [Docker Compose](../11_deployment/deploy_15_docker_compose_full.md) | сервіси, volumes, networks, health checks, depends_on |
| [DevOps workflow](../11_deployment/deploy_16_devops_workflow_full.md) | CI/CD pipeline, blue-green deploy, rollback |
| [Kubernetes огляд](../11_deployment/deploy_17_kubernetes_overview_full.md) | Pod, Deployment, Service, Ingress — концептуально |
| [Roadmap](../11_deployment/deploy_18_roadmap_next_steps_full.md) | що вчити далі після курсу |

---

## Ключові концепти

**Docker Compose стек Notes Chat App:**

```yaml
# docker-compose.yml (спрощено)
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

# 1. PostgreSQL і Redis уже healthy: це гарантує depends_on + healthcheck у docker-compose.yml

# 2. Застосовуємо міграції
if [ "${RUN_MIGRATIONS:-1}" = "1" ]; then
    python manage.py migrate --noinput
fi

# 3. Збираємо статику
if [ "${RUN_COLLECTSTATIC:-1}" = "1" ]; then
    python manage.py collectstatic --noinput
fi

# 4. Seed demo data (якщо SEED_DEMO_DATA=1)
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    python manage.py seed_demo_data ${seed_args}   # --force або --force --reset
fi

# 5. Запускаємо Uvicorn ASGI server (у dev — з --reload)
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --proxy-headers
```

**Nginx конфігурація для WebSocket:**

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
        proxy_set_header Upgrade    $http_upgrade;   # ← обов'язково для WS
        proxy_set_header Connection "upgrade";
    }

    # Static files — Nginx роздає напряму (не Django)
    location /static/ {
        alias /staticfiles/;
    }
}
```

**Environment variables — secrets:**

```bash
# .env (ніколи не комітити у git)
SECRET_KEY=django-prod-secret-key-here
DATABASE_URL=postgres://user:pass@db:5432/notes
REDIS_URL=redis://redis:6379/0
DEBUG=False
ALLOWED_HOSTS=notes.example.com,www.notes.example.com

# В Python (production-підхід):
import os
SECRET_KEY = os.environ['SECRET_KEY']   # ← Exception якщо відсутній (не default!)
# Навчальний проєкт зараз використовує os.environ.get("SECRET_KEY", "django-insecure-...")
# з dev-дефолтом — у production цей дефолт треба прибрати.
```

**Production checklist:**

```text
✓ DEBUG=False
✓ SECRET_KEY — з env, не у коді
✓ DATABASE_URL — відсутність → Exception (не SQLite fallback!)
✓ ALLOWED_HOSTS — конкретні домени
✓ HTTPS — CSRF_TRUSTED_ORIGINS, SESSION_COOKIE_SECURE
✓ Static files — Nginx, не Django
✓ DebugExceptionMiddleware — тільки if DEBUG
✓ Logrotate / log aggregation
✓ Health check endpoint
✓ CI: тести зелені перед деплоєм
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `docker-compose.yml` | повний стек: db, redis, web, nginx, celery-worker, celery-beat, selenium, selenium-tests, ngrok |
| `Dockerfile` | single-stage build: `FROM python:3.12-slim` |
| `entrypoint.sh` | startup: migrate → collectstatic → seed_demo_data → uvicorn |
| `nginx/nginx.conf` | proxy_pass, WebSocket upgrade, static alias |
| `.github/workflows/django-tests.yml` | GitHub Actions CI |
| `notes_project/settings.py` | `SECRET_KEY = os.environ.get("SECRET_KEY", ...)`, `DATABASE_URL` parsing |

---

## Педагогічний зв'язок

```text
Linux basics → Docker → Docker Compose → Nginx → GitHub Actions CI
Частина X охоплює весь deployment стек Notes Chat App (Крок 8 Zero to Hero)
```

**Zero to Hero:** Крок 8 — Docker Compose, Nginx, GitHub Actions.

---

## Практика

1. Виконай `docker compose ps` — переглянь стан всіх сервісів.
2. Виконай `docker compose logs web --tail=50` — знайди startup sequence.
3. Виконай `docker compose exec web python manage.py shell` → `from django.conf import settings; print(settings.DEBUG)`.
4. Змінений `SECRET_KEY` у `.env` → `docker compose up -d` → переконайся що застосунок перезапустився.
5. Виконай `docker compose exec web python manage.py check --deploy` — перевір production checklist.

---

## Контрольні питання

- Що таке Docker image і Docker container? Яка між ними різниця?
- Навіщо `volumes:` у Docker Compose? Що трапиться з даними БД без volume?
- Чому Nginx роздає `/static/` напряму, а не через Django?
- Що таке `ENTRYPOINT` у Dockerfile?
- Чому `DATABASE_URL` відсутність повинна давати `Exception`, а не SQLite fallback?
- Що таке `proxy_set_header Upgrade $http_upgrade`? Навіщо для WebSocket?
- Що перевіряє `python manage.py check --deploy`?

---

**Далі →** [Notes Chat App Deep Dive](../12_final_project/README.md) — фінальний архітектурний розбір.
