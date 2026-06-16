# Nginx

> **Nginx як reverse proxy:** браузер не підключається до Uvicorn напряму.
> Nginx приймає з'єднання, термінує SSL, роздає статику, проксує решту.

---

## Архітектура nginx у цьому стеку

```
Браузер → nginx:80 → routing:

  GET /static/css/main.css
    → alias /staticfiles/css/main.css   ← з тома, без Django
    → 200 з Cache-Control: max-age=604800

  GET /notes/
    → proxy_pass http://web:8001/notes/  ← HTTP до Uvicorn
    → Django view → HTML → nginx → браузер

  WebSocket UPGRADE /ws/groups/7/chat/
    → proxy_http_version 1.1
    → proxy_set_header Upgrade $http_upgrade    ← ОБОВ'ЯЗКОВО!
    → proxy_set_header Connection $connection_upgrade
    → proxy_pass http://web:8001/ws/groups/7/chat/
    → Uvicorn ASGI → GroupChatConsumer → persistent
```

---

## nginx.conf — повний з коментарями

```nginx
worker_processes auto;   # auto = кількість CPU cores
# 2 cores → 2 worker processes

events {
    worker_connections 1024;   # одночасних з'єднань на один worker process
    # 2 cores × 1024 = 2048 одночасних з'єднань
}

http {
    include /etc/nginx/mime.types;   # .css → text/css, .js → application/javascript

    # ── WebSocket Upgrade handling ────────────────────────────────────────────
    # $http_upgrade = заголовок "Upgrade" від браузера ("websocket" або "")
    # Якщо браузер надсилає Upgrade: websocket → $connection_upgrade = "upgrade"
    # Якщо звичайний HTTP запит (Upgrade = "") → $connection_upgrade = "close"
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    # ── Upstream: Django/Uvicorn ──────────────────────────────────────────────
    upstream django {
        server web:8001;   # "web" — DNS ім'я сервісу в Docker network app-net
        # Можна додати кілька: server web2:8001; → load balancing
    }

    server {
        listen 80;
        # У production: listen 443 ssl; + ssl_certificate

        client_max_body_size 10M;   # максимальний розмір upload (форми з файлами)

        # ── Статичні файли (nginx роздає напряму) ────────────────────────────
        location /static/ {
            alias /staticfiles/;   # volume з collectstatic (web → nginx)
            expires 7d;            # браузер кешує 7 днів
            add_header Cache-Control "public, immutable";
            # "immutable": браузер не перевіряє freshness (файли мають hash в іменах)
        }

        # ── Все інше → Uvicorn ───────────────────────────────────────────────
        location / {
            proxy_pass http://django;

            # Реальний IP клієнта (Django бачить nginx IP без цих заголовків):
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # ── WEBSOCKET UPGRADE (критично!) ─────────────────────────────
            proxy_http_version 1.1;
            # ↑ WebSocket вимагає HTTP/1.1 (connection keep-alive)
            # Без цього nginx downgrade до HTTP/1.0 → Upgrade заголовки ігноруються
            # → WS handshake fails → браузер отримує 400 або 101 а потім одразу close

            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # ↑ Передаємо Upgrade: websocket і Connection: upgrade до Uvicorn
            # Uvicorn бачить ці заголовки → перемикає протокол → ASGI WS scope

            proxy_read_timeout 300s;    # WS-з'єднання може жити 5 хвилин без активності
            proxy_connect_timeout 75s;  # ліміт на встановлення з'єднання до upstream
            proxy_send_timeout 300s;    # ліміт на відправку відповіді клієнту
        }
    }
}
```

---

## Як staticfiles потрапляє до nginx

```
1. Dockerfile COPY . .
   → весь проєкт у /app/

2. entrypoint.sh:
   python manage.py collectstatic --noinput
   → Django збирає всі static файли в STATIC_ROOT (/app/staticfiles/)
   → CSS з crispy_forms, JS, admin, icons — все в одному місці

3. docker-compose.yml:
   web:   volumes: - staticfiles:/app/staticfiles   ← web WRITES here
   nginx: volumes: - staticfiles:/staticfiles:ro    ← nginx READS here (read-only!)

4. nginx.conf:
   location /static/ { alias /staticfiles/; }      ← nginx → volume → файл

→ GET /static/admin/css/base.css
  → nginx → /staticfiles/admin/css/base.css
  → 200 без Python!
```

### STATIC_ROOT у settings.py

```python
# settings.py
STATIC_URL = '/static/'

# collectstatic копіює всі static files сюди:
STATIC_ROOT = BASE_DIR / 'staticfiles'   # /app/staticfiles

# Де Django шукає static files (окрім <app>/static/):
STATICFILES_DIRS = []  # Django знаходить <app>/static/ автоматично
```

### Без nginx vs з nginx

```
Без nginx:
  Browser → Django/Uvicorn → читає CSS/JS з disk → повертає
  Python process задіяний для кожного статичного файлу

З nginx:
  Browser → nginx → читає CSS/JS з disk напряму → повертає
  Django/Uvicorn не задіяний взагалі

Nginx роздає статику у 5–10x швидше і звільняє Python workers
для обробки реальних запитів.
```

---

## WebSocket проксі — чому потрібен HTTP/1.1

```
HTTP/1.0: кожен запит = нове з'єднання
HTTP/1.1: keepalive — з'єднання залишається відкритим

WebSocket Upgrade handshake:
  GET /ws/groups/7/chat/ HTTP/1.1  ← ОБОВ'ЯЗКОВО 1.1
  Upgrade: websocket
  Connection: Upgrade

Якщо nginx проксює як HTTP/1.0:
  Upgrade заголовок ігнорується
  → handshake не проходить
  → WS з'єднання не встановлюється
  → браузер отримує 400 або 404
```

`proxy_http_version 1.1` у `location /` — обов'язкова директива для WebSocket підтримки.

---

## Nginx у production (з SSL)

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

## Читання логів nginx

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          IP клієнта    Час                             Метод+URL     Статус  Байти

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (браузер використовує кеш)
```

```bash
# Переглянути логи nginx:
docker compose logs nginx

# Слідкувати у реальному часі:
docker compose logs -f nginx

# Перевірити nginx конфіг:
docker compose exec nginx nginx -t

# Перезапустити nginx (після зміни nginx.conf):
docker compose restart nginx

# Тест upstream з середини nginx контейнера:
docker compose exec nginx curl -I http://web:8001/accounts/login/

---

## У книзі

- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — nginx, reverse proxy, статичні файли, HTTP headers, SSL/TLS
- [Частина XI. Deployment](../../11_deployment/README.md) — production стек, nginx + Uvicorn, WebSocket через proxy

---

## Офіційна документація

- [nginx: Reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) — proxy_pass, upstream, headers
- [nginx: WebSocket proxying](https://nginx.org/en/docs/http/websocket.html) — `Upgrade`, `Connection` headers, HTTP/1.1
- [nginx: Static files](https://docs.nginx.com/nginx/admin-guide/web-server/serving-static-content/) — `location`, `alias`, `expires`
- [MDN: HTTP/1.1 Upgrade mechanism](https://developer.mozilla.org/en-US/docs/Web/HTTP/Protocol_upgrade_mechanism) — як відбувається WebSocket handshake
- [MDN: Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) — `public`, `immutable`, `max-age`
```
