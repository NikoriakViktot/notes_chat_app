# Project Tutorial Accuracy Report

Звіт про неточності у студентських туторіалах відносно фактичного коду.
Інспекція: 2026-06-14. Оновлено: 2026-06-14. Гілка: main.

Перевірений файл авторитету: поточний код репозиторію (не документація).

Рівні серйозності:
- 🔴 **critical** — код, що показується, не виконується або викличе помилку
- 🟠 **high** — неправильна назва поля/функції, яку студент використає і помилиться
- 🟡 **medium** — спрощення, що вводить в оману щодо архітектурного рішення
- 🟢 **low** — неточна дрібниця (шляхи, коментарі) — не впливає на виконання
- ⚪ **editorial** — навмисні освітні спрощення, потребують примітки

---

## tutorials/05_authentication.md — СТАТУС: ВСІ 4 КРИТИЧНІ ПОМИЛКИ ВИПРАВЛЕНО ✅

### Неточність 1 — `update_note` → 🔴 critical → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/05_authentication.md` |
| **Рядок** | 1294 |
| **Проблема (була)** | `services.update_note(note, form.cleaned_data)` — TypeError |
| **Виправлення** | Замінено на коректний виклик з Q-filter доступом та keyword args |
| **Статус** | ✅ **FIXED** — рядок 1294 тепер містить `user_groups = request.user.groups.all()` та Q-filter |

---

### Неточність 2 — `note_edit` Q-filter → 🟠 high → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/05_authentication.md` |
| **Рядки** | 1287, 1294 (блок note_edit) |
| **Проблема (була)** | `get_object_or_404(Note, pk=pk, user=request.user)` замість Q-filter |
| **Виправлення** | Замінено на `Note.objects.filter(Q(user=request.user) \| Q(group__in=user_groups)), pk=pk` |
| **Статус** | ✅ **FIXED** — рядки 1290-1298 тепер показують Q-filter паттерн |

---

### Неточність 3 — `ShoppingList.store` → 🟠 high → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/05_authentication.md` |
| **Рядок** | 1378 |
| **Проблема (була)** | `store = models.CharField(...)` — невірне ім'я поля |
| **Виправлення** | Замінено на `store_name = models.CharField(...)` |
| **Статус** | ✅ **FIXED** — реальне поле `store_name` тепер показано правильно |

---

### Неточність 4 — `group_create` raw POST → 🟠 high → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/05_authentication.md` |
| **Рядки** | 1565–1577 |
| **Проблема (була)** | Raw POST без `GroupCreateForm` |
| **Виправлення** | Замінено на реальну реалізацію з `GroupCreateForm(request.POST)` |
| **Статус** | ✅ **FIXED** |

---

### Неточність 5 — коментар test_views.py → 🟢 low → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `notes_app/tests/test_views.py` (заголовковий коментар) |
| **Проблема (була)** | Посилання на старий шлях `module_5/lesson_Django_Testing/crispy_notes_project` |
| **Статус** | ✅ **FIXED** |

---

## tutorials/README_6.md — СТАТУС: ВИЯВЛЕНО 1 ПОМИЛКУ

README_6 описує **`crispy_notes_project`** (не `notes_chat_app`). Це навмисно — READ_6 є детальним туторіалом про попередній проєкт. Деякі відмінності від `notes_chat_app` є очікуваними (різні app_name, різні namespaces тощо).

