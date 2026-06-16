# KB Audit: 00 Getting Started / 01 Web Foundations / 02 Django Core
Generated: 2026-06-14

---

## 00 Getting Started

### README.md

```
path: docs/00_getting_started/README.md
inspection_status: fully inspected
lines: 255
topics: [навіщо Django, batteries included, реальні компанії що використовують, структура notes_chat_app, MTV архітектура, DRY принцип, production-ready порівняння, мінімальний старт]
level: beginner
has_mermaid: no
has_exercises: no (лише контрольні питання без практичного завдання)
has_debugging: no
has_production_notes: yes (таблиця типовий туторіал vs notes_chat_app)
code_examples: yes (django code — ModelForm, admin.site.register, структура файлів)
notes_chat_app_connection: integrated (детально описує notes_chat_app: всі файли, схему даних, docker-compose сервіси, demo credentials)
unique_content: [найдетальніша таблиця production vs tutorial для notes_chat_app, список реальних Django-компаній з контекстом, пояснення чому Instagram 2 розробники за 8 тижнів, мінімальний старт з demo credentials]
duplicate_candidate: none (є короткий огляд, що не дублюється — є унікальний рекламний/вступний тон)
contradictions_with_code:
  - README називає ASGI сервер "Uvicorn ASGI" у таблиці production → відповідає entrypoint.sh ✓
  - Схема даних співпадає з CLAUDE.md ✓
  - nginx 1.27 — потрібно перевірити docker-compose.yml, але прийнятно як загальна документація
  - У структурі файлів згадує notes_project/wsgi.py "не використовується в production" — це відповідає wsgi_vs_asgi.md ✓
canonical_role: теорія (вступний розділ — мотивація, огляд проєкту)
action: keep
notes: Найсильніший файл розділу. Єдиний що містить реальну структуру notes_chat_app, схему даних і demo credentials. Є навігаційні посилання до всіх 4 sub-документів розділу. Посилання ../tutorials/03_crud.md потребує перевірки існування.
```

---

### how_to_use_course.md

```
path: docs/00_getting_started/how_to_use_course.md
inspection_status: fully inspected
lines: 48
topics: [маршрути навчання, ролі (студент/викладач/практик/DevOps), правило "Де це знайти у фінальному проєкті"]
level: beginner
has_mermaid: no
has_exercises: yes (практичне завдання — вибрати маршрут)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: mentioned (посилання на docs/LEARNING_PATH.md та docs/12_final_project/README.md)
unique_content: [опис чотирьох режимів читання документації, контрольні питання про "що є входом, що результат, де помилка, яка команда перевіряє"]
duplicate_candidate: none
contradictions_with_code:
  - Посилається на docs/LEARNING_PATH.md і docs/12_final_project/README.md — треба перевірити існування
  - Посилається на docs/10_linux_and_devops/ і docs/11_deployment/ — треба перевірити існування
canonical_role: supplement (метадокумент про навігацію)
action: needs verification (перевірити що всі посилання існують)
notes: Дуже короткий, загальний. Чотири секції контрольних питань є шаблонними (однакові в кількох файлах розділу). Файл LEARNING_PATH.md у root docs/ не підтверджений у цій інспекції — може бути відсутній.
```

---

### local_setup.md

```
path: docs/00_getting_started/local_setup.md
inspection_status: fully inspected
lines: 65
topics: [локальний запуск без Docker, virtualenv для Linux/macOS/WSL, virtualenv для Windows PowerShell, ASGI запуск через uvicorn]
level: beginner
has_mermaid: no
has_exercises: yes (запустити python manage.py check)
has_debugging: no
has_production_notes: no
code_examples: yes (bash/powershell команди)
notes_chat_app_connection: mentioned (manage.py, notes_project/asgi.py)
unique_content: [Windows PowerShell варіант setup (єдиний в документації де він є), uvicorn команда для ASGI чату]
duplicate_candidate: none
contradictions_with_code:
  - КРИТИЧНА ПРОБЛЕМА: файл описує запуск БЕЗ Docker (pip install -r requirements.txt, python manage.py migrate, python manage.py runserver), але CLAUDE.md чітко вказує: "The project requires PostgreSQL. Run Django commands through Docker unless a valid PostgreSQL DATABASE_URL is explicitly configured." Локальний запуск без PostgreSQL призведе до помилки якщо DATABASE_URL не заданий.
  - uvicorn команда: "uvicorn notes_project.asgi:application --reload --port 8001" — порт 8001 відповідає docker-compose, але без Docker-стеку (postgres, redis) чат не запрацює
  - Не згадує Docker compose up --build як основний метод запуску
canonical_role: supplement (локальна альтернатива Docker — але потенційно misleading)
action: needs verification
notes: НАЙБІЛЬША СУПЕРЕЧНІСТЬ У РОЗДІЛІ 00. Документ не застерігає що без PostgreSQL (або DATABASE_URL) runserver впаде з OperationalError. README.md (255 рядків) натомість одразу показує docker compose up --build. Варто або додати попередження "потрібен DATABASE_URL або Docker", або чітко зазначити що це для повністю локального PostgreSQL. Секція "ASGI для чату" — хороша деталь, унікальна для цього файлу.
```

---

### prerequisites.md

