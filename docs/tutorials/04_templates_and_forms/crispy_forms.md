# Crispy Forms

> **FormHelper** — об'єкт, прикріплений до форми, що описує:
> - Атрибути `<form>` тегу (method, action, id, class)
> - Поведінку рендерингу
> - Layout — структуру та порядок полів

---

## Архітектура FormHelper

```
NoteForm
│
├── fields (Django стандарт)
│   ├── title     CharField
│   ├── content   TextField
│   └── ...
│
└── helper = FormHelper()          ← crispy додає сюди
    ├── form_method = 'post'       ← <form method="post">
    ├── form_id = 'note-form'      ← <form id="note-form">
    ├── form_tag = True            ← рендерити <form>...</form>
    └── layout = Layout(...)       ← структура полів
        ├── Fieldset(...)          ← <fieldset><legend>
        │   ├── Field('title')     ← окреме поле з attrs
        │   └── Row(...)           ← <div class="row">
        │       ├── Column(...)    ← <div class="col-md-4">
        │       └── Column(...)    ← <div class="col-md-8">
        ├── Submit(...)            ← <button type="submit">
        └── HTML('<hr>')           ← довільний HTML
```

---

## Конвеєр рендерингу

```
{% crispy form %}
     │
     ▼
crispy_forms templatetag
     │  Знаходить form.helper
     │  Знаходить form.helper.layout
     ▼
Layout.render(form, context)
     │
     ├── Fieldset.render()
     │   ├── Field('title').render()  → field.html template
     │   └── Row.render()
     │       └── Column.render()
     ├── Submit.render()              → baseinput.html template
     └── HTML.render()               → direct string
     │
     ▼
Bootstrap 5 HTML
(form-control, mb-3, row, col-md-4, invalid-feedback...)
```

---

## Атрибути Layout об'єктів

```python
# kwargs → HTML атрибути
Field('title', placeholder='Підказка')   # placeholder="Підказка"
Field('title', autofocus=True)           # autofocus
Field('title', data_custom="val")        # data-custom="val" (підкреслення → дефіс)
Field('title', css_class="extra")        # додатковий CSS клас
Field('title', type="hidden")            # прихований input

# Обгортаючий div
Field('title', wrapper_class="mt-3")     # клас для <div class="mb-3 mt-3">
```

---

## Де crispy vs де ручний HTML — правило

| Ситуація | Підхід |
|----------|--------|
| Форма займає цілу сторінку | `{% crispy form %}` — повний контроль через Layout |
| Швидкий прототип | `{{ form\|crispy }}` — без FormHelper, просто Bootstrap-стилі |
| Одне поле вбудоване в сторінку | `{{ form.title\|as_crispy_field }}` |
| Форма без Bootstrap (API, email) | `{{ form.as_p }}` або `form.cleaned_data` напряму |

---

## Повний код `NoteForm` з FormHelper і Layout

```python
# hello_app/forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import (
    Layout, Submit, Row, Column,
    Fieldset, HTML, Div, Field
)
from .models import Note, Notebook, Tag


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'is_pinned']
        # ↑ НІ ЖОДНИХ widget attrs — crispy додає Bootstrap-класи автоматично!

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        # Security: фільтруємо FK по поточному user
        if user is not None:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
            self.fields['notebook'].empty_label = '— без записника —'

        # FormHelper — описуємо форму Python-кодом
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.form_id = 'note-form'

        # Layout — структура полів
        self.helper.layout = Layout(
            # Секція 1: основна інформація
            Fieldset('Основна інформація',
                Field('title', placeholder='Назва нотатки...', autofocus=True),
                Row(
                    Column('priority', css_class='col-md-4'),
                    Column('notebook', css_class='col-md-8'),
                ),
            ),
            # Секція 2: зміст
            Fieldset('Зміст нотатки',
                Field('content', rows=8, placeholder='Текст нотатки...'),
            ),
            # Секція 3: теги та опції
            Fieldset('Теги та параметри',
                'tags',
                Div(Field('is_pinned'), css_class='form-check mt-2'),
            ),
            # Розділювач
            HTML('<hr class="my-4">'),
            # Кнопки
            Submit('submit', 'Зберегти нотатку', css_class='btn btn-primary me-2'),
            HTML('<a href="javascript:history.back()" class="btn btn-outline-secondary">Скасувати</a>'),
        )
```

---

## `{% crispy form %}` покроковий розбір

