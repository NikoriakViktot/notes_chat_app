# Туторіал 06 — Django Тестування

**Мета:** зрозуміти піраміду тестування, написати unit-тести для моделей і сервісів, integration-тести через Django Test Client, і запустити Selenium E2E тести у Docker.

---

## Навіщо тести — сигналізація коду

Без тестів ти виявляєш баг коли юзери його знаходять у production. З тестами — за 30 секунд після `git push`.

```
БЕЗ ТЕСТІВ                              З ТЕСТАМИ
──────────────────────────────────────  ──────────────────────────────────────
Правиш selectors.py                      Правиш selectors.py
"Виглядає ок"                            python manage.py test
git push → деплой                        FAIL: test_group_notes_visible_to_members
Через тиждень: "Групові нотатки зникли"  AssertionError: Note not found for bob
Стаєш детективом                         Виправляєш за 2 хвилини до коміту
```

**Реальний сценарій:** хтось "рефакторить" `selectors.py` і забуває Q-фільтр для груп:

```python
# СТАРА (правильна):
def get_user_notes(user, *, archived=False):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups),
        is_archived=archived,
    )

# НОВА (помилка!):
def get_user_notes(user, *, archived=False):
    return Note.objects.filter(user=user, is_archived=archived)
    # ↑ групові нотатки зникли для всіх!
```

Без тестів: клієнти дізнаються через тиждень. З тестами: CI повідомляє одразу.

---

## Піраміда тестування

```
              ╱╲
             ╱E2E╲          Selenium — реальний браузер
            ╱──────╲        Повільно (~10 сек/тест), крихко
           ╱ Integr. ╲      Django Test Client: HTTP → DB → response
          ╱────────────╲    Середньо (~100мс/тест)
         ╱     Unit      ╲  TestCase: функція → результат
        ╱──────────────────╲ Швидко (1-10мс/тест), надійно

      70% Unit | 20% Integration | 10% E2E
```

| Рівень | Файл | Що тестує | Кількість |
|--------|------|-----------|-----------|
| Unit | `tests/test_models.py` | Constraints, `__str__`, `SET_NULL` | ~20 |
| Unit | `tests/test_services.py` | CRUD, security, транзакції | ~30 |
| Unit | `tests/test_forms.py` | Валідація, queryset filtering | ~20 |
| Integration | `tests/test_views.py` | HTTP коди, ownership, redirects | ~40 |
| E2E | `tests/test_selenium.py` | Браузер: форми, навігація | ~6 |

---

## Django TestCase — як це працює

`django.test.TestCase` — це `unittest.TestCase` з транзакційною ізоляцією:

```
Перед ВСІМА тестами класу:
  → Створює тестову БД (не торкається db.sqlite3 або PostgreSQL!)
  → Застосовує всі міграції

Перед КОЖНИМ тестом:
  → Відкриває транзакцію
  → Викликає setUp()

  [ ТЕСТ ВИКОНУЄТЬСЯ ]

Після КОЖНОГО тесту:
  → ROLLBACK транзакції (всі записи зникають!)

Після ВСІХ тестів:
  → Видаляє тестову БД
```

```python
class MyTest(TestCase):
    def test_first(self):
        User.objects.create_user('alice')
        self.assertEqual(User.objects.count(), 1)
        # Після тесту → ROLLBACK → alice зникла

    def test_second(self):
        self.assertEqual(User.objects.count(), 0)  # ← 0, не 1!
```

---

## AAA паттерн — структура кожного тесту

```python
def test_create_note_assigns_tags(self):

    # ── ARRANGE: підготовка стану ─────────────────────────────────────────
    tag1 = Tag.objects.create(user=self.alice, name='work')
    tag2 = Tag.objects.create(user=self.alice, name='python')

    # ── ACT: виконуємо те, що тестуємо ───────────────────────────────────
    note = services.create_note(
        user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
    )

    # ── ASSERT: перевіряємо результат ────────────────────────────────────
    self.assertIn(tag1, list(note.tags.all()))
    self.assertIn(tag2, list(note.tags.all()))
```

**Правила хорошого тесту:**
- Один тест — одна поведінка
- Назва = специфікація: `test_notebook_default_unsets_previous_default`
- Кожен тест ізольований — не залежить від порядку

---

## Структура пакету tests/

```
notes_app/
├── models.py
├── views.py
├── services.py
├── selectors.py
└── tests/
    ├── __init__.py          ← порожній — робить tests/ пакетом Python
    ├── test_models.py       ← Unit: constraints, __str__, SET_NULL
    ├── test_services.py     ← Unit: бізнес-логіка, security
    ├── test_forms.py        ← Unit: валідація, queryset filtering
    ├── test_views.py        ← Integration: HTTP, ownership, redirects
    └── test_selenium.py     ← E2E: браузер (skip без geckodriver)
```