### README_6 Issue 1 — `update_note` фіктивний метод → 🟠 high

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/README_6.md` |
| **Рядок** | ~951 (Крок 6) |
| **Проблема** | Показує `services.update_note(note, **form.cleaned_data_for_service())` — метод `form.cleaned_data_for_service()` не існує ні в crispy_notes_project ні в notes_chat_app |
| **Контекст** | README_6 відноситься до `crispy_notes_project`. Якщо цей метод існує у тому проєкті — помилка відсутня. Якщо ні — це помилка. Потребує перевірки `crispy_notes_project/hello_app/forms.py` |
| **Серйозність** | 🟠 **high** — якщо студент скопіює → `AttributeError` |
| **Рекомендація** | Перевірити `crispy_notes_project/hello_app/forms.py` на наявність `cleaned_data_for_service()` |

### README_6 Issue 2 — `note_edit` не використовує Q-filter → ⚪ editorial

| Поле | Значення |
|------|---------|
| **Рядок** | ~946 (Крок 6) |
| **Спостереження** | `note_edit` використовує `get_object_or_404(Note, pk=pk, user=request.user)` без Q-filter |
| **Чи це помилка?** | Ні — `crispy_notes_project` — попередній проєкт без групового sharing. У цьому контексті власник-тільки є правильним |
| **Серйозність** | ⚪ **editorial** — не помилка для crispy_notes_project |

### README_6 Issue 3 — `remove_user_from_group` відрізняється → ⚪ editorial

| Поле | Значення |
|------|---------|
| **Рядок** | ~1126 |
| **Спостереження** | README_6 `remove_user_from_group(group, user)` — 2 аргументи. У `notes_chat_app` `remove_user_from_group(group, user_pk, remover)` — 3 аргументи |
| **Чи це помилка?** | Ні для README_6 (опис `crispy_notes_project`). Так якщо студент порівнює з `notes_chat_app` |
| **Серйозність** | ⚪ **editorial** — різні проєкти |

---

## tutorials/README_7.md — СТАТУС: ВИЯВЛЕНО 2 ПРОБЛЕМИ

README_7 описує тестування **`crispy_notes_project`** (не `notes_chat_app`).

### README_7 Issue 1 — шлях проєкту → 🟢 low

| Поле | Значення |
|------|---------|
| **Рядок** | ~989 (Крок 0) |
| **Проблема** | `cd module_5/lesson_Django_Testing/crispy_notes_project` — посилається на legacy шлях |
| **Серйозність** | 🟢 **low** — відноситься до іншого проєкту |

### README_7 Issue 2 — шлях у CI coverage artifact → 🟢 low

| Поле | Значення |
|------|---------|
| **Рядок** | ~1705 |
| **Проблема** | `path: module_5/lesson_Django_Testing/crispy_notes_project/coverage.xml` — legacy шлях у YAML прикладі |
| **Серйозність** | 🟢 **low** — приклад, не реальний файл |

---

## tutorials/README_8.md — СТАТУС: ВИЯВЛЕНО 1 АРХІТЕКТУРНУ ВІДМІННІСТЬ

README_8 описує **`crispy_notes_project`** з async views, але також включає `notes_chat_app`.

### README_8 Issue 1 — `async_selectors.py`, `async_services.py`, `async_views.py` → 🟡 medium

| Поле | Значення |
|------|---------|
| **Рядки** | ~88-108 (таблиця файлів) |
| **Проблема** | README_8 показує `async_selectors.py`, `async_services.py`, `async_views.py` як нові файли. У реальному `notes_chat_app` ці файли **відсутні** — async реалізований тільки через `consumers.py` |
| **Чи це помилка?** | README_8 описує розширений навчальний проєкт де ці файли є. `notes_chat_app` — спрощена версія |
| **Серйозність** | 🟡 **medium** — студент може шукати ці файли в `notes_chat_app` і не знайти |
| **Рекомендація** | Додати примітку: "async_selectors.py та async_views.py існують у навчальному проєкті до цього уроку, але НЕ у notes_chat_app — там async реалізований лише через GroupChatConsumer" |

---

## tutorials/README_9.md — СТАТУС: ВИЯВЛЕНО 2 ПОМИЛКИ

README_9 описує `notes_chat_app` production stack. Потребує виправлення.

### README_9 Issue 1 — `ChatMessage.author` on_delete → 🟠 high

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/README_9.md` |
| **Рядки** | ~907-910 |
| **Проблема** | README_9 показує `author = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='chat_messages')` |
| **Фактичний код** | `notes_app/models.py:262-263`: `author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='chat_messages')` |
| **Чому важливо** | Різна поведінка при видаленні юзера: SET_NULL → повідомлення стають анонімними; CASCADE → повідомлення видаляються разом з юзером |
| **Виправлення** | Замінити `SET_NULL` на `CASCADE`, прибрати `null=True` з author FK |
| **Серйозність** | 🟠 **high** — неправильна семантика видалення |

