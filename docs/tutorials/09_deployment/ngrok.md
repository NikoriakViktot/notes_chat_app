# Ngrok

> **Навіщо ngrok:** `localhost:80` недоступний з інтернету.
> ngrok створює публічний HTTPS URL що тунелює до твого nginx.

---

## Як ngrok працює

```
Браузер у Інтернеті → ngrok servers → тунель → Docker nginx → Django

Без ngrok:
  Django доступний тільки на localhost — ніхто інший не може зайти

З ngrok:
  ngrok надає публічний URL: https://fawn-natural-mayfly.ngrok-free.app
  Весь трафік з Інтернету → ngrok servers → твій nginx:80
```

---

## ngrok в Docker Compose

```yaml
ngrok:
  image: ngrok/ngrok:latest
  command: http --url=${NGROK_DOMAIN} nginx:80
  # ↑ "http" = HTTP тунель (ngrok додає HTTPS з боку клієнта)
  # --url: фіксований домен (потрібен ngrok Pro або static domain)
  # nginx:80 = куди перенаправляти трафік (Docker internal DNS)
  environment:
    NGROK_AUTHTOKEN: ${NGROK_AUTHTOKEN}
  ports:
    - "4040:4040"   # ngrok web UI: inspect HTTP traffic
  depends_on:
    nginx: {condition: service_healthy}   # чекаємо nginx
  networks: [app-net]
```

`.env` файл:

```bash
NGROK_AUTHTOKEN=2abc123_your_real_token_here
NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app
```

Отримати `NGROK_AUTHTOKEN` і зарезервувати безкоштовний static domain можна на [dashboard.ngrok.com](https://dashboard.ngrok.com).

---

## Проблема: CSRF + ngrok

**Симптом:** відкрив `https://my-domain.ngrok-free.app/accounts/login/`, ввів credentials → `403 Forbidden: CSRF verification failed`.

**Причина:**

```
POST /accounts/login/ HTTP/1.1
Host: fawn-natural-mayfly.ngrok-free.app
Origin: https://fawn-natural-mayfly.ngrok-free.app
X-CSRFToken: abc123...

Django перевіряє Origin header:
  Чи є "https://fawn-natural-mayfly.ngrok-free.app" у CSRF_TRUSTED_ORIGINS?
  CSRF_TRUSTED_ORIGINS = []   ← пусто → 403
```

**Рішення в `settings.py`:**

```python
# settings.py
import os

_ngrok_domain = os.environ.get('NGROK_DOMAIN', '')

CSRF_TRUSTED_ORIGINS = (
    [f'https://{_ngrok_domain}']
    if _ngrok_domain else []
)
# CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']

# Також треба дозволити домен в ALLOWED_HOSTS:
_allowed = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1')
ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',')]
# + додати ngrok домен:
if _ngrok_domain:
    ALLOWED_HOSTS.append(_ngrok_domain)
```

**В `docker-compose.yml`:**

```yaml
web:
  environment:
    NGROK_DOMAIN: ${NGROK_DOMAIN}   # передаємо з .env в контейнер
```

### Ланцюг передачі значення

```
.env:
  NGROK_DOMAIN=fawn-natural-mayfly.ngrok-free.app

docker-compose.yml:
  web.environment.NGROK_DOMAIN: ${NGROK_DOMAIN}
  → передає у контейнер

settings.py:
  _ngrok_domain = os.environ.get('NGROK_DOMAIN', '')
  CSRF_TRUSTED_ORIGINS = ['https://fawn-natural-mayfly.ngrok-free.app']
  ALLOWED_HOSTS += ['fawn-natural-mayfly.ngrok-free.app']

Django:
  POST /login/ → Origin check → trusted → 200 OK
```

---

## Проблема: ERR_NGROK_8012 — no such host nginx

**Симптом:** ngrok запускається, але показує `ERR_NGROK_8012: failed to connect to upstream: no such host nginx`.

**Причина:** ngrok контейнер не знаходить nginx за DNS ім'ям. Зазвичай через відсутність shared network.

**Рішення: явна named network у ВСІХ сервісів:**

```yaml
# Рішення: явна named network у ВСІХ сервісів
networks:
  app-net:
    driver: bridge

services:
  nginx:
    networks: [app-net]
  ngrok:
    networks: [app-net]   # ← обидва в app-net → DNS резолюція "nginx" ✓
```

Без явної named network Docker може створити окремі автоматичні мережі для різних сервісів, і вони не побачать один одного за DNS іменами.

---

## Інша проблема: ERR_NGROK_334 — session limit

**Симптом:** `ERR_NGROK_334: session limit exceeded`.

**Причина:** ngrok вже запущений локально І в Docker — один домен дозволяє тільки одне активне з'єднання.

```bash
# ❌ Помилка: ngrok запущений і локально і у Docker
ngrok http --url=my-domain.ngrok-free.app 80 &   # локально
docker compose up                                  # ngrok у Docker
# → ERR_NGROK_334: session limit exceeded

# ✅ Один спосіб за раз:
# Варіант A: тільки через Docker (рекомендовано)
docker compose up -d

# Варіант B: тільки локально
ngrok http --url=my-domain.ngrok-free.app 80
```

---

## ngrok dashboard

```
http://localhost:4040   ← ngrok web UI
```

Дозволяє:

- Переглядати всі HTTP запити через тунель в реальному часі
- Бачити заголовки запиту і відповіді
- Бачити тіло запиту (JSON, форми)
- Replay запитів (відтворити той самий POST ще раз)
- Перевірити CSRF token у cookie і POST body

Корисно для дебагу CSRF: відкрий Inspector → POST /accounts/login/

```
→ Cookies: csrftoken=<value>
→ Body: csrfmiddlewaretoken=<value>
→ Чи вони збігаються?
```

---

## NGROK_DOMAIN і NGROK_AUTHTOKEN env vars

| Змінна | Де взяти | Навіщо |
|--------|----------|--------|
| `NGROK_AUTHTOKEN` | [dashboard.ngrok.com/authtokens](https://dashboard.ngrok.com/authtokens) | Аутентифікація ngrok агента |
| `NGROK_DOMAIN` | [dashboard.ngrok.com/domains](https://dashboard.ngrok.com/domains) | Фіксований публічний URL (1 безкоштовний static domain на акаунт) |

Без `NGROK_DOMAIN` ngrok генерує випадковий URL при кожному запуску. З `NGROK_DOMAIN` URL завжди однаковий — корисно для `CSRF_TRUSTED_ORIGINS` у `settings.py`.

---

## У книзі

- [Частина VII. Auth і Security](../../07_auth_and_security/README.md) — CSRF захист, `CSRF_TRUSTED_ORIGINS`, `Origin` header перевірка Django
- [Частина XI. Deployment](../../11_deployment/README.md) — публічний доступ, ngrok, reverse tunnel

---

## Офіційна документація

- [ngrok: Docker agent](https://ngrok.com/docs/using-ngrok-with/docker/) — запуск ngrok у Docker
- [ngrok: Static domains](https://ngrok.com/docs/network-edge/domains/) — безкоштовні static domains
- [ngrok: Traffic Inspector](https://ngrok.com/docs/agent/web-inspection-interface/) — dashboard на :4040
- [Django: CSRF_TRUSTED_ORIGINS](https://docs.djangoproject.com/en/5.2/ref/settings/#csrf-trusted-origins) — налаштування довірених origins
- [Django: ALLOWED_HOSTS](https://docs.djangoproject.com/en/5.2/ref/settings/#allowed-hosts) — захист від Host header attacks
