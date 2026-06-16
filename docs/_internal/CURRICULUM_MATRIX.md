# Curriculum Matrix

Phase 2 — Architecture Planning
Створено: 2026-06-14

Матриця трьох шарів книги для 34+ тем.
Кожна тема має теоретичний контекст, практичний крок і фактичний приклад із Notes Chat App.

---

| Topic | Knowledge Chapter (Part) | Zero to Hero Step | Project Deep Dive Chapter | Lab | Level | Prerequisites |
|-------|--------------------------|-------------------|--------------------------|-----|-------|---------------|
| HTTP request/response | Частина I — network_foundation_full.md, http_https.md | Крок 1 (hello_project) | Ch.1, Ch.6 | — | Foundation | Python basics |
| DNS, TCP, TLS | Частина I — network_foundation_full.md | Крок 0 | Ch.1 | — | Foundation | — |
| Django request lifecycle | Частина II — django_architecture_full.md, request_lifecycle.md | Крок 1 | Ch.4 | — | Beginner | HTTP |
| URL routing | Частина II — url_routing_full.md | Крок 1 | Ch.6 | — | Beginner | Django request lifecycle |
| Views (FBV) | Частина II — views_full.md | Крок 1, 3, 5 | Ch.13 | — | Beginner | URL routing |
| Views (CBV) | Частина II — views_full.md | Крок 4 (crispy_notes) | Ch.13 (порівняння) | — | Intermediate | FBV |
| Middleware | Частина II — django_architecture_full.md | Крок 8 | Ch.4, Ch.32 | — | Intermediate | Django lifecycle |
| Django settings | Частина II — project_structure_full.md | Кроки 1, 8 | Ch.4, Ch.5 | — | Beginner | — |
| Management commands | Частина II — management_commands_full.md | Кроки 2, 3 | Ch.3 | — | Beginner | Django lifecycle |
| WSGI vs ASGI | Частина II — wsgi_vs_asgi.md | Крок 7 | Ch.23 | — | Intermediate | Django lifecycle |
| Relational DB fundamentals | Частина III — relational_db_foundations_full.md | Крок 2 | Ch.7 | — | Foundation | — |
| Django Models | Частина III — django_orm_full.md | Крок 2 | Ch.7, Ch.8 | ORM Lab | Beginner | Relational DB |
| Migrations | Частина III — django_migrations_full.md | Крок 2 | Ch.9 | ORM Lab | Beginner | Models |
| QuerySet laziness | Частина III — django_orm_deep_full.md | Крок 3 | Ch.11 (selectors) | ORM Lab | Intermediate | ORM |
| Q objects | Частина III — django_orm_deep_full.md | Крок 5 | Ch.11, Ch.17 | ORM Lab | Intermediate | ORM |
| select_related / prefetch_related | Частина III — django_orm_deep_full.md | Крок 3 | Ch.11 | ORM Lab | Intermediate | ORM, FK |
| Transactions | Частина III — transactions_concurrency_full.md | Крок 3 | Ch.27 | — | Advanced | ORM, PostgreSQL |
| Indexes | Частина III — indexing_deep_full.md | Крок 3 | Ch.27 | — | Advanced | PostgreSQL |
| PostgreSQL | Частина III — postgresql_advanced_full.md | Крок 3 | Ch.27 | — | Intermediate | Relational DB |
| Django Forms | Частина IV — django_forms_full.md | Крок 4 | Ch.10 | Forms Lab | Beginner | Models |
| ModelForm | Частина IV — django_forms_full.md | Крок 4, 5 | Ch.10 | Forms Lab | Beginner | Forms |
| Form validation | Частина IV — django_forms_full.md | Крок 4 | Ch.10 | Forms Lab | Intermediate | ModelForm |
| Crispy Forms | Частина IV — crispy_forms_full.md | Крок 4 | Ch.14 (templates) | Forms Lab | Intermediate | Forms |
| Django Templates | Частина V — django_templates_full.md | Крок 1, 4 | Ch.14 | — | Beginner | Views |
| Template inheritance | Частина V — advanced_templates_full.md | Крок 4 | Ch.14 | — | Intermediate | Templates |
| Bootstrap 5 | Частина V — bootstrap_5_full.md | Крок 4 | Ch.14 | — | Beginner | HTML/CSS |
| Static files | Частина V — templates_bootstrap_static.md | Кроки 4, 7 | Ch.15 | — | Beginner | Django settings |
| Services pattern | Частина VI — services_selectors_full.md | Крок 3 | Ch.12 | — | Intermediate | Models, Forms |
| Selectors pattern | Частина VI — services_selectors_full.md | Крок 3 | Ch.11 | — | Intermediate | ORM, Q objects |
| Authentication (AuthN) | Частина VII — auth_basics_full.md | Крок 5 | Ch.16 | — | Intermediate | Django Core |
| Sessions | Частина VII — sessions_flow_full.md | Крок 5 | Ch.16 | — | Intermediate | Authentication |
| Authorization | Частина VII — permissions_full.md | Крок 5 | Ch.17 | — | Intermediate | Authentication |
| IDOR prevention | Частина VII — security_misconceptions_full.md | Крок 5 | Ch.17 | — | Intermediate | Auth, QuerySet |
| Object-level permissions | Частина VII — permissions_full.md | Крок 5 | Ch.17 | — | Intermediate | Authorization |
| Group sharing | Частина VII — permissions_full.md | Крок 5 | Ch.18 | — | Intermediate | Groups, Q objects |
| OWASP Top 10 | Частина VII — owasp_top_10_full.md | Крок 5, 8 | Ch.32 | — | Advanced | Security |
| CSRF | Частина VII — django_security_architecture_full.md | Крок 4 | Ch.10, Ch.32 | — | Intermediate | Forms |
| Testing foundations | Частина VIII — testing_foundations_full.md | Крок 6 | Ch.29 | Testing Lab | Beginner | Django Core |
| Django TestCase | Частина VIII — django_testing_full.md | Крок 6 | Ch.29 | Testing Lab | Beginner | Testing foundations |
| TransactionTestCase | Частина VIII — django_testing_full.md | Крок 6, 7 | Ch.29, Ch.25 | Testing Lab | Advanced | TestCase, Async |
| Mocking | Частина VIII — mocking_and_patching_full.md | Крок 6 | Ch.29 | Testing Lab | Intermediate | TestCase |
| Selenium E2E | Частина VIII — selenium_full.md | Крок 6 | Ch.29 | Testing Lab | Advanced | Testing pyramid |
| CI/CD | Частина VIII — ci_cd_full.md | Крок 8 | Ch.31 | — | Intermediate | Tests |
| asyncio | Частина IX — async_02_asyncio_full.md | Крок 7 | Ch.23 | Async Lab | Intermediate | Python basics |
| ASGI / ProtocolTypeRouter | Частина IX — async_03_asgi_full.md | Крок 7 | Ch.23 | Async Lab | Advanced | asyncio, WSGI |
| Django Channels | Частина IX — channels_websocket.md | Крок 7 | Ch.24, Ch.25 | Async Lab | Advanced | ASGI |
| WebSocket | Частина IX — channels_websocket.md | Крок 7 | Ch.26 | Async Lab | Advanced | HTTP, Channels |
| database_sync_to_async | Частина IX — async_06_sync_to_async_full.md | Крок 7 | Ch.25 | Async Lab | Advanced | asyncio, ORM |
| Redis (channel layer) | Частина IX — channels_websocket.md | Крок 7 | Ch.28 | Async Lab | Advanced | Channels |
| Linux basics | Частина X — linux_01–10 | Крок 0 | Ch.3 | — | Foundation | — |
| Environment variables | Частина X — linux_08 | Кроки 5, 8 | Ch.5 | — | Intermediate | Linux basics |
| Docker | Частина X — deploy_14_docker_basics_full.md | Крок 8 | Ch.30 | — | Intermediate | Linux |
| Docker Compose | Частина X — deploy_15_docker_compose_full.md | Крок 8 | Ch.30 | — | Intermediate | Docker |
| Nginx / reverse proxy | Частина X — deploy_12_nginx_gunicorn_uvicorn_full.md | Крок 8 | Ch.30, Ch.34 | — | Advanced | Docker |
| Deployment checklist | Частина X — deployment_checklist.md | Крок 8 | Ch.33, Ch.34 | — | Production | Docker, Nginx |

---

## Нотатки

### Критичні педагогічні попередники

```text
IDOR prevention → requires: AuthN + Q objects (both before)
TransactionTestCase → requires: TestCase + asyncio basics (both before)
database_sync_to_async → requires: asyncio + Django ORM (both before)
Redis channel layer → requires: Docker + Channels (both before)
```

### Теми, що вперше вводяться у Zero to Hero (не у Knowledge Book)

```text
TransactionTestCase for consumers — вперше практично у Кроці 6
database_sync_to_async pattern — вперше у Кроці 7
socket_timeout=None у RedisChannelLayer — вперше у Кроці 7
Notes Chat App specific domain (ShopItem fields etc.) — у Кроці 5
```

### Теми тільки у Project Deep Dive (немає відповідного ZH кроку)

```text
DebugExceptionMiddleware security issue (Ch.32)
ORM Architecture Board (Ch.7 + Ch.8 detailed)
Migration history (Ch.9)
ngrok service у Docker Compose (Ch.30)
```
