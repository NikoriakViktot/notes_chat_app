# Plan: Book Expansion — повний аудит і план доповнення

> Дата: 2026-06-16  
> Мета: зробити книгу самодостатнім навчальним ресурсом  
> Принцип: WHY → Mental Model → Real Code → Debugging → Summary

---

## Масштаб проблеми

| Категорія | Кількість файлів | Стан |
|-----------|-----------------|------|
| STUB (< 70 рядків) | 25 файлів | Порожні заглушки |
| ТОНКІ (70–200 рядків) | 28 файлів | Мало контенту |
| РОЗДІЛ 12 (всі тонкі) | 12 файлів | 68–176 рядків |
| TUTORIAL INDEX (тонкі) | 9 файлів | 51–82 рядки |
| НОВІ ФАЙЛИ (відсутні) | 6 файлів | Прогалини у curriculum |
| **Загалом** | **80 файлів** | потребують роботи |

---

## ФАЗА 1 — STUB файли (< 70 рядків): написати з нуля

Ці файли є в навігації але майже без контенту. **Критично.**

### 00_getting_started

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `prerequisites.md` | 48 рядків | 300+ | Чекліст знань: Python (функції, класи, списки), HTML, термінал, Git. Для кожного — мінімальний рівень і де підтягнути |
| `local_setup.md` | 65 рядків | 450+ | Покроково: 1) Docker Desktop 2) clone repo 3) cp .env.example .env 4) docker compose up --build 5) відкрий localhost. Скріншот-описи очікуваного виводу. Типові помилки |
| `how_to_use_course.md` | 48 рядків | 300+ | Два шляхи: Книга (теорія, можна читати незалежно) + Zero to Hero (практика, крок за кроком). Як їх поєднувати. Рекомендований порядок читання |
| `repository_structure.md` | 51 рядків | 250+ | ASCII дерево структури репо з поясненням кожного елементу. Де живе код, де документація, що ігнорувати |

### 01_web_foundations

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `http_https.md` | 47 рядків | 400+ | HTTP: методи, статуси, заголовки, тіло запиту. HTTPS = TLS зверху HTTP. Certificates, CA, HSTS. DevTools Network tab для дослідження. Що бачить Django коли приходить запит |
| `browser_server_lifecycle.md` | 46 рядків | 450+ | Повний цикл: URL → DNS → TCP Handshake → TLS Handshake → HTTP Request → Django pipeline → HTTP Response → HTML parsing → CSS → JS → render. Кожен крок: хто виконує, що повертає |

### 02_django_core

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `django_command_system.md` | 4 рядки | 350+ | ПОРОЖНІЙ! manage.py як entry point. Вбудовані команди (migrate, runserver, shell, startapp). Як написати власну команду. Приклад: seed_demo_data з notes_chat_app |
| `request_lifecycle.md` | 48 рядків | 450+ | Повний шлях Django request: URLconf → Middleware (chain, порядок важливий) → View → Context → Template → Response. Що відбувається при 404, 403, 500. Код прикладу middleware |
| `urls_and_views.md` | 45 рядків | 350+ | path() vs re_path(). include(). Named URLs і reverse(). URL параметри. Namespace. FBV як callable. З реального urls.py notes_chat_app |

### 03_database_and_orm

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `django_models.md` | 56 рядків | 400+ | Model = Python клас = SQL таблиця. Field types taблиця (CharField, IntegerField, ForeignKey...). Meta клас: ordering, verbose_name, unique_together. Приклад з Note моделі notes_chat_app |
| `migrations.md` | 53 рядків | 350+ | Що таке міграція (= Python файл що змінює схему БД). makemigrations vs migrate. Як читати auto-generated migration. data migrations. squashmigrations. Конфлікти міграцій |
| `query_optimization.md` | 46 рядків | 450+ | N+1 проблема з прикладом. select_related (JOIN). prefetch_related (окремий SELECT). only(), defer(). values(). annotate(). explain(). django-debug-toolbar для виявлення |
| `transactions_indexes_postgresql.md` | 47 рядків | 350+ | atomic() декоратор і context manager. select_for_update(). Isolation levels. B-Tree indexes. PostgreSQL EXPLAIN ANALYZE. Коли потрібні індекси |

### 04_forms_and_validation

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `django_forms_and_crispy.md` | 50 рядків | 300+ | Ландшафт форм: HTML форми → Django Form → ModelForm → Crispy Form. Validation pipeline: is_valid() → clean_field() → clean(). Crispy FormHelper і Layout |

### 05_frontend_and_templates

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `templates_bootstrap_static.md` | 54 рядків | 400+ | TEMPLATES settings. Де Django шукає шаблони. collectstatic механізм. STATICFILES_DIRS. {% load static %}. Bootstrap CDN vs local. django-bootstrap-icons |

