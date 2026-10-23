# Request Flows

Наскрізні сценарії: від браузера до БД і назад.

---

## Створення нотатки (HTTP POST)

```mermaid
sequenceDiagram
    participant B as Browser
    participant V as views.py
    participant F as NoteForm
    participant Sv as services.py
    participant DB as PostgreSQL

    B->>V: GET /notes/new/
    V-->>B: порожня форма (NoteForm)

    B->>V: POST /notes/new/ (title, content, ...)
    V->>F: NoteForm(data=request.POST, user=request.user)
    F-->>V: cleaned_data або errors
    alt form valid
        V->>Sv: create_note(user, cleaned_data)
        Sv->>DB: INSERT INTO note ...
        V-->>B: redirect /notes/<pk>/
    else form invalid
        V-->>B: форма з помилками
    end
```

---

## Перевірка доступу до об'єкта (IDOR захист)

```mermaid
flowchart TD
    pk["URL pk"] --> Filter["selectors.get_note(user, pk)"]
    Filter --> Q["Q(user=user) | Q(group__in=user_groups)"]
    Q --> Found{"знайдено?"}
    Found -->|так| Render["render деталь / форму редагування"]
    Found -->|ні| 404["Http404"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class pk,Filter,Q step;
    class Found decision;
    class Render success;
    class 404 error;
```

Mutable операції (edit/delete) — тільки власник (`Q(user=user)`).
Read — власник **або** члени групи (`Q(group__in=user_groups)`).

---

## Вхід / сесія

```mermaid
sequenceDiagram
    participant B as Browser
    participant V as Django auth views
    participant DB as PostgreSQL
    participant S as Session store

    B->>V: POST /accounts/login/ (username, password)
    V->>DB: SELECT User WHERE username=... (authenticate)
    DB-->>V: User object або None
    alt credentials valid
        V->>S: create session (session_key → DB або cache)
        V-->>B: redirect / (Set-Cookie: sessionid=...)
    else invalid
        V-->>B: форма з помилкою
    end
```

---

## WebSocket — підключення до чату

```mermaid
sequenceDiagram
    participant B as Browser (JS)
    participant N as Nginx
    participant C as GroupChatConsumer
    participant DB as PostgreSQL
    participant RL as Redis (channel layer)

    B->>N: WS Upgrade ws://host/ws/groups/42/chat/
    N->>C: проксі (Upgrade + Connection headers)
    C->>C: scope["user"] ← AuthMiddlewareStack (session cookie)
    C->>DB: перевірка group membership (database_sync_to_async)
    alt authenticated + member
        C->>DB: SELECT останні 50 ChatMessage
        C-->>B: history JSON
        C->>RL: group_add(room_group_name, channel_name)
        C-->>B: WebSocket accepted
    else anonymous або не member
        C-->>B: close(4003 або 4004)
    end
```

---

## WebSocket — надсилання повідомлення

```mermaid
sequenceDiagram
    participant B1 as Browser (sender)
    participant C1 as Consumer (sender)
    participant RL as Redis
    participant C2 as Consumer (receiver)
    participant B2 as Browser (receiver)
    participant DB as PostgreSQL

    B1->>C1: {"content": "Привіт!"}
    C1->>DB: ChatMessage.objects.create(...) via database_sync_to_async
    C1->>RL: group_send(room_group_name, {type: "chat_message", ...})
    RL->>C1: chat_message event
    RL->>C2: chat_message event
    C1-->>B1: {"type": "message", "content": "Привіт!", "author": "..."}
    C2-->>B2: {"type": "message", "content": "Привіт!", "author": "..."}
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
      → manage.py seed_demo_data --force  (якщо SEED_DEMO_DATA=1)
      → exec python -m uvicorn notes_project.asgi:application --host 0.0.0.0 --port 8001 --reload
  ↓ nginx: forward :80 → web:8001
  ↓ celery-worker, celery-beat (після healthcheck db і redis)
  ↓ ngrok (dev тунель, profile tunnel)
  ↓ selenium, selenium-tests (E2E тести, profile test)
```
