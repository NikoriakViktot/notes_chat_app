# Checkpoint — Крок 6 завершено

---

## Очікуваний результат запуску

### crispy_notes_project (standalone)

```bash
$ python manage.py test hello_app.tests -v 1

Creating test database for alias 'default' ...
Found 129 test(s).
...........................................................................................................................ssssss
----------------------------------------------------------------------
Ran 129 tests in 90.2s

OK (skipped=6)
Destroying test database for alias 'default' ...
```

**Ключ до виводу:**

```
...........   ← крапки = passed tests (123 passed)
s             ← s = skipped (6 Selenium тестів без geckodriver)
F             ← F = failed (assertion не спрацювала)
E             ← E = error (виняток у тесті, не assertion)

OK (skipped=6) ← все зелено, 6 пропущено (очікувано)
```

**Що означають цифри:**

```
23  — test_models.py  (unit: constraints, __str__, SET_NULL)
36  — test_services.py (unit: бізнес-логіка, security, транзакції)
23  — test_forms.py   (unit: валідація, queryset security)
41  — test_views.py   (integration: HTTP, ownership, redirects)
 6  — test_selenium.py (E2E: браузер, skip без geckodriver)
───
129 — всього
```

### notes_chat_app (Docker + PostgreSQL + WebSocket)

```bash
$ docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2

Creating test database for alias 'default' ...
System check identified no issues.
Found 129 test(s).
test_str_returns_hash_name ... ok
test_unique_constraint_same_user_same_name_raises ... ok
...
test_authenticated_member_can_connect ... ok
test_non_member_cannot_connect ... ok
...
----------------------------------------------------------------------
Ran 129 tests in 45.3s

OK
```

```bash
# Selenium (через exec, не run!)
$ docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

test_login_form_and_redirect ... ok
test_dashboard_shows_username ... ok
test_invalid_login_shows_error ... ok
----------------------------------------------------------------------
Ran 3 tests in 28.5s
OK
```

---

## Чеклист по всіх рівнях тестування

### Структура

- [ ] `tests/__init__.py` існує (порожній файл — без нього Django не знайде тести)
- [ ] Кожен тест-метод починається з `test_`
- [ ] `setUp()` дочірнього класу що перевизначає батьківський — викликає `super().setUp()`

### Unit тести (models, services, forms)

- [ ] Validators перевіряються через `full_clean()`, а не `.objects.create()`
- [ ] Після `delete()` пов'язаного об'єкта → `refresh_from_db()` перед перевіркою
- [ ] SET_NULL поведінка задокументована тестом
- [ ] Security тест: чужий тег/записник не приєднується

### Integration тести (views)

- [ ] Integration тести використовують `force_login()`, а не `login()`
- [ ] Кожен захищений URL перевіряється на redirect для anonymous
- [ ] Bob отримує 404 для нотаток Alice (не 403)
- [ ] IDOR prevention: Alice не може POST у Bob's notebook

### Consumer тести (notes_chat_app)

- [ ] Використовується `TransactionTestCase`, а не `TestCase`
- [ ] `communicator.scope['user']` встановлений перед `connect()`
- [ ] `await communicator.disconnect()` у кожному тесті
- [ ] `database_sync_to_async` для всіх звернень до БД з async коду

### Selenium E2E

- [ ] `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` на класі
- [ ] `_DockerLiveServerMixin` для Docker-середовища (notes_chat_app)
- [ ] Selenium: `exec` не `run` для запуску в Docker
- [ ] `manage.py test` повертає `OK` (навіть з `skipped=6`)

### CI/CD

- [ ] `.github/workflows/ci.yml` у корені репозиторію
- [ ] Job 1: unit + integration + consumer без selenium
- [ ] Job 2: selenium з `needs: test` (запускається після Job 1)
- [ ] PostgreSQL і Redis як GitHub Actions services
- [ ] `health-cmd` для PostgreSQL і Redis
- [ ] Coverage report зберігається як artifact

---

## Таблиця: що і де вчити

### Unit тести

| Концепція | Де дивитись у коді |
|-----------|-------------------|
| **Базова структура тесту** | Будь-який метод `test_*` — Arrange / Act / Assert |
| **setUp і BaseTestCase** | `BaseServiceTest.setUp()` в `test_services.py` |
| **assertRaises** | `test_models.py` — `test_unique_constraint_same_user_same_name_raises` |
| **full_clean() vs save()** | `test_models.py` — `test_priority_above_4_raises_validation_error` |
| **refresh_from_db()** | `test_models.py` — `test_note_group_becomes_null_when_group_deleted` |
| **Persistence test** | `test_services.py` — `test_toggle_pin_note_persisted_in_db` |
| **Security (Mass Assignment)** | `test_services.py` — `test_create_note_ignores_other_users_tags` |
| **Транзакційна логіка** | `test_services.py` — `test_create_notebook_default_unsets_previous_default` |
| **Ізоляція між юзерами** | `test_services.py` — `test_create_notebook_default_does_not_affect_other_users` |
| **Form queryset security** | `test_forms.py` — `NoteFormSecurityTest` |

