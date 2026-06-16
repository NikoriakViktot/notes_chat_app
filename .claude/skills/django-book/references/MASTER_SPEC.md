Ти працюєш як:

* senior Python/Django developer;
* software architect;
* technical writer;
* instructional designer;
* редактор великої навчальної книги;
* reviewer Django-коду та технічної документації.

Репозиторій:

```text
/home/niko_notebook/projects/notes_chat_app
```

Основні директорії:

```text
/home/niko_notebook/projects/notes_chat_app/docs
/home/niko_notebook/projects/notes_chat_app/archive
```

Документація публікується або буде публікуватися через:

```text
MkDocs
Material for MkDocs
GitHub Pages
```

# Головна мета

Перетвори поточну документацію на **цілісну навчальну книгу про Django**, яка одночасно:

1. пояснює фундаментальні принципи Django;
2. проводить студента шляхом Zero to Hero;
3. детально розбирає реальний проєкт Notes Chat App.

Це має бути не колекція окремих Markdown-файлів, а одна логічно побудована книга з:

* частинами;
* главами;
* послідовністю;
* переходами;
* передумовами;
* практикою;
* контрольними точками;
* наскрізним проєктом;
* чітким зв’язком між теорією та реальним кодом.

---

# КРИТИЧНО ВАЖЛИВО

Це завдання НЕ є завданням на скорочення.

Заборонено:

* скорочувати детальні пояснення;
* замінювати глави короткими оглядами;
* видаляти приклади;
* видаляти Mermaid-схеми;
* видаляти таблиці;
* видаляти лабораторні роботи;
* видаляти контрольні питання;
* видаляти debugging-секції;
* перетворювати документацію на набір README-файлів;
* створювати лише красиву навігацію без повного змісту;
* залишати повний матеріал тільки в `archive/`;
* вигадувати функціональність, якої немає в коді.

Головний принцип:

```text
ORGANIZE ≠ SUMMARIZE
REWRITE ≠ SHORTEN
MERGE ≠ DELETE UNIQUE CONTENT
BOOK STRUCTURE ≠ DIRECTORY LIST
```

Поточний код репозиторію є головним джерелом істини щодо Notes Chat App.

---

# 1. Три шари книги

Документація повинна мати три чітко розділені, але взаємопов’язані шари.

---

## Шар 1 — Django Knowledge Book

Це фундаментальна книга.

Вона відповідає на питання:

```text
Що це?
Навіщо це існує?
Яку проблему вирішує?
Як це працює всередині?
Як компоненти пов’язані?
Які є альтернативи?
Які trade-offs?
Що змінюється у production?
```

Цей шар не повинен бути прив’язаний лише до одного проєкту.

Він може використовувати:

1. короткі нейтральні приклади;
2. приклади з Notes Chat App;
3. додаткові навчальні приклади, якщо вони справді допомагають поясненню.

Для кожної теми використовуй структуру:

```markdown
# Назва теми

## Яку проблему вирішує тема

## Ментальна модель

## Основні поняття

## Як механізм працює всередині

## Повний lifecycle

## Мінімальний незалежний приклад

## Приклад із Notes Chat App

## Типові помилки

## Debugging

## Security implications

## Performance implications

## Архітектурні наслідки

## Контрольні питання

## Що читати далі
```

Основні частини фундаментальної книги:

```text
Частина I. Web Foundation
Частина II. Django Core
Частина III. Models, Database та ORM
Частина IV. Forms і Validation
Частина V. Templates і Frontend
Частина VI. Application Architecture
Частина VII. Authentication і Security
Частина VIII. Testing і Quality
Частина IX. Async і Real-Time
Частина X. Linux, DevOps і Deployment
```

---

## Шар 2 — Django Zero to Hero

Це наскрізний покроковий маршрут.

Студент починає з порожньої директорії і поступово створює застосунок.

Цей маршрут має показувати **еволюцію архітектури**, а не одразу видавати фінальний складний код.

Приблизна послідовність:

