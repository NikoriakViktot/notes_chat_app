# Zero to Hero Plan — Directory-Based Structure

Оновлено: 2026-06-15 | Попередня версія: 2026-06-14 (два-файлова "tutorial + Детально")

## Мета реструктуризації

Замінити модель "коротке 0N_*.md + окремий README_N.md як «Детально»" на
модульну book-like структуру: кожен крок → каталог → послідовні глави.

**Заборонено:**
- "tutorial + Детально" паттерн у навігації
- Гігантські файли (3000+ рядків)
- README_N під технічними назвами у студентській навігації
- Видалення унікального контенту

---

## Проєкти-попередники (педагогічна еволюція)

```text
hello_project        ← Крок 1 (standalone, SQLite, без моделей)
bootstrap_notes      ← Крок 2 (standalone, перша модель + Bootstrap)
notes_project        ← Крок 3 (CRUD, selectors/services, PostgreSQL)
notes_project_cbv    ← Крок 3 альтернатива (CBV замість FBV)
crispy_notes         ← Крок 4 (Crispy Forms, SaaS dashboard)
crispy_notes_project ← Кроки 5-6 (Auth, Testing — попередник notes_chat_app)
hello_app            ← Крок 7A (sync vs async comparison)
notes_chat_app       ← Кроки 5-9 (production: PostgreSQL, Redis, WS, Docker)
```

Standalone-проєкти є **навчальними застосунками** — не гілками notes_chat_app.
Їхнє явне позначення обов'язкове у кожному кроці.

---

## Цільова структура каталогів

```text
docs/tutorials/
├── README.md                         ← маршрутний огляд (оновити)
├── 00_environment/
│   └── index.md
├── 01_hello_django/
│   ├── index.md
│   ├── environment.md
│   ├── project_structure.md
│   ├── urls_and_views.md
│   ├── templates.md
│   ├── admin.md
│   └── checkpoint.md
├── 02_first_model/
│   ├── index.md
│   ├── models_and_migrations.md
│   ├── django_admin.md
│   ├── modelform_and_crud.md
│   └── checkpoint.md
├── 03_crud_and_architecture/
│   ├── index.md
│   ├── domain_design.md
│   ├── er_diagrams.md
│   ├── models.md
│   ├── migrations.md
│   ├── services_and_selectors.md
│   ├── queryset_deep.md
│   ├── postgresql.md
│   ├── cbv.md                        ← з README_4
│   └── checkpoint.md
├── 04_templates_and_forms/
│   ├── index.md
│   ├── template_inheritance.md
│   ├── forms_evolution.md            ← Tier 1→2→3 з README_5
│   ├── crispy_forms.md
│   ├── dashboard_architecture.md
│   ├── context_processor.md
│   ├── components.md
│   ├── bootstrap_advanced.md         ← Modal, Debug Toolbar, Unfold Admin
│   └── checkpoint.md
├── 05_auth_and_security/
│   ├── index.md
│   ├── auth_basics.md
│   ├── password_security.md
│   ├── object_permissions.md
│   ├── group_sharing.md
│   ├── security_settings.md
│   ├── notes_chat_app_auth.md        ← Docker-specific, Group sharing в notes_chat_app
│   └── checkpoint.md
├── 06_testing/
│   ├── index.md
│   ├── why_tests.md
│   ├── test_models.md
│   ├── test_services.md
│   ├── test_forms.md
│   ├── test_views.md
│   ├── test_consumers.md             ← унікально для notes_chat_app
│   ├── test_selenium.md
│   ├── ci_github_actions.md
│   └── checkpoint.md
├── 07_async_django/
│   ├── index.md
│   ├── 7a_sync_vs_async.md           ← README_8: hello_app порівняння
│   ├── 7a_async_views.md             ← README_8: async_selectors/services/views
│   ├── 7a_benchmark.md               ← README_8: benchmarking
│   ├── 7b_websocket_protocol.md      ← 07_async.md
│   ├── 7b_asgi_stack.md
│   ├── 7b_channels_settings.md
│   ├── 7b_consumer.md
│   ├── 7b_websocket_client.md
│   └── checkpoint.md
├── 08_background_tasks/
│   ├── index.md
│   ├── celery_architecture.md
│   ├── implementation.md
│   ├── browser_notifications.md
│   ├── testing.md
│   └── checkpoint.md
└── 09_deployment/
    ├── index.md
    ├── docker_compose.md
    ├── postgresql.md
    ├── redis.md
    ├── nginx.md
    ├── ngrok.md
    ├── entrypoint.md
    ├── selenium_docker.md
    ├── seed_data.md
    ├── development_workflow.md       ← README_9 §14 (унікальне)
    ├── production_checklist.md
    └── checkpoint.md
```

