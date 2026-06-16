# Архітектура Celery

## Проблема: чому Django-view не може відправляти email

Django побудований за моделлю **Request → Response**. Кожен HTTP-запит займає один потік (thread) виконання. Поки view не поверне відповідь — браузер чекає. Тому всі операції всередині view мають завершитись якнайшвидше.

Подивись що станеться якщо спробувати відправляти нагадування прямо у view:

```python
# ❌ НЕ РОБИ ТАК — це антипаттерн
def note_detail(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)

    # Перевіряємо всі нагадування для всіх юзерів...
    for reminder in Reminder.objects.filter(remind_at__lte=timezone.now()):
        send_mail(...)   # SMTP-з'єднання займає 300–500 мс на кожен email
        reminder.is_sent = True
        reminder.save()

    return render(request, 'notes_app/note_detail.html', {'note': note})
```

Якщо є 20 нагадувань — view заблокує потік на 6–10 секунд. Браузер покаже «Loading...» весь цей час. При 100 одночасних юзерах — сервер ляже.

**Три фундаментальні проблеми цього підходу:**

| Проблема | Чому виникає | Наслідок |
|----------|-------------|---------|
| `send_mail()` блокує потік | SMTP handshake — мережева операція | сторінка завантажується 5+ секунд |
| Виконується лише при HTTP-запиті | view спрацьовує тільки коли хтось відкриває сторінку | нагадування не надсилається, якщо ніхто не відкрив `/notes/42/` рівно о 14:00 |
| Неможливо планувати точний час | немає механізму «виконати о 14:00» у стандартному Django | нагадування або раніше, або пізніше |

**Правило:** Django-view не повинен виконувати операції, які займають більше ~200 мс або залежать від часу. Для цього існують **background task queues**.

---

## Що таке черга задач (task queue)

Черга задач — це архітектурний паттерн «виробник → черга → споживач»:

```
Django (view)                           Celery Worker
   │                                        │
   │  task.delay()                          │
   │  «постав задачу у чергу»              │
   ▼                                        │
Redis (broker)  ←────────────────────────  │
   │            «є нова задача»             │
   │                                        │
   └──────────────────────────────────────► │
                 «беру задачу і виконую»    │
                                            ▼
                                       send_mail()
                                       reminder.is_sent = True
```

**Ключова ідея:** Django не чекає поки задача виконається. Він каже «ось задача, виконай її» — і одразу повертає відповідь браузеру. Worker виконує задачу окремо, у своєму процесі.

---

## Celery — реалізація черги задач для Python

**Celery** — найпопулярніша бібліотека черги задач для Python/Django. Вона складається з кількох компонентів:

### Компоненти Celery

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CELERY СИСТЕМА                               │
│                                                                     │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │  Django  │    │    Redis     │    │     Celery Worker        │  │
│  │  (view)  │───►│   (broker)  │───►│                          │  │
│  │          │    │             │    │  @shared_task functions   │  │
│  └──────────┘    └──────────────┘    └──────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Celery Beat                               │   │
│  │  (планувальник, запускає задачі за розкладом — без Django)  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

| Компонент | Роль | Аналогія |
|-----------|------|---------|
| **Task** (`@shared_task`) | Python-функція, яку можна поставити у чергу | «замовлення» |
| **Broker** (Redis) | черга повідомлень, зберігає задачі | «черга на касу» |
| **Worker** | окремий процес, читає задачі і виконує їх | «касир» |
| **Beat** | окремий процес-планувальник, ставить задачі за розкладом | «будильник» |
| **Result Backend** (Redis) | зберігає результати виконаних задач | «квитанція» |

### Як Beat ставить задачі без Django

Beat — це окремий **Python-процес**, що запускається командою:

```bash
celery -A notes_project beat -l info
```

Він читає `CELERY_BEAT_SCHEDULE` з `settings.py` і кожні N секунд публікує повідомлення у Redis:

```
Beat (кожні 60 сек):
  └─► публікує у Redis: {"task": "notes_app.tasks.send_reminder_notifications", "args": [], "kwargs": {}}

Worker (постійно слухає Redis):
  └─► отримує повідомлення → виконує send_reminder_notifications()
```

Beat **не виконує задачу сам** — він тільки ставить її у чергу. Worker виконує.

### Розбір команди запуску Worker

```bash
celery -A notes_project worker -l info --concurrency=2
```

| Частина | Що означає |
|---------|-----------|
| `celery` | CLI Celery |
| `-A notes_project` | «додаток» — читає `notes_project/celery.py` |
| `worker` | запустити Worker (не Beat) |
| `-l info` | рівень логування (info, debug, warning, error) |
| `--concurrency=2` | 2 паралельних процеси-виконавці |

---

## Архітектура системи нагадувань у notes_chat_app

У проєкті два незалежних механізми нагадувань:

