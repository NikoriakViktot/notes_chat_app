# Django Architecture — Mermaid-схеми

> Усі схеми — візуалізація концепцій із `django_architecture.md`.

---

## 1. Django Request Lifecycle — загальна схема (MVT)

```mermaid
graph TD
    Browser[🖥️ Браузер] -->|HTTP Request| WebServer["Web Server<br>WSGI / ASGI"]
    WebServer -->|HttpRequest об'єкт| MW_IN["Middleware 1..N<br>вхідний шлях"]
    MW_IN -->|Security / Sessions / Auth| URLDisp["URL Dispatcher<br>urlresolver"]
    URLDisp -->|Знайдено збіг| View(("View Function<br>або CBV"))
    View <-->|ORM QuerySet → SQL| ORM[ORM Layer]
    ORM <-->|SQL запити| DB[(PostgreSQL)]
    View <-->|context dict| Tmpl["Template Engine<br>Jinja2 / DTL"]
    Tmpl -->|HTML рядок| View
    View -->|HttpResponse об'єкт| MW_OUT["Middleware N..1<br>зворотній шлях"]
    MW_OUT -->|Заголовки / Cookies| WebServer
    WebServer -->|HTTP Response| Browser

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Browser,WebServer,MW_IN,MW_OUT,URLDisp,ORM,Tmpl,DB step;
    class View success;
```

---

## 2. Браузер → Django → База даних — повний sequence

```mermaid
sequenceDiagram
    participant B as 🖥️ Браузер
    participant N as Nginx
    participant G as Gunicorn/uWSGI
    participant DJ as Django App
    participant DB as PostgreSQL

    B->>N: HTTPS GET /books/42/
    N->>G: Forwarding via Unix Socket
    G->>DJ: WSGI environ dict
    
    Note over DJ: Middleware (вхід):<br>1. SecurityMiddleware<br>2. SessionMiddleware<br>3. AuthMiddleware → request.user
    
    DJ->>DJ: URL Dispatcher: /books/42/ → BookDetailView
    
    Note over DJ: View execution
    DJ->>DB: SELECT * FROM books_book WHERE id=42
    DB-->>DJ: Рядок даних → Python Book об'єкт
    
    DJ->>DJ: Template render: book_detail.html + context
    
    Note over DJ: Middleware (вихід):<br>Content-Length header
    
    DJ-->>G: HttpResponse (200 OK, HTML)
    G-->>N: HTTP bytes
    N-->>B: HTTPS 200 OK + HTML
```

---

## 3. URL Dispatcher — логіка маршрутизації

```mermaid
flowchart TD
    Req["HTTP Request<br>PATH: /api/books/42/"] --> Root[myproject/urls.py]
    
    Root -->|path: admin/| Admin[Django Admin]
    Root -->|path: api/| APIUrls["api/urls.py<br>include"]
    Root -->|path: нічого не збіглось| NotFound[404 Not Found]
    
    APIUrls -->|path: books/| BookUrls["books/urls.py<br>include"]
    APIUrls -->|path: users/| UserUrls[users/urls.py]
    
    BookUrls -->|"path: пусто<br>GET /api/books/"| BookList["BookListView<br>Список книг"]
    BookUrls -->|"path: int:pk /<br>/api/books/42/"| BookDetail["BookDetailView<br>Деталі книги pk=42"]
    BookUrls -->|path: нічого не збіглось| NotFound

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    class Req,Admin,UserUrls,BookList step;
    class Root,APIUrls,BookUrls decision;
    class BookDetail success;
    class NotFound error;
```

---

## 4. Middleware Chain — "цибулина" запиту

```mermaid
graph TD
    subgraph Зовнішній шар
        S1["SecurityMiddleware<br>HTTPS redirect, HSTS"]
    end
    subgraph Шар сесій
        S2["SessionMiddleware<br>Читає sessionid cookie"]
    end
    subgraph Шар захисту
        S3["CsrfViewMiddleware<br>Перевірка CSRF токену"]
    end
    subgraph Шар авторизації
        S4["AuthenticationMiddleware<br>request.user = User"]
    end
    subgraph Центр
        View["🎯 View Function<br>Бізнес-логіка"]
    end

    Request[HTTP Request] --> S1
    S1 --> S2 --> S3 --> S4 --> View

    View --> S4_out[Middleware 4 out]
    S4_out --> S3_out["Middleware 3 out<br>Content-Length"]
    S3_out --> S2_out["Middleware 2 out<br>Set-Cookie session"]
    S2_out --> S1_out["Middleware 1 out<br>Security headers"]
    S1_out --> Response[HTTP Response]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Request,S1,S2,S3,S4,S4_out,S3_out,S2_out,S1_out step;
    class View,Response success;
```

