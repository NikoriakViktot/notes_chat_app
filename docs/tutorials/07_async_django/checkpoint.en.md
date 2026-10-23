# Checkpoint: Step 7

---

## Checklist 7A: Async Views (hello_app)

- [ ] `requirements.txt` contains `uvicorn`, `httpx`, `wsproto`
- [ ] `asgi.py`: `ProtocolTypeRouter` is configured
- [ ] `async_selectors.py`: lazy QuerySets (regular `def`) + `async def` only where `aget()` is used
- [ ] `async_services.py`: `sync_to_async(create_note)`, `adelete()`, `aupdate(F(...))`
- [ ] `async_views.py`: 5 async def views: `async_note_list`, `async_note_detail`, `async_note_create`, `async_note_delete`, `async_note_toggle_pin`
- [ ] `urls.py`: the `/async/notes/` URL prefix is wired up
- [ ] `tests/test_async_views.py`: async tests through `AsyncClient`
- [ ] Both servers start: `runserver` (:8000) and `uvicorn` (:8001)
- [ ] A note created through the sync view is visible through the async view (one SQLite DB)

---

## Checklist 7B: WebSocket chat (notes_chat_app)

- [ ] `daphne` is first in `INSTALLED_APPS` in `settings.py`
- [ ] `channels` is in `INSTALLED_APPS`
- [ ] `ASGI_APPLICATION = 'notes_project.asgi.application'` in `settings.py`
- [ ] `CHANNEL_LAYERS` is configured (InMemory or Redis depending on `REDIS_URL`)
- [ ] `"socket_timeout": None` in the `RedisChannelLayer CONFIG` (if Redis)
- [ ] `asgi.py`: `get_asgi_application()` BEFORE any import from `notes_app`
- [ ] `notes_project/routing.py` is created and wired into `asgi.py`
- [ ] `notes_app/consumers.py`: `GroupChatConsumer` inherits from `AsyncWebsocketConsumer`
- [ ] All ORM calls in the Consumer use `@database_sync_to_async`
- [ ] `load_history` returns `list(qs.values(...))`, not a QuerySet
- [ ] `disconnect()` calls `group_discard()` (with a `hasattr` check)
- [ ] JS client: `escapeHtml()` is applied to `data.author` and `data.content`
- [ ] nginx (if present): `proxy_http_version 1.1` + `Upgrade` + `Connection` headers
- [ ] Consumer tests pass: `docker compose run --rm web python manage.py test notes_app.tests.test_consumers`

---

## Consumer test: TransactionTestCase + WebsocketCommunicator

### Why TransactionTestCase and not TestCase

```
TestCase: wraps each test in a transaction (rollback after the test)
  → WebsocketCommunicator opens a separate thread for the consumer
  → The consumer in another thread does not see the uncommitted setUp() data
  → setUp objects (User, Group) "disappear" for the consumer

TransactionTestCase: does not wrap in a transaction
  → Data is written to the DB and is visible to all threads
  → The consumer sees the User and Group from setUp()
  → The right choice for tests through WebsocketCommunicator
```

### Basic structure

```python
# notes_app/tests/test_consumers.py
import json
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import User, Group
from django.test import TransactionTestCase, override_settings

from notes_project.asgi import application

TEST_CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}


def _make_session_cookie(user):
    """Helper: creates a session cookie for user."""
    from importlib import import_module
    from django.conf import settings

    engine = import_module(settings.SESSION_ENGINE)
    session = engine.SessionStore()
    if user:
        session[settings.AUTH_USER_SESSION_KEY] = user.pk
        session['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
        session['_auth_user_hash'] = user.get_session_auth_hash()
    session.save()
    return session.session_key


@override_settings(CHANNEL_LAYERS=TEST_CHANNEL_LAYERS)
class GroupChatConsumerTest(TransactionTestCase):

    def setUp(self):
        # setUp() is synchronous, even if the tests are async.
        # We make ORM calls directly: setUp() never runs
        # in an async context, so database_sync_to_async is not needed.
        self.user = User.objects.create_user('testuser', password='testpass123')
        self.other_user = User.objects.create_user('otheruser', password='testpass123')
        self.group = Group.objects.create(name='Test Group')
        self.group.user_set.add(self.user)

    def _communicator(self, user=None, group_pk=None):
        session_key = _make_session_cookie(user)
        pk = group_pk if group_pk is not None else self.group.pk
        return WebsocketCommunicator(
            application,
            f"/ws/groups/{pk}/chat/",
            headers=[(b"cookie", f"sessionid={session_key}".encode())],
        )
```

!!! note "asyncSetUp() in Django 5.1+"
    Django 5.1 added `asyncSetUp()` and `asyncTearDown()` to `TransactionTestCase`.
    In Django 5.2+ you can write:
    ```python
    async def asyncSetUp(self):
        self.user = await User.objects.acreate_user('testuser', password='pass')
        self.group = await DjangoGroup.objects.acreate(name='Chat')
        await self.group.user_set.aadd(self.user)
    ```
    Both approaches are correct. **`notes_chat_app`** uses a synchronous `setUp()`:
    it is simpler and does not require `database_sync_to_async` in the initialization method.

### Test 1: a member can connect

```python
    async def test_member_can_connect(self):
        comm = self._communicator(user=self.user)
        connected, _ = await comm.connect()
        self.assertTrue(connected)
        await comm.disconnect()
```

### Test 2: history is sent after connect

```python
    async def test_member_receives_history_on_connect(self):
        from notes_app.models import ChatMessage
        await database_sync_to_async(ChatMessage.objects.create)(
            group=self.group, author=self.user, content='Старе повідомлення',
        )

        comm = self._communicator(user=self.user)
        await comm.connect()

        response = await comm.receive_json_from()
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Старе повідомлення')

        await comm.disconnect()
```

