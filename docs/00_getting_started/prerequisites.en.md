# What You Need to Know Before You Start

> This course is designed for someone who already knows Python and can use the terminal.
> Django is not your first language — it is your first serious framework.

---

## Required knowledge

### Python — minimum level

You should be able to read and write code like this without hints:

```python
# Functions with default values and *args/**kwargs
def create_note(title, content='', priority=2, **kwargs):
    return {'title': title, 'content': content, 'priority': priority}

# Classes: __init__, self, inheritance, super()
class Note:
    def __init__(self, title, user):
        self.title = title
        self.user = user

    def __str__(self):
        return self.title

class PinnedNote(Note):
    def __init__(self, title, user):
        super().__init__(title, user)
        self.is_pinned = True

# List/dict comprehensions
notes = [n for n in all_notes if n.user == current_user]
tag_map = {tag.id: tag.name for tag in tags}

# Decorators
def login_required(func):
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect('/login/')
        return func(request, *args, **kwargs)
    return wrapper

# Context managers
with open('data.json') as f:
    data = json.load(f)

# Exception handling
try:
    note = Note.objects.get(pk=pk)
except Note.DoesNotExist:
    raise Http404
```

**If this is not clear**, take a Python course first. Django uses all of these constructs everywhere.

### HTML — basic level

```html
<!-- Page structure -->
<!DOCTYPE html>
<html>
<head>
    <title>Page</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <form method="post" action="/notes/new/">
        <input type="text" name="title" placeholder="Title">
        <textarea name="content"></textarea>
        <button type="submit">Save</button>
    </form>
    <script src="app.js"></script>
</body>
</html>
```

You need to understand: tags, attributes, forms (`method`, `action`, `name`), links to CSS and JS.

### Terminal — basic level

```bash
# Navigation
cd /path/to/project
ls -la
pwd

# Reading files
cat requirements.txt
less notes_app/views.py

# Running commands
python manage.py migrate
git status
docker compose up
```

You need to be able to: open a terminal, go to a folder, run a command, read the output.

### Git — minimum level

```bash
git clone https://github.com/NikoriakViktot/notes_chat_app.git
git status
git log --oneline
git diff
```

You need to be able to: clone a repository, check the status, look at changes.

---

## Running the application requires Docker

`notes_chat_app` requires PostgreSQL and Redis. They run through Docker.

!!! warning "The application will not start without Docker"
    `manage.py migrate` fails with `OperationalError` if there is no PostgreSQL.
    `manage.py runserver` fails if there is no `DATABASE_URL`.
    
    There is only one reliable way to run the project — `docker compose up`.

### Install Docker Desktop

| System | Download |
|---------|-------------|
| Windows / macOS | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| Ubuntu/Debian | `sudo apt install docker.io docker-compose-plugin` |
| WSL2 | Docker Desktop with WSL2 integration enabled |

After installing, check:

```bash
docker --version        # Docker version 24.x.x
docker compose version  # Docker Compose version v2.x.x
```

!!! note "Docker is not needed to read the code"
    If you only want to read the documentation and the code, Python and an editor are enough.
    Docker is needed only when you run `docker compose up`.

---

## What you do NOT need to know at the start

| Topic | When it appears |
|------|---------------|
| Linux in depth | Part X — Linux and DevOps |
| nginx configuration | Step 9 — Deployment |
| Redis/Celery | Step 8 — Background Tasks |
| The WebSocket protocol | Step 7B — Channels |
| PostgreSQL commands | Step 9 — PostgreSQL in Docker |
| JavaScript (async/await) | Step 7B — WebSocket client |

---

## Check yourself before you start

```bash
# Is Python installed?
python3 --version   # Python 3.11+ or 3.12

# Is Git installed?
git --version       # git version 2.x.x

# Is Docker installed?
docker --version    # Docker version 24+
```

If all three commands print versions, you can begin.

---

## Next

→ [Setting up the environment](local_setup.md) — clone the repo and start the stack
