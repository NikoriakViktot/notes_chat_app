# Seed Data

> **`seed_demo_data`** is a Django management command that fills the database with demo data for development.
> It lets you see the application right away with realistic notes, groups and chat.

---

## Why seed data

**Problem:** on the first `docker compose up` the database is empty. You see an empty application — no notes, no groups, the chat is silent. It is hard to show students what a real application looks like and hard to check the group features.

**Solution:** the seed command creates realistic demo data:
- 3 users with passwords — you can log in right away
- Groups with members — you can test group notes and chat in different tabs
- Different kinds of notes (personal, group, pinned, with reminders) — all the functionality is visible
- Messages in group chats — the chat doesn't look empty

---

## What `seed_demo_data` creates

### Users

| Login | Password | Role |
|-------|--------|------|
| `demo_alice` | `demo1234` | Member of "Команда розробки" and "Сімейний чат" |
| `demo_bob` | `demo1234` | Member of "Команда розробки" |
| `demo_carol` | `demo1234` | Member of "Команда розробки" and "Сімейний чат" |

Each user has their own `UserProfile`.

### Groups and members

| Group | Members |
|-------|---------|
| `demo_команда_розробки` ("Команда розробки", "Dev team") | alice, bob, carol |
| `demo_сімейний_чат` ("Сімейний чат", "Family chat") | alice, carol |

In the DB the group name carries the `demo_` prefix (that prefix is what `--reset` uses). Alice and Carol are members of both groups → they see the group notes and chat of both groups; Bob only those of "Команда розробки".

### Each user's notes

Each of the three users gets the same set of 10 notes of their own:

| Type | Count |
|-----|---------|
| Total (different priorities 1–3) | 10 |
| Pinned (`is_pinned=True`) | 3 |
| With reminders (`Reminder`) | 4 |
| Group (group="Команда розробки") | 3 |

### Other data

- **Notebooks:** "Робочі нотатки" (default), "Особисте", "Навчання Python"
- **Tags:** робота, особисте, навчання, важливо, ідеї, перечитати — each with a unique color
- **TodoList:** 3 lists ("Задачі спринту", "Домашні справи", "Навчальний план"), the first two TodoItems in each are done
- **ShoppingList:** 3 lists, one of them ("Спільні покупки для офісу") belongs to the "Команда розробки" group
- **ChatMessages:** 20 messages in "Команда розробки" and 10 in "Сімейний чат"

---

## `SEED_DEMO_DATA=1` at startup

When `SEED_DEMO_DATA=1` is set in `.env`, seeding runs automatically on every `docker compose up` via `entrypoint.sh`:

```sh
# entrypoint.sh
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    seed_args="--force"
    if [ "${SEED_DEMO_RESET:-0}" = "1" ]; then
        seed_args="--force --reset"
    fi
    log "Seeding demo data with args: ${seed_args}"
    python manage.py seed_demo_data ${seed_args}
fi
```

```yaml
# docker-compose.yml
web:
  environment:
    SEED_DEMO_DATA: ${SEED_DEMO_DATA:-1}
    # ↑ If .env does not contain SEED_DEMO_DATA — default 1 (seeding enabled)
    SEED_DEMO_RESET: ${SEED_DEMO_RESET:-0}
```

```bash
# .env:
SEED_DEMO_DATA=1   # enables auto-seeding on every docker compose up
```

---

## Commands

```bash
# First run (SEED_DEMO_DATA=1 in .env → automatic on docker compose up):
docker compose up

# Manually — first time (empty DB):
docker compose exec web python manage.py seed_demo_data

# Manually — reset and refill (DB already exists):
docker compose exec web python manage.py seed_demo_data --reset
# --reset: deletes all demo_* users and related data → seeds again

# Without the stack (separate container — only if the DB already has data from a previous up):
docker compose run --rm web python manage.py seed_demo_data
```

!!! note "`--force` in entrypoint.sh"
    `entrypoint.sh` runs `seed_demo_data --force` (or `--force --reset` when `SEED_DEMO_RESET=1`).
    `--force` lets the seed run even when `DEBUG=False`; it does not delete existing data.
    The command is idempotent (`update_or_create`), so running it again creates no duplicates.
    `--reset` first deletes the demo data, then seeds again.

---

## Check that the seed worked

