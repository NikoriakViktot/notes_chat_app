# Zero to Hero — Шлях від нуля до production

Цей маршрут проведе тебе від порожньої директорії до production-ready Django-застосунку з WebSocket-чатом, Docker Compose, автентифікацією та CI.

Кожен крок вирішує **одну конкретну проблему** і залишає після себе рабочий застосунок.

---

## Карта маршруту

```
[0] Середовище ──► [1] Hello Django ──► [2] Перша модель ──► [3] CRUD + arch
                                                                      │
                                                                      ▼
[9] Deployment ◄── [8] Celery ◄── [7] WebSocket ◄── [6] Тести ◄── [5] Auth ◄── [4] Forms + UI
```

Кроки 1–4 — standalone навчальні проєкти.
Кроки 5–9 — розвиток **notes_chat_app** (фінальний production-застосунок).

---

## Проєкти маршруту

```text
hello_project        ← Крок 1  — один view, SQLite, без моделей
bootstrap_notes      ← Крок 2  — перша модель, Django Admin
notes_project        ← Крок 3  — CRUD, selectors/services, PostgreSQL
crispy_notes         ← Крок 4  — ModelForm, Bootstrap 5, template inheritance
notes_chat_app       ← Кроки 5–9 — auth, testing, WebSocket, Celery, Docker, CI
```

Кожен standalone-проєкт — **окремий репозиторій**, не гілка notes_chat_app.
Він показує лише ту концепцію, яка потрібна на цьому кроці.

---

## Зведена таблиця кроків

