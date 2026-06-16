# Book Progress

Поточний стан роботи з документацією Notes Chat App.
Оновлено: 2026-06-15 (ревізія 10 — Zero to Hero restructuring).

---

## Поточна фаза

**Batch O — Zero to Hero Directory Restructuring: IN PROGRESS 🔄**

### Задача

Замінити модель "0N_*.md + README_N.md (Детально)" на directory-based модулі:
кожен крок → каталог → послідовні глави.

### Прогрес

| Крок | Директорія | Статус | Файлів |
|------|-----------|--------|--------|
| 1 | `tutorials/01_hello_django/` | ✅ Done | 7 |
| 2 | `tutorials/02_first_model/` | ⏳ Pending | 5 |
| 3 | `tutorials/03_crud_and_architecture/` | ⏳ Pending | 10 |
| 4 | `tutorials/04_templates_and_forms/` | ⏳ Pending | 9 |
| 5 | `tutorials/05_auth_and_security/` | ⏳ Pending | 8 |
| 6 | `tutorials/06_testing/` | ⏳ Pending | 10 |
| 7 | `tutorials/07_async_django/` | ⏳ Pending | 10 |
| 8 | `tutorials/08_background_tasks/` | ⏳ Pending | 6 |
| 9 | `tutorials/09_deployment/` | ⏳ Pending | 12 |

**Документи планування:**
- `ZERO_TO_HERO_PLAN.md` — оновлено 2026-06-15 ✅
- `CONTENT_MIGRATION_PLAN.md` — section-level mapping ✅
- `MKDOCS_NAVIGATION_PLAN.md` — нова директорійна навігація ✅

---

**Batch N завершено (2026-06-14)** — Issue 11 (settings.py middleware) та Issue 24 (07_async.md asyncSetUp). Всі відкриті issues закрито.

### Batch N — Issue 11 + Issue 24: COMPLETED ✅ — 0 відкритих issues

| # | Файл | Проблема | Серйозність | Статус |
|---|------|----------|-------------|--------|
| 11 | `notes_project/settings.py` | `DebugExceptionMiddleware` перед `SecurityMiddleware`; traceback при `DEBUG=False` | 🟡 medium (code) | ✅ FIXED |
| 24 | `docs/tutorials/07_async.md` | `asyncSetUp` vs sync `setUp`; не відповідає реальному `test_consumers.py` | 🟡 medium | ✅ FIXED |

**Зміни settings.py:** `SecurityMiddleware` переміщено на позицію 1; `DebugExceptionMiddleware` загорнуто у `if DEBUG:`.
**Зміни 07_async.md:** `asyncSetUp` → sync `setUp` з прямими ORM-викликами; додано `!!! note` про Django 5.1+ asyncSetUp.

**Всі issues закрито після Batch N: 0 відкритих.**

---

**Batch M завершено (2026-06-14)** — Accuracy inspection туторіалів 01–04. Виправлено 4 проблеми.

### Batch M — Tutorials 01–04 accuracy inspection: COMPLETED ✅

**Файли проінспектовано:** 4 (01–04_*.md)
**Вихідні дані для перевірки:** `notes_app/models.py`, `notes_app/services.py`

| # | Файл | Проблема | Серйозність | Статус |
|---|------|----------|-------------|--------|
| M-2 | 03_crud.md | `update_note` без `notebook` → TypeError | 🔴 critical | ✅ FIXED |
| M-3 | 03_crud.md | PRIORITY_CHOICES 3 vs 4 у notes_chat_app | 🟡 medium | ✅ admonition added |
| M-4 | 04_templates_bootstrap.md | `notes_app/` замість `hello_app/` | 🟡 medium | ✅ FIXED |
| M-5 | 02_first_model.md | `/del/` замість `/delete/` у таблиці | 🟢 low | ✅ FIXED |

Tutorial 01: без виправлень (editorial-рівень — forward-reference у теоретичній секції 04).