---

## Детальний план глав по кроках

### Крок 1: Hello Django
**Джерела:** `README_1.md` (1542 рядки) + `01_first_django_page.md` (1087 рядків)

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | Що будуємо, проєкт hello_project, структура модуля |
| environment.md | Крок 1-3 обидва | venv, pip, startproject |
| project_structure.md | §02-04 з 01_* | manage.py, settings.py, MTV, request/response cycle |
| urls_and_views.md | §05 + Крок 7-8 обидва | URL patterns, view functions, HttpResponse |
| templates.md | README_1 Крок + 01_* | перші шаблони |
| admin.md | README_1 §Admin | Адмін-панель: детальне пояснення, SQLite, Бонуси 1-3 |
| checkpoint.md | обидва | Чеклист, типові помилки, практичне завдання |

### Крок 2: Перша модель
**Джерела:** `README_2.md` (1409 рядків) + `02_first_model.md` (1348 рядків)
**Розподіл:** Моделі/міграції/Admin → Крок 2; Bootstrap/UI/Modal → Крок 4

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | bootstrap_notes, що вивчаємо |
| models_and_migrations.md | §01 ModelForm + Крок 1-2 | models.Model, makemigrations, migrate |
| django_admin.md | README_2 Фаза А | Admin реєстрація, __str__, customize |
| modelform_and_crud.md | §02-06 + Крок 3-9 | ModelForm, PRG pattern, Messages, CRUD views, templates |
| checkpoint.md | обидва | Чеклист, типові помилки |

**Примітка:** Фаза Б-Е (Bootstrap, Modal, Debug Toolbar, Unfold) → переходять у Крок 4.

### Крок 3: CRUD і архітектура
**Джерела:** `README_3.md` (2387 рядків) + `03_crud.md` (1318 рядків) + `README_4.md` (1506 рядків, CBV)

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | notes_project, мета кроку |
| domain_design.md | §01 + Крок 0-1 обидва | DOMAIN→SCHEMA, 7-крокова методологія |
| er_diagrams.md | README_3 Крок 3 | ER-діаграми, нормалізація, всі 11 таблиць |
| models.md | §04 + Крок 4 обидва | Django моделі, on_delete, choices |
| migrations.md | §05 + Крок 5-6 | makemigrations, migrate, SQLite запуск |
| services_and_selectors.md | §03 + Крок 7-8 обидва | selectors.py, services.py, тонкий view |
| queryset_deep.md | §04-06 + Крок 9 | N+1, transaction.atomic, select_related, orm_laboratory |
| postgresql.md | README_3 Крок 10 | SQLite→PostgreSQL, налаштування DATABASE_URL |
| cbv.md | README_4 (повністю) | as_view, dispatch, Generic Views, Mixins, MRO, FBV vs CBV |
| checkpoint.md | обидва | Чеклист, практичне завдання |

### Крок 4: Templates і Forms
**Джерела:** `README_5.md` (1415 рядків) + `04_templates_bootstrap.md` (1115 рядків) + унікальний контент README_2 (Bootstrap/UI)

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | crispy_notes, SaaS dashboard |
| template_inheritance.md | §01-02 обидва | Template Soup, 3-рівнева ієрархія |
| forms_evolution.md | README_5 §03 | Tier 1 raw → Tier 2 manual → Tier 3 crispy |
| crispy_forms.md | §04 + §03 з 04_* | FormHelper, Layout, Field, Row, Column |
| dashboard_architecture.md | README_5 §05 | SaaS dashboard, layouts/, Context processor sidebar |
| context_processor.md | §04 з 04_* + Крок 8 обидва | Context processor, active nav state |
| components.md | README_5 Крок 9 | Pagination, empty_state, modal components |
| bootstrap_advanced.md | README_2 Фаза Б-З | Bootstrap Cards, Modal видалення, Unfold Admin, Debug Toolbar |
| checkpoint.md | обидва | Чеклист, практичне завдання |

