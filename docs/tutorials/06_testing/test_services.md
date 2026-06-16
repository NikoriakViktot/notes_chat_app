# test_services.py — Тестування сервісів

---

## Чому сервіси легко тестувати

> **Сервіси — найкращий шар для unit тестів.** Без HTTP, без шаблонів, тільки логіка.

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

---

## Два типи перевірки в сервісних тестах

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

---

## Persistence тест — "чи справді збереглось у БД?"

```python
def test_toggle_pin_note_persisted_in_db(self):
    """
    ВАЖЛИВО: перевіряємо що зміна збережена в БД, а не тільки в пам'яті.

    Помилковий код міг би:
        def toggle_pin_note(note):
            note.is_pinned = True   ← змінив у пам'яті Python
            return note             ← але не зберіг! (немає note.save())

    Тест ЯВНО читає з БД знову:
    """
    note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
    services.toggle_pin_note(note)

    # Завантажуємо НОВИЙ об'єкт з БД — ігноруємо кешований у пам'яті
    note_from_db = Note.objects.get(pk=note.pk)
    self.assertTrue(note_from_db.is_pinned)
    #                ↑ справді True в БД, не тільки у пам'яті об'єкта
```

---

## Тест security: Mass Assignment через tag_ids

```python
def test_create_note_ignores_other_users_tags(self):
    """
    Атака: зловмисник надсилає POST з tag_id що belongs to Bob.
    POST /notes/new/ → tag_ids=[bob_secret_tag_id]

    БЕЗ ЗАХИСТУ (вразливо):
        note.tags.set(Tag.objects.filter(id__in=tag_ids))
        → Тег Bob'а прикріплюється до нотатки Alice
        → Alice бачить Bob's secret tag у своїй нотатці → DATA LEAK

    З ЗАХИСТОМ (наш код у services.py):
        note.tags.set(Tag.objects.filter(id__in=tag_ids, user=user))
        → filter(user=user) блокує чужі теги
    """
    bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

    note = services.create_note(
        user=self.alice, title='Note', tag_ids=[bob_tag.id]
    )

    self.assertEqual(note.tags.count(), 0)   # ← чужий тег не прикріпився
```

---

## Тест транзакційної логіки

```python
def test_create_notebook_default_unsets_previous_default(self):
    """
    Бізнес-правило: у юзера ТІЛЬКИ ОДИН default записник.

    Код у services.py:
        with transaction.atomic():
            if is_default:
                Notebook.objects.filter(user=user, is_default=True)
                                .update(is_default=False)   ← СКИДАЄМО старий
            return Notebook.objects.create(..., is_default=is_default)  ← СТВОРЮЄМО новий

    Якщо прибрати рядок з .update() → два записники з is_default=True
    → форма нотатки обирає "перший" → непередбачувана поведінка

    Цей тест виявить це ОДРАЗУ.
    """
    old = services.create_notebook(user=self.alice, title='Old', is_default=True)

    new = services.create_notebook(user=self.alice, title='New', is_default=True)

    old.refresh_from_db()       # ← читаємо свіжий стан старого записника
    self.assertFalse(old.is_default)  # старий скинутий ✓
    self.assertTrue(new.is_default)   # новий встановлений ✓
```

---

## Тест ізоляції між юзерами

```python
def test_create_notebook_default_does_not_affect_other_users(self):
    """
    Критичний тест multi-user системи.

    ПОМИЛКОВИЙ КОД (не фільтрує по user):
        Notebook.objects.filter(is_default=True).update(is_default=False)
        ↑ Скидає default У ВСІХ ЮЗЕРІВ! Bob втратить свій default.

    ПРАВИЛЬНИЙ КОД:
        Notebook.objects.filter(user=user, is_default=True).update(...)
        ↑ Скидає тільки для конкретного user. Bob в безпеці.
    """
    alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
    bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

    # Аліса створює ще один default:
    services.create_notebook(user=self.alice, title='Alice2', is_default=True)

    bob_nb.refresh_from_db()
    self.assertTrue(bob_nb.is_default)   # Bob's default не торкнувся ✓
```

---

## Тест (True/False, повідомлення) патерну

```python
def test_add_user_to_group_duplicate_returns_false(self):
    """
    add_user_to_group() повертає (bool, message).
    При дублікаті → (False, 'bob вже є членом').

    Навіщо перевіряти двічі? Функція може повернути (True, '') але не додати,
    або додати але повернути (False, ''). Перевіряємо обидва аспекти.
    """
    group = services.create_group(name='Team', creator=self.alice)
    services.add_user_to_group(group, self.bob.username)   # перший раз ✓

    ok, message = services.add_user_to_group(group, self.bob.username)  # вдруге

    self.assertFalse(ok)                       # ← функція повернула False
    self.assertIn('вже є членом', message)     # ← повідомлення містить текст
    self.assertEqual(group.user_set.count(), 2) # ← БД не змінилась (alice + bob, не 3)
```

