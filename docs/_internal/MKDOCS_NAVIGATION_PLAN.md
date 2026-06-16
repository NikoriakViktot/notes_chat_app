# MkDocs Navigation Plan

Phase 2 — Architecture Planning → **ЗАСТОСОВАНО (Batch L, 2026-06-14)**
Створено: 2026-06-14

**Цей план застосовано до `mkdocs.yml` в рамках Batch L.**

Зміни відносно старої навігації:
- Новий top-level `Як користуватися` (було всередині `Книга`)
- `Книга` → `Книга Django` з 10 явними Частинами
- Новий top-level `Zero to Hero` (туторіали виведені з `Практика`)
- `Практика` — тільки labs
- `Довідник` — без `legacy_indexes/` і `legacy_source/`; додано `deployment_checklist`
- Виправлено 3 YAML-помилки з двокрапками в мітках nav (quoted)
- `mkdocs build --strict`: BLOCKED (MkDocs не встановлено)

---

## Принципи навігації

- Глибина меню: максимум 3 рівні.
- Прогресія: Foundation → Beginner → Intermediate → Advanced → Production.
- Окремий top-level для кожного з трьох шарів книги.
- Reference і Teacher guide винесені на верхній рівень.
- `docs/_internal/` не з'являється у navigation.
- Legacy indexes переносяться до archive або прибираються з nav.

---

## Запропонований YAML-фрагмент

