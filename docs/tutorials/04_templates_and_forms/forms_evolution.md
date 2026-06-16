# Forms Evolution

> Три рівні еволюції форм — від "просто працює" до "красиво і без дублювання".
> Один і той самий `NoteForm` рендериться по-різному залежно від підходу.
> Різниця тільки у шарі **presentation** — бізнес-логіка (`services.create_note()`) не змінюється.

---

## Навіщо вчити три рівні

Django форми вирішують **дві незалежні задачі**:

1. **Валідація вводу** — перевірити що `title` не пустий, `priority` в допустимому діапазоні
2. **Рендеринг HTML** — відобразити поля, мітки, помилки у браузері

Три Tier відрізняються тільки у рендерингу (пункт 2). Валідація (`is_valid()`, `cleaned_data`) однакова у всіх трьох.

| Tier | Метод | Рядків HTML | Де Bootstrap-класи |
|------|-------|------------|--------------------|
| **1 — Raw** | `{{ form.as_p }}` | ~5 | Ніде (немає стилів) |
| **2 — Manual** | Ручний HTML | ~80 | У шаблоні вручну |
| **3 — Crispy** | `{% crispy form %}` | **1** | У `forms.py` через Layout |

Всі три підходи передають **ту саму** `NoteForm`. Різниця — тільки спосіб рендерингу.

---

## Форма як Python-клас: анатомія NoteForm

Перш ніж розбирати рівні — зрозумій що таке `NoteForm`.

```python
# notes_app/forms.py
from django import forms
from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

        # Meta.widgets — налаштовуємо HTML-атрибути полів.
        # Це стосується Tier 2. Для Tier 3 (Crispy) — аналогічно але через Layout.
        widgets = {
            'title': forms.TextInput(attrs={
                'class': 'form-control',      # Bootstrap: рамка, padding, focus-ring
                'placeholder': 'Назва нотатки...',
                'autofocus': True,            # браузер фокусує це поле автоматично
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 8,                    # висота textarea у рядках
            }),
            'priority': forms.Select(attrs={
                'class': 'form-select',       # Bootstrap: стиль для <select>
            }),
            'notebook': forms.Select(attrs={
                'class': 'form-select',
            }),
            'is_pinned': forms.CheckboxInput(attrs={
                'class': 'form-check-input',  # Bootstrap: стиль checkbox
            }),
        }

        labels = {
            'title':    'Заголовок',
            'content':  'Текст нотатки',
            'priority': 'Пріоритет',
            'notebook': 'Записник',
            'tags':     'Теги',
            'is_pinned': 'Закріпити',
        }

        help_texts = {
            'notebook': 'Залиш порожнім — нотатка буде без записника.',
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        # Фільтруємо choices по user — щоб Alice не бачила записники Bob'а
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
```

**Ключові компоненти:**

| Компонент | Роль |
|-----------|------|
| `Meta.model` | Яка модель Django — звідси беруться поля, типи, валідатори |
| `Meta.fields` | Які поля включити у форму (порядок має значення) |
| `Meta.widgets` | Як рендерити HTML — клас, placeholder, атрибути |
| `Meta.labels` | Текст `<label>` для кожного поля |
| `Meta.help_texts` | Підказка під полем (`<div class="form-text">`) |
| `__init__(user=)` | Кастомна фільтрація queryset по поточному юзеру |

---

## Tier 1: Raw Django — `{{ form.as_p }}`

> **Навіщо:** Найшвидший спосіб відобразити форму. Корисний для debug і прототипів. Валідація повністю працює — тільки вигляд мінімальний.

```python
# views.py
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect
from . import forms, services


@login_required
def note_create_raw(request):
    if request.method == 'POST':
        form = forms.NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', 2),
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.pk for t in form.cleaned_data.get('tags', [])],
                is_pinned=form.cleaned_data.get('is_pinned', False),
            )
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = forms.NoteForm(user=request.user)

    return render(request, 'notes_app/note_form_raw.html', {'form': form})
```

```html
<!-- templates/notes_app/note_form_raw.html -->
{% extends 'base.html' %}
{% block content %}

<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit" class="btn btn-primary">Зберегти</button>
</form>

{% endblock %}
```

**Що `as_p` генерує для поля `title`:**

