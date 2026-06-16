# Project Code Documentation Map

Відповідність між компонентами коду та документацією.
Інспекція: 2026-06-14 (оновлено: 2026-06-14). Гілка: main.

Статус точності:
- ✅ **accurate** — документація відповідає коду
- ⚠️ **partial** — часткова відповідність або спрощення
- 🔴 **inaccurate** — конкретні помилки у документації
- 📝 **undocumented** — код не задокументований

---

## notes_app/models.py

**Реальний шлях:** `notes_app/models.py`

### UserProfile

| Атрибут | Значення |
|---------|---------|
| Клас | `UserProfile(models.Model)` |
| Поля | `user` OneToOne(User, CASCADE, related='profile'), `display_name` Char(max=100,blank), `avatar_url` URLField(blank), `timezone` Char(max=50,default='UTC'), `bio` Text(blank) |
| Тест | `test_models.py` — немає прямого тесту UserProfile |
| Документація | `12_final_project/domain_model.md` (Mermaid), `tutorials/05_authentication.md` (не задокументований) |
| Статус | 📝 **undocumented** — UserProfile не згадується у туторіалах |
| **Виправлення (ревізія 3)** | avatar — URLField (не ImageField); поля: display_name, avatar_url, timezone, bio |

### Tag

| Атрибут | Значення |
|---------|---------|
| Клас | `Tag(models.Model)` |
| Поля | `user` FK(User,CASCADE), `name` Char(max=50), `color` Char(max=7,default='#6c757d') |
| Constraints | `unique_together = [['user', 'name']]` |
| Тест | `test_models.py::TagModelTest` — unique_together, default_color |
| Документація | `tutorials/03_crud.md` (домен), `12_final_project/domain_model.md` (Mermaid) |
| Статус | ✅ **accurate** |

### Notebook

| Атрибут | Значення |
|---------|---------|
| Клас | `Notebook(models.Model)` |
| Поля | `user` FK(User,CASCADE), `title` Char(max=200), `description` Text(blank), `color` Char(max=7,default='#0d6efd'), `is_default` Bool(default=False) |
| Ordering | `['-is_default', 'title']` |
| Тест | `test_models.py::NotebookModelTest` — str, default_color |
| Документація | `tutorials/03_crud.md`, `tutorials/05_authentication.md` (NoteForm секція) |
| Статус | ✅ **accurate** |

### Note

| Атрибут | Значення |
|---------|---------|
| Клас | `Note(models.Model)` |
| Поля | `user` FK(User,CASCADE), `notebook` FK(Notebook,SET_NULL,null,blank), `group` FK(Group,SET_NULL,null,blank,related='notes'), `title` Char(max=200), `content` Text(blank), `priority` PositiveSmall(default=1), `is_pinned` Bool(false), `is_archived` Bool(false), `created_at` auto_now_add, `updated_at` auto_now, `tags` M2M(Tag,blank) |
| Constraints | CheckConstraint: priority IN (1,2,3,4) |
| Indexes | (user, is_archived), (group, is_archived) |
| Deletion | notebook→SET_NULL, group→SET_NULL, tags→M2M (не CASCADE) |
| Тест | `test_models.py::NoteModelTest` — str, defaults, validators, SET_NULL on group delete |
| Документація | `tutorials/03_crud.md`, `tutorials/05_authentication.md`, `12_final_project/domain_model.md` |
| Статус | ✅ **accurate** у domain_model, ⚠️ **partial** у tutorial 05 (group access logic спрощена) |

### Reminder

| Атрибут | Значення |
|---------|---------|
| Клас | `Reminder(models.Model)` |
| Поля | `note` FK(Note,CASCADE), `remind_at` DateTimeField, `is_sent` Bool(false), **`repeat_pattern`** Char(max=20, choices=REPEAT_CHOICES, default='none') |
| Deletion | note→CASCADE |
| Ordering | `['remind_at']` |
| Тест | Непряме тестування в test_models.py (Note deletion) |
| Документація | `12_final_project/domain_model.md` (Mermaid — без `repeat_pattern`) |
| Статус | 🔴 **inaccurate** — `repeat_pattern` поле відсутнє у всій документації |

### TodoList

