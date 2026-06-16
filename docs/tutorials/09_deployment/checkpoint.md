# Checkpoint — Крок 9

---

## Що і де шукати: фінальна таблиця

| Концепція | Де у коді |
|-----------|-----------|
| **Docker Compose ланцюг** | `docker-compose.yml` — `depends_on` + `healthcheck` |
| **PostgreSQL підключення** | `notes_project/settings.py` — `DATABASE_URL` парсинг |
| **Redis channel layer** | `settings.py` — `CHANNEL_LAYERS` з `socket_timeout=None` |
| **nginx WebSocket config** | `nginx/nginx.conf` — `map $http_upgrade` + `proxy_http_version 1.1` |
| **Static volume** | `docker-compose.yml` `staticfiles` volume + nginx `alias /staticfiles` |
| **CSRF + ngrok** | `settings.py` — `CSRF_TRUSTED_ORIGINS` з `NGROK_DOMAIN` env |
| **entrypoint.sh ланцюг** | `entrypoint.sh` — migrate → collectstatic → seed → uvicorn |
| **Consumer lifecycle** | `notes_app/consumers.py` — connect/receive/chat_message/disconnect |
| **database_sync_to_async** | `consumers.py` — `check_membership`, `load_history`, `save_message` |
| **XSS захист у JS** | `static/notes_app/js/group_chat.js` — `escapeHtml()` |
| **IDOR захист** | `notes_app/views.py` — `get_object_or_404(Note, pk=pk, user=request.user)` |
| **Q-filter групи** | `notes_app/selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **Seed data** | `notes_app/management/commands/seed_demo_data.py` |
| **Docker Selenium** | `tests/test_selenium.py` — `_DockerLiveServerMixin` + `SELENIUM_REMOTE_URL` |
| **Consumer тести** | `tests/test_consumers.py` — `WebsocketCommunicator` |
| **`daphne` перший** | `settings.py` `INSTALLED_APPS` — `daphne` перед `channels` і `django.*` |

---

## Чеклист: запущений стек, перевірені URL

- [ ] `.env` заповнений (скопійований з `.env.example`)
- [ ] `NGROK_AUTHTOKEN` і `NGROK_DOMAIN` встановлені (якщо потрібен публічний доступ)
- [ ] `docker compose up --build` завершується без помилок
- [ ] `docker compose ps` — всі сервіси мають статус `Up (healthy)` або `Up`
- [ ] `http://localhost` відкривається і показує сайт (через nginx)
- [ ] Логін: `demo_alice / demo1234` — успішний, без 403
- [ ] `http://localhost:4040` відкривається (ngrok dashboard)
- [ ] Login через ngrok URL (`https://...ngrok-free.app`) — без CSRF 403
- [ ] Груповий чат (WebSocket) — повідомлення проходять в реальному часі
- [ ] Відкрий чат в двох вкладках різних юзерів — broadcast працює
- [ ] `docker compose logs nginx` показує access log без помилок
- [ ] `docker compose exec web python manage.py check --deploy` — переглянуто
- [ ] Unit тести пройшли:

```bash
docker compose run --rm web python manage.py test \
  notes_app.tests.test_models \
  notes_app.tests.test_services \
  notes_app.tests.test_forms \
  notes_app.tests.test_views \
  notes_app.tests.test_consumers \
  -v 2
```

- [ ] Selenium E2E тести пройшли:

```bash
docker compose up -d
docker compose exec web python manage.py test notes_app.tests.test_selenium -v 2
```

---

## Вітаємо!

Ти пройшов весь маршрут від першого Django view до production-ready deployment:

```
01 → Перший Django view (URL → View → Template)
02 → Перша модель (ORM, форми, PRG)
03 → CRUD та бізнес-логіка (selectors/services, N+1, транзакції)
04 → Шаблони та Bootstrap (3-рівневе наслідування, Crispy Forms)
05 → Автентифікація (login, register, UserProfile, декоратори)
06 → Тестування (піраміда тестів, TestCase, WebsocketCommunicator, Selenium)
07 → Async та WebSocket (ASGI, Channels, Consumer, channel layer)
08 → Testing Advanced (WebsocketCommunicator, TransactionTestCase, coverage)
09 → Deployment (Docker Compose, nginx, ngrok, production checklist)
```

Ти знаєш як:

- Запакувати Django застосунок у Docker Compose стек з 6 сервісами
- Налаштувати nginx як reverse proxy з підтримкою WebSocket
- Вирішити проблему CSRF при роботі через ngrok
- Налагодити Redis channel layer для масштабованого broadcast
- Запустити Selenium E2E тести у Docker через Remote WebDriver
- Підготувати застосунок до production: security checklist, secret management

---

## Навігація

[← Крок 8. Testing](../08_testing/index.md)
