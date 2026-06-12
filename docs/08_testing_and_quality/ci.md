# Continuous Integration

> CI запускає checks автоматично після push або pull request.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Workflow

`.github/workflows/django-tests.yml` має jobs для unit/integration/consumer tests і Selenium E2E.

Поточні команди потребують встановлених dependencies. Якщо хтось повертає legacy async HTTP routes, треба також відновити відповідні `async_views.py`, `async_selectors.py` і `async_services.py`.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `.github/workflows/django-tests.yml` | GitHub Actions config |

## Практичне завдання

Поясніть, які tests мають запускатись до merge.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Async and realtime](../09_async_and_realtime/README.md).
