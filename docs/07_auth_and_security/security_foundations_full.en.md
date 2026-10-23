# Web Application Security Foundations — Security Foundations

> **Audience:** Students with no prior cybersecurity knowledge.
>
> **Goal:** Build a foundation — understand HOW an attacker thinks so you can build protection correctly.
>
> **Approach:** Every topic starts with a real-world analogy, followed by theory and code.

---

## 1. The three pillars of security: the CIA Triad

### Analogy — a bank vault

Imagine a bank vault holding documents:
- **Confidentiality (C):** only the owner sees the documents. Outsiders don't.
- **Integrity (I):** nobody swapped the documents while the vault was locked.
- **Availability (A):** the vault opens when the owner arrives. Not "closed for repairs".

Violating even one of the three is already an attack.

### The CIA Triad in a web application

```mermaid
flowchart TB

    CIA["🛡️ CIA Triad"]

    CIA --> C["Confidentiality"]
    CIA --> I["Integrity"]
    CIA --> A["Availability"]

    C --> C1["Authorization"]
    C --> C2["Access rights checks"]

    I --> I1["CSRF protection"]
    I --> I2["Password hashing"]

    A --> A1["Rate limiting"]
    A --> A2["Brute-force protection"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class CIA warning;
    class C,I,A step;
    class C1,C2,I1,I2,A1,A2 success;
```

---

#  Django Security

```mermaid
flowchart LR

    User["👤 User"]

    Auth["Authentication<br>Who are you?"]

    Perm["Authorization<br>What are you allowed to do?"]

    Resource["System data"]

    User --> Auth

    Auth --> Perm

    Perm --> Resource

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class User step;
    class Auth,Perm warning;
    class Resource success;
```

---
## ARCHITECT INSIGHT
```text

Confidentiality:
    who sees the data

Integrity:
    who can change the data

Availability:
    whether the system is available to legitimate users
```


### Examples of violations and their consequences

| Violation | Attack example | Real-world consequence |
|-----------|---------------|-------------------|
| **Confidentiality** | Alice reads Bob's notes via IDOR | Personal data leak → GDPR fines |
| **Integrity** | An attacker changes a price from $99 to $1 | Financial losses for the company |
| **Availability** | A DDoS attack with 10 Gbps of traffic | The site is down → lost customers |

> **Important for beginners:** Most students think of security only as
> "don't let the password get stolen" (Confidentiality). But tampering with data (Integrity)
> and making a system unavailable (Availability) are attacks too!

---

## 2. Trust Boundary

### Analogy — customs control at the airport

When you fly in from another country, customs checks EVERY suitcase you have. They don't say
"this passenger looks fine, let's skip the inspection". Everyone goes through the same check.

**The Trust Boundary in Django** is the place where Django checks every incoming request,
regardless of who sent it.

### The request path: from the browser to the DB

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 60, 'rankSpacing': 80}}}%%
flowchart TD

    subgraph RED["🔴 Untrusted zone"]
        Browser["🌐 Browser"]
        Attacker["👾 Attacker"]
    end

    subgraph YELLOW["🟡 Security Layer"]
        Nginx["Nginx"]
        Middleware["Middleware"]
        Auth["Authentication"]
        Validation["Validation"]
        Permissions["Permissions"]
    end

    subgraph GREEN["🟢 Trusted Zone"]
        View["Django View"]
        ORM["Django ORM"]
        DB["PostgreSQL"]
    end

    Browser --> Nginx
    Attacker --> Nginx

    Nginx --> Middleware
    Middleware --> Auth
    Auth --> Validation
    Validation --> Permissions
    Permissions --> View
    View --> ORM
    ORM --> DB

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Browser,Nginx,Middleware,Auth,Validation,Permissions step;
    class Attacker,RED error;
    class YELLOW warning;
    class View,ORM,DB,GREEN success;
```

**Red zone (untrusted):** Any request from the Internet. Anyone can forge:
- HTTP headers (`X-Forwarded-For`, `Content-Type`)
- The POST request body (`priority=999`, `is_admin=true`)
- Cookies (`sessionid=чужий_токен`)
- URL parameters (`?pk=42` — someone else's note)

**Green zone (trusted):** Inside Django, after the checks.

### What Django checks when the boundary is crossed

```python
# Every incoming request passes through this chain:

# 1. SecurityMiddleware — basic HTTP checks
# 2. SessionMiddleware — who is sending the request?
# 3. AuthenticationMiddleware — request.user is set here
# 4. CsrfViewMiddleware — is there a valid CSRF token?
# 5. Your @login_required decorator — logged in?
# 6. forms.is_valid() — is the form data correct?
# 7. get_object_or_404(..., user=request.user) — is there permission for this object?

# Only after ALL of these checks → trusted logic
```

> **Rule:** Everything that came from the Internet — **treat it as forged** until it is checked.
> `request.POST`, `request.GET`, `request.FILES`, `request.COOKIES` — all untrusted.

---

## 3. Attack Surface

### Analogy — the number of doors in a house

A castle with 10 doors is harder to guard than a castle with 2 doors. Every additional
door is one more point that needs protecting and that an attacker might find.

**Attack Surface** is the total number of "doors" in your application.

### All the entry points of a typical Django application

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 50, 'rankSpacing': 70}}}%%
flowchart LR

    A["👾 Attacker"]

    subgraph SURFACE["🔴 Web application attack surface"]
        U["URL endpoints<br/>/notes/, /admin/, /api/"]
        F["HTML forms<br/>&lt;input&gt;, &lt;textarea&gt;"]
        C["Cookies<br/>sessionid, csrftoken"]
        H["HTTP Headers<br/>Content-Type, User-Agent"]
        FI["File uploads<br/>.jpg, .pdf, .exe"]
        Q["Query params<br/>?search=..., ?pk=..."]
        D["Dependencies<br/>Django, Pillow, requests"]
    end

    A --> U
    A --> F
    A --> C
    A --> H
    A --> FI
    A --> Q
    A --> D

    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class A error;
    class U,F,C,H,FI,Q,D warning;
```

### How to reduce the Attack Surface in Django

```python
# settings.py — close everything you don't need:

DEBUG = False                     # Removes debug endpoints and detailed errors
ALLOWED_HOSTS = ['mysite.com']    # Only your domain, not '*' (opens everything)

# urls.py — you can remove /admin/ if you don't need it:
# path('admin/', admin.site.urls),  # ← comment it out or change the URL

# INSTALLED_APPS — remove what you don't use:
INSTALLED_APPS = [
    # 'django.contrib.staticfiles',  # if Nginx serves static files
    # 'debug_toolbar',               # NEVER in production!
]
```

**Attack Surface reduction checklist:**
- ✓ `DEBUG = False` — removes `/500-debug-page/` and stack traces
- ✓ A specific `ALLOWED_HOSTS` — not `['*']`
- ✓ Remove `django-debug-toolbar` from `INSTALLED_APPS` in production
- ✓ Close test endpoints (`/dev/`, `/seed-data/`)
- ✓ Rate limiting on `/accounts/login/` and `/accounts/password_reset/`

---

## 4. The Defense-in-Depth principle

### Analogy — a medieval castle

```
🏰 Medieval castle               ←→    Web application

🌊 Moat with water               ←→    Firewall / DDoS protection (Cloudflare)
🧱 Outer walls                   ←→    Nginx: rate limiting, HTTPS
⚔️  Guards at the gates           ←→    Django Middleware (CSRF, Sessions)
🚪 Inner doors with locks        ←→    @login_required + object-level checks
🔐 Treasure vault                ←→    PostgreSQL + ORM (parameterized queries)
📹 Video surveillance            ←→    Logging + SIEM monitoring
```

**The main idea:** If an attacker crosses the moat (bypasses the Firewall), the walls (Nginx) stop them.
If they get past the walls, the guards (Middleware) stop them. And so on.