```html
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" maxlength="200" required id="id_title">
</p>
```

Зверни увагу: **жодного** `class="form-control"`. Жодних Bootstrap-стилів. Форма виглядає як голий HTML. Валідація Django **повністю працює** — `is_valid()`, `cleaned_data`, помилки — але відображаються також без стилів:

```html
<!-- При помилці валідації as_p додає ErrorList перед полем: -->
<ul class="errorlist">
  <li>Це поле обов'язкове.</li>
</ul>
<p>
  <label for="id_title">Заголовок:</label>
  <input type="text" name="title" ...>
</p>
```

**Коли використовувати Tier 1:**
- Debug і тестування форми
- Адміністративні внутрішні інструменти де зовнішній вигляд неважливий
- **Ніколи** у production для кінцевих користувачів

---

## Tier 2: Manual Bootstrap HTML

> **Навіщо:** Повний контроль над HTML-розміткою. Дозволяє розмістити поля у Bootstrap Grid, додати іконки, кастомні hints. Дорого у підтримці — кожне нове поле = вручну дописати у шаблон.

### forms.py — Widget attrs для Tier 2

Django рендерить поле через свій `Widget`. Щоб додати Bootstrap-клас до `<input>`, потрібно передати його через `widget.attrs`:

```python
# Підхід 1: через Meta.widgets (статичні атрибути)
class Meta:
    widgets = {
        'title': forms.TextInput(attrs={'class': 'form-control'}),
    }

# Підхід 2: через __init__ (динамічні атрибути)
def __init__(self, *args, **kwargs):
    super().__init__(*args, **kwargs)
    self.fields['title'].widget.attrs.update({'class': 'form-control'})
```

Обидва підходи дають однаковий результат. Підхід через `Meta.widgets` чистіший для статичних атрибутів. `__init__` потрібен коли атрибут залежить від runtime-даних.

| Bootstrap клас | HTML елемент | Ефект |
|----------------|-------------|-------|
| `form-control` | `<input>`, `<textarea>` | Повна ширина, рамка, padding, focus-ring |
| `form-select` | `<select>` | Стрілочка dropdown, padding, рамка |
| `form-check-input` | `<input type="checkbox">` | Кастомний стиль чекбоксу |

### Анатомія BoundField у шаблоні

`form.title` у шаблоні — це `BoundField`: об'єкт що знає поле + поточне значення + форму.

| Вираз | Тип | Приклад значення |
|-------|-----|-----------------|
| `{{ form.title }}` | str (HTML) | `<input type="text" name="title" class="form-control" ...>` |
| `{{ form.title.id_for_label }}` | str | `'id_title'` |
| `{{ form.title.label }}` | str | `'Заголовок'` |
| `{{ form.title.help_text }}` | str | `'Залиш порожнім...'` |
| `{{ form.title.html_name }}` | str | `'title'` |
| `{{ form.title.errors }}` | ErrorList | `['Це поле обов'язкове.']` |
| `{% if form.title.errors %}` | bool | `True` / `False` |
| `form.title.value()` | str | `'Назва нотатки'` |

### Повний шаблон одного поля

```html
<!-- templates/notes_app/note_form.html — рендеринг поля title вручну -->

<div class="mb-3">
    <!--
      .id_for_label → 'id_title'
      Клік на <label for="id_title"> фокусує <input id="id_title"> — стандартна HTML поведінка
    -->
    <label for="{{ form.title.id_for_label }}" class="form-label fw-semibold">
        {{ form.title.label }}
        {% if form.title.field.required %}
            <span class="text-danger ms-1">*</span>
        {% endif %}
    </label>

    <!--
      {{ form.title }} → Widget.render() → повний HTML-тег <input>
      Атрибути (class, placeholder, autofocus) беруться з Meta.widgets
    -->
    {{ form.title }}

    <!--
      help_text — підказка під полем. Є тільки якщо задано у Meta.help_texts.
      Для title не задано — блок не показується.
    -->
    {% if form.title.help_text %}
    <div class="form-text text-muted">{{ form.title.help_text }}</div>
    {% endif %}

    <!--
      Помилки валідації. Порожній при GET. Заповнюється якщо POST + is_valid() = False.
      Bootstrap: is-invalid + invalid-feedback показує червону рамку і текст помилки.
    -->
    {% if form.title.errors %}
    {% for error in form.title.errors %}
    <div class="invalid-feedback d-block">{{ error }}</div>
    {% endfor %}
    {% endif %}
</div>
```