---

## 5. ORM Architecture — Model → SQL → Python

```mermaid
graph LR
    subgraph Python код
        Model["class Book<br>models.Model"]
        QS["QuerySet<br>Book.objects.filter..."]
        PO["Python об'єкти<br>list of Book instances"]
    end

    subgraph Django ORM
        SQL_GEN["SQL Generator<br>Django DB Backend"]
        CONN["Connection Pool<br>psycopg2"]
    end

    subgraph База даних
        PG[("PostgreSQL<br>books_book table")]
    end

    Model -->|визначає схему| SQL_GEN
    QS -->|lazy evaluation| SQL_GEN
    SQL_GEN -->|SELECT / INSERT / UPDATE| CONN
    CONN -->|SQL запит| PG
    PG -->|rows| CONN
    CONN -->|raw data| SQL_GEN
    SQL_GEN -->|hydration| PO

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Model,QS,SQL_GEN,CONN,PG step;
    class PO success;
```

---

## 6. Структура Django проєкту

```mermaid
graph TD
    Root[myproject/] --> Manage[manage.py]
    Root --> Config["myproject/<br>Конфігурація"]
    Root --> App1["books/<br>Додаток"]
    Root --> App2["users/<br>Додаток"]

    Config --> Settings["settings.py<br>Налаштування"]
    Config --> URLs["urls.py<br>Кореневий роутер"]
    Config --> WSGI[wsgi.py]
    Config --> ASGI[asgi.py]

    App1 --> Models["models.py<br>Book, Author"]
    App1 --> Views["views.py<br>BookListView, BookDetailView"]
    App1 --> AppURLs["urls.py<br>Маршрути"]
    App1 --> Templates["templates/books/<br>*.html"]
    App1 --> Admin_py["admin.py<br>Адмін реєстрація"]
    App1 --> Migrations["migrations/<br>0001_initial.py..."]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    class Root,Manage,Settings,URLs,WSGI,ASGI,Models,Views,AppURLs,Templates,Admin_py,Migrations step;
    class Config,App1,App2 decision;
```

---

## 7. Authentication Flow — Login/Logout

```mermaid
sequenceDiagram

    participant U as 👤 Користувач
    participant B as 🌍 Браузер
    participant DJ as 🐍 Django Server

    U->>B: Вводить логін і пароль

    B->>DJ: POST /login/

    Note over DJ: authenticate(username, password)<br>Перевірка хешу пароля

    alt ✅ Дані правильні

        DJ->>DJ: login(request, user)

        Note over DJ: Створення session<br>у django_session

        DJ-->>B: 302 Redirect /dashboard/<br>Set-Cookie: sessionid=abc123

        B->>DJ: GET /dashboard/<br>Cookie: sessionid=abc123

        Note over DJ: SessionMiddleware<br>зчитує session

        Note over DJ: AuthMiddleware<br>request.user = User(id=42)

        DJ-->>B: HTML Dashboard

    else ❌ Невірний пароль

        DJ-->>B: HTML + "Невірні дані"

    end

    U->>B: Натискає "Вийти"

    B->>DJ: POST /logout/

    Note over DJ: logout(request)<br>видаляє session

    DJ-->>B: Redirect /<br>очищення session cookie
```

---


```mermaid
flowchart LR


    User["👤 Користувач"]

    Browser["🌍 Браузер<br>sessionid cookie"]

    Django["🐍 Django<br>Auth + SessionMiddleware"]

    DB[("🗄️ django_session")]

    User --> Browser

    Browser -->|"POST /login"| Django

    Django -->|"authenticate()"| DB

    Django -->|"створення session"| DB

    Django -->|"Set-Cookie: sessionid"| Browser

    Browser -->|"Cookie: sessionid"| Django

    Django -->|"request.user"| User

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class User,Browser,DB step;
    class Django success;
```



---


```mermaid
flowchart TB

    Request["HTTP Request"]

    Cookie["sessionid cookie"]

    Session["django_session table"]

    User["Authenticated User"]

    Request --> Cookie

    Cookie --> Session

    Session --> User

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Request,Cookie,Session step;
    class User success;
```



---

## 8. Session Lifecycle

```mermaid
flowchart LR


    Anonymous["👤 Анонімний"]

    Login["POST /login/"]

    Auth["✅ Автентифікований<br>sessionid cookie"]

    Logout["POST /logout/"]

    Expire["Session Expired"]

    Anonymous --> Login

    Login -->|"authenticate() OK"| Auth

    Login -->|"❌ wrong password"| Anonymous

    Auth --> Logout

    Logout --> Anonymous

    Auth --> Expire

    Expire --> Anonymous

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    class Login,Logout step;
    class Expire warning;
    class Auth success;
    class Anonymous error;
```