**Залишилось відкритим після Batch M → виправлено у Batch N:**
- Issue 24 (🟡 medium) — 07_async.md: `asyncSetUp` → sync `setUp` ✅ FIXED (Batch N)
- Issue 11 (code) — DebugExceptionMiddleware у settings.py ✅ FIXED (Batch N)

**Batch L завершено (2026-06-14)** — MKDOCS_NAVIGATION_PLAN.md застосовано до mkdocs.yml.

### Batch L — Navigation restructure: COMPLETED ✅

**Зміни mkdocs.yml:**

| Зміна | Деталі |
|-------|--------|
| Новий top-level `Як користуватися` | Виокремлено з `Книга/00. Початок роботи` |
| `Книга` → `Книга Django` | 10 явних частин (Частина I–X) замість flat-списку |
| `11_deployment/` злито в Частину X | Deployment більше не окремий top-level |
| Новий top-level `Zero to Hero` | Туторіали переведені з `Практика` → крокова структура (0–8) |
| `Практика` → labs only | Туторіали видалені з Практики |
| `Довідник` очищено | Видалено `legacy_indexes/` і `legacy_source/` з nav; додано `deployment_checklist` |
| Quoted nav labels | Виправлено 3 YAML-помилки: `"HTTP Requests: архітектура"`, `"asyncio: Event Loop"`, `"Docker: повний посібник"` |

**Валідаційні перевірки (ручна, mkdocs не встановлено):**

| Перевірка | Результат |
|-----------|-----------|
| Nav entries | 154 |
| Missing files | 0 |
| Max nav depth | 3 (ліміт: 3) |
| `_internal/` в nav | не знайдено |
| `legacy_indexes/` в nav | не знайдено |
| `legacy_source/` в nav | не знайдено |
| YAML colon labels quoted | виправлено 3 |

**`mkdocs build --strict`:** BLOCKED — MkDocs не встановлено ні локально, ні через Docker-сервіс. Запустити при наступному розгортанні: `pip install mkdocs mkdocs-material && mkdocs build --strict`.

**Batch K завершено (2026-06-14)** — Legacy inspection: рішення для всіх legacy_indexes та legacy_source файлів.

### Batch K — Legacy inspection: COMPLETED ✅

**Файли проінспектовано:** 14 (7 × legacy_indexes + 7 × legacy_source)

**Рішення:**

| Файл | Рішення | Обґрунтування |
|------|---------|---------------|
| `legacy_indexes/README.md` | keep as stub | Нема контенту |
| `legacy_indexes/index_1.md` | keep as learning path source → KB Parts I+II README | "Шлях студента" 1-16 + таблиця 10 типових помилок |
| `legacy_indexes/index_2.md` | keep as learning path source → KB Part V README | 23-крок. маршрут + debugging algorithm (найцінніший) |
| `legacy_indexes/index_3.md` | keep as learning path source → KB Part III README | 9-рівн. learning map + 20-крок. читання |
| `legacy_indexes/index_4.md` | keep as learning path source → KB Part VII README | 10-крок. Auth маршрут (quickstart vказує на crispy_notes_chat_app) |
| `legacy_indexes/index_5.md` | keep as learning path source → KB Part VIII README | 13-секц. тестування гід для початківців |
| `legacy_indexes/index_7.md` | keep as learning path source → KB Part IX README | Mermaid 01→09 + "Async ≠ faster" warning |
| `legacy_indexes/index_8.md` | keep as learning path source → KB Parts X+XI README | 18-файл. mermaid + мін/повний маршрут |
| `legacy_source/README.md` | keep as stub | Нема контенту |
| `legacy_source/archive_legacy_docs_readme.md` | keep as stub | Пояснення про docs_flat, нема навч. контенту |
| `legacy_source/docs_flat_readme.md` | keep → merge later into testing_lab.md | Унікальні: IDOR test patterns + Django Test Client examples |
| `legacy_source/forms_views_laboratory_reference.md` | keep as stub | Placeholder для broken links з index_3 |
| `legacy_source/legacy_missing_reference.md` | keep as stub | Placeholder для відсутніх проєктів (index_1, index_2, index_3) |
| `legacy_source/orm_laboratory_reference.md` | keep as stub | Placeholder для broken links з index_3 |

