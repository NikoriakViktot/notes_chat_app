# Network Foundation — Mermaid Diagrams

> All diagrams in this file visualize concepts from [`network_foundation_full.md`](network_foundation_full.md).
> They render in any Markdown viewer with Mermaid support (GitHub, Obsidian, VSCode).

---

## 1. Overview of the Internet — from the browser to the server

```mermaid
graph LR
    A[🖥️ Browser] -->|DNS query| B[DNS Resolver]
    B -->|IP address| A
    A -->|TCP + HTTP| C[🌐 Internet]
    C -->|packets| D[Router ISP]
    D -->|routing| E[Router Datacenter]
    E -->|packets| F[🖧 Web server]
    F -->|HTTP response| C
    C -->|response| A

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class A,C,D,E step;
    class B decision;
    class F success;
```

---

## 2. The full request route: Client → Router → ISP → Server

```mermaid
graph TD
    Browser["Browser<br>192.168.1.10"] -->|HTTP GET /| HomeRouter["Home router<br>NAT: replaces the IP"]
    HomeRouter -->|Client's public IP| ISP["ISP<br>Internet Provider"]
    ISP -->|BGP routing| InternetCore["Backbone nodes<br>Internet backbone"]
    InternetCore -->|To the target AS| DatacenterRouter[Datacenter router]
    DatacenterRouter -->|To the server| LB["Load Balancer<br>optional"]
    LB -->|Round-robin| Server["🖧 Target server<br>203.0.113.10:443"]
    Server -->|HTTP Response| DatacenterRouter
    DatacenterRouter -->|Return route| Browser

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,ISP,InternetCore,DatacenterRouter,LB step;
    class HomeRouter warning;
    class Server success;
```

---

## 3. DNS resolution — step by step

```mermaid
sequenceDiagram
    participant Browser as Browser
    participant Cache as Local OS cache
    participant Resolver as DNS Resolver<br>(ISP / 8.8.8.8)
    participant Root as Root DNS Server
    participant TLD as TLD Server (.com)
    participant Auth as Authoritative DNS<br>(github.com)

    Browser->>Cache: github.com → IP?
    Cache-->>Browser: None (cache is empty)
    Browser->>Resolver: github.com → IP?
    Resolver->>Root: github.com → IP?
    Root-->>Resolver: Ask the TLD for .com
    Resolver->>TLD: github.com → IP?
    TLD-->>Resolver: Ask ns1.p16.dynect.net
    Resolver->>Auth: github.com → IP?
    Auth-->>Resolver: 140.82.121.4 (TTL=60s)
    Resolver-->>Browser: 140.82.121.4
    Note over Browser,Cache: The browser caches the result for TTL seconds
    Browser->>Browser: Connect to 140.82.121.4:443
```

---

## 4. TCP — Three-Way Handshake + HTTP + Teardown

```mermaid
sequenceDiagram
    participant C as Client (Browser)
    participant S as Server (Nginx)

    Note over C,S: Phase 1 — TCP Three-Way Handshake
    C->>S: SYN (seq=100)
    S-->>C: SYN-ACK (seq=200, ack=101)
    C->>S: ACK (ack=201)
    Note over C,S: Connection established ✓

    Note over C,S: Phase 2 — HTTP exchange
    C->>S: HTTP GET /products/ (headers + body)
    Note over S: Nginx processes it, Django generates the response
    S-->>C: HTTP 200 OK + HTML (Content-Length: 4200)

    Note over C,S: Phase 3 — Closing the connection
    C->>S: FIN
    S-->>C: ACK
    S->>C: FIN
    C-->>S: ACK
    Note over C,S: Connection closed
```

---

## 5. HTTP Request/Response Lifecycle

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant B as Browser
    participant DNS as DNS
    participant S as Server

    U->>B: Enters https://shop.com/cart/
    B->>DNS: shop.com → IP?
    DNS-->>B: 93.184.216.34
    B->>S: TCP + TLS Handshake
    Note over B,S: Encrypted channel established
    B->>S: GET /cart/ HTTP/1.1<br>Host: shop.com · Cookie: sessionid=abc
    Note over S: Server logic: reads sessionid, finds the user,<br>queries the DB, renders HTML
    S-->>B: HTTP/1.1 200 OK · Content-Type: text/html<br>#lt;html#gt;...#lt;/html#gt;
    B->>U: Displays the cart page