```
path: docs/00_getting_started/prerequisites.md
inspection_status: fully inspected
lines: 48
topics: [мінімальні вимоги, Git, Python 3.12, Terminal, virtualenv, що НЕ потрібно на старті]
level: beginner
has_mermaid: no
has_exercises: yes (python --version, створити venv)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: mentioned (requirements.txt, .env.example)
unique_content: [секція "Не потрібно на старті" — явно вказує що Docker/Redis/PostgreSQL/Nginx не потрібні для першого локального запуску]
duplicate_candidate: none
contradictions_with_code:
  - Стверджує що Docker "не потрібен на старті" — але CLAUDE.md вимагає Docker для всіх Django команд (без явного DATABASE_URL). Це підсилює суперечність з local_setup.md.
  - Загалом файл правильний для абсолютного початку (клонування, огляд коду) але може бути misleading якщо студент думає що може запустити app без Docker.
canonical_role: теорія (перелік попередніх знань)
action: needs verification
notes: Правила про "Не потрібно на старті" суперечать CLAUDE.md вимогам. Файл сам по собі короткий і правильно описує абсолютний мінімум (Git + Python + terminal). Потрібна примітка що для запуску повного стеку потрібен Docker.
```

---

### repository_structure.md

```
path: docs/00_getting_started/repository_structure.md
inspection_status: fully inspected
lines: 51
topics: [структура папок, головні директорії, staticfiles виняток]
level: beginner
has_mermaid: no
has_exercises: yes (знайти кожен шлях у editor)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: integrated (notes_project/settings.py, notes_app/models.py, notes_app/tests/)
unique_content: [застереження що staticfiles/ є результатом collectstatic і не для редагування — єдине місце де це вказано у розділі 00]
duplicate_candidate: README.md (00) — README містить більш детальну структуру
contradictions_with_code: none found (структура відповідає реальному проєкту)
canonical_role: reference (короткий довідник структури)
action: keep
notes: Дуже короткий огляд. Пропускає важливі директорії (nginx/, archive/, docs/) які є в README.md. Практично є дещо скороченою версією секції "Як влаштований notes_chat_app" з README. Але існує як самостійний документ для швидкого огляду. Посилання "Далі: local setup" замість "Далі: prerequisites → local setup" виглядає непослідовно (how_to_use_course.md → repository_structure → local_setup але README починає з prerequisites).
```

---

## 01 Web Foundations

### README.md

```
path: docs/01_web_foundations/README.md
inspection_status: fully inspected
lines: 47
topics: [призначення розділу, HTTP/HTTPS, browser-server lifecycle, практичні завдання трьох рівнів]
level: beginner
has_mermaid: no
has_exercises: yes (3 рівні: мінімальне, основне, advanced challenge)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: mentioned (notes_project/urls.py, notes_app/views.py)
unique_content: [тристопінчаста система завдань: мінімальне/основне/advanced — єдиний README у 01 що структурує завдання так]
duplicate_candidate: none
contradictions_with_code: none found
canonical_role: теорія (навігаційний README для розділу)
action: keep
notes: Чистий навігаційний файл. Вказує лише на 2 документи (http_https.md, browser_server_lifecycle.md) але в розділі є ще 2 великих файли (network_foundation_full.md, network_mermaid_full.md) — вони відсутні у матеріалах README. Потенційна проблема навігації: студент що читає README не дізнається про network_foundation_full.md.
```

---

### browser_server_lifecycle.md

```
path: docs/01_web_foundations/browser_server_lifecycle.md
inspection_status: fully inspected
lines: 46
topics: [browser → DNS → TCP → HTTP → Django → HTML lifecycle, development vs production reverse proxy]
level: beginner
has_mermaid: yes (1 flowchart: Browser → DNS → TCP → HTTP → Django → HTML → Browser)
has_exercises: yes (пояснити чому 127.0.0.1:8000 тільки локально)
has_debugging: no
has_production_notes: yes (згадка reverse proxy перед Django у production)
code_examples: no
notes_chat_app_connection: mentioned (notes_project/wsgi.py, notes_project/asgi.py)
unique_content: [мінімальна Mermaid-схема lifecycle — єдиний компактний візуальний огляд повного ланцюга]
duplicate_candidate: network_foundation_full.md (розділ 10 — Повний lifecycle запиту значно детальніший)
contradictions_with_code: none found
canonical_role: теорія (вступний огляд lifecycle)
action: keep
notes: Дуже короткий — ледве 46 рядків. Є "заглушкою" що веде до більш детального network_foundation_full.md. Шаблонні секції (Що студент вивчить, Передумови) займають майже половину файлу. Mermaid схема дуже спрощена (одна лінія вузлів без деталей). Єдина унікальна думка: "У development runserver приймає HTTP напряму."
```

---

### http_https.md

```
path: docs/01_web_foundations/http_https.md
inspection_status: fully inspected
lines: 47
topics: [HTTP request/response модель, GET/POST у Django, PRG патерн]
level: beginner
has_mermaid: no
has_exercises: yes (знайти view що обробляє GET і POST)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: mentioned (notes_app/urls.py, notes_app/views.py)
unique_content: [PRG (Post/Redirect/Get) згадка на рівні web foundations — раніше ніж у 02_django_core]
duplicate_candidate: network_foundation_full.md (розділ 6 — HTTP детально)
contradictions_with_code: none found
canonical_role: теорія (мінімальний HTTP overview)
action: keep
notes: Аналогічно browser_server_lifecycle.md — дуже короткий шаблонний файл. "Ментальна модель" секція з 2 реченнями. PRG згадка цінна бо з'являється раніше ніж у views_full.md. Зміст значно перекривається з network_foundation_full.md розділ 6 (HTML method table, status codes тощо) але http_https.md не містить кодів статусів і не дублює їх повністю.
```

