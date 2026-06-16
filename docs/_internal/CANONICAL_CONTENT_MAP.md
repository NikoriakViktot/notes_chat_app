# Canonical Content Map

Phase 2 — Architecture Planning
Створено: 2026-06-14

Цільова роль кожного з 179 Markdown-файлів у трьох шарах книги.

Допустимі Action:
- `keep as canonical` — ця глава є основним джерелом теми
- `keep as section index` — навігаційний файл, залишається як є
- `keep as summary` — коротке нагадування, посилається на canonical
- `keep as visual companion` — тільки Mermaid-схеми до canonical глави
- `expand` — stub, потребує написання повного змісту
- `rewrite later` — має зміст, але потребує переробки
- `merge later` — унікальний контент злити до canonical глави (у майбутньому батчі)
- `redirect later` — замінити посиланням на canonical (після merge)
- `archive later` — не унікальний, безпечно перемістити до archive/ (тільки після повної інспекції)
- `provisional` — рішення відкладено до повної семантичної інспекції

Допустимі Confidence:
- `high` — файл повністю прочитаний, рішення надійне
- `medium` — файл частково прочитаний
- `low` — тільки структура відома

---

## 00 — Getting Started

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `00_getting_started/README.md` | Огляд курсу, три шари, схема | KB Intro | Книга → Як користуватися | keep as canonical | high | fully inspected | Схема notes_chat_app, опис трьох шарів |
| `00_getting_started/how_to_use_course.md` | Як читати курс | KB Intro | Книга → Як користуватися | keep as canonical | low | structure only | — |
| `00_getting_started/local_setup.md` | Docker, команди запуску | ZH/KB | Zero to Hero Крок 0 | keep as canonical | high | fully inspected | Команди docker compose, uvicorn |
| `00_getting_started/prerequisites.md` | Необхідні знання | KB Intro | Книга → Як користуватися | keep as canonical | low | structure only | — |
| `00_getting_started/repository_structure.md` | Структура репо | KB/PD | Project Deep Dive Ch.3 | keep as canonical | low | structure only | — |

---

## 01 — Web Foundations

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `01_web_foundations/README.md` | Огляд розділу | KB I | Частина I (index) | keep as section index | low | structure only | — |
| `01_web_foundations/http_https.md` | HTTP/HTTPS | KB I | Частина I | keep as summary | low | structure only | — |
| `01_web_foundations/browser_server_lifecycle.md` | HTTP lifecycle | KB I | Частина I | keep as summary | low | structure only | — |
| `01_web_foundations/network_foundation_full.md` | Мережевий фундамент, TCP/IP, DNS, TLS | KB I | Частина I | keep as canonical | low | structure only | Повна теорія TCP/IP, TLS handshake |
| `01_web_foundations/network_mermaid_full.md` | Mermaid-схеми мережі | KB I | Частина I | keep as visual companion | low | structure only | Mermaid мережевих протоколів |

---

## 02 — Django Core

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `02_django_core/README.md` | Огляд розділу | KB II | Частина II (index) | keep as section index | low | structure only | — |
| `02_django_core/django_architecture_full.md` | Архітектура Django, MTV, middleware | KB II | Частина II | keep as canonical | medium | partially inspected | MTV diagram, middleware stack |
| `02_django_core/django_command_system.md` | Redirect до management_commands_full | KB II | Частина II | redirect later | low | structure only | — |
| `02_django_core/django_mermaid_full.md` | Mermaid-схеми Django | KB II | Частина II | keep as visual companion | low | structure only | Всі Mermaid Django |
| `02_django_core/management_commands_full.md` | Management commands | KB II | Частина II | keep as canonical | low | structure only | — |
| `02_django_core/project_structure_full.md` | Структура проєкту | KB II | Частина II | keep as canonical | low | structure only | — |
| `02_django_core/request_lifecycle.md` | Request lifecycle (short) | KB II | Частина II | keep as summary | low | structure only | — |
| `02_django_core/url_routing_full.md` | URL routing | KB II | Частина II | keep as canonical | low | structure only | Routing deep dive |
| `02_django_core/urls_and_views.md` | URLs + Views (short) | KB II | Частина II | provisional | low | structure only | Перевірити на унікальний контент |
| `02_django_core/views_full.md` | FBV, CBV, decorators | KB II | Частина II | keep as canonical | medium | partially inspected | selectors/services pattern у views |
| `02_django_core/wsgi_vs_asgi.md` | WSGI vs ASGI | KB II | Частина II | keep as canonical | low | structure only | — |

