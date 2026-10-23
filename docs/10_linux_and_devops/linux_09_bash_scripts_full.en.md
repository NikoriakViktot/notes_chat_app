# 09. Bash scripts

## Why this matters

Imagine typing 15 commands by hand every time you deploy: `git pull`, `source .venv/bin/activate`, `pip install -r requirements.txt`, `python manage.py migrate`, `python manage.py collectstatic`, `sudo systemctl restart myapp`... It is slow, and sooner or later you will skip something or make a typo.

A Bash script is a file that contains all of these commands in order. You run a single file, and it does everything for you.

---

## Simple explanation

> A Bash script is a list of commands written to a file. Instead of typing them by hand one after another, you run a single file and it does everything for you.

---

## Shebang: the first line of a script

```bash
#!/usr/bin/env bash
```

The first line of a script always starts with `#!` (the shebang). It specifies which program should execute the file.

`/usr/bin/env bash` means "find bash via `env`" (a more reliable option than `#!/bin/bash`, because bash may live in different locations).

---

## Your first script

```bash
#!/usr/bin/env bash

echo "Starting Django project setup..."

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput

echo "Done!"
```

Save it to a file named `setup.sh`, make it executable, and run it:

```bash
chmod +x setup.sh
./setup.sh
```

---

## Variables

```bash
#!/usr/bin/env bash

PROJECT_DIR="/var/www/myapp"
VENV_DIR="$PROJECT_DIR/.venv"
APP_USER="www-data"

echo "Project: $PROJECT_DIR"
echo "Virtualenv: $VENV_DIR"
```

Rules for variables in Bash:
- No spaces: `NAME="value"` ✓, `NAME = "value"` ✗
- Read them with `$`: `$NAME` or `${NAME}`
- Quotes matter: `"$NAME"` preserves spaces

---

## Conditions (if/else)

```bash
#!/usr/bin/env bash

if [ -f ".env" ]; then
    echo ".env file found"
else
    echo "ERROR: .env file is missing"
    exit 1
fi
```

Useful checks:

| Condition | What it checks |
|---|---|
| `[ -f file ]` | the file exists |
| `[ -d dir ]` | the directory exists |
| `[ -z "$VAR" ]` | the variable is empty |
| `[ "$A" = "$B" ]` | the strings are equal |
| `[ $N -gt 0 ]` | the number is greater than 0 |

---

## Exit codes in scripts

```bash
#!/usr/bin/env bash

# Stop at the first error
set -e

git pull origin main
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate

echo "Deployment successful!"
```

`set -e` is a very useful option: if any command returns a non-zero exit code, the script stops. Without it, the script keeps running even after an error.

---

## Loops

```bash
#!/usr/bin/env bash

# Run a command for each argument
for app in users notes tags; do
    echo "Running migrations for $app..."
    python manage.py migrate $app
done

# Iterate over files
for file in *.py; do
    echo "File: $file"
done
```

---

## Command-line arguments

```bash
#!/usr/bin/env bash

ENVIRONMENT=${1:-development}   # $1 is the first argument, development by default

echo "Deploying to environment: $ENVIRONMENT"

if [ "$ENVIRONMENT" = "production" ]; then
    echo "Warning: deploying to production!"
fi
```

Running it:
```bash
./deploy.sh production
./deploy.sh            # will use development
```

---

## A real deployment script

```bash
#!/usr/bin/env bash
set -e

echo "=== Deploying the Django project ==="

# Variables
APP_DIR="/var/www/myapp"
VENV="$APP_DIR/.venv"
SERVICE_NAME="myapp"

# Update the code
cd "$APP_DIR"
git pull origin main

# Update dependencies
source "$VENV/bin/activate"
pip install -r requirements.txt --quiet

# Apply migrations
python manage.py migrate --noinput

# Collect static files
python manage.py collectstatic --noinput

# Restart the service
sudo systemctl restart "$SERVICE_NAME"

echo "=== Deployment finished! ==="
echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager
```

---

## Debugging a script

```bash
bash -x script.sh         # run with tracing (shows every command)
set -x                    # turn on tracing inside the script
set +x                    # turn off tracing
```

---

## Common beginner mistakes

**Mistake 1:** `Permission denied` when running the script
> You forgot `chmod +x script.sh`

**Mistake 2:** `./script.sh: line 1: $'\r': command not found`
> The file was saved in Windows format (CRLF). Fix it with: `sed -i 's/\r//' script.sh`

**Mistake 3:** The script keeps going after an error and breaks the server
> Add `set -e` at the start of the script

**Mistake 4:** Spaces around `=` in variables
> `NAME="value"` ✓, `NAME = "value"` ✗ — Bash will treat `NAME` as a command

---

## Practical exercise

### Task 1
Write `setup.sh` for a Django project that:
1. Checks that `.env` exists
2. Creates a virtualenv (if it does not exist)
3. Installs dependencies
4. Runs migrations

### Task 2
Write `deploy.sh` that:
1. Runs `git pull`
2. Runs `pip install -r requirements.txt`
3. Runs `python manage.py migrate`
4. Runs `python manage.py collectstatic --noinput`
5. Checks the exit code of each step

### Task 3
```bash
bash -x setup.sh 2>&1 | head -30
```
Run the script with tracing and analyze the output.

---

## Self-check

- [ ] I understand what a shebang is and why it is needed
- [ ] I can write a script with variables, conditions, and loops
- [ ] I know that `set -e` stops the script on an error
- [ ] I know how to make a script executable with `chmod +x`
- [ ] I can write a simple deployment script for Django

---

## Short summary

A Bash script is a set of commands in a file. The shebang specifies the interpreter. `set -e` stops the script on an error. Real deployment starts with writing a script that automates all the manual steps. The next step is the Makefile, another way to organize commands.
