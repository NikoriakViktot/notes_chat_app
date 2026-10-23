# Testing Strategy

The tests live in `notes_app/tests/`.

---

## Test modules

| File | Base class | What it tests |
|------|-------------|-----------|
| `test_models.py` | `TestCase` | constraints, `__str__`, deletion behavior (CASCADE/SET_NULL) |
| `test_services.py` | `TestCase` | create/update/delete operations, security (mass assignment of tags), business rules |
| `test_forms.py` | `TestCase` | validation, scoped querysets in form fields (Tag, Notebook for the current user) |
| `test_views.py` | `TestCase` | HTTP status codes, redirects, IDOR protection, `force_login` |
| `test_consumers.py` | `TransactionTestCase` | WebSocket connect, receive, disconnect, auth |
| `test_tasks.py` | `TestCase` | the reminder Celery task, email, repeats, the JSON endpoint |
| `test_selenium.py` | `StaticLiveServerTestCase` / `ChannelsLiveServerTestCase` | E2E browser flows through Chrome |

---

## Why `TransactionTestCase` for consumers

`TestCase` wraps each test in a transaction (SAVEPOINT / ROLLBACK).  
`database_sync_to_async` runs the ORM in a separate worker thread.  
That thread **does not see** `TestCase`'s uncommitted transaction → setUp objects "disappear".

`TransactionTestCase` does not wrap tests → all threads see the data.

`setUp` in `TransactionTestCase` is **sync**, not async: Django test cases don't call `asyncSetUp` (that is a `unittest.IsolatedAsyncioTestCase` API), so data setup goes in a regular `setUp`, even when the tests themselves are `async def`.

---

## Running tests

### Unit, integration, and consumer tests

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

!!! warning "exec, not run"
    The Selenium container reaches the `web` container through the `web` network alias.  
    `docker compose run --rm web` creates a **separate** container without that alias.

### All tests (except Selenium)

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers notes_app.tests.test_tasks -v 2
```

---

## What is covered

| Topic | Where |
|------|----|
| Deletion behavior (CASCADE/SET_NULL) | `test_models.py` |
| IDOR: no access to someone else's note | `test_views.py`, `test_services.py` |
| Mass assignment: tag filtering by user | `test_services.py` |
| Form queryset scoping (Tag, Notebook) | `test_forms.py` |
| WebSocket auth (anonymous → close 4003) | `test_consumers.py` |
| WebSocket group membership check | `test_consumers.py` |
| E2E: login, create note, chat | `test_selenium.py` |

---

## CI

GitHub Actions: `.github/workflows/django-tests.yml`.

Watches: `notes_app/**`, `notes_project/**`.

Job 1 (unit+integration) → Job 2 (Selenium, only if Job 1 ✅).