### Diagram of the 6 layers of protection

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 60, 'rankSpacing': 90}}}%%
flowchart TD

    Attack["🦹 Attacker"]

    subgraph DEFENSE["🛡️ Defense-in-Depth: 6 layers of protection"]
        L1["🌐 Layer 1: Network<br/>Firewall · DDoS protection · HTTPS · Cloudflare / AWS Shield"]

        L2["🧱 Layer 2: Web Server<br/>Nginx · Rate limiting · HTTP Security Headers"]

        L3["⚙️ Layer 3: Django Middleware<br/>SecurityMiddleware · CSRF Middleware · SessionMiddleware"]

        L4["🔐 Layer 4: Application Layer<br/>@login_required · Permissions · get_object_or_404(..., user=request.user)"]

        L5["🗄️ Layer 5: Database<br/>Django ORM · parameterized queries · DB user without DROP privileges"]

        L6["📡 Layer 6: Monitoring<br/>Logging · Sentry · Grafana · SIEM / Alerts"]
    end

    Data["✅ Data is protected"]

    Attack --> L1
    L1 --> L2
    L2 --> L3
    L3 --> L4
    L4 --> L5
    L5 --> L6
    L6 --> Data

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    class Attack error;
    class L1,L2,L3,L4,L5,L6 step;
    class Data success;
```

### What happens if one layer is breached

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 60, 'rankSpacing': 80}}}%%
flowchart TD

    Attack["🦹 Attacker"]
    Bypass["⚠️ Layer 2 breached<br/>Nginx rate limiting bypassed via VPN rotation"]

    subgraph BAD["❌ Without Defense-in-Depth"]
        Bad1["Nginx let it through"]
        Bad2["Brute force continues"]
        Bad3["💀 GAME OVER<br/>password guessed"]
    end

    subgraph GOOD["✅ With Defense-in-Depth"]
        Good1["Nginx let it through"]
        Good2["Django Middleware checks the request"]
        Good3["CSRF / Session / Auth checks"]
        Good4["🛡️ Request blocked"]
    end

    Attack --> Bypass

    Bypass --> Bad1
    Bad1 --> Bad2
    Bad2 --> Bad3

    Bypass --> Good1
    Good1 --> Good2
    Good2 --> Good3
    Good3 --> Good4

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Attack,Bad2,Bad3,BAD error;
    class Bypass warning;
    class Bad1,Good1,Good2,Good3 step;
    class Good4,GOOD success;
```

```
Scenario: The attacker bypassed Nginx rate limiting via VPN rotation.

Without Defense-in-Depth:
  Nginx → let through → GAME OVER (password brute force succeeds)

With Defense-in-Depth:
  Nginx → let through
  → Django Middleware: CSRF check failed → blocked ✓

Or another scenario: the attacker stole the sessionid cookie.

Without Defense-in-Depth:
  They log in and see ALL the data → GAME OVER

With Defense-in-Depth:
  They log in → see ONLY the session owner's data
  → get_object_or_404(Note, pk=pk, user=request.user) → other users' notes are inaccessible ✓
```
___

## 5. Authentication vs Authorization

### Analogy — a passport and a concert ticket

- **Passport** = Authentication (AuthN): "Who are you?" — confirms identity
- **Ticket** = Authorization (AuthZ): "Where are you allowed to go?" — defines rights

At the airport: security checks your passport (AuthN), then your boarding pass (AuthZ).
A passport without a ticket won't get you in. A ticket without a passport won't either.

### The full authentication flow in Django

```mermaid
sequenceDiagram
    participant Б as Browser
    participant V as Django View
    participant DB as Database

    Б->>V: POST /accounts/login/ {username, password}
    V->>DB: authenticate(username, password)
    Note over DB: Finds the user<br/>Compares PBKDF2 hashes
    DB-->>V: User object (or None)
    
    alt Hash matches
        V->>DB: login() — creates a session record
        DB-->>V: session_key = "xK9mPq..."
        V-->>Б: 302 Redirect + Set-Cookie: sessionid=xK9mPq...
    else Doesn't match
        V-->>Б: 200 + form with the error "Invalid login"
    end
```

