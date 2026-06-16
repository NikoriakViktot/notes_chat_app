# Що потрібно знати перед стартом

> Цей курс розрахований на людину, яка вже знає Python і вміє користуватись терміналом.
> Django — це не перша мова, це перший серйозний фреймворк.

---

## Обов'язкові знання

### Python — мінімальний рівень

Ти маєш вміти прочитати і написати такий код без підказок:

```python
# Функції зі значеннями за замовчуванням і *args/**kwargs
def create_note(title, content='', priority=2, **kwargs):
    return {'title': title, 'content': content, 'priority': priority}

# Класи: __init__, self, наслідування, super()
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

# Декоратори
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

**Якщо це не зрозуміло** — пройди спочатку курс по Python. Django використовує всі ці конструкції повсюдно.

### HTML — базовий рівень

```html
<!-- Структура сторінки -->
<!DOCTYPE html>
<html>
<head>
    <title>Сторінка</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <form method="post" action="/notes/new/">
        <input type="text" name="title" placeholder="Заголовок">
        <textarea name="content"></textarea>
        <button type="submit">Зберегти</button>
    </form>
    <script src="app.js"></script>
</body>
</html>
```

Потрібно розуміти: теги, атрибути, форми (`method`, `action`, `name`), посилання на CSS і JS.

### Термінал — базовий рівень

```bash
# Навігація
cd /path/to/project
ls -la
pwd

# Читання файлів
cat requirements.txt
less notes_app/views.py

# Запуск команд
python manage.py migrate
git status
docker compose up
```

Потрібно: відкрити термінал, перейти до папки, запустити команду, прочитати вивід.

### Git — мінімальний рівень

```bash
git clone https://github.com/NikoriakViktot/notes_chat_app.git
git status
git log --oneline
git diff
```

Потрібно: клонувати репозиторій, перевірити статус, подивитись зміни.

---

## Для запуску застосунку потрібен Docker

`notes_chat_app` вимагає PostgreSQL і Redis. Вони запускаються через Docker.

!!! warning "Без Docker застосунок не запуститься"
    `manage.py migrate` падає з `OperationalError` якщо немає PostgreSQL.
    `manage.py runserver` падає якщо немає `DATABASE_URL`.
    
    Є тільки один надійний спосіб запустити проєкт — `docker compose up`.

### Встановити Docker Desktop

| Система | Завантаження |
|---------|-------------|
| Windows / macOS | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| Ubuntu/Debian | `sudo apt install docker.io docker-compose-plugin` |
| WSL2 | Docker Desktop з увімкненим WSL2 integration |

Після установки перевір:

```bash
docker --version        # Docker version 24.x.x
docker compose version  # Docker Compose version v2.x.x
```

!!! note "Docker не потрібен для читання коду"
    Якщо хочеш тільки читати документацію і код — Python і редактор достатньо.
    Docker потрібен тільки коли запускаєш `docker compose up`.

---

## Що НЕ потрібно знати на старті

| Тема | Коли з'явиться |
|------|---------------|
| Linux глибоко | Розділ X — Linux і DevOps |
| nginx конфігурація | Крок 9 — Deployment |
| Redis/Celery | Крок 8 — Background Tasks |
| WebSocket протокол | Крок 7B — Channels |
| PostgreSQL команди | Крок 9 — PostgreSQL в Docker |
| JavaScript (async/await) | Крок 7B — WebSocket клієнт |

---

## Перевір себе перед початком

```bash
# Python встановлений?
python3 --version   # Python 3.11+ або 3.12

# Git встановлений?
git --version       # git version 2.x.x

# Docker встановлений?
docker --version    # Docker version 24+
```

Якщо всі три команди виводять версії — можеш починати.

---

## Далі

→ [Налаштування середовища](local_setup.md) — клонуємо репо і запускаємо стек
