# Setup

## Локально

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

## ASGI для WebSocket

```bash
uvicorn notes_project.asgi:application --reload --port 8001
```

## Відомий blocker

Async HTTP demo files (`async_views.py`, `async_selectors.py`, `async_services.py`) у поточному working tree відсутні, тому вони не подаються як активна feature. WebSocket chat лишається активним async/ASGI прикладом.
