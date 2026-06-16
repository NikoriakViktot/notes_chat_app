# Checkpoint — Перевірка знань

---

## Чеклист самоперевірки

### AuthN і Sessions

- [ ] `@login_required` і `LOGIN_URL` у `settings.py` налаштовані
- [ ] `include("django.contrib.auth.urls")` підключено в `urls.py`
- [ ] Шаблони `registration/login.html` і `registration/register.html` існують
- [ ] `{% csrf_token %}` у КОЖНІЙ формі з `method="post"` — без винятків
- [ ] Logout реалізований як POST запит (не GET посилання)
- [ ] `SESSION_COOKIE_HTTPONLY = True` у `settings.py`

### Password Security

- [ ] Password Reset flow протестований (посилання у `docker compose logs web` або terminal)
- [ ] `validlink` перевірка присутня у `password_reset_confirm.html`
- [ ] `AUTH_PASSWORD_VALIDATORS` налаштовані у `settings.py`
- [ ] `EMAIL_BACKEND = console.EmailBackend` для dev

### IDOR і Object Permissions

- [ ] Особисті об'єкти (Notebook, TodoList тощо): `get_object_or_404(Model, pk=pk, user=request.user)`
- [ ] Спільні об'єкти (Note): Q-filter + `note.user != request.user` перед записом
- [ ] Повертається 404 (не 403) для чужих об'єктів

### Group Sharing

- [ ] `Note.group` і `ShoppingList.group` мають `on_delete=SET_NULL`
- [ ] Q-filter `Q(user=user) | Q(group__in=user_groups)` присутній у `selectors.py`
- [ ] `get_user_groups` використовує `annotate(member_count=Count('user'))`
- [ ] `create_group` огорнуто в `transaction.atomic()`
- [ ] Group delete пояснює що нотатки стають особистими (не видаляються)

### Security Settings

- [ ] `SESSION_COOKIE_HTTPONLY = True` і `X_FRAME_OPTIONS = "DENY"` у `settings.py`
- [ ] `DEBUG = False` у production
- [ ] `ALLOWED_HOSTS` містить тільки реальні домени у production
- [ ] Production HTTPS settings закоментовані і готові до увімкнення

---

## IDOR Test — ручна перевірка

Виконай цей тест щоб переконатись що IDOR захист працює:

```
1. Залогінись як alice (demo_alice/demo1234)

2. Перейди на будь-яку нотатку: /notes/
   Запам'ятай pk однієї зі своїх нотаток (наприклад pk=1)

3. Відкрий другу вкладку або incognito вікно
   Залогінись як bob (demo_bob/demo1234)

4. В браузері де ти — bob, вручну введи URL:
   http://localhost/notes/1/edit/     ← pk нотатки alice!

5. Очікуваний результат:
   ✓ 404 Not Found  — захист від IDOR працює
   ✗ Якщо показується форма редагування — IDOR вразливість!

6. Перевір також:
   http://localhost/notes/1/delete/   ← pk нотатки alice
   → теж має повертати 404
```

---

## Типові помилки

### 403 Forbidden на POST формах

```
Симптом: після сабміту форми — "403 Forbidden: CSRF verification failed"

Причина: відсутній {% csrf_token %} у формі

Виправлення:
  <form method="post">
    {% csrf_token %}    ← ОБОВ'ЯЗКОВО!
    ...
  </form>
```

### Logout через GET не працює

```
Симптом: <a href="/accounts/logout/">Вийти</a> не розлогінює (Django 4.1+)

Причина: LogoutView приймає тільки POST запити (Django 4.1+ security fix)

Виправлення:
  <form method="post" action="{% url 'logout' %}">
    {% csrf_token %}
    <button type="submit">Вийти</button>
  </form>
```

### `request.user = AnonymousUser` всередині view

```
Симптом: `request.user.is_authenticated` → False, хоча юзер залогінений

Причина 1: `SessionMiddleware` або `AuthenticationMiddleware` видалений з MIDDLEWARE
Причина 2: Порядок middleware порушений (Auth стоїть перед Session)

Виправлення:
  # settings.py — перевір порядок:
  MIDDLEWARE = [
      ...
      'django.contrib.sessions.middleware.SessionMiddleware',   # ← спочатку Session
      ...
      'django.contrib.auth.middleware.AuthenticationMiddleware',  # ← потім Auth
      ...
  ]
```

### Password Reset email не приходить (dev)

```
Симптом: заповнив форму password_reset, але нічого не відбувається

Причина: шукаєш email у браузері, а не в логах

Виправлення для crispy_notes_project:
  Дивись термінал де запущений runserver — там буде текст email

Виправлення для notes_chat_app:
  docker compose logs -f web
  # Шукай "Subject: Password reset on localhost"
```

