# Lesson: Network Foundation — From the Wire to Python

> **Before learning Django, you need to understand where your code lives.**
> Django is just one layer in a large stack. This document describes all the layers below it.

---

## Why learn this?

When you run `python manage.py runserver` and open the browser, dozens of operations take place: a DNS query, a TCP connection, HTTP negotiation, request parsing. Most developers do not know what happens before the request reaches their Python code. That is the cause of most production bugs.

---

## 1. What is a network?

A network is a system in which two or more computers can exchange data. Physically, it is wires, optical fiber, a Wi-Fi signal. Logically, it is a set of protocols (agreements about a language).

### Levels of abstraction (the OSI model — simplified)

| Layer | What it does | Example |
|--------|-----------|---------|
| Physical | Transmits bits | Cable, Wi-Fi |
| Data link | Addressing within a local network | MAC address |
| Network | Routing between networks | IP |
| Transport | Reliable transmission | TCP, UDP |
| Application | Protocols for programs | HTTP, DNS, SSH |

> **Key idea:** Each layer solves one task and does not know the details of the other layers.

---

## 2. IP address — where a computer lives

An IP address (Internet Protocol Address) is a unique numeric identifier of every device on a network.

### IPv4

```
192.168.1.105
```

Four numbers (0–255) separated by dots. About 4 billion addresses in total. Almost exhausted.

### IPv6

```
2001:0db8:85a3:0000:0000:8a2e:0370:7334
```

A 128-bit address. A practically unlimited space.

### Public vs Private IP

| Type | Example | Visible from the Internet |
|-----|---------|-------------------|
| Public | `104.21.14.55` | Yes |
| Private | `192.168.1.x`, `10.0.0.x` | No (only within the local network) |

When you open `localhost:8000`, you are addressing `127.0.0.1`, the address of the machine itself (loopback).

---

## 3. DNS — the phone book of the Internet

Computers communicate through IP addresses. But people remember `google.com`, not `142.250.74.46`.

**DNS (Domain Name System)** is a distributed system that translates domains into IP addresses.

### How DNS resolution happens

