# 00. Getting Started — Де починається Django

> Цей розділ відповідає на головне питання: **навіщо вивчати Django і що ти отримаєш наприкінці?**
> Перш ніж запускати код — зрозумій, що ти будуєш і чому це важливо.

---

## Django — не просто фреймворк

Django — це "батарейки включені" (batteries included) веб-фреймворк для Python.
Це означає: замість того щоб збирати систему з десятків бібліотек,
ти отримуєш один інструмент де вже є **все** що потрібно для продакшн-додатку.

```
Типовий проєкт БЕЗ фреймворку:
  requests + urllib → HTTP parsing
  + Jinja2           → templates
  + SQLAlchemy       → database
  + WTForms          → form validation
  + bcrypt           → passwords
  + itsdangerous     → sessions/CSRF
  + pytest           → testing
  = 8 бібліотек, 8 документацій, 8 місць де щось може не узгодитись

Django:
  ORM + templates + forms + auth + admin + sessions + CSRF + testing
  = один інструмент, одна документація, все узгоджено між собою
```

### Де Django використовується у реальному світі

- **Instagram** — найбільший Django-проєкт у світі (мільярди запитів/день)
- **Pinterest** — соцмережа (250+ мільйонів активних юзерів)
- **Disqus** — коментарі на 2 мільярди сайтів
- **Mozilla** — Firefox Add-ons, bugzilla
- **Washington Post** — медіа з мільйонами читачів
- **Eventbrite** — продаж квитків
- **Spotify** (частково) — backend сервіси
- Тисячі стартапів і SaaS продуктів

**Чому Django?** Він дозволяє маленькій команді (або одній людині) швидко побудувати
надійний, безпечний і масштабований продукт. Instagram запустили два розробники за 8 тижнів.

---

## Що ти вивчиш у цьому курсі

На кінець курсу ти побудуєш **notes_chat_app** — повноцінний production-ready додаток:

```
notes_chat_app — що вміє:
  ✓ Реєстрація та авторизація (сесії, cookies, CSRF)
  ✓ Нотатки з тегами, підручниками, нагадуваннями
  ✓ Todo списки та Shopping lists
  ✓ Групи з спільним доступом до даних
  ✓ Груповий чат у реальному часі (WebSocket)
  ✓ E2E тести через Selenium (headless Chrome)
  ✓ Публічний доступ через ngrok (HTTPS тунель)
  ✓ PostgreSQL, Redis, nginx — production стек
  ✓ Docker Compose — одна команда запускає все
```

### Модулі курсу

| Модуль | Тема | Що навчишся |
|--------|------|-------------|
| 01 | Перший Django view | HTTP, URL, View, Template — базовий цикл |
| 02 | Перша модель | ORM, ModelForm, PRG, Django Messages |
| 03 | CRUD та бізнес-логіка | selectors/services, N+1, транзакції |
| 04 | Шаблони та Bootstrap | 3-рівневе наслідування, Crispy Forms |
| 05 | Автентифікація | login, register, UserProfile, декоратори |
| 06 | Тестування | піраміда тестів, TestCase, WebSocket, Selenium |
| 07 | Async та WebSocket | ASGI, Channels, channel layer |
| 08 | Deployment | Docker Compose, nginx, ngrok |

---

## Філософія Django: "Convention over Configuration"

Django побудований на принципі: є один правильний спосіб зробити типову задачу,
і фреймворк веде тебе до нього.

### MTV — не MVC

Django використовує варіацію MVC під назвою MTV:

```
MVC (класичний):        Django MTV:
  Model                   Model       (ORM, models.py)
  View                    Template    (HTML шаблони)
  Controller              View        (views.py — бізнес-логіка + HTTP)
```

Назви інші, концепція та сама. Розподіл обов'язків:

```
models.py     → ЩО зберігаємо (схема даних, бізнес-правила)
views.py      → ЯК обробляємо запит (логіка, відповідь)
templates/    → ЯК відображаємо (HTML, CSS, JS)
urls.py       → ЯКИЙ URL → яка view
forms.py      → ЯК валідуємо введені дані
```

### Don't Repeat Yourself (DRY)

Django максимально уникає дублювання:

```python
# Модель визначена ОДИН раз:
class Note(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()

# ModelForm генерує форму АВТОМАТИЧНО з моделі:
class NoteForm(ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content']
# → HTML форма, валідація, збереження — все з одного опису

# Admin генерується АВТОМАТИЧНО з моделі:
admin.site.register(Note)
# → повний CRUD у адмін-панелі
```

### Batteries Included — що вже є у Django

