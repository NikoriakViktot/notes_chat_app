# Lifecycle: від URL до сторінки

> Що відбувається між тим як студент натискає Enter в адресному рядку
> і тим як бачить сторінку з нотатками?
> Ці 8 кроків — фундамент будь-якого веб-розробника.

---

## Повна карта

```
Студент вводить: http://localhost/notes/

  1. DNS lookup
     localhost → 127.0.0.1 (loopback)

  2. TCP connection
     браузер → 127.0.0.1:80 (три рукостискання)

  3. (HTTPS) TLS handshake
     обмін сертифікатами, шифрування сесії
     (у localhost пропускається)

  4. HTTP Request відправляється
     GET /notes/ HTTP/1.1
     Host: localhost
     Cookie: sessionid=abc123

  5. nginx отримує запит
     → проксує до uvicorn :8001

  6. Django ASGI stack обробляє
     Middleware → URL routing → View → Selector → DB → Template

  7. HTTP Response відправляється
     200 OK + Content-Type: text/html + HTML тіло

  8. Браузер рендерить HTML
     CSS → DOM → CSSOM → Layout → Paint
     + додаткові запити для CSS/JS/images
```

---

## Крок 1: DNS lookup

**DNS** (Domain Name System) — телефонна книга інтернету: перетворює доменне ім'я у IP адресу.

```
Браузер шукає IP для "localhost" у такому порядку:
  1. Кеш браузера (чи питали це раніше?)
  2. Кеш ОС
  3. /etc/hosts файл ← localhost → 127.0.0.1 ЗАВЖДИ тут
  4. DNS сервер (якщо нічого вище не знайшло)
```

Для `localhost` DNS сервер ніколи не запитується — `/etc/hosts` відповідає завжди:

```bash
cat /etc/hosts
# 127.0.0.1  localhost
```

Для реального домену (`notes.example.com`):
```
Browser → DNS resolver (8.8.8.8) → Root nameserver → .com nameserver → example.com nameserver
→ відповідь: 203.0.113.1
```

**Час:** 0–50 мс для закешованих, 50–300 мс для нових доменів.

---

## Крок 2: TCP connection

**TCP** — протокол надійної доставки даних. Перед першим байтом HTTP — три рукостискання:

```
Browser → Server: SYN (хочу підключитися)
Browser ← Server: SYN-ACK (приймаю, підключися)
Browser → Server: ACK (підтверджую)
← з'єднання встановлено →
```

**Час:** 1 RTT (round-trip time) — для localhost ~0 мс, для зарубіжного сервера 50–200 мс.

**HTTP/1.1 Keep-Alive:** після з'єднання браузер не закриває сокет — надсилає наступний запит тим самим з'єднанням. Зберігає час на нові TCP handshake для CSS/JS/images.

---

## Крок 3: (HTTPS) TLS handshake

Для `https://` додається TLS handshake після TCP:

```
Browser → Server: ClientHello (підтримую TLS 1.3, cipher suites список)
Browser ← Server: ServerHello (вибрав cipher), Certificate, ServerHelloDone
Browser: Перевіряє certificate у системних CA
Browser → Server: ClientKeyExchange (shared secret через Diffie-Hellman)
← шифрований канал встановлений →
```

**Час:** 1 RTT (TLS 1.3) або 2 RTT (TLS 1.2).

Для `localhost` без TLS: крок 3 пропускається, з'єднання незахищене. В production — nginx або CDN термінує TLS і передає HTTP до uvicorn.

---

## Крок 4: HTTP Request

Браузер надсилає HTTP запит по встановленому з'єднанню:

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

**Кожен заголовок щось означає:**
- `Accept:` — браузер каже "я розумію HTML і ще кілька форматів"
- `Accept-Encoding: gzip` — "стискай відповідь, я розпакую"
- `Cookie:` — session cookie і CSRF token для кожного запиту
- `Cache-Control: max-age=0` — "не кешуй, дай свіже"