---

## 03 — Database and ORM

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `03_database_and_orm/README.md` | Огляд розділу | KB III | Частина III (index) | keep as section index | low | structure only | — |
| `03_database_and_orm/relational_db_foundations_full.md` | Реляційні БД, SQL | KB III | Частина III | keep as canonical | low | structure only | SQL foundation |
| `03_database_and_orm/django_models.md` | Моделі (short) | KB III | Частина III | keep as summary | low | structure only | Перевірити перед merge |
| `03_database_and_orm/django_orm_full.md` | ORM основи | KB III | Частина III | keep as canonical | low | structure only | QuerySet API |
| `03_database_and_orm/django_orm_deep_full.md` | Q, F, annotate | KB III | Частина III | keep as canonical | low | structure only | Q objects, annotate, F |
| `03_database_and_orm/django_migrations_full.md` | Міграції (deep) | KB III | Частина III | keep as canonical | high | fully inspected | Migration graph, squash |
| `03_database_and_orm/migrations.md` | Міграції notes_chat_app (short) | KB III/PD | Частина III + PD Ch.9 | keep as summary | high | fully inspected | Реальні команди для notes_chat_app |
| `03_database_and_orm/postgresql_advanced_full.md` | PostgreSQL, production | KB III | Частина III | keep as canonical | low | structure only | — |
| `03_database_and_orm/indexing_deep_full.md` | Індекси PostgreSQL | KB III | Частина III | keep as canonical | low | structure only | — |
| `03_database_and_orm/transactions_concurrency_full.md` | Транзакції, блокування | KB III | Частина III | keep as canonical | low | structure only | — |
| `03_database_and_orm/transactions_indexes_postgresql.md` | Транзакції+Індекси+PG (short) | KB III | Частина III | keep as summary | low | structure only | Перевірити на унікальний контент |
| `03_database_and_orm/orm_mermaid_full.md` | Mermaid ORM схеми | KB III | Частина III | keep as visual companion | low | structure only | Всі ORM Mermaid |
| `03_database_and_orm/query_optimization.md` | Query optimization (short) | KB III | Частина III | keep as summary | low | structure only | Перевірити |

---

## 04 — Forms and Validation

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `04_forms_and_validation/README.md` | Огляд розділу | KB IV | Частина IV (index) | keep as section index | low | structure only | — |
| `04_forms_and_validation/django_forms_full.md` | Django Forms, ModelForm, validation | KB IV | Частина IV | keep as canonical | low | structure only | Validation pipeline, PRG |
| `04_forms_and_validation/crispy_forms_full.md` | Crispy Forms, FormHelper, Layout | KB IV | Частина IV | keep as canonical | low | structure only | Layout system |
| `04_forms_and_validation/django_forms_and_crispy.md` | Forms + Crispy (short) | KB IV | Частина IV | keep as summary | low | structure only | Перевірити на унікальний контент |

---

## 05 — Frontend and Templates

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `05_frontend_and_templates/README.md` | Огляд розділу | KB V | Частина V (index) | keep as section index | low | structure only | — |
| `05_frontend_and_templates/html_basics_full.md` | HTML | KB V | Частина V | keep as canonical | low | structure only | — |
| `05_frontend_and_templates/css_basics_full.md` | CSS | KB V | Частина V | keep as canonical | low | structure only | — |
| `05_frontend_and_templates/django_templates_full.md` | Шаблони Django | KB V | Частина V | keep as canonical | high | fully inspected | Context system, template security, Mermaid |
| `05_frontend_and_templates/advanced_templates_full.md` | Context Processors, Custom Tags, HTMX | KB V | Частина V | keep as canonical | medium | partially inspected | Context processors, custom tags, HTMX intro |
| `05_frontend_and_templates/bootstrap_5_full.md` | Bootstrap 5 | KB V | Частина V | keep as canonical | low | structure only | — |
| `05_frontend_and_templates/design_foundations_full.md` | Дизайн-основи | KB V | Частина V | keep as canonical | low | structure only | — |
| `05_frontend_and_templates/design_readme_full.md` | Design README | KB V | Частина V | provisional | low | structure only | Перевірити overlap з design_foundations |
| `05_frontend_and_templates/django_admin_full.md` | Django Admin | KB V | Частина V | keep as canonical | low | structure only | — |
| `05_frontend_and_templates/django_admin_unfold_full.md` | Django Admin + Unfold | KB V | Частина V | keep as canonical | low | structure only | Unfold theming |
| `05_frontend_and_templates/django_templates_bootstrap_full.md` | Templates + Bootstrap | KB V | Частина V | provisional | low | structure only | Перевірити overlap з advanced_templates |
| `05_frontend_and_templates/templates_bootstrap_static.md` | Templates+Bootstrap+Static (short) | KB V | Частина V | keep as summary | low | structure only | Перевірити |

