# Lifecycle: From URL to Page

> What happens between the moment a student presses Enter in the address bar
> and the moment they see the page with their notes?
> These 8 steps are the foundation for every web developer.

---

## The full map

```
The student types: http://localhost/notes/

  1. DNS lookup
     localhost → 127.0.0.1 (loopback)

  2. TCP connection
     browser → 127.0.0.1:80 (three-way handshake)

  3. (HTTPS) TLS handshake
     certificate exchange, session encryption
     (skipped on localhost)

  4. The HTTP Request is sent
     GET /notes/ HTTP/1.1
     Host: localhost
     Cookie: sessionid=abc123

  5. nginx receives the request
     → proxies it to uvicorn :8001

  6. The Django ASGI stack processes it
     Middleware → URL routing → View → Selector → DB → Template

  7. The HTTP Response is sent
     200 OK + Content-Type: text/html + HTML body

  8. The browser renders the HTML
     CSS → DOM → CSSOM → Layout → Paint
     + additional requests for CSS/JS/images
```

---

## Step 1: DNS lookup

**DNS** (Domain Name System) is the phone book of the internet: it turns a domain name into an IP address.

```
The browser looks up the IP for "localhost" in this order:
  1. Browser cache (have we asked this before?)
  2. OS cache
  3. The /etc/hosts file ← localhost → 127.0.0.1 is ALWAYS here
  4. DNS server (if nothing above found it)
```

For `localhost` the DNS server is never queried — `/etc/hosts` always answers:

```bash
cat /etc/hosts
# 127.0.0.1  localhost
```

For a real domain (`notes.example.com`):
```
Browser → DNS resolver (8.8.8.8) → Root nameserver → .com nameserver → example.com nameserver
→ answer: 203.0.113.1
```

**Time:** 0–50 ms for cached domains, 50–300 ms for new ones.

---

## Step 2: TCP connection

**TCP** is a protocol for reliable data delivery. Before the first byte of HTTP there is a three-way handshake:

```
Browser → Server: SYN (I want to connect)
Browser ← Server: SYN-ACK (accepted, go ahead and connect)
Browser → Server: ACK (confirmed)
← connection established →
```

**Time:** 1 RTT (round-trip time) — ~0 ms for localhost, 50–200 ms for a server abroad.

**HTTP/1.1 Keep-Alive:** after connecting, the browser does not close the socket — it sends the next request over the same connection. This saves the time of new TCP handshakes for CSS/JS/images.

---

## Step 3: (HTTPS) TLS handshake

For `https://`, a TLS handshake is added after TCP:

```
Browser → Server: ClientHello (I support TLS 1.3, list of cipher suites, key_share)
Browser ← Server: ServerHello (chosen cipher, key_share), Certificate, CertificateVerify, Finished
Browser: Verifies the certificate against the local store of trusted CAs
Browser → Server: Finished (the shared secret is already derived via Diffie-Hellman)
← encrypted channel established →
```

TLS 1.2 uses a different exchange: the server ends its part with a `ServerHelloDone` message and the client sends `ClientKeyExchange`, which is why it needs an extra round trip.

**Time:** 1 RTT (TLS 1.3) or 2 RTT (TLS 1.2).

For `localhost` without TLS: step 3 is skipped and the connection is unprotected. In production, nginx or a CDN terminates TLS and passes HTTP on to uvicorn.

---

## Step 4: HTTP Request

The browser sends an HTTP request over the established connection:

```
GET /notes/ HTTP/1.1
Host: localhost
Accept: text/html,application/xhtml+xml,*/*;q=0.9
Accept-Language: uk,en-US;q=0.7,en;q=0.3
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Cookie: sessionid=abc123; csrftoken=xyz456
Cache-Control: max-age=0
```

**Every header means something:**
- `Accept:` — the browser says "I understand HTML and a few other formats"
- `Accept-Encoding: gzip` — "compress the response, I'll unpack it"
- `Cookie:` — the session cookie and CSRF token for every request
- `Cache-Control: max-age=0` — "don't serve from cache, give me a fresh one"

