# Async Lab — WebSocket and Django Channels

**Goal:** explore the lifecycle of `GroupChatConsumer`, understand why `database_sync_to_async` is needed, and learn to test WebSocket with `WebsocketCommunicator`.

**Related files:** `notes_app/consumers.py`, `notes_app/tests/test_consumers.py`, `notes_project/asgi.py`.

---

## Part 1 — Consumer lifecycle

Open `notes_app/consumers.py` and find `class GroupChatConsumer(AsyncWebsocketConsumer)`.

For each of the three methods, describe in a comment what happens:

| Method | What it does | When it is called |
|-------|-----------|------------------|
| `connect()` | | During the WS handshake (before accept) |
| `receive()` | | When the browser has sent text |
| `disconnect()` | | When the connection is closed |

**Task:** find the line where the consumer closes the connection for an anonymous user. Which close code does it use? What does that code mean?

---

## Part 2 — `database_sync_to_async`

**Problem:** the Django ORM is synchronous. In an async context, calling `ChatMessage.objects.create(...)` directly will raise:

```
SynchronousOnlyOperation: You cannot call this from an async context
```

**Solution:** `database_sync_to_async` runs the ORM in the Django thread pool:

```python
from channels.db import database_sync_to_async

@database_sync_to_async
def _save_message(self, content):
    return ChatMessage.objects.create(
        group=self.group,
        author=self.user,
        content=content,
    )
```

**Questions:**

1. Why is `list(queryset.values(...))` mandatory when returning data from `database_sync_to_async`?
2. What happens if you return a lazy QuerySet into the async context and access it later?
3. Find the place in `consumers.py` where the latest 50 messages are loaded. Which SQL operation runs?

---

## Part 3 — `WebsocketCommunicator`

`WebsocketCommunicator` tests a consumer without a real browser or server.

Study the helper from `test_consumers.py`:

```python
from channels.testing import WebsocketCommunicator
from notes_project.asgi import application

def _make_communicator(group_pk, user):
    communicator = WebsocketCommunicator(
        application,
        f"/ws/groups/{group_pk}/chat/"
    )
    communicator.scope['user'] = user
    communicator.scope['url_route'] = {'kwargs': {'group_pk': str(group_pk)}}
    return communicator
```

**Questions:**

1. Why set `scope['user']` manually? Why does `AuthMiddlewareStack` not kick in during the test?
2. Why do consumer tests inherit from `TransactionTestCase` rather than `TestCase`?

---

## Part 4 — Write your own test

**Task:** write a test that verifies that after a disconnect the consumer is correctly removed from the channel group (another participant does not receive messages for the disconnected one):

```python
# notes_app/tests/test_consumers.py — add the method to the existing class
async def test_disconnected_user_does_not_receive_messages(self):
    from channels.testing import WebsocketCommunicator
    from notes_project.asgi import application

    comm_alice = _make_communicator(self.group.pk, self.user1)
    comm_bob   = _make_communicator(self.group.pk, self.user2)

    await comm_alice.connect()
    await comm_bob.connect()

    # Bob disconnects
    await comm_bob.disconnect()

    # Alice sends a message
    await comm_alice.send_json_to({'content': 'Only for Alice'})
    msg = await comm_alice.receive_json_from()
    self.assertEqual(msg['content'], 'Only for Alice')

    # Bob must NOT receive anything (he is not in the group)
    # receive_nothing() returns True if there are no messages
    self.assertTrue(await comm_bob.receive_nothing())

    await comm_alice.disconnect()
```

Run it (with exec, not run):

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

---

## Part 5 — Channel Layer

**Task:** determine which channel layer is active in Docker and which one is active locally without Docker.

```bash
# In the Django shell (Docker)
docker compose run --rm web python manage.py shell
```

```python
from django.conf import settings
print(settings.CHANNEL_LAYERS)
```

**Explain:** why `InMemoryChannelLayer` is not suitable for multi-worker production but is sufficient for a single Uvicorn process in development.

---

## Part 6 — XSS in the WebSocket client

Open `notes_app/static/notes_app/js/group_chat.js`.

Find the `escapeHtml` function. Explain:

1. Why message content must not be inserted directly via `innerHTML`.
2. How `escapeHtml` prevents the execution of JavaScript code sent through the chat.
3. Is the server side protected? Where is `content` stored?

---

## Summary

| Concept | Where in the code |
|-----------|-----------|
| `ProtocolTypeRouter` | `notes_project/asgi.py` |
| `AuthMiddlewareStack` | `notes_project/asgi.py` |
| `URLRouter` + WS routes | `notes_project/routing.py` |
| `GroupChatConsumer` | `notes_app/consumers.py` |
| `database_sync_to_async` | `consumers.py` — ORM wrapper |
| `channel_layer.group_send` | `consumers.py` — fan-out to everyone |
| `WebsocketCommunicator` | `notes_app/tests/test_consumers.py` |
| `TransactionTestCase` | `test_consumers.py` — not TestCase! |
| `socket_timeout=None` | `notes_project/settings.py` — Redis config |
| XSS escape | `group_chat.js` — `escapeHtml()` |

---

## Evaluate and choose (analysis and evaluation level)

### Q.1. WebSocket vs HTTP Polling: where is the line?

Notes Chat App uses WebSocket for the group chat.

**Evaluate:**
- Which feature in Notes Chat App could be implemented with polling, and would that be acceptable? (Reminders? The note list? Todo updates?)
- With 1000 active users, how many HTTP requests/sec does polling at a 2-second interval generate? How many with WebSocket?
- Name two scenarios where polling is **better than WebSocket**. Justify your answer.
- Find where the WS connection is established in `group_chat.js`. What happens on disconnect? Is there reconnect logic?

---

### Q.2. `InMemoryChannelLayer` vs `RedisChannelLayer`: what to choose and when?

```python
# Option A: In-Memory (no Redis)
CHANNEL_LAYERS = {
    "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
}

# Option B: Redis
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL], "socket_timeout": None},
    }
}
```

**Evaluate:**
- Imagine the production server runs 3 Uvicorn workers. What happens to the chat with Option A?
- With Option B, if Redis is unavailable, what happens to the chat?
- Find in `settings.py` which option is active when `REDIS_URL` is present and when it is not.
- Draw a conclusion: "Option A is appropriate when..., Option B is mandatory when..."

---

### Q.3. `async def view` vs `def view`: where is async justified?

Django 5.2 supports `async def` views.

```python
# Sync view
def note_list(request):
    notes = selectors.get_user_notes(user=request.user)
    return render(request, 'note_list.html', {'notes': notes})

# Async view
async def note_list(request):
    # list() runs the SQL in the worker thread; a lazy QuerySet in render() → SynchronousOnlyOperation
    notes = await database_sync_to_async(
        lambda: list(selectors.get_user_notes(user=request.user))
    )()
    return render(request, 'note_list.html', {'notes': notes})
```

**Evaluate:**
- Why does Notes Chat App use sync views instead of async for most views?
- In which scenario does an async view give a real benefit for this project?
- What makes debugging async views harder compared to sync ones?
- Look through `views.py`: is there at least one async view? If not, why?