**Ключовий висновок:** жоден файл не підлягає видаленню. Індекси є цінними педагогічними навч. маршрутами — джерелами для майбутніх KB README файлів. Нотатки оновлено в `CANONICAL_CONTENT_MAP.md` (confidence: high, inspection: fully inspected).

**Наступна фаза: Batch L** — застосування `MKDOCS_NAVIGATION_PLAN.md` до `mkdocs.yml`, видалення legacy_indexes / legacy_source з nav (файли зберігаються), запуск `mkdocs build --strict`.

**Batch J завершено (2026-06-14)** — Labs expansion і GLOSSARY.

### Batch J — Labs expansion: COMPLETED ✅

Розширено: `labs/orm_lab.md`, `labs/forms_lab.md`, `labs/testing_lab.md`, `labs/async_lab.md`, `GLOSSARY.md`.

GLOSSARY: 23 → 55+ термінів, розбито за абеткою, кожен термін прив'язаний до реального коду проєкту.

**Batch I завершено (2026-06-14)** — Project Deep Dive expansion (12 файлів docs/12_final_project/).

### Batch I — Project Deep Dive expansion: COMPLETED ✅

Розширено 12 з 13 файлів (orm_architecture_board.md залишено без змін — містить iframe).

Виправлено в процесі:
- `setup.md` — критично виправлено: локальний запуск без Docker неможливий (DATABASE_URL raises Exception); замінено на docker compose
- `domain_model.md` — додано поля для всіх 9 моделей, виправлено ER (TodoList.shared_with і ShoppingList.shared_with були відсутні), deletion behavior
- `feature_map.md` — виправлено "Direct sharing" (TodoList і ShoppingList мають shared_with M2M)

### Batch H — Zero to Hero accuracy inspection: COMPLETED ✅

Інспектовано: `tutorials/06_testing.md`, `07_async.md`, `08_deployment.md`, `README_7.md`
Виправлено: Issues 23, 25 (high), 7 (low). Задокументовано: Issue 24 (medium).

### Phase 2 — Architecture Planning: COMPLETED ✅

Створені файли:

| Файл | Статус |
|------|--------|
| `docs/_internal/BOOK_ARCHITECTURE_PLAN.md` | ✅ створено |
| `docs/_internal/ZERO_TO_HERO_PLAN.md` | ✅ створено |
| `docs/_internal/PROJECT_DEEP_DIVE_PLAN.md` | ✅ створено |
| `docs/_internal/CURRICULUM_MATRIX.md` | ✅ створено |
| `docs/_internal/CANONICAL_CONTENT_MAP.md` | ✅ створено |
| `docs/_internal/CONTENT_MIGRATION_PLAN.md` | ✅ створено |
| `docs/_internal/MKDOCS_NAVIGATION_PLAN.md` | ✅ створено |

### Статистика Phase 2

| Параметр | Значення |
|---------|---------|
| Knowledge Book частин | 10 (I–X) |
| Knowledge Book канонічних глав | ~90 файлів визначені |
| Zero to Hero кроків | 9 (0–8) |
| Project Deep Dive глав | 35 |
| Наскрізних сценаріїв | 11 |
| Лабораторних робіт | 4 |
| Reference сторінок | ~11 |
| Teacher сторінок | 2 |
| Файлів у Canonical Content Map | 179 |
| High-confidence рішень | ~100 файлів |
| Provisional рішень | ~27 файлів |
| Файлів що потребують повної інспекції | ~69 |

### Попередні фази

- Phase 1 Inspect: ✅ ЗАВЕРШЕНА (ревізія 3)
- Phase 1 FIX: ✅ ЗАВЕРШЕНА — 20 issues виправлено
- Phase 2 PLAN: ✅ ЗАВЕРШЕНА