### Bootstrap Grid у формі

Bootstrap Grid дозволяє розмістити кілька полів в один рядок:

```html
<!--
  row + col-6 + col-6 = 12 колонок Bootstrap Grid.
  g-3 = gutter (відступи між колонками).
  Поля priority і notebook — поруч в одному рядку.
-->
<div class="row g-3 mb-3">

    <div class="col-6">
        <label for="{{ form.priority.id_for_label }}" class="form-label">
            {{ form.priority.label }}
        </label>
        {{ form.priority }}
        {% if form.priority.errors %}
        <div class="invalid-feedback d-block">{{ form.priority.errors|join:", " }}</div>
        {% endif %}
    </div>

    <div class="col-6">
        <label for="{{ form.notebook.id_for_label }}" class="form-label">
            {{ form.notebook.label }}
        </label>
        {{ form.notebook }}
        {% if form.notebook.help_text %}
        <div class="form-text">{{ form.notebook.help_text }}</div>
        {% endif %}
        {% if form.notebook.errors %}
        <div class="invalid-feedback d-block">{{ form.notebook.errors|join:", " }}</div>
        {% endif %}
    </div>

</div>
```

### Навіщо `novalidate` на `<form>`

```html
<form method="post" novalidate>
    {% csrf_token %}
    <!-- поля форми -->
</form>
```

`novalidate` **вимикає браузерну HTML5 валідацію** (`required`, `minlength`, `type="email"`).

**Чому це правильно для Django:**
- Браузерна валідація виглядає по-різному у Chrome, Firefox, Safari — немає єдиного стилю
- Вона не знає про Django-специфічні правила (`clean_title()`, кастомні валідатори)
- Django валідує на сервері: завжди однаково, з вашими повідомленнями про помилки
- Після POST з помилками → шаблон рендериться знову з `form.errors` → єдиний стиль помилок

**`{% csrf_token %}`** вставляє прихований input:
```html
<input type="hidden" name="csrfmiddlewaretoken" value="abc123XYZ...">
```
Django відхиляє POST без цього токена з `403 Forbidden`. Захист від Cross-Site Request Forgery.

### Підрахунок рядків шаблону для 5 полів

```
title:     14 рядків
priority:  12 рядків (select)
notebook:  14 рядків (select + queryset)
content:   12 рядків (textarea)
tags:      14 рядків (multiple select / checkbox group)
is_pinned: 10 рядків (checkbox)
buttons:    3 рядки
─────────────────
ВСЬОГО:   ~80 рядків HTML тільки для форми
```

**Проблеми Tier 2:**
- 80 рядків HTML тільки для одної форми
- При додаванні поля у `models.py` → вручну дописати у кожен шаблон форми
- При зміні Bootstrap-версії → правити кожен шаблон
- 10 форм у застосунку = 800 рядків дублювання

---

## Tier 3: Crispy Forms — `{% crispy form %}`

> **Навіщо:** Crispy переносить всю Bootstrap-розмітку з шаблонів у `forms.py`. Шаблон стає одним рядком. При додаванні поля — правиш тільки `Layout` у `forms.py`, шаблон не змінюється.

### Встановлення

```bash
# requirements.txt
django-crispy-forms==2.3
crispy-bootstrap5==2024.10
```

```python
# settings.py
INSTALLED_APPS = [
    ...
    'crispy_forms',
    'crispy_bootstrap5',
]

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'
```

### forms.py з FormHelper і Layout

```python
# notes_app/forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Row, Column, Fieldset, Submit, Field

from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Фільтрація queryset — незалежно від Tier
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)

        # FormHelper — описує HTML-обгортку і Layout
        self.helper = FormHelper()
        self.helper.form_method = 'post'        # <form method="post">
        self.helper.form_novalidate = True      # novalidate атрибут

        self.helper.layout = Layout(
            # Fieldset = <fieldset><legend>Текст</legend>...</fieldset>
            Fieldset('Основна інформація',
                # Field() — рендерить поле з додатковими HTML-атрибутами
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                # Row + Column = Bootstrap Grid
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
            ),
            Fieldset('Вміст',
                Field('content', rows=8),
                'tags',         # просто назва поля — рендерить з дефолтними атрибутами
                'is_pinned',
            ),
            # Submit = кнопка відправки форми
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary'),
        )
```

