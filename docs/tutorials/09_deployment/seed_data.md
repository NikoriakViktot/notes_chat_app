# Seed Data

> **`seed_demo_data`** — Django management command що заповнює БД демо-даними для розробки.
> Дозволяє відразу побачити застосунок з реальними нотатками, групами і чатом.

---

## Навіщо seed data

**Проблема:** при першому `docker compose up` БД порожня. Ти бачиш порожній застосунок — нема нотаток, нема груп, чат мовчить. Важко показати студентам як виглядає реальний застосунок і важко перевірити групові функції.

**Рішення:** seed command створює реалістичні демо-дані:
- 3 юзери з паролями — можна одразу залогінитись
- Групи з учасниками — можна тестувати групові нотатки і чат у різних вкладках
- Різні типи нотаток (особисті, групові, закріплені, з нагадуваннями) — видна вся функціональність
- Повідомлення у групових чатах — чат не виглядає порожнім

---

## Що створює `seed_demo_data`

### Юзери

| Логін | Пароль | Роль |
|-------|--------|------|
| `demo_alice` | `demo1234` | Учасниця "Команда розробки" і "Сімейний чат" |
| `demo_bob` | `demo1234` | Учасник "Команда розробки" |
| `demo_carol` | `demo1234` | Учасниця "Команда розробки" і "Сімейний чат" |

Кожен юзер має свій `UserProfile`.

### Групи та учасники

| Група | Учасники |
|-------|---------|
| `demo_команда_розробки` ("Команда розробки") | alice, bob, carol |
| `demo_сімейний_чат` ("Сімейний чат") | alice, carol |

У БД група зберігається під назвою з префіксом `demo_` (саме цей префікс використовує `--reset`). Alice і Carol — учасниці обох груп → бачать групові нотатки і чат обох груп; Bob — тільки "Команди розробки".

### Нотатки кожного юзера

Кожен із трьох юзерів отримує однаковий набір із 10 власних нотаток:

| Тип | Кількість |
|-----|---------|
| Усього (різні пріоритети 1–3) | 10 |
| Закріплені (`is_pinned=True`) | 3 |
| З нагадуваннями (`Reminder`) | 4 |
| Групові (group="Команда розробки") | 3 |

### Інші дані

- **Notebooks:** "Робочі нотатки" (default), "Особисте", "Навчання Python"
- **Tags:** робота, особисте, навчання, важливо, ідеї, перечитати — кожен з унікальним кольором
- **TodoList:** 3 списки ("Задачі спринту", "Домашні справи", "Навчальний план"), у кожному перші два TodoItems виконані
- **ShoppingList:** 3 списки, один з них ("Спільні покупки для офісу") — у групі "Команда розробки"
- **ChatMessages:** 20 повідомлень у "Команді розробки" і 10 у "Сімейному чаті"

---

## `SEED_DEMO_DATA=1` при старті

Коли `SEED_DEMO_DATA=1` встановлено у `.env`, seed виконується автоматично при кожному `docker compose up` через `entrypoint.sh`:

```sh
# entrypoint.sh
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    seed_args="--force"
    if [ "${SEED_DEMO_RESET:-0}" = "1" ]; then
        seed_args="--force --reset"
    fi
    log "Seeding demo data with args: ${seed_args}"
    python manage.py seed_demo_data ${seed_args}
fi
```

```yaml
# docker-compose.yml
web:
  environment:
    SEED_DEMO_DATA: ${SEED_DEMO_DATA:-1}
    # ↑ Якщо .env не містить SEED_DEMO_DATA — default 1 (seed увімкнений)
    SEED_DEMO_RESET: ${SEED_DEMO_RESET:-0}
```

```bash
# .env:
SEED_DEMO_DATA=1   # вмикає автосід при кожному docker compose up
```

---

## Команди

```bash
# Перший запуск (SEED_DEMO_DATA=1 у .env → автоматично при docker compose up):
docker compose up

# Вручну — перший раз (БД порожня):
docker compose exec web python manage.py seed_demo_data

# Вручну — скидання і повторне заповнення (БД вже є):
docker compose exec web python manage.py seed_demo_data --reset
# --reset: видаляє всіх demo_* юзерів і пов'язані дані → сіде заново

# Без стека (окремий контейнер — тільки якщо БД вже має дані з попереднього up):
docker compose run --rm web python manage.py seed_demo_data
```

!!! note "`--force` у entrypoint.sh"
    `entrypoint.sh` запускає `seed_demo_data --force` (або `--force --reset`, якщо `SEED_DEMO_RESET=1`).
    `--force` дозволяє виконати seed навіть при `DEBUG=False`; існуючі дані він не видаляє.
    Команда ідемпотентна (`update_or_create`), тому повторний запуск не створює дублікатів.
    `--reset` спочатку видаляє demo дані, потім сідує знову.

---

## Перевірити що seed спрацював

