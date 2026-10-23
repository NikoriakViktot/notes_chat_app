# Python Web Servers, Kernel та Production Networking

---

# Головна ідея

Більшість початківців думають:

```python
from fastapi import FastAPI
```

або:

```python
from flask import Flask
```

це вже:

```text
web server
```

Але це НЕ так.

---

# Framework ≠ Server

FastAPI, Flask, Django —
це:

```text
application frameworks
```

Вони:
- описують routes,
- business logic,
- request handlers,
- middleware.

Але вони НЕ:
- відкривають TCP sockets напряму,
- НЕ роблять accept(),
- НЕ керують epoll/select,
- НЕ працюють із kernel networking stack напряму.

---

# Хто реально працює з мережею?

Реальний networking робить:

- Gunicorn
- Uvicorn
- Hypercorn
- uWSGI
- Daphne

Саме вони:
- відкривають sockets,
- bind() на port,
- listen(),
- accept(),
- recv(),
- send().

---

# Архітектурно

```text
Python App
    ↓
WSGI / ASGI
    ↓
Python Server
    ↓
OS Kernel
    ↓
TCP/IP Stack
    ↓
Network
```

---

# Що таке WSGI?

WSGI =
```text
Web Server Gateway Interface
```

Старий synchronous стандарт Python web.

---

# WSGI модель

```text
HTTP Request
↓
1 worker/thread/process
↓
Framework handles request
↓
HTTP Response
```

---

# Frameworks які працюють через WSGI

| Framework | Тип |
|---|---|
| Flask | minimal WSGI |
| Django (classic) | full-stack WSGI |

---

# Що таке ASGI?

ASGI =
```text
Asynchronous Server Gateway Interface
```

Новий async стандарт Python.

---

# ASGI підтримує

- asyncio
- WebSocket
- long connections
- streaming
- async I/O
- event loops

---

# Frameworks які працюють через ASGI

| Framework | Тип |
|---|---|
| FastAPI | modern ASGI |
| Starlette | lightweight ASGI |
| Quart | async Flask |
| aiohttp | async HTTP |
| modern Django async | hybrid |

---

# Найважливіший systems-thinking момент

Framework:
```text
визначає application logic
```

Server:
```text
визначає networking model
```

---

# Що реально робить Gunicorn?

Gunicorn:
- socket()
- bind()
- listen()
- fork workers
- accept()
- recv()
- передає request у Flask/Django app

---

# Gunicorn lifecycle

```text
socket()
↓
bind()
↓
listen()
↓
fork workers
↓
accept()
↓
recv()
↓
WSGI app
↓
response
```

---

# Що реально робить Uvicorn?

Uvicorn —
це async ASGI server.

Він:
- використовує event loop,
- epoll/select,
- non-blocking sockets,
- asyncio tasks.

---

# Uvicorn lifecycle

```text
socket()
↓
epoll/select
↓
event loop
↓
async tasks
↓
ASGI app
↓
await recv/send
```

---

# Production Architecture

Типова production схема для FastAPI:

```text
                 INTERNET
                      │
══════════════════════╪══════════════════════
                      ▼
               ┌────────────┐
               │   Nginx    │
               │ :80 / :443 │
               └─────┬──────┘
                     │ reverse proxy
                     ▼
          ┌─────────────────────┐
          │     Uvicorn         │
          │   ASGI Server       │
          └─────┬──────┬────────┘
                │      │
         Worker 1   Worker 2
                │      │
                ▼      ▼
             FastAPI App
```

---

# Для Django

```text
Browser
↓
Nginx
↓
Gunicorn
↓
Django
```

---

# Що робить Nginx?

Nginx:
- слухає 80/443,
- TLS/HTTPS,
- reverse proxy,
- buffering,
- static files,
- load balancing,
- keep-alive connections.

---

# Чому НЕ запускати FastAPI/Flask напряму?

Бо:

```python
app.run()

```

це:

```text
development server
```

---

# Development server НЕ вміє нормально

- multiprocessing
- worker management
- graceful shutdown
- production buffering
- efficient concurrency
- load balancing
- advanced socket handling

---

# Повна Mental Model

```text
        USER SPACE
═══════════════════════════════════

 FastAPI / Django / Flask
            │
            ▼
    Uvicorn / Gunicorn
            │
            ▼
════════ syscall boundary ════════

         OS KERNEL
═══════════════════════════════════

 TCP Stack
 Socket Buffers
 Scheduler
 epoll/select
 File Descriptors

═══════════════════════════════════

        NETWORK LAYER
═══════════════════════════════════

 TCP/IP
 Ethernet
 Wi-Fi
 Routers
 Internet
```

---

# Що означає recv() у production server?

Коли Uvicorn або Gunicorn робить:

```python
sock.recv(1024)
```

це означає:

```text
перехід через syscall boundary у kernel
```

---

# Далі kernel:

- перевіряє receive buffer,
- якщо bytes є → повертає data,
- якщо bytes немає → блокує thread/process.

---

# Blocking Model

```text
Python Process
↓
recv()
↓
Kernel checks socket buffer
↓
buffer empty
↓
process asleep
↓
packet arrives
↓
kernel wakeup
↓
recv() returns bytes
```

---

# Найважливіший висновок

Python framework —
це лише application layer.

Реальний networking:
- sockets,
- TCP,
- buffers,
- event loops,
- epoll/select,
- scheduler,
- kernel wakeups

