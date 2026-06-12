# Feature Map

| Feature | URL/code | Status |
| --- | --- | --- |
| Notes CRUD | `/notes/`, `notes_app/views.py` | implemented |
| Notebooks | `/notebooks/` | implemented |
| Tags | `/tags/new/` | implemented |
| Reminders | `/notes/<note_pk>/reminders/add/` | implemented |
| Todo lists | `/todo/` | implemented |
| Shopping lists | `/shopping/` | implemented |
| Direct sharing | `shared_with` fields | implemented |
| Groups | `/groups/` | implemented |
| Group chat | `/groups/<pk>/chat/`, `/ws/groups/<pk>/chat/` | implemented |
| Async HTTP demo | legacy `async_*` modules | inactive; files absent from working tree |
| Docker deployment | `Dockerfile`, `docker-compose.yml` | draft, needs path fix |
| Serializers/API | none in app code | not implemented |
| Celery/tasks | none in app code | not implemented |
