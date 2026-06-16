# Feature Map

Що реалізовано у Notes Chat App і де знаходиться у коді.

---

## HTTP Features

| Feature | URL | View / сервіс | Статус |
|---------|-----|--------------|--------|
| Реєстрація | `/register/` | `register` (notes_app/views.py) | ✅ |
| Вхід / вихід | `/accounts/login/`, `/accounts/logout/` | Django built-in | ✅ |
| Зміна паролю | `/accounts/password_change/` | Django built-in | ✅ |
| Список нотаток | `/notes/` | `note_list` | ✅ |
| Деталь нотатки | `/notes/<pk>/` | `note_detail` | ✅ |
| Створення нотатки | `/notes/new/` | `note_create` | ✅ |
| Редагування нотатки | `/notes/<pk>/edit/` | `note_update` | ✅ |
| Видалення нотатки | `/notes/<pk>/delete/` | `note_delete` | ✅ |
| Пін/відпін нотатки | `/notes/<pk>/pin/` | `services.toggle_pin` | ✅ |
| Архівування нотатки | `/notes/<pk>/archive/` | `services.toggle_archive` | ✅ |
| Список записників | `/notebooks/` | `notebook_list` | ✅ |
| Список тегів | `/tags/` | `tag_list` | ✅ |
| Нагадування | `/notes/<note_pk>/reminders/add/` | `reminder_create` | ✅ |
| Todo lists | `/todo/` | `todo_list_view` | ✅ |
| Shopping lists | `/shopping/` | `shopping_list_view` | ✅ |
| Групи | `/groups/` | `group_list` | ✅ |
| Чат (сторінка) | `/groups/<pk>/chat/` | `group_chat` | ✅ |

---

## WebSocket Features

| Feature | URL | Consumer | Статус |
|---------|-----|----------|--------|
| Real-time чат | `/ws/groups/<pk>/chat/` | `GroupChatConsumer` | ✅ |

---

## Background Task Features

| Feature | Файл | Тригер | Статус |
|---------|------|--------|--------|
| Email-нагадування | `notes_app/tasks.py` | Celery Beat (60 сек) | ✅ |
| Повторювані нагадування (daily/weekly/monthly) | `notes_app/tasks.py` → `_schedule_next()` | після `send_reminder_notifications` | ✅ |
| Browser Toast-нотифікації | `notes_app/static/notes_app/js/reminders.js` | HTTP polling (60 сек) | ✅ |
| JSON endpoint для polling | `/reminders/check/` → `reminders_check` | fetch у браузері | ✅ |

---

## Механізми ділення

| Модель | Тип ділення | Поле |
|--------|------------|------|
| `Note` | через Group | `group = FK(Group, SET_NULL)` |
| `ShoppingList` | через Group і прямо | `group = FK(Group)` + `shared_with = M2M(User)` |
| `TodoList` | прямо з користувачами | `shared_with = M2M(User)` |
| `ChatMessage` | через Group membership | group FK |

---

## Не реалізовано

| Feature | Причина |
|---------|---------|
| DRF serializers / REST API | навчальний фокус на templates |
| Async HTTP views | `async_views.py` відсутній у поточному working tree |
| Kubernetes | поза scope навчального проєкту |
| Production Docker | є Dockerfile, але потребує доопрацювання (SECRET_KEY, DEBUG, HTTPS) |