робить:
- Gunicorn,
- Uvicorn,
- kernel networking stack.

# 🔥 1. Flask / Django (WSGI) Architecture

```mermaid
flowchart TB

    Browser["🌍 Browser"]

    Nginx["Nginx<br>Reverse Proxy"]

    Gunicorn["Gunicorn<br>WSGI Server"]

    Django["Django / Flask<br>WSGI App"]

    Browser -->|"HTTP Request"| Nginx

    Nginx -->|"proxy_pass"| Gunicorn

    Gunicorn -->|"WSGI call"| Django

    Django --> Gunicorn

    Gunicorn --> Nginx

    Nginx --> Browser

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,Gunicorn step;
    class Nginx warning;
    class Django success;
```

---

# 🔥 2. FastAPI + Uvicorn (ASGI)

```mermaid
flowchart TB

    Browser["🌍 Browser"]

    Nginx["Nginx<br>:80 / :443"]

    Uvicorn["Uvicorn<br>ASGI Server"]

    Loop["asyncio Event Loop"]

    FastAPI["FastAPI<br>ASGI App"]

    Browser --> Nginx

    Nginx -->|"reverse proxy"| Uvicorn

    Uvicorn --> Loop

    Loop --> FastAPI

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,Uvicorn step;
    class Nginx warning;
    class Loop decision;
    class FastAPI success;
```

---

# 🔥 3. Full Production Networking Stack

```mermaid
flowchart TB

    subgraph USER["USER SPACE"]
        App["FastAPI / Django / Flask"]
        Server["Uvicorn / Gunicorn"]
    end

    subgraph KERNEL["KERNEL SPACE"]
        TCP["TCP/IP Stack"]
        Buffers["Socket Buffers"]
        Scheduler["Scheduler"]
        Epoll["epoll/select"]
    end

    NIC["🌐 NIC Driver"]

    Internet["🌍 Internet"]

    App --> Server

    Server -->|"syscalls"| TCP

    TCP --> Buffers
    TCP --> Scheduler
    TCP --> Epoll

    Buffers --> NIC

    NIC --> Internet

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class App,Server success;
    class TCP,Buffers,Scheduler,Epoll warning;
    class NIC,Internet step;
```

---

# 🔥 4. Gunicorn Worker Model

```mermaid
flowchart TB

    Master["Gunicorn Master Process"]

    W1["Worker 1"]
    W2["Worker 2"]
    W3["Worker 3"]

    Flask["Flask/Django App"]

    Master --> W1
    Master --> W2
    Master --> W3

    W1 --> Flask
    W2 --> Flask
    W3 --> Flask

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Master warning;
    class W1,W2,W3 step;
    class Flask success;
```

---

# 🔥 5. Uvicorn Event Loop Model

```mermaid

flowchart LR

    EventLoop["🔄 asyncio Event Loop"]

    Socket1["Socket A"]
    Socket2["Socket B"]
    Socket3["Socket C"]

    FastAPI["FastAPI ASGI App"]

    EventLoop --> Socket1
    EventLoop --> Socket2
    EventLoop --> Socket3

    Socket1 --> FastAPI
    Socket2 --> FastAPI
    Socket3 --> FastAPI

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class EventLoop warning;
    class Socket1,Socket2,Socket3 step;
    class FastAPI success;
```

---

# 🔥 6. recv() Through Kernel Boundary

```mermaid
sequenceDiagram

    participant Python as Uvicorn/Gunicorn
    participant Kernel as OS Kernel
    participant NIC as Network Card

    Python->>Kernel: recv()

    Kernel->>Kernel: check socket buffer

    alt buffer empty
        Kernel->>Python: BLOCK process/thread
    end

    NIC->>Kernel: packet arrived

    Kernel->>Kernel: copy bytes into receive buffer

    Kernel-->>Python: return bytes
```

---

# 🔥 7. Development Server vs Production Server

```mermaid
flowchart LR

    subgraph DEV["❌ Development"]
        FlaskRun["app.run()"]
        Single["single process"]
        NoWorkers["no worker management"]
    end

    subgraph PROD["✅ Production"]
        Nginx["Nginx"]
        Gunicorn["Gunicorn/Uvicorn"]
        Workers["multiple workers"]
        Buffers["socket buffering"]
    end

    FlaskRun --> Single
    Single --> NoWorkers

    Nginx --> Gunicorn
    Gunicorn --> Workers
    Workers --> Buffers

    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class FlaskRun,Single,NoWorkers error;
    class Nginx,Gunicorn,Workers,Buffers success;
```

---

# 🔥 8. Reverse Proxy Architecture

```mermaid
flowchart LR

    Browser["🌍 Browser"]

    Nginx["Nginx Reverse Proxy"]

    API1["FastAPI Worker 1"]
    API2["FastAPI Worker 2"]
    API3["FastAPI Worker 3"]

    Browser --> Nginx

    Nginx --> API1
    Nginx --> API2
    Nginx --> API3

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser step;
    class Nginx warning;
    class API1,API2,API3 success;
```

---

# 🔥 9. Socket Lifecycle in Production Server

```mermaid
stateDiagram-v2

    [*] --> socket

    socket --> bind

    bind --> listen

    listen --> accept

    accept --> recv

    recv --> process_request

    process_request --> send_response

    send_response --> close

    close --> [*]
```