### 06_application_architecture

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `services_selectors.md` | 48 рядків | 350+ | Проблема fat views/fat models. Чому views → selectors+services. Де знаходиться логіка. Приклад: create_note() як service з notes_chat_app. Порівняльна таблиця патернів |

### 07_auth_and_security

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `auth_sessions_permissions.md` | 56 рядків | 450+ | Django auth system: User model, contrib.auth. Sessions: що зберігається в cookie vs session store. Session lifecycle. Django permissions: has_perm(). Group permissions. Object-level permissions |

### 08_testing_and_quality

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `ci.md` | 42 рядки | 350+ | CI: що це і навіщо. GitHub Actions: .github/workflows/ci.yml для Django. Run tests on PR. Test matrix (Python 3.11/3.12). Artifact upload для coverage |
| `testing_strategy.md` | 54 рядки | 350+ | Піраміда тестів для Django (Unit/Integration/E2E ratio). Що тестувати обов'язково (models, services, critical views). Що НЕ тестувати (Django internals, third-party) |

### 09_async_and_realtime

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `channels_websocket.md` | 54 рядки | 500+ | WebSocket protocol: handshake, frames, opcodes. Django Channels: Consumer lifecycle (connect/receive/disconnect). Channel layer і групи. routing.py і asgi.py. Повний приклад GroupChatConsumer |

### 10_linux_and_devops

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `docker_and_runtime.md` | 46 рядків | 400+ | Runtime environments: bare metal vs VM vs container. Docker: image, container, layer caching. Dockerfile анатомія. docker-compose vs docker run. Container networking |

### 11_deployment

| Файл | Зараз | Потрібно | Що добавити |
|------|-------|----------|-----------|
| `README.md` | 56 рядків | 400+ | ДУЖЕ ТОНКИЙ для цілого розділу! Landscape: development → staging → production. Deployment options: VPS, PaaS (Railway/Render), Container platforms. Що вивчиш у розділі. Road map |
| `deployment_checklist.md` | 54 рядки | 300+ | Quick reference: pre-deploy, security, performance, monitoring. Інша від tutorials/09_deployment/production_checklist.md — ця для VPS деплою без Docker |

---

## ФАЗА 2 — ТОНКІ файли (70–200 рядків): значне розширення

### Theory section READMEs (кожен < 200 рядків)

| Файл | Зараз | Потрібно | Ключові елементи |
|------|-------|----------|-----------------|
| `01_web_foundations/README.md` | 106 | 350+ | Навіщо web foundations для Django-розробника. Learning objectives. Карта розділу (що де) |
| `02_django_core/README.md` | 149 | 400+ | MTV vs MVC аналогія (Model-Template-View). Де в коді кожен компонент. Карта розділу |
| `04_forms_and_validation/README.md` | 142 | 300+ | Lifecycle форми: браузер → Django → БД → відповідь. Три рівні форм (HTML/Form/ModelForm) |
| `05_frontend_and_templates/README.md` | 158 | 350+ | Frontend у Django: templates, static, admin. Що Django НЕ робить (React/Vue — окремо) |
| `06_application_architecture/README.md` | 164 | 350+ | Архітектурні патерни в Django: від fat views → thin views + services/selectors |
| `07_auth_and_security/README.md` | 159 | 400+ | Security layers у Django app. Authentication vs Authorization. What could go wrong |
| `08_testing_and_quality/README.md` | 178 | 350+ | Навіщо тести для Django. Test runner. Чому TestCase > unittest.TestCase |
| `10_linux_and_devops/README.md` | 225 | 350+ | Чому Linux для backend розробника. Мінімальний набір команд. Docker як надбудова |
| `11_deployment/README.md` | 56 | **400+** | КРИТИЧНО ТОНКИЙ — expand в Фазі 1 |

### Specific thin chapters

| Файл | Зараз | Потрібно | Ключові елементи |
|------|-------|----------|-----------------|
| `02_django_core/wsgi_vs_asgi.md` | 192 | 500+ | WSGI: один request = один thread. ASGI: один event loop = тисячі concurrent. WebSocket неможливий з WSGI. Uvicorn vs Gunicorn. Практика: запустити обидва і виміряти |
| `03_database_and_orm/django_migrations_full.md` | 70 | 450+ | Labeled "full" але лише 70 рядків! Anatomy of migration file. Forward/backward operations. Squash. Data migrations з RunPython. Circular dependencies |
| `05_frontend_and_templates/django_admin_full.md` | 127 | 500+ | ModelAdmin: list_display, list_filter, search_fields. Admin actions. Inlines. Custom views в admin. Кастомізація форм. admin.py з notes_chat_app |
| `05_frontend_and_templates/django_templates_full.md` | 205 | 500+ | Template tags: for, if, with, url, static, block, extends, include. Filters: date, length, truncatechars. Custom template tags. Context processors |
| `07_auth_and_security/auth_basics_full.md` | 155 | 500+ | authenticate(), login(), logout(). User model fields. AbstractUser extension. LoginView, LogoutView. Login required decorator vs mixin. Registration flow |

