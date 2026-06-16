# 7A. Benchmark та тестування

---

## Тести: sync vs async

### Запуск тестів

```bash
# Тільки оригінальні sync тести (129 тестів)
python manage.py test hello_app.tests.test_views -v 2

# Тільки нові async тести
python manage.py test hello_app.tests.test_async_views -v 2

# Всі тести разом (sync + async)
python manage.py test hello_app -v 1

# Конкретний async клас
python manage.py test hello_app.tests.test_async_views.AsyncNoteListViewTest -v 2

# Зупинитись на першому провалі
python manage.py test hello_app --failfast -v 2
```

### Ключові відмінності async тестів

Відкрий поруч:
- `hello_app/tests/test_views.py` — sync тести (NoteListViewTest)
- `hello_app/tests/test_async_views.py` — async тести (AsyncNoteListViewTest)

```python
# test_views.py — sync тест
class NoteListViewTest(TestCase):

    def setUp(self):
        # Sync ORM — завжди ОК у setUp
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_redirects_to_login(self):
        # Sync HTTP request
        response = self.client.get(reverse('hello_app:note_list'))
        self.assertEqual(response.status_code, 302)

    def test_auth_user_gets_200(self):
        self.client.force_login(self.alice)   # sync login
        response = self.client.get(reverse('hello_app:note_list'))
        self.assertEqual(response.status_code, 200)
```

```python
# test_async_views.py — async тест
class AsyncNoteListViewTest(TestCase):  # TestCase (не AsyncTestCase)

    def setUp(self):
        # setUp — sync, ORM без await — ОК
        self.alice = User.objects.create_user('alice_async', password='pass123')

    async def test_redirects_to_login(self):
        client = AsyncClient()                  # AsyncClient замість self.client
        response = await client.get(            # await client.get()
            reverse('hello_app:async_note_list')
        )
        self.assertEqual(response.status_code, 302)

    async def test_auth_user_gets_200(self):
        client = AsyncClient()
        await client.force_login(self.alice)    # await force_login
        response = await client.get(
            reverse('hello_app:async_note_list')
        )
        self.assertEqual(response.status_code, 200)
```

### Таблиця порівняння sync vs async тестів

| Концепція | Sync тест | Async тест |
|-----------|-----------|------------|
| Базовий клас | `TestCase` | `TestCase` (те саме!) |
| setUp | `def setUp(self)` | `def setUp(self)` (sync!) |
| test_ методи | `def test_*(self)` | `async def test_*(self)` |
| HTTP клієнт | `self.client` | `AsyncClient()` |
| GET запит | `self.client.get(url)` | `await client.get(url)` |
| Login | `self.client.force_login(user)` | `await client.force_login(user)` |
| ORM у тесті | `Note.objects.create(...)` | `await sync_to_async(Note.objects.create)(...)` |

> **Чому TestCase, а не AsyncTestCase?**
> `AsyncTestCase` — підклас `SimpleTestCase` і не підтримує транзакції.
> `TestCase` обгортає кожен тест у транзакцію (rollback після тесту).
> Django 4.1+ підтримує `async def test_*` у звичайному `TestCase`.
> Тому ми використовуємо `TestCase` з `async def test_*` методами.

---

## Postman / браузер: як тестувати

### Тестування в браузері

**Крок 1:** Запусти обидва сервери одночасно

```bash
# Terminal 1 (sync)
python manage.py runserver

# Terminal 2 (async)
uvicorn notes_project.asgi:application --reload --port 8001
```

**Крок 2:** Зареєструйся або логінься на http://127.0.0.1:8000/

**Крок 3:** Відкрий обидва URL-и в різних вкладках

```
Вкладка 1: http://127.0.0.1:8000/notes/           ← sync
Вкладка 2: http://127.0.0.1:8001/async/notes/     ← async
```

**Крок 4:** Створи нотатку через sync (/notes/new/) і перевір що вона видна в async (/async/notes/).

> Обидва сервери підключаються до одного db.sqlite3 — дані спільні.

### Тестування в Postman

> **Що таке CSRF token?**
> CSRF (Cross-Site Request Forgery) — захист від підробки запитів між сайтами.
> Django перевіряє спеціальний токен у кожному POST-запиті.
> Браузер отримує токен автоматично через cookie. Postman — треба вручну.

**Крок 1:** Отримай CSRF token через GET-запит в Postman

Django встановлює `csrftoken` cookie при першому GET-запиті до будь-якої сторінки.

```
GET http://127.0.0.1:8000/
```

У відповіді Postman покаже вкладку **Cookies**:
- Знайди cookie з назвою `csrftoken`
- Скопіюй її значення (довгий рядок із букв та цифр)

Або через браузер (якщо вже відкрито):
- F12 → Application → Cookies → http://127.0.0.1:8000
- Скопіюй значення `csrftoken`

> Django автоматично включає cookie manager в Postman (Settings → Cookies).
> Після першого GET запиту, cookie `csrftoken` з'явиться у Cookie Jar Postman.