---

# Session + Cookie Architecture

```mermaid
flowchart TB

    Browser["🌍 Browser"]

    Cookie["sessionid cookie"]

    Django["🐍 Django"]

    SessionDB[("🗄️ django_session")]

    User["request.user"]

    Browser --> Cookie

    Cookie --> Django

    Django --> SessionDB

    SessionDB --> User

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Browser,Cookie,Django,SessionDB step;
    class User success;
```

---

#  Що реально відбувається на кожному request.

```mermaid
sequenceDiagram

    participant B as Browser
    participant D as Django
    participant DB as Session DB

    B->>D: HTTP Request + sessionid cookie

    D->>DB: find session by sessionid

    DB-->>D: session data

    D->>D: request.user restored

    D-->>B: HTTP Response
```

---

## 9. WSGI vs ASGI — модель конкурентності

```mermaid
graph TD
    subgraph WSGI_SYN[WSGI — Синхронна модель]
        W_Nginx[Nginx] --> W_Gunicorn["Gunicorn<br>4 workers"]
        W_Gunicorn --> W1["Worker 1<br>🔒 зайнятий: чекає БД 3сек"]
        W_Gunicorn --> W2["Worker 2<br>🔒 Зайнятий"]
        W_Gunicorn --> W3["Worker 3<br>✅ Вільний"]
        W_Gunicorn --> W4["Worker 4<br>✅ Вільний"]
        Note1[Максимум 4 паралельні запити]
    end

    subgraph ASGI_ASY[ASGI — Асинхронна модель]
        A_Nginx[Nginx] --> A_Uvicorn["Uvicorn<br>4 workers з event loop"]
        A_Uvicorn --> EL["Event Loop<br>Worker 1"]
        EL --> T1[Task 1: await db.query]
        EL --> T2[Task 2: обробляє запит]
        EL --> T3[Task 3: await file.read]
        EL --> T4[Task N: тисячі корутин...]
        Note2[Тисячі паралельних з'єднань]
    end

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    class W_Nginx,W_Gunicorn,A_Nginx,A_Uvicorn,EL,T1,T2,T3,T4 step;
    class W1,W2 warning;
    class W3,W4,Note2 success;
    class Note1 error;
```

---

## 10. Django + PostgreSQL з'єднання

```mermaid
graph TD
    subgraph Django App
        ORM["Django ORM<br>QuerySet API"]
        Pool["Connection Pool (Django DB connections)<br>max 10 за замовчуванням"]
    end

    subgraph PostgreSQL
        PG_Auth["Auth<br>User: myapp Password: ***"]
        PG_Parser["Query Parser<br>SQL → Query Plan"]
        PG_Exec[Query Executor]
        PG_Storage[("Storage Engine<br>Heap / B-Tree Index")]
    end

    ORM -->|Python QuerySet| Pool
    Pool -->|"TCP :5432 або Unix Socket<br>psycopg2"| PG_Auth
    PG_Auth -->|Authenticated| PG_Parser
    PG_Parser -->|Optimized Query Plan| PG_Exec
    PG_Exec -->|Read/Write| PG_Storage
    PG_Storage -->|Rows| PG_Exec
    PG_Exec -->|Result set| Pool
    Pool -->|Python objects| ORM

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class ORM,PG_Auth,PG_Parser,PG_Exec,PG_Storage step;
    class Pool warning;
```

---

## 11. Django + Redis + Celery

```mermaid
graph LR
    User[👤 Користувач] -->|POST /order/| DjangoView[Django View]
    
    DjangoView -->|send_confirmation_email.delay| Redis[("Redis<br>Broker Queue")]
    DjangoView -->|HttpResponse 201| User
    Note1["Відповідь миттєва!<br>Email іде фоново"]
    
    Redis -->|Task picked up| CeleryW[Celery Worker]
    CeleryW -->|SMTP| Email[📧 Email Server]
    CeleryW -->|Результат| Redis

    subgraph Моніторинг
        Flower["Flower UI<br>:5555"]
    end
    
    CeleryW --> Flower

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class User,DjangoView,Redis,CeleryW,Email,Flower step;
    class Note1 success;
```

---

## 12. Production Deployment Architecture (Nginx + Gunicorn + Docker)

