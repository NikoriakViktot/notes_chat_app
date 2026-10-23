# Django ORM та БД — Mermaid-схеми

> Всі діаграми — візуалізація концепцій з усіх файлів документації.
> Використовуй після читання теорії щоб закріпити розуміння через схеми.
> Порядок: ER → Зв'язки → ORM Flow → Query Lifecycle → Transactions → Architecture

---

> 🔬 **Хочеш побачити ці схеми у дії?**
> [`docs/reference/legacy_source/orm_laboratory_reference.md`](../reference/legacy_source/orm_laboratory_reference.md) —
> кожна mermaid-діаграма має відповідний code cell де виконується реальний SQL.
>
> ⚠️ Сам notebook не входить до цього репозиторію: файл за посиланням лише пояснює це. Назви розділів у таблиці нижче — орієнтири з оригінальної структури ноутбука, а не якорі. Ці ж запити можна виконати самостійно в `python manage.py shell` або в [ORM-лабораторії](../labs/orm_lab.md).
>
> | Mermaid-схема в цьому файлі | Розділ ноутбука |
> |-----------------------------|-----------------|
> | ER-діаграма / схема таблиць | `## 0. 🧱 Що таке object в Django ORM?` |
> | ORM → SQL Lifecycle | `## 1. 🧠 ORM Mental Model` |
> | Lazy Evaluation flow | `## 1. 🧠 ORM Mental Model` |
> | N+1 vs select_related | `## 8. ⚡ N+1 Problem & Optimization` |
> | select_related vs prefetch_related | `## 8. ⚡ N+1 Problem & Optimization` |
> | transaction.atomic() SQL lifecycle | `## 13. 🔒 Транзакції` |
> | Services/Selectors архітектура | `README.md` → секція `03 · APPLICATION LAYERS` |



## 1. ER-діаграма — Notes Platform (повний проект)

> **Що показує:** Всі таблиці проекту `notes_chat_app` з усіма зв'язками.
> `||--o|` = 1:1, `||--o{` = 1:N, `}o--o{` = M:N.
> FK завжди на стороні "багатьох" (Many side).

```mermaid
erDiagram
    USER ||--o| USER_PROFILE : "1:1 OneToOneField"
    USER ||--o{ NOTEBOOK : "1:N ForeignKey"
    USER ||--o{ NOTE : "1:N ForeignKey"
    USER ||--o{ TODO_LIST : "1:N ForeignKey"
    USER ||--o{ SHOPPING_LIST : "1:N ForeignKey"
    USER ||--o{ TAG : "1:N ForeignKey"

    NOTEBOOK ||--o{ NOTE : "1:N SET_NULL"
    NOTE }o--o{ TAG : "M:N junction table"
    NOTE ||--o{ REMINDER : "1:N CASCADE"

    TODO_LIST ||--o{ TODO_ITEM : "1:N CASCADE"
    SHOPPING_LIST ||--o{ SHOP_ITEM : "1:N CASCADE"

    USER {
        bigint id PK
        string username
        string email
        string password_hash
    }
    USER_PROFILE {
        bigint id PK
        bigint user_id FK "UNIQUE → 1:1"
        string display_name
        string timezone
    }
    NOTEBOOK {
        bigint id PK
        bigint user_id FK
        string title
        string color
        boolean is_default
    }
    NOTE {
        bigint id PK
        bigint user_id FK
        bigint notebook_id FK "nullable"
        string title
        text content
        int priority
        boolean is_pinned
        boolean is_archived
        timestamp updated_at
    }
    TAG {
        bigint id PK
        bigint user_id FK
        string name
        string color
    }
    NOTE_TAG_JUNCTION {
        bigint note_id FK
        bigint tag_id FK
    }
    REMINDER {
        bigint id PK
        bigint note_id FK
        timestamp remind_at
        boolean is_sent
        string repeat_pattern
    }
    TODO_LIST {
        bigint id PK
        bigint user_id FK
        string title
        boolean is_completed
    }
    TODO_ITEM {
        bigint id PK
        bigint todo_list_id FK
        string text
        boolean is_done
        int order_position
        date due_date
    }
    SHOPPING_LIST {
        bigint id PK
        bigint user_id FK
        string title
        string store_name
    }
    SHOP_ITEM {
        bigint id PK
        bigint shopping_list_id FK
        string name
        decimal quantity
        string unit
        boolean is_purchased
        decimal estimated_price
    }
```

