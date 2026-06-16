# Django — Система команд

> `python manage.py` — командний рядок Django.
> Кожна команда — Python клас що має доступ до всього Django (ORM, settings, signals).

---

## Навіщо команди

Django команди — це скрипти для задач поза HTTP: міграції, завантаження даних, очищення старих записів, відправка розсилок.

```python
# Звичайний Python скрипт — немає доступу до Django ORM без setup:
python scripts/seed_data.py     # ← ImportError або AppRegistryNotReady

# Django command — ORM, settings, all apps готові автоматично:
python manage.py seed_demo_data
```

---

## Шпаргалка — Таблиця команд

| Команда | Синтаксис | Коли |
|---------|-----------|------|
| Запустити сервер | `python manage.py runserver` | Розробка |
| Генерація міграцій | `python manage.py makemigrations` | Після зміни `models.py` |
| Застосування міграцій | `python manage.py migrate` | Після `makemigrations` |
| Переглянути SQL | `python manage.py sqlmigrate notes_app 0004` | Debug |
| Статус міграцій | `python manage.py showmigrations` | Аудит БД |
| Відкат міграції | `python manage.py migrate notes_app 0003` | Rollback |
| Створити суперюзера | `python manage.py createsuperuser` | Після першої міграції |
| Зібрати статику | `python manage.py collectstatic` | Перед деплоєм |
| Python shell | `python manage.py shell` | Debug ORM |
| SQL shell | `python manage.py dbshell` | Прямий SQL |
| Запустити тести | `python manage.py test` | CI/CD |
| Перевірити проєкт | `python manage.py check` | Перевірка конфігурації |
| Аудит безпеки | `python manage.py check --deploy` | Перед деплоєм |
| Власна команда | `python manage.py seed_demo_data` | Автоматизація |

---

## Анатомія `manage.py`

```python
# manage.py — у корені кожного Django проєкту
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notes_project.settings')
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
```

Коли ти запускаєш `python manage.py migrate`:
1. `os.environ` встановлює який `settings.py` використовувати
2. Django ініціалізується (всі `INSTALLED_APPS`, `DATABASES`, etc.)
3. `execute_from_command_line(['manage.py', 'migrate'])` шукає команду `migrate` серед всіх `management/commands/`

---

## Де Django шукає команди

```
кожна INSTALLED_APP/
└── management/
    └── commands/
        └── *.py   ← кожен файл = одна команда
```

`notes_app` має:

```
notes_app/
└── management/
    └── commands/
        └── seed_demo_data.py   ← python manage.py seed_demo_data
```

---

## Основні вбудовані команди

### `makemigrations` — Фіксація змін схеми

Сканує `models.py`, порівнює зі збереженим станом і генерує Python-скрипт:

```bash
python manage.py makemigrations
python manage.py makemigrations notes_app         # для конкретного app
python manage.py makemigrations --name add_tags   # з описовим іменем
```

**Важливо:** Команда **не вносить змін до бази даних** — лише створює план.

```python
# Приклад згенерованого файлу migrations/0005_note_is_archived.py
class Migration(migrations.Migration):
    dependencies = [('notes_app', '0004_chatmessage')]
    operations = [
        migrations.AddField(
            model_name='note',
            name='is_archived',
            field=models.BooleanField(default=False),
        ),
    ]
```

### `migrate` — Застосування міграцій

```bash
python manage.py migrate           # всі apps
python manage.py migrate notes_app # тільки один app
python manage.py migrate notes_app 0003  # відкат до конкретної версії
```

**Як відстежується:** Django зберігає застосовані міграції в таблиці `django_migrations`.

```bash
# Переглянути SQL перед застосуванням
python manage.py sqlmigrate notes_app 0004
# BEGIN;
# CREATE TABLE "notes_app_chatmessage" (...)
# CREATE INDEX chat_group_ts_idx ON ...
# COMMIT;
```

### `runserver` — Dev сервер

```bash
python manage.py runserver           # localhost:8000
python manage.py runserver 0.0.0.0:8001  # доступний у мережі
```

!!! danger "Тільки для розробки"
    `runserver` — однопотоковий, без SSL, без буферизації. У production — тільки Uvicorn або Gunicorn + nginx.

### `shell` — Інтерактивний ORM

```bash
python manage.py shell
```

```python
>>> from notes_app.models import Note
>>> from django.contrib.auth.models import User
>>> user = User.objects.get(username='demo_alice')
>>> notes = Note.objects.filter(user=user)
>>> notes.count()
5
>>> qs = notes.select_related('notebook')
>>> print(qs.query)   # ← показує SQL
```

