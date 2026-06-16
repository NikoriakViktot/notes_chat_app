# Науково-педагогічний аналіз
## Курс «Django: від нуля до production» (Notes Chat App)

**Тип:** Внутрішня рецензія курсу  
**Дата:** 2026-06-14  
**Методологія:** [PEDAGOGICAL_ANALYSIS_PLAN.md](PEDAGOGICAL_ANALYSIS_PLAN.md)  
**Об'єкт:** Весь курс — Knowledge Book + Zero to Hero + Notes Chat App Deep Dive

---

## Частина 1. Загальна характеристика курсу

### 1.1. Паспорт курсу

| Параметр | Значення |
|---------|---------|
| **Назва** | Django: від нуля до production (Notes Chat App) |
| **Тип** | Онлайн-підручник у форматі MkDocs (book-format) |
| **Мова** | Українська (студентські матеріали), з кодом і термінами англійською |
| **Цільова аудиторія** | Студенти з базовим Python (функції, класи, списки, словники) |
| **Рівень входу** | Python Beginner + елементарний HTML |
| **Рівень виходу** | Junior Django Developer (production-ready deployment) |
| **Технологічний стек** | Django 5.2, Python 3.12, PostgreSQL 16, Redis 7, Docker Compose, Nginx, GitHub Actions |
| **Репозиторій** | notes_chat_app (єдиний наскрізний проєкт) |

### 1.2. Обсяг курсу

| Шар | Складові | Приблизний обсяг |
|-----|---------|------------------|
| **Knowledge Book** | 10 частин, ~100+ Markdown-файлів | Повна теоретична база |
| **Zero to Hero** | 10 кроків (0–9), ~9 туторіальних файлів | Практичний маршрут побудови |
| **Notes Chat App Deep Dive** | 35 глав, 12+ файлів | Архітектурний розбір |
| **Labs** | 4 лабораторні роботи | Самостійна практика |
| **Reference** | Cheatsheets, команди | Довідники |
| **Загалом** | ~179 Markdown-файлів | Повний курс |

### 1.3. Наскрізний проєкт — Notes Chat App

```text
User ──1:1──► UserProfile
User ──1:N──► Notebook, Note, Tag, TodoList, ShoppingList
Notebook ──1:N──► Note
Note ──M:N──► Tag
Note ──1:N──► Reminder
TodoList ──1:N──► TodoItem
ShoppingList ──1:N──► ShopItem
Group ──1:N──► ChatMessage
```

**9 моделей, ~221 тест у 7 файлах, WebSocket-чат, Celery Worker + Beat, Docker Compose з 8 сервісами.**

### 1.4. Структура трьох шарів

```
┌─────────────────────────────────────┐
│  Knowledge Book (теорія, I–X)       │  ← «Чому?» і «Як це працює?»
├─────────────────────────────────────┤
│  Zero to Hero (покрокова практика)  │  ← «Побудуй це!»
├─────────────────────────────────────┤
│  Notes Chat App Deep Dive           │  ← «Ось як це зроблено у prod»
└─────────────────────────────────────┘
           ↕ cross-references ↕
```

---

## Частина 2. Аналіз відповідності дидактичним принципам

### К1. Науковість змісту — **5/5**

**Реалізація:** Курс використовує актуальні технології (Django 5.2, Python 3.12, PostgreSQL 16, Redis 7, Docker Compose). Технічні твердження верифіковані реальним кодом (221 тест у CI). Жодних застарілих API (deprecated `url()`, `render_to_response()` тощо не використовуються). Термінологія відповідає офіційній документації Django.

**Докази:**
- `notes_project/settings.py` — правильний порядок MIDDLEWARE зі SecurityMiddleware першим (виправлено у Batch N)
- `database_sync_to_async` + `list()` матеріалізація — коректний async-ORM паттерн
- Q-scoped selectors — стандартний Django-підхід до object-level permissions
- `TransactionTestCase` для consumer tests — необхідна і правильно пояснена різниця

**Зауваження:** Serializers і Celery присутні у Knowledge Book (Частина VI), але не реалізовані у проєкті. Це явно задокументовано як межа курсу — правильне рішення.

---

### К2. Логічна послідовність тем — **5/5**

**Реалізація:** Курс має чітко виражену залежнісну структуру. CURRICULUM_MATRIX.md документує prerequisites для кожної теми. LEARNING_PATH.md задає 10 послідовних кроків. TEACHING_GUIDE.md — три маршрути для різних сценаріїв.

**Scaffolding-ланцюжки (перевірено):**

```
HTTP (I) → Django lifecycle (II) → Views (II) → Models/ORM (III)
→ Forms (IV) → Templates (V) → Services/Selectors (VI)
→ Auth (VII) → Testing (VIII) → Async/WebSocket (IX) → Deployment (X)
```

**Критичні залежності задокументовані:**
```
IDOR prevention → requires: AuthN + Q objects
TransactionTestCase → requires: TestCase + asyncio basics
database_sync_to_async → requires: asyncio + ORM
Redis channel layer → requires: Docker + Channels
```

