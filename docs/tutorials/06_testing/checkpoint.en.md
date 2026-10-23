# Checkpoint — Step 6 complete

---

## Expected run result

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

**Key to the output:**

```
...........   ← dots = passed tests (123 passed)
s             ← s = skipped (6 Selenium tests without geckodriver)
F             ← F = failed (an assertion did not hold)
E             ← E = error (an exception in the test, not an assertion)

OK (skipped=6) ← all green, 6 skipped (expected)
```

**What the numbers mean:**

```
23  — test_models.py  (unit: constraints, __str__, SET_NULL)
36  — test_services.py (unit: business logic, security, transactions)
23  — test_forms.py   (unit: validation, queryset security)
41  — test_views.py   (integration: HTTP, ownership, redirects)
 6  — test_selenium.py (E2E: browser, skipped without geckodriver)
───
129 — total
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
Found 206 test(s).
test_str_returns_hash_name ... ok
test_unique_together_same_user_same_name_raises ... ok
...
test_member_can_connect ... ok
test_non_member_rejected ... ok
...
----------------------------------------------------------------------
Ran 206 tests in 45.3s

OK
```

```bash
# Selenium (via exec, not run!)
$ docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2

test_login_page_renders ... ok
test_valid_login_redirects_to_notes ... ok
test_invalid_login_shows_error ... ok
...
----------------------------------------------------------------------
Ran 23 tests in 98.5s
OK
```

---

## Checklist across all testing levels

### Structure