**Крок 2:** Логін через Postman

```
POST http://127.0.0.1:8000/accounts/login/
Content-Type: application/x-www-form-urlencoded
Body (x-www-form-urlencoded):
  username      alice
  password      pass123
  csrfmiddlewaretoken   <значення csrftoken з кроку 1>
```

Після успішного логіну:
- Postman збереже cookie `sessionid` автоматично (через Cookie Jar)
- Статус відповіді: 302 Redirect (до головної сторінки)

**Крок 3:** GET список async нотаток

```
GET http://127.0.0.1:8001/async/notes/
```

Postman автоматично надішле cookies `sessionid` і `csrftoken` (з Cookie Jar).
Ти побачиш HTML-сторінку зі списком нотаток.

**Крок 4:** POST створення нотатки через async view

```
POST http://127.0.0.1:8001/async/notes/create/
Content-Type: application/x-www-form-urlencoded
Headers:
  X-CSRFToken    <значення csrftoken>
Body (x-www-form-urlencoded):
  title         Тестова нотатка через Postman
  content       Зміст нотатки
  priority      1
```

---

## Benchmark: що можна і чого не можна міряти

### Чого НЕ можна очікувати

```bash
# ❌ Один запит — нічого не доводить
curl http://127.0.0.1:8000/notes/        # Sync: 45ms
curl http://127.0.0.1:8001/async/notes/  # Async: 48ms
# "Async повільніший!" — ХИБНИЙ висновок
```

Async має overhead від event loop. Для одного запиту — sync може бути швидшим.

### Що дійсно показує різницю

Різниця видна при **конкурентному навантаженні** (50+ одночасних запитів):

```bash
# 1000 запитів, 50 одночасних (потребує apache-httpd або apache2-utils)
ab -n 1000 -c 50 http://127.0.0.1:8000/notes/         # sync
ab -n 1000 -c 50 http://127.0.0.1:8001/async/notes/   # async
```

> **Увага:** SQLite не є ідеальною БД для async performance benchmark.
> SQLite має глобальне блокування запису. Для реального async benchmark
> використовуй PostgreSQL з пулом з'єднань.

### Locust для навчального benchmark

```bash
pip install locust
```

Створи `locustfile.py` поруч з `manage.py`:

```python
from locust import HttpUser, task, between

class SyncUser(HttpUser):
    host = "http://127.0.0.1:8000"
    wait_time = between(0.1, 0.5)

    @task
    def view_notes(self):
        self.client.get("/notes/")


class AsyncUser(HttpUser):
    host = "http://127.0.0.1:8001"
    wait_time = between(0.1, 0.5)

    @task
    def view_async_notes(self):
        self.client.get("/async/notes/")
```

```bash
locust -f locustfile.py
# Відкрий http://localhost:8089 і запусти тест
```

---

## Docker Compose: ізольований запуск

### Навіщо Docker для цього проєкту

Без Docker, Python додає всі пакети з `.venv` до `sys.path`. Якщо в одному workspace
є кілька Django-проєктів з однаковими іменами пакетів (`notes_project`, `notes_app`) —
Python може завантажити **не той проєкт**. Docker вирішує це раз і назавжди:
контейнер має лише `/app` у `sys.path`, жодних сторонніх пакетів.

```
Без Docker:                         З Docker:
sys.path = [                        sys.path = [
  lesson_Django_authentication/..., ← /app ← тільки notes_chat_app
  lesson_Django_Async/...,          ]
  ...                               WORKDIR /app → ENV PYTHONPATH=/app
]
```

### Структура Docker Compose

```yaml
# docker-compose.yml
services:
  web:       ← Django + Uvicorn (порт 8001)
  selenium:  ← Selenium Grid + Chrome (порт 4444, для E2E тестів)
```

| Сервіс | Image | Роль |
|--------|-------|------|
| `web` | Dockerfile (python:3.12-slim) | Django ASGI сервер |
| `selenium` | `selenium/standalone-chrome` | Headless Chrome для E2E тестів |

### Запуск

```powershell
# Перейти до папки проєкту (PowerShell / CMD)
cd C:\Users\victo\PycharmProjects\PY-Course-Victor-Nikoriak-23_02\module_5\lesson_Django_Async\notes_chat_app

# Білд + старт (перший раз ~3-5 хв)
docker compose up --build

# Або у фоні
docker compose up --build -d
```

При першому старті `entrypoint.sh` автоматично виконує:
1. `python manage.py migrate` — застосовує всі міграції
2. `python manage.py collectstatic --noinput` — збирає статичні файли
3. Запускає `uvicorn` на порту `8001`

### Корисні команди

```powershell
# Переглянути логи
docker compose logs -f web

# Відкрити shell всередині контейнера
docker compose exec web bash

# Запустити будь-яку Django команду
docker compose exec web python manage.py shell
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py migrate

# Зупинити
docker compose down

# Зупинити і видалити томи (скинути БД)
docker compose down -v
```

### Тести в Docker