### Authorization decision tree

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 70, 'rankSpacing': 90}}}%%
flowchart TD

    R["🌐 Request<br/>/notes/42/edit/"]

    Q1{"request.user<br/>authenticated?"}

    R1["🔁 302 Redirect<br/>/accounts/login/"]

    Q2{"note.user<br/>== request.user?"}

    A1["✅ Access granted<br/>show the edit form"]

    Q3{"is user a member of<br/>note.group?"}

    A2["👁️ Group access<br/>viewing allowed, editing forbidden"]

    A3["⛔ 403 Forbidden<br/>PermissionDenied"]

    R --> Q1

    Q1 -->|no| R1
    Q1 -->|yes| Q2

    Q2 -->|yes| A1
    Q2 -->|no| Q3

    Q3 -->|yes| A2
    Q3 -->|no| A3

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class R step;
    class Q1,Q2,Q3 decision;
    class R1 warning;
    class A1 success;
    class A2 step;
    class A3 error;
```

### Django implementation

```python
# Authentication (who are you?):
from django.contrib.auth import authenticate, login

user = authenticate(request, username='alice', password='secret')
if user is not None:
    login(request, user)   # ← creates a session in the DB
    # now request.user = alice in all subsequent requests

# Authorization (what are you allowed to do?):
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied

@login_required                                        # ← AuthN: logged in?
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)
    if note.user != request.user:                      # ← AuthZ: the owner?
        raise PermissionDenied                         # 403 Forbidden
    # or shorter:
    note = get_object_or_404(Note, pk=pk, user=request.user)  # AuthN + AuthZ together
```

> **A common mistake:** `@login_required` is ONLY AuthN. It doesn't check
> whether this particular object belongs to the user. You need both checks!

---

## 6. Password hashing — why MD5 is dangerous

### Analogy — a meat grinder (a one-way function)

Meat → meat grinder → ground meat. Turning ground meat back into a whole piece of meat is impossible.
A hash function works the same way: password → hash function → hash. Recovering the password from the hash is
mathematically infeasible (for a good algorithm).

### Why MD5 is the wrong choice

MD5 was designed in 1991 as a checksum (not for passwords!). It is extremely fast.

```
Speed comparison (on a modern RTX 4090 GPU):

MD5:      60,000,000,000 hashes/second (60 billion!)
bcrypt:        20,000 hashes/second
PBKDF2:        10,000 hashes/second

Brute-forcing the password "Password1" (8 characters, A-z + 0-9):
  MD5:    < 1 second    ← DANGEROUS
  bcrypt: ~3 days       ← acceptable  
  PBKDF2: ~7 days       ← GOOD
```

**Key principle:** For passwords, "slow = secure". The algorithm is intentionally slow,
so that a brute-force attack would cost years of time even on a supercomputer.

### Algorithm comparison table

| Algorithm | Speed | Salt | Secure? | Where it's used |
|----------|-----------|------|------------|-------------------|
| MD5 | ~60 Ghash/s | ✗ | ❌ NO | File checksums |
| SHA-256 | ~20 Ghash/s | ✗ | ❌ NO for passwords | Signatures (not passwords!) |
| bcrypt | ~20k/s | ✓ | ✅ YES | PHP, Ruby projects |
| PBKDF2 | ~10k/s | ✓ | ✅ YES | **Django's default** |
| Argon2 | ~1k/s | ✓ | ✅ YES | The most modern (Django 3+) |

### What Django stores in the DB

```
The User.password field in the database:

pbkdf2_sha256$1000000$randomsalt$VQaFwT...longhash...==
│             │        │           │
│             │        │           └─ the hash itself (base64)
│             │        └─ salt (random, 22 characters)
│             └─ number of iterations (1000000 in Django 5.2+)
└─ algorithm name
```

```python
# Django hashes automatically in set_password():
user = User.objects.create_user(username='alice', password='secret123')
print(user.password)
# → 'pbkdf2_sha256$1000000$xK9mPq3rT8aL2v...=$VQaFwT+abc...=='

# Django checks automatically in authenticate():
user = authenticate(request, username='alice', password='secret123')
# → Django: PBKDF2('secret123', salt='xK9mPq3rT8aL2v...', iterations=1000000)
# → Compares it with the hash in the DB
# → Returns the User if it matches, None if not
```

### Why salt matters

```
WITHOUT SALT — a Rainbow Table attack:

The attacker precomputes a table:
  "password"  → "5f4dcc3b5aa765d61d8327deb882cf99"
  "123456"    → "e10adc3949ba59abbe56e057f20f883e"
  "qwerty"    → "d8578edf8458ce06fbc5bb76a58c5ca4"
  ...billions of entries...

Got a hash from the DB: "5f4dcc3b5aa765d61d8327deb882cf99"
→ Finds it in the table in 0.001 seconds → the password is "password" ✓

WITH SALT — the Rainbow Table is useless:

  "password" + "xK9mPq" (Alice's) → "A COMPLETELY UNIQUE hash"
  "password" + "mR7pLw" (Bob's)   → "ANOTHER UNIQUE hash"

Even if Alice and Bob have the SAME password, their hashes differ.
A precomputed table is useless: each account has to be brute-forced separately.
```

---

## 7. CSRF — Cross-Site Request Forgery

### Analogy — a forged letter in your name

Imagine: a bank accepts transfers via letters bearing your signature. An attacker forges your signature
and sends a letter: "transfer $1000 to my account". The bank doesn't know the letter is forged.

CSRF is the same thing, but in the browser: the attacker forces **your browser** to send a request
on your behalf (with your cookies), without you knowing.

### A CSRF attack: step by step

```mermaid
sequenceDiagram
    participant Б as Alice's browser
    participant E as evil.com
    participant D as bank.com

    Note over Б,D: Alice is logged in to bank.com (has a sessionid cookie)
    
    Б->>E: Alice opens evil.com
    E-->>Б: HTML with a hidden form:
    Note over E,Б: <form action="bank.com/transfer"><br/>  <input value="hacker_account"><br/>  <input value="1000"><br/></form><br/><script>form.submit()</script>
    Б->>D: POST /transfer amount=1000 to=hacker
    Note over Б,D: The browser adds the sessionid cookie automatically!
    D-->>Б: Transfer completed (bank.com thought it was Alice)
```

### CSRF protection: with a token

```mermaid
sequenceDiagram
    participant Б as Alice's browser
    participant E as evil.com
    participant D as bank.com (with CSRF protection)

    Б->>D: GET /transfer (first time opening the page)
    D-->>Б: HTML with a CSRF token: csrfmiddlewaretoken=abc123xyz
    Note over Б: The token is tied to Alice's session
    
    Б->>E: Alice opens evil.com
    E-->>Б: A form without a CSRF token (evil.com doesn't know abc123xyz!)
    Б->>D: POST without csrfmiddlewaretoken
    D-->>Б: 403 Forbidden — CSRF check failed ✓
```

### Django implementation

```html
<!-- Every POST form MUST have {% csrf_token %}: -->
<form method="POST" action="{% url 'note_create' %}">
    {% csrf_token %}
    <!-- Django generates: -->
    <!-- <input type="hidden" name="csrfmiddlewaretoken" value="abc123...xyz"> -->
    
    {{ form.as_p }}
    <button type="submit">Save</button>
</form>
```

```python
# settings.py — CSRF and cookie settings:
SESSION_COOKIE_SAMESITE = "Lax"
# ↑ "Lax": the cookie is sent when navigating within the site,
#   but is NOT sent with cross-site POST requests.
#   So evil.com → bank.com won't get the sessionid automatically.

# "Strict": the cookie isn't sent with any cross-site request at all.
#   Stricter, but breaks some OAuth flows.

# "None": always sent (DANGEROUS, requires the Secure flag).
```

### SameSite: comparing the modes

| SameSite | Navigation (a → b) | Cross-site POST | OAuth redirects | Recommendation |
|----------|-------------------|-----------------|-----------------|--------------|
| `Strict` | ✗ not sent | ✗ | ✗ | Maximum security |
| `Lax` | ✓ sent | ✗ | ✓ | **Recommended for Django** |
| `None` | ✓ | ✓ | ✓ | Only with the `Secure` flag |

---

## 8. File upload security

### Analogy — customs and an X-ray

A border guard can check a passport (the `.jpg` file extension) — but a name can be forged.
An X-ray checks the CONTENTS of the suitcase (the file's magic bytes) — that's much harder to forge.

**Rule:** Never trust a file extension. Always check the real type through its content.

### Dangerous extensions and what attackers do with them

| Extension | Danger | Attack |
|------------|-----------|-------|
| `.php`, `.py`, `.sh` | Code execution on the server (RCE) | Upload a webshell renamed to `.jpg` |
| `.html`, `.svg` | XSS | `<script>` inside an SVG or HTML file |
| `.exe`, `.bat` | Infecting the client | Social engineering via a download |
| `.zip` (Zip Bomb) | DoS | A 1 KB archive → 1 TB after extraction |

### Step-by-step protection

```python
# 1. Extension check (the first barrier):
from django.core.validators import FileExtensionValidator

class AvatarUploadForm(forms.Form):
    avatar = forms.FileField(
        validators=[FileExtensionValidator(allowed_extensions=['jpg', 'jpeg', 'png', 'webp'])]
    )
    # ↑ Rejects .php, .exe — but an attacker can rename the file. Step 2 is needed!

# 2. Magic bytes check (the real type):
import magic    # pip install python-magic-bin (Windows) or python-magic (Linux)

def validate_image_content(file):
    file_content = file.read(2048)
    file.seek(0)  # rewind the cursor — Django will read the file further
    
    mime_type = magic.from_buffer(file_content, mime=True)
    allowed_types = {'image/jpeg', 'image/png', 'image/webp'}
    
    if mime_type not in allowed_types:
        raise forms.ValidationError(
            f"Invalid file type: {mime_type}. Allowed: JPEG, PNG, WebP."
        )

# 3. A safe file name (a UUID instead of the original name):
import uuid
from pathlib import Path

def upload_to(instance, filename):
    ext = Path(filename).suffix.lower()   # .jpg
    new_name = f"{uuid.uuid4()}{ext}"     # 550e8400-e29b-41d4-a716-446655440000.jpg
    return f"avatars/{new_name}"
    # An attacker can't predict the URL of the uploaded file
```

```python
# 4. Storage OUTSIDE the web root:
MEDIA_ROOT = '/var/uploads/private/'   # NOT /var/www/uploads/ !

# A Django view for serving files:
@login_required
def serve_avatar(request, filename):
    note = get_object_or_404(Note, avatar_filename=filename, user=request.user)
    file_path = Path(settings.MEDIA_ROOT) / filename
    return FileResponse(open(file_path, 'rb'), content_type='image/jpeg')
# ↑ The file is accessible only through the Django view, not directly via Nginx
```

---

## 9. The Principle of Least Privilege

### Analogy — the key system in an office

The security guard has a key to the main entrance (they can open the office). But they DON'T have a key
to the director's safe, to the server room, or to the accounting department. They have exactly as much access
as their job requires — and no more.

**Least Privilege** = every component of the system has the minimum necessary rights.

### Django components and their minimum rights

| Component | Minimum rights | What NOT to grant |
|-----------|------------------|--------------------|
| Django DB user | SELECT, INSERT, UPDATE, DELETE | CREATE DB, DROP TABLE, GRANT |
| Celery worker | connection to Redis/RabbitMQ | DB admin rights |
| Email service | SMTP sending | IMAP/POP3 reading |
| S3 bucket policy | `s3:PutObject`, `s3:GetObject` | `s3:DeleteBucket`, `s3:*` |
| Nginx process | reading `/var/www/` | writing to `/etc/` |

### Setting up a separate DB user (PostgreSQL)

```sql
-- Connect as the postgres superuser:
-- psql -U postgres

-- 1. Create a separate user for Django:
CREATE USER django_user WITH PASSWORD 'strongpassword';

-- 2. Grant rights ONLY on a specific DB:
GRANT CONNECT ON DATABASE mydb TO django_user;

-- 3. Grant rights on the schema:
GRANT USAGE ON SCHEMA public TO django_user;

-- 4. Grant rights for operations (no DROP, CREATE, GRANT!):
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO django_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO django_user;

-- If an attacker compromises Django → they can only read/write data
-- but can NOT do: DROP TABLE users; or CREATE USER hacker SUPERUSER;
```

```python
# settings.py:
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'mydb',
        'USER': 'django_user',     # ← a separate user, not 'postgres'!
        'PASSWORD': os.environ['DB_PASSWORD'],
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

---

## 10. Secrets and Environment Variables

### Analogy — a password on a sticky note vs a password in your head

A password written on a sticky note stuck to the monitor is seen by everyone who walks by.
The same happens with secrets in code: git commit → GitHub → PUBLIC repository → everyone sees them.

### The problem: git keeps the ENTIRE HISTORY

```bash
# Even if you removed SECRET_KEY from settings.py and made a commit —
# it STAYS in the git history and can be found:

git log --all --full-history -p -- "*.py" | grep "SECRET_KEY"
# → Shows every commit where SECRET_KEY changed

# Attackers scan GitHub looking for such leaks:
# GitGuardian, TruffleHog — automatic scanners for secrets in git
```

### The right solution: a .env file + python-decouple

```bash
# Step 1: the .env file (NEVER commit it to git!)
# File: crispy_notes_chat_app/.env

SECRET_KEY=django-very-random-key-50-chars-here
DATABASE_URL=postgresql://django_user:strongpassword@localhost:5432/mydb
EMAIL_HOST_PASSWORD=smtp_password_here
DEBUG=False
```

```python
# Step 2: pip install python-decouple
# settings.py:

from decouple import config, Csv

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost', cast=Csv())

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='mydb'),
        'USER': config('DB_USER', default='django_user'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
    }
}
```

```bash
# Step 3: .gitignore (MANDATORY):
echo ".env" >> .gitignore
echo "*.env" >> .gitignore

# Check that .env doesn't get into git:
git status   # .env must not appear in the list
git check-ignore -v .env   # → .gitignore:1:.env  .env  (ignored)
```

```bash
# Step 4: .env.example — a template for new developers (WITHOUT real values):
# .env.example (this file CAN be committed):

SECRET_KEY=your-secret-key-here
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
EMAIL_HOST_PASSWORD=your-smtp-password
DEBUG=True
```

---

## 11. Secure HTTP Headers

### How it works: the browser reads the headers and applies the rules

```mermaid
sequenceDiagram
    participant Б as Browser
    participant D as Django (SecurityMiddleware)

    Б->>D: GET /notes/
    D-->>Б: HTTP/1.1 200 OK
    Note over D,Б: X-Frame-Options: DENY<br/>X-Content-Type-Options: nosniff<br/>Strict-Transport-Security: max-age=31536000<br/>Referrer-Policy: same-origin
    
    Note over Б: The browser applies the rules:<br/>— Won't load this page in an iframe<br/>— Won't guess the MIME type of files<br/>— Will always use HTTPS<br/>— Won't send the Referer to external sites
```

### A detailed breakdown of each header

**`X-Frame-Options: DENY`** — protection against Clickjacking

```
A Clickjacking attack:
1. The attacker places your site in a hidden <iframe> on evil.com
2. On top of the iframe — fake buttons ("Click here to get a prize!")
3. The user "clicks the prize" — but actually clicks your site's "Delete account" button

Protection X-Frame-Options: DENY → the browser refuses to load the page in an <iframe>
```

```python
# settings.py:
X_FRAME_OPTIONS = 'DENY'          # Forbids any iframe
# or:
X_FRAME_OPTIONS = 'SAMEORIGIN'    # Allows an iframe only from the same domain
```

**`X-Content-Type-Options: nosniff`** — protection against MIME sniffing

```
The attack:
1. The attacker uploads a file "photo.jpg" that is actually JavaScript
2. The browser "sniffs" the content and says: "Looks like JS, I'll run it as a script!"
3. An XSS attack through the uploaded file

Protection nosniff → the browser always uses the Content-Type from the header, never "guesses"
```

**`Strict-Transport-Security: max-age=31536000`** — forced HTTPS

```
An SSL Stripping attack:
1. The user types "mybank.com" (without https://)
2. An attacker "in the middle" intercepts and sets up an HTTP connection with the user
3. Passwords are transmitted in plain text

Protection HSTS → after the first HTTPS visit the browser ALWAYS uses HTTPS
              and doesn't accept an HTTP response even if the server sends one
```

**`Content-Security-Policy`** — protection against XSS

```
Without CSP:
  The attacker injects <script src="evil.com/steal.js"> → the browser loads and runs it

With CSP: default-src 'self':
  The browser loads scripts ONLY from the current domain → evil.com/steal.js is blocked
```

```python
# settings.py — all the security headers:
SECURE_CONTENT_TYPE_NOSNIFF = True          # nosniff
X_FRAME_OPTIONS = 'DENY'                    # clickjacking
SECURE_REFERRER_POLICY = 'same-origin'      # the URL doesn't leak via the Referer header

# Production HTTPS (uncomment once you have SSL):
# SECURE_SSL_REDIRECT = True                # HTTP → HTTPS redirect
# SECURE_HSTS_SECONDS = 31536000            # HSTS for 1 year
# SECURE_HSTS_INCLUDE_SUBDOMAINS = True     # applies to subdomains
# SESSION_COOKIE_SECURE = True              # sessionid over HTTPS only
# CSRF_COOKIE_SECURE = True                 # csrftoken over HTTPS only
```

### Checking with the Django check command

```bash
python manage.py check --deploy

# Example output:
# WARNINGS:
# ?: (security.W004) You have not set SESSION_COOKIE_SECURE to True.
# ?: (security.W008) Your SECRET_KEY has less than 50 characters.
# ?: (security.W012) SESSION_COOKIE_HTTPONLY is not set to True.
# ?: (security.W018) You should not have DEBUG set to True in deployment.
#
# Every warning is a specific vulnerability!
```

---

## 12. Pre-deployment checklist

### Category 1: Core settings

```python
# settings.py:
DEBUG = False                               # ❌ Never True in production

SECRET_KEY = os.environ['SECRET_KEY']       # ❌ Not a hardcoded string
# How to generate a new SECRET_KEY:
# python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

ALLOWED_HOSTS = ['mysite.com', 'www.mysite.com']  # ❌ Not ['*']
```

### Category 2: HTTPS

```python
# Uncomment after installing the SSL certificate:
SECURE_SSL_REDIRECT = True           # HTTP → HTTPS
SESSION_COOKIE_SECURE = True         # Cookie over HTTPS only
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000       # The browser remembers HTTPS for 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
```

### Category 3: Database

```bash
# A separate DB user with minimal rights (not postgres!):
# CREATE USER django_user WITH PASSWORD 'strongpassword';
# GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO django_user;
```

### Category 4: Secrets

```bash
# The .env file — NOT in git:
git status             # .env doesn't appear in the list
cat .gitignore | grep env    # → .env  (present!)

# Check that secrets aren't in the git history:
git log --all --full-history -p -- settings.py | grep "SECRET_KEY ="
```

### Category 5: Dependencies

```bash
# Vulnerability check:
pip-audit                      # pip install pip-audit

# Check for outdated packages:
pip list --outdated

# Pinned versions in requirements.txt (not >=, but ==):
# Django==5.2.14
# django-crispy-forms==2.3.3
```

### Category 6: Django Security Check

```bash
python manage.py check --deploy
# It should show: System check identified no issues (0 silenced).
# If there are WARNINGS, these are real vulnerabilities!
```

### Category 7: Logging

```python
# settings.py — basic logging for production:
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'class': 'logging.FileHandler',
            'filename': '/var/log/django/security.log',
        },
    },
    'loggers': {
        'django.security': {
            'handlers': ['file'],
            'level': 'WARNING',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': False,
        },
    },
}
```

---

> **Summary:** Security isn't a single `@login_required`. It's **layers**: settings,
> hashing, CSRF, headers, minimal privileges, monitoring. Every layer matters.
> Skip one and an attacker will find it.