- [ ] `tests/__init__.py` exists (an empty file — without it Django won't find the tests)
- [ ] Every test method starts with `test_`
- [ ] A child class `setUp()` that overrides the parent one calls `super().setUp()`

### Unit tests (models, services, forms)

- [ ] Validators are checked via `full_clean()`, not `.objects.create()`
- [ ] After `delete()` of a related object → `refresh_from_db()` before checking
- [ ] SET_NULL behavior is documented by a test
- [ ] Security test: someone else's tag/notebook is not attached

### Integration tests (views)

- [ ] Integration tests use `force_login()`, not `login()`
- [ ] Every protected URL is checked for a redirect for anonymous users
- [ ] Bob gets 404 for Alice's notes (not 403)
- [ ] IDOR prevention: Alice cannot POST into Bob's notebook

### Consumer tests (notes_chat_app)

- [ ] `TransactionTestCase` is used, not `TestCase`
- [ ] `communicator.scope['user']` is set before `connect()`
- [ ] `await communicator.disconnect()` in every test
- [ ] `database_sync_to_async` for all database access from async code

### Selenium E2E

- [ ] `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` on the class
- [ ] `_DockerLiveServerMixin` for the Docker environment (notes_chat_app)
- [ ] Selenium: `exec`, not `run`, to launch in Docker
- [ ] `manage.py test` returns `OK` (even with `skipped=6`)

### CI/CD

- [ ] `.github/workflows/ci.yml` in the repository root
- [ ] Job 1: unit + integration + consumer without selenium
- [ ] Job 2: selenium with `needs: test` (runs after Job 1)
- [ ] PostgreSQL and Redis as GitHub Actions services
- [ ] `health-cmd` for PostgreSQL and Redis
- [ ] The coverage report is saved as an artifact

---

## Table: what to learn and where

### Unit tests

| Concept | Where to look in the code |
|-----------|-------------------|
| **Basic test structure** | Any `test_*` method — Arrange / Act / Assert |
| **setUp and BaseTestCase** | `BaseServiceTest.setUp()` in `test_services.py` |
| **assertRaises** | `test_models.py` — `test_unique_constraint_same_user_same_name_raises` |
| **full_clean() vs save()** | `test_models.py` — `test_priority_above_4_raises_validation_error` |
| **refresh_from_db()** | `test_models.py` — `test_note_group_becomes_null_when_group_deleted` |
| **Persistence test** | `test_services.py` — `test_toggle_pin_note_persisted_in_db` |
| **Security (Mass Assignment)** | `test_services.py` — `test_create_note_ignores_other_users_tags` |
| **Transactional logic** | `test_services.py` — `test_create_notebook_default_unsets_previous_default` |
| **Isolation between users** | `test_services.py` — `test_create_notebook_default_does_not_affect_other_users` |
| **Form queryset security** | `test_forms.py` — `NoteFormSecurityTest` |

### Integration tests

| Concept | Where to look in the code |
|-----------|-------------------|
| **force_login vs login** | `BaseViewTest.setUp()` — `self.client.force_login(alice)` |
| **@login_required check** | `AuthenticationViewTest` — redirect for anonymous users |
| **response.status_code** | `NoteListViewTest.test_authenticated_gets_200` |
| **assertContains / assertNotContains** | `NoteListViewTest.test_note_list_shows_only_user_notes` |
| **Ownership: 404 for someone else's** | `NoteDetailViewTest.test_non_owner_gets_404` |
| **Group-based access** | `NoteDetailViewTest.test_group_member_can_view_shared_note` |
| **IDOR via a view** | `NoteCreateIDORTest.test_note_create_with_bobs_notebook_fails` |
| **Form errors in context** | `NoteCreateViewTest.test_invalid_post_returns_form_with_errors` |
| **assertRedirects** | `NoteDeleteViewTest.test_delete_redirects_to_note_list` |

### Consumer tests (notes_chat_app)

| Concept | Where to look in the code |
|-----------|-------------------|
| **TransactionTestCase** | `GroupChatConsumerTest(TransactionTestCase)` |
| **WebsocketCommunicator** | `communicator.connect()`, `receive_json_from()`, `disconnect()` |
| **scope['user']** | `communicator.scope['user'] = self.alice` |
| **database_sync_to_async** | `await database_sync_to_async(ChatMessage.objects.create)(...)` |
| **broadcast test** | `test_send_message_saves_to_db_and_broadcasts` |

### E2E tests

| Concept | Where to look in the code |
|-----------|-------------------|
| **StaticLiveServerTestCase** | Base class of the Selenium tests |
| **_DockerLiveServerMixin** | `host = '0.0.0.0'`, `live_server_url` → `http://web:PORT` |
| **Session cookie trick** | `_login_via_cookie()` — bypasses the login form |
| **Remote WebDriver** | `_make_driver()` → `SELENIUM_REMOTE_URL` |
| **implicitly_wait** | `cls.driver.implicitly_wait(5)` — wait up to 5 sec for an element |
| **skipUnless** | `@unittest.skipUnless(SELENIUM_AVAILABLE, ...)` |
| **find_element + send_keys** | `test_login_form_and_redirect` |

---

## Practical exercise

### Exercise 1 — Write a test (level: basic)

Write a test that checks: if a user deletes a `TodoList`, all related `TodoItem` records are deleted along with it (CASCADE).

```python
# Hint:
def test_todo_items_deleted_when_todo_list_deleted(self):
    todo_list = TodoList.objects.create(user=self.alice, title='Shopping')
    TodoItem.objects.create(todo_list=todo_list, text='Milk')
    TodoItem.objects.create(todo_list=todo_list, text='Bread')

    todo_list.delete()

    self.assertEqual(TodoItem.objects.count(), ___)  # what goes here?
```

### Exercise 2 — Security test (level: intermediate)

Write a test that confirms: Bob (logged in) cannot edit Alice's note (Bob gets 404).

```python
# Hint:
def test_non_owner_cannot_edit_note(self):
    alice_note = Note.objects.create(user=self.alice, title='Private')
    self.client.force_login(self.bob)

    response = self.client.get(
        reverse('notes_app:note_edit', args=[alice_note.pk])
    )

    self.assertEqual(response.status_code, ___)  # what goes here?
```

### Exercise 3 — Consumer test (level: advanced)

Write a test that confirms: if a group with `pk=999` doesn't exist, the consumer rejects the connection.

```python
# Hint: use WebsocketCommunicator with a nonexistent pk
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

## Navigation

**Previous:** [Step 5. Auth and Security](../05_auth_and_security/index.md) — AuthN vs AuthZ, Sessions, IDOR, Group Sharing

**Next:** [Step 7. Async Django](../07_async_django/index.md) — ASGI, Django Channels, GroupChatConsumer, channel layer
