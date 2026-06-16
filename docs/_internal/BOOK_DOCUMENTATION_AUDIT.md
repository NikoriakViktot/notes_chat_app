# Book Documentation Audit

Детальний аудит кожного Markdown-файлу в репозиторії.
Інспекція: 2026-06-14. Оновлено: 2026-06-15. Гілка: main.

Для повного переліку файлів — див. [SOURCE_INVENTORY.md](SOURCE_INVENTORY.md).
Цей файл зосереджений на змістовій оцінці та рекомендованих діях.

Умовні позначення дій:
- ✅ **keep** — матеріал актуальний, відповідає коду, нічого міняти не треба
- ⚠️ **needs verification** — потребує точнішої перевірки на відповідність коду
- 🔴 **fix** — знайдено конкретні неточності, потрібно виправити
- 📝 **expand** — контент вірний, але потребує розширення (stub)
- 🔀 **merge** — дублює інший файл, кандидат на злиття
- 🗂️ **archive** — застарілий або замінений, переносити до archive/

---

## Туторіали — Zero to Hero (tutorials/01–09)

Критичний шар: прив'язані до коду notes_chat_app. Неточності впливають на студентів напряму.

### tutorials/01_first_django_page.md (1087 рядків)

- **Тип:** ZH — Zero to Hero starter
- **Рівень:** beginner
- **Теми:** Django setup, hello world, перший view, URLconf, templates, SQLite
- **Проєкт:** `hello_project` — НАВМИСНО ≠ notes_chat_app
- **Inspection:** ⚠️ partially inspected (заголовок + перші секції)
- **Передумови:** Python, термінал
- **Неточності:**
  - Використовує `venv` (не `.venv`) — **не неточність**, навмисна відмінність
  - Порт 8000 (не 8001 notes_chat_app) — навмисно, standalone проєкт
  - SQLite, не PostgreSQL — навмисно
- **Дія:** ✅ **keep** — навмисно використовує простіший standalone проєкт. Варто додати callout box.

---

### tutorials/02_first_model.md (1348 рядків)

- **Тип:** ZH
- **Рівень:** beginner
- **Теми:** ModelForm, CRUD views, PRG-pattern, Django Messages, Template Inheritance, Bootstrap 5
- **Проєкт:** bootstrap_notes (standalone)
- **Inspection:** ⚠️ partially inspected
- **Дія:** ✅ **keep**

---

### tutorials/03_crud.md (1288 рядків)

- **Тип:** ZH
- **Рівень:** intermediate
- **Теми:** Domain→Schema методологія, ORM relationships, selectors/services архітектура
- **Проєкт:** notes_project (попередник notes_chat_app)
- **Inspection:** ⚠️ partially inspected
- **Дія:** ⚠️ **needs verification** — показує ранню версію архітектури

---

### tutorials/04_templates_bootstrap.md (1115 рядків)

- **Тип:** ZH
- **Рівень:** intermediate
- **Теми:** 3-рівнева Template Inheritance, Crispy Forms, Context Processor, SaaS Dashboard
- **Проєкт:** crispy_notes (попередник)
- **Inspection:** ⚠️ partially inspected
- **Дія:** ✅ **keep**

---

### tutorials/05_authentication.md (2020 рядків) — ✅ ВСІ ПОМИЛКИ ВИПРАВЛЕНО

- **Тип:** ZH
- **Рівень:** intermediate–advanced
- **Теми:** Auth, sessions, IDOR, groups, group-sharing, WebSocket chat
- **Проєкт:** notes_chat_app (повна реалізація)
- **Inspection:** ✅ fully inspected
- **Виправлено:**
  1. Рядок 1294: `update_note(note, form.cleaned_data)` → keyword args з Q-filter
  2. Рядки 1287–1298: `get_object_or_404(Note, pk=pk, user=...)` → Q-filter паттерн
  3. Рядок 1378: `store` → `store_name`
  4. Рядки 1565–1577: raw POST `group_create` → `GroupCreateForm`
- **Дія:** ✅ **keep** — виправлено всі 4 неточності

---

### tutorials/06_testing.md (1912 рядків)

- **Тип:** ZH
- **Рівень:** intermediate–advanced
- **Теми:** Unit/integration/consumer/Selenium тести, AAA pattern, CI
- **Проєкт:** notes_chat_app
- **Inspection:** ⚠️ partially inspected
- **Дія:** ✅ **keep**

