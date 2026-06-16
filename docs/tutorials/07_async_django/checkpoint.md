# Checkpoint: Крок 7

---

## Чеклист 7A — Async Views (hello_app)

- [ ] `requirements.txt` містить `uvicorn`, `httpx`, `wsproto`
- [ ] `asgi.py` — `ProtocolTypeRouter` налаштовано
- [ ] `async_selectors.py` — lazy QuerySets (звичайні `def`) + `async def` тільки де `aget()`
- [ ] `async_services.py` — `sync_to_async(create_note)`, `adelete()`, `aupdate(F(...))`
- [ ] `async_views.py` — 5 async def views: `async_note_list`, `async_note_detail`, `async_note_create`, `async_note_delete`, `async_note_toggle_pin`
- [ ] `urls.py` — `/async/notes/` URL prefix підключено
- [ ] `tests/test_async_views.py` — async тести через `AsyncClient`
- [ ] Обидва сервери запускаються: `runserver` (:8000) і `uvicorn` (:8001)
- [ ] Нотатка, створена через sync view, видна через async view (один SQLite)

---

## Чеклист 7B — WebSocket чат (notes_chat_app)

- [ ] `daphne` — перший у `INSTALLED_APPS` у `settings.py`
- [ ] `channels` — у `INSTALLED_APPS`
- [ ] `ASGI_APPLICATION = 'notes_project.asgi.application'` у `settings.py`
- [ ] `CHANNEL_LAYERS` налаштовано (InMemory або Redis залежно від `REDIS_URL`)
- [ ] `"socket_timeout": None` у `RedisChannelLayer CONFIG` (якщо Redis)
- [ ] `asgi.py`: `get_asgi_application()` ПЕРЕД будь-яким імпортом з `notes_app`
- [ ] `notes_project/routing.py` створено і підключено до `asgi.py`
- [ ] `notes_app/consumers.py` — `GroupChatConsumer` успадковує `AsyncWebsocketConsumer`
- [ ] Всі ORM-виклики у Consumer — `@database_sync_to_async`
- [ ] `load_history` повертає `list(qs.values(...))`, не QuerySet
- [ ] `disconnect()` викликає `group_discard()` (з `hasattr` перевіркою)
- [ ] JS клієнт: `escapeHtml()` застосовується до `data.author` і `data.content`
- [ ] nginx (якщо є): `proxy_http_version 1.1` + `Upgrade` + `Connection` headers
- [ ] Consumer тести проходять: `docker compose run --rm web python manage.py test notes_app.tests.test_consumers`

---

## Consumer тест: TransactionTestCase + WebsocketCommunicator

### Чому TransactionTestCase, а не TestCase

```
TestCase: огортає кожен тест у транзакцію (rollback після тесту)
  → WebsocketCommunicator відкриває окремий потік для consumer
  → Consumer з іншого потоку не бачить незакомічені дані setUp()
  → setUp-об'єкти (User, Group) «зникають» для consumer

TransactionTestCase: не загортає у транзакцію
  → Дані записуються у БД і видимі всім потокам
  → Consumer бачить User і Group з setUp()
  → Правильний вибір для тестів через WebsocketCommunicator
```

### Базова структура

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
    """Хелпер: створює session cookie для user."""
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
        # setUp() — синхронний, навіть якщо тести async.
        # ORM-виклики виконуємо напряму: setUp() ніколи не запускається
        # в async-контексті, тому database_sync_to_async не потрібний.
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

!!! note "asyncSetUp() у Django 5.1+"
    Django 5.1 додав `asyncSetUp()` і `asyncTearDown()` до `TransactionTestCase`.
    У Django 5.2+ можна писати:
    ```python
    async def asyncSetUp(self):
        self.user = await User.objects.acreate_user('testuser', password='pass')
        self.group = await DjangoGroup.objects.acreate(name='Chat')
        await self.group.user_set.aadd(self.user)
    ```
    Обидва підходи коректні. **`notes_chat_app`** використовує синхронний `setUp()`
    — він простіший і не вимагає `database_sync_to_async` в методі ініціалізації.

### Тест 1: member може підключитись

```python
    async def test_member_can_connect(self):
        comm = self._communicator(user=self.user)
        connected, _ = await comm.connect()
        self.assertTrue(connected)
        await comm.disconnect()
```