---

## 2. Де живе FK — правило "Many side"

> **Що показує:** Наочно де записується Foreign Key при 1:N та M:N зв'язках.
> FK завжди в таблиці "Many" (не в "One"!).

```mermaid
graph LR
    subgraph "1:1 — OneToOneField"
        U1[User id=5] <-->|user_id FK + UNIQUE| UP1[UserProfile user_id=5]
        N1["FK в UserProfile<br>(FK + UNIQUE = 1:1)"]
    end

    subgraph "1:N — ForeignKey"
        NB[Notebook id=1] -->|"contains"| NO1[Note notebook_id=1]
        NB --> NO2[Note notebook_id=1]
        NB --> NO3[Note notebook_id=1]
        N2["FK в Note<br>(сторона Many)"]
    end

    subgraph "M:N — ManyToManyField"
        N[Note id=1] -->|through| JT["note_tags<br>(note_id=1, tag_id=10), (note_id=1, tag_id=11)"]
        JT -->|"tagged"| T1[Tag id=10]
        JT --> T2[Tag id=11]
        N3["Junction table<br>(автоматично Django)"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class U1,UP1,NB,NO1,NO2,NO3,N,JT,T1,T2 step;
    class N1,N2,N3 warning;
```

---

## 3. ORM → SQL — Lifecycle запиту

> **Що показує:** Повний шлях від Python коду до SQL і назад.
> Ключовий момент: QuerySet ЛІНИВИЙ — SQL виконується тільки при evaluation.

```mermaid
graph TD

    A["Python QuerySet:<br>Note.objects.filter(user=alice)"]

    A2[".select_related(notebook)<br>.prefetch_related(tags)"]

    A3[".order_by(updated_at DESC)"]

    B["QuerySet object created"]

    C{"Evaluation triggered?"}

    D["SQLCompiler.as_sql()"]

    E["SQL #1: SELECT notes + notebooks<br>JOIN notebook table WHERE user_id=5"]

    F["SQL #2: Prefetch tags<br>WHERE note_id IN (...)"]

    G["psycopg2<br>TCP connection → PostgreSQL"]

    H["ModelIterable<br>Create Note objects"]

    I["Related objects loaded:<br>notebook cached, tags prefetched"]

    A --> A2

    A2 --> A3

    A3 --> B

    B --> C

    C -->|"ні"| B

    C -->|"так"| D

    D --> E

    E --> F

    F --> G

    G --> H

    H --> I

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class A,A2,A3,B,D,E,F,G,H step;
    class C decision;
    class I success;
```

---

## 4. Lazy Evaluation — коли виконується SQL

> **Що показує:** QuerySet методи що НЕ виконують SQL (повертають QuerySet)
> vs методи що ВИКОНУЮТЬ SQL (evaluation triggers).

```mermaid
graph LR
    subgraph "НЕ виконують SQL (lazy)"
        L1[".filter()"] --> QS[QuerySet]
        L2[".exclude()"] --> QS
        L3[".order_by()"] --> QS
        L4[".select_related()"] --> QS
        L5[".prefetch_related()"] --> QS
        L6[".annotate()"] --> QS
        L7[".values()"] --> QS
        QS -.->|"можна ланцюжити скільки завгодно"| QS
    end

    subgraph "ВИКОНУЮТЬ SQL (evaluation)"
        QS --> E1["list(qs)"]
        QS --> E2["for note in qs"]
        QS --> E3["qs[0], qs[:10]"]
        QS --> E4["qs.first(), qs.last()"]
        QS --> E5["qs.count()"]
        QS --> E6["len(qs)"]
        QS --> E7["bool(qs)"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class L1,L2,L3,L4,L5,L6,L7 step;
    class QS decision;
    class E1,E2,E3,E4,E5,E6,E7 error;
```

