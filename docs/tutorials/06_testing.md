# Туторіал 06 — Django Тестування від A до Z

> Цей туторіал проводить тебе через **повний стек тестування Django-застосунку**:
> unit тести → сервіси → форми → integration (views) → WebSocket consumers → E2E (Selenium).
>
> Проєкт — **`notes_chat_app`** — менеджер нотаток із груповим чатом.
> У цьому розділі ми розбираємо тести що вже покривають застосунок.
> Ти побачиш як кожен рівень захищає різний шар системи.
>
> **Результат:** 129+ тестів — unit + integration + consumer + Selenium

---

## Зміст

**Теорія** _(читати перед кодом)_
- [01 · НАВІЩО ТЕСТИ — сигналізація замість ручної перевірки](#01--навіщо-тести)
- [02 · ПІРАМІДА — unit vs integration vs E2E](#02--піраміда-тестування)
- [03 · DJANGO TESTCASE — як це працює під капотом](#03--django-testcase)
- [04 · ТЕСТОВА БД — ізоляція і rollback](#04--тестова-бд)
- [05 · AAA ПАТТЕРН — структура кожного тесту](#05--aaa-паттерн)
- [06 · ЧИТАННЯ ВИВОДУ — PASSED / FAILED / ERROR](#06--читання-виводу)

**Що ми тестуємо і навіщо**
- [07 · МОДЕЛІ — constraints, defaults, SET_NULL](#07--тестування-моделей)
- [08 · СЕРВІСИ — бізнес-логіка і security](#08--тестування-сервісів)
- [09 · ФОРМИ — валідація і queryset filtering](#09--тестування-форм)
- [10 · DJANGO TEST CLIENT — integration тести](#10--django-test-client)
- [11 · CONSUMERS — WebSocket тести](#11--consumers)
- [12 · SELENIUM — тести через реальний браузер у Docker](#12--selenium)

**Покрокова реалізація**
1. [Крок 0 — Запуск тестів у Docker](#крок-0--запуск)
2. [Крок 1 — Структура tests/ пакету](#крок-1--структура-tests)
3. [Крок 2 — test_models.py](#крок-2--test_modelspy)
4. [Крок 3 — test_services.py](#крок-3--test_servicespy)
5. [Крок 4 — test_forms.py](#крок-4--test_formspy)
6. [Крок 5 — test_views.py](#крок-5--test_viewspy)
7. [Крок 6 — test_consumers.py](#крок-6--test_consumerspy)
8. [Крок 7 — test_selenium.py](#крок-7--test_seleniumpy)
9. [Крок 8 — GitHub Actions CI](#крок-8--github-actions-ci)
10. [Структура файлів](#структура-файлів)

---

## 01 · НАВІЩО ТЕСТИ

> **Головне питання:** Як дізнатись що після змін нічого не зламалось?
>
> Відповідь без тестів: запустити вручну, клацати по сайту, сподіватись.
> Відповідь з тестами: запустити одну команду і побачити все за 30 секунд.

### Аналогія — пожежна сигналізація

Будинок без сигналізації: виявляєш пожежу коли вже горить.
Будинок з сигналізацією: дізнаєшся про іскру ДО того як все охопить вогнем.

**Тести = сигналізація коду.** Вони перевіряють "чи все ще правильно" при кожній зміні.

```
БЕЗ ТЕСТІВ                              З ТЕСТАМИ
──────────────────────────────────────  ──────────────────────────────────────
Пишеш новий фічер                       Пишеш новий фічер
Вручну клацаєш 10+ сторінок             docker compose run --rm web manage.py test
"Виглядає ок"                           FAIL: test_group_notes_visible_to_members
git push → деплой                       AssertionError: Note not found for bob
Через тиждень: "Групові нотатки зникли" Виправляєш за 2 хвилини до коміту
Стаєш детективом — шукаєш причину      git push → CI green → деплой безпечний
```

### Реальний сценарій: рефакторинг selectors.py

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
        user=user,        # ← забули Q-filter для груп!
        is_archived=archived,
    )
```

**Без тестів:** всі групові нотатки зникають для всіх юзерів.
Клієнти дізнаються через тиждень після деплою в production.

**З тестами:** `test_group_notes_visible_to_members` одразу:

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
| **Edge cases** | При написанні тесту думаєш: "а що якщо None? а якщо порожньо?" |
| **Захист від регресій** | Баг виправлений + тест написаний = баг ніколи не повернеться |
| **Security перевірка** | `test_notebook_queryset_excludes_other_user_notebooks` — IDOR неможливий |
| **CI сигнал** | GitHub Actions: FAIL перед merge → не деплоїш зламаний код |

---

## 02 · ПІРАМІДА ТЕСТУВАННЯ

> **Не всі тести однакові.** Різні рівні мають різну вартість і швидкість.

```
              ╱╲
             ╱E2E╲          Selenium — реальний браузер
            ╱──────╲        Повільно (~10 сек/тест), крихко
           ╱ Integr. ╲      Django Test Client: HTTP → DB → response
          ╱────────────╲    Середньо (~100мс/тест)
         ╱ Consumers    ╲   WebsocketCommunicator: WS lifecycle
        ╱────────────────╲  Середньо (~200мс/тест)
       ╱       Unit        ╲ TestCase: функція → результат
      ╱──────────────────────╲ Швидко (1-10мс/тест), надійно

    60% Unit | 25% Integration | 10% Consumers | 5% E2E
```

### Де живуть наші тести

| Рівень | Файл | Що тестує | Кількість |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Constraints, `__str__`, defaults, SET_NULL | ~23 |
| Unit | `tests/test_services.py` | CRUD, security, транзакції, бізнес-правила | ~36 |
| Unit | `tests/test_forms.py` | Валідація, нормалізація, queryset filtering | ~23 |
| Integration | `tests/test_views.py` | HTTP коди, ownership, redirects, IDOR | ~41 |
| Consumer | `tests/test_consumers.py` | WebSocket auth, broadcast, disconnect | ~6 |
| E2E | `tests/test_selenium.py` | Браузер: login, форми, навігація | ~6 |

### Що тестує кожен рівень

**Unit тести** — тестуємо функцію ізольовано:

```python
# Прямий виклик — без HTTP, без шаблонів
def test_create_notebook_default_unsets_previous_default(self):
    old = services.create_notebook(user=alice, title='Old', is_default=True)
    new = services.create_notebook(user=alice, title='New', is_default=True)
    old.refresh_from_db()
    self.assertFalse(old.is_default)   # ← бізнес-інваріант: 1 default на юзера
```

**Integration тести** — через HTTP stack:

```python
# Test Client → middleware → view → БД → response
def test_note_list_shows_only_user_notes(self):
    self.client.force_login(self.alice)
    response = self.client.get(reverse('notes_app:note_list'))
    self.assertNotContains(response, "Bob's Secret Note")
```

**Consumer тести** — WebSocket lifecycle:

```python
# WebsocketCommunicator → consumer → channel layer
async def test_non_member_cannot_connect(self):
    communicator = WebsocketCommunicator(application, f'/ws/groups/{pk}/chat/')
    communicator.scope['user'] = self.bob  # не є членом групи
    connected, code = await communicator.connect()
    self.assertFalse(connected)
```

**E2E тести** — Selenium:

```python
# Реальний Chrome → DOM → форми → навігація
def test_user_can_login_and_see_dashboard(self):
    self.driver.get(f'{self.live_server_url}/accounts/login/')
    self.driver.find_element(By.NAME, 'username').send_keys('alice')
    self.driver.find_element(By.NAME, 'password').send_keys('pass123')
    self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()
    self.assertIn('/notes/', self.driver.current_url)
```

---

## 03 · DJANGO TESTCASE

> `django.test.TestCase` — це `unittest.TestCase` + магія Django.

### Що відрізняє Django TestCase від чистого unittest

```python
import unittest
from django.test import TestCase

# unittest.TestCase — базовий, без БД і Django
class PureUnitTest(unittest.TestCase):
    def test_math(self):
        self.assertEqual(2 + 2, 4)   # ОК, без БД

# django.test.TestCase — з повним Django стеком
class DjangoTest(TestCase):
    def test_with_db(self):
        user = User.objects.create_user('alice')   # ← потребує тестової БД
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

### Чому rollback між тестами — це добре

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_first(self):
        Note.objects.create(user=self.alice, title='Test Note')
        self.assertEqual(Note.objects.count(), 1)
        # Після тесту → ROLLBACK → Note зникла

    def test_second(self):
        # Note НЕ існує — кожен тест починає з чистого стану
        self.assertEqual(Note.objects.count(), 0)   # ← 0, не 1!
        # Незалежно від порядку виконання тестів!
```

**Без rollback** тести б впливали один на одного:
- тест 1 створює Note → тест 2 бачить чужу Note → `count()` = 1 замість 0
- Порядок виконання тестів впливав би на результат → нестабільні тести

**З rollback** кожен тест ізольований → результат детермінований.

### `setUp` — підготовка перед кожним тестом

```python
class NoteServiceTest(TestCase):

    def setUp(self):
        """
        Виконується ПЕРЕД КОЖНИМ тестом. БД чиста.
        Не потрібен tearDown — ROLLBACK виконується автоматично.
        """
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        # self.alice і self.bob будуть у кожному тесті
        # Після кожного тесту → ROLLBACK → вони зникають
        # Перед наступним тестом → setUp знову → нові об'єкти

    def test_something(self):
        note = services.create_note(user=self.alice, title='Test')
        # self.alice і self.bob вже тут!
```

### BaseServiceTest — DRY для спільного setUp

```python
class BaseServiceTest(TestCase):
    """Базовий клас для всіх сервісних тестів."""
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() успадковується → self.alice і self.bob є автоматично
    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)


class NotebookServiceTest(BaseServiceTest):
    # Той самий setUp, різна логіка тестів
    def test_create_notebook_returns_notebook(self):
        nb = services.create_notebook(user=self.alice, title='Work')
        self.assertIsInstance(nb, Notebook)
```

---

## 04 · ТЕСТОВА БД

> **Найважливіше правило:** тести ніколи не торкаються твоєї робочої PostgreSQL.

### Як Django створює тестову БД (PostgreSQL)

```bash
$ docker compose run --rm web python manage.py test notes_app.tests

Creating test database for alias 'default' ...
# ↑ Django: CREATE DATABASE test_notes_db
#   Окрема порожня БД, відмінна від notes_db!

System check identified no issues.
Found 129 test(s).
...............F...
FAILED (failures=1)

Destroying test database for alias 'default' ...
# ↑ DROP DATABASE test_notes_db
```

### Три рівні ізоляції одночасно

```
1. ІЗОЛЯЦІЯ ВІД РОБОЧОЇ БД:
   notes_db (твоя prod) ≠ test_notes_db (тимчасова)
   Тести не можуть зіпсувати реальні дані.

2. ІЗОЛЯЦІЯ МІЖ ТЕСТАМИ:
   Кожен тест → BEGIN TRANSACTION → код → ROLLBACK
   Тест A не бачить даних Тесту B.
   Порядок тестів не впливає на результат.

3. ІЗОЛЯЦІЯ ВІД ЗОВНІШНІХ СИСТЕМ:
   Email: EMAIL_BACKEND = console (не надсилається)
   Redis: InMemoryChannelLayer (тести без Redis)
   API:   треба mock через unittest.mock.patch
```

### У Docker — PostgreSQL для тестів

```bash
# Тести використовують той самий PostgreSQL контейнер (db)
# але створюють окрему БД: test_<POSTGRES_DB>
#
# Для прискорення: keepdb — не видаляти між запусками
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# Перший запуск: CREATE + migrate (повільно)
# Наступні: тільки migrate нові (швидко)
# Корисно при великій кількості міграцій
```

---

## 05 · AAA ПАТТЕРН

> Кожен тест має три чіткі частини. Це стандарт у всіх мовах і фреймворках.

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: підготовка стану ─────────────────────────────────────────
    # Що потрібно для тесту? Мінімально необхідний стан.
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: виконуємо те, що тестуємо ───────────────────────────────────
    # Один виклик. Що саме тестуємо?
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: перевіряємо результат ────────────────────────────────────
    # Що має бути правдою після Act? Конкретно.
    note_tags = list(note.tags.all())
    self.assertIn(tag1, note_tags)
    self.assertIn(tag2, note_tags)
```

### Правила гарного тесту

| Правило | Пояснення |
|---------|-----------|
| **Один тест — одна поведінка** | `test_create_note_sets_user` ≠ `test_create_note_saves_to_db` — різні assert |
| **Назва = специфікація** | `test_add_user_to_group_duplicate_returns_false` пояснює все без коментарів |
| **Незалежність** | Не залежить від порядку і від інших тестів (немає глобального стану) |
| **Швидкість** | Unit тест < 50мс. Якщо повільно — перевір зайві запити до БД |
| **Детермінованість** | Той самий тест при тих самих умовах = той самий результат завжди |

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

> Розуміти вивід manage.py test — ключова навичка.

### Успішний запуск (-v 2)

```bash
$ docker compose run --rm web python manage.py test notes_app.tests -v 2

Creating test database for alias 'default' ...
Found 129 test(s).

test_str_returns_hash_name (notes_app.tests.test_models.TagModelTest) ... ok
test_unique_together_same_user_same_name_raises (...) ... ok
test_unique_together_different_users_same_name_ok (...) ... ok
test_note_group_becomes_null_when_group_deleted (...) ... ok
test_create_note_sets_correct_user (...) ... ok
...
test_login_flow_redirects_to_notes (notes_app.tests.test_selenium.SeleniumLoginFlowTest) ... skipped 'selenium not installed'
...

----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK (skipped=6)
#  ↑ 123 passed, 6 skipped (Selenium без geckodriver) — ВСЕ ЗЕЛЕНО!
```

### Провалений тест

```bash
FAIL: test_create_notebook_default_unsets_previous_default
----------------------------------------------------------------------
Traceback (most recent call last):
  File "notes_app/tests/test_services.py", line 179, in test_create_notebook...
    self.assertFalse(old.is_default)
AssertionError: True is not false
#                  ↑ Очікували False, отримали True

----------------------------------------------------------------------
Ran 129 tests in 77.1s
FAILED (failures=1)
```

**Як читати:**

```
FAIL: test_create_notebook_default_unsets_previous_default
 ↑ Назва → що зламалось (інваріант: тільки 1 default на юзера)

File "tests/test_services.py", line 179
 ↑ Точне місце у файлі

self.assertFalse(old.is_default)
AssertionError: True is not false
 ↑ Очікували False (скинутий старий default)
   Отримали True (не скинувся)
   → Баг у services.create_notebook(): відсутній .update(is_default=False)
```

### Типи результатів

| Символ | Назва | Причина |
|--------|-------|---------|
| `.` | PASSED | Тест пройшов |
| `F` | FAILED | `assert` не спрацював — неправильний результат |
| `E` | ERROR | Виняток в тесті (не AssertionError) — AttributeError, ImportError тощо |
| `s` | SKIPPED | `@unittest.skip` або `@unittest.skipUnless` — навмисно пропущений |
| `x` | XFAIL | `@unittest.expectedFailure` — очікуваний провал (відомий баг) |

### Рівні verbosity

```bash
# -v 0: тільки підсумок
docker compose run --rm web python manage.py test notes_app.tests
# → OK  або  FAILED (failures=3, errors=1)

# -v 1 (default): крапки прогресу
docker compose run --rm web python manage.py test notes_app.tests -v 1
# → ...............F....s...... (129 тестів)

# -v 2: кожен тест окремо (рекомендовано)
docker compose run --rm web python manage.py test notes_app.tests -v 2
# → test_str_returns_hash_name ... ok
# → test_unique_together... ... ok
```

### Зупинитись на першому провалі

```bash
docker compose run --rm web python manage.py test notes_app.tests --failfast
# При великій кількості помилок — зупиняється одразу
# Фокусуєш увагу на першому баг, не на всіх одразу
```

---

## 07 · ТЕСТУВАННЯ МОДЕЛЕЙ

> **Питання:** Навіщо тестувати моделі? Це ж просто поля і зв'язки.
>
> **Відповідь:** Модель містить бізнес-правила. Якщо їх порушити — додаток поводиться неправильно мовчки.

### Що живе в моделі і що можна зламати

```
Note модель
  ├── priority: validators=[MinValueValidator(1), MaxValueValidator(4)]
  │     Якщо хтось видалить validators → форма прийме priority=99
  │     → PRIORITY_CHOICES не знайде 99 → KeyError у шаблоні
  │
  ├── group: ForeignKey(Group, on_delete=SET_NULL)
  │     Якщо змінити на CASCADE → видалення групи видалить всі нотатки!
  │     → Юзери втратять дані, дізнаються в production
  │
  ├── notebook: ForeignKey(Notebook, on_delete=SET_NULL)
  │     Якщо CASCADE → видалення записника видалить нотатки
  │
  ├── is_pinned: BooleanField(default=False)
  │     Якщо default=True → всі нові нотатки закріплені → сортування зламане
  │
  ├── __str__: "📌 {title}" або "{title}"
  │     Якщо змінити формат → Admin і логи показують неправильно
  │
  └── Tag: UniqueConstraint(fields=['user', 'name'])
        Якщо прибрати → два теги 'python' в одного юзера → баги у формах
```

### Повна структура test_models.py

```python
# notes_app/tests/test_models.py
from django.contrib.auth.models import Group, User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase

from notes_app.models import (
    ChatMessage, Note, Notebook, Reminder,
    ShopItem, ShoppingList, Tag, TodoItem, TodoList,
)


class TagModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')

    # ── __str__ ────────────────────────────────────────────────────────────

    def test_str_returns_hash_name(self):
        tag = Tag.objects.create(user=self.alice, name='python')
        self.assertEqual(str(tag), '#python')

    # ── UniqueConstraint ───────────────────────────────────────────────────

    def test_unique_constraint_same_user_same_name_raises(self):
        """Два однакові теги в одного юзера → IntegrityError."""
        Tag.objects.create(user=self.alice, name='work')
        with self.assertRaises(IntegrityError):
            Tag.objects.create(user=self.alice, name='work')

    def test_unique_constraint_different_users_same_name_ok(self):
        """Різні юзери можуть мати однакові назви тегів."""
        Tag.objects.create(user=self.alice, name='work')
        Tag.objects.create(user=self.bob,   name='work')   # ← OK
        self.assertEqual(Tag.objects.count(), 2)


class NoteModelTest(TestCase):

    def setUp(self):
        self.alice  = User.objects.create_user('alice', password='pass123')
        self.group  = Group.objects.create(name='Family')

    # ── Defaults ───────────────────────────────────────────────────────────

    def test_default_priority_is_1(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertEqual(note.priority, 1)

    def test_default_is_pinned_is_false(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertFalse(note.is_pinned)

    def test_default_is_archived_is_false(self):
        note = Note.objects.create(user=self.alice, title='Test')
        self.assertFalse(note.is_archived)

    # ── Validators (тільки через full_clean!) ─────────────────────────────

    def test_priority_above_4_raises_validation_error(self):
        """
        validators=[MinValueValidator(1), MaxValueValidator(4)] перевіряє full_clean().
        NOT перевіряє .objects.create() — Django обходить validators при прямому записі.
        """
        note = Note(user=self.alice, title='Test', priority=5)
        with self.assertRaises(ValidationError) as ctx:
            note.full_clean()
        self.assertIn('priority', ctx.exception.message_dict)

    def test_priority_0_raises_validation_error(self):
        note = Note(user=self.alice, title='Test', priority=0)
        with self.assertRaises(ValidationError):
            note.full_clean()

    def test_priority_4_is_valid(self):
        """Граничне значення 4 — валідне."""
        note = Note(user=self.alice, title='Test', priority=4)
        note.full_clean()   # ← не повинно кинути виняток

    # ── SET_NULL: захист від CASCADE ──────────────────────────────────────

    def test_note_group_becomes_null_when_group_deleted(self):
        """
        Документує і захищає поведінку SET_NULL:
        якщо хтось змінить на CASCADE → групові нотатки видаляться → дані юзерів втрачені.
        Цей тест впаде (DoesNotExist) і запобіжить деплою.
        """
        note = Note.objects.create(user=self.alice, title='Family note', group=self.group)

        self.group.delete()

        note.refresh_from_db()         # ← ОБОВ'ЯЗКОВО! Python-об'єкт застарів
        self.assertIsNone(note.group)  # нотатка збереглась, group = NULL ✓

    def test_note_notebook_becomes_null_when_notebook_deleted(self):
        """Видалення записника → нотатки стають без записника (не видаляються)."""
        nb   = Notebook.objects.create(user=self.alice, title='Work')
        note = Note.objects.create(user=self.alice, title='Work note', notebook=nb)

        nb.delete()

        note.refresh_from_db()
        self.assertIsNone(note.notebook)   # SET_NULL на notebook FK ✓

    # ── __str__ ────────────────────────────────────────────────────────────

    def test_str_pinned_note_has_pin_emoji(self):
        note = Note.objects.create(user=self.alice, title='Important', is_pinned=True)
        self.assertIn('Important', str(note))

    def test_str_unpinned_note(self):
        note = Note.objects.create(user=self.alice, title='Normal')
        self.assertEqual(str(note), 'Normal')


class NotebookModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_default_is_not_default(self):
        nb = Notebook.objects.create(user=self.alice, title='Work')
        self.assertFalse(nb.is_default)

    def test_str_returns_title(self):
        nb = Notebook.objects.create(user=self.alice, title='My Notebook')
        self.assertEqual(str(nb), 'My Notebook')


class ChatMessageModelTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.group = Group.objects.create(name='Team')

    def test_chat_message_cleared_when_group_deleted(self):
        """
        ChatMessage.group = FK(Group, CASCADE):
        Видалення групи → всі повідомлення чату видаляються.
        (На відміну від Note.group = SET_NULL)
        """
        ChatMessage.objects.create(
            group=self.group, author=self.alice, content='Hello!'
        )
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.group.delete()

        self.assertEqual(ChatMessage.objects.count(), 0)   # CASCADE ✓

    def test_chat_message_author_becomes_null_when_user_deleted(self):
        """
        ChatMessage.author = FK(User, SET_NULL):
        Видалення юзера → повідомлення стає анонімним (не видаляється).
        """
        msg = ChatMessage.objects.create(
            group=self.group, author=self.alice, content='I will be deleted'
        )
        self.alice.delete()

        msg.refresh_from_db()
        self.assertIsNone(msg.author)       # SET_NULL → анонімний ✓
        self.assertEqual(msg.content, 'I will be deleted')  # вміст збережений
```

### Чому `full_clean()`, а не `.save()` для validators

```python
# ❌ НЕПРАВИЛЬНО — validators ігноруються:
note = Note.objects.create(user=user, title='Test', priority=99)
# Django збереже priority=99! validators обходяться при прямому записі.
# CheckConstraint у PostgreSQL може спрацювати → IntegrityError
# Але validators (MinValueValidator, MaxValueValidator) — ні!

# ✅ ПРАВИЛЬНО — через full_clean():
note = Note(user=user, title='Test', priority=99)  # ← не зберігаємо
with self.assertRaises(ValidationError):
    note.full_clean()   # ← validators запускаються тут!

# full_clean() виконує:
# 1. validate_unique() — UniqueConstraint
# 2. clean_fields()    — field validators (MinValueValidator, MaxValueValidator...)
# 3. clean()           — custom model validation
```

---

## 08 · ТЕСТУВАННЯ СЕРВІСІВ

> **Сервіси — найкращий шар для unit тестів.** Без HTTP, без шаблонів, тільки логіка.

### Чому сервіси легко тестувати

```
VIEWS (HTTP layer):                    SERVICES (business logic):
  Приймає request                        create_note(user=alice, title='Test')
  Парсить форму                          Приймає Python об'єкти
  Перевіряє CSRF                         Повертає результат
  Викликає сервіс                        Зберігає в БД
  Рендерить шаблон                       Залежностей від HTTP немає!
  Залежить від: HTTP, sessions,
  форми, шаблони, middleware           Тестуємо прямо:
  → Складно тестувати ізольовано         result = services.create_note(...)
                                         self.assertEqual(result.title, 'Test')
```

### Два типи перевірки в кожному тесті

```python
# ТИП 1: перевірка ПОВЕРНУТОГО ОБ'ЄКТА (return value)
def test_create_note_returns_note_object(self):
    note = services.create_note(user=self.alice, title='Test')
    self.assertIsInstance(note, Note)
    self.assertEqual(note.title, 'Test')
    self.assertEqual(note.user, self.alice)

# ТИП 2: перевірка СТАНУ БД (persistence test)
def test_create_note_saves_to_database(self):
    services.create_note(user=self.alice, title='Test')
    self.assertEqual(Note.objects.count(), 1)
    # ↑ Перевіряємо що ЗБЕРЕГЛОСЬ, а не тільки що повернулось

# НАВІЩО ОБИДВА?
# Баг: create_note() повертає note але не викликає .save()
# Тест 1 пройде (об'єкт є), Тест 2 провалиться (count=0)
# Разом — повне покриття
```

### Persistence тест — "чи справді збереглось у БД?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    Помилковий код міг би:
        def toggle_pin_note(note):
            note.is_pinned = True   ← змінив у пам'яті Python
            return note             ← але не зберіг! (немає note.save())

    Тест явно читає з БД знову через окремий SELECT — не покладається на кешований об'єкт.
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)

    services.toggle_pin_note(note)

    # Читаємо НОВИЙ об'єкт з БД:
    note_from_db = Note.objects.get(pk=note.pk)
    self.assertTrue(note_from_db.is_pinned)
    # Якщо toggle_pin_note() не зберіг → note_from_db.is_pinned=False → FAIL
```

### Security тест — Mass Assignment через tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Атака: зловмисник надсилає POST /notes/new/ з tag_id що belongs to Bob.
    tag_ids=[bob_secret_tag_id]

    БЕЗ ЗАХИСТУ (вразливо):
        note.tags.set(Tag.objects.filter(id__in=tag_ids))
        → Тег Bob'а прикріплюється до нотатки Alice!
        → Alice бачить Bob's secret tag у своїй нотатці → DATA LEAK

    З ЗАХИСТОМ (наш код у services.py):
        note.tags.set(Tag.objects.filter(id__in=tag_ids, user=user))
        → filter(user=user) блокує чужі теги
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)   # чужий тег не прикріпився ✓
```

### Транзакційний інваріант — один default записник

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Бізнес-правило: у юзера ТІЛЬКИ ОДИН default записник.

    Якщо прибрати .update(is_default=False) у services.create_notebook():
      → два записники з is_default=True
      → непередбачувана поведінка sidebar (показує обидва як default)
      → форма нотатки вибирає "перший" default → хаотично

    Цей тест виявить порушення ОДРАЗУ, до деплою.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)
    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()          # ← читаємо свіжий стан з БД!
    self.assertFalse(old.is_default)  # старий скинутий ✓
    self.assertTrue(new.is_default)   # новий встановлений ✓


def test_create_notebook_default_does_not_affect_other_users(self):
    """
    Інваріант скидається тільки для ОДНОГО юзера.
    Без filter(user=user) у services.py → скинуться default ВСІХ юзерів.
    """
    alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
    bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

    # Аліса створює ще один default:
    services.create_notebook(user=self.alice, title='Alice2', is_default=True)

    bob_nb.refresh_from_db()
    self.assertTrue(bob_nb.is_default)   # Bob's default не торкнувся ✓
```

### Group services тести

```python
class GroupServiceTest(BaseServiceTest):

    def test_create_group_adds_creator_as_member(self):
        """Creator автоматично стає першим учасником."""
        group = services.create_group(name='Team', creator=self.alice)
        self.assertIn(self.alice, group.user_set.all())

    def test_add_user_to_group_returns_true_on_success(self):
        group = services.create_group(name='Team', creator=self.alice)
        ok, msg = services.add_user_to_group(group, self.bob.username)
        self.assertTrue(ok)
        self.assertEqual(msg, '')

    def test_add_user_to_group_returns_false_for_unknown_username(self):
        group = services.create_group(name='Team', creator=self.alice)
        ok, msg = services.add_user_to_group(group, 'ghost_user_xyz')
        self.assertFalse(ok)
        self.assertIn('не знайдено', msg)

    def test_add_user_to_group_returns_false_for_duplicate(self):
        """Додавання вже існуючого учасника → False, не виняток."""
        group = services.create_group(name='Team', creator=self.alice)
        services.add_user_to_group(group, self.bob.username)   # перший раз ✓
        ok, msg = services.add_user_to_group(group, self.bob.username)  # вдруге
        self.assertFalse(ok)
        self.assertIn('вже є членом', msg)

    def test_delete_group_sets_note_group_to_null(self):
        """Видалення групи → Note.group = NULL (SET_NULL)."""
        group = services.create_group(name='Fam', creator=self.alice)
        note  = Note.objects.create(user=self.alice, title='Family note', group=group)

        services.delete_group(group)

        note.refresh_from_db()
        self.assertIsNone(note.group)   # нотатка збереглась ✓
```

---

## 09 · ТЕСТУВАННЯ ФОРМ

### Як тестувати форму без HTTP

```python
# Форму тестуємо напряму — без Test Client, без HTTP:
from notes_app.forms import TagForm, NoteForm

# Валідна форма:
form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
#                                ↑ msg=form.errors: якщо провалиться → бачимо ЧОМУ

# Невалідна форма:
form = TagForm(data={'name': '', 'color': '#ff0000'}, user=self.alice)
self.assertFalse(form.is_valid())
self.assertIn('name', form.errors)

# Перевірка cleaned_data (нормалізованого значення):
form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)
form.is_valid()
self.assertEqual(form.cleaned_data['name'], 'python')   # lowercase нормалізація
```

### Найважливіший тест форм — queryset security

```python
def test_notebook_queryset_excludes_other_user_notebooks(self):
    """
    БЕЗ захисту у формі:
        NoteForm().fields['notebook'].queryset = Notebook.objects.all()
        → Alice бачить у dropdown Bob's Private Notebook!
        → Alice вибирає Bob's notebook → нотатка Alice з'являється у Bob's notebook
        → DATA LEAK

    З захистом (наш NoteForm.__init__):
        queryset = Notebook.objects.filter(user=self.user)
        → Alice бачить тільки свої записники → IDOR неможливий
    """
    alice_nb = Notebook.objects.create(user=self.alice, title="Alice's")
    bob_nb   = Notebook.objects.create(user=self.bob,   title="Bob's Private")

    form = NoteForm(user=self.alice)

    self.assertIn(alice_nb, form.fields['notebook'].queryset)
    self.assertNotIn(bob_nb, form.fields['notebook'].queryset)   # Bob не видно ✓

def test_tag_queryset_excludes_other_user_tags(self):
    """Аналогічна перевірка для тегів у NoteForm."""
    alice_tag = Tag.objects.create(user=self.alice, name='my-tag')
    bob_tag   = Tag.objects.create(user=self.bob,   name='bob-secret')

    form = NoteForm(user=self.alice)

    self.assertIn(alice_tag, form.fields['tags'].queryset)
    self.assertNotIn(bob_tag, form.fields['tags'].queryset)   # Bob не видно ✓
```

### Тест нормалізації і валідації

```python
class TagFormTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')

    def test_name_normalized_to_lowercase(self):
        """Tag name зберігається у нижньому регістрі."""
        form = TagForm(data={'name': 'PYTHON', 'color': '#3776AB'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'python')

    def test_empty_name_is_invalid(self):
        form = TagForm(data={'name': '', 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
        self.assertIn('name', form.errors)

    def test_name_too_long_is_invalid(self):
        form = TagForm(data={'name': 'x' * 51, 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
```

---

## 10 · DJANGO TEST CLIENT

> Test Client симулює HTTP запит **всередині Django процесу** — без мережі, але через весь middleware стек.

### Що проходить через Test Client

```
self.client.get('/notes/')
    ↓
SecurityMiddleware         → перевірка HTTPS заголовків
SessionMiddleware          → завантаження сесії з тестової БД
AuthenticationMiddleware   → встановлення request.user
CsrfViewMiddleware         → перевірка CSRF (відключена для test client POST)
note_list view             → @login_required → selectors → QuerySet
HTML Response              ← шаблон рендериться з реальними даними
    ↓
response.status_code       → 200 / 302 / 404
response.content           → HTML байти
response.context           → контекст шаблону (для assertContains)
```

### Базовий клас для integration тестів

```python
# notes_app/tests/test_views.py
from django.contrib.auth.models import Group, User
from django.test import TestCase
from django.urls import reverse

from notes_app.models import Note, Notebook, Tag


class BaseViewTest(TestCase):
    """Базовий клас з alice і bob для всіх view тестів."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
```

### force_login vs login

```python
# force_login — швидко, без перевірки пароля (стандарт у тестах)
self.client.force_login(self.alice)
# → не запускає auth pipeline, не перевіряє password
# → просто встановлює session cookie → request.user = alice
# → ідеально для тестів де нас не цікавить сам процес логіну

# login — повна auth pipeline (тільки якщо тестуєш сам процес login)
success = self.client.login(username='alice', password='pass123')
# → authenticate() + login() + session
# → Використовувати тільки у test_selenium або test_login_flow
```

### Патерн 1 — @login_required: redirect незалогінених

```python
class NoteListViewTest(BaseViewTest):

    def test_anonymous_redirects_to_login(self):
        """Незалогінений юзер → redirect до /accounts/login/?next=/notes/"""
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 302)
        self.assertIn('/accounts/login/', response['Location'])

    def test_authenticated_gets_200(self):
        self.client.force_login(self.alice)
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 200)

    def test_note_list_shows_only_user_notes(self):
        """Multi-tenant: Alice не бачить нотатки Bob'а."""
        Note.objects.create(user=self.bob, title="Bob's Secret Note")
        self.client.force_login(self.alice)

        response = self.client.get(reverse('notes_app:note_list'))

        self.assertNotContains(response, "Bob's Secret Note")
```

### Патерн 2 — Ownership check: 404 для чужих об'єктів

```python
class NoteDetailViewTest(BaseViewTest):

    def test_owner_gets_200(self):
        note = Note.objects.create(user=self.alice, title='Alice Note')
        self.client.force_login(self.alice)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)

    def test_non_owner_gets_404(self):
        """
        Bob намагається відкрити нотатку Alice.
        get_object_or_404(Note, pk=pk, user=request.user):
          → SELECT WHERE pk=alice_note.pk AND user_id=bob.id
          → Не знайдено → 404

        Чому 404 а не 403?
          403: "ресурс існує, але доступ заборонено" → хакер знає що id існує
          404: "такого ресурсу немає"               → менше інформації для атаки
        """
        alice_note = Note.objects.create(user=self.alice, title='Alice Private')
        self.client.force_login(self.bob)

        response = self.client.get(
            reverse('notes_app:note_detail', args=[alice_note.pk])
        )

        self.assertEqual(response.status_code, 404)

    def test_group_member_can_view_shared_note(self):
        """Член групи бачить групову нотатку."""
        group = Group.objects.create(name='Team')
        group.user_set.add(self.alice, self.bob)
        note = Note.objects.create(user=self.alice, title='Team Note', group=group)

        self.client.force_login(self.bob)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)
```

### Патерн 3 — POST form: redirect після успіху

```python
class NoteCreateViewTest(BaseViewTest):

    def setUp(self):
        super().setUp()
        self.url = reverse('notes_app:note_create')

    def test_valid_post_creates_note_and_redirects(self):
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': 'New Note',
            'content': 'Content',
            'priority': 2,
        })

        # Перевіряємо redirect після успішного POST
        self.assertEqual(response.status_code, 302)

        # Перевіряємо що запис існує у БД
        self.assertTrue(Note.objects.filter(title='New Note', user=self.alice).exists())

    def test_invalid_post_returns_form_with_errors(self):
        """Порожній title → форма не валідна → 200 (не redirect)."""
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': '',    # порожній → invalid
            'priority': 1,
        })

        self.assertEqual(response.status_code, 200)
        self.assertFalse(Note.objects.exists())   # нотатка не створилась
```

### Патерн 4 — IDOR через form: чужий notebook

```python
class NoteCreateIDORTest(BaseViewTest):

    def test_note_create_with_bobs_notebook_fails(self):
        """
        Alice намагається POST /notes/new/ з notebook=bob_notebook.id

        БЕЗ захисту у формі: Alice могла б записати нотатку до Bob's notebook
        З захистом (NoteForm queryset): форма invalid → 200, нотатка не створена
        """
        bob_nb = Notebook.objects.create(user=self.bob, title="Bob's Private")
        self.client.force_login(self.alice)

        response = self.client.post(
            reverse('notes_app:note_create'),
            data={
                'title': 'IDOR Attack',
                'notebook': bob_nb.pk,   # ← чужий записник
                'priority': 1,
            }
        )

        # Форма invalid → 200 (не redirect)
        self.assertEqual(response.status_code, 200)
        # Нотатка не створилась → IDOR blocked ✓
        self.assertFalse(Note.objects.filter(title='IDOR Attack').exists())
```

### Ключові assert методи

```python
# ── HTTP статуси ────────────────────────────────────────────────────────────
self.assertEqual(response.status_code, 200)
self.assertEqual(response.status_code, 302)
self.assertEqual(response.status_code, 404)

# ── Redirect ────────────────────────────────────────────────────────────────
self.assertRedirects(
    response,
    reverse('notes_app:note_list'),
    fetch_redirect_response=False,   # не робить другий запит за redirect URL
)

# ── Вміст відповіді ─────────────────────────────────────────────────────────
self.assertContains(response, 'Alice Note')          # текст присутній
self.assertNotContains(response, "Bob's Secret")     # текст відсутній

# ── Заголовок Location (redirect) ────────────────────────────────────────────
self.assertIn('/accounts/login/', response['Location'])

# ── Контекст шаблону ────────────────────────────────────────────────────────
self.assertIn('title', response.context['form'].errors)
self.assertEqual(len(response.context['notes']), 3)

# ── Наявність у БД ──────────────────────────────────────────────────────────
self.assertTrue(Note.objects.filter(title='New Note').exists())
self.assertEqual(Note.objects.count(), 1)
```

---

## 11 · CONSUMERS

> **WebSocket тести** — як тестувати `GroupChatConsumer` без браузера.
> `channels.testing.WebsocketCommunicator` симулює WebSocket з'єднання.

### Як WebsocketCommunicator працює

```
WebsocketCommunicator
    ↓
ASGI application (asgi.py)
    ↓
ProtocolTypeRouter → WebSocket scope
    ↓
AuthMiddlewareStack (але scope['user'] встановлюємо вручну в тестах)
    ↓
URLRouter → /ws/groups/<pk>/chat/
    ↓
GroupChatConsumer.connect()
              .receive()
              .disconnect()
```

### test_consumers.py

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TestCase

from notes_app.models import ChatMessage
from notes_project.asgi import application   # ← ASGI app для WebSocket тестів


class GroupChatConsumerTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob не є членом групи (для тесту non-member)

    async def test_authenticated_member_can_connect(self):
        """Залогінений член групи може підключитись до чату."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice   # AuthMiddlewareStack bypass

        connected, subprotocol = await communicator.connect()
        self.assertTrue(connected)

        await communicator.disconnect()

    async def test_non_member_cannot_connect(self):
        """Bob не є членом групи → consumer закриває WS (code 4404)."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.bob   # не член

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_anonymous_cannot_connect(self):
        """AnonymousUser → consumer закриває (code 4403)."""
        from django.contrib.auth.models import AnonymousUser
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = AnonymousUser()

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_connected_member_receives_history(self):
        """Після connect — consumer надсилає history повідомлень."""
        # Arrange: додаємо повідомлення в БД
        await database_sync_to_async(ChatMessage.objects.create)(
            group=self.group,
            author=self.alice,
            content='Hello world'
        )

        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice

        await communicator.connect()

        # Act: отримуємо перше повідомлення
        response = await communicator.receive_json_from()

        # Assert: це history
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Hello world')
        self.assertEqual(response['author'], 'alice')

        await communicator.disconnect()

    async def test_send_message_saves_to_db_and_broadcasts(self):
        """Повідомлення зберігається в БД і надсилається назад."""
        self.group.user_set.add(self.bob)   # bob теж у групі

        comm_alice = WebsocketCommunicator(
            application, f'/ws/groups/{self.group.pk}/chat/'
        )
        comm_bob = WebsocketCommunicator(
            application, f'/ws/groups/{self.group.pk}/chat/'
        )
        comm_alice.scope['user'] = self.alice
        comm_bob.scope['user']   = self.bob

        await comm_alice.connect()
        await comm_bob.connect()

        # Alice надсилає повідомлення
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob отримує broadcast
        bob_msg = await comm_bob.receive_json_from()
        self.assertEqual(bob_msg['type'], 'message')
        self.assertEqual(bob_msg['content'], 'Hello Bob!')
        self.assertEqual(bob_msg['author'], 'alice')

        # Перевіряємо що збереглось у БД
        count = await database_sync_to_async(ChatMessage.objects.count)()
        self.assertEqual(count, 1)

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

---

## 12 · SELENIUM

> Django Test Client не бачить JS і CSS. Selenium бачить все що бачить юзер.

### Що тестує Selenium, чого не може Test Client

```
Test Client (integration):                Selenium (E2E):
  ✓ HTTP статуси                           ✓ JavaScript поведінка
  ✓ HTML контент (assertContains)          ✓ CSS видимість елементів
  ✓ Redirect                               ✓ Форма submit через кнопку
  ✓ Шаблон context                         ✓ WebSocket з'єднання у браузері
  ✗ JavaScript events                      ✓ Bootstrap dropdown
  ✗ CSS display:none                       ✓ Реальна навігація між сторінками
  ✗ form.submit() через кнопку             ✓ Ajax запити
  ✗ WebSocket у браузері                   ✗ Дуже повільно (~10с/тест)
```

### Архітектура Selenium у Docker

```
[test runner — web container]
  │
  │ HTTP  →  StaticLiveServerTestCase  →  Django live server :PORT
  │
  │ WebDriver protocol  →  http://selenium:4444/wd/hub
  │                            │
  │                     [selenium container]
  │                       standalone-chrome
  │                            │
  │                     Chrome → GET http://web:PORT/
  │
  │ ← DOM / assertions
```

**Ключова проблема без Docker:** `localhost` у Chrome container ≠ `localhost` у test runner.
**Рішення:** bind на `0.0.0.0`, Chrome підключається за `http://web:PORT`.

### `_DockerLiveServerMixin` — універсальне рішення

```python
# notes_app/tests/test_selenium.py
import os
import unittest

try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

from django.contrib.auth.models import User
from django.contrib.staticfiles.testing import StaticLiveServerTestCase


class _DockerLiveServerMixin:
    """
    Адаптує StaticLiveServerTestCase для роботи з Selenium у Docker.

    Проблема: LiveServerTestCase за замовчуванням bind на 127.0.0.1.
    У Docker: selenium container не може дістатись до 127.0.0.1 web container.

    Рішення:
      1. host = '0.0.0.0' → bind на всі interfaces
      2. live_server_url: замінюємо '0.0.0.0' на 'web' (Docker DNS)
         http://0.0.0.0:PORT → http://web:PORT

    WEB_HOST env var: docker-compose.yml → web.environment.WEB_HOST = "web"
    Без Docker (локально): WEB_HOST не встановлено → url залишається localhost
    """
    host = '0.0.0.0'

    @property
    def live_server_url(self):
        url = super().live_server_url   # http://0.0.0.0:PORT
        web_host = os.environ.get('WEB_HOST')
        if web_host:
            return url.replace('0.0.0.0', web_host)   # http://web:PORT
        return url


def _make_driver():
    """
    Повертає Chrome WebDriver залежно від середовища:
      - SELENIUM_REMOTE_URL встановлено → Remote WebDriver (Docker selenium container)
      - Не встановлено → локальний Chrome (headless)
    """
    remote_url = os.environ.get('SELENIUM_REMOTE_URL')
    # = 'http://selenium:4444/wd/hub' (з docker-compose.yml)

    options = webdriver.ChromeOptions()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    # --disable-dev-shm-usage: Chrome в Docker використовує /tmp замість /dev/shm
    # (за замовчуванням /dev/shm у Docker = 64MB → Chrome падає)

    if remote_url:
        return webdriver.Remote(
            command_executor=remote_url,
            options=options,
        )
    else:
        options.add_argument('--headless')   # локально: без GUI вікна
        return webdriver.Chrome(options=options)
```

### Session Cookie Trick — логін без форми

```python
def _login_via_cookie(self, user):
    """
    Логін без заповнення login форми в браузері.
    Значно швидше і надійніше ніж заповнювати форму.

    Метод:
    1. Test Client (server side) створює session у тестовій БД
    2. Копіюємо sessionid cookie до Selenium Chrome
    3. Chrome надсилає цей cookie → Django вважає Chrome залогіненим

    Навіщо:
    - Login форма може мати CSRF, JS валідацію, рекапчу
    - Session cookie trick завжди надійний
    - Швидше: 1 HTTP запит замість форми
    """
    self.client.force_login(user)                     # ← server: session у БД
    session_cookie = self.client.cookies['sessionid'] # ← витягуємо cookie value

    # Chrome має бути на нашому домені перед add_cookie
    self.driver.get(f'{self.live_server_url}/')        # ← будь-який URL сайту

    self.driver.add_cookie({
        'name':  'sessionid',
        'value': session_cookie.value,
        'path':  '/',
    })
    # Тепер Chrome залогінений як user ✓
```

### Повний selenium тест

```python
@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(_DockerLiveServerMixin, StaticLiveServerTestCase):
    """E2E тест: login форма → dashboard."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.driver = _make_driver()
        cls.driver.implicitly_wait(5)   # чекати до 5 сек на елемент

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()
        super().tearDownClass()

    def setUp(self):
        self.user = User.objects.create_user(
            username='alice', password='testpass123'
        )

    def test_login_form_and_redirect(self):
        """Заповнення login форми → redirect до /notes/."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        # Заповнюємо форму
        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('testpass123')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # Після успішного login → redirect до /notes/
        WebDriverWait(self.driver, 5).until(
            EC.url_contains('/notes/')
        )
        self.assertIn('/notes/', self.driver.current_url)

    def test_dashboard_shows_username(self):
        """Після login navbar показує username."""
        self._login_via_cookie(self.user)
        self.driver.get(f'{self.live_server_url}/notes/')

        # Шукаємо username у navbar
        page_text = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertIn('alice', page_text)

    def test_invalid_login_shows_error(self):
        """Неправильний пароль → форма з помилкою."""
        self.driver.get(f'{self.live_server_url}/accounts/login/')

        self.driver.find_element(By.NAME, 'username').send_keys('alice')
        self.driver.find_element(By.NAME, 'password').send_keys('wrongpassword')
        self.driver.find_element(By.CSS_SELECTOR, '[type=submit]').click()

        # Залишились на login сторінці (немає redirect)
        self.assertIn('/accounts/login/', self.driver.current_url)

        # Повідомлення про помилку
        body = self.driver.find_element(By.TAG_NAME, 'body').text
        self.assertTrue(
            'Невірний' in body or 'Please enter' in body or 'wrong' in body.lower()
        )
```

### `@unittest.skipUnless` — graceful skip

```python
@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumTests(StaticLiveServerTestCase):
    ...

# Якщо selenium не встановлений (або SELENIUM_REMOTE_URL недоступний):
# → тести позначаються 's' (skipped), НЕ падають як 'E' (error)

# Вивід:
# ...........ssssss
# Ran 129 tests in 90.2s
# OK (skipped=6)     ← зелений результат навіть без Selenium!
```

---

## Крок 0 — Запуск

```bash
# ─── Старт стеку ────────────────────────────────────────────────────────────
docker compose up -d              # підняти всі сервіси у фоні

# ─── Unit + Integration + Consumer тести (через новий контейнер) ─────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

# ─── Selenium E2E тести (EXEC, не RUN!) ─────────────────────────────────────
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
# exec → виконується всередині ЗАПУЩЕНОГО контейнера що має DNS alias "web"
# run  → НОВИЙ контейнер без "web" alias → Selenium не може знайти Django сервер!

# ─── Всі тести одразу ─────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests -v 2
# Selenium автоматично skipped якщо SELENIUM_REMOTE_URL недоступний

# ─── Конкретний клас ──────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# ─── Конкретний тест ──────────────────────────────────────────────────────────
docker compose run --rm web python manage.py test \
  notes_app.tests.test_services.NoteServiceTest.test_create_note_sets_correct_user -v 2

# ─── Зупинитись на першому провалі ────────────────────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests --failfast

# ─── Швидкий re-run (зберегти БД між запусками) ─────────────────────────────
docker compose run --rm web python manage.py test notes_app.tests --keepdb
# Не re-creates test DB → швидше при багатьох міграціях

# ─── Coverage ─────────────────────────────────────────────────────────────────
docker compose run --rm web sh -c "
  coverage run manage.py test \
    notes_app.tests.test_models notes_app.tests.test_services \
    notes_app.tests.test_forms notes_app.tests.test_views \
    notes_app.tests.test_consumers &&
  coverage report --show-missing
"
```

---

## Крок 1 — Структура tests/

```
notes_app/
├── models.py
├── views.py
├── services.py
├── selectors.py
├── consumers.py
└── tests/
    ├── __init__.py          ← ОБОВ'ЯЗКОВИЙ! Порожній. Робить tests/ Python пакетом.
    │                          Без нього: Django не знайде тести → "Found 0 test(s)"
    ├── test_models.py       ← Unit: constraints, defaults, SET_NULL, __str__
    ├── test_services.py     ← Unit: бізнес-логіка, security, транзакції
    ├── test_forms.py        ← Unit: валідація, нормалізація, queryset filtering
    ├── test_views.py        ← Integration: HTTP, ownership, redirects, IDOR
    ├── test_consumers.py    ← Consumer: WebSocket lifecycle, auth, broadcast
    └── test_selenium.py     ← E2E: браузер, форми, навігація, DOM
```

**Чому пакет, а не один `tests.py`?**

```
tests.py → 3000+ рядків у великому проєкті, важко орієнтуватись

tests/ пакет:
  test_models.py   ← тільки моделі (~150 рядків)
  test_services.py ← тільки сервіси (~300 рядків)
  test_forms.py    ← тільки форми (~150 рядків)
  test_views.py    ← integration (~400 рядків)
  test_consumers.py ← WebSocket (~150 рядків)
  test_selenium.py ← E2E (~200 рядків)

Переваги:
  → Запускаємо окремо: manage.py test notes_app.tests.test_services
  → Кожен файл = один шар системи → легко знайти тест
  → CI може паралельно запускати різні файли
```

---

## Крок 8 — GitHub Actions CI

### Повний workflow для notes_chat_app

```yaml
# .github/workflows/ci.yml
name: CI — Test Suite

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    name: Unit + Integration + Consumer tests
    runs-on: ubuntu-latest

    services:
      # PostgreSQL у GitHub Actions (окремий container)
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user -d test_notes_db"
          --health-interval 5s
          --health-retries 5

      # Redis для channel layer
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s

    env:
      DATABASE_URL: postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:    redis://localhost:6379/0
      SECRET_KEY:   ci-secret-key-not-for-production
      DEBUG:        "False"
      ALLOWED_HOSTS: localhost,127.0.0.1

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run Unit + Integration tests
        run: |
          python manage.py test \
            notes_app.tests.test_models \
            notes_app.tests.test_services \
            notes_app.tests.test_forms \
            notes_app.tests.test_views \
            notes_app.tests.test_consumers \
            -v 2

  selenium-e2e:
    name: Selenium E2E tests
    runs-on: ubuntu-latest
    needs: test          # ← запускається ПІСЛЯ успіху unit тестів

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB:       test_notes_db
          POSTGRES_USER:     test_user
          POSTGRES_PASSWORD: test_pass
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U test_user"
          --health-interval 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ['6379:6379']

      selenium:
        image: selenium/standalone-chrome:latest
        ports: ['4444:4444']
        options: --shm-size=2g   # Chrome потребує shared memory

    env:
      DATABASE_URL:        postgres://test_user:test_pass@localhost:5432/test_notes_db
      REDIS_URL:           redis://localhost:6379/0
      SECRET_KEY:          ci-secret-key
      DEBUG:               "False"
      ALLOWED_HOSTS:       localhost,127.0.0.1
      SELENIUM_REMOTE_URL: http://localhost:4444/wd/hub
      WEB_HOST:            localhost

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run migrations
        run: python manage.py migrate --noinput

      - name: Run Selenium E2E tests
        run: python manage.py test notes_app.tests.test_selenium -v 2

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: selenium-screenshots
          path: /tmp/selenium-*.png
          # Якщо тест падає і зберігає screenshot → побачимо в Artifacts
```

### Що означають `needs` і `if: failure()`

```yaml
selenium-e2e:
  needs: test
  # ↑ Запускається тільки якщо job 'test' пройшов успішно.
  #   Якщо unit тести провалились → Selenium не запускається.
  #   Логіка: нема сенсу тестувати браузер якщо unit тести червоні.

- name: Upload screenshots on failure
  if: failure()
  # ↑ Виконується ТІЛЬКИ якщо попередній крок провалився.
  #   Selenium тест падає → зберегти screenshot для діагностики.
  #   Доступний у GitHub Actions → Artifacts → selenium-screenshots.zip
```

---

## Структура файлів

```
notes_chat_app/
│
├── .github/
│   └── workflows/
│       └── ci.yml              ← GitHub Actions: test + selenium jobs
│
├── notes_app/
│   ├── models.py               ← Note, Notebook, Tag, ChatMessage, ...
│   ├── services.py             ← Бізнес-логіка (тестуємо напряму)
│   ├── selectors.py            ← Read-only queries (Q-filter)
│   ├── forms.py                ← NoteForm, TagForm, GroupCreateForm, ...
│   ├── views.py                ← HTTP layer (@login_required + IDOR захист)
│   ├── consumers.py            ← GroupChatConsumer (WebSocket)
│   └── tests/
│       ├── __init__.py         ← ★ ОБОВ'ЯЗКОВИЙ! Порожній.
│       ├── test_models.py      ← Unit: constraints, SET_NULL, validators
│       ├── test_services.py    ← Unit: create/update/delete, security
│       ├── test_forms.py       ← Unit: validation, queryset security
│       ├── test_views.py       ← Integration: HTTP, ownership, redirects
│       ├── test_consumers.py   ← Consumer: WebSocket auth, broadcast
│       └── test_selenium.py    ← E2E: Chrome через Docker Remote WebDriver
│
└── docker-compose.yml          ← selenium сервіс на порту 4444 і 7900 (VNC)
```

---

## Підсумок: що і де шукати

| Концепція | Де у коді |
|-----------|-----------|
| **TestCase + setUp** | `test_models.py`, `test_services.py` — `class BaseServiceTest` |
| **ROLLBACK між тестами** | Автоматично — Django TestCase транзакції |
| **AAA паттерн** | Будь-який тест: `# ARRANGE / ACT / ASSERT` коментарі |
| **full_clean() для validators** | `test_models.py` — `test_priority_above_4_raises_validation_error` |
| **refresh_from_db()** | `test_models.py` — `test_note_group_becomes_null_when_group_deleted` |
| **SET_NULL тест** | `test_models.py` — захист від CASCADE |
| **Persistence тест** | `test_services.py` — `test_toggle_pin_note_persisted_in_db` |
| **Security тест** | `test_services.py` — `test_create_note_ignores_other_users_tags` |
| **Транзакційний інваріант** | `test_services.py` — `test_create_notebook_default_unsets_previous_default` |
| **Queryset security форм** | `test_forms.py` — `test_notebook_queryset_excludes_other_user_notebooks` |
| **force_login vs login** | `test_views.py` — `self.client.force_login(self.alice)` |
| **404 не 403** | `test_views.py` — `test_non_owner_gets_404` + пояснення |
| **WebSocket тести** | `test_consumers.py` — `WebsocketCommunicator` |
| **database_sync_to_async** | `test_consumers.py` — `await database_sync_to_async(...)()` |
| **_DockerLiveServerMixin** | `test_selenium.py` — `host = '0.0.0.0'`, `live_server_url` |
| **Session cookie trick** | `test_selenium.py` — `_login_via_cookie()` |
| **@skipUnless** | `test_selenium.py` — graceful skip без geckodriver |
| **CI/CD workflow** | `.github/workflows/ci.yml` — `needs:`, `services:`, `if: failure()` |

---

## Чеклист самоперевірки

- [ ] `tests/__init__.py` існує (порожній файл — без нього Django не знайде тести)
- [ ] Кожен тест-метод починається з `test_`
- [ ] `setUp()` дочірнього класу який перевизначає батьківський — викликає `super().setUp()`
- [ ] Для validators використовується `full_clean()`, не `.objects.create()`
- [ ] Після `delete()` пов'язаного об'єкта → `refresh_from_db()` перед перевіркою
- [ ] Integration тести використовують `force_login()`, а не `login()`
- [ ] WebSocket тести: `await communicator.disconnect()` у кожному тесті
- [ ] Selenium тести мають `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)`
- [ ] Selenium: `exec` не `run` для запуску в Docker
- [ ] `manage.py test` повертає `OK` (навіть з `skipped=6`)

---

## Далі

Наступний крок: [07 — Async та WebSocket](07_async.md) — ASGI, Django Channels, GroupChatConsumer, channel layer.

Модулі документації:
- [README_7.md](README_7.md) — Testing: детальний туторіал з CI/CD pipeline (crispy_notes_project)
- [README_9.md](README_9.md) — Production Stack: Docker Selenium Remote WebDriver деталі
- [docs/08_testing_and_quality/](../08_testing_and_quality/) — теоретичні матеріали: pytest, Selenium, CI/CD