### Тест 2: history надсилається після connect

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

### Тест 3: non-member отримує відмову

```python
    async def test_non_member_is_rejected(self):
        # other_user НЕ є членом групи
        comm = self._communicator(user=self.other_user)
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Тест 4: anonymous отримує відмову

```python
    async def test_anonymous_user_is_rejected(self):
        # Без cookie — anonymous
        comm = WebsocketCommunicator(
            application,
            f"/ws/groups/{self.group.pk}/chat/",
        )
        connected, _ = await comm.connect()
        self.assertFalse(connected)
        await comm.disconnect()
```

### Тест 5: broadcast між двома юзерами

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

### Тест 6: повідомлення зберігається у БД

```python
    async def test_message_saved_to_database(self):
        from notes_app.models import ChatMessage

        comm = self._communicator(user=self.user)
        await comm.connect()

        await comm.send_json_to({'content': 'Тестове повідомлення'})
        await comm.receive_json_from()  # чекаємо broadcast відповіді

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

### Запуск Consumer тестів

```bash
# Consumer тести
docker compose run --rm web python manage.py test \
    notes_app.tests.test_consumers -v 2

# Всі тести (крім Selenium)
docker compose run --rm web python manage.py test \
    notes_app.tests.test_models \
    notes_app.tests.test_services \
    notes_app.tests.test_forms \
    notes_app.tests.test_views \
    notes_app.tests.test_consumers -v 2
```

---

## Типові помилки і виправлення

### Повна таблиця

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `SynchronousOnlyOperation` | sync ORM у async context | `@database_sync_to_async` |
| `AppRegistryNotReady` | імпорт до `get_asgi_application()` | Перенести імпорти після |
| `TimeoutError reading from redis` | `socket_timeout=5` vs brpop | `"socket_timeout": None` |
| WS 400 через nginx | Відсутні Upgrade заголовки | `proxy_http_version 1.1` + Upgrade headers |
| WS з'єднання закривається після простою | `socket_timeout=5` у Redis | `"socket_timeout": None, "health_check_interval": 30` |
| History не приходить | QuerySet lazy | `list(qs.values(...))` у `@database_sync_to_async` |
| `daphne` не override runserver | `daphne` не перший у `INSTALLED_APPS` | Перемістити `daphne` першим |
| Consumer не знаходиться | Відсутній `routing.py` у `asgi.py` | Підключити `websocket_urlpatterns` |

### Приклади виправлень

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
# ❌ asgi.py — імпорт ДО get_asgi_application():
from notes_project.routing import websocket_urlpatterns
django_asgi_app = get_asgi_application()
# ✅
django_asgi_app = get_asgi_application()
from notes_project.routing import websocket_urlpatterns

# time.sleep() блокує event loop:
# ❌
async def connect(self):
    time.sleep(1)
# ✅
async def connect(self):
    await asyncio.sleep(1)

# Lazy QuerySet у @database_sync_to_async:
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

## Практичні завдання

**Завдання 1 — спостереження:**
```bash
docker compose up -d
# DevTools → Network → WS
# Відкрий чат → знайди ws://... з'єднання
# Надішли повідомлення → переглянь WS frames
```

**Завдання 2 — broadcast:**
```
Відкрий два браузери під demo_alice і demo_bob (пароль: demo1234)
Відправ повідомлення з одного → воно з'явилось в іншому без перезавантаження?
```

**Завдання 3 — розуміння коду:**
```
Знайди у consumers.py метод load_history().
Чому повертається list(qs.values(...)) а не просто qs?
Що станеться якщо прибрати list()?
```

**Завдання 4 — авторизація:**
```
Спробуй підключитись до групи, членом якої не є.
Який close code у DevTools → Network → WS? (має бути 4003)
```

**Завдання 5 — логування:**
```python
# Додай у connect() перед accept():
import logging
logger = logging.getLogger(__name__)

async def connect(self):
    ...
    logger.info(f"User {self.user.username} connected to group {self.group_pk}")
    await self.accept()

# Перезапусти і переглянь:
docker compose logs -f web
```

---

## Навігація

- Попередній: [Крок 6 — Testing](../06_testing/index.md)
- Наступний: [Крок 8 — Celery та фонові задачі](../08_celery/index.md)

### Модулі документації

- [Async and Realtime](../../09_async_and_realtime/README.md)