---

## 5. N+1 Problem vs select_related

> **Що показує:** Різниця в кількості SQL запитів між N+1 та select_related.
> Без оптимізації: 1 + N запитів. З select_related: 1 запит.

```mermaid
sequenceDiagram
    participant App as Django View
    participant DB as PostgreSQL

    Note over App,DB: ❌ N+1 PROBLEM (100 нотаток)
    App->>DB: SELECT * FROM notes WHERE status='published' LIMIT 100
    DB-->>App: 100 rows (user_id=5,3,7,8,...)
    App->>DB: SELECT * FROM auth_user WHERE id=5
    App->>DB: SELECT * FROM auth_user WHERE id=3
    App->>DB: SELECT * FROM auth_user WHERE id=7
    Note over App,DB: ... ще 97 запитів ...
    Note over App,DB: ВСЬОГО: 101 SQL запит!

    Note over App,DB: ✅ select_related (ЗАВЖДИ 1 запит)
    App->>DB: SELECT n.*, u.*, nb.* FROM notes n LEFT JOIN users u ON n.user_id=u.id LEFT JOIN notebooks nb ON n.notebook_id=nb.id WHERE status='published' LIMIT 100
    DB-->>App: 100 rows (вже з user + notebook даними!)
    Note over App,DB: note.user.username → з кешу 0 SQL!
```

---

## 6. select_related vs prefetch_related — архітектура

> **Що показує:** Механізм кожного методу на рівні SQL.
> select_related = SQL JOIN. prefetch_related = окремий запит + Python join.

```mermaid
graph TD
    subgraph "select_related → SQL JOIN"
        A1["Note.objects.select_related('user', 'notebook')"] --> B1[1 SQL з JOIN]
        B1 --> C1["SELECT n.*, u.*, nb.*<br>FROM notes n"]
        C1 --> C1b["LEFT JOIN users u ON n.user_id=u.id<br>LEFT JOIN notebooks nb ON n.notebook_id=nb.id"]
        C1b --> D1["Всі дані в одному рядку результату"]
        D1 --> E1["✅ Для FK та OneToOne"]
    end

    subgraph "prefetch_related → Python JOIN"
        A2["Note.objects.prefetch_related('tags')"] --> B2[SQL #1: Fetch Notes]
        B2 --> C2["SELECT * FROM notes"]
        A2 --> B3[SQL #2: Fetch Tags]
        B3 --> C3["SELECT t.*, nt.note_id<br>FROM tags t INNER JOIN note_tags nt"]
        C3 --> C3b["WHERE nt.note_id IN (1,2,3,...,100)"]
        C2 --> D2["Python: obj._prefetched_objects_cache<br>заповнюється dict note_id → [tags]"]
        C3b --> D2
        D2 --> E2["✅ Для ManyToMany та reverse FK"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class A1,B1,C1,C1b,D1,A2,B2,C2,B3,C3,C3b,D2 step;
    class E1,E2 success;
```

---

## 7. Migration Lifecycle

> **Що показує:** Повний цикл міграції від зміни моделі до оновленої БД.
> Ключовий факт: `makemigrations` не змінює БД, `migrate` — змінює.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Django as Django ORM
    participant FS as Filesystem
    participant DB as PostgreSQL

    Dev->>Django: Змінити models.py
    Dev->>Django: manage.py makemigrations
    Django->>Django: Порівняти models.py з migration graph
    Django->>FS: Створити 0003_add_field.py
    FS-->>Dev: Файл готовий

    Dev->>Dev: Перевірити файл міграції!
    Dev->>Django: manage.py sqlmigrate app 0003
    Django-->>Dev: Показати SQL без виконання

    Dev->>Django: manage.py migrate
    Django->>DB: ALTER TABLE ADD COLUMN ...
    DB-->>Django: OK
    Django->>DB: INSERT INTO django_migrations (app, name, applied)
    Django-->>Dev: Applied 0003_add_field