| Атрибут | Значення |
|---------|---------|
| Клас | `TodoList(models.Model)` |
| Поля | `user` FK(User,CASCADE), `title` Char(max=200), **`description`** Text(blank), **`is_completed`** Bool(default=False), `shared_with` M2M(User,related='shared_todo_lists',blank) |
| Deletion | shared_with→M2M (не CASCADE) |
| Ordering | **`['is_completed', '-created_at']`** |
| Тест | `test_views.py::TodoListSharingTest` |
| Документація | `tutorials/05_authentication.md` (згадується), `12_final_project/domain_model.md` |
| Статус | 🔴 **inaccurate** — `description` і `is_completed` відсутні у PROJECT_CODE_DOCUMENTATION_MAP та туторіалах; ordering неточна |

### TodoItem

| Атрибут | Значення |
|---------|---------|
| Клас | `TodoItem(models.Model)` |
| Поля | `todo_list` FK(TodoList,CASCADE), `text` Char(max=500), `is_done` Bool(false), **`order_position`** PositiveInt(default=0), **`due_date`** DateField(null,blank) |
| Ordering | `['order_position', 'id']` |
| Тест | Непрямо через test_views |
| Документація | `12_final_project/domain_model.md` (Mermaid — показує `position` замість `order_position`) |
| Статус | 🔴 **inaccurate** — поле `order` у попередньому аудиті та `position` у README_9 є неправильними; реальна назва `order_position`; `due_date` не задокументовано |

### ShoppingList

| Атрибут | Значення |
|---------|---------|
| Клас | `ShoppingList(models.Model)` |
| Поля | `user` FK(User,CASCADE), `group` FK(Group,SET_NULL,null,blank), `title` Char(max=200), **`store_name`** Char(max=100,blank), `shared_with` M2M(User,blank) |
| Deletion | group→SET_NULL |
| Ordering | `['-created_at']` |
| Тест | Непряме тестування |
| Документація | `tutorials/05_authentication.md` рядок 1378 — **ВИПРАВЛЕНО** (store → store_name); README_9 лінія ~808 показує `store` — **ЩЕ НЕТОЧНО** |
| Статус | ⚠️ **partial** — tutorial 05 виправлено, README_9 потребує виправлення |

### ShopItem

| Атрибут | Значення |
|---------|---------|
| Клас | `ShopItem(models.Model)` |
| Поля | `shopping_list` FK(ShoppingList,CASCADE,related='items'), `name` Char(max=200), `quantity` DecimalField(max_digits=8,decimal_places=2,default=1,min>0), `unit` Char(max=5,choices=UNIT_CHOICES,default='шт'), `is_purchased` Bool(false), `estimated_price` DecimalField(max_digits=10,decimal_places=2,null,blank) |
| Ordering | `['is_purchased', 'name']` |
| Constraints | CheckConstraint: quantity > 0 |
| Тест | `test_models.py::ShopItemModelTest` — str, defaults, CheckConstraint |
| Документація | `12_final_project/domain_model.md` |
| Статус | ⚠️ **partial** — quantity є DecimalField (не PositiveInt), є unit choices та estimated_price |
| **Виправлення (ревізія 3)** | quantity=DecimalField; unit=Char(max=5,choices=[шт/кг/л/г]); is_purchased (не is_bought); estimated_price існує |

### ChatMessage

| Атрибут | Значення |
|---------|---------|
| Клас | `ChatMessage(models.Model)` |
| Поля | `group` FK(Group,CASCADE,related='chat_messages'), `author` FK(User,CASCADE,related='chat_messages'), `content` TextField, `timestamp` DateTimeField(auto_now_add=True) |
| Deletion | group→CASCADE (чат видаляється з групою), author→**CASCADE** (повідомлення видаляються з юзером!) |
| Ordering | `['timestamp']` |
| Indexes | (group, timestamp) |
| Тест | Непряме тестування через consumers |
| Документація | `tutorials/07_async.md` ✅; README_9 рядки ~900-924 — **ПОМИЛКА**: показує `author.on_delete=SET_NULL` і `related_name='messages'`, реально `CASCADE` і `'chat_messages'` |
| Статус | 🔴 **inaccurate** у README_9 — author on_delete та related_name неточні |

---

## notes_app/selectors.py

**Реальний шлях:** `notes_app/selectors.py`

