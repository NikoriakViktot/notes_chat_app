# Контрольна точка

> Цей розділ — фінальна перевірка Кроку 1.
> Виконай практичні завдання, звір чеклист і переглянь таблицю частих помилок
> перед тим як переходити до Кроку 2.

---

## Всі команди по порядку

```bash
# 1. Створити і активувати venv
python -m venv venv
source venv/bin/activate      # Linux/Mac
# або: venv\Scripts\activate  # Windows

# 2. Встановити Django
pip install -r requirements.txt
# або: pip install django

# 3. Створити проєкт (крапка важлива!)
django-admin startproject hello_project .

# 4. Застосувати початкові міграції
python manage.py migrate

# 5. Створити адміністратора
python manage.py createsuperuser

# 6. Перевірити адмін-панель
python manage.py runserver
# → http://localhost:8000/admin/

# 7. Створити додаток
python manage.py startapp hello_app

# 8. Зареєструвати hello_app у settings.py
# (додати 'hello_app' до INSTALLED_APPS)

# 9. Написати view-функції (views.py) і URL-маршрути (urls.py)

# 10. Підключити hello_app.urls до hello_project/urls.py (include)

# 11. Описати модель у models.py
# 12. Зробити міграцію
python manage.py makemigrations

# 13. Застосувати міграцію
python manage.py migrate

# 14. Зареєструвати модель в admin.py (@admin.register)

# 15. Фінальна перевірка
python manage.py runserver
# http://localhost:8000/        → Hello, Django!
# http://localhost:8000/about/  → текст
# http://localhost:8000/notes/  → список нотаток
# http://localhost:8000/admin/  → адмін-панель
```

---

## Зміни у файлах

| Файл | Що ти зробив |
|------|-------------|
| `hello_project/settings.py` | Додав `'hello_app'` в `INSTALLED_APPS` |
| `hello_app/models.py` | Написав модель `Note` (CharField, TextField, DateTimeField) |
| `hello_app/admin.py` | Зареєстрував `NoteAdmin` через `@admin.register` |
| `hello_app/migrations/0001_initial.py` | Автоматично згенеровано `makemigrations` |
| `hello_app/views.py` | Написав функції `index()`, `about()`, `note_list()` |
| `hello_app/urls.py` | Створив файл з `app_name` і маршрутами `/, /about/, /notes/` |
| `hello_project/urls.py` | Підключив маршрути через `include()` |
| `hello_app/templates/hello_app/note_list.html` | Перший HTML-шаблон |

---

## Часті помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `AttributeError: 'super' object has no attribute 'dicts'` | Python 3.14 несумісний з Django 5.1 | `pip install django --upgrade` (встановить 5.2+) |
| `OperationalError: no such table: auth_user` | Міграції не запускались | `python manage.py migrate` |
| `OperationalError: no such table: hello_app_note` | `migrate` після `makemigrations` не запускався | `python manage.py migrate` |
| `ModuleNotFoundError: No module named 'django'` | venv не активований або Django не встановлений | Активуй venv → `pip install -r requirements.txt` |
| `Page not found (404)` на `/` | Маршрут не зареєстрований | Перевір `urls.py` в обох файлах |
| `ImproperlyConfigured: Specifying a namespace...` | `namespace=` є в `include()`, але `app_name` відсутній у `hello_app/urls.py` | Додай `app_name = "hello_app"` у `hello_app/urls.py` |
| `NameError: name 'Note' is not defined` | `views.py` не імпортує модель | Додай `from .models import Note` у `views.py` |
| Django не бачить `hello_app` | Не додано в `INSTALLED_APPS` | Додай `'hello_app'` у `settings.py` |
| `django-admin: command not found` | Django не встановлений або venv не активований | Активуй venv, потім `pip install django` |
| `ModuleNotFoundError: No module named 'hello_project'` | Запускаєш не з кореня проєкту | Перейди в папку де є `manage.py` |
| `DisallowedHost` | ALLOWED_HOSTS не містить хост | Додай хост до `ALLOWED_HOSTS` у `settings.py` |
| `CSRF verification failed` | `{% csrf_token %}` відсутній у формі | Додай `{% csrf_token %}` всередині `<form>` |
| Не зупиняється сервер | — | Натисни `Ctrl + C` у терміналі |

---

## Практичні завдання

1. Пройди кроки 1–9 самостійно, отримай `Hello, Django!` у браузері.

2. Додай третій маршрут `/contact/` з view-функцією `contact()`,
   яка повертає рядок з твоїм ім'ям та email.

3. Додай маршрут `/greet/<str:name>/` який повертає `"Привіт, {name}!"`.

4. Створи модель `Note`, зроби міграцію, відкрий адмін-панель і додай 3 нотатки вручну.

5. У Django shell: знайди нотатку з `id=2`, зміни її `title`, збережи.
   Перевір в адмін-панелі.

6. (Бонус) Додай поле `is_pinned = models.BooleanField(default=False)` до моделі `Note`.
   Зроби нову міграцію. Переконайся що поле з'явилось в адмін-панелі.

---

## Чеклист самоперевірки

- [ ] `http://localhost:8000/` → `Hello, Django!`
- [ ] `http://localhost:8000/about/` → текст
- [ ] `http://localhost:8000/notes/` → HTML-список нотаток
- [ ] `http://localhost:8000/admin/` → адмін-панель (логін superuser)
- [ ] Я розумію різницю між `startproject` і `startapp`
- [ ] Я знаю навіщо `makemigrations` і `migrate` — два окремі кроки
- [ ] Модель `Note` з'являється в адмін-панелі
- [ ] Я можу виконати CRUD через Django shell (`create`, `filter`, `get`, `save`, `delete`)
- [ ] Я розумію як Django знаходить view за URL (URLconf ланцюг)
- [ ] Я знаю різницю між superuser / staff / regular user
- [ ] `render()` приймає `request`, шлях до шаблону і словник `context`
- [ ] Шаблон лежить у `hello_app/templates/hello_app/` (подвоєна папка — це правильно)

---

## Підсумок концепцій

| Концепція | Де у коді |
|-----------|-----------|
| URL маршрут | `hello_app/urls.py` → `path('about/', views.about)` |
| View-функція | `hello_app/views.py` → `def about(request): return HttpResponse(...)` |
| Підключення app URLs | `hello_project/urls.py` → `include('hello_app.urls')` |
| Namespace | `app_name = 'hello_app'` + `namespace='hello_app'` |
| Зворотний URL | `reverse('hello_app:about')` або `{% url 'hello_app:about' %}` |
| Path converter | `path('notes/<int:pk>/', ...)` |
| Шаблон | `hello_app/templates/hello_app/note_list.html` |
| Контекст | `render(request, 'шаблон.html', {'notes': queryset})` |
| Модель → БД | `makemigrations` + `migrate` |
| ORM CRUD | `create`, `filter`, `get`, `.save()`, `.delete()` |
| Адмін реєстрація | `@admin.register(Note)` у `admin.py` |
| MVT | Model → View → Template |

---

## Далі

**Крок 2 →** Bootstrap Notes — Bootstrap 5, ModelForm, повноцінний CRUD з PRG-паттерном, перший `notes_project`.
