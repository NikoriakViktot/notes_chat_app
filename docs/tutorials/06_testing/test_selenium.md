# test_selenium.py — E2E тести через браузер

---

## Що тестує Selenium (і чого не можуть unit тести)

```
Django Test Client (integration):         Selenium (E2E):
  ✓ HTTP статуси                           ✓ JavaScript поведінка
  ✓ HTML контент (assertContains)          ✓ CSS видимість елементів
  ✓ Redirect                               ✓ Форма submit через кнопку
  ✓ Шаблон context                         ✓ WebSocket з'єднання у браузері
  ✗ JavaScript events                      ✓ Bootstrap dropdown
  ✗ CSS display:none                       ✓ Реальна навігація між сторінками
  ✗ form.submit() через кнопку             ✓ Ajax запити
  ✗ WebSocket у браузері                   ✗ Дуже повільно (~10с/тест)
```

### Чому Selenium тестів мало

```
Unit test: 0.01s  ×  100 = 1 секунда
Selenium:  10s    ×  100 = 16 хвилин

+ Selenium крихкий: зміна CSS класу ламає тест навіть якщо логіка правильна
+ Потрібен geckodriver або chromedriver, специфічна версія браузера
+ Нестабільний в CI без implicitly_wait

Правило: E2E тести тільки для КРИТИЧНИХ user flows.
         Все інше — unit/integration.
```

---

## `StaticLiveServerTestCase` — реальний сервер

```python
from django.contrib.staticfiles.testing import StaticLiveServerTestCase

class MySeleniumTest(StaticLiveServerTestCase):
    def test_something(self):
        self.live_server_url  # → 'http://127.0.0.1:PORT' (random port)
        self.driver.get(f'{self.live_server_url}/notes/')
```

`StaticLiveServerTestCase` запускає реальний Django HTTP сервер на тимчасовому порту. Selenium підключається до нього як справжній браузер.

---

## Пропуск тестів якщо Selenium не встановлений (`@skipUnless`)

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

Якщо `selenium` не встановлений → тести позначаються як `s` (skipped), **не падають**:

```
...........ssssss
Ran 129 tests in 90.2s
OK (skipped=6)   ← зелений результат навіть без Selenium!
```

Це важливо: `manage.py test` повинен завжди повертати `OK`, навіть без geckodriver.

---

## Selenium у Docker — архітектура

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

**Ключова проблема без Docker:** `localhost` у Chrome container ≠ `localhost` у test runner.
**Рішення:** bind на `0.0.0.0`, Chrome підключається за `http://web:PORT`.

---

## `_DockerLiveServerMixin` — адаптація для Docker

```python
class _DockerLiveServerMixin:
    """
    Адаптує StaticLiveServerTestCase для роботи з Selenium у Docker.

    Проблема: LiveServerTestCase за замовчуванням bind на 127.0.0.1.
    У Docker: selenium container не може дістатись до 127.0.0.1 web container.

    Рішення:
      1. host = '0.0.0.0' → bind на всі interfaces
      2. live_server_url: замінюємо '0.0.0.0' на 'web' (Docker DNS)
         http://0.0.0.0:PORT → http://web:PORT

    WEB_HOST env var: docker-compose.yml → web.environment.WEB_HOST = "web"
    Без Docker (локально): WEB_HOST не встановлено → url залишається localhost
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

## `_make_driver()` — WebDriver для Docker і локально

```python
def _make_driver():
    """
    Повертає Chrome WebDriver залежно від середовища:
      - SELENIUM_REMOTE_URL встановлено → Remote WebDriver (Docker selenium container)
      - Не встановлено → локальний Chrome (headless)
    """
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = 'http://selenium:4444/wd/hub' (з docker-compose.yml)

    options = webdriver.ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    # --disable-dev-shm-usage: Chrome в Docker використовує /tmp замість /dev/shm
    # (за замовчуванням /dev/shm у Docker = 64MB → Chrome падає)

    if remote_url:
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        options.add_argument('--headless')   # локально: без GUI вікна
        return webdriver.Chrome(options=options)