| Функція | Підпис | Що повертає | Тест | Документація | Статус |
|---------|--------|-------------|------|--------------|--------|
| `get_user_notes` | `(user, *, archived=False)` | QuerySet Notes (власні + групові), select_related+prefetch | `test_views.py` | `tutorials/03_crud.md`, `tutorials/05_authentication.md` | ✅ accurate |
| `get_note_detail` | `(pk, user)` | Note з prefetch Reminder | `test_views.py` | не задокументований окремо | 📝 undocumented |
| `get_user_notebooks` | `(user)` | QuerySet Notebooks | непряме | `tutorials/04` | ✅ accurate |
| `get_user_tags` | `(user)` | QuerySet Tags | непряме | `tutorials/04` | ✅ accurate |
| `get_user_todo_lists` | `(user)` | QuerySet TodoLists з shared | не прямо | не задокументований | 📝 undocumented |
| `get_user_shopping_lists` | `(user)` | QuerySet ShoppingLists | не прямо | не задокументований | 📝 undocumented |
| `get_user_groups` | `(user)` | QuerySet Groups annotated member_count | `test_views.py` | `tutorials/05_authentication.md` | ✅ accurate |
| `get_group_with_members` | `(pk, user)` | Group або None (membership check) | `test_views.py` | `tutorials/05_authentication.md` | ✅ accurate |

---

## notes_app/services.py

**Реальний шлях:** `notes_app/services.py`

| Функція | Підпис | Поведінка | Тест | Документація | Статус |
|---------|--------|-----------|------|--------------|--------|
| `create_note` | `(user, *, title, content, priority, notebook, is_pinned, group, tag_ids)` | transaction.atomic, tags.set() | `test_services.py` | `tutorials/03_crud.md` | ✅ accurate |
| `update_note` | `(note, *, title, content, priority, notebook, is_pinned, group=..., tag_ids)` | Sentinel `...` для group | `test_services.py` | `tutorials/05_authentication.md` — **ВИПРАВЛЕНО** | ✅ accurate (після виправлення) |
| `delete_note` | `(note)` | simple delete | `test_services.py` | не задокументований окремо | ✅ accurate implicitly |
| `create_notebook` | `(user, *, title, description, color, is_default)` | atomic, unsets old default | `test_services.py` | `tutorials/04` | ✅ accurate |
| `update_notebook` | `(notebook, *, title, description, color, is_default)` | atomic, old default | `test_services.py` | не задокументований | 📝 undocumented |
| `create_group` | `(name, creator)` | atomic, group.user_set.add(creator) | `test_services.py` | `tutorials/05_authentication.md` | ✅ accurate |
| `add_user_to_group` | `(group, username)` → `(bool, msg)` | lookup User, add | `test_services.py` | `tutorials/05_authentication.md` | ✅ accurate |
| `remove_user_from_group` | `(group, user_pk, remover)` | checks not removing self | `test_services.py` | `tutorials/05_authentication.md` | ✅ accurate |
| `delete_group` | `(group, user)` | checks membership | `test_services.py` | `tutorials/05_authentication.md` | ✅ accurate |

---

## notes_app/views.py

**Реальний шлях:** `notes_app/views.py`
Всі views — FBV з `@login_required`.

| View | URL | Метод | Примітки | Тест | Статус doc |
|------|-----|-------|----------|------|-----------|
| `index` | `/` | GET | public, показує landing | `test_views.py` | ✅ |
| `note_list` | `/notes/` | GET | Q-filter: власні + групові | `test_views.py` | ✅ |
| `note_create` | `/notes/new/` | GET/POST | NoteForm(user=) | `test_views.py` | ✅ |
| `note_detail` | `/notes/<pk>/` | GET | get_note_detail selector | `test_views.py` | ✅ |
| `note_edit` | `/notes/<pk>/edit/` | GET/POST | Q-filter access + owner check, NoteForm, `services.update_note(note, **kwargs)` — **ВИПРАВЛЕНО** | `test_views.py` | ✅ (після виправлення) |
| `note_delete` | `/notes/<pk>/delete/` | GET/POST | `get_object_or_404(Note,pk=pk,user=request.user)` — власник тільки | `test_views.py` | ✅ |
| `notebook_*` | `/notebooks/` | GET/POST | стандартний CRUD | `test_views.py` | ✅ |
| `register` | `/register/` | GET/POST | UserCreationForm, auto-login | `test_views.py` | ✅ |
| `todo_*` | `/todo/` | GET/POST | TodoList CRUD + share + items | `test_views.py` | ✅ |
| `shopping_*` | `/shopping/` | GET/POST | ShoppingList CRUD + group + share + items | `test_views.py` | ✅ |
| `group_list` | `/groups/` | GET | get_user_groups (annotated) | `test_views.py` | ✅ |
| `group_create` | `/groups/new/` | GET/POST | **`GroupCreateForm`** — **ВИПРАВЛЕНО** | `test_views.py` | ✅ (після виправлення) |
| `group_detail` | `/groups/<pk>/` | GET/POST | 3-action: add/remove/leave | `test_views.py` | ✅ |
| `group_delete` | `/groups/<pk>/delete/` | GET/POST | membership check | `test_views.py` | ✅ |
| `group_chat` | `/groups/<pk>/chat/` | GET | рендерить HTML, WS через routing | `test_views.py` | ✅ |

