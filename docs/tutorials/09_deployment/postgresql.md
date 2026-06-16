# PostgreSQL

> **Ключова відмінність від SQLite:** PostgreSQL — окремий сервіс у мережі.
> Django з'єднується через `DATABASE_URL` (парсимо рядок підключення у `settings.py`).

---

## Як Django підключається до PostgreSQL

```python
# notes_project/settings.py
import os
import re

_DATABASE_URL = os.environ.get('DATABASE_URL')
if not _DATABASE_URL:
    raise Exception("DATABASE_URL не встановлено. Запускай через docker compose.")

# Парсимо URL вручну
_m = re.match(r'postgres://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', _DATABASE_URL)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME':     _m.group(5),
        'USER':     _m.group(1),
        'PASSWORD': _m.group(2),
        'HOST':     _m.group(3),   # ← Docker DNS: "db" → IP контейнера
        'PORT':     _m.group(4),
        'CONN_MAX_AGE': 0,
    }
}
```

!!! warning "Без DATABASE_URL — Exception, не SQLite"
    `settings.py` **не** має SQLite fallback. Якщо `DATABASE_URL` не встановлено,
    застосунок кидає `Exception` відразу при старті. Завжди запускай через `docker compose`.

`DATABASE_URL` у `docker-compose.yml` виглядає так:

```yaml
web:
  environment:
    DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
    #                                                               ↑
    #                                          "db" — DNS ім'я сервісу у Docker network app-net
```

### Внутрішня DNS у Docker мережі

```
docker-compose.yml:
  services:
    db:    ← ім'я сервісу = DNS ім'я
    redis:
    web:
    nginx:

У мережі app-net:
  "db"     → IP контейнера db    (postgres)
  "redis"  → IP контейнера redis
  "web"    → IP контейнера web   (uvicorn)
  "nginx"  → IP контейнера nginx

DATABASE_URL: postgres://user:pass@db:5432/notes_db
                                    ↑
                              Docker DNS резолюція
```

---

## Чому не SQLite у production

| | SQLite | PostgreSQL |
|--|--------|-----------|
| **Конкурентний запис** | Один writer, блокування файлу | MVCC — тисячі writers |
| **WebSocket + ORM** | Конфлікти при concurrent WS | Немає конфліктів |
| **Транзакції** | Обмежені | Повна ACID + SERIALIZABLE |
| **Indexing** | Базові | GIN, GiST, часткові індекси |
| **Масштаб** | ~100K рядків зручно | Мільярди рядків |
| **Docker** | Файл у контейнері (втрачається!) | Окремий сервіс + volume |

**Критична проблема SQLite у Docker:**

```
Без named volume:
  docker compose down → контейнер видаляється → db.sqlite3 видаляється
  docker compose up   → нова БД → всі дані втрачені!

З PostgreSQL + named volume:
  docker compose down → контейнер видаляється → postgres_data volume залишається
  docker compose up   → PostgreSQL підключається до volume → дані збережені
```

---

## Міграції у Docker

Міграції запускаються **автоматично** при кожному `docker compose up` через `entrypoint.sh`:

```sh
python manage.py migrate --noinput
```

Решта корисних команд:

```bash
# Вручну (якщо треба застосувати без перезапуску):
docker compose exec web python manage.py migrate

# Перевірити стан міграцій:
docker compose exec web python manage.py showmigrations

# Створити нову міграцію (після зміни models.py):
docker compose exec web python manage.py makemigrations

# Підключитись до PostgreSQL напряму:
docker compose exec db psql -U notes_user -d notes_db

# Переглянути таблиці:
\dt
\d notes_app_note    # схема конкретної таблиці
\q                   # вийти
```

---

## CONN_MAX_AGE — persistent connections

```python
# settings.py
DATABASES = {
    'default': {
        ...,
        'CONN_MAX_AGE': 0,  # async-compatible: 0 = нові з'єднання кожен раз
    }
}
```

**Чому `CONN_MAX_AGE = 0` для ASGI:**

`CONN_MAX_AGE > 0` вмикає persistent connections через thread-local storage. У синхронному WSGI Django — кожен запит обробляється у своєму thread, persistent connection безпечна. У асинхронному Uvicorn — один thread обслуговує кілька coroutines одночасно. Якщо persistent connection ділиться між coroutines → race condition на рівні БД з'єднання.

```
CONN_MAX_AGE = 60  (погано для ASGI):
  coroutine A → отримала connection з пулу
  coroutine B → намагається використати ту саму connection
  → Непередбачувані помилки або race conditions

CONN_MAX_AGE = 0  (правильно для ASGI):
  coroutine A → відкриває нове з'єднання → запит → закриває
  coroutine B → відкриває нове з'єднання → запит → закриває
  → Ізольовані з'єднання, немає конфліктів
```

Django документація рекомендує `CONN_MAX_AGE = 0` при використанні ASGI-сервера.

---

## Дані між restartами

```bash
docker compose down        # зупиняє контейнери, volume зберігається
docker compose up          # postgres_data → дані збережені

docker compose down -v     # -v: видаляє volumes → БД очищена
```

```yaml
# docker-compose.yml
volumes:
  postgres_data:    # named volume

services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

!!! danger "`docker compose down -v`"
    Прапор `-v` видаляє всі named volumes включно з `postgres_data`.
    **Всі дані у БД будуть знищені.** Використовуй тільки коли хочеш повний reset.

---

## У книзі

- [Частина III. Database і ORM](../../03_database_and_orm/README.md) — Django ORM, QuerySet, migrations, транзакції, PostgreSQL-специфічні можливості
- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker volumes, мережі, named volumes vs bind mounts

---

## Офіційна документація

- [Django: Databases](https://docs.djangoproject.com/en/5.2/ref/databases/) — PostgreSQL-специфічні налаштування, `CONN_MAX_AGE`
- [Django: DATABASE_URL patterns](https://docs.djangoproject.com/en/5.2/ref/settings/#databases) — формат рядка підключення
- [PostgreSQL: Connection strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING) — URL формат
- [PostgreSQL: pg_isready](https://www.postgresql.org/docs/current/app-pg-isready.html) — health check утиліта
- [Docker: Named volumes](https://docs.docker.com/engine/storage/volumes/) — коли використовувати named vs anonymous volumes
