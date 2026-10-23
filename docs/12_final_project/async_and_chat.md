# Async і Chat

WebSocket-чат є основним async-компонентом проєкту.

---

## Файли

| Файл | Роль |
|------|------|
| `notes_project/asgi.py` | `ProtocolTypeRouter` — розподіл HTTP vs WebSocket |
| `notes_project/routing.py` | WebSocket URL patterns |
| `notes_app/consumers.py` | `GroupChatConsumer(AsyncWebsocketConsumer)` |
| `notes_app/static/notes_app/js/group_chat.js` | JS-клієнт (WebSocket API) |
| `notes_app/templates/notes_app/group_chat.html` | Шаблон сторінки чату |

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

`AuthMiddlewareStack` читає session cookie з WS handshake і наповнює `scope["user"]`.

---

## GroupChatConsumer — lifecycle

### connect()

1. Перевіряє `scope["user"].is_authenticated` → `close()` якщо ні.
2. Читає `group_pk` з `scope["url_route"]["kwargs"]`.
3. Перевіряє існування групи і членство через `database_sync_to_async` (`check_membership`) — `close()` якщо не member.
4. Додає канал до room group: `channel_layer.group_add(room_group_name, self.channel_name)`.
5. `accept()` — рукостискання WebSocket.
6. Завантажує останні 50 повідомлень (`load_history`) і відправляє клієнту кадрами з `"type": "history"`.

### receive()

1. Парсить JSON: `{"content": "..."}`.
2. Перевіряє `content` — якщо порожній або довший за 2000 символів, ігнорує.
3. Зберігає `ChatMessage` через `database_sync_to_async`.
4. Публікує подію у channel group: `channel_layer.group_send(room_group_name, {...})`.
5. Кожен consumer у групі отримує подію через `chat_message()` і відправляє JSON клієнту.

### disconnect()

1. Видаляє канал з room group: `channel_layer.group_discard(...)`.

---

## database_sync_to_async

Django ORM є синхронним. У async consumer всі ORM-операції мають виконуватись у worker thread через `database_sync_to_async`:

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

`list(queryset.values(...))` — обов'язкове. Lazy QuerySet, що повертається в async context, викличе `SynchronousOnlyOperation`.

---

## Channel Layer

### Без REDIS_URL (локально без Docker)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

Придатно лише для одного процесу. Повідомлення не передаються між різними uvicorn workers.

### З REDIS_URL (Docker / production)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": _REDIS_URL,
                "socket_timeout": None,  # критично — без цього TimeoutError при idle
                "socket_connect_timeout": 5,
                "health_check_interval": 30,
            }],
        },
    }
}
```

`socket_timeout=None` — без нього `RedisChannelLayer` закриває з'єднання після idle timeout → `TimeoutError` при наступному повідомленні.

---

## Тестування consumer (TransactionTestCase)

```python
from django.test import TransactionTestCase

class GroupChatConsumerTest(TransactionTestCase):
    def setUp(self):   # SYNC setUp, не asyncSetUp
        ...
```

`TransactionTestCase` (не `TestCase`) використовується тому, що `TestCase` загортає кожен тест у транзакцію, яку `database_sync_to_async` worker thread не бачить. `TransactionTestCase` не загортає → дані видимі з усіх потоків.

---

## XSS захист

JavaScript-клієнт екранує HTML перед вставкою у DOM:

```js
function escapeHtml(text) {
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}
```

Вміст повідомлень вставляється через `escapeHtml()`, а не через `innerHTML` напряму.
