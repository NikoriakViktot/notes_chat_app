# Lesson 34 — Asyncio: Cooperative Multitasking and Event Loop Architecture

**Module:** 4 — Network & Concurrent Systems  
**Level:** intermediate  
**Language:** English

---

## Contents

1. [Why asyncio?](#1-why-asyncio)
2. [Key concepts](#2-key-concepts)
3. [Coroutine Lifecycle](#3-coroutine-lifecycle)
4. [Event Loop Architecture](#4-event-loop-architecture)
5. [Cooperative vs Preemptive Multitasking](#5-cooperative-vs-preemptive-multitasking)
6. [asyncio API Reference](#6-asyncio-api-reference)
7. [Blocking vs Non-Blocking](#7-blocking-vs-non-blocking)
8. [FastAPI & Backend Integration](#8-fastapi--backend-integration)
9. [Threading vs Multiprocessing vs Asyncio](#9-threading-vs-multiprocessing-vs-asyncio)
10. [Common mistakes and anti-patterns](#10-common-mistakes-and-anti-patterns)
11. [Production Patterns](#11-production-patterns)
12. [Debugging Guide](#12-debugging-guide)

---

## 1. Why asyncio?

### The problem with synchronous servers

In a traditional WSGI architecture, every connection requires a separate OS thread. A thread takes ~8 MB of RAM and is blocked for the entire time it waits for I/O. With 10,000 concurrent users, the server spends ~80 GB of RAM on threads alone — even if they spend 99% of their time just waiting.

### Time scale: why I/O is so slow

| Operation | Real time | "Human" equivalent |
|----------|--------------|-----------------------|
| CPU cache (L1) | 1 ns | 3 seconds |
| RAM | 100 ns | 5 minutes |
| SSD read | 100 µs | 3.5 days |
| TCP round trip | 100 ms | ~9.5 years |
| External API | 500 ms | **~48 years** |

Asyncio solves this with **cooperative multitasking**: instead of keeping a thread blocked for ~48 "human years", `await` frees the Event Loop to serve thousands of other connections.

---

## 2. Key concepts

### Coroutine

A special function defined with `async def` that:
- When **called**, returns a `coroutine object` (executes nothing)
- When awaited with `await`, runs until its first internal `await`
- On `await asyncio.sleep()`, suspends itself, saves its state and hands control to the Event Loop

```python
async def my_coroutine():      # Definition
    ...

obj = my_coroutine()           # Call → coroutine object (FROZEN)
result = await my_coroutine()  # Execute and wait for the result
```

### Task

`asyncio.Task` is a wrapper around a coroutine that schedules its execution on the Event Loop.

```python
task = asyncio.create_task(my_coroutine())  # Schedules NOW, does not wait
result = await task                          # Explicitly wait for completion
```

**Task states:**
```
create_task() → [PENDING] → [RUNNING] → [DONE / CANCELLED]
                                 ↑            ↓
                           on await     result or exception
```

### Event Loop

The central scheduler of asyncio. How it works:

```
while True:
    1. Run all READY tasks up to their first await
    2. Ask the OS: which sockets/timers are ready? (epoll/kqueue)
    3. Move completed tasks to the READY queue
    4. Repeat
```

---

## 3. Coroutine Lifecycle

```
Call async def func()
         │
         ▼
┌─────────────────┐
│ coroutine object│  ← STATE: GEN_CREATED
│ code: lines...  │    Nothing is executed!
│ locals: {}      │
└────────┬────────┘
         │ await func() or asyncio.run(func())
         ▼
┌─────────────────┐
│   RUNNING       │  ← Executes line by line
│                 │
│  ... code ...   │
│  await <awaitable>  ← PAUSE
└────────┬────────┘
         │ await
         ▼
┌─────────────────┐
│   SUSPENDED     │  ← State saved (locals, position)
│ waiting for I/O │    The Event Loop is free!
└────────┬────────┘
         │ I/O completed
         ▼
┌─────────────────┐
│   RUNNING       │  ← Resumes from the await point
└────────┬────────┘
         │ return
         ▼
┌─────────────────┐
│   CLOSED        │  ← GEN_CLOSED, result available
└─────────────────┘
```

---

## 4. Event Loop Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      EVENT LOOP (single thread)            │
│                                                            │
│  ┌──────────────────┐   ┌────────────────────────────────┐ │
│  │   Ready Queue    │   │  I/O Selector (epoll/kqueue)   │ │
│  │                  │   │                                │ │
│  │ [Task A] ──────► │   │ Socket A: HTTP ── WAITING      │ │
│  │ [Task C]         │   │ Socket B: DB   ── WAITING      │ │
│  │                  │   │ Socket C: API  ── READY! ◄──── │ │
│  └────────┬─────────┘   └──────────────┬─────────────────┘ │
│           │                             │                   │
│           ▼                             ▼                   │
│     Run Task                      Wake Task B              │
│     until await                   (move to Queue)          │
└────────────────────────────────────────────────────────────┘
```

### Where does the "waiting" actually happen?

When Python executes `await asyncio.sleep(1)`:
1. The Event Loop registers a timer with the OS
2. The coroutine moves to SUSPENDED
3. The OS uses `epoll`/`kqueue` — a hardware-backed notification mechanism
4. The Python thread sleeps, using ~0% CPU
5. After 1 second the OS wakes Python up, and the Event Loop resumes the coroutine

---

## 5. Cooperative vs Preemptive Multitasking

| | Preemptive (Threading) | Cooperative (Asyncio) |
|--|------------------------|----------------------|
| Who interrupts | The OS, forcibly, at any moment | The coroutine, voluntarily, via `await` |
| Race conditions | Yes — you need Lock/Semaphore | Less often — switches happen only at `await`, but state can change between `await`s (`asyncio.Lock`) |
| Stack | ~8 MB/thread | ~2 KB/coroutine |
| Max concurrent | ~500–1000 | ~100,000+ |
| Blocking call | Stops 1 thread | Stops the **entire** Event Loop |

**The key danger of asyncio:** a single blocking call (`time.sleep`, `requests.get`) stops EVERYTHING — not just one task.

---

## 6. asyncio API Reference

### Core functions

```python
# Program entry point
asyncio.run(main())
asyncio.run(main(), debug=True)

# Scheduling tasks
task = asyncio.create_task(coro())
tasks = asyncio.gather(coro1(), coro2(), coro3())
results = await asyncio.gather(*coros, return_exceptions=True)

# Waiting
await asyncio.sleep(seconds)        # Releases the Event Loop
await asyncio.wait_for(coro, timeout=5.0)  # With a timeout

# Checking status
task.done()        # True if finished
task.cancelled()   # True if cancelled
task.result()      # Returns the result or raises the exception
task.cancel()      # Sends CancelledError into the task

# Current Event Loop
loop = asyncio.get_event_loop()

# Delegating blocking code
result = await loop.run_in_executor(executor, sync_func, *args)
```

### async with and async for

```python
# async context manager
async with aiofiles.open("file.txt") as f:
    data = await f.read()

# async generator / iterator
async for item in async_generator():
    process(item)
```

---

## 7. Blocking vs Non-Blocking

### Replacement table

| Synchronous (BLOCKING) | Asynchronous (CORRECT) |
|------------------------|--------------------------|
| `time.sleep(n)` | `await asyncio.sleep(n)` |
| `requests.get(url)` | `await session.get(url)` (aiohttp) |
| `open(path).read()` | `await aio_file.read()` (aiofiles) |
| `psycopg2.connect(...)` | `await asyncpg.connect(...)` |
| `subprocess.run(cmd)` | `await asyncio.create_subprocess_exec(...)` |
| CPU-bound loop | `await loop.run_in_executor(process_pool, func)` |

### run_in_executor — the bridge between worlds

```python
import asyncio
import concurrent.futures

process_pool = concurrent.futures.ProcessPoolExecutor()
thread_pool = concurrent.futures.ThreadPoolExecutor()

async def handle_request():
    loop = asyncio.get_event_loop()

    # CPU-bound → ProcessPoolExecutor (bypasses the GIL)
    result = await loop.run_in_executor(process_pool, heavy_computation)

    # Legacy sync I/O → ThreadPoolExecutor
    data = await loop.run_in_executor(thread_pool, legacy_db_query)

    return result, data
```

---

## 8. FastAPI & Backend Integration

### Three kinds of endpoints in FastAPI

```python
from fastapi import FastAPI
import asyncio, time

app = FastAPI()

# ✅ async def + await: best for async I/O
@app.get("/users")
async def get_users(pool):
    async with pool.acquire() as conn:
        return await conn.fetch("SELECT * FROM users")

# ❌ async def + blocking: the worst (blocks the entire Event Loop!)
@app.get("/broken")
async def broken_endpoint():
    time.sleep(2)               # Stops the WHOLE server!
    return {"status": "bad"}

# ⚠️ def (not async): FastAPI automatically runs it in a threadpool
@app.get("/legacy")
def legacy_endpoint():
    time.sleep(2)               # OK — a separate thread, the loop is free
    return {"status": "ok but limited"}
```

### The FastAPI rule:
- `async def` + only `await` operations → **Event Loop (optimal)**
- `async def` + a blocking call → **disaster**
- `def` (sync) → **automatic threadpool** (safe, but limited)

### WebSocket scale

```
Synchronous WSGI (Gunicorn threads):
  10,000 WebSocket connections → 10,000 threads → ~80 GB RAM
  (practically impossible)

Asyncio ASGI (uvicorn):
  10,000 WebSocket connections → 10,000 coroutine objects → ~20 MB RAM
  (easy — only memory for the state)
```

---

## 9. Threading vs Multiprocessing vs Asyncio

| | Threading | Multiprocessing | Asyncio |
|--|-----------|----------------|---------|
| Model | N threads, 1 process | N processes | 1 thread, 1 process |
| GIL | One shared by all | Each has its own | One (not a limitation) |
| Scheduling | Preemptive (OS) | Preemptive (OS) | Cooperative (await) |
| Memory/unit | ~8 MB/thread | ~50 MB/process | ~2 KB/coroutine |
| Race conditions | Yes | No | Less often (only at `await`) |
| CPU-bound | ❌ GIL | ✅ True parallelism | ❌ Blocks the loop |
| I/O-bound | ✅ OK | ✅ OK | ✅ Best |
| Max concurrent | ~500 | ~CPU cores | ~100,000+ |
| Ideal for | Legacy sync libraries | ML, image, math | Web, API, WebSocket |

### A solution for combined workloads (FastAPI production)

```
HTTP request → FastAPI async endpoint
    │
    ├── DB query → asyncpg (async) → await
    ├── HTTP call → aiohttp (async) → await  
    └── CPU work → ProcessPoolExecutor → run_in_executor → await
```

---

## 10. Common mistakes and anti-patterns

### Anti-pattern 1: Blocking in async (the most frequent mistake)

```python
# DANGEROUS
async def endpoint():
    time.sleep(2)          # Stops the whole server!
    requests.get(url)      # Blocks the Event Loop!
    psycopg2.execute(...)  # Stops all connections!

# CORRECT
async def endpoint():
    await asyncio.sleep(2)
    async with session.get(url) as r: ...
    async with pool.acquire() as conn: await conn.fetch(...)
```

### Anti-pattern 2: A forgotten await

```python
# DANGEROUS — RuntimeWarning, nothing is executed
result = fetch_data()        # Returns a coroutine object!

# CORRECT
result = await fetch_data()  # Executes and waits
```

### Anti-pattern 3: A Task without a reference (the exception disappears)

```python
# DANGEROUS
asyncio.create_task(risky_op())  # The exception will be swallowed!

# CORRECT
task = asyncio.create_task(risky_op())
try:
    await task
except Exception as e:
    logger.error(f"Task failed: {e}")
```

### Anti-pattern 4: CPU-bound in async (freezes the loop)

```python
# DANGEROUS
async def process():
    result = sum(i*i for i in range(10**8))  # Blocks the loop for seconds!

# CORRECT
async def process():
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(process_pool, heavy_sync_func)
```

### Anti-pattern 5: Main finishes before the Task

```python
# DANGEROUS
async def main():
    asyncio.create_task(background_work())
    # The Event Loop stops → the Task is destroyed!

# CORRECT
async def main():
    task = asyncio.create_task(background_work())
    await asyncio.sleep(0)  # Let the Task start
    await task               # Explicitly wait
```

---

## 11. Production Patterns

### Pattern 1: Connection Pool with a Semaphore

```python
class ConnectionPool:
    def __init__(self, max_size: int):
        self._semaphore = asyncio.Semaphore(max_size)
    
    async def __aenter__(self):
        await self._semaphore.acquire()
        return await self._create_connection()
    
    async def __aexit__(self, *args):
        self._semaphore.release()
```

### Pattern 2: Retry with Exponential Backoff

```python
async def with_retry(coro_factory, max_retries=3, base_delay=1.0):
    for attempt in range(max_retries):
        try:
            return await coro_factory()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            delay = base_delay * (2 ** attempt)
            await asyncio.sleep(delay)
```

### Pattern 3: Producer-Consumer with asyncio.Queue

```python
async def producer(queue: asyncio.Queue, items):
    for item in items:
        await queue.put(item)
    await queue.put(None)  # sentinel

async def consumer(queue: asyncio.Queue):
    while True:
        item = await queue.get()
        if item is None:
            break
        await process(item)
        queue.task_done()
```

### Pattern 4: Rate Limiter

```python
class AsyncRateLimiter:
    def __init__(self, max_calls: int, period: float = 1.0):
        self._semaphore = asyncio.Semaphore(max_calls)
        self._period = period
    
    async def __aenter__(self):
        await self._semaphore.acquire()
        asyncio.create_task(self._release_after_period())
        return self
    
    async def _release_after_period(self):
        await asyncio.sleep(self._period)
        self._semaphore.release()
    
    async def __aexit__(self, *args):
        pass
```

---

## 12. Debugging Guide

### Debugging tools

```bash
# 1. Debug mode via an environment variable
PYTHONASYNCIODEBUG=1 python app.py

# 2. Verbose asyncio logging
PYTHONASYNCIODEBUG=1 python -W always app.py
```

```python
# 3. Debug mode in code
asyncio.run(main(), debug=True)

# 4. A custom exception handler
def handle_exception(loop, context):
    logger.error(f"Unhandled exception: {context}")

loop = asyncio.get_event_loop()
loop.set_exception_handler(handle_exception)
```

### What debug mode detects

| Problem | What debug mode reports |
|----------|--------------------|
| A coroutine was never awaited | `RuntimeWarning: coroutine was never awaited` |
| A blocking function > 100ms | `Executing took X.XX seconds` |
| An exception in a Task without await | A log message at GC time |
| Slow callbacks | `Executing callback took X seconds` |

### Analyzing a typical stack trace

```
Task exception was never retrieved
future: <Task finished name='Task-2' coro=<risky_op() at app.py:15>
exception=ValueError('...')>
Traceback (most recent call last):
  File "app.py", line 17, in risky_op   ← Where the exception occurred
    raise ValueError(...)
ValueError: ...
```

**Rule:** if you see "Task exception was never retrieved", find the place where the Task was created and add a `try/except` around `await task`.

---

## Connection to previous lessons

| Lesson | Topic | Relation to Asyncio |
|------|------|-----------------------|
| 32 | Threading | Preemptive vs Cooperative multitasking |
| 33 | Multiprocessing | ProcessPoolExecutor for run_in_executor |
| 34 | **Asyncio** | **This lesson** |
| — | FastAPI | Asyncio = the engine for ASGI web servers |
