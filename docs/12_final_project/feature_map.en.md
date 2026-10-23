# Feature Map

What is implemented in Notes Chat App and where it lives in the code.

---

## HTTP Features

| Feature | URL | View / service | Status |
|---------|-----|--------------|--------|
| Registration | `/register/` | `register` (notes_app/views.py) | ✅ |
| Log in / log out | `/accounts/login/`, `/accounts/logout/` | Django built-in | ✅ |
| Password change | `/accounts/password_change/` | Django built-in | ✅ |
| Note list | `/notes/` | `note_list` | ✅ |
| Note detail | `/notes/<pk>/` | `note_detail` | ✅ |
| Create a note | `/notes/new/` | `note_create` | ✅ |
| Edit a note | `/notes/<pk>/edit/` | `note_edit` | ✅ |
| Delete a note | `/notes/<pk>/delete/` | `note_delete` | ✅ |
| Pin/unpin a note | `/notes/<pk>/edit/` (the `is_pinned` field) | `note_edit`; service `services.toggle_pin_note` (no separate URL) | ✅ |
| Archive a note | — (no separate URL) | `services.archive_note` | ⚠️ service only |
| Notebook list | `/notebooks/` | `notebook_list` | ✅ |
| Create a tag | `/tags/new/` | `tag_create` | ✅ |
| Reminders | `/notes/<note_pk>/reminders/add/` | `reminder_create` | ✅ |
| Todo lists | `/todo/` | `todo_list_list` | ✅ |
| Shopping lists | `/shopping/` | `shopping_list_list` | ✅ |
| Groups | `/groups/` | `group_list` | ✅ |
| Chat (page) | `/groups/<pk>/chat/` | `group_chat` | ✅ |

---

## WebSocket Features

| Feature | URL | Consumer | Status |
|---------|-----|----------|--------|
| Real-time chat | `/ws/groups/<pk>/chat/` | `GroupChatConsumer` | ✅ |

---

## Background Task Features

| Feature | File | Trigger | Status |
|---------|------|--------|--------|
| Email reminders | `notes_app/tasks.py` | Celery Beat (60 sec) | ✅ |
| Repeating reminders (daily/weekly/monthly) | `notes_app/tasks.py` → `_schedule_next()` | after `send_reminder_notifications` | ✅ |
| Browser Toast notifications | `notes_app/static/notes_app/js/reminders.js` | HTTP polling (60 sec) | ✅ |
| JSON endpoint for polling | `/reminders/check/` → `reminders_check` | fetch in the browser | ✅ |

---

## Sharing mechanisms

| Model | Sharing type | Field |
|--------|------------|------|
| `Note` | through a Group | `group = FK(Group, SET_NULL)` |
| `ShoppingList` | through a Group and directly | `group = FK(Group)` + `shared_with = M2M(User)` |
| `TodoList` | directly with users | `shared_with = M2M(User)` |
| `ChatMessage` | through Group membership | group FK |

---

## Not implemented

| Feature | Reason |
|---------|---------|
| DRF serializers / REST API | the course focuses on templates |
| Async HTTP views | `async_views.py` is absent from the current working tree |
| Kubernetes | outside the scope of a learning project |
| Production Docker | there is a Dockerfile, but it needs more work (SECRET_KEY, DEBUG, HTTPS) |