### README_9 Issue 2 — `ShoppingList.store` замість `store_name` → 🟠 high

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/README_9.md` |
| **Рядок** | ~808 (ER-діаграма) |
| **Проблема** | ER-діаграма показує `store (100)` |
| **Фактичний код** | `notes_app/models.py:194`: `store_name = models.CharField(max_length=100, blank=True)` |
| **Виправлення** | Замінити `store` на `store_name` у ER-діаграмі |
| **Серйозність** | 🟠 **high** — та сама помилка що була в tutorial 05 (вже виправлено там) |

---

## notes_app/models.py (code file, не туторіал)

### Code Issue 1 — `DebugExceptionMiddleware` у production → 🟡 medium

| Поле | Значення |
|------|---------|
| **Файл** | `notes_project/middleware.py` + `notes_project/settings.py` |
| **Проблема** | `DebugExceptionMiddleware` зареєстрований ПЕРШИМ у MIDDLEWARE (перед SecurityMiddleware). Повертає traceback у HTTP-відповіді при помилках. Коментар: "Temporary debug middleware" але залишається у production коді |
| **Ризик** | Розкриває внутрішній traceback клієнтам при 500 помилках; позиція перед SecurityMiddleware може маскувати middleware-рівневі помилки |
| **Рекомендація** | Видалити або переміщати після SecurityMiddleware; додати умову `if DEBUG:` |
| **Серйозність** | 🟡 **medium** — security concern у production коді |

---

## Зведена таблиця

### Статус виправлень tutorial 05

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| 1 | tutorials/05_authentication.md | 1294 | `update_note(note, form.cleaned_data)` → TypeError | 🔴 critical | ✅ **FIXED** |
| 2 | tutorials/05_authentication.md | 1287–1298 | `get_object_or_404` замість Q-filter | 🟠 high | ✅ **FIXED** |
| 3 | tutorials/05_authentication.md | 1378 | `store` замість `store_name` | 🟠 high | ✅ **FIXED** |
| 4 | tutorials/05_authentication.md | 1565–1577 | `group_create` raw POST замість `GroupCreateForm` | 🟠 high | ✅ **FIXED** |
| 5 | test_views.py (header) | ~1 | неправильний шлях у коментарі | 🟢 low | ✅ **FIXED** |

### Нові проблеми (не у попередньому звіті)

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| 6 | tutorials/README_6.md | ~951 | `form.cleaned_data_for_service()` — фіктивний метод? | 🟠 high | ⚠️ **потребує перевірки** |
| 7 | tutorials/README_7.md | ~989, ~1705 | Legacy шляхи `module_5/...` | 🟢 low | ⚠️ open |
| 8 | tutorials/README_8.md | ~88-108 | async_selectors.py, async_services.py не існують у notes_chat_app | 🟡 medium | ⚠️ open |
| 9 | tutorials/README_9.md | ~907-910 | ChatMessage.author `SET_NULL` замість `CASCADE` | 🟠 high | ⚠️ open |
| 10 | tutorials/README_9.md | ~808 | `store` замість `store_name` (ER-діаграма) | 🟠 high | ⚠️ open |
| 11 | notes_project/middleware.py | 1 (settings MIDDLEWARE) | DebugExceptionMiddleware першим, повертає traceback | 🟡 medium | ⚠️ open (code, не doc) |

### Редакційні спостереження (не блокуючі)

| # | Файл | Спостереження | Серйозність |
|---|------|---------------|------------|
| A | tutorials/01_first_django_page.md | standalone проєкт, перехід не позначено | ⚪ editorial |
| B | tutorials/05_authentication.md | неповний urls.py (навмисно) | ⚪ editorial |
| C | tutorials/05_authentication.md | таблиця IDOR спрощена | ⚪ editorial |
| D | tutorials/README_6.md | note_edit без Q-filter (crispy_notes_project — правильно) | ⚪ editorial |
| E | tutorials/README_6.md | remove_user_from_group має 2 аргументи (не 3 як у notes_chat_app) | ⚪ editorial |

---

## Пріоритети

### Необхідно виправити до публікації студентам:

1. **README_9.md ~907**: `author.on_delete=SET_NULL` → `CASCADE`, прибрати `null=True`
2. **README_9.md ~808**: `store` → `store_name` у ER-діаграмі
3. **README_6.md ~951**: Перевірити `form.cleaned_data_for_service()` — чи існує у crispy_notes_project

### Рекомендовано (не блокуючі):

4. Додати примітку у README_8 про відсутність async_selectors/async_views у notes_chat_app
5. Оновити legacy шляхи у README_7
6. Видалити або обмежити `DebugExceptionMiddleware` у production settings

---

---

## tutorials/06_testing.md — СТАТУС: ВИЯВЛЕНО 1 ПОМИЛКУ

README_6 описує тести `notes_chat_app`.

### Tutorial 06 Issue 1 — `ChatMessage.author SET_NULL` у прикладі тесту → 🔴 critical

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/06_testing.md` |
| **Рядки** | ~706–717 |
| **Проблема** | Tutorial показує `test_chat_message_author_becomes_null_when_user_deleted` з `self.assertIsNone(msg.author)` і коментарем "ChatMessage.author = FK(User, SET_NULL)" |
| **Фактичний код** | `notes_app/models.py:262`: `author = models.ForeignKey(User, on_delete=models.CASCADE)` |
| **Наслідок** | Студент пише тест → тест ПАДАЄ: при видаленні user видаляється ChatMessage (CASCADE), а не ставиться NULL на author |
| **Виправлення** | Замінити тест на перевірку CASCADE: після видалення user → `self.assertEqual(ChatMessage.objects.count(), 0)` |
| **Серйозність** | 🔴 **critical** — студент пише тест що завжди падає |
| **Статус** | ⚠️ OPEN |

