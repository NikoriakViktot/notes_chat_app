# Lesson 31 — HTTP Requests: Documentation and Architecture Diagrams

**Module 4 · Network & Concurrent Systems**

> This file is a reference and architectural companion to `note_lesson_31_http_requests.ipynb`.
> It contains Mermaid diagrams, in-depth explanations and production patterns.

---

## Contents

1. [What is HTTP](#1-what-is-http)
2. [Layers of the network stack](#2-layers-of-the-network-stack)
3. [The 7 phases of an HTTP request](#3-the-7-phases-of-an-http-request)
4. [requests: Internal architecture](#4-requests-internal-architecture)
5. [Error types and their sources](#5-error-types-and-their-sources)
6. [HTTP Methods and semantics](#6-http-methods-and-semantics)
7. [Session vs Standalone Requests](#7-session-vs-standalone-requests)
8. [Production Patterns](#8-production-patterns)
9. [Debugging Flowchart](#9-debugging-flowchart)

---

## 1. What is HTTP

### Definition

HTTP (HyperText Transfer Protocol) is a text-based application-layer (L7) protocol
that defines the format of requests and responses between a client and a server.

### Key properties

| Property | Explanation |
| ----------- | --------- |
| **Stateless** | The server does not remember previous requests |
| **Text-based** | Messages are formatted ASCII text |
| **Request-Response** | The client always initiates, the server responds |
| **TCP-based** | Runs on top of TCP (reliable delivery) |
| **Layered** | HTTP knows nothing about TCP details; TCP knows nothing about HTTP |

### Anatomy of an HTTP Request

```
GET /users/octocat HTTP/1.1\r\n         ← Request Line
Host: api.github.com\r\n                 ← Headers (the envelope)
User-Agent: python-requests/2.28.1\r\n
Authorization: Bearer token123\r\n
Accept: application/json\r\n
\r\n                                     ← Empty line = end of headers
                                         ← Body (empty for GET)
```

### Anatomy of an HTTP Response

```
HTTP/1.1 200 OK\r\n                      ← Status Line
Content-Type: application/json\r\n       ← Headers
Content-Length: 135\r\n
X-RateLimit-Remaining: 59\r\n
\r\n                                     ← Empty line
{"login": "octocat", "id": 1, ...}       ← Body (JSON)
```

---

## 2. Layers of the Network Stack

```mermaid
flowchart TD
    A["🐍 Your Python code<br>requests.get(url)"]
    B["📦 requests library<br>Session · PreparedRequest · HTTPAdapter"]
    C["🔗 urllib3<br>ConnectionPool · HTTPConnection · Retry"]
    D["⚙️ OS Kernel<br>TCP/IP Stack · DNS · TLS · Socket Buffers"]
    E["🔌 NIC Hardware<br>Network card driver"]
    F["🌐 Internet<br>Routers · Switches · Optical Fiber"]
    G["🖥️ Remote Server<br>Nginx · FastAPI · Django · Database"]

    A -->|"high-level wrapper"| B
    B -->|"connection pooling"| C
    C -->|"system calls (syscalls)"| D
    D -->|"NIC driver interrupt"| E
    E -->|"electrical / optical signals"| F
    F -->|"TCP segments"| G

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class A,B,C,F step;
    class D,E warning;
    class G success;
```

**Key principle:** Python works only at level A and partly at level B.
Everything below is the OS Kernel and hardware. `requests` hides this complexity,
but when errors happen it "leaks" back to you as an exception.

---

## 3. The 7 Phases of an HTTP Request

### Sequence Diagram: The Full Lifecycle

```mermaid
sequenceDiagram
    participant PY as 🐍 Python Process
    participant OS as ⚙️ OS Kernel
    participant DNS as 🔍 DNS Server
    participant NET as 🌐 Internet
    participant SRV as 🖥️ Remote Server
    participant DB as 🗄️ Database

    Note over PY: [T=0] requests.get() is called
    Note over PY: Python STOPS

    PY->>OS: getaddrinfo("api.github.com")
    OS->>DNS: UDP Query: "api.github.com?"
    DNS-->>OS: IP: 140.82.112.4
    OS-->>PY: IP received

    Note over PY,OS: Phase 1: DNS Resolution ✓

    PY->>OS: connect(140.82.112.4:443)
    OS->>SRV: SYN →
    SRV-->>OS: ← SYN-ACK
    OS->>SRV: ACK →
    Note over OS,SRV: TCP ESTABLISHED
    OS->>SRV: TLS ClientHello →
    SRV-->>OS: ← TLS ServerHello + Certificate
    OS->>SRV: TLS Finished →
    Note over OS,SRV: TLS ESTABLISHED

    Note over PY,OS: Phase 2: TCP + TLS Handshake ✓

    PY->>OS: sendall(HTTP bytes)
    Note over PY: PreparedRequest is built
    OS->>NET: TCP Segments
    NET->>SRV: Packets arrived

    Note over PY,OS: Phase 3+4: Serialization + Send ✓
    Note over PY: Python SLEEPS (blocking recv)

    SRV->>DB: SQL Query
    DB-->>SRV: Result rows
    SRV->>SRV: Builds the JSON response
    SRV->>NET: HTTP Response bytes
    NET->>OS: Packets arrived

    Note over PY,OS: Phase 5: Server Processing ✓

    OS->>OS: Receive Buffer filled
    Note over PY: Hardware interrupt!
    OS-->>PY: recv() returns bytes
    Note over PY: Python WAKES UP

    Note over PY,OS: Phase 6: Receiving + Wakeup ✓

    PY->>PY: HTTP parsing → Response object
    PY->>PY: response.json() → json.loads()
    Note over PY: [T=6] requests.get() returns a Response

    Note over PY: Phase 7: Deserialization ✓
```

### The phases in detail

| Phase | Time | Where Python is | Who does the work |
| ---- | --- | --------- | ------------------- |
| DNS Resolution | T=0 | Stopped | OS Kernel → DNS Server |
| TCP + TLS Handshake | T=1 | Stopped | OS Kernel ↔ Remote OS |
| HTTP Serialization | T=2 | Active | `requests` library |
| Send + Long Sleep | T=3 | **Sleeping** | OS Kernel → NIC → Internet |
| Server Processing | T=4 | **Sleeping** | Remote Server + DB |
| Receive + Wakeup | T=5 | Waking up | OS Kernel (interrupt) |
| Deserialization | T=6 | Active | `json.loads()` in RAM |

---

## 4. requests: Internal Architecture

```mermaid
classDiagram
    class Session {
        +headers: dict
        +cookies: CookieJar
        +auth: tuple
        +adapters: dict
        +get(url, **kwargs)
        +post(url, **kwargs)
        +request(method, url, **kwargs)
        +prepare_request(request)
    }

    class Request {
        +method: str
        +url: str
        +headers: dict
        +params: dict
        +data: dict
        +json: dict
        +auth: tuple
    }

    class PreparedRequest {
        +method: str
        +url: str
        +headers: CaseInsensitiveDict
        +body: bytes
        +prepare()
    }

    class HTTPAdapter {
        +max_retries: Retry
        +send(request, timeout)
        +build_response(request, resp)
    }

    class Response {
        +status_code: int
        +headers: dict
        +text: str
        +content: bytes
        +request: PreparedRequest
        +history: list
        +json()
        +raise_for_status()
    }

    Session --> Request : prepare_request()
    Request --> PreparedRequest : prepare()
    Session --> HTTPAdapter : send()
    HTTPAdapter --> Response : build_response()
    Response --> PreparedRequest : .request (back reference)
```

### Data flow inside requests

```mermaid
flowchart LR
    A["requests.get(url,<br>params=..., headers=..., json=..., timeout=...)"]

    B["Request object<br>(not prepared)"]

    C["PreparedRequest: method='GET'<br>url='https://...?q=python', headers={...}, body=b'{...}'"]

    D["HTTPAdapter.send()<br>urllib3 ConnectionPool"]

    E["OS Socket<br>sendall() + recv()"]

    F["HTTP Response bytes<br>HTTP/1.1 200 OK ..."]

    G["Response object<br>.status_code=200, .headers={...}, .text='...'"]

    A -->|"Session.request()"| B
    B -->|"prepare_request()"| C
    C -->|"adapter.send()"| D
    D -->|"socket syscall"| E
    E -->|"raw bytes"| F
    F -->|"build_response()"| G

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class A,B,D,F step;
    class C,E warning;
    class G success;
```

---

## 5. Error Types and Their Sources

```mermaid
flowchart TD
    START["requests.get(url, timeout=5)"]

    DNS{"DNS Resolution<br>succeeded?"}
    TCP{"TCP Handshake<br>succeeded?"}
    SEND{"sendall()<br>succeeded?"}
    WAIT{"recv()<br>received bytes?"}
    STATUS{"HTTP Status<br>Code?"}
    JSON{"response.json()<br>succeeded?"}

    ERR1["❌ ConnectionError (DNSError)<br>DNS does not respond or the domain does not exist"]
    ERR2["❌ ConnectionError (Connection Refused)<br>Server closed TCP or the port is not listening"]
    ERR3["❌ ConnectTimeout<br>TCP handshake took too long"]
    ERR4["❌ ReadTimeout<br>Server did not respond within read_timeout seconds"]
    ERR5["⚠️ HTTPError 4xx: your request is wrong<br>401 · 403 · 404 · 429"]
    ERR6["⚠️ HTTPError 5xx: the server is broken<br>500 · 502 · 503 · 504"]
    ERR7["❌ JSONDecodeError<br>Server returned HTML instead of JSON"]
    SUCCESS["✅ Python dict<br>Data received"]

    START --> DNS
    DNS -->|"no"| ERR1
    DNS -->|"yes"| TCP
    TCP -->|"RST packet"| ERR2
    TCP -->|"Timeout"| ERR3
    TCP -->|"OK"| SEND
    SEND --> WAIT
    WAIT -->|"Timeout"| ERR4
    WAIT -->|"bytes"| STATUS
    STATUS -->|"2xx"| JSON
    STATUS -->|"4xx"| ERR5
    STATUS -->|"5xx"| ERR6
    JSON -->|"HTML/XML"| ERR7
    JSON -->|"valid JSON"| SUCCESS

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class START step;
    class DNS,TCP,SEND,WAIT,STATUS,JSON decision;
    class ERR1,ERR2,ERR3,ERR4,ERR7 error;
    class ERR5,ERR6 warning;
    class SUCCESS success;
```

### Table: Exception → Cause → Action

| Exception | Layer | Cause | Action |
| --------- | ------ | ------- | --- |
| `ConnectionError` (DNS) | L3-L4 | Domain not found | Check DNS: `ping domain.com` |
| `ConnectionError` (Refused) | L4 | Port closed, RST | Check whether the server is running |
| `ConnectTimeout` | L4 | Handshake hung | Increase connect_timeout or check the firewall |
| `ReadTimeout` | L7 | Server is slow | Increase read_timeout or retry |
| `SSLError` | L4-L7 | Invalid certificate | Update the CA bundle or `verify=False` (dangerous!) |
| `HTTPError 401` | L7 | No authorization | Add an `Authorization` header |
| `HTTPError 403` | L7 | Blocked (WAF/bot) | Check `User-Agent`, IP ban |
| `HTTPError 404` | L7 | Resource does not exist | Check the URL, do not retry |
| `HTTPError 429` | L7 | Rate limit | Wait `Retry-After` seconds |
| `HTTPError 5xx` | L7 | Server is broken | Retry with backoff |
| `JSONDecodeError` | Python | HTML instead of JSON | Check the `Content-Type` header |
| `TooManyRedirects` | L7 | Redirect loop | `allow_redirects=False`, check the URL |

---

## 6. HTTP Methods and Semantics

```mermaid
flowchart LR
    subgraph GET["GET — Retrieve a resource"]
        direction TB
        G1["params= → URL query string<br>?search=python&page=1"]
        G2["Body: empty"]
        G3["Idempotent: Yes<br>Safe: Yes (does not change state)"]
    end

    subgraph POST["POST — Create a resource"]
        direction TB
        P1["json= → JSON body<br>data= → form-encoded body"]
        P2["Body: payload"]
        P3["Idempotent: No<br>Safe: No"]
    end

    subgraph PUT["PUT — Replace a resource"]
        direction TB
        U1["json= → full replacement of the object"]
        U2["Body: the full object"]
        U3["Idempotent: Yes<br>Safe: No"]
    end

    subgraph PATCH["PATCH — Partially update"]
        direction TB
        PA1["json= → only the changed fields"]
        PA2["Body: partial changes"]
        PA3["Idempotent: Depends<br>Safe: No"]
    end

    subgraph DELETE["DELETE — Delete a resource"]
        direction TB
        D1["params= → ID in the URL"]
        D2["Body: usually empty"]
        D3["Idempotent: Yes<br>Safe: No"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class G1,G2,P1,P2,U1,U2,PA1,PA2,D1,D2 step;
    class G3,U3,D3 success;
    class P3 warning;
    class PA3 decision;
```

### Where the data goes — a clear comparison

| Kwargs | HTTP part | Method | Example |
| ------ | ------------ | ----- | ------- |
| `params={'q': 'py'}` | URL: `?q=py` | GET | search, filtering |
| `headers={'Auth': '...'}` | HTTP Headers | any | tokens, content-type |
| `data={'key': 'val'}` | Body (form-encoded) | POST | HTML forms |
| `json={'key': 'val'}` | Body (JSON) | POST/PUT/PATCH | REST API |
| `files={'file': ...}` | Body (multipart) | POST | file uploads |
| `auth=('user','pass')` | Authorization header | any | Basic Auth |

---

## 7. Session vs Standalone Requests

```mermaid
sequenceDiagram
    participant CODE as Your code
    participant SA as Standalone requests
    participant SESS as requests.Session()
    participant SRV as Server

    Note over CODE,SRV: STANDALONE — every request is isolated

    CODE->>SA: requests.get(url, auth=creds)
    SA->>SRV: GET + Authorization header
    SRV-->>SA: 200 OK + Set-Cookie: session=abc
    SA-->>CODE: Response (cookie discarded!)

    CODE->>SA: requests.get(url)
    SA->>SRV: GET (no cookie, no auth!)
    SRV-->>SA: 401 Unauthorized
    SA-->>CODE: Response(401)

    Note over CODE,SRV: SESSION — state is preserved

    CODE->>SESS: session.auth = ('user', 'pass')
    CODE->>SESS: session.get(url)
    SESS->>SRV: GET + Authorization header
    SRV-->>SESS: 200 OK + Set-Cookie: session=abc
    SESS->>SESS: Cookie saved automatically!
    SESS-->>CODE: Response(200)

    CODE->>SESS: session.get(other_url)
    SESS->>SRV: GET + Authorization + Cookie: session=abc
    SRV-->>SESS: 200 OK
    SESS-->>CODE: Response(200)
```

### What a Session keeps between requests

```python
session = requests.Session()
session.headers['User-Agent'] = 'MyApp/1.0'     # every request will have this User-Agent
session.auth = ('user', 'pass')                  # Basic Auth in every request
session.cookies.set('tracking', 'value')         # cookie in every request
session.verify = False                           # disable SSL verification (dangerous!)
```

---

## 8. Production Patterns

### 8.1. Basic Production Pattern

```python
import requests
from typing import Any

def safe_api_call(
    url: str,
    method: str = 'GET',
    **kwargs: Any
) -> dict:
    """
    Production-grade HTTP request with full error handling.
    """
    kwargs.setdefault('timeout', (3.05, 10))

    try:
        response = requests.request(method, url, **kwargs)
        response.raise_for_status()
        return response.json()

    except requests.exceptions.ConnectTimeout:
        raise RuntimeError(f"TCP handshake timeout: {url}")

    except requests.exceptions.ReadTimeout:
        raise RuntimeError(f"Server response timeout: {url}")

    except requests.exceptions.ConnectionError as e:
        raise RuntimeError(f"Network unreachable (DNS/TCP): {e}")

    except requests.exceptions.HTTPError as e:
        status = e.response.status_code
        body = e.response.text[:500]
        raise RuntimeError(f"HTTP {status} from {url}: {body}")

    except ValueError:
        raise RuntimeError(f"Invalid JSON from {url}: {response.text[:200]}")
```

### 8.2. Session with Retry and Backoff

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


def build_session(
    retries: int = 3,
    backoff_factor: float = 1.0,
    token: str = '',
) -> requests.Session:
    """
    Production session with retry, backoff and authorization.
    """
    retry_strategy = Retry(
        total=retries,
        backoff_factor=backoff_factor,   # 1s → 2s → 4s between attempts
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=['GET', 'POST', 'PUT'],
        respect_retry_after_header=True,
    )

    adapter = HTTPAdapter(max_retries=retry_strategy)

    session = requests.Session()
    session.mount('https://', adapter)
    session.mount('http://', adapter)

    if token:
        session.headers['Authorization'] = f'Bearer {token}'

    return session


# Usage
session = build_session(
    retries=3,
    backoff_factor=1.0,
    token='my_api_token_here'
)

response = session.get(
    'https://httpbin.org/get',
    params={'q': 'python'},
    timeout=(3.05, 10)
)
response.raise_for_status()
data = response.json()
```

### 8.3. Debugging Helper

```python
import requests

def inspect_request(response: requests.Response) -> None:
    """Full diagnostics of the sent request and the received response."""

    req = response.request

    print("── SENT ─────────────────────────────")
    print(f"  {req.method} {req.url}")
    for k, v in req.headers.items():
        print(f"  {k}: {v}")
    if req.body:
        print(f"\n  Body: {req.body[:200]}")

    print("\n── RECEIVED ─────────────────────────")
    print(f"  HTTP {response.status_code} {response.reason}")
    for k, v in response.headers.items():
        print(f"  {k}: {v}")
    print(f"\n  Body (first 300 characters):")
    print(f"  {response.text[:300]}")

    if response.history:
        print(f"\n── REDIRECTS ({len(response.history)}) ────────────")
        for r in response.history:
            print(f"  {r.status_code} → {r.headers.get('Location')}")
```

---

## 9. Debugging Flowchart

```mermaid
flowchart TD
    START["The API responds incorrectly or an exception is raised"]

    Q1{"What type of<br>exception?"}

    Q2{"ConnectionError:<br>DNS or Refused?"}
    Q3{"Timeout:<br>connect or read?"}
    Q4{"HTTPError:<br>which status?"}
    Q5{"JSONDecodeError?"}

    A1["ping the domain in a terminal, curl -v URL<br>check Wi-Fi/VPN"]
    A2["nc -zv host port<br>check whether the server is running, and the firewall rules"]
    A3["increase connect_timeout, check firewall/NAT<br>curl --connect-timeout 10"]
    A4["increase read_timeout<br>check the server load"]

    A5A["check the Authorization header"]
    A5B["check User-Agent, IP ban"]
    A5C["check the URL, do not retry"]
    A5D["wait for Retry-After"]
    A5E["retry with backoff"]

    A6["check the Content-Type header, print(response.text[:300])<br>check raise_for_status() first"]

    START --> Q1
    Q1 -->|"ConnectionError"| Q2
    Q1 -->|"Timeout"| Q3
    Q1 -->|"HTTPError"| Q4
    Q1 -->|"JSONDecodeError"| Q5
    Q1 -->|"No exception,<br>but the result is wrong"| INSPECT

    Q2 -->|"DNS fail"| A1
    Q2 -->|"Connection Refused"| A2
    Q3 -->|"connect timeout"| A3
    Q3 -->|"read timeout"| A4
    Q4 -->|"401"| A5A
    Q4 -->|"403"| A5B
    Q4 -->|"404"| A5C
    Q4 -->|"429"| A5D
    Q4 -->|"5xx"| A5E
    Q5 --> A6

    INSPECT["Inspect the PreparedRequest:<br>print(response.request.url / .headers / .body)"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class START error;
    class Q1,Q2,Q3,Q4,Q5 decision;
    class A1,A2,A3,A4,A6,INSPECT step;
    class A5A,A5B,A5C,A5D,A5E warning;
```

### General Debug Checklist

```
Step 1: Check status_code
    → 2xx? Continue
    → 4xx? Your request is wrong
    → 5xx? The server is broken, retry

Step 2: Check Content-Type
    → application/json? You can call response.json()
    → text/html? The server returned an HTML error page

Step 3: Look at the first 300 characters of the body
    → response.text[:300]

Step 4: Check what Python sent
    → response.request.url
    → response.request.headers
    → response.request.body

Step 5: Bypass Python
    → curl -v "https://..." in a terminal
    → ping domain.com
    → telnet host port
```

---

## Glossary

| Term | Definition |
| ------ | ---------- |
| **HTTP** | HyperText Transfer Protocol — a text-based L7 protocol |
| **Stateless** | Every request is isolated; the server does not remember previous ones |
| **TCP Handshake** | 3-way (SYN-SYN/ACK-ACK) connection establishment |
| **TLS** | Transport Layer Security — HTTPS encryption |
| **DNS** | Domain Name System — converting a domain into an IP |
| **PreparedRequest** | An internal requests object: a ready HTTP byte string |
| **Blocking I/O** | `recv()` stops the Python process until the response arrives |
| **Serialization** | Python dict → JSON string → bytes |
| **Deserialization** | bytes → JSON string → Python dict |
| **Timeout tuple** | `(connect_timeout, read_timeout)` in seconds |
| **raise_for_status()** | Raises `HTTPError` if status_code >= 400 |
| **Session** | An object that keeps headers/cookies/auth between requests |
| **Retry / Backoff** | Repeated attempts with a growing pause between them |
| **Rate Limiting** | The server limits the number of requests (429 Too Many Requests) |
| **Thundering Herd** | All retries fire at the same time → server overload |
| **Circuit Breaker** | A pattern: after N errors — fail immediately, do not retry |

---

*Documentation for Lesson 31 · Module 4 · Python Networking Course*
