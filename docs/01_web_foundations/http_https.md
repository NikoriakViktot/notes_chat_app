# HTTP and HTTPS

> HTTP - це протокол request/response, яким browser спілкується з Django server.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Ментальна модель

Browser надсилає method, path, headers і body. Server повертає status code, headers і body.

## Django mapping

- `GET /notes/` -> показати список.
- `POST /notes/new/` -> validate form і створити note.
- Redirect після POST захищає від повторного submit при refresh.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/urls.py` | HTTP paths |
| `notes_app/views.py` | GET/POST branching |

## Практичне завдання

Знайдіть один view, який обробляє і GET, і POST.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [browser-server lifecycle](browser_server_lifecycle.md).