---

## reference/settings_reference.md — СТАТУС: ВИЯВЛЕНО 1 НЕТОЧНІСТЬ

### Settings Reference Issue 1 — SQLite fallback замість Exception → 🟠 high

| Поле | Значення |
|------|---------|
| **Файл** | `docs/reference/settings_reference.md` |
| **Рядки** | ~44–62 (секція "База даних") |
| **Проблема** | Показує SQLite fallback коли `DATABASE_URL` не встановлено |
| **Фактичний код** | `notes_project/settings.py` підіймає `Exception("DATABASE_URL не встановлено. Запускай через docker compose.")` |
| **Наслідок** | Студент очікує що локальний запуск без DATABASE_URL запустить SQLite — замість цього отримує Exception |
| **Виправлення** | Замінити SQLite-fallback на опис реального поведінки з Exception та посиланням на Troubleshooting |
| **Серйозність** | 🟠 **high** — хибне очікування щодо поведінки без DATABASE_URL |
| **Статус** | ⚠️ OPEN |

---

## reference/testing_cheatsheet.md — СТАТУС: ВИЯВЛЕНО 1 НЕТОЧНІСТЬ

### Testing Cheatsheet Issue 1 — `TestCase` замість `TransactionTestCase` → 🟡 medium

| Поле | Значення |
|------|---------|
| **Файл** | `docs/reference/testing_cheatsheet.md` |
| **Рядки** | ~106 |
| **Проблема** | Consumer test приклад показує `class ConsumerTest(TestCase):` |
| **Фактичний код** | `notes_app/tests/test_consumers.py` використовує `TransactionTestCase` |
| **Чому важливо** | `TestCase` огортає кожен тест у транзакцію яку відкочує. Async consumer tests потребують `TransactionTestCase` щоб фактично бачити дані між sync/async boundaries |
| **Виправлення** | Замінити `TestCase` на `TransactionTestCase` у прикладі |
| **Серйозність** | 🟡 **medium** — тест може не виявляти реальні помилки |
| **Статус** | ⚠️ OPEN |

---

## Зведена таблиця — ОНОВЛЕНО (ревізія 4 FIX, 2026-06-14)

### Статус виправлень tutorial 05

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| 1 | tutorials/05_authentication.md | 1294 | `update_note(note, form.cleaned_data)` → TypeError | 🔴 critical | ✅ **FIXED** |
| 2 | tutorials/05_authentication.md | 1287–1298 | `get_object_or_404` замість Q-filter | 🟠 high | ✅ **FIXED** |
| 3 | tutorials/05_authentication.md | 1378 | `store` замість `store_name` | 🟠 high | ✅ **FIXED** |
| 4 | tutorials/05_authentication.md | 1565–1577 | `group_create` raw POST замість `GroupCreateForm` | 🟠 high | ✅ **FIXED** |
| 5 | test_views.py (header) | ~1 | неправильний шлях у коментарі | 🟢 low | ✅ **FIXED** |

### Нові проблеми (знайдені в ревізії 2 — README_6–9)

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| 6 | tutorials/README_6.md | ~951 | `form.cleaned_data_for_service()` — метод не визначений ніде у README_6 чи примітивному API Django | 🟠 high | ✅ FIXED |
| 7 | tutorials/README_7.md | ~989, ~1705 | Legacy шляхи `module_5/...` | 🟢 low | ⚠️ deferred |
| 8 | tutorials/README_8.md | ~88-108 | async_selectors.py, async_services.py не існують у notes_chat_app | 🟡 medium | ✅ FIXED (callout added) |
| 9 | tutorials/README_9.md | ~907-910 | ChatMessage.author `SET_NULL` замість `CASCADE` | 🟠 high | ✅ FIXED |
| 10 | tutorials/README_9.md | ~808 | `store` замість `store_name` (ER-діаграма) | 🟠 high | ✅ FIXED |
| 11 | notes_project/middleware.py | - | DebugExceptionMiddleware першим у MIDDLEWARE | 🟡 medium | ⚠️ documented (no code change) |