```

---

## 8. Migration Dependency Graph

> **Що показує:** Як міграції залежать одна від одної.
> Django виконує в правильному порядку залежностей (DAG).

```mermaid
graph TD
    A["notes_app 0001_initial<br>CREATE TABLE notes"] --> B["notes_app 0002_extended<br>CREATE TABLE notebooks, tags..."]
    A --> C["notes_app 0002_extended<br>also depends on:"]
    D["auth 0001_initial<br>CREATE TABLE auth_user"] --> B
    B --> E["notes_app 0003_add_index<br>CREATE INDEX"]
    B --> F["notes_app 0004_add_word_count<br>ADD COLUMN word_count"]
    E --> G["notes_app 0005_add_constraint<br>ADD CONSTRAINT CHECK"]
    F --> G

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class B,C,E,F step;
    class A,D success;
    class G warning;
```

---

## 9. Query Execution Lifecycle — 8 фаз

> **Що показує:** Що відбувається в PostgreSQL з SQL запитом від парсингу до результату.

```mermaid
graph TD
    A["SQL: SELECT * FROM notes<br>WHERE user_id=5 ORDER BY updated_at DESC"] --> B

    B["1. PARSING: Lexer + Parser<br>Tokenize SQL → Build AST"] --> C

    C["2. SEMANTIC ANALYSIS<br>Перевірити таблиці, права, system catalog lookup"] --> D

    D["3. REWRITER<br>View expansion, rule system application"] --> E

    E["4. PLANNER: Enumerate plans<br>Seq Scan / Index Scan user_id / Index Scan updated_at"] --> F

    F["5. OPTIMIZER: Choose cheapest<br>(based on table statistics)"] --> F2

    F2["cost(Seq Scan)=5000 ← відхилено<br>cost(Index Scan)=23 ← обрано!"] --> G

    G["6. EXECUTION PLAN<br>Index Scan on note_user_updated_idx → Heap fetch"] --> H

    H["7. EXECUTION ENGINE<br>Read index pages → fetch heap tuples → apply remaining filters"] --> I

    I["8. RESULT<br>Rows → psycopg2 cursor → Django ModelIterable → List[Note]"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class A,B,C,D,E,G,H step;
    class I success;
    class F,F2 warning;
```

---

## 10. B-Tree Index — навігація пошуку

> **Що показує:** Як B-Tree індекс знаходить запис за O(log N) замість O(N).
> Кожен рівень = один disk I/O. Глибина: log₂(N) рівнів.

```mermaid
graph TD
    Root["Root Node<br>[250, 500, 750]"] --> B1["Branch<br>[10, 50, 100]"]
    Root --> B2["Branch<br>[260, 300, 400]"]
    Root --> B3["Branch<br>[510, 600, 700]"]
    Root --> B4["Branch<br>[760, 800, 900]"]

    B1 --> L1["Leaf [1,2,3,4,5]<br>TID→heap"]
    B1 --> L2["Leaf [6,7,8,9]<br>TID→heap"]
    B1 --> L3["Leaf [11,12,15]<br>TID→heap"]

    L2 -.->|"двозв'язний список<br>(для range scans)"| L3

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class B1,B2,B3,B4,L1,L3 step;
    class L2 success;
    class Root warning;
```

> **Пошук user_id=7:**
> Root: `7 < 250` → Branch[10,50,100] → `7 < 10` → Leaf[6,7,8,9] → знайдено TID → heap fetch.
> **3-4 disk I/O** для мільярда рядків.

---

## 11. transaction.atomic() — SQL lifecycle

> **Що показує:** Що відбувається в SQL при transaction.atomic() та при exception.

```mermaid
sequenceDiagram
    participant PY as Python (atomic block)
    participant PG as PostgreSQL

    PY->>PG: BEGIN (при вході в atomic())
    PY->>PG: INSERT INTO notes (title, ...) VALUES ('Django', ...)
    PG-->>PY: id=42
    PY->>PG: SAVEPOINT sp_1 (вкладений atomic)
    PY->>PG: INSERT INTO reminders (...) VALUES (...)
    PG-->>PY: id=5

    alt Успіх (без exception):
        PY->>PG: RELEASE SAVEPOINT sp_1
        PY->>PG: COMMIT
        PG-->>PY: OK
        Note over PY,PG: on_commit() callbacks виконуються тут
    else Exception у вкладеному atomic:
        PY->>PG: ROLLBACK TO SAVEPOINT sp_1
        Note over PY,PG: тільки reminder відкатився, note збережена
        PY->>PG: COMMIT (зовнішній успішно)
    else Exception у зовнішньому atomic:
        PY->>PG: ROLLBACK
        Note over PY,PG: ВСЕ відкатилось, on_commit НЕ виконується
    end
```

---

## 12. select_for_update() — Row Locking Timeline

> **Що показує:** Як select_for_update() запобігає race condition при конкурентному доступі.

```mermaid
sequenceDiagram
    participant T1 as Transaction 1 (Alice)
    participant T2 as Transaction 2 (Bob)
    participant PG as PostgreSQL

    T1->>PG: BEGIN
    T1->>PG: SELECT * FROM events WHERE id=1 FOR UPDATE
    PG-->>T1: event(seats=1) ← lock набутий!

    T2->>PG: BEGIN
    T2->>PG: SELECT * FROM events WHERE id=1 FOR UPDATE
    Note over T2,PG: T2 ЧЕКАЄ (рядок заблокований T1)

    T1->>PG: UPDATE events SET seats=0 WHERE id=1
    T1->>PG: INSERT INTO bookings (event_id, user_id) VALUES (1, alice)
    T1->>PG: COMMIT ← lock знімається

    PG-->>T2: event(seats=0) ← T2 отримує lock, бачить seats=0
    T2->>T2: seats=0 → raise ValueError("Немає місць")
    T2->>PG: ROLLBACK
```

---

## 13. Deadlock — взаємне блокування

> **Що показує:** Як виникає deadlock при різному порядку блокування.
> Рішення: завжди блокувати в стабільному порядку (по id ASC).

```mermaid
graph LR
    subgraph "Deadlock ситуація"
        T1A["T1: lock(note_id=1)"] -->|"чекає"| T1B["T1: lock(note_id=2)"]
        T2B["T2: lock(note_id=2)"] -->|"чекає"| T2A["T2: lock(note_id=1)"]
        T1A -.->|"заблокований T2"| T2B
        T2B -.->|"заблокований T1"| T1A
    end

    subgraph "Рішення: стабільний порядок"
        S1["T1 і T2: завжди lock<br>order_by('id') ASC"] --> S2["T1: lock(1) → lock(2)<br>T2: lock(1) ← чекає T1"]
        S2 --> S2b["T2 НЕ бере lock(2) першим!"]
        S2b --> S3["T1 завершує → T2 продовжує<br>Deadlock неможливий!"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class S2 step;
    class S3 success;
    class T1A,T1B,T2A,T2B error;
    class S1,S2b warning;
```

---

## 14. MVCC — Tuple Versioning

> **Що показує:** Як PostgreSQL зберігає кілька версій рядка для MVCC.
> xmin = транзакція що створила, xmax = транзакція що видалила/замінила.

```mermaid
graph TD
    subgraph "Таблиця notes (внутрішньо)"
        T1["Tuple v1: id=42, title='Django'<br>xmin=100, xmax=NULL · видимий: txid >= 100"]
        T2["Tuple v2: id=42, title='Django ORM'<br>xmin=200, xmax=NULL · видимий: txid >= 200"]
        T3["Tuple v1 (мертвий): id=42, title='Django'<br>xmin=100, xmax=200 · видимий: 100 <= txid < 200"]
    end

    TX150["Транзакція txid=150<br>(почалась до UPDATE)"] -->|"бачить"| T3
    TX250["Транзакція txid=250<br>(почалась після UPDATE)"] -->|"бачить"| T2
    VACUUM["VACUUM<br>(прибирає мертві tuple)"] -->|"видаляє"| T3

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class T1,TX150,TX250 step;
    class T2 success;
    class T3 error;
    class VACUUM warning;
```

---

## 15. N+1 vs оптимізовані запити — повна картина

> **Що показує:** Кількість SQL запитів для різних стратегій завантаження 100 нотаток.

```mermaid
graph LR
    subgraph "❌ N+1 (101 запит)"
        Q1["SELECT * FROM notes LIMIT 100"] --> R1["100 рядків"]
        R1 -->|"for note in notes:"| Q2["SELECT * FROM users WHERE id=X<br>× 100 разів"]
    end

    subgraph "✅ select_related (1 запит)"
        Q3["SELECT n.*, u.*, nb.* FROM notes JOIN users JOIN notebooks<br>LIMIT 100"] --> R3["100 рядків (з user+notebook)"]
    end

    subgraph "✅ prefetch_related (2 запити)"
        Q4["SELECT * FROM notes LIMIT 100"] --> R4["100 рядків"]
        Q5["SELECT t.*, nt.note_id FROM tags INNER JOIN note_tags<br>WHERE note_id IN (1..100)"] --> R5["теги в кеші"]
        R4 --> R6["Python join у пам'яті"]
        R5 --> R6
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;

    class Q1,R1,Q3,Q4,Q5,R4,R5 step;
    class R3,R6 success;
    class Q2 error;
```

---

## 16. PostgreSQL System Architecture

> **Що показує:** Як PostgreSQL обробляє Django запит на системному рівні.
> Shared Buffers = кеш. WAL = журнал відмовостійкості.

```mermaid
graph TD
    Client["Django + psycopg2<br>TCP connection"] --> PM["Postmaster :5432<br>приймає з'єднання"]
    PM -->|"fork()"| BP["Backend Process<br>(ізольований процес для кожного з'єднання)"]
    BP --> QP["Parser → AST → Planner → Optimizer<br>→ Execution Plan"]
    QP --> EE["Execution Engine"]
    EE <-->|"read/write"| SB["Shared Buffers<br>(25% RAM кеш, спільний для всіх процесів)"]
    SB -->|"dirty pages"| WW["WAL Writer<br>(WRITE-AHEAD LOG)"]
    WW -->|"fsync"| WAL["WAL Files /pg_wal/<br>(журнал спочатку!)"]
    WAL -.->|"checkpoint (async)"| DF["Data Files /base/<br>(actual tables)"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class Client,PM,BP,QP,EE,WW,DF step;
    class SB success;
    class WAL warning;
```

---

## 17. Services/Selectors архітектура

> **Що показує:** Потік даних через шари Services/Selectors архітектури.
> View — тонкий. Логіка — в services/selectors.

```mermaid
graph TD
    REQ["HTTP Request<br>(GET /notes/?q=python)"] --> VIEW["views.note_list()<br>Парсить GET параметри"]
    VIEW -->|"get_user_notes(user, search='python')"| SEL["selectors.py: BUILDS QuerySet<br>select_related + prefetch_related"]
    SEL -->|"SQL"| DB[(PostgreSQL)]
    DB -->|"rows"| SEL
    SEL -->|"QuerySet[Note]"| VIEW
    VIEW -->|"render(template, context)"| TMPL["note_list.html ітерує notes<br>0 нових SQL!"]

    REQ2["HTTP Request<br>(POST /notes/create/)"] --> VIEW2["views.note_create()<br>Парсить form.cleaned_data"]
    VIEW2 -->|"create_note(user, title, ...)"| SVC["services.py: transaction.atomic()<br>Note.objects.create() + note.tags.set()"]
    SVC -->|"INSERT"| DB
    DB -->|"id=42"| SVC
    SVC -->|"Note instance"| VIEW2
    VIEW2 -->|"redirect(note_detail)"| RESP["HTTP 302<br>Location: /notes/42/"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    class REQ,VIEW,REQ2,VIEW2,DB,RESP step;
    class SEL,SVC,TMPL success;
```

---

## 18. Нормалізація — Before/After

> **Що показує:** Чому дублювання в схемі — проблема, і як нормалізація вирішує її.

```mermaid
graph LR
    subgraph "❌ До нормалізації (порушує 3NF)"
        T1["employees<br>id | name | dept_id | dept_name | dept_location | salary<br>───────────────────────────────────────────────────<br>1  | Alice| 10     | Engineering | Kyiv         | 50000<br>2  | Bob  | 10     | Engineering | Kyiv         | 45000<br>3  | Carol| 20     | Design      | Lviv         | 48000"]
    end

    subgraph "✅ Після нормалізації (3NF)"
        T2["employees<br>id | name | dept_id FK | salary<br>─────────────────────────────<br>1  | Alice| 10         | 50000<br>2  | Bob  | 10         | 45000<br>3  | Carol| 20         | 48000"]
        T3["departments<br>id | name        | location<br>──────────────────────────<br>10 | Engineering | Kyiv<br>20 | Design      | Lviv"]
        T2 -->|"dept_id → id"| T3
    end

    PROB["Engineering переїхала до Харкова"] --> PB1["❌ UPDATE employees SET dept_location='Kharkiv'<br>WHERE dept_name='Engineering' (1000 рядків!)"]
    PROB --> PB2["✅ UPDATE departments SET location='Kharkiv'<br>WHERE id=10 (1 рядок!)"]

    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class T2,T3,PB2 success;
    class T1,PB1 error;
    class PROB warning;
```

---

## 19. Relationship Types Map (повна карта)

> **Що показує:** Всі типи зв'язків Django + SQL механізм + правило розташування FK.

```mermaid
graph TD
    subgraph "OneToOneField 1:1"
        U[User] <-->|"FK + UNIQUE: user_id → user.id<br>OneToOneField cascade"| UP[UserProfile]
        NOTE1["Вертикальне партиціонування: User — 5 основних полів<br>UserProfile — 20 додаткових, user.profile ← related_name"]
    end

    subgraph "ForeignKey 1:N"
        NB[Notebook] <---|"note.notebook_id → notebook.id<br>ForeignKey SET_NULL nullable"| NT[Note]
        NOTE2["FK В NOTE (Many side), нотатка без записника → NULL<br>Notebook.notes.all() ← related_name"]
    end

    subgraph "ManyToManyField M:N"
        N[Note] <-->|"через автоматичну junction table<br>notes_app_note_tags (note_id, tag_id)"| T[Tag]
        NOTE3["Django автоматично: CREATE TABLE note_tags<br>note.tags.add(tag), tag.notes.all()"]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    class U,UP,NB,NT,N,T step;
    class NOTE1,NOTE2,NOTE3 warning;
```

---

## 20. F() Expression — Race Condition Prevention

> **Що показує:** Різницю між небезпечним Python read-modify-write та атомарним F().

```mermaid
sequenceDiagram
    participant A as Process A
    participant B as Process B
    participant PG as PostgreSQL

    Note over A,PG: ❌ НЕБЕЗПЕЧНО (Python RMW)
    A->>PG: SELECT views_count FROM notes WHERE id=42
    PG-->>A: views=100
    B->>PG: SELECT views_count FROM notes WHERE id=42
    PG-->>B: views=100
    A->>PG: UPDATE notes SET views_count=101 WHERE id=42
    B->>PG: UPDATE notes SET views_count=101 WHERE id=42
    Note over A,PG: Результат: views=101 замість 102 (один перегляд загублено!)

    Note over A,PG: ✅ БЕЗПЕЧНО F() Expression
    A->>PG: UPDATE notes SET views_count=views_count+1 WHERE id=42
    B->>PG: UPDATE notes SET views_count=views_count+1 WHERE id=42
    Note over A,PG: PostgreSQL серіалізує: спочатку A, потім B
    Note over A,PG: Результат: views=102 (правильно!)
```