```

---

## 6. HTTPS / TLS Handshake

```mermaid
sequenceDiagram
    participant C as Client (Browser)
    participant S as Server (Nginx + SSL cert)
    participant CA as Local store of<br>trusted CAs (OS/browser)

    Note over C,S: The TCP connection is already established (TLS 1.2 with RSA key exchange)
    C->>S: ClientHello (TLS version, cipher suites, random_C)
    S-->>C: ServerHello + SSL Certificate (signed by a CA)
    C->>CA: Verifying the certificate chain (locally, no request to the CA)
    CA-->>C: Certificate is valid ✓
    C->>S: Pre-master secret (encrypted with the server's public key)
    Note over C,S: Both sides generate the session key
    C->>S: Finished (the first encrypted packet)
    S-->>C: Finished (confirmation)
    Note over C,S: All subsequent data is encrypted with the session key
    C->>S: HTTP GET / (now encrypted)
    S-->>C: HTTP 200 OK + HTML (encrypted)
```

---

## 7. Browser → Backend → Database (the full stack)

```mermaid
graph TD
    Browser[🖥️ Browser] -->|HTTPS request| Nginx["Nginx<br>Reverse Proxy :443"]
    Nginx -->|Static file?| Static[("📁 File system<br>/static/ /media/")]
    Static -->|PNG CSS JS| Nginx
    Nginx -->|"Dynamic request<br>Unix Socket"| WSGI["uWSGI / Gunicorn<br>Process manager"]
    WSGI -->|WSGI environ dict| Django[🐍 Django Application]
    Django -->|"SQL query<br>ORM"| PG[(PostgreSQL)]
    PG -->|Data rows| Django
    Django -->|HttpResponse HTML/JSON| WSGI
    WSGI -->|HTTP bytes| Nginx
    Nginx -->|HTTPS response| Browser

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class Browser,Static,WSGI,PG step;
    class Nginx decision;
    class Django success;
```

---

## 8. Socket communication

```mermaid
graph LR
    subgraph Server
        S_App["Program<br>Django/FastAPI"] -->|"socket.bind<br>port 8000"| S_Socket["Server Socket<br>0.0.0.0:8000"]
        S_Socket -->|socket.listen| Queue[Connection queue]
        Queue -->|socket.accept| Conn["Active connection<br>Conn Socket"]
        Conn -->|recv / send| S_App
    end

    subgraph Client
        C_App["Browser /<br>HTTP client"] -->|"socket.connect<br>93.184.1.1:8000"| C_Socket["Client Socket<br>ephemeral port"]
        C_Socket -->|send / recv| C_App
    end

    Conn <-->|TCP bytes| C_Socket

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class S_App,Queue,C_App step;
    class S_Socket,C_Socket warning;
    class Conn success;
```

---

## 9. REST API Flow — the full cycle

```mermaid
sequenceDiagram
    participant App as 📱 Mobile app
    participant Auth as Auth Middleware
    participant Router as URL Router
    participant View as API View
    participant DB as Database

    App->>Auth: POST /api/login/ {"username": "...", "password": "..."}
    Auth-->>App: 200 OK {"token": "eyJhbGc..."}

    App->>Auth: GET /api/products/ + Header: Authorization: Bearer eyJhbGc...
    Note over Auth: JWT token verification
    Auth->>Router: Request + request.user (authenticated)
    Router->>View: ProductListView.get(request)
    View->>DB: SELECT * FROM products WHERE active=true
    DB-->>View: 150 product rows
    View-->>Auth: JsonResponse([...], status=200)
    Auth-->>App: 200 OK [{"id":1, "name":"..."}, ...]

    App->>Auth: POST /api/cart/items/ {"product_id": 5, "qty": 2}
    Auth->>Router: CartItemCreateView.post(request)
    Router->>View: Validation + saving
    View->>DB: INSERT INTO cart_items ...
    DB-->>View: OK, id=42
    View-->>Auth: JsonResponse({"id": 42}, status=201)
    Auth-->>App: 201 Created {"id": 42}
```

---

## 10. Client-server architecture — a conceptual overview

```mermaid
graph TB
    subgraph Clients
        Browser[🖥️ Web browser]
        Mobile[📱 Mobile app]
        CLI[⌨️ CLI / curl]
    end

    subgraph Internet[Internet]
        DNS_S[DNS Server]
        Router_I[Routers]
    end

    subgraph Server[Server infrastructure]
        Nginx_S[Nginx :80/:443]
        App["Python Backend<br>Django / FastAPI"]
        DB_S[(PostgreSQL)]
        Cache_S[(Redis Cache)]
        Worker[Celery Workers]
    end

    Browser -->|HTTPS| Nginx_S
    Mobile -->|HTTPS| Nginx_S
    CLI -->|HTTP| Nginx_S
    
    Browser <-->|DNS lookup| DNS_S
    
    Nginx_S --> App
    App <--> DB_S
    App <--> Cache_S
    App -->|Task queue| Worker
    Worker <--> DB_S

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Browser,Mobile,CLI,DNS_S,Router_I,DB_S,Cache_S,Worker step;
    class Nginx_S warning;
    class App success;
```

---

## 11. Packets and IP routing

```mermaid
flowchart LR

    subgraph PACKET["TCP/IP Packet"]
        direction TB

        ETH["Ethernet Header<br>MAC addresses"]

        IP["IP Header<br>src/dst IP"]

        TCP["TCP Header<br>ports + sequence"]

        DATA["Payload<br>HTTP data"]
    end

    Browser["🌍 Browser"]

    R1["Home Router"]

    ISP["ISP Router"]

    Core["Core Router"]

    Alt["Alternative Route"]

    Server["🖥️ Server"]

    Browser --> R1

    R1 --> ISP

    ISP --> Core

    ISP --> Alt

    Core --> Server

    Alt --> Server

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class ETH,IP,TCP,DATA step;
    class R1,ISP,Core,Alt warning;
    class Browser,Server success;
```

---

## Protocol reference table

```mermaid
graph TD
    subgraph OSI [Network layers simplified]
        L7["L7 Application<br>HTTP HTTPS DNS FTP SMTP"]
        L4["L4 Transport<br>TCP UDP"]
        L3["L3 Network<br>IP ICMP"]
        L2["L2 Data link<br>Ethernet WiFi MAC"]
        L1["L1 Physical<br>Wires Optics Radio"]
    end
    L7 --> L4 --> L3 --> L2 --> L1

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class L7 success;
    class L4 warning;
    class L3,L2,L1 step;
```