---

## 06 — Application Architecture

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `06_application_architecture/README.md` | Огляд розділу | KB VI | Частина VI (index) | keep as section index | low | structure only | — |
| `06_application_architecture/services_selectors_full.md` | Services, Selectors, антипатерни | KB VI | Частина VI | keep as canonical | medium | partially inspected | Повна архітектурна карта, антипатерни |
| `06_application_architecture/django_services_full.md` | Services pattern | KB VI | Частина VI | keep as canonical | low | structure only | Services deep dive |
| `06_application_architecture/django_selectors_full.md` | Selectors pattern | KB VI | Частина VI | keep as canonical | low | structure only | Selectors deep dive |
| `06_application_architecture/django_services_selectors.md` | Services+Selectors об'єднаний (historical) | KB VI | Частина VI | merge later | high | fully inspected | Перевірити на унікальний контент до merge |
| `06_application_architecture/services_selectors.md` | Services+Selectors (short) | KB VI | Частина VI | keep as summary | low | structure only | Перевірити |
| `06_application_architecture/django_serializers_full.md` | Serializers | KB VI | Частина VI | keep as canonical | low | structure only | — |
| `06_application_architecture/django_tasks_full.md` | Celery tasks | KB VI | Частина VI | keep as canonical | low | structure only | Celery theory |
| `06_application_architecture/django_ninja_templates_full.md` | Django Ninja + rendering | KB VI | Частина VI | keep as canonical | low | structure only | Ninja API approach |

---