```mermaid
graph TD
    Client[Browser / Mobile] -->|HTTPS :443| Nginx["Nginx<br>Reverse Proxy"]
    
    Nginx -->|"/static/ /media/<br>Без Python"| Disk[("📁 Файлова система<br>staticfiles/ media/")]
    
    Nginx -->|"Динамічні запити<br>Unix Socket"| Gunicorn["Gunicorn<br>Process Manager"]
    
    subgraph Python Application
        Gunicorn -->|fork| W1[Uvicorn Worker 1]
        Gunicorn -->|fork| W2[Uvicorn Worker 2]
        Gunicorn -->|fork| W3[Uvicorn Worker 3]
        Gunicorn -->|fork| W4[Uvicorn Worker 4]
    end
    
    W1 -->|ASGI| DjApp[Django Application]
    W2 -->|ASGI| DjApp
    W3 -->|ASGI| DjApp
    W4 -->|ASGI| DjApp
    
    DjApp -->|Async ORM| PG[(PostgreSQL :5432)]
    DjApp -->|Cache / Sessions| RedisDB[(Redis :6379)]
    DjApp -->|Tasks| CeleryQ[Celery Workers]
    CeleryQ --> PG

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Client,Nginx,Disk,Gunicorn,W1,W2,W3,W4,PG,RedisDB,CeleryQ step;
    class DjApp success;
```

---

## 13. Django Request Lifecycle — детальний sequence

```mermaid
sequenceDiagram
    participant B as 🖥️ Браузер
    participant MW as Middleware (In/Out)
    participant URL as URL Router
    participant V as View
    participant DB as ORM / Database
    participant T as Template Engine

    B->>MW: HTTP GET /books/1/
    Note over MW: Вхідний шлях (зверху вниз):<br>1. SecurityMiddleware<br>2. SessionMiddleware<br>3. AuthMiddleware → request.user

    MW->>URL: HttpRequest (request.user доданий)
    URL->>V: invoke book_detail(request, pk=1)
    
    V->>DB: Book.objects.select_related('author').get(id=1)
    Note over DB: SELECT books_book.*, auth_author.*<br>FROM books_book<br>JOIN auth_author ON ...<br>WHERE books_book.id = 1
    DB-->>V: Python Book об'єкт (з author)
    
    V->>T: render('books/detail.html', {'book': book})
    Note over T: Парсинг шаблону<br>Підстановка змінних<br>Escape HTML (XSS захист)
    T-->>V: HTML рядок (4.2KB)
    
    V-->>MW: HttpResponse(html, status=200)
    
    Note over MW: Зворотній шлях (знизу вгору):<br>Content-Length: 4200<br>Vary: Cookie
    
    MW-->>B: HTTP/1.1 200 OK + HTML
```

---

## 14. Django Admin Panel — архітектура

```mermaid
graph TD
    Dev[👨‍💻 Розробник] -->|register| AdminSite["django.contrib.admin<br>AdminSite"]
    
    subgraph Реєстрація моделей
        AdminSite --> BA["BookAdmin<br>list_display, search_fields"]
        AdminSite --> UA["UserAdmin<br>filter_horizontal"]
        AdminSite --> OtherAdmin[...]
    end
    
    User[👤 Адмін-користувач] -->|GET /admin/books/book/| AdminSite
    
    AdminSite -->|CRUD операції| ORM_A[Django ORM]
    ORM_A -->|SQL| DB_A[(Database)]
    
    AdminSite -->|"auth check<br>is_staff=True"| Auth[Authentication System]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Dev,User,BA,UA,OtherAdmin,ORM_A,DB_A step;
    class AdminSite success;
    class Auth warning;
```

---

## 15. Масштабування Django у продакшні

```mermaid
graph TD
    Internet[🌐 Інтернет] --> LB["Load Balancer<br>HAProxy / AWS ALB"]
    
    LB --> Nginx1[Nginx 1]
    LB --> Nginx2[Nginx 2]
    
    Nginx1 --> App1["Django App<br>Container 1"]
    Nginx1 --> App2["Django App<br>Container 2"]
    Nginx2 --> App3["Django App<br>Container 3"]
    Nginx2 --> App4["Django App<br>Container 4"]
    
    App1 & App2 & App3 & App4 -->|Спільна БД| PG_Master[("PostgreSQL<br>Master")]
    App1 & App2 & App3 & App4 -->|Read replicas| PG_Read[("PostgreSQL<br>Read Replica")]
    App1 & App2 & App3 & App4 -->|"Shared cache<br>Sessions"| Redis_Cluster[(Redis Cluster)]
    
    App1 & App2 & App3 & App4 -->|Tasks| CeleryQ[(Redis Queue)]
    CeleryQ --> CW1[Celery Worker 1]
    CeleryQ --> CW2[Celery Worker 2]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Internet,LB,Nginx1,Nginx2,PG_Master,PG_Read,CeleryQ,CW1,CW2 step;
    class App1,App2,App3,App4 success;
    class Redis_Cluster warning;
```