```bash
# Швидка перевірка через shell:
docker compose exec web python manage.py shell -c "
from django.contrib.auth.models import User
from notes_app.models import Note, ChatMessage
from django.contrib.auth.models import Group

print('Users:', User.objects.count())
print('Notes:', Note.objects.count())
print('Groups:', Group.objects.count())
print('ChatMessages:', ChatMessage.objects.count())
"

# Очікуваний вивід:
# Users: 3
# Notes: 30
# Groups: 2
# ChatMessages: 30 (або більше)
# (на чистій БД; команда також сама друкує підсумок після seed)
```

```bash
# Або напряму у PostgreSQL:
docker compose exec db psql -U notes_user -d notes_db -c "
SELECT username FROM auth_user WHERE username LIKE 'demo_%';
"
#  demo_alice
#  demo_bob
#  demo_carol
```

---

## Тестування групових функцій з двома акаунтами

Seed дозволяє тестувати реальні сценарії:

### Сценарій: групова нотатка

```
1. Браузер 1: залогінись як demo_alice
2. Браузер 2 (або Private): залогінись як demo_bob
3. Alice: відкрий нотатку з групи "Команда розробки"
4. Bob: відкрий ту саму нотатку (видна через group membership)
```

### Сценарій: груповий чат у реальному часі

```
1. Браузер 1: demo_alice → Groups → "Команда розробки" → Chat
2. Браузер 2: demo_bob → Groups → "Команда розробки" → Chat
3. Alice: введи повідомлення → Enter
4. Bob: повідомлення з'являється миттєво (WebSocket!)
```

### Сценарій: ізоляція даних

```
1. demo_carol: намагається відкрити особисту нотатку demo_alice
2. → 404 (нотатка не належить carol і не прив'язана до спільної групи)
3. demo_bob: намагається відкрити нотатку demo_alice
4. → 404 якщо особиста нотатка, 200 якщо з "Команди розробки"
```

---

## `.env` конфігурація для dev

```bash
# .env (скопіюй з .env.example)

POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=notes_password_dev

SECRET_KEY=dev-secret-key-not-for-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db

# Seed demo data при кожному docker compose up:
SEED_DEMO_DATA=1

# ngrok (потрібен тільки для публічного доступу)
NGROK_AUTHTOKEN=          # отримати на ngrok.com
NGROK_DOMAIN=             # твій static domain (ngrok free tier: 1 static domain)
```

Скопіювати шаблон:

```bash
cp .env.example .env
# Відредагуй: додати NGROK_AUTHTOKEN і NGROK_DOMAIN якщо потрібно
```

---

## Debugging: коли seed не спрацьовує

### `CommandError: Demo data disabled`

```
CommandError: Demo data seeding is disabled when DEBUG=False. Use --force to override.
```

**Причина:** `seed_demo_data` перевіряє `DEBUG = True`. У production він вимкнений за замовчуванням щоб не перезаписати реальні дані.

**Рішення:** `entrypoint.sh` вже передає `--force`, тому ця помилка виникає тільки при ручному запуску без прапору.

```bash
# Правильно для ручного запуску при DEBUG=False:
docker compose exec web python manage.py seed_demo_data --force
```

### `IntegrityError: duplicate key`

Поточна команда ідемпотентна: вона використовує `update_or_create`, тому повторний запуск без `--reset` **не** дає цієї помилки. Вона можлива лише у власних seed-командах, що використовують `create()`, або якщо дані змінені вручну:

```
django.db.utils.IntegrityError: duplicate key value violates unique constraint
"auth_user_username_key"
DETAIL: Key (username)=(demo_alice) already exists.
```

**Рішення:**
```bash
docker compose exec web python manage.py seed_demo_data --reset
# --reset видаляє існуючих demo_ юзерів перед створенням нових
```

### БД не ініціалізована

```
django.db.utils.OperationalError: could not connect to server
```

**Причина:** спробував запустити seed перед `docker compose up` або після `docker compose down -v`.

**Рішення:**
```bash
docker compose up -d
# Дочекатись поки web container стане healthy
docker compose ps    # web: healthy?
docker compose exec web python manage.py seed_demo_data
```

---

## Demо облікові записи після seed

Після успішного seed можна відкрити `http://localhost` і залогінитись:

```
http://localhost/accounts/login/
  Username: demo_alice
  Password: demo1234
```

Alice бачить:
- Особисті нотатки з різними пріоритетами і тегами
- Закріплені нотатки вгорі списку
- Групові нотатки "Команди розробки" (свої й інших учасників)
- Todo списки з кількома задачами
- Shopping lists з продуктами
- Групові чати обох груп з history повідомлень

---

## У книзі

- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker, docker compose, volume management
- [Частина XI. Deployment](../../11_deployment/README.md) — production deploy, environment variables, `.env` файли

---

## Офіційна документація

- [Django: Management Commands](https://docs.djangoproject.com/en/5.2/howto/custom-management-commands/) — як писати свої management команди
- [Django: Fixtures vs management commands](https://docs.djangoproject.com/en/5.2/howto/initial-data/) — різниця між fixtures і custom seed commands