### Шаблон — один рядок

```html
<!-- templates/notes_app/note_form.html -->
{% extends 'base.html' %}
{% load crispy_forms_tags %}

{% block content %}
{% crispy form %}
{% endblock %}
```

**Що `{% crispy form %}` генерує автоматично:**

- `<form method="post" novalidate>` + `{% csrf_token %}`
- `<fieldset><legend>` для кожного `Fieldset`
- `<div class="row">` + `<div class="col-md-4">` для `Row` + `Column`
- `<div class="mb-3">` для кожного поля
- `<label class="form-label">` з required-зірочкою
- `<input class="form-control">` або `<select class="form-select">`
- `<div class="invalid-feedback">` для помилок
- `<div class="form-text">` для `help_text`
- `<button type="submit" class="btn btn-primary">`

### Порівняння views.py для всіх трьох Tier

```python
# views.py — VIEW ОДНАКОВА для всіх трьох Tier!
# Crispy — це виключно рівень PRESENTATION, не бізнес-логіки.

@login_required
def note_create(request):
    if request.method == 'POST':
        form = NoteForm(request.POST, user=request.user)
        if form.is_valid():
            note = services.create_note(
                user=request.user,
                title=form.cleaned_data['title'],
                content=form.cleaned_data.get('content', ''),
                priority=form.cleaned_data.get('priority', 2),
                notebook=form.cleaned_data.get('notebook'),
                tag_ids=[t.pk for t in form.cleaned_data.get('tags', [])],
                is_pinned=form.cleaned_data.get('is_pinned', False),
            )
            messages.success(request, f'Нотатку "{note.title}" створено!')
            return redirect('notes_app:note_detail', pk=note.pk)
    else:
        form = NoteForm(user=request.user)

    return render(request, 'notes_app/note_form.html', {'form': form})
```

View однаковий для Tier 1, 2 і 3. Crispy не змінює бізнес-логіку. Він змінює тільки те як форма **виглядає**.

---

## Debuging: чому форма не валідується

### Симптом 1: POST завжди показує форму знову (ніколи немає redirect)

```python
# ❌ ПРИЧИНА — `is_valid()` повертає False, але ти не виводиш помилки
if form.is_valid():
    ...  # ← до сюди ніколи не доходить

# Швидка діагностика — додай print у view (тимчасово):
print("POST data:", request.POST)
print("Form errors:", form.errors)
```

Запусти view, отримай POST з браузера, перевір `form.errors` у console Django:

```
Form errors: {
    'title': ['Це поле обов'язкове.'],
    'notebook': ['Виберіть правильний варіант. Цього варіанту немає серед доступних.']
}
```

### Симптом 2: `notebook` або `tags` завжди "Виберіть правильний варіант"

```python
# ❌ ПРИЧИНА — передано queryset від іншого user'а
class NoteForm(forms.ModelForm):
    # Без __init__ → queryset = Tag.objects.all()
    # Bob бачить теги Alice, і навпаки!
    pass

# ✅ РІШЕННЯ — фільтруй у __init__
def __init__(self, *args, user=None, **kwargs):
    super().__init__(*args, **kwargs)
    if user is not None:
        self.fields['tags'].queryset = Tag.objects.filter(user=user)

# ✅ ПЕРЕДАЙ user у view при instantiation:
form = NoteForm(request.POST, user=request.user)
#               ↑ data        ↑ кастомний параметр
```

Якщо не передати `user` при ініціалізації форми — queryset залишиться `Tag.objects.all()`. Validation перевірить що pk тегу є у queryset — і якщо Alice передає pk тегу що є в `all()` але не в `filter(user=alice)` — валідація пройде! А якщо передає тег що є тільки у неї — all() теж містить його. Тому: **завжди фільтруй queryset по user**.

### Симптом 3: CSRF 403 Forbidden

```
Forbidden (403)
CSRF verification failed. Request aborted.
```

