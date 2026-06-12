# 02. Django Core

> Цей розділ формує ментальну модель Django: settings, URLs, views, middleware, WSGI і ASGI.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Request lifecycle](request_lifecycle.md) | як request проходить через Django |
| [URLs and views](urls_and_views.md) | routing і function-based views |
| [WSGI vs ASGI](wsgi_vs_asgi.md) | sync і async entrypoints |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/settings.py` | installed apps, middleware, DB |
| `notes_project/urls.py` | root URLs |
| `notes_app/views.py` | HTTP layer |

## Мінімальне завдання

Прочитайте головний документ розділу і знайдіть у коді всі згадані файли.

## Основне завдання

Поясніть своїми словами, як ця тема проявляється у поточному проєкті. Не змінюйте код, якщо завдання прямо цього не вимагає.

## Advanced challenge

Знайдіть одну потенційну точку покращення в цій темі і запишіть, які tests або checks мають підтвердити зміну.

## Контрольні питання

- Яка проблема вирішується цим шаром?
- Де межа відповідальності цього шару?
- Який файл є головною точкою входу?
- Яка типова помилка початківця?

## Далі

Далі: [Database and ORM](../03_database_and_orm/README.md).
