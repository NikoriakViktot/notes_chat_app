# Architecture

Цей документ містить наскрізні карти, які зв'язують теорію з фінальним кодом.

## HTTP request lifecycle

```mermaid
flowchart TD
    Browser["Browser"] --> DNS["DNS"]
    DNS --> TCP["TCP/TLS"]
    TCP --> Server["Development server або reverse proxy"]
    Server --> Middleware["Django middleware"]
    Middleware --> URLDispatcher["URL dispatcher"]
    URLDispatcher --> View["View"]
    View --> Form["Form validation"]
    View --> Selector["Selector"]
    View --> Service["Service"]
    Selector --> ORM["ORM"]
    Service --> ORM
    ORM --> DB["PostgreSQL"]
    View --> Template["Template"]
    Template --> Response["HTML response"]
    Response --> Browser

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class Browser,DNS,TCP,Server,Middleware,URLDispatcher,View,Form,Selector,Service,ORM,DB,Template step;
    class Response success;
```

## Django MVT

```mermaid
flowchart LR
    URL["URL pattern"] --> View["View"]
    View --> Model["Model/ORM"]
    View --> Template["Template"]
    Template --> Browser["Browser"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class URL,View,Model,Template step;
    class Browser success;
```

## CRUD flow

```mermaid
sequenceDiagram
    participant B as Browser
    participant V as View
    participant F as Form
    participant S as Service
    participant D as Database
    B->>V: GET form
    V-->>B: render form
    B->>V: POST data
    V->>F: validate
    F-->>V: cleaned_data
    V->>S: create/update/delete
    S->>D: transaction
    V-->>B: redirect
```

## Authentication flow

```mermaid
sequenceDiagram
    participant B as Browser
    participant A as Auth view
    participant S as Session store
    participant M as AuthenticationMiddleware
    B->>A: username/password
    A->>S: create session
    A-->>B: Set-Cookie sessionid
    B->>M: next request with cookie
    M->>S: load session
    M-->>B: request.user available to view
```

## Object permission flow

```mermaid
flowchart TD
    PK["URL pk"] --> User["authenticated user"]
    User --> ScopedQS["scoped queryset"]
    ScopedQS --> Lookup["object lookup"]
    Lookup --> Allowed{"found?"}
    Allowed -->|yes| View["render or mutate"]
    Allowed -->|no| Deny["404 або PermissionDenied"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class PK,User,ScopedQS,Lookup step;
    class Allowed decision;
    class View success;
    class Deny error;
```

## Testing pyramid

```mermaid
flowchart TD
    E2E["E2E: Selenium"] --> Integration["Integration: Django TestClient"]
    Integration --> Unit["Unit: models, services, forms"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Integration step;
    class Unit success;
    class E2E warning;
```

## Async і WebSocket flow

```mermaid
sequenceDiagram
    participant JS as Browser JavaScript
    participant ASGI as ASGI application
    participant PTR as ProtocolTypeRouter
    participant Auth as AuthMiddlewareStack
    participant Router as URLRouter
    participant C as Consumer
    participant L as Channel layer
    JS->>ASGI: WebSocket handshake
    ASGI->>PTR: protocol=websocket
    PTR->>Auth: load user from session
    Auth->>Router: route /ws/groups/pk/chat/
    Router->>C: GroupChatConsumer.connect
    C->>L: group_add
    JS->>C: send message
    C->>L: group_send
    L->>C: deliver event to consumers
    C->>JS: message frame
```

## Production deployment

```mermaid
flowchart LR
    Internet["Internet"] --> DNS["DNS"]
    DNS --> HTTPS["HTTPS"]
    HTTPS --> Nginx["Nginx recommended"]
    Nginx --> App["Gunicorn/Uvicorn recommended"]
    App --> Django["Django"]
    Django --> Postgres["PostgreSQL"]
    Django --> Redis["Redis for Channels"]
    Nginx --> Static["Static files"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class Internet,DNS,HTTPS,Django,Postgres,Redis,Static step;
    class Nginx,App success;
```

Компоненти Nginx, Gunicorn/Uvicorn, PostgreSQL і Redis є рекомендованим production stack. Поточний Docker setup ще потребує виправлення перед використанням як готового deployment.