---

## Повний код test_services.py

```python
# notes_app/tests/test_services.py
from django.contrib.auth.models import Group, User
from django.test import TestCase

from notes_app import services
from notes_app.models import Note, Notebook, Tag, TodoList


class BaseServiceTest(TestCase):
    """
    Базовий клас для всіх сервісних тестів.
    Всі класи-нащадки автоматично отримують self.alice і self.bob.
    """
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class NoteServiceTest(BaseServiceTest):

    def test_create_note_sets_correct_user(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertEqual(note.user, self.alice)

    def test_create_note_returns_note_object(self):
        note = services.create_note(user=self.alice, title='Test')
        self.assertIsInstance(note, Note)

    def test_create_note_saves_to_database(self):
        services.create_note(user=self.alice, title='Test')
        self.assertEqual(Note.objects.count(), 1)

    def test_create_note_assigns_tags(self):
        tag1 = Tag.objects.create(user=self.alice, name='work')
        tag2 = Tag.objects.create(user=self.alice, name='python')

        note = services.create_note(
            user=self.alice, title='Tagged', tag_ids=[tag1.id, tag2.id]
        )

        note_tags = list(note.tags.all())
        self.assertIn(tag1, note_tags)
        self.assertIn(tag2, note_tags)

    def test_create_note_ignores_other_users_tags(self):
        """
        Атака: зловмисник надсилає POST /notes/new/ з tag_id що belongs to Bob.
        Захист: filter(id__in=tag_ids, user=user) блокує чужі теги.
        """
        bob_tag = Tag.objects.create(user=self.bob, name='bob-secret')

        note = services.create_note(
            user=self.alice, title='Note', tag_ids=[bob_tag.id]
        )

        self.assertEqual(note.tags.count(), 0)

    def test_toggle_pin_note_persisted_in_db(self):
        """Перевіряємо що зміна збережена в БД, а не тільки в пам'яті."""
        note = Note.objects.create(user=self.alice, title='Test', is_pinned=False)
        services.toggle_pin_note(note)

        note_from_db = Note.objects.get(pk=note.pk)
        self.assertTrue(note_from_db.is_pinned)


class NotebookServiceTest(BaseServiceTest):

    def setUp(self):
        super().setUp()   # ← ОБОВ'ЯЗКОВО! Викликаємо setUp батьківського класу

    def test_create_notebook_returns_notebook(self):
        nb = services.create_notebook(user=self.alice, title='Work')
        self.assertIsInstance(nb, Notebook)

    def test_create_notebook_default_unsets_previous_default(self):
        """Бізнес-правило: у юзера ТІЛЬКИ ОДИН default записник."""
        old = services.create_notebook(user=self.alice, title='Old', is_default=True)
        new = services.create_notebook(user=self.alice, title='New', is_default=True)

        old.refresh_from_db()
        self.assertFalse(old.is_default)
        self.assertTrue(new.is_default)

    def test_create_notebook_default_does_not_affect_other_users(self):
        """Інваріант скидається тільки для ОДНОГО юзера."""
        alice_nb = services.create_notebook(user=self.alice, title='Alice', is_default=True)
        bob_nb   = services.create_notebook(user=self.bob,   title='Bob',   is_default=True)

        services.create_notebook(user=self.alice, title='Alice2', is_default=True)

        bob_nb.refresh_from_db()
        self.assertTrue(bob_nb.is_default)


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
        services.add_user_to_group(group, self.bob.username)      # перший раз ✓
        ok, msg = services.add_user_to_group(group, self.bob.username)  # вдруге

        self.assertFalse(ok)
        self.assertIn('вже є членом', msg)

    def test_delete_group_sets_note_group_to_null(self):
        """Видалення групи → Note.group = NULL (SET_NULL)."""
        group = services.create_group(name='Fam', creator=self.alice)
        note  = Note.objects.create(user=self.alice, title='Family note', group=group)

        services.delete_group(group)

        note.refresh_from_db()
        self.assertIsNone(note.group)
```

---

## Запуск тестів сервісів

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_services -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_services -v 2

# Конкретний тест:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_services.NoteServiceTest.test_create_note_sets_correct_user -v 2
```

---

## Далі

- **[test_forms.py](test_forms.md)** — bound/unbound форми, queryset security, cleaned_data
