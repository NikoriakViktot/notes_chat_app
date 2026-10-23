# Selenium in Docker

> **Difference from the previous steps:** here Selenium runs in a separate container
> (not locally). The Django test server and Chrome are in different containers — a special configuration is needed.

---

## Problem: localhost ≠ localhost between containers

```
WITHOUT Docker Selenium (previous steps):
  Runner VM: Django test server (localhost:PORT) + Chrome (localhost:PORT) ✓
  Chrome sees Django at localhost → OK

With Docker Selenium:
  web container: Django test server (localhost:PORT)
  selenium container: Chrome
    Chrome: http://localhost:PORT → NOT FOUND!
    localhost in the selenium container = the IP of the selenium container itself
    NOT the IP of the web container!
```

---

## The Selenium service in docker-compose.yml

```yaml
selenium:
  image: selenium/standalone-chrome:latest
  ports:
    - "4444:4444"    # WebDriver API (used by test_selenium.py)
    - "7900:7900"    # VNC (you can watch the browser live: http://localhost:7900)
  shm_size: '2g'     # Chrome needs shared memory
  networks: [app-net]
```

`selenium/standalone-chrome` is the official Selenium image with Chrome built in. It runs `selenium-server` on port `4444`, which `webdriver.Remote` connects to.

`shm_size: '2g'` — Chrome uses shared memory (`/dev/shm`) for rendering. Without it, Chrome crashes when opening complex pages.

Environment variables in the `web` service for Selenium:

```yaml
web:
  environment:
    WEB_HOST:            web              # DNS name of the web container
    SELENIUM_REMOTE_URL: http://selenium:4444/wd/hub
```

---

## StaticLiveServerTestCase with a Remote driver

### Solution: `_DockerLiveServerMixin`

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Lets Selenium in a Docker container see the Django test server.

    Problem: LiveServerTestCase usually binds to 127.0.0.1 (localhost only).
    Solution: bind to 0.0.0.0 (all interfaces) → reachable from the selenium container.

    Also replaces 0.0.0.0 with "web" in live_server_url:
    http://0.0.0.0:PORT → http://web:PORT
    "web" is the DNS name of the web container in the Docker network app-net.
    """
    host = '0.0.0.0'   # StaticLiveServerTestCase.host

    @property
    def live_server_url(self):
        url = super().live_server_url           # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')  # = "web" (from the docker-compose.yml env)
        if web_host:
            return url.replace('0.0.0.0', web_host)  # http://web:PORT
        return url


def _make_driver():
    """Returns a Chrome WebDriver: Remote (Docker) or local."""
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = http://selenium:4444/wd/hub (from docker-compose.yml env web.environment)

    if remote_url:
        # Docker: Chrome runs in the selenium container
        options = webdriver.ChromeOptions()
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        # headless is not needed: selenium/standalone-chrome is already headless
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        # Locally (without Docker): Chrome on the same machine
        options = webdriver.ChromeOptions()
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        return webdriver.Chrome(options=options)


@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(_DockerLiveServerMixin, StaticLiveServerTestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)  # wait up to 5 sec for an element

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def _login_via_cookie(self):
        """Fast login via the session cookie (without the form)."""
        # 1. The Test Client creates a session in the DB
        self.client.force_login(self.user)
        session_cookie = self.client.cookies['sessionid']

        # 2. The browser must be on the domain before add_cookie
        self.driver.get(f'{self.live_server_url}/')

        # 3. Copy the session cookie into Selenium
        self.driver.add_cookie({
            'name': 'sessionid',
            'value': session_cookie.value,
            'path': '/',
        })
        # Now the driver is logged in = the same user as self.client
```

---

## Running with `docker compose exec` (not `run`!)

```bash
# ❌ WRONG — docker compose run:
docker compose run --rm web python manage.py test notes_app.tests.test_selenium
# run creates a NEW container
# The new container does not have the DNS alias "web" in the network
# Selenium tries GET http://web:8001/... → Cannot resolve host

# ✅ CORRECT — docker compose exec:
docker compose up -d   # bring the stack up first
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec runs INSIDE the already running web container
# the web container is already registered in the Docker network with the alias "web"
# Selenium: GET http://web:8001/ → DNS resolution → IP of the web container
```

---

## Why `exec` and not `run`

`docker compose run` creates a **new** container from the same image. This container:
- Has no registered DNS alias `"web"` in the `app-net` network (that alias is bound to the original running container)
- Runs its own `entrypoint.sh` (migrate, collectstatic all over again)
- Is isolated from selenium, nginx and the other services of the stack

`docker compose exec` runs the command **inside** the already running `web` container. This container:
- Is already registered with the alias `"web"` in the Docker network
- Selenium in the `selenium` container resolves `http://web:PORT` → the IP of this container
- No repeated migrations or seeding

---

## VNC — watch the Selenium browser live

```bash
# http://localhost:7900  (password: secret)
# ↑ Opens a VNC viewer where you can see Chrome in real time
```

Useful for debugging Selenium tests:
- You see exactly what the driver finds
- You see the state of forms when errors occur
- You see JavaScript alerts and popups
- You understand why `find_element` cannot find an element

---

## Running all tests

```bash
# ─── Through Docker (recommended) ──────────────────────────────────────────

# All unit + integration + consumer tests (run is fine here):
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# Selenium E2E tests (EXEC, not RUN!):
docker compose up -d                    # bring the stack up first
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# A specific class:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# Stop at the first failure:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Coverage:
docker compose run --rm web sh -c "
  coverage run manage.py test notes_app.tests.test_models notes_app.tests.test_services \
    notes_app.tests.test_forms notes_app.tests.test_views notes_app.tests.test_consumers
  coverage report --show-missing
"
```

---

## In the book

- [Part VIII. Testing and Quality](../../08_testing_and_quality/README.md) — the test pyramid, Selenium E2E, StaticLiveServerTestCase, WebDriver API
- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker networking, DNS between containers, `exec` vs `run`

---

## Official documentation

- [Selenium: Remote WebDriver](https://www.selenium.dev/documentation/webdriver/drivers/remote_webdriver/) — connecting to Selenium Grid / standalone
- [Selenium: standalone-chrome Docker image](https://github.com/SeleniumHQ/docker-selenium) — `shm_size`, VNC on :7900
- [Django: StaticLiveServerTestCase](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#django.test.LiveServerTestCase) — live server host, port, URL
- [Django: Testing tools](https://docs.djangoproject.com/en/5.2/topics/testing/tools/) — force_login, Client.cookies, session management in tests
