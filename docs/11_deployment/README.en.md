# Deployment

Deployment means running the application stack on a server with production settings. Notes Chat App is deployed with Docker Compose using Uvicorn (ASGI) + Nginx + PostgreSQL + Redis + Celery.

This section is part of [Part X. Linux, DevOps and Deployment](../10_linux_and_devops/README.md).

---

## Sections

| Document | What we will learn |
|----------|-----------|
| [Django on Linux](deploy_11_django_on_linux_full.md) | virtualenv, gunicorn as a systemd service |
| [Nginx + Gunicorn/Uvicorn](deploy_12_nginx_gunicorn_uvicorn_full.md) | `proxy_pass`, SSL termination, WebSocket upgrade, static |
| [Logs and monitoring](deploy_13_logs_monitoring_debugging_full.md) | `LOGGING` in Django, `journalctl`, `docker logs`, Sentry |
| [Docker basics](deploy_14_docker_basics_full.md) | layers, registry, multi-stage build, `ENTRYPOINT` vs `CMD` |
| [Docker Compose](deploy_15_docker_compose_full.md) | services, volumes, networks, `depends_on`, health checks |
| [DevOps workflow](deploy_16_devops_workflow_full.md) | CI/CD, blue-green deploy, rollback strategy |
| [Kubernetes overview](deploy_17_kubernetes_overview_full.md) | Pod, Deployment, Service, Ingress — conceptually |
| [Roadmap](deploy_18_roadmap_next_steps_full.md) | what to learn next: k8s, Terraform, observability, SRE |

---

## Production Checklist for Notes Chat App

```bash
# Check before deploying:
docker compose exec web python manage.py check --deploy
```

| Parameter | Dev | Production |
|----------|-----|-----------|
| `DEBUG` | `True` | **`False`** |
| `SECRET_KEY` | in settings.py | from env, at least 50 characters |
| `DATABASE_URL` | PG from docker compose (required, SQLite is not supported) | PG from env, missing → Exception |
| `ALLOWED_HOSTS` | `['*']` | specific domains |
| Static files | Django dev server | Nginx `/static/` → volume |
| `SESSION_COOKIE_SECURE` | False | **True** (HTTPS) |
| `CSRF_COOKIE_SECURE` | False | **True** |
| `DebugExceptionMiddleware` | active | only `if DEBUG:` |
| Logs | console | file / Sentry |

---

## Where this lives in Notes Chat App

| File | Purpose |
|------|-------------|
| `docker-compose.yml` | full stack: db, redis, web, nginx, celery-worker, celery-beat, selenium, selenium-tests, ngrok |
| `Dockerfile` | `FROM python:3.12-slim`, COPY, pip install, EXPOSE 8001 |
| `entrypoint.sh` | migrate → collectstatic → seed_demo_data → uvicorn (DB and Redis are awaited via `depends_on: service_healthy`) |
| `nginx/nginx.conf` | proxy_pass :8001, WS upgrade, `/static/` alias |
| `.github/workflows/` | CI: tests before merge |
| `notes_project/settings.py` | `os.environ.get("SECRET_KEY", ...)`, `DATABASE_URL` parsing |

**Next →** [Notes Chat App Deep Dive](../12_final_project/README.md)
