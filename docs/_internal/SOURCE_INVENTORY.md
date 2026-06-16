# Source Inventory

Повний перелік усіх документів репозиторію (179 файлів).
Інспекція: 2026-06-14. Оновлено: 2026-06-14. Гілка: main.

Типи матеріалу:
- **KB** — Knowledge Book chapter (теорія)
- **ZH** — Zero to Hero tutorial (покроковий туторіал, проєкт)
- **RM** — README модуль (детальні README_N)
- **PD** — Project Deep Dive (12_final_project)
- **LAB** — Лабораторна робота
- **REF** — Довідник / Cheatsheet
- **LEG** — Legacy (застарілий матеріал)
- **INT** — Внутрішній (навігація, index, README)

Статус інспекції:
- ✅ **fully inspected** — повністю прочитано, зміст перевірено
- ⚠️ **partially inspected** — заголовки + ключові секції прочитано
- 🔍 **structure only** — лише структура та кількість рядків відома
- ❌ **not inspected** — не перевірявся

---

## 00 — Getting Started

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 255 | `00_getting_started/README.md` | KB | Огляд курсу, три шари книги, схема notes_chat_app, мінімальний старт | Частково з index.md | keep | ✅ fully inspected |
| 48 | `00_getting_started/how_to_use_course.md` | KB | Як читати курс | — | keep | 🔍 structure only |
| 65 | `00_getting_started/local_setup.md` | KB | Docker, команди запуску, ASGI uvicorn | Частково з tutorials/08 | keep | ✅ fully inspected |
| 48 | `00_getting_started/prerequisites.md` | KB | Необхідні знання | — | keep | 🔍 structure only |
| 51 | `00_getting_started/repository_structure.md` | KB | Структура репо | — | keep | 🔍 structure only |

---

## 01 — Web Foundations

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `01_web_foundations/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 46 | `01_web_foundations/browser_server_lifecycle.md` | KB | HTTP lifecycle | Частково з network_foundation_full | keep | 🔍 structure only |
| 47 | `01_web_foundations/http_https.md` | KB | HTTP/HTTPS | Частково з network_foundation_full | keep | 🔍 structure only |
| 410 | `01_web_foundations/network_foundation_full.md` | KB | Мережевий фундамент, TCP/IP, DNS, TLS | — | keep | 🔍 structure only |
| 323 | `01_web_foundations/network_mermaid_full.md` | KB | Mermaid-схеми мережі | Візуалізація network_foundation_full | keep | 🔍 structure only |

---

## 02 — Django Core

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 49 | `02_django_core/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 842 | `02_django_core/django_architecture_full.md` | KB | Архітектура Django, MTV, middleware; посилання на інші KB | — | keep | ⚠️ partially inspected |
| 4 | `02_django_core/django_command_system.md` | INT | Перенаправлення (redirect) до management_commands_full | — | merge або видалити | 🔍 structure only |
| 582 | `02_django_core/django_mermaid_full.md` | KB | Mermaid-схеми Django | Візуалізація architecture | keep | 🔍 structure only |
| 409 | `02_django_core/management_commands_full.md` | KB | Management commands | — | keep | 🔍 structure only |
| 534 | `02_django_core/project_structure_full.md` | KB | Структура проєкту | Частково з 00/repository_structure | keep | 🔍 structure only |
| 48 | `02_django_core/request_lifecycle.md` | KB | Request lifecycle | Частково з django_architecture_full | merge/keep | 🔍 structure only |
| 434 | `02_django_core/url_routing_full.md` | KB | URL routing | Частково з views_full | keep | 🔍 structure only |
| 45 | `02_django_core/urls_and_views.md` | KB | URLs + Views (short) | Дублює url_routing_full + views_full | needs verification | 🔍 structure only |
| 1075 | `02_django_core/views_full.md` | KB | FBV, CBV, decorators, selectors/services паттерн, Mermaid | — | keep | ⚠️ partially inspected |
| 192 | `02_django_core/wsgi_vs_asgi.md` | KB | WSGI vs ASGI | Частково з 09/async_03_asgi_full | keep | 🔍 structure only |

