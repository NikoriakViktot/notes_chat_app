# Browser Notifications

## Чому не WebSocket для notifications

Celery надсилає email у фоні. Але щоб показати нагадування прямо у браузері, потрібен окремий механізм.

WebSocket ідеально підходить для **живого двостороннього потоку** (чат). Для нагадувань достатньо **HTTP polling** — простіший механізм без постійного з'єднання.

| | WebSocket | HTTP polling |
|-|-----------|-------------|
| Підходить для | живий чат, real-time дошка | рідкісні оновлення (раз на хвилину) |
| З'єднання | постійне | закривається після кожного запиту |
| Складність | AuthMiddlewareStack, consumer, ASGI | звичайний `@login_required` view |
| Коли WebSocket не потрібен | нагадування раз на хвилину | ✅ саме цей випадок |

**Висновок:** для нагадувань, які перевіряються раз на хвилину, HTTP polling — правильний і простіший вибір. WebSocket доречний там, де затримка < 1 секунди є важливою (чат, спільне редагування).

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
            remind_at__gte=now - timedelta(hours=1),   # вікно 1 год
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

**Вікно 1 година** (`remind_at__gte=now - timedelta(hours=1)`) — якщо користувач відкрив браузер через 30 хвилин після нагадування, він все одно побачить Toast. Нагадування старші 1 години вже не актуальні.

---

## JavaScript polling

```javascript
// notes_app/static/notes_app/js/reminders.js
(function () {
  'use strict';

  var POLL_INTERVAL = 60_000;           // 60 секунд
  var STORAGE_KEY   = 'shown_reminders'; // sessionStorage — дедуплікація
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

  function escapeHtml(str) {   // XSS захист — завжди екранувати user content
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
    } catch (_) { /* тихий fail — мережа недоступна */ }
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!document.getElementById('reminder-toast-container')) return;
    checkReminders();                          // одразу при завантаженні
    setInterval(checkReminders, POLL_INTERVAL); // потім кожні 60 секунд
  });
})();
```

**Ключові рішення:**

| Рішення | Причина |
|---------|---------|
| `sessionStorage` для дедуплікації | Toast не з'явиться двічі в одній сесії |
| `escapeHtml()` для усього user content | XSS: зловмисник міг вставити `<script>` у назву нотатки |
| `checkReminders()` одразу на `DOMContentLoaded` | тест не чекає 60 секунд — перевірка при першому завантаженні |
| IIFE `(function () { ... })()` | модульна ізоляція — нема глобальних змінних |

---

## Toast container у base.html

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

<!-- ... решта body ... -->

{% if user.is_authenticated %}
<script src="{% static 'notes_app/js/reminders.js' %}"></script>
{% endif %}
```

`aria-live="polite"` — скрінрідер оголошує нові Toast після поточного речення (не перериває).

---

## Архітектура: Celery ↔ JSON endpoint ↔ JS polling

```
Celery Worker
    │  reminder.is_sent = True
    │  (пише у PostgreSQL)
    ▼
PostgreSQL
    │  Reminder.objects.filter(remind_at__lte=now, is_sent=False)
    │  (читає selector)
    ▼
GET /reminders/check/
    │  JsonResponse({'reminders': [...]})
    ▼
reminders.js (fetch кожні 60 сек)
    │  showToast(r)
    ▼
Bootstrap Toast (знизу-праворуч)
```

Зверни увагу: Celery і JS polling **не взаємодіють напряму**. Celery пише стан у базу даних, а JS читає його через звичайний HTTP endpoint. Це спрощує архітектуру і робить кожну частину незалежно тестованою.

---

## URL конфігурація

```python
# notes_app/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # ... інші URL ...
    path('reminders/check/', views.reminders_check, name='reminders_check'),
]
```

`name='reminders_check'` дозволяє використовувати `{% url 'reminders_check' %}` у шаблонах замість хардкоду `/reminders/check/`.

У `reminders.js` URL хардкодований (`CHECK_URL = '/reminders/check/'`). Для production-застосунків краще передавати URL через data-атрибут у HTML і читати його з JS:

```html
<!-- base.html -->
<div id="reminder-toast-container"
     data-check-url="{% url 'reminders_check' %}"
     ...>
```

```javascript
// reminders.js
var CHECK_URL = document.getElementById('reminder-toast-container').dataset.checkUrl;
```

---

## Debugging у браузері

### DevTools → Network

1. Відкрий `http://localhost/notes/`
2. F12 → вкладка **Network**
3. Знайди запит `check/` або `reminders/check/`
4. Що перевіряти:

| Що бачиш | Що означає |
|----------|-----------|
| Status: 200, Response: `{"reminders": []}` | endpoint працює, нагадувань немає |
| Status: 200, Response: `{"reminders": [...]}` | є нагадування — перевір чи з'являється Toast |
| Status: 302 → redirect на `/accounts/login/` | не увійшов у систему або `@login_required` спрацював |
| Status: 404 | URL не зареєстрований — перевір `urls.py` |
| Status: 500 | помилка у view — перевір логи `docker compose logs web` |

### Перевірка через curl

```bash
# Спочатку потрібна сесія. Логінимось і зберігаємо cookie:
curl -c cookies.txt -X POST http://localhost/accounts/login/ \
  -d "username=demo_alice&password=demo1234&csrfmiddlewaretoken=TOKEN"

# Тепер перевіряємо endpoint:
curl -b cookies.txt http://localhost/reminders/check/
# → {"reminders": []}  або  {"reminders": [{...}]}
```

### Перевірка через Django shell

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.selectors import get_due_reminders_for_browser

user = User.objects.get(username='demo_alice')
reminders = get_due_reminders_for_browser(user)
print(reminders)
# [] — немає нагадувань або всі вже надіслані (is_sent=True)

# Перевір чи є нагадування взагалі:
from notes_app.models import Reminder
from django.utils import timezone
print(Reminder.objects.filter(note__user=user).values('remind_at', 'is_sent'))
```

### Якщо Toast не з'являється

```
1. Перевір консоль браузера (F12 → Console) — чи є JS-помилки
2. Перевір Network → чи виконується запит до /reminders/check/
3. Перевір що #reminder-toast-container є у HTML (тільки для авторизованих)
4. Перевір що reminders.js підключений: Network → JS файли
5. Перевір відповідь /reminders/check/ — чи є нагадування у JSON
6. Перевір sessionStorage: DevTools → Application → Session Storage
   → показані shown_reminders — якщо id вже там, Toast не з'явиться
```

---

## У книзі

- [Частина VI. Архітектура застосунку](../../06_application_architecture/README.md) — Celery background tasks, архітектурні паттерни для фонових задач
- [Частина IX. Async і Real-Time](../../09_async_and_realtime/README.md) — коли WebSocket потрібен, коли polling достатній, async patterns

---

## Офіційна документація

- [Django: JsonResponse](https://docs.djangoproject.com/en/5.2/ref/request-response/#jsonresponse-objects)
- [Django: URL dispatcher](https://docs.djangoproject.com/en/5.2/topics/http/urls/)
- [MDN: Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch)
- [MDN: sessionStorage](https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage)
- [MDN: setInterval](https://developer.mozilla.org/en-US/docs/Web/API/setInterval)
- [Bootstrap: Toasts](https://getbootstrap.com/docs/5.3/components/toasts/)
- [MDN: aria-live](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-live)