### Крок 5: Auth і безпека
**Джерела:** `README_6.md` (1510 рядків, crispy_notes_project) + `05_authentication.md` (2083 рядки, notes_chat_app)

| Глава | Джерела | Примітка |
|-------|---------|----------|
| index.md | обидва | Явна позначка: crispy_notes_project → notes_chat_app |
| auth_basics.md | §01-02 обидва | AuthN/AuthZ, sessions, login/logout |
| password_security.md | §03 + Крок 3-5 обидва | Password Reset, Password Change |
| object_permissions.md | §04 + Крок 6 обидва | IDOR, object-level permissions |
| group_sharing.md | §05 + Крок 7-11 обидва | Group FK, Q(user=user)\|Q(group__in=...), views, templates |
| security_settings.md | §06 обидва | Security headers, DEBUG=False |
| notes_chat_app_auth.md | 05_authentication.md специфічне | Docker, Group sharing у notes_chat_app, UserProfile |
| checkpoint.md | обидва | IDOR test, чеклист |

### Крок 6: Тестування
**Джерела:** `README_7.md` (2011 рядків, crispy_notes_project) + `06_testing.md` (1919 рядків, notes_chat_app)

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | Мета: не ламати при рефакторингу |
| why_tests.md | §01-06 обидва | Піраміда, TestCase, тестова БД, AAA, читання виводу |
| test_models.md | §07 обидва | Структура tests/, test_models.py |
| test_services.md | §08 обидва | test_services.py |
| test_forms.md | §09 обидва | test_forms.py |
| test_views.md | §10 + Крок 5 обидва | Django Test Client, force_login, test_views.py |
| test_consumers.md | §11 з 06_testing.md | **Унікально для notes_chat_app**: TransactionTestCase, WebsocketCommunicator |
| test_selenium.md | §11 README_7 + §12 06_testing | Selenium, Docker, StaticLiveServerTestCase |
| ci_github_actions.md | Крок 8 README_7 | GitHub Actions YAML, CI jobs |
| checkpoint.md | обидва | Запуск 221 тесту, чеклист |

### Крок 7: Async Django
**Джерела:** `README_8.md` (1497 рядків, hello_app) + `07_async.md` (1398 рядків, notes_chat_app)
**Структура:** 7A (sync vs async) | 7B (WebSocket chat)

| Глава | Джерела | Ключовий контент |
|-------|---------|-----------------|
| index.md | обидва | Дві частини: порівняння vs реалізація |
| 7a_sync_vs_async.md | README_8 §03-05 | Sync Django, async Django, коли async виправданий |
| 7a_async_views.md | README_8 §09-11 | async_selectors.py, async_services.py, async_views.py |
| 7a_benchmark.md | README_8 §14 | Benchmarking, що можна і не можна міряти |
| 7b_websocket_protocol.md | 07_async.md | HTTP vs WebSocket, asyncio |
| 7b_asgi_stack.md | 07_async.md | ProtocolTypeRouter, asgi.py, routing.py |
| 7b_channels_settings.md | 07_async.md | Daphne, Channel layers, Redis |
| 7b_consumer.md | 07_async.md | GroupChatConsumer, database_sync_to_async |
| 7b_websocket_client.md | 07_async.md | JS client, XSS захист |
| checkpoint.md | обидва | Consumer test, чеклист |

### Крок 8: Background Tasks
**Джерело:** `08_celery.md` (поточний файл — вже добре структурований)

Конвертувати у директорію, зміст зберегти без скорочень.

### Крок 9: Deployment
**Джерела:** `README_9.md` (1934 рядки, notes_chat_app) + `09_deployment.md` (1373 рядки)

