# Final Project Architecture

| Компонент | Файл | Відповідальність |
| --- | --- | --- |
| Settings | `notes_project/settings.py` | apps, DB, auth, static, Channels |
| Root URLs | `notes_project/urls.py` | admin, accounts, app include |
| App URLs | `notes_app/urls.py` | HTTP routes |
| WebSocket routing | `notes_project/routing.py` | WS routes |
| Models | `notes_app/models.py` | domain schema |
| Views | `notes_app/views.py` | HTTP request/response |
| Forms | `notes_app/forms.py` | validation and Crispy layout |
| Selectors | `notes_app/selectors.py` | read queries |
| Services | `notes_app/services.py` | write operations |
| Consumer | `notes_app/consumers.py` | WebSocket chat |
| Templates | `templates/`, `notes_app/templates/` | HTML |
| Tests | `notes_app/tests/` | automated checks |