---

### tutorials/07_async.md (1398 рядків)

- **Тип:** ZH
- **Рівень:** advanced
- **Теми:** HTTP vs WebSocket, asyncio, ASGI stack, GroupChatConsumer, database_sync_to_async; місток asyncio→ASGI→Channels (додано 2026-06-14)
- **Проєкт:** notes_chat_app
- **Inspection:** ⚠️ partially inspected
- **Дія:** ✅ **keep**

---

### tutorials/08_celery.md (NEW — 2026-06-15)

- **Тип:** ZH
- **Рівень:** advanced
- **Теми:** Celery Worker, Beat, Redis broker (DB 1), `@shared_task`, `CELERY_BEAT_SCHEDULE`, `relativedelta`, HTTP polling, Bootstrap Toast, `mail.outbox`, Selenium Toast tests
- **Проєкт:** notes_chat_app
- **Inspection:** ✅ новий файл, написаний з нуля на основі реального коду
- **Виправлення:** N/A — новий
- **Дія:** ✅ **keep**

---

### tutorials/09_deployment.md (1371 рядків) ← перейменовано з 08_deployment.md

- **Тип:** ZH
- **Рівень:** advanced
- **Теми:** Docker Compose, nginx, ngrok, Selenium E2E, GitHub Actions, .env
- **Проєкт:** notes_chat_app
- **Inspection:** ⚠️ partially inspected
- **Дія:** ✅ **keep**

---

## README Модулі (tutorials/README_1–README_9)

### Статус після повної інспекції

| Файл | Проєкт | Inspection | Знайдено проблем | Дія |
|------|--------|-----------|-----------------|-----|
| README_1.md | hello_project | 🔍 structure only | — | ✅ keep |
| README_2.md | bootstrap_notes | 🔍 structure only | — | ✅ keep |
| README_3.md | notes_project | 🔍 structure only | — | ⚠️ needs verification |
| README_4.md | notes_project_cbv | 🔍 structure only | — | ⚠️ needs verification |
| README_5.md | crispy_notes | ⚠️ partially inspected | — | ✅ keep |
| README_6.md | **crispy_notes_project** | ✅ fully inspected | 1 потенційна (cleaned_data_for_service?) | ⚠️ needs verification |
| README_7.md | **crispy_notes_project** | ✅ fully inspected | 2 low (legacy paths) | ✅ keep (minor) |
| README_8.md | crispy_notes + notes_chat_app | ✅ fully inspected | 1 medium (async_selectors не існує в notes_chat_app) | 🔴 **fix** (додати примітку) |
| README_9.md | **notes_chat_app** | ✅ fully inspected | **2 high** (author on_delete, store замість store_name) | 🔴 **fix** |

**Важливо:** README_6, README_7, README_8 описують `crispy_notes_project` — попередній навчальний проєкт, НЕ `notes_chat_app`. Деякі відмінності від `notes_chat_app` є навмисними.

---

## Knowledge Book (00–11)

### 00 — Getting Started

| Файл | Inspection | Унікальний зміст | notes_chat_app | Дія |
|------|-----------|-----------------|----------------|-----|
| README.md | ✅ fully inspected | Три шари книги, порівняльна таблиця "типовий туторіал vs notes_chat_app", мінімальний старт | ✅ прив'язаний | ✅ keep |
| how_to_use_course.md | 🔍 structure only | — | — | ✅ keep |
| local_setup.md | ✅ fully inspected | Локальний запуск (venv + pip + runserver) — **увага**: не відображає Docker flow; ASGI через uvicorn | ⚠️ часткова прив'язка | ⚠️ **needs update**: слід згадати що основний flow — Docker |
| prerequisites.md | 🔍 structure only | — | — | ✅ keep |
| repository_structure.md | 🔍 structure only | — | — | ✅ keep |

---

### 01 — Web Foundations (5 файлів)

Теоретичні концепції. Стабільні, не прив'язані до конкретного коду.
Inspection: 🔍 structure only для всіх.
**Дія:** ✅ **keep** для всіх файлів.

---

