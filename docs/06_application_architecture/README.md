# 06. Application Architecture

> Великі Django-проєкти потребують меж відповідальності: views не повинні містити всю логіку.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Services and selectors](services_selectors.md) | thin views, read/write layers |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_app/views.py` | HTTP orchestration |
| `notes_app/selectors.py` | read queries |
| `notes_app/services.py` | write operations |

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

Далі: [Auth and security](../07_auth_and_security/README.md).

<!-- restored-full-chapters:start -->

## Повні відновлені глави

Цей блок веде до повних навчальних матеріалів, перенесених з `archive/` без скорочення змісту.

- [Django Ninja + Rendering Architecture](django_ninja_templates_full.md)
- [Django Selectors — Шар читання даних](django_selectors_full.md)
- [Django Serializers — Transport Layer](django_serializers_full.md)
- [Django Services — Шар бізнес-логіки](django_services_full.md)
- [Django Tasks — Celery та Асинхронні Задачі](django_tasks_full.md)
- [Django Services, Selectors & Serializers — Шар бізнес-логіки](services_selectors_full.md)

<!-- restored-full-chapters:end -->