---

## 03 — Database and ORM

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 50 | `03_database_and_orm/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 70 | `03_database_and_orm/django_migrations_full.md` | KB | Міграції, makemigrations vs migrate, граф залежностей, Mermaid | Дублює migrations.md (але значно глибший) | keep canonical | ✅ fully inspected |
| 56 | `03_database_and_orm/django_models.md` | KB | Моделі (short) | Частково з django_orm_full | needs verification | 🔍 structure only |
| 860 | `03_database_and_orm/django_orm_deep_full.md` | KB | ORM механіка, Q, F, annotate | — | keep | 🔍 structure only |
| 510 | `03_database_and_orm/django_orm_full.md` | KB | ORM основи, QuerySet API | Частково з django_orm_deep_full | keep | 🔍 structure only |
| 475 | `03_database_and_orm/indexing_deep_full.md` | KB | Індекси PostgreSQL | — | keep | 🔍 structure only |
| 53 | `03_database_and_orm/migrations.md` | KB | Міграції (short) — фактичні міграції notes_chat_app, команди | Менш глибокий ніж django_migrations_full | summary/keep | ✅ fully inspected |
| 673 | `03_database_and_orm/orm_mermaid_full.md` | KB | Mermaid ORM схеми | — | keep | 🔍 structure only |
| 678 | `03_database_and_orm/postgresql_advanced_full.md` | KB | PostgreSQL, Docker, production | — | keep | 🔍 structure only |
| 46 | `03_database_and_orm/query_optimization.md` | KB | Query optimization (short) | Частково з django_orm_deep_full | needs verification | 🔍 structure only |
| 1090 | `03_database_and_orm/relational_db_foundations_full.md` | KB | Реляційні БД, SQL | — | keep | 🔍 structure only |
| 604 | `03_database_and_orm/transactions_concurrency_full.md` | KB | Транзакції, блокування | — | keep | 🔍 structure only |
| 47 | `03_database_and_orm/transactions_indexes_postgresql.md` | KB | Транзакції+Індекси+PG (short) | Дублює три більші файли | needs verification | 🔍 structure only |

---

## 04 — Forms and Validation

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 46 | `04_forms_and_validation/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 698 | `04_forms_and_validation/crispy_forms_full.md` | KB | Crispy Forms, FormHelper, Layout | — | keep | 🔍 structure only |
| 50 | `04_forms_and_validation/django_forms_and_crispy.md` | KB | Forms + Crispy (short) | Дублює crispy_forms_full | needs verification | 🔍 structure only |
| 1307 | `04_forms_and_validation/django_forms_full.md` | KB | Django Forms, ModelForm, validation | — | keep | 🔍 structure only |

---