### 02 — Django Core (11 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| django_architecture_full.md | ⚠️ partially inspected | Велика (842 рядки), охоплює MTV, middleware; посилання-карта до всієї документації | ✅ keep |
| django_command_system.md | 🔍 structure only | 4 рядки — redirect-placeholder | 🔀 merge або видалити |
| request_lifecycle.md | 🔍 structure only | Короткий (48 рядків) — дублює частину architecture_full | 🔀 merge або keep як summary |
| urls_and_views.md | 🔍 structure only | Короткий (45 рядків) — дублює url_routing_full + views_full | ⚠️ needs verification |
| views_full.md | ⚠️ partially inspected | Повна (1075 рядків), FBV+CBV+decorators; Mermaid lifecycle; selectors/services паттерн; антипатерни | ✅ keep |
| wsgi_vs_asgi.md | 🔍 structure only | Перетинається з 09/async_03_asgi_full | ✅ keep (різний фокус) |
| Решта (5) | 🔍 structure only | — | ✅ keep |

---

### 03 — Database and ORM (13 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| django_migrations_full.md | ✅ fully inspected | Глибокий аналіз міграцій, 2 Mermaid діаграми, debugging intuition, production deployment | ✅ keep canonical |
| migrations.md | ✅ fully inspected | Short summary — фактичні міграції notes_chat_app (0001-0004), команди | 🔀 summary (різний purpose) |
| django_orm_deep_full.md | 🔍 structure only | Q, F, annotate — глибоко | ✅ keep |
| transactions_indexes_postgresql.md | 🔍 structure only | Дублює 3 великі файли | 🔀 merge або archive |
| query_optimization.md | 🔍 structure only | — | ⚠️ needs verification |
| Решта (8) | 🔍 structure only | — | ✅ keep |

---

### 04 — Forms and Validation (4 файли)

| Файл | Inspection | Дія |
|------|-----------|-----|
| crispy_forms_full.md | 🔍 structure only | ✅ keep |
| django_forms_and_crispy.md | 🔍 structure only | ⚠️ needs verification (дублює більші файли?) |
| django_forms_full.md | 🔍 structure only | ✅ keep |
| README.md | 🔍 structure only | ✅ keep |

---

### 05 — Frontend and Templates (12 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| advanced_templates_full.md | ⚠️ partially inspected | Context Processors (sidebar_context), Custom Template Tags, crispy-forms, Vite, SaaS Dashboard, HTMX, Jinja2 Deep Dive; унікальний поглиблений контент | ✅ keep canonical |
| django_templates_full.md | ✅ fully inspected | Template engine механізм, Node compilation, context system, XSS, Mermaid execution flow | 🔀 summary (різний рівень від advanced) — keep |
| bootstrap_5_full.md | 🔍 structure only | — | ✅ keep |
| css_basics_full.md | 🔍 structure only | — | ✅ keep |
| design_foundations_full.md | 🔍 structure only | — | ✅ keep |
| design_readme_full.md | 🔍 structure only | — | ⚠️ needs verification |
| django_admin_full.md | 🔍 structure only | — | ✅ keep |
| django_admin_unfold_full.md | 🔍 structure only | — | ✅ keep |
| django_templates_bootstrap_full.md | 🔍 structure only | — | ⚠️ needs verification |
| html_basics_full.md | 🔍 structure only | — | ✅ keep |
| templates_bootstrap_static.md | 🔍 structure only | — | ⚠️ needs verification |
| README.md | 🔍 structure only | — | ✅ keep |

---

### 06 — Application Architecture (9 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| services_selectors_full.md | ⚠️ partially inspected | Повна архітектурна карта, Input/OutputSerializer, антипатерни, data flow | ✅ keep canonical |
| django_services_selectors.md | ✅ fully inspected | Ідентичний services_selectors_full (з позначкою "збережено як історичний") | 🗂️ **archive** — точний дублікат з disclamer |
| django_services_full.md | 🔍 structure only | Services pattern окремо | ✅ keep |
| django_selectors_full.md | 🔍 structure only | Selectors CQRS-light окремо | ✅ keep |
| services_selectors.md | 🔍 structure only | Short summary | ⚠️ needs verification |
| django_serializers_full.md | 🔍 structure only | Serializers | ✅ keep |
| django_tasks_full.md | 🔍 structure only | Celery | ✅ keep |
| django_ninja_templates_full.md | 🔍 structure only | Django Ninja | ✅ keep |
| README.md | 🔍 structure only | — | ✅ keep |

