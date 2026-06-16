# test_models.py — Тестування моделей

---

## Що живе в моделі (і що можна зламати)

> **Питання:** Чому тестувати моделі? Це ж просто поля і зв'язки.
>
> **Відповідь:** Модель містить бізнес-правила. Якщо їх порушити — додаток поводиться неправильно мовчки.

```
Note модель
  ├── priority: validators=[MinValueValidator(1), MaxValueValidator(4)]
  │     Якщо хтось видалить validators → форма прийме priority=99
  │     → Відображення пріоритету зламається (KeyError в PRIORITY_CHOICES)
  │
  ├── group: ForeignKey(Group, on_delete=SET_NULL)
  │     Якщо змінити на CASCADE → видалення групи видалить всі нотатки!
  │     → Юзери втратять дані, дізнаються в production
  │
  ├── notebook: ForeignKey(Notebook, on_delete=SET_NULL)
  │     Якщо CASCADE → видалення записника видалить нотатки
  │
  ├── is_pinned: BooleanField(default=False)
  │     Якщо default стане True → всі нові нотатки стануть закріпленими
  │     → Сортування зламається
  │
  ├── __str__: "📌 {title}" або "{title}"
  │     Якщо зміниться формат → Django Admin і логи показують неправильно
  │
  └── Tag: UniqueConstraint(fields=['user', 'name'])
        Якщо прибрати → два теги 'python' в одного юзера → баги у формах
```

---

## Структура tests/ пакету

```
notes_app/
├── models.py
├── views.py
├── forms.py
├── services.py
├── selectors.py
├── consumers.py
└── tests/                          ← пакет (директорія з __init__.py)
    ├── __init__.py                  ← ОБОВ'ЯЗКОВИЙ! Порожній.
    │                                  Без нього Django не знайде тести → "Found 0 test(s)"
    ├── test_models.py               ← Unit: constraints, __str__, SET_NULL
    ├── test_services.py             ← Unit: бізнес-логіка, security
    ├── test_forms.py                ← Unit: валідація, queryset filtering
    ├── test_views.py                ← Integration: HTTP, ownership, redirects
    ├── test_consumers.py            ← Consumer: WebSocket lifecycle
    └── test_selenium.py             ← E2E: браузер
```

**Чому `tests/` пакет, а не один `tests.py`?**

```
# Варіант 1: один файл tests.py
notes_app/tests.py   ← все в одному → стає 3000+ рядків, важко орієнтуватись

# Варіант 2: пакет tests/ (наш варіант)
notes_app/tests/
    test_models.py    ← тільки моделі
    test_services.py  ← тільки сервіси
    test_forms.py     ← тільки форми
    test_views.py     ← integration
    test_consumers.py ← WebSocket
    test_selenium.py  ← E2E
```

Переваги:
- Запускаємо окремо: `manage.py test notes_app.tests.test_services`
- Кожен файл = один шар системи → легко знайти тест
- CI може паралельно запускати різні файли

---

## Як тестувати validators через `full_clean()`

```python
# ВАЖЛИВО: validators не запускаються при .save() або .objects.create()!
# Вони запускаються тільки через full_clean() або ModelForm.

# НЕПРАВИЛЬНО (validators не перевіряться):
note = Note.objects.create(user=user, title='Test', priority=5)
# ← Django просто збереже priority=5! (validators проігноровані)
# ← CheckConstraint у БД може спрацювати → IntegrityError
# ← Але validators (MinValueValidator, MaxValueValidator) — ні!

# ПРАВИЛЬНО — через full_clean():
note = Note(user=user, title='Test', priority=5)  # ← НЕ зберігаємо одразу
note.full_clean()   # ← тут запускаються validators → ValidationError

# full_clean() виконує:
# 1. validate_unique() — UniqueConstraint
# 2. clean_fields()    — field validators (MinValueValidator, MaxValueValidator...)
# 3. clean()           — custom model validation

# У тесті:
def test_priority_above_4_raises_validation_error(self):
    note = Note(user=self.user, title='Test', priority=5)
    with self.assertRaises(ValidationError) as ctx:
        note.full_clean()
    self.assertIn('priority', ctx.exception.message_dict)
    #              ↑ перевіряємо що помилка саме у полі priority
```

---

## Тест SET_NULL — захист від CASCADE

```python
def test_note_group_becomes_null_when_group_deleted(self):
    """
    Перевіряємо що Note.group = ForeignKey(Group, on_delete=SET_NULL)
    працює правильно: видалення групи → нотатка стає особистою.

    Якщо хтось змінить на CASCADE → цей тест ПРОВАЛИТЬСЯ і покаже:
    DoesNotExist: Note matching query does not exist.
    → ми дізнаємось ДО деплою що зміна зломала дані юзерів.
    """
    group = Group.objects.create(name='Family')
    note  = Note.objects.create(user=self.user, title='Family note', group=group)

    group.delete()               # видаляємо групу

    note.refresh_from_db()       # ← ОБОВ'ЯЗКОВО! читаємо свіжий стан з БД
    self.assertIsNone(note.group)# нотатка збереглась, group = NULL
```

> **Чому `refresh_from_db()`?** Після `group.delete()` об'єкт `note` у пам'яті
> ще зберігає стару reference. `refresh_from_db()` перечитує з БД.

---

## Повний код test_models.py (notes_chat_app)

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
    """Специфічно для notes_chat_app: ChatMessage і GROUP CASCADE."""

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

    def test_chat_message_deleted_when_author_deleted(self):
        """
        ChatMessage.author = FK(User, CASCADE):
        Видалення юзера → всі його повідомлення видаляються разом.
        """
        ChatMessage.objects.create(
            group=self.group, author=self.alice, content='I will be deleted'
        )
        self.assertEqual(ChatMessage.objects.count(), 1)

        self.alice.delete()

        # CASCADE: повідомлення видалено разом з автором
        self.assertEqual(ChatMessage.objects.count(), 0)
```

### Ключові assert методи у тестах моделей

```python
self.assertEqual(str(tag), '#python')     # рівність рядків
self.assertFalse(note.is_pinned)          # перевірка False
self.assertIsNone(note.group)             # перевірка None
self.assertIsNotNone(note.created_at)     # перевірка що не None
self.assertIn('Milk', str(item))          # підрядок у рядку
self.assertGreaterEqual(updated, old)     # порівняння дат

# Для перевірки винятків:
with self.assertRaises(IntegrityError):
    Tag.objects.create(user=user, name='duplicate')

with self.assertRaises(ValidationError) as ctx:
    note.full_clean()
self.assertIn('priority', ctx.exception.message_dict)
```

---

## Запуск тестів моделей

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_models -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2
```

---

## Далі

- **[test_services.py](test_services.md)** — бізнес-логіка, persistence, security, транзакції