Наступна фаза: **Batch K** — Legacy inspection і provisional decisions (7 legacy_indexes файлів, 3 provisional KB файли).

Repository inspection status:
- fully inspected: ~85 files
- partially inspected: ~25 files
- structure only: ~69 files (large KB full-chapters)

---

## Статистика інспекції Markdown файлів

| Параметр | Значення |
|---------|---------|
| Всього md файлів | 179 |
| Повністю інспектовано (`fully inspected`) | **~85 файлів** |
| Частково інспектовано (`partially inspected`) | **~25 файлів** |
| Тільки структура (`structure only`) | **~69 файлів** |
| Не інспектовано | 0 |

### Ревізія 3 — нові повністю інспектовані файли

**docs/12_final_project/ (12 файлів — всі прочитані):**
README.md, architecture.md, domain_model.md, feature_map.md, project_overview.md, request_flows.md, security_model.md, async_and_chat.md, setup.md, testing_strategy.md, deployment.md, orm_architecture_board.md

**docs/labs/ (5 файлів — всі прочитані):**
README.md, orm_lab.md, forms_lab.md, testing_lab.md, async_lab.md

**docs/reference/ (5 файлів):**
README.md, commands.md, testing_cheatsheet.md, deployment_cheatsheet.md, settings_reference.md

**docs/ top-level (7 файлів):**
README.md, ARCHITECTURE.md, GLOSSARY.md, LEARNING_PATH.md, TROUBLESHOOTING.md, TEACHING_GUIDE.md, index.md

**docs/XX/README.md (KB navs, 9 файлів):**
03/, 04/, 05/, 06/, 07/, 08/, 09/, 10/, 11/

**docs/XX/ short primary files (13 файлів):**
03/django_models.md, 03/query_optimization.md, 03/transactions_indexes_postgresql.md,
04/django_forms_and_crispy.md, 05/templates_bootstrap_static.md,
06/services_selectors.md, 07/auth_sessions_permissions.md,
08/testing_strategy.md, 09/channels_websocket.md, 10/docker_and_runtime.md,
11/deployment_checklist.md, + 2 вже в ревізії 2

**docs/00-02/ (subagent, 21 файлів):**
00/how_to_use_course.md, 00/prerequisites.md, 00/repository_structure.md,
01/README.md, 01/browser_server_lifecycle.md, 01/http_https.md, 01/network_foundation_full.md, 01/network_mermaid_full.md,
02/README.md, 02/django_architecture_full.md, 02/django_command_system.md, 02/django_mermaid_full.md, 02/management_commands_full.md, 02/project_structure_full.md, 02/request_lifecycle.md, 02/url_routing_full.md, 02/urls_and_views.md, 02/views_full.md, 02/wsgi_vs_asgi.md
(+ 2 вже в ревізії 2: 00/README.md, 00/local_setup.md)

### Частково інспектовані (ревізія 3 additions)

| Файл | Прочитано | Всього | Проблеми |
|------|-----------|--------|----------|
| `tutorials/01_first_django_page.md` | 150 lines | 1087 | standalone, educational |
| `tutorials/02_first_model.md` | 80 lines | 1348 | standalone, educational |
| `tutorials/03_crud.md` | 80 lines | 1288 | standalone, educational |
| `tutorials/04_templates_bootstrap.md` | 80 lines | 1115 | standalone, educational |
| `tutorials/06_testing.md` | ✅ повністю | 1912 | Issues 12, 25 FIXED (Batch H) |
| `tutorials/07_async.md` | ✅ повністю | 1387 | Issue 24 documented (asyncSetUp medium) |
| `tutorials/08_deployment.md` | ✅ повністю | 1371 | Issue 23 FIXED (dj_database_url + SQLite fallback) |
| `tutorials/README_7.md` | ✅ повністю | ~1914+ | Issue 7 FIXED (legacy monorepo path admonitions) |

### Залишаються structure only (~69 файлів)

