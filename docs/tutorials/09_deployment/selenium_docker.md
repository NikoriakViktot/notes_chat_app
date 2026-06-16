# Selenium у Docker

> **Різниця від попередніх кроків:** тут Selenium запускається у окремому контейнері
> (не локально). Django test server і Chrome у різних контейнерах — потрібна спеціальна конфігурація.

---

## Проблема: localhost ≠ localhost між контейнерами

```
БЕЗ Docker Selenium (попередні кроки):
  Runner VM: Django test server (localhost:PORT) + Chrome (localhost:PORT) ✓
  Chrome бачить Django за localhost → OK

З Docker Selenium:
  web container: Django test server (localhost:PORT)
  selenium container: Chrome
    Chrome: http://localhost:PORT → NOT FOUND!
    localhost в selenium container = IP самого selenium container
    НЕ IP web container!
```

---

## Selenium сервіс у docker-compose.yml

```yaml
selenium:
  image: selenium/standalone-chrome:latest
  ports:
    - "4444:4444"    # WebDriver API (використовується test_selenium.py)
    - "7900:7900"    # VNC (можна переглянути браузер живцем: http://localhost:7900)
  shm_size: '2g'     # Chrome потребує shared memory
  networks: [app-net]
```

`selenium/standalone-chrome` — офіційний образ Selenium з вбудованим Chrome. Він запускає `selenium-server` на порту `4444`, до якого підключається `webdriver.Remote`.

`shm_size: '2g'` — Chrome використовує shared memory (`/dev/shm`) для рендерингу. Без цього Chrome аварійно завершується при відкритті складних сторінок.

Змінні оточення у `web` сервісі для Selenium:

```yaml
web:
  environment:
    WEB_HOST:            web              # DNS ім'я web контейнера
    SELENIUM_REMOTE_URL: http://selenium:4444/wd/hub
```

---

## StaticLiveServerTestCase з Remote driver

### Рішення: `_DockerLiveServerMixin`

```python
# notes_app/tests/test_selenium.py

class _DockerLiveServerMixin:
    """
    Дозволяє Selenium у Docker container бачити Django test server.

    Проблема: LiveServerTestCase зазвичай bind на 127.0.0.1 (тільки localhost).
    Рішення: bind на 0.0.0.0 (всі interfaces) → доступний з selenium container.

    Також замінює 0.0.0.0 на "web" у live_server_url:
    http://0.0.0.0:PORT → http://web:PORT
    "web" — DNS ім'я web container у Docker network app-net.
    """
    host = '0.0.0.0'   # StaticLiveServerTestCase.host

    @property
    def live_server_url(self):
        url = super().live_server_url           # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')  # = "web" (з docker-compose.yml env)
        if web_host:
            return url.replace('0.0.0.0', web_host)  # http://web:PORT
        return url


def _make_driver():
    """Повертає Chrome WebDriver: Remote (Docker) або локальний."""
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = http://selenium:4444/wd/hub (з docker-compose.yml env web.environment)

    if remote_url:
        # Docker: Chrome запускається у selenium контейнері
        options = webdriver.ChromeOptions()
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        # headless не потрібен: selenium/standalone-chrome вже headless
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        # Локально (без Docker): Chrome на тій же машині
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
        cls.driver.implicitly_wait(5)  # чекати до 5 сек на елемент

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def _login_via_cookie(self):
        """Швидкий логін через session cookie (без форми)."""
        # 1. Test Client створює session у БД
        self.client.force_login(self.user)
        session_cookie = self.client.cookies['sessionid']

        # 2. Браузер має бути на домені перед add_cookie
        self.driver.get(f'{self.live_server_url}/')

        # 3. Копіюємо session cookie до Selenium
        self.driver.add_cookie({
            'name': 'sessionid',
            'value': session_cookie.value,
            'path': '/',
        })
        # Тепер driver залогінений = той самий user що і self.client
```

---

## Запуск через `docker compose exec` (не `run`!)

```bash
# ❌ НЕПРАВИЛЬНО — docker compose run:
docker compose run --rm web python manage.py test notes_app.tests.test_selenium
# run створює НОВИЙ контейнер
# Новий контейнер не має DNS alias "web" у мережі
# Selenium намагається GET http://web:8001/... → Cannot resolve host

# ✅ ПРАВИЛЬНО — docker compose exec:
docker compose up -d   # спочатку підняти стек
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec виконується У вже запущеному контейнері web
# web контейнер вже зареєстрований у Docker network з alias "web"
# Selenium: GET http://web:8001/ → DNS resolution → IP контейнера web
```

---

## Чому `exec`, а не `run`

`docker compose run` створює **новий** контейнер з тим самим образом. Цей контейнер:
- Не має зареєстрованого DNS alias `"web"` у мережі `app-net` (цей alias прив'язаний до оригінального запущеного контейнера)
- Починає своє власне `entrypoint.sh` (migrate, collectstatic знову)
- Ізольований від selenium, nginx та інших сервісів стеку

`docker compose exec` виконує команду **всередині** вже запущеного контейнера `web`. Цей контейнер:
- Вже зареєстрований з alias `"web"` у Docker мережі
- Selenium у `selenium` контейнері резолює `http://web:PORT` → IP цього контейнера
- Немає повторних міграцій або seed

---

## VNC — переглянути Selenium браузер живцем

```bash
# http://localhost:7900  (пароль: secret)
# ↑ Відкриє VNC viewer де видно Chrome в реальному часі
```

Корисно для дебагу Selenium тестів:
- Бачиш що саме знаходить driver
- Бачиш стан форм при помилках
- Бачиш JavaScript алерти і popups
- Розумієш чому `find_element` не може знайти елемент

---

## Запуск всіх тестів

```bash
# ─── Через Docker (рекомендовано) ──────────────────────────────────────────

# Всі unit + integration + consumer тести (можна через run):
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# Selenium E2E тести (EXEC не RUN!):
docker compose up -d                    # спочатку підняти стек
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# Конкретний клас:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# Зупинитись на першому провалі:
docker compose run --rm web python manage.py test notes_app.tests --failfast

# Coverage:
docker compose run --rm web sh -c "
  coverage run manage.py test notes_app.tests.test_models notes_app.tests.test_services \
    notes_app.tests.test_forms notes_app.tests.test_views notes_app.tests.test_consumers
  coverage report --show-missing
"
```

---

## У книзі

- [Частина VIII. Testing і Quality](../../08_testing_and_quality/README.md) — піраміда тестів, Selenium E2E, StaticLiveServerTestCase, WebDriver API
- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker networking, DNS між контейнерами, `exec` vs `run`

---

## Офіційна документація

- [Selenium: Remote WebDriver](https://www.selenium.dev/documentation/webdriver/drivers/remote_webdriver/) — підключення до Selenium Grid / standalone
- [Selenium: standalone-chrome Docker image](https://github.com/SeleniumHQ/docker-selenium) — `shm_size`, VNC на :7900
- [Django: StaticLiveServerTestCase](https://docs.djangoproject.com/en/5.2/topics/testing/tools/#django.test.LiveServerTestCase) — live server host, port, URL
- [Django: Testing tools](https://docs.djangoproject.com/en/5.2/topics/testing/tools/) — force_login, Client.cookies, session management у тестах