```
МЕХАНІЗМ 1: Email (завжди, незалежно від браузера)
─────────────────────────────────────────────────
Celery Beat (кожні 60 секунд)
    │
    ▼
@shared_task send_reminder_notifications()
    │
    ├─ SELECT * FROM reminder WHERE remind_at <= now AND is_sent = FALSE
    │
    └─ для кожного reminder:
          ├── send_mail(to=user.email, ...)  ← email у dev: виводить у консоль
          ├── reminder.is_sent = True
          ├── reminder.save(update_fields=['is_sent'])
          └── _schedule_next(reminder)       ← якщо repeat_pattern ≠ 'none'

МЕХАНІЗМ 2: Browser Toast (тільки при відкритому браузері)
───────────────────────────────────────────────────────────
reminders.js (DOMContentLoaded + кожні 60 сек)
    │
    ├─ GET /reminders/check/
    │      └─ JsonResponse({reminders: [...]})
    │
    └─ для кожного нового нагадування:
          └── Bootstrap Toast (знизу-праворуч, 8 секунд)
```

**Чому два механізми, а не один?**

- Email потрібен навіть якщо браузер закритий → Celery Worker
- Browser Toast потрібен якщо браузер відкритий → JS polling
- Вони незалежні: Celery пише `is_sent=True` у БД, JS читає через окремий endpoint

---

## Модель Reminder

Перш ніж переходити до реалізації — зрозумій структуру даних:

```python
# notes_app/models.py
class Reminder(models.Model):
    REPEAT_CHOICES = [
        ('none',    'Одноразово'),
        ('daily',   'Щодня'),
        ('weekly',  'Щотижня'),
        ('monthly', 'Щомісяця'),
    ]

    note           = models.ForeignKey(Note, on_delete=models.CASCADE,
                                       related_name='reminders')
    remind_at      = models.DateTimeField()        # коли надіслати
    message        = models.TextField(blank=True)  # текст нагадування
    is_sent        = models.BooleanField(default=False)  # чи вже надіслано
    repeat_pattern = models.CharField(max_length=10, choices=REPEAT_CHOICES,
                                      default='none')

    class Meta:
        ordering = ['remind_at']
```

Поле `is_sent` — ключове: Celery Worker встановлює його в `True` після надсилання. Це запобігає повторному надсиланню при наступному запуску задачі.

---

## Redis як broker: чому не база даних

Популярні варіанти broker для Celery:

| Broker | Плюси | Мінуси |
|--------|-------|--------|
| **Redis** | швидкий (in-memory), простий, вже є у проєкті | втрачає задачі при перезапуску без persistence |
| **RabbitMQ** | надійний, складні маршрути | складніший у налаштуванні |
| **PostgreSQL** | не потрібен окремий сервіс | повільний, навантажує БД |

У `notes_chat_app` Redis вже є для Django Channels. Використовуємо його і для Celery, але **різні БД** щоб не змішувати повідомлення:

```
Redis сервер (один)
├── DB 0  ← Django Channels (WebSocket channel layer)
└── DB 1  ← Celery (broker + result backend)
```

Якщо обидва використовували б DB 0, Redis міг би переплутати WebSocket-повідомлення чату з Celery-задачами нагадувань. Різні БД ізолюють їх.

---

## Порівняння: sync у view vs Celery background

| | Sync у view | Celery background |
|-|-------------|-------------------|
| Відповідь браузеру | **блокується** до завершення | миттєва (< 10 мс) |
| Виконання за розкладом | ❌ неможливо | ✅ Celery Beat |
| Масштабування | 1 задача за раз (блокує потік) | N воркерів паралельно |
| Відмовостійкість при помилці | виняток → 500 для юзера | автоматичний retry |
| Видимість стану | немає | логи воркера, result backend |
| Складність | мінімальна | +2 сервіси (worker, beat), broker |

**Коли варто використовувати Celery:**

- задача займає > 200 мс (email, HTTP до зовнішнього API, обробка файлів, PDF)
- задача повинна виконатись за розкладом, незалежно від HTTP-запитів
- задача має виконатись кілька разів з retry при помилці
- потрібно обробляти сотні задач паралельно

---

## У книзі

- [Частина VI. Архітектура застосунку](../../06_application_architecture/README.md) — детальний розбір архітектури сервісного шару, Celery patterns, task design
- [Частина IX. Async і Real-Time](../../09_async_and_realtime/README.md) — asyncio, event loop, коли async vs threading vs multiprocessing

---

## Офіційна документація

- [Celery: First Steps with Django](https://docs.celeryq.dev/en/stable/django/first-steps-with-django.html)
- [Celery: User Guide — Tasks](https://docs.celeryq.dev/en/stable/userguide/tasks.html)
- [Celery: Periodic Tasks (Beat)](https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html)
- [Celery: Workers Guide](https://docs.celeryq.dev/en/stable/userguide/workers.html)
- [Redis: Select DB](https://redis.io/commands/select/) — розуміння Redis databases