**Зауваження:** Частини IV (Forms) і V (Templates) могли б мати зворотну послідовність — Templates є передумовою для розуміння Forms (форма рендерується у шаблоні). Поточний порядок педагогічно виправданий (форма → шаблон як два кроки одного фіча), але варто додати cross-reference.

---

### К3. Доступність викладу (ZPD) — **4/5**

**Реалізація:** Курс починається з абсолютних основ (HTTP, TCP/IP, DNS), поступово нарощує складність. Кожна Part README містить розділ «Передумови» та рівень складності (Foundation / Beginner / Intermediate / Advanced / Production).

**Позитивне:**
- Різниця між `@login_required` (AuthN) і object-level permissions (AuthZ) — пояснена з конкретним прикладом IDOR-помилки
- `TransactionTestCase` vs `TestCase` — пояснено «чому» (transaction isolation), не лише «що»
- Fat view → thin view — показано дві версії одного коду зі поясненням мотивації

**Зауваження (−1):** 
- Перехід від Кроку 2 (перша модель) до Кроку 3 (CRUD + ORM + select_related + Q-filters + Selectors) — значний стрибок складності. Рекомендується додатковий проміжний крок або чіткіший scaffolding.
- Async (Частина IX) потребує asyncio + ASGI + Channels + Redis + database_sync_to_async — можливо занадто щільно для одного модуля.

---

### К4. Наочність — **5/5**

**Реалізація:** Кожна Part README містить:
- Mermaid-діаграми (sequence, flowchart, ER)
- Кодові приклади у форматі «❌ неправильно / ✅ правильно»
- ASCII-схеми для архітектурних концепцій
- Порівняльні таблиці (FBV vs CBV, TestCase vs TransactionTestCase, polling vs WebSocket)

**Конкретні приклади:**
- Частина I: Mermaid sequence diagram Browser → Nginx → Daphne → views → PostgreSQL
- Частина VII: IDOR вразливий код vs Q-scoped selector
- Частина VIII: тестова піраміда у ASCII
- Частина IX: polling (100 req/s) vs WebSocket (100 persistent connections) — текстова порівняльна схема
- Deep Dive: Mermaid архітектурна діаграма всього застосунку

---

### К5. Зв'язок теорії з практикою — **5/5**

**Реалізація:** Це один із найсильніших аспектів курсу. Кожна Part README має секцію «Де це у Notes Chat App» з таблицею реальних файлів. CURRICULUM_MATRIX.md пов'язує кожну тему з конкретними файлами Knowledge Book, кроком Zero to Hero і главою Deep Dive.

**Приклади зв'язків:**

| Теоретична концепція | Реальний файл Notes Chat App |
|---------------------|------------------------------|
| Q-filter + IDOR | `notes_app/selectors.py` → `Q(user=user) \| Q(group__in=...)` |
| `database_sync_to_async` | `notes_app/consumers.py` → `GroupChatConsumer` |
| `TransactionTestCase` | `notes_app/tests/test_consumers.py` |
| ASGI import order | `notes_project/asgi.py` |
| SecurityMiddleware першим | `notes_project/settings.py` |
| `socket_timeout=None` | `notes_project/settings.py` → `CHANNEL_LAYERS` |

**Зауваження:** Деякі теми Knowledge Book (Celery, Serializers, Kubernetes) не мають відповідного рядка у Notes Chat App. Це правильно задокументовано як межа курсу.

---

### К6. Активізація пізнавальної діяльності — **4/5**

**Реалізація:** Курс має декілька механізмів активізації:

1. **Контрольні питання** — кожна Part README закінчується 6–7 запитаннями на розуміння
2. **Практичні завдання** — у секції «Практика» кожної частини (3–5 конкретних завдань)
3. **Labs** — 4 лабораторні роботи без готового рішення: ORM Lab, Forms Lab, Testing Lab, Async Lab
4. **Zero to Hero** — покрокова побудова з критеріями завершення на кожному кроці
5. **LEARNING_PATH.md** — 10 контрольних точок з конкретними перевіряємими навичками

**Зауваження (−1):**
- Немає формальної системи самооцінювання (rubric, checklist з балами)
- Labs не мають автоматичної перевірки (студент запускає тести сам, але немає CI для Labs)
- Домашні завдання у TEACHING_GUIDE.md описані, але не структуровані як окремі документи

---

### К7. Міцність засвоєння — **4/5**

**Реалізація:** Курс реалізує спіральне повернення до тем:

**Spiraling (ключові теми повертаються):**
```
ORM → з'являється у кожному наступному кроці
Auth → вводиться у Частині VII → повертається у Частині VIII (IDOR tests), IX (check_membership)
Testing → вводиться у Частині VIII → застосовується у Частині IX (consumer tests)
Docker → вводиться у Частині X → фіксується у Deep Dive (Ch.30)
```

**Cross-references між шарами:**
- Кожна Part README посилається на відповідні Zero to Hero кроки
- Deep Dive посилається на Knowledge Book глави

**Зауваження (−1):**
- Немає явних «recap»-секцій на початку модулів («у попередній частині ми дізналися...»)
- Немає кумулятивних тестів / checkpoint quizzes між модулями

