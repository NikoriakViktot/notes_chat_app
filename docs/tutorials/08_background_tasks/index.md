# Крок 8. Background Tasks: Celery + Redis + Browser Notifications

> Навчальний проєкт: **notes_chat_app** — той самий, що у Кроках 1–7.
>
> **Результат:** нагадування для нотаток надсилаються у фоні через Celery Beat, браузер отримує Toast-повідомлення через HTTP polling.

!!! warning "Передумови"
    Перед початком переконайся, що пройдені:

    - [Крок 7. Async Django](../07_async_django/index.md) — WebSocket, Channels, Redis
    - Потрібен запущений **Redis** і **Docker** (вже є з Кроку 7)

---

## Що ти вивчиш

- **Чому Django-view не може виконувати довгі задачі** — модель Request → Response і її обмеження
- **Celery** — Worker, Beat, Broker, Result Backend
- **`@shared_task`** — стандарт для Django-проєктів
- **Celery Beat** — планувальник задач за розкладом (cron-подібно)
- **Redis DB 0 vs DB 1** — ізоляція Channels і Celery
- **`CELERY_BEAT_SCHEDULE`** у `settings.py` — без зовнішніх пакетів
- **Browser Notifications через JS polling** — коли WebSocket зайвий
- **Toast UI** — Bootstrap Toast, aria-live, XSS-захист, sessionStorage дедуплікація
- **Тестування** — unit тести задачі, `@override_settings`, `mail.outbox`, Selenium E2E

---

## Навчальний проєкт

Той самий `notes_chat_app`, що будували з Кроку 1. У цьому кроці додаємо:

- `notes_project/celery.py` — ініціалізація Celery-додатку
- `notes_app/tasks.py` — фонова задача `send_reminder_notifications`
- Нові сервіси `celery-worker` і `celery-beat` у `docker-compose.yml`
- JSON endpoint `/reminders/check/` для браузерного polling
- `reminders.js` — fetch + Bootstrap Toast
- Тести: `test_tasks.py`, доповнення до `test_views.py` і `test_selenium.py`

---

## Архітектура результату

```
Celery Beat (кожну хвилину)
        │
        ▼
@shared_task send_reminder_notifications()
        │
        ├─ email → Console backend (dev)
        └─ reminder.is_sent = True

Browser (кожні 60 секунд, HTTP polling)
        │
        ▼
GET /reminders/check/  →  JSON [{id, note__title, message, remind_at}]
        │
        ▼
reminders.js  →  Bootstrap Toast (знизу-праворуч)
```

---

## Порядок читання

1. **[Архітектура Celery](celery_architecture.md)** — проблема блокування, що таке Celery, ASCII-схема, Redis як broker
2. **[Реалізація](implementation.md)** — `celery.py`, `tasks.py`, `settings.py`, `docker-compose.yml` крок за кроком
3. **[Browser Notifications](browser_notifications.md)** — JSON endpoint, JavaScript polling, Toast container
4. **[Тести](testing.md)** — unit тести задачі, тести view, Selenium E2E
5. **[Checkpoint](checkpoint.md)** — практичне завдання, чеклист самоперевірки
