# Як читати цей курс

> Цей курс — одночасно і практичний туторіал, і теоретична книга.
> Є два шляхи: **Zero to Hero** (практика) і **Книга Django** (теорія).
> Вони доповнюють одне одного.

---

## Два паралельних шляхи

```
┌─────────────────────────────────────────────────────────────────┐
│                      NOTES CHAT APP КУРС                        │
├──────────────────────────┬──────────────────────────────────────┤
│   ZERO TO HERO           │   КНИГА DJANGO                       │
│   (практика)             │   (теорія)                           │
│                          │                                      │
│  Крок 1 → Крок 9         │  Частина I → Частина XI              │
│  Будуєш notes_chat_app   │  Пояснює ЧОМУ                        │
│  Покрокові туторіали     │  Глибокі концепції                   │
│  Реальний код            │  Схеми і аналогії                    │
│                          │                                      │
│  Рекомендовано для       │  Рекомендовано для                   │
│  новачків у Django       │  "чому це так працює?"               │
└──────────────────────────┴──────────────────────────────────────┘
```

**Що обрати:**
- Ніколи не писав Django? → Почни з **Zero to Hero**, крок 1
- Вже знаєш Django, хочеш поглибити знання? → Читай **Книгу Django** в будь-якому порядку
- Шукаєш конкретну тему? → Використовуй пошук (клавіша `/` в документації)

---

## Шлях 1: Zero to Hero (9 кроків)

Ти будуєш `notes_chat_app` з нуля. Кожен крок — окрема функціональність.

```
Крок 1 → Hello Django
    Перша сторінка, URL routing, шаблони, Django Admin

Крок 2 → Bootstrap Notes
    Перша модель (Note), міграції, Django Admin, базовий CRUD

Крок 3 → CRUD і архітектура
    Повна модель проєкту, selectors/services, FBV views, QuerySet

Крок 4 → Templates і Forms
    Bootstrap, template inheritance, Crispy Forms, context processors

Крок 5 → Auth і безпека
    Login/logout, реєстрація, групи, object-level permissions, CSRF

Крок 6 → Тестування
    TestCase, unit/integration/E2E, Selenium, GitHub Actions CI

Крок 7 → Async Django
    Async views, WebSocket, Django Channels, GroupChatConsumer

Крок 8 → Background Tasks
    Celery, Redis, фонові задачі, browser notifications

Крок 9 → Deployment
    Docker Compose, nginx, ngrok, PostgreSQL, production checklist
```

Кожен крок закінчується **Checkpoint** — списком що ти маєш вміти після нього.

---

## Шлях 2: Книга Django (теорія)

11 розділів, кожен охоплює окрему область:

```
Частина I.   Web Foundation    → HTTP, DNS, TCP, browser lifecycle
Частина II.  Django Core       → MTV, URL routing, views, middleware
Частина III. Database і ORM    → Models, QuerySet, міграції, PostgreSQL
Частина IV.  Forms і Validation → Django Forms, ModelForm, Crispy Forms
Частина V.   Templates і Frontend → Template language, Bootstrap, Admin
Частина VI.  Архітектура       → Services, Selectors, thin views
Частина VII. Auth і Security   → Sessions, permissions, OWASP, CSRF
Частина VIII. Testing          → Піраміда тестів, pytest, Selenium, CI
Частина IX.  Async і Realtime  → asyncio, ASGI, Channels, WebSocket
Частина X.   Linux і DevOps    → Linux, Docker, nginx, SSH
Частина XI.  Deployment        → VPS, Gunicorn/Uvicorn, HTTPS, monitoring
```

Розділи можна читати в будь-якому порядку залежно від потреби.

---

## Як пов'язані практика і теорія

Кожна практична глава (Zero to Hero) містить секцію **"У книзі"** — посилання на теоретичні розділи де пояснюється ЧОМ щось працює саме так.

```
Приклад:

Крок 3 → "Services і Selectors" (туторіал — ЯК написати)
  ↓  посилання "У книзі"
Частина VI → "Services і Selectors" (книга — ЧОМУ ця архітектура)
```

І навпаки — теоретичні розділи посилаються на туторіали де концепції застосовуються на практиці.

---

## Notes Chat App — фінальний проєкт

Розділ **"Notes Chat App"** у навігації — це документація самого проєкту:
- Архітектура і domain model
- Всі URL і view функції
- Тести і їх структура
- Деплой і production налаштування

Корисний як довідник коли будуєш і хочеш зрозуміти де живе конкретна функціональність.

---

## Як шукати

```
/              → пошук по всій документації (Material MkDocs)
Ctrl+K         → альтернативний shortcut для пошуку
```

Пошук працює по тексту, заголовках і прикладах коду.

---

## Ролі і фокус

| Хто ти | Рекомендований маршрут |
|--------|----------------------|
| Новачок у Django | Zero to Hero крок 1→9, паралельно книга Частина I-II |
| Досвідчений Python, перший Django | Почни з книги Частина II-III, потім Zero to Hero крок 2-3 |
| Знаєш Django, хочеш production skills | Zero to Hero крок 6-9 (тести, async, деплой) |
| Викладач | `TEACHING_GUIDE.md` у корені `docs/` |
| DevOps фокус | Частини X-XI, Крок 9 (Deployment) |

---

## Практичне завдання

1. Визнач яку роль ти берешь (новачок / досвідчений / DevOps)
2. Обери відповідний маршрут із таблиці вище
3. Переходь до першого документу маршруту

---

## Далі

→ [Структура репозиторію](repository_structure.md) — де знаходиться кожна частина коду