## 07 — Auth and Security

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `07_auth_and_security/README.md` | Огляд розділу | KB VII | Частина VII (index) | keep as section index | low | structure only | — |
| `07_auth_and_security/auth_basics_full.md` | AuthN vs AuthZ | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/sessions_flow_full.md` | Сесії, login/logout | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/permissions_full.md` | Permissions та Groups | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/auth_sessions_permissions.md` | Auth+Sessions+Perms (short) | KB VII | Частина VII | keep as summary | low | structure only | Перевірити |
| `07_auth_and_security/django_security_architecture_full.md` | Архітектура безпеки Django | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/security_foundations_full.md` | Основи безпеки | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/security_misconceptions_full.md` | Типові помилки безпеки | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/owasp_top_10_full.md` | OWASP Top 10 | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/zero_trust_full.md` | Zero Trust | KB VII | Частина VII | keep as canonical | low | structure only | — |
| `07_auth_and_security/siem_full.md` | SIEM | KB VII | Частина VII | keep as canonical | low | structure only | — |

---

## 08 — Testing and Quality

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `08_testing_and_quality/README.md` | Огляд розділу | KB VIII | Частина VIII (index) | keep as section index | low | structure only | — |
| `08_testing_and_quality/testing_foundations_full.md` | Основи тестування | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/unittest_basics_full.md` | unittest | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/pytest_basics_full.md` | pytest | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/django_testing_full.md` | Django Testing довідник | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/mocking_and_patching_full.md` | Mock, patch | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/test_data_and_fixtures_full.md` | Test data, fixtures | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/selenium_full.md` | Selenium, E2E | KB VIII | Частина VIII | keep as canonical | low | structure only | — |
| `08_testing_and_quality/ci_cd_full.md` | CI/CD, GitHub Actions | KB VIII | Частина VIII | keep as canonical | medium | partially inspected | YAML рядок за рядком |
| `08_testing_and_quality/ci.md` | CI short | KB VIII | Частина VIII | keep as summary | high | fully inspected | Legacy async routes |
| `08_testing_and_quality/testing_strategy.md` | Testing strategy (short) | KB VIII | Частина VIII | keep as summary | low | structure only | — |
| `08_testing_and_quality/testing_practice_project_full.md` | Практика: notes_chat_app | KB VIII/ZH | Частина VIII + ZH Крок 6 | keep as canonical | low | structure only | Тестування notes_chat_app |

---

## 09 — Async and Realtime

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `09_async_and_realtime/README.md` | Огляд розділу | KB IX | Частина IX (index) | keep as section index | low | structure only | — |
| `09_async_and_realtime/async_01_sync_vs_async_full.md` | Sync vs Async | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_02_asyncio_full.md` | asyncio | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_03_asgi_full.md` | ASGI | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_04_django_async_views_full.md` | Async views | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_05_async_orm_full.md` | Async ORM | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_06_sync_to_async_full.md` | sync_to_async | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_07_async_http_clients_full.md` | Async HTTP clients | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_08_benchmarking_full.md` | Benchmarking | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/async_09_async_use_cases_full.md` | Async use cases | KB IX | Частина IX | keep as canonical | low | structure only | — |
| `09_async_and_realtime/channels_websocket.md` | Channels+WebSocket short, Mermaid flow | KB IX | Частина IX | keep as summary | high | fully inspected | Mermaid flow, channel layer switch |

---

## 10 — Linux and DevOps

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `10_linux_and_devops/README.md` | Огляд розділу | KB X | Частина X (index) | keep as section index | low | structure only | — |
| `10_linux_and_devops/linux_01_mental_model_full.md` | Linux ментальна модель | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_02_terminal_and_shell_full.md` | Terminal та shell | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_03_filesystem_navigation_full.md` | Файлова система | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_04_files_permissions_users_full.md` | Файли, permissions | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_05_processes_ports_services_full.md` | Процеси, порти | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_06_package_managers_and_software_full.md` | Пакетні менеджери | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_07_ssh_and_remote_server_full.md` | SSH та сервери | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_08_environment_variables_and_secrets_full.md` | Env vars | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_09_bash_scripts_full.md` | Bash скрипти | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/linux_10_makefile_basics_full.md` | Makefile | KB X | Частина X | keep as canonical | low | structure only | — |
| `10_linux_and_devops/docker_and_runtime.md` | Docker short — notes_chat_app specific | KB X/PD | Частина X + PD Ch.30 | keep as summary | high | fully inspected | notes_chat_app Docker details, legacy dir note |

---

## 11 — Deployment

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `11_deployment/README.md` | Огляд розділу | KB X | Частина X Deployment (index) | keep as section index | low | structure only | — |
| `11_deployment/deploy_11_django_on_linux_full.md` | Django на Linux | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_12_nginx_gunicorn_uvicorn_full.md` | Nginx, gunicorn, uvicorn | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_13_logs_monitoring_debugging_full.md` | Логи, моніторинг | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_14_docker_basics_full.md` | Docker basics | KB X | Частина X | keep as canonical | medium | partially inspected | Mermaid image vs container |
| `11_deployment/deploy_15_docker_compose_full.md` | Docker Compose | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_16_devops_workflow_full.md` | DevOps workflow | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_17_kubernetes_overview_full.md` | Kubernetes | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deploy_18_roadmap_next_steps_full.md` | Roadmap | KB X | Частина X | keep as canonical | low | structure only | — |
| `11_deployment/deployment_checklist.md` | Deployment checklist | REF | Довідник | keep as canonical | low | structure only | — |

---

## 12 — Final Project (Project Deep Dive)

