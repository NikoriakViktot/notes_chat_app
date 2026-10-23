# Browser Notifications

## Why not WebSocket for notifications

Celery sends email in the background. But to show a reminder right in the browser, you need a separate mechanism.

WebSocket is ideal for a **live two-way stream** (chat). For reminders **HTTP polling** is enough: a simpler mechanism without a persistent connection.

| | WebSocket | HTTP polling |
|-|-----------|-------------|
| Suitable for | live chat, a real-time board | rare updates (once a minute) |
| Connection | persistent | closed after every request |
| Complexity | AuthMiddlewareStack, consumer, ASGI | an ordinary `@login_required` view |
| When WebSocket is not needed | reminders once a minute | ✅ exactly this case |

**Conclusion:** for reminders that are checked once a minute, HTTP polling is the correct and simpler choice. WebSocket is appropriate where latency < 1 second matters (chat, collaborative editing).

---

## JSON endpoint

```python
# notes_app/selectors.py
def get_due_reminders_for_browser(user):
    from datetime import timedelta
    now = timezone.now()
    return list(
        Reminder.objects
        .filter(
            note__user=user,
            remind_at__lte=now,
            remind_at__gte=now - timedelta(hours=1),   # 1-hour window
        )
        .select_related('note')
        .order_by('remind_at')
        .values('id', 'message', 'remind_at', 'note__title')
    )
```

```python
# notes_app/views.py
@login_required
def reminders_check(request):
    data = selectors.get_due_reminders_for_browser(request.user)
    for item in data:
        item['remind_at'] = item['remind_at'].strftime('%d.%m.%Y %H:%M')
    return JsonResponse({'reminders': data})
```

**The 1-hour window** (`remind_at__gte=now - timedelta(hours=1)`): if the user opens the browser 30 minutes after the reminder, they still see the Toast. Reminders older than 1 hour are no longer relevant.

---

## JavaScript polling

```javascript
// notes_app/static/notes_app/js/reminders.js
(function () {
  'use strict';

  var POLL_INTERVAL = 60_000;           // 60 seconds
  var STORAGE_KEY   = 'shown_reminders'; // sessionStorage for deduplication
  var CHECK_URL     = '/reminders/check/';

  function getShownIds() {
    try {
      return new Set(JSON.parse(sessionStorage.getItem(STORAGE_KEY) || '[]'));
    } catch (_) { return new Set(); }
  }

  function markShown(id) {
    var s = getShownIds();
    s.add(id);
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(Array.from(s)));
  }

  function escapeHtml(str) {   // XSS protection: always escape user content
    return String(str)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function showToast(reminder) {
    var container = document.getElementById('reminder-toast-container');
    if (!container) return;

    var toastEl = document.createElement('div');
    toastEl.className = 'toast align-items-center border-0';
    toastEl.innerHTML =
      '<div class="d-flex">'
      + '<div class="toast-body">'
      + '<strong>🔔 Нагадування</strong><br>'
      + '<span>' + escapeHtml(reminder.note__title) + '</span><br>'
      + (reminder.message ? '<small>' + escapeHtml(reminder.message) + '</small><br>' : '')
      + '<small class="text-muted">' + escapeHtml(reminder.remind_at) + '</small>'
      + '</div>'
      + '<button type="button" class="btn-close me-2 m-auto"'
      + ' data-bs-dismiss="toast" aria-label="Закрити"></button>'
      + '</div>';

    container.appendChild(toastEl);
    new bootstrap.Toast(toastEl, { delay: 8000, autohide: true }).show();
    toastEl.addEventListener('hidden.bs.toast', function () { toastEl.remove(); });
  }

  async function checkReminders() {
    try {
      var resp = await fetch(CHECK_URL, { credentials: 'same-origin' });
      if (!resp.ok) return;
      var data = await resp.json();
      var shown = getShownIds();
      (data.reminders || []).forEach(function (r) {
        if (!shown.has(r.id)) { showToast(r); markShown(r.id); }
      });
    } catch (_) { /* silent fail: network unavailable */ }
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!document.getElementById('reminder-toast-container')) return;
    checkReminders();                          // right away on load
    setInterval(checkReminders, POLL_INTERVAL); // then every 60 seconds
  });
})();
```

**Key decisions:**

| Decision | Reason |
|---------|---------|
| `sessionStorage` for deduplication | The Toast will not appear twice in the same session |
| `escapeHtml()` for all user content | XSS: an attacker could put `<script>` into a note title |
| `checkReminders()` right on `DOMContentLoaded` | the test does not wait 60 seconds: the check happens on the first load |
| IIFE `(function () { ... })()` | module isolation: no global variables |

---

## Toast container in base.html