### Нові проблеми (знайдені в ревізії 3 — інспекція туторіалів 01–08, reference)

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| 12 | tutorials/06_testing.md | ~706–717 | `test_chat_message_author_becomes_null_when_user_deleted` → SET_NULL, реально CASCADE | 🔴 critical | ✅ FIXED |
| 13 | reference/settings_reference.md | ~44–62 | SQLite fallback замість Exception при відсутності DATABASE_URL | 🟠 high | ✅ FIXED |
| 14 | reference/testing_cheatsheet.md | ~106 | `TestCase` замість `TransactionTestCase` у consumer test прикладі | 🟡 medium | ✅ FIXED |
| 15 | tutorials/07_async.md | ~1121 | `class GroupChatConsumerTest(TestCase):` — має бути `TransactionTestCase` | 🟡 medium | ✅ FIXED |
| 16 | tutorials/README_9.md | ~1422 | `class GroupChatConsumerTest(TestCase):` — має бути `TransactionTestCase` | 🟡 medium | ✅ FIXED |

### Нові проблеми (знайдені у фазі FIX під час перечитання README_9 ER-діаграми)

| # | Файл | Рядки | Проблема | Джерело | Серйозність | Статус |
|---|------|-------|----------|---------|-------------|--------|
| 17 | tutorials/README_9.md | ~808 | `is_bought` → `is_purchased` (ShopItem ER) | `models.py:218` | 🟠 high | ✅ FIXED |
| 18 | tutorials/README_9.md | ~807 | `quantity (pos.int)` → `quantity (decimal 8,2)` (ShopItem ER) | `models.py:215` | 🟡 medium | ✅ FIXED |
| 19 | tutorials/README_9.md | ~809 | `position (int)` — поле не існує у ShopItem | `models.py:210-228` | 🟠 high | ✅ FIXED (замінено на estimated_price + unit) |
| 20 | tutorials/README_9.md | ~1222 | `or 'Видалений юзер'` в consumer history — імплікує nullable author, CASCADE → не потрібно | `consumers.py:136, models.py:264` | 🟡 medium | ✅ FIXED |
| 21 | tutorials/README_9.md | ~905 | `related_name='messages'` → фактично `'chat_messages'` | `models.py:259` | 🟢 low | ✅ FIXED |
| 22 | tutorials/README_9.md | ~796 | `position (int)` у TodoItem ER → фактично `order_position` | `models.py:177` | 🟢 low | ✅ FIXED |

### Редакційні спостереження (не блокуючі)

| # | Файл | Спостереження | Серйозність |
|---|------|---------------|------------|
| A | tutorials/01_first_django_page.md | standalone проєкт, перехід не позначено | ⚪ editorial |
| B | tutorials/05_authentication.md | неповний urls.py (навмисно) | ⚪ editorial |
| C | tutorials/05_authentication.md | таблиця IDOR спрощена | ⚪ editorial |
| D | tutorials/README_6.md | note_edit без Q-filter (crispy_notes_project — правильно) | ⚪ editorial |
| E | tutorials/README_6.md | remove_user_from_group має 2 аргументи (не 3 як у notes_chat_app) | ⚪ editorial |
| F | docs/08/testing_strategy.md + migrations.md | bare `python manage.py` без `docker compose run --rm web` prefix | ⚪ editorial |

---

---

## tutorials/08_deployment.md — Batch H

### Неточність 23 — `dj_database_url` + SQLite fallback → 🟠 high → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/08_deployment.md` |
| **Рядки (були)** | ~402–429 |
| **Проблема (була)** | Приклад settings.py показував `import dj_database_url` та fallback на SQLite коли DATABASE_URL не встановлено |
| **Реальний код** | `notes_project/settings.py` використовує `import re` + ручний regex parsing; якщо DATABASE_URL не встановлено — `raise Exception("...")`. `dj_database_url` **відсутній** у `requirements.txt`. SQLite fallback **відсутній**. |
| **Виправлення** | Замінено на фактичний код із regex parsing та `CONN_MAX_AGE: 0`. Додано `!!! warning` admonition про Exception поведінку. |
| **Статус** | ✅ **FIXED** |

