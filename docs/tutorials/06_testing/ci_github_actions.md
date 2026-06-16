# GitHub Actions CI

> **Мета:** кожен `git push` автоматично запускає ті самі тести, які ти щойно навчився писати.
> Без твоєї участі. На чистому сервері. З результатом у GitHub за 2–3 хвилини.

---

## Де живе workflow

```
notes_chat_app/                   ← корінь репозиторію
└── .github/
    └── workflows/
        └── ci.yml                ← GitHub бачить тільки files у .github/workflows/
```

GitHub Actions читає workflow **ТІЛЬКИ** з директорії `.github/workflows/` у кореневій папці репозиторію.

---

## Що відбувається при `git push`

```
Ти:  git push origin main
         │
         ▼
GitHub:  Detect event → push до main
         │
         ▼
Azure:   Provision Ubuntu 22.04 VM (нова, чиста)
         │
         ├── Job 1: Unit + Integration + Consumer (~1-2 хв)
         │     checkout → python 3.12 → pip install
         │     → PostgreSQL service → Redis service
         │     → manage.py test models/services/forms/views/consumers
         │     Результат: ✅ або ❌
         │
         └── Job 2: Selenium E2E (~1-2 хв) — тільки якщо Job 1 ✅
               checkout → pip install → migrations
               → PostgreSQL + Redis + Selenium Chrome service
               → manage.py test test_selenium
               Результат: ✅ або ❌
         │
         ▼
GitHub:  Зелений/червоний статус на коміті + email якщо ❌
```

---

## Повний workflow YAML рядок за рядком

```yaml
# .github/workflows/ci.yml
name: CI — Test Suite
```

Ця назва відображається у вкладці **Actions** у GitHub.

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:
```

**`on`** — визначає коли запускати workflow.

| Ключ | Що означає |
|------|-----------|
| `push` | При кожному git push |
| `branches` | Тільки для гілок `main` або `master` |
| `pull_request` | При відкритті або оновленні PR |
| `workflow_dispatch` | Кнопка "Run workflow" у GitHub UI → Actions |

---

### Job 1: Unit + Integration + Consumer Tests

```yaml
jobs:
  test:
    name: Unit + Integration + Consumer tests
    runs-on: ubuntu-latest
```

**`runs-on: ubuntu-latest`** — свіжа Ubuntu 22.04 VM на Azure. Після завершення VM знищується. Між запусками немає стану.

```yaml
    services:
      # PostgreSQL у GitHub Actions (окремий container)
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user -d test_notes_db"
          --health-interval 5s
          --health-retries 5

      # Redis для channel layer
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
```

**`services`** — додаткові Docker containers, що запускаються поруч з runner VM.
`health-cmd` + `health-interval` + `health-retries` — GitHub Actions чекає поки сервіс стане healthy перед початком steps.

```yaml
    env:
      DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:    redis://localhost:6379/0
      SECRET_KEY:   ci-secret-key-not-for-production
      DEBUG:        "False"
      ALLOWED_HOSTS: localhost,127.0.0.1
```

Змінні середовища для Django. `DATABASE_URL` вказує на PostgreSQL service container (`localhost:5432`).

---

**Step 1 — Checkout**

```yaml
    steps:
      - uses: actions/checkout@v4
```

Клонує весь репозиторій на VM. Без цього кроку на runner немає жодного файлу з твоїм кодом.

---

**Step 2 — Setup Python**

```yaml
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip
```

Встановлює Python 3.12. `cache: pip` — кешує `~/.cache/pip` між запусками (аналог `actions/cache`, але вбудований у `setup-python`).

---

**Step 3 — Install dependencies**

```yaml
      - name: Install dependencies
        run: pip install -r requirements.txt
```

---

**Step 4 — Run Unit + Integration tests**

```yaml
      - name: Run Unit + Integration tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2