### IDOR вразливість залишилась

```
Симптом: інший юзер може редагувати чужу нотатку

Причина: view використовує get_object_or_404(Note, pk=pk) без user=

Виправлення для особистих об'єктів:
  note = get_object_or_404(Note, pk=pk, user=request.user)

Виправлення для спільних об'єктів (Note з групою):
  user_groups = request.user.groups.all()
  note = get_object_or_404(
      Note.objects.filter(Q(user=request.user) | Q(group__in=user_groups)),
      pk=pk,
  )
  if note.user != request.user:
      messages.error(request, 'Ти не можеш редагувати чужу нотатку.')
      return redirect('notes_app:note_detail', pk=pk)
```

### Group видалення видаляє нотатки

```
Симптом: після видалення групи зникають нотатки учасників

Причина: Note.group = ForeignKey(Group, on_delete=CASCADE)

Виправлення:
  Note.group = ForeignKey(
      Group,
      on_delete=models.SET_NULL,   # ← SET_NULL, не CASCADE!
      null=True,
      blank=True,
  )
  # Після цього — нова міграція: python manage.py makemigrations
```

---

## Підсумок: що і де шукати

| Концепція | Де у коді |
|-----------|-----------|
| **AuthN vs AuthZ** | `views.py` — `@login_required` + Q-filter для доступу + `note.user != request.user` для редагування |
| **Middleware chain** | `settings.py` — `MIDDLEWARE` список + порядок |
| **Session flow** | `settings.py` — `SESSION_COOKIE_*` + Django session framework |
| **Login/Logout** | `templates/registration/login.html` + `urls.py` auth.urls |
| **POST logout** | `dashboard.html` — `<form method="post" action="{% url 'logout' %}">` |
| **Password Reset** | `templates/registration/password_reset_*.html` (5 файлів) |
| **DEV email** | `docker compose logs -f web` — знайти URL `/accounts/reset/...` |
| **Password Change** | `templates/registration/password_change_*.html` + dashboard dropdown |
| **IDOR захист** | `views.py` — особисті об'єкти: `get_object_or_404(Model, pk=pk, user=...)`, спільні: Q-filter + owner check |
| **404 не 403** | `views.py` — "не розкривати факт існування чужого об'єкта" |
| **Group FK SET_NULL** | `models.py` — `Note.group` + `ShoppingList.group` |
| **Q-filter** | `selectors.py` — `Q(user=user) \| Q(group__in=user_groups)` |
| **N+1 захист** | `selectors.py` — `select_related('notebook', 'group')`, `prefetch_related('tags')` |
| **Group CRUD** | `services.py` — `create_group`, `add_user_to_group`, `delete_group` |
| **3-action POST** | `views.py group_detail` — `action='add'/'remove'/'leave'` |
| **SET_NULL cascade** | `group_confirm_delete.html` — пояснення поведінки |
| **Security settings** | `settings.py` — `HTTPONLY, SAMESITE, X_FRAME_OPTIONS, DEBUG=False` |
| **ngrok CSRF** | `settings.py` — `CSRF_TRUSTED_ORIGINS` з `NGROK_DOMAIN` env |
| **PBKDF2 паролі** | `auth_user.password` поле — `pbkdf2_sha256$600000$salt$hash` |

---

## Практичне завдання

Виконай самостійно:

1. **Базове:** Запусти `notes_chat_app` (`docker compose up --build`), зареєструй нового юзера, протестуй Password Reset — знайди email у `docker compose logs web` і зміни пароль.

2. **Середнє:** Створи групу "Моя команда", додай demo_bob до групи. Створи нотатку і познач її цією групою. Залогінись як demo_bob і переконайся що нотатка видна у `/notes/`.

3. **Просунуте:** Виконай IDOR тест вручну (описаний вище). Переконайся що отримуєш 404. Потім тимчасово зміни `get_object_or_404(Note.objects.filter(...), pk=pk)` на `get_object_or_404(Note, pk=pk)` і повтори тест — переконайся що IDOR з'являється. Поверни захист назад.

4. **Дослідницьке:** Відкрий DevTools → Application → Cookies після входу. Знайди `sessionid` cookie. Переконайся що `HttpOnly = ✓`. Відкрий Console і виконай `document.cookie` — переконайся що `sessionid` відсутній у відповіді.

---

## Навігація

- Попередній: [Крок 4. Templates і Forms](../04_templates_and_forms/index.md)
- Наступний: [Крок 6. Тестування](../06_testing/index.md)
