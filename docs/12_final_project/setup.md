# Запуск Notes Chat App

## Docker — єдиний підтримуваний спосіб

Notes Chat App потребує PostgreSQL і Redis. `settings.py` піднімає `Exception` якщо `DATABASE_URL` не встановлено — SQLite fallback відсутній.

```bash
# Перший запуск (збирає образи, застосовує міграції, сідить демо-дані)
docker compose up --build

# Наступні запуски
docker compose up
```

Стек доступний на **`http://localhost`** (Nginx → порт 80 → Django на 8001).

### Сервіси Docker Compose

| Сервіс | Образ | Роль |
|--------|-------|------|
| `db` | `postgres:16-alpine` | PostgreSQL — основна БД |
| `redis` | `redis:7-alpine` | Redis — channel layer для WebSocket (DB 0) і Celery broker (DB 1) |
| `web` | Django ASGI (Uvicorn) | Застосунок на порту 8001 |
| `nginx` | `nginx:1.27-alpine` | Reverse proxy, порт 80 |
| `celery-worker` | той самий image, що й `web` | Виконує Celery-задачі |
| `celery-beat` | той самий image, що й `web` | Планувальник Celery (`CELERY_BEAT_SCHEDULE`) |
| `ngrok` | `ngrok/ngrok:latest` | Публічний тунель (dev, profile `tunnel`) |
| `selenium` | `selenium/standalone-chrome` | E2E тести (profile `test`) |
| `selenium-tests` | той самий image, що й `web` | Запуск `test_selenium` проти Selenium (profile `test`) |

### Автоматична ініціалізація (`entrypoint.sh`)

При старті `web` контейнера виконується:

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py seed_demo_data --force   ← якщо SEED_DEMO_DATA=1 (+ --reset, якщо SEED_DEMO_RESET=1)
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --proxy-headers --forwarded-allow-ips '*' --reload   ← --reload, якщо UVICORN_RELOAD=1
```

### Демо-дані

```bash
# Посіяти демо-дані вручну
docker compose run --rm web python manage.py seed_demo_data

# Скинути і посіяти знову
docker compose run --rm web python manage.py seed_demo_data --reset
```

---

## Змінні середовища

Скопіюй `.env.example` у `.env`:

```bash
cp .env.example .env
```

Обов'язкові змінні:

| Змінна | Приклад | Обов'язкова |
|--------|---------|-------------|
| `DATABASE_URL` | `postgres://notes:notes@db:5432/notes_db` | ✅ завжди |
| `REDIS_URL` | `redis://redis:6379/0` | ✅ для WebSocket |
| `SECRET_KEY` | будь-який рядок | ✅ |
| `DJANGO_DEBUG` | `1` | рекомендовано для dev |
| `SEED_DEMO_DATA` | `1` | для автоматичного сіду |

---

## Запуск тестів

### Unit, integration і consumer тести

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2
```

### Selenium E2E тести

Selenium тести вимагають запущений контейнер (`exec`, не `run`):

```bash
docker compose up -d
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium \
  -v 2
```

---

## Відоме обмеження

Async HTTP demo файли (`async_views.py`, `async_selectors.py`, `async_services.py`) відсутні у поточному working tree. WebSocket chat — активний ASGI/async приклад.