---

### network_foundation_full.md

```
path: docs/01_web_foundations/network_foundation_full.md
inspection_status: fully inspected
lines: 410
topics: [OSI модель (спрощено), IPv4/IPv6, публічна vs приватна IP, DNS резолюція, DNS записи, порти, TCP handshake, UDP, HTTP request/response структура, HTTP методи, статус-коди, HTTPS/TLS handshake, Python socket API, Unix Domain Sockets, HTTP stateless + cookies/sessions, cookie атрибути (HttpOnly/Secure/SameSite), client-server архітектура, повний lifecycle URL→HTML, REST архітектура, backend під капотом ОС]
level: intermediate
has_mermaid: no (текстові діаграми/ascii, Mermaid схеми у відповідному файлі)
has_exercises: yes (5 питань для самоперевірки)
has_debugging: yes (3 типових помилки: блокуючі запити, stateless misconception, відсутність HTTPS)
has_production_notes: yes (Unix Domain Sockets nginx-uWSGI, HTTPS production, Django не для production без Gunicorn)
code_examples: yes (Python socket API, async httpx view, blocking requests.get антипатерн)
notes_chat_app_connection: none (загальна теорія мережі, не прив'язана до notes_chat_app)
unique_content: [єдиний документ що пояснює Python socket API на низькому рівні, Unix Domain Sockets, детальна DNS резолюція крок за кроком (8 кроків), cookie атрибути з поясненням XSS/CSRF, повна таблиця HTTP методів з idempotency, REST принципи та URL-конвенції, пояснення що відбувається на рівні ОС (NIC → TCP stack → nginx → uWSGI → Django)]
duplicate_candidate: network_mermaid_full.md (є companion-схемами), django_architecture_full.md (частково дублює lifecycle)
contradictions_with_code:
  - У розділі 10 lifecycle згадує "uWSGI" як WSGI сервер ("Nginx передає до uWSGI через Unix socket", "uWSGI перетворює HTTP в Python dict") — але notes_chat_app використовує Uvicorn (ASGI), не uWSGI. Це загальноосвітній приклад, не специфічний для notes_chat_app, але може заплутати студента.
canonical_role: теорія (головний навчальний документ мережевого фундаменту)
action: keep
notes: НАЙЦІННІШИЙ ФАЙЛ РОЗДІЛУ 01. Великий, структурований, педагогічно якісний з аналогіями. Має унікальний контент якого немає ніде в 00-02. Не з'являється у README.md розділу 01 — серйозна проблема навігації. Посилання у django_architecture_full.md (рядок 13) підтверджує що цей файл навмисно є частиною навчальної системи. Використання "uWSGI" в прикладі lifecycle нормальне для загальноосвітнього матеріалу, але потрібна примітка що notes_chat_app використовує Uvicorn.
```

---

### network_mermaid_full.md

```
path: docs/01_web_foundations/network_mermaid_full.md
inspection_status: fully inspected
lines: 323
topics: [11 Mermaid-схем: огляд Інтернету, повний маршрут клієнт→сервер, DNS резолюція sequence, TCP handshake+HTTP+teardown, HTTP request/response lifecycle, HTTPS/TLS handshake sequence, браузер→бекенд→БД граф, socket-комунікація, REST API flow, клієнт-серверна архітектура, IP packets та маршрутизація, OSI довідкова таблиця]
level: intermediate
has_mermaid: yes (11 схем різних типів: flowchart, sequenceDiagram, graph)
has_exercises: no
has_debugging: no
has_production_notes: yes (у схемах: Load Balancer, Celery Workers, Redis)
code_examples: no (тільки Mermaid)
notes_chat_app_connection: none (загальна архітектура, не notes_chat_app специфічна)
unique_content: [11 Mermaid-схем мережевого стеку — найповніша колекція мережевих діаграм у документації, DNS sequence diagram, TCP teardown (FIN sequence), TLS handshake з Certificate Authority, socket комунікація клієнт-сервер]
duplicate_candidate: network_foundation_full.md (схеми є візуалізацією тексту), django_mermaid_full.md (деякі схеми перекриваються — наприклад браузер→бекенд→БД)
contradictions_with_code:
  - Схема 7 (Браузер→Бекенд→БД) показує "uWSGI / Gunicorn" — notes_chat_app використовує Uvicorn. Але це загальноосвітній контекст.
  - REST API Flow схема показує JWT токен авторизацію — notes_chat_app використовує сесії. Контекст general-purpose.
canonical_role: reference (companion до network_foundation_full.md)
action: keep
notes: Companion-файл схем. Цінний для студентів-візуалів. Файл сам по собі немає тексту пояснень — тільки схеми. Рекомендується читати разом з network_foundation_full.md. Не з'являється у README.md розділу 01 — та сама проблема навігації що і network_foundation_full.md.
```

---

## 02 Django Core

### README.md

