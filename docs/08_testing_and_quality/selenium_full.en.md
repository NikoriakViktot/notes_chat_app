# Selenium WebDriver: browser automation from your first script to Django E2E

> This file is a self-contained reference on Selenium for Python.
> From installation and your first `driver.get()` to Django's `StaticLiveServerTestCase`,
> the session cookie trick, and Remote WebDriver on GitHub Actions.
> All the code is tied to the real `test_selenium.py` in our project.

📖 Official documentation: https://selenium.dev/selenium/docs/api/py
📖 API Reference: https://selenium.dev/selenium/docs/api/py/api.html
📖 GitHub: https://github.com/SeleniumHQ/Selenium

---

## Contents

**Concepts**
- [1. Why Selenium — what it does that the Test Client can't](#1-why-selenium)
- [2. Mental model — WebDriver, Driver, Browser](#2-mental-model)
- [3. Selenium Manager — automatic driver management](#3-selenium-manager)

**First steps**
- [4. Installation](#4-installation)
- [5. Your first script — 8 basic components](#5-your-first-script--8-basic-components)
- [6. Browsers and headless mode](#6-browsers-and-headless-mode)

**Finding and interacting**
- [7. Finding elements — By strategies](#7-finding-elements--by-strategies)
- [8. Interacting with elements](#8-interacting-with-elements)
- [9. Waits — implicitly_wait and WebDriverWait](#9-waits--implicitly_wait-and-webdriverwait)

**Selenium in tests**
- [10. Selenium + unittest](#10-selenium--unittest)
- [11. Selenium + pytest](#11-selenium--pytest)
- [12. Django + Selenium — StaticLiveServerTestCase](#12-django--selenium--staticliveservertestcase)
- [13. Session Cookie Trick — logging in without a form](#13-session-cookie-trick--logging-in-without-a-form)
- [14. Remote WebDriver and Selenium Grid](#14-remote-webdriver-and-selenium-grid)

**Our project**
- [15. _make_headless_driver() — how it works in our project](#15-_make_headless_driver--how-it-works-in-our-project)
- [16. Walking through test_selenium.py class by class](#16-walking-through-test_seleniumpy-class-by-class)

**Reference**
- [17. Common errors and how to read them](#17-common-errors-and-how-to-read-them)
- [18. Anti-patterns](#18-anti-patterns)
- [19. Self-check questions](#19-self-check-questions)

---

## 1. Why Selenium

### The problem it solves

The Django Test Client checks HTTP. But between HTTP and what the user sees, there is one more layer.

```
The Django Test Client checks:

  Python ──► Django middleware ──► view ──► HTTP response (bytes)
             ↑ everything is automated here, no browser


Selenium checks:

  Python ──► chromedriver ──► Chrome ──► HTTP ──► Django server ──► HTML
                                 ↑
                              HTML + CSS rendering
                              JavaScript execution
                              clicks, forms, navigation
                              everything the user sees in the browser
```

### What the Test Client cannot check

| Situation | Test Client | Selenium |
|----------|-------------|---------|
| `@login_required` protects a URL | ✓ | ✓ |
| Redirect after POST | ✓ | ✓ |
| Text in the HTML response | ✓ | ✓ |
| JavaScript shows/hides an element | ✗ | ✓ |
| CSS breaks how a form is displayed | ✗ | ✓ |
| A button can actually be clicked | ✗ | ✓ |
| A field has the correct `placeholder` | ✗ | ✓ |
| The real redirect chain in the browser | ✗ | ✓ |
| A form isn't submitted without a required field | ✗ | ✓ |

### When Selenium is needed and when it is overkill

Selenium is needed for:
- A critical user flow (login → create → see result)
- Forms with JavaScript validation
- Single Page Applications (React, Vue)
- Checking that CSS doesn't break the layout

Selenium is overkill for:
- Checking business logic (that's for unit tests)
- Checking `status_code` and `redirect` (that's for integration tests)
- Anything that can be checked without a browser

The rule: if a test can be written with `self.client`, write it with `self.client`. Selenium is only for what requires a real browser.

---

## 2. Mental model

### Three components

```
your Python code
      │
      │  selenium package (pip install selenium)
      │  sends commands via the WebDriver Protocol (HTTP/JSON)
      ▼
chromedriver / geckodriver        ← driver: translates WebDriver commands
      │                              into native browser commands
      │
      ▼
Chrome / Firefox                  ← a real browser,
                                     opens pages, runs JS
```

Your Python code never "controls" the browser directly. It sends JSON commands to the driver (using the W3C WebDriver protocol). The driver translates them into the browser's native API.

### WebDriver Protocol

Every command is an HTTP request to the local driver:

```
Python: driver.find_element(By.ID, "username")
            │
            ▼
POST http://localhost:9515/session/abc123/element
{"using": "id", "value": "username"}
            │
            ▼
chromedriver: CDP command to Chrome → find the element
            │
            ▼
Chrome: returns an element reference → id=XYZ
```

That is exactly why Selenium is slower than the Test Client — every action is a real HTTP round-trip to the driver.

---

## 3. Selenium Manager

In older versions of Selenium (before 4.6), you had to manually:
1. Download `chromedriver.exe` / `geckodriver`
2. Put it on the PATH or specify the path in the code
3. Keep track of versions — Chrome version ≠ chromedriver version → error

Starting with Selenium 4.6, there is **Selenium Manager** — a built-in driver manager:

```python
# OLD WAY (before Selenium 4.6):
from selenium.webdriver.chrome.service import Service
driver = webdriver.Chrome(service=Service('/usr/local/bin/chromedriver'))

# NEW WAY (Selenium 4.6+):
driver = webdriver.Chrome()   # Selenium Manager finds and downloads chromedriver by itself
```

Selenium Manager:
1. Detects the installed Chrome version
2. Finds the matching chromedriver in the cache or downloads it
3. Starts chromedriver automatically

This is especially convenient for GitHub Actions: `ubuntu-latest` includes Chrome, and Selenium Manager downloads the matching chromedriver without any extra steps in the workflow.

📖 [Selenium Manager documentation](https://www.selenium.dev/documentation/selenium_manager/)

---

## 4. Installation

```bash
# Latest stable version
pip install -U selenium

# Check the installed version
python -c "import selenium; print(selenium.__version__)"
```

Supported Python versions: **3.10+**

Supported browsers: Chrome, Edge, Firefox, Safari, WebKitGTK, WPEWebKit

After installation, you don't need to download chromedriver separately — Selenium Manager does it automatically on the first run.

For our project, selenium is already in `requirements.txt`:

```
# requirements.txt
selenium>=4.6.0
```

---

## 5. Your first script — 8 basic components

Every Selenium interaction consists of 8 basic operations. Here they are all together:

```python
from selenium import webdriver
from selenium.webdriver.common.by import By

# 1. Start the session — open the browser
driver = webdriver.Chrome()

# 2. Act on the browser — open a URL
driver.get("https://www.selenium.dev/selenium/web/web-form.html")

# 3. Request information about the browser
title = driver.title   # → "Web form"

# 4. Waiting strategy
driver.implicitly_wait(0.5)   # wait up to 0.5 seconds for an element to appear

# 5. Find elements
text_box     = driver.find_element(by=By.NAME,         value="my-text")
submit_button = driver.find_element(by=By.CSS_SELECTOR, value="button")

# 6. Interact with elements
text_box.send_keys("Selenium")
submit_button.click()

# 7. Request information about an element
message = driver.find_element(by=By.ID, value="message")
text = message.text   # → "Received!"

# 8. End the session — close the browser
driver.quit()
```

### What happens at each step

| Step | Method | What it does |
|------|-------|-----------|
| 1 | `webdriver.Chrome()` | Starts Chrome and chromedriver, opens an empty window |
| 2 | `driver.get(url)` | Navigates to the URL, waits until the page loads |
| 3 | `driver.title` | Returns the `<title>` of the current page |
| 4 | `driver.implicitly_wait(n)` | A global wait for `find_element` (once per session) |
| 5 | `driver.find_element(By.X, "val")` | Finds the first matching element in the DOM |
| 6 | `.send_keys()` / `.click()` | Types text / clicks |
| 7 | `.text` | Returns the element's visible text |
| 8 | `driver.quit()` | Stops the driver process, closes the browser |

### The difference between quit() and close()

```python
driver.close()  # Closes the current tab. The driver process keeps running.
driver.quit()   # Stops the driver process and closes all tabs. ALWAYS call it in tearDown.
```

If you don't call `driver.quit()`, the chromedriver process stays in memory. After several tests, several zombie processes pile up.

---

## 6. Browsers and headless mode

### Launching different browsers

```python
from selenium import webdriver

driver = webdriver.Chrome()    # Chrome (the most popular in CI)
driver = webdriver.Firefox()   # Firefox (geckodriver)
driver = webdriver.Edge()      # Microsoft Edge
driver = webdriver.Safari()    # Safari (macOS only)
```

### Headless mode — no GUI window

Headless = the browser performs all actions without a graphical interface. It is needed for:
- CI/CD servers (GitHub Actions, Jenkins) — there is no display there
- Speed — no resources spent on rendering pixels
- Docker containers — there is usually no display server

```python
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

options = Options()
options.add_argument('--headless=new')          # headless mode (Chrome 112+)
options.add_argument('--no-sandbox')            # needed in Docker / CI
options.add_argument('--disable-dev-shm-usage') # avoid shared memory problems in Docker

driver = webdriver.Chrome(options=options)
# the driver opens pages in memory, with no window on the screen
```

### Firefox headless

```python
from selenium.webdriver.firefox.options import Options

options = Options()
options.add_argument('--headless')

driver = webdriver.Firefox(options=options)
```

### Useful options for Chrome

```python
options = Options()
options.add_argument('--window-size=1920,1080')     # window size
options.add_argument('--disable-extensions')         # disable extensions
options.add_argument('--disable-gpu')               # needed in some environments
options.add_argument('--lang=uk')                   # browser language
options.add_experimental_option('prefs', {
    'profile.default_content_setting_values.notifications': 2  # disable notifications
})
```

---

## 7. Finding elements — By strategies

`find_element()` returns the first element found.
`find_elements()` returns a list of all elements found (an empty list if nothing is found).

### All By strategies

```python
from selenium.webdriver.common.by import By

# By the HTML attribute id="username"
elem = driver.find_element(By.ID, "username")

# By the HTML attribute name="password"
elem = driver.find_element(By.NAME, "password")

# By CSS selector
elem = driver.find_element(By.CSS_SELECTOR, "input[type='submit']")
elem = driver.find_element(By.CSS_SELECTOR, ".btn-primary")
elem = driver.find_element(By.CSS_SELECTOR, "#note-form button")

# By XPath
elem = driver.find_element(By.XPATH, "//button[@type='submit']")
elem = driver.find_element(By.XPATH, "//h1[contains(text(), 'Нотатки')]")

# By HTML tag name
elems = driver.find_elements(By.TAG_NAME, "input")

# By CSS class
elem = driver.find_element(By.CLASS_NAME, "btn")

# By the text of an <a> link
elem = driver.find_element(By.LINK_TEXT, "Увійти")

# By partial link text
elem = driver.find_element(By.PARTIAL_LINK_TEXT, "Вий")
```

### Which strategy to choose

| Strategy | When to choose | Pros | Cons |
|-----------|-------------|-------|--------|
| `By.ID` | There is a unique id | The fastest, stable | There isn't always an id |
| `By.NAME` | Forms — fields have a name | Convenient for inputs | May not be unique |
| `By.CSS_SELECTOR` | Flexible selection | Readable, powerful | Requires knowing CSS |
| `By.XPATH` | Complex DOM structure | The most powerful | Fragile when the HTML is refactored |
| `By.CLASS_NAME` | A CSS class | Simple | Unreliable (a class can repeat) |
| `By.TAG_NAME` | All elements with a tag | For `find_elements` | Unreliable as the only criterion |

Recommended order: `By.ID` → `By.NAME` → `By.CSS_SELECTOR` → `By.XPATH`.

### Searching inside an element

```python
# find_element can be called not only on driver but also on a found element
form = driver.find_element(By.TAG_NAME, 'form')
submit = form.find_element(By.CSS_SELECTOR, '[type="submit"]')
# Searches for submit only inside form, not across the whole page
```

### NoSuchElementException

```python
from selenium.common.exceptions import NoSuchElementException

try:
    elem = driver.find_element(By.ID, "nonexistent")
except NoSuchElementException:
    print("Element not found")
```

If `find_element` doesn't find the element, it raises `NoSuchElementException`; it doesn't return `None`.

---

## 8. Interacting with elements

### Text fields

```python
field = driver.find_element(By.NAME, "title")

field.send_keys("Моя нотатка")          # type text (appends to the current value)
field.clear()                           # clear the field
field.clear()
field.send_keys("Нова нотатка")         # clear and type something new
```

### Clicks

```python
button = driver.find_element(By.CSS_SELECTOR, '[type="submit"]')
button.click()

# Or find and click right away
driver.find_element(By.LINK_TEXT, "Додати нотатку").click()
```

### Getting information about an element

```python
elem = driver.find_element(By.ID, "message")
elem.text                           # the element's visible text
elem.get_attribute("href")          # the value of an HTML attribute
elem.get_attribute("class")         # the element's CSS classes
elem.get_attribute("value")         # the value of an input field
elem.is_displayed()                 # True if visible (display: block)
elem.is_enabled()                   # True if not disabled
elem.is_selected()                  # True for a checkbox/radio if selected
```

### Special keys

```python
from selenium.webdriver.common.keys import Keys

field.send_keys(Keys.RETURN)        # Enter
field.send_keys(Keys.TAB)          # Tab
field.send_keys(Keys.ESCAPE)       # Escape
field.send_keys(Keys.BACKSPACE)    # Backspace
field.send_keys(Keys.CONTROL, 'a') # Ctrl+A (select all)
field.send_keys(Keys.CONTROL, 'c') # Ctrl+C (copy)
```

### Dropdown (Select)

```python
from selenium.webdriver.support.ui import Select

select = Select(driver.find_element(By.NAME, "priority"))
select.select_by_value("2")            # by the value attribute
select.select_by_visible_text("High")  # by the visible text
select.select_by_index(0)             # by position

# Get the selected option
current = select.first_selected_option.text
```

### Information about the browser and the page

```python
driver.title             # <title> of the current page
driver.current_url       # the current URL
driver.page_source       # the page's full HTML (a string)
driver.get_cookies()     # list of cookies
driver.get_cookie('sessionid')  # a specific cookie

# Execute JavaScript
driver.execute_script("return document.title")
driver.execute_script("window.scrollTo(0, document.body.scrollHeight)")
```

---

## 9. Waits — implicitly_wait and WebDriverWait

### The problem without waits

```python
driver.get("http://localhost:8000/notes/new/")
driver.find_element(By.NAME, 'title')  # ← MAY FAIL!
# If the page hasn't fully loaded yet, the element isn't in the DOM
```

The browser is asynchronous. `driver.get()` returns when it has received the response, but the DOM may not be fully built yet.

### implicitly_wait — a global wait

```python
driver.implicitly_wait(5)
# Now every find_element waits up to 5 seconds before raising NoSuchElementException
```

It is set once per session (usually in `setUpClass`). On every `find_element`:
- If the element is there, it returns immediately
- If not, it waits and checks again, up to the timeout
- If it still hasn't found it within 5 seconds — `NoSuchElementException`

```python
# Our project: test_selenium.py
@classmethod
def setUpClass(cls):
    super().setUpClass()
    cls.driver = _make_headless_driver()
    cls.driver.implicitly_wait(5)   # ← set once for the whole class
```

### WebDriverWait — an explicit wait for a specific condition

`implicitly_wait` only waits for an element to appear. But sometimes you need to wait for a different condition: a URL change, text, visibility.

```python
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

wait = WebDriverWait(driver, timeout=5)

# Wait until the URL changes
wait.until(EC.url_changes("http://localhost:8000/accounts/login/"))

# Wait until the element becomes clickable
wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, '[type="submit"]')))

# Wait until the element becomes visible
wait.until(EC.visibility_of_element_located((By.ID, "message")))

# Wait until text appears in the element
wait.until(EC.text_to_be_present_in_element((By.ID, "status"), "Saved"))

# Wait until the element disappears
wait.until(EC.invisibility_of_element_located((By.CLASS_NAME, "loading")))
```

### Common expected_conditions

| Condition | What it checks |
|-------|-------------|
| `url_changes(url)` | The current URL differs from the given one |
| `url_contains("path")` | The URL contains a substring |
| `title_contains("text")` | The `<title>` contains the text |
| `element_to_be_clickable(locator)` | The element exists and is clickable |
| `visibility_of_element_located(locator)` | The element exists and is visible |
| `invisibility_of_element_located(locator)` | The element is invisible or absent |
| `text_to_be_present_in_element(locator, text)` | The text is in the element |
| `staleness_of(element)` | The old element has left the DOM (after a reload) |

### When to choose which

```
implicitly_wait(n):
  + Simple, set once
  + Automatic for every find_element
  - Only waits for the element to appear in the DOM
  - Doesn't check visibility or clickability

WebDriverWait + EC:
  + Flexible — any condition
  + You can set different timeouts for different situations
  - More code
```

In our project: `implicitly_wait(5)` for general lookups, and `WebDriverWait(driver, 5).until(EC.url_changes(...))` after clicking Submit (because we need to wait for a redirect, not for an element to appear).

---

## 10. Selenium + unittest

The classic way — with `unittest.TestCase`:

```python
import unittest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


class SeleniumTestCase(unittest.TestCase):

    def setUp(self):
        """Runs before every test — opens a new browser."""
        options = Options()
        options.add_argument('--headless=new')
        self.driver = webdriver.Chrome(options=options)
        self.addCleanup(self.driver.quit)  # ← quit() even if the test failed

    def test_page_title(self):
        self.driver.get("https://selenium.dev")
        self.assertIn("Selenium", self.driver.title)

    def test_find_element(self):
        self.driver.get("https://www.selenium.dev/selenium/web/web-form.html")
        field = self.driver.find_element(By.NAME, "my-text")
        self.assertIsNotNone(field)
```

`self.addCleanup(self.driver.quit)` guarantees that `quit()` is called even if the test raises an exception. This is better than `tearDown`, because `tearDown` is not called when there are exceptions in `setUp`.

### setUpClass — one driver for all the tests in a class (faster)

```python
class SeleniumTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Runs once before all tests in the class."""
        super().setUpClass()
        options = Options()
        options.add_argument('--headless=new')
        cls.driver = webdriver.Chrome(options=options)
        cls.driver.implicitly_wait(5)

    @classmethod
    def tearDownClass(cls):
        """Runs once after all tests in the class."""
        cls.driver.quit()
        super().tearDownClass()

    def test_page_one(self):
        self.driver.get("https://selenium.dev")
        # ...

    def test_page_two(self):
        self.driver.get("https://selenium.dev/documentation")
        # ...
```

**Important:** with `setUpClass`, all tests in the class share one driver. If a test leaves the browser in an unexpected state (cookies, open dialogs), the next test may fail. In our project we work around this with the session cookie trick (we log in every time via `setUp`).

---

## 11. Selenium + pytest

```python
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


@pytest.fixture
def driver():
    """Fixture — opens the driver before the test, closes it afterwards."""
    options = Options()
    options.add_argument('--headless=new')
    d = webdriver.Chrome(options=options)
    d.implicitly_wait(5)
    yield d        # ← the test runs here
    d.quit()       # ← always called after the test (even on error)


def test_page_title(driver):
    driver.get("https://selenium.dev")
    assert "Selenium" in driver.title


def test_form(driver):
    from selenium.webdriver.common.by import By
    driver.get("https://www.selenium.dev/selenium/web/web-form.html")
    driver.find_element(By.NAME, "my-text").send_keys("pytest test")
    driver.find_element(By.CSS_SELECTOR, "button").click()
    message = driver.find_element(By.ID, "message")
    assert message.text == "Received!"
```

### scope="session" — one driver for all tests

```python
@pytest.fixture(scope="session")
def driver():
    """One driver for the whole pytest test session."""
    options = Options()
    options.add_argument('--headless=new')
    d = webdriver.Chrome(options=options)
    yield d
    d.quit()
```

`scope="session"` runs the fixture once. It's faster, but the tests share the browser state.

For Django it's better to use `django.test.TestCase` + `StaticLiveServerTestCase` rather than pytest fixtures — they integrate with Django's test database.

---

## 12. Django + Selenium — StaticLiveServerTestCase

### The problem with a regular TestCase

Selenium opens a real browser that makes HTTP requests. A regular Django `TestCase` does not start an HTTP server — it simulates requests inside the process. Selenium cannot connect.

### StaticLiveServerTestCase — a real HTTP server

```python
from django.contrib.staticfiles.testing import StaticLiveServerTestCase
```

`StaticLiveServerTestCase`:
1. Starts a real Django HTTP server in a separate thread
2. The server runs on a random port: `http://127.0.0.1:XXXXX`
3. `self.live_server_url` contains this address
4. Each test has an isolated test DB (with rollback — like in `TestCase`)
5. Additionally: it serves static files (CSS, JS) — hence "Static" in the name

```python
from django.contrib.staticfiles.testing import StaticLiveServerTestCase
from selenium.webdriver.common.by import By


class MyDjangoSeleniumTest(StaticLiveServerTestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Start headless Chrome once for all tests in the class
        options = ChromeOptions()
        options.add_argument('--headless=new')
        cls.driver = webdriver.Chrome(options=options)
        cls.driver.implicitly_wait(5)

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def setUp(self):
        # Create a test user in the test DB
        self.user = User.objects.create_user('alice', password='pass')

    def test_login_flow(self):
        # self.live_server_url → "http://127.0.0.1:38471" (random port)
        self.driver.get(f'{self.live_server_url}/accounts/login/')
        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('pass')
        self.driver.find_element(By.CSS_SELECTOR, '[type="submit"]').click()
        self.assertIn('/notes/', self.driver.current_url)
```

### LiveServerTestCase vs StaticLiveServerTestCase

```python
from django.test import LiveServerTestCase              # does not serve static files
from django.contrib.staticfiles.testing import StaticLiveServerTestCase  # ← use this one
```

Most tests need `StaticLiveServerTestCase` — because if the Bootstrap CSS doesn't load, some elements may be hidden and Selenium won't click them.

---

## 13. Session Cookie Trick — logging in without a form

### The problem with logging in via the form in E2E tests

The most obvious way to authenticate in a Selenium test:

```python
# AN UNSTABLE WAY — via the form
def login_via_form(driver, url, username, password):
    driver.get(f'{url}/accounts/login/')
    driver.find_element(By.NAME, 'username').send_keys(username)
    driver.find_element(By.NAME, 'password').send_keys(password)
    driver.find_element(By.CSS_SELECTOR, '[type="submit"]').click()
```

**Problems:**
- If the form has a CSRF check involving JavaScript, the test may depend on the loading order
- If the form layout changes (renamed CSS classes), the test fails for reasons unrelated to the logic
- If you add reCAPTCHA, the test breaks completely
- It's slow: every test does a full round-trip through the form

### The solution: a session cookie

```python
def _login_via_cookie(self):
    """
    The standard E2E login technique via a session cookie:
    1. The Django Test Client logs in (no browser, instantly)
    2. We get the session cookie
    3. We pass the cookie to the Selenium driver
    4. The driver is authenticated — without filling in the form
    """
    # Step 1: the Test Client logs in
    self.client.force_login(self.user)

    # Step 2: Get the session cookie
    session_cookie = self.client.cookies['sessionid']

    # Step 3: Open any page on the same domain
    # (the browser doesn't allow setting cookies without an active domain)
    self.driver.get(f'{self.live_server_url}/')

    # Step 4: Add the cookie to the driver
    self.driver.add_cookie({
        'name':  'sessionid',
        'value': session_cookie.value,
        'path':  '/',
    })

    # Now the driver is authenticated. The next get() goes out as a logged-in user.
```

### Why `force_login` and not `login`

```python
# force_login — sets up the session without authentication (for tests only)
self.client.force_login(self.user)   # ← fast, no password check

# login — full authentication with a password check
self.client.login(username='alice', password='pass')  # ← slower, for login tests
```

In the session cookie trick we are not testing login — we are testing functionality after login. That's why `force_login` is the right choice.

### The full pattern with a session cookie in a test

```python
class SeleniumNoteFlowTest(StaticLiveServerTestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_headless_driver()
        cls.driver.implicitly_wait(5)

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def setUp(self):
        # The test DB is clean (rollback between tests)
        self.user = User.objects.create_user('alice', password='pass')
        self._login_via_cookie()   # ← log in via cookie before EVERY test

    def _login_via_cookie(self):
        self.client.force_login(self.user)
        session_cookie = self.client.cookies['sessionid']
        self.driver.get(f'{self.live_server_url}/')
        self.driver.add_cookie({'name': 'sessionid', 'value': session_cookie.value, 'path': '/'})

    def test_create_note(self):
        # Here the driver is already authenticated as alice
        self.driver.get(f'{self.live_server_url}/notes/new/')
        self.driver.find_element(By.NAME, 'title').send_keys('My Note')
        self.driver.find_element(By.CSS_SELECTOR, '[type="submit"]').click()
        # ...
```

---

## 14. Remote WebDriver and Selenium Grid

### When you need Remote WebDriver

Local WebDriver: the driver and the browser are on the same machine.

Remote WebDriver: the driver is on one machine, the browser on another (in Docker, in the cloud).

Uses:
- Selenium Grid — run tests in parallel on several browsers
- Docker — run Chrome in a container
- BrowserStack, Sauce Labs — cloud testing on real devices

### Selenium Grid + Docker

```bash
# Start Selenium standalone-chrome in Docker
docker run -d -p 4444:4444 selenium/standalone-chrome:latest
```

```python
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

options = Options()
driver = webdriver.Remote(
    command_executor="http://localhost:4444/wd/hub",  # Grid address
    options=options,
)
driver.get("https://selenium.dev")
```

### Our `_make_headless_driver()` — dynamic selection

`test_selenium.py` has an environment variable `SELENIUM_REMOTE_URL`. If it is set — Remote WebDriver; if not — local Chrome:

```python
SELENIUM_REMOTE_URL = os.environ.get("SELENIUM_REMOTE_URL")

def _make_headless_driver():
    options = ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    if SELENIUM_REMOTE_URL:
        # CI with a separate Selenium container
        return webdriver.Remote(
            command_executor=SELENIUM_REMOTE_URL,
            options=options,
        )

    # Locally or on GitHub Actions without a container
    options.add_argument('--headless=new')
    return webdriver.Chrome(options=options)
```

This lets you run ONE test file in both environments.

📖 [Remote WebDriver documentation](https://selenium.dev/documentation/webdriver/drivers/remote_webdriver/)

---

## 15. _make_headless_driver() — how it works in our project

Let's look at the full `_make_headless_driver()` from our project and go through each argument:

```python
def _make_headless_driver():
    options = ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    if SELENIUM_REMOTE_URL:
        return webdriver.Remote(
            command_executor=SELENIUM_REMOTE_URL,
            options=options,
        )

    options.add_argument('--headless=new')
    return webdriver.Chrome(options=options)
```

| Argument | Explanation |
|----------|-----------|
| `--no-sandbox` | The Chrome sandbox isolates processes. In Docker and on the GitHub Actions runner this conflicts with the container's namespace isolation. We disable it. |
| `--disable-dev-shm-usage` | By default Chrome writes to `/dev/shm` (shared memory). In Docker this is limited to 64MB → Chrome crashes. This flag makes Chrome write to `/tmp`. |
| `--headless=new` | The new headless mode (Chrome 112+). The old `--headless` is kept for compatibility. |

### Why GitHub Actions doesn't use a service container

The template `crispy_notes_chat_app/.github/.../django-tests.yml` has `services: selenium: image: selenium/standalone-chrome`. But the real workflow in `.github/workflows/django-tests.yml` doesn't use it.

```
Problem:
  The Selenium container opens http://localhost:PORT
  BUT its localhost ≠ the runner's localhost
  → Chrome in the container cannot connect to the Django server on the runner

Solution:
  Chrome and the Django server on the same machine (the runner)
  → localhost is shared
  → everything works
```

That's why in the real workflow the Selenium tests run without a service container — Chrome is already on `ubuntu-latest`, and Selenium Manager downloads the matching chromedriver.

---

## 16. Walking through test_selenium.py class by class

### The _DockerLiveServerMixin mixin

Every live-server class in the file inherits `_DockerLiveServerMixin`. It solves a networking problem: a Remote Selenium in a separate container cannot see `127.0.0.1` of the `web` container.

```
Variable:   WEB_HOST (from the environment)
Locally:    WEB_HOST is empty → host = '127.0.0.1' → live_server_url = 'http://127.0.0.1:PORT'
In Docker:  WEB_HOST=web → host = '0.0.0.0' (bind to all interfaces),
            after setUpClass() the host name goes into the URL → 'http://web:PORT'
In CI:      WEB_HOST=host.docker.internal → Chrome in the selenium container can reach the runner
```

`ChannelsLiveServerTestCase` computes `live_server_url` in advance and stores the string in `cls.__dict__`, so the mixin also replaces `0.0.0.0` with `WEB_HOST` in it.

### The SeleniumLoginFlowTest class

```
Tests:    The login flow through a real browser
Method:   Filling in the form (not the session cookie)
Tests:
  test_login_page_renders         — the form is in the DOM
  test_valid_login_redirects_to_notes — correct password → redirect
  test_invalid_login_shows_error  — wrong password → we stay on login
```

The key point: `test_valid_login_redirects_to_notes` uses `WebDriverWait(driver, 5).until(EC.url_changes(login_url))` — it waits until Chrome finishes the redirect after the POST.

```python
def test_valid_login_redirects_to_notes(self):
    login_url = f'{self.live_server_url}/accounts/login/'
    self.driver.get(login_url)

    self.driver.find_element(By.NAME, 'username').send_keys('seleniumuser')
    self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
    self.driver.find_element(By.CSS_SELECTOR, '[type="submit"]').click()

    # Without this wait, current_url is checked before the redirect
    WebDriverWait(self.driver, 5).until(EC.url_changes(login_url))

    self.assertIn('/notes/', self.driver.current_url)
```

---

### The SeleniumNoteFlowTest class

```
Tests:    Note workflow: viewing and creating
Method:   Session cookie trick for login
Tests:
  test_note_list_page_loads   — the /notes/ page loaded
  test_create_note_via_form   — the note creation form works
  test_created_note_appears_in_list — the note is visible in the list
```

`test_created_note_appears_in_list` doesn't fill in the form — it creates a note via the ORM and checks that `page_source` contains its title:

```python
def test_created_note_appears_in_list(self):
    Note.objects.create(user=self.user, title='Visible Note', content='Test')
    self.driver.get(f'{self.live_server_url}/notes/')
    self.assertIn('Visible Note', self.driver.page_source)
```

This checks not the business logic (which is covered by unit tests), but that **the template renders the data correctly** — `{% for note in notes %}` displays `note.title`.

---

### The SeleniumGroupChatPageTest class

```
Tests:    The group chat page /groups/<pk>/chat/
Server:   StaticLiveServerTestCase (no ASGI → the WebSocket does NOT connect)
Tests:
  test_chat_page_loads_for_member      — a group member opens the chat
  test_chat_page_shows_group_name      — the group name is visible
  test_chat_input_element_present      — #chat-input exists
  test_chat_send_button_present        — #chat-send-btn exists
  test_chat_messages_feed_present      — #chat-messages exists
  test_non_member_redirected_from_chat — a non-member gets a redirect
  test_group_detail_has_chat_link      — group_detail contains a link to the chat
```

This class checks only the HTML markup and access rights. The WebSocket connection itself is not established here.

### The SeleniumWebSocketChatTest class

```
Tests:    The real WebSocket chat in a browser
Server:   ChannelsLiveServerTestCase (Daphne ASGI in a child process)
Tests:
  test_websocket_connects_and_enables_input         — after onopen, #chat-input becomes enabled
  test_send_message_appears_in_chat_feed            — the message appears in #chat-messages
  test_status_shows_connected_after_websocket_opens — #status-text shows 'Підключено' ("Connected")
```

The full path: browser → WebSocket → `GroupChatConsumer` → DB → `group_send` → DOM. The class replaces `ProtocolServerProcess` with `_FreshConnectionDaphneProcess`, which closes the DB connections inherited through fork and sets `TEST["NAME"]`, so the Daphne child process works with the same test database.

Besides these classes, the file also has `SeleniumReminderToastTest` (reminder toasts from `reminders.js`) and `SeleniumDockerStackSmokeTest` (smoke tests against an already running Docker stack; they run only when `SELENIUM_EXTERNAL_BASE_URL` is set).

---

## 17. Common errors and how to read them

### NoSuchElementException — element not found

```
selenium.common.exceptions.NoSuchElementException:
Message: no such element: Unable to locate element: {"method":"css selector","selector":"[type='submit']"}

Causes:
  1. The element isn't in the DOM yet (the page hasn't loaded)
     → Increase implicitly_wait or add a WebDriverWait
  2. Wrong selector
     → Open the browser DevTools (F12), check the selector in the console: document.querySelector('[type="submit"]')
  3. The element is in a different iframe
     → driver.switch_to.frame("frame_name") before find_element
```

### StaleElementReferenceException — a stale element

```
selenium.common.exceptions.StaleElementReferenceException:
Message: stale element reference: stale element not found in the current frame

Cause:
  You found an element, then the page reloaded (or JS rebuilt the DOM),
  and that element reference is no longer valid.

Solution:
  # WRONG:
  button = driver.find_element(By.ID, "submit")
  do_something_that_reloads_page()
  button.click()   # ← StaleElementReferenceException!

  # RIGHT:
  do_something_that_reloads_page()
  driver.find_element(By.ID, "submit").click()  # ← find it again
```

### TimeoutException — WebDriverWait ran out of time

```
selenium.common.exceptions.TimeoutException

Cause:
  WebDriverWait(driver, 5).until(EC.url_changes(...)) didn't get its condition within 5 seconds.

Actions:
  1. Increase the timeout: WebDriverWait(driver, 10)
  2. Check that the condition can actually be met
  3. Add a screenshot for diagnosis:
     driver.save_screenshot('/tmp/debug.png')
     # See what is displayed at the moment of the timeout
```

### ElementNotInteractableException — cannot interact

```
selenium.common.exceptions.ElementNotInteractableException:
Message: element not interactable

Cause:
  The element is in the DOM, but hidden (display:none) or covered by another element.

Solution:
  # Check visibility
  if elem.is_displayed():
      elem.click()
  else:
      # Scroll to the element
      driver.execute_script("arguments[0].scrollIntoView(true);", elem)
      elem.click()
```

### WebDriverException — the driver didn't start

```
selenium.common.exceptions.WebDriverException:
Message: 'chromedriver' executable needs to be in PATH

Cause (old Selenium version < 4.6):
  chromedriver is not on the PATH and was not found by Selenium Manager.

For newer versions (4.6+):
  Selenium Manager should download chromedriver automatically.
  If it didn't work: check that Chrome is installed on the system.
  chrome --version  (or google-chrome --version)
```

---

## 18. Anti-patterns

### Anti-pattern 1: time.sleep instead of a wait

```python
# BAD — unstable and slow
driver.find_element(By.ID, "submit").click()
time.sleep(3)   # wait 3 seconds "to be sure it loaded"
assert "Success" in driver.page_source

# GOOD — wait for a specific condition
driver.find_element(By.ID, "submit").click()
WebDriverWait(driver, 5).until(
    EC.text_to_be_present_in_element((By.ID, "message"), "Success")
)
assert "Success" in driver.page_source
```

`time.sleep(3)` always waits 3 seconds, even if the page loaded in 0.1s. `WebDriverWait` waits at most 5 seconds and returns as soon as the condition is met.

### Anti-pattern 2: Selenium for what the Test Client does better

```python
# BAD — Selenium for checking an HTTP status
def test_unauthenticated_redirect(self):
    self.driver.get(f'{self.live_server_url}/notes/')
    self.assertIn('/accounts/login/', self.driver.current_url)

# GOOD — that's what an integration test is for
def test_unauthenticated_redirect(self):
    response = self.client.get('/notes/')
    self.assertEqual(response.status_code, 302)
    self.assertIn('/accounts/login/', response['Location'])
```

Checking `@login_required` is an integration test. Selenium is needed only if you must check that the redirect happens in a real browser with navigation.

### Anti-pattern 3: opening a new driver in every test

```python
# BAD — 100 tests × 3 seconds of Chrome startup = 5 minutes of wasted time
class BadTest(TestCase):
    def setUp(self):
        self.driver = webdriver.Chrome()   # every test launches a new Chrome

    def tearDown(self):
        self.driver.quit()

# GOOD — one driver per class
class GoodTest(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.driver = webdriver.Chrome()

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
```

### Anti-pattern 4: fragile XPath

```python
# BAD — breaks on any change to the HTML structure
elem = driver.find_element(By.XPATH, "/html/body/div[2]/main/div[1]/form/div[3]/button")

# GOOD — a stable CSS selector or data attribute
elem = driver.find_element(By.CSS_SELECTOR, '[type="submit"]')
# or add data-testid to the HTML:
# <button data-testid="submit-note" type="submit">
elem = driver.find_element(By.CSS_SELECTOR, '[data-testid="submit-note"]')
```

### Anti-pattern 5: Selenium tests for every little thing

```
Unit test: 0.01s  × 100 = 1 second
Selenium:  10s    × 100 = 16 minutes

+ Selenium tests are brittle (a CSS change breaks the test)
+ They require a browser driver, versions, configuration

Rule: Selenium only for critical user flows.
      Anything that can be checked with the Test Client — check it with the Test Client.
```

---

## 19. Self-check questions

1. How does Selenium differ from the Django Test Client? What does each of them check?
2. What is the WebDriver Protocol, and why is Selenium slower than the Test Client?
3. What problem does Selenium Manager solve, and in which version did it appear?
4. What is the difference between `driver.close()` and `driver.quit()`?
5. Which lookup strategy should you choose if the element has an `id`? If it only has a CSS class?
6. How does `implicitly_wait` differ from `WebDriverWait`? When should you use each?
7. Why do you need `WebDriverWait(...).until(EC.url_changes(...))` after `submit_button.click()`?
8. What is `StaticLiveServerTestCase`, and why is it needed for Django Selenium tests?
9. Explain the session cookie trick: what are the 4 steps, and why is it better than filling in the login form?
10. Why is there one `driver` for the whole class in `setUpClass`, while `_login_via_cookie()` is called every time in `setUp`?
11. What is `StaleElementReferenceException`, and how do you avoid it?
12. When is Remote WebDriver necessary, and when can you make do with a local one?
13. Why doesn't the real workflow use `selenium/standalone-chrome` as a service container?
14. Why use `--no-sandbox` and `--disable-dev-shm-usage` in GitHub Actions / Docker?
15. In which cases is it better to write an integration test rather than a Selenium test?

---

## Links

| Resource | Link |
|--------|-----------|
| Selenium Python Docs | https://selenium.dev/selenium/docs/api/py |
| Selenium Python API Reference | https://selenium.dev/selenium/docs/api/py/api.html |
| Selenium GitHub | https://github.com/SeleniumHQ/Selenium |
| PyPI: selenium | https://pypi.org/project/selenium |
| Selenium Manager | https://www.selenium.dev/documentation/selenium_manager/ |
| Write your first Selenium script | https://selenium.dev/documentation/webdriver/getting_started/first_script/ |
| WebDriver — all browsers | https://selenium.dev/documentation/webdriver/browsers/ |
| Locator strategies | https://selenium.dev/documentation/webdriver/elements/locators/ |
| Interacting with elements | https://selenium.dev/documentation/webdriver/elements/interactions/ |
| Waiting strategies | https://selenium.dev/documentation/webdriver/waits/ |
| Expected conditions | https://selenium.dev/selenium/docs/api/py/webdriver_support/selenium.webdriver.support.expected_conditions.html |
| Remote WebDriver | https://selenium.dev/documentation/webdriver/drivers/remote_webdriver/ |
| Selenium Grid | https://selenium.dev/documentation/grid/ |
| Django StaticLiveServerTestCase | https://docs.djangoproject.com/en/5.2/topics/testing/tools/#django.test.LiveServerTestCase |
| chromedriver | https://developer.chrome.com/docs/chromedriver |
| geckodriver (Firefox) | https://github.com/mozilla/geckodriver |