```

Запускає 123+ тестів. Явно перераховані модулі без `test_selenium` — Selenium в окремому job.

`-v 2` — verbose: кожен тест виводиться окремим рядком. В CI це корисно: одразу видно яке ім'я тесту впало.

Якщо будь-який тест повертає `FAILED` → step повертає exit code 1 → GitHub Actions вважає step провалений → job зупиняється → Job 2 (selenium) не запускається.

---

### Job 2: Selenium E2E

```yaml
  selenium-e2e:
    name: Selenium E2E tests
    runs-on: ubuntu-latest
    needs: test          # ← запускається ПІСЛЯ успіху unit тестів
```

**`needs: test`** — Job 2 запускається тільки після того як Job 1 завершився успішно. Якщо unit тести впали — Selenium навіть не стартує.

```yaml
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user"
          --health-interval 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ['6379:6379']

      selenium:
        image: selenium/standalone-chrome:latest
        ports: ['4444:4444']
        options: --shm-size=2g   # Chrome потребує shared memory
```

**`--shm-size=2g`** — Chrome потребує достатньо shared memory. Без цього Chrome може падати з OOM.

```yaml
    env:
      DATABASE_URL:        postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:           redis://localhost:6379/0
      SECRET_KEY:          ci-secret-key
      DEBUG:               "False"
      ALLOWED_HOSTS:       localhost,127.0.0.1
      SELENIUM_REMOTE_URL: http://localhost:4444/wd/hub
      WEB_HOST:            localhost
```

- `SELENIUM_REMOTE_URL` — `_make_driver()` використовує Remote WebDriver замість локального Chrome
- `WEB_HOST` — `_DockerLiveServerMixin` замінює `0.0.0.0` на `localhost` у `live_server_url`

```yaml
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run migrations
        run: python manage.py migrate --noinput

      - name: Run Selenium E2E tests
        run: python manage.py test notes_app.tests.test_selenium -v 2

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: selenium-screenshots
          path: /tmp/selenium-*.png
```

**`if: failure()`** — крок виконується ТІЛЬКИ якщо попередній крок провалився. Якщо тест падає і зберігає screenshot → він доступний у GitHub Actions → Artifacts.

---

## Повний workflow (для копіювання)

```yaml
# .github/workflows/ci.yml
name: CI — Test Suite

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  test:
    name: Unit + Integration + Consumer tests
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user -d test_notes_db"
          --health-interval 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s

    env:
      DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:    redis://localhost:6379/0
      SECRET_KEY:   ci-secret-key-not-for-production
      DEBUG:        "False"
      ALLOWED_HOSTS: localhost,127.0.0.1

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Django system check
        run: python manage.py check

      - name: Run Unit + Integration tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2

      - name: Generate coverage report
        run: |
          coverage run manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers
          coverage report --show-missing
          coverage xml -o coverage.xml

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-xml
          path: coverage.xml

  selenium-e2e:
    name: Selenium E2E tests
    runs-on: ubuntu-latest
    needs: test

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user"
          --health-interval 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ['6379:6379']

      selenium:
        image: selenium/standalone-chrome:latest
        ports: ['4444:4444']
        options: --shm-size=2g

    env:
      DATABASE_URL:        postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:           redis://localhost:6379/0
      SECRET_KEY:          ci-secret-key
      DEBUG:               "False"
      ALLOWED_HOSTS:       localhost,127.0.0.1
      SELENIUM_REMOTE_URL: http://localhost:4444/wd/hub
      WEB_HOST:            localhost

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run migrations
        run: python manage.py migrate --noinput

      - name: Run Selenium E2E tests
        run: python manage.py test notes_app.tests.test_selenium -v 2

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: selenium-screenshots
          path: /tmp/selenium-*.png
```

---

## Coverage report

```
coverage run manage.py test ...
coverage report --show-missing
```

Вивід:

```
Name                          Stmts   Miss  Cover   Missing
-----------------------------------------------------------
notes_app/models.py             87      3    97%   45, 67, 89
notes_app/services.py          124      8    94%   34-41
notes_app/views.py             198     12    94%   ...
notes_app/consumers.py          56      4    93%   ...
-----------------------------------------------------------
TOTAL                          465     27    94%
```

`coverage xml -o coverage.xml` — зберігає у XML для інтеграції з Codecov / SonarQube.

---

## Як переглянути результати

**1. Actions tab у репозиторії**

```
https://github.com/<user>/<repo>/actions
```

Тут список всіх workflow runs. Зелений — all green. Червоний — щось впало.

**2. Граф Jobs**

Клікни на конкретний run → бачиш два прямокутники:

```
[Unit + Integration Tests] ──needs──► [Selenium E2E Tests]
      ✅ 1m 23s                              ✅ 1m 47s