```
path: docs/02_django_core/README.md
inspection_status: fully inspected
lines: 49
topics: [огляд розділу, перелік матеріалів (3 документи), практичні завдання трьох рівнів]
level: beginner
has_mermaid: no
has_exercises: yes (3 рівні)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: mentioned (notes_project/settings.py, notes_project/urls.py, notes_app/views.py)
unique_content: none
duplicate_candidate: none (навігаційний файл)
contradictions_with_code: none found
canonical_role: теорія (навігаційний README)
action: needs verification
notes: Посилається лише на 3 файли (request_lifecycle.md, urls_and_views.md, wsgi_vs_asgi.md) але у розділі 02 є ще 8 файлів. Студент що читає README не дізнається про django_architecture_full.md, views_full.md, project_structure_full.md тощо — значна навігаційна проблема. Потрібно додати посилання або вказати що повний перелік у django_architecture_full.md.
```

---

### django_command_system.md

```
path: docs/02_django_core/django_command_system.md
inspection_status: fully inspected
lines: 4
topics: [перенаправлення до management_commands_full.md]
level: beginner
has_mermaid: no
has_exercises: no
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: none
unique_content: none (stub/redirect файл)
duplicate_candidate: management_commands_full.md (цей файл є тільки stub)
contradictions_with_code: none
canonical_role: redirect stub
action: archive (або видалити — весь контент у management_commands_full.md)
notes: Файл містить лише 4 рядки — заголовок і посилання. Не несе педагогічної цінності. Якщо є зовнішні посилання на django_command_system.md — потрібен redirect. Якщо ні — можна видалити. Не з'являється у README.md розділу.
```

---

### request_lifecycle.md

```
path: docs/02_django_core/request_lifecycle.md
inspection_status: fully inspected
lines: 48
topics: [request lifecycle flowchart, thin view pattern, View → Selector/Service delegation]
level: beginner
has_mermaid: yes (1 flowchart: Request → Middleware → URLConf → View → Template → Response, + View → Selector/Service гілки)
has_exercises: yes (відкрити note_create і розбити на steps)
has_debugging: no
has_production_notes: no
code_examples: no
notes_chat_app_connection: integrated (notes_project/middleware.py, notes_app/views.py, note_create view)
unique_content: [Mermaid схема що явно показує View → Selector та View → Service гілки — ключова для розуміння архітектури проєкту]
duplicate_candidate: django_architecture_full.md (розділ 4 — детальний lifecycle), django_mermaid_full.md (схема 13 — детальний sequence)
contradictions_with_code: none found
canonical_role: теорія (короткий вступ до lifecycle)
action: keep
notes: Короткий але цінний — Mermaid схема що показує Selector/Service гілки є унікальною в такому компактному вигляді. Посилання на notes_project/middleware.py потребує перевірки (CLAUDE.md згадує DebugExceptionMiddleware як перший middleware, але чи є файл middleware.py окремий?).
```

---

### urls_and_views.md

```
path: docs/02_django_core/urls_and_views.md
inspection_status: fully inspected
lines: 45
topics: [function-based views, path() синтаксис, CBV vs FBV (посилання на архів)]
level: beginner
has_mermaid: no
has_exercises: yes (знайти URL для group chat і відповідний view)
has_debugging: no
has_production_notes: no
code_examples: yes (один рядок path() приклад)
notes_chat_app_connection: integrated (notes_app/urls.py, notes_app/views.py, явно вказує що проєкт використовує FBV)
unique_content: [явна вказівка що notes_chat_app використовує FBV, а CBV збережені в архіві — важливий навігаційний факт для студента]
duplicate_candidate: url_routing_full.md (повний розбір URL routing), views_full.md (повний розбір views)
contradictions_with_code: none found (FBV підтверджено CLAUDE.md: "Views: FBV (функціональні, НЕ CBV у notes_app)")
canonical_role: теорія (короткий вступ до URL/views)
action: keep
notes: Критично важлива вказівка про FBV (не CBV). Але при цьому views_full.md розкриває обидва підходи (FBV і CBV) що може заплутати якщо студент прочитає views_full.md без контексту urls_and_views.md. Практичне завдання "знайти URL для group chat" — хороший ground truth приклад.
```

---

### wsgi_vs_asgi.md