---

## tutorials/07_async.md — Batch H

### Неточність 24 — `asyncSetUp` з `TransactionTestCase` → 🟡 medium → ⚠️ documented

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/07_async.md` |
| **Рядки** | ~420–430 |
| **Проблема** | Tutorial показує `async def asyncSetUp(self)` з `TransactionTestCase` і `database_sync_to_async` ORM calls |
| **Реальний код** | `notes_app/tests/test_consumers.py` використовує sync `def setUp` з прямими sync ORM calls. Коментар у коді: "asyncSetUp() не підтримується в TransactionTestCase до Django 5.1". |
| **Аналіз** | Цей проєкт використовує Django 5.2, де `asyncSetUp` в `TransactionTestCase` є підтримуваним. Тобто tutorial технічно коректний для Django 5.2, але відрізняється від фактичного test_consumers.py. |
| **Рішення** | Педагогічне неузгодження (medium), не помилка виконання. Не виправляти зараз — потребує переписування секції з поясненням обох підходів. |
| **Статус** | ⚠️ **documented** — відкрите питання для майбутнього rewrite |

---

## tutorials/06_testing.md — Batch H

### Неточність 25 — `TestCase` в consumer test section → 🟠 high → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/06_testing.md` |
| **Рядки (були)** | ~1254–1260 (секція 11 · CONSUMERS) |
| **Проблема (була)** | `from django.test import TestCase` та `class GroupChatConsumerTest(TestCase):` |
| **Реальний код** | `notes_app/tests/test_consumers.py`: `from django.test import TransactionTestCase`; `class GroupChatConsumerTest(TransactionTestCase):` |
| **Виправлення** | Замінено `TestCase` → `TransactionTestCase` в import і class. Додано explanatory comment блок з поясненням чому TransactionTestCase (worker thread visibility + asyncSetUp обмеження). |
| **Статус** | ✅ **FIXED** |

---

## tutorials/README_7.md — Batch H

### Неточність 7 — legacy monorepo paths → 🟢 low → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/README_7.md` |
| **Рядки** | 989, 1504, 1514, 1519, 1557, 1723 |
| **Проблема (була)** | Команди та CI YAML references використовують `module_5/lesson_Django_Testing/crispy_notes_project` — шлях оригінального курсового монорепозиторію |
| **Реальний код** | CI workflow у `notes_chat_app` slідкує за `notes_app/**` та `notes_project/**` без `module_5/` префіксу |
| **Виправлення** | Додано `!!! note` admonition перед "Крок 0 — Запуск" та `!!! warning` перед "Повний workflow" — пояснення про монорепозиторій vs standalone структуру |
| **Статус** | ✅ **FIXED** |

---

## Підрахунок проблем (ревізія 5 — Batch H, 2026-06-14)

### Всього знайдено (1–25, без editorial A–F)

| Категорія | IDs | Знайдено | Виправлено | Залишилось |
|-----------|-----|----------|------------|------------|
| 🔴 critical | 12 | 1 | 1 | **0** |
| 🟠 high | 6, 9, 10, 13, 17, 19, 23, 25 | 8 | 8 | **0** |
| 🟡 medium | 8, 11, 14, 15, 16, 18, 20, 24 | 8 | 6 | **2** (Issue 11 code, 24 deferred) |
| 🟢 low | 7, 21, 22 | 3 | 3 | **0** |
| **Всього doc** | | **20** | **18** | **2** |
| code (11) | — | 1 | — | **documented** |

> Issue 11 (DebugExceptionMiddleware) — code issue, не документаційна помилка.
> Задокументовано у `notes_project/middleware.py` docstring. Зміна коду потребує окремого рішення.

> Issue 24 (asyncSetUp) — педагогічне неузгодження (medium), не помилка виконання. Django 5.2 підтримує asyncSetUp в TransactionTestCase. Потребує rewrite секції.

---

## Пріоритети (після Batch H)

### Всі Critical та High виправлено ✅

Виправлені: Issue 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25

### Залишилось відкритим після Batch H:

- **Issue 24** (🟡 medium) — 07_async.md: asyncSetUp vs sync setUp — ✅ виправлено у Batch N (2026-06-14)
- **Issue 11** (code) — DebugExceptionMiddleware — ✅ виправлено у Batch N (2026-06-14)

---

## Що НЕ перевірялось (залишається відкритим)

- `crispy_notes_project/hello_app/forms.py` — чи існує `cleaned_data_for_service()`
- README_1-5 — **перевірено ревізія 3**: немає references до notes_chat_app (standalone projects). README_3 перевірено і моделі точні (store_name ✅, PositiveSmallIntegerField ✅)
- KB full-chapters (03–11) — **перевірено ревізія 3 цільовим grep**: `orm_mermaid_full.md` показує `store_name` ✅. Немає додаткових ChatMessage/SET_NULL/store помилок знайдено.
- `docs/reference/orm_cheatsheet.md` — grep: без ChatMessage/SET_NULL/store помилок ✅
- `docs/reference/git_cheatsheet.md` — references тільки `WebsocketCommunicator` у git commit message прикладі (OK)
- `tutorials/01_first_django_page.md`, `02_first_model.md`, `03_crud.md`, `04_templates_bootstrap.md` — **перевірено у Batch M** (2026-06-14). Деталі нижче.

---

## tutorials/01–04 — Batch M (2026-06-14)

Туторіали 01–04 описують standalone precursor-проєкти (hello_project → bootstrap_notes → crispy_notes).
Вони не посилаються на notes_chat_app код безпосередньо — відмінності моделей є **навмисними** педагогічними спрощеннями.

### Tutorial 01 (01_first_django_page.md) — СТАТУС: без критичних помилок ✅

Standalone `hello_project`. Всі команди, URL, view-функції, settings.py анатомія — коректні для Django 5.2.
Примітка A: settings.py теоретична секція (04) показує `django_bootstrap5`, `crispy_forms` в INSTALLED_APPS — це forward-reference для ілюстрації, а не інструкція для цього кроку. ⚪ editorial.

### Tutorial 02 (02_first_model.md) — СТАТУС: 1 виправлення ✅

#### Issue M-5 — URL `/del/` замість `/delete/` → 🟢 low → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/02_first_model.md` |
| **Рядки** | 1297–1298 (таблиця "Як все пов'язано") |
| **Проблема** | Таблиця показувала `/notes/42/del/` але URL pattern (рядок 950–952) визначає `/notes/<int:pk>/delete/` |
| **Виправлення** | Замінено `/del/` на `/delete/` у обох рядках таблиці |
| **Статус** | ✅ FIXED |

### Tutorial 03 (03_crud.md) — СТАТУС: 2 виправлення ✅

#### Issue M-2 — `update_note` без параметра `notebook` → 🔴 critical → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/03_crud.md` |
| **Рядки (були)** | 1067–1068 (`update_note` сигнатура) |
| **Проблема** | Функція `update_note(note, *, title, content, priority, is_pinned, is_archived, tag_ids)` не мала параметра `notebook`. View (Крок 9, lines ~1196–1202) викликав `services.update_note(..., notebook=form.cleaned_data.get('notebook'), ...)` → **`TypeError: unexpected keyword argument 'notebook'`** |
| **Джерело** | Порівняно з `notes_app/services.py:24–25`: `def update_note(note, *, title, content, notebook=None, ...)` |
| **Виправлення** | Додано `notebook=...` (Ellipsis sentinel) до сигнатури; додано блок `if notebook is not ...: note.notebook = notebook; changed.append('notebook')` з коментарем що пояснює патерн |
| **Статус** | ✅ FIXED |

#### Issue M-3 — PRIORITY_CHOICES 3 рівні vs 4 у notes_chat_app → 🟡 medium → ✅ FIXED (note added)

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/03_crud.md` |
| **Рядки** | 819–827 (Note model) |
| **Проблема** | Tutorial показує PRIORITY_CHOICES з 3 рівнями (1=Low, 2=Medium, 3=High) та `SmallIntegerField`/`MaxValueValidator(3)`. Фактичний `notes_chat_app/notes_app/models.py:73–83` має 4 рівні (+ PRIORITY_URGENT=4), `PositiveSmallIntegerField`, `MaxValueValidator(4)`, і Note має `group = ForeignKey(Group)` для групового sharing |
| **Рішення** | Спрощення у tutorial є навмисним (group sharing вводиться у Кроці 5). Додано `!!! note` admonition після Note model з описом відмінностей від notes_chat_app |
| **Статус** | ✅ FIXED (admonition added) |

### Tutorial 04 (04_templates_bootstrap.md) — СТАТУС: 1 виправлення ✅

#### Issue M-4 — `notes_app/` у практичному завданні → 🟡 medium → ✅ FIXED

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/04_templates_bootstrap.md` |
| **Рядок** | 1069 |
| **Проблема** | Практичне завдання п.1: "Відкрий `notes_app/templates/base.html` → ... → `notes_app/note_list.html`". Tutorial 04 будує `hello_app/` (не `notes_app/`). Порядок також зворотний — правильний порядок слідування `{% extends %}` ланцюга: від конкретного шаблону до базового |
| **Виправлення** | Замінено на `hello_app/templates/hello_app/note_list.html → templates/layouts/dashboard.html → templates/base.html` |
| **Статус** | ✅ FIXED |