---

### К8. Диференціація (індивідуалізація) — **4/5**

**Реалізація:**

1. **Три маршрути** (TEACHING_GUIDE.md):
   - Короткий (7 тем) — для швидкого старту
   - Стандартний (+services/selectors, query opt, Selenium, CI, WebSocket)
   - Повний (+web foundations, Linux, Docker, deployment security)

2. **Рівні складності** в кожній темі (Foundation → Beginner → Intermediate → Advanced → Production)

3. **LEARNING_PATH.md** — студент може стартувати з будь-якого місця («якщо вам потрібен лише проєкт, переходьте до `12_final_project`»)

4. **Що можна пропустити** у скороченому курсі — явно задокументовано в TEACHING_GUIDE.md

**Зауваження (−1):**
- Немає адаптивних матеріалів (окремих глав «для початківців» і «для досвідчених» на одну тему)
- Немає explicit маршруту для тих, хто вже знає Flask або FastAPI

---

### К9. Повнота охоплення тематики — **4/5**

**Охоплені теми (34+ з CURRICULUM_MATRIX.md):**

```
HTTP, DNS, TCP/TLS ✓
Django lifecycle, URL, Views, Middleware ✓
Models, ORM, Q objects, select_related ✓
Transactions, Indexes, PostgreSQL ✓
Forms, ModelForm, validation ✓
Templates, inheritance, Bootstrap ✓
Services, Selectors pattern ✓
Authentication, Sessions ✓
Authorization, IDOR, OWASP Top 10 ✓
Testing pyramid, TestCase, TransactionTestCase, Selenium, CI ✓
asyncio, ASGI, Channels, WebSocket, database_sync_to_async ✓
Linux, Docker, Docker Compose, Nginx, Deployment ✓
```

**Зауваження (−1) — поза межами курсу (явно задекларовано):**
```
REST API / DRF — не охоплено (задекларована межа)
GraphQL — не охоплено
Celery (background tasks) — ✅ реалізовано у коді (tasks.py, celery.py, docker-compose) + задокументовано (08_celery.md, background_tasks.md)
Kubernetes — лише концептуально (огляд)
Accessibility (a11y) — не охоплено
```

Ці прогалини є свідомим рішенням (documented scope), а не недоліком.

---

### К10. Актуальність — **5/5**

**Реалізація:**

| Технологія | Версія у курсі | Актуальність |
|-----------|---------------|-------------|
| Django | 5.2 | ✅ Остання LTS (2025) |
| Python | 3.12 | ✅ Остання стабільна |
| PostgreSQL | 16 | ✅ Поточна стабільна |
| Redis | 7 | ✅ Поточна стабільна |
| Docker Compose | v2 | ✅ Актуальна версія |
| GitHub Actions | v4 checkout | ✅ Актуальна версія |
| Bootstrap | 5 | ✅ Поточна версія |

**Практики:** selectors/services паттерн, Q-scoped IDOR захист, `database_sync_to_async` — усе відповідає рекомендаціям Django-спільноти.

---

### Зведена таблиця оцінок

| Критерій | Бал | Рівень |
|---------|-----|--------|
| К1. Науковість | **5/5** | Відмінно |
| К2. Послідовність | **5/5** | Відмінно |
| К3. Доступність | **4/5** | Добре |
| К4. Наочність | **5/5** | Відмінно |
| К5. Теорія-практика | **5/5** | Відмінно |
| К6. Активізація | **4/5** | Добре |
| К7. Міцність | **4/5** | Добре |
| К8. Диференціація | **4/5** | Добре |
| К9. Повнота | **4/5** | Добре |
| К10. Актуальність | **5/5** | Відмінно |
| **Загальна оцінка** | **4.5/5** | **Відмінно** |

---

## Частина 3. Таксономічний аналіз за Блумом

### 3.1. Матриця: Модуль × Когнітивний рівень

| Модуль / Шар | Знання | Розуміння | Застосування | Аналіз | Синтез | Оцінювання |
|-------------|--------|-----------|--------------|--------|--------|------------|
| Knowledge Book | ✅✅ | ✅✅ | ✅ | ✅ | — | — |
| Zero to Hero | ✅ | ✅ | ✅✅ | ✅ | ✅✅ | — |
| Deep Dive | — | ✅✅ | — | ✅✅ | — | ✅ |
| Labs | — | ✅ | ✅✅ | ✅✅ | ✅✅ | ✅ |
| TEACHING_GUIDE | — | — | — | ✅ | — | ✅✅ |

*✅✅ = домінантний рівень, ✅ = присутній*

### 3.2. Аналіз по рівнях

**Рівні 1–2 (Знання + Розуміння) — Добре охоплені:**
- Knowledge Book: визначення термінів, пояснення концепцій
- Контрольні питання перевіряють розуміння («Що таке IDOR? Чому `@login_required` недостатній?»)
- Mermaid-діаграми формують концептуальне розуміння