Це переважно великі "full chapter" KB файли (500-2400 рядків) у:
- docs/03_database_and_orm/ (7 великих: orm_full, orm_deep, relational_db, postgresql, etc.)
- docs/04_forms_and_validation/ (2: crispy_forms_full, django_forms_full)
- docs/05_frontend_and_templates/ (8: bootstrap_5_full, css_basics, html_basics, django_admin_unfold, etc.)
- docs/06_application_architecture/ (6: django_ninja, selectors_full, serializers, services_full, tasks, solid)
- docs/07_auth_and_security/ (9: auth_basics, security_foundations, owasp, etc.)
- docs/08_testing_and_quality/ (10: django_testing_full, selenium_full, testing_practice, etc.)
- docs/09_async_and_realtime/ (9: async_01-09 series)
- docs/10_linux_and_devops/ (10: linux_01-10 series)
- docs/11_deployment/ (8: deploy_11-18 series)
- docs/tutorials/README_1-5 (5 великих туторіальних модулів)
- docs/reference/orm_cheatsheet.md, git_cheatsheet.md
- docs/reference/legacy_indexes/ (7 файлів), legacy_source/ (6 файлів)

---

## Статистика інспекції коду

| Файл | Статус |
|------|--------|
| `notes_app/models.py` | ✅ перевірено повністю |
| `notes_app/views.py` | ✅ перевірено повністю |
| `notes_app/selectors.py` | ✅ перевірено повністю |
| `notes_app/services.py` | ✅ перевірено повністю |
| `notes_app/consumers.py` | ✅ перевірено повністю |
| `notes_app/forms.py` | ✅ перевірено повністю |
| `notes_app/urls.py` | ✅ перевірено повністю |
| `notes_app/admin.py` | ✅ перевірено повністю |
| `notes_app/apps.py` | ✅ перевірено (HelloAppConfig odd naming) |
| `notes_app/context_processors.py` | ✅ перевірено повністю |
| `notes_project/middleware.py` | ✅ перевірено (DebugExceptionMiddleware) |
| `notes_app/tests/test_models.py` | ✅ перевірено |
| `notes_app/tests/test_views.py` | ✅ перевірено |
| `notes_app/tests/test_consumers.py` | ✅ перевірено |
| `notes_app/tests/test_services.py` | ⚠️ структура відома |
| `notes_app/tests/test_forms.py` | ⚠️ структура відома |
| `notes_app/tests/test_selenium.py` | ⚠️ структура відома |
| `notes_project/settings.py` | ✅ перевірено |
| `notes_project/asgi.py` | ✅ перевірено |
| `notes_project/routing.py` | ✅ перевірено |
| `notes_project/urls.py` | ✅ перевірено |
| `notes_app/management/commands/seed_demo_data.py` | ✅ перевірено (частково) |
| `Dockerfile` | ✅ перевірено |
| `docker-compose.yml` | ✅ перевірено |
| `entrypoint.sh` | ✅ перевірено повністю |
| `requirements.txt` | ✅ перевірено |
| `.env.example` | ✅ перевірено |
| `.github/workflows/django-tests.yml` | ✅ перевірено |
| `mkdocs.yml` | ✅ перевірено |
| `CLAUDE.md` (проєкт) | ✅ перевірено |
| `notes_app/static/notes_app/js/group_chat.js` | ⚠️ підтверджено існування, зміст не читано |

### Код що НЕ існує (виправлення попереднього аудиту)

| Очікуваний файл | Реальний статус |
|----------------|----------------|
| `Makefile` | **НЕ ІСНУЄ** |
| `notes_app/signals.py` | **НЕ ІСНУЄ** |
| `notes_app/middleware.py` | **НЕ ІСНУЄ** — middleware лише `notes_project/middleware.py` |

---

## Знайдені проблеми

### Виправлено (tutorial 05 — 5 проблем)

