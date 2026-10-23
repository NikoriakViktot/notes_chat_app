# CI/CD and GitHub Actions: automated testing of a Django project

> This file is a self-contained reference on CI/CD in the context of Django Testing.
> It explains: what CI/CD is, how GitHub Actions works, how to read
> the existing `django-tests.yml` in our project, and how all of this relates to the tests
> you are already writing.

---

## Contents

**Concepts**
- [1. The problem CI/CD solves](#1-the-problem-cicd-solves)
- [2. What CI/CD is](#2-what-cicd-is)
- [3. Continuous Integration vs Continuous Delivery vs Continuous Deployment](#3-continuous-integration-vs-continuous-delivery-vs-continuous-deployment)

**GitHub Actions**
- [4. GitHub Actions components](#4-github-actions-components)
- [5. How to read a YAML workflow](#5-how-to-read-a-yaml-workflow)
- [6. Our django-tests.yml — line by line](#6-our-django-testsyml--line-by-line)
- [7. Events — when to run](#7-events--when-to-run)
- [8. Jobs and Steps — what runs and how](#8-jobs-and-steps--what-runs-and-how)
- [9. Actions — ready-made building blocks](#9-actions--ready-made-building-blocks)
- [10. Runners — where the code runs](#10-runners--where-the-code-runs)

**Practice**
- [11. How to view results on GitHub](#11-how-to-view-results-on-github)
- [12. CI/CD and the testing pyramid](#12-cicd-and-the-testing-pyramid)
- [13. GitHub Pages — publishing a static site](#13-github-pages--publishing-a-static-site)
- [14. Common errors and how to read them](#14-common-errors-and-how-to-read-them)
- [15. Self-check questions](#15-self-check-questions)

---

## 1. The problem CI/CD solves

Imagine this situation. You wrote a function `create_note_for_user`. It passed the local tests. You did `git push`. Two hours later it turns out that the form on the registration page no longer saves data.

How does that happen? You didn't touch the form. But somewhere a change in the service layer pulled in a dependency you didn't see.

Without automation, this chain looks like this:

```
Developer A         Developer B         Deploy to production
writes feature ─┐   writes feature ─┐
                │                   │
                └── manual merge ───┴── manual tests ── manual deploy
                   (merge conflicts!)  (someone forgot)  (2+ hrs of rituals)
```

And then there's a bug in production. And nobody knows exactly whose change caused it.

**This is exactly what CI/CD solves:** every `git push` automatically runs the full test suite on a clean server. If the tests pass, the code is safe to merge. If they fail, the developer sees it before the code ever reaches `main`.

---

## 2. What CI/CD is

**CI/CD** stands for Continuous Integration / Continuous Delivery (or Deployment).

It is not a single tool or a single button. It is a way of organizing a team's work so that testing and deployment happen automatically after every change.

In short:

| Abbreviation | Name | What it does |
|---|---|---|
| CI | Continuous Integration | Automatically builds and tests the code after every push |
| CD | Continuous Delivery | Automatically prepares a build for production — but a human deploys it |
| CD | Continuous Deployment | Automatically deploys to production without human involvement |

The difference between Delivery and Deployment comes down to one word: **human**. In Delivery, a human clicks the confirm button. In Deployment, nobody does.

An important idea:

> CI/CD is not about tools. It is about tests running automatically and feedback arriving quickly.

---

## 3. Continuous Integration vs Continuous Delivery vs Continuous Deployment

A detailed diagram:

```mermaid
flowchart LR
    subgraph CI["Continuous Integration"]
        direction LR
        A[git push] --> B["Build<br>Install deps"]
        B --> C["Lint<br>Type check"]
        C --> D["Unit Tests<br>Integration Tests"]
        D --> E{Passed?}
        E -- yes --> F[Notify: OK]
        E -- no --> G["Block PR<br>Notify: Failed"]
    end

    subgraph DELIVERY["Continuous Delivery"]
        direction LR
        H[Artifact ready] --> I[Deploy: Staging]
        I --> J[Smoke Tests]
        J --> K{OK?}
        K -- yes --> L[Human approves]
        L --> M[Deploy: Production]
        K -- no --> N[Rollback Staging]
    end

    subgraph DEPLOYMENT["Continuous Deployment"]
        direction LR
        O[Artifact ready] --> P[Deploy: Staging]
        P --> Q[Automated Tests]
        Q --> R{OK?}
        R -- yes --> S[Auto Deploy: Production]
        R -- no --> T[Auto Rollback]
    end

    CI --> DELIVERY
    CI --> DEPLOYMENT

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class A,B,C,D,H,I,J,O,P,Q step;
    class E,K,R decision;
    class F,M,S success;
    class G,N,T error;
    class L warning;
```

Where is our `notes_chat_app` right now? At the **CI** level: every push to `main` runs the tests. Deployment is not automated yet — but this is the first and most important step.

---

## 4. GitHub Actions components

GitHub Actions is a CI/CD platform built right into GitHub. No third-party services are needed.

The component hierarchy:

```
Repository
└── .github/
    └── workflows/
        └── django-tests.yml     ← Workflow
            │
            ├── on: push         ← Event (trigger)
            │
            └── jobs:
                ├── unit-and-integration:  ← Job 1
                │   ├── step 1   ← Step: checkout
                │   ├── step 2   ← Step: setup-python
                │   └── step 3   ← Step: manage.py test
                │
                └── selenium-e2e:  ← Job 2 (needs: unit-and-integration)
                    ├── step 1
                    └── step 2
```

| Component | What it is | Analogy |
|---|---|---|
| Workflow | The whole scenario in a YAML file | The script of a play |
| Event | The trigger that starts the workflow | The curtain rises |
| Job | A set of steps on one runner | An act of the play |
| Step | One command or action | A single scene |
| Action | A ready-made reusable step | A prop from a store |
| Runner | The server where the code runs | The stage |

---

## 5. How to read a YAML workflow

A workflow is a YAML file. Here is a minimal example with explanations:

```yaml
name: Django Tests          # Name (shown in GitHub → Actions)

on:                         # When to run
  push:
    branches: [main]        # On push to main

jobs:                       # What to do
  test:                     # Job name
    runs-on: ubuntu-latest  # On which OS

    steps:                  # Steps in order
      - uses: actions/checkout@v4       # Clone the repository
      - uses: actions/setup-python@v5   # Install Python
        with:
          python-version: "3.12"
      - run: pip install -r requirements.txt   # Shell command
      - run: python manage.py test             # Run the tests
```

Reading rules:
- `uses:` — use a ready-made action (from the marketplace)
- `run:` — run a shell command
- `with:` — parameters for an action
- `needs:` — this job waits for another one
- `env:` — environment variables

---

## 6. Our django-tests.yml — line by line

Our project already has a workflow:

```
.github/workflows/django-tests.yml
```

Note: the Django project (`manage.py`, `requirements.txt`) sits right in the repository root, so the workflow lives in the root `.github/workflows/` too, and GitHub **runs it automatically**. GitHub ignores a workflow placed in any other folder (for example, inside `docs/`). There is only one correct place:

```
<repo-root>/.github/workflows/django-tests.yml
```

Let's go through it piece by piece.

### Triggers

```yaml
on:
  push:
    branches: [ main, master ]   # push to main or master
  pull_request:
    branches: [ main, master ]   # PR to main or master
  workflow_dispatch:             # manual run via a button in the UI
```

In the real file, `push` and `pull_request` also have a `paths:` filter (`notes_app/**`, `notes_project/**`, `templates/**`, `static/**`, `requirements.txt` and the workflow itself): changes that touch only the documentation do not run the tests.

What happens: if someone opens a Pull Request to `main` → GitHub sees `on: pull_request` → runs the workflow → the result (green/red) appears right in the PR.

### Job 1: Unit + Integration tests

```yaml
jobs:
  unit-and-integration:
    name: Unit, Integration & Consumer Tests
    runs-on: ubuntu-latest

    services:
      db:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: notes_db
          POSTGRES_USER: notes_user
          POSTGRES_PASSWORD: notes_pass
        ports:
          - 5432:5432
        # ... health-check options (pg_isready)

    env:
      DATABASE_URL: postgres://notes_user:notes_pass@localhost:5432/notes_db
```

`ubuntu-latest` is a fresh VM on Azure that is destroyed after every run. There is no state between runs.

`services.db` is a PostgreSQL container next to the runner: the project works only with PostgreSQL, so the tests get their database through `DATABASE_URL`.

```yaml
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
```

The first step is always the same: clone the repository onto the VM. Without this step, the runner doesn't have your code at all.

```yaml
      - name: Cache pip dependencies
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-
```

A cache of pip dependencies. If `requirements.txt` hasn't changed, pip packages are loaded from the cache instead of the internet. This speeds up the pipeline from 3 minutes to 1 minute.

```yaml
      - name: Django system check
        run: python manage.py check
```

`manage.py check` is a built-in Django command. It checks the configuration, models, and middleware without starting the server. If you have an error in `settings.py`, you'll find out before the tests even run.

```yaml
      - name: Run unit, integration and consumer tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2
```

Runs all tests except Selenium (those are in a separate job), including the WebSocket tests in `test_consumers`. The `-v 2` parameter means verbose — it shows the name of every test.

```yaml
      - name: Generate coverage report
        run: |
          coverage run manage.py test ...
          coverage report --show-missing
          coverage xml -o coverage.xml
```

Coverage: runs the tests via `coverage run` to track which lines of code were executed. `coverage xml` generates a file for integration with services such as Codecov.

```yaml
      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-xml
          path: coverage.xml
```

Saves `coverage.xml` as an artifact — a file you can download through the GitHub UI after the workflow finishes.

### Job 2: Selenium E2E

```yaml
  selenium-e2e:
    name: Selenium E2E Tests
    needs: unit-and-integration   # Run AFTER the "unit-and-integration" job succeeds
    runs-on: ubuntu-latest

    services:
      db:
        image: postgres:16-alpine
        # ... the same as in Job 1

      selenium:
        image: selenium/standalone-chrome:latest
        ports:
          - 4444:4444
        options: >-
          --add-host=host.docker.internal:host-gateway
          --shm-size=2gb
        # ... health-check options

    env:
      DATABASE_URL: postgres://notes_user:notes_pass@localhost:5432/notes_db
      SELENIUM_REMOTE_URL: http://localhost:4444/wd/hub
      WEB_HOST: host.docker.internal
```

`services` are Docker containers that start alongside the runner. Selenium/standalone-chrome runs Chrome in headless mode. Our test connects to it via `http://localhost:4444`. `--add-host=host.docker.internal:host-gateway` together with `WEB_HOST=host.docker.internal` lets Chrome inside the container open the Django test server running on the runner.

```yaml
    steps:
      # ... checkout, setup-python, cache, pip install
      - name: Run Selenium E2E tests
        run: python manage.py test notes_app.tests.test_selenium -v 2
```

`SELENIUM_REMOTE_URL` is an environment variable read by `_make_headless_driver()` in `notes_app/tests/test_selenium.py`. `WEB_HOST` is read by `_DockerLiveServerMixin`: it binds the test server to `0.0.0.0` and puts `host.docker.internal` into `live_server_url`. If it is set, Selenium connects to a Remote WebDriver instead of a local browser.

---

## 7. Events — when to run

The most commonly used triggers:

```yaml
on:
  # On push to specific branches
  push:
    branches: [main, develop]
    paths: ['notes_app/**', 'tests/**']  # Only if these files changed

  # When a PR is opened or updated
  pull_request:
    types: [opened, synchronize, reopened]

  # On a schedule (cron syntax)
  schedule:
    - cron: '0 6 * * 1'   # Every Monday at 6:00 UTC

  # Manual run via the GitHub UI
  workflow_dispatch:

  # When a release is published
  release:
    types: [published]
```

Practical tip: for a learning project, `push` and `pull_request` are enough. `schedule` is useful for nightly full test runs, and `release` for deploying when a version is published.

---

## 8. Jobs and Steps — what runs and how

### Parallelism and dependencies

By default, jobs run **in parallel**. `needs` changes that:

```yaml
jobs:
  lint:          # Starts immediately
    ...
  test:          # Starts immediately (in parallel with lint)
    ...
  test-selenium:
    needs: test  # Waits for test
    ...
  deploy:
    needs: [lint, test]   # Waits for BOTH
    ...
```

What it looks like over time:

```
Time:   0s          30s         60s         90s
        │           │           │           │
lint    ├───────────┤
test    ├───────────────────────┤
selenium                        ├───────────┤
deploy              (won't start until lint and test pass)
```

### Conditional execution

```yaml
steps:
  - name: Deploy (only on success)
    if: success()
    run: ./deploy.sh

  - name: Notify about a failure (any failure)
    if: failure()
    run: ./notify.sh

  - name: Clean up temp files (always)
    if: always()
    run: rm -rf /tmp/test_*

  - name: Deploy only from main
    if: github.ref == 'refs/heads/main'
    run: ./deploy.sh
```

---

## 9. Actions — ready-made building blocks

Actions are reusable steps from the GitHub Marketplace.

### The most commonly used ones in Django projects

```yaml
# Clone the repository (always the first step)
- uses: actions/checkout@v4

# Install Python with a pip cache
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'            # Caches pip automatically

# Manual cache (more control)
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}

# Save a file as an artifact
- uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: coverage.xml
    retention-days: 7       # Keep for 7 days

# Download an artifact in another job
- uses: actions/download-artifact@v4
  with:
    name: test-results
```

### Passing data between Jobs

Jobs do not share a file system. To pass data, use artifacts or outputs:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.ver.outputs.version }}
    steps:
      - id: ver
        run: echo "version=$(cat VERSION)" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }}"
```

---

## 10. Runners — where the code runs

### GitHub-hosted runners

| Runner | OS | CPU | RAM |
|---|---|---|---|
| `ubuntu-latest` | Ubuntu 22.04 | 2-core | 7 GB |
| `windows-latest` | Windows Server 2022 | 2-core | 7 GB |
| `macos-latest` | macOS 13 | 3-core | 14 GB |

For Django projects, always use `ubuntu-latest` — the fastest and cheapest.

### What happens when you do git push

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant GH as GitHub
    participant VM as Runner VM (Azure)

    DEV->>GH: git push main
    GH->>GH: Detect workflow trigger

    GH->>VM: Provision fresh Ubuntu VM
    VM->>VM: actions/checkout → clone repo
    VM->>VM: pip install -r requirements.txt
    VM->>VM: python manage.py check
    VM->>VM: python manage.py test -v 2
    VM-->>GH: Test results

    GH-->>DEV: ✅ All tests passed (or ❌ Failed)
    GH->>VM: Terminate VM (ephemeral!)

    Note over VM: The VM is destroyed. Next push gets a new clean VM.
```

An important detail: the VM is **ephemeral** — it is destroyed after every run. There is no "state" whatsoever between runs. If tests pass on the runner, they pass on a clean machine without your local settings.

---

## 11. How to view results on GitHub

1. Open the repository on GitHub
2. The **Actions** tab — a list of all workflow runs
3. Click a specific run — you'll see the jobs graph
4. Click a job — you'll see the list of steps
5. Click a step — you'll see live logs

### What the colors mean

| Color | Meaning |
|---|---|
| Green ✅ | The Step/Job finished successfully |
| Yellow 🟡 | The Step/Job is running right now |
| Red ❌ | The Step/Job failed |
| Gray ⏭ | The Step/Job was skipped (because of `if:` or `needs:`) |

### Live logs — your best debugging tool

Each step expands into a full log with:
- A timestamp for every line
- The process's stdout and stderr
- A "Download log archive" button

If a test fails, expand the test step and read the output the same way you read it locally.

---

## 12. CI/CD and the testing pyramid

Remember the pyramid from the ["Testing pyramid"](testing_foundations_full.md#8-the-testing-pyramid) section?

```
        E2E / Selenium
      integration tests
    unit tests (foundation)
```

In CI/CD, each level has its own role:

```mermaid
flowchart TD
    PUSH([git push]) --> CI

    subgraph CI["CI Pipeline"]
        direction LR
        L["Lint · ~30s<br>black, flake8"] --> U["Unit Tests · ~60s<br>test_models, test_services"]
        U --> I["Integration Tests · ~90s<br>test_forms, test_views"]
        I --> E["E2E Selenium · ~120s<br>test_selenium"]
    end

    CI --> STATUS{Status?}
    STATUS -- ✅ All green --> MERGE[Safe to merge PR]
    STATUS -- ❌ Lint failed --> FIX_LINT[Fix formatting]
    STATUS -- ❌ Unit failed --> FIX_LOGIC[Fix business logic]
    STATUS -- ❌ Integration failed --> FIX_VIEWS[Fix views/forms]
    STATUS -- ❌ E2E failed --> FIX_E2E[Fix user flow]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    class PUSH,L,U,I,E step;
    class STATUS decision;
    class MERGE success;
    class FIX_LINT,FIX_LOGIC,FIX_VIEWS,FIX_E2E error;
```

Why does the order matter? Lint fails within 30 seconds. If there's a formatting problem, you'll find out before you spend 5 minutes on a full run. "Fail fast" is a principle of good CI.

---

## 13. GitHub Pages — publishing a static site

GitHub Pages is a built-in way to publish a static site directly from a repository. Useful for Django documentation or a landing page.

### Option 1: Publishing from a branch (simple)

```
Settings → Pages → Source: Deploy from a branch
    └── Branch: main, /docs
```

Put HTML/CSS into the `docs/` folder → push → the site is available at `username.github.io/repo`.

### Option 2: Via GitHub Actions (flexible)

```yaml
name: Deploy Documentation

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Build MkDocs site
        run: |
          pip install mkdocs mkdocs-material
          mkdocs build

      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./site

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment
```

### Important limitations

```
⚠️  The site is PUBLICLY available on the internet — even if the repository is private.

⚠️  A CNAME file in the repository does NOT configure a custom domain.
    The domain is changed only via Settings → Pages.

ℹ️  A push via GITHUB_TOKEN does not trigger a Pages rebuild
    (protection against infinite recursion).
```

---

## 14. Common errors and how to read them

### The workflow does not start

```
Symptom:  the push was made, but there is no new run in the Actions tab

Causes:
  - The YAML file is not in <repo-root>/.github/workflows/ (for example, it sits in docs/)
  - A syntax error in the YAML (check the indentation)
  - The branch does not match the filter in on.push.branches

Diagnosis:  GitHub → Actions → "Check workflows", or look for the red icon
            next to the commit in the commit list
```

### Process completed with exit code 1

```
Symptom:  The "Run unit tests" step is red, and the log shows:
          FAIL: test_login_required (notes_app.tests.test_views.NoteListViewTest.test_login_required)

Cause:    A test failed. That's normal — this is what CI is for.

Action:   Expand the step → read the traceback → fix the code or the test
```

### Permission denied / Resource not accessible

```
Symptom:  The "Upload artifact" or "Deploy Pages" step is red

Cause:    The workflow lacks the required permissions

Solution: Add at the top level of the YAML:
          permissions:
            contents: read
            pages: write
            id-token: write
```

### Cache miss every time

```
Symptom:  pip install takes 3 minutes on every run

Cause:    the cache key keeps changing — maybe hashFiles picks the wrong file

Solution: Check the path:
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
                                       ↑ the glob looks for requirements.txt
                                         in any subfolder
```

### A secret is not passed into the environment

```
Symptom:  The step fails with "API key not found" or "env var is None"

Cause:    The secret exists in Settings but is not passed into the workflow

Solution:
    - name: Deploy
      env:
        API_KEY: ${{ secrets.MY_API_KEY }}  ← pass it explicitly
      run: ./deploy.sh
```

---

## 15. Self-check questions

1. How does CI differ from Continuous Delivery and Continuous Deployment?
2. Why is the runner VM destroyed after every run — is it an advantage or a limitation?
3. Why must `actions/checkout@v4` be the first step?
4. Why is `needs: unit-and-integration` in `selenium-e2e` important?
5. What happens if `on: push` is specified without `branches: [main]`?
6. Why cache pip dependencies if you could simply install them every time?
7. Where is our `django-tests.yml` located, and why does GitHub run it automatically?
8. What role does `SELENIUM_REMOTE_URL` play in Job 2, and where does the test code read this variable?
9. Why does lint run first in the pipeline and Selenium last?
10. If a test fails in CI but passes locally — what should you check first?