```
django.contrib.admin          → автогенерована адмін-панель
django.contrib.auth           → авторизація, сесії, паролі (bcrypt)
django.contrib.contenttypes   → generic relationships
django.contrib.messages       → flash messages (одноразові нотифікації)
django.contrib.staticfiles    → збирання і роздача static files
django.contrib.humanize       → фільтри: "3 days ago", "1,000" тощо
django.test                   → TestCase, Client, RequestFactory
```

---

## Як влаштований notes_chat_app

```
notes_chat_app/
├── Dockerfile              ← Docker образ (python:3.12-slim + requirements)
├── docker-compose.yml      ← Оркестрація: db + redis + web + nginx + ngrok + selenium
├── entrypoint.sh           ← Скрипт запуску контейнера
├── requirements.txt        ← Python залежності
├── .env.example            ← Шаблон конфігурації (скопіюй у .env)
│
├── notes_project/          ← Django проєкт (конфігурація)
│   ├── settings.py         ← Всі налаштування (БД, apps, static, channels)
│   ├── urls.py             ← Кореневий URL dispatcher
│   ├── asgi.py             ← ASGI точка входу (HTTP + WebSocket)
│   ├── wsgi.py             ← WSGI (не використовується в production)
│   └── routing.py          ← WebSocket URL patterns
│
├── notes_app/              ← Django додаток (основна логіка)
│   ├── models.py           ← 9 моделей: Note, Notebook, Tag, UserProfile, ChatMessage...
│   ├── views.py            ← HTTP views (тонкий шар)
│   ├── consumers.py        ← WebSocket consumer (async)
│   ├── selectors.py        ← Тільки SELECT (read-only ORM)
│   ├── services.py         ← Мутації (CREATE, UPDATE, DELETE)
│   ├── forms.py            ← Django ModelForms
│   ├── urls.py             ← HTTP URL patterns
│   ├── admin.py            ← Адмін-панель реєстрація
│   ├── templates/          ← HTML шаблони
│   ├── static/             ← CSS, JavaScript
│   └── tests/              ← Тести (models, services, forms, views, consumers, selenium)
│
├── nginx/
│   └── nginx.conf          ← Конфігурація reverse proxy + WebSocket
│
└── docs/                   ← Вся документація (MkDocs)
```

### Схема даних (стисло)

```
User ──1:1──► UserProfile
User ──1:N──► Notebook, Note, Tag, TodoList, ShoppingList
Notebook ──1:N──► Note
Note ──M:N──► Tag
Note ──1:N──► Reminder
TodoList ──1:N──► TodoItem
ShoppingList ──1:N──► ShopItem
Group ──1:N──► ChatMessage
```

Детальніше: [03 — CRUD та моделі](../tutorials/03_crud.md)

---

## Матеріали цього розділу

| Документ | Що всередині |
|----------|-------------|
| [Prerequisites](prerequisites.md) | Що встановити: Python, Docker, Git, VSCode |
| [Local setup](local_setup.md) | Як запустити: `docker compose up --build` |
| [Repository structure](repository_structure.md) | Що де лежить у репозиторії |
| [How to use course](how_to_use_course.md) | Як ефективно читати матеріали |

---

## Мінімальний старт — три команди

```bash
# 1. Скопіюй конфіг:
cp .env.example .env

# 2. Запусти стек:
docker compose up --build

# 3. Відкрий браузер:
# http://localhost
#
# Демо-облікові записи (пароль: demo1234):
# demo_alice, demo_bob, demo_carol
```

---

## Що означає "production-ready"

Більшість туторіалів показують Django на `runserver` з SQLite.
`notes_chat_app` — інший рівень:

| Компонент | Типовий туторіал | notes_chat_app |
|-----------|-----------------|---------------|
| **БД** | SQLite | PostgreSQL 16 |
| **Сервер** | `runserver` | Uvicorn ASGI |
| **Proxy** | — | nginx 1.27 |
| **Channel layer** | — | Redis 7 |
| **WebSocket** | — | Django Channels |
| **Тести** | Мінімум | Unit + Integration + Consumer + Selenium E2E |
| **Запуск** | `python manage.py runserver` | `docker compose up` |
| **Public URL** | localhost | ngrok HTTPS тунель |

Ти вивчаєш не "як щось запустити", а "як воно насправді працює у production".

---

## Контрольні питання перед початком

- Що таке HTTP запит і відповідь?
- Що таке Docker і для чого він потрібен?
- Що таке реляційна база даних?
- Що таке Git і як клонувати репозиторій?

Якщо є прогалини — поглянь на [Prerequisites](prerequisites.md).

## Далі

[01 — Web foundations](../01_web_foundations/README.md) → HTTP, браузер, DNS.

Або одразу до туторіалів: [01 — Перший Django view](../tutorials/01_first_django_page.md)
