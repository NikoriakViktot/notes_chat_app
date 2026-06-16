# test_views.py — Integration тести через Test Client

---

## Django Test Client

> **Питання:** Що integration тест перевіряє, чого unit тест НЕ може?

`self.client` — це `django.test.Client`, вбудований HTTP клієнт для тестів.

```python
# Автоматично доступний у кожному TestCase як self.client
from django.test import TestCase

class MyTest(TestCase):
    def test_something(self):
        self.client  # ← готовий до використання
```

Він не відкриває реальний браузер. Він симулює HTTP запит **всередині Django процесу**: мінаючи мережу, але проходячи через весь Django middleware stack.

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

### Що integration тест виявляє, чого unit НЕ виявить

| Що перевіряє | Unit (services) | Integration (views) |
|-------------|-----------------|---------------------|
| `@login_required` захищає view | ✗ | ✓ |
| URL routing (`/notes/` → note_list) | ✗ | ✓ |
| redirect після POST (302 → /notes/pk/) | ✗ | ✓ |
| form errors у контексті шаблону | ✗ | ✓ |
| Bob отримує 404 при спробі доступу | ✗ | ✓ |
| HTML сторінки містить назву нотатки | ✗ | ✓ |
| Бізнес-логіка create_note() правильна | ✓ | ✓ |

---

## `force_login` vs `login`

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

---

## Ключові атрибути response

```python
response = self.client.get(reverse('notes_app:note_list'))

response.status_code      # → 200, 302, 404, 403, 500
response.context          # → контекст шаблону {'notes': queryset, 'form': form}
response.content          # → bytes HTML відповіді
response['Location']      # → URL для редіректу (якщо 302)
response.context['form'].errors  # → {'title': ['This field is required.']}
```

### Assert методи для HTTP тестів

```python
# HTTP статус коди
self.assertEqual(response.status_code, 200)    # OK
self.assertEqual(response.status_code, 302)    # redirect
self.assertEqual(response.status_code, 404)    # not found
self.assertEqual(response.status_code, 403)    # forbidden

# Перевірка redirect
self.assertRedirects(response, reverse('notes_app:note_list'),
                     fetch_redirect_response=False)
# fetch_redirect_response=False — не робимо другий GET запит

# Текст у HTML
self.assertContains(response, 'Alice Note')    # рядок є в HTML
self.assertNotContains(response, 'Bob Secret') # рядка НЕМАЄ в HTML

# Перевірка що URL містить login
self.assertIn('/accounts/login/', response['Location'])

# Form errors
self.assertIn('title', response.context['form'].errors)

# Наявність у БД
self.assertTrue(Note.objects.filter(title='New Note').exists())
self.assertEqual(Note.objects.count(), 1)
```

---

## Структура test_views.py

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


class AuthenticationViewTest(BaseViewTest):  # ← @login_required на всіх views
class NoteListViewTest(BaseViewTest):         # ← multi-tenant ізоляція
class NoteDetailViewTest(BaseViewTest):       # ← ownership + group access
class NoteCreateViewTest(BaseViewTest):       # ← form valid/invalid, IDOR prevention
class NoteEditViewTest(BaseViewTest):         # ← ownership check (чужий → 404)
class NoteDeleteViewTest(BaseViewTest):       # ← ownership + cascade до БД
class NotebookViewTest(BaseViewTest):         # ← ownership via get_object_or_404
class GroupViewTest(BaseViewTest):            # ← membership check
class TodoListSharingViewTest(BaseViewTest):  # ← share/unshare workflow
```

---

## Три найважливіших паттерни

### Паттерн 1 — @login_required: redirect незалогінених

```python
class NoteListViewTest(BaseViewTest):

    def test_anonymous_redirects_to_login(self):
        """Незалогінений юзер → redirect до /accounts/login/?next=/notes/"""
        response = self.client.get(reverse('notes_app:note_list'))
        # Не 200! → redirect на login page
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

### Паттерн 2 — Ownership check: Bob отримує 404

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

### Паттерн 3 — POST form: redirect після успіху, 200 при помилці

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

        # Перевіряємо redirect після успішного POST (PRG паттерн)
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

### Паттерн 4 — IDOR prevention через form

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

---

## Схема доступу: що повертає кожен view для кожного юзера

```
                    alice     bob (not member)   bob (member of group)
note_list           200       200 (own notes)    200 (own notes)
note_detail (own)   200       404                404
note_detail (group) 200       404                200 ← group access!
note_edit           200       404                302+error
note_delete         302 ok    404                302+error
notebook_edit       200       404                404
group_detail        200       404                200 ← if member
group_delete        302 ok    403                403
```

---

## Що перевіряє кожна категорія тестів

```
AuthenticationViewTest    ← @login_required на кожному view
NoteListViewTest          ← multi-tenant: alice бачить тільки свої нотатки
NoteDetailViewTest        ← ownership + group-based access
NoteCreateViewTest        ← form valid/invalid, IDOR prevention, note.user = request.user
NoteEditViewTest          ← ownership: чужий → 404; свій → 302
NoteDeleteViewTest        ← ownership + cascade: нотатка видалена з БД
NotebookViewTest          ← ownership: get_object_or_404(user=request.user)
GroupViewTest             ← membership check: чужий → 404, non-member delete → 403
TodoListSharingViewTest   ← share/unshare workflow через HTTP
```

---

## Запуск integration тестів

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_views -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_views -v 2

# Конкретний клас:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteDetailViewTest -v 2

# Конкретний тест:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteDetailViewTest.test_group_member_can_view_shared_note -v 2
```

---

## Далі

- **[test_consumers.py](test_consumers.md)** — WebSocket тести (тільки notes_chat_app)