| # | Серйозність | Опис | Статус |
|---|-------------|------|--------|
| 1 | 🔴 critical | `update_note(note, form.cleaned_data)` → TypeError | ✅ FIXED |
| 2 | 🟠 high | `get_object_or_404` замість Q-filter у note_edit | ✅ FIXED |
| 3 | 🟠 high | `store` замість `store_name` | ✅ FIXED |
| 4 | 🟠 high | `group_create` raw POST замість `GroupCreateForm` | ✅ FIXED |
| 5 | 🟢 low | Неправильний шлях у коментарі test_views.py | ✅ FIXED |

### Виправлено у FIX фазі (Issues 6–22 по канонічній нумерації accuracy report)

| Accuracy ID | Файл | Серйозність | Опис | Статус |
|-------------|------|-------------|------|--------|
| 6 | README_6.md | 🟠 high | `form.cleaned_data_for_service()` → explicit cleaned_data call | ✅ FIXED |
| 7 | README_7.md | 🟢 low | Legacy шляхи `module_5/...` — 2 admonitions додано | ✅ FIXED |
| 8 | README_8.md | 🟡 medium | async_*.py не у фінальному notes_chat_app → callout added | ✅ FIXED |
| 9 | README_9.md | 🟠 high | ChatMessage.author SET_NULL → CASCADE (code block) | ✅ FIXED |
| 10 | README_9.md | 🟠 high | ER-діаграма: `store` → `store_name` | ✅ FIXED |
| 11 | middleware.py / settings.py | 🟡 medium (code) | DebugExceptionMiddleware перед SecurityMiddleware; traceback при DEBUG=False | ✅ FIXED (Batch N) |
| 12 | 06_testing.md | 🔴 critical | SET_NULL тест → CASCADE тест | ✅ FIXED |
| 13 | settings_reference.md | 🟠 high | SQLite fallback → Exception | ✅ FIXED |
| 14 | testing_cheatsheet.md | 🟡 medium | TestCase → TransactionTestCase | ✅ FIXED |
| 15 | 07_async.md | 🟡 medium | TestCase → TransactionTestCase | ✅ FIXED |
| 16 | README_9.md | 🟡 medium | TestCase → TransactionTestCase (consumer test) | ✅ FIXED |
| 17 | README_9.md | 🟠 high | ShopItem: `is_bought` → `is_purchased` (ER) | ✅ FIXED |
| 18 | README_9.md | 🟡 medium | ShopItem: `quantity (pos.int)` → `decimal 8,2` (ER) | ✅ FIXED |
| 19 | README_9.md | 🟠 high | ShopItem: `position` не існує → `estimated_price + unit` (ER) | ✅ FIXED |
| 20 | README_9.md | 🟡 medium | Consumer `or 'Видалений юзер'` імплікує nullable author → removed | ✅ FIXED |
| 21 | README_9.md | 🟢 low | `related_name='messages'` → `'chat_messages'` | ✅ FIXED |
| 22 | README_9.md | 🟢 low | TodoItem: `position` → `order_position` (ER) | ✅ FIXED |

### Batch H (Issues 23–25, виявлені і оброблені 2026-06-14)

| Accuracy ID | Файл | Серйозність | Опис | Статус |
|-------------|------|-------------|------|--------|
| 23 | 08_deployment.md | 🟠 high | `dj_database_url` + SQLite fallback → regex parsing + Exception | ✅ FIXED |
| 24 | 07_async.md | 🟡 medium | `asyncSetUp` vs sync `setUp` педагогічне неузгодження | ✅ FIXED (Batch N) |
| 25 | 06_testing.md | 🟠 high | `TestCase` → `TransactionTestCase` у consumer test секції 11 | ✅ FIXED |

**Всього підтверджених tutorial проблем: 25 (включаючи нові знайдені у Batch H)**
**Виправлено: 25 (всі)**
**Відкритих: 0** ✅ — всі закрито у Batch N (2026-06-14)

---

## Аналіз дублікатів за змістом

