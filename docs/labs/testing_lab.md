# Testing Lab — Регресійний тест на permission bug

**Мета:** навчитися писати тест, який виявляє permission bug до того, як він потрапить у production. Зрозуміти різницю між `TestCase` і `TransactionTestCase`.

**Пов'язані файли:** `notes_app/tests/test_views.py`, `notes_app/tests/test_services.py`, `notes_app/tests/test_consumers.py`.

---

## Частина 1 — Прочитайте існуючий IDOR тест

Відкрийте `notes_app/tests/test_views.py` і знайдіть тест на IDOR (спроба доступу до чужої нотатки).

Типовий патерн:

```python
def test_cannot_access_other_users_note(self):
    alice = User.objects.create_user('alice', password='pw')
    bob = User.objects.create_user('bob', password='pw')
    note = Note.objects.create(user=bob, title="Bob's note", content="secret")

    self.client.force_login(alice)
    response = self.client.get(reverse('note_detail', kwargs={'pk': note.pk}))
    self.assertEqual(response.status_code, 404)
```

**Питання:**

1. Чому очікується `404`, а не `403`?
2. Що відбудеться якщо selector поверне `Note.objects.get(pk=pk)` без фільтрації по user?
3. Як `force_login` відрізняється від `client.login(username=..., password=...)`?

---

## Частина 2 — Напишіть регресійний тест

**Сценарій:** у вас є підозра, що при редагуванні нотатки не перевіряється ownership. Напишіть тест, що підтверджує баг, а потім доводить що його виправлено.

```python
# notes_app/tests/test_views.py — додайте клас
class NoteEditPermissionTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice_edit', password='pw')
        self.bob = User.objects.create_user('bob_edit', password='pw')
        self.bob_note = Note.objects.create(
            user=self.bob, title="Bob's private note", content="top secret"
        )

    def test_alice_cannot_edit_bobs_note(self):
        """Alice не повинна мати змогу редагувати нотатку Bob."""
        self.client.force_login(self.alice)
        url = reverse('note_update', kwargs={'pk': self.bob_note.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 404)

    def test_alice_cannot_post_to_bobs_note(self):
        """POST до чужої нотатки теж має повернути 404."""
        self.client.force_login(self.alice)
        url = reverse('note_update', kwargs={'pk': self.bob_note.pk})
        response = self.client.post(url, {'title': 'hacked', 'content': 'x', 'priority': 1})
        self.assertEqual(response.status_code, 404)
        # нотатка не змінилась
        self.bob_note.refresh_from_db()
        self.assertEqual(self.bob_note.title, "Bob's private note")
```

Запустіть:

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_views -v 2
```

---

## Частина 3 — Тест на deletion behavior

**Завдання:** напишіть тест, що перевіряє поведінку при видаленні нотатки — Reminder-и видаляються (CASCADE), але Notebook залишається.

```python
# notes_app/tests/test_models.py — додайте метод
def test_note_deletion_cascades_to_reminders(self):
    from django.utils import timezone
    note = Note.objects.create(user=self.user, title="Test", content="")
    from notes_app.models import Reminder
    Reminder.objects.create(note=note, remind_at=timezone.now())
    note_pk = note.pk
    note.delete()
    self.assertFalse(Reminder.objects.filter(note_id=note_pk).exists())
```

---

## Частина 4 — `TransactionTestCase` vs `TestCase`

**Завдання:** дослідіть різницю на практиці.

Скопіюйте будь-який тест з `test_consumers.py` і спробуйте змінити `TransactionTestCase` на `TestCase`. Запустіть:

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

**Очікуваний результат:** тест або падає з `DoesNotExist`, або з'являється неочікувана поведінка — setUp-об'єкти недоступні consumer worker thread.

**Поясніть у коментарі до коду чому так відбувається.**

---

## Частина 5 — Тест на mass assignment security

`services.py` отримує `tag_ids` і фільтрує їх по поточному user:

```python
# services.py (приблизний патерн)
tags = Tag.objects.filter(user=user, pk__in=tag_ids)
note.tags.set(tags)
```

**Завдання:** напишіть тест, що перевіряє: навіть якщо у request передаються `tag_ids` чужих тегів, вони не встановлюються:

```python
def test_cannot_assign_other_users_tags(self):
    other_user = User.objects.create_user('other_tag_test', password='pw')
    alien_tag = Tag.objects.create(user=other_user, name='alien')

    # спробуйте передати alien_tag.pk у tag_ids
    # після виклику service — нотатка не повинна мати цей тег
    ...
```

**Критерій:** тест проходить і підтверджує що чужий тег не встановлений.

---

## Підсумок: типи тестів у проєкті

| Тип | Клас | Файл |
|-----|------|------|
| Unit (модель, constraint) | `TestCase` | `test_models.py` |
| Unit (сервіс, security) | `TestCase` | `test_services.py` |
| Unit (форма, queryset) | `TestCase` | `test_forms.py` |
| Integration (HTTP, IDOR) | `TestCase` | `test_views.py` |
| Async (WebSocket) | `TransactionTestCase` | `test_consumers.py` |
| E2E (браузер) | `StaticLiveServerTestCase` | `test_selenium.py` |

---

## Оціни та обери (рівень аналізу і оцінювання)

### В.1. `TestCase` vs `TransactionTestCase` — у якому випадку що обрати?

**Сценарій:** ти пишеш тест для нової фічі — нагадування (Reminder). Нагадування створюється через service, далі Celery task (гіпотетично) зберігає результат у БД у окремому worker-процесі.

**Оціни:**
- Чому для такого сценарію `TestCase` міг би не спрацювати?
- Знайди у `test_consumers.py` коментар або патерн, що пояснює різницю.
- Якщо б ти тестував `create_reminder` service без Celery worker — який клас обрав би? Чому?
- Чи є performance trade-off між `TestCase` і `TransactionTestCase`? Де він помітний?

---

### В.2. Mock vs реальна БД у service-тестах

Два підходи до тесту `create_note`:

```python
# Підхід A: реальна БД (TestCase)
class CreateNoteTest(TestCase):
    def test_note_is_saved(self):
        note = services.create_note(user=self.user, title='T', content='')
        self.assertEqual(Note.objects.count(), 1)

# Підхід B: mock ORM
from unittest.mock import patch
class CreateNoteTest(TestCase):
    @patch('notes_app.services.Note.objects.create')
    def test_note_save_called(self, mock_create):
        mock_create.return_value = MagicMock(pk=1)
        services.create_note(user=self.user, title='T', content='')
        mock_create.assert_called_once()
```

**Оціни:**
- Що кожен підхід тестує насправді? Що кожен пропускає?
- Підхід B пройде навіть якщо `create_note` зламаний (збереже у неправильну таблицю). Чому?
- Знайди у `test_services.py` — який підхід обраний? Чому це правильне рішення для Django?
- Сформулюй правило: «я мокую коли..., і не мокую коли...»

---

### В.3. Де тестовий охоплення найважливіше?

Notes Chat App має ~205 тестів у 6 файлах. Уявімо, що є 10 годин на написання нових тестів.

**Оціни:**
- Які два файли/модулі потребують тестів найбільше? Аргументуй через ризик помилки і вартість.
- В яких ситуаціях 100% code coverage не гарантує безпеку? Наведи конкретний приклад з проєкту.
- Порівняй цінність одного IDOR-тесту (`test_views.py`) і одного `__str__` тесту (`test_models.py`). Що критичніше?
- Напиши список із 5 тестів, яких ти б додав першими, і поясни пріоритет кожного.
