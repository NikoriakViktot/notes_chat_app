# HTTP та HTTPS

> HTTP — це мова якою браузер розмовляє із сервером.
> Django — це "перекладач" на стороні сервера: він розуміє HTTP і відповідає теж HTTP.

---

## Навіщо розуміти HTTP

Коли у `notes_app/views.py` ти пишеш:

```python
def note_create(request):
    if request.method == 'POST':
        ...
```

— ти вже використовуєш HTTP. `request.method` — це рядок `'GET'` або `'POST'` що прийшов від браузера. Без розуміння HTTP неможливо зрозуміти звідки це беруться і чому форма не зберігається.

---

## Анатомія HTTP запиту

HTTP запит — це просто текст з певною структурою:

```
POST /notes/new/ HTTP/1.1          ← рядок запиту: метод + шлях + версія
Host: localhost                     ← обов'язковий заголовок (якому серверу?)
Content-Type: application/x-www-form-urlencoded
Content-Length: 52
Cookie: sessionid=abc123; csrftoken=xyz456
                                    ← порожній рядок = кінець заголовків
title=Перша+нотатка&priority=2     ← тіло запиту (тільки у POST, PUT, PATCH)
```

**Три частини запиту:**

| Частина | Де в Django |
|---------|------------|
| Рядок запиту (`POST /notes/new/`) | `request.method`, `request.path` |
| Заголовки (`Host`, `Cookie`...) | `request.headers`, `request.META` |
| Тіло (тільки POST/PUT) | `request.POST` (форми) або `request.body` (JSON) |

---

## Анатомія HTTP відповіді

```
HTTP/1.1 302 Found                  ← рядок відповіді: версія + статус
Location: /notes/42/                ← заголовок: куди редіректити
Content-Type: text/html             ← тип вмісту
Set-Cookie: sessionid=new_val       ← встановити cookie
                                    ← порожній рядок
<!-- тіло відповіді (HTML або JSON) -->
```

У Django:
- `return render(request, 'template.html', context)` → 200 OK + HTML тіло
- `return redirect('notes_app:note_list')` → 302 Found + Location заголовок
- `raise Http404` → 404 Not Found

---

## HTTP методи — навіщо різні

```
GET  /notes/           → отримати список (тільки читання, без тіла)
GET  /notes/42/        → отримати конкретну нотатку
POST /notes/new/       → створити нотатку (дані у тілі запиту)
POST /notes/42/delete/ → видалити (Django FBV часто POST для небезпечних дій)
```

**Ключові властивості:**

| Метод | Має тіло? | Безпечний? | Ідемпотентний? |
|-------|-----------|------------|----------------|
| GET | Ні | Так | Так |
| POST | Так | Ні | Ні |
| PUT | Так | Ні | Так |
| DELETE | Ні | Ні | Так |

**Безпечний** = не змінює стан сервера (GET лише читає).  
**Ідемпотентний** = повторний запит дає той самий результат (DELETE двічі = те ж що DELETE один раз).

!!! note "Чому в HTML формах тільки GET і POST?"
    HTML 4 специфікація дозволяла лише GET і POST для `<form>`. PUT і DELETE з'явились у REST API через JavaScript (fetch/axios). Django FBV у notes_chat_app використовує POST для всіх мутацій.

---

## Статус коди — що означають

```
2xx — Успіх
  200 OK             → звичайна відповідь (GET)
  201 Created        → створено (REST API)

3xx — Перенаправлення
  301 Moved Permanently  → URL назавжди змінився (кешується браузером!)
  302 Found              → тимчасовий redirect (PRG pattern після POST)
  304 Not Modified       → ресурс не змінився, використай кеш браузера

4xx — Помилка клієнта
  400 Bad Request        → невалідний запит
  403 Forbidden          → немає доступу (відомо що існує)
  404 Not Found          → не знайдено (або IDOR захист)
  405 Method Not Allowed → неправильний HTTP метод
  422 Unprocessable      → форма не пройшла валідацію (REST API)

5xx — Помилка сервера
  500 Internal Server Error → Python exception (перевір логи!)
  503 Service Unavailable   → сервер недоступний (deploy в процесі?)
```

Django автоматично повертає:
- `404` — якщо URL не знайдений у `urls.py` або `raise Http404`
- `403` — якщо CSRF токен неправильний або `PermissionDenied`
- `500` — якщо необроблений exception у view (при `DEBUG=False`)

---

## PRG Pattern — чому redirect після POST