**Рівень 3 (Застосування) — Відмінно охоплений:**
- Zero to Hero: кожен крок = нова фіча, яку студент реалізує
- Labs: самостійне написання тестів, query optimization, async consumer

**Рівень 4 (Аналіз) — Добре охоплений:**
- Порівняльні таблиці (FBV vs CBV, polling vs WebSocket, TestCase vs TransactionTestCase)
- «❌ вразливо / ✅ безпечно» паттерн — примушує до аналізу різниці
- Deep Dive: аналіз реального кодобази

**Рівень 5 (Синтез/Створення) — Частково охоплений:**
- Zero to Hero Крок 5–8: студент будує auth, testing, async, deployment самостійно
- Labs: написати тест з нуля, написати consumer
- **Прогалина:** немає завдання «спроєктуй нову фічу з нуля» (лише розширення існуючого)

**Рівень 6 (Оцінювання) — Мінімально охоплений:**
- TEACHING_GUIDE.md (для викладача) включає критерії оцінювання проєкту
- Deep Dive описує трейдофи (FBV vs CBV, in-memory vs Redis channel layer)
- **Прогалина:** немає явних завдань «оціни цей підхід», «порівняй і обери кращий»

### 3.3. Висновок з таксономії

Курс добре охоплює рівні 1–4. Рівень 5 (Синтез) присутній у Labs і Zero to Hero, але без відкритих завдань «спроєктуй з нуля». Рівень 6 (Оцінювання) представлений найслабше — потребує додавання критичних дискусійних завдань.

---

## Частина 4. Аналіз Scaffolding-структури

### 4.1. Загальна структура scaffolding

```
Крок 0: Середовище              ← max support (вся конфігурація готова)
Крок 1: hello_project           ← full scaffold (router, view, template — усе показано)
Крок 2: bootstrap_notes         ← guided scaffold (модель додається крок за кроком)
Крок 3: CRUD / Selectors        ← partial scaffold (паттерни показані, студент адаптує)
Крок 4: Forms/Bootstrap         ← partial scaffold
Крок 5: Auth/Notes Chat App     ← minimal scaffold (структура відома, реалізація — студент)
Крок 6: Testing                 ← minimal scaffold (AAA паттерн показаний, тести — студент)
Крок 7: Async/WebSocket         ← guided (consumer lifecycle детально), решта — студент
Крок 8: Docker/Deployment       ← partial scaffold (Dockerfile готовий, налаштування — студент)
Labs                            ← no scaffold (самостійно, тільки вимога + перевірка тестами)
```

**Висновок:** Класична scaffolding-крива: максимальна підтримка на початку, поступове зниження до самостійності.

### 4.2. Критичні переходи (ZPD-перевірка)

| Перехід | ZPD-оцінка | Примітка |
|---------|-----------|---------|
| HTTP → Django lifecycle | ✅ плавний | Mermaid-діаграма пояснює зв'язок |
| Models → QuerySet laziness | ✅ виправлено | Додано §«Lazy evaluation — покроковий розбір» у docs/03 README + bridge §«Зв'язок з lazy evaluation» перед N+1 у tutorial 03_crud.md |
| Fat view → Selectors/Services | ✅ плавний | Показано ❌/✅ прикладом |
| TestCase → TransactionTestCase | ✅ пояснений | Причина (transaction isolation) задокументована |
| asyncio → ASGI → Channels | ✅ виправлено | Додано §«Концептуальний місток: asyncio → ASGI → Channels» у docs/09 README — таблиця залежностей + WSGI vs ASGI порівняння |
| Docker → Nginx → Production | ✅ покрокові | entrypoint.sh крок за кроком |

### 4.3. Педагогічна еволюція наскрізного проєкту

```
hello_project       — навчальний: один view, SQLite
bootstrap_notes     — навчальний: перша модель, migrate
notes_project       — навчальний: CRUD, ORM, selectors зачаток
crispy_notes        — навчальний: forms, Bootstrap, PRG
notes_chat_app      ← PRODUCTION: auth + permissions + tests + WebSocket + Docker
```

Курс **явно позначає** ці переходи між standalone-проєктами — важливий педагогічний прийом.

---

## Частина 5. Theory-Practice-Assessment Ratio

### 5.1. Оцінка балансу по шарах

| Шар | Тип | Оцінка |
|-----|-----|--------|
| Knowledge Book | ~80% теорія, ~20% mini-code examples | Здебільшого теорія |
| Zero to Hero | ~30% теорія, ~70% практика (guided) | Здебільшого практика |
| Deep Dive | ~40% теорія, ~60% аналіз коду | Аналітична практика |
| Labs | ~5% теорія, ~95% практика (unguided) | Повна самостійність |
| Контрольні питання | Контроль розуміння | Рефлексія |

### 5.2. Загальний баланс курсу

```
Теорія (Knowledge Book):              ~45%
Guided практика (Zero to Hero):       ~30%
Аналіз (Deep Dive):                   ~15%
Самостійна практика (Labs):           ~10%
Контроль (контрольні питання):        ~5% (частково перекривається)
```

**Оцінка:** Баланс є розумним для технічного курсу. Knowledge Book (теорія) займає найбільшу частку, що виправдано — студент повинен мати теоретичну базу перед реалізацією.