## 05 — Frontend and Templates

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `05_frontend_and_templates/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 1811 | `05_frontend_and_templates/advanced_templates_full.md` | KB | Context Processors, Custom Template Tags, crispy-forms, Vite, SaaS Dashboard, HTMX, Jinja2 | Унікальний поглиблений контент | keep canonical | ⚠️ partially inspected |
| 1760 | `05_frontend_and_templates/bootstrap_5_full.md` | KB | Bootstrap 5 | — | keep | 🔍 structure only |
| 1340 | `05_frontend_and_templates/css_basics_full.md` | KB | CSS | — | keep | 🔍 structure only |
| 857 | `05_frontend_and_templates/design_foundations_full.md` | KB | Дизайн-основи | — | keep | 🔍 structure only |
| 832 | `05_frontend_and_templates/design_readme_full.md` | KB | Design README | Частково з design_foundations_full | needs verification | 🔍 structure only |
| 127 | `05_frontend_and_templates/django_admin_full.md` | KB | Django Admin | — | keep | 🔍 structure only |
| 2360 | `05_frontend_and_templates/django_admin_unfold_full.md` | KB | Django Admin + Unfold | — | keep | 🔍 structure only |
| 1449 | `05_frontend_and_templates/django_templates_bootstrap_full.md` | KB | Templates + Bootstrap | Частково з advanced_templates + django_templates_full | needs verification | 🔍 structure only |
| 205 | `05_frontend_and_templates/django_templates_full.md` | KB | Шаблони Django: механізм, execution flow, context system, безпека — технічна глибина; Mermaid | Менш глибокий ніж advanced_templates_full | summary/keep | ✅ fully inspected |
| 1411 | `05_frontend_and_templates/html_basics_full.md` | KB | HTML | — | keep | 🔍 structure only |
| 54 | `05_frontend_and_templates/templates_bootstrap_static.md` | KB | Templates+Bootstrap+Static (short) | Дублює два більші файли | needs verification | 🔍 structure only |

---

## 06 — Application Architecture

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `06_application_architecture/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 1292 | `06_application_architecture/django_ninja_templates_full.md` | KB | Django Ninja + rendering | — | keep | 🔍 structure only |
| 435 | `06_application_architecture/django_selectors_full.md` | KB | Selectors pattern, CQRS-light | Частково з services_selectors_full | keep | 🔍 structure only |
| 542 | `06_application_architecture/django_serializers_full.md` | KB | Serializers | — | keep | 🔍 structure only |
| 538 | `06_application_architecture/django_services_full.md` | KB | Services pattern | Частково з services_selectors_full | keep | 🔍 structure only |
| 617 | `06_application_architecture/django_services_selectors.md` | KB | Services+Selectors об'єднаний — з позначкою "збережено як історичний" | Дублює services_selectors_full | archive/merge | ✅ fully inspected |
| 630 | `06_application_architecture/django_tasks_full.md` | KB | Celery tasks | — | keep | 🔍 structure only |
| 48 | `06_application_architecture/services_selectors.md` | KB | Services+Selectors (short) | Дублює services_selectors_full | needs verification | 🔍 structure only |
| 614 | `06_application_architecture/services_selectors_full.md` | KB | Services, Selectors, Serializers; повна архітектурна карта; антипатерни; data flow | Частково дублює три окремі файли | keep canonical | ⚠️ partially inspected |

---

## 07 — Auth and Security

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `07_auth_and_security/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 155 | `07_auth_and_security/auth_basics_full.md` | KB | AuthN vs AuthZ | — | keep | 🔍 structure only |
| 56 | `07_auth_and_security/auth_sessions_permissions.md` | KB | Auth+Sessions+Permissions (short) | Дублює три більші файли | needs verification | 🔍 structure only |
| 282 | `07_auth_and_security/django_security_architecture_full.md` | KB | Архітектура безпеки Django | — | keep | 🔍 structure only |
| 317 | `07_auth_and_security/owasp_top_10_full.md` | KB | OWASP Top 10 | — | keep | 🔍 structure only |
| 218 | `07_auth_and_security/permissions_full.md` | KB | Permissions та Groups | — | keep | 🔍 structure only |
| 1068 | `07_auth_and_security/security_foundations_full.md` | KB | Основи безпеки | — | keep | 🔍 structure only |
| 175 | `07_auth_and_security/security_misconceptions_full.md` | KB | Типові помилки безпеки | — | keep | 🔍 structure only |
| 192 | `07_auth_and_security/sessions_flow_full.md` | KB | Сесії, login/logout | — | keep | 🔍 structure only |
| 281 | `07_auth_and_security/siem_full.md` | KB | SIEM | — | keep | 🔍 structure only |
| 319 | `07_auth_and_security/zero_trust_full.md` | KB | Zero Trust | — | keep | 🔍 structure only |

---

## 08 — Testing and Quality

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `08_testing_and_quality/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 42 | `08_testing_and_quality/ci.md` | KB | CI short — workflow, legacy async routes | Менш глибокий ніж ci_cd_full | summary/keep | ✅ fully inspected |
| 714 | `08_testing_and_quality/ci_cd_full.md` | KB | CI/CD, GitHub Actions, YAML, Django-tests.yml рядок за рядком, pytest integration | — | keep canonical | ⚠️ partially inspected |
| 1108 | `08_testing_and_quality/django_testing_full.md` | KB | Django Testing довідник | Частково з testing_practice_project_full | keep | 🔍 structure only |
| 348 | `08_testing_and_quality/mocking_and_patching_full.md` | KB | Mock, patch | — | keep | 🔍 structure only |
| 402 | `08_testing_and_quality/pytest_basics_full.md` | KB | pytest | — | keep | 🔍 structure only |
| 1225 | `08_testing_and_quality/selenium_full.md` | KB | Selenium, E2E | — | keep | 🔍 structure only |
| 303 | `08_testing_and_quality/test_data_and_fixtures_full.md` | KB | Test data, fixtures | — | keep | 🔍 structure only |
| 54 | `08_testing_and_quality/testing_strategy.md` | KB | Testing strategy (short) | — | needs verification | 🔍 structure only |
| 340 | `08_testing_and_quality/unittest_basics_full.md` | KB | unittest | — | keep | 🔍 structure only |
| 1258 | `08_testing_and_quality/testing_foundations_full.md` | KB | Основи тестування | — | keep | 🔍 structure only |
| 1271 | `08_testing_and_quality/testing_practice_project_full.md` | KB | Практика: notes_chat_app тести | Практичне доповнення до tutorials/06 | keep | 🔍 structure only |