**Чому пакет, а не один `tests.py`?**

```
tests.py → 2000+ рядків, важко орієнтуватись

tests/
  test_models.py   ← тільки моделі
  test_services.py ← тільки сервіси
  test_forms.py    ← тільки форми
  test_views.py    ← integration
  test_selenium.py ← E2E
```

`__init__.py` — порожній файл, але **обов'язковий**. Без нього Django не знайде тести.

---

## Тестування моделей — constraints і поведінка

```python
# notes_app/tests/test_models.py
from django.contrib.auth.models import Group, User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase
from notes_app.models import Note, Notebook, ShopItem, ShoppingList, Tag


class TagModelTest(TestCase):

    def setUp(self):
        self.user  = User.objects.create_user('alice', password='pass123')
        self.user2 = User.objects.create_user('bob',   password='pass123')

    def test_str_returns_hash_name(self):
        tag = Tag.objects.create(user=self.user, name='python')
        self.assertEqual(str(tag), '#python')

    def test_unique_together_same_user_same_name_raises(self):
        Tag.objects.create(user=self.user, name='work')
        with self.assertRaises(IntegrityError):
            Tag.objects.create(user=self.user, name='work')

    def test_unique_together_different_users_same_name_ok(self):
        Tag.objects.create(user=self.user,  name='work')
        Tag.objects.create(user=self.user2, name='work')  # Bob's 'work' — OK
        self.assertEqual(Tag.objects.count(), 2)
```

### Чому validators не запускаються через `.save()`

```python
# ❌ НЕПРАВИЛЬНО — validators ігноруються:
note = Note.objects.create(user=user, title='Test', priority=99)
# Django збереже priority=99 без помилки!

# ✅ ПРАВИЛЬНО — через full_clean():
def test_priority_above_4_raises_validation_error(self):
    note = Note(user=self.user, title='Test', priority=99)
    with self.assertRaises(ValidationError) as ctx:
        note.full_clean()
    self.assertIn('priority', ctx.exception.message_dict)
```

### Тест SET_NULL — захист від CASCADE

```python
def test_note_group_becomes_null_when_group_deleted(self):
    """
    Якщо хтось змінить on_delete=SET_NULL на CASCADE →
    цей тест впаде: DoesNotExist.
    Ми дізнаємось ДО деплою що зміна знищить дані юзерів.
    """
    group = Group.objects.create(name='Family')
    note  = Note.objects.create(user=self.user, title='Family note', group=group)

    group.delete()

    note.refresh_from_db()       # ← ОБОВ'ЯЗКОВО! читаємо свіжий стан з БД
    self.assertIsNone(note.group)  # нотатка збереглась, group = NULL
```

> **Чому `refresh_from_db()`?** Після `group.delete()` Python-об'єкт `note` у пам'яті ще має старе посилання. `refresh_from_db()` перечитує реальний стан з БД.

---

## Тестування сервісів — бізнес-логіка і security

Сервіси легко тестувати — вони приймають Python-об'єкти і не залежать від HTTP:

```python
# UNIT ТЕСТ — прямий виклик:
note = services.create_note(user=alice, title='Test')

# vs INTEGRATION через HTTP:
self.client.post('/notes/new/', {'title': 'Test'})
```

### BaseServiceTest — уникаємо дублювання

```python
# notes_app/tests/test_services.py
from django.contrib.auth.models import Group, User
from django.test import TestCase
from notes_app import services
from notes_app.models import Note, Notebook, Tag


class BaseServiceTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):
    # setUp() inherited — self.alice і self.bob є автоматично

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)

    def test_create_note_saves_to_database(self):
        services.create_note(user=self.alice, title='Test')
        self.assertEqual(Note.objects.count(), 1)
```

### Persistence тест — "чи справді збереглось?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    Помилковий код міг би:
        note.is_pinned = True   ← змінив у пам'яті
        return note             ← але не зберіг!

    Тест явно читає з БД знову — не покладається на кешований об'єкт.
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
    services.toggle_pin_note(note)

    note_from_db = Note.objects.get(pk=note.pk)  # ← новий об'єкт з БД
    self.assertTrue(note_from_db.is_pinned)
```

### Security тест — Mass Assignment через tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Атака: зловмисник надсилає POST з tag_id що belongs to Bob.
    Захист у services.py: filter(id__in=tag_ids, user=user)
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)  # чужий тег не прикріпився!
```

### Тест транзакційного інваріанту

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Бізнес-правило: у юзера тільки ОДИН default записник.

    Якщо прибрати .update(is_default=False) у services.py →
    два записники з is_default=True → непередбачувана поведінка форм.

    Цей тест виявить це ОДРАЗУ.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)
    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()
    self.assertFalse(old.is_default)  # старий скинутий
    self.assertTrue(new.is_default)   # новий встановлений
