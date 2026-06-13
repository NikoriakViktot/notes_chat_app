# Туторіал 02 — Bootstrap Notes: ModelForm, CRUD і шаблони

> Цей туторіал перетворює простий Django-проєкт на повноцінний Bootstrap 5-застосунок
> із **Navbar, картками, формами і Flash-повідомленнями**.
>
> **Результат:**
> ```
> http://localhost:8000/notes/           →  Список нотаток — Bootstrap Cards Grid
> http://localhost:8000/notes/new/       →  Форма створення (ModelForm)
> http://localhost:8000/notes/1/         →  Деталь нотатки
> http://localhost:8000/notes/1/edit/    →  Форма редагування (instance=note)
> http://localhost:8000/notes/1/delete/  →  Підтвердження видалення (POST only)
> ```
>
> **Передумови:** пройдений [Туторіал 01](01_first_django_page.md) — є `Note` модель і Django-проєкт.

---

## Зміст

**Теорія** _(читати перед кодом)_
- [01 · ModelForm — автоматична форма з моделі](#01--modelform)
- [02 · PRG-паттерн — чому redirect після POST](#02--prg-паттерн)
- [03 · Django Messages — Flash-повідомлення](#03--django-messages)
- [04 · Template Inheritance — блоки і наслідування](#04--template-inheritance)
- [05 · Bootstrap 5 — Grid і компоненти](#05--bootstrap-5)
- [06 · Django Template Filters і Tags](#06--template-filters-і-tags)

**Покрокова реалізація**
1. [Крок 1 — Bootstrap залежності](#крок-1--bootstrap-залежності)
2. [Крок 2 — base.html — базовий шаблон](#крок-2--basehtml)
3. [Крок 3 — NoteForm (ModelForm)](#крок-3--noteform)
4. [Крок 4 — CRUD views з PRG](#крок-4--crud-views)
5. [Крок 5 — URL-маршрути](#крок-5--url-маршрути)
6. [Крок 6 — Шаблон списку (Card Grid)](#крок-6--шаблон-списку)
7. [Крок 7 — Шаблон форми](#крок-7--шаблон-форми)
8. [Крок 8 — Шаблон видалення](#крок-8--шаблон-видалення)
9. [Крок 9 — Шаблон деталі](#крок-9--шаблон-деталі)

---

## 01 · ModelForm

> `ModelForm` — Django автоматично генерує HTML форму з Python моделі.
> Один клас замінює 50 рядків HTML.

### Без ModelForm vs З ModelForm

```python
# ❌ БЕЗ ModelForm: вручну описуєш кожне поле
class NoteFormManual(forms.Form):
    title   = forms.CharField(max_length=200, label='Заголовок')
    content = forms.CharField(widget=forms.Textarea, required=False, label='Текст')
    # + дублювання з моделлю — при зміні models.py → редагувати ще й тут

# ✅ З ModelForm: один рядок fields = [...]
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content']
        # Django сам дивиться на Note.title (CharField(max_length=200))
        # і генерує forms.CharField(max_length=200)
        # Синхронізація автоматична при зміні моделі
```

### Що ModelForm робить автоматично

```
Note модель                     NoteForm генерує
─────────────────────────       ────────────────────────────────────
CharField(max_length=200)   →   forms.CharField(max_length=200)
                                widget=TextInput
                                → <input type="text" maxlength="200">

TextField(blank=True)       →   forms.CharField(required=False)
                                widget=Textarea
                                → <textarea rows="10"></textarea>

SmallIntegerField(choices)  →   forms.TypedChoiceField(choices=...)
                                widget=Select
                                → <select><option>...</option></select>

BooleanField(default=False) →   forms.BooleanField(required=False)
                                widget=CheckboxInput
                                → <input type="checkbox">

ForeignKey(Notebook)        →   forms.ModelChoiceField(
                                    queryset=Notebook.objects.all())
                                widget=Select
                                → <select> з усіма записниками

ManyToManyField(Tag)        →   forms.ModelMultipleChoiceField(
                                    queryset=Tag.objects.all())
                                widget=SelectMultiple
```

### Цикл форми: GET → POST → redirect

```python
def note_create(request):

    # GET запит → показати порожню форму
    if request.method == 'POST':
        # POST запит → заповнена форма

        form = NoteForm(request.POST)
        # ↑ request.POST: QueryDict {'title': ['Нотатка'], 'content': ['']}
        # NoteForm зв'язується з даними → bound form

        if form.is_valid():
            # is_valid() виконує:
            # 1. Конвертує рядки з request.POST у Python-типи
            # 2. Запускає validators кожного поля
            # 3. Запускає clean_<field>() якщо є
            # 4. Запускає form.clean() (cross-field validation)
            # Якщо є помилки → is_valid() = False → form.errors заповнений

            note = form.save()
            # form.save() = form.instance.save()
            # Виконує INSERT INTO hello_app_note (...) VALUES (...)
            # Повертає збережений об'єкт

            return redirect('hello_app:note_list')
    else:
        form = NoteForm()
        # ↑ Незв'язана (unbound) форма — порожня

    return render(request, 'hello_app/note_form.html', {'form': form})
    # Якщо is_valid() = False → повертаємо ТУ САМО форму з помилками
    # form.errors: {'title': ['Це поле обов\'язкове.']}
    # Шаблон показує помилки під кожним полем
```

### form.save() і form.save(commit=False)

```python
# form.save() — зберігає і повертає об'єкт
note = form.save()   # INSERT INTO + return Note instance

# form.save(commit=False) — не зберігає, повертає несхоплений об'єкт
note = form.save(commit=False)
note.user = request.user   # ← додаємо поля які не у формі
note.save()                # ← тепер зберігаємо

# Чому commit=False?
# Форма NoteForm не включає поле user (захист від IDOR)
# Тому view додає user = request.user вручну перед збереженням
```

### Форма з instance — редагування

```python
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)

    # instance= передає існуючий об'єкт у форму:
    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        # ↑ Зв'язана форма + існуючий об'єкт
        # form.save() → UPDATE замість INSERT
    else:
        form = NoteForm(instance=note)
        # ↑ Форма заповнена поточними даними note

    # Без instance: form.save() завжди INSERT (дублікат!)
    # З instance: form.save() → UPDATE hello_app_note SET ... WHERE id=note.id
```

---

## 02 · PRG-паттерн

> **POST/Redirect/Get** — стандарт обробки форм. Захищає від дублікатів при F5.

### Проблема без PRG

```
Користувач → POST /notes/new/ (створити нотатку "Shopping")
  ↓ View зберігає нотатку, повертає 200 з підтвердженням
  ↓ Браузер показує сторінку
  ↓ Користувач натискає F5 (оновити)
  ↓ Браузер ПОВТОРЮЄ POST запит ← ПРОБЛЕМА!
  ↓ Друга нотатка "Shopping" створена!

Результат: 2 однакові нотатки.
Натиснути F5 ще раз → 3 нотатки. Це "Double Submit" проблема.
```

### Рішення — PRG

```
Користувач → POST /notes/new/
  ↓ View зберігає нотатку
  ↓ View повертає 302 REDIRECT → /notes/
  ↓ Браузер GET /notes/ (автоматично слідує redirect)
  ↓ Браузер показує список нотаток
  ↓ F5 → повторює GET /notes/ (безпечно!)

Результат: лише одна нотатка. F5 = перезавантаження списку.
```

```python
# ✅ Правильно — PRG:
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return redirect('hello_app:note_list')   # ← 302, не 200!
    else:
        form = NoteForm()
    return render(request, 'hello_app/note_form.html', {'form': form})

# ❌ Неправильно — без redirect:
def note_create_bad(request):
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            return render(request, 'success.html', {'note': note})
            # ↑ Браузер залишається на POST URL
            # F5 → browser: "Повторити POST запит?" → дублікат!
```

---

## 03 · Django Messages

> Flash-повідомлення — одноразові повідомлення що зникають після одного перегляду.
> Ідеально для "Нотатку збережено" після redirect.

### Як Messages працюють

```
1. POST /notes/new/
   messages.success(request, "Нотатку збережено!")
   → повідомлення збереглося у SESSION (не в response)
   ↓
2. redirect → GET /notes/
   шаблон: {% for message in messages %}{{ message }}{% endfor %}
   → повідомлення відображається
   → SESSION очищається (використано одноразово!)
   ↓
3. F5 → GET /notes/ знову
   messages = порожній → повідомлення зникло
```

### Рівні Messages і Bootstrap класи

```python
# Django рівні → Bootstrap Alert класи
from django.contrib import messages

messages.debug(request, 'Налагоджувальне повідомлення')
messages.info(request, 'Інформаційне повідомлення')
messages.success(request, 'Нотатку успішно збережено!')
messages.warning(request, 'Нотатку видалено.')
messages.error(request, 'Помилка при збереженні.')

# MESSAGE_TAGS у settings.py:
from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',   # → alert-secondary
    messages.INFO:    'info',        # → alert-info
    messages.SUCCESS: 'success',     # → alert-success
    messages.WARNING: 'warning',     # → alert-warning
    messages.ERROR:   'danger',      # → alert-danger (Bootstrap використовує danger!)
}
```

### Messages у шаблоні

```html
{% if messages %}
    {% for message in messages %}
    <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
        <!--
            message.tags → 'success' / 'warning' / 'danger'
            alert-{{ message.tags }} → Bootstrap клас alert-success / alert-warning...
        -->
        {{ message }}
        <button type="button" class="btn-close" data-bs-dismiss="alert">
        </button>
        <!-- data-bs-dismiss="alert": Bootstrap JS закриває alert -->
    </div>
    {% endfor %}
{% endif %}
```

---

## 04 · Template Inheritance

> Один `base.html` містить Bootstrap CDN, Navbar, Footer.
> Всі інші сторінки лише заповнюють блоки.

### Як Django template engine обробляє шаблони

```
1. render(request, 'hello_app/note_list.html', context)

2. Django знаходить шаблон:
   APP_DIRS=True → шукає у hello_app/templates/hello_app/note_list.html
   (APP_DIRS шукає templates/ у кожному INSTALLED_APP)

3. Зустрічає {% extends 'base.html' %}
   → завантажує base.html
   → знаходить всі {% block name %}...{% endblock %} у base.html

4. Для кожного block:
   → якщо дочірній шаблон перевизначає → використовує дочірній вміст
   → якщо ні → використовує базовий вміст (якщо є)

5. {{ variable }} → замінює на context значення
   {% tag %} → виконує template tag
   {{ var|filter }} → застосовує filter
```

### Блоки base.html і їх призначення

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <!-- Тут ЗАВЖДИ є Bootstrap CDN -->
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>
    <!--
        block title: дочірній шаблон перевизначає:
        {% block title %}Мої нотатки{% endblock %}
        → <title>Мої нотатки</title>
    -->
    <link rel="stylesheet" href="...bootstrap.min.css">
    {% block extra_css %}{% endblock %}
    <!--
        extra_css: порожній блок — дочірній може додати CSS специфічний для сторінки
        Наприклад: <link rel="stylesheet" href="{% static 'css/editor.css' %}">
    -->
</head>
<body>
    <nav>...</nav>

    <main>
        {% block content %}{% endblock %}
        <!--
            content: ГОЛОВНИЙ блок — кожна сторінка заповнює своє
            base.html тут нічого не визначає → порожній за замовчуванням
        -->
    </main>

    <footer>...</footer>
    <script src="...bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
    <!--
        extra_js: дочірній може додати JS специфічний для сторінки
        наприклад: <script>...</script> для Leaflet карти, Chart.js тощо
    -->
</body>
</html>
```

### {{ block.super }} — успадкування вмісту блоку

```html
{# Базовий шаблон #}
{% block extra_css %}
<link rel="stylesheet" href="global-styles.css">
{% endblock %}

{# Дочірній шаблон #}
{% block extra_css %}
    {{ block.super }}  {# ← вставляє вміст з base.html #}
    <link rel="stylesheet" href="page-specific.css">
{% endblock %}

{# Результат: ОБИДВА рядки CSS, не тільки page-specific #}
```

---

## 05 · Bootstrap 5

> Bootstrap 5 — CSS framework. Класи → готові стилі без написання CSS.

### Bootstrap Grid System

```
Bootstrap Grid = 12 колонок у рядку (row)
Сумарна ширина колонок = 12 (або менше)

col-md-4 + col-md-4 + col-md-4 = 12 ✓  (3 рівні колонки)
col-md-6 + col-md-6 = 12 ✓              (2 рівні половини)
col-md-8 + col-md-4 = 12 ✓              (sidebar layout)
col-md-12 = 12 ✓                         (повна ширина)

Breakpoints:
  без суфікса → завжди (від 0px)
  sm  → ≥576px   (більший телефон)
  md  → ≥768px   (планшет)
  lg  → ≥992px   (ноутбук)
  xl  → ≥1200px  (монітор)
  xxl → ≥1400px  (великий монітор)
```

```html
<!-- Card Grid — адаптивний: 1 колонка → 2 → 3 -->
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    <!--
        row-cols-1:    мобільний   → 1 карточка в рядку
        row-cols-md-2: планшет     → 2 карточки в рядку
        row-cols-lg-3: ноутбук/PC  → 3 карточки в рядку
        g-4:           gap (відступи між карточками) = 1.5rem
    -->
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 shadow-sm">
            <!-- h-100: висота = 100% рядка (рівні картки) -->
            <!-- shadow-sm: легка тінь -->
            <div class="card-body">
                <h5 class="card-title">{{ note.title }}</h5>
                <p class="card-text text-muted">{{ note.content|truncatechars:80 }}</p>
            </div>
            <div class="card-footer">
                <!-- Дії: редагувати / видалити -->
            </div>
        </div>
    </div>
    {% endfor %}
</div>
```

### Часті Bootstrap класи

```
Відступи:
  m-{n}   → margin all sides    mt-3 → margin-top: 1rem
  p-{n}   → padding all sides   px-4 → padding-left+right: 1.5rem
  mb-4    → margin-bottom: 1.5rem
  gap-2   → gap між flex елементами

Flex:
  d-flex                  → display: flex
  justify-content-between → space-between
  align-items-center      → vertically center
  flex-grow-1             → займає весь вільний простір

Текст:
  text-muted   → gray color
  text-center  → text-align: center
  fw-bold      → font-weight: bold
  small        → font-size: 0.875em
  display-1    → великий заголовок

Колір:
  bg-dark   → background: dark
  text-white → color: white
  bg-primary → синій Bootstrap

Кнопки:
  btn btn-primary      → синя кнопка
  btn btn-outline-secondary → контурна сіра
  btn-sm               → маленька кнопка
  btn-group btn-group-sm → група кнопок

Alerts:
  alert alert-success    → зелений
  alert alert-warning    → жовтий
  alert alert-danger     → червоний
  alert-dismissible      → кнопка закрити
  fade show              → анімація появи

Utilities:
  shadow-sm     → тінь
  border-0      → no border
  rounded       → rounded corners
  h-100         → height: 100%
  min-vh-100    → min-height: 100vh
  overflow-auto → overflow: auto
```

### Sticky Footer — технічна деталь

```
Проблема: при мало контенту footer піднімається вгору, не залишається внизу.

Рішення через Flexbox:
  body {
    display: flex;         → body = flex контейнер
    flex-direction: column → вертикальна вісь
    min-height: 100vh;     → мінімум 100% висоти вікна
  }
  main {
    flex-grow: 1;          → main займає весь вільний простір між nav і footer
  }
```

```html
<body class="d-flex flex-column min-vh-100">
    <nav>...</nav>
    <main class="container my-4 flex-grow-1">...</main>
    <footer>...</footer>  ← завжди внизу!
</body>
```

---

## 06 · Template Filters і Tags

### Filters — трансформують значення

```html
{# Синтаксис: {{ variable|filter:argument }} #}

{{ note.title }}                      → "Дуже довга назва нотатки..."
{{ note.title|truncatechars:30 }}     → "Дуже довга назва нотатк..."

{{ note.content|truncatechars:100 }}  → перші 100 символів
{{ note.content|linebreaks }}         → \n → <br><p>
{{ note.content|safe }}               → не екранувати HTML (ОБЕРЕЖНО: XSS)
{{ note.content|escape }}             → екранувати HTML (за замовчуванням)

{{ note.created_at }}                 → 2026-06-13 10:00:00
{{ note.created_at|date:"d.m.Y" }}   → 13.06.2026
{{ note.created_at|date:"H:i" }}      → 10:00
{{ note.created_at|timesince }}       → 5 годин тому
{{ note.created_at|naturalday }}      → сьогодні / вчора

{{ notes|length }}                    → 42
{{ notes|first }}                     → перший елемент
{{ notes|last }}                      → останній елемент

{{ note.title|upper }}                → ВЕЛИКА НАЗВА
{{ note.title|lower }}                → маленька назва
{{ note.title|capfirst }}             → Перша буква велика

{{ note.priority|default:"не вказано" }}  → якщо None/False → дефолтне
{{ note.priority|default_if_none:"—" }}   → тільки якщо None

{% load static %}
{% static 'css/style.css' %}          → /static/css/style.css
```

### Tags — логіка у шаблоні

```html
{# Умови #}
{% if notes %}
    ...
{% elif archived_notes %}
    ...
{% else %}
    <p>Немає нотаток</p>
{% endif %}

{% if note.priority == 3 %}
    <span class="badge bg-danger">Високий</span>
{% elif note.priority == 2 %}
    <span class="badge bg-warning">Середній</span>
{% else %}
    <span class="badge bg-secondary">Низький</span>
{% endif %}

{# Цикли #}
{% for note in notes %}
    {{ forloop.counter }}       ← 1, 2, 3... (з 1)
    {{ forloop.counter0 }}      ← 0, 1, 2... (з 0)
    {{ forloop.revcounter }}    ← N, N-1... (зворотній)
    {{ forloop.first }}         ← True тільки в першій ітерації
    {{ forloop.last }}          ← True тільки в останній ітерації
    {{ note.title }}
{% empty %}
    <p>Список порожній</p>  ← якщо notes = [] або None
{% endfor %}

{# Блоки — Template Inheritance #}
{% extends 'base.html' %}
{% block content %}...{% endblock %}
{% block title %}Мої нотатки{% endblock %}

{# Включення підшаблону #}
{% include 'hello_app/_note_card.html' with note=note %}

{# URL генерація #}
{% url 'hello_app:note_detail' pk=note.pk %}

{# CSRF токен (обов'язковий у кожній POST формі) #}
{% csrf_token %}
```

---

## Крок 1 — Bootstrap залежності

```bash
pip install django-bootstrap5
```

Зареєструй у `hello_project/settings.py`:

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_bootstrap5',    # ← Bootstrap 5 для форм ({% bootstrap_form form %})
    'hello_app',
]

# Django Messages → Bootstrap Alert класи
from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',
    messages.INFO:    'info',
    messages.SUCCESS: 'success',
    messages.WARNING: 'warning',
    messages.ERROR:   'danger',
}
```

---

## Крок 2 — base.html

```
hello_app/
└── templates/
    ├── base.html           ← Тут (доступний всім apps)
    └── hello_app/
        ├── note_list.html
        └── note_form.html
```

`hello_app/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bootstrap Notes{% endblock %}</title>

    <!-- Bootstrap 5 CSS — CDN (не потрібен npm/webpack) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          crossorigin="anonymous">

    <!-- Bootstrap Icons (bi bi-pencil, bi bi-trash тощо) -->
    <link rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">

    {% block extra_css %}{% endblock %}
</head>

<!--
    Sticky Footer — тіло = flex колонка, main забирає вільний простір
    body.d-flex.flex-column.min-vh-100 + main.flex-grow-1 → footer завжди внизу
-->
<body class="bg-light d-flex flex-column min-vh-100">

    <!-- ═══════════════ NAVBAR ═══════════════ -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'hello_app:note_list' %}">
                <i class="bi bi-journal-text me-2"></i>Bootstrap Notes
            </a>

            <!-- Hamburger для мобільних -->
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse" data-bs-target="#navMenu">
                <span class="navbar-toggler-icon"></span>
            </button>

            <div class="collapse navbar-collapse" id="navMenu">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_list' %}">
                            <i class="bi bi-list-ul me-1"></i>Всі нотатки
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'hello_app:note_create' %}">
                            <i class="bi bi-plus-circle me-1"></i>Нова нотатка
                        </a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <!-- ═══════════════ MAIN ═══════════════ -->
    <main class="container my-4 flex-grow-1">

        <!-- Django Messages → Bootstrap Alerts -->
        {% if messages %}
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }} alert-dismissible fade show mb-3"
                 role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert"
                        aria-label="Закрити"></button>
            </div>
            {% endfor %}
        {% endif %}

        {% block content %}{% endblock %}

    </main>

    <!-- ═══════════════ FOOTER ═══════════════ -->
    <footer class="bg-dark text-center text-white-50 py-3 mt-auto">
        <small>Bootstrap Notes &copy; 2026</small>
    </footer>

    <!-- Bootstrap 5 JS (bundle включає Popper.js) -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
            crossorigin="anonymous" defer></script>
    {% block extra_js %}{% endblock %}

</body>
</html>
```

---

## Крок 3 — NoteForm

Створи `hello_app/forms.py`:

```python
from django import forms
from .models import Note


class NoteForm(forms.ModelForm):
    """
    ModelForm для Note.
    Django автоматично генерує поля з моделі:
      title (CharField(max_length=200)) → TextInput
      content (TextField(blank=True))   → Textarea
    """

    class Meta:
        model  = Note
        fields = ['title', 'content']
        # НЕ включаємо: created_at (auto_now_add), updated_at (auto_now)
        # Їх встановлює Django автоматично — юзер не повинен їх бачити

        widgets = {
            'title': forms.TextInput(attrs={
                'class':       'form-control',     # Bootstrap клас
                'placeholder': 'Введіть назву...',
                'autofocus':   True,               # Курсор одразу на цьому полі
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows':  6,
                'placeholder': 'Текст нотатки...',
            }),
        }
        labels = {
            'title':   'Заголовок',
            'content': 'Зміст',
        }
        help_texts = {
            'title':   'Коротка і описова назва (до 200 символів)',
            'content': 'Основний вміст нотатки. Поле необов\'язкове.',
        }

    def clean_title(self):
        """
        Кастомний validator для поля title.
        clean_<field_name>() викликається після стандартних validators.
        """
        title = self.cleaned_data.get('title', '').strip()
        if len(title) < 3:
            raise forms.ValidationError('Заголовок має бути мінімум 3 символи.')
        return title   # ← ВАЖЛИВО: повернути очищене значення!
```

### Виведення форми у шаблоні (3 способи)

```html
{# Спосіб 1 — as_p (швидко, без Bootstrap) #}
{{ form.as_p }}
{# Генерує: <p><label>...</label><input class="..."></p> #}

{# Спосіб 2 — django-bootstrap5 #}
{% load django_bootstrap5 %}
{% bootstrap_form form %}
{# Генерує: <div class="mb-3"><label class="form-label">...</label><input class="form-control">... #}

{# Спосіб 3 — вручну (повний контроль) #}
{% for field in form %}
<div class="mb-3">
    <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
        {{ field.label }}
        {% if field.field.required %}<span class="text-danger">*</span>{% endif %}
    </label>
    {{ field }}
    {% if field.help_text %}
    <div class="form-text text-muted">{{ field.help_text }}</div>
    {% endif %}
    {% for error in field.errors %}
    <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
</div>
{% endfor %}

{# Non-field помилки (from clean()) #}
{% if form.non_field_errors %}
<div class="alert alert-danger">
    {% for error in form.non_field_errors %}
    <p class="mb-0">{{ error }}</p>
    {% endfor %}
</div>
{% endif %}
```

---

## Крок 4 — CRUD views

`hello_app/views.py`:

```python
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages

from .models import Note
from .forms import NoteForm


def index(request):
    """Головна → redirect на список."""
    return redirect('hello_app:note_list')


def note_list(request):
    """Список всіх нотаток."""
    notes = Note.objects.all()              # SELECT * FROM hello_app_note
    return render(request, 'hello_app/note_list.html', {'notes': notes})


def note_detail(request, pk):
    """Деталь однієї нотатки."""
    note = get_object_or_404(Note, pk=pk)   # get() або 404
    return render(request, 'hello_app/note_detail.html', {'note': note})


def note_create(request):
    """
    GET  → порожня форма
    POST → валідація → збереження → redirect (PRG)
    """
    if request.method == 'POST':
        form = NoteForm(request.POST)
        if form.is_valid():
            note = form.save()
            messages.success(request, f'Нотатку "{note.title}" успішно створено!')
            return redirect('hello_app:note_list')
    else:
        form = NoteForm()

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'action': 'Створити',
        'title':  'Нова нотатка',
    })


def note_edit(request, pk):
    """
    GET  → форма заповнена поточними даними (instance=note)
    POST → оновлення (UPDATE, не INSERT)
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        form = NoteForm(request.POST, instance=note)
        if form.is_valid():
            form.save()
            messages.success(request, f'Нотатку "{note.title}" оновлено!')
            return redirect('hello_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(instance=note)   # Заповнити поточними даними

    return render(request, 'hello_app/note_form.html', {
        'form':   form,
        'note':   note,
        'action': 'Зберегти зміни',
        'title':  f'Редагувати: {note.title}',
    })


def note_delete(request, pk):
    """
    GET  → сторінка підтвердження
    POST → видалення → redirect (DELETE тільки через POST!)

    Чому тільки POST?
    Якщо DELETE через GET: <img src="/notes/1/delete/"> або <a href=...>
    видалить нотатку при завантаженні сторінки (CSRF атака, пошукові боти).
    POST вимагає форму з csrf_token → захищено.
    """
    note = get_object_or_404(Note, pk=pk)

    if request.method == 'POST':
        title = note.title   # Зберегти перед видаленням
        note.delete()
        messages.warning(request, f'Нотатку "{title}" видалено.')
        return redirect('hello_app:note_list')

    return render(request, 'hello_app/note_confirm_delete.html', {'note': note})
```

### get_object_or_404 — захист від KeyError / DoesNotExist

```python
# ❌ Без get_object_or_404:
note = Note.objects.get(pk=pk)   # Якщо не знайдено → DoesNotExist → 500 Internal Error

# ✅ З get_object_or_404:
note = get_object_or_404(Note, pk=pk)   # Якщо не знайдено → Http404 → 404 сторінка

# Можна фільтрувати за кількома полями:
note = get_object_or_404(Note, pk=pk, user=request.user)
# → 404 якщо нотатка або не існує, або belongs to іншого юзера
# Це захист від IDOR (Insecure Direct Object Reference)!
```

---

## Крок 5 — URL-маршрути

`hello_app/urls.py`:

```python
from django.urls import path
from . import views

app_name = 'hello_app'

urlpatterns = [
    path('',                        views.index,       name='index'),
    path('notes/',                  views.note_list,   name='note_list'),
    path('notes/new/',              views.note_create, name='note_create'),
    path('notes/<int:pk>/',         views.note_detail, name='note_detail'),
    path('notes/<int:pk>/edit/',    views.note_edit,   name='note_edit'),
    path('notes/<int:pk>/delete/',  views.note_delete, name='note_delete'),
]
```

**Важливо: порядок `notes/new/` перед `notes/<int:pk>/`**

```
'notes/new/' → не співпадає з <int:pk> бо 'new' не є int → OK
'notes/42/'  → <int:pk> → pk=42 → OK

Якщо б порядок був зворотним:
'notes/<int:pk>/' → 'new' → int('new') → ValueError → помилка!
Django перевіряє urlpatterns ЗВЕРХУ ДОНИЗУ → перший match виграє.
Конкретніші патерни — вгору!
```

`hello_project/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('hello_app.urls', namespace='hello_app')),
]
```

---

## Крок 6 — Шаблон списку

`hello_app/templates/hello_app/note_list.html`:

```html
{% extends 'base.html' %}

{% block title %}Мої нотатки{% endblock %}

{% block content %}

<!-- Заголовок з лічильником і кнопкою -->
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h2 mb-0">
        Мої нотатки
        <span class="badge bg-secondary fs-6">{{ notes|length }}</span>
    </h1>
    <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-lg me-1"></i>Нова нотатка
    </a>
</div>

{% if notes %}
    <!--
        Адаптивна сітка:
        - Мобільний: 1 колонка
        - Планшет (md): 2 колонки
        - Ноутбук (lg): 3 колонки
        g-4: відступи між картками
    -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
        {% for note in notes %}
        <div class="col">
            <div class="card h-100 shadow-sm hover-lift">

                <div class="card-body">
                    <h5 class="card-title mb-1">
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="text-decoration-none text-dark stretched-link">
                            {{ note.title }}
                        </a>
                    </h5>
                    <!--
                        stretched-link: весь .card стає кліковим
                        (position:relative на card + ::after на link)
                    -->

                    <p class="card-text text-muted small mt-2">
                        {{ note.content|truncatechars:120 }}
                        <!--
                            truncatechars:120 → обрізає до 120 символів
                            і додає "..." якщо довше
                        -->
                    </p>
                </div>

                <div class="card-footer bg-transparent d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="bi bi-clock me-1"></i>
                        {{ note.created_at|timesince }} тому
                    </small>
                    <!--
                        timesince: "2 години", "5 днів", "1 місяць"
                        Відносний час — завжди актуальний без оновлення
                    -->

                    <div class="btn-group btn-group-sm position-relative z-1">
                        <!-- z-1: вище за stretched-link → кнопки кліковні -->
                        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
                           class="btn btn-outline-secondary"
                           title="Редагувати">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
                           class="btn btn-outline-danger"
                           title="Видалити">
                            <i class="bi bi-trash"></i>
                        </a>
                    </div>
                </div>

            </div>
        </div>
        {% endfor %}
    </div>

{% else %}
    <!-- Empty state — коли нотаток немає -->
    <div class="text-center py-5">
        <i class="bi bi-journal-x display-1 text-muted d-block mb-3"></i>
        <h4 class="text-muted">Ще немає нотаток</h4>
        <p class="text-muted">Створи першу нотатку і вона з'явиться тут.</p>
        <a href="{% url 'hello_app:note_create' %}" class="btn btn-primary mt-2">
            <i class="bi bi-plus-lg me-1"></i>Створити першу нотатку
        </a>
    </div>
{% endif %}

{% endblock %}
```

---

## Крок 7 — Шаблон форми

`hello_app/templates/hello_app/note_form.html`:

```html
{% extends 'base.html' %}

{% block title %}{{ title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-8 col-lg-6">
        <div class="card shadow-sm">

            <div class="card-header bg-white border-bottom">
                <h1 class="h4 mb-0">
                    <i class="bi bi-journal-plus me-2"></i>{{ title }}
                </h1>
            </div>

            <div class="card-body">
                <form method="post" novalidate>
                    <!--
                        novalidate: вимикає браузерну HTML5 валідацію
                        → Django робить валідацію на сервері (надійніше)
                        → Браузерна валідація обходиться curl/Postman
                    -->
                    {% csrf_token %}
                    <!--
                        csrf_token: ОБОВ'ЯЗКОВО для кожної POST форми!
                        Django генерує: <input type="hidden" name="csrfmiddlewaretoken" value="...">
                        Без нього: 403 Forbidden від CsrfViewMiddleware
                    -->

                    {% for field in form %}
                    <div class="mb-3">
                        <label for="{{ field.id_for_label }}" class="form-label fw-semibold">
                            {{ field.label }}
                            {% if field.field.required %}
                            <span class="text-danger" title="Обов'язкове поле">*</span>
                            {% endif %}
                        </label>
                        {{ field }}
                        {#
                            field.widget вже має class="form-control" (з forms.py widgets)
                            → {{ field }} генерує <input class="form-control"> або <textarea ...>
                        #}

                        {% if field.help_text %}
                        <div class="form-text text-muted">{{ field.help_text }}</div>
                        {% endif %}

                        {% for error in field.errors %}
                        <div class="invalid-feedback d-block">
                            <i class="bi bi-exclamation-circle me-1"></i>{{ error }}
                        </div>
                        {% endfor %}
                    </div>
                    {% endfor %}

                    <div class="d-flex gap-2 mt-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-check-lg me-1"></i>{{ action }}
                        </button>
                        <a href="{% url 'hello_app:note_list' %}"
                           class="btn btn-outline-secondary">
                            <i class="bi bi-x-lg me-1"></i>Скасувати
                        </a>
                    </div>

                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

---

## Крок 8 — Шаблон видалення

`hello_app/templates/hello_app/note_confirm_delete.html`:

```html
{% extends 'base.html' %}

{% block title %}Видалити: {{ note.title }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-12 col-md-6 col-lg-5">
        <div class="card border-danger shadow-sm">

            <div class="card-header bg-danger text-white">
                <h1 class="h4 mb-0">
                    <i class="bi bi-exclamation-triangle me-2"></i>Видалити нотатку
                </h1>
            </div>

            <div class="card-body">
                <p class="mb-1">
                    Ви дійсно хочете видалити нотатку
                    <strong>«{{ note.title }}»</strong>?
                </p>
                <p class="text-muted small mb-3">Ця дія незворотна.</p>

                <form method="post">
                    <!--
                        DELETE через POST (не GET):
                        Якщо GET: <img src="/notes/1/delete/"> видалить нотатку при завантаженні
                        POST + csrf_token: захист від CSRF/ненавмисного видалення
                    -->
                    {% csrf_token %}
                    <div class="d-flex gap-2">
                        <button type="submit" class="btn btn-danger">
                            <i class="bi bi-trash me-1"></i>Так, видалити
                        </button>
                        <a href="{% url 'hello_app:note_detail' pk=note.pk %}"
                           class="btn btn-outline-secondary">
                            Скасувати
                        </a>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
{% endblock %}
```

---

## Крок 9 — Шаблон деталі

`hello_app/templates/hello_app/note_detail.html`:

```html
{% extends 'base.html' %}

{% block title %}{{ note.title }}{% endblock %}

{% block content %}

<div class="d-flex justify-content-between align-items-start mb-3">
    <div>
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item">
                    <a href="{% url 'hello_app:note_list' %}">Нотатки</a>
                </li>
                <li class="breadcrumb-item active">{{ note.title|truncatechars:40 }}</li>
            </ol>
        </nav>
        <h1 class="h2">{{ note.title }}</h1>
        <small class="text-muted">
            <i class="bi bi-calendar me-1"></i>
            Створено: {{ note.created_at|date:"d.m.Y о H:i" }}
            {% if note.updated_at != note.created_at %}
            · Оновлено: {{ note.updated_at|timesince }} тому
            {% endif %}
        </small>
    </div>

    <div class="btn-group">
        <a href="{% url 'hello_app:note_edit' pk=note.pk %}"
           class="btn btn-outline-primary">
            <i class="bi bi-pencil me-1"></i>Редагувати
        </a>
        <a href="{% url 'hello_app:note_delete' pk=note.pk %}"
           class="btn btn-outline-danger">
            <i class="bi bi-trash me-1"></i>Видалити
        </a>
    </div>
</div>

<div class="card shadow-sm">
    <div class="card-body">
        {% if note.content %}
            <p class="card-text" style="white-space: pre-wrap;">{{ note.content }}</p>
            <!--
                white-space: pre-wrap: зберігає переноси рядків з TextField
                Без цього \n → пробіл у HTML
                Альтернатива: {{ note.content|linebreaks }}
            -->
        {% else %}
            <p class="text-muted fst-italic">Нотатка без вмісту.</p>
        {% endif %}
    </div>
</div>

{% endblock %}
```

---

## Як все пов'язано — повний цикл

```
CRUD операції і HTTP методи:
─────────────────────────────────────────────────────────────────────────
CREATE:  GET  /notes/new/     → note_create view → порожня форма
         POST /notes/new/     → form.save() → redirect → flash message
         GET  /notes/         → список з новою нотаткою + flash message

READ:    GET  /notes/         → note_list view → QuerySet → шаблон
         GET  /notes/42/      → note_detail view → get_object_or_404 → шаблон

UPDATE:  GET  /notes/42/edit/ → note_edit view → форма з instance=note
         POST /notes/42/edit/ → form.save(instance) → UPDATE → redirect

DELETE:  GET  /notes/42/del/  → note_delete view → підтвердження
         POST /notes/42/del/  → note.delete() → redirect → flash message
─────────────────────────────────────────────────────────────────────────
```

---

## Часті помилки

| Помилка | Причина | Рішення |
|---------|---------|---------|
| `NoReverseMatch: 'note_list'` | Не вказано namespace | `{% url 'hello_app:note_list' %}` |
| `403 Forbidden` у POST | `{% csrf_token %}` відсутній | Додай у `<form>` |
| `TemplateSyntaxError: Invalid block tag 'url'` | Помилка в URL тезі | Перевір назву і namespace |
| Форма не валідується але немає помилок | `novalidate` без server validation | Перевір `form.errors` у view з `print(form.errors)` |
| Дублікат після F5 | Немає redirect після POST | PRG: завжди `return redirect(...)` після `form.save()` |
| Кнопки не кліковні через stretched-link | z-index | Додай `position-relative z-1` на btn-group |
| `TemplateDoesNotExist: base.html` | Неправильний шлях | `APP_DIRS=True` + `templates/base.html` у встановленому app |

---

## Практичне завдання

1. Запусти проєкт, відкрий `/notes/` — переконайся що сторінка оформлена Bootstrap.
2. Створи 3 нотатки через форму `/notes/new/`. Перевір Flash-повідомлення.
3. Відредагуй одну нотатку. Перевір що це `UPDATE` (не дублікат).
4. Видали нотатку — переконайся що сторінка підтвердження показується.
5. Додай поле `priority` (choices: 1=Низький, 2=Середній, 3=Високий) до моделі, форми і деталі.
6. У `note_list.html` покажи Badge з пріоритетом на кожній картці.

---

## Чеклист самоперевірки

- [ ] `base.html` → `note_list.html` / `note_form.html`: Template Inheritance через `{% extends %}`
- [ ] Bootstrap CSS підключений через CDN у `base.html`
- [ ] Flash-повідомлення відображаються після POST і зникають після F5
- [ ] `{% csrf_token %}` є у кожній POST формі
- [ ] `redirect()` після `form.save()` (PRG-паттерн)
- [ ] `get_object_or_404` замість `objects.get()` — 404 а не 500
- [ ] Sticky Footer: `body.d-flex.flex-column.min-vh-100` + `main.flex-grow-1`
- [ ] Card Grid адаптивний: 1/2/3 колонки залежно від ширини екрану

---

## Далі

Наступний крок: [03 — Domain Design та архітектура](03_crud.md) — domain-driven проектування, N+1 проблема, selectors/services шари.

Модулі документації:
- [Frontend and Templates](../05_frontend_and_templates/README.md)
- [Forms and Validation](../04_forms_and_validation/README.md)
