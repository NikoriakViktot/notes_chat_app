# Документація Notes Chat App

Це головна карта документації. Вона замінює старі розрізнені `INDEX_*.md` і веде студента єдиним маршрутом.

## Швидка навігація

| Потреба | Куди йти |
| --- | --- |
| Просто запустити проєкт | [Getting started](00_getting_started/README.md) |
| Пройти весь курс | [Learning path](LEARNING_PATH.md) |
| Зрозуміти архітектуру | [Architecture](ARCHITECTURE.md) |
| Працювати з фінальним кодом | [Final project](12_final_project/README.md) |
| Підготувати заняття | [Teaching guide](TEACHING_GUIDE.md) |
| Знайти команду | [Reference](reference/README.md) |
| Розібрати помилку | [Troubleshooting](TROUBLESHOOTING.md) |
| Знайти термін | [Glossary](GLOSSARY.md) |

## Мінімальний маршрут

1. [Local setup](00_getting_started/local_setup.md)
2. [Django request lifecycle](02_django_core/request_lifecycle.md)
3. [Models and migrations](03_database_and_orm/django_models.md)
4. [Forms and Crispy](04_forms_and_validation/django_forms_and_crispy.md)
5. [Services and selectors](06_application_architecture/services_selectors.md)
6. [Auth and permissions](07_auth_and_security/auth_sessions_permissions.md)
7. [Testing strategy](08_testing_and_quality/testing_strategy.md)
8. [Final project overview](12_final_project/project_overview.md)

## Повний маршрут

| Розділ | Тема |
| --- | --- |
| [00](00_getting_started/README.md) | старт, структура, локальний запуск |
| [01](01_web_foundations/README.md) | Internet, DNS, TCP, HTTP, browser/server |
| [02](02_django_core/README.md) | Django MVT, URLs, views, middleware, WSGI/ASGI |
| [03](03_database_and_orm/README.md) | relational DB, models, migrations, QuerySet, indexes |
| [04](04_forms_and_validation/README.md) | forms, ModelForms, validation, CSRF, PRG, Crispy |
| [05](05_frontend_and_templates/README.md) | HTML, CSS, Bootstrap, templates, static |
| [06](06_application_architecture/README.md) | thin views, services, selectors |
| [07](07_auth_and_security/README.md) | auth, sessions, permissions, IDOR, OWASP |
| [08](08_testing_and_quality/README.md) | unittest, pytest, Django TestCase, Selenium, CI |
| [09](09_async_and_realtime/README.md) | async, ASGI, Channels, WebSocket |
| [10](10_linux_and_devops/README.md) | Linux, shell, env, Docker |
| [11](11_deployment/README.md) | server, settings, DB, static, reverse proxy |
| [12](12_final_project/README.md) | актуальна документація фінального проєкту |

## Маршрут для викладача

Почніть з [Teaching guide](TEACHING_GUIDE.md), потім використовуйте modules `00`-`12` як основу для занять. Labs лежать у [labs](labs/README.md).

## Маршрут для студента

Йдіть за [Learning path](LEARNING_PATH.md). Після кожного великого розділу виконуйте мінімальне завдання і одне lab-завдання.

## Маршрут для запуску проєкту

1. [Local setup](00_getting_started/local_setup.md)
2. [Commands reference](reference/commands.md)
3. [Troubleshooting](TROUBLESHOOTING.md)

## Маршрут для deployment

1. [Environment variables](10_linux_and_devops/README.md)
2. [Docker and runtime](10_linux_and_devops/docker_and_runtime.md)
3. [Deployment checklist](11_deployment/deployment_checklist.md)
4. [Final project deployment](12_final_project/deployment.md)

## Архів

Старі плоскі docs збережено у `../archive/legacy_docs/docs_flat/`. Вони є історичними джерелами і можуть містити старі назви або шляхи.

<!-- restored-full-chapters:start -->

## Повна відновлена бібліотека

Нижче наведено повні глави, відновлені з `archive/legacy_docs/docs_flat/` у відповідні розділи `docs/`.
Короткі README залишаються навігацією, але не замінюють повні матеріали.

| Розділ | Повних глав | Директорія |
| --- | ---: | --- |
| 01 Web foundations | 2 | [docs/01_web_foundations](01_web_foundations/README.md) |
| 02 Django core | 6 | [docs/02_django_core](02_django_core/README.md) |
| 03 Database and ORM | 8 | [docs/03_database_and_orm](03_database_and_orm/README.md) |
| 04 Forms and validation | 2 | [docs/04_forms_and_validation](04_forms_and_validation/README.md) |
| 05 Frontend and templates | 10 | [docs/05_frontend_and_templates](05_frontend_and_templates/README.md) |
| 06 Application architecture | 6 | [docs/06_application_architecture](06_application_architecture/README.md) |
| 07 Auth and security | 9 | [docs/07_auth_and_security](07_auth_and_security/README.md) |
| 08 Testing and quality | 9 | [docs/08_testing_and_quality](08_testing_and_quality/README.md) |
| 09 Async and realtime | 9 | [docs/09_async_and_realtime](09_async_and_realtime/README.md) |
| 10 Linux and DevOps | 10 | [docs/10_linux_and_devops](10_linux_and_devops/README.md) |
| 11 Deployment | 8 | [docs/11_deployment](11_deployment/README.md) |
| Legacy course indexes | 7 | [docs/reference/legacy_indexes](reference/legacy_indexes/README.md) |
| Legacy source notes | 2 | [docs/reference/legacy_source](reference/legacy_source/README.md) |

<!-- restored-full-chapters:end -->
