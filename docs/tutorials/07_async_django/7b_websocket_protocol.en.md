# 7B. The WebSocket protocol and asyncio

---

## Why HTTP is not suitable for chat

HTTP is a "request → response → connection closed" protocol. The server **cannot** send a message to the browser without a request from the browser.

```
HTTP (classic):
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  Browser ── GET /chat/ ──► Django view → HttpResponse → [connection closed]
  (a new connection every time — the server is silent between requests)
```

**The problem for chat:** the server cannot send a message to the browser FIRST.
If Olya writes "Hi", Viktor's browser only learns about it on its next
request. When should that next request happen? We don't know.

### Two "hacky" workarounds over HTTP

| Approach | How it works | Problem |
|--------|-----------|----------|
| **Polling** | The browser requests `/new-messages/` every 2 seconds | 1000 users = 500 requests/sec. A message arrives with a delay of up to 2 sec |
| **Long polling** | The browser sends a request, and the server "holds" it open until a new message appears | 1000 users = 1000 blocked threads on the server |
| **Server-Sent Events** | A one-way stream from the server to the browser | Not bidirectional (the browser cannot send) |

### Long polling + sync Django = a concurrency disaster

```
Sync Django thread pool:
  Typically: 4–16 worker threads (gunicorn/wsgi)
  
  1000 users in the chat → 1000 threads blocked waiting for a message
  Thread pool exhausted → the rest of the site (forms, notes, login) stops responding
  Each blocked thread: ~8 MB RAM for its stack → 1000 users = ~8 GB RAM just for threads
```

---

## WebSocket — a persistent bidirectional connection

A WebSocket is established through an HTTP Upgrade handshake **once**, after which the open TCP connection lives until the tab is closed.

### Handshake

```
1. Browser: GET /ws/groups/7/chat/ HTTP/1.1
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==

2. Server:  HTTP/1.1 101 Switching Protocols
            Upgrade: websocket
            Connection: Upgrade
            Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

3. After this — not HTTP, but WebSocket frames (a binary protocol on top of TCP)
```

### Flow after the connection is established

```
WebSocket (after the handshake):
  Browser ════════════ PERSISTENT TCP ════════════ Server
  ↑ Either side can send data at any moment

  Viktor: ws.send({content: "Hi!"}) ──────────────► consumer.receive()
                                                          │
                                                     group_send()
                                                          │
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Olya
          ws.onmessage ◄── consumer.send() ◄─────────────┤ Masha
          ws.onmessage ◄── consumer.send() ◄─────────────┘ Viktor
```

### The browser WebSocket API

```javascript
// Built into the browser — no libraries needed
const ws = new WebSocket('ws://localhost/ws/groups/7/chat/')
//                        ↑ ws:// for HTTP, wss:// for HTTPS

ws.onopen = () => {
    console.log('Connected to the chat')
}

ws.onmessage = (event) => {
    const data = JSON.parse(event.data)
    console.log('New message:', data)
}

ws.onclose = (event) => {
    // event.code:
    //   1000 — normal closure
    //   1001 — the page is closing
    //   1006 — abnormal (the internet connection dropped)
    //   4003 — custom code (an example; our consumer does not send it)
    console.log(`Connection closed: ${event.code}`)
}

ws.onerror = (error) => {
    console.error('WS error:', error)
}

ws.send(JSON.stringify({ content: 'Hi!' }))
ws.close()
```

---

## asyncio — the event loop and coroutines

To understand Django Channels, you need to understand asyncio, Python's standard library for asynchronous programming.

### The event loop — the heart of async Python

```python
import asyncio

# Event loop — a "scheduler" of coroutines
# NOT parallel execution (not threading)
# Cooperative multitasking: tasks voluntarily yield via await

asyncio.run(main())
```

```
Event loop — one thread, many coroutines:

  ┌──────────────────────────────────────────────────────────┐
  │  Task 1: fetch(url_a) ──── await ──→ PAUSE               │
  │  Task 2: fetch(url_b) ──── await ──→ PAUSE               │
  │  Task 3: fetch(url_c) ──── await ──→ PAUSE               │
  │                                                           │
  │  I/O ready for Task 1 → RESUME Task 1                    │
  │  I/O ready for Task 3 → RESUME Task 3                    │
  │  I/O ready for Task 2 → RESUME Task 2                    │
  └──────────────────────────────────────────────────────────┘

  ≠ Threading (parallel execution in several OS threads)
  = Cooperative multitasking (one thread, switching via await)
```