```
path: docs/02_django_core/wsgi_vs_asgi.md
inspection_status: fully inspected
lines: 192
topics: [WSGI vs ASGI таблиця, notes_project/wsgi.py анотований код, notes_project/asgi.py повний анотований код, notes_project/routing.py анотований код, settings.py ASGI секція (daphne, ASGI_APPLICATION, CHANNEL_LAYERS), Docker entrypoint flow, таблиця "коли що змінювати"]
level: intermediate
has_mermaid: no
has_exercises: yes (практичне завдання з docker compose)
has_debugging: no
has_production_notes: yes (entrypoint.sh uvicorn команда, CHANNEL_LAYERS з socket_timeout=None)
code_examples: yes (реальний код з notes_chat_app — wsgi.py, asgi.py, routing.py, settings.py фрагменти)
notes_chat_app_connection: integrated (найбільш "прив'язаний до проєкту" документ у розділі 02 — всі приклади з реального коду)
unique_content: [анотований код asgi.py з поясненнями "що змінювати / що НЕ змінювати", routing.py WebSocket URL pattern, CHANNEL_LAYERS config з socket_timeout=None (це саме той redis timeout bug fix з MEMORY.md), таблиця "коли що змінювати" (HTTP url vs WS url vs Consumer vs Redis config)]
duplicate_candidate: django_architecture_full.md (розділ 8 — WSGI vs ASGI загально), django_mermaid_full.md (схема 9 — WSGI vs ASGI модель конкурентності)
contradictions_with_code:
  - У wsgi.py коментарі: "У notes_chat_app цей файл НЕ використовується в production — ми використовуємо asgi.py і Uvicorn." — відповідає entrypoint.sh ✓
  - entrypoint.sh команда показана коректно: "exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001" ✓
  - settings.py показує 'daphne' першим в INSTALLED_APPS — CLAUDE.md підтверджує ✓
canonical_role: reference (найточніший reference для ASGI/WebSocket архітектури notes_chat_app)
action: keep
notes: НАЙЦІННІШИЙ ФАЙЛ РОЗДІЛУ 02 для розуміння конкретної архітектури notes_chat_app. Реальний код з правильними коментарями. Містить саме той socket_timeout=None fix що зафіксований у MEMORY.md. Посилання на tutorials/07_async.md і 09_async_and_realtime/README.md — потребують перевірки існування.
```

---

### django_architecture_full.md

```
path: docs/02_django_core/django_architecture_full.md
inspection_status: fully inspected
lines: 842
topics: [framework vs library, Django vs Flask vs FastAPI, MVT архітектура, структура Django проєкту, request lifecycle крок за кроком (7 кроків з аналогіями), ORM QuerySet API (CRUD, N+1, select_related), middleware (custom), auth/sessions (login/logout), WSGI vs ASGI (коли що), migrations lifecycle, static files (collectstatic + nginx), production Nginx+Gunicorn config, Docker Compose production приклад, Celery фонові задачі, 13 типових помилок]
level: intermediate
has_mermaid: no (Mermaid схеми у django_mermaid_full.md)
has_exercises: yes (5 питань для самоперевірки)
has_debugging: yes (13 типових помилок: N+1, blocking, logic in templates, middleware order, static files)
has_production_notes: yes (nginx config, gunicorn команди, Docker Compose, collectstatic, DEBUG=False)
code_examples: yes (Python + SQL, django code — models, views, auth, migrations, celery tasks)
notes_chat_app_connection: none (загальна архітектура, приклади з books/Author/Book моделями, не notes_chat_app)
unique_content: [аналогії для кожного кроку (кухар, листоноша, перекладач, тощо) — педагогічний підхід унікальний у цьому файлі, повний Docker Compose production приклад з celery, nginx config з ssl_certificate, Celery on_commit pattern, пояснення чому не можна редагувати застосовані міграції]
duplicate_candidate: project_structure_full.md (структура проєкту), management_commands_full.md (migrations), views_full.md (views), wsgi_vs_asgi.md (ASGI)
contradictions_with_code:
  - Middleware order у прикладі: SecurityMiddleware, SessionMiddleware, CommonMiddleware, CsrfViewMiddleware, AuthenticationMiddleware, MessageMiddleware — але CLAUDE.md вказує реальний порядок: DebugExceptionMiddleware (перший!), debug_toolbar, security, sessions, common, csrf, auth, messages, clickjacking. Файл показує приклад "стандартного" middleware порядку без DebugExceptionMiddleware.
  - Production приклад показує "gunicorn myproject.asgi:application --workers 4 --worker-class uvicorn.workers.UvicornWorker" — notes_chat_app натомість використовує прямо uvicorn (не через gunicorn) згідно entrypoint.sh
  - Celery приклад у розділі 12 — notes_chat_app не має Celery (немає в docker-compose)
canonical_role: теорія (головний навчальний документ Django архітектури — повний курс від нуля)
action: keep
notes: НАЙБІЛЬШИЙ файл розділу 02 (842 рядки). Якісний педагогічний матеріал з аналогіями. Навігаційна таблиця на початку (рядки 9-26) посилається на всі companion документи — робить його хорошим точкою входу. Не прив'язаний до notes_chat_app (приклади з абстрактними models). Middleware order discrepancy некритична для навчання (але варто зазначити у примітці). Celery секція може заплутати студентів notes_chat_app (де celery немає).
```

---

### django_mermaid_full.md

