# Commands — Шпаргалка команд notes_chat_app

---

## Docker Compose

```bash
# ─── Запуск ───────────────────────────────────────────────────────────
docker compose up --build         # зібрати і запустити всі сервіси
docker compose up -d              # запустити у background (detached)
docker compose up -d --build      # rebuild + background

# ─── Зупинка ──────────────────────────────────────────────────────────
docker compose down               # зупинити (volumes зберігаються)
docker compose down -v            # зупинити + видалити volumes (скинути БД)
docker compose down --rmi all     # зупинити + видалити images

# ─── Стан ─────────────────────────────────────────────────────────────
docker compose ps                 # статус всіх сервісів
docker compose ps web             # статус тільки web

# ─── Логи ─────────────────────────────────────────────────────────────
docker compose logs web           # всі логи web
docker compose logs -f web        # слідкувати у реальному часі
docker compose logs --tail=50 web # останні 50 рядків

# ─── Shell ────────────────────────────────────────────────────────────
docker compose exec web bash                      # bash у web
docker compose exec web python manage.py shell    # Django shell
docker compose exec db psql -U notes_user notes_db # PostgreSQL shell

# ─── Перезапуск ───────────────────────────────────────────────────────
docker compose restart web        # перезапустити тільки web
docker compose build --no-cache web  # rebuild без кешу
```

---

## Django manage.py

> У Docker завжди через `docker compose run --rm web` або `docker compose exec web`

```bash
# ─── Міграції ─────────────────────────────────────────────────────────
docker compose run --rm web python manage.py makemigrations
docker compose run --rm web python manage.py migrate
docker compose run --rm web python manage.py migrate --fake   # позначити як виконані
docker compose run --rm web python manage.py showmigrations
docker compose run --rm web python manage.py sqlmigrate notes_app 0001

# ─── Статика ──────────────────────────────────────────────────────────
docker compose run --rm web python manage.py collectstatic --noinput

# ─── Демо-дані ────────────────────────────────────────────────────────
docker compose run --rm web python manage.py seed_demo_data          # засіяти
docker compose run --rm web python manage.py seed_demo_data --reset  # очистити + засіяти
docker compose run --rm web python manage.py seed_demo_data --force  # для DEBUG=False

# ─── Користувачі ──────────────────────────────────────────────────────
docker compose run --rm web python manage.py createsuperuser

# ─── Перевірка ────────────────────────────────────────────────────────
docker compose run --rm web python manage.py check
docker compose run --rm web python manage.py check --deploy   # аудит production

# ─── Shell ────────────────────────────────────────────────────────────
docker compose exec web python manage.py shell
docker compose exec web python manage.py shell_plus   # якщо встановлено django-extensions
docker compose exec web python manage.py dbshell      # SQL shell
```

---

## Тести

```bash
# ─── Unit + Integration + Consumer тести ─────────────────────────────
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2

# ─── Окремий модуль ───────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_services -v 2
docker compose run --rm web python manage.py test notes_app.tests.test_consumers -v 2

# ─── Selenium E2E (через exec!) ───────────────────────────────────────
docker compose up -d                    # стек має бути запущений
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

## Uvicorn (локально, без Docker)

```bash
# Запуск ASGI сервера (якщо PostgreSQL і Redis вже запущені):
uvicorn notes_project.asgi:application --reload --port 8001

# З усіма параметрами:
uvicorn notes_project.asgi:application \
    --host 0.0.0.0 \
    --port 8001 \
    --reload \
    --log-level debug
```

---

## Ngrok

```bash
# Тунель до nginx (через Docker — не потрібно окремо):
# Запускається автоматично у docker compose up

# Локально (якщо без Docker):
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
git add -p                    # інтерактивний staging (по частинах)
git stash                     # тимчасово зберегти зміни
git stash pop                 # відновити
```