---

## notes_app/consumers.py

**Реальний шлях:** `notes_app/consumers.py`
**Клас:** `GroupChatConsumer(AsyncWebsocketConsumer)`

| Метод | Поведінка | Тест | Документація |
|-------|-----------|------|--------------|
| `connect` | auth check, group membership, group_add, accept(), load_history | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `disconnect` | group_discard (з hasattr guard) | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `receive` | JSON parse, max 2000 chars, save_message, group_send | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `chat_message` | broadcast event handler | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `load_history` | `@database_sync_to_async`, `.values()` + `list()` + `.reverse()` | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `save_message` | `@database_sync_to_async`, `ChatMessage.objects.create()` | `test_consumers.py` | `tutorials/07_async.md` ✅ |
| `check_membership` | `@database_sync_to_async`, group lookup | `test_consumers.py` | `tutorials/07_async.md` ✅ |

**Статус документації consumers:** ✅ **accurate** — tutorial 07 повно описує lifecycle

---

## notes_app/forms.py

**Реальний шлях:** `notes_app/forms.py`

| Форма | Поля | Безпека | Тест | Документація | Статус |
|-------|------|---------|------|--------------|--------|
| `NoteForm` | title, content, priority, notebook, tags, is_pinned, group | queryset notebook/tags/group по user kwarg (IDOR prevention) | `test_forms.py` | `tutorials/04`, `tutorials/05` | ✅ |
| `NotebookForm` | title, description, color, is_default | — | `test_forms.py` | `tutorials/04` | ✅ |
| `TagForm` | name, color | — | `test_forms.py` | `tutorials/03` | ✅ |
| `TodoListForm` | title | — | `test_forms.py` | — | 📝 |
| `TodoItemForm` | text (form_tag=False) | — | `test_forms.py` | — | 📝 |
| `ShoppingListForm` | title, store_name, group | queryset group по user | `test_forms.py` | — | 📝 |
| `ShopItemForm` | name, quantity, unit (form_tag=False) | — | `test_forms.py` | — | 📝 |
| `ShareForm` | users | — | `test_forms.py` | — | 📝 |
| `ReminderForm` | remind_at | — | `test_forms.py` | — | 📝 |
| `GroupCreateForm` | name | unique_together validation | `test_forms.py` | `tutorials/05` — **ВИПРАВЛЕНО** (тепер показана форма) | ✅ |
| `GroupAddMemberForm` | username | — | `test_forms.py` | — | 📝 |

---

## notes_project/settings.py

**Реальний шлях:** `notes_project/settings.py`

| Налаштування | Значення | Документація | Статус |
|-------------|---------|--------------|--------|
| `INSTALLED_APPS` | daphne першим (ASGI override) | `tutorials/07_async.md` | ✅ |
| `DATABASE_URL` | required, raises Exception | `tutorials/08_deployment.md` | ✅ |
| `CHANNEL_LAYERS` | RedisChannelLayer if REDIS_URL, else InMemory; socket_timeout=None | `tutorials/07_async.md` | ✅ |
| `DEBUG=False` | жорстко закодовано | `tutorials/08_deployment.md` | ✅ |
| `LANGUAGE_CODE='uk'` | — | `reference/settings_reference.md` | ⚠️ потрібна перевірка |
| `CSRF_TRUSTED_ORIGINS` | з NGROK_DOMAIN | `tutorials/08_deployment.md` | ✅ |
| `SESSION_COOKIE_HTTPONLY=True` | XSS захист | `tutorials/05_authentication.md` | ✅ |
| `CSRF_COOKIE_HTTPONLY=False` | для fetch у чаті | `tutorials/05_authentication.md` | ✅ |
| `MESSAGE_TAGS` | Bootstrap variants | `tutorials/05_authentication.md` | ✅ |
| `EMAIL_BACKEND` | console (dev) | `tutorials/05_authentication.md` | ✅ |
| `MIDDLEWARE[0]` | **`notes_project.middleware.DebugExceptionMiddleware`** (перед SecurityMiddleware!) | Ніде не задокументовано | 📝 **undocumented** (security concern) |

