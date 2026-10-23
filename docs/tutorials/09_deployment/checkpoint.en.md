# Checkpoint — Step 9

---

## What to look for and where: the final table

| Concept | Where in the code |
|-----------|-----------|
| **Docker Compose chain** | `docker-compose.yml` — `depends_on` + `healthcheck` |
| **PostgreSQL connection** | `notes_project/settings.py` — `DATABASE_URL` parsing |
| **Redis channel layer** | `settings.py` — `CHANNEL_LAYERS` with `socket_timeout=None` |
| **nginx WebSocket config** | `nginx/nginx.conf` — `map $http_upgrade` + `proxy_http_version 1.1` |
| **Static volume** | `docker-compose.yml` `staticfiles` volume + nginx `alias /staticfiles` |
| **CSRF + ngrok** | `settings.py` — `CSRF_TRUSTED_ORIGINS` from the `NGROK_DOMAIN` env |
| **entrypoint.sh chain** | `entrypoint.sh` — migrate → collectstatic → seed → uvicorn |
| **Consumer lifecycle** | `notes_app/consumers.py` — connect/receive/chat_message/disconnect |
| **database_sync_to_async** | `consumers.py` — `check_membership`, `load_history`, `save_message` |
| **XSS protection in JS** | `static/notes_app/js/group_chat.js` — `escapeHtml()` |
| **IDOR protection** | `notes_app/views.py` — `get_object_or_404(Note, pk=pk, user=request.user)` |
| **Group Q-filter** | `notes_app/selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **Seed data** | `notes_app/management/commands/seed_demo_data.py` |
| **Docker Selenium** | `tests/test_selenium.py` — `_DockerLiveServerMixin` + `SELENIUM_REMOTE_URL` |
| **Consumer tests** | `tests/test_consumers.py` — `WebsocketCommunicator` |
| **`daphne` first** | `settings.py` `INSTALLED_APPS` — `daphne` before `channels` and `django.*` |

---

## Checklist: running stack, verified URLs

- [ ] `.env` is filled in (copied from `.env.example`)
- [ ] `NGROK_AUTHTOKEN` and `NGROK_DOMAIN` are set (if you need public access)
- [ ] `docker compose up --build` finishes without errors
- [ ] `docker compose ps` — all services have the status `Up (healthy)` or `Up`
- [ ] `http://localhost` opens and shows the site (through nginx)
- [ ] Login: `demo_alice / demo1234` — successful, no 403
- [ ] `http://localhost:4040` opens (ngrok dashboard)
- [ ] Login through the ngrok URL (`https://...ngrok-free.app`) — no CSRF 403
- [ ] Group chat (WebSocket) — messages go through in real time
- [ ] Open the chat in two tabs as different users — broadcast works
- [ ] `docker compose logs nginx` shows the access log without errors
- [ ] `docker compose exec web python manage.py check --deploy` — reviewed
- [ ] Unit tests passed:

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2
```

- [ ] Selenium E2E tests passed:

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

---

## Congratulations!

You have walked the whole route from your first Django view to a production-ready deployment:

```
01 → First Django view (URL → View → Template)
02 → First model (ORM, forms, PRG)
03 → CRUD and business logic (selectors/services, N+1, transactions)
04 → Templates and Bootstrap (3-level inheritance, Crispy Forms)
05 → Authentication (login, register, UserProfile, decorators)
06 → Testing (test pyramid, TestCase, WebsocketCommunicator, Selenium)
07 → Async and WebSocket (ASGI, Channels, Consumer, channel layer)
08 → Testing Advanced (WebsocketCommunicator, TransactionTestCase, coverage)
09 → Deployment (Docker Compose, nginx, ngrok, production checklist)
```

You now know how to:

- Package a Django application into a Docker Compose stack with 6 services
- Configure nginx as a reverse proxy with WebSocket support
- Solve the CSRF problem when working through ngrok
- Set up a Redis channel layer for scalable broadcast
- Run Selenium E2E tests in Docker through Remote WebDriver
- Prepare the application for production: security checklist, secret management

---

## Navigation

[← Step 8. Testing](../08_testing/index.md)