**Рекомендація:** Збільшити частку Labs (4 → 6–8) для рівня 5–6 Блума.

---

## Частина 6. SWOT-аналіз

### 6.1. Матриця

| | Позитивне | Негативне |
|-|-----------|-----------|
| **Внутрішні** | **Сильні сторони** | **Слабкі сторони** |
| | Єдиний наскрізний проєкт (Notes Chat App) | Відсутність формальної системи оцінювання |
| | Точна відповідність теорії реальному коду | Щільний перехід до async-концептів |
| | 221 тест у CI верифікують точність | Мало рівня 6 (Оцінювання) за Блумом |
| | Триша-шарова структура (theory/practice/dive) | Деякі теми (DRF, Signals) присутні теоретично, але не реалізовані |
| | Три маршрути для різних сценаріїв | Немає recap/checkpoint між модулями |
| | Mermaid-діаграми і ❌/✅ паттерни | MkDocs-навігація потребує валідації |
| **Зовнішні** | **Можливості** | **Загрози** |
| | Розширення Labs (більше самостійних завдань) | Швидкий розвиток Django (5.3 очікується) |
| | Додавання DRF-модуля як опційного | Python 3.13 → можливі зміни async |
| | Відеолекції до кожної частини | Конкуренція з англомовними курсами (Django Girls, Real Python) |
| | Платформа (Moodle, OpenEDX) для tracking | Студенти можуть пропускати теорію заради Zero to Hero |
| | Community (Discord/Telegram) для peer review | Відсутність живого feedback без студентів |

---

## Частина 7. Gap-аналіз

### 7.1. Що є і що відсутнє

| Тема | Статус | Коментар |
|------|--------|---------|
| Django REST Framework | ❌ Відсутній | Задекларована межа. Потребує окремого модуля |
| GraphQL | ❌ Відсутній | Поза межами; не критично |
| Celery (background tasks) | ✅ Реалізовано | tasks.py + celery.py + docker-compose; туторіал `08_celery.md`; розділ `background_tasks.md` у Deep Dive |
| Kubernetes | ⚠️ Тільки огляд | Частина X: концептуально, без практики |
| Accessibility (a11y) | ❌ Відсутній | Не охоплено навіть теоретично |
| Cache (Django cache framework) | ❌ Відсутній | Не охоплено |
| Signals | ❌ Відсутній | Не охоплено |
| Custom middleware | ⚠️ Частково | DebugExceptionMiddleware є у проєкті, але не задокументована як самостійна тема |
| Email (SMTP) | ✅ Реалізовано | `send_mail()` у tasks.py; `console.EmailBackend` у dev; `locmem.EmailBackend` + `mail.outbox` у тестах; задокументовано у `08_celery.md` |
| Paginiation | ❌ Відсутній | Не перевірено у Phase II |
| Формальна rubric для оцінювання | ❌ Відсутня | Є критерії у TEACHING_GUIDE, але не рубрика |
| Checkpoint quizzes | ❌ Відсутні | Немає між-модульного контролю |

### 7.2. Пріоритизація прогалин

| Прогалина | Критичність | Обґрунтування |
|-----------|------------|---------------|
| Формальна rubric | **High** | Без неї студент не знає, як оцінити свою роботу |
| DRF базовий модуль | **Medium** | Більшість Django-позицій потребують API |
| Celery практика | ~~**Medium**~~ **Виконано** | Реалізовано: `tasks.py`, `08_celery.md`, `background_tasks.md`, 221 тест |
| Checkpoint quizzes | **Medium** | Допомагає закріпити знання |
| Accessibility | **Low** | Важливо, але поза зоною курсу |
| Cache framework | **Low** | Доречно у Module+ версії |

### 7.3. Зачепки у проєкті

Для кожної прогалини — конкретне місце в Notes Chat App, де тема «чіпляється» до наявного коду. Це не повна реалізація, а точка входу: звідки починати, якщо розширювати курс.

---

#### Celery (background tasks) — повний flow

**Чому тут:** Модель `Reminder` (`notes_app/models.py`) має поля `remind_at` і `is_sent=False`, але жоден код ніколи не встановлює `is_sent=True`. Celery Beat — природна відповідь.

**Повний ланцюжок:**

```
Reminder.remind_at (DateTime) + is_sent=False
    ↓
Celery Beat (scheduler, кожну хвилину)
    ↓
@shared_task send_reminder_notifications()
    ↓ Reminder.objects.filter(remind_at__lte=now, is_sent=False)
    ↓ for reminder: send_mail()  ←── або channel_layer.group_send() (WebSocket push)
    ↓ reminder.is_sent = True; reminder.save(update_fields=['is_sent'])
```

**`notes_project/celery.py`** (новий файл):

```python
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
app = Celery('notes_project')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
```

**`notes_app/tasks.py`** (новий файл):