---

## 09 — Async and Realtime

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `09_async_and_realtime/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 262 | `09_async_and_realtime/async_01_sync_vs_async_full.md` | KB | Sync vs Async | — | keep | 🔍 structure only |
| 317 | `09_async_and_realtime/async_02_asyncio_full.md` | KB | asyncio | — | keep | 🔍 structure only |
| 275 | `09_async_and_realtime/async_03_asgi_full.md` | KB | ASGI | Частково з 02/wsgi_vs_asgi | keep | 🔍 structure only |
| 299 | `09_async_and_realtime/async_04_django_async_views_full.md` | KB | Async views | — | keep | 🔍 structure only |
| 307 | `09_async_and_realtime/async_05_async_orm_full.md` | KB | Async ORM | — | keep | 🔍 structure only |
| 282 | `09_async_and_realtime/async_06_sync_to_async_full.md` | KB | sync_to_async | — | keep | 🔍 structure only |
| 322 | `09_async_and_realtime/async_07_async_http_clients_full.md` | KB | Async HTTP clients | — | keep | 🔍 structure only |
| 300 | `09_async_and_realtime/async_08_benchmarking_full.md` | KB | Benchmarking | — | keep | 🔍 structure only |
| 372 | `09_async_and_realtime/async_09_async_use_cases_full.md` | KB | Async use cases | — | keep | 🔍 structure only |
| 54 | `09_async_and_realtime/channels_websocket.md` | KB | Channels+WebSocket short — Mermaid flow, channel layer, project посилання | Різний фокус від tutorials/07 | different pedagogical purpose | ✅ fully inspected |

---

## 10 — Linux and DevOps

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 47 | `10_linux_and_devops/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| 46 | `10_linux_and_devops/docker_and_runtime.md` | KB | Docker short — Dockerfile, compose, entrypoint; примітка про legacy `notes` dir | Різний фокус від deploy_14 (загальна теорія vs notes_chat_app specific) | different pedagogical purpose | ✅ fully inspected |
| 203 | `10_linux_and_devops/linux_01_mental_model_full.md` | KB | Linux ментальна модель | — | keep | 🔍 structure only |
| ~240 | `10_linux_and_devops/linux_02_terminal_and_shell_full.md` | KB | Terminal та shell | — | keep | 🔍 structure only |
| ~260 | `10_linux_and_devops/linux_03_filesystem_navigation_full.md` | KB | Файлова система | — | keep | 🔍 structure only |
| ~250 | `10_linux_and_devops/linux_04_files_permissions_users_full.md` | KB | Файли, permissions, users | — | keep | 🔍 structure only |
| ~260 | `10_linux_and_devops/linux_05_processes_ports_services_full.md` | KB | Процеси, порти, сервіси | — | keep | 🔍 structure only |
| ~250 | `10_linux_and_devops/linux_06_*.md` – `linux_10_*.md` (5 файлів) | KB | Linux 06-10 | — | keep | 🔍 structure only |

---

## 11 — Deployment