```
path: docs/02_django_core/django_mermaid_full.md
inspection_status: fully inspected
lines: 582
topics: [15 Mermaid-схем: MVT lifecycle, браузер→Django→БД sequence, URL dispatcher flowchart, middleware "цибулина", ORM architecture, структура проєкту, auth flow login/logout, session lifecycle (3 варіанти), WSGI vs ASGI конкурентність, Django+PostgreSQL з'єднання, Django+Redis+Celery, production deployment Nginx+Gunicorn+Docker, детальний request lifecycle sequence, Django Admin архітектура, масштабування з Load Balancer]
level: intermediate
has_mermaid: yes (15 схем)
has_exercises: no
has_debugging: no
has_production_notes: yes (схеми 12, 15 — production архітектура, масштабування)
code_examples: no
notes_chat_app_connection: none (загальні схеми, не notes_chat_app-специфічні)
unique_content: [15 Mermaid схем Django архітектури — найбільша колекція. Session lifecycle (3 схеми різної деталізації), Auth flow sequence, масштабування з LB + PostgreSQL Read Replica + Redis Cluster]
duplicate_candidate: network_mermaid_full.md (перетин схем: браузер→бекенд→БД), django_architecture_full.md (схеми є візуалізацією тексту)
contradictions_with_code:
  - Схема 2 (браузер→Django→БД) показує "Gunicorn/uWSGI" — notes_chat_app використовує Uvicorn
  - Схема 12 показує "Gunicorn Process Manager → Uvicorn Worker" — notes_chat_app використовує standalone uvicorn
  - Схеми 11 і 12 показують Celery workers — notes_chat_app не має Celery
  - Схема 15 (масштабування) показує PostgreSQL Read Replica, LB — рівень вище ніж потрібно для notes_chat_app
canonical_role: reference (companion до django_architecture_full.md)
action: keep
notes: Companion-файл схем. Цінний для візуального засвоєння. Три схеми поспіль про sessions (схема 7 частина, потім окремі flowchart без нумерації рядки 236-287, 327-351) виглядають як незакінчена консолідація — дублюються між собою. Auth flow є найкращою схемою файлу. Production deployment схеми корисні але не відповідають реальному notes_chat_app стеку (gunicorn vs uvicorn).
```

---

### management_commands_full.md

```
path: docs/02_django_core/management_commands_full.md
inspection_status: fully inspected
lines: 409
topics: [таблиця всіх Django команд (22 команди), startproject, startapp, makemigrations, migrate, runserver, createsuperuser, collectstatic, shell, check/check --deploy, власні команди (management/commands/), повний lifecycle від нуля до продакшну, шпаргалки (додати поле, відкотити міграцію, debug ORM, reset all migrations), таблиця типових помилок]
level: beginner-intermediate
has_mermaid: no
has_exercises: no
has_debugging: yes (таблиця типових помилок: 6 помилок з причинами і рішеннями)
has_production_notes: yes (check --deploy аудит безпеки, collectstatic, gunicorn команда)
code_examples: yes (bash, python manage.py commands, migration file example, management command class)
notes_chat_app_connection: none (загальні Django команди, не notes_chat_app-специфічні — але всі команди застосовні)
unique_content: [повна таблиця 22 команд (найповніша в документації), аналогії для кожної команди (ділянка/кімната/архітектор/будівельники), розділ "Від нуля до продакшену" покрокова послідовність, "Скидання всіх міграцій (НЕБЕЗПЕЧНО)" з попередженням, python manage.py migrate myapp zero]
duplicate_candidate: django_architecture_full.md (розділ 9 — migrations, менш детально)
contradictions_with_code:
  - "gunicorn myproject.wsgi:application --workers 4" у кроці 8 "Підготовка до деплою" — notes_chat_app використовує uvicorn не gunicorn. Але це загальний Django lifecycle, не notes_chat_app-специфічний.
canonical_role: reference (повний довідник команд)
action: keep
notes: Добре структурований довідник. Найповніша таблиця команд в документації. "Від нуля до продакшену" послідовність особливо корисна для початківців. Файл django_command_system.md (4 рядки) є redirect stub до цього файлу — треба видалити stub або замінити redirectом.
```

---

### project_structure_full.md

```
path: docs/02_django_core/project_structure_full.md
inspection_status: fully inspected
lines: 534
topics: [стандартна структура файлів, 2 Mermaid схеми (architecture + lifecycle), детальний розбір кожного компонента по таблицях (manage.py, settings.py, wsgi+asgi, urls.py, views.py, apps.py, models.py, migrations, admin.py, templates, static), production-архітектура (bounded context), production структура папок (config/apps/shared/infrastructure), app=bounded context правило, нові файли у production (services/selectors/serializers/tasks/validators/permissions/filters), shared/ абстракції, infrastructure/ інтеграції, порівняльна таблиця навчальна vs production структура]
level: intermediate-advanced
has_mermaid: yes (2 схеми: architecture graph + lifecycle sequence)
has_exercises: no
has_debugging: yes (у таблицях для кожного компонента є "Помилка")
has_production_notes: yes (production структура, shared/, infrastructure/)
code_examples: yes (settings.py фрагменти, services.py, selectors.py, tasks.py, views.py приклади)
notes_chat_app_connection: mentioned (посилання на django_services_full.md, django_selectors_full.md, django_serializers_full.md)
unique_content: [найдетальніший розбір production-архітектури bounded context у розділі 02, shared/ і infrastructure/ шари (відсутні в django_architecture_full.md), таблиці "що компонент НЕ повинен vs ПОВИНЕН" для views.py, приклад flood/dem/ml/papers domains]
duplicate_candidate: django_architecture_full.md (розділ 3 — структура проєкту базово)
contradictions_with_code:
  - views.py приклад показує "FloodEventCreateAPIView(APIView)" з DRF — але notes_chat_app не використовує DRF. Це приклад з GeoHydroAI-V2, не notes_chat_app.
  - Production bounded context структура (apps/flood, apps/dem, apps/ml) — це GeoHydroAI-V2 структура, не notes_chat_app. Може заплутати студента.
canonical_role: reference (advanced reference для production архітектурних патернів)
action: keep
notes: Файл є гібридом: навчальна частина (розбір кожного файлу) цінна для notes_chat_app, але production частина написана під GeoHydroAI-V2 архітектуру. Посилання на ../06_application_architecture/ документи потрібно перевірити. Два Mermaid-схеми дублюють схеми з django_mermaid_full.md але з різним фокусом.
```