---

### 07 — Auth and Security (11 файлів)

Теоретичні матеріали. Стабільний контент.
Inspection: 🔍 structure only для більшості.

| Файл | Дія |
|------|-----|
| auth_basics_full.md | ✅ keep |
| auth_sessions_permissions.md | ⚠️ needs verification (дублює три більші файли) |
| django_security_architecture_full.md | ✅ keep |
| owasp_top_10_full.md | ✅ keep |
| permissions_full.md | ✅ keep |
| security_foundations_full.md | ✅ keep |
| security_misconceptions_full.md | ✅ keep |
| sessions_flow_full.md | ✅ keep |
| siem_full.md | ✅ keep |
| zero_trust_full.md | ✅ keep |
| README.md | ✅ keep |

---

### 08 — Testing and Quality (12 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| ci.md | ✅ fully inspected | Short — CI workflow, посилання на legacy async routes; відмінний від ci_cd_full | 🔀 summary (різний purpose) — keep |
| ci_cd_full.md | ⚠️ partially inspected | Повний CI/CD, GitHub Actions YAML рядок за рядком, artifacts, Selenium job | ✅ keep canonical |
| django_testing_full.md | 🔍 structure only | — | ✅ keep |
| testing_practice_project_full.md | 🔍 structure only | Практика notes_chat_app тести | ✅ keep |
| Решта (8) | 🔍 structure only | — | ✅ keep |

---

### 09 — Async and Realtime (11 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| channels_websocket.md | ✅ fully inspected | Short, але з Mermaid WS flow; посилання на реальні файли notes_chat_app (consumers.py, group_chat.js, ChatMessage) | ✅ keep (короткий довідник) |
| async_01_sync_vs_async_full.md | 🔍 structure only | — | ✅ keep |
| async_02..09_*.md (8 файлів) | 🔍 structure only | — | ✅ keep |
| README.md | 🔍 structure only | — | ✅ keep |

---

### 10 — Linux and DevOps (12 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| docker_and_runtime.md | ✅ fully inspected | Short, notes_chat_app specific; примітка про legacy `notes` dir у build config | ✅ keep (проєктний довідник) |
| linux_01..10_*.md (10 файлів) | 🔍 structure only | — | ✅ keep |
| README.md | 🔍 structure only | — | ✅ keep |

---

### 11 — Deployment (10 файлів)

| Файл | Inspection | Унікальний зміст | Дія |
|------|-----------|-----------------|-----|
| deploy_14_docker_basics_full.md | ⚠️ partially inspected | Docker basics, image vs container, Mermaid VM vs Docker; загальна теорія (не notes_chat_app specific) | ✅ keep canonical |
| deploy_11..13, deploy_15..18 (7 файлів) | 🔍 structure only | — | ✅ keep |
| deployment_checklist.md | 🔍 structure only | — | ✅ keep |
| README.md | 🔍 structure only | — | ✅ keep |

---

## Аналіз дублікатів за змістом (6 перевірених пар)

### Пара 1: `03/django_migrations_full.md` ↔ `03/migrations.md`

| Характеристика | django_migrations_full.md (70 рядків) | migrations.md (53 рядки) |
|---------------|--------------------------------------|--------------------------|
| Тип | Глибоке пояснення механізму | Проєкт-specific short |
| Унікальний контент | Mermaid діаграми, makemigrations vs migrate, граф залежностей, debugging, production | Фактичні міграції notes_chat_app (0001-0004), команди showmigrations/sqlmigrate |
| Overlap | Загальна концепція міграцій | — |
| **Висновок** | **overlapping but unique** — різні педагогічні цілі | |
| **Canonical** | `django_migrations_full.md` для теорії; `migrations.md` для проєктного довідника |

### Пара 2: `06/services_selectors_full.md` ↔ `06/django_services_selectors.md`

| Характеристика | services_selectors_full.md (614 рядків) | django_services_selectors.md (617 рядків) |
|---------------|-----------------------------------------|------------------------------------------|
| Зміст | Ідентичний | Ідентичний (з disclamer "збережено як історичний") |
| **Висновок** | **exact duplicate** — django_services_selectors.md є застарілою копією |
| **Canonical** | `services_selectors_full.md` |
| **Дія** | 🗂️ archive `django_services_selectors.md` |