```text
0. Підготовка середовища
1. Перший Python web response
2. Створення Django project
3. Створення Django app
4. URL routing
5. Перша view
6. Templates
7. Перша model
8. Migrations
9. Django Admin
10. ORM і QuerySet
11. CRUD
12. Forms і validation
13. Template inheritance
14. Bootstrap
15. Crispy Forms
16. Authentication
17. User-owned data
18. Object-level permissions
19. Більша доменна модель
20. Services і Selectors
21. FBV → CBV
22. PostgreSQL
23. Query optimization
24. Unit tests
25. Integration tests
26. E2E tests
27. GitHub Actions
28. Async fundamentals
29. ASGI
30. Async views та ORM
31. Django Channels
32. WebSocket chat
33. JavaScript WebSocket client
34. Environment variables
35. Docker
36. Production settings
37. Nginx і Uvicorn/Gunicorn
38. Deployment
```

Це орієнтир. Побудуй точний маршрут після аудиту поточного матеріалу.

Кожний крок Zero to Hero має містити:

```markdown
# Крок N — Назва

## Де ми зараз

Що вже реалізовано до початку кроку.

## Яка проблема з’явилася

Чому потрібен наступний компонент.

## Що ми додаємо

## Що зміниться в архітектурі

## Файли, які створюємо або змінюємо

## Реалізація крок за кроком

## Детальний розбір коду

## Як проходить execution flow

## Як перевірити результат

## Очікуваний результат

## Типові помилки

## Тести для цього кроку

## Git checkpoint

Що логічно зафіксувати в commit.

## Контрольна точка

Що студент повинен уміти пояснити своїми словами.

## Наступний крок

Чому наступна глава є логічним продовженням.
```

## Важлива педагогічна вимога

Не показуй складну фінальну архітектуру раніше, ніж студент зрозуміє проблему, яку вона вирішує.

Наприклад:

```text
Спочатку:
ORM-запит безпосередньо у view.

Потім:
Показати дублювання, N+1 або складну бізнес-логіку.

Лише після цього:
Ввести Selectors і Services.
```

Аналогічно:

```text
FBV
→ побачити повторюваний CRUD-код
→ CBV
→ mixins
→ thin views
```

І:

```text
HTTP polling
→ пояснити обмеження
→ WebSocket
→ Channels
→ Redis channel layer
```

---

## Шар 3 — Notes Chat App Deep Dive

Це повний tutorial і архітектурний розбір поточного проєкту.

Він повинен відповідати фактичному коду репозиторію.

Не використовуй старі назви, URL, моделі або структуру без перевірки.

Цей шар повинен пояснювати проєкт по модулях:

```text
1. Мета застосунку
2. Функціональні можливості
3. Структура репозиторію
4. Django project package
5. Django applications
6. Settings
7. Environment variables
8. URL routing
9. Middleware
10. Models
11. Relationships
12. Migrations
13. Admin
14. Forms
15. Selectors
16. Services
17. Function-Based Views
18. Class-Based Views
19. Async Views
20. Templates
21. Static files
22. JavaScript
23. Authentication
24. Sessions
25. Permissions
26. Groups або sharing
27. Tests
28. ASGI
29. Channels
30. Consumers
31. WebSocket routing
32. Chat lifecycle
33. Database
34. Docker
35. CI
36. Production preparation
37. Deployment
```

Включай лише те, що реально існує.

Для кожного модуля пояснюй:

```text
яка його відповідальність;
які дані він отримує;
що він повертає;
хто його викликає;
кого викликає він;
чому він не знаходиться в іншому шарі;
як він тестується;
які помилки тут можливі;
як він вписується в загальну архітектуру.
```

---

# 2. Спочатку повна інспекція документації

Перед переписуванням або переміщенням проведи аудит.

Проаналізуй:

```text
docs/
archive/
README.md
mkdocs.yml
requirements-docs.txt
.github/workflows/
```

Прочитай кожний Markdown-файл повністю.

Не аналізуй тільки назви або перші абзаци.

Створи:

```text
BOOK_DOCUMENTATION_AUDIT.md
```

Для кожного документа вкажи:

| Поле             | Значення                                            |
| ---------------- | --------------------------------------------------- |
| Path             | Шлях                                                |
| Назва            | Назва матеріалу                                     |
| Тип              | theory / tutorial / project guide / lab / reference |
| Рівень           | beginner / intermediate / advanced                  |
| Теми             | Повний перелік                                      |
| Передумови       | Що треба знати                                      |
| Наступна тема    | Логічне продовження                                 |
| Приклади         | Які приклади є                                      |
| Project examples | Які приклади з Notes Chat App є                     |
| Problems         | Неточності, дублювання або розриви                  |
| Target layer     | Knowledge / Zero to Hero / Project Deep Dive        |
| Target chapter   | Куди має входити                                    |
| Action           | keep / expand / split / merge / rewrite / archive   |

---

# 3. Інспекція поточного проєкту

Перевір фактичний код:

```text
manage.py
settings.py
urls.py
wsgi.py
asgi.py
routing.py
models.py
admin.py
forms.py
views.py
async_views.py
selectors.py
async_selectors.py
services.py
async_services.py
consumers.py
signals.py
middleware.py
context_processors.py
templates/
static/
tests/
migrations/
requirements.txt
pyproject.toml
Dockerfile
compose.yaml
docker-compose.yml
Makefile
.env.example
.github/workflows/
```

Не припускай, що всі файли існують.

Створи:

```text
PROJECT_CODE_DOCUMENTATION_MAP.md
```

Приклад структури:

| Project component | Actual path        | Classes/functions  | Documentation chapter | Accuracy status |
| ----------------- | ------------------ | ------------------ | --------------------- | --------------- |
| Models            | `.../models.py`    | `Note`, `Notebook` | Project / Models      | verified        |
| Views             | `.../views.py`     | ...                | Project / Views       | needs update    |
| Consumer          | `.../consumers.py` | ...                | Project / WebSocket   | verified        |

---

# 4. Аудит існуючого tutorial

Окремо перевір поточні tutorial-файли.

Знайди:

* застарілі назви файлів;
* старі URL;
* старі моделі;
* команди, які не працюють;
* різні назви `.venv` і `venv`;
* неправильні залежності;
* SQLite там, де потрібен PostgreSQL;
* згадки про неіснуючі templates;
* суперечності між FBV і CBV;
* неточні async-пояснення;
* помилки у Channels;
* неправильний WebSocket lifecycle;
* неактуальні порти;
* неактуальні environment variables;
* неіснуючі Docker services;
* неправильні test commands;
* кроки, які потребують попередньо не створених файлів;
* код, який не відповідає попередньому або наступному кроку.

Створи:

```text
PROJECT_TUTORIAL_ACCURACY_REPORT.md
```

Таблиця:

| Tutorial file | Section | Problem      | Actual code        | Required correction | Severity |
| ------------- | ------- | ------------ | ------------------ | ------------------- | -------- |
| ...           | ...     | URL outdated | current URL is ... | update              | high     |

Severity:

```text
critical
high
medium
low
editorial
```

Не виправляй лише формулювання. Перевіряй, чи студент реально зможе пройти tutorial від початку до кінця.

---

# 5. Створи архітектуру книги

Перед реалізацією створи:

```text
BOOK_ARCHITECTURE_PLAN.md
```

У плані покажи:

## 5.1. Загальну структуру

```text
Book Home
├── Knowledge Book
├── Zero to Hero
├── Notes Chat App
├── Tutorials and Labs
├── Reference
└── Teacher Guide
```

## 5.2. Повний зміст

Для кожної частини:

* назва;
* мета;
* рівень;
* передумови;
* глави;
* практика;
* зв’язок із Zero to Hero;
* зв’язок із Notes Chat App;
* наступна частина.

## 5.3. Dependency graph

Створи Mermaid-схему залежностей між темами.

Приклад логіки:

```text
HTTP
→ Django Request
→ URL
→ View
→ Template

Relational DB
→ Model
→ Migration
→ ORM
→ Selector

Forms
→ Validation
→ Service
→ Transaction

Authentication
→ Session
→ Authorization
→ Object Permission

asyncio
→ ASGI
→ Async View
→ Channels
→ WebSocket
```

## 5.4. Curriculum matrix

Створи таблицю:

| Topic      | Knowledge chapter | Zero to Hero step | Project chapter | Lab          |
| ---------- | ----------------- | ----------------- | --------------- | ------------ |
| Migrations | ...               | Step 8            | ...             | ORM Lab      |
| Services   | ...               | Step 20           | ...             | Services Lab |
| WebSocket  | ...               | Step 31           | ...             | Chat Lab     |

Кожна важлива концепція повинна з’являтися у трьох контекстах:

```text
теорія;
побудова;
реальний проєкт.
```

---

# 6. Чіткі переходи між главами

Книга не повинна виглядати як окремі статті.

Кожна глава має починатися блоком:

```markdown
## Де ми знаходимося

У попередній главі ми...
Тепер ми маємо...
Але залишається проблема...
```

І завершуватися блоком:

```markdown
## Що ми побудували

## Що тепер розуміємо

## Яка проблема залишилась

## Наступна глава
```

Перехід повинен пояснювати не лише:

> «Далі читайте Forms».

А:

> «Ми вже вміємо показувати дані з бази, але досі створюємо їх лише через Admin. Щоб користувач міг безпечно надсилати дані з браузера, потрібен шар Forms і серверна валідація.»

---

# 7. Рівні складності

Позначай глави:

```text
Foundation
Beginner
Intermediate
Advanced
Production
```

Для складних тем давай кілька маршрутів:

## Мінімальний маршрут

Що потрібно junior Django developer.

## Повний маршрут

Усі внутрішні механізми.

## Advanced маршрут

Performance, security, async і production.

Не прибирай складні пояснення. Відділяй їх візуально.

---

# 8. Реальні приклади

Використовуй два типи прикладів.

## Тип A — Незалежний мінімальний приклад

Наприклад:

```python
class Article(models.Model):
    title = models.CharField(max_length=200)
```

Такий приклад має бути коротким і показувати одну концепцію.

## Тип B — Реальний приклад Notes Chat App

Після мінімального прикладу покажи фактичний код або мінімальний релевантний фрагмент проєкту.

Формат:

````markdown
## Як це реалізовано в Notes Chat App

**Файл:** `relative/path/models.py`

```python
...
````

У цьому фрагменті:

1. ...
2. ...
3. ...

````

Не копіюй великі файли повністю.

Показуй релевантний фрагмент і давай посилання на повний source file.

## Додаткові приклади

Можна створювати інші приклади для пояснення:

- blog;
- library;
- shop;
- booking;
- school.

Але вони повинні:

- пояснювати конкретну концепцію;
- не відволікати від Notes Chat App;
- бути чітко позначеними як навчальні;
- не суперечити поточній версії Django.

---

# 9. Детальне пояснення коду

Не обмежуйся фразою:

> «Ця функція отримує нотатки».

Для важливого коду пояснюй:

- import;
- signature;
- parameters;
- return type;
- QuerySet laziness;
- момент виконання SQL;
- error paths;
- permissions;
- transactions;
- side effects;
- context;
- template rendering;
- tests;
- production implications.

Для execution flow використовуй:

```text
Browser
→ URL resolver
→ middleware
→ view
→ form
→ service
→ selector
→ ORM
→ PostgreSQL
→ template
→ response
````

---

# 10. Оновлення Django

Перевір фактичну версію Django в dependency-файлах.

Не вигадуй версію.

Документація повинна відповідати поточній версії проєкту.

Перевір:

* сумісність із Python;
* синтаксис settings;
* CBV API;
* async ORM methods;
* auth views;
* middleware;
* static files;
* Channels;
* testing API.

Для інформації, яка залежить від версії, додай:

```markdown
!!! note "Версія Django"
    Цей розділ перевірено для Django X.Y.
```

Якщо старий матеріал описує попередню версію:

1. не видаляй корисне пояснення;
2. актуалізуй код;
3. поясни різницю, якщо вона навчально важлива.

---

# 11. Педагогічні елементи

Кожна велика глава повинна містити:

* learning objectives;
* prerequisites;
* mental model;
* architecture diagram;
* code example;
* real project example;
* typical mistakes;
* debugging section;
* self-check questions;
* practical task;
* chapter summary;
* next chapter transition.