```

---

## Тестування форм — валідація і security

```python
# Форму тестуємо без HTTP — прямо в Python:
form = TagForm(data={'name': 'Python', 'color': '#ff0000'})
form.is_valid()              # True/False
form.cleaned_data['name']   # 'python' — нормалізоване
form.errors                  # {'name': ['...']} — помилки

# Перевірка валідних даних:
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
# ↑ msg=form.errors — якщо провалиться, побачимо ЧОМУ

# Перевірка нормалізації:
form = TagForm(data={'name': 'Python', 'color': '#ff'})
form.is_valid()
self.assertEqual(form.cleaned_data['name'], 'python')  # lowercase!
```

### Найважливіший тест форм — queryset security

```python
def test_notebook_queryset_excludes_other_user_notebooks(self):
    """
    БЕЗ захисту у формі:
        NoteForm().fields['notebook'].queryset = Notebook.objects.all()
        → Alice бачить у dropdown Bob's Private Notebook!
        → Alice записує нотатку до чужого записника → DATA LEAK

    З захистом (наш код):
        NoteForm(user=alice).fields['notebook'].queryset = Notebook.objects.filter(user=alice)
        → Alice бачить тільки свої → SAFE
    """
    alice_nb = Notebook.objects.create(user=self.alice, title="Alice's")
    bob_nb   = Notebook.objects.create(user=self.bob,   title="Bob's")

    form = NoteForm(user=self.alice)
    self.assertIn(alice_nb, form.fields['notebook'].queryset)
    self.assertNotIn(bob_nb, form.fields['notebook'].queryset)  # IDOR impossible!
```

---

## Integration тести — Django Test Client

Test Client симулює HTTP запит **всередині Django процесу** — без мережі, але через весь middleware:

```python
class NoteListViewTest(TestCase):

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')

    def test_redirects_anonymous_to_login(self):
        """@login_required — незалогінений отримує redirect."""
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 302)
        self.assertIn('/accounts/login/', response['Location'])

    def test_authenticated_user_gets_200(self):
        self.client.force_login(self.alice)
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 200)

    def test_note_list_excludes_other_user_notes(self):
        """Multi-tenant: Alice не бачить нотатки Bob'а."""
        Note.objects.create(user=self.bob, title="Bob's Secret Note")
        self.client.force_login(self.alice)
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertNotContains(response, "Bob's Secret Note")
```

### force_login vs login

```python
# force_login — швидко, без перевірки пароля (стандарт у тестах)
self.client.force_login(self.alice)

# login — повна auth pipeline (тільки якщо тестуєш сам процес логіну)
self.client.login(username='alice', password='pass123')
```

### Три ключові паттерни integration тестів

**1. Ownership check — Bob отримує 404:**

```python
def test_non_owner_gets_404(self):
    """
    Чому 404 а не 403?
    404 — нічого не відомо про ресурс (безпечніше).
    403 — ресурс існує, але доступ заборонено (розкриває інформацію).
    """
    alice_note = Note.objects.create(user=self.alice, title='Alice Note')
    self.client.force_login(self.bob)
    response = self.client.get(
        reverse('notes_app:note_detail', args=[alice_note.pk])
    )
    self.assertEqual(response.status_code, 404)
```

**2. IDOR через view (attack prevention):**

```python
def test_form_rejects_other_users_notebook(self):
    """
    Alice надсилає POST з notebook=bob_notebook.id.
    NoteForm(user=alice) queryset не містить Bob's notebook → invalid choice.
    """
    bob_nb = Notebook.objects.create(user=self.bob, title="Bob Notebook")
    self.client.force_login(self.alice)
    response = self.client.post(
        reverse('notes_app:note_create'),
        data={'title': 'Hack Note', 'notebook': bob_nb.pk, 'priority': 1},
    )
    self.assertEqual(response.status_code, 200)  # форма invalid, не redirect
    self.assertFalse(Note.objects.filter(title='Hack Note').exists())
```

**3. Group access:**

```python
def test_group_member_can_view_shared_note(self):
    group = Group.objects.create(name='Team')
    group.user_set.add(self.alice, self.bob)
    note = Note.objects.create(user=self.alice, title='Team Note', group=group)

    self.client.force_login(self.bob)
    response = self.client.get(
        reverse('notes_app:note_detail', args=[note.pk])
    )
    self.assertEqual(response.status_code, 200)
```

### Ключові assert методи

```python
self.assertEqual(response.status_code, 200)
self.assertEqual(response.status_code, 302)

self.assertRedirects(response, reverse('notes_app:note_list'),
                     fetch_redirect_response=False)

