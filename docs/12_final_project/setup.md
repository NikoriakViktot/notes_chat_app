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
| `redis` | `redis:7-alpine` | Redis — channel layer для WebSocket |
| `web` | Django ASGI (Uvicorn) | Застосунок на порту 8001 |
| `nginx` | `nginx:1.27-alpine` | Reverse proxy, порт 80 |
| `ngrok` | `ngrok/ngrok:latest` | Публічний тунель (dev) |
| `selenium` | `selenium/standalone-chrome` | E2E тести |

### Автоматична ініціалізація (`entrypoint.sh`)

При старті `web` контейнера виконується:

```text
python manage.py migrate
python manage.py collectstatic --no-input
python manage.py seed_demo_data   ← якщо SEED_DEMO_DATA=1
exec uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --reload
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
| `DEBUG` | `1` | рекомендовано для dev |
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
