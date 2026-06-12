# Docs Reorganization Plan

Цей план створено перед фактичною реорганізацією документації. Головне правило: поточний код репозиторію є джерелом істини, а старі Markdown-файли є навчальною сировиною.

## 1. Поточний стан

- Кореневий `README.md` зараз занадто великий для головної сторінки GitHub. Він більше схожий на книгу, ніж на entrypoint.
- `docs/` існує як плоска директорія з приблизно 48k рядків Markdown.
- `docs/README.md` зараз є уроком про testing, а не головною картою документації.
- Є багато `INDEX_*.md`, які конкурують між собою і не складаються в єдине дерево.
- Частина документів використовує старі навчальні назви, приклади або структури: `hello_app`, `hello_project`, `module_5`, старі lesson paths.
- Частина матеріалів пояснює теми, яких немає у фінальному коді як реалізованих feature: serializers, Celery/tasks, Kubernetes, Unfold admin.
- Поточний код має реальні компоненти: `notes_project`, `notes_app`, models, forms, selectors, services, function-based views, templates, tests, Channels consumer і WebSocket chat.
- Async HTTP demo не подається як активна feature: `notes_app/async_views.py`, `async_selectors.py`, `async_services.py` відсутні у working tree. Реальний async-компонент поточного коду - WebSocket chat через ASGI і Channels.
- Docker-файли присутні, але `docker-compose.yml`/`Dockerfile` посилаються на директорію `notes`, якої в корені немає.

## 2. Основні проблеми

1. Немає єдиного learning path.
2. Плоский `docs/` змішує theory, tutorial, reference, labs і project docs.
3. Дублюються теми: ORM, templates, services/selectors, security, testing, async, deployment.
4. Старі index-файли не мають єдиного маршруту.
5. Кореневий README перевантажений.
6. Старі приклади можуть суперечити поточному коду.
7. Немає окремої документації фінального проєкту.
8. Немає окремого guide для викладача.

## 3. Запропонована структура

```text
README.md
DOCS_REORGANIZATION_PLAN.md
docs/
  README.md
  LEARNING_PATH.md
  GLOSSARY.md
  TROUBLESHOOTING.md
  ARCHITECTURE.md
  TEACHING_GUIDE.md
  00_getting_started/
  01_web_foundations/
  02_django_core/
  03_database_and_orm/
  04_forms_and_validation/
  05_frontend_and_templates/
  06_application_architecture/
  07_auth_and_security/
  08_testing_and_quality/
  09_async_and_realtime/
  10_linux_and_devops/
  11_deployment/
  12_final_project/
  tutorials/
  labs/
  reference/
archive/
  legacy_docs/
    README.md
    docs_flat/
```

## 4. Рішення по документах