---

## ФАЗА 3 — РОЗДІЛ 12 (Final Project): всі файли тонкі

Розділ 12 — це документація реального проєкту `notes_chat_app`. Всі файли потребують розширення.

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `orm_architecture_board.md` | **18 рядків** | 300+ | ПРАКТИЧНО ПОРОЖНІЙ. Або розширити до повної ORM карти (всі моделі, зв'язки, on_delete) або видалити і перенаправити до domain_model.md |
| `feature_map.md` | 68 | 400+ | Карта feature → код. Для кожного feature: URL, View, Template, Service, Selectors, Models. Таблиця або Mermaid |
| `security_model.md` | 96 | 450+ | Auth flow (login → session → cookie). IDOR захист у views. CSRF токени. Group-based sharing security. XSS і messages. @login_required + get_object_or_404 patterns |
| `student_tasks.md` | 75 | 500+ | Реальні завдання для студентів. 3 рівні: Beginner (CSS зміни, нові поля), Intermediate (нова модель, нові views), Advanced (WebSocket feature, Celery task). Кожне із описом і hints |
| `deployment.md` | 84 | 350+ | Як деплоїти саме notes_chat_app. Посилання на кроки з tutorials/09_deployment/. Production environment variables |
| `project_overview.md` | 98 | 350+ | Що вміє notes_chat_app (feature list). Tech stack table. Demo accounts. Architecture overview у 5 реченнях. Скільки рядків коду, скільки тестів |
| `setup.md` | 100 | 400+ | Покроковий setup: prerequisites → .env → docker compose up → seed → перший логін. З очікуваним виводом кожного кроку. Troubleshooting |
| `testing_strategy.md` | 87 | 400+ | Test pyramid для цього проєкту. Як запустити кожен тип тестів. Coverage звіт. Опис кожного test файлу і що він тестує |
| `architecture.md` | 115 | 500+ | Повна архітектура: ASGI stack, Middleware, ProtocolTypeRouter, URL routing, Layer separation (views/services/selectors). Mermaid діаграми |
| `async_and_chat.md` | 143 | 500+ | WebSocket flow від браузера до БД. GroupChatConsumer lifecycle. Channel layer broadcast. JavaScript client (group_chat.js). database_sync_to_async wrapper |
| `domain_model.md` | 176 | 500+ | Повна ER діаграма (Mermaid). Всі 10 моделей з полями. Зв'язки і on_delete. Business rules вбудовані в модель |
| `request_flows.md` | 134 | 500+ | HTTP request flow (sequence diagram). WebSocket flow (connect/message/disconnect). Auth flow. Group sharing flow. Mermaid sequence діаграми для кожного |

---

## ФАЗА 4 — TUTORIAL INDEX файли: тонкі (51–82 рядки)

Кожен index.md — це "огляд кроку". Зараз вони занадто короткі.

| Файл | Зараз | Потрібно | Що додати |
|------|-------|----------|-----------|
| `01_hello_django/index.md` | 79 | 200+ | Що побудуємо на цьому кроці. Що вивчимо. Скільки часу потрібно. Prerequisites. Карта розділу |
| `02_first_model/index.md` | 82 | 200+ | Аналогічно |
| `03_crud_and_architecture/index.md` | 70 | 250+ | Аналогічно + пояснення чому архітектура так важлива |
| `04_templates_and_forms/index.md` | 69 | 200+ | Аналогічно |
| `05_auth_and_security/index.md` | **51** | 250+ | Найтонший. Чому auth — критично. Типові помилки новачків |
| `06_testing/index.md` | **61** | 250+ | Навіщо тести для джуна. Що буде з проєктом без тестів |
| `07_async_django/index.md` | 80 | 200+ | Аналогічно + різниця між 7A (async views) і 7B (WebSocket) |
| `08_background_tasks/index.md` | 70 | 200+ | Аналогічно + коли потрібен Celery |
| `tutorials/02_first_model/django_admin.md` | 196 | 400+ | Реальний admin.py notes_chat_app. ModelAdmin з list_display, filters. Admin actions. Inline для TodoItem |

---

## ФАЗА 5 — НОВІ ФАЙЛИ: прогалини у curriculum

| Новий файл | Чому потрібен |
|-----------|--------------|
| `docs/01_web_foundations/dns_and_tcp.md` | DNS → IP → TCP handshake (SYN/SYN-ACK/ACK). Без цього незрозуміло звідки "localhost" → 127.0.0.1 і що означає порт |
| `docs/02_django_core/settings_deep.md` | DATABASES, INSTALLED_APPS (порядок!), MIDDLEWARE (порядок!), TEMPLATES, STATIC, LOGGING, CELERY. Де знаходиться кожна настройка в notes_chat_app |
| `docs/03_database_and_orm/n_plus_one_guide.md` | Детальний практичний гід по N+1: виявлення через django-debug-toolbar і django-silk, fix з select_related/prefetch_related. Приклади з notes_app QuerySet |
| `docs/07_auth_and_security/group_permissions.md` | Django Group model для sharing. Як notes_chat_app використовує Groups для спільних нотаток і чату. Q(user=user) | Q(group__in=user_groups) паттерн |
| `docs/reference/TROUBLESHOOTING.md` | Топ-20 помилок Django-розробника: AppRegistryNotReady, SynchronousOnlyOperation, 403 CSRF, DisallowedHost, WebSocket 403, docker ERR_NGROK_8012, TimeoutError redis |
| `docs/reference/deployment_cheatsheet.md` | Quick ref: docker compose команди, nginx restart, psql команди, redis-cli, manage.py команди для production |

---

## Педагогічні принципи для кожного файлу

Кожна нова або розширена глава повинна мати цю структуру:

```
## Навіщо (WHY — завжди першим!)
  Аналогія або реальна ситуація де це потрібно.
  "Без цього в тебе буде проблема X"

## Концепція (Mental Model — перед кодом!)
  Блок: [ABSTRACT]
  ┌──────────────────────────────────────────┐
  │  Схема або аналогія (ASCII або текст)   │
  │  Пояснення на рівні "що і чому"         │
  └──────────────────────────────────────────┘
  
## Як це працює (HOW — деталі)
  Технічне пояснення + реальний код з notes_chat_app

## Перевірка (Verify it works)
  Команда або дія в браузері що показує результат

## Типові помилки (Common Mistakes)
  Таблиця: Симптом → Причина → Рішення

## У книзі / Офіційна документація
  Посилання
```

### Блоки для складних технічних тем

Для дуже технічних але важливих тем — додавати блоки вищого рівня:

```markdown
!!! abstract "Рівень вище: навіщо це існує"
    Короткий абстрактний опис ЧОМУ ця конструкція взагалі з'явилась,
    яку проблему вона вирішила. Один абзац.
```

```markdown
!!! example "У нашому проєкті"
    Де саме це використовується в notes_chat_app.
    Файл + рядки коду.
```

```markdown
!!! tip "Аналогія"
    Аналогія з реального життя для абстрактного поняття.
```

---

## Пріоритет виконання

### Тиждень 1 — STUB файли (КРИТИЧНО)
1. `02_django_core/django_command_system.md` (4 рядки → 0!)
2. `11_deployment/README.md` (56 → повноцінний огляд)
3. `09_async_and_realtime/channels_websocket.md` (54 → повний WebSocket гід)
4. `01_web_foundations/browser_server_lifecycle.md` + `http_https.md`
5. `02_django_core/request_lifecycle.md` + `urls_and_views.md`
6. `00_getting_started/local_setup.md` + `prerequisites.md`

### Тиждень 2 — Section 12 (Final Project)
7. `feature_map.md`, `security_model.md`, `student_tasks.md`
8. `architecture.md`, `request_flows.md`, `async_and_chat.md`
9. `domain_model.md`, `setup.md`, `project_overview.md`

### Тиждень 3 — Theory thin files
10. `03_database_and_orm/django_migrations_full.md`
11. `07_auth_and_security/auth_basics_full.md`
12. `05_frontend_and_templates/django_admin_full.md` + `django_templates_full.md`
13. Section READMEs

### Тиждень 4 — Tutorial indexes + нові файли
14. Index файли всіх 9 кроків
15. Нові файли з Фази 5
16. `02_django_core/settings_deep.md`

---

## Орієнтири якості

Після завершення розширення:

- Жоден файл в навігації не менший за 200 рядків (крім index/checkpoint)
- Кожна глава має секцію "Навіщо" перед технічним контентом
- Кожна глава має "У книзі" і "Офіційна документація" в кінці
- Складні технічні теми мають `!!! abstract` блок з аналогією
- Кожна глава має приклад з notes_chat_app коду
- Section 12 стає повноцінним reference для фінального проєкту
