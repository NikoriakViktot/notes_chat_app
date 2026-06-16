# PostgreSQL

> Перехід з SQLite на PostgreSQL — важливий крок перед production.
> SQLite ідеальний для розробки, але PostgreSQL надає: конкурентний доступ, розширені типи полів, ACID транзакції з рівнями ізоляції, та продуктивність при великих обсягах даних.

---

## 10.1 Запуск PostgreSQL через Docker

```bash
# Запуск через docker-compose:
docker-compose up -d

# Або прямо через docker run:
docker run -d \
  --name notes_postgres \
  -e POSTGRES_DB=notes_db \
  -e POSTGRES_USER=notes_user \
  -e POSTGRES_PASSWORD=notes_pass \
  -p 5432:5432 \
  postgres:16-alpine
```

```yaml
# docker-compose.yml
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: notes_db
      POSTGRES_USER: notes_user
      POSTGRES_PASSWORD: notes_pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
volumes:
  postgres_data:
```

---

## 10.2 Налаштування Django

```bash
pip install psycopg2-binary python-decouple
```

```python
# settings.py — після переходу на PostgreSQL
from decouple import config

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='notes_db'),
        'USER': config('DB_USER', default='notes_user'),
        'PASSWORD': config('DB_PASSWORD', default='notes_pass'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
        'CONN_MAX_AGE': 60,  # тримати з'єднання між запитами
    }
}
```

```
# .env (ніколи не комітити!)
DB_NAME=notes_db
DB_USER=notes_user
DB_PASSWORD=notes_pass
DB_HOST=localhost
DB_PORT=5432
```

Після зміни settings.py запусти міграції на нову БД:

```bash
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

---

## 10.3 Перенесення даних з SQLite

```bash
# Крок 1: Дамп з SQLite (поки ще підключена)
python manage.py dumpdata \
  --natural-foreign --natural-primary \
  --exclude=contenttypes --exclude=auth.permission \
  --indent=2 > data_backup.json

# Крок 2: Перемикаємо settings.py на PostgreSQL

# Крок 3: Міграції в нову БД
python manage.py migrate

# Крок 4: Завантаження даних
python manage.py loaddata data_backup.json

# Крок 5: Перевірка
python manage.py shell -c "from hello_app.models import Note; print(f'Notes: {Note.objects.count()}')"
```

---

## 10.4 PostgreSQL-специфічні поля

Після переходу на PostgreSQL стають доступні унікальні типи полів:

```python
# Тільки PostgreSQL — ArrayField, JSONField з повними можливостями
from django.contrib.postgres.fields import ArrayField

class Note(models.Model):
    # Масив тегів у стовпці (alternative до M:N для простих сценаріїв)
    quick_labels = ArrayField(
        models.CharField(max_length=30),
        blank=True, default=list
    )
    # metadata як JSON (не потребує окремої таблиці)
    metadata = models.JSONField(default=dict, blank=True)

# Фільтрація по JSON/Array:
Note.objects.filter(quick_labels__contains=['python'])
Note.objects.filter(metadata__word_count__gte=100)
Note.objects.filter(metadata__language='uk')
```

### Порівняння SQLite vs PostgreSQL

| Властивість | SQLite | PostgreSQL |
|-------------|--------|------------|
| Конкурентні записи | Блокує всю БД | Row-level locking |
| `select_for_update()` | Не підтримується повністю | Повна підтримка |
| ArrayField | Недоступний | Доступний |
| JSONField | Базовий (рядок) | Повний JSONB |
| Full-text search | Обмежений | `SearchVector`, `SearchQuery` |
| Тригери | Обмежені | Повна підтримка |
| Обсяг даних | До ~1 ГБ | Без практичних обмежень |
| Налаштування | Нічого | Docker або cloud service |

---

## Структура файлів проекту

```
notes_project/
├── notes_project/              ← Django project config
│   ├── settings.py             ← DATABASES, INSTALLED_APPS, AUTH
│   ├── urls.py                 ← root URL router
│   └── wsgi.py / asgi.py       ← production entry point
│
├── hello_app/                  ← Django додаток
│   ├── models.py               ← 9 моделей (UserProfile, Tag, Notebook, Note,
│   │                             Reminder, TodoList, TodoItem, ShoppingList, ShopItem)
│   ├── selectors.py            ← ВСІ SELECT запити тут (читання)
│   ├── services.py             ← ВСЯ бізнес-логіка тут (запис/зміна)
│   ├── views.py                ← ТІЛЬКИ HTTP: парсити запит → selector/service → render
│   ├── forms.py                ← Django Forms для валідації вводу
│   ├── admin.py                ← реєстрація в адмін-панелі (з select_related)
│   ├── urls.py                 ← app URL маршрути
│   └── migrations/
│       ├── 0001_initial.py           ← стартова Note модель
│       └── 0002_extended_models.py   ← всі розширені моделі
│
├── hello_app/templates/hello_app/
│   ├── note_list.html          ← список нотаток + sidebar фільтри
│   ├── note_detail.html        ← деталь нотатки + нагадування
│   ├── note_form.html          ← форма створення/редагування
│   └── note_confirm_delete.html ← сторінка підтвердження видалення
│
├── templates/
│   └── base.html               ← базовий шаблон (Bootstrap navbar, messages)
│
├── manage.py
├── requirements.txt            ← Django, psycopg2-binary, python-decouple
├── docker-compose.yml          ← PostgreSQL у Docker
└── .env                        ← секрети (ніколи не комітити!)
```

---

## Навігація

- Попередня: [QuerySet глибоко](queryset_deep.md)
- Наступна: [Class-Based Views](cbv.md)
