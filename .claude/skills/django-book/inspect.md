/django-book inspect

Продовж Phase 1 — Inspection. Поточний аудит є попереднім і не вважається завершеним, тому що для значної частини документації було перевірено лише структуру, заголовки або перші рядки.

Перед початком прочитай:

```text
CLAUDE.md
.claude/skills/django-book/SKILL.md
.claude/skills/django-book/references/MASTER_SPEC.md
docs/_internal/SOURCE_INVENTORY.md
docs/_internal/BOOK_DOCUMENTATION_AUDIT.md
docs/_internal/PROJECT_CODE_DOCUMENTATION_MAP.md
docs/_internal/PROJECT_TUTORIAL_ACCURACY_REPORT.md
docs/_internal/BOOK_PROGRESS.md
```

## Головна мета

Завершити повну змістову інспекцію документації та коду перед переходом до Phase 2 — Architecture.

Не створюй поки:

```text
BOOK_ARCHITECTURE_PLAN.md
ZERO_TO_HERO_PLAN.md
PROJECT_DEEP_DIVE_PLAN.md
```

Не перебудовуй MkDocs navigation.

Не переміщуй, не об’єднуй і не архівуй студентські документи.

## 1. Усунь суперечність у статусі аудиту

У `BOOK_PROGRESS.md` зазначено, що:

* приблизно 30 Markdown-файлів прочитано повністю;
* для приблизно 149 файлів перевірено лише структуру або заголовки.

Тому не використовуй формулювання:

```text
всі документи повністю перевірені
повний аудит 179 файлів завершено
знайдено всі неточності
```

доки зміст відповідних файлів не прочитано повністю.

Для кожного документа введи один із точних статусів:

```text
fully inspected
partially inspected
structure only
not inspected
```

Онови ці статуси у:

```text
docs/_internal/SOURCE_INVENTORY.md
docs/_internal/BOOK_DOCUMENTATION_AUDIT.md
docs/_internal/BOOK_PROGRESS.md
```

## 2. Повністю прочитай Knowledge Book

Повністю прочитай усі Markdown-файли у:

```text
docs/00_getting_started/
docs/01_web_foundations/
docs/02_django_core/
docs/03_database_and_orm/
docs/04_forms_and_validation/
docs/05_frontend_and_templates/
docs/06_application_architecture/
docs/07_auth_and_security/
docs/08_testing_and_quality/
docs/09_async_and_realtime/
docs/10_linux_and_devops/
docs/11_deployment/
```

Не аналізуй лише назви, розмір, заголовки або перші 60–80 рядків.

Через великий обсяг працюй тематичними пакетами. Після кожного пакета відразу оновлюй audit-файли, щоб висновки не залежали від пам’яті поточного контексту.

Для кожного файла перевір:

* фактичні теми;
* рівень;
* передумови;
* унікальні пояснення;
* кодові приклади;
* Mermaid-схеми;
* таблиці;
* exercises;
* debugging;
* security;
* production notes;
* дублювання з іншими файлами;
* суперечності з поточним кодом;
* версійну актуальність;
* канонічну роль у майбутній книзі.

## 3. Повністю прочитай tutorial і README-модулі

Повністю прочитай:

```text
docs/tutorials/01_first_django_page.md
docs/tutorials/02_first_model.md
docs/tutorials/03_crud.md
docs/tutorials/04_templates_bootstrap.md
docs/tutorials/05_authentication.md
docs/tutorials/06_testing.md
docs/tutorials/07_async.md
docs/tutorials/08_deployment.md
docs/tutorials/README_1.md
docs/tutorials/README_2.md
docs/tutorials/README_3.md
docs/tutorials/README_4.md
docs/tutorials/README_5.md
docs/tutorials/README_6.md
docs/tutorials/README_7.md
docs/tutorials/README_8.md
docs/tutorials/README_9.md
```

Особливо перевір, чи помилки з `tutorials/05_authentication.md` повторюються в `README_6.md`.

Перевір також відповідність:

```text
tutorials/06 ↔ README_7 ↔ реальні tests
tutorials/07 ↔ README_8 ↔ consumers.py/asgi.py/routing.py
tutorials/08 ↔ README_9 ↔ Dockerfile/docker-compose/CI/env
```

## 4. Заверши інспекцію коду

Повністю прочитай усі раніше пропущені або частково прочитані файли, зокрема, якщо вони існують:

```text
notes_app/tests/test_services.py
notes_app/tests/test_forms.py
notes_app/tests/test_selenium.py
notes_app/context_processors.py
notes_app/apps.py
notes_app/signals.py
notes_app/middleware.py
notes_project/middleware.py
entrypoint.sh
Makefile
manage.py
notes_app/migrations/
notes_app/templates/
notes_app/static/
```

Не припускай, що файл існує. Якщо його немає, зафіксуй:

```text
not present
```

а не `not inspected`.

Для templates і JavaScript створи карту:

| Feature | View | Template | JavaScript | URL | Test | Documentation |
| ------- | ---- | -------- | ---------- | --- | ---- | ------------- |

## 5. Перевір дублікати за змістом

Не називай файли дублікатами лише через схожі назви або коротший розмір.

Для кожної потенційної пари визнач:

```text
exact duplicate
near duplicate
summary of canonical chapter
different pedagogical purpose
overlapping but contains unique material
```

Особливо перевір:

```text
django_migrations_full.md ↔ migrations.md
services_selectors_full.md ↔ django_services_selectors.md
django_templates_full.md ↔ advanced_templates_full.md
ci.md ↔ ci_cd_full.md
channels_websocket.md ↔ tutorials/07_async.md
docker_and_runtime.md ↔ deploy_14_docker_basics.md
```

Для кожної пари вкажи:

* спільний зміст;
* унікальний зміст першого файла;
* унікальний зміст другого файла;
* рекомендований канонічний файл;
* чи потрібен redirect/summary;
* чи можна безпечно merge;
* що не можна втратити.

## 6. Виправ підтверджені помилки

Після повторної перевірки фактичного коду виправ у:

```text
docs/tutorials/05_authentication.md
```

### Помилка 1

Замінити неправильний виклик:

```python
services.update_note(note, form.cleaned_data)
```

на фактичний виклик із keyword arguments відповідно до поточного `services.py` та `views.py`.

Не використовуй абстрактне `**form.cleaned_data`, якщо ключі форми не відповідають підпису сервісу або `tag_ids` потребує окремого перетворення.

### Помилка 2

Виправити пояснення `note_edit`:

* read/access lookup враховує власні та групові нотатки;
* write permission перевіряється окремо;
* редагувати може лише власник;
* не спрощувати це до одного `get_object_or_404(..., user=request.user)`, якщо це не відповідає коду.

Виправити всі пов’язані місця, а не лише один code block.

### Помилка 3

Замінити:

```python
store = models.CharField(...)
```

на:

```python
store_name = models.CharField(...)
```

відповідно до поточної моделі.

### Помилка 4

Замінити raw `request.POST.get("name")` у `group_create` на фактичну реалізацію з:

```python
GroupCreateForm
```

Пояснити, чому серверну валідацію потрібно виконувати через форму.

### Low issue

Оновити застарілий коментар у:

```text
notes_app/tests/test_views.py
```

лише якщо він справді містить старий шлях і зміна не впливає на поведінку тестів.

## 7. Не змішуй виправлення і перебудову книги

На цьому етапі дозволено змінювати лише:

```text
docs/_internal/*
docs/tutorials/05_authentication.md
notes_app/tests/test_views.py
```

Не змінюй інші студентські матеріали, навіть якщо знайдеш проблему. Запиши її в accuracy report для наступної фази.

## 8. Онови звіти

Онови:

```text
docs/_internal/SOURCE_INVENTORY.md
docs/_internal/BOOK_DOCUMENTATION_AUDIT.md
docs/_internal/PROJECT_CODE_DOCUMENTATION_MAP.md
docs/_internal/PROJECT_TUTORIAL_ACCURACY_REPORT.md
docs/_internal/BOOK_PROGRESS.md
```

У `BOOK_PROGRESS.md` окремо покажи:

```text
Fully inspected Markdown files:
Partially inspected:
Structure only:
Not inspected:
Fully inspected code files:
Code files not present:
Confirmed tutorial issues:
Fixed tutorial issues:
Open tutorial issues:
Duplicate groups verified by content:
```

Не позначай Phase 1 завершеною, якщо залишилися `partially inspected`, `structure only` або `not inspected` для матеріалів, які повинні увійти до книги.

## 9. Validation

Після виправлень виконай доступні перевірки.

Для документації:

```bash
mkdocs build --strict
```

Якщо локальний `mkdocs` недоступний, перевір, чи існує підтверджений Docker-спосіб запуску. Не вигадуй новий Docker service.

Для Django:

```bash
docker compose run --rm web python manage.py check
```

Запусти релевантні тести для зміненого або перевіреного коду.

Якщо середовище недоступне, вкажи точний статус:

```text
blocked
not run
failed
passed
```

Не підмінюй `blocked` статусом `passed`.

## 10. Завершальний звіт

Покажи:

```text
Markdown files fully inspected:
Markdown files partially inspected:
Markdown files structure-only:
Markdown files not inspected:

Code files fully inspected:
Code files not present:

Tutorial issues before:
Tutorial issues fixed:
Tutorial issues still open:

Critical:
High:
Medium:
Low:
Editorial:

Duplicate groups checked by full content:
Canonical chapter candidates:
Stub files confirmed:

mkdocs build --strict:
python manage.py check:
Relevant tests:
```

Також покажи:

```bash
git status --short
git diff --stat
```

Не виконуй:

```bash
git add
git commit
git push
```
/