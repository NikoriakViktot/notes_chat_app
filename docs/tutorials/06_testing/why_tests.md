# Навіщо тести і як вони працюють

---

## 01 · НАВІЩО ТЕСТИ

> **Головне питання:** Як дізнатись що після змін нічого не зламалось?
>
> Відповідь без тестів: запустити вручну, клацати по сайту, сподіватись.
> Відповідь з тестами: запустити одну команду і побачити все за 30 секунд.

### Аналогія — пожежна сигналізація

Будинок без сигналізації: виявляєш пожежу коли вже горить.
Будинок з сигналізацією: дізнаєшся про іскру ДО того як все охопить вогнем.

**Тести = сигналізація вашого коду.** Вони перевіряють "чи все ще правильно" при кожній зміні.

```
БЕЗ ТЕСТІВ                              З ТЕСТАМИ
──────────────────────────────────────  ──────────────────────────────────────
Пишеш новий фічер                       Пишеш новий фічер
Вручну клацаєш 10+ сторінок             Запускаєш: manage.py test
"Виглядає ок"                           FAIL: test_note_visible_only_to_owner
git push → деплой                       Бачиш ТОЧНО що зламалось
Через тиждень: "Баг у продакшені!"      Виправляєш ДО деплою
Стаєш детективом — шукаєш причину      git push → деплой → все зелено
```

### Реальний сценарій: ти міняєш `selectors.py`

```python
# СТАРА версія (правильна):
def get_user_notes(user, *, archived=False):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),   # ← власні + групові
        is_archived=archived,
    )

# НОВА версія після "рефакторингу" (помилка!):
def get_user_notes(user, *, archived=False):
    return Note.objects.filter(
        user=user,    # ← забули Q-filter для груп!
        is_archived=archived,
    )
```

**Без тестів:** Всі групові нотатки зникають для всіх юзерів.
Виявляють клієнти через тиждень після деплою в production.

**З тестами:** `test_selectors.py` одразу:
```
FAIL: test_group_notes_visible_to_members
AssertionError: <Note: Team meeting> not found in queryset for bob
```
Виправляєш за 2 хвилини до коміту.

### Що ще дають тести

| Перевага | Пояснення |
|----------|-----------|
| **Документація** | `test_create_notebook_default_unsets_previous_default` пояснює інваріант краще за коментар |
| **Рефакторинг без страху** | Змінив реалізацію → тести підтверджують що поведінка та сама |
| **Виявлення edge cases** | При написанні тесту думаєш: "а що якщо None? а якщо порожньо?" |
| **Захист від регресій** | Баг виправлений + тест написаний = баг ніколи не повернеться |
| **Security перевірка** | `test_notebook_queryset_excludes_other_user_notebooks` — IDOR неможливий |
| **CI сигнал** | GitHub Actions: FAIL перед merge → не деплоїш зламаний код |

---

## 02 · ПІРАМІДА ТЕСТУВАННЯ

> **Не всі тести однакові.** Різні рівні мають різну вартість і швидкість.

```
              ╱╲
             ╱E2E╲          Selenium, Playwright
            ╱──────╲        Реальний браузер, повний сценарій
           ╱ Integr. ╲      Повільно (секунди/тест), крихко
          ╱────────────╲    Django Test Client: запити → БД → відповідь
         ╱  Consumers   ╲   Середньо (100мс/тест)
        ╱────────────────╲  WebsocketCommunicator (тільки notes_chat_app)
       ╱       Unit        ╲ TestCase: функція → результат
      ╱──────────────────────╲ Швидко (1-10мс/тест), надійно

    60% Unit | 25% Integration | 10% Consumers | 5% E2E
```

### Що тестуємо на кожному рівні

**Unit тести** (моделі, сервіси, форми):
```python
# Тестуємо функцію ізольовано від HTTP
def test_create_notebook_default_unsets_previous_default(self):
    old = services.create_notebook(user=alice, title='Old', is_default=True)
    new = services.create_notebook(user=alice, title='New', is_default=True)
    old.refresh_from_db()
    self.assertFalse(old.is_default)  # 1 is_default на юзера — інваріант
```