| Рядки | Файл | Тип | Головні теми | Дублювання | Дія | Inspection |
|-------|------|-----|--------------|------------|-----|-----------|
| 46 | `11_deployment/README.md` | INT | Огляд розділу | — | keep | 🔍 structure only |
| ~283 | `11_deployment/deploy_11_django_on_linux_full.md` | KB | Django на Linux | — | keep | 🔍 structure only |
| ~264 | `11_deployment/deploy_12_nginx_gunicorn_uvicorn_full.md` | KB | nginx, gunicorn, uvicorn | — | keep | 🔍 structure only |
| ~270 | `11_deployment/deploy_13_logs_monitoring_debugging_full.md` | KB | Логи, моніторинг | — | keep | 🔍 structure only |
| ~250 | `11_deployment/deploy_14_docker_basics_full.md` | KB | Docker basics, image vs container, Mermaid | Загальна теорія Docker (не notes_chat_app specific) | keep canonical | ⚠️ partially inspected |
| ~270 | `11_deployment/deploy_15_docker_compose_full.md` | KB | Docker Compose | — | keep | 🔍 structure only |
| ~260 | `11_deployment/deploy_16_devops_workflow_full.md` | KB | DevOps workflow | — | keep | 🔍 structure only |
| ~250 | `11_deployment/deploy_17_kubernetes_overview_full.md` | KB | Kubernetes | — | keep | 🔍 structure only |
| ~260 | `11_deployment/deploy_18_roadmap_next_steps_full.md` | KB | Roadmap | — | keep | 🔍 structure only |
| 54 | `11_deployment/deployment_checklist.md` | REF | Deployment checklist | — | keep | 🔍 structure only |

---

## 12 — Final Project (Project Deep Dive)

**Увага:** всі файли цієї секції — переважно стаби (13–31 рядків), містять лише заголовки та посилання. Потребують розширення.

| Рядки | Файл | Тип | Головні теми | Стан | Inspection |
|-------|------|-----|--------------|------|-----------|
| 19 | `12_final_project/README.md` | PD | Огляд фінального проєкту | stub | 🔍 structure only |
| 16 | `12_final_project/architecture.md` | PD | Архітектура | stub | 🔍 structure only |
| 13 | `12_final_project/async_and_chat.md` | PD | Async та Chat | stub | 🔍 structure only |
| 22 | `12_final_project/deployment.md` | PD | Деплоймент | stub | 🔍 structure only |
| 22 | `12_final_project/domain_model.md` | PD | ER-діаграма (Mermaid) | має Mermaid, але мінімум тексту | ⚠️ partially inspected |
| 17 | `12_final_project/feature_map.md` | PD | Feature map | stub | 🔍 structure only |
| 18 | `12_final_project/orm_architecture_board.md` | PD | ORM board | stub | 🔍 structure only |
| 20 | `12_final_project/project_overview.md` | PD | Огляд проєкту | stub | ⚠️ partially inspected |
| 25 | `12_final_project/request_flows.md` | PD | Request flows | stub | 🔍 structure only |
| 21 | `12_final_project/security_model.md` | PD | Security model | stub | 🔍 structure only |
| 21 | `12_final_project/setup.md` | PD | Setup | stub | 🔍 structure only |
| 31 | `12_final_project/student_tasks.md` | PD | Завдання студентів | stub | 🔍 structure only |
| 18 | `12_final_project/testing_strategy.md` | PD | Testing strategy | stub | 🔍 structure only |

---

## Root-level docs

| Рядки | Файл | Тип | Дія | Inspection |
|-------|------|-----|-----|-----------|
| 128 | `ARCHITECTURE.md` | REF | keep | 🔍 structure only |
| 28 | `GLOSSARY.md` | REF | expand | 🔍 structure only |
| 63 | `LEARNING_PATH.md` | KB | keep | 🔍 structure only |
| 95 | `README.md` | INT | keep | 🔍 structure only |
| 76 | `TEACHING_GUIDE.md` | KB | keep | 🔍 structure only |
| 109 | `TROUBLESHOOTING.md` | REF | keep | 🔍 structure only |
| 56 | `index.md` | INT | keep | 🔍 structure only |