```bash
# Quick check through the shell:
docker compose exec web python manage.py shell -c "
from django.contrib.auth.models import User
from notes_app.models import Note, ChatMessage
from django.contrib.auth.models import Group

print('Users:', User.objects.count())
print('Notes:', Note.objects.count())
print('Groups:', Group.objects.count())
print('ChatMessages:', ChatMessage.objects.count())
"

# Expected output:
# Users: 3
# Notes: 30
# Groups: 2
# ChatMessages: 30 (or more)
# (on a clean DB; the command also prints its own summary after seeding)
```

```bash
# Or directly in PostgreSQL:
docker compose exec db psql -U notes_user -d notes_db -c "
SELECT username FROM auth_user WHERE username LIKE 'demo_%';
"
#  demo_alice
#  demo_bob
#  demo_carol
```

---

## Testing group features with two accounts

The seed lets you test real scenarios:

### Scenario: group note

```
1. Browser 1: log in as demo_alice
2. Browser 2 (or Private window): log in as demo_bob
3. Alice: open a note from the "Команда розробки" group
4. Bob: open the same note (visible through group membership)
```

### Scenario: real-time group chat

```
1. Browser 1: demo_alice → Groups → "Команда розробки" → Chat
2. Browser 2: demo_bob → Groups → "Команда розробки" → Chat
3. Alice: type a message → Enter
4. Bob: the message appears instantly (WebSocket!)
```

### Scenario: data isolation

```
1. demo_carol: tries to open a personal note of demo_alice
2. → 404 (the note does not belong to carol and is not attached to a shared group)
3. demo_bob: tries to open a note of demo_alice
4. → 404 if it is a personal note, 200 if it is from "Команда розробки"
```

---

## `.env` configuration for dev

```bash
# .env (copy from .env.example)

POSTGRES_DB=notes_db
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=notes_password_dev

SECRET_KEY=dev-secret-key-not-for-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgres://notes_user:notes_password_dev@db:5432/notes_db

# Seed demo data on every docker compose up:
SEED_DEMO_DATA=1

# ngrok (only needed for public access)
NGROK_AUTHTOKEN=          # get it at ngrok.com
NGROK_DOMAIN=             # your static domain (ngrok free tier: 1 static domain)
```

Copy the template:

```bash
cp .env.example .env
# Edit: add NGROK_AUTHTOKEN and NGROK_DOMAIN if needed
```

---

## Debugging: when the seed doesn't work

### `CommandError: Demo data disabled`

```
CommandError: Demo data seeding is disabled when DEBUG=False. Use --force to override.
```

**Cause:** `seed_demo_data` checks `DEBUG = True`. In production it is disabled by default so it doesn't overwrite real data.

**Solution:** `entrypoint.sh` already passes `--force`, so this error only happens when you run it manually without the flag.

```bash
# Correct for a manual run with DEBUG=False:
docker compose exec web python manage.py seed_demo_data --force
```

### `IntegrityError: duplicate key`

The current command is idempotent: it uses `update_or_create`, so running it again without `--reset` does **not** cause this error. It can only happen in your own seed commands that use `create()`, or when the data was changed by hand:

```
django.db.utils.IntegrityError: duplicate key value violates unique constraint
"auth_user_username_key"
DETAIL: Key (username)=(demo_alice) already exists.
```

**Solution:**
```bash
docker compose exec web python manage.py seed_demo_data --reset
# --reset deletes existing demo_ users before creating new ones
```

### DB is not initialized

```
django.db.utils.OperationalError: could not connect to server
```

**Cause:** you tried to run the seed before `docker compose up` or after `docker compose down -v`.

**Solution:**
```bash
docker compose up -d
# Wait until the web container becomes healthy
docker compose ps    # web: healthy?
docker compose exec web python manage.py seed_demo_data
```

---

## Demo accounts after seeding

After a successful seed you can open `http://localhost` and log in:

```
http://localhost/accounts/login/
  Username: demo_alice
  Password: demo1234
```

Alice sees:
- Personal notes with different priorities and tags
- Pinned notes at the top of the list
- Group notes from "Команда розробки" (her own and other members')
- Todo lists with several tasks
- Shopping lists with groceries
- Group chats of both groups with message history

---

## In the book

- [Part X. Linux and DevOps](../../10_linux_and_devops/README.md) — Docker, docker compose, volume management
- [Part XI. Deployment](../../11_deployment/README.md) — production deploy, environment variables, `.env` files

---

## Official documentation

- [Django: Management Commands](https://docs.djangoproject.com/en/5.2/howto/custom-management-commands/) — how to write your own management commands
- [Django: Fixtures vs management commands](https://docs.djangoproject.com/en/5.2/howto/initial-data/) — the difference between fixtures and custom seed commands