```

**3. Logs конкретного step**

Клікни на job → клікни на step → розгорни:

```
Run python manage.py test ...

Creating test database for alias 'default' ...
Found 123 test(s).
test_str_returns_hash_name (notes_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
...
----------------------------------------------------------------------
Ran 123 tests in 34.2s
OK
```

**4. Download artifacts**

Actions run → Artifacts (внизу сторінки) → `coverage-xml` → завантажити.

**5. Статус на коміті**

Кожен коміт отримує значок:
- `✅` — всі workflow пройшли
- `❌` — хтось впав
- `🟡` — виконується

---

## Зв'язок: тести ↔ CI/CD

```
Ти пишеш:                  CI/CD запускає:            Ти отримуєш:

test_models.py    ─────►   Job 1 (unit+integration)  ──► ✅ або ❌ за 30 сек
test_services.py  ─────►                             ──► Traceback прямо в GitHub
test_forms.py     ─────►
test_views.py     ─────►
test_consumers.py ─────►

test_selenium.py  ─────►   Job 2 (needs: job1)       ──► ✅ або ❌ після Job 1
                                                      ──► Chrome у Docker container
```

---

## Що означають рядки у лозі при помилці

```
FAIL: test_note_list_shows_only_user_notes
      ↑ Назва тесту → одразу зрозуміло ЩО зламалось

(notes_app.tests.test_views.NoteListViewTest)
      ↑ Клас і файл → можеш одразу відкрити

Traceback (most recent call last):
  File ".../test_views.py", line 89, in test_note_list_shows_only_user_notes
    self.assertNotContains(response, "Bob's Secret Note")
AssertionError: Response should not contain "Bob's Secret Note"
      ↑ Очікували що рядка НЕМАЄ, але він є → нотатки Bob'а видимі Alice!
      → Баг у selectors.get_user_notes() — забули фільтр по user

Process completed with exit code 1
      ↑ Django test runner повернув 1 → GitHub Actions вважає step провалений
```

---

## Посилання на документацію

| Тема | Посилання |
|------|-----------|
| GitHub Actions — Quick Start | https://docs.github.com/en/actions/writing-workflows/quickstart |
| Understanding GitHub Actions | https://docs.github.com/en/actions/about-github-actions/understanding-github-actions |
| Events that trigger workflows | https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows |
| Workflow syntax (повний довідник) | https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions |
| Caching dependencies | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows |
| GitHub-hosted runners | https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners |
| actions/checkout | https://github.com/marketplace/actions/checkout |
| actions/setup-python | https://github.com/marketplace/actions/setup-up-a-specific-version-of-python |
| actions/cache | https://github.com/marketplace/actions/cache |
| actions/upload-artifact | https://github.com/marketplace/actions/upload-a-build-artifact |
| Coverage.py | https://coverage.readthedocs.io/en/latest/ |
| Django system check | https://docs.djangoproject.com/en/5.2/topics/checks/ |

---

## Практика: перевір що CI/CD працює

1. Відкрий у браузері: `https://github.com/<user>/<repo>/actions`
2. Знайди workflow **"CI — Test Suite"**
3. Клікни на останній run
4. Розгорни Job 1 → Step "Run Unit + Integration tests"
5. Знайди рядок `Ran ... tests in ... OK`
6. Перейди до Job 2 → подивись як запускається Selenium у Docker container

**Самостійно:** зроби навмисну помилку в будь-якому тесті (`assertFalse(True)`), зроби `git push`, подивись як CI показує FAIL і Traceback у GitHub Actions.

---

## Далі

- **[Checkpoint](checkpoint.md)** — очікуваний результат, чеклист, практичне завдання
