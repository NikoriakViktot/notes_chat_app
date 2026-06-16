# Async Lab — WebSocket і Django Channels

**Мета:** дослідити lifecycle `GroupChatConsumer`, зрозуміти навіщо `database_sync_to_async`, навчитися тестувати WebSocket через `WebsocketCommunicator`.

**Пов'язані файли:** `notes_app/consumers.py`, `notes_app/tests/test_consumers.py`, `notes_project/asgi.py`.

---

## Частина 1 — Lifecycle consumer

Відкрийте `notes_app/consumers.py` і знайдіть `class GroupChatConsumer(AsyncWebsocketConsumer)`.

Для кожного з трьох методів опишіть у коментарі що відбувається:

| Метод | Що робить | Коли викликається |
|-------|-----------|------------------|
| `connect()` | | При WS handshake (до accept) |
| `receive()` | | Коли браузер надіслав текст |
| `disconnect()` | | При закритті з'єднання |

**Завдання:** знайдіть рядок, де consumer закриває з'єднання для анонімного user. Який close code він використовує? Що означає цей код?

---

## Частина 2 — `database_sync_to_async`

**Проблема:** Django ORM є синхронним. У async context виклик `ChatMessage.objects.create(...)` напряму підніме:

```
SynchronousOnlyOperation: You cannot call this from an async context
```

**Рішення:** `database_sync_to_async` запускає ORM у Django thread pool:

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

**Питання:**

1. Чому `list(queryset.values(...))` є обов'язковим при поверненні даних з `database_sync_to_async`?
2. Що відбудеться якщо повернути lazy QuerySet в async context і звернутися до нього пізніше?
3. Знайдіть у `consumers.py` де завантажуються 50 останніх повідомлень — яка SQL операція виконується?

---

## Частина 3 — `WebsocketCommunicator`

`WebsocketCommunicator` тестує consumer без реального браузера і сервера.

Вивчіть helper з `test_consumers.py`:

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

**Питання:**

1. Навіщо вручну встановлювати `scope['user']`? Чому `AuthMiddlewareStack` не спрацьовує у тесті?
2. Чому consumer-тести успадковують `TransactionTestCase`, а не `TestCase`?

---

## Частина 4 — Напишіть власний тест

**Завдання:** напишіть тест, що перевіряє — після disconnect consumer правильно видаляється з channel group (інший учасник не отримує повідомлення від відключеного):

```python
# notes_app/tests/test_consumers.py — додайте метод до існуючого класу
async def test_disconnected_user_does_not_receive_messages(self):
    from channels.testing import WebsocketCommunicator
    from notes_project.asgi import application

    comm_alice = _make_communicator(self.group.pk, self.user1)
    comm_bob   = _make_communicator(self.group.pk, self.user2)

    await comm_alice.connect()
    await comm_bob.connect()

    # Bob відключається
    await comm_bob.disconnect()

    # Alice надсилає повідомлення
    await comm_alice.send_json_to({'content': 'Тільки для Alice'})
    msg = await comm_alice.receive_json_from()
    self.assertEqual(msg['content'], 'Тільки для Alice')

    # Bob НЕ повинен отримати нічого (немає в групі)
    # receive_nothing() повертає True якщо немає повідомлень
    self.assertTrue(await comm_bob.receive_nothing())

    await comm_alice.disconnect()
```

Запустіть (через exec, не run):

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_consumers -v 2
```

---

## Частина 5 — Channel Layer

**Завдання:** визначте, який channel layer активний у Docker і який локально без Docker.

```bash
# У Django shell (Docker)
docker compose run --rm web python manage.py shell
```

```python
from django.conf import settings
print(settings.CHANNEL_LAYERS)
```

**Поясніть:** чому `InMemoryChannelLayer` не підходить для multi-worker production, але достатній для одного процесу Uvicorn у розробці.

---

## Частина 6 — XSS у WebSocket клієнті

Відкрийте `notes_app/static/notes_app/js/group_chat.js`.

Знайдіть функцію `escapeHtml`. Поясніть:

1. Чому вміст повідомлення не можна вставляти через `innerHTML` напряму.
2. Як `escapeHtml` запобігає виконанню JavaScript коду, надісланого через чат.
3. Чи захищений server side — де зберігається `content`?

---

## Підсумок

| Концепція | Де у коді |
|-----------|-----------|
| `ProtocolTypeRouter` | `notes_project/asgi.py` |
| `AuthMiddlewareStack` | `notes_project/asgi.py` |
| `URLRouter` + WS routes | `notes_project/routing.py` |
| `GroupChatConsumer` | `notes_app/consumers.py` |
| `database_sync_to_async` | `consumers.py` — ORM wrapper |
| `channel_layer.group_send` | `consumers.py` — fan-out до всіх |
| `WebsocketCommunicator` | `notes_app/tests/test_consumers.py` |
| `TransactionTestCase` | `test_consumers.py` — не TestCase! |
| `socket_timeout=None` | `notes_project/settings.py` — Redis config |
| XSS escape | `group_chat.js` — `escapeHtml()` |

---

## Оціни та обери (рівень аналізу і оцінювання)

### В.1. WebSocket vs HTTP Polling — де межа?

Notes Chat App використовує WebSocket для групового чату.

**Оціни:**
- Яку функцію у Notes Chat App можна реалізувати через polling, і це було б прийнятно? (Нагадування? Список нотаток? Оновлення Todo?)
- При 1000 активних користувачів: скільки HTTP запитів/сек генерує polling з інтервалом 2 сек? Скільки — WebSocket?
- Назви два сценарії де polling **кращий за WebSocket**. Аргументуй.
- Знайди у `group_chat.js` де встановлюється WS-з'єднання. Що відбувається при disconnect? Чи є reconnect логіка?

---

### В.2. `InMemoryChannelLayer` vs `RedisChannelLayer` — що обрати і коли?

```python
# Варіант A: In-Memory (без Redis)
CHANNEL_LAYERS = {
    "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
}

# Варіант B: Redis
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL], "socket_timeout": None},
    }
}
```

**Оціни:**
- Уяви що production-сервер запускає 3 Daphne workers. Що трапиться з чатом при Варіанті A?
- При Варіанті B — якщо Redis недоступний, що трапиться з чатом?
- Знайди у `settings.py` який варіант активний при наявності `REDIS_URL` і без нього.
- Зроби висновок: «Варіант A доречний коли..., Варіант B обов'язковий коли...»

---

### В.3. `async def view` vs `def view` — де async виправданий?

Django 5.2 підтримує `async def` views.

```python
# Sync view
def note_list(request):
    notes = selectors.get_user_notes(user=request.user)
    return render(request, 'note_list.html', {'notes': notes})

# Async view
async def note_list(request):
    notes = await database_sync_to_async(selectors.get_user_notes)(user=request.user)
    return render(request, 'note_list.html', {'notes': notes})
```

**Оціни:**
- Чому Notes Chat App використовує sync views замість async для більшості view?
- В якому сценарії async view дає реальний benefit для цього проєкту?
- Що ускладнює debugging у async views порівняно з sync?
- Перегляньте `views.py` — чи є там хоча б один async view? Якщо ні, чому?