| # | Назва | Проєкт | Нова концепція | Knowledge | Критерій завершення |
|--:|-------|--------|---------------|-----------|---------------------|
| 0 | [Середовище](#крок-0-середовище) | — | Python, pyenv, Docker | — | `python -c "import django; print(django.__version__)"` |
| 1 | [Hello Django](#крок-1-hello-django) | hello_project | MTV, URLconf, HttpResponse | I, II | `curl http://127.0.0.1:8000/` → 200 |
| 2 | [Перша модель](#крок-2-перша-модель) | bootstrap_notes | ORM, migration, Admin | III | запис у БД через Admin |
| 3 | [CRUD + arch](#крок-3-crud--архітектура) | notes_project | selectors/services, PostgreSQL | VI | unit TestCase проходить |
| 4 | [Forms + UI](#крок-4-форми-та-bootstrap) | crispy_notes | ModelForm, Bootstrap 5 | IV, V | crispy форма у браузері |
| 5 | [Auth + безпека](#крок-5-автентифікація-та-безпека) | notes_chat_app | IDOR, Q-filter, Groups | VII | IDOR-тест падає без fix, проходить після |
| 6 | [Тестування](#крок-6-тестування) | notes_chat_app | TransactionTestCase, Selenium | VIII | 205 тестів зелені |
| 7 | [WebSocket](#крок-7-async-та-websocket) | notes_chat_app | Channels, Redis, ASGI | IX | consumer-тест проходить |
| 8 | [Celery](#крок-8-celery-та-фонові-задачі) | notes_chat_app | Celery Worker, Beat, Redis broker, HTTP polling | IX | нагадування надходять по email + toast у браузері |
| 9 | [Deployment](#крок-9-deployment-та-ci) | notes_chat_app | Docker Compose, Nginx, CI | X | GitHub Actions: green |

---

## Крок 0. Середовище

**Проблема:** нічого не запускається.

**Що встановлюємо:** Python (через pyenv), Git, Docker Desktop, VS Code + Python extension.

**Перевірка:**

```bash
python --version        # 3.12.x
docker version          # Engine: 24+
git --version           # 2.x
python -c "import django; print(django.__version__)"  # 5.2.x
```

**Нові концепти:** virtual environment, PATH, Docker daemon.

---

## Крок 1. Hello Django

> **Туторіал:** [01 — Перша Django-сторінка](01_first_django_page.md) · **Детально:** [README_1](README_1.md)

**Проблема:** як змусити браузер отримати відповідь від Python?

**Що будуємо:** `hello_project` — порожній Django-проєкт з одним view.

```bash
django-admin startproject hello_project .
python manage.py runserver
```

**Архітектура на цьому кроці:**

```
Browser → urls.py → view function → HttpResponse
```

**Нові концепти:** MTV, URLconf, `HttpResponse`, `DEBUG`, `INSTALLED_APPS`.

**Типові помилки:**
- `ModuleNotFoundError: No module named 'django'` — не активований virtual environment
- `Error: That port is already in use` — запущено інший `runserver`

**Notes Chat App:** аналогічна структура `notes_project/urls.py` → `notes_app/views.py`, але 15+ views замість одного.

---

## Крок 2. Перша модель

> **Туторіал:** [02 — Перша модель](02_first_model.md) · **Детально:** [README_2](README_2.md)

**Проблема:** дані зникають після перезавантаження сервера.

**Що будуємо:** `bootstrap_notes` — проєкт з моделлю `Note`, міграціями, Django Admin.

```python
class Note(models.Model):
    title   = models.CharField(max_length=200)
    content = models.TextField()
    created = models.DateTimeField(auto_now_add=True)
```

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

**Архітектурна зміна:** HTTP stateless → дані зберігаються у SQLite між запитами.

**Нові концепти:** `models.Model`, migration graph, `__str__`, `ForeignKey`, `on_delete`, Django Admin, QuerySet.

**Типові помилки:**
- Забути `makemigrations` після зміни моделі
- `IntegrityError: NOT NULL constraint` — обов'язкове поле без default

**Notes Chat App:** `notes_app/models.py` має 8 моделей з ForeignKey, M2M та `on_delete=CASCADE` / `SET_NULL`. SQLite замінено PostgreSQL починаючи з Кроку 3.

---

## Крок 3. CRUD і архітектура

> **Туторіал:** [03 — CRUD](03_crud.md) · **Детально:** [README_3](README_3.md) · **CBV:** [README_4](README_4.md)

**Проблема:** view стає жирним — ORM-запити, validation і HTTP-логіка змішані в одній функції.

**Що будуємо:** `notes_project` — CRUD з `selectors.py` та `services.py`, PostgreSQL.

**Педагогічна еволюція:**

```text
def note_list(request):
    notes = Note.objects.filter(user=request.user)  # ORM у view
    ...

# Дублюється у 5 views → витягуємо:

# selectors.py
def get_notes_for_user(user):
    return Note.objects.filter(user=user)  # тільки читання

# services.py
def create_note(user, title, content):
    return Note.objects.create(user=user, title=title, content=content)  # тільки мутація
```

**Перехід SQLite → PostgreSQL:**

```text
SQLite: немає повноцінних FOREIGN KEY constraints, обмежений конкурентний запис
PostgreSQL: transactions, indexes, ON DELETE CASCADE/SET NULL, UNIQUE constraints
```

**Нові концепти:** PRG (Post/Redirect/Get), тонкий view, selector (read-only), service (mutation), `get_object_or_404`.

**Typicові помилки:**
- Повернути lazy QuerySet з selector → `SynchronousOnlyOperation` у async-контексті
- Мутація у selector (порушення шару)
- `TypeError` якщо параметри view і service не узгоджені

---

## Крок 4. Форми та Bootstrap

> **Туторіал:** [04 — Шаблони + Bootstrap](04_templates_bootstrap.md) · **Детально:** [README_5](README_5.md)

**Проблема:** HTML-форми виглядають погано, validation дублюється у view і template.

**Що будуємо:** `crispy_notes` — `ModelForm`, crispy-forms, Bootstrap 5, SaaS dashboard.

```python
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority']

    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title) < 3:
            raise ValidationError("Заголовок занадто короткий.")
        return title
```

**Template inheritance:**

```
templates/base.html           ← DOCTYPE, head, navbar
└── templates/layouts/dashboard.html  ← sidebar, content block
    └── notes_app/note_list.html       ← конкретна сторінка
```

**FBV vs CBV:**

```text
FBV: явні if request.method == 'POST' — більше коду, але прозоріший
CBV: CreateView, UpdateView — менше boilerplate, але складніший debug
→ notes_chat_app обирає FBV для явності та гнучкості з permissions
```

**Нові концепти:** `ModelForm`, `clean_<field>`, CSRF, `{{ form|crispy }}`, `{% extends %}`, `{% block %}`, `{% include %}`.

---

## Крок 5. Автентифікація та безпека

> **Туторіал:** [05 — Auth та безпека](05_authentication.md) · **Детально:** [README_6](README_6.md)

**Проблема:** будь-хто може читати і редагувати чужі нотатки (IDOR).

**Що додаємо до notes_chat_app:**

- `@login_required` — тільки автентифіковані бачать notes
- Object-level permissions — `Note.user == request.user OR group`
- `UserProfile` (1:1 до `User`)
- `Group` sharing — кілька користувачів мають спільний доступ
- Password reset flow

**IDOR-атака і захист:**

```python
# ВРАЗЛИВО: перевірено тільки login, не ownership
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)  # будь-яка нотатка!
    ...

# БЕЗПЕЧНО: Q-filter за власником і групою
def get_note_for_user(pk, user):
    user_groups = user.groups.all()
    return get_object_or_404(
        Note,
        Q(pk=pk) & (Q(user=user) | Q(group__in=user_groups))
    )
```

**Нові концепти:** `request.user`, `login_required`, sessions, `UserProfile`, `Q` objects, IDOR, `AbstractBaseUser`, password hashing, `authenticate()`.

**Типові помилки:**
- `@login_required` ≠ object-level permission → IDOR
- Перевірка `note.user == request.user` без урахування group-sharing

---

## Крок 6. Тестування

> **Туторіал:** [06 — Тестування](06_testing.md) · **Детально:** [README_7](README_7.md)

**Проблема:** рефакторинг ламає речі, які ніхто не помітив.

**Архітектура тест-suite:**

```text
test_models.py    — перевіряємо constraints, __str__, on_delete behaviour
test_services.py  — перевіряємо return value + persistence
test_forms.py     — valid data, invalid data, custom clean_
test_views.py     — Client + force_login, status codes, redirect targets
test_consumers.py — WebsocketCommunicator + TransactionTestCase (не TestCase!)
test_selenium.py  — E2E у реальному браузері (StaticLiveServerTestCase)
```

**Критично — TransactionTestCase для consumer-тестів:**

```text
TestCase огортає кожен тест у транзакцію → rollback після тесту.
Async consumer читає БД з окремого worker-потоку —
  ця транзакція невидима йому → setUp-об'єкти «зникають».
ЗАВЖДИ використовуй TransactionTestCase для consumer-тестів.
```

**Запуск:**

```bash
# Unit + integration + consumer
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium E2E (потребує запущеного стеку)
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

**Нові концепти:** AAA (Arrange/Act/Assert), `setUp`, `force_login`, `WebsocketCommunicator`, `StaticLiveServerTestCase`, CI YAML.

---

## Крок 7. Async та WebSocket

> **Туторіал:** [07 — Async та WebSocket](07_async.md) · **Детально:** [README_8](README_8.md) · [README_9](README_9.md)

**Проблема:** HTTP request/response не підходить для real-time — 100 клієнтів = 100 requests/sec при polling.

**Педагогічна еволюція:**

```text
HTTP polling
  setInterval(() => fetch('/new-messages/'), 1000)
  → 100 клієнтів = 100 запитів/сек — неефективно

WebSocket
  → одне довготривале з'єднання
  → сервер може пушити події без запиту від клієнта
  → Django Channels — ASGI-обробник для WS
  → Redis channel layer — broadcast до групи
```

**ASGI-стек:**

```
Browser WS connect
  → Nginx (proxy_pass ws://)
  → Daphne ASGI server
  → ProtocolTypeRouter (asgi.py)
  → AuthMiddlewareStack  (читає session cookie → scope["user"])
  → URLRouter (routing.py: /ws/groups/<pk>/chat/)
  → GroupChatConsumer
```

**Критичні деталі реалізації:**

```python
# asgi.py: get_asgi_application() ПЕРЕД імпортом notes_app
django.setup() → get_asgi_application() → from notes_app.consumers import ...

# consumers.py: ніколи не викликати sync ORM напряму
history = await database_sync_to_async(
    lambda: list(ChatMessage.objects.filter(group=group_pk).values(...))
)()  # list() — щоб матеріалізувати QuerySet ДО виходу з worker

# RedisChannelLayer (settings.py):
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL], "socket_timeout": None},
        #                                 ^^^^^^^^^^^^^^^^^^^
        #                     None = без таймауту для idle WS
    }
}
```

**Нові концепти:** `asyncio`, coroutine, `await`, ASGI vs WSGI, `AsyncWebsocketConsumer`, channel layer, `group_send`, `database_sync_to_async`.

---

## Крок 8. Celery та фонові задачі

> **Туторіал:** [08 — Celery та фонові задачі](08_celery.md)

**Проблема:** Django не може надіслати email рівно о запланованому часі — view виконується лише у відповідь на запит.

**Два рівні нагадувань:**

```text
Email (Celery Worker)
  Celery Beat → кожні 60 сек → @shared_task send_reminder_notifications()
  → Reminder.filter(remind_at__lte=now, is_sent=False)
  → send_mail() → reminder.is_sent = True
  → _schedule_next() → новий Reminder якщо repeat_pattern ≠ none

Browser Toast (HTTP polling)
  reminders.js → кожні 60 сек → GET /reminders/check/
  → JsonResponse({reminders: [...]})
  → Bootstrap Toast для нових (sessionStorage — дедуплікація)
```

**Redis DB розподіл:**

```text
Redis DB 0 — Django Channels channel layer (WebSocket)
Redis DB 1 — Celery broker і result backend
```

**Docker Compose сервіси:**

```yaml
celery-worker:
  command: celery -A notes_project worker -l info --concurrency=2
celery-beat:
  command: celery -A notes_project beat -l info   # рівно 1 екземпляр!
```

**Нові концепти:** `@shared_task`, Celery Beat, broker, `CELERY_BEAT_SCHEDULE`, `relativedelta`, HTTP polling, Bootstrap Toast API, `sessionStorage`, `@override_settings(EMAIL_BACKEND=...)`, `mail.outbox`.

---

## Крок 9. Deployment та CI

> **Туторіал:** [09 — Deployment](09_deployment.md) · **Детально:** [README_9](README_9.md)

**Проблема:** застосунок працює тільки локально.

**Docker Compose стек:**

```yaml
services:
  db:       # PostgreSQL + PostGIS
  redis:    # канальний рівень для Channels
  web:      # Django (Daphne ASGI)
  nginx:    # reverse proxy, SSL-термінація, статика
  ngrok:    # публічний HTTPS-тунель для розробки
  selenium: # Selenium Grid для E2E тестів
```

**Production checklist:**

```text
✓ DEBUG=False
✓ SECRET_KEY — з env, не у коді
✓ DATABASE_URL — відсутність → Exception (не SQLite fallback!)
✓ ALLOWED_HOSTS — конкретні домени
✓ Static files — через Nginx, не Django
✓ DebugExceptionMiddleware — тільки якщо DEBUG=True
✓ HTTPS — CSRF_TRUSTED_ORIGINS, SESSION_COOKIE_SECURE
```

**GitHub Actions CI:**

```yaml
jobs:
  test:       # unit + integration + consumer tests
  selenium:   # E2E у Selenium Grid
```

**Нові концепти:** `Dockerfile`, multi-service `docker-compose.yml`, `ENTRYPOINT`, Nginx `proxy_pass`, `collectstatic`, `.env` файл, GitHub Actions workflow.

---

## Архітектурна еволюція за весь маршрут

| Крок | DB | Auth | Форми | Тести | Deploy | Фоновий процес |
|-----:|----|----|-------|-------|--------|----------------|
| 1 | SQLite (не використовується) | — | — | — | runserver | — |
| 2 | SQLite | — | Admin | — | runserver | — |
| 3 | PostgreSQL | — | raw HTML | TestCase | runserver | — |
| 4 | PostgreSQL | — | ModelForm + crispy | Form tests | runserver | — |
| 5 | PostgreSQL | login_required + Q-filter | ModelForm | IDOR test | runserver | — |
| 6 | PostgreSQL | ✓ | ✓ | 205 tests | runserver | — |
| 7 | PostgreSQL | ✓ | ✓ | + consumer | Daphne ASGI | — |
| 8 | PostgreSQL | ✓ | ✓ | + test_tasks | Daphne ASGI | Celery Worker + Beat |
| 9 | PostgreSQL | ✓ | ✓ | + Selenium | Docker + Nginx + CI | Celery Worker + Beat |

---

## Що далі

Після завершення Zero to Hero маршруту:

- **[Notes Chat App Deep Dive](../12_final_project/README.md)** — повний архітектурний розбір фінального застосунку
- **[Книга Django](../index.md)** — теоретична база для поглиблення знань
- **[Лабораторні роботи](../labs/README.md)** — практика без покрокових підказок