---

### url_routing_full.md

```
path: docs/02_django_core/url_routing_full.md
inspection_status: fully inspected
lines: 434
topics: [URL dispatcher механізм (ROOT_URLCONF, urlpatterns, top-down matching, 404), include() і модульний бекенд, path converters (int/slug/str), query strings (request.GET), GET filter chaining, POST обробка з raw request.POST, PRG патерн, Django Forms/ModelForms (is_valid, cleaned_data, form.save()), CreateView CBV, завдання на передбачення URL матчингу]
level: beginner-intermediate
has_mermaid: no
has_exercises: yes (завдання на передбачення — що відбудеться з /api/users/active/ у даних urlpatterns)
has_debugging: yes (пастка "найкращого збігу", дебагінг через 404 сторінку)
has_production_notes: no
code_examples: yes (urls.py, views.py, forms.py, HTML template — повний CRUD flow)
notes_chat_app_connection: none (абстрактні Book/User моделі)
unique_content: [завдання на передбачення URL матчингу (єдине у розділі 02), пояснення чому query strings ігноруються маршрутизатором, детальний розбір що відбувається під .is_valid() (4 кроки), CreateView CBV фінальний розділ]
duplicate_candidate: views_full.md (sections 3, 5, 7 — FBV+Forms+CBV), django_architecture_full.md (розділ 3, URL dispatcher)
contradictions_with_code:
  - CreateView секція (CBV) — urls_and_views.md вказує що notes_chat_app використовує FBV. CreateView є навчальним матеріалом, але може заплутати студента.
  - "Питання для роздумів" у розділі 4 (секція 5) стоїть між розділами 3 і 4 (не в логічному місці в документі)
canonical_role: теорія (повний розбір URL routing + Forms)
action: keep
notes: Довгий і якісний документ. Містить практичне завдання на передбачення URL матчингу — найкращий педагогічний елемент у файлі. CBV/CreateView секція в кінці — важлива для навчання але суперечить "FBV-only" підходу notes_chat_app (що нормально — це навчальний матеріал). Деяке дублювання з views_full.md (Forms/ModelForms). Варто додати примітку що notes_chat_app використовує FBV.
```

---

### views_full.md

```
path: docs/02_django_core/views_full.md
inspection_status: fully inspected
lines: 1075
topics: [View контракт (HttpRequest → callable → HttpResponse), lifecycle sequence (з selectors/services), URL dispatch notes_app приклад, FBV анатомія (note_list, note_create з PRG, note_edit, note_delete), FBV декоратори (@login_required, @require_POST, @permission_required), CBV — навіщо (проблема boilerplate), dispatch() механізм (as_view(), MRO), FBV vs CBV порівняння, as_view() підключення, class attributes override, Generic Views (ListView, DetailView, CreateView, UpdateView, DeleteView), Mixins (LoginRequiredMixin, PermissionRequiredMixin, UserPassesTestMixin, кастомний UserQuerySetMixin), MRO порядок, Forms у views (FBV+Form, FormView, порівняльна таблиця), декорування CBV (URLconf/method_decorator/Mixin), вибір FBV vs CBV flowchart, антипатерни таблиця]
level: intermediate-advanced
has_mermaid: yes (9+ схем: View контракт, lifecycle sequence, URL dispatch flowchart, GET/POST flowchart, dispatch() flowchart, CBV MRO graph, FormView flowchart, FBV vs CBV decision flowchart)
has_exercises: no (окремого практичного завдання немає)
has_debugging: yes (антипатерни таблиця: 8 антипатернів)
has_production_notes: no
code_examples: yes (найбільше Django коду в одному файлі — реальний notes_app code: note_list, note_create, note_edit, note_delete, CBV variants)
notes_chat_app_connection: integrated (реальний notes_app code: views.note_list з selectors.get_user_notes, note_create з services.create_note, URL namespace 'notes_app:', PRG redirect pattern, get_object_or_404 з user=request.user)
unique_content: [реальний код notes_app views (note_list, note_create, note_edit, note_delete) — єдиний документ де є справжній код проєкту, dispatch() internal implementation пояснення, UserQuerySetMixin приклад, формальне пояснення MRO для Mixins, антипатерни таблиця з 8 пунктів включаючи "DELETE через GET"]
duplicate_candidate: url_routing_full.md (Forms, CBV/CreateView), django_architecture_full.md (views section)
contradictions_with_code:
  - Файл містить обширні CBV секції (4-8) але notes_chat_app використовує FBV. Це педагогічно цінно але може заплутати студента якщо читати без контексту urls_and_views.md.
  - notes_app namespace використовується коректно ('notes_app:note_detail') ✓
  - selectors.get_user_notes(), services.create_note() — відповідають реальній архітектурі ✓
  - get_object_or_404(Note, pk=pk, user=request.user) — правильний permission check ✓
canonical_role: теорія (найповніший навчальний документ про views)
action: keep
notes: НАЙБІЛЬШИЙ файл документації (1075 рядків). Поєднує навчальний матеріал (FBV+CBV) з реальним кодом notes_app. Унікальний тим що містить справжній working code views.py проєкту. CBV секції (4-8) розраховані на розуміння Django ecosystem, хоча notes_chat_app не використовує CBV. Варто додати примітку на початку CBV секції що "у notes_chat_app використовуються FBV, CBV — для розуміння екосистеми Django." Посилання на 04_forms_and_validation/django_forms_full.md, 06_application_architecture/ — потребують перевірки.
```

