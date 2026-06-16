# Entrypoint

> **`entrypoint.sh`** — shell скрипт що виконується при кожному `docker compose up`.
> Він запускає підготовчі кроки і потім uvicorn.

---

## entrypoint.sh — повний код

```sh
#!/bin/sh
set -e   # зупинитись при будь-якій помилці (exit code ≠ 0)
# Без set -e: uvicorn стартує навіть якщо migrate провалилась → 500 на всіх запитах

echo "=== Running migrations ==="
python manage.py migrate --noinput
# --noinput: не питати підтвердження в інтерактивному режимі
# Застосовує всі нові міграції з попередньої версії коду

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput
# Збирає static з усіх installed apps у STATIC_ROOT (/app/staticfiles)
# Потрібно при кожному deploy (якщо змінились CSS/JS)

echo "=== Seeding demo data (if enabled) ==="
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
    # --force: без підтвердження, навіть якщо БД не порожня
fi

echo "=== Starting uvicorn ==="
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload
    # --reload: авто-перезапуск при зміні файлів (ТІЛЬКИ ДЛЯ DEV!)
    # У production: прибрати --reload + додати --workers 4

# exec: замінює shell процес uvicorn'ом
# Без exec: shell → uvicorn як child process
# SIGTERM від Docker → shell → shell може ігнорувати → uvicorn не отримує сигнал
# З exec: SIGTERM → uvicorn → graceful shutdown ✓
```

---

## `set -e` — чому migrate має завершитись перед uvicorn

**Ланцюг `set -e` у дії:**

```
✅ Нормальний запуск:
  migrate OK → collectstatic OK → seed OK → uvicorn START

❌ Якщо migrate провалилась (наприклад, PostgreSQL ще не ready):
  migrate FAIL (exit 1) → set -e → shell EXIT
  entrypoint повертає exit 1
  → Docker: контейнер вийшов з помилкою → "Exited (1)"
  → nginx НЕ стартує (depends_on: service_healthy)
  → Зрозуміла помилка в логах замість таємничих 500
```

**Без `set -e`:**

```
migrate FAIL → shell продовжується
collectstatic → може теж провалитись (якщо БД потрібна для static discovery)
seed_demo_data → може провалитись
uvicorn START → стартує без міграцій
→ 500 IntegrityError або OperationalError на кожній сторінці
→ важко зрозуміти що пішло не так
```

---

## `--noinput` прапор

```sh
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

`--noinput` (або `--no-input`) вимикає інтерактивні підтвердження. Без нього:

```
You have requested to collect static files at the destination location as
specified in your settings:

    /app/staticfiles

This will overwrite existing files!
Are you sure you want to do this?

Type 'yes' to continue, or 'no' to cancel:
```

У Docker контейнері немає інтерактивного терміналу → команда зависає назавжди. `--noinput` автоматично відповідає `yes`.

---

## `collectstatic` — коли і навіщо

```sh
python manage.py collectstatic --noinput
```

Ця команда збирає static files з усіх встановлених apps в один директорій (`STATIC_ROOT = /app/staticfiles`):

```
Джерела:
  notes_app/static/notes_app/css/style.css
  notes_app/static/notes_app/js/group_chat.js
  django/contrib/admin/static/admin/css/base.css
  crispy_forms/static/...

Результат: /app/staticfiles/
  notes_app/css/style.css
  notes_app/js/group_chat.js
  admin/css/base.css
  ...
```

`collectstatic` виконується при **кожному** `docker compose up` тому що:
1. При зміні CSS/JS у code → нові файли мають потрапити у volume
2. При першому запуску staticfiles volume порожній
3. Це ідемпотентна операція (завжди безпечно виконати)

---

## `exec` — чому не просто uvicorn

**Без `exec`:**

```bash
# ❌ Без exec (погано):
python -m uvicorn notes_project.asgi:application ...
# Process tree:
#   PID 1: sh entrypoint.sh
#   PID 2: python uvicorn  ← SIGTERM не доходить до нього
#
# docker stop → SIGTERM → PID 1 (sh) → sh ігнорує
#             → 10 сек → SIGKILL → hard kill
# Активні WebSocket з'єднання обриваються без graceful shutdown
```

**З `exec`:**

```bash
# ✅ З exec (правильно):
exec python -m uvicorn notes_project.asgi:application ...
# Process tree:
#   PID 1: python uvicorn  ← SIGTERM приходить напряму
#
# docker stop → SIGTERM → PID 1 (uvicorn) → graceful shutdown
#             → допомагає завершити активні WebSocket з'єднання
#             → зупиняється коректно
```

`exec` замінює поточний shell процес процесом uvicorn. Після `exec` PID 1 — це uvicorn, а не shell. Docker завжди надсилає `SIGTERM` до PID 1 при `docker stop`, і тепер uvicorn правильно його отримує.

---

## production vs dev entrypoint

**Development (поточний):**

```sh
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload    # ← автоматичний перезапуск при зміні .py файлів
```

**Production:**

```sh
exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --workers 4        # ← 4 паралельних worker (2 × CPU cores)
    # Без --reload: статичний запуск, вища продуктивність
```

`--reload` у production — антипатерн:
- Uvicorn стежить за файловою системою → зайве навантаження
- При кожному записі temp файлу або логу → можливий перезапуск
- Один worker process (не можна використовувати `--workers` з `--reload`)

---

## У книзі

- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker, контейнери, shell скрипти, process management, signals

---

## Офіційна документація

- [Uvicorn: Deployment](https://www.uvicorn.org/deployment/) — `--workers`, `--reload`, graceful shutdown
- [Docker: ENTRYPOINT vs CMD](https://docs.docker.com/reference/dockerfile/#entrypoint) — різниця між entrypoint і cmd
- [Bash: set -e](https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin) — опція errexit
- [Linux: exec (shell builtin)](https://man7.org/linux/man-pages/man3/exec.3.html) — замінити поточний процес
- [Django: collectstatic](https://docs.djangoproject.com/en/5.2/ref/contrib/staticfiles/#collectstatic) — команда і параметри
