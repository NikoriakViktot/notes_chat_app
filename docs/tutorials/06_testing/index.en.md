# Step 6. Django Testing from A to Z

> This step covers two projects: **crispy_notes_project** (standalone, SQLite, no Docker)
> and **notes_chat_app** (Docker + PostgreSQL + Redis + WebSocket).
>
> You will see how each level of tests protects a different layer of the system.
>
> **Result:** 129+ tests — 123 pass + 6 Selenium (skipped without geckodriver/Remote Chrome)

!!! warning "Prerequisites"
    Before you start, make sure you have completed:

    - [Step 1. Hello Django](../01_hello_django/index.md) — the first `HttpResponse`, URL routing
    - [Step 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Step 3. CRUD and architecture](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL
    - [Step 4. Templates and Forms](../04_templates_and_forms/index.md) — Crispy Forms, Dashboard, Context Processor
    - [Step 5. Auth and Security](../05_auth_and_security/index.md) — Login/Logout, IDOR, Group Sharing

---

## Learning project vs Notes Chat App

| | crispy_notes_project (Steps 1–6) | notes_chat_app (Steps 7–11) |
|-|----------------------------------|------------------------------|
| Running tests | `python manage.py test hello_app.tests` | `docker compose run --rm web python manage.py test notes_app.tests` |
| Database | SQLite | PostgreSQL (Docker) |
| What is tested | models, services, forms, views, selenium | The same + **consumers** (WebSocket) |
| Selenium | `geckodriver` / local Firefox | Remote Chrome in Docker (`selenium:4444`) |
| CI/CD | GitHub Actions → ubuntu-latest → Chrome headless | GitHub Actions → PostgreSQL + Redis + selenium services |
| Number of tests | 129 (123 pass + 6 selenium skip) | 129+ (+ consumer tests) |
| Unique | Standalone, no Docker | `GroupChatConsumer`, `WebsocketCommunicator`, `TransactionTestCase` |

---

## What you will learn

- **Why tests** — the fire alarm analogy, a real scenario with `selectors.py`
- **The testing pyramid** — unit / integration / E2E: different cost, different speed
- **Django TestCase** — the test database, ROLLBACK after each test, `setUp`, `BaseServiceTest`
- **The AAA pattern** — Arrange / Act / Assert: the structure of every test
- **test_models.py** — constraints, validators via `full_clean()`, the SET_NULL test
- **test_services.py** — persistence test, security (Mass Assignment), a transactional invariant
- **test_forms.py** — bound/unbound forms, queryset security, `cleaned_data`
- **test_views.py** — Django Test Client, `force_login`, ownership 404, IDOR prevention
- **test_consumers.py** — `WebsocketCommunicator`, `TransactionTestCase`, `database_sync_to_async` (notes_chat_app)
- **test_selenium.py** — `StaticLiveServerTestCase`, Remote Chrome in Docker, the session cookie trick
- **GitHub Actions CI** — the workflow line by line, `needs:`, `services:`, artifacts

---

## Reading order

1. **[Why tests](why_tests.md)** — the alarm, the pyramid, TestCase, setUp, the test database, AAA, reading the output
2. **[test_models.py](test_models.md)** — what lives in the model, the tests/ structure, validators, SET_NULL
3. **[test_services.py](test_services.md)** — business logic, persistence, security, transactions
4. **[test_forms.py](test_forms.md)** — bound/unbound, queryset security, cleaned_data
5. **[test_views.py](test_views.md)** — Test Client, force_login, three patterns, the access diagram
6. **[test_consumers.py](test_consumers.md)** — WebSocket tests (notes_chat_app, unique)
7. **[test_selenium.py](test_selenium.md)** — browser tests, Docker, the session cookie trick
8. **[GitHub Actions CI](ci_github_actions.md)** — workflow, jobs, steps, results
9. **[Checkpoint](checkpoint.md)** — expected result, checklist, practical exercise