self.assertContains(response, 'Alice Note')
self.assertNotContains(response, "Bob's Secret Note")

self.assertIn('/accounts/login/', response['Location'])
self.assertIn('title', response.context['form'].errors)
```

---

## Selenium E2E — тести через реальний браузер

Django Test Client не бачить JS і CSS. Selenium бачить всe що бачить юзер.

```python
# test_selenium.py
import unittest
try:
    from selenium import webdriver
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

from django.contrib.staticfiles.testing import StaticLiveServerTestCase


@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class SeleniumLoginFlowTest(StaticLiveServerTestCase):
    ...
```

### Session Cookie Trick — логін без форми

```python
def _login_via_cookie(self):
    """Логін без заповнення login форми в браузері."""
    self.client.force_login(self.user)
    session_cookie = self.client.cookies['sessionid']

    self.driver.get(f'{self.live_server_url}/')
    self.driver.add_cookie({
        'name': 'sessionid', 'value': session_cookie.value, 'path': '/'
    })
    # Тепер driver авторизований без форми!
```

**Навіщо:** login форма може мати CSRF, JS валідацію, рекапчу. Session cookie trick надійніший.

### Headless режим (для CI)

```python
options = webdriver.ChromeOptions()
options.add_argument('--headless')  # без GUI вікна
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(options=options)
```

### `@unittest.skipUnless` — graceful skip

```python
@unittest.skipUnless(SELENIUM_AVAILABLE, "selenium not installed")
class MySeleniumTest(StaticLiveServerTestCase):
    ...
```

Якщо `selenium` не встановлений → тести позначаються `s` (skipped), **не падають**:

```
Ran 129 tests in 90.2s
OK (skipped=6)
```

---

## Запуск тестів

```bash
# Через Docker (рекомендовано — PostgreSQL, Redis, Selenium)
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models notes_app.tests.test_services \
  notes_app.tests.test_forms notes_app.tests.test_views \
  notes_app.tests.test_consumers -v 2

# Selenium E2E — ОБОВ'ЯЗКОВО exec (не run), щоб web alias був доступний
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

# Конкретний клас або тест
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteListViewTest -v 2

# Зупинитись на першому провалі
docker compose run --rm web python manage.py test notes_app.tests --failfast
```

### Читання результатів

```bash
Creating test database for alias 'default' ...
Found 129 test(s).
...........................................................ssssss
Ran 129 tests in 90.2s
OK (skipped=6)   ← все зелено, 6 Selenium пропущені (очікувано)

# Якщо тест впав:
FAIL: test_create_notebook_default_unsets_previous_default
AssertionError: True is not false
# ↑ Читаєш: назва тесту → що очікував → що отримав → знаходиш баг
```

| Символ | Означає |
|--------|---------|
| `.` | PASSED |
| `F` | FAILED — assertion не спрацював |
| `E` | ERROR — виняток у тесті |
| `s` | SKIPPED — `@unittest.skip` |

---

## Таблиця: що перевіряє кожен рівень

| | Unit (services) | Integration (views) |
|--|-----------------|---------------------|
| `@login_required` захищає view | ✗ | ✓ |
| URL routing правильний | ✗ | ✓ |
| redirect після POST | ✗ | ✓ |
| Bob отримує 404 | ✗ | ✓ |
| Бізнес-логіка правильна | ✓ | ✓ |
| Mass Assignment blocked | ✓ | ✓ |

---

## Практичне завдання

1. Запусти `docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2`. Всі тести green? Знайди тест SET_NULL і прочитай його коментар.
2. Відкрий `notes_app/tests/test_services.py`, знайди `test_create_notebook_default_unsets_previous_default`. Тимчасово змінь assert на `assertTrue(old.is_default)` — запусти тест — переконайся що бачиш FAIL.
3. Запусти тільки `NoteListViewTest` — скільки тестів? Яку вразливість перевіряє `test_note_list_excludes_other_user_notes`?
4. Запусти Selenium тести: `docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2`.

---

## Чеклист самоперевірки

- [ ] `tests/__init__.py` існує (порожній файл)
- [ ] Кожен тест починається з `test_`
- [ ] `setUp()` дочірнього класу викликає `super().setUp()`
- [ ] Для validators використовується `full_clean()`, не `.save()`
- [ ] Після `delete()` пов'язаного об'єкта — `refresh_from_db()` перед перевіркою
- [ ] Integration тести використовують `force_login()`, а не `login()`
- [ ] Selenium тести мають `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)`
- [ ] `manage.py test` повертає `OK` (навіть з `skipped=6`)

---

## Далі

Наступний крок: [07 — Async та WebSocket](07_async.md) — ASGI, Django Channels, GroupChatConsumer.

Модулі документації:
- [Testing and Quality](../08_testing_and_quality/README.md)
