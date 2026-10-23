# test_selenium.py — E2E tests through the browser

---

## What Selenium tests (and what unit tests can't)

```
Django Test Client (integration):         Selenium (E2E):
  ✓ HTTP statuses                          ✓ JavaScript behavior
  ✓ HTML content (assertContains)          ✓ CSS visibility of elements
  ✓ Redirect                               ✓ Form submit via a button
  ✓ Template context                       ✓ WebSocket connection in the browser
  ✗ JavaScript events                      ✓ Bootstrap dropdown
  ✗ CSS display:none                       ✓ Real navigation between pages
  ✗ form.submit() via a button             ✓ Ajax requests
  ✗ WebSocket in the browser               ✗ Very slow (~10s/test)
```

### Why there are few Selenium tests

```
Unit test: 0.01s  ×  100 = 1 second
Selenium:  10s    ×  100 = 16 minutes

+ Selenium is brittle: changing a CSS class breaks a test even if the logic is correct
+ It needs geckodriver or chromedriver, a specific browser version
+ It is unstable in CI without implicitly_wait

Rule: E2E tests only for CRITICAL user flows.
      Everything else — unit/integration.
```

---

## `StaticLiveServerTestCase` — a real server

```python
from django.contrib.staticfiles.testing import StaticLiveServerTestCase

class MySeleniumTest(StaticLiveServerTestCase):
    def test_something(self):
        self.live_server_url  # → 'http://127.0.0.1:PORT' (random port)
        self.driver.get(f'{self.live_server_url}/notes/')
```

`StaticLiveServerTestCase` starts a real Django HTTP server on a temporary port. Selenium connects to it like a real browser.

---

## Skipping tests if Selenium is not installed (`@skipUnless`)

```python
try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False


@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class MySeleniumTest(StaticLiveServerTestCase):
    ...
```

If `selenium` is not installed → the tests are marked as `s` (skipped) and **do not fail**:

```
...........ssssss
Ran 129 tests in 90.2s
OK (skipped=6)   ← a green result even without Selenium!
```

This matters: `manage.py test` should always return `OK`, even without geckodriver.

---

## Selenium in Docker — the architecture

```
[test runner — web container]
  │
  │ HTTP  →  StaticLiveServerTestCase  →  Django live server :PORT
  │
  │ WebDriver protocol  →  http://selenium:4444/wd/hub
  │                            │
  │                     [selenium container]
  │                       standalone-chrome
  │                            │
  │                     Chrome → GET http://web:PORT/
  │
  │ ← DOM / assertions
```

**The key problem without the Docker adaptation:** `localhost` in the Chrome container ≠ `localhost` in the test runner.
**Solution:** bind to `0.0.0.0`, Chrome connects via `http://web:PORT`.

---

## `_DockerLiveServerMixin` — adapting for Docker

```python
class _DockerLiveServerMixin:
    """
    Adapts StaticLiveServerTestCase to work with Selenium in Docker.

    Problem: LiveServerTestCase binds to 127.0.0.1 by default.
    In Docker: the selenium container cannot reach 127.0.0.1 of the web container.

    Solution:
      1. host = '0.0.0.0' → bind to all interfaces
      2. live_server_url: replace '0.0.0.0' with 'web' (Docker DNS)
         http://0.0.0.0:PORT → http://web:PORT

    WEB_HOST env var: docker-compose.yml → web.environment.WEB_HOST = "web"
    Without Docker (locally): WEB_HOST is not set → the url stays localhost
    """
    host = '0.0.0.0'

    @property
    def live_server_url(self):
        url = super().live_server_url   # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')
        if web_host:
            return url.replace('0.0.0.0', web_host)   # http://web:PORT
        return url
```

---

## `_make_driver()` — a WebDriver for Docker and local runs

```python
def _make_driver():
    """
    Returns a Chrome WebDriver depending on the environment:
      - SELENIUM_REMOTE_URL is set → Remote WebDriver (Docker selenium container)
      - Not set → local Chrome (headless)
    """
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = 'http://selenium:4444/wd/hub' (from docker-compose.yml)

    options = webdriver.ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    # --disable-dev-shm-usage: Chrome in Docker uses /tmp instead of /dev/shm
    # (by default /dev/shm in Docker = 64MB → Chrome crashes)

    if remote_url:
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        options.add_argument('--headless')   # locally: no GUI window
        return webdriver.Chrome(options=options)
```

---

## The Session Cookie Trick — logging in without the form

