# Deployment Checklist

> Production checklist відділяє готове від бажаного.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Потрібно перед production

- `DEBUG=False`.
- Real `ALLOWED_HOSTS`.
- `SECRET_KEY` з environment.
- PostgreSQL з backup strategy.
- Redis для Channels.
- `collectstatic` і static serving.
- HTTPS і secure cookies.
- Application server без `--reload`.
- Reverse proxy.
- Logging і monitoring.

## Не стверджуйте production-ready

Поки Docker mismatch і hardcoded settings не виправлені, deployment docs мають бути checklist, а не гарантія готового server.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/settings.py` | production-sensitive settings |
| `.env.example` | env template |

## Практичне завдання

Складіть список environment variables, яких не вистачає settings.py.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Final project](../12_final_project/README.md).