---

## Крок 5: nginx отримує запит

У production nginx (або в Docker стеку) стоїть між браузером і Django:

```
Browser :80 → nginx → uvicorn :8001 → Django
                ↓
          staticfiles/    ← nginx сам обробляє без Django
```

Конфігурація у `nginx/nginx.conf`:

```nginx
location / {
    proxy_pass http://web:8001;       # → uvicorn
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;  # Django бачить справжній IP
}

location /static/ {
    alias /staticfiles/;  # nginx сам, без Django
}
```

**Навіщо nginx перед Django?**
- Статичні файли без навантаження на Python
- SSL термінація (TLS decryption) — Django не знає про TLS
- Буферизація запитів від повільних клієнтів
- Rate limiting і security headers

---

## Крок 6: Django ASGI stack

Запит досягає Django і проходить крізь декілька шарів:

### 6.1 ASGI вхід

```python
# notes_project/asgi.py
application = ProtocolTypeRouter({
    'http': django_asgi_app,      # ← HTTP запит іде сюди
    'websocket': ...
})
```

### 6.2 Middleware ланцюг

Кожен middleware може модифікувати запит або перехопити відповідь:

```python
# settings.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',    # HTTP → HTTPS redirect, HSTS
    'whitenoise.middleware.WhiteNoiseMiddleware',       # static файли в dev
    'django.contrib.sessions.middleware.SessionMiddleware',  # session cookie → user
    'django.middleware.common.CommonMiddleware',        # trailing slash redirect
    'django.middleware.csrf.CsrfViewMiddleware',        # ← ПЕРЕВІРЯЄ CSRF TOKEN
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # ← request.user
    'django.contrib.messages.middleware.MessageMiddleware',  # messages framework
    ...
]
```

Middleware виконується у ЗВОРОТНЬОМУ порядку для відповіді:

```
Request  → SecurityMW → SessionMW → CsrfMW → AuthMW → View
Response ← SecurityMW ← SessionMW ← CsrfMW ← AuthMW ← View
```

### 6.3 URL routing

Django знаходить яка функція обробляє цей URL:

```python
# notes_project/urls.py
urlpatterns = [
    path('', include('notes_app.urls', namespace='notes_app')),
    path('admin/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),
]

# notes_app/urls.py
urlpatterns = [
    path('notes/', views.note_list, name='note_list'),    # ← /notes/ → тут
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    ...
]
```

### 6.4 View функція

```python
# notes_app/views.py
@login_required
def note_list(request):
    # Якщо не залогінений — SessionMiddleware вже set request.user = AnonymousUser
    # @login_required перенаправить на /accounts/login/

    # Selector: читання з БД
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

SQL що виконується:
```sql
SELECT notes.*, auth_user.*, notebooks.*
FROM notes_app_note notes
JOIN auth_user ON notes.user_id = auth_user.id
LEFT JOIN notes_app_notebook notebooks ON notes.notebook_id = notebooks.id
WHERE notes.user_id = 1 OR notes.group_id IN (1, 3)
ORDER BY notes.updated_at DESC;
```

### 6.6 Template rendering

Django компілює шаблон і підставляє контекст:

```html
<!-- templates/notes_app/note_list.html -->
{% extends 'base.html' %}
{% block content %}
{% for note in notes %}
  <div class="card">{{ note.title }}</div>
{% endfor %}
{% endblock %}
```

Результат — рядок HTML.

---

## Крок 7: HTTP Response

Django повертає:

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

Middleware ланцюг додає security заголовки під час виходу.

---

## Крок 8: Браузер рендерить HTML

Браузер отримав HTML і починає будувати сторінку:

```
1. HTML парсинг → DOM tree
   <html> → <head> → <body> → <div class="card"> ...

2. CSS запит (зустрів <link rel="stylesheet">)
   GET /static/notes_app/css/style.css
   GET /static/vendor/bootstrap.min.css
   → CSSOM tree

