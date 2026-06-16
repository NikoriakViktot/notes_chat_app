# Налаштування середовища

> **Рекомендований шлях:** одразу переходь до [Кроку 1 — Hello Django](../tutorials/01_hello_django/index.md).
> Там є покрокове налаштування з перевіркою кожного кроку.
>
> Цей документ — для тих хто хоче зрозуміти опції запуску перед початком.

---

## Рекомендований шлях — туторіал

Якщо ти тут вперше — **не читай цей файл далі**, переходь одразу до:

**→ [Крок 1. Hello Django — Середовище та запуск](../tutorials/01_hello_django/environment.md)**

Там є:
- Установка Docker Desktop крок за кроком
- Клонування репозиторію
- `docker compose up --build` з поясненням кожного рядка виводу
- Перша сторінка Django в браузері
- Типові помилки і як їх виправити

---

## Два способи запуску

### Спосіб A — Docker Compose (рекомендовано)

`notes_chat_app` потребує PostgreSQL і Redis. Docker Compose піднімає все за одну команду:

```bash
git clone https://github.com/NikoriakViktot/notes_chat_app.git
cd notes_chat_app
cp .env.example .env          # скопіювати конфігурацію
docker compose up --build     # перший запуск (3–7 хвилин)
```

Після `Application startup complete` — відкрий `http://localhost`.

**Демо облікові записи** (пароль: `demo1234`): `demo_alice`, `demo_bob`, `demo_carol`

### Спосіб B — Локально без Docker

!!! warning "Без PostgreSQL застосунок не запуститься"
    `manage.py migrate` падає з `OperationalError` якщо немає `DATABASE_URL`.
    Цей спосіб для досвідчених розробників з власним PostgreSQL і Redis.

```bash
# Передумови: PostgreSQL і Redis запущені локально

python3 -m venv .venv
source .venv/bin/activate          # Linux/macOS
# .\.venv\Scripts\Activate.ps1     # Windows PowerShell

pip install -r requirements.txt

# Встановити змінні середовища:
export DATABASE_URL=postgres://user:pass@localhost:5432/notes_db
export REDIS_URL=redis://localhost:6379/0
export SECRET_KEY=dev-key
export DEBUG=True

python manage.py migrate
python manage.py seed_demo_data
uvicorn notes_project.asgi:application --reload --port 8001
```

---

## `.env` файл

При обох способах потрібен `.env` у корені проєкту:

```bash
cp .env.example .env
```

Ключові змінні:

```bash
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db
REDIS_URL=redis://redis:6379/0
SECRET_KEY=dev-secret-key-replace-in-production
DEBUG=True
SEED_DEMO_DATA=1     # автоматично заповнює демо-даними при старті
```

!!! danger "Ніколи не комітити `.env`"
    `.env` вже є у `.gitignore`. Перевір: `git status` не повинен показувати `.env`.

---

## Типові проблеми при першому запуску

| Симптом | Причина | Рішення |
|---------|---------|---------|
| `docker: command not found` | Docker не встановлений | Встановити Docker Desktop |
| `port is already allocated` | Порт 80/5432 зайнятий | `docker compose down` або змінити порт |
| `web-1 exited with code 1` | Помилка міграції або відсутній `.env` | `docker compose logs web` |
| Чат не працює | Redis не стартував | `docker compose logs redis` |

---

## Наступний крок

Все готово? Переходь до туторіалу:

**→ [Крок 1. Hello Django](../tutorials/01_hello_django/index.md)**

---

## У книзі

- [Частина X. Linux і DevOps](../10_linux_and_devops/README.md) — Docker архітектура, volumes, networks
- [Крок 9. Deployment](../tutorials/09_deployment/index.md) — детально про кожен сервіс стеку