| Старий файл | Новий файл | Дія | Причина |
| --- | --- | --- | --- |
| `docs/01_linux_mental_model.md` | `docs/10_linux_and_devops/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/01_sync_vs_async.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/02_asyncio.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/02_terminal_and_shell.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/03_asgi.md` | `docs/09_async_and_realtime/channels_websocket.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/03_filesystem_navigation.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/04_django_async_views.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/04_files_permissions_users.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/05_async_orm.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/05_processes_ports_services.md` | `docs/06_application_architecture/services_selectors.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/06_package_managers_and_software.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/06_sync_to_async.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/07_async_http_clients.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/07_ssh_and_remote_server.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/08_benchmarking.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/08_environment_variables_and_secrets.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/09_async_use_cases.md` | `docs/09_async_and_realtime/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/09_bash_scripts.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/10_makefile_basics.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/11_deploy_django_on_linux.md` | `docs/10_linux_and_devops/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/12_nginx_gunicorn_uvicorn.md` | `docs/11_deployment/deployment_checklist.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/13_logs_monitoring_debugging.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/14_docker_basics.md` | `docs/10_linux_and_devops/docker_and_runtime.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/15_docker_compose.md` | `docs/10_linux_and_devops/docker_and_runtime.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/16_devops_workflow.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/17_kubernetes_overview.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/18_roadmap_next_steps.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/ADVANCED_TEMPLATES.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/AUTH_BASICS.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/BOOTSTRAP_5.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/CI_CD.md` | `docs/08_testing_and_quality/ci.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/CRISPY_FORMS.md` | `docs/04_forms_and_validation/django_forms_and_crispy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/CSS_BASICS.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DESIGN_FOUNDATIONS.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DESIGN_README.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_ADMIN.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/DJANGO_ADMIN_UNFOLD.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/DJANGO_COMMAND_SYSTEM.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/DJANGO_FORMS.md` | `docs/04_forms_and_validation/django_forms_and_crispy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_MIGRATIONS.md` | `docs/03_database_and_orm/migrations.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_NINJA_TEMPLATES.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_ORM_DEEP.md` | `docs/03_database_and_orm/django_models.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_PROJECT_STRUCTURE.md` | `docs/02_django_core/README.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_SECURITY_ARCHITECTURE.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_SELECTORS.md` | `docs/06_application_architecture/services_selectors.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_SERIALIZERS.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/DJANGO_SERVICES.md` | `docs/06_application_architecture/services_selectors.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_SERVICES_SELECTORS.md` | `docs/06_application_architecture/services_selectors.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_TASKS.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/DJANGO_TEMPLATES_BOOTSTRAP.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/DJANGO_TESTING.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/Django_ORM.md` | `docs/03_database_and_orm/django_models.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/Django_ORM_Architecture_Board.html` | `docs/03_database_and_orm/django_models.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/Django_Templates.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/Django_URL_Routing.md` | `docs/02_django_core/urls_and_views.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/Django_Views.md` | `docs/02_django_core/urls_and_views.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/HTML_BASICS.md` | `docs/05_frontend_and_templates/templates_bootstrap_static.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/INDEXING_DEEP.md` | `docs/03_database_and_orm/query_optimization.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/INDEX_1.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_2.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_3.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_4.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_5.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_7.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/INDEX_8.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/MOCKING_AND_PATCHING.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/ORM_MERMAID.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/OWASP_TOP_10.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/PERMISSIONS.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/POSTGRESQL_ADVANCED.md` | `docs/03_database_and_orm/transactions_indexes_postgresql.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/PYTEST_BASICS.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/README.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/RELATIONAL_DB_FOUNDATIONS.md` | `docs/03_database_and_orm/README.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/SECURITY_FOUNDATIONS.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/SECURITY_MISCONCEPTIONS.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/SELENIUM.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/SESSIONS_FLOW.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/SIEM.md` | `archive/legacy_docs/docs_flat/` | archive | flat legacy material; useful content is routed into canonical docs |
| `docs/TESTING_FOUNDATIONS.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/TESTING_PRACTICE_PROJECT.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/TEST_DATA_AND_FIXTURES.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/TRANSACTIONS_CONCURRENCY.md` | `docs/03_database_and_orm/transactions_indexes_postgresql.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/UNITTEST_BASICS.md` | `docs/08_testing_and_quality/testing_strategy.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/ZERO_TRUST.md` | `docs/07_auth_and_security/auth_sessions_permissions.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/django_architecture.md` | `docs/ARCHITECTURE.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/django_mermaid.md` | `docs/ARCHITECTURE.md` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/network_foundation.md` | `docs/01_web_foundations/` | merge | canonical topic document replaces duplicated lesson/index material |
| `docs/network_mermaid.md` | `docs/01_web_foundations/` | merge | canonical topic document replaces duplicated lesson/index material |

## 5. Які файли залишаються активними

- `README.md` - короткий entrypoint.
- `docs/README.md` - головна карта документації.
- `docs/LEARNING_PATH.md` - рекомендований порядок навчання.
- `docs/GLOSSARY.md` - терміни.
- `docs/TROUBLESHOOTING.md` - типові помилки.
- `docs/ARCHITECTURE.md` - наскрізні Mermaid-схеми.
- `docs/TEACHING_GUIDE.md` - маршрут для викладача.
- `docs/12_final_project/` - документація фактичного Django-проєкту.
- `docs/reference/` - короткі команди і cheatsheets.

## 6. Що об'єднується

- Network docs -> `docs/01_web_foundations/`.
- Django architecture, URL і view docs -> `docs/02_django_core/`.
- ORM, SQL, migrations, indexes, PostgreSQL -> `docs/03_database_and_orm/`.
- Forms і Crispy -> `docs/04_forms_and_validation/`.
- HTML, CSS, Bootstrap, templates, static -> `docs/05_frontend_and_templates/`.
- Services і selectors -> `docs/06_application_architecture/`.
- Auth, sessions, permissions, OWASP -> `docs/07_auth_and_security/`.
- unittest, pytest, Django TestCase, Selenium, CI -> `docs/08_testing_and_quality/`.
- Async, ASGI, sync_to_async, Channels, WebSocket -> `docs/09_async_and_realtime/`.
- Linux, shell, Docker, logs -> `docs/10_linux_and_devops/`.
- Nginx, Uvicorn, deployment checklist -> `docs/11_deployment/`.

## 7. Що архівується

Усі старі flat Markdown-файли з `docs/` переносяться до `archive/legacy_docs/docs_flat/`. Вони не видаляються. Активна документація посилається на архів лише як на історичне джерело.

## 8. Нові index-файли

- `docs/README.md`
- `docs/LEARNING_PATH.md`
- `docs/*/README.md`
- `docs/tutorials/README.md`
- `docs/labs/README.md`
- `docs/reference/README.md`
- `archive/legacy_docs/README.md`

## 9. Посилання, які потрібно оновити

- Кореневий README має вести до `docs/README.md`, а не містити всю книгу.
- Старі `INDEX_*.md` не залишаються активними.
- Посилання на `module_5/...`, `hello_app`, `hello_project` не використовуються в активній документації.
- Посилання на код даються як відносні шляхи у backticks, а не абсолютні локальні paths.

## 10. Контроль якості після змін

- Перевірити Markdown links власним checker-скриптом.
- Перевірити відсутність старих локальних шляхів в активних docs.
- Запустити `python3 manage.py check`.
- Якщо dependencies встановлені, запустити `python3 manage.py test`.
- Показати `git status --short --untracked-files=all`.
- Показати `git diff --stat`.