---

## notes_project/asgi.py

**Реальний шлях:** `notes_project/asgi.py`

| Компонент | Значення | Документація | Статус |
|----------|---------|--------------|--------|
| Import order | `get_asgi_application()` ПЕРЕД notes_app imports | `tutorials/07_async.md` | ✅ |
| HTTP routing | `ASGIStaticFilesHandler(django_asgi_app)` | `tutorials/07_async.md`, `tutorials/08_deployment.md` | ✅ |
| WS routing | `AuthMiddlewareStack(URLRouter(websocket_urlpatterns))` | `tutorials/07_async.md` | ✅ |

---

## notes_project/routing.py

**Реальний шлях:** `notes_project/routing.py`

| WebSocket URL | Consumer | Документація | Статус |
|--------------|---------|--------------|--------|
| `ws/groups/<group_pk>/chat/` | `GroupChatConsumer` | `tutorials/07_async.md` | ✅ |

---

## notes_project/middleware.py ← НОВИЙ ЗАПИС

**Реальний шлях:** `notes_project/middleware.py`

| Компонент | Значення |
|----------|---------|
| Клас | `DebugExceptionMiddleware` |
| Позиція | ПЕРШИЙ у `settings.MIDDLEWARE` (перед `SecurityMiddleware`) |
| Призначення | Catch-all для 500 помилок — виводить traceback у stdout та повертає HTML pre з traceback |
| Ризик | Розкриває traceback у HTTP-відповіді при помилках. Тимчасовий debug middleware (`"""Temporary debug middleware"""`). Розміщення ПЕРЕД SecurityMiddleware означає що він перехоплює запити до перевірок безпеки. |
| Документація | Ніде не задокументовано у туторіалах |
| Статус | 📝 **undocumented** — security concern, потребує примітки |

---

## notes_app/context_processors.py ← НОВИЙ ЗАПИС

**Реальний шлях:** `notes_app/context_processors.py`

| Компонент | Значення |
|----------|---------|
| Функція | `sidebar_context(request)` |
| Що повертає (authenticated) | `sidebar_notebooks`, `sidebar_tags`, `sidebar_todo_count`, `sidebar_shopping_count`, `sidebar_groups` |
| Що повертає (anonymous) | Всі порожні / нулі |
| Захист | Try/except для DB помилок (OperationalError тощо) |
| Реєстрація | `settings.TEMPLATES[0]['OPTIONS']['context_processors']` |
| Документація | `docs/05_frontend_and_templates/advanced_templates_full.md §1` (є посилання у docstring) |
| Статус | ⚠️ **partial** — згадується у advanced_templates_full але не в туторіалах |

---

## notes_app/urls.py

**Реальний шлях:** `notes_app/urls.py`
**app_name:** `notes_app`

Зареєстровано 33 URL-patterns, включаючи:
- Notes CRUD (5)
- Notebooks CRUD (4)
- Tags (1)
- Register (1)
- TodoList CRUD + share + items (9)
- ShoppingList CRUD + share + items (9)
- Reminders (2)
- Groups + chat (5)

**Документація:** `tutorials/05_authentication.md` (Крок 2) — показує лише Notes, Notebooks, Register, Groups. Не показує TodoList, ShoppingList, Reminders, Tags — **навмисне спрощення** для туторіалу про аутентифікацію.

**Статус:** ⚠️ **partial** — навмисна неповнота, але потребує примітки

---

## Feature → View → Template → JS карта