```python
from celery import shared_task
from django.utils import timezone
from .models import Reminder

@shared_task
def send_reminder_notifications():
    now = timezone.now()
    pending = Reminder.objects.select_related('note__user').filter(
        remind_at__lte=now, is_sent=False
    )
    for reminder in pending:
        # Тут: send_mail() або channel_layer.group_send()
        reminder.is_sent = True
        reminder.save(update_fields=['is_sent'])
```

**Додати у `notes_project/settings.py`:**

```python
CELERY_BROKER_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
CELERY_BEAT_SCHEDULE = {
    'send-reminders-every-minute': {
        'task': 'notes_app.tasks.send_reminder_notifications',
        'schedule': 60.0,
    },
}
```

**Додати у `docker-compose.yml`:**

```yaml
celery-worker:
  build: .
  command: celery -A notes_project worker -l info
  env_file: .env
  depends_on: [db, redis]

celery-beat:
  build: .
  command: celery -A notes_project beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
  env_file: .env
  depends_on: [db, redis]
```

Redis вже є у `docker-compose.yml` — жодного нового сервісу не потрібно для брокера.

---

#### Django REST Framework

**Чому тут:** `selectors.py` вже ізолює всі read-запити. Кожна функція = один DRF endpoint.

**Зачепка:** `get_notes_for_user()` → `NoteListAPIView`:

```python
# notes_app/api/views.py
from rest_framework import generics
from . import selectors, serializers

class NoteListAPIView(generics.ListAPIView):
    serializer_class = serializers.NoteSerializer

    def get_queryset(self):
        return selectors.get_notes_for_user(user=self.request.user)
```

Паттерн повторюється для всіх 13+ функцій `selectors.py` — архітектура вже підготовлена.

---

#### Signals

**Чому тут:** `UserProfile` (`notes_app/models.py:24`) зараз створюється тільки в `seed_demo_data` management command — нові реальні юзери профілю не отримують. Це класичний баг, який signals вирішують.

**Зачепка:**

```python
# notes_app/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import UserProfile

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.get_or_create(user=instance)
```

```python
# notes_app/apps.py
class NotesAppConfig(AppConfig):
    def ready(self):
        import notes_app.signals  # noqa: F401
```

Другий use case: `post_save` на `Note` — автоматично створити тег «без теґу» або перший `Reminder`.

---

#### Email (SMTP)

**Чому тут:** Celery task `send_reminder_notifications` (вище) — природне місце для `send_mail()`. Поле `Reminder.note.user.email` вже доступне через `select_related`.

**Зачепка:**

```python
from django.core.mail import send_mail
from django.conf import settings

send_mail(
    subject=f'Нагадування: {reminder.note.title}',
    message=reminder.message or 'Час вашого нагадування!',
    from_email=settings.DEFAULT_FROM_EMAIL,
    recipient_list=[reminder.note.user.email],
    fail_silently=True,
)
```

**Dev-сервер для SMTP:** Mailhog у `docker-compose.yml`:

```yaml
mailhog:
  image: mailhog/mailhog
  ports:
    - "8025:8025"
```

```python
# settings.py (dev)
EMAIL_HOST = 'mailhog'
EMAIL_PORT = 1025
```

---

#### Cache (Django cache framework)

**Чому тут:** `get_notes_for_user()` у `selectors.py` викликається при кожному `GET /notes/` — часто, результат стабільний між запитами одного юзера.

**Зачепка:**

```python
# selectors.py
from django.core.cache import cache

def get_notes_for_user(user):
    key = f'notes_user_{user.pk}'
    result = cache.get(key)
    if result is None:
        result = list(
            Note.objects.filter(user=user)
            .select_related('notebook')
            .prefetch_related('tags')
            .order_by('-updated_at')
        )
        cache.set(key, result, timeout=60)
    return result
```

Redis вже є у `docker-compose.yml`. Достатньо додати в `settings.py`:

```python
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://redis:6379/1'),
    }
}
```

(db `1` замість `0` — щоб не конфліктувати з Channel Layer)

---

#### Pagination

**Чому тут:** `notes_list` view (`notes_app/views.py`) повертає всі нотатки одразу. При 500+ нотатках — performance issue.

**Зачепка:**

```python
# views.py
from django.core.paginator import Paginator

@login_required
def notes_list(request):
    qs = selectors.get_notes_for_user(user=request.user)
    paginator = Paginator(qs, per_page=20)
    page_obj = paginator.get_page(request.GET.get('page'))
    return render(request, 'notes_app/notes_list.html', {'page_obj': page_obj})
```

У шаблоні — стандартний Bootstrap pagination block з `page_obj.has_previous`, `page_obj.has_next`.

---

#### Custom middleware

**Чому тут:** `DebugExceptionMiddleware` вже існує у `notes_project/middleware.py` — реальний, робочий middleware у проєкті, але не використовується як педагогічний приклад.

**Структура для документування:**

```python
# notes_project/middleware.py
class DebugExceptionMiddleware:
    def __init__(self, get_response):   # 1. ініціалізація
        self.get_response = get_response

    def __call__(self, request):         # 2. обробка кожного запиту
        try:
            response = self.get_response(request)
            if response.status_code == 500:
                print(f"[MW 500] {request.method} {request.path}")
            return response
        except Exception as exc:
            tb = traceback.format_exc()
            print(f"[MW EXCEPTION] {exc}")
            return HttpResponse(f"<pre>{tb}</pre>", status=500)
```

