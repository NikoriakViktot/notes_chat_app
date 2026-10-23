# Commands — notes_chat_app Command Cheatsheet

---

## Docker Compose

```bash
# ─── Start ────────────────────────────────────────────────────────────
docker compose up --build         # build and start all services
docker compose up -d              # start in the background (detached)
docker compose up -d --build      # rebuild + background

# ─── Stop ─────────────────────────────────────────────────────────────
docker compose down               # stop (volumes are kept)
docker compose down -v            # stop + remove volumes (reset the DB)
docker compose down --rmi all     # stop + remove images

# ─── Status ───────────────────────────────────────────────────────────
docker compose ps                 # status of all services
docker compose ps web             # status of web only

# ─── Logs ─────────────────────────────────────────────────────────────
docker compose logs web           # all web logs
docker compose logs -f web        # follow in real time
docker compose logs --tail=50 web # last 50 lines

# ─── Shell ────────────────────────────────────────────────────────────
docker compose exec web bash                      # bash in web
docker compose exec web python manage.py shell    # Django shell
docker compose exec db psql -U notes_user notes_db # PostgreSQL shell

# ─── Restart ──────────────────────────────────────────────────────────
docker compose restart web        # restart web only
docker compose build --no-cache web  # rebuild without cache
```

---

## Django manage.py

> In Docker, always run via `docker compose run --rm web` or `docker compose exec web`

```bash
# ─── Migrations ───────────────────────────────────────────────────────
docker compose run --rm web python manage.py makemigrations
docker compose run --rm web python manage.py migrate
docker compose run --rm web python manage.py migrate --fake   # mark as applied
docker compose run --rm web python manage.py showmigrations
docker compose run --rm web python manage.py sqlmigrate notes_app 0001

# ─── Static files ─────────────────────────────────────────────────────
docker compose run --rm web python manage.py collectstatic --noinput

# ─── Demo data ────────────────────────────────────────────────────────
docker compose run --rm web python manage.py seed_demo_data          # seed
docker compose run --rm web python manage.py seed_demo_data --reset  # clear + seed
docker compose run --rm web python manage.py seed_demo_data --force  # for DEBUG=False

# ─── Users ────────────────────────────────────────────────────────────
docker compose run --rm web python manage.py createsuperuser

# ─── Checks ───────────────────────────────────────────────────────────
docker compose run --rm web python manage.py check
docker compose run --rm web python manage.py check --deploy   # production audit

# ─── Shell ────────────────────────────────────────────────────────────
docker compose exec web python manage.py shell
docker compose exec web python manage.py shell_plus   # if django-extensions is installed
docker compose exec web python manage.py dbshell      # SQL shell
```

---

## Tests

```bash
# ─── Unit + Integration + Consumer tests ─────────────────────────────
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2

# ─── A single module ──────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_services -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_consumers -v 2

# ─── Selenium E2E (via exec!) ─────────────────────────────────────────
docker compose up -d                    # the stack must be running
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# ─── Coverage ─────────────────────────────────────────────────────────
docker compose run --rm web bash -c \
    "coverage run manage.py test notes_app.tests.test_models \
                                   notes_app.tests.test_services \
                                   notes_app.tests.test_forms \
                                   notes_app.tests.test_views \
                                   notes_app.tests.test_consumers \
    && coverage report --show-missing"
```

---

## Uvicorn (locally, without Docker)

```bash
# Start the ASGI server (if PostgreSQL and Redis are already running):
uvicorn notes_project.asgi:application --reload --port 8001

# With all parameters:
uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload \
    --log-level debug
```

---

## Ngrok

```bash
# Tunnel to nginx (via Docker — no separate step needed):
# Started automatically by docker compose up

# Locally (without Docker):
ngrok http --url=your-domain.ngrok-free.app 80

# Dashboard:
open http://localhost:4040
```

---

## Git

```bash
git status --short
git diff --stat
git log --oneline --decorate -20
git add -p                    # interactive staging (in chunks)
git stash                     # temporarily save changes
git stash pop                 # restore them
```
