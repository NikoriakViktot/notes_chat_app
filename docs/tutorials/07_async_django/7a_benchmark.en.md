# 7A. Benchmark and testing

---

## Tests: sync vs async

### Running the tests

```bash
# Only the original sync tests (129 tests)
python manage.py test hello_app.tests.test_views -v 2

# Only the new async tests
python manage.py test hello_app.tests.test_async_views -v 2

# All tests together (sync + async)
python manage.py test hello_app -v 1

# A specific async class
python manage.py test hello_app.tests.test_async_views.AsyncNoteListViewTest -v 2

# Stop at the first failure
python manage.py test hello_app --failfast -v 2
```

### Key differences in async tests

Open side by side:
- `hello_app/tests/test_views.py`: sync tests (NoteListViewTest)
- `hello_app/tests/test_async_views.py`: async tests (AsyncNoteListViewTest)

```python
# test_views.py: a sync test
class NoteListViewTest(TestCase):

    def setUp(self):
        # Sync ORM is always OK in setUp
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
# test_async_views.py: an async test
class AsyncNoteListViewTest(TestCase):  # TestCase (not AsyncTestCase)

    def setUp(self):
        # setUp is sync, ORM without await is OK
        self.alice = User.objects.create_user('alice_async', password='pass123')

    async def test_redirects_to_login(self):
        client = AsyncClient()                  # AsyncClient instead of self.client
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

### Comparison table: sync vs async tests

| Concept | Sync test | Async test |
|-----------|-----------|------------|
| Base class | `TestCase` | `TestCase` (the same!) |
| setUp | `def setUp(self)` | `def setUp(self)` (sync!) |
| test_ methods | `def test_*(self)` | `async def test_*(self)` |
| HTTP client | `self.client` | `AsyncClient()` |
| GET request | `self.client.get(url)` | `await client.get(url)` |
| Login | `self.client.force_login(user)` | `await client.force_login(user)` |
| ORM in a test | `Note.objects.create(...)` | `await sync_to_async(Note.objects.create)(...)` |

> **Why TestCase and not AsyncTestCase?**
> `AsyncTestCase` is a subclass of `SimpleTestCase` and does not support transactions.
> `TestCase` wraps each test in a transaction (rollback after the test).
> Django 4.1+ supports `async def test_*` in a regular `TestCase`.
> That is why we use `TestCase` with `async def test_*` methods.

---

## Postman / browser: how to test

### Testing in the browser

**Step 1:** Start both servers at the same time

```bash
# Terminal 1 (sync)
python manage.py runserver

# Terminal 2 (async)
uvicorn notes_project.asgi:application --reload --port 8001
```

**Step 2:** Sign up or log in at http://127.0.0.1:8000/

**Step 3:** Open both URLs in different tabs

```
Tab 1: http://127.0.0.1:8000/notes/           ← sync
Tab 2: http://127.0.0.1:8001/async/notes/     ← async
```

**Step 4:** Create a note through sync (/notes/new/) and check that it is visible in async (/async/notes/).

> Both servers connect to the same db.sqlite3, so the data is shared.

### Testing in Postman

> **What is a CSRF token?**
> CSRF (Cross-Site Request Forgery) protection guards against forged cross-site requests.
> Django checks a special token in every POST request.
> A browser gets the token automatically through a cookie. With Postman you have to do it by hand.

**Step 1:** Get the CSRF token with a GET request in Postman

Django sets the `csrftoken` cookie on the first GET request to any page.

```
GET http://127.0.0.1:8000/
```

In the response Postman shows a **Cookies** tab:
- Find the cookie named `csrftoken`
- Copy its value (a long string of letters and digits)

Or through the browser (if it is already open):
- F12 → Application → Cookies → http://127.0.0.1:8000
- Copy the `csrftoken` value

> Django automatically includes the cookie manager in Postman (Settings → Cookies).
> After the first GET request, the `csrftoken` cookie appears in Postman's Cookie Jar.

**Step 2:** Log in through Postman

```
POST http://127.0.0.1:8000/accounts/login/
Content-Type: application/x-www-form-urlencoded
Body (x-www-form-urlencoded):
  username      alice
  password      pass123
  csrfmiddlewaretoken   <csrftoken value from step 1>