**Integration тести** (views через Test Client):
```python
# Тестуємо через HTTP — view + БД + відповідь
def test_note_list_shows_only_user_notes(self):
    self.client.force_login(alice)
    response = self.client.get(reverse('notes_app:note_list'))
    self.assertEqual(response.status_code, 200)
    self.assertNotContains(response, "Bob's Secret Note")
```

**Consumer тести** (WebSocket, тільки notes_chat_app):
```python
# WebsocketCommunicator → consumer → channel layer
async def test_non_member_cannot_connect(self):
    communicator = WebsocketCommunicator(application, f'/ws/groups/{pk}/chat/')
    communicator.scope['user'] = self.bob  # не є членом групи
    connected, code = await communicator.connect()
    self.assertFalse(connected)
```

**E2E тести** (Selenium):
```python
# Тестуємо через реальний браузер — кліки, форми, навігація
def test_user_can_login_and_see_dashboard(self):
    self.driver.get(f'{self.live_server_url}/accounts/login/')
    self.driver.find_element(By.NAME, 'username').send_keys('alice')
    self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
    self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()
    self.assertIn('/notes/', self.driver.current_url)
```

### Де живуть наші тести

| Рівень | Файл | Що тестує | Кількість |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Модель: constraints, `__str__`, defaults, SET_NULL | ~23 |
| Unit | `tests/test_services.py` | Бізнес-логіка: create, update, delete, security | ~36 |
| Unit | `tests/test_forms.py` | Валідація, нормалізація, queryset filtering | ~23 |
| Integration | `tests/test_views.py` | Views через `self.client`: HTTP коди, ownership, redirects | ~41 |
| Consumer | `tests/test_consumers.py` | WebSocket auth, broadcast, disconnect | ~6 |
| E2E | `tests/test_selenium.py` | Браузер: форми, навігація, DOM (skip без geckodriver) | ~6 |

---

## 03 · DJANGO TESTCASE

> `django.test.TestCase` — це `unittest.TestCase` + магія Django.

### Що відрізняє Django TestCase від чистого unittest

```python
import unittest
from django.test import TestCase

# unittest.TestCase — базовий, без БД
class PureUnitTest(unittest.TestCase):
    def test_math(self):
        self.assertEqual(2 + 2, 4)   # ОК, без БД

# django.test.TestCase — з повним Django стеком
class DjangoTest(TestCase):
    def test_with_db(self):
        user = User.objects.create_user('alice')  # ← потребує тестової БД
        self.assertEqual(user.username, 'alice')
        # Після тесту → ROLLBACK → alice зникла автоматично
```

### Що Django TestCase дає автоматично

```
┌─────────────────────────────────────────────────────────────────────┐
│  Перед ВСІМА тестами класу (setUpClass):                            │
│    → Створює тестову БД: CREATE DATABASE test_notes_db              │
│    → Застосовує всі міграції (CREATE TABLE ...)                      │
│    → Завантажує fixtures якщо є                                     │
│                                                                     │
│  Перед КОЖНИМ тестом:                                               │
│    → BEGIN TRANSACTION                                              │
│    → Викликає setUp()                                               │
│                                                                     │
│    ┌─── ТЕСТ ВИКОНУЄТЬСЯ ──────────────────────────────────────┐   │
│    │  User.objects.create(...)  ← INSERT INTO auth_user        │   │
│    │  Note.objects.create(...)  ← INSERT INTO notes_app_note   │   │
│    │  services.create_note(...) ← бізнес-логіка + INSERT       │   │
│    │  self.assertEqual(...)     ← перевірка                    │   │
│    └───────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Після КОЖНОГО тесту:                                              │
│    → ROLLBACK   ← всі INSERT/UPDATE/DELETE зникають!               │
│    → Викликає tearDown()                                            │
│                                                                     │
│  Після ВСІХ тестів (tearDownClass):                                 │
│    → DROP DATABASE test_notes_db                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Чому rollback — це добре

```python
class MyTest(TestCase):
    def test_first(self):
        User.objects.create_user('alice')    # ← alice ІСНУЄ
        self.assertEqual(User.objects.count(), 1)
        # Після тесту → ROLLBACK → alice зникла

    def test_second(self):
        # alice НЕ існує — кожен тест починає з чистого стану
        self.assertEqual(User.objects.count(), 0)  # ← 0, не 1!
