# Async and Chat

The WebSocket chat is the main async component of the project.

---

## Files

| File | Role |
|------|------|
| `notes_project/asgi.py` | `ProtocolTypeRouter` — splits HTTP vs WebSocket |
| `notes_project/routing.py` | WebSocket URL patterns |
| `notes_app/consumers.py` | `GroupChatConsumer(AsyncWebsocketConsumer)` |
| `notes_app/static/notes_app/js/group_chat.js` | JS client (WebSocket API) |
| `notes_app/templates/notes_app/group_chat.html` | Chat page template |

---

## ASGI routing

```text
Browser WebSocket: ws://host/ws/groups/42/chat/
       │
       ▼
Nginx (proxy_http_version 1.1 + Upgrade/Connection headers)
       │
       ▼
Uvicorn (ASGI server)
       │
       ▼
ProtocolTypeRouter
  "websocket" → AuthMiddlewareStack
                  ↓
               URLRouter
                  ↓
               /ws/groups/<pk>/chat/ → GroupChatConsumer
```

`AuthMiddlewareStack` reads the session cookie from the WS handshake and populates `scope["user"]`.

---

## GroupChatConsumer — lifecycle

### connect()

1. Checks `scope["user"].is_authenticated` → `close()` if not.
2. Reads `group_pk` from `scope["url_route"]["kwargs"]`.
3. Checks that the group exists and the user is a member via `database_sync_to_async` (`check_membership`) — `close()` if not a member.
4. Adds the channel to the room group: `channel_layer.group_add(room_group_name, self.channel_name)`.
5. `accept()` — the WebSocket handshake.
6. Loads the last 50 messages (`load_history`) and sends them to the client as frames with `"type": "history"`.

### receive()

1. Parses JSON: `{"content": "..."}`.
2. Checks `content` — if it is empty or longer than 2000 characters, ignores it.
3. Saves the `ChatMessage` via `database_sync_to_async`.
4. Publishes an event to the channel group: `channel_layer.group_send(room_group_name, {...})`.
5. Every consumer in the group receives the event through `chat_message()` and sends JSON to its client.

### disconnect()

1. Removes the channel from the room group: `channel_layer.group_discard(...)`.

---

## database_sync_to_async

The Django ORM is synchronous. In an async consumer, all ORM operations must run in a worker thread via `database_sync_to_async`:

```python
from channels.db import database_sync_to_async

@database_sync_to_async
def load_history(self, group_pk):
    qs = (
        ChatMessage.objects
        .filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:50]
    )
    messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
    messages.reverse()
    return messages
```

`list(queryset.values(...))` is mandatory. A lazy QuerySet returned into the async context will raise `SynchronousOnlyOperation`.

---

## Channel Layer

### Without REDIS_URL (locally without Docker)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

Suitable for a single process only. Messages are not passed between different uvicorn workers.

### With REDIS_URL (Docker / production)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": _REDIS_URL,
                "socket_timeout": None,  # critical — without it, TimeoutError when idle
                "socket_connect_timeout": 5,
                "health_check_interval": 30,
            }],
        },
    }
}
```

`socket_timeout=None` — without it, `RedisChannelLayer` closes the connection after an idle timeout → `TimeoutError` on the next message.

---

## Testing the consumer (TransactionTestCase)

```python
from django.test import TransactionTestCase

class GroupChatConsumerTest(TransactionTestCase):
    def setUp(self):   # SYNC setUp, not asyncSetUp
        ...
```

`TransactionTestCase` (not `TestCase`) is used because `TestCase` wraps each test in a transaction that the `database_sync_to_async` worker thread cannot see. `TransactionTestCase` does not wrap → the data is visible from all threads.

---

## XSS protection

The JavaScript client escapes HTML before inserting it into the DOM:

```js
function escapeHtml(text) {
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}
```

Message content is inserted through `escapeHtml()`, not directly through `innerHTML`.
