# Teaching Guide

Цей документ допомагає викладачу перетворити репозиторій на курс.

## Короткий маршрут

1. Local setup і структура репозиторію.
2. Django URL -> view -> template.
3. Models, migrations і ORM.
4. Forms, validation, PRG.
5. Auth і object-level permissions.
6. Tests.
7. Фінальний проєкт.

## Стандартний маршрут

Додайте до короткого маршруту:

- services/selectors;
- query optimization;
- template inheritance і Bootstrap;
- Selenium;
- CI;
- WebSocket chat.

## Повний маршрут

Додайте:

- web foundations;
- Linux basics;
- Docker mental model;
- deployment checklist;
- production security.

## Що показувати live coding

- Додати простий route і view.
- Додати model field і migration.
- Додати form validation.
- Винести query у selector.
- Написати service test.
- Показати IDOR bug і test, який його ловить.
- Показати WebSocket connection у browser DevTools.

## Домашні роботи

- Мінімальна: змінити template і додати test.
- Основна: додати feature через model, form, service, view, template.
- Advanced: відновити async HTTP demo повним набором files або виправити Docker setup.

## Складні теми для початківців

- QuerySet laziness.
- Різниця authentication і authorization.
- ManyToMany і through table.
- Transactions.
- ASGI і WebSocket lifecycle.
- Production settings.

## Критерії оцінювання фінального проєкту

- `python manage.py check` проходить.
- Tests покривають model/service/form/view.
- Object permissions перевірені.
- Немає секретів у Git.
- README і docs відповідають фактичному коду.
- Deployment notes чесно відділяють готове від планів.

## Що можна пропустити у скороченому курсі

- Kubernetes overview.
- Deep indexing.
- Advanced transactions.
- SIEM.
- Serializers і Celery, бо вони не реалізовані у фінальному проєкті.
