# Development Workflow

> Практичний гід по щоденній роботі з production стеком `notes_chat_app`.
> Цей розділ містить унікальний контент: реальні workflows, debug tips і корисні команди.

---

## Типовий workflow: перший запуск

```bash
# 1. Скопіювати конфігурацію:
cp .env.example .env

# 2. Відредагувати .env:
#   - SECRET_KEY  — згенеруй (інструкція нижче)
#   - NGROK_AUTHTOKEN — з https://dashboard.ngrok.com/authtokens
#   - NGROK_DOMAIN — з https://dashboard.ngrok.com/domains
#   - SEED_DEMO_DATA=1 — щоб одразу мати демо-дані

# 3. Збілдити і запустити:
docker compose up --build
# --build: перезбирає образ (потрібно при першому запуску або зміні Dockerfile/requirements)

# 4. Переконатись що все піднялось:
docker compose ps

# 5. Відкрити застосунок:
# http://localhost — через nginx (логін: demo_alice / demo1234)
# http://localhost:4040 — ngrok dashboard
```

### Очікуваний вивід

```
db-1       | database system is ready to accept connections
redis-1    | Ready to accept connections
web-1      |   Applying notes_app.0001_initial... OK
web-1      | 128 static files copied to '/app/staticfiles'
web-1      | Seeding demo data...
web-1      | INFO:     Uvicorn running on http://0.0.0.0:8001
nginx-1    | Starting nginx
ngrok-1    | started tunnel session ... url=https://your-domain.ngrok-free.app
```

---

## Щоденна розробка

```bash
# Підняти стек (без rebuild якщо Dockerfile не змінився):
docker compose up

# Слідкувати за логами Django у реальному часі:
docker compose logs -f web

# Слідкувати за логами nginx:
docker compose logs -f nginx
```

---

## Після зміни `requirements.txt` або `Dockerfile`

```bash
# Перебілдити web контейнер:
docker compose up --build

# Без кешу (після зміни pip dependencies що могли бути закешовані):
docker compose build --no-cache web
docker compose up
```

---

## Зміна коду Python — uvicorn `--reload`

`uvicorn` запускається з `--reload` у `entrypoint.sh`. При зміні будь-якого `.py` файлу uvicorn автоматично перезапускається:

```bash
# Лог при авторезапуску:
web-1  | WARNING:  Detected file change in 'notes_app/views.py'. Reloading...
web-1  | INFO:     Started server process [1]
web-1  | INFO:     Application startup complete.
```

Для шаблонів (`.html`) і статики (`.css`, `.js`) — перезавантаж браузер вручну.

---

## Нова міграція

```bash
# 1. Змінив models.py → створити міграцію:
docker compose exec web python manage.py makemigrations

# 2. Застосувати міграцію:
docker compose exec web python manage.py migrate

# 3. Перевірити стан:
docker compose exec web python manage.py showmigrations
# Всі міграції мають мати [X]
```

---

## Django shell

```bash
docker compose exec web python manage.py shell

# Приклади у shell:
>>> from notes_app.models import Note, User
>>> User.objects.count()
4
>>> Note.objects.filter(user__username='demo_alice').count()
8
>>> from notes_app import selectors
>>> selectors.get_user_tags(User.objects.get(username='demo_alice'))
<QuerySet [<Tag: django>, <Tag: python>, <Tag: ідеї>]>
```

---

## Зупинка

```bash
docker compose down           # зупинити (дані в volumes зберігаються)
docker compose down -v        # зупинити + видалити volumes (скинути БД!)
docker compose down --rmi all # зупинити + видалити images
docker compose restart web    # перезапустити тільки web сервіс
```

---

## Debug tips

