# Repository Structure

> Структура репозиторію показує, де шукати код, templates, tests і документацію.

## Що студент вивчить

- базову ментальну модель теми;
- як тема працює у Django;
- де її побачити у фінальному проєкті;
- як перевірити, що розуміння не лише теоретичне.

## Передумови

- Вміти відкрити репозиторій.
- Розуміти, що всі шляхи в документації відносні до кореня `notes_chat_app`.

## Головні папки

```text
notes_project/   Django project package
notes_app/       Django app з доменною логікою
templates/       project-level templates
static/          project-level static files
docs/            активна документація
archive/         історичні матеріали
```

`staticfiles/` є результатом `collectstatic` і не є навчальним джерелом для редагування.

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/settings.py` | project config |
| `notes_app/models.py` | domain models |
| `notes_app/tests/` | tests |

## Практичне завдання

Знайдіть кожен шлях з таблиці у своєму editor.

## Контрольні питання

- Що є входом у цей процес?
- Який результат очікується?
- Де найчастіше виникає помилка?
- Яка команда або test допомагає перевірити зміну?

## Далі

Далі: [local setup](local_setup.md).