### Integration тести

| Концепція | Де дивитись у коді |
|-----------|-------------------|
| **force_login vs login** | `BaseViewTest.setUp()` — `self.client.force_login(alice)` |
| **@login_required check** | `AuthenticationViewTest` — redirect для anonymous |
| **response.status_code** | `NoteListViewTest.test_authenticated_gets_200` |
| **assertContains / assertNotContains** | `NoteListViewTest.test_note_list_shows_only_user_notes` |
| **Ownership: 404 для чужого** | `NoteDetailViewTest.test_non_owner_gets_404` |
| **Group-based access** | `NoteDetailViewTest.test_group_member_can_view_shared_note` |
| **IDOR через view** | `NoteCreateIDORTest.test_note_create_with_bobs_notebook_fails` |
| **Form errors у context** | `NoteCreateViewTest.test_invalid_post_returns_form_with_errors` |
| **assertRedirects** | `NoteDeleteViewTest.test_delete_redirects_to_note_list` |

### Consumer тести (notes_chat_app)

| Концепція | Де дивитись у коді |
|-----------|-------------------|
| **TransactionTestCase** | `GroupChatConsumerTest(TransactionTestCase)` |
| **WebsocketCommunicator** | `communicator.connect()`, `receive_json_from()`, `disconnect()` |
| **scope['user']** | `communicator.scope['user'] = self.alice` |
| **database_sync_to_async** | `await database_sync_to_async(ChatMessage.objects.create)(...)` |
| **broadcast тест** | `test_send_message_saves_to_db_and_broadcasts` |

### E2E тести

| Концепція | Де дивитись у коді |
|-----------|-------------------|
| **StaticLiveServerTestCase** | Базовий клас Selenium тестів |
| **_DockerLiveServerMixin** | `host = '0.0.0.0'`, `live_server_url` → `http://web:PORT` |
| **Session cookie trick** | `_login_via_cookie()` — обходить login форму |
| **Remote WebDriver** | `_make_driver()` → `SELENIUM_REMOTE_URL` |
| **implicitly_wait** | `cls.driver.implicitly_wait(5)` — чекати до 5 сек на елемент |
| **skipUnless** | `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` |
| **find_element + send_keys** | `test_login_form_and_redirect` |

---

## Практичне завдання

### Завдання 1 — Написати тест (рівень: базовий)

Напиши тест що перевіряє: якщо юзер видаляє `TodoList`, всі пов'язані `TodoItem` видаляються разом (CASCADE).

```python
# Підказка:
def test_todo_items_deleted_when_todo_list_deleted(self):
    todo_list = TodoList.objects.create(user=self.alice, title='Shopping')
    TodoItem.objects.create(todo_list=todo_list, text='Milk')
    TodoItem.objects.create(todo_list=todo_list, text='Bread')

    todo_list.delete()

    self.assertEqual(TodoItem.objects.count(), ___)  # що тут?
```

### Завдання 2 — Security тест (рівень: середній)

Напиши тест що підтверджує: Bob (залогінений) не може відредагувати нотатку Alice (Bob отримує 404).

```python
# Підказка:
def test_non_owner_cannot_edit_note(self):
    alice_note = Note.objects.create(user=self.alice, title='Private')
    self.client.force_login(self.bob)

    response = self.client.get(
        reverse('notes_app:note_edit', args=[alice_note.pk])
    )

    self.assertEqual(response.status_code, ___)  # що тут?
```

### Завдання 3 — Consumer тест (рівень: просунутий)

Напиши тест що підтверджує: якщо group з `pk=999` не існує, consumer відхиляє з'єднання.

```python
# Підказка: використовуй WebsocketCommunicator з неіснуючим pk
async def test_nonexistent_group_rejects_connection(self):
    communicator = WebsocketCommunicator(
        application,
        '/ws/groups/999/chat/',
    )
    communicator.scope['user'] = self.alice

    connected, code = await communicator.connect()
    self.assertFalse(connected)
    await communicator.disconnect()
```

---

## Навігація

**Попередній:** [Крок 5. Auth і Безпека](../05_auth_and_security/index.md) — AuthN vs AuthZ, Sessions, IDOR, Group Sharing

**Наступний:** [Крок 7. Async Django](../07_async/index.md) — ASGI, Django Channels, GroupChatConsumer, channel layer