Використовуй Material for MkDocs admonitions:

```markdown
!!! note
    Додаткова інформація.

!!! warning
    Поширена небезпечна помилка.

!!! danger
    Security або data-loss ризик.

!!! tip
    Практична порада.

??? example "Розгорнути приклад"
    Детальний приклад.
```

Не ховай основне пояснення всередині collapsible-блоків.

---

# 12. Практичні завдання

Після кожної частини додай:

## Checkpoint

Невелика перевірка знань.

## Guided practice

Завдання з підказками.

## Independent task

Завдання без повного рішення.

## Advanced challenge

Архітектурне або production-завдання.

Для кожного завдання:

```text
Мета
Передумови
Умови
Файли
Критерії готовності
Тести
Поширені помилки
```

---

# 13. Labs

Організуй лабораторні роботи:

```text
ORM Lab
Forms Lab
Views Lab
Services and Selectors Lab
Security Lab
Testing Lab
Async Lab
WebSocket Lab
Deployment Lab
```

Lab не повинен бути лише текстом.

Він має містити:

```text
setup;
tasks;
commands;
expected output;
experiments;
intentional failures;
debugging questions;
completion criteria.
```

---

# 14. MkDocs navigation

Після затвердження структури онови `mkdocs.yml`.

Верхнє меню:

```text
Головна
Книга Django
Zero to Hero
Notes Chat App
Практика
Довідник
Викладачу
```

## Книга Django

Теоретичний маршрут.

## Zero to Hero

Послідовні numbered chapters.

## Notes Chat App

Повний розбір поточного проєкту.

## Практика

Tutorials, labs і assignments.

## Довідник

Commands, cheatsheets, glossary, troubleshooting.

## Викладачу

Teaching guide, curriculum, assessment.

Не включай у студентське меню:

```text
audit;
coverage;
legacy;
reorganization plans;
internal reports.
```

---

# 15. Канонічний зміст без дублювання

Одна тема повинна мати один основний theory chapter.

Zero to Hero та Project Deep Dive не повинні повторювати всю теорію.

Вони повинні:

1. давати короткий контекст;
2. посилатися на theory chapter;
3. зосереджуватися на реалізації.

Приклад:

```markdown
Перш ніж продовжити, прочитайте:
[Як працюють Django migrations](../book/.../migrations.md).

У цьому кроці ми застосуємо цей механізм до моделі Note.
```

Не прибирай корисні пояснення, якщо вони потрібні для безперервності tutorial.

---

# 16. Перевірка наскрізного tutorial

Zero to Hero має бути реально прохідним.

Створи окрему тимчасову checklist-перевірку:

```text
ZERO_TO_HERO_EXECUTION_AUDIT.md
```

Для кожного кроку перевір:

| Step | Required starting files | Commands | Expected files | Expected result | Pass |
| ---- | ----------------------- | -------- | -------------- | --------------- | ---- |

Перевір:

* чи існують усі файли перед їх редагуванням;
* чи встановлено всі залежності до import;
* чи міграції створюються у правильному порядку;
* чи URL з’являється до перевірки в браузері;
* чи template створено до render;
* чи form створено до import;
* чи tests відповідають поточному коду;
* чи async steps запускаються під ASGI;
* чи Channels налаштований до WebSocket;
* чи deployment steps відповідають production architecture.

Якщо tutorial будує спрощену навчальну версію, чітко поясни різницю між:

```text
навчальним станом на цьому кроці
та
фінальним станом Notes Chat App.
```

---

# 17. Перевірка Project Deep Dive

Для кожної project chapter перевір:

* фактичний шлях;
* назви класів;
* назви функцій;
* URL names;
* template names;
* model fields;
* relationships;
* settings;
* environment variables;
* test names;
* Docker services;
* ports;
* Channels routing.

Створи Mermaid-схеми:

## System context

```text
User
→ Browser
→ Notes Chat App
→ PostgreSQL
→ Redis, якщо використовується
```

## HTTP lifecycle

## Data model

## Create note flow

## Permission check flow

## Login/session flow

## WebSocket chat flow

