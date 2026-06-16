# Content Migration Plan — README_1–9 → Directory Structure

Оновлено: 2026-06-15
Попередня версія: 2026-06-14 (загальний план без README_N mapping)

## Мета

Section-level міграція README_1–9 + 01-09 tutorial files у directory-based модулі.
Кожен розділ README_N отримує canonical destination у новій структурі.

Правила:
- `→ NEW FILE` — контент іде у новий файл (ще не існує)
- `→ EXISTING FILE` — розширення вже існуючого файлу
- `✅ Migrated` — перенесено і верифіковано
- `⏳ Pending` — заплановано, ще не виконано

---

## README_1.md (1542 рядки, hello_project)

| README_1 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| Що ти отримаєш, Кінцева структура | `01_hello_django/index.md` | ⏳ |
| Покрокові інструкції (Крок 1-15) | `01_hello_django/environment.md` + `urls_and_views.md` | ⏳ |
| Адмін-панель Django — повне пояснення | `01_hello_django/admin.md` | ⏳ |
| Підсумок, команди, зміни у файлах | `01_hello_django/checkpoint.md` | ⏳ |
| Часті помилки початківців | `01_hello_django/checkpoint.md` | ⏳ |
| Бонус: перша модель | `01_hello_django/admin.md` | ⏳ |
| Бонус 2: виводимо нотатки | `01_hello_django/templates.md` | ⏳ |
| Бонус 3: Django Debug Toolbar | `04_templates_and_forms/bootstrap_advanced.md` | ⏳ |

**01_first_django_page.md розподіл:**
| Section | Canonical Destination |
|---------|----------------------|
| §01-04 (Request cycle, Structure, manage.py, settings.py) | `01_hello_django/project_structure.md` |
| §05 URL Patterns + Кроки 7-8 | `01_hello_django/urls_and_views.md` |
| Кроки 1-6 (venv, Django, project, migrate, superuser, app) | `01_hello_django/environment.md` |
| Крок 9, Бонус — Перша модель | `01_hello_django/admin.md` |
| Часті помилки, Чеклист, Далі | `01_hello_django/checkpoint.md` |

---

## README_2.md (1409 рядків, bootstrap_notes)

**Важливо:** Фаза А + основний CRUD → Крок 2. Фаза Б-З (Bootstrap/UI) → Крок 4.

| README_2 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| Навчальна карта (таблиця A-И) | `02_first_model/index.md` | ⏳ |
| Що ти отримаєш, Кінцева структура | `02_first_model/index.md` | ⏳ |
| Фаза А — Розуміємо наявний код | `02_first_model/models_and_migrations.md` | ⏳ |
| Крок 8 — Перевір міграції | `02_first_model/models_and_migrations.md` | ⏳ |
| Крок 9 — Запусти і перевір | `02_first_model/checkpoint.md` | ⏳ |
| Підсумок, Часті помилки | `02_first_model/checkpoint.md` | ⏳ |
| Фаза Б — Bootstrap CDN | `04_templates_and_forms/bootstrap_advanced.md` | ⏳ |
| Фаза В — base.html | `04_templates_and_forms/template_inheritance.md` | ⏳ |
| Фаза Г — Список нотаток з Cards | `04_templates_and_forms/bootstrap_advanced.md` | ⏳ |
| Фаза Д — Форма нотатки | `04_templates_and_forms/forms_evolution.md` | ⏳ |
| Фаза Е — Шаблони деталей, форми, видалення | `02_first_model/modelform_and_crud.md` | ⏳ |
| Фаза Ж — Unfold Admin | `04_templates_and_forms/bootstrap_advanced.md` | ⏳ |
| Фаза З — Django Debug Toolbar | `04_templates_and_forms/bootstrap_advanced.md` | ⏳ |

**02_first_model.md розподіл:**
| Section | Canonical Destination |
|---------|----------------------|
| §01 ModelForm, §02 PRG, §03 Messages | `02_first_model/modelform_and_crud.md` |
| §04 Template Inheritance | `04_templates_and_forms/template_inheritance.md` |
| §05 Bootstrap 5 | `04_templates_and_forms/bootstrap_advanced.md` |
| §06 Template Filters і Tags | `04_templates_and_forms/template_inheritance.md` |
| Кроки 1-9 (CRUD, urls, templates) | `02_first_model/modelform_and_crud.md` |
| Чеклист, Далі | `02_first_model/checkpoint.md` |

