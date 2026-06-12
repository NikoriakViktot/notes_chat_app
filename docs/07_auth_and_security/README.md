# 07. Auth and Security

> Security починається з правильної різниці між login і правом доступу до object.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Auth, sessions and permissions](auth_sessions_permissions.md) | authentication, sessions, IDOR, groups |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/settings.py` | security/auth settings |
| `notes_app/views.py` | permission checks |
| `notes_app/consumers.py` | WebSocket membership check |

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

Далі: [Testing and quality](../08_testing_and_quality/README.md).

<!-- restored-full-chapters:start -->

## Повні відновлені глави

Цей блок веде до повних навчальних матеріалів, перенесених з `archive/` без скорочення змісту.

- [Автентифікація vs Авторизація — Основи](auth_basics_full.md)
- [Архітектура безпеки Django](django_security_architecture_full.md)
- [OWASP Top 10 — 10 Найнебезпечніших Вразливостей](owasp_top_10_full.md)
- [Дозволи та Групи — Permissions & Groups](permissions_full.md)
- [Основи Безпеки Вебзастосунків — Security Foundations](security_foundations_full.md)
- [Типові помилки безпеки — Security Misconceptions](security_misconceptions_full.md)
- [Сесії, Login/Logout та Власність даних](sessions_flow_full.md)
- [SIEM — Системи Управління Подіями Безпеки](siem_full.md)
- [Zero Trust Architecture — Архітектура Нульової Довіри](zero_trust_full.md)

<!-- restored-full-chapters:end -->