```bash
# Статус всіх контейнерів:
docker compose ps

# Переглянути детальний стан і health:
docker compose ps -a

# Увійти в shell web контейнера:
docker compose exec web bash

# Переглянути змінні оточення у контейнері:
docker compose exec web env | grep -E 'DEBUG|SECRET|REDIS|DATABASE|NGROK'

# Перевірити мережу:
docker network inspect notes_chat_app_app-net

# Тест connectivity між контейнерами:
docker compose exec web ping db
docker compose exec web ping redis
docker compose exec nginx curl -I http://web:8001/accounts/login/

# Production readiness check:
docker compose exec web python manage.py check --deploy
```

---

## Корисні команди: Django management

```bash
docker compose exec web python manage.py check --deploy    # перевірка production readiness
docker compose exec web python manage.py showmigrations     # стан міграцій
docker compose exec web python manage.py createsuperuser    # admin access
docker compose exec web python manage.py dbshell           # psql до PostgreSQL
docker compose exec web python manage.py collectstatic     # зібрати static вручну
docker compose exec web python manage.py seed_demo_data --reset  # скинути демо-дані
```

---

## Корисні команди: PostgreSQL

```bash
# Підключитись до PostgreSQL напряму:
docker compose exec db psql -U notes_user -d notes_db

# Команди у psql:
\dt          # список таблиць
\d note      # схема таблиці note
SELECT id, username, email FROM auth_user;
SELECT count(*) FROM notes_app_note;
\q           # вийти
```

---

## Корисні команди: Redis

```bash
# Підключитись до Redis напряму:
docker compose exec redis redis-cli

# Команди у redis-cli:
KEYS *            # всі ключі (обережно на великих БД!)
TYPE channels:*   # тип ключа
TTL channels:*    # TTL ключа
MONITOR           # live stream всіх команд (Ctrl+C щоб зупинити)
```

---

## Корисні команди: nginx

```bash
# Перевірити конфіг nginx:
docker compose exec nginx nginx -t

# Перезапустити nginx (після зміни nginx.conf):
docker compose restart nginx

# Тест upstream з середини nginx контейнера:
docker compose exec nginx curl -I http://web:8001/accounts/login/
```

---

## Читання логів nginx

```
nginx-1  | 172.29.0.1 - - [13/Jun/2026:10:00:00 +0000] "GET /notes/ HTTP/1.1" 200 4523 "-" "Mozilla..."
          │             │                               │             │    │
          IP клієнта    Час                             Метод+URL     Статус  Байти

nginx-1  | "GET /ws/groups/7/chat/ HTTP/1.1" 101 839
                                                  ↑ 101 = WebSocket upgrade SUCCESS

nginx-1  | "GET /static/admin/css/base.css HTTP/1.1" 304 0
                                                       ↑ 304 = Not Modified (браузер кешує)

nginx-1  | "POST /accounts/login/ HTTP/1.1" 302 0
                                              ↑ 302 = Redirect після успішного логіну
```

---

## Доступ після запуску

```bash
# Local:
http://localhost          # через nginx
http://localhost:8001     # напряму до uvicorn (для Selenium тестів)
http://localhost:4040     # ngrok dashboard
http://localhost:7900     # VNC (Selenium Chrome браузер живцем)

# Public (через ngrok):
https://your-domain.ngrok-free.app

# Демо-облікові записи (пароль: demo1234):
# demo_alice, demo_bob, demo_carol
```

---

## У книзі

- [Частина X. Linux і DevOps](../../10_linux_and_devops/README.md) — Docker Compose команди, логи, налагодження контейнерів, docker exec, docker logs
- [Частина XI. Deployment](../../11_deployment/README.md) — development vs production workflow, environment management

---

## Офіційна документація

- [Docker Compose: CLI reference](https://docs.docker.com/reference/cli/docker/compose/) — up, down, exec, run, logs, ps, restart
- [Docker: docker logs](https://docs.docker.com/reference/cli/docker/container/logs/) — `--since`, `--follow`, `--tail`
- [Django: Management commands](https://docs.djangoproject.com/en/5.2/ref/django-admin/) — check, showmigrations, makemigrations, migrate, shell, dbshell
