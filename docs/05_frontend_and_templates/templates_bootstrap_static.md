# Templates, Bootstrap and Static Files

> Template inheritance прибирає дублювання HTML і створює єдину структуру UI.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Поточна ієрархія

```text
templates/base.html
└── templates/layouts/dashboard.html
    └── notes_app/templates/notes_app/*.html
```

`base.html` підключає Bootstrap і app CSS. `dashboard.html` додає sidebar, topbar, messages і content block.

Static files:

- `notes_app/static/notes_app/css/app.css`;
- `notes_app/static/notes_app/js/group_chat.js`;
- `static/css/project.css`.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `templates/base.html` | HTML skeleton |
| `templates/layouts/dashboard.html` | sidebar and topbar |
| `notes_app/context_processors.py` | global sidebar context |

## Практичне завдання

Знайдіть, як `sidebar_notebooks` потрапляє у template.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [Application architecture](../06_application_architecture/README.md).