| Пара | Тип дублювання | Рекомендація |
|------|---------------|-------------|
| `django_migrations_full.md` ↔ `migrations.md` | overlapping but unique (різний рівень) | keep обидва |
| `services_selectors_full.md` ↔ `django_services_selectors.md` | **exact duplicate** | archive `django_services_selectors.md` |
| `django_templates_full.md` ↔ `advanced_templates_full.md` | different pedagogical purpose | keep обидва |
| `ci.md` ↔ `ci_cd_full.md` | summary of canonical | keep обидва (різний use case) |
| `channels_websocket.md` ↔ `tutorials/07_async.md` | different pedagogical purpose | keep обидва |
| `docker_and_runtime.md` ↔ `deploy_14_docker_basics_full.md` | different pedagogical purpose | keep обидва |

**Дублікатів за змістом верифіковано: 6**
**Точних дублікатів що потребують архівування: 1** (`django_services_selectors.md`)

---

## Стан Docker stack

| Сервіс | Стан |
|--------|------|
| db (postgres:16-alpine) | ✅ Up (healthy) |
| redis (redis:7-alpine) | ✅ Up (healthy) |
| web (Django + uvicorn) | ✅ Up (healthy) — порт 8001 |
| nginx (1.27-alpine) | ✅ Up (healthy) — порт 80 |
| ngrok | ✅ Up — порт 4040 |
| selenium (standalone-chrome) | ✅ Up (healthy) — порт 4444 |

**mkdocs:** не доступний локально (`blocked` — не встановлений поза Docker)

---

## Аудит-файли

| Файл | Статус | Остання зміна |
|------|--------|--------------|
| `docs/_internal/SOURCE_INVENTORY.md` | ✅ оновлено | 2026-06-14 (ревізія 2) |
| `docs/_internal/BOOK_DOCUMENTATION_AUDIT.md` | ✅ оновлено | 2026-06-14 (ревізія 2) |
| `docs/_internal/PROJECT_CODE_DOCUMENTATION_MAP.md` | ✅ оновлено | 2026-06-14 (ревізія 3) |
| `docs/_internal/PROJECT_TUTORIAL_ACCURACY_REPORT.md` | ✅ оновлено | 2026-06-14 (ревізія 4 FIX) |
| `docs/_internal/BOOK_PROGRESS.md` | ✅ оновлено | 2026-06-14 (FIX phase) |

---

## Наступні кроки (в порядку пріоритету)

### FIX PHASE COMPLETED ✅

Всі issues виправлено. Batch N (2026-06-14): Issue 11 (settings.py) + Issue 24 (07_async.md). Відкритих: 0.

### PLAN PHASE COMPLETED ✅

7 архітектурних планів створено. Детальний план міграції у `CONTENT_MIGRATION_PLAN.md`.

### 1. Batch H — Zero to Hero accuracy fixes (НАСТУПНИЙ КРОК)

Повна інспекція tutorials/01–04, продовження 06–08, cleanup README_7 legacy paths.
Деталі: `CONTENT_MIGRATION_PLAN.md#batch-h`

### 2. Batch I — Project Deep Dive expansion

13 stub-файлів у `12_final_project/` потребують повного контенту.
Деталі: `CONTENT_MIGRATION_PLAN.md#batch-i`

### 3. Batches B–G — Knowledge Book inspection

~69 structure-only файлів потребують повної семантичної інспекції перед merge/archive рішеннями.

### 4. Batch J — Labs expansion

4 lab-файли — стаби. Написати після Batch H.

### 5. Batch K — Legacy і provisional decisions

27 provisional файлів потребують кінцевого рішення.

### 6. Batch L — Navigation і final validation

Застосувати MKDOCS_NAVIGATION_PLAN.md до mkdocs.yml, пройти `mkdocs build --strict`.

---

## Блокери

| Блокер | Впливає на |
|--------|-----------|
| mkdocs не встановлений локально | `mkdocs build --strict` — blocked |
| crispy_notes_project не у поточному репо | Верифікація README_6 Issue 1 |
