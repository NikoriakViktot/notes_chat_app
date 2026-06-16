# Крок 6. Тестування Django від A до Z

> Цей крок охоплює два проєкти: **crispy_notes_project** (автономний, SQLite, без Docker)
> та **notes_chat_app** (Docker + PostgreSQL + Redis + WebSocket).
>
> Ти побачиш як кожен рівень тестів захищає різний шар системи.
>
> **Результат:** 129+ тестів — 123 pass + 6 Selenium (skipped без geckodriver/Remote Chrome)

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 1. Hello Django](../01_hello_django/index.md) — перший `HttpResponse`, URL routing
    - [Крок 2. Bootstrap Notes](../02_first_model/index.md) — ModelForm, PRG, Bootstrap CRUD
    - [Крок 3. CRUD і архітектура](../03_crud_and_architecture/index.md) — Services & Selectors, PostgreSQL
    - [Крок 4. Templates і Forms](../04_templates_and_forms/index.md) — Crispy Forms, Dashboard, Context Processor
    - [Крок 5. Auth і Безпека](../05_auth_and_security/index.md) — Login/Logout, IDOR, Group Sharing

---

## Навчальний проєкт vs Notes Chat App

| | crispy_notes_project (Кроки 1–6) | notes_chat_app (Кроки 7–11) |
|-|----------------------------------|------------------------------|
| Запуск тестів | `python manage.py test hello_app.tests` | `docker compose run --rm web python manage.py test notes_app.tests` |
| База даних | SQLite | PostgreSQL (Docker) |
| Що тестується | models, services, forms, views, selenium | Те саме + **consumers** (WebSocket) |
| Selenium | `geckodriver` / локальний Firefox | Remote Chrome у Docker (`selenium:4444`) |
| CI/CD | GitHub Actions → ubuntu-latest → Chrome headless | GitHub Actions → PostgreSQL + Redis + selenium services |
| Кількість тестів | 129 (123 pass + 6 selenium skip) | 129+ (+ consumer тести) |
| Унікально | Standalone, без Docker | `GroupChatConsumer`, `WebsocketCommunicator`, `TransactionTestCase` |

---

## Що ти вивчиш

- **Навіщо тести** — аналогія пожежна сигналізація, реальний сценарій з `selectors.py`
- **Піраміда тестування** — unit / integration / E2E: різна вартість, різна швидкість
- **Django TestCase** — тестова БД, ROLLBACK після кожного тесту, `setUp`, `BaseServiceTest`
- **AAA паттерн** — Arrange / Act / Assert: структура кожного тесту
- **test_models.py** — constraints, validators через `full_clean()`, SET_NULL тест
- **test_services.py** — persistence test, security (Mass Assignment), транзакційний інваріант
- **test_forms.py** — bound/unbound форми, queryset security, `cleaned_data`
- **test_views.py** — Django Test Client, `force_login`, ownership 404, IDOR prevention
- **test_consumers.py** — `WebsocketCommunicator`, `TransactionTestCase`, `database_sync_to_async` (notes_chat_app)
- **test_selenium.py** — `StaticLiveServerTestCase`, Remote Chrome у Docker, session cookie trick
- **GitHub Actions CI** — workflow рядок за рядком, `needs:`, `services:`, artifacts

---

## Порядок читання

1. **[Навіщо тести](why_tests.md)** — сигналізація, піраміда, TestCase, setUp, тестова БД, AAA, читання виводу
2. **[test_models.py](test_models.md)** — що живе в моделі, структура tests/, validators, SET_NULL
3. **[test_services.py](test_services.md)** — бізнес-логіка, persistence, security, транзакції
4. **[test_forms.py](test_forms.md)** — bound/unbound, queryset security, cleaned_data
5. **[test_views.py](test_views.md)** — Test Client, force_login, три паттерни, схема доступу
6. **[test_consumers.py](test_consumers.md)** — WebSocket тести (notes_chat_app, унікально)
7. **[test_selenium.py](test_selenium.md)** — браузерні тести, Docker, session cookie trick
8. **[GitHub Actions CI](ci_github_actions.md)** — workflow, jobs, кроки, результати
9. **[Checkpoint](checkpoint.md)** — очікуваний результат, чеклист, практичне завдання