1. You type `github.com` into the browser
2. The browser checks its **local cache** (does it already know this address?)
3. If not, it asks a **DNS Resolver** (usually your ISP's or `8.8.8.8`)
4. The resolver asks a **Root DNS Server** (which only knows the TLD servers)
5. The root server points to the **TLD server** (for `.com` — Verisign)
6. The TLD server points to the **Authoritative DNS** (where the real `github.com` records are stored)
7. The Authoritative DNS returns the IP: `140.82.121.4`
8. The browser caches the answer and connects to the server

### DNS records

| Type | What it does | Example |
|-----|-----------|---------|
| `A` | Domain → IPv4 | `github.com → 140.82.121.4` |
| `AAAA` | Domain → IPv6 | |
| `CNAME` | Alias to another domain | `www.example.com → example.com` |
| `MX` | Where the email server is | |
| `TXT` | Arbitrary text (SPF, verification) | |

> **Real backend:** When deploying a Django project, you buy a domain and add an `A` record pointing to the IP of your cloud VM.

**Why does a site load faster the second time?** — The DNS answer is cached for the TTL (Time To Live). The repeated query is served straight from the cache.

---

## 4. Ports — apartments in a building

An IP address delivers a packet to the right **computer**. But one computer may run dozens of programs. A port specifies which **program** the traffic is meant for.

```
192.168.1.100:80   ← web server (Nginx)
192.168.1.100:5432 ← PostgreSQL
192.168.1.100:22   ← SSH
192.168.1.100:8000 ← Django runserver
```

### Well-known ports

| Port | Protocol | Usage |
|------|----------|--------------|
| 80 | HTTP | Web (unencrypted) |
| 443 | HTTPS | Web (with TLS) |
| 22 | SSH | Secure access to a server |
| 5432 | PostgreSQL | Database |
| 6379 | Redis | Cache / broker |
| 25 | SMTP | Email |
| 53 | DNS | DNS queries |

> **Real backend:** If you start two Django projects at the same time on port 8000, the second one will print `Address already in use`. The OS cannot bind one port to two processes.

---

## 5. TCP — reliable delivery

TCP (Transmission Control Protocol) provides **guaranteed and ordered** delivery of data.

### How it works

Data is split into **packets** (chunks). Each packet:
- has a sequence number
- may travel along different routes across the Internet
- may arrive out of order

TCP on the receiving side:
- checks the sequence numbers
- requests retransmission of lost packets
- reassembles the packets in the correct order

### TCP Three-Way Handshake

Before sending any data, TCP establishes a connection:

```
Client → Server: SYN         (Hi, can we talk?)
Server → Client: SYN-ACK     (Yes, I'm ready)
Client → Server: ACK         (Great, let's begin)
         [Connection established]
Client → Server: HTTP GET /  (Now we send the data)
```

> **Analogy:** Imagine you are mailing a 300-page book one page at a time. The postal service (IP) may send the pages along different routes. Your friend (TCP) looks at the page numbers, puts the book together in order and asks you to resend page 47 if it got lost.

### UDP — a fast, unreliable alternative

UDP (User Datagram Protocol) sends packets without acknowledgment. It is used where losing a packet is better than a delay: video calls, online games, DNS.

---

## 6. HTTP — the language of the web

HTTP (HyperText Transfer Protocol) is a text-based application-layer protocol. It describes the **format** of requests and responses between the browser and the server.

### Structure of an HTTP request

```
PATCH /api/users/42/ HTTP/1.1
Host: example.com
Accept: application/json
Authorization: Bearer eyJhbGc...
Content-Type: application/json

{"name": "Alice"}
```

| Part | What it is |
|---------|-------|
| `PATCH` | Method (action) |
| `/api/users/42/` | Path (resource) |
| `HTTP/1.1` | Protocol version |
| `Host`, `Accept`... | Headers (metadata) |
| `{"name": "Alice"}` | Body (only for POST/PUT/PATCH) |

### HTTP methods

| Method | Purpose | Idempotent |
|-------|-------------|---------------|
| `GET` | Retrieve a resource | Yes |
| `POST` | Create a resource | No |
| `PUT` | Replace completely | Yes |
| `PATCH` | Partially update | No |
| `DELETE` | Delete | Yes |

### Structure of an HTTP response

```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 48
Set-Cookie: sessionid=abc123; HttpOnly

{"id": 42, "name": "Alice", "email": "alice@mail.com"}
```

### Status codes

| Range | Meaning | Examples |
|----------|----------|---------|
| 2xx | Success | `200 OK`, `201 Created`, `204 No Content` |
| 3xx | Redirect | `301 Moved Permanently`, `302 Found` |
| 4xx | Client error | `400 Bad Request`, `401 Unauthorized`, `404 Not Found` |
| 5xx | Server error | `500 Internal Server Error`, `503 Service Unavailable` |

---

## 7. HTTPS and TLS

HTTPS = HTTP + TLS (Transport Layer Security). TLS encrypts the data between the client and the server.

### Why is it needed?

Without HTTPS, any node between the client and the server (a router in a café, your ISP) can read your request — including passwords and tokens.

### TLS Handshake (simplified)

1. Client: *"I support TLS 1.3, here is my random key"*
2. Server: *"OK, here is my SSL certificate and public key"*
3. Client: *"I've verified the certificate (signed by a trusted CA). Generating a session key."*
4. Both sides: *"From now on we encrypt everything with the session key"*

> SSL certificates are issued by trusted organizations (Certificate Authorities): Let's Encrypt, DigiCert, etc. Nginx stores the certificate and performs the TLS handshake before the request reaches Python.

---

## 8. Sockets — the foundation of network programming

A socket is a bidirectional connection endpoint between two programs. It is a low-level API provided by the operating system.

### How Python opens a network connection (low level)

```python
import socket

# Server
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('0.0.0.0', 8080))   # Bind to a port
server.listen(5)                  # Wait for connections
conn, addr = server.accept()      # Blocks until a client connects
data = conn.recv(1024)            # Read the data
conn.send(b"HTTP/1.1 200 OK\r\n\r\nHello")
conn.close()
```

```python
# Client
client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client.connect(('127.0.0.1', 8080))
client.send(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
response = client.recv(4096)
```

> Django, Flask, FastAPI — all of them ultimately use exactly this mechanism, just with lots of abstractions on top.

### Unix Domain Sockets

In production, Nginx and uWSGI often communicate through a **Unix socket** (a file in the file system, e.g. `/run/django.sock`) instead of a network socket. This is faster because it does not go through the network stack.

---

## 9. A stateless protocol and session state

HTTP is **stateless** by nature — it has no memory. Every request is completely independent. The server does not remember that you already made a request a second ago.

### Then how does a site know you are logged in?

Through **cookies** and **sessions**:

**The flow:**
1. You send `POST /login/` with your username/password
2. The server checks the data and creates a **session** in the database with a unique ID
3. The server sends a response with the header `Set-Cookie: sessionid=abc123`
4. The browser stores the cookie and **automatically** adds it to every subsequent request: `Cookie: sessionid=abc123`
5. The server reads `sessionid`, finds the session in the DB and knows who you are

### Cookie attributes

| Attribute | What it does |
|---------|-----------|
| `HttpOnly` | JavaScript cannot read it (protection against XSS) |
| `Secure` | Sent only over HTTPS |
| `SameSite` | Protection against CSRF |
| `Expires` | When the cookie becomes invalid |

---

## 10. Client/Server architecture

In the classic architecture there are two roles:

| Role | Who | What it does |
|------|-----|-----------|
| **Client** | Browser, mobile app | Initiates the request, displays the result |
| **Server** | Nginx, Django, PostgreSQL | Passively waits, processes, responds |

### The full request lifecycle (from URL to HTML)

```
1. The user enters https://shop.example.com/products/
2. DNS: shop.example.com → 203.0.113.10
3. TCP Handshake with the server 203.0.113.10:443
4. TLS Handshake (encryption)
5. HTTP GET /products/ is sent
6. Nginx receives the request
7. Nginx forwards it to uWSGI over a Unix socket
8. uWSGI turns HTTP into a Python dict (WSGI environ)
9. Middleware: SecurityMiddleware → SessionMiddleware → AuthMiddleware
10. Django URL Dispatcher: /products/ → ProductListView
11. View: Product.objects.all() → SQL SELECT → Python objects
12. Template: rendering HTML with the data
13. HttpResponse 200 OK with HTML
14. Nginx sends the response to the client
15. The browser parses the HTML, loads CSS/JS
```

---

## 11. REST API architecture

REST (Representational State Transfer) is an architectural style for designing APIs.

### REST principles

| Principle | Explanation |
|---------|-----------|
| **Stateless** | Every request contains all the information it needs |
| **Resource-based** | The URL describes a resource (`/users/`, `/products/42/`) |
| **HTTP Verbs** | The action is expressed by the method (GET, POST, PUT, DELETE) |
| **Uniform Interface** | Standard behavior for all resources |

### REST URL conventions

```
GET    /api/products/         → list all products
POST   /api/products/         → create a product
GET    /api/products/42/      → get product #42
PUT    /api/products/42/      → fully update product #42
PATCH  /api/products/42/      → partially update product #42
DELETE /api/products/42/      → delete product #42
```

---

## 12. How the backend receives a request — under the hood

What happens at the OS level when an HTTP request arrives:

```
1. The NIC (network card) receives an electrical signal → turns it into bytes
2. OS: the TCP/IP stack processes the packets → assembles the HTTP request
3. OS: looks at which program is listening on port 80 → it's Nginx
4. OS: copies the data into Nginx's buffer via the recv() system call
5. Nginx: parses the HTTP headers
6. Nginx: looks at the location rules in nginx.conf
7. Nginx: proxy_pass → sends it to unix:/run/django.sock
8. uWSGI: reads from the socket → parses HTTP → builds the WSGI environ dict
9. uWSGI: calls the Django application(environ, start_response)
10. Django: the rest is Python
```

> **Key insight:** The whole path is a series of byte transformations between different programs via OS buffers. The Python code is the last link in the chain.

---

## Common mistakes — the network layer

### 1. Blocking requests in synchronous code
```python
# BAD: blocks the whole process for the duration of the HTTP request
import requests

def my_view(request):
    response = requests.get("https://slow-api.example.com/data")  # waits 5 sec
    return JsonResponse(response.json())
```
```python
# GOOD: async view (Django 3.1+)
import httpx

async def my_view(request):
    async with httpx.AsyncClient() as client:
        response = await client.get("https://slow-api.example.com/data")
    return JsonResponse(response.json())
```

### 2. Misunderstanding statelessness

Do not keep state in Python global variables — with several workers, each one has its own memory. State must live in the DB or Redis.

### 3. No HTTPS

Never deploy to production without TLS. Session cookies, passwords, tokens — everything travels as plain text.

---

## Self-check questions

1. What happens if the DNS server is unavailable? Will the request reach the site?
2. Why is a TCP handshake needed if you could just send the data right away?
3. Why are `127.0.0.1` and `localhost` the same thing?
4. How does the server know you are logged in if HTTP is stateless?
5. Why is `python manage.py runserver` not suitable for production?
