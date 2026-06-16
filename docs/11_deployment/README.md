# Deployment

Deployment — це запуск application stack на сервері з production settings. Notes Chat App розгортається через Docker Compose з Daphne (ASGI) + Nginx + PostgreSQL + Redis.

Цей розділ є частиною [Частини X. Linux, DevOps і Deployment](../10_linux_and_devops/README.md).

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Django на Linux](deploy_11_django_on_linux_full.md) | virtualenv, gunicorn/daphne як systemd service |
| [Nginx + Gunicorn/Uvicorn](deploy_12_nginx_gunicorn_uvicorn_full.md) | `proxy_pass`, SSL termination, WebSocket upgrade, static |
| [Логи та моніторинг](deploy_13_logs_monitoring_debugging_full.md) | `LOGGING` в Django, `journalctl`, `docker logs`, Sentry |
| [Docker основи](deploy_14_docker_basics_full.md) | layers, registry, multi-stage build, `ENTRYPOINT` vs `CMD` |
| [Docker Compose](deploy_15_docker_compose_full.md) | сервіси, volumes, networks, `depends_on`, health checks |
| [DevOps workflow](deploy_16_devops_workflow_full.md) | CI/CD, blue-green deploy, rollback стратегія |
| [Kubernetes огляд](deploy_17_kubernetes_overview_full.md) | Pod, Deployment, Service, Ingress — концептуально |
| [Roadmap](deploy_18_roadmap_next_steps_full.md) | що вивчати далі: k8s, Terraform, observability, SRE |

---

## Production Checklist для Notes Chat App

```bash
# Перевір перед деплоєм:
docker compose exec web python manage.py check --deploy
```

| Параметр | Dev | Production |
|----------|-----|-----------|
| `DEBUG` | `True` | **`False`** |
| `SECRET_KEY` | у settings.py | з env, мінімум 50 символів |
| `DATABASE_URL` | SQLite або local PG | PG з env, відсутність → Exception |
| `ALLOWED_HOSTS` | `['*']` | конкретні домени |
| Static files | Django dev server | Nginx `/static/` → volume |
| `SESSION_COOKIE_SECURE` | False | **True** (HTTPS) |
| `CSRF_COOKIE_SECURE` | False | **True** |
| `DebugExceptionMiddleware` | активний | тільки `if DEBUG:` |
| Logs | console | файл / Sentry |

---

## Де це у Notes Chat App

| Файл | Призначення |
|------|-------------|
| `docker-compose.yml` | повний стек: db, redis, web, nginx, ngrok, selenium |
| `Dockerfile` | `FROM python:3.12-slim`, COPY, pip install, EXPOSE 8001 |
| `entrypoint.sh` | wait-for-db → migrate → collectstatic → daphne |
| `nginx/nginx.conf` | proxy_pass :8001, WS upgrade, `/static/` alias |
| `.github/workflows/` | CI: тести перед merge |
| `notes_project/settings.py` | `os.environ['SECRET_KEY']`, `DATABASE_URL` parsing |

**Далі →** [Notes Chat App Deep Dive](../12_final_project/README.md)
