# Async and Chat

WebSocket chat is the real async feature in the current project.

Files:

- `notes_project/asgi.py`
- `notes_project/routing.py`
- `notes_app/consumers.py`
- `notes_app/static/notes_app/js/group_chat.js`
- `notes_app/templates/notes_app/group_chat.html`

`InMemoryChannelLayer` is fine for one-process development. Redis is needed for multi-worker production.
