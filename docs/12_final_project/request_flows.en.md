# Request Flows

End-to-end scenarios: from the browser to the database and back.

---

## Creating a note (HTTP POST)

```mermaid
sequenceDiagram
    participant B as Browser
    participant V as views.py
    participant F as NoteForm
    participant Sv as services.py
    participant DB as PostgreSQL

    B->>V: GET /notes/new/
    V-->>B: empty form (NoteForm)

    B->>V: POST /notes/new/ (title, content, ...)
    V->>F: NoteForm(data=request.POST, user=request.user)
    F-->>V: cleaned_data or errors
    alt form valid
        V->>Sv: create_note(user, cleaned_data)
        Sv->>DB: INSERT INTO note ...
        V-->>B: redirect /notes/<pk>/
    else form invalid
        V-->>B: form with errors
    end
```

---

## Checking access to an object (IDOR protection)

```mermaid
flowchart TD
    pk["URL pk"] --> Filter["selectors.get_note(user, pk)"]
    Filter --> Q["Q(user=user) | Q(group__in=user_groups)"]
    Q --> Found{"found?"}
    Found -->|yes| Render["render detail / edit form"]
    Found -->|no| 404["Http404"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class pk,Filter,Q step;
    class Found decision;
    class Render success;
    class 404 error;
```

Mutating operations (edit/delete) are allowed only for the owner (`Q(user=user)`).
Read access is for the owner **or** group members (`Q(group__in=user_groups)`).

---

## Login / session

```mermaid
sequenceDiagram
    participant B as Browser
    participant V as Django auth views
    participant DB as PostgreSQL
    participant S as Session store

    B->>V: POST /accounts/login/ (username, password)
    V->>DB: SELECT User WHERE username=... (authenticate)
    DB-->>V: User object or None
    alt credentials valid
        V->>S: create session (session_key → DB or cache)
        V-->>B: redirect / (Set-Cookie: sessionid=...)
    else invalid
        V-->>B: form with an error
    end
```

---

## WebSocket: connecting to the chat

```mermaid
sequenceDiagram
    participant B as Browser (JS)
    participant N as Nginx
    participant C as GroupChatConsumer
    participant DB as PostgreSQL
    participant RL as Redis (channel layer)

    B->>N: WS Upgrade ws://host/ws/groups/42/chat/
    N->>C: proxy (Upgrade + Connection headers)
    C->>C: scope["user"] ← AuthMiddlewareStack (session cookie)
    C->>DB: group membership check (database_sync_to_async)
    alt authenticated + member
        C->>DB: SELECT the latest 50 ChatMessage
        C-->>B: history JSON
        C->>RL: group_add(room_group_name, channel_name)
        C-->>B: WebSocket accepted
    else anonymous or not a member
        C-->>B: close(4003 or 4004)
    end
```

---

## WebSocket: sending a message

```mermaid
sequenceDiagram
    participant B1 as Browser (sender)
    participant C1 as Consumer (sender)
    participant RL as Redis
    participant C2 as Consumer (receiver)
    participant B2 as Browser (receiver)
    participant DB as PostgreSQL

    B1->>C1: {"content": "Hello!"}
    C1->>DB: ChatMessage.objects.create(...) via database_sync_to_async
    C1->>RL: group_send(room_group_name, {type: "chat_message", ...})
    RL->>C1: chat_message event
    RL->>C2: chat_message event
    C1-->>B1: {"type": "message", "content": "Hello!", "author": "..."}
    C2-->>B2: {"type": "message", "content": "Hello!", "author": "..."}
```

---

## Docker startup

```text
Docker Compose up
  ↓ db healthcheck (pg_isready)
  ↓ redis healthcheck
  ↓ web: entrypoint.sh
      → manage.py migrate
      → manage.py collectstatic
      → manage.py seed_demo_data --force  (if SEED_DEMO_DATA=1)
      → exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --reload
  ↓ nginx: forward :80 → web:8001
  ↓ celery-worker, celery-beat (after the db and redis healthchecks)
  ↓ ngrok (dev tunnel, profile tunnel)
  ↓ selenium, selenium-tests (E2E tests, profile test)
```