```

---

## Session Cookie Trick — логін без форми

```python
def _login_via_cookie(self, user):
    """
    Логін без заповнення login форми в браузері.
    Значно швидше і надійніше ніж заповнювати форму.

    Метод:
    1. Test Client (server side) створює session у тестовій БД
    2. Копіюємо sessionid cookie до Selenium Chrome
    3. Chrome надсилає цей cookie → Django вважає Chrome залогіненим

    Навіщо:
    - Login форма може мати CSRF, JS валідацію, рекапчу
    - Session cookie trick завжди надійний
    - Швидше: 1 HTTP запит замість форми
    """
    self.client.force_login(user)                     # ← server: session у БД
    session_cookie = self.client.cookies['sessionid'] # ← витягуємо cookie value

    # Chrome має бути на нашому домені перед add_cookie
    self.driver.get(f'{self.live_server_url}/')        # ← будь-який URL сайту

    self.driver.add_cookie({
        'name':  'sessionid',
        'value': session_cookie.value,
        'path':  '/',
    })
    # Тепер Chrome залогінений як user ✓
```

---

## Структура test_selenium.py

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
    """E2E тест: login форма → dashboard."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)   # чекати до 5 сек на елемент

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
        """Заповнення login форми → redirect до /notes/."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # Після успішного login → redirect до /notes/
        WebDriverWait(self.driver, 5).until(
            EC.url_contains('/notes/')
        )
        self.assertIn('/notes/', self.driver.current_url)

    def test_dashboard_shows_username(self):
        """Після login navbar показує username."""
        self._login_via_cookie(self.user)
        self.driver.get(f'{self.live_server_url}/notes/')

        page_text = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertIn('alice', page_text)

    def test_invalid_login_shows_error(self):
        """Неправильний пароль → форма з помилкою."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('wrongpassword')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # Залишились на login сторінці (немає redirect)
        self.assertIn('/accounts/login/', self.driver.current_url)

        body = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertTrue(
            'Невірний' in body or 'Please enter' in body or 'wrong' in body.lower()
        )
```

---

## Запуск без Docker і через Docker

```bash
# ── Без Docker (crispy_notes_project) ─────────────────────────────────────────
# 1. Встановити selenium
pip install selenium

# 2. Завантажити geckodriver для Firefox або chromedriver для Chrome
#    https://github.com/mozilla/geckodriver/releases
#    → розпакувати і додати до PATH

# 3. Запустити
python manage.py test hello_app.tests.test_selenium -v 2

# Якщо selenium НЕ встановлений:
python manage.py test hello_app.tests -v 1
# → ...........ssssss
# → OK (skipped=6)


# ── notes_chat_app: через Docker ──────────────────────────────────────────────
# Важливо: Selenium тести потребують ЗАПУЩЕНОГО контейнера з DNS alias "web"
# Тому використовуємо exec (у запущеному контейнері), а не run (новий контейнер)

# 1. Підняти стек (включно з selenium service)
docker compose up -d

# 2. Запустити тести через exec
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec → виконується всередині ЗАПУЩЕНОГО контейнера що має DNS alias "web"
# run  → НОВИЙ контейнер без "web" alias → Selenium не може знайти Django сервер!

# 3. Якщо потрібно -- перевірити selenium container
docker compose ps selenium
# Selenium доступний на http://localhost:7900 (VNC, опціонально)
```

---

## Headless режим

```python
from selenium.webdriver.firefox.options import Options

options = Options()
options.add_argument('--headless')  # без GUI вікна
driver = webdriver.Firefox(options=options)
```

**headless** = браузер запускається без графічного інтерфейсу. Потрібно для:
- CI/CD серверів (GitHub Actions, Jenkins, Docker) — там немає дисплею
- Швидкість — не треба рендерити піксели на екран

---

## Далі

- **[GitHub Actions CI](ci_github_actions.md)** — workflow рядок за рядком, jobs, results