### Пара 3: `05/django_templates_full.md` ↔ `05/advanced_templates_full.md`

| Характеристика | django_templates_full.md (205 рядків) | advanced_templates_full.md (1811 рядків) |
|---------------|---------------------------------------|------------------------------------------|
| Унікальний контент | Template engine механізм, Node compilation, execution flow, Mermaid | Context Processors, Custom Tags, crispy-forms, Vite, SaaS Dashboard, HTMX, Jinja2 Deep Dive |
| Overlap | Базові поняття шаблонів | — |
| **Висновок** | **different pedagogical purpose** — django_templates_full є технічним intro, advanced — поглибленим |
| **Canonical** | обидва зберігаємо; django_templates_full як технічне введення |

### Пара 4: `08/ci.md` ↔ `08/ci_cd_full.md`

| Характеристика | ci.md (42 рядки) | ci_cd_full.md (714 рядків) |
|---------------|------------------|---------------------------|
| Унікальний контент | Посилання на legacy async routes, notes_chat_app specific | Повний CI/CD tutorial, GitHub Actions YAML, Selenium job |
| Overlap | CI поняття | — |
| **Висновок** | **summary of canonical** — ci.md є коротким проєктним довідником |
| **Canonical** | `ci_cd_full.md` для повного розуміння |

### Пара 5: `09/channels_websocket.md` ↔ `tutorials/07_async.md`

| Характеристика | channels_websocket.md (54 рядки) | tutorials/07_async.md (1387 рядків) |
|---------------|----------------------------------|-------------------------------------|
| Унікальний контент | Mermaid WS flow, channel layer вибір, посилання на проєктні файли | HTTP vs WebSocket теорія, повна реалізація GroupChatConsumer, sync_to_async |
| Overlap | Базовий WS flow | — |
| **Висновок** | **different pedagogical purpose** — channels_websocket.md є quick reference |
| **Canonical** | `tutorials/07_async.md` для навчання; `channels_websocket.md` для швидкого пошуку |

### Пара 6: `10/docker_and_runtime.md` ↔ `11/deploy_14_docker_basics_full.md`

| Характеристика | docker_and_runtime.md (46 рядків) | deploy_14_docker_basics_full.md (~250 рядків) |
|---------------|-----------------------------------|----------------------------------------------|
| Унікальний контент | notes_chat_app specific (Dockerfile, compose, entrypoint); примітка про legacy `notes` dir | Docker теорія: image vs container, VM vs Docker, Mermaid, terminology |
| Overlap | Docker поняття | — |
| **Висновок** | **different pedagogical purpose** — docker_and_runtime проєктний, deploy_14 теоретичний |
| **Canonical** | обидва зберігаємо з чіткими ролями |

---

## Project Deep Dive (12_final_project)

**Оновлено 2026-06-14/15.** Всі основні файли розширено з стабів до повного контенту.

| Файл | Рядків | Inspection | Дія |
|------|--------|-----------|-----|
| README.md | 511 | ✅ повний огляд: навігація, діаграма, структура, шари, URL, selectors, services, consumer, security, тести, Docker | ✅ keep |
| architecture.md | 115 | ✅ компоненти, ASGI routing, Mermaid flowchart | ✅ keep |
| domain_model.md | 176 | ✅ ER-діаграма, 9 моделей, deletion behavior | ✅ keep |
| feature_map.md | 68 | ✅ HTTP features, WebSocket, **Background Tasks** (Celery — додано), Не реалізовано (Celery прибрано) | ✅ keep |
| request_flows.md | 134 | ✅ HTTP flows, WebSocket flow (Mermaid) | ✅ keep |
| async_and_chat.md | 143 | ✅ ASGI routing, GroupChatConsumer lifecycle, channel layer | ✅ keep |
| background_tasks.md | 317 | ✅ **НОВИЙ (2026-06-15)**: Celery flow, Redis DB розподіл, browser notifications, тестування | ✅ keep |
| security_model.md | 96 | ✅ IDOR, Q-filter, матриця дозволів, WebSocket auth | ✅ keep |
| setup.md | 100 | ✅ Docker Compose launch, env vars | ✅ keep |
| testing_strategy.md | 87 | ✅ 7 тест-файлів, 221 тест, TransactionTestCase пояснення | ✅ keep |
| deployment.md | 84 | ✅ Docker services, production checklist | ✅ keep |
| student_tasks.md | 75 | ⚠️ 3 рівні завдань, але < 10 задач | 📝 можна розширити |
| orm_architecture_board.md | 18 | ⚠️ stub — посилання | 📝 expand |
| project_overview.md | 98 | ✅ ролі, стек, архітектурні патерни | ✅ keep |