Усі файли є стабами (13–31 рядків) — потребують написання повного змісту.

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `12_final_project/README.md` | Огляд фінального проєкту (stub) | PD | PD Ch.1 | expand | high | fully inspected | — |
| `12_final_project/project_overview.md` | Огляд (stub) | PD | PD Ch.1 | expand | medium | partially inspected | — |
| `12_final_project/architecture.md` | Архітектура (stub) | PD | PD Ch.3, Ch.23 | expand | high | fully inspected | — |
| `12_final_project/domain_model.md` | ER-діаграма (Mermaid) | PD | PD Ch.7 | expand | medium | partially inspected | Mermaid ER — перевірити на точність полів |
| `12_final_project/feature_map.md` | Feature map (stub) | PD | PD Ch.2 | expand | high | fully inspected | — |
| `12_final_project/request_flows.md` | Request flows (stub) | PD | PD Ch.13, Ch.23 | expand | high | fully inspected | — |
| `12_final_project/async_and_chat.md` | Async та Chat (stub) | PD | PD Ch.23–Ch.28 | expand | high | fully inspected | — |
| `12_final_project/security_model.md` | Security model (stub) | PD | PD Ch.32 | expand | high | fully inspected | — |
| `12_final_project/setup.md` | Setup (stub) | PD | PD Ch.4, Ch.5 | expand | high | fully inspected | — |
| `12_final_project/testing_strategy.md` | Testing strategy (stub) | PD | PD Ch.29 | expand | high | fully inspected | — |
| `12_final_project/deployment.md` | Деплоймент (stub) | PD | PD Ch.30, Ch.34 | expand | high | fully inspected | — |
| `12_final_project/student_tasks.md` | Завдання студентів (stub) | PD | PD Ch.35 | expand | high | fully inspected | — |
| `12_final_project/orm_architecture_board.md` | ORM board (stub) | PD | PD Ch.7, Ch.8 | expand | high | fully inspected | — |

---

## Root-level docs

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `README.md` | Вступ до репо | INT | Книга → Головна | keep as canonical | low | structure only | — |
| `index.md` | Головна MkDocs | INT | Книга → Головна | keep as canonical | low | structure only | — |
| `ARCHITECTURE.md` | Архітектурний огляд | PD/REF | PD Ch.1 + Довідник | keep as canonical | low | structure only | — |
| `GLOSSARY.md` | Глосарій | REF | Довідник | expand | low | structure only | — |
| `LEARNING_PATH.md` | Маршрут навчання | KB/ZH | Викладачу | keep as canonical | high | fully inspected | Sequential learning path |
| `TEACHING_GUIDE.md` | Гайд викладача | KB | Викладачу | keep as canonical | high | fully inspected | Short/standard/full routes |
| `TROUBLESHOOTING.md` | Troubleshooting | REF | Довідник | keep as canonical | low | structure only | — |

---

## Labs

Усі lab-файли є стабами (5–8 рядків) — потребують написання повного змісту.

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection |
|---|---|---|---|---|---|---|
| `labs/README.md` | Огляд лабораторних (stub) | LAB | Практика | expand | low | structure only |
| `labs/orm_lab.md` | ORM Lab (stub) | LAB | Практика | expand | low | structure only |
| `labs/forms_lab.md` | Forms Lab (stub) | LAB | Практика | expand | low | structure only |
| `labs/testing_lab.md` | Testing Lab (stub) | LAB | Практика | expand | low | structure only |
| `labs/async_lab.md` | Async Lab (stub) | LAB | Практика | expand | low | structure only |

---