```
1. {% load crispy_forms_tags %} — реєструє тег

2. {% crispy form %} — викликає do_uni_form() в crispy_forms_tags.py

3. Знаходить form.helper — наш FormHelper з Layout

4. Рендерить form.helper.layout:
   ├── Fieldset('Основна інформація', ...) →
   │     <fieldset>
   │       <legend>Основна інформація</legend>
   │       ...поля...
   │     </fieldset>
   │
   ├── Field('title', placeholder='...') →
   │     <div class="mb-3">
   │       <label for="id_title" class="form-label">Заголовок *</label>
   │       <input type="text" name="title" id="id_title"
   │              class="form-control" placeholder="Назва нотатки..."
   │              autofocus>
   │     </div>
   │
   ├── Row(Column('priority', css_class='col-md-4'), ...) →
   │     <div class="row">
   │       <div class="col-md-4">...priority field...</div>
   │       <div class="col-md-8">...notebook field...</div>
   │     </div>
   │
   └── Submit('submit', 'Зберегти') →
         <input type="submit" value="Зберегти" class="btn btn-primary me-2">

5. Додає <form method="post"> та {% csrf_token %} автоматично
```

### Шаблон з `{% crispy form %}`

```html
{% extends 'layouts/dashboard.html' %}
{% load crispy_forms_tags %}

{% block topbar_title %}{{ title }}{% endblock %}

{% block content %}
<div class="row">
  <div class="col-lg-8">
    <div class="card shadow-sm">
      <div class="card-header bg-primary text-white">
        <h6 class="mb-0"><i class="bi bi-journal-plus me-2"></i>{{ title }}</h6>
      </div>
      <div class="card-body">

        {% crispy form %}

        {# ↑ Один тег замість 80 рядків HTML.
           FormHelper + Layout у forms.py описують ВСЮ Bootstrap-розмітку. #}

      </div>
    </div>
  </div>
</div>
{% endblock %}
```

---

## Патерн `form_tag = False` — вбудовані форми

Іноді форма є **частиною більшої сторінки**, а не окремою сторінкою.
Наприклад: список завдань + inline-форма для додавання нового завдання на тій самій сторінці.

**Проблема:** якщо у шаблоні вже є `<form action="/todo/5/items/add/">`, а crispy теж рендерить
`<form>` — виходить nested `<form>` — **невалідний HTML**, браузери ігнорують внутрішній `<form>`.

**Рішення:** `self.helper.form_tag = False` — crispy рендерить тільки поля та кнопки,
але **не** `<form>...</form>` обгортку. Шаблон сам надає тег форми.

```python
# forms.py — TodoItemForm: вбудовується всередині <form> що є в шаблоні
class TodoItemForm(forms.Form):
    text = forms.CharField(max_length=500, label='Завдання')
    due_date = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = False          # ← не рендерити <form>...</form>
        self.helper.form_show_labels = False  # ← без label (компактний вигляд)
        self.helper.layout = Layout(
            Row(
                Column(Field('text', placeholder='Нове завдання...'), css_class='col-md-7'),
                Column(Field('due_date'), css_class='col-md-3'),
                Column(Submit('submit', '+ Додати', css_class='btn btn-primary w-100'),
                       css_class='col-md-2'),
            ),
        )
```

```html
<!-- todo_detail.html — шаблон надає <form> тег, crispy — тільки поля -->
<form method="post" action="{% url 'hello_app:todo_item_add' list.pk %}">
  {% csrf_token %}
  {% crispy item_form %}   ← рендерить Row з полями та кнопкою, але БЕЗ <form>
</form>
```

| Сценарій | `form_tag` |
|----------|-----------|
| Форма займає окрему сторінку (note_create, note_edit) | `True` (за замовчуванням) |
| Форма вбудована у сторінку (inline add item) | `False` |

---

## Layout Elements — довідник

```python
from crispy_forms.layout import *

# Базові елементи:
Field('field_name')                        # Поле з label і errors
Field('field_name', css_class='custom')   # + кастомний клас
Field('field_name', placeholder='...')    # + HTML атрибут
Field('field_name', rows=8)               # Textarea rows
Field('field_name', type='hidden')        # Прихований input

# Структурні:
Row(Column('f1', css_class='col-6'), Column('f2', css_class='col-6'))
# → <div class="row"><div class="col-6">f1</div><div class="col-6">f2</div></div>

Fieldset('Заголовок', Field('f1'), Field('f2'))
# → <fieldset><legend>Заголовок</legend>f1 f2</fieldset>

Div(Field('f1'), css_class='custom-div')
# → <div class="custom-div">f1</div>

HTML('<hr><p>Довільний HTML</p>')

# Кнопки:
Submit('submit', 'Зберегти')
# → <input type="submit" class="btn btn-primary" value="Зберегти">

Submit('submit', 'Зберегти', css_class='btn btn-success')
# → кастомний клас

ButtonHolder(Submit('s', 'OK'), HTML('<a href="#">Cancel</a>'))
# → обгортка для кнопок
```

---

## Навігація

- Попередня: [Forms Evolution](forms_evolution.md)
- Наступна: [Dashboard Architecture](dashboard_architecture.md)
