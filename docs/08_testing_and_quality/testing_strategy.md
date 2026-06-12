# Testing Strategy

> Testing pyramid допомагає вибрати правильний рівень перевірки.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Рівні

- Unit: models, services, forms.
- Integration: views через Django TestClient.
- Consumer: Channels WebsocketCommunicator.
- E2E: Selenium browser flows.

## Команди

```bash
python manage.py test notes_app.tests.test_models -v 2
python manage.py test notes_app.tests.test_services -v 2
python manage.py test notes_app.tests.test_views -v 2
python manage.py test notes_app.tests.test_consumers -v 2
```

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/tests/test_models.py` | model tests |
| `notes_app/tests/test_consumers.py` | WebSocket consumer tests |
| `notes_app/tests/test_selenium.py` | browser tests |

## Практичне завдання

Додайте один regression test перед зміною behavior.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [CI](ci.md).
