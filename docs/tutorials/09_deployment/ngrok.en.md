# Ngrok

> **Why ngrok:** `localhost:80` is not reachable from the internet.
> ngrok creates a public HTTPS URL that tunnels to your nginx.

---

## How ngrok works

```
Browser on the Internet → ngrok servers → tunnel → Docker nginx → Django

Without ngrok:
  Django is available only on localhost — nobody else can reach it

With ngrok:
  ngrok provides a public URL: https://fawn-natural-mayfly.ngrok-free.app
  All traffic from the Internet → ngrok servers → your nginx:80
```

---

## ngrok in Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ "http" = HTTP tunnel (ngrok adds HTTPS on the client side)
  # --url: a fixed domain (requires ngrok Pro or a static domain)
  # nginx:80 = where to forward traffic (Docker internal DNS)
  environment:
    NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
  ports:
    - "4040:4040"   # ngrok web UI: inspect HTTP traffic
  depends_on:
    nginx: {condition: service_healthy}   # wait for nginx
  networks: [app-net]
```

The `.env` file:

```bash
NGROK_AUTHTOKEN=2abc123_your_real_token_here
NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app
```

You can get an `NGROK_AUTHTOKEN` and reserve a free static domain at [dashboard.ngrok.com](https://dashboard.ngrok.com).

---

## Problem: CSRF + ngrok

**Symptom:** you open `https://my-domain.ngrok-free.app/accounts/login/`, enter your credentials → `403 Forbidden: CSRF verification failed`.

**Cause:**

```
POST /accounts/login/ HTTP/1.1
Host: fawn-natural-mayfly.ngrok-free.app
Origin: https://fawn-natural-mayfly.ngrok-free.app
X-CSRFToken: abc123...

Django checks the Origin header:
  Is "https://fawn-natural-mayfly.ngrok-free.app" in CSRF_TRUSTED_ORIGINS?
  CSRF_TRUSTED_ORIGINS = []   ← empty → 403
```

**Solution in `settings.py`:**

```python
# settings.py
import os

_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')

CSRF_TRUSTED_ORIGINS = (
    [f'https://{_ngrok_domain}']
    if _ngrok_domain else []
)
# CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']

# The domain must also be allowed in ALLOWED_HOSTS:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
# + add the ngrok domain:
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

**In `docker-compose.yml`:**

```yaml
web:
  environment:
    NGROK_DOMAIN: ${NGROK_DOMAIN}   # pass it from .env into the container
```

### How the value is passed along

```
.env:
  NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

docker-compose.yml:
  web.environment.NGROK_DOMAIN: ${NGROK_DOMAIN}
  → passes it into the container

settings.py:
  _ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
  CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']
  ALLOWED_HOSTS += ['fawn-natural-mayfly.ngrok-free.app']

Django:
  POST /login/ → Origin check → trusted → 200 OK
```

---

## Problem: ERR_NGROK_8012 — no such host nginx

**Symptom:** ngrok starts, but shows `ERR_NGROK_8012: failed to connect to upstream: no such host nginx`.

**Cause:** the ngrok container cannot find nginx by its DNS name. Usually this is because there is no shared network.

**Solution: an explicit named network on ALL services:**

```yaml
# Solution: an explicit named network on ALL services
networks:
  app-net:
    driver: bridge

services:
  nginx:
    networks: [app-net]
  ngrok:
    networks: [app-net]   # ← both in app-net → DNS resolution of "nginx" ✓
```

Without an explicit named network, Docker may create separate automatic networks for different services, and they will not see each other by DNS name.

---

## Another problem: ERR_NGROK_334 — session limit

**Symptom:** `ERR_NGROK_334: session limit exceeded`.

**Cause:** ngrok is already running locally AND in Docker — one domain allows only one active connection.

```bash
# ❌ Error: ngrok is running both locally and in Docker
ngrok http --url=my-domain.ngrok-free.app 80 &   # locally
docker compose up                                  # ngrok in Docker
# → ERR_NGROK_334: session limit exceeded

# ✅ One way at a time:
# Option A: only through Docker (recommended)
docker compose up -d

# Option B: only locally
ngrok http --url=my-domain.ngrok-free.app 80
```

---

## ngrok dashboard

```
http://localhost:4040   ← ngrok web UI
```

It lets you:

- View all HTTP requests going through the tunnel in real time
- See request and response headers
- See the request body (JSON, forms)
- Replay requests (send the same POST again)
- Check the CSRF token in the cookie and the POST body

Useful for debugging CSRF: open Inspector → POST /accounts/login/

```
→ Cookies: csrftoken=<value>
→ Body: csrfmiddlewaretoken=<value>
→ Do they match?
```

---

## NGROK_DOMAIN and NGROK_AUTHTOKEN env vars

| Variable | Where to get it | Why |
|--------|----------|--------|
| `NGROK_AUTHTOKEN` | [dashboard.ngrok.com/authtokens](https://dashboard.ngrok.com/authtokens) | Authenticates the ngrok agent |
| `NGROK_DOMAIN` | [dashboard.ngrok.com/domains](https://dashboard.ngrok.com/domains) | A fixed public URL (1 free static domain per account) |

Without `NGROK_DOMAIN`, ngrok generates a random URL on every start. With `NGROK_DOMAIN` the URL is always the same — useful for `CSRF_TRUSTED_ORIGINS` in `settings.py`.

---

## In the book

- [Part VII. Auth and Security](../../07_auth_and_security/README.md) — CSRF protection, `CSRF_TRUSTED_ORIGINS`, Django's `Origin` header check
- [Part XI. Deployment](../../11_deployment/README.md) — public access, ngrok, reverse tunnel

---

## Official documentation

- [ngrok: Docker agent](https://ngrok.com/docs/using-ngrok-with/docker/) — running ngrok in Docker
- [ngrok: Static domains](https://ngrok.com/docs/network-edge/domains/) — free static domains
- [ngrok: Traffic Inspector](https://ngrok.com/docs/agent/web-inspection-interface/) — the dashboard on :4040
- [Django: CSRF_TRUSTED_ORIGINS](https://docs.djangoproject.com/en/5.2/ref/settings/#csrf-trusted-origins) — configuring trusted origins
- [Django: ALLOWED_HOSTS](https://docs.djangoproject.com/en/5.2/ref/settings/#allowed-hosts) — protection against Host header attacks
