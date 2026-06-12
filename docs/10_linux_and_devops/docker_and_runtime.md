# Docker and Runtime

> Docker описує runtime, але runtime має відповідати реальній структурі репозиторію.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Поточний статус

`docker-compose.yml` описує PostgreSQL, Redis, web і Selenium. Але build config зараз згадує директорію `notes`, якої немає. Перед використанням Docker треба виправити context і `COPY`.

## Environment

`DATABASE_URL` перемикає Django на PostgreSQL. `REDIS_URL` перемикає Channels на Redis.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `Dockerfile` | image build |
| `docker-compose.yml` | service graph |
| `entrypoint.sh` | runtime command |

## Практичне завдання

Зробіть plan виправлення Docker без зміни application code.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Deployment](../11_deployment/README.md).