### Coroutine vs a regular function

```python
# A regular function — runs to completion without pausing
def sync_fetch(url):
    response = requests.get(url)   # blocks the thread for the whole request
    return response.text

# A coroutine — can pause and yield to the event loop
async def async_fetch(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()  # this is where it yields to the event loop
```

### await — where the switching happens

```python
async def handler():
    # await = "start an async operation and yield to the event loop"
    result = await some_async_operation()
    
    # CPU code — the event loop does NOT switch here
    processed = process(result)
    
    return processed
```

### asyncio.gather — concurrent operations

```python
async def fetch_all():
    # Runs three tasks "simultaneously" (concurrent, not parallel)
    results = await asyncio.gather(
        fetch(url_1),
        fetch(url_2),
        fetch(url_3),
    )
    # If each fetch takes 1 sec → ~1 sec in total (not 3)
    return results
```

---

## Why WebSocket and sync Django don't mix

A sync view in Django: handles the request → returns the response → **the thread is free**.
A WebSocket connection: opens → **stays open for hours**.

```
Sync Django + WebSocket:
  1000 users in the chat → 1000 threads blocked until the tabs are closed
  Thread pool exhausted → the rest of the site stops responding

  Solve it with more threads? 1000 OS threads ≈ 8 GB RAM just for stacks
  That doesn't scale.
```

**Async + WebSocket — the right architecture:**

```
Async Django Channels:
  1000 users in the chat → 1000 Consumer objects in memory
  Each Consumer is a coroutine that "sleeps" while there are no messages
  The event loop serves the active connections (where there are messages)
  The CPU is busy only when there is something to process

  1000 open connections ≈ RAM for 1000 Python objects (a few MB)
```

### Comparing the models

| | Sync (WSGI/Gunicorn) | Async (ASGI/Uvicorn) |
|--|----------------------|----------------------|
| **Model** | Thread per request | Event loop + coroutines |
| **1000 connections** | 1000 OS threads (~8 GB RAM) | 1000 coroutines (~a few MB) |
| **CPU while there are no messages** | The thread is blocked and "sleeps" | The event loop serves others |
| **Code complexity** | Simpler (sync Python) | More complex (async/await everywhere) |
| **Risks** | Thread exhaustion | Blocking calls in an async context |
| Server sends data without a request from the browser | ❌ Impossible | ✅ `consumer.send()` |
| Connection open for hours | ❌ Blocks a thread | ✅ The coroutine "sleeps" |
| Broadcasting one message to everyone | ❌ No mechanism | ✅ `channel_layer.group_send()` |

---

## Where async is the only right choice

```
Sync Django: CRUD for notes, forms, authentication
  → sync is perfectly suitable
  → switching to async: complicates the code, gives nothing

Async Django Channels: 1000 simultaneous WS connections in the chat
  → sync is impossible (thread exhaustion)
  → async is the only right approach
```

**Rule:** async is justified for **long-lived connections** and **high-concurrency I/O**. For ordinary CRUD it is unnecessary complexity.

### What is async and what is sync in notes_chat_app

| Feature | Implementation | Why |
|------------|-----------|------|
| Notes, Notebooks, Tags | Sync views | Simple CRUD, short requests |
| TodoList, ShoppingList | Sync views | Simple mutations |
| Authentication (login/register) | Sync views | Standard Django auth |
| Group chat | `AsyncWebsocketConsumer` | WS = thousands of long-lived connections |

---

## Summary: why chat is the ideal demonstration of async

The async views in part 7A (the async_views.py sections) show **how** to write async code.
Technically, the same result can be achieved with sync code.

The group chat shows **why** async exists — here sync is **architecturally impossible**:

- a WebSocket connection lives for minutes or hours, not milliseconds like an HTTP request;
- in the WSGI model every such connection would hold a separate thread: 1000 chat members → 1000 threads that wait almost all the time;
- the server must push messages to clients by itself, while WSGI only supports the "request → response" scheme;
- an async consumer "sleeps" in the event loop and holds no thread while there are no messages, so one process serves thousands of connections.

This is not "async is better" — it is "for long-lived connections sync is **architecturally unsuitable**".
That is why the group chat is the best demonstration: not a stylistic advantage, but a **necessity**.

---

## Next

Next chapter: **[7B. The ASGI stack](7b_asgi_stack.md)** — WSGI vs ASGI, `ProtocolTypeRouter`, `asgi.py`, `routing.py`, `AuthMiddlewareStack`.
