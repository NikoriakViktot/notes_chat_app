# 7B. WebSocket протокол і asyncio

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

**Проблема для чату:** сервер не може ПЕРШИМ надіслати повідомлення браузеру.
Якщо Оля пише "Привіт" — браузер Віктора дізнається про це лише при наступному
запиті. Коли зробити наступний запит? Не знаємо.

### Два "костильних" вирішення через HTTP

| Підхід | Як працює | Проблема |
|--------|-----------|----------|
| **Polling** | Браузер запитує `/new-messages/` кожні 2 секунди | 1000 юзерів = 500 запитів/сек. Повідомлення приходить із затримкою до 2 сек |
| **Long polling** | Браузер надсилає запит, сервер "тримає" його відкритим до появи нового повідомлення | 1000 юзерів = 1000 заблокованих потоків на сервері |
| **Server-Sent Events** | Однобічний потік від сервера до браузера | Не двосторонній (браузер не може надсилати) |

### Long polling + sync Django = катастрофа concurrency

```
Sync Django thread pool:
  Типово: 4–16 worker threads (gunicorn/wsgi)
  
  1000 юзерів у чаті → 1000 потоків заблоковані в очікуванні повідомлення
  Thread pool вичерпаний → решта сайту (форми, нотатки, логін) не відповідає
  Кожен блокований thread: ~8 MB RAM на stack → 1000 юзерів = ~8 GB RAM тільки на threads
```

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
//                        ↑ ws:// для HTTP, wss:// для HTTPS

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
    //   1001 — сторінка закривається
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

## Чому WebSocket + sync Django не поєднуються

Sync view в Django: обробив запит → повернув відповідь → **потік вільний**.
WebSocket з'єднання: відкрилось → **тримається відкритим годинами**.

```
Sync Django + WebSocket:
  1000 юзерів у чаті → 1000 потоків заблоковані до закриття вкладок
  Thread pool вичерпаний → решта сайту не відповідає

  Рішення через більше потоків? 1000 OS-потоків ≈ 8 GB RAM тільки на stack
  Це не масштабується.
```

**Async + WebSocket — правильна архітектура:**

```
Async Django Channels:
  1000 юзерів у чаті → 1000 Consumer об'єктів в пам'яті
  Кожен Consumer — coroutine, "спить" поки немає повідомлень
  Event loop обслуговує активні з'єднання (де є повідомлення)
  CPU зайнятий тільки коли є що обробляти

  1000 відкритих з'єднань ≈ RAM для 1000 Python об'єктів (кілька MB)
```

### Порівняння моделей

| | Sync (WSGI/Gunicorn) | Async (ASGI/Uvicorn) |
|--|----------------------|----------------------|
| **Модель** | Thread per request | Event loop + coroutines |
| **1000 з'єднань** | 1000 OS threads (~8 GB RAM) | 1000 coroutines (~кілька MB) |
| **CPU поки немає повідомлень** | Thread заблокований і "спить" | Event loop обслуговує інших |
| **Складність коду** | Простіша (sync Python) | Складніша (async/await скрізь) |
| **Ризики** | Thread exhaustion | Блокуючі виклики у async context |
| Сервер надсилає дані без запиту від браузера | ❌ Неможливо | ✅ `consumer.send()` |
| З'єднання відкрите годинами | ❌ Блокує потік | ✅ Coroutine "спить" |
| Broadcast одного повідомлення всім | ❌ Немає механізму | ✅ `channel_layer.group_send()` |

---

## Де async — єдиний правильний вибір

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

## Підсумок: чому чат — ідеальна демонстрація async

Async views у частині 7A (розділи async_views.py) показують **як** писати async код.
Технічно той самий результат можна отримати sync.

Груповий чат показує **навіщо** async існує — тут sync **архітектурно неможливий**:

Це не "async краще" — це "для long-lived з'єднань sync **не підходить архітектурно**".
Тому груповий чат і є найкращою демонстрацією: не стилістична перевага, а **необхідність**.

---

## Далі

Наступна глава: **[7B. ASGI стек](7b_asgi_stack.md)** — WSGI vs ASGI, `ProtocolTypeRouter`, `asgi.py`, `routing.py`, `AuthMiddlewareStack`.
