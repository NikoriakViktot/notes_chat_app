# HTTP and HTTPS

> HTTP is the language the browser uses to talk to the server.
> Django is the "translator" on the server side: it understands HTTP and replies in HTTP too.

---

## Why understand HTTP

When you write this in `notes_app/views.py`:

```python
def note_create(request):
    if request.method == 'POST':
        ...
```

— you are already using HTTP. `request.method` is the string `'GET'` or `'POST'` that came from the browser. Without understanding HTTP, you cannot understand where it comes from or why a form is not saving.

---

## Anatomy of an HTTP request

An HTTP request is just text with a particular structure:

```
POST /notes/new/ HTTP/1.1          ← request line: method + path + version
Host: localhost                     ← required header (which server?)
Content-Type: application/x-www-form-urlencoded
Content-Length: 52
Cookie: sessionid=abc123; csrftoken=xyz456
                                    ← empty line = end of headers
title=First+note&priority=2        ← request body (only in POST, PUT, PATCH)
```

**The three parts of a request:**

| Part | Where in Django |
|---------|------------|
| Request line (`POST /notes/new/`) | `request.method`, `request.path` |
| Headers (`Host`, `Cookie`...) | `request.headers`, `request.META` |
| Body (POST/PUT only) | `request.POST` (forms) or `request.body` (JSON) |

---

## Anatomy of an HTTP response

```
HTTP/1.1 302 Found                  ← status line: version + status
Location: /notes/42/                ← header: where to redirect
Content-Type: text/html             ← content type
Set-Cookie: sessionid=new_val       ← set a cookie
                                    ← empty line
<!-- response body (HTML or JSON) -->
```

In Django:
- `return render(request, 'template.html', context)` → 200 OK + HTML body
- `return redirect('notes_app:note_list')` → 302 Found + Location header
- `raise Http404` → 404 Not Found

---

## HTTP methods — why there are different ones

```
GET  /notes/           → get the list (read-only, no body)
GET  /notes/42/        → get a specific note
POST /notes/new/       → create a note (data in the request body)
POST /notes/42/delete/ → delete (Django FBVs often use POST for dangerous actions)
```

**Key properties:**

| Method | Has a body? | Safe? | Idempotent? |
|-------|-----------|------------|----------------|
| GET | No | Yes | Yes |
| POST | Yes | No | No |
| PUT | Yes | No | Yes |
| DELETE | No | No | Yes |

**Safe** = does not change the server's state (GET only reads).  
**Idempotent** = repeating the request gives the same result (DELETE twice = the same as DELETE once).

!!! note "Why do HTML forms only support GET and POST?"
    The HTML 4 specification allowed only GET and POST for `<form>`. PUT and DELETE came into use in REST APIs via JavaScript (fetch/axios). The Django FBVs in notes_chat_app use POST for all mutations.

---

## Status codes — what they mean

```
2xx — Success
  200 OK             → a normal response (GET)
  201 Created        → created (REST API)

3xx — Redirection
  301 Moved Permanently  → the URL changed permanently (cached by the browser!)
  302 Found              → temporary redirect (PRG pattern after POST)
  304 Not Modified       → the resource has not changed, use the browser cache

4xx — Client error
  400 Bad Request        → invalid request
  403 Forbidden          → no access (it is known to exist)
  404 Not Found          → not found (or IDOR protection)
  405 Method Not Allowed → wrong HTTP method
  422 Unprocessable      → form failed validation (REST API)

5xx — Server error
  500 Internal Server Error → Python exception (check the logs!)
  503 Service Unavailable   → server unavailable (deploy in progress?)
```

Django automatically returns:
- `404` — if the URL is not found in `urls.py` or on `raise Http404`
- `403` — if the CSRF token is wrong or on `PermissionDenied`
- `500` — if there is an unhandled exception in a view (with `DEBUG=False`)

---

## The PRG pattern — why redirect after POST

**The problem without PRG:**

```
POST /notes/new/  → the server saved the note → render 200 OK HTML
The student presses F5 (reload the page)
Browser: "Resend the POST request?"
Student: "Yes"
→ The note is created a SECOND time. A duplicate!
```

