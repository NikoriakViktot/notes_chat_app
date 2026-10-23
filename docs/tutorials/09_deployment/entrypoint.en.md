# Entrypoint

> **`entrypoint.sh`** — a shell script that runs on every `docker compose up`.
> It runs the preparation steps and then starts uvicorn.

---

## entrypoint.sh — full code

```sh
#!/bin/sh
set -eu  # -e: stop on any error (exit code ≠ 0)
         # -u: fail when an undefined variable is used
# Without set -e: uvicorn starts even if migrate failed → 500 on every request

log() {
    printf '[entrypoint] %s\n' "$1"
}

if [ "${RUN_MIGRATIONS:-1}" = "1" ]; then
    log "Applying database migrations..."
    python manage.py migrate --noinput
    # --noinput: do not ask for confirmation in interactive mode
    # Applies all new migrations since the previous version of the code
fi

if [ "${RUN_COLLECTSTATIC:-1}" = "1" ]; then
    log "Collecting static files..."
    python manage.py collectstatic --noinput
    # Collects static files from all installed apps into STATIC_ROOT (/app/staticfiles)
    # Needed on every deploy (in case CSS/JS changed)
fi

if [ "${CREATE_SUPERUSER:-0}" = "1" ]; then
    log "Creating/updating Django superuser ${DJANGO_SUPERUSER_USERNAME:-admin}..."
    python manage.py shell -c "..."
    # ... creates or updates a superuser from
    # DJANGO_SUPERUSER_USERNAME / _EMAIL / _PASSWORD
fi

if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    seed_args="--force"
    # --force: allow seeding even when DEBUG=False
    if [ "${SEED_DEMO_RESET:-0}" = "1" ]; then
        seed_args="--force --reset"
        # --reset: delete existing demo data first
    fi
    log "Seeding demo data with args: ${seed_args}"
    python manage.py seed_demo_data ${seed_args}
fi

port="${PORT:-8001}"
set -- --host 0.0.0.0 --port "${port}" --proxy-headers --forwarded-allow-ips '*'
# set -- ...: builds the argument list for uvicorn ("$@")
# --proxy-headers: trust X-Forwarded-* from nginx

if [ "${UVICORN_RELOAD:-1}" = "1" ]; then
    set -- "$@" --reload
    # --reload: auto-restart when files change (DEV ONLY!)
    # In production: UVICORN_RELOAD=0
fi

log "Starting ASGI web server on port ${port}..."
exec python -m uvicorn notes_project.asgi:application "$@"

# exec: replaces the shell process with uvicorn
# Without exec: shell → uvicorn as a child process
# SIGTERM from Docker → shell → the shell may ignore it → uvicorn never gets the signal
# With exec: SIGTERM → uvicorn → graceful shutdown ✓
```

Each step is controlled by an environment variable from `docker-compose.yml` / `.env` (`RUN_MIGRATIONS`, `RUN_COLLECTSTATIC`, `CREATE_SUPERUSER`, `SEED_DEMO_DATA`, `SEED_DEMO_RESET`, `UVICORN_RELOAD`, `PORT`), so the same script works for both dev and production.

---

## `set -e` — why migrate must finish before uvicorn

**The `set -e` chain in action:**

```
✅ Normal startup:
  migrate OK → collectstatic OK → seed OK → uvicorn START

❌ If migrate failed (for example, PostgreSQL is not ready yet):
  migrate FAIL (exit 1) → set -e → shell EXIT
  entrypoint returns exit 1
  → Docker: the container exited with an error → "Exited (1)"
  → nginx does NOT start (depends_on: service_healthy)
  → A clear error in the logs instead of mysterious 500s
```

**Without `set -e`:**

```
migrate FAIL → the shell keeps going
collectstatic → may fail too (if the DB is needed for static discovery)
seed_demo_data → may fail
uvicorn START → starts without migrations
→ 500 IntegrityError or OperationalError on every page
→ hard to figure out what went wrong
```

---

## The `--noinput` flag

```sh
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

`--noinput` (or `--no-input`) disables interactive confirmations. Without it:

```
You have requested to collect static files at the destination location as
specified in your settings:

    /app/staticfiles

This will overwrite existing files!
Are you sure you want to do this?

Type 'yes' to continue, or 'no' to cancel:
```

A Docker container has no interactive terminal → the command hangs forever. `--noinput` answers `yes` automatically.

---

## `collectstatic` — when and why

```sh
python manage.py collectstatic --noinput
```

This command collects static files from all installed apps into a single directory (`STATIC_ROOT = /app/staticfiles`):

```
Sources:
  notes_app/static/notes_app/css/style.css
  notes_app/static/notes_app/js/group_chat.js
  django/contrib/admin/static/admin/css/base.css
  crispy_forms/static/...

Result: /app/staticfiles/
  notes_app/css/style.css
  notes_app/js/group_chat.js
  admin/css/base.css
  ...
```

`collectstatic` runs on **every** `docker compose up` because:
1. When CSS/JS changes in the code → the new files must get into the volume
2. On the first run the staticfiles volume is empty
3. It is an idempotent operation (always safe to run)

---

## `exec` — why not just uvicorn

**Without `exec`:**

```bash
# ❌ Without exec (bad):
python -m uvicorn notes_project.asgi:application ...
# Process tree:
#   PID 1: sh entrypoint.sh
#   PID 2: python uvicorn  ← SIGTERM does not reach it
#
# docker stop → SIGTERM → PID 1 (sh) → sh ignores it
#             → 10 sec → SIGKILL → hard kill
# Active WebSocket connections are cut off without a graceful shutdown
```

**With `exec`:**

```bash
# ✅ With exec (correct):
exec python -m uvicorn notes_project.asgi:application ...
# Process tree:
#   PID 1: python uvicorn  ← SIGTERM arrives directly
#
# docker stop → SIGTERM → PID 1 (uvicorn) → graceful shutdown
#             → helps close active WebSocket connections
#             → stops cleanly
```

`exec` replaces the current shell process with the uvicorn process. After `exec`, PID 1 is uvicorn, not the shell. Docker always sends `SIGTERM` to PID 1 on `docker stop`, and now uvicorn receives it properly.

---

## Production vs dev entrypoint

**Development (current):**

```sh
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload    # ← automatic restart when .py files change
```

**Production:**

```sh
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --workers 4        # ← 4 parallel workers (2 × CPU cores)
    # Without --reload: a static launch, higher performance
```

In the real `entrypoint.sh`, `--reload` is added only when `UVICORN_RELOAD=1` (the default), so for production it is enough to set `UVICORN_RELOAD=0`. The script has no `--workers` flag; you add it yourself.

`--reload` in production is an anti-pattern:
- Uvicorn watches the file system → unnecessary load
- Every write of a temp file or log → a possible restart
- A single worker process (you cannot use `--workers` together with `--reload`)

---

## In the book

- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker, containers, shell scripts, process management, signals

---

## Official documentation

- [Uvicorn: Deployment](https://www.uvicorn.org/deployment/) — `--workers`, `--reload`, graceful shutdown
- [Docker: ENTRYPOINT vs CMD](https://docs.docker.com/reference/dockerfile/#entrypoint) — the difference between entrypoint and cmd
- [Bash: set -e](https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin) — the errexit option
- [Linux: exec (shell builtin)](https://man7.org/linux/man-pages/man3/exec.3.html) — replace the current process
- [Django: collectstatic](https://docs.djangoproject.com/en/5.2/ref/contrib/staticfiles/#collectstatic) — the command and its options
