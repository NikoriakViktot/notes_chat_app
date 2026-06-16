# test_forms.py — Тестування форм

---

## Два режими форми: bound vs unbound

> **Форма в Django — не просто HTML.** Це валідація, нормалізація і security бар'єр.

```python
# UNBOUND форма — без даних (для відображення порожньої форми)
form = NoteForm(user=self.alice)
# form.is_bound → False
# Корисно для тестування queryset полів (security)

# BOUND форма — з даними (для обробки POST запиту)
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
# form.is_bound → True
# Можна викликати form.is_valid(), form.cleaned_data, form.errors
```

### Як тестувати форму без HTTP

```python
# Форму можна тестувати прямо, без client.post():

form = TagForm(data={'name': 'Python', 'color': '#ff0000'}, user=self.alice)

# Перевірка валідності:
form.is_valid()              # True або False — перевіряємо
form.cleaned_data['name']   # 'python' — нормалізоване значення
form.errors                  # {'name': ['...']} — помилки по полях

# Перевіряємо валідну форму:
form = NoteForm(data={'title': 'Test', 'priority': 1}, user=self.alice)
self.assertTrue(form.is_valid(), msg=form.errors)
# ↑ msg=form.errors — якщо провалиться, побачимо ЧОМУ невалідна

# Перевіряємо невалідну форму:
form = NoteForm(data={'title': '', 'priority': 1}, user=self.alice)
self.assertFalse(form.is_valid())
self.assertIn('title', form.errors)
# ↑ Перевіряємо що помилка у КОНКРЕТНОМУ полі (не загальна)
```

---

## Структура test_forms.py

```python
# notes_app/tests/test_forms.py
from django.contrib.auth.models import Group, User
from django.test import TestCase

from notes_app.forms import GroupCreateForm, NoteForm, TagForm
from notes_app.models import Notebook, Tag


class BaseFormTest(TestCase):
    """Базовий клас: alice і bob для security тестів."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class TagFormTest(BaseFormTest):
    """Тести нормалізації і базової валідації TagForm."""

    def test_name_normalized_to_lowercase(self):
        """Tag name зберігається у нижньому регістрі."""
        form = TagForm(data={'name': 'PYTHON', 'color': '#3776AB'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'python')

    def test_name_strips_whitespace(self):
        """'  work  ' → 'work' (пробіли по краях прибираються)."""
        form = TagForm(data={'name': '  work  ', 'color': '#ff0000'}, user=self.alice)
        self.assertTrue(form.is_valid())
        self.assertEqual(form.cleaned_data['name'], 'work')

    def test_empty_name_is_invalid(self):
        form = TagForm(data={'name': '', 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
        self.assertIn('name', form.errors)

    def test_name_too_long_is_invalid(self):
        form = TagForm(data={'name': 'x' * 51, 'color': '#000000'}, user=self.alice)
        self.assertFalse(form.is_valid())
```

---

## NoteFormSecurityTest — повний security блок