```

**Без rollback** тести б впливали один на одного:
- тест 1 створює alice → тест 2 бачить alice → результати непередбачувані
- Порядок виконання тестів впливав би на результат

**З rollback** кожен тест ізольований → результат не залежить від порядку.

### setUp — підготовка перед кожним тестом

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        """Виконується ПЕРЕД кожним тестом. БД чиста."""
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        # Ці юзери будуть у кожному тесті цього класу
        # Після кожного тесту → ROLLBACK → вони зникають → наступний setUp створить знову

    def test_something(self):
        # self.alice і self.bob вже існують тут
        note = services.create_note(user=self.alice, title='Test')
        ...
```

### BaseServiceTest — DRY для спільного setUp

```python
class BaseServiceTest(TestCase):
    """
    Базовий клас з загальним setUp.
    Всі класи-нащадки автоматично отримують self.alice і self.bob.
    """
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() НЕ потрібен — inherited від BaseServiceTest
    # self.alice і self.bob доступні в кожному тесті

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)
```

---

## 04 · ТЕСТОВА БД

> **Найважливіше правило:** Тести ніколи не торкаються твоєї робочої БД.

### Як Django створює тестову БД

```bash
# crispy_notes_project (SQLite):
$ python manage.py test hello_app.tests

Creating test database for alias 'default' ...
#  ↑ Django створює test_<db_name> або in-memory (SQLite)
#    Вся дані там — не в твоєму db.sqlite3!

Found 129 test(s).
...

Destroying test database for alias 'default' ...
#  ↑ Тестова БД видаляється після завершення

# notes_chat_app (PostgreSQL у Docker):
$ docker compose run --rm web python manage.py test notes_app.tests

Creating test database for alias 'default' ...
# ↑ Django: CREATE DATABASE test_notes_db
#   Окрема порожня БД, відмінна від notes_db!
```

### Три ізоляції одночасно

```
1. ІЗОЛЯЦІЯ ВІД РЕАЛЬНОЇ БД:
   db.sqlite3 або notes_db (твоя робоча) ≠ тестова БД (окрема, тимчасова)
   Тести не можуть зламати твої реальні дані.

2. ІЗОЛЯЦІЯ МІЖ ТЕСТАМИ:
   Кожен тест — своя транзакція → rollback.
   Тест A не бачить даних Тесту B.
   Порядок виконання не впливає на результат.

3. ІЗОЛЯЦІЯ ВІД ЗОВНІШНІХ СИСТЕМ:
   Email: EMAIL_BACKEND = console (не надсилається реально)
   Redis: InMemoryChannelLayer (тести без реального Redis)
   API: треба mock (unittest.mock.patch)
```

### --keepdb: прискорення при великих міграціях (notes_chat_app)

```bash
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# Перший запуск: CREATE + migrate (повільно)
# Наступні: тільки нові міграції (швидко)
# Корисно при великій кількості міграцій
```

---

## 05 · AAA ПАТТЕРН

> Кожен тест має три чіткі частини. Це стандарт у всіх мовах.

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: підготовка стану ─────────────────────────────────────────
    # Що потрібно для тесту? Створюємо мінімально необхідний стан.
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: виконуємо те, що тестуємо ───────────────────────────────────
    # Один виклик — одна дія. Що саме тестуємо? Тільки це.
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: перевіряємо результат ────────────────────────────────────
    # Що має бути правдою після Act? Перевіряємо конкретно.
    note_tags = list(note.tags.all())
    self.assertIn(tag1, note_tags)
    self.assertIn(tag2, note_tags)