| Фіча | View | Шаблон | JS |
|------|------|--------|-----|
| Landing page | `index` | `index.html` | — |
| Список нотаток | `note_list` | `note_list.html` | — |
| Деталь нотатки | `note_detail` | `note_detail.html` | — |
| Форма нотатки | `note_create`, `note_edit` | `note_form.html` | — |
| Видалення нотатки | `note_delete` | `note_confirm_delete.html` | — |
| Список записників | `notebook_list` | `notebook_list.html` | — |
| Форма записника | `notebook_create`, `notebook_edit` | `notebook_form.html` | — |
| Видалення записника | `notebook_delete` | `notebook_confirm_delete.html` | — |
| Форма тега | `tag_create` | `tag_form.html` | — |
| Список Todo | `todo_list` | `todo_list.html` | — |
| Деталь Todo | `todo_detail` | `todo_detail.html` | — |
| Форма Todo | `todo_create`, `todo_edit` | (inline у todo_detail/list) | — |
| Видалення Todo | `todo_delete` | `todo_confirm_delete.html` | — |
| Шерінг Todo | `todo_share` | `share_form.html` | — |
| Список Shopping | `shopping_list` | `shopping_list.html` | — |
| Деталь Shopping | `shopping_detail` | `shopping_detail.html` | — |
| Форма Shopping | `shopping_create`, `shopping_edit` | `shopping_form.html` | — |
| Видалення Shopping | `shopping_delete` | `shopping_confirm_delete.html` | — |
| Список груп | `group_list` | `group_list.html` | — |
| Форма групи | `group_create` | `group_form.html` | — |
| Деталь групи | `group_detail` | `group_detail.html` | — |
| Видалення групи | `group_delete` | `group_confirm_delete.html` | — |
| Груповий чат | `group_chat` | `group_chat.html` | `static/notes_app/js/group_chat.js` |

**JS:** `notes_app/static/notes_app/js/group_chat.js` — vanilla JS WebSocket клієнт з exponential backoff reconnection. Підключається до `ws[s]://<host>/ws/groups/<pk>/chat/`. Взаємодіє з `GroupChatConsumer`.

---

## entrypoint.sh ← НОВИЙ ЗАПИС

**Реальний шлях:** `entrypoint.sh`

| Крок | Команда | Примітка |
|------|---------|---------|
| 1 | `python manage.py migrate --noinput` | set -e: при помилці контейнер виходить |
| 2 | `python manage.py collectstatic --noinput` | збирає static у `/app/staticfiles/` |
| 3 | `seed_demo_data --force` | тільки якщо `SEED_DEMO_DATA=1` |
| 4 | `exec python -m uvicorn ... --reload` | замінює shell процес; `--reload` активний! |

**Ризик:** `--reload` прапор у production є небажаним (перезапуск при кожній зміні файлу). Це підходить для DEV, але не для PROD. Потрібно прибрати `--reload` або замінити на `--workers N` перед production деплоєм.

**Документація:** `tutorials/08_deployment.md` ✅ (згадує entrypoint), `docs/tutorials/README_8.md` секція 19 (описує повний вміст)

---

## apps.py ← НОВИЙ ЗАПИС

**Реальний шлях:** `notes_app/apps.py`

| Атрибут | Значення |
|---------|---------|
| Клас | `HelloAppConfig(AppConfig)` |
| `name` | `notes_app` |
| Примітка | Клас названий `HelloAppConfig` (залишок від попереднього проєкту `hello_app`), але `name = 'notes_app'` → Django реєструє правильно |
| Документація | Не задокументовано |
| Статус | 📝 **undocumented** (незначна невідповідність у назві) |

---

## CI/CD (.github/workflows/django-tests.yml)

| Job | Що тестує | Документація | Статус |
|-----|-----------|--------------|--------|
| unit-and-integration | PostgreSQL; test_models + test_services + test_forms + test_views + test_consumers | `tutorials/08_deployment.md` | ✅ |
| selenium-e2e | PostgreSQL + Selenium; test_selenium; needs job 1 | `tutorials/08_deployment.md` | ✅ |

---

## management/commands/seed_demo_data.py

| Компонент | Значення |
|----------|---------|
| Команда | `python manage.py seed_demo_data` |
| Прапорці | `--reset`, `--force` |
| Демо-дані | demo_alice, demo_bob + Notebooks, Notes, Tags, TodoLists, ShoppingLists, ChatMessages |
| SEED_DEMO_DATA=1 | автосідинг при старті контейнера |
| Документація | `CLAUDE.md` (проєкт), `tutorials/08_deployment.md` |
| Статус | ✅ **accurate** |

---

## notes_app/admin.py

Простий `admin.site.register()` для Note, Notebook, Tag, Reminder, TodoList, TodoItem, ShoppingList, ShopItem.
Не реєструє: UserProfile, ChatMessage.

**Документація:** не задокументовано в туторіалах.
**Статус:** 📝 **undocumented** (незначно)

---

## Файли що НЕ існують (виправлення попереднього аудиту)

| Шлях | Статус |
|------|--------|
| `Makefile` | **НЕ ІСНУЄ** у репозиторії |
| `notes_app/signals.py` | **НЕ ІСНУЄ** |
| `notes_app/middleware.py` | **НЕ ІСНУЄ** — middleware лише у `notes_project/middleware.py` |
