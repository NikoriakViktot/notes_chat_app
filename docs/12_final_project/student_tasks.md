# Student Tasks

Практичні завдання до Notes Chat App — трьох рівнів складності.

---

## Рівень 1 — Мінімальне

Додайте нове поле до моделі `Note`, створіть і застосуйте migration, покажіть поле у detail template.

**Кроки:**

1. Додайте поле у `notes_app/models.py` (наприклад, `color = models.CharField(max_length=7, default='#808080', blank=True)`).
2. Створіть migration: `docker compose run --rm web python manage.py makemigrations`.
3. Застосуйте: `docker compose run --rm web python manage.py migrate`.
4. Покажіть поле у `templates/notes_app/note_detail.html`.

**Критерії:**

- migration файл існує у `notes_app/migrations/`.
- `manage.py check` проходить без помилок.
- template відображає поле без помилок.
- Існуючі тести проходять: `docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2`.

---

## Рівень 2 — Основне

Додайте archive/unarchive flow через service, view, URL і тест.

**Кроки:**

1. `Note` вже має поле `is_archived` — використайте його.
2. Додайте функцію у `notes_app/services.py` (аналог `toggle_pin`).
3. Додайте selector у `notes_app/selectors.py` для отримання архівованих нотаток.
4. Додайте view у `notes_app/views.py`.
5. Додайте URL у `notes_app/urls.py`.
6. Додайте тест у `notes_app/tests/test_services.py` або `test_views.py`.

**Критерії:**

- Бізнес-логіка у `services.py` (не у view).
- Read query у `selectors.py`.
- Access rules протестовані (неможливість архівувати чужу нотатку).
- Всі існуючі тести проходять.

---

## Рівень 3 — Advanced

Відновіть async HTTP demo або виправте Docker production blockers.

### Варіант A: Async HTTP demo

Поточний стан: `async_views.py`, `async_selectors.py`, `async_services.py` відсутні у working tree.

Реалізуйте async view для списку нотаток:
- Використайте `async def note_list_async(request)`.
- ORM wrap через `database_sync_to_async`.
- Зареєструйте URL.
- Напишіть тест.

### Варіант B: Production Docker

1. Перенесіть `SECRET_KEY` у environment variable.
2. Додайте `DEBUG=False` режим з коректним `ALLOWED_HOSTS`.
3. Видаліть `DebugExceptionMiddleware` або обмежте умовою `if settings.DEBUG`.
4. Замініть `uvicorn --reload` на production команду.
5. Задокументуйте всі зміни.

**Критерії (обидва варіанти):**

- Команда задокументована.
- Тести / checks проходять, або blocker чесно описаний.
- Існуючі features не ламаються.
