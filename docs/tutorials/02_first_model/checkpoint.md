# Контрольна точка

> Фінальна перевірка Кроку 2.
> Виконай практичні завдання, звір чеклист і переглянь типові помилки.

---

## Всі команди по порядку

```bash
# 1. Активувати venv
source venv/bin/activate          # Linux/Mac
# або: venv\Scripts\activate      # Windows

# 2. Встановити залежності
pip install -r requirements.txt

# 3. Застосувати міграції
python manage.py migrate

# 4. Створити адміністратора
python manage.py createsuperuser

# 5. Запустити сервер
python manage.py runserver
# → http://localhost:8000/notes/

# Якщо змінював models.py:
python manage.py makemigrations
python manage.py migrate
```

---

## Що перевірити в браузері

| URL | Що перевірити |
|-----|---------------|
| `http://localhost:8000/` | Редирект на `/notes/` |
| `http://localhost:8000/notes/` | Список з Bootstrap Cards |
| `http://localhost:8000/notes/new/` | Форма створення з Bootstrap стилями |
| `http://localhost:8000/notes/1/` | Деталь нотатки |
| `http://localhost:8000/notes/1/edit/` | Форма редагування (заповнена даними) |
| `http://localhost:8000/notes/1/delete/` | Сторінка підтвердження видалення |
| `http://localhost:8000/admin/` | Адмін-панель з кастомним NoteAdmin |

**Детальна перевірка:**

1. Список: Cards рівні по висоті (`h-100`)
2. Мобільний (DevTools → Toggle Device, Ctrl+Shift+M): 1 колонка, Navbar гамбургер
3. Планшет: 2 колонки; Десктоп: 3 колонки
4. Форма: при порожньому `title` — з'явиться помилка валідації
5. Після створення → Flash-повідомлення `success` з текстом назви
6. F5 після POST → залишається на `/notes/` (PRG працює)

---

## Зміни у файлах

| Файл | Що ти зробив |
|------|-------------|
| `hello_project/settings.py` | `django_bootstrap5` у INSTALLED_APPS, `MESSAGE_TAGS` |
| `hello_app/forms.py` | `NoteForm(ModelForm)` — НОВИЙ |
| `hello_app/views.py` | 5 CRUD views: `index`, `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| `hello_app/urls.py` | 6 URL маршрутів |
| `hello_app/admin.py` | `NoteAdmin` з `list_display`, `search_fields`, `@admin.display` |
| `hello_app/templates/base.html` | Bootstrap CDN, Navbar, Messages, Footer — НОВИЙ |
| `hello_app/templates/hello_app/note_list.html` | Bootstrap Card Grid — ПЕРЕПИСАНИЙ |
| `hello_app/templates/hello_app/note_detail.html` | Деталь + Breadcrumb — НОВИЙ |
| `hello_app/templates/hello_app/note_form.html` | Bootstrap Form — НОВИЙ |
| `hello_app/templates/hello_app/note_confirm_delete.html` | Видалення — НОВИЙ |

---

## Типові помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `TemplateDoesNotExist: base.html` | `base.html` не там де Django шукає | Файл має бути в `hello_app/templates/base.html` (не в `hello_app/templates/hello_app/`) |
| `NoReverseMatch: 'note_create'` | URL name не зареєстровано або не той namespace | Перевір `hello_app/urls.py` і `app_name = 'hello_app'` |
| `NoReverseMatch: 'note_list'` | Не вказано namespace | `{% url 'hello_app:note_list' %}` (з двокрапкою) |
| `403 Forbidden` після POST | Відсутній `{% csrf_token %}` у формі | Додай `{% csrf_token %}` всередину `<form>` |
| Bootstrap стилі не застосовуються | `class='form-control'` не додано до widget | Перевір `NoteForm.Meta.widgets` у `forms.py` |
| `IntegrityError` при збереженні | `title` не може бути порожнім | Перевір валідацію: `form.is_valid()` |
| Дублікат після F5 | Немає redirect після POST | PRG: завжди `return redirect(...)` після `form.save()` |
| Cards різної висоти | Немає `h-100` на `.card` | Додай `h-100` до `<div class="card">` |
| Футер посередині сторінки | Немає Flexbox body | `d-flex flex-column min-vh-100` на `<body>` + `flex-grow-1` на `<main>` |
| Кнопки не кліковні (є stretched-link) | z-index | Додай `position-relative z-1` на `btn-group` |
| Flash-повідомлення не з'являються | `MESSAGE_TAGS` не налаштовано або шаблон не правильний | Перевір `settings.py` → `MESSAGE_TAGS` і `base.html` → `{% if messages %}` |
| `ImproperlyConfigured: namespace` | `app_name` відсутній у `urls.py` | Додай `app_name = 'hello_app'` |

---

## Практичні завдання

1. Запусти проєкт, відкрий `/notes/` — переконайся що сторінка оформлена Bootstrap.
2. Створи 3 нотатки через форму `/notes/new/`. Перевір Flash-повідомлення.
3. Відредагуй одну нотатку. Переконайся що це `UPDATE` а не дублікат (id не змінився).
4. Видали нотатку — переконайся що сторінка підтвердження показується перед видаленням.
5. Додай поле `priority` (choices: 1=Низький, 2=Середній, 3=Високий) до моделі, NoteForm і деталі нотатки.
6. (Бонус) У `note_list.html` покажи Bootstrap Badge з пріоритетом на кожній картці.

---

## Чеклист самоперевірки

- [ ] `base.html` → `note_list.html` / `note_form.html`: Template Inheritance через `{% extends %}`
- [ ] Bootstrap CSS підключений через CDN у `base.html`
- [ ] Flash-повідомлення відображаються після POST і зникають після F5
- [ ] `{% csrf_token %}` є у кожній POST формі
- [ ] `redirect()` після `form.save()` (PRG-паттерн)
- [ ] `get_object_or_404` замість `objects.get()` — 404 а не 500
- [ ] Sticky Footer: `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1`
- [ ] Card Grid адаптивний: 1/2/3 колонки залежно від ширини
- [ ] `note_create` — `form.save()` → INSERT; `note_edit` — `form.save(instance=note)` → UPDATE
- [ ] Я розумію що таке PRG і чому F5 після PRG безпечний

---

## Підсумок концепцій

| Концепція | Де у коді |
|-----------|-----------|
| ModelForm | `hello_app/forms.py` → `class NoteForm(forms.ModelForm)` |
| PRG-паттерн | `note_create`: `return redirect(...)` після `form.save()` |
| Messages | `messages.success(request, ...)` + `{% if messages %}` у `base.html` |
| Template Inheritance | `{% extends 'base.html' %}` + `{% block content %}` |
| CRUD views | `note_list`, `note_detail`, `note_create`, `note_edit`, `note_delete` |
| Bootstrap Grid | `row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4` |
| Sticky Footer | `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1` |
| Захист DELETE | POST, не GET + `{% csrf_token %}` |

---

## Далі

**Крок 3 →** CRUD і архітектура — notes_project: Selectors, Services, ER-діаграми, PostgreSQL, CBV.