| Глава | Джерела README_9 | Джерела 09_deployment | Ключовий контент |
|-------|-----------------|----------------------|-----------------|
| index.md | §01 ОГЛЯД | Загальна картина | Стек, порядок читання |
| docker_compose.md | §02 | docker-compose.yml | Сервіси, depends_on, health checks |
| postgresql.md | §03 | PostgreSQL | SQLite→PG, DATABASE_URL |
| redis.md | §04 | Redis | Channel layer, Redis DB 0 vs 1 |
| nginx.md | §05 | nginx.conf | Reverse proxy, WebSocket, static |
| ngrok.md | §06 | ngrok | NGROK_DOMAIN, CSRF |
| entrypoint.md | §07 | entrypoint.sh | Ланцюг запуску |
| selenium_docker.md | §12 | Selenium | E2E у Docker |
| seed_data.md | §13 | (згадка) | Seed demo data |
| development_workflow.md | §14 РОЗРОБКА | (відсутнє) | **Унікально з README_9** |
| production_checklist.md | §15 | Production checklist | DEBUG=False, SECRET_KEY... |
| checkpoint.md | — | Вітаємо! | Фінальний чеклист |

**README_9 §08-10 (Models, Services+Selectors, Consumers):**
→ Перевірити наявність цього контенту в `docs/12_final_project/` (domain_model.md, architecture.md, async_and_chat.md).
→ Якщо контент там відсутній — перенести. Після підтвердження `Lost: 0` — архівувати README_9.

---

## Статус навігації (до і після)

**Було (приклад Крок 3):**
```yaml
- "Крок 3 — CRUD":
    - Туторіал: tutorials/03_crud.md
    - Детально: tutorials/README_3.md
```

**Стане:**
```yaml
- "Крок 3. CRUD і архітектура":
    - Огляд: tutorials/03_crud_and_architecture/index.md
    - Проєктування домену: tutorials/03_crud_and_architecture/domain_design.md
    - ER-діаграми: tutorials/03_crud_and_architecture/er_diagrams.md
    - Моделі: tutorials/03_crud_and_architecture/models.md
    - Міграції: tutorials/03_crud_and_architecture/migrations.md
    - Services і Selectors: tutorials/03_crud_and_architecture/services_and_selectors.md
    - QuerySet поглиблено: tutorials/03_crud_and_architecture/queryset_deep.md
    - PostgreSQL: tutorials/03_crud_and_architecture/postgresql.md
    - FBV → CBV: tutorials/03_crud_and_architecture/cbv.md
    - Контрольна точка: tutorials/03_crud_and_architecture/checkpoint.md
```

---

## Прогрес конвертації

| Крок | Директорія | Статус |
|------|-----------|--------|
| Крок 1 | `01_hello_django/` | ✅ Готово |
| Крок 2 | `02_first_model/` | ✅ Готово |
| Крок 3 | `03_crud_and_architecture/` | ✅ Готово (2026-06-15) |
| Крок 4 | `04_templates_and_forms/` | ✅ Готово (2026-06-15) |
| Крок 5 | `05_auth_and_security/` | ✅ Готово (2026-06-15) |
| Крок 6 | `06_testing/` | ✅ Готово (2026-06-16) |
| Крок 7 | `07_async_django/` | ✅ Готово (2026-06-16) |
| Крок 8 | `08_background_tasks/` | ✅ Готово (2026-06-15) |
| Крок 9 | `09_deployment/` | ✅ Готово (2026-06-16) |

---

## Критерії завершення

- [x] README_4 має окремий CBV-підмодуль → `03_crud_and_architecture/cbv.md`
- [x] README_1–9 не відображаються студенту як «Детально» (всі 9 кроків конвертовано)
- [x] Немає двох конкуруючих пояснень одного кроку в навігації
- [x] Великі матеріали розбиті на глави, не скорочені
- [x] Standalone-проєкти явно позначені як педагогічні попередники
- [x] README_8 розділений на 7A (sync vs async) та 7B (WebSocket)
- [x] README_9 §14 перенесено до `09_deployment/development_workflow.md`
- [x] README_9 §08-10 перевірено vs 12_final_project/ — Lost: 0 (посилання замість дублювання)
- [x] `mkdocs build --strict` проходить
- [ ] Zero to Hero читається послідовно через Previous/Next (потребує перевірки навігаційних посилань)
- [ ] Commit і push не виконуються без явного запиту