## Test architecture

## Production deployment

Схеми мають відповідати коду.

---

# 18. Troubleshooting

Створи єдину систему troubleshooting.

Кожна проблема:

```markdown
## Назва помилки

### Симптом

### Ймовірна причина

### Як перевірити

### Як виправити

### Чому це сталося

### Як не допустити повторення
```

Включи релевантні проблеми:

* virtual environment;
* imports;
* migrations;
* PostgreSQL;
* DATABASE_URL;
* port 5432;
* port 8000;
* templates;
* static;
* CSRF;
* permissions;
* tests;
* ASGI;
* Channels;
* Redis;
* WebSocket;
* Docker;
* GitHub Actions.

---

# 19. Teaching Guide

Онови або створи:

```text
docs/teacher/teaching_guide.md
```

Включи:

* короткий маршрут;
* стандартний маршрут;
* повний маршрут;
* порядок занять;
* live coding;
* домашні завдання;
* складні теми;
* типові помилки;
* контрольні питання;
* критерії фінального проєкту;
* assessment rubric;
* які глави є optional;
* які глави є advanced.

Не вигадуй точну кількість академічних годин без вихідних вимог.

---

# 20. Етапи виконання

Дотримуйся порядку.

## Phase 1 — Inspection

Створи:

```text
BOOK_DOCUMENTATION_AUDIT.md
PROJECT_CODE_DOCUMENTATION_MAP.md
PROJECT_TUTORIAL_ACCURACY_REPORT.md
```

## Phase 2 — Architecture

Створи:

```text
BOOK_ARCHITECTURE_PLAN.md
ZERO_TO_HERO_PLAN.md
PROJECT_DEEP_DIVE_PLAN.md
```

## Phase 3 — Canonical structure

Визнач:

* канонічні theory chapters;
* numbered Zero to Hero chapters;
* project chapters;
* labs;
* reference.

## Phase 4 — Content implementation

Організуй і розширюй документацію.

Не скорочуй вихідний корисний матеріал.

## Phase 5 — Tutorial verification

Створи та заповни:

```text
ZERO_TO_HERO_EXECUTION_AUDIT.md
```

## Phase 6 — MkDocs

Онови:

```text
mkdocs.yml
docs/index.md
```

## Phase 7 — Validation

Виконай:

```bash
source .venv/bin/activate
mkdocs build --strict
```

Також:

```bash
python manage.py check
python manage.py test
```

Для проєкту з PostgreSQL використовуй належне середовище.

Якщо PostgreSQL недоступний:

* не вигадуй успішний test result;
* задокументуй точну причину;
* перевір те, що можна перевірити без нього.

---

# 21. Критерії приймання

Робота приймається лише тоді, коли:

* книга має три чіткі шари;
* існує логічний порядок від основ до advanced;
* Zero to Hero реально можна пройти;
* Project Deep Dive відповідає коду;
* кожна глава має чіткий перехід;
* theory пов’язана з практикою;
* практика пов’язана з Notes Chat App;
* документація не скорочена;
* додано більше пояснень там, де були розриви;
* додано реальні приклади;
* додано незалежні приклади для складних концепцій;
* усі code paths перевірені;
* tutorial inaccuracies виправлені;
* MkDocs navigation відображає структуру книги;
* `mkdocs build --strict` проходить;
* audit/legacy-файли не заважають студентові;
* commit і push не виконано.

---

# 22. Фінальний звіт

Покажи:

## Inspection

```text
Documents inspected:
Code files inspected:
Tutorial issues found:
Critical:
High:
Medium:
Low:
```

## Book architecture

```text
Knowledge chapters:
Zero to Hero steps:
Project Deep Dive chapters:
Labs:
Reference pages:
```

## Corrections

Які неточності tutorial виправлено.

## Content expansion

Які теми отримали:

* більше пояснень;
* нові схеми;
* незалежні приклади;
* project examples;
* debugging;
* exercises.

## Validation

```text
mkdocs build --strict:
Markdown links:
Mermaid:
python manage.py check:
tests:
```

## Git

```bash
git status --short
git diff --stat
```

Не виконуй commit або push.