## Reference

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `reference/README.md` | Огляд довідника | REF | Довідник (index) | keep as section index | low | structure only | — |
| `reference/commands.md` | Команди | REF | Довідник | keep as canonical | high | fully inspected | Docker compose commands |
| `reference/orm_cheatsheet.md` | ORM Cheatsheet | REF | Довідник | keep as canonical | low | structure only | — |
| `reference/testing_cheatsheet.md` | Testing Cheatsheet | REF | Довідник | keep as canonical | high | fully inspected | Consumer test pattern (fixed) |
| `reference/git_cheatsheet.md` | Git Cheatsheet | REF | Довідник | keep as canonical | low | structure only | — |
| `reference/deployment_cheatsheet.md` | Deployment Cheatsheet | REF | Довідник | keep as canonical | high | fully inspected | — |
| `reference/settings_reference.md` | Settings Reference | REF | Довідник | keep as canonical | high | fully inspected | DATABASE_URL Exception (fixed) |
| `reference/legacy_indexes/README.md` | Legacy index stub (2 рядки) | LEG | — | keep as stub | high | fully inspected | Нема унікального контенту |
| `reference/legacy_indexes/index_1.md` | Навч. путівник Parts I+II+VI: 5-рівневий learning map, "шлях студента" 1-16, таблиця 10 типових помилок, quickref | LEG | KB Part I+II README (джерело) | keep as learning path source | high | fully inspected | "Шлях студента" 1-16; таблиця помилок (N+1, atomic trap тощо); деякі посилання вказують на legacy_missing_reference (проєкти відсутні) |
| `reference/legacy_indexes/index_2.md` | Навч. путівник Part V: 23-крокова "студентська стежка", детальні section-map для 7 файлів, алгоритм дебагу, cross-file dependency map | LEG | KB Part V README (джерело) | keep as learning path source | high | fully inspected | 23-кроковий навч. маршрут унікальний; алгоритм дебагу (CSS/Bootstrap/Template/HTMX) унікальний; деякі посилання → legacy_missing_reference (django_bootstrap_project відсутній) |
| `reference/legacy_indexes/index_3.md` | Навч. путівник Part III: 9-рівневий learning map, 20-кроковий порядок читання, таблиці FBV/CBV проєктів | LEG | KB Part III README (джерело) | keep as learning path source | high | fully inspected | 9-рівневий map унікальний; FBV/CBV роздвоєння описує застарілу dual-project структуру — потребує адаптації |
| `reference/legacy_indexes/index_4.md` | Навч. путівник Part VII: 10-кроковий маршрут Auth+Security, quickstart для crispy_notes_chat_app | LEG | KB Part VII README (джерело) | keep as learning path source | high | fully inspected | 10-кроковий порядок унікальний; quickstart команди вказують на crispy_notes_chat_app (окремий старий проєкт, не notes_chat_app) — потребує уточнення |
| `reference/legacy_indexes/index_5.md` | Навч. путівник Part VIII: 13-секційний гід для початківців — піраміда, таблиця навичок, mermaid шляху студента | LEG | KB Part VIII README (джерело) | keep as learning path source | high | fully inspected | 13 секцій (піраміда, AAA, три рівні розуміння, карта файлів уроку) унікальні як педагогічний вступ |
| `reference/legacy_indexes/index_7.md` | Навч. путівник Part IX: mermaid async flowchart, 9-файлова таблиця, передумови, результати | LEG | KB Part IX README (джерело) | keep as learning path source | high | fully inspected | mermaid 01→09 flowchart унікальний; "Async ≠ завжди швидше" попередження цінне; файли вже в nav |
| `reference/legacy_indexes/index_8.md` | Навч. путівник Parts X+XI: 18-файлова таблиця, mermaid flowchart, мін/повний маршрут, student outcomes | LEG | KB Part X README (джерело) | keep as learning path source | high | fully inspected | 18-файловий mermaid унікальний; мінімальний маршрут (7 файлів) + повний (18) унікальні |
| `reference/legacy_source/README.md` | Stub (2 рядки) | LEG | — | keep as stub | high | fully inspected | Нема контенту |
| `reference/legacy_source/archive_legacy_docs_readme.md` | 9-рядкове пояснення про docs_flat | LEG | — | keep as stub | high | fully inspected | Пояснює що docs_flat/ = archive — нема унікального навч. контенту |
| `reference/legacy_source/docs_flat_readme.md` | Повний гід Django Testing (~300 рядків): IDOR тест, Django Test Client приклади, мокінг, navigation | LEG | labs/testing_lab.md (джерело) | keep → merge later into testing_lab | high | fully inspected | Унікальні: IDOR тест test_cannot_edit_other_users_note, test_note_form_filters_notebooks_by_user; посилання на crispy_notes_chat_app (не notes_chat_app) — код концептуально валідний |
| `reference/legacy_source/forms_views_laboratory_reference.md` | Stub — placeholder для відсутнього forms/views .ipynb | LEG | — | keep as stub | high | fully inspected | Не видаляти — запобігає broken links з index_3 |
| `reference/legacy_source/legacy_missing_reference.md` | Stub — placeholder для посилань на відсутні проєкти (simple_django_project, news_portal тощо) | LEG | — | keep as stub | high | fully inspected | Не видаляти — зберігає цілісність посилань з index_1, index_2, index_3 |
| `reference/legacy_source/orm_laboratory_reference.md` | Stub — placeholder для відсутнього ORM .ipynb | LEG | — | keep as stub | high | fully inspected | Не видаляти — запобігає broken links з index_3 |