---

## README_3.md (2387 рядків, notes_project)

| README_3 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| §01 DOMAIN → SCHEMA | `03_crud_and_architecture/domain_design.md` | ⏳ |
| §02 RELATIONSHIP TYPES | `03_crud_and_architecture/er_diagrams.md` | ⏳ |
| §03 APPLICATION LAYERS | `03_crud_and_architecture/services_and_selectors.md` | ⏳ |
| §04 NORMALIZATION | `03_crud_and_architecture/er_diagrams.md` | ⏳ |
| §05 MIGRATIONS | `03_crud_and_architecture/migrations.md` | ⏳ |
| Крок 0-2 (Домен, Сутності, Зв'язки) | `03_crud_and_architecture/domain_design.md` | ⏳ |
| Крок 3 ER-діаграми | `03_crud_and_architecture/er_diagrams.md` | ⏳ |
| Крок 4 Django Моделі | `03_crud_and_architecture/models.md` | ⏳ |
| Крок 5-6 Міграції, SQLite | `03_crud_and_architecture/migrations.md` | ⏳ |
| Крок 7-8.5 Services, Selectors, Views | `03_crud_and_architecture/services_and_selectors.md` | ⏳ |
| Крок 9 QuerySets | `03_crud_and_architecture/queryset_deep.md` | ⏳ |
| Крок 10 PostgreSQL | `03_crud_and_architecture/postgresql.md` | ⏳ |

**03_crud.md розподіл:**
| Section | Canonical Destination |
|---------|----------------------|
| §01 DOMAIN→SCHEMA, §02 Relationships, §03 on_delete | `03_crud_and_architecture/domain_design.md` / `er_diagrams.md` |
| §04 Django ORM, §05 N+1, §06 transaction.atomic | `03_crud_and_architecture/queryset_deep.md` |
| §07 Application Layers | `03_crud_and_architecture/services_and_selectors.md` |
| Кроки 0-9 | відповідні глави вище |
| Чеклист, Далі | `03_crud_and_architecture/checkpoint.md` |

---

## README_4.md (1506 рядків, notes_project_cbv)

Повністю → `03_crud_and_architecture/cbv.md` (окрема CBV глава)

| README_4 Section | Status |
|-----------------|--------|
| Що таке CBV і навіщо | ⏳ |
| Кроки 1-12 (as_view, Generic Views, Mixins, MRO, CRUD, Services, urls) | ⏳ |
| FBV → CBV порівняння | ⏳ |
| Bootstrap форми у шаблонах | ⏳ |

---

## README_5.md (1415 рядків, crispy_notes)

| README_5 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| §01 TEMPLATE SOUP | `04_templates_and_forms/template_inheritance.md` | ⏳ |
| §02 TEMPLATE INHERITANCE | `04_templates_and_forms/template_inheritance.md` | ⏳ |
| §03 FORMS EVOLUTION (Tier 1→2→3) | `04_templates_and_forms/forms_evolution.md` | ⏳ |
| §04 FORMHELPER + LAYOUT | `04_templates_and_forms/crispy_forms.md` | ⏳ |
| §05 DASHBOARD ARCHITECTURE | `04_templates_and_forms/dashboard_architecture.md` | ⏳ |
| Крок 0 — Запуск | `04_templates_and_forms/index.md` | ⏳ |
| Крок 1 — Settings | `04_templates_and_forms/crispy_forms.md` | ⏳ |
| Крок 2 — base.html | `04_templates_and_forms/template_inheritance.md` | ⏳ |
| Крок 3-4 — layouts/dashboard + Сторінки | `04_templates_and_forms/dashboard_architecture.md` | ⏳ |
| Крок 5-7 — Tier 1, 2, 3 | `04_templates_and_forms/forms_evolution.md` | ⏳ |
| Крок 8 — Context Processor | `04_templates_and_forms/context_processor.md` | ⏳ |
| Крок 9 — Components | `04_templates_and_forms/components.md` | ⏳ |

---

## README_6.md (1510 рядків, crispy_notes_project)

Педагогічний попередник. У кожній главі явна позначка: "Навчальний проєкт: crispy_notes_project".

| README_6 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| §01 AUTH BASICS | `05_auth_and_security/auth_basics.md` | ⏳ |
| §02 SESSIONS | `05_auth_and_security/auth_basics.md` | ⏳ |
| §03 PASSWORD SECURITY | `05_auth_and_security/password_security.md` | ⏳ |
| §04 OBJECT-LEVEL PERMISSIONS | `05_auth_and_security/object_permissions.md` | ⏳ |
| §05 GROUP SHARING | `05_auth_and_security/group_sharing.md` | ⏳ |
| §06 SECURITY SETTINGS | `05_auth_and_security/security_settings.md` | ⏳ |
| Крок 0-2 | `05_auth_and_security/index.md` | ⏳ |
| Крок 3-5 (Login, Reset, Change) | `05_auth_and_security/password_security.md` | ⏳ |
| Крок 6 (Object-Level) | `05_auth_and_security/object_permissions.md` | ⏳ |
| Крок 7-11 (Group FK, Selectors, Services, Views, Templates) | `05_auth_and_security/group_sharing.md` | ⏳ |

**05_authentication.md розподіл:**
| Section | Canonical Destination |
|---------|----------------------|
| §01-06 (теорія) | відповідні глави вище |
| Кроки 0-11 (Docker-specific, Group sharing у notes_chat_app) | `05_auth_and_security/notes_chat_app_auth.md` |
| Перевірка у браузері, Чеклист, Далі | `05_auth_and_security/checkpoint.md` |

---

## README_7.md (2011 рядків, crispy_notes_project)

| README_7 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| §01 НАВІЩО ТЕСТИ | `06_testing/why_tests.md` | ⏳ |
| §02 ПІРАМІДА ТЕСТУВАННЯ | `06_testing/why_tests.md` | ⏳ |
| §03 DJANGO TESTCASE | `06_testing/why_tests.md` | ⏳ |
| §04 ТЕСТОВА БД | `06_testing/why_tests.md` | ⏳ |
| §05 AAA ПАТТЕРН | `06_testing/why_tests.md` | ⏳ |
| §06 ЧИТАННЯ ВИВОДУ | `06_testing/why_tests.md` | ⏳ |
| §07 ТЕСТУВАННЯ МОДЕЛЕЙ | `06_testing/test_models.md` | ⏳ |
| §08 ТЕСТУВАННЯ СЕРВІСІВ | `06_testing/test_services.md` | ⏳ |
| §09 ТЕСТУВАННЯ ФОРМ | `06_testing/test_forms.md` | ⏳ |
| §10 DJANGO TEST CLIENT | `06_testing/test_views.md` | ⏳ |
| §11 SELENIUM | `06_testing/test_selenium.md` | ⏳ |
| Крок 0-7 | відповідні глави вище | ⏳ |
| Крок 8 — GitHub Actions CI | `06_testing/ci_github_actions.md` | ⏳ |

**06_testing.md специфічне:**
| Section | Canonical Destination |
|---------|----------------------|
| §11 CONSUMERS | `06_testing/test_consumers.md` (унікально notes_chat_app) |
| §12 SELENIUM | `06_testing/test_selenium.md` (розширює README_7) |

---

## README_8.md (1497 рядків, hello_app — sync vs async)

Основа 7A. НЕ зливати з WebSocket-матеріалом (07_async.md = 7B).

| README_8 Section | Canonical Destination | Status |
|-----------------|----------------------|--------|
| §00-02 (Про проєкт, Що вивчиш, Архітектура) | `07_async_django/index.md` | ⏳ |
| §03-05 (Sync, Async, Коли async) | `07_async_django/7a_sync_vs_async.md` | ⏳ |
| §06-07 (runserver vs Uvicorn) | `07_async_django/7a_sync_vs_async.md` | ⏳ |
| §08 Таблиця порівняння URL | `07_async_django/7a_sync_vs_async.md` | ⏳ |
| §09-11 (async_selectors, services, views) | `07_async_django/7a_async_views.md` | ⏳ |
| §12 Тести sync vs async | `07_async_django/7a_async_views.md` | ⏳ |
| §13-14 (Postman, Benchmark) | `07_async_django/7a_benchmark.md` | ⏳ |
| §15-16 (Помилки, Завдання) | `07_async_django/checkpoint.md` | ⏳ |
| §18 Real-time чат (bridge до 7B) | `07_async_django/index.md` | ⏳ |
| §19 Docker | `07_async_django/7a_sync_vs_async.md` | ⏳ |

**07_async.md розподіл (7B):**
| Section | Canonical Destination |
|---------|----------------------|
| Чому HTTP не підходить | `07_async_django/7b_websocket_protocol.md` |
| WebSocket, asyncio | `07_async_django/7b_websocket_protocol.md` |
| Архітектура ASGI, asgi.py, routing.py | `07_async_django/7b_asgi_stack.md` |
| settings.py, Channel Layers | `07_async_django/7b_channels_settings.md` |
| Consumer lifecycle, database_sync_to_async | `07_async_django/7b_consumer.md` |
| WebSocket JS, XSS | `07_async_django/7b_websocket_client.md` |
| Тестування consumers, Чеклист | `07_async_django/checkpoint.md` |

---

## README_9.md (1934 рядки, notes_chat_app)

**Критично:** Не видаляти до підтвердження Lost: 0 для §08-10.

| README_9 Section | Canonical Destination | Верифікація | Status |
|-----------------|----------------------|------------|--------|
| §01 ОГЛЯД | `09_deployment/index.md` | — | ⏳ |
| §02 DOCKER COMPOSE | `09_deployment/docker_compose.md` | — | ⏳ |
| §03 POSTGRESQL | `09_deployment/postgresql.md` | — | ⏳ |
| §04 REDIS + CHANNELS | `09_deployment/redis.md` | — | ⏳ |
| §05 NGINX | `09_deployment/nginx.md` | — | ⏳ |
| §06 NGROK | `09_deployment/ngrok.md` | — | ⏳ |
| §07 ENTRYPOINT | `09_deployment/entrypoint.md` | — | ⏳ |
| §08 MODELS | `12_final_project/domain_model.md` | Читати обидва, порівняти | ⏳ |
| §09 SERVICES + SELECTORS | `12_final_project/architecture.md` | Читати обидва, порівняти | ⏳ |
| §10 CONSUMERS | `12_final_project/async_and_chat.md` | Читати обидва, порівняти | ⏳ |
| §11 ТЕСТОВА СТРАТЕГІЯ | `12_final_project/testing_strategy.md` | Читати обидва, порівняти | ⏳ |
| §12 SELENIUM У DOCKER | `09_deployment/selenium_docker.md` | — | ⏳ |
| §13 SEED DATA | `09_deployment/seed_data.md` | — | ⏳ |
| §14 РОЗРОБКА | `09_deployment/development_workflow.md` | Унікальне — перенести повністю | ⏳ |
| §15 PRODUCTION CHECKLIST | `09_deployment/production_checklist.md` | — | ⏳ |

---

## Порядок виконання

### Фаза 1 — Планування (ВИКОНАНО)
- [x] ZERO_TO_HERO_PLAN.md оновлено
- [x] CONTENT_MIGRATION_PLAN.md створено
- [ ] MKDOCS_NAVIGATION_PLAN.md оновлено

### Фаза 2 — Пілотний Крок 1
- [ ] Створити `docs/tutorials/01_hello_django/` (7 файлів)
- [ ] Контент з README_1 + 01_first_django_page.md → глави
- [ ] Перевірка mkdocs build --strict
- [ ] Оновити MKDOCS_NAVIGATION_PLAN.md фактичним результатом

### Фаза 3 — Кроки 2-9
- [ ] По одному кроку, після кожного → mkdocs build --strict
- [ ] Оновлювати таблицю ✅/⏳ вище

### Фаза 4 — Архівування
- [ ] Після повної міграції → перемістити README_1-9 до `archive/`
- [ ] Прибрати з student nav

---

## Прогрес

| Статус | К-сть секцій |
|--------|-------------|
| ✅ Migrated | 0 |
| ⏳ Pending | ~120 |
| Lost | 0 (очікується) |