```powershell
# Всі тести (146 unit/integration + 13 Selenium E2E через Remote Chrome)
docker compose exec web python manage.py test --verbosity=2

# Тільки unit тести (без Selenium)
docker compose exec web python manage.py test notes_app.tests.test_views notes_app.tests.test_async_views notes_app.tests.test_consumers -v 2

# Тільки Selenium (вимагає selenium сервіс запущеним)
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# Тільки WebSocket consumer тести
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

**Як Selenium E2E тести працюють у Docker:**

```
web container              selenium container
───────────────            ──────────────────
LiveServerTestCase         selenium/standalone-chrome
  binds 0.0.0.0:PORT  ←── Chrome відкриває http://web:PORT/...
  (усі інтерфейси)         (Docker internal network)

env: WEB_HOST=web          ← _DockerLiveServerMixin підставляє в live_server_url
env: SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub  ← Remote WebDriver
```

`_DockerLiveServerMixin` у `test_selenium.py` автоматично:
- Bind-ить test server на `0.0.0.0` (доступний з selenium container)
- Замінює `0.0.0.0` на `web` у `live_server_url` якщо `WEB_HOST` встановлено

### Нові файли Docker

| Файл | Роль |
|------|------|
| `Dockerfile` | Образ: python:3.12-slim + встановлення пакетів |
| `docker-compose.yml` | Сервіси: web + selenium |
| `entrypoint.sh` | migrate → collectstatic → uvicorn при старті |
| `.dockerignore` | Виключає .venv, __pycache__, staticfiles, db.sqlite3 |

```dockerfile
# Dockerfile — ключові рядки
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONPATH=/app DJANGO_SETTINGS_MODULE=notes_project.settings
RUN pip install -r requirements.txt
CMD ["./entrypoint.sh"]
```

```sh
# entrypoint.sh — запускається при кожному docker compose up
python manage.py migrate --noinput
python manage.py collectstatic --noinput
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --reload
```

### Доступні URL після docker compose up

| URL | Що це |
|-----|-------|
| http://localhost:8001/ | Django (dashboard) |
| http://localhost:8001/groups/ | Список груп |
| http://localhost:8001/groups/`<pk>`/chat/ | Груповий чат |
| http://localhost:8001/async/notes/ | Async views |
| http://localhost:4444 | Selenium Grid UI (для дебагу) |

---

## Підсумок 7A: що зробили

| Крок | Файл | Результат |
|------|------|-----------|
| 1 | `requirements.txt` | Додали uvicorn, httpx |
| 2 | `settings.py` | Коментарі про ASGI, CONN_MAX_AGE=0 |
| 3 | `asgi.py` | Навчальні коментарі про uvicorn команду |
| 4 | `async_selectors.py` | Lazy QuerySets + aget() |
| 5 | `async_services.py` | sync_to_async + adelete + aupdate + F() |
| 6 | `async_views.py` | 5 async def views з детальними коментарями |
| 7 | `urls.py` | `/async/notes/` URL prefix |
| 8 | `tests/test_async_views.py` | AsyncClient тести, sync vs async порівняння |

### Офіційна документація

| Тема | Посилання |
|------|-----------|
| Django async views | https://docs.djangoproject.com/en/5.2/topics/async/ |
| Django async ORM | https://docs.djangoproject.com/en/5.2/ref/models/querysets/#async-queries |
| sync_to_async | https://docs.djangoproject.com/en/5.2/topics/async/#asgiref-sync |
| Django async testing | https://docs.djangoproject.com/en/5.2/topics/testing/tools/#asynchronous-tests |
| Uvicorn | https://uvicorn.dev/ |
| httpx | https://www.python-httpx.org/ |
| asgiref | https://github.com/django/asgiref |
| asyncio (Python docs) | https://docs.python.org/3/library/asyncio.html |

> **Async Django — це інструмент, а не стиль написання коду.**
>
> Sync Django підходить для більшості проєктів: CRUD, admin, блог, API.
> Async Django виправданий коли є **реальний I/O bottleneck**:
> паралельні зовнішні API-запити, WebSockets, streaming, high concurrency.
>
> Цей навчальний проєкт показує: один і той самий результат,
> дві різних архітектури. Вибирай відповідно до задачі.

### Практичне завдання: порівняй результати в браузері

1. Запусти обидва сервери
2. Створи нотатку через `/notes/new/`
3. Перевір що вона видна через `/async/notes/`
4. Видали нотатку через `/async/notes/<pk>/delete/`
5. Перевір що вона зникла через `/notes/`

### Практичне завдання: написати async тест

У `test_async_views.py` додай тест, що перевіряє:
- POST на `/async/notes/create/` без `title` → 200 (форма з помилками)
- POST на `/async/notes/create/` з `title` → 302 (redirect)

---

## Далі

Наступна глава: **[7B. WebSocket протокол](7b_websocket_protocol.md)** — чому HTTP не підходить для чату, WebSocket handshake, asyncio event loop.