**Проблема без PRG:**

```
POST /notes/new/  → сервер зберіг нотатку → render 200 OK HTML
Студент натискає F5 (оновити сторінку)
Браузер: "Повторити POST запит?"
Студент: "Так"
→ Нотатка створюється ВДРУГЕ. Дублікат!
```

**З PRG (Post/Redirect/Get):**

```
POST /notes/new/  → сервер зберіг → redirect 302 → /notes/42/
Браузер автоматично: GET /notes/42/ → render 200 OK HTML
F5 → повторює GET /notes/42/ → безпечно, просто перезавантажує сторінку
```

```python
# views.py — PRG паттерн
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

## HTTP заголовки що Django використовує

```
Від браузера до Django:
  Host: localhost              → request.META['HTTP_HOST']
  Cookie: sessionid=abc123    → request.COOKIES['sessionid']
  Accept: text/html,...       → request.META['HTTP_ACCEPT']
  X-CSRFToken: xyz            → перевіряється CsrfViewMiddleware
  Content-Type: ...           → request.content_type

Від Django до браузера:
  Content-Type: text/html     → тип відповіді (HTML, JSON, PDF...)
  Set-Cookie: sessionid=...   → встановити сесійний cookie
  Location: /notes/42/        → куди редіректити (при 302)
  X-Frame-Options: DENY       → заборона iframe (Clickjacking захист)
```

---

## HTTPS — TLS зверху HTTP

HTTP передає дані відкритим текстом. Без HTTPS:

```
Мережа → Зловмисник бачить:
  Cookie: sessionid=abc123
  → входить під твоїм акаунтом без пароля!
```

HTTPS = HTTP + TLS шифрування:

```
Browser ←──TLS──→ Server
         ↑
  Дані зашифровані:
  Cookie: ????XSK##$@!  (нечитабельно без ключа)
```

**TLS handshake** (відбувається перед першим HTTP запитом):
1. Browser → Server: "Підтримую TLS 1.3, ось мої cipher suites"
2. Server → Browser: "Certificate (підписаний CA), публічний ключ"
3. Browser: Перевіряє certificate у системному сховищі CA
4. Browser → Server: Обмін ключами, встановлення shared secret
5. Далі: всі HTTP запити і відповіді шифруються

**Чому `Session Cookie Secure = True` у production:**

```python
# settings.py
SESSION_COOKIE_SECURE = True   # cookie надсилається тільки по HTTPS
# Без цього cookie може бути перехоплений по HTTP (HTTP → HTTPS redirect не захищає!)
```

---

## Дослідження HTTP у браузері

Відкрий DevTools (F12) → вкладка **Network**:

```
1. Відкрий http://localhost/notes/
2. F12 → Network → All
3. Клацни на перший запит у списку
4. Вкладка "Headers":
   Request URL: http://localhost/notes/
   Request Method: GET
   Status Code: 200 OK
   
   Response Headers:
     Content-Type: text/html; charset=utf-8
     X-Frame-Options: DENY
   
   Request Headers:
     Cookie: sessionid=...; csrftoken=...
```

Залий форму нотатки і натисни Submit — побачиш POST запит з 302 redirect.

---

## Де в notes_chat_app

| Концепція | Де знайти |
|-----------|-----------|
| `request.method` | `notes_app/views.py` — кожен view |
| PRG pattern | `note_create`, `note_update`, `todo_create` у `views.py` |
| CSRF token | `{% csrf_token %}` у кожній формі в `templates/` |
| Security headers | `notes_project/settings.py` — `X_FRAME_OPTIONS`, `SECURE_CONTENT_TYPE_NOSNIFF` |
| `SESSION_COOKIE_SECURE` | `settings.py` (закоментовано, вмикається у production) |

---

## У книзі

- [Мережевий фундамент](network_foundation_full.md) — HTTP детально: всі методи, статуси, cookie атрибути, REST принципи
- [Частина VII. Auth і Security](../07_auth_and_security/README.md) — CSRF, XSS, session hijacking, HTTPS в production

---

## Офіційна документація

- [MDN: HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP) — повний HTTP довідник
- [MDN: HTTP request methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods) — всі методи з прикладами
- [MDN: HTTP response status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) — всі статуси
- [MDN: HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers) — всі заголовки
- [MDN: HTTPS](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security) — TLS/HTTPS
- [Django: Request and response objects](https://docs.djangoproject.com/en/5.2/ref/request-response/) — HttpRequest API