3. JavaScript запит (зустрів <script src="...">)
   GET /static/notes_app/js/group_chat.js
   → JavaScript execution

4. Layout (Reflow)
   Браузер обчислює позицію кожного елементу

5. Paint
   Пікселі на екрані

6. Composite
   Шари об'єднуються (GPU)
```

**Ці додаткові запити** (CSS, JS, images) — кожен проходить кроки 1–7 (DNS кешований, TCP keep-alive, nginx → staticfiles без Django).

---

## Що бачить Django vs браузер

| | Браузер | Django |
|---|---------|--------|
| Протокол | HTTP/2 або HTTP/1.1 | завжди HTTP/1.1 (nginx перекодовує) |
| Адреса | `http://localhost/notes/` | `/notes/` у `request.path` |
| IP клієнта | свій | `X-Real-IP` заголовок від nginx |
| TLS | бачить HTTPS | не знає (nginx термінує) |
| Стиснення | gzip/br | відповідь без стиснення (nginx стискає) |

---

## Lifecycle WebSocket (для довідки)

```
Browser → nginx → Django (Channels) → GroupChatConsumer

Відмінності:
- Протокол: ws:// або wss://
- TCP з'єднання: відкривається і ЗАЛИШАЄТЬСЯ відкритим
- Upgrade заголовок:  Connection: Upgrade, Upgrade: websocket
- Далі: binary frames замість text HTTP
```

Докладно: [Частина IX. Async і Realtime](../09_async_and_realtime/README.md)

---

## DevTools Network tab: побачити lifecycle

```
F12 → Network → перезавантаж сторінку

Що побачиш:
  Timing (перший запит):
    Stalled:            0 ms   (waiting in queue)
    DNS Lookup:         0 ms   (localhost = кеш)
    Initial connection: 0 ms   (loopback)
    Request sent:       0 ms
    Waiting (TTFB):    50 ms  ← Django processing time
    Content Download:   5 ms

  Initiator:
    notes_app/css/style.css    ← browser.html parser
    bootstrap.min.css          ← browser.html parser
    group_chat.js              ← browser.html parser
```

**TTFB** (Time to First Byte) — найважливіша метрика для backend: час від відправки запиту до першого байту відповіді. Це час роботи Django (включно з DB запитами).

---

## Де в notes_chat_app

| Крок lifecycle | Файл |
|---------------|------|
| nginx config | `nginx/nginx.conf` |
| ASGI router | `notes_project/asgi.py` |
| Middleware | `notes_project/settings.py` → `MIDDLEWARE` |
| URL routing | `notes_project/urls.py`, `notes_app/urls.py` |
| View | `notes_app/views.py` |
| DB query | `notes_app/selectors.py` |
| Template | `templates/notes_app/*.html` |
| Static files | `notes_app/static/` → `staticfiles/` (після collectstatic) |

---

## У книзі

- [HTTP та HTTPS](http_https.md) — анатомія HTTP запиту і відповіді
- [Мережевий фундамент](network_foundation_full.md) — TCP/IP, DNS, HTTP детально
- [Частина II. Django Core](../02_django_core/README.md) — Middleware, URL routing, MTV
- [Крок 9. Deployment → nginx](../tutorials/09_deployment/nginx.md) — nginx конфігурація

---

## Офіційна документація

- [MDN: How browsers work](https://developer.mozilla.org/en-US/docs/Web/Performance/How_browsers_work) — детально про рендеринг
- [MDN: DNS](https://developer.mozilla.org/en-US/docs/Learn/Common_questions/Web_mechanics/What_is_a_domain_name) — домени і DNS
- [Django: Request and response](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest API
- [Django: Middleware](https://docs.djangoproject.com/en/5.2/topics/http/middleware/) — написання та порядок middleware
- [nginx: proxy_pass](http://nginx.org/en/docs/http/ngx_http_proxy_module.html) — конфігурація проксі
