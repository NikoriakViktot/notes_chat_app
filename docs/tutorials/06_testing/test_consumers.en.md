# test_consumers.py — WebSocket tests

!!! info "Specific to notes_chat_app"
    This section describes testing `GroupChatConsumer` — a WebSocket consumer that exists only in **notes_chat_app**.
    `crispy_notes_project` (standalone) does not have this section.

---

## `TransactionTestCase`: why not `TestCase`?

```python
from django.test import TransactionTestCase  # not TestCase!
```

**The reason:**

```
TestCase:
  Wraps each test in a transaction with a ROLLBACK after the test.
  The async consumer reads the database from a separate worker thread via database_sync_to_async.
  That thread does NOT SEE the uncommitted TestCase transaction
  → setUp objects "disappear" for the consumer
  → The test fails with DoesNotExist or empty querysets.

TransactionTestCase:
  Does NOT wrap tests in a transaction.
  The data is VISIBLE to all threads (the database_sync_to_async worker thread sees it too).
  The cost: after each test, all tables are TRUNCATEd (slower).
  For consumer tests this is the right choice.
```

!!! warning "`asyncSetUp()` and Django"
    `asyncSetUp()` is a method of `unittest.IsolatedAsyncioTestCase`. Django's `TestCase` and `TransactionTestCase` never call it, in any version (they only run `async def test_*` methods through `async_to_sync`).
    Use a synchronous `setUp()` — it runs in a regular thread, which is correct for `TransactionTestCase`.

---

## `WebsocketCommunicator` from `channels.testing`

`WebsocketCommunicator` simulates a WebSocket connection without a real browser:

```
WebsocketCommunicator
    ↓
ASGI application (asgi.py)
    ↓
ProtocolTypeRouter → WebSocket scope
    ↓
AuthMiddlewareStack (but in tests we set scope['user'] manually)
    ↓
URLRouter → /ws/groups/<pk>/chat/
    ↓
GroupChatConsumer.connect()
              .receive()
              .disconnect()
```

The key feature: `communicator.scope['user'] = self.alice` — we bypass `AuthMiddlewareStack` and set the user directly. This is reliable and avoids having to emulate a cookie or session in the test.

---

## `database_sync_to_async` in tests

In consumer tests you need `database_sync_to_async` from `channels.db` for any database access from async code:

```python
from channels.db import database_sync_to_async

# Writing to the database:
await database_sync_to_async(ChatMessage.objects.create)(
    group=self.group, author=self.alice, content='Hello world'
)

# Reading from the database:
count = await database_sync_to_async(ChatMessage.objects.count)()
self.assertEqual(count, 1)

# Checking a queryset via exists():
exists = await database_sync_to_async(
    lambda: ChatMessage.objects.filter(content='Hello').exists()
)()
```

---

## Full test_consumers.py code

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TransactionTestCase  # not TestCase!

from notes_app.models import ChatMessage
from notes_project.asgi import application   # ← ASGI app for WebSocket tests


class GroupChatConsumerTest(TransactionTestCase):
    """
    Testing GroupChatConsumer via WebsocketCommunicator.

    Why TransactionTestCase:
      TestCase wraps each test in a transaction.
      The async consumer reads the database from a separate worker thread via database_sync_to_async.
      That thread doesn't see the uncommitted TestCase transaction → setUp objects "disappear".
      TransactionTestCase doesn't wrap in a transaction → the data is visible to all threads.
    """

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob is not a group member (for the non-member test)

    async def test_authenticated_member_can_connect(self):
        """A logged-in group member can connect to the chat."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice   # AuthMiddlewareStack bypass

        connected, subprotocol = await communicator.connect()
        self.assertTrue(connected)

        await communicator.disconnect()

    async def test_non_member_cannot_connect(self):
        """Bob is not a group member → the consumer closes the WS (code 4404)."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.bob   # not a member

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_anonymous_cannot_connect(self):
        """AnonymousUser → the consumer closes (code 4403)."""
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
        """After connect, the consumer sends the message history."""
        # Arrange: add a message to the database
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

        # Act: receive the first message
        response = await communicator.receive_json_from()

        # Assert: it is history
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Hello world')
        self.assertEqual(response['author'], 'alice')

        await communicator.disconnect()

    async def test_send_message_saves_to_db_and_broadcasts(self):
        """The message is saved to the database and sent back."""
        self.group.user_set.add(self.bob)   # bob is in the group too

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

        # Alice sends a message
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob receives the broadcast
        bob_msg = await comm_bob.receive_json_from()
        self.assertEqual(bob_msg['type'], 'message')
        self.assertEqual(bob_msg['content'], 'Hello Bob!')
        self.assertEqual(bob_msg['author'], 'alice')

        # Check that it was saved to the database
        count = await database_sync_to_async(ChatMessage.objects.count)()
        self.assertEqual(count, 1)

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

---

## Running the consumer tests

```bash
# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_consumers -v 2

# A specific test:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_consumers.GroupChatConsumerTest.test_non_member_cannot_connect -v 2
```

!!! note "Redis in tests"
    Consumer tests use `InMemoryChannelLayer` (if `REDIS_URL` is not set) or `RedisChannelLayer` (with Redis).
    In the Docker environment Redis is available, so the broadcast tests (channel groups) will work correctly.

---

## Checklist for consumer tests

- [ ] `TransactionTestCase` is used, not `TestCase`
- [ ] `setUp()` is synchronous (not `asyncSetUp`)
- [ ] `communicator.scope['user']` is set before `connect()`
- [ ] `await communicator.disconnect()` in every test (even if `connected=False`)
- [ ] Database access from async code goes through `database_sync_to_async`
- [ ] `application` is imported from `notes_project.asgi`, not from views

---

## Next

- **[test_selenium.md](test_selenium.md)** — browser tests, Docker, the session cookie trick