**With PRG (Post/Redirect/Get):**

```
POST /notes/new/  → the server saved it → redirect 302 → /notes/42/
The browser automatically does: GET /notes/42/ → render 200 OK HTML
F5 → repeats GET /notes/42/ → safe, it just reloads the page
```

```python
# views.py — the PRG pattern
@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(...)
            return redirect('notes_app:note_detail', pk=note.pk)  # ← REDIRECT!
    else:
        form = NoteForm(user=request.user)
    return render(request, 'notes_app/note_form.html', {'form': form})
```

---

## HTTP headers that Django uses

```
From the browser to Django:
  Host: localhost              → request.META['HTTP_HOST']
  Cookie: sessionid=abc123    → request.COOKIES['sessionid']
  Accept: text/html,...       → request.META['HTTP_ACCEPT']
  X-CSRFToken: xyz            → checked by CsrfViewMiddleware
  Content-Type: ...           → request.content_type

From Django to the browser:
  Content-Type: text/html     → response type (HTML, JSON, PDF...)
  Set-Cookie: sessionid=...   → set the session cookie
  Location: /notes/42/        → where to redirect (with 302)
  X-Frame-Options: DENY       → forbid iframes (Clickjacking protection)
```

---

## HTTPS — TLS on top of HTTP

HTTP transmits data as plain text. Without HTTPS:

```
Network → An attacker sees:
  Cookie: sessionid=abc123
  → logs in to your account without a password!
```

HTTPS = HTTP + TLS encryption:

```
Browser ←──TLS──→ Server
         ↑
  The data is encrypted:
  Cookie: ????XSK##$@!  (unreadable without the key)
```

**TLS handshake** (happens before the first HTTP request):
1. Browser → Server: "I support TLS 1.3, here are my cipher suites and key share" (ClientHello)
2. Server → Browser: ServerHello + key share, "Certificate (signed by a CA), public key"
3. Browser: Verifies the certificate against the system CA store
4. Both sides have already derived the shared secret from the key shares (Diffie-Hellman); Browser → Server: Finished
5. From then on: all HTTP requests and responses are encrypted

**Why `Session Cookie Secure = True` in production:**

```python
# settings.py
SESSION_COOKIE_SECURE = True   # the cookie is sent only over HTTPS
# Without this the cookie can be intercepted over HTTP (an HTTP → HTTPS redirect does not protect it!)
```

---

## Exploring HTTP in the browser

Open DevTools (F12) → the **Network** tab:

```
1. Open http://localhost/notes/
2. F12 → Network → All
3. Click the first request in the list
4. The "Headers" tab:
   Request URL: http://localhost/notes/
   Request Method: GET
   Status Code: 200 OK
   
   Response Headers:
     Content-Type: text/html; charset=utf-8
     X-Frame-Options: DENY
   
   Request Headers:
     Cookie: sessionid=...; csrftoken=...
```

Fill in the note form and click Submit — you will see a POST request with a 302 redirect.

---

## Where in notes_chat_app

| Concept | Where to find it |
|-----------|-----------|
| `request.method` | `notes_app/views.py` — every view |
| PRG pattern | `note_create`, `note_update`, `todo_create` in `views.py` |
| CSRF token | `{% csrf_token %}` in every form in `templates/` |
| Security headers | `notes_project/settings.py` — `X_FRAME_OPTIONS`, `SECURE_CONTENT_TYPE_NOSNIFF` |
| `SESSION_COOKIE_SECURE` | `settings.py` (commented out, enabled in production) |

---

## In the book

- [Network foundation](network_foundation_full.md) — HTTP in detail: all methods, statuses, cookie attributes, REST principles
- [Part VII. Auth and Security](../07_auth_and_security/README.md) — CSRF, XSS, session hijacking, HTTPS in production

---

## Official documentation

- [MDN: HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP) — the complete HTTP reference
- [MDN: HTTP request methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods) — all methods with examples
- [MDN: HTTP response status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) — all statuses
- [MDN: HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) — all headers
- [MDN: HTTPS](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security) — TLS/HTTPS
- [Django: Request and response objects](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest API