```

### Правила гарного тесту

| Правило | Пояснення |
|---------|-----------|
| **Один тест — одна поведінка** | `test_create_note_sets_user` ≠ `test_create_note_saves_to_db` |
| **Назва = специфікація** | `test_add_user_to_group_duplicate_returns_false` — назва пояснює все |
| **Незалежність** | Тест не залежить від порядку і від інших тестів |
| **Швидкість** | Unit тест < 50мс. Якщо повільно — перевір чи не робиш зайвих запитів |
| **Детермінованість** | Той самий тест при тих самих умовах = той самий результат |

### Типові помилки у назвах тестів

```python
# ✗ ПОГАНО: незрозуміло що саме тестується
def test_note(self): ...
def test_service(self): ...
def test_1(self): ...

# ✓ ДОБРЕ: назва = що перевіряємо → якого результату очікуємо
def test_create_note_sets_correct_user(self): ...
def test_note_group_becomes_null_when_group_deleted(self): ...
def test_non_owner_gets_404_on_note_edit(self): ...
def test_notebook_queryset_excludes_other_user_notebooks(self): ...
```

---

## 06 · ЧИТАННЯ ВИВОДУ

> Розуміти що показує `manage.py test` — ключова навичка.

### Успішний запуск

```bash
# crispy_notes_project:
$ python manage.py test hello_app.tests -v 2

Creating test database for alias 'default' ...
Found 129 test(s).

test_str_returns_hash_name (hello_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
test_create_note_assigns_tags (...) ... ok
...

----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK   ← ВСЕ ЗЕЛЕНО! Можна робити git push.

# notes_chat_app (у Docker):
$ docker compose run --rm web python manage.py test notes_app.tests -v 2
...
OK (skipped=6)
#  ↑ 123 passed, 6 skipped (Selenium без geckodriver) — ВСЕ ЗЕЛЕНО!
```

### Провалений тест

```bash
FAIL: test_create_notebook_default_unsets_previous_default
----------------------------------------------------------------------
Traceback (most recent call last):
  File "tests/test_services.py", line 179, in test_create_notebook_...
    self.assertFalse(old_default.is_default)
AssertionError: True is not false

----------------------------------------------------------------------
Ran 129 tests in 77.1s

FAILED (failures=1)
```

**Як читати провалений тест:**

```
FAIL: test_create_notebook_default_unsets_previous_default
 ↑ Назва тесту → одразу зрозуміло ЩО зламалось

File "tests/test_services.py", line 179
 ↑ Де саме у файлі

self.assertFalse(old_default.is_default)
AssertionError: True is not false
 ↑ Очікували False, отримали True
   → Старий default НЕ скинувся
   → Баг у services.create_notebook()
```

### Типи результатів

| Символ | Означає | Причина |
|--------|---------|---------|
| `.` | PASSED | Тест пройшов |
| `F` | FAILED | `assert` не спрацював — неправильний результат |
| `E` | ERROR | Виняток в тесті (не AssertionError) — наприклад, AttributeError |
| `s` | SKIPPED | `@unittest.skip` або `@unittest.skipUnless` — тест пропущений навмисно |
| `x` | XFAIL | Очікуваний провал (`@unittest.expectedFailure`) |

### Рівні verbosity (-v 0/1/2)

```bash
# -v 0: тільки підсумок
python manage.py test hello_app.tests
# OK або FAILED (failures=3)

# -v 1 (default): крапки прогресу
python manage.py test hello_app.tests -v 1
# ...............F........ (129 тестів)

# -v 2: кожен тест окремо (рекомендовано)
python manage.py test hello_app.tests -v 2
# test_str_returns_hash_name ... ok
# test_unique_together... ... ok
```

### Зупинитись на першому провалі

```bash
python manage.py test hello_app.tests --failfast
# Зупиняється одразу при першому FAIL
# Корисно при великій кількості помилок

# notes_chat_app:
docker compose run --rm web python manage.py test notes_app.tests --failfast
```

---

## Далі

- **[test_models.py](test_models.md)** — що живе в моделі, структура tests/, validators, SET_NULL