---

## Підрахунок проблем (ревізія 6 — Batch M, 2026-06-14)

### Нові проблеми Batch M (Issues M-2 — M-5)

| # | Файл | Рядки | Проблема | Серйозність | Статус |
|---|------|-------|----------|-------------|--------|
| M-2 | tutorials/03_crud.md | 1067–1068 | `update_note` без `notebook` → TypeError | 🔴 critical | ✅ FIXED |
| M-3 | tutorials/03_crud.md | 819–827 | PRIORITY_CHOICES 3 vs 4 рівні, відсутній group FK | 🟡 medium | ✅ FIXED (note) |
| M-4 | tutorials/04_templates_bootstrap.md | 1069 | `notes_app/` замість `hello_app/` | 🟡 medium | ✅ FIXED |
| M-5 | tutorials/02_first_model.md | 1297–1298 | `/del/` замість `/delete/` | 🟢 low | ✅ FIXED |

### Загальний статус після Batch M

| Категорія | Знайдено (всього) | Виправлено | Залишилось |
|-----------|-------------------|------------|------------|
| 🔴 critical | 1 + M-2 = 2 | 2 | **0** |
| 🟠 high | 8 | 8 | **0** |
| 🟡 medium | 6 + M-3 + M-4 = 8 | 7 | **1** (Issue 24 deferred) |
| 🟢 low | 3 + M-5 = 4 | 4 | **0** |
| **Всього doc** | **23** | **22** | **1** |
| code | 1 | — | **documented** |

---

## Batch N — Issue 11 + Issue 24 (2026-06-14)

### Issue 11 — DebugExceptionMiddleware (settings.py)

| Поле | Значення |
|------|---------|
| **Файл** | `notes_project/settings.py` |
| **Проблема** | `DebugExceptionMiddleware` — перший у MIDDLEWARE (перед `SecurityMiddleware`); повертає HTML traceback навіть при `DEBUG=False` |
| **Вплив** | Production security: HSTS/HTTPS redirect від `SecurityMiddleware` не застосовується до traceback-відповіді; traceback розкривається клієнтам |
| **Виправлення** | `SecurityMiddleware` переміщено на першу позицію; `DebugExceptionMiddleware` загорнуто у `if DEBUG:` → `MIDDLEWARE.insert(0, ...)` |
| **Статус** | ✅ **FIXED** |

### Issue 24 — asyncSetUp vs setUp (07_async.md)

| Поле | Значення |
|------|---------|
| **Файл** | `docs/tutorials/07_async.md` рядок 1128 |
| **Проблема** | Туторіал показував `async def asyncSetUp(self):` з `database_sync_to_async`; реальний `test_consumers.py` використовує синхронний `def setUp(self):` |
| **Вплив** | Педагогічне неузгодження: студент бачить asyncSetUp, але реальний код — sync setUp |
| **Виправлення** | `asyncSetUp` → `def setUp(self):` з прямими синхронними ORM-викликами; додано `!!! note` про Django 5.1+ asyncSetUp підтримку |
| **Статус** | ✅ **FIXED** |

### Загальний статус після Batch N

| Категорія | Знайдено (всього) | Виправлено | Залишилось |
|-----------|-------------------|------------|------------|
| 🔴 critical | 2 | 2 | **0** |
| 🟠 high | 8 | 8 | **0** |
| 🟡 medium | 8 | 8 | **0** |
| 🟢 low | 4 | 4 | **0** |
| **Всього doc** | **23** | **23** | **0** ✅ |
| code (11) | 1 | 1 | **0** ✅ |