Реєстрація в `MIDDLEWARE` (тільки у DEBUG-режимі): `settings.py:73–75`.

---

#### Kubernetes

**Де використовується:** Замінює `docker-compose.yml` у production при горизонтальному масштабуванні.

**Прямий маппінг з docker-compose.yml:**

| docker-compose service | Kubernetes об'єкт |
|------------------------|-------------------|
| `web` (Django) | `Deployment` + `Service` (ClusterIP) |
| `redis` | `StatefulSet` + `PersistentVolumeClaim` |
| `nginx` | `Ingress` + `Service` (LoadBalancer) |
| `celery-worker` | `Deployment` (replicas: N, auto-scaling) |
| `celery-beat` | `Deployment` (replicas: 1 — beat не масштабується) |
| `db` (PostgreSQL) | Зазвичай managed (RDS, Cloud SQL) — не в K8s |

Docker Compose конфіг у проєкті є готовою основою для написання K8s YAML.

---

#### GraphQL

**Де використовується:** Коли SPA або мобільний клієнт хоче гнучко вибирати поля (замість REST, де endpoint фіксує форму відповіді).

**Зачепка у проєкті:** Граф `Note → Tags (M:N) → Reminders (1:N)` — ідеальна ієрархія для GraphQL.

```python
# notes_app/schema.py (Strawberry)
import strawberry
from .models import Note

@strawberry.django.type(Note)
class NoteType:
    id: strawberry.auto
    title: strawberry.auto
    tags: list['TagType']
    reminders: list['ReminderType']
```

Бібліотека: `strawberry-graphql[django]`. Альтернатива: `graphene-django`.

---

#### Accessibility (a11y)

**Де використовується:** Будь-який публічний веб-застосунок — вимога WCAG 2.1 (законодавча в ЄС з 2025).

**Зачепка у проєкті:** Bootstrap 5 шаблони вже є. Додається без змін Python коду:

```html
{# templates/notes_app/notes_list.html #}
<button aria-label="Видалити нотатку {{ note.title }}">🗑</button>

<nav aria-label="Пагінація нотаток">
  {% include "partials/pagination.html" %}
</nav>

<main id="main-content" tabindex="-1">...</main>
```

Перевірка: браузерне розширення axe DevTools або Lighthouse audit.

---

#### Формальна rubric для оцінювання