---

## Labs

**Увага:** всі lab-файли — стаби (5–8 рядків). Потребують повного написання.

| Рядки | Файл | Тип | Стан | Inspection |
|-------|------|-----|------|-----------|
| 8 | `labs/README.md` | INT | stub | 🔍 structure only |
| 5 | `labs/async_lab.md` | LAB | stub | 🔍 structure only |
| 7 | `labs/forms_lab.md` | LAB | stub | 🔍 structure only |
| 7 | `labs/orm_lab.md` | LAB | stub | 🔍 structure only |
| 5 | `labs/testing_lab.md` | LAB | stub | 🔍 structure only |

---

## Reference

| Рядки | Файл | Тип | Дія | Inspection |
|-------|------|-----|-----|-----------|
| 15 | `reference/README.md` | INT | keep | 🔍 structure only |
| 146 | `reference/commands.md` | REF | keep | 🔍 structure only |
| 138 | `reference/deployment_cheatsheet.md` | REF | keep | 🔍 structure only |
| 126 | `reference/git_cheatsheet.md` | REF | keep | 🔍 structure only |
| 1 | `reference/legacy_indexes/README.md` | LEG | keep (stub) | 🔍 structure only |
| 362 | `reference/legacy_indexes/index_1.md` | LEG | keep/archive | 🔍 structure only |
| 494 | `reference/legacy_indexes/index_2.md` | LEG | keep/archive | 🔍 structure only |
| 186 | `reference/legacy_indexes/index_3.md` | LEG | keep/archive | 🔍 structure only |
| 180 | `reference/legacy_indexes/index_4.md` | LEG | keep/archive | 🔍 structure only |
| 278 | `reference/legacy_indexes/index_5.md` | LEG | keep/archive | 🔍 structure only |
| 87 | `reference/legacy_indexes/index_7.md` | LEG | keep/archive | 🔍 structure only |
| 122 | `reference/legacy_indexes/index_8.md` | LEG | keep/archive | 🔍 structure only |
| 1 | `reference/legacy_source/README.md` | LEG | keep (stub) | 🔍 structure only |
| 8 | `reference/legacy_source/archive_legacy_docs_readme.md` | LEG | keep/archive | 🔍 structure only |
| 326 | `reference/legacy_source/docs_flat_readme.md` | LEG | keep/archive | 🔍 structure only |
| 5 | `reference/legacy_source/forms_views_laboratory_reference.md` | LEG | stub/archive | 🔍 structure only |
| 5 | `reference/legacy_source/legacy_missing_reference.md` | LEG | stub/archive | 🔍 structure only |
| 7 | `reference/legacy_source/orm_laboratory_reference.md` | LEG | stub/archive | 🔍 structure only |
| 725 | `reference/orm_cheatsheet.md` | REF | keep | 🔍 structure only |
| 217 | `reference/settings_reference.md` | REF | needs accuracy check | 🔍 structure only |
| 205 | `reference/testing_cheatsheet.md` | REF | keep | 🔍 structure only |

---

## Tutorials — покрокові туторіали (01–08)

| Рядки | Файл | Тип | Проєкт | Дія | Inspection |
|-------|------|-----|--------|-----|-----------|
| 19 | `tutorials/README.md` | INT | — | keep | ✅ fully inspected |
| 1087 | `tutorials/01_first_django_page.md` | ZH | hello_project (standalone, SQLite) | keep — навмисно ≠ notes_chat_app | ⚠️ partially inspected |
| 1348 | `tutorials/02_first_model.md` | ZH | bootstrap_notes | keep | ⚠️ partially inspected |
| 1288 | `tutorials/03_crud.md` | ZH | notes_project (selectors/services) | keep | ⚠️ partially inspected |
| 1115 | `tutorials/04_templates_bootstrap.md` | ZH | crispy_notes (SaaS dashboard) | keep | ⚠️ partially inspected |
| 2020 | `tutorials/05_authentication.md` | ZH | notes_chat_app | **4 помилки виправлено** ✅ | ✅ fully inspected |
| 1912 | `tutorials/06_testing.md` | ZH | notes_chat_app | keep | ⚠️ partially inspected |
| 1387 | `tutorials/07_async.md` | ZH | notes_chat_app | keep | ⚠️ partially inspected |
| 1371 | `tutorials/08_deployment.md` | ZH | notes_chat_app | keep | ⚠️ partially inspected |

