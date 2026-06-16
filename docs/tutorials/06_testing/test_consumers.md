# test_consumers.py — WebSocket тести

!!! info "Специфічно для notes_chat_app"
    Цей розділ описує тестування `GroupChatConsumer` — WebSocket consumer, який існує тільки в **notes_chat_app**.
    У `crispy_notes_project` (standalone) цього розділу немає.

---

## `TransactionTestCase`: чому не `TestCase`?

```python
from django.test import TransactionTestCase  # не TestCase!
```

**Причина:**

```
TestCase:
  Загортає кожен тест у транзакцію з ROLLBACK після тесту.
  Async consumer читає БД з окремого worker-потоку через database_sync_to_async.
  Цей потік НЕ БАЧИТЬ незакомічену транзакцію TestCase
  → setUp-об'єкти «зникають» для consumer
  → Тест падає з DoesNotExist або порожніми queryset-ами.

TransactionTestCase:
  НЕ загортає в транзакцію.
  Дані ВИДИМІ всім потокам (worker thread database_sync_to_async теж бачить).
  Ціна: після кожного тесту — TRUNCATE всіх таблиць (повільніше).
  Для consumer тестів — це правильний вибір.
```

!!! warning "`asyncSetUp()` і Django"
    `asyncSetUp()` не підтримується в `TransactionTestCase` до Django 5.1.
    Використовуй синхронний `setUp()` — він виконується у звичайному потоці, що правильно для `TransactionTestCase`.

---

## `WebsocketCommunicator` від `channels.testing`

`WebsocketCommunicator` симулює WebSocket з'єднання без реального браузера:

```
WebsocketCommunicator
    ↓
ASGI application (asgi.py)
    ↓
ProtocolTypeRouter → WebSocket scope
    ↓
AuthMiddlewareStack (але scope['user'] встановлюємо вручну в тестах)
    ↓
URLRouter → /ws/groups/<pk>/chat/
    ↓
GroupChatConsumer.connect()
              .receive()
              .disconnect()
```

Ключова особливість: `communicator.scope['user'] = self.alice` — ми обходимо `AuthMiddlewareStack` і встановлюємо user напряму. Це надійно і без необхідності емулювати cookie або session у тесті.

---

## `database_sync_to_async` у тестах

У consumer тестах потрібен `database_sync_to_async` з `channels.db` для будь-якого звернення до БД з async коду:

```python
from channels.db import database_sync_to_async

# Запис у БД:
await database_sync_to_async(ChatMessage.objects.create)(
    group=self.group, author=self.alice, content='Hello world'
)

# Читання з БД:
count = await database_sync_to_async(ChatMessage.objects.count)()
self.assertEqual(count, 1)

# Перевірка queryset через exists():
exists = await database_sync_to_async(
    lambda: ChatMessage.objects.filter(content='Hello').exists()
)()
```

---

## Повний код test_consumers.py

```python
# notes_app/tests/test_consumers.py
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group, User
from django.test import TransactionTestCase  # не TestCase!

from notes_app.models import ChatMessage
from notes_project.asgi import application   # ← ASGI app для WebSocket тестів


class GroupChatConsumerTest(TransactionTestCase):
    """
    Тестування GroupChatConsumer через WebsocketCommunicator.

    Чому TransactionTestCase:
      TestCase загортає кожен тест у транзакцію.
      Async consumer читає БД з окремого worker-потоку через database_sync_to_async.
      Цей потік не бачить незакомічену транзакцію TestCase → setUp-об'єкти «зникають».
      TransactionTestCase не загортає в транзакцію → дані видимі всім потокам.
    """

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')
        self.group = Group.objects.create(name='TestGroup')
        self.group.user_set.add(self.alice)
        # bob не є членом групи (для тесту non-member)

    async def test_authenticated_member_can_connect(self):
        """Залогінений член групи може підключитись до чату."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.alice   # AuthMiddlewareStack bypass

        connected, subprotocol = await communicator.connect()
        self.assertTrue(connected)

        await communicator.disconnect()

    async def test_non_member_cannot_connect(self):
        """Bob не є членом групи → consumer закриває WS (code 4404)."""
        communicator = WebsocketCommunicator(
            application,
            f'/ws/groups/{self.group.pk}/chat/',
        )
        communicator.scope['user'] = self.bob   # не член

        connected, code = await communicator.connect()
        self.assertFalse(connected)

        await communicator.disconnect()

    async def test_anonymous_cannot_connect(self):
        """AnonymousUser → consumer закриває (code 4403)."""
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
        """Після connect — consumer надсилає history повідомлень."""
        # Arrange: додаємо повідомлення в БД
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

        # Act: отримуємо перше повідомлення
        response = await communicator.receive_json_from()

        # Assert: це history
        self.assertEqual(response['type'], 'history')
        self.assertEqual(response['content'], 'Hello world')
        self.assertEqual(response['author'], 'alice')

        await communicator.disconnect()

    async def test_send_message_saves_to_db_and_broadcasts(self):
        """Повідомлення зберігається в БД і надсилається назад."""
        self.group.user_set.add(self.bob)   # bob теж у групі

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

        # Alice надсилає повідомлення
        await comm_alice.send_json_to({'content': 'Hello Bob!'})

        # Bob отримує broadcast
        bob_msg = await comm_bob.receive_json_from()
        self.assertEqual(bob_msg['type'], 'message')
        self.assertEqual(bob_msg['content'], 'Hello Bob!')
        self.assertEqual(bob_msg['author'], 'alice')

        # Перевіряємо що збереглось у БД
        count = await database_sync_to_async(ChatMessage.objects.count)()
        self.assertEqual(count, 1)

        await comm_alice.disconnect()
        await comm_bob.disconnect()
```

---

## Запуск consumer тестів

```bash
# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_consumers -v 2

# Конкретний тест:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_consumers.GroupChatConsumerTest.test_non_member_cannot_connect -v 2
```

!!! note "Redis у тестах"
    Consumer тести використовують `InMemoryChannelLayer` (якщо `REDIS_URL` не встановлено) або `RedisChannelLayer` (з Redis).
    У Docker-середовищі Redis доступний, тому тести з broadcast (channel groups) працюватимуть коректно.

---

## Чеклист для consumer тестів

- [ ] Використовується `TransactionTestCase`, а не `TestCase`
- [ ] `setUp()` — синхронний (не `asyncSetUp`)
- [ ] `communicator.scope['user']` встановлений перед `connect()`
- [ ] `await communicator.disconnect()` у кожному тесті (навіть якщо `connected=False`)
- [ ] Звернення до БД з async — через `database_sync_to_async`
- [ ] Імпорт `application` з `notes_project.asgi`, не з views

---

## Далі

- **[test_selenium.md](test_selenium.md)** — браузерні тести, Docker, session cookie trick
