# GitHub Actions CI

> **Goal:** every `git push` automatically runs the same tests you have just learned to write.
> Without your involvement. On a clean server. With the result in GitHub within 2–3 minutes.

---

## Where the workflow lives

```
notes_chat_app/                   ← repository root
└── .github/
    └── workflows/
        └── ci.yml                ← GitHub only sees files in .github/workflows/
```

GitHub Actions reads workflows **ONLY** from the `.github/workflows/` directory in the repository root.

---

## What happens on `git push`

```
You:     git push origin main
         │
         ▼
GitHub:  Detect event → push to main
         │
         ▼
Azure:   Provision Ubuntu 24.04 VM (new, clean)
         │
         ├── Job 1: Unit + Integration + Consumer (~1-2 min)
         │     checkout → python 3.12 → pip install
         │     → PostgreSQL service → Redis service
         │     → manage.py test models/services/forms/views/consumers
         │     Result: ✅ or ❌
         │
         └── Job 2: Selenium E2E (~1-2 min) — only if Job 1 ✅
               checkout → pip install → migrations
               → PostgreSQL + Redis + Selenium Chrome service
               → manage.py test test_selenium
               Result: ✅ or ❌
         │
         ▼
GitHub:  Green/red status on the commit + email if ❌
```

---

## The full workflow YAML line by line

```yaml
# .github/workflows/ci.yml
name: CI — Test Suite
```

This name is shown in the **Actions** tab on GitHub.

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:
```

**`on`** — defines when the workflow runs.

| Key | What it means |
|------|-----------|
| `push` | On every git push |
| `branches` | Only for the `main` or `master` branches |
| `pull_request` | When a PR is opened or updated |
| `workflow_dispatch` | The "Run workflow" button in the GitHub UI → Actions |

---

### Job 1: Unit + Integration + Consumer Tests

```yaml
jobs:
  test:
    name: Unit + Integration + Consumer tests
    runs-on: ubuntu-latest
```

**`runs-on: ubuntu-latest`** — a fresh Ubuntu 24.04 VM on Azure. After completion the VM is destroyed. There is no state between runs.

```yaml
    services:
      # PostgreSQL in GitHub Actions (a separate container)
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

      # Redis for the channel layer
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
```

**`services`** — additional Docker containers that run alongside the runner VM.
`health-cmd` + `health-interval` + `health-retries` — GitHub Actions waits until the service becomes healthy before starting the steps.

```yaml
    env:
      DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:    redis://localhost:6379/0
      SECRET_KEY:   ci-secret-key-not-for-production
      DEBUG:        "False"
      ALLOWED_HOSTS: localhost,127.0.0.1
```

Environment variables for Django. `DATABASE_URL` points to the PostgreSQL service container (`localhost:5432`).

---

**Step 1 — Checkout**

```yaml
    steps:
      - uses: actions/checkout@v4
```

Clones the whole repository onto the VM. Without this step the runner has not a single file of your code.

---

**Step 2 — Setup Python**

```yaml
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip
```

Installs Python 3.12. `cache: pip` caches `~/.cache/pip` between runs (similar to `actions/cache`, but built into `setup-python`).

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

Runs 123+ tests. The modules are listed explicitly, without `test_selenium` — Selenium is in a separate job.

`-v 2` — verbose: each test is printed on its own line. This is useful in CI: you immediately see the name of the test that failed.

If any test returns `FAILED` → the step returns exit code 1 → GitHub Actions considers the step failed → the job stops → Job 2 (selenium) does not run.

---

### Job 2: Selenium E2E

```yaml
  selenium-e2e:
    name: Selenium E2E tests
    runs-on: ubuntu-latest
    needs: test          # ← runs AFTER the unit tests succeed
```

**`needs: test`** — Job 2 runs only after Job 1 has completed successfully. If the unit tests failed, Selenium doesn't even start.

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
        options: --shm-size=2g   # Chrome needs shared memory
```

**`--shm-size=2g`** — Chrome needs enough shared memory. Without it, Chrome may crash with OOM.

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

