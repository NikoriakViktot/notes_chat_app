# Notes Chat App

Навчальний Django-репозиторій, який веде студента від web foundations до фінального Django-застосунку з нотатками, списками, груповим доступом і WebSocket-чатом.

## Про проєкт

`Notes Chat App` показує, як виростає Django-застосунок:

- від URL routing і function-based views;
- до models, migrations, ORM і оптимізації запитів;
- до forms, templates, Bootstrap і Crispy Forms;
- до services/selectors, authentication, permissions і tests;
- до ASGI, Django Channels і WebSocket-чату;
- до мислення про Docker, Redis, PostgreSQL і deployment.

UI проєкту використовує назву `CrispyNotes`. Django project package - `notes_project`, Django app - `notes_app`.

## Можливості

| Напрям | Реалізація |
| --- | --- |
| Notes | CRUD, пошук, notebooks, tags, priority, pinned |
| Todo lists | списки, items, toggle, direct sharing |
| Shopping lists | товари, кількість, estimated price, sharing |
| Groups | створення груп, учасники, group-owned notes/shopping lists |
| Chat | real-time group chat через Django Channels |
| Auth | registration, login/logout, password change/reset templates |
| Tests | models, services, forms, views, consumers, Selenium |

## Технології

- Python 3.12 у середовищі аудиту.
- Django `>=5.2,<6.0`.
- Bootstrap 5 і Bootstrap Icons.
- `django-crispy-forms` + `crispy-bootstrap5`.
- Django Channels, Daphne, Uvicorn, `channels-redis`.
- SQLite локально без `DATABASE_URL`.
- PostgreSQL і Redis через environment variables.
- Selenium, coverage, GitHub Actions.

## Швидкий запуск

```bash
git clone https://github.com/NikoriakViktot/notes_chat_app.git
cd notes_chat_app

python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
pip install -r requirements.txt

python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

## Основні URL

| URL | Призначення |
| --- | --- |
| `/` | стартова сторінка |
| `/register/` | реєстрація |
| `/accounts/login/` | login |
| `/notes/` | нотатки |
| `/todo/` | списки справ |
| `/shopping/` | списки покупок |
| `/groups/` | групи |
| `/groups/<pk>/chat/` | HTML-сторінка чату |
| `/ws/groups/<pk>/chat/` | WebSocket endpoint |
| `/admin/` | Django admin |

## Архітектура

```mermaid
flowchart TD
    Browser["Browser"] --> URLs["notes_project/urls.py"]
    URLs --> AppURLs["notes_app/urls.py"]
    AppURLs --> Views["notes_app/views.py"]
    Views --> Forms["notes_app/forms.py"]
    Views --> Selectors["notes_app/selectors.py"]
    Views --> Services["notes_app/services.py"]
    Selectors --> Models["notes_app/models.py"]
    Services --> Models
    Models --> DB["SQLite або PostgreSQL"]
    Browser --> JS["group_chat.js"]
    JS --> ASGI["notes_project/asgi.py"]
    ASGI --> Consumer["notes_app/consumers.py"]
    Consumer --> ChannelLayer["InMemory або Redis channel layer"]
```

## Документація

Документація побудована на [MkDocs + Material](https://squidfunk.github.io/mkdocs-material/).

**Онлайн:** https://nikoriakviktor.github.io/notes_chat_app/

### Локальний перегляд

```bash
source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

Відкрий у браузері: **http://localhost:8000**

`mkdocs serve` автоматично перезавантажує при зміні будь-якого `.md` файлу.

### Публікація на GitHub Pages

```bash
git add mkdocs.yml requirements-docs.txt docs/ .github/workflows/docs.yml
git commit -m "docs: update documentation"
git push
```

GitHub Actions автоматично збудує сайт і задеплоїть у гілку `gh-pages`.
Статус: https://github.com/NikoriakViktot/notes_chat_app/actions

> **Перший деплой:** зайди в **Settings → Pages**, вибери Source = `gh-pages` / `/ (root)`, натисни Save.

### Структура документації

| Розділ | Опис |
|--------|------|
| [Книга](docs/00_getting_started/README.md) | 12 модулів: Web → Django → DB → Forms → Frontend → Architecture → Auth → Testing → Async → Linux → Deploy |
| [Notes Chat App](docs/12_final_project/README.md) | Архітектура, моделі, тести, деплоймент фінального проєкту |
| [Практика](docs/tutorials/README.md) | Туторіали та labs |
| [Довідник](docs/reference/README.md) | Cheatsheets, глосарій, troubleshooting |
| [Викладачу](docs/TEACHING_GUIDE.md) | Teaching guide, learning path |

## Навчальний маршрут

1. [Getting started](docs/00_getting_started/README.md)
2. [Web foundations](docs/01_web_foundations/README.md)
3. [Django core](docs/02_django_core/README.md)
4. [Database and ORM](docs/03_database_and_orm/README.md)
5. [Forms and validation](docs/04_forms_and_validation/README.md)
6. [Frontend and templates](docs/05_frontend_and_templates/README.md)
7. [Application architecture](docs/06_application_architecture/README.md)
8. [Auth and security](docs/07_auth_and_security/README.md)
9. [Testing and quality](docs/08_testing_and_quality/README.md)
10. [Async and realtime](docs/09_async_and_realtime/README.md)
11. [Linux and DevOps](docs/10_linux_and_devops/README.md)
12. [Deployment](docs/11_deployment/README.md)
13. [Final project](docs/12_final_project/README.md)

## Тести

```bash
python manage.py check
python manage.py test
```

Async HTTP demo modules у поточному working tree відсутні і не описуються як активна feature. Реальний async-компонент проєкту - WebSocket chat через ASGI, Channels і `GroupChatConsumer`.

## Deployment status

Проєкт має заготовки `Dockerfile`, `docker-compose.yml`, `entrypoint.sh` і `.env.example`, але Docker path зараз неузгоджений: compose/build налаштування згадують директорію `notes`, якої немає в корені. Production deployment треба доробити і перевірити.

## Подальший розвиток

- Якщо потрібно повернути async HTTP demo, відновити `async_views.py`, `async_selectors.py`, `async_services.py` разом із routes.
- Виправити Docker build context.
- Винести `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS` у environment.
- Увімкнути Redis channel layer для production.
- Додати production-ready logging і monitoring.
