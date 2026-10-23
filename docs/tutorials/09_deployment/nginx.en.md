# Nginx

> **Nginx as a reverse proxy:** the browser does not connect to Uvicorn directly.
> Nginx accepts the connection, terminates SSL, serves static files, and proxies everything else.

---

## Nginx architecture in this stack

```
Browser → nginx:80 → routing:

  GET /static/css/main.css
    → alias /staticfiles/css/main.css   ← from the volume, without Django
    → 200 with Cache-Control: max-age=604800

  GET /notes/
    → proxy_pass http://web:8001/notes/  ← HTTP to Uvicorn
    → Django view → HTML → nginx → browser

  WebSocket UPGRADE /ws/groups/7/chat/
    → proxy_http_version 1.1
    → proxy_set_header Upgrade $http_upgrade    ← REQUIRED!
    → proxy_set_header Connection $connection_upgrade
    → proxy_pass http://web:8001/ws/groups/7/chat/
    → Uvicorn ASGI → GroupChatConsumer → persistent
```

---

## nginx.conf — complete, with comments

```nginx
worker_processes auto;   # auto = number of CPU cores
# 2 cores → 2 worker processes

events {
    worker_connections 1024;   # simultaneous connections per worker process
    # 2 cores × 1024 = 2048 simultaneous connections
}

http {
    include /etc/nginx/mime.types;   # .css → text/css, .js → application/javascript

    # ── WebSocket Upgrade handling ────────────────────────────────────────────
    # $http_upgrade = the "Upgrade" header from the browser ("websocket" or "")
    # If the browser sends Upgrade: websocket → $connection_upgrade = "upgrade"
    # If it is a regular HTTP request (Upgrade = "") → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ── Upstream: Django/Uvicorn ──────────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — DNS name of the service in the Docker network app-net
        # You can add several: server web2:8001; → load balancing
    }

    server {
        listen 80;
        # In production: listen 443 ssl; + ssl_certificate

        client_max_body_size 10M;   # maximum upload size (forms with files)

        # ── Static files (nginx serves them directly) ────────────────────────
        location /static/ {
            alias /staticfiles/;   # volume from collectstatic (web → nginx)
            expires 7d;            # the browser caches for 7 days
            add_header Cache-Control "public, immutable";
            # "immutable": the browser does not check freshness (files have a hash in their names)
        }

        # ── Everything else → Uvicorn ────────────────────────────────────────
        location / {
            proxy_pass http://django;

            # The client's real IP (without these headers Django sees the nginx IP):
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (critical!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WebSocket requires HTTP/1.1 (connection keep-alive)
            # Without this nginx downgrades to HTTP/1.0 → Upgrade headers are ignored
            # → WS handshake fails → the browser gets 400, or 101 followed immediately by close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ We pass Upgrade: websocket and Connection: upgrade on to Uvicorn
            # Uvicorn sees these headers → switches protocol → ASGI WS scope

            proxy_read_timeout 300s;    # a WS connection may live 5 minutes without activity
            proxy_connect_timeout 75s;  # limit for establishing a connection to the upstream
            proxy_send_timeout 300s;    # limit for sending the response to the client
        }
    }
}
```

---

## How staticfiles gets to nginx

```
1. Dockerfile COPY . .
   → the whole project in /app/

2. entrypoint.sh:
   python manage.py collectstatic --noinput
   → Django collects all static files into STATIC_ROOT (/app/staticfiles/)
   → CSS from crispy_forms, JS, admin, icons — all in one place

3. docker-compose.yml:
   web:   volumes: - staticfiles:/app/staticfiles   ← web WRITES here
   nginx: volumes: - staticfiles:/staticfiles:ro    ← nginx READS here (read-only!)

4. nginx.conf:
   location /static/ { alias /staticfiles/; }      ← nginx → volume → file

→ GET /static/admin/css/base.css
  → nginx → /staticfiles/admin/css/base.css
  → 200 without Python!
```

### STATIC_ROOT in settings.py

```python
# settings.py
STATIC_URL = '/static/'

# collectstatic copies all static files here:
STATIC_ROOT = BASE_DIR / 'staticfiles'   # /app/staticfiles

# Where Django looks for static files (besides <app>/static/):
STATICFILES_DIRS = []  # Django finds <app>/static/ automatically
```

### Without nginx vs with nginx

```
Without nginx:
  Browser → Django/Uvicorn → reads CSS/JS from disk → returns it
  A Python process is involved for every static file

With nginx:
  Browser → nginx → reads CSS/JS from disk directly → returns it
  Django/Uvicorn is not involved at all

Nginx serves static files 5–10x faster and frees Python workers
to handle real requests.
```

---

## WebSocket proxy — why HTTP/1.1 is needed

```
HTTP/1.0: every request = a new connection
HTTP/1.1: keepalive — the connection stays open

WebSocket Upgrade handshake:
  GET /ws/groups/7/chat/ HTTP/1.1  ← 1.1 is REQUIRED
  Upgrade: websocket
  Connection: Upgrade

If nginx proxies as HTTP/1.0:
  the Upgrade header is ignored
  → the handshake fails
  → the WS connection is not established
  → the browser gets 400 or 404
```

`proxy_http_version 1.1` in `location /` is a mandatory directive for WebSocket support.

---

## Nginx in production (with SSL)

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /static/ {
        alias /staticfiles/;
        expires 7d;
    }

    location / {
        proxy_pass http://django;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;  # HTTP → HTTPS redirect
}
```

---

## Reading nginx logs

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          Client IP     Time                            Method+URL    Status  Bytes

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (the browser uses its cache)
```

```bash
# View nginx logs:
docker compose logs nginx

# Follow in real time:
docker compose logs -f nginx

# Check the nginx config:
docker compose exec nginx nginx -t

# Restart nginx (after changing nginx.conf):
docker compose restart nginx

# Test the upstream from inside the nginx container:
docker compose exec nginx curl -I http://web:8001/accounts/login/
```

---

## In the book

- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — nginx, reverse proxy, static files, HTTP headers, SSL/TLS
- [Part XI. Deployment](../../11_deployment/README.md) — production stack, nginx + Uvicorn, WebSocket through a proxy

---

## Official documentation

- [nginx: Reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) — proxy_pass, upstream, headers
- [nginx: WebSocket proxying](https://nginx.org/en/docs/http/websocket.html) — `Upgrade`, `Connection` headers, HTTP/1.1
- [nginx: Static files](https://docs.nginx.com/nginx/admin-guide/web-server/serving-static-content/) — `location`, `alias`, `expires`
- [MDN: HTTP/1.1 Upgrade mechanism](https://developer.mozilla.org/en-US/docs/Web/HTTP/Protocol_upgrade_mechanism) — how the WebSocket handshake happens
- [MDN: Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) — `public`, `immutable`, `max-age`