```python
class NoteFormSecurityTest(BaseFormTest):
    """
    Найважливіший блок тестів форм — перевіряємо що queryset
    фільтрує тільки об'єкти поточного юзера (захист від IDOR).
    """

    def setUp(self):
        super().setUp()
        # Обидва юзери мають свої записники
        self.alice_notebook = Notebook.objects.create(user=self.alice, title="Alice's")
        self.bob_notebook   = Notebook.objects.create(user=self.bob,   title="Bob's")
        # Alice має тег
        self.alice_tag = Tag.objects.create(user=self.alice, name='my-tag')
        self.bob_tag   = Tag.objects.create(user=self.bob,   name='bob-secret')

    def test_notebook_queryset_contains_user_notebooks(self):
        """Alice бачить СВІЙ записник у dropdown."""
        form = NoteForm(user=self.alice)
        self.assertIn(self.alice_notebook, form.fields['notebook'].queryset)

    def test_notebook_queryset_excludes_other_user_notebooks(self):
        """
        Alice НЕ бачить записники Bob'а — IDOR неможливий.

        БЕЗ захисту у формі:
            NoteForm().fields['notebook'].queryset = Notebook.objects.all()
            → Alice бачить у dropdown Bob's Private Notebook!
            → Alice вибирає Bob's notebook → нотатка Alice записується до Bob
            → Bob бачить чужі нотатки у своєму записнику → DATA LEAK

        З захистом (наш NoteForm.__init__):
            queryset = Notebook.objects.filter(user=self.user)
            → Alice бачить тільки свої записники → IDOR неможливий
        """
        form = NoteForm(user=self.alice)
        self.assertNotIn(self.bob_notebook, form.fields['notebook'].queryset)

    def test_tag_queryset_contains_user_tags(self):
        """Alice бачить свої теги у dropdown."""
        form = NoteForm(user=self.alice)
        self.assertIn(self.alice_tag, form.fields['tags'].queryset)

    def test_tag_queryset_excludes_other_user_tags(self):
        """Alice НЕ бачить теги Bob'а."""
        form = NoteForm(user=self.alice)
        self.assertNotIn(self.bob_tag, form.fields['tags'].queryset)

    def test_group_queryset_excludes_groups_user_not_in(self):
        """Alice не бачить групи де вона не є членом."""
        group = Group.objects.create(name="Bob's Team")
        self.bob.groups.add(group)        # тільки Bob у групі

        form = NoteForm(user=self.alice)
        self.assertNotIn(group, form.fields['group'].queryset)

    def test_form_without_user_has_empty_querysets(self):
        """
        Якщо форму створити без user= (помилка розробника):
            form = NoteForm(data=request.POST)  ← забули user=request.user

        НЕБЕЗПЕЧНО: queryset = Notebook.objects.all() → всі записники видимі
        БЕЗПЕЧНО (наш код): queryset = Notebook.objects.none() → порожній список

        Краще показати юзеру порожній dropdown ніж злити всі дані.
        """
        form = NoteForm()  # user не переданий
        self.assertFalse(form.fields['notebook'].queryset.exists())
        self.assertFalse(form.fields['tags'].queryset.exists())
```

---

## Перевірка cleaned_data (нормалізація)

```python
class NoteFormValidationTest(BaseFormTest):

    def test_valid_form_with_required_fields(self):
        """Мінімально необхідні поля → форма валідна."""
        form = NoteForm(
            data={'title': 'My Note', 'priority': 1},
            user=self.alice,
        )
        self.assertTrue(form.is_valid(), msg=form.errors)

    def test_empty_title_is_invalid(self):
        """Порожній title → ValidationError для поля title."""
        form = NoteForm(
            data={'title': '', 'priority': 1},
            user=self.alice,
        )
        self.assertFalse(form.is_valid())
        self.assertIn('title', form.errors)

    def test_priority_valid_range(self):
        """Priority від 1 до 4 — валідний."""
        for p in [1, 2, 3, 4]:
            form = NoteForm(data={'title': 'Test', 'priority': p}, user=self.alice)
            self.assertTrue(form.is_valid(), msg=f'priority={p} should be valid')
```

---

## Перевірка помилок у конкретному полі

```python
def test_specific_field_error(self):
    """Перевіряємо що помилка у КОНКРЕТНОМУ полі, а не загальна."""
    form = NoteForm(data={'title': '', 'priority': 99}, user=self.alice)
    self.assertFalse(form.is_valid())

    # Перевіряємо конкретне поле:
    self.assertIn('title', form.errors)      # title: порожнє → required
    # або:
    self.assertIn('priority', form.errors)   # priority: 99 → out of range

    # НЕ перевіряємо тільки form.errors (можуть бути помилки у всіх полях)
    # Перевіряємо що саме у потрібному полі
```

---

## Таблиця: що перевіряємо у кожній формі

| Форма | Що тестуємо |
|-------|-------------|
| `TagForm` | `clean_name`: lowercase + strip, порожнє ім'я → помилка |
| `NoteForm` | queryset для notebook/tags/group фільтрується по user |
| `NoteForm` | без user= → порожні queryset (безпечний fallback) |
| `NoteForm` | порожній title → invalid, пріоритет 1–4 → valid |
| `GroupCreateForm` | `clean_name`: дублікат → ValidationError, strip whitespace |

---

## Запуск тестів форм

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_forms -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_forms -v 2

# Конкретний клас:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_forms.NoteFormSecurityTest -v 2
```

---

## Далі

- **[test_views.py](test_views.md)** — Test Client, force_login, три паттерни, схема доступу