```yaml
nav:
  - Головна: index.md

  - Як користуватися:
    - Вступ: 00_getting_started/README.md
    - Необхідні знання: 00_getting_started/prerequisites.md
    - Налаштування: 00_getting_started/local_setup.md
    - Структура репозиторію: 00_getting_started/repository_structure.md
    - Як читати курс: 00_getting_started/how_to_use_course.md

  - Книга Django:
    - "Частина I. Web Foundation":
      - Огляд: 01_web_foundations/README.md
      - Мережевий фундамент: 01_web_foundations/network_foundation_full.md
      - HTTP та HTTPS: 01_web_foundations/http_https.md
      - Браузер ↔ Сервер: 01_web_foundations/browser_server_lifecycle.md
      - Мережеві діаграми: 01_web_foundations/network_mermaid_full.md

    - "Частина II. Django Core":
      - Огляд: 02_django_core/README.md
      - Архітектура Django: 02_django_core/django_architecture_full.md
      - URL Routing: 02_django_core/url_routing_full.md
      - Views: 02_django_core/views_full.md
      - Request Lifecycle: 02_django_core/request_lifecycle.md
      - WSGI vs ASGI: 02_django_core/wsgi_vs_asgi.md
      - Структура проєкту: 02_django_core/project_structure_full.md
      - Management Commands: 02_django_core/management_commands_full.md
      - Діаграми: 02_django_core/django_mermaid_full.md

    - "Частина III. Models, Database та ORM":
      - Огляд: 03_database_and_orm/README.md
      - Реляційні БД: 03_database_and_orm/relational_db_foundations_full.md
      - Django Models: 03_database_and_orm/django_orm_full.md
      - ORM поглиблено: 03_database_and_orm/django_orm_deep_full.md
      - Міграції: 03_database_and_orm/django_migrations_full.md
      - PostgreSQL: 03_database_and_orm/postgresql_advanced_full.md
      - Індекси: 03_database_and_orm/indexing_deep_full.md
      - Транзакції: 03_database_and_orm/transactions_concurrency_full.md
      - ORM Діаграми: 03_database_and_orm/orm_mermaid_full.md

    - "Частина IV. Forms і Validation":
      - Огляд: 04_forms_and_validation/README.md
      - Django Forms: 04_forms_and_validation/django_forms_full.md
      - Crispy Forms: 04_forms_and_validation/crispy_forms_full.md

    - "Частина V. Templates і Frontend":
      - Огляд: 05_frontend_and_templates/README.md
      - HTML основи: 05_frontend_and_templates/html_basics_full.md
      - CSS основи: 05_frontend_and_templates/css_basics_full.md
      - Django Templates: 05_frontend_and_templates/django_templates_full.md
      - Advanced Templates: 05_frontend_and_templates/advanced_templates_full.md
      - Bootstrap 5: 05_frontend_and_templates/bootstrap_5_full.md
      - Django Admin: 05_frontend_and_templates/django_admin_full.md
      - Django Admin Unfold: 05_frontend_and_templates/django_admin_unfold_full.md
      - Дизайн-основи: 05_frontend_and_templates/design_foundations_full.md

    - "Частина VI. Архітектура застосунку":
      - Огляд: 06_application_architecture/README.md
      - Services та Selectors: 06_application_architecture/services_selectors_full.md
      - Services (поглиблено): 06_application_architecture/django_services_full.md
      - Selectors (поглиблено): 06_application_architecture/django_selectors_full.md
      - Serializers: 06_application_architecture/django_serializers_full.md
      - Celery Tasks: 06_application_architecture/django_tasks_full.md
      - Django Ninja: 06_application_architecture/django_ninja_templates_full.md

    - "Частина VII. Authentication і Security":
      - Огляд: 07_auth_and_security/README.md
      - Автентифікація: 07_auth_and_security/auth_basics_full.md
      - Сесії: 07_auth_and_security/sessions_flow_full.md
      - Права доступу: 07_auth_and_security/permissions_full.md
      - Архітектура безпеки: 07_auth_and_security/django_security_architecture_full.md
      - Основи безпеки: 07_auth_and_security/security_foundations_full.md
      - Типові помилки: 07_auth_and_security/security_misconceptions_full.md
      - OWASP Top 10: 07_auth_and_security/owasp_top_10_full.md
      - Zero Trust: 07_auth_and_security/zero_trust_full.md
      - SIEM: 07_auth_and_security/siem_full.md

    - "Частина VIII. Testing і Quality":
      - Огляд: 08_testing_and_quality/README.md
      - Основи тестування: 08_testing_and_quality/testing_foundations_full.md
      - unittest: 08_testing_and_quality/unittest_basics_full.md
      - pytest: 08_testing_and_quality/pytest_basics_full.md
      - Django Testing: 08_testing_and_quality/django_testing_full.md
      - Mocking: 08_testing_and_quality/mocking_and_patching_full.md
      - Test Data: 08_testing_and_quality/test_data_and_fixtures_full.md
      - Selenium: 08_testing_and_quality/selenium_full.md
      - CI/CD: 08_testing_and_quality/ci_cd_full.md
      - Практика тестування: 08_testing_and_quality/testing_practice_project_full.md

    - "Частина IX. Async і Real-Time":
      - Огляд: 09_async_and_realtime/README.md
      - Sync vs Async: 09_async_and_realtime/async_01_sync_vs_async_full.md
      - asyncio: 09_async_and_realtime/async_02_asyncio_full.md
      - ASGI: 09_async_and_realtime/async_03_asgi_full.md
      - Django Async Views: 09_async_and_realtime/async_04_django_async_views_full.md
      - Async ORM: 09_async_and_realtime/async_05_async_orm_full.md
      - sync_to_async: 09_async_and_realtime/async_06_sync_to_async_full.md
      - Async HTTP Clients: 09_async_and_realtime/async_07_async_http_clients_full.md
      - Benchmarking: 09_async_and_realtime/async_08_benchmarking_full.md
      - Async Use Cases: 09_async_and_realtime/async_09_async_use_cases_full.md
      - WebSocket та Channels: 09_async_and_realtime/channels_websocket.md

    - "Частина X. Linux, DevOps і Deployment":
      - Огляд Linux: 10_linux_and_devops/README.md
      - Ментальна модель Linux: 10_linux_and_devops/linux_01_mental_model_full.md
      - Термінал та shell: 10_linux_and_devops/linux_02_terminal_and_shell_full.md
      - Файлова система: 10_linux_and_devops/linux_03_filesystem_navigation_full.md
      - Файли та права: 10_linux_and_devops/linux_04_files_permissions_users_full.md
      - Процеси та порти: 10_linux_and_devops/linux_05_processes_ports_services_full.md
      - Пакетні менеджери: 10_linux_and_devops/linux_06_package_managers_and_software_full.md
      - SSH та сервери: 10_linux_and_devops/linux_07_ssh_and_remote_server_full.md
      - Змінні середовища: 10_linux_and_devops/linux_08_environment_variables_and_secrets_full.md
      - Bash скрипти: 10_linux_and_devops/linux_09_bash_scripts_full.md
      - Makefile: 10_linux_and_devops/linux_10_makefile_basics_full.md
      - Docker та Runtime: 10_linux_and_devops/docker_and_runtime.md
      - Docker: повний посібник: 10_linux_and_devops/docker_guide.md
      - Огляд Deployment: 11_deployment/README.md
      - Django на Linux: 11_deployment/deploy_11_django_on_linux_full.md
      - Nginx + Gunicorn/Uvicorn: 11_deployment/deploy_12_nginx_gunicorn_uvicorn_full.md
      - Логи та моніторинг: 11_deployment/deploy_13_logs_monitoring_debugging_full.md
      - Docker основи: 11_deployment/deploy_14_docker_basics_full.md
      - Docker Compose: 11_deployment/deploy_15_docker_compose_full.md
      - DevOps workflow: 11_deployment/deploy_16_devops_workflow_full.md
      - Kubernetes огляд: 11_deployment/deploy_17_kubernetes_overview_full.md
      - Roadmap: 11_deployment/deploy_18_roadmap_next_steps_full.md

  - Zero to Hero:
    - Огляд маршруту: tutorials/README.md
    - "Крок 0 — Середовище": 00_getting_started/local_setup.md
    - "Крок 1. Hello Django":
      - Огляд: tutorials/01_hello_django/index.md
      - Середовище та запуск: tutorials/01_hello_django/environment.md
      - Структура проєкту: tutorials/01_hello_django/project_structure.md
      - URLs та Views: tutorials/01_hello_django/urls_and_views.md
      - Шаблони: tutorials/01_hello_django/templates.md
      - Django Admin: tutorials/01_hello_django/admin.md
      - Контрольна точка: tutorials/01_hello_django/checkpoint.md
    - "Крок 2. Перша модель":
      - Огляд: tutorials/02_first_model/index.md
      - Моделі та міграції: tutorials/02_first_model/models_and_migrations.md
      - Django Admin: tutorials/02_first_model/django_admin.md
      - ModelForm і CRUD: tutorials/02_first_model/modelform_and_crud.md
      - Контрольна точка: tutorials/02_first_model/checkpoint.md
    - "Крок 3. CRUD і архітектура":
      - Огляд: tutorials/03_crud_and_architecture/index.md
      - Проєктування домену: tutorials/03_crud_and_architecture/domain_design.md
      - ER-діаграми: tutorials/03_crud_and_architecture/er_diagrams.md
      - Моделі: tutorials/03_crud_and_architecture/models.md
      - Міграції та PostgreSQL: tutorials/03_crud_and_architecture/migrations.md
      - Services і Selectors: tutorials/03_crud_and_architecture/services_and_selectors.md
      - QuerySet поглиблено: tutorials/03_crud_and_architecture/queryset_deep.md
      - PostgreSQL: tutorials/03_crud_and_architecture/postgresql.md
      - "FBV → CBV": tutorials/03_crud_and_architecture/cbv.md
      - Контрольна точка: tutorials/03_crud_and_architecture/checkpoint.md
    - "Крок 4. Templates і Forms":
      - Огляд: tutorials/04_templates_and_forms/index.md
      - Template Inheritance: tutorials/04_templates_and_forms/template_inheritance.md
      - "Forms: Tier 1 → 3": tutorials/04_templates_and_forms/forms_evolution.md
      - Crispy Forms: tutorials/04_templates_and_forms/crispy_forms.md
      - Dashboard Architecture: tutorials/04_templates_and_forms/dashboard_architecture.md
      - Context Processor: tutorials/04_templates_and_forms/context_processor.md
      - Components: tutorials/04_templates_and_forms/components.md
      - Bootstrap Advanced: tutorials/04_templates_and_forms/bootstrap_advanced.md
      - Контрольна точка: tutorials/04_templates_and_forms/checkpoint.md
    - "Крок 5. Auth і безпека":
      - Огляд: tutorials/05_auth_and_security/index.md
      - Основи Auth: tutorials/05_auth_and_security/auth_basics.md
      - Password Security: tutorials/05_auth_and_security/password_security.md
      - Object Permissions: tutorials/05_auth_and_security/object_permissions.md
      - Group Sharing: tutorials/05_auth_and_security/group_sharing.md
      - Security Settings: tutorials/05_auth_and_security/security_settings.md
      - "notes_chat_app: Auth": tutorials/05_auth_and_security/notes_chat_app_auth.md
      - Контрольна точка: tutorials/05_auth_and_security/checkpoint.md
    - "Крок 6. Тестування":
      - Огляд: tutorials/06_testing/index.md
      - Навіщо тести: tutorials/06_testing/why_tests.md
      - test_models.py: tutorials/06_testing/test_models.md
      - test_services.py: tutorials/06_testing/test_services.md
      - test_forms.py: tutorials/06_testing/test_forms.md
      - test_views.py: tutorials/06_testing/test_views.md
      - test_consumers.py: tutorials/06_testing/test_consumers.md
      - test_selenium.py: tutorials/06_testing/test_selenium.md
      - GitHub Actions CI: tutorials/06_testing/ci_github_actions.md
      - Контрольна точка: tutorials/06_testing/checkpoint.md
    - "Крок 7. Async Django":
      - Огляд: tutorials/07_async_django/index.md
      - "7A: Sync vs Async": tutorials/07_async_django/7a_sync_vs_async.md
      - "7A: Async Views": tutorials/07_async_django/7a_async_views.md
      - "7A: Benchmark": tutorials/07_async_django/7a_benchmark.md
      - "7B: WebSocket Protocol": tutorials/07_async_django/7b_websocket_protocol.md
      - "7B: ASGI Stack": tutorials/07_async_django/7b_asgi_stack.md
      - "7B: Channel Layer": tutorials/07_async_django/7b_channels_settings.md
      - "7B: Consumer": tutorials/07_async_django/7b_consumer.md
      - "7B: JS Client": tutorials/07_async_django/7b_websocket_client.md
      - Контрольна точка: tutorials/07_async_django/checkpoint.md
    - "Крок 8. Background Tasks":
      - Огляд: tutorials/08_background_tasks/index.md
      - Архітектура Celery: tutorials/08_background_tasks/celery_architecture.md
      - Реалізація: tutorials/08_background_tasks/implementation.md
      - Browser Notifications: tutorials/08_background_tasks/browser_notifications.md
      - Тестування: tutorials/08_background_tasks/testing.md
      - Контрольна точка: tutorials/08_background_tasks/checkpoint.md
    - "Крок 9. Deployment":
      - Огляд: tutorials/09_deployment/index.md
      - Docker Compose: tutorials/09_deployment/docker_compose.md
      - PostgreSQL: tutorials/09_deployment/postgresql.md
      - Redis: tutorials/09_deployment/redis.md
      - Nginx: tutorials/09_deployment/nginx.md
      - Ngrok: tutorials/09_deployment/ngrok.md
      - Entrypoint: tutorials/09_deployment/entrypoint.md
      - Selenium у Docker: tutorials/09_deployment/selenium_docker.md
      - Seed Data: tutorials/09_deployment/seed_data.md
      - Локальна розробка: tutorials/09_deployment/development_workflow.md
      - Production Checklist: tutorials/09_deployment/production_checklist.md
      - Контрольна точка: tutorials/09_deployment/checkpoint.md

  - Notes Chat App:
    - Огляд проєкту: 12_final_project/README.md
    - Project Overview: 12_final_project/project_overview.md
    - Архітектура: 12_final_project/architecture.md
    - Domain Model: 12_final_project/domain_model.md
    - Feature Map: 12_final_project/feature_map.md
    - Request Flows: 12_final_project/request_flows.md
    - Async та Chat: 12_final_project/async_and_chat.md
    - Security Model: 12_final_project/security_model.md
    - Налаштування: 12_final_project/setup.md
    - Тестування: 12_final_project/testing_strategy.md
    - Деплоймент: 12_final_project/deployment.md
    - ORM Architecture Board: 12_final_project/orm_architecture_board.md
    - Завдання студентів: 12_final_project/student_tasks.md

  - Практика:
    - Огляд: labs/README.md
    - ORM Lab: labs/orm_lab.md
    - Forms Lab: labs/forms_lab.md
    - Testing Lab: labs/testing_lab.md
    - Async Lab: labs/async_lab.md

  - Довідник:
    - Огляд: reference/README.md
    - Команди: reference/commands.md
    - ORM Cheatsheet: reference/orm_cheatsheet.md
    - Testing Cheatsheet: reference/testing_cheatsheet.md
    - Git Cheatsheet: reference/git_cheatsheet.md
    - Deployment Cheatsheet: reference/deployment_cheatsheet.md
    - Settings Reference: reference/settings_reference.md
    - Deployment Checklist: 11_deployment/deployment_checklist.md
    - Архітектура: ARCHITECTURE.md
    - Глосарій: GLOSSARY.md
    - Troubleshooting: TROUBLESHOOTING.md

  - Викладачу:
    - Teaching Guide: TEACHING_GUIDE.md
    - Learning Path: LEARNING_PATH.md
```