### Test 3: a non-member is rejected

```python
    async def test_non_member_is_rejected(self):
        # other_user is NOT a member of the group
        comm = self._communicator(user=self.other_user)
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Test 4: an anonymous user is rejected

```python
    async def test_anonymous_user_is_rejected(self):
        # No cookie means anonymous
        comm = WebsocketCommunicator(
            application,
            f"/ws/groups/{self.group.pk}/chat/",
        )
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Test 5: broadcast between two users

```python
    async def test_message_broadcast_to_all_members(self):
        await database_sync_to_async(self.group.user_set.add)(self.other_user)

        comm1 = self._communicator(user=self.user)
        comm2 = self._communicator(user=self.other_user)

        await comm1.connect()
        await comm2.connect()

        await comm1.send_json_to({'content': 'Привіт від testuser'})

        response1 = await comm1.receive_json_from()
        response2 = await comm2.receive_json_from()

        self.assertEqual(response1['type'], 'message')
        self.assertEqual(response1['content'], 'Привіт від testuser')

        self.assertEqual(response2['type'], 'message')
        self.assertEqual(response2['content'], 'Привіт від testuser')
        self.assertEqual(response2['author'], 'testuser')

        await comm1.disconnect()
        await comm2.disconnect()
```

### Test 6: the message is saved to the DB

```python
    async def test_message_saved_to_database(self):
        from notes_app.models import ChatMessage

        comm = self._communicator(user=self.user)
        await comm.connect()

        await comm.send_json_to({'content': 'Тестове повідомлення'})
        await comm.receive_json_from()  # wait for the broadcast response

        count = await database_sync_to_async(
            ChatMessage.objects.filter(
                group=self.group,
                author=self.user,
                content='Тестове повідомлення',
            ).count
        )()
        self.assertEqual(count, 1)

        await comm.disconnect()
```

### Running the Consumer tests

```bash
# Consumer tests
docker compose run --rm web python manage.py test \
    notes_app.tests.test_consumers -v 2

# All tests (except Selenium)
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2
```

---

## Common mistakes and fixes

### Full table

| Error | Cause | Fix |
|---------|---------|-------------|
| `SynchronousOnlyOperation` | sync ORM in an async context | `@database_sync_to_async` |
| `AppRegistryNotReady` | import before `get_asgi_application()` | Move the imports after it |
| `TimeoutError reading from redis` | `socket_timeout=5` vs brpop | `"socket_timeout": None` |
| WS 400 through nginx | Missing Upgrade headers | `proxy_http_version 1.1` + Upgrade headers |
| WS connection closes after idle time | `socket_timeout=5` in Redis | `"socket_timeout": None, "health_check_interval": 30` |
| History does not arrive | Lazy QuerySet | `list(qs.values(...))` in `@database_sync_to_async` |
| `daphne` does not override runserver | `daphne` is not first in `INSTALLED_APPS` | Move `daphne` to the first position |
| Consumer is not found | `routing.py` is missing from `asgi.py` | Wire in `websocket_urlpatterns` |

### Fix examples

```python
# SynchronousOnlyOperation:
# ❌
async def connect(self):
    group = Group.objects.get(pk=self.group_pk)
# ✅
@database_sync_to_async
def get_group(self, pk):
    return Group.objects.get(pk=pk)

# AppRegistryNotReady:
# ❌ asgi.py: import BEFORE get_asgi_application():
from notes_project.routing import websocket_urlpatterns
django_asgi_app = get_asgi_application()
# ✅
django_asgi_app = get_asgi_application()
from notes_project.routing import websocket_urlpatterns

# time.sleep() blocks the event loop:
# ❌
async def connect(self):
    time.sleep(1)
# ✅
async def connect(self):
    await asyncio.sleep(1)

# Lazy QuerySet in @database_sync_to_async:
# ❌
@database_sync_to_async
def load_history(self, group_pk):
    return ChatMessage.objects.filter(group_id=group_pk).values(...)
# ✅
@database_sync_to_async
def load_history(self, group_pk):
    qs = ChatMessage.objects.filter(group_id=group_pk).order_by('-timestamp')[:50]
    messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
    messages.reverse()
    return messages
```

---

## Practical exercises

**Exercise 1: observation**
```bash
docker compose up -d
# DevTools → Network → WS
# Open the chat → find the ws://... connection
# Send a message → inspect the WS frames
```

**Exercise 2: broadcast**
```
Open two browsers as demo_alice and demo_bob (password: demo1234)
Send a message from one → did it appear in the other without a reload?
```

**Exercise 3: understanding the code**
```
Find the load_history() method in consumers.py.
Why does it return list(qs.values(...)) and not just qs?
What happens if you remove list()?
```

**Exercise 4: authorization**
```
Try to connect to a group you are not a member of.
What does DevTools → Network → WS show, and which event.code does onclose get?
(the handshake is rejected before accept() → 1006; the consumer uses close() without a custom code)
```

**Exercise 5: logging**
```python
# Add this to connect() before accept():
import logging
logger = logging.getLogger(__name__)

async def connect(self):
    ...
    logger.info(f"User {self.user.username} connected to group {self.group_pk}")
    await self.accept()

# Restart and inspect:
docker compose logs -f web
```

---

## Navigation

- Previous: [Step 6: Testing](../06_testing/index.md)
- Next: [Step 8: Celery and background tasks](../08_background_tasks/index.md)

### Documentation modules

- [Async and Realtime](../../09_async_and_realtime/README.md)
