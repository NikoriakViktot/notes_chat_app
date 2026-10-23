# Testing Strategy

Тести знаходяться у `notes_app/tests/`.

---

## Тестові модулі

| Файл | Базовий клас | Що тестує |
|------|-------------|-----------|
| `test_models.py` | `TestCase` | constraints, `__str__`, deletion behavior (CASCADE/SET_NULL) |
| `test_services.py` | `TestCase` | create/update/delete операції, security (масове призначення тегів), бізнес-правила |
| `test_forms.py` | `TestCase` | валідація, scoped queryset у form fields (Tag, Notebook для поточного user) |
| `test_views.py` | `TestCase` | HTTP статуси, redirect, IDOR захист, `force_login` |
| `test_consumers.py` | `TransactionTestCase` | WebSocket connect, receive, disconnect, auth |
| `test_tasks.py` | `TestCase` | Celery-задача нагадувань, email, повторення, JSON endpoint |
| `test_selenium.py` | `StaticLiveServerTestCase` / `ChannelsLiveServerTestCase` | E2E browser flows через Chrome |

---

## Чому `TransactionTestCase` для consumers

`TestCase` загортає кожен тест у транзакцію (SAVEPOINT / ROLLBACK).  
`database_sync_to_async` запускає ORM у окремому worker thread.  
Цей thread **не бачить** незакомічену транзакцію `TestCase` → setUp-об'єкти "зникають".

`TransactionTestCase` не загортає → всі потоки бачать дані.

`setUp` у `TransactionTestCase` — **sync**, не async: Django test cases не викликають `asyncSetUp` (це API `unittest.IsolatedAsyncioTestCase`), тому підготовку даних робимо у звичайному `setUp`, навіть коли самі тести `async def`.

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

### Selenium E2E

```bash
docker compose up -d
docker compose exec web python manage.py test \
  notes_app.tests.test_selenium \
  -v 2
```

!!! warning "exec, не run"
    Selenium контейнер звертається до `web` контейнера за мережевим аліасом `web`.  
    `docker compose run --rm web` створює **окремий** контейнер без цього аліасу.

### Усі тести (крім Selenium)

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers notes_app.tests.test_tasks -v 2
```

---

## Що покривається

| Тема | Де |
|------|----|
| Deletion behavior (CASCADE/SET_NULL) | `test_models.py` |
| IDOR: неможливість доступу до чужої нотатки | `test_views.py`, `test_services.py` |
| Mass assignment: tag filtering по user | `test_services.py` |
| Form queryset scoping (Tag, Notebook) | `test_forms.py` |
| WebSocket auth (анонімний → close 4003) | `test_consumers.py` |
| WebSocket group membership check | `test_consumers.py` |
| E2E: login, create note, chat | `test_selenium.py` |

---

## CI

GitHub Actions: `.github/workflows/django-tests.yml`.

Watches: `notes_app/**`, `notes_project/**`.

Job 1 (unit+integration) → Job 2 (Selenium, тільки якщо Job 1 ✅).
