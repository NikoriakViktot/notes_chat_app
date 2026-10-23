# 16. DevOps workflow

## Why you need this

You wrote some code. You ran `git push`. Five minutes later the changes are already in production — automatically. No manual SSH, no copying files, no "I just deployed, please check". That is a **DevOps workflow**.

---

## What DevOps is

> DevOps is neither a job title nor a set of tools. It is a culture and a set of practices that help teams deliver changes quickly and safely from a developer's laptop to a production server.

**DevOps = Development + Operations.**

In the past: developers wrote code, and a separate team (operations) deployed and maintained it. Between them stood a "wall" and constant conflicts.

Today: teams are jointly responsible for the whole path of the code — from writing it to monitoring it in production.

---

## Key concepts

| Concept | What it means |
|---|---|
| **CI** (Continuous Integration) | Automatic code checks on every push |
| **CD** (Continuous Delivery) | Automatic preparation for deployment |
| **CD** (Continuous Deployment) | Automatic deployment to production |
| **Pipeline** | A sequence of steps from code to production |
| **Staging** | A test server that imitates production |
| **Production** | The real server for end users |
| **Rollback** | Reverting to the previous working version |
| **IaC** | Infrastructure as Code — servers described as code |

---

## The path of code from laptop to production

```mermaid
flowchart LR
    Dev["Developer<br>writes code"] --> Push["git push<br>to GitHub"]
    Push --> CI["CI:<br>tests + linter"]
    CI -->|"failed"| Notify["Notification<br>to the developer"]
    CI -->|"passed"| Build["Build:<br>docker build"]
    Build --> Registry["Push image<br>to Registry"]
    Registry --> Staging["Deploy<br>to Staging"]
    Staging --> ManualQA{"Manual QA<br>(or auto E2E)"}
    ManualQA -->|"OK"| Production["Deploy<br>to Production"]
    Production --> Monitor["Monitoring<br>logs, metrics"]
    Monitor -->|"problems found"| Rollback["Rollback<br>to the previous version"]
    Monitor --> Dev

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Dev,Push,CI,Build,Registry,Staging step;
    class ManualQA decision;
    class Production success;
    class Notify,Rollback error;
    class Monitor warning;
```

---

## CI — Continuous Integration

CI runs automatically on every push to the repository and performs:

1. `ruff check .` — linter
2. `pytest` — tests
3. Possibly: `safety check` — vulnerability check

If something fails, the pull request cannot be merged. Code with broken tests will not get into main.

### GitHub Actions — an example CI for Django

```yaml
# .github/workflows/ci.yml
name: Django CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      db:
        image: postgres:16
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run linter
        run: ruff check .

      - name: Run tests
        env:
          DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_db
          DEBUG: "True"
          SECRET_KEY: "ci-test-secret-key"
        run: pytest --tb=short
```

---

## CD — Continuous Deployment

After a successful CI run — automatic deployment:

```yaml
# .github/workflows/deploy.yml (part)
  deploy:
    needs: test            # only if the tests passed
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /var/www/myapp
            git pull origin main
            source .venv/bin/activate
            pip install -r requirements.txt
            python manage.py migrate --noinput
            python manage.py collectstatic --noinput
            sudo systemctl restart myapp
```

---

## Staging and Production

> Staging is a mirror of production. You deploy there first, check that everything works, and only then deploy to production.

```text
[Developer] → [Git] → [CI] → [Staging] → [Manual/Auto QA] → [Production]
```

On staging:
- A real database (a copy or test data)
- Real Docker, Nginx, Gunicorn
- But access is restricted (not public)

Advantages:
- Bugs are found before users see them
- You can test migrations
- The QA team can check new features

---

## Rollback

If something breaks after a deployment, you need to go back quickly.

### Option 1: Git rollback

```bash
git log --oneline -5           # find the previous commit
git checkout HEAD~1            # or a specific SHA
sudo systemctl restart myapp
```

### Option 2: Docker image tags

```bash
# The previous image is still in the registry
docker pull myapp:v1.2.3
docker compose up -d           # with the previous version
```

### Option 3: Via CI/CD

Most CI/CD systems have a "Redeploy previous build" button.

---

## Infrastructure as Code (IaC)

> If you describe the server configuration in code, you can version it, reproduce it, review changes, and deploy it again after a disaster.

Instead of manually configuring Nginx, PostgreSQL, and the firewall, this is described in files (Terraform, Ansible, Pulumi) and run automatically.

For a beginner: `docker-compose.yml` and Bash scripts are enough. Terraform and Ansible are the next level.

---

## Common beginner mistakes

**Mistake 1:** Deploying manually without a script
> One day you will forget `collectstatic` or `migrate` and the site will break.

**Mistake 2:** Deploying without tests
> Without CI, tests do not run automatically and bugs get into production.

**Mistake 3:** No staging
> You see the behavior for the first time in production. There is no way to reproduce the problem.

---

## Practical exercise

### Task 1
Draw the pipeline for your Django project: from `git push` to the live site. What are the steps? What is automatic and what is manual?

### Task 2
Add `.github/workflows/ci.yml` to your project with the steps: install, ruff, pytest. Check that it runs on push.

### Task 3
Write `deploy.sh` — a script for deploying to the server that runs git pull, migrate, collectstatic, restart.

---

## Self-check

- [ ] I can explain what CI/CD is
- [ ] I understand why Staging is needed
- [ ] I know what a rollback is and how to do one
- [ ] I can write a basic GitHub Actions workflow for Django
- [ ] I understand the path of code from push to production

---

## Short summary

DevOps is a set of practices for delivering code quickly and safely. CI checks the tests on every push. CD automates deployment. Staging is a safe place for testing before production. Rollback is the retreat plan. The next step is the Kubernetes overview.
