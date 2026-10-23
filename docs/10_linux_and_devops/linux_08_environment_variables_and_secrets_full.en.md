# 08. Environment Variables and Secrets

## Why this matters

A Django project contains things that **must not be stored in code**: database passwords, `SECRET_KEY`, API keys, tokens. If they end up in Git, the whole world (or attackers) will see them.

Environment variables are a way to pass confidential data to a program without writing it into the code.

---

## A simple explanation

> Imagine your Django project is a cake recipe. The code is the recipe (you can share it). The database passwords and SECRET_KEY are the secret ingredient that you don't write in the recipe but pass on separately, by word of mouth.

Environment variables are the "word of mouth" part. They live in the operating system or in a `.env` file, but **not in the code**.

---

## What an environment variable is

An environment variable is a `KEY=value` pair that exists in a process's runtime environment.

```bash
echo $HOME          # /home/student
echo $USER          # student
echo $PATH          # /usr/bin:/usr/local/bin:...
printenv            # all environment variables
```

`PATH` is one of the most important variables. Linux looks for programs in the directories listed in `PATH`. That's why you can type `python` instead of `/usr/bin/python3`.

---

## Managing variables in the shell

### Set a variable in the current session

```bash
export DEBUG=True
export DATABASE_URL=postgres://user:pass@localhost/mydb
```

### View the value

```bash
echo $DEBUG
echo $DATABASE_URL
printenv DEBUG
```

### Remove a variable

```bash
unset DEBUG
```

> A variable set with `export` exists only in the current terminal session. Once the terminal is closed, it's gone.

---

## The .env file

So you don't have to type the variables by hand every time, they are stored in a `.env` file:

```env
DEBUG=True
SECRET_KEY=your-very-secret-key-change-me-in-production
DATABASE_URL=postgres://app_user:app_password@localhost:5432/app_db
ALLOWED_HOSTS=localhost,127.0.0.1
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=yourmail@gmail.com
EMAIL_HOST_PASSWORD=your_app_password
REDIS_URL=redis://localhost:6379/0
```

`.env` is just a text file. The format: `KEY=value`, one per line. No spaces around `=`.

### .env and .gitignore

`.env` is always added to `.gitignore`:

```bash
# .gitignore
.env
.env.local
.env.production
.venv/
__pycache__/
*.pyc
```

Instead of `.env`, Git stores `.env.example` — a template without real values:

```env
# .env.example
DEBUG=True
SECRET_KEY=change-me
DATABASE_URL=postgres://user:password@localhost:5432/dbname
ALLOWED_HOSTS=localhost
```

---

## Django and environment variables

### The python-decouple package

```bash
pip install python-decouple dj-database-url
```

```python
# settings.py
import dj_database_url
from decouple import config

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
DATABASE_URL = config('DATABASE_URL')
# decouple only reads the string — DATABASES must be built from it separately:
DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')
```

### The django-environ package

```bash
pip install django-environ
```

```python
# settings.py
import environ

env = environ.Env(
    DEBUG=(bool, False)
)
environ.Env.read_env('.env')

SECRET_KEY = env('SECRET_KEY')
DEBUG = env('DEBUG')
DATABASES = {'default': env.db()}
```

### Or os.environ directly

```python
import os

SECRET_KEY = os.environ.get('SECRET_KEY', 'fallback-only-for-dev')
DEBUG = os.environ.get('DEBUG', 'False') == 'True'
```

---

## Passing variables through systemd

If Django runs as a systemd service, variables are passed via `EnvironmentFile`:

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Django App
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/myapp
EnvironmentFile=/var/www/myapp/.env
ExecStart=/var/www/myapp/.venv/bin/gunicorn myapp.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
```

In this case the `.env` file is read by systemd, not by bash:
```bash
sudo chmod 600 /var/www/myapp/.env
sudo chown www-data:www-data /var/www/myapp/.env
```

---

## Passing variables to Docker

```yaml
# docker-compose.yml
services:
  web:
    build: .
    env_file:
      - .env
    environment:
      - DEBUG=False
```

or via a separate file:
```bash
docker run --env-file .env django-app
```

---

## Security rules

```text
✓ Keep all secrets in .env
✓ Add .env to .gitignore BEFORE the first commit
✓ Keep .env.example in Git (without real values)
✓ Permissions on .env — 600 (only the owner can read)
✓ In production: different values than in dev

✗ Don't store SECRET_KEY or passwords in settings.py
✗ Don't commit .env to Git
✗ Don't send .env by email or Slack
✗ Don't use the same SECRET_KEY in dev and production
```

---

## Common beginner mistakes

**Mistake 1:** Committed `.env` with real passwords
> Change all passwords and keys immediately. Remove it from the Git history: `git filter-branch` or `git-filter-repo`. Assume they are compromised.

**Mistake 2:** `KeyError: 'SECRET_KEY'` when starting Django
> The variable isn't set. Check: does the `.env` file exist? Is it being read correctly?

**Mistake 3:** The same `DEBUG=True` value on dev and on production
> In production, always `DEBUG=False`. If `DEBUG=True` in production, Django shows stack traces to every user.

---

## Practical exercise

### Task 1
```bash
export MY_NAME="Linux Student"
echo "Hello, $MY_NAME!"
printenv MY_NAME
```

### Task 2
Create a Django project and move `SECRET_KEY` into `.env`:
```bash
django-admin startproject config .
pip install python-decouple
```
In `settings.py`, replace `SECRET_KEY = '...'` with reading it from `.env`.

### Task 3
Make sure `.gitignore` contains `.env`. Run `git status` and check that `.env` doesn't appear in the list of files to commit.

---

## Self-check

- [ ] I understand what an environment variable is and why it's needed
- [ ] I can set a variable with `export` and read it with `echo $VAR`
- [ ] I know the format of a `.env` file
- [ ] I understand why `.env` must not be committed to Git
- [ ] I can read variables in Django with `python-decouple` or `os.environ`

---

## Short summary

Environment variables are a way to keep secrets separate from code. Django reads `SECRET_KEY`, database passwords, and email settings from `.env` or from environment variables. `.env` always goes in `.gitignore`. The next step is Bash scripts for automation.