```

After a successful login:
- Postman saves the `sessionid` cookie automatically (through the Cookie Jar)
- Response status: 302 Redirect (to the home page)

**Step 3:** GET the list of async notes

```
GET http://127.0.0.1:8001/async/notes/
```

Postman automatically sends the `sessionid` and `csrftoken` cookies (from the Cookie Jar).
You will see an HTML page with the list of notes.

**Step 4:** POST to create a note through the async view

```
POST http://127.0.0.1:8001/async/notes/create/
Content-Type: application/x-www-form-urlencoded
Headers:
  X-CSRFToken    <csrftoken value>
Body (x-www-form-urlencoded):
  title         Test note via Postman
  content       Note content
  priority      1
```

---

## Benchmark: what you can and cannot measure

### What you should NOT expect

```bash
# ❌ A single request proves nothing
curl http://127.0.0.1:8000/notes/        # Sync: 45ms
curl http://127.0.0.1:8001/async/notes/  # Async: 48ms
# "Async is slower!" is a WRONG conclusion
```

Async has overhead from the event loop. For a single request, sync can be faster.

### What actually shows the difference

The difference becomes visible under **concurrent load** (50+ simultaneous requests):

```bash
# 1000 requests, 50 concurrent (requires apache-httpd or apache2-utils)
ab -n 1000 -c 50 http://127.0.0.1:8000/notes/         # sync
ab -n 1000 -c 50 http://127.0.0.1:8001/async/notes/   # async
```

> **Note:** SQLite is not an ideal DB for an async performance benchmark.
> SQLite has a global write lock. For a real async benchmark
> use PostgreSQL with a connection pool.

### Locust for a learning benchmark

```bash
pip install locust
```

Create `locustfile.py` next to `manage.py`:

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
# Open http://localhost:8089 and start the test
```

---

## Docker Compose: an isolated run

### Why Docker for this project

Without Docker, Python adds every package from `.venv` to `sys.path`. If one workspace
contains several Django projects with the same package names (`notes_project`, `notes_app`),
Python may load **the wrong project**. Docker solves this once and for all:
the container has only `/app` in `sys.path`, with no third-party packages from elsewhere.

```
Without Docker:                     With Docker:
sys.path = [                        sys.path = [
  lesson_Django_authentication/..., ← /app ← only notes_chat_app
  lesson_Django_Async/...,          ]
  ...                               WORKDIR /app → ENV PYTHONPATH=/app
]
```

### Docker Compose structure

```yaml
# docker-compose.yml
services:
  web:       ← Django + Uvicorn (port 8001)
  selenium:  ← Selenium Grid + Chrome (port 4444, for E2E tests)
```

| Service | Image | Role |
|--------|-------|------|
| `web` | Dockerfile (python:3.12-slim) | Django ASGI server |
| `selenium` | `selenium/standalone-chrome` | Headless Chrome for E2E tests |

### Running it

```powershell
# Go to the project folder (PowerShell / CMD)
cd C:\Users\victo\PycharmProjects\PY-Course-Victor-Nikoriak-23_02\module_5\lesson_Django_Async\notes_chat_app

# Build + start (the first time takes ~3-5 min)
docker compose up --build

# Or in the background
docker compose up --build -d
```

On the first start `entrypoint.sh` automatically runs:
1. `python manage.py migrate`: applies all migrations
2. `python manage.py collectstatic --noinput`: collects static files
3. Starts `uvicorn` on port `8001`

### Useful commands

```powershell
# View the logs
docker compose logs -f web

# Open a shell inside the container
docker compose exec web bash

# Run any Django command
docker compose exec web python manage.py shell
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py migrate

# Stop
docker compose down

# Stop and delete volumes (reset the DB)
docker compose down -v
```

### Tests in Docker

```powershell
# All tests (200+ unit/integration + 20+ Selenium E2E through Remote Chrome)
docker compose exec web python manage.py test --verbosity=2

# Only unit tests (without Selenium)
docker compose exec web python manage.py test notes_app.tests.test_models notes_app.tests.test_services notes_app.tests.test_forms notes_app.tests.test_views notes_app.tests.test_consumers notes_app.tests.test_tasks -v 2

# Only Selenium (requires the selenium service to be running)
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# Only the WebSocket consumer tests
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

**How the Selenium E2E tests work in Docker:**

```
web container              selenium container
───────────────            ──────────────────
LiveServerTestCase         selenium/standalone-chrome
  binds 0.0.0.0:PORT  ←── Chrome opens http://web:PORT/...
  (all interfaces)         (Docker internal network)