**Причина:** шаблон не містить `{% csrf_token %}`.

```html
<!-- ✅ ОБОВ'ЯЗКОВО в кожній формі з method="post" -->
<form method="post">
    {% csrf_token %}
    {{ form.as_p }}
</form>
```

Для Crispy: `{% crispy form %}` автоматично додає CSRF токен.

### Симптом 4: `field.queryset has no attribute` при GET

```
AttributeError: 'NoneType' object has no attribute 'filter'
```

```python
# ❌ ПРИЧИНА — user=None у __init__
form = NoteForm(user=None)

# __init__ перевіряє if user is not None:
def __init__(self, *args, user=None, **kwargs):
    super().__init__(*args, **kwargs)
    if user is not None:           # ← захист від None
        self.fields['tags'].queryset = Tag.objects.filter(user=user)

# ✅ Для аутентифікованих view — завжди є request.user:
form = NoteForm(user=request.user)
```

### Перевірити форму в Django shell

```bash
docker compose run --rm web python manage.py shell
```

```python
from django.contrib.auth.models import User
from notes_app.forms import NoteForm

user = User.objects.get(username='demo_alice')

# Симулюємо GET (порожня форма)
form = NoteForm(user=user)
print(form.fields['tags'].queryset)   # → QuerySet[Tag] тільки для alice

# Симулюємо POST з невалідними даними
data = {'title': '', 'priority': '2'}  # title порожній
form = NoteForm(data, user=user)
print(form.is_valid())   # → False
print(form.errors)       # → {'title': ['Це поле обов'язкове.']}

# Симулюємо валідний POST
data = {'title': 'Тестова нотатка', 'priority': '2', 'tags': []}
form = NoteForm(data, user=user)
print(form.is_valid())          # → True
print(form.cleaned_data)        # → {'title': 'Тестова нотатка', 'priority': 2, ...}
```

---

## Типові помилки

| Помилка | Симптом | Рішення |
|---------|---------|---------|
| Немає `{% csrf_token %}` | `403 Forbidden` на POST | Додати `{% csrf_token %}` всередину `<form>` |
| Не передано `user=` | choices включають чужі об'єкти | `NoteForm(request.POST, user=request.user)` |
| `method="get"` замість `"post"` | Дані у URL, форма не опрацьовується | `<form method="post">` |
| `if request.method == 'GET':` замість `'POST':` | Форма ніколи не обробляється | Перевірити умову в view |
| CRISPY_TEMPLATE_PACK не встановлено | `TemplateDoesNotExist: bootstrap5/uni_form.html` | Додати `CRISPY_TEMPLATE_PACK = 'bootstrap5'` у settings.py |
| Забули `{% load crispy_forms_tags %}` | `Invalid block tag: 'crispy'` | Додати `{% load %}` у шаблон |

---

## У книзі

- [Частина IV. Форми і валідація](../../04_forms_and_validation/README.md) — `ModelForm`, `clean_*` методи, кастомні валідатори, `ValidationError`, форми для M:N полів
- [Частина V. Frontend і шаблони](../../05_frontend_and_templates/README.md) — Bootstrap Grid, template tags, `{% load %}`, filters

---

## Офіційна документація

- [Django: Forms](https://docs.djangoproject.com/en/5.2/topics/forms/) — повний цикл форми
- [Django: ModelForm](https://docs.djangoproject.com/en/5.2/topics/forms/modelforms/) — `Meta.widgets`, `Meta.labels`, `__init__`
- [Django: BoundField](https://docs.djangoproject.com/en/5.2/ref/forms/api/#django.forms.BoundField) — всі атрибути що доступні у шаблоні
- [Django: CSRF](https://docs.djangoproject.com/en/5.2/ref/csrf/) — як працює CSRF захист
- [django-crispy-forms: docs](https://django-crispy-forms.readthedocs.io/en/latest/) — FormHelper, Layout, Field, Row, Column
- [crispy-bootstrap5: docs](https://crispy-bootstrap5.readthedocs.io/en/latest/) — пакет Bootstrap 5 для crispy-forms
- [Bootstrap: Forms](https://getbootstrap.com/docs/5.3/forms/overview/) — `form-control`, `form-select`, `form-check`, `invalid-feedback`
