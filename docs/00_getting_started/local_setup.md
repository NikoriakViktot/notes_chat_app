# Local Setup

> Локальний запуск потрібний, щоб перевіряти кожну концепцію руками.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Linux/macOS/WSL

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

## Windows PowerShell

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

## ASGI для чату

```bash
uvicorn notes_project.asgi:application --reload --port 8001
```

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `manage.py` | Django command entrypoint |
| `notes_project/asgi.py` | ASGI entrypoint |

## Практичне завдання

Після встановлення dependencies запустіть `python manage.py check`.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Web foundations](../01_web_foundations/README.md).