```python
def _login_via_cookie(self, user):
    """
    Logging in without filling in the login form in the browser.
    Much faster and more reliable than filling in the form.

    Method:
    1. The Test Client (server side) creates a session in the test database
    2. We copy the sessionid cookie into Selenium Chrome
    3. Chrome sends this cookie → Django considers Chrome logged in

    Why:
    - The login form may have CSRF, JS validation, a reCAPTCHA
    - The session cookie trick is always reliable
    - Faster: 1 HTTP request instead of the form
    """
    self.client.force_login(user)                     # ← server: session in the database
    session_cookie = self.client.cookies['sessionid'] # ← extract the cookie value

    # Chrome must be on our domain before add_cookie
    self.driver.get(f'{self.live_server_url}/')        # ← any URL of the site

    self.driver.add_cookie({
        'name':  'sessionid',
        'value': session_cookie.value,
        'path':  '/',
    })
    # Now Chrome is logged in as user ✓
```

---

## Structure of test_selenium.py

```python
# notes_app/tests/test_selenium.py
import os
import unittest

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

from django.contrib.auth.models import User
from django.contrib.staticfiles.testing import StaticLiveServerTestCase


class _DockerLiveServerMixin:
    host = '0.0.0.0'

    @property
    def live_server_url(self):
        url = super().live_server_url
        web_host = os.environ.get('WEB_HOST')
        if web_host:
            return url.replace('0.0.0.0', web_host)
        return url


def _make_driver():
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    options = webdriver.ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    if remote_url:
        return webdriver.Remote(command_executor=remote_url, options=options)
    else:
        options.add_argument('--headless')
        return webdriver.Chrome(options=options)


@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(_DockerLiveServerMixin, StaticLiveServerTestCase):
    """E2E test: login form → dashboard."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)   # wait up to 5 sec for an element

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def setUp(self):
        self.user = User.objects.create_user(
            username='alice', password='testpass123'
        )

    def _login_via_cookie(self, user):
        self.client.force_login(user)
        session_cookie = self.client.cookies['sessionid']
        self.driver.get(f'{self.live_server_url}/')
        self.driver.add_cookie({
            'name':  'sessionid',
            'value': session_cookie.value,
            'path':  '/',
        })

    def test_login_form_and_redirect(self):
        """Filling in the login form → redirect to /notes/."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # After a successful login → redirect to /notes/
        WebDriverWait(self.driver, 5).until(
            EC.url_contains('/notes/')
        )
        self.assertIn('/notes/', self.driver.current_url)

    def test_dashboard_shows_username(self):
        """After login the navbar shows the username."""
        self._login_via_cookie(self.user)
        self.driver.get(f'{self.live_server_url}/notes/')

        page_text = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertIn('alice', page_text)

    def test_invalid_login_shows_error(self):
        """Wrong password → the form with an error."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('wrongpassword')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # We stayed on the login page (no redirect)
        self.assertIn('/accounts/login/', self.driver.current_url)

        body = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertTrue(
            'Невірний' in body or 'Please enter' in body or 'wrong' in body.lower()
        )
```

---

## Running without Docker and through Docker

```bash
# ── Without Docker (crispy_notes_project) ─────────────────────────────────────
# 1. Install selenium
pip install selenium

# 2. Download geckodriver for Firefox or chromedriver for Chrome
#    https://github.com/mozilla/geckodriver/releases
#    → unpack it and add it to PATH

# 3. Run
python manage.py test hello_app.tests.test_selenium -v 2

# If selenium is NOT installed:
python manage.py test hello_app.tests -v 1
# → ...........ssssss
# → OK (skipped=6)


# ── notes_chat_app: through Docker ────────────────────────────────────────────
# Important: Selenium tests need a RUNNING container with the DNS alias "web"
# That's why we use exec (inside the running container), not run (a new container)

# 1. Bring up the stack (including the selenium service)
docker compose up -d

# 2. Run the tests via exec
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec → runs inside the RUNNING container that has the DNS alias "web"
# run  → a NEW container without the "web" alias → Selenium cannot find the Django server!

# 3. If needed -- check the selenium container
docker compose ps selenium
# Selenium is available at http://localhost:7900 (VNC, optional)
```

---

## Headless mode

```python
from selenium.webdriver.firefox.options import Options

options = Options()
options.add_argument('--headless')  # no GUI window
driver = webdriver.Firefox(options=options)
```

**headless** = the browser runs without a graphical interface. It is needed for:
- CI/CD servers (GitHub Actions, Jenkins, Docker) — they have no display
- Speed — no need to render pixels on a screen

---

## Next

- **[GitHub Actions CI](ci_github_actions.md)** — the workflow line by line, jobs, results