- `SELENIUM_REMOTE_URL` — `_make_driver()` uses a Remote WebDriver instead of a local Chrome
- `WEB_HOST` — `_DockerLiveServerMixin` replaces `0.0.0.0` with `localhost` in `live_server_url`

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

**`if: failure()`** — the step runs ONLY if a previous step failed. If a test fails and saves a screenshot → it is available in GitHub Actions → Artifacts.

---

## The full workflow (for copying)

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

Output:

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

`coverage xml -o coverage.xml` saves it as XML for integration with Codecov / SonarQube.

---

## How to view the results

**1. The Actions tab in the repository**

```
https://github.com/<user>/<repo>/actions
```

Here is the list of all workflow runs. Green means all green. Red means something failed.

**2. The Jobs graph**

Click a specific run → you see two boxes:

```
[Unit + Integration Tests] ──needs──► [Selenium E2E Tests]
      ✅ 1m 23s                              ✅ 1m 47s
```

**3. Logs of a specific step**

Click a job → click a step → expand it:

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

Actions run → Artifacts (at the bottom of the page) → `coverage-xml` → download.

**5. Status on the commit**

Every commit gets a badge:
- `✅` — all workflows passed
- `❌` — something failed
- `🟡` — in progress

---

## The connection: tests ↔ CI/CD

```
You write:                 CI/CD runs:                You get:

test_models.py    ─────►   Job 1 (unit+integration)  ──► ✅ or ❌ in 30 sec
test_services.py  ─────►                             ──► Traceback right in GitHub
test_forms.py     ─────►
test_views.py     ─────►
test_consumers.py ─────►

test_selenium.py  ─────►   Job 2 (needs: job1)       ──► ✅ or ❌ after Job 1
                                                      ──► Chrome in a Docker container
```

---

## What the lines in the log mean when there is an error

```
FAIL: test_note_list_shows_only_user_notes
      ↑ Test name → you immediately see WHAT broke

(notes_app.tests.test_views.NoteListViewTest)
      ↑ Class and file → you can open it right away

Traceback (most recent call last):
  File ".../test_views.py", line 89, in test_note_list_shows_only_user_notes
    self.assertNotContains(response, "Bob's Secret Note")
AssertionError: Response should not contain "Bob's Secret Note"
      ↑ We expected the string NOT to be there, but it is → Bob's notes are visible to Alice!
      → A bug in selectors.get_user_notes() — the user filter was forgotten

Process completed with exit code 1
      ↑ The Django test runner returned 1 → GitHub Actions considers the step failed
```

---

## Documentation links

| Topic | Link |
|------|-----------|
| GitHub Actions — Quick Start | https://docs.github.com/en/actions/writing-workflows/quickstart |
| Understanding GitHub Actions | https://docs.github.com/en/actions/about-github-actions/understanding-github-actions |
| Events that trigger workflows | https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows |
| Workflow syntax (full reference) | https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions |
| Caching dependencies | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows |
| GitHub-hosted runners | https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners |
| actions/checkout | https://github.com/marketplace/actions/checkout |
| actions/setup-python | https://github.com/marketplace/actions/setup-up-a-specific-version-of-python |
| actions/cache | https://github.com/marketplace/actions/cache |
| actions/upload-artifact | https://github.com/marketplace/actions/upload-a-build-artifact |
| Coverage.py | https://coverage.readthedocs.io/en/latest/ |
| Django system check | https://docs.djangoproject.com/en/5.2/topics/checks/ |

---

## Practice: check that CI/CD works

1. Open in the browser: `https://github.com/<user>/<repo>/actions`
2. Find the **"CI — Test Suite"** workflow
3. Click the latest run
4. Expand Job 1 → Step "Run Unit + Integration tests"
5. Find the line `Ran ... tests in ... OK`
6. Go to Job 2 → watch how Selenium runs in a Docker container

**On your own:** introduce a deliberate error in any test (`assertFalse(True)`), do a `git push`, and watch how CI shows FAIL and the Traceback in GitHub Actions.

---

## Next

- **[Checkpoint](checkpoint.md)** — expected result, checklist, practical exercise