---

## Tutorials — покрокові туторіали

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `tutorials/README.md` | Огляд туторіалів | ZH | Zero to Hero (index) | keep as section index | high | fully inspected | — |
| `tutorials/01_first_django_page.md` | Hello project (ZH) | ZH | ZH Крок 1 | keep as canonical | medium | partially inspected | Standalone hello_project |
| `tutorials/02_first_model.md` | Перша модель (ZH) | ZH | ZH Крок 2 | keep as canonical | medium | partially inspected | bootstrap_notes |
| `tutorials/03_crud.md` | CRUD + selectors (ZH) | ZH | ZH Крок 3 | keep as canonical | medium | partially inspected | notes_project CRUD |
| `tutorials/04_templates_bootstrap.md` | Forms + Bootstrap (ZH) | ZH | ZH Крок 4 | keep as canonical | medium | partially inspected | crispy_notes SaaS |
| `tutorials/05_authentication.md` | Auth + permissions (ZH) | ZH | ZH Крок 5 | keep as canonical | high | fully inspected | **4 помилки виправлено** — canonical version |
| `tutorials/06_testing.md` | Testing (ZH) | ZH | ZH Крок 6 | keep as canonical | medium | partially inspected | **Issue 12 виправлено** |
| `tutorials/07_async.md` | Async + WebSocket (ZH) | ZH | ZH Крок 7 | keep as canonical | medium | partially inspected | **Issue 15 виправлено** |
| `tutorials/08_deployment.md` | Deployment (ZH) | ZH | ZH Крок 8 | keep as canonical | medium | partially inspected | Docker stack |

---

## Tutorials — README модулів

| Current file | Current role | Target layer | Canonical target | Action | Confidence | Inspection | Unique content to preserve |
|---|---|---|---|---|---|---|---|
| `tutorials/README_1.md` | Module 1 детальний (hello_project) | ZH/RM | ZH Крок 1 companion | keep as canonical | low | structure only | Детальніший ніж 01_first_django_page |
| `tutorials/README_2.md` | Module 2 детальний (bootstrap_notes) | ZH/RM | ZH Крок 2 companion | keep as canonical | low | structure only | — |
| `tutorials/README_3.md` | Module 3 детальний (notes_project CRUD) | ZH/RM | ZH Крок 3 companion | keep as canonical | low | structure only | — |
| `tutorials/README_4.md` | Module 4 детальний (CBV) | ZH/RM | ZH Крок 4 companion | keep as canonical | low | structure only | CBV coverage (немає у 04 tutorial) |
| `tutorials/README_5.md` | Module 5 детальний (crispy_notes) | ZH/RM | ZH Крок 4 companion | keep as canonical | medium | partially inspected | — |
| `tutorials/README_6.md` | Module 6 детальний (crispy_notes auth) | ZH/RM | ZH Крок 5 companion | keep as canonical | high | fully inspected | **Issue 6 виправлено** — explicit keyword args |
| `tutorials/README_7.md` | Module 7 детальний (testing) | ZH/RM | ZH Крок 6 companion | rewrite later | high | fully inspected | Low: legacy paths — потребує cleanup |
| `tutorials/README_8.md` | Module 8 детальний (async) | ZH/RM | ZH Крок 7 companion | keep as canonical | high | fully inspected | **Issue 8 виправлено** — навчальний async_views vs prod |
| `tutorials/README_9.md` | Module 9 детальний (production stack) | ZH/RM | ZH Крок 8 companion | keep as canonical | high | fully inspected | **Issues 9,10,17-22 виправлено** — ChatMessage CASCADE, ShopItem fields |

---

## Зведена статистика рішень

| Action | К-сть файлів |
|--------|-------------|
| keep as canonical | ~95 |
| keep as section index | ~15 |
| keep as summary | ~15 |
| keep as visual companion | ~5 |
| expand (stubs) | ~18 |
| rewrite later | ~1 |
| merge later | ~2 |
| redirect later | ~1 |
| provisional | ~27 |

**Всього: 179 файлів**

Жоден файл не позначено як `delete` — унікальний контент потребує збереження або повної інспекції перед архівацією.