---

## Step 5: nginx receives the request

In production (or in the Docker stack), nginx sits between the browser and Django:

```
Browser :80 → nginx → uvicorn :8001 → Django
                ↓
          staticfiles/    ← nginx handles these itself, without Django
```

Configuration in `nginx/nginx.conf`:

```nginx
location / {
    proxy_pass http://web:8001;       # → uvicorn
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;  # Django sees the real IP
}

location /static/ {
    alias /staticfiles/;  # nginx by itself, without Django
}
```

**Why put nginx in front of Django?**
- Static files without loading Python
- SSL termination (TLS decryption) — Django does not know about TLS
- Buffering requests from slow clients
- Rate limiting and security headers

---

## Step 6: The Django ASGI stack

The request reaches Django and passes through several layers:

### 6.1 ASGI entry

```python
# notes_project/asgi.py
application = ProtocolTypeRouter({
    'http': django_asgi_app,      # ← the HTTP request goes here
    'websocket': ...
})
```

### 6.2 The middleware chain

Each middleware can modify the request or intercept the response:

```python
# settings.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',    # HTTP → HTTPS redirect, HSTS
    'debug_toolbar.middleware.DebugToolbarMiddleware',  # Django Debug Toolbar (dev)
    'django.contrib.sessions.middleware.SessionMiddleware',  # session cookie → request.session
    'django.middleware.common.CommonMiddleware',        # trailing slash redirect
    'django.middleware.csrf.CsrfViewMiddleware',        # ← CHECKS THE CSRF TOKEN
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # ← request.user
    'django.contrib.messages.middleware.MessageMiddleware',  # messages framework
    ...
]
```

Middleware runs in REVERSE order for the response:

```
Request  → SecurityMW → SessionMW → CsrfMW → AuthMW → View
Response ← SecurityMW ← SessionMW ← CsrfMW ← AuthMW ← View
```

### 6.3 URL routing

Django finds which function handles this URL:

```python
# notes_project/urls.py
urlpatterns = [
    path('', include('notes_app.urls', namespace='notes_app')),
    path('admin/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),
]

# notes_app/urls.py
urlpatterns = [
    path('notes/', views.note_list, name='note_list'),    # ← /notes/ → here
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    ...
]
```

### 6.4 The view function

```python
# notes_app/views.py
@login_required
def note_list(request):
    # If not logged in, AuthenticationMiddleware has already set request.user = AnonymousUser
    # @login_required will redirect to /accounts/login/

    # Selector: reading from the DB
    notes = selectors.get_user_notes(user=request.user)

    # Template rendering
    return render(request, 'notes_app/note_list.html', {
        'notes': notes,
    })
```

### 6.5 Database query

```python
# notes_app/selectors.py
def get_user_notes(user):
    user_groups = user.groups.all()
    return Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups)
    ).select_related('user', 'notebook').prefetch_related('tags').order_by('-updated_at')
```

The SQL that runs:
```sql
SELECT notes.*, auth_user.*, notebooks.*
FROM notes_app_note notes
JOIN auth_user ON notes.user_id = auth_user.id
LEFT JOIN notes_app_notebook notebooks ON notes.notebook_id = notebooks.id
WHERE notes.user_id = 1 OR notes.group_id IN (1, 3)
ORDER BY notes.updated_at DESC;
```

### 6.6 Template rendering

Django compiles the template and fills in the context:

```html
<!-- notes_app/templates/notes_app/note_list.html -->
{% extends 'base.html' %}
{% block content %}
{% for note in notes %}
  <div class="card">{{ note.title }}</div>
{% endfor %}
{% endblock %}
```

The result is a string of HTML.

---

## Step 7: HTTP Response

Django returns:

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: same-origin
Content-Length: 15234

<!DOCTYPE html>
<html lang="uk">
<head>
  <title>Мої нотатки</title>
  ...