---

## Labs

**Оновлено 2026-06-14.** Лабораторні роботи розширено.

| Файл | Рядків | Зміст | Дія |
|------|--------|-------|-----|
| orm_lab.md | 197 | N+1 проблема, `select_related`, `prefetch_related`, `annotate` на реальному коді Notes Chat App | ✅ keep |
| forms_lab.md | 197 | валідація форм, `clean_*`, CSRF | ✅ keep |
| testing_lab.md | 199 | AAA паттерн, `force_login`, IDOR тест | ✅ keep |
| async_lab.md | 228 | `GroupChatConsumer` lifecycle, `database_sync_to_async`, `WebsocketCommunicator` | ✅ keep |

---

## Reference

| Файл | Стан | Дія |
|------|------|-----|
| commands.md | Актуальний, містить Docker команди | ✅ keep |
| orm_cheatsheet.md | 725 рядків, детальний | ✅ keep |
| testing_cheatsheet.md | 205 рядків | ✅ keep |
| git_cheatsheet.md | 126 рядків | ✅ keep |
| deployment_cheatsheet.md | 138 рядків | ✅ keep |
| settings_reference.md | 217 рядків | ⚠️ needs accuracy check vs settings.py |
| legacy_indexes/index_*.md | Старі покажчики | 🗂️ archive (вже в legacy/) |
| legacy_source/docs_flat_readme.md | 326 рядків — стара README про тестування | 🗂️ archive |
| legacy_source/forms_views_laboratory_reference.md | 5 рядків — stub | 🗂️ archive |
| legacy_source/legacy_missing_reference.md | 5 рядків | 🗂️ archive |
| legacy_source/orm_laboratory_reference.md | 7 рядків | 🗂️ archive |

---

## Root-level docs

| Файл | Стан | Дія |
|------|------|-----|
| ARCHITECTURE.md | 128 рядків, актуальний | ✅ keep |
| GLOSSARY.md | 28 рядків — мінімальний | 📝 expand |
| LEARNING_PATH.md | 63 рядки | ✅ keep |
| TEACHING_GUIDE.md | 76 рядків | ✅ keep |
| TROUBLESHOOTING.md | 109 рядків | ✅ keep |
| index.md | 56 рядків | ✅ keep |

---

## Зведена статистика

Оновлено: 2026-06-15.

| Дія | К-сть файлів |
|-----|-------------|
| ✅ keep | ~125 |
| ⚠️ needs verification | ~15 |
| 🔴 fix | 1 (README_8.md — `async_selectors.py` примітка) |
| 📝 expand | ~3 (orm_architecture_board.md, student_tasks.md, GLOSSARY) |
| 🔀 merge | ~6 |
| 🗂️ archive | ~9 (django_services_selectors + legacy files) |

**Виконано з 2026-06-14:**
1. ✅ Виправлено 2 помилки в `tutorials/README_9.md` (ChatMessage.author on_delete, store→store_name)
2. ✅ Написано повний контент для `docs/12_final_project/` (всі основні файли)
3. ✅ Написано `docs/labs/` (4 лабораторні роботи)
4. ✅ Реалізовано Celery (tasks.py, celery.py, docker-compose) + tutor 08_celery.md + background_tasks.md
5. ✅ ZPD переходи виправлено (lazy evaluation bridge, asyncio→ASGI bridge)
6. ✅ Перенумеровано: deployment 08→09, Celery став 08

**Залишається:**
1. ✅ Примітка в `tutorials/README_8.md` вже є (рядки 109–115): `async_selectors.py` описано як навчальний файл `hello_app`, відсутній у `notes_chat_app`
2. 📝 Розширити `orm_architecture_board.md` (stub, 18 рядків)
3. 📝 Перевірити `form.cleaned_data_for_service()` у README_6 (crispy_notes_project)
4. 📝 Перевірити `reference/settings_reference.md` — відсутні CELERY_* налаштування