env: WEB_HOST=web          ← _DockerLiveServerMixin substitutes it into live_server_url
env: SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub  ← Remote WebDriver
```

`_DockerLiveServerMixin` in `test_selenium.py` automatically:
- Binds the test server to `0.0.0.0` (reachable from the selenium container)
- Replaces `0.0.0.0` with `web` in `live_server_url` if `WEB_HOST` is set

### New Docker files

| File | Role |
|------|------|
| `Dockerfile` | Image: python:3.12-slim + package installation |
| `docker-compose.yml` | Services: web + selenium |
| `entrypoint.sh` | migrate → collectstatic → uvicorn on startup |
| `.dockerignore` | Excludes .venv, __pycache__, staticfiles, db.sqlite3 |

```dockerfile
# Dockerfile: the key lines
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONPATH=/app DJANGO_SETTINGS_MODULE=notes_project.settings
RUN pip install -r requirements.txt
CMD ["./entrypoint.sh"]
```

```sh
# entrypoint.sh: runs on every docker compose up
python manage.py migrate --noinput
python manage.py collectstatic --noinput
exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --reload
```

### URLs available after docker compose up

| URL | What it is |
|-----|-------|
| http://localhost:8001/ | Django (dashboard) |
| http://localhost:8001/groups/ | Group list |
| http://localhost:8001/groups/`<pk>`/chat/ | Group chat |
| http://localhost:8001/async/notes/ | Async views |
| http://localhost:4444 | Selenium Grid UI (for debugging) |

---

## 7A summary: what we did

| Step | File | Result |
|------|------|-----------|
| 1 | `requirements.txt` | Added uvicorn, httpx |
| 2 | `settings.py` | Comments about ASGI, CONN_MAX_AGE=0 |
| 3 | `asgi.py` | Teaching comments about the uvicorn command |
| 4 | `async_selectors.py` | Lazy QuerySets + aget() |
| 5 | `async_services.py` | sync_to_async + adelete + aupdate + F() |
| 6 | `async_views.py` | 5 async def views with detailed comments |
| 7 | `urls.py` | `/async/notes/` URL prefix |
| 8 | `tests/test_async_views.py` | AsyncClient tests, sync vs async comparison |

### Official documentation

| Topic | Link |
|------|-----------|
| Django async views | https://docs.djangoproject.com/en/5.2/topics/async/ |
| Django async ORM | https://docs.djangoproject.com/en/5.2/ref/models/querysets/#async-queries |
| sync_to_async | https://docs.djangoproject.com/en/5.2/topics/async/#asgiref-sync |
| Django async testing | https://docs.djangoproject.com/en/5.2/topics/testing/tools/#asynchronous-tests |
| Uvicorn | https://uvicorn.dev/ |
| httpx | https://www.python-httpx.org/ |
| asgiref | https://github.com/django/asgiref |
| asyncio (Python docs) | https://docs.python.org/3/library/asyncio.html |

> **Async Django is a tool, not a coding style.**
>
> Sync Django suits most projects: CRUD, admin, a blog, an API.
> Async Django is justified when there is a **real I/O bottleneck**:
> parallel external API requests, WebSockets, streaming, high concurrency.
>
> This learning project shows the same result
> with two different architectures. Choose according to the task.

### Practical exercise: compare the results in the browser

1. Start both servers
2. Create a note through `/notes/new/`
3. Check that it is visible through `/async/notes/`
4. Delete the note through `/async/notes/<pk>/delete/`
5. Check that it is gone through `/notes/`

### Practical exercise: write an async test

In `test_async_views.py` add a test that checks:
- POST to `/async/notes/create/` without `title` → 200 (form with errors)
- POST to `/async/notes/create/` with `title` → 302 (redirect)

---

## Next

Next chapter: **[7B. The WebSocket protocol](7b_websocket_protocol.md)**: why HTTP is not suitable for chat, the WebSocket handshake, the asyncio event loop.