---

## Summary

```
Total files: 21
Fully inspected: 21
```

### Mermaid diagrams found

| Файл | Кількість Mermaid схем |
|------|----------------------|
| browser_server_lifecycle.md | 1 |
| request_lifecycle.md | 1 |
| views_full.md | 9+ |
| network_mermaid_full.md | 11 |
| django_mermaid_full.md | 15 |
| project_structure_full.md | 2 |
| django_architecture_full.md | 0 (схеми у companion файлі) |
| Решта файлів | 0 |

**Разом файлів з Mermaid: 7**

### Exercises found

Файли з практичними завданнями: 11 з 21
(Більшість коротких файлів мають шаблонні "Контрольні питання" але не всі мають унікальні практичні завдання)

Унікальні практичні завдання:
- `local_setup.md` — python manage.py check
- `browser_server_lifecycle.md` — пояснити 127.0.0.1
- `http_https.md` — знайти view з GET і POST
- `repository_structure.md` — знайти шляхи у editor
- `network_foundation_full.md` — 5 питань для самоперевірки
- `request_lifecycle.md` — розбити note_create на steps
- `urls_and_views.md` — знайти group chat URL
- `url_routing_full.md` — завдання на передбачення URL матчингу (найкраще)
- `wsgi_vs_asgi.md` — docker compose практичне завдання

### Contradictions with notes_chat_app code

**КРИТИЧНІ:**
1. `local_setup.md` — описує запуск БЕЗ Docker, але CLAUDE.md вимагає Docker/DATABASE_URL для всіх команд
2. `prerequisites.md` — "Docker не потрібен на старті" суперечить CLAUDE.md

**НЕКРИТИЧНІ (загальноосвітні):**
3. `network_foundation_full.md` (рядок 310-320) — lifecycle приклад показує uWSGI, notes_chat_app використовує Uvicorn
4. `network_mermaid_full.md` — схема 7 показує "uWSGI / Gunicorn"
5. `django_architecture_full.md` — middleware order відрізняється від реального (без DebugExceptionMiddleware), gunicorn у production замість uvicorn, Celery (відсутній у notes_chat_app)
6. `django_mermaid_full.md` — Gunicorn в схемах замість Uvicorn, Celery схема
7. `management_commands_full.md` — gunicorn у lifecycle (загальний приклад)
8. `project_structure_full.md` — приклади з GeoHydroAI-V2 (flood/dem/ml domains, FloodEventCreateAPIView з DRF)
9. `views_full.md` — обширні CBV секції (notes_chat_app використовує FBV)

### Redundant/merge candidates

| Пара | Рекомендація |
|------|-------------|
| `django_command_system.md` (4 рядки) → `management_commands_full.md` | Видалити stub або залишити як redirect |
| `browser_server_lifecycle.md` + `http_https.md` (короткі stub) → відповідні секції `network_foundation_full.md` | Можна залишити як "вступні" але потрібно додати чіткі посилання |
| `django_mermaid_full.md` схеми sessions (3 схеми без заголовків, рядки 236-351) | Консолідувати в одну схему |
| `network_mermaid_full.md` схема 7 та `django_mermaid_full.md` схема 2 | Обидві показують браузер→бекенд→БД, різний рівень деталей — прийнятне дублювання |

### Canonical chapter recommendations

| Тема | Canonical документ |
|------|-------------------|
| Мережевий фундамент | `network_foundation_full.md` (410 рядків, найповніший) |
| Мережеві схеми | `network_mermaid_full.md` (companion) |
| Django архітектура overview | `django_architecture_full.md` (842 рядки, найповніший) |
| Django Mermaid схеми | `django_mermaid_full.md` (15 схем) |
| ASGI/WebSocket notes_chat_app | `wsgi_vs_asgi.md` (реальний код проєкту) |
| Django команди | `management_commands_full.md` (повна таблиця) |
| Project structure | `project_structure_full.md` (production patterns) |
| URL routing + Forms | `url_routing_full.md` |
| Views повний розбір | `views_full.md` (реальний notes_app код) |

### Navigation issues (файли не з'являються у README)

- `network_foundation_full.md` — не у README.md розділу 01
- `network_mermaid_full.md` — не у README.md розділу 01
- 8 файлів `02_django_core/` — не у README.md розділу 02 (тільки 3 з 11 є у README)

### Action summary

| Дія | Файли |
|-----|-------|
| keep | README.md (00), repository_structure.md, how_to_use_course.md, README.md (01), browser_server_lifecycle.md, http_https.md, network_foundation_full.md, network_mermaid_full.md, README.md (02), request_lifecycle.md, urls_and_views.md, wsgi_vs_asgi.md, django_architecture_full.md, django_mermaid_full.md, management_commands_full.md, project_structure_full.md, url_routing_full.md, views_full.md |
| needs verification | how_to_use_course.md (посилання), local_setup.md (Docker warning), prerequisites.md (Docker warning), README.md (02) (навігація), wsgi_vs_asgi.md (посилання) |
| archive | django_command_system.md (stub 4 рядки) |
```