### `check --deploy` — Аудит безпеки

```bash
python manage.py check --deploy
```

Перевіряє: `DEBUG=False`, `SECRET_KEY` не дефолтний, `ALLOWED_HOSTS`, HTTPS headers, cookie безпеку.

### `collectstatic` — Підготовка статики

```bash
python manage.py collectstatic
```

Збирає всі static файли в `STATIC_ROOT`. У production nginx роздає звідти без Django.

---

## Кастомна команда — `seed_demo_data`

Повна реалізація з `notes_app/management/commands/seed_demo_data.py`:

```python
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User, Group
from notes_app.models import Note, Tag, Notebook

class Command(BaseCommand):
    help = 'Seed demo data (users, groups, notes, todos, chats)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--reset',
            action='store_true',
            help='Delete existing demo data before seeding',
        )

    def handle(self, *args, **options):
        if options['reset']:
            self.stdout.write('Resetting demo data...')
            User.objects.filter(username__startswith='demo_').delete()

        # get_or_create → безпечно для повторного запуску
        alice, created = User.objects.get_or_create(
            username='demo_alice',
            defaults={'email': 'alice@demo.com'}
        )
        if created:
            alice.set_password('demo1234')
            alice.save()
            self.stdout.write(self.style.SUCCESS('✓ Created user: demo_alice'))
        else:
            self.stdout.write('  User demo_alice already exists, skipping')

        # Demо нотатки
        notebook, _ = Notebook.objects.get_or_create(
            user=alice, title='Мої нотатки', defaults={'is_default': True}
        )
        Note.objects.get_or_create(
            user=alice, title='Перша нотатка',
            defaults={
                'content': 'Привіт! Це демо-нотатка.',
                'notebook': notebook,
                'priority': Note.PRIORITY_MEDIUM,
            }
        )

        self.stdout.write(self.style.SUCCESS('Seeding complete!'))
```

**Ключові частини:**
- `BaseCommand` — базовий клас, надає `stdout`, `style`, `add_arguments`, `handle`
- `add_arguments` — аргументи командного рядка (`--reset`)
- `handle` — вся логіка команди виконується тут
- `self.style.SUCCESS(...)` — зелений текст у виводі
- `get_or_create` — ідемпотентна операція (безпечна для повторного запуску)

---

## Запуск у Docker

```bash
# Одноразовий контейнер
docker compose run --rm web python manage.py seed_demo_data

# З аргументом
docker compose run --rm web python manage.py seed_demo_data --reset

# В уже запущеному контейнері (exec, не run)
docker compose exec web python manage.py showmigrations
docker compose exec web python manage.py shell

# Перевірка конфігурації
docker compose exec web python manage.py check
```

---

## Повний lifecycle — від нуля до production

```
Крок 1: Ініціалізація
  django-admin startproject notes_project
  python manage.py startapp notes_app
  # Додати 'notes_app' до INSTALLED_APPS

Крок 2: Моделі → БД
  # Написати models.py
  python manage.py makemigrations
  python manage.py migrate

Крок 3: Перший адмін
  python manage.py createsuperuser

Крок 4: Розробка
  python manage.py runserver
  # Змінюємо models.py → makemigrations → migrate
  # Пишемо views.py, urls.py, templates/

Крок 5: Перед деплоєм
  python manage.py check --deploy
  python manage.py collectstatic
  python manage.py test
```

---

## Типові помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `No module named 'notes_app'` | Не в `INSTALLED_APPS` | Додай `'notes_app'` до `INSTALLED_APPS` |
| `Table doesn't exist` | `migrate` не запущено | `python manage.py migrate` |
| `InconsistentMigrationHistory` | Видалено файл міграції після `migrate` | Відновити файл або `migrate --fake` |
| `Address already in use` | Порт 8000/8001 зайнятий | `docker compose down` або змінити порт |
| `Non-nullable field` | Додав поле без `default` | Додай `default=` або `null=True` |
| `AppRegistryNotReady` | Імпортуєш models до ініціалізації Django | Перевір порядок імпортів у `asgi.py` |

---

## У книзі

- [Частина X. Linux і DevOps](../10_linux_and_devops/README.md) — Docker, entrypoint.sh
- [Крок 9. Deployment → Seed data](../tutorials/09_deployment/seed_data.md) — seeding у production

---

## Офіційна документація

- [Django: Writing custom management commands](https://docs.djangoproject.com/en/5.2/howto/custom-management-commands/) — повний API
- [Django: django-admin and manage.py](https://docs.djangoproject.com/en/5.2/ref/django-admin/) — всі вбудовані команди