---

## Зміни відносно поточної навігації

### Додано

- Top-level "Як користуватися" (виокремлено з "Книга")
- Top-level "Zero to Hero" (замість "Практика → Туторіали")
- Крок 3 → CBV субсторінка (README_4.md — раніше не виокремлений)
- `11_deployment/deployment_checklist.md` перенесений до "Довідник"

### Прибрано з nav (залишаються у файловій системі)

- `docs/_internal/` — ніколи не в nav
- `reference/legacy_indexes/` — прибрати з nav (зберегти файли)
- `reference/legacy_source/` — прибрати з nav (зберегти файли)
- Короткі summary файли (knowledge XX short) — залишаються у файловій системі, виключені з nav (доступні через пряме посилання)
- Дублюючі секції, де canonical замінює short

### Структурні зміни

- "Книга" → розбита на 10 явних Частин (не одна довга група)
- "Практика" → тільки Labs (туторіали переведені до "Zero to Hero")
- Порядок Довідника розширений (checklist)

---

## Перевірки перед застосуванням (Batch L)

```text
[ ] mkdocs build --strict проходить без помилок
[ ] Всі шляхи у nav ведуть до реально існуючих файлів
[ ] Жоден docs/_internal/ файл не потрапив у nav
[ ] Жоден legacy_indexes файл не у nav
[ ] Глибина меню ≤ 3 рівні
[ ] MkDocs Material navigation.tabs відповідає top-level секціям
[ ] Мобільна навігація перевірена у браузері
[ ] Всі internal links між главами оновлені
```