```html
<!-- templates/base.html -->
<body>

{% if user.is_authenticated %}
<div id="reminder-toast-container"
     class="toast-container position-fixed bottom-0 end-0 p-3"
     style="z-index: 1100;"
     aria-live="polite"
     aria-label="Нагадування">
</div>
{% endif %}

<!-- ... the rest of body ... -->

{% if user.is_authenticated %}
<script src="{% static 'notes_app/js/reminders.js' %}"></script>
{% endif %}
```

`aria-live="polite"`: the screen reader announces new Toasts after the current sentence (without interrupting).

---

## Architecture: Celery ↔ JSON endpoint ↔ JS polling

```
Celery Worker
    │  reminder.is_sent = True
    │  (writes to PostgreSQL)
    ▼
PostgreSQL
    │  Reminder.objects.filter(note__user=user,
    │      remind_at__lte=now, remind_at__gte=now - 1 h)
    │  (read by the get_due_reminders_for_browser selector; is_sent is not checked)
    ▼
GET /reminders/check/
    │  JsonResponse({'reminders': [...]})
    ▼
reminders.js (fetch every 60 sec)
    │  showToast(r)
    ▼
Bootstrap Toast (bottom right)
```

Note: Celery and JS polling **do not interact directly**. Celery writes state to the database, and JS reads it through an ordinary HTTP endpoint. This simplifies the architecture and makes each part independently testable.

---

## URL configuration

```python
# notes_app/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # ... other URLs ...
    path('reminders/check/', views.reminders_check, name='reminders_check'),
]
```

`name='reminders_check'` together with `app_name = "notes_app"` lets you use `{% url 'notes_app:reminders_check' %}` in templates instead of hardcoding `/reminders/check/`.

In `reminders.js` the URL is hardcoded (`CHECK_URL = '/reminders/check/'`). For production applications it is better to pass the URL through a data attribute in the HTML and read it from JS:

```html
<!-- base.html -->
<div id="reminder-toast-container"
     data-check-url="{% url 'notes_app:reminders_check' %}"
     ...>
```

```javascript
// reminders.js
var CHECK_URL = document.getElementById('reminder-toast-container').dataset.checkUrl;
```

---

## Debugging in the browser

### DevTools → Network

1. Open `http://localhost/notes/`
2. F12 → the **Network** tab
3. Find the `check/` or `reminders/check/` request
4. What to check:

| What you see | What it means |
|----------|-----------|
| Status: 200, Response: `{"reminders": []}` | the endpoint works, there are no reminders |
| Status: 200, Response: `{"reminders": [...]}` | there are reminders: check whether the Toast appears |
| Status: 302 → redirect to `/accounts/login/` | you are not logged in, or `@login_required` kicked in |
| Status: 404 | the URL is not registered: check `urls.py` |
| Status: 500 | an error in the view: check the logs with `docker compose logs web` |

### Checking with curl

```bash
# First you need a session. Log in and save the cookie:
curl -c cookies.txt -X POST http://localhost/accounts/login/ \
  -d "username=demo_alice&password=demo1234&csrfmiddlewaretoken=TOKEN"

# Now check the endpoint:
curl -b cookies.txt http://localhost/reminders/check/
# → {"reminders": []}  or  {"reminders": [{...}]}
```

### Checking through the Django shell

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.selectors import get_due_reminders_for_browser

user = User.objects.get(username='demo_alice')
reminders = get_due_reminders_for_browser(user)
print(reminders)
# []: no reminders with remind_at in the last hour (window [now − 1 h, now])

# Check whether there are any reminders at all:
from notes_app.models import Reminder
from django.utils import timezone
print(Reminder.objects.filter(note__user=user).values('remind_at', 'is_sent'))
```

### If the Toast does not appear

```
1. Check the browser console (F12 → Console) for JS errors
2. Check Network → is the request to /reminders/check/ being made
3. Check that #reminder-toast-container is in the HTML (only for logged-in users)
4. Check that reminders.js is loaded: Network → JS files
5. Check the /reminders/check/ response: are there reminders in the JSON
6. Check sessionStorage: DevTools → Application → Session Storage
   → shown_reminders lists what was shown; if the id is already there, the Toast will not appear
```

---

## In the book

- [Part VI. Application architecture](../../06_application_architecture/README.md): Celery background tasks, architectural patterns for background tasks
- [Part IX. Async and Real-Time](../../09_async_and_realtime/README.md): when WebSocket is needed, when polling is enough, async patterns

---

## Official documentation

- [Django: JsonResponse](https://docs.djangoproject.com/en/5.2/ref/request-response/#jsonresponse-objects)
- [Django: URL dispatcher](https://docs.djangoproject.com/en/5.2/topics/http/urls/)
- [MDN: Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch)
- [MDN: sessionStorage](https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage)
- [MDN: setInterval](https://developer.mozilla.org/en-US/docs/Web/API/setInterval)
- [Bootstrap: Toasts](https://getbootstrap.com/docs/5.3/components/toasts/)
- [MDN: aria-live](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-live)