---

## Tutorials — README модулів (README_1–README_9)

Більш деталізовані версії туторіалів (1409–2387 рядків кожен).

| Рядки | Файл | Тип | Відповідний tutorial | Проєкт | Дія | Inspection |
|-------|------|-----|----------------------|--------|-----|-----------|
| 1542 | `tutorials/README_1.md` | RM | 01_first_django_page | hello_project | keep | 🔍 structure only |
| 1409 | `tutorials/README_2.md` | RM | 02_first_model | bootstrap_notes | keep | 🔍 structure only |
| 2387 | `tutorials/README_3.md` | RM | 03_crud | notes_project | keep | 🔍 structure only |
| 1506 | `tutorials/README_4.md` | RM | (CBV — не охоплено в 01–08) | notes_project_cbv | keep | 🔍 structure only |
| 1415 | `tutorials/README_5.md` | RM | 04_templates_bootstrap | crispy_notes | keep | ⚠️ partially inspected |
| 1501 | `tutorials/README_6.md` | RM | 05_authentication | **crispy_notes_project** (не notes_chat_app!) | needs accuracy check — виявлено 1 потенційну помилку | ✅ fully inspected |
| 1993 | `tutorials/README_7.md` | RM | 06_testing | **crispy_notes_project** (тести того ж проєкту) | needs accuracy check — виявлено 2 low проблеми | ✅ fully inspected |
| 1490 | `tutorials/README_8.md` | RM | 07_async | crispy_notes_project + notes_chat_app | needs accuracy check — виявлено 1 medium проблему | ✅ fully inspected |
| 1930 | `tutorials/README_9.md` | RM | 08_deployment | **notes_chat_app** (production stack) | needs accuracy check — **2 помилки знайдено** 🔴 | ✅ fully inspected |

---

## Зведення за типами

| Тип | К-сть файлів | Приблизно рядків | Пріоритет перевірки |
|-----|-------------|------------------|---------------------|
| KB (Knowledge Book) | ~90 | ~55 000 | середній — теорія відносно стабільна |
| ZH (Zero to Hero) | 8 | ~11 500 | **ВИСОКИЙ** — прив'язані до коду |
| RM (README модулі) | 9 | ~15 500 | **ВИСОКИЙ** — прив'язані до коду |
| PD (Project Deep Dive) | 13 | ~240 | **КРИТИЧНИЙ** — стаби, потребують написання |
| LAB | 4 | ~24 | **КРИТИЧНИЙ** — стаби |
| REF | ~11 | ~2 000 | середній |
| LEG (Legacy) | ~13 | ~2 000 | низький |
| INT | ~25 | ~1 200 | низький |

---

## Файли коду що НЕ існують (виправлення попереднього аудиту)

| Очікуваний файл | Реальний статус |
|----------------|----------------|
| `Makefile` | **НЕ ІСНУЄ** |
| `notes_app/signals.py` | **НЕ ІСНУЄ** |
| `notes_app/middleware.py` | **НЕ ІСНУЄ** — middleware лише у `notes_project/middleware.py` |
| `archive/` директорія | **НЕ ІСНУЄ** у поточному репо |

## Нові файли коду (додані до аудиту)

| Файл | Роль |
|------|------|
| `notes_project/middleware.py` | `DebugExceptionMiddleware` — першим у MIDDLEWARE (security concern) |
| `notes_app/context_processors.py` | `sidebar_context()` — глобальний контекст шаблонів |
| `notes_app/apps.py` | `HelloAppConfig` (odd naming) |
| `entrypoint.sh` | migrate → collectstatic → uvicorn --reload |
| `notes_app/static/notes_app/js/group_chat.js` | Vanilla JS WebSocket клієнт з exponential backoff |