**Де:** `docs/_internal/ASSESSMENT_RUBRIC.md` (окремий файл, не прив'язаний до коду).

**Структура:** категорії (Models, Services, Tests, Security, Deployment) × рівні (0–4) × ваги.

---

#### Checkpoint quizzes

**Де:** 5–10 запитань у кінці кожного Part README.

**Формат (Markdown):**
```markdown
## Контрольні питання

1. Яка різниця між `TestCase` і `TransactionTestCase`?
2. Чому `@login_required` не захищає від IDOR?
3. Що відбудеться, якщо не викликати `list()` у `database_sync_to_async`?
```

**Автоматизація:** Google Forms із результатами до Google Sheets — без змін у MkDocs.

---

## Частина 8. Висновки

### 8.1. Загальна оцінка

| Параметр | Оцінка |
|---------|--------|
| Середня оцінка за 10 критеріями | **4.5 / 5** |
| Таксономічне покриття (Блум 1–6) | **Рівні 1–4 відмінно, 5 добре, 6 задовільно** |
| Scaffolding-структура | **Класична, коректна** |
| Theory-Practice balance | **Помірний → теорія переважає (прийнятно)** |
| Наявність gaps | **5 незначних, 1 значний (rubric)** |

### 8.2. Рейтинг шарів

| Місце | Шар | Сильні сторони |
|-------|-----|----------------|
| 🥇 1 | **Knowledge Book** | Найповніший, найточніший, Mermaid-діаграми, ❌/✅ паттерни |
| 🥈 2 | **Notes Chat App Deep Dive** | Відмінна прив'язка до реального коду, вичерпний архітектурний розбір |
| 🥉 3 | **Zero to Hero** | Покрокова практика, але деякі кроки щільні |
| — | **Labs** | Невеликі за обсягом, але цінні — потребують розширення |

### 8.3. Ключові переваги курсу

1. **Єдиний наскрізний проєкт** — студент будує реальну систему, не вправляється на toy examples
2. **Тришарова структура** — теорія / практика / архітектурний розбір взаємопосилаються
3. **221 тест у CI** — курс верифікований на точність автоматично
4. **Україномовний** — заповнює нішу україномовних технічних ресурсів
5. **Production-grade стек** — Django 5.2, PostgreSQL, Redis, Docker, GitHub Actions
6. **IDOR → безпека** — увага до security на рівні архітектури, а не лише як параграф
7. **Async як перша категорія** — WebSocket і Channels не є afterthought, а повноцінна частина
8. **Scaffolding-еволюція** — явне маркування переходів між навчальними проєктами

### 8.4. Ключові точки вдосконалення

1. Відсутність формальної rubric для оцінювання студентських робіт
2. Рівень 6 Блума (Оцінювання) не охоплений явно
3. Складний перехід: Крок 2 → Крок 3 і asyncio → ASGI → Channels
4. Labs можна розширити з 4 до 6–8

---

## Частина 9. Рекомендації

### Пріоритет High (критично для якості навчання)

**Р1. Формальна rubric для оцінювання**
- Додати до TEACHING_GUIDE.md структуровану рубрику: категорії (models/services/tests/security/deployment), критерії і бали
- Чому: без rubric студент не може самооцінити роботу; викладач не має єдиного стандарту
- Файл: `docs/TEACHING_GUIDE.md` або новий `docs/_internal/ASSESSMENT_RUBRIC.md`

**Р2. Checkpoint між Кроком 2 і Кроком 3**
- Додати проміжний mini-lab або розбити Крок 3 на 3a (базовий CRUD) і 3b (selectors/services)
- Чому: стрибок від «першої моделі» до «N+1 оптимізація + Q-filters + Selectors» занадто великий

**Р3. Явні завдання рівня 6 Блума (Оцінювання)**
- Додати у Labs або Zero to Hero секції типу «Compare and Decide»:
  - «Чому цей проєкт використовує FBV замість CBV? Що б ви змінили і чому?»
  - «Оціни безпеку цього view — знайди вразливість»
  - «Який підхід до тестування обрати: pytest vs unittest?»

### Пріоритет Medium (покращить досвід студента)

**Р4. Recap-секції на початку модулів**
- Додати коротке «У попередній частині ми...» + «Що нам це дає тут» на початок Part README
- Підсилює міцність засвоєння (К7)

**Р5. Checkpoint quizzes між частинами**
- 5–10 запитань після кожної частини Knowledge Book (можна у форматі Markdown)
- Варіант: Google Forms або embedded quiz у MkDocs

**Р6. Маршрут для тих, хто знає Flask/FastAPI**
- Додати до TEACHING_GUIDE.md секцію «Якщо ви знаєте Flask» — де Django відрізняється, що пропустити
- Зберігає час для досвідченіших студентів

**Р7. Базовий DRF-модуль як опційний**
- Додати Частину XI (опційна): REST API з DRF — 3–5 глав
- Чому: більшість Django-позицій потребують API; відсутність DRF — gap у career readiness

### Пріоритет Low (довгострокові доповнення)

**Р8. Розширити Labs з 4 до 6–8**
- Додати: Permissions Lab (повна auth flow з нуля), Deployment Lab (Docker Compose від нуля)
- Підсилює рівень 5 (Синтез) за Блумом

**Р9. Celery практика — ✅ Виконано (2026-06-15)**
- Реалізовано: `notes_project/celery.py`, `notes_app/tasks.py`, `celery-worker` + `celery-beat` у Docker Compose
- `send_mail()` через `console.EmailBackend` (dev) + `locmem.EmailBackend` (тести)
- Browser Toast через HTTP polling: `reminders.js` + `GET /reminders/check/`
- Туторіал: `docs/tutorials/08_celery.md`; розділ книги: `docs/12_final_project/background_tasks.md`
- 221 тест (було 205) у 7 файлах (було 6), включно з `test_tasks.py` (13 тестів)

**Р10. Відеоматеріали**
- Короткі відео (5–10 хв) до ключових концепцій: ASGI import order, database_sync_to_async, IDOR demo
- Підсилює наочність для різних типів учнів

---

## Загальний висновок

Курс «Django: від нуля до production» є **зрілим, технічно точним навчальним продуктом** з відмінною відповідністю дидактичним принципам (4.5/5). Тришарова структура (Knowledge Book / Zero to Hero / Deep Dive), єдиний наскрізний проєкт і CI-верифіковані ~221 тест роблять його надійним джерелом для вивчення Django у виробничому контексті.

Основні точки зростання: формальна rubric, завдання рівня 6 Блума і додатковий scaffolding на критичних переходах. Усі три є реалізовними без структурних змін курсу.

Курс рекомендований до використання як основний матеріал для навчання Django у відповідних навчальних програмах.

---

## Файли, проаналізовані при складанні рецензії

```
docs/_internal/CURRICULUM_MATRIX.md
docs/_internal/BOOK_ARCHITECTURE_PLAN.md
docs/TEACHING_GUIDE.md
docs/LEARNING_PATH.md
docs/labs/README.md
docs/tutorials/README.md
docs/12_final_project/README.md
docs/01_web_foundations/README.md
docs/02_django_core/README.md
docs/06_application_architecture/README.md
docs/07_auth_and_security/README.md
docs/08_testing_and_quality/README.md
docs/09_async_and_realtime/README.md
docs/10_linux_and_devops/README.md
docs/11_deployment/README.md
```

**Код Notes Chat App:**
```
notes_app/models.py, selectors.py, services.py, consumers.py
notes_app/tests/ (7 файлів, ~221 тест)
notes_project/settings.py, asgi.py
```