```

The middleware chain adds security headers on the way out.

---

## Step 8: The browser renders the HTML

The browser has received the HTML and starts building the page:

```
1. HTML parsing → DOM tree
   <html> → <head> → <body> → <div class="card"> ...

2. CSS request (encountered <link rel="stylesheet">)
   GET /static/notes_app/css/style.css
   GET /static/vendor/bootstrap.min.css
   → CSSOM tree

3. JavaScript request (encountered <script src="...">)
   GET /static/notes_app/js/group_chat.js
   → JavaScript execution

4. Layout (Reflow)
   The browser computes the position of every element

5. Paint
   Pixels on the screen

6. Composite
   Layers are combined (GPU)
```

**These additional requests** (CSS, JS, images) each go through steps 1–7 (DNS cached, TCP keep-alive, nginx → staticfiles without Django).

---

## What Django sees vs. the browser

| | Browser | Django |
|---|---------|--------|
| Protocol | HTTP/2 or HTTP/1.1 | always HTTP/1.1 (nginx translates) |
| Address | `http://localhost/notes/` | `/notes/` in `request.path` |
| Client IP | its own | the `X-Real-IP` header from nginx |
| TLS | sees HTTPS | does not know (nginx terminates it) |
| Compression | gzip/br | response without compression (nginx compresses) |

---

## WebSocket lifecycle (for reference)

```
Browser → nginx → Django (Channels) → GroupChatConsumer

Differences:
- Protocol: ws:// or wss://
- TCP connection: opens and STAYS open
- Upgrade header:  Connection: Upgrade, Upgrade: websocket
- After that: binary frames instead of text HTTP
```

In detail: [Part IX. Async and Realtime](../09_async_and_realtime/README.md)

---

## DevTools Network tab: seeing the lifecycle

```
F12 → Network → reload the page

What you will see:
  Timing (first request):
    Stalled:            0 ms   (waiting in queue)
    DNS Lookup:         0 ms   (localhost = cache)
    Initial connection: 0 ms   (loopback)
    Request sent:       0 ms
    Waiting (TTFB):    50 ms  ← Django processing time
    Content Download:   5 ms

  Initiator:
    notes_app/css/style.css    ← browser.html parser
    bootstrap.min.css          ← browser.html parser
    group_chat.js              ← browser.html parser
```

**TTFB** (Time to First Byte) is the most important backend metric: the time from sending the request to the first byte of the response. It is Django's working time (including DB queries).

---

## Where in notes_chat_app

| Lifecycle step | File |
|---------------|------|
| nginx config | `nginx/nginx.conf` |
| ASGI router | `notes_project/asgi.py` |
| Middleware | `notes_project/settings.py` → `MIDDLEWARE` |
| URL routing | `notes_project/urls.py`, `notes_app/urls.py` |
| View | `notes_app/views.py` |
| DB query | `notes_app/selectors.py` |
| Template | `notes_app/templates/notes_app/*.html` |
| Static files | `notes_app/static/` → `staticfiles/` (after collectstatic) |

---

## In the book

- [HTTP and HTTPS](http_https.md) — anatomy of an HTTP request and response
- [Network foundation](network_foundation_full.md) — TCP/IP, DNS, HTTP in detail
- [Part II. Django Core](../02_django_core/README.md) — Middleware, URL routing, MTV
- [Step 9. Deployment → nginx](../tutorials/09_deployment/nginx.md) — nginx configuration

---

## Official documentation

- [MDN: How browsers work](https://developer.mozilla.org/en-US/docs/Web/Performance/How_browsers_work) — rendering in detail
- [MDN: DNS](https://developer.mozilla.org/en-US/docs/Learn/Common_questions/Web_mechanics/What_is_a_domain_name) — domains and DNS
- [Django: Request and response](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest API
- [Django: Middleware](https://docs.djangoproject.com/en/5.2/topics/http/middleware/) — writing middleware and its order
- [nginx: proxy_pass](http://nginx.org/en/docs/http/ngx_http_proxy_module.html) — proxy configuration
