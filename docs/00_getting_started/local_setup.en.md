# Setting Up the Environment

> **Recommended path:** go straight to [Step 1 — Hello Django](../tutorials/01_hello_django/index.md).
> It contains a step-by-step setup with a check at every step.
>
> This document is for those who want to understand the startup options before beginning.

---

## Recommended path — the tutorial

If you are here for the first time — **do not read this file any further**, go straight to:

**→ [Step 1. Hello Django — Environment and startup](../tutorials/01_hello_django/environment.md)**

It covers:
- Installing Docker Desktop step by step
- Cloning the repository
- `docker compose up --build` with an explanation of every line of output
- Your first Django page in the browser
- Common mistakes and how to fix them

---

## Two ways to run the project

### Option A — Docker Compose (recommended)

`notes_chat_app` requires PostgreSQL and Redis. Docker Compose brings everything up with a single command:

```bash
git clone https://github.com/NikoriakViktot/notes_chat_app.git
cd notes_chat_app
cp .env.example .env          # copy the configuration
docker compose up --build     # first run (3–7 minutes)
```

After `Application startup complete`, open `http://localhost`.

**Demo accounts** (password: `demo1234`): `demo_alice`, `demo_bob`, `demo_carol`

### Option B — Locally without Docker

!!! warning "The application will not start without PostgreSQL"
    Without `DATABASE_URL`, every `manage.py` command fails while `settings.py` is loading (`Exception: DATABASE_URL не встановлено...`, "DATABASE_URL is not set").
    This option is for experienced developers with their own PostgreSQL and Redis.

```bash
# Prerequisites: PostgreSQL and Redis running locally

python3 -m venv .venv
source .venv/bin/activate          # Linux/macOS
# .\.venv\Scripts\Activate.ps1     # Windows PowerShell

pip install -r requirements.txt

# Set environment variables:
export DATABASE_URL=postgres://user:pass@localhost:5432/notes_db
export REDIS_URL=redis://localhost:6379/0
export SECRET_KEY=dev-key
export DEBUG=True

python manage.py migrate
python manage.py seed_demo_data
uvicorn notes_project.asgi:application --reload --port 8001
```

---

## The `.env` file

Both options need a `.env` file in the project root:

```bash
cp .env.example .env
```

Key variables:

```bash
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db
REDIS_URL=redis://redis:6379/0
SECRET_KEY=dev-secret-key-replace-in-production
DEBUG=True
SEED_DEMO_DATA=1     # automatically fills the database with demo data on startup
```

!!! danger "Never commit `.env`"
    `.env` is already in `.gitignore`. Check: `git status` must not show `.env`.

---

## Common problems on the first run

| Symptom | Cause | Solution |
|---------|---------|---------|
| `docker: command not found` | Docker is not installed | Install Docker Desktop |
| `port is already allocated` | Port 80/5432 is in use | `docker compose down` or change the port |
| `web-1 exited with code 1` | Migration error or missing `.env` | `docker compose logs web` |
| Chat does not work | Redis did not start | `docker compose logs redis` |

---

## Next step

All set? Go to the tutorial:

**→ [Step 1. Hello Django](../tutorials/01_hello_django/index.md)**

---

## In the book

- [Part X. Linux and DevOps](../10_linux_and_devops/README.md) — Docker architecture, volumes, networks
- [Step 9. Deployment](../tutorials/09_deployment/index.md) — details on every service in the stack
