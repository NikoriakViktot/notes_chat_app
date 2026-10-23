# Django Crispy Forms — from zero to practice

> Source: [django-crispy-forms.readthedocs.io](https://django-crispy-forms.readthedocs.io/en/latest/)
> Version: crispy-forms ≥ 2.x + crispy-bootstrap5

---

## How to read this file

This reference is built **from simple to complex**:

| Level | What's here | For whom |
|--------|--------|----------|
| [🟢 Start](#-start-your-first-crispy-form-in-5-minutes) | Installation + your first form in 5 minutes | Complete beginners |
| [🟡 Practice](#-practice-formhelper--layout) | FormHelper, Layout, all components | You already know the basics |
| [🔵 Reference](#-reference-the-full-api) | Formsets, Dynamic API, template packs | Full control |

> **Recommendation:** if this is your first time seeing crispy-forms, read from top to bottom without skipping ahead.
> If you are looking for a specific component, use the [Layout objects table](#layout-objects-table).

---

## 🟢 Start: Your First Crispy Form in 5 Minutes

### The problem: why does "HTML spaghetti" happen?

Imagine you need to display a form with Bootstrap 5. Without crispy you write:

```html
<!-- ❌ Without crispy: 18 lines of HTML for ONE field -->
<div class="mb-3">
  <label for="id_title" class="form-label fw-semibold">
    Заголовок
    <span class="text-danger">*</span>
  </label>
  <input type="text"
         name="title"
         id="id_title"
         class="form-control {% if form.title.errors %}is-invalid{% endif %}"
         required>
  {% if form.title.errors %}
    {% for error in form.title.errors %}
    <div class="invalid-feedback">{{ error }}</div>
    {% endfor %}
  {% endif %}
</div>
<!-- repeat for EVERY field... -->
```

And so on for every field. 5 fields = ~90 lines of HTML.
When the form changes, you edit the HTML in the template.
When Bootstrap changes, you edit every template.

With crispy:
```html
<!-- ✅ With crispy: 1 line — Bootstrap, validation and structure all included -->
{% crispy form %}
```

> **🧠 Mental model:** crispy-forms moves the Bootstrap markup from the template into Python code.
> The template becomes thin (`{% crispy form %}`), and the form describes itself (FormHelper + Layout).

---

### Step 1: Installation

```bash
pip install django-crispy-forms crispy-bootstrap5
```

```python
# settings.py — add TWO packages to INSTALLED_APPS
INSTALLED_APPS = [
    ...
    'crispy_forms',       # ← 1. the core package
    'crispy_bootstrap5',  # ← 2. the template pack for Bootstrap 5
]

# Specify which CSS framework you use
CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"
```

> **Why two packages?** Since version 2.0, crispy has been split: `crispy_forms` is the core, and the Bootstrap templates are
> a separate `crispy_bootstrap5`. This lets you plug in another framework (Tailwind, Bulma) without changing the core.

---

### Step 2: Load it in the template

```html
<!-- At the top of the template — once per file -->
{% load crispy_forms_tags %}

<!-- And wherever you need to show the form -->
{% crispy form %}
```

That's it! The form is rendered with Bootstrap 5: `form-control`, `form-label`, `invalid-feedback` — all automatic.

---

### Step 3: FormHelper — describing the form from Python

Without FormHelper, crispy just adds Bootstrap classes. With FormHelper, you describe:
- the form method (`POST`/`GET`)
- the order and structure of the fields (Layout)
- the Submit button

```python
# forms.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit

class ContactForm(forms.Form):
    name    = forms.CharField(label='Your name')
    email   = forms.EmailField(label='Email')
    message = forms.CharField(widget=forms.Textarea, label='Message')

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # FormHelper — attached to the form via self.helper
        self.helper = FormHelper()
        self.helper.form_method = 'post'          # <form method="post">
        self.helper.layout = Layout(
            'name',                               # a field by name
            'email',
            'message',
            Submit('submit', 'Send'),              # submit button
        )
```

```python
# views.py — nothing special
def contact(request):
    form = ContactForm()
    return render(request, 'contact.html', {'form': form})
```

```html
<!-- contact.html -->
{% load crispy_forms_tags %}
{% crispy form %}
```

> **🧠 What happens:** `{% crispy form %}` finds `form.helper`, looks at `form.helper.layout`,
> and renders every `Layout` object through Bootstrap 5 templates. That's all the "magic" there is.

---

### Step 4: Check that everything works

After the first run, make sure that:
- The form looks like Bootstrap (label + input + button)
- Red validation errors appear automatically on an empty submit
- There is no `ModuleNotFoundError: No module named 'crispy_forms'`

---

## 🟡 Practice: FormHelper + Layout

### FormHelper — what it controls

```python
self.helper = FormHelper()

# Attributes of the <form> tag
self.helper.form_method = 'post'          # POST or GET
self.helper.form_id = 'my-form'           # id="my-form"
self.helper.form_class = 'my-class'       # class="my-class"
self.helper.form_action = '/submit/'      # action="/submit/"

# Behavior
self.helper.form_tag = True               # True = renders <form>...</form>
                                          # False = fields only (useful for AJAX)
self.helper.disable_csrf = False          # True = remove CSRF (rarely needed)
self.helper.include_media = True          # Insert form.media automatically
self.helper.form_show_errors = True       # Show errors
self.helper.form_show_labels = True       # Show labels
```

> **💡 Most commonly used:** `form_method`, `form_tag`, `form_id`. The rest — as needed.

### FormHelper with a bound form

If the form is large and you don't want to list all the fields manually, pass `self` to FormHelper:

```python
def __init__(self, *args, **kwargs):
    super().__init__(*args, **kwargs)
    self.helper = FormHelper(self)   # ← crispy finds all the fields itself
    # Now you can skip Layout() — crispy builds a default one automatically
```

---

### Layout — how to describe the form structure

`Layout` is a tree of objects that describes the order and structure of the fields.

```python
from crispy_forms.layout import Layout, Fieldset, Row, Column, Field, Submit, HTML, Div

self.helper.layout = Layout(
    'simple_field',                              # just a field name — a string
    Field('title', placeholder='Hint'),          # a field with attributes
    Row(                                         # a horizontal row (Bootstrap row)
        Column('first_name', css_class='col-md-6'),
        Column('last_name',  css_class='col-md-6'),
    ),
    Fieldset('Section title',                    # <fieldset><legend>
        'field_1',
        'field_2',
    ),
    HTML('<hr>'),                                # arbitrary HTML
    Submit('submit', 'Save'),                    # button
)
```

> **🧠 Rule:** you specify fields as strings (`'title'`) or via `Field('title', ...)`.
> `Field` lets you set additional HTML attributes.

---

### Layout objects table

#### Basic (from `crispy_forms.layout`)

| Object | Generated HTML | When to use |
|--------|---------------------|----------------------|
| `'field_name'` | a standard field | just specify a field |
| `Field('field', placeholder='...')` | field + attributes | you need `placeholder`, `rows`, `autofocus` |
| `Field('field', type='hidden')` | `<input type="hidden">` | a hidden field |
| `Row(Column('f', css_class='col-md-6'), ...)` | `<div class="row">` | several fields in one row |
| `Fieldset('Назва', 'f1', 'f2')` | `<fieldset><legend>Назва` | grouping fields into sections |
| `Div('field', css_class='my-class')` | `<div class="my-class">` | a wrapper for custom styling |
| `HTML('<hr>')` | arbitrary HTML | separators, hints, links |
| `Submit('name', 'Текст')` | `<input type="submit">` | submit button |
| `Button('name', 'Текст')` | `<button type="button">` | a regular button |
| `Reset('name', 'Текст')` | `<input type="reset">` | reset button |
| `Hidden('name', 'value')` | `<input type="hidden">` | a hidden constant |
| `ButtonHolder(Submit(...), Button(...))` | `<div class="buttonHolder">` | a group of buttons |
| `MultiField('label', 'f1', 'f2')` | several fields under one label | a rare case |

#### Bootstrap-specific (from `crispy_forms.bootstrap`)

| Object | What it shows | Example |
|--------|-----------|---------|
| `AppendedText('field', '$')` | Input with a suffix | Prices, units |
| `PrependedText('field', '@')` | Input with a prefix | Username, symbols |
| `PrependedAppendedText('f', '$', '.00')` | Both together | A price with cents |
| `InlineCheckboxes('field')` | Checkboxes in a row | MultipleChoiceField |
| `InlineRadios('field')` | RadioSelect in a row | ChoiceField with RadioSelect |
| `StrictButton('Текст', css_class='btn-success')` | `<button>` (not `<input>`) | Buttons with arbitrary CSS |
| `FieldWithButtons('field', StrictButton("Go!"))` | Input + button side by side | Search, submit-in-group |
| `Tab('Назва', ...)` inside `TabHolder` | Bootstrap tabs | A form with tabs |
| `AccordionGroup('Назва', ...)` in `Accordion` | Bootstrap accordion | Large forms |
| `Modal(Field(...), css_id='my-id', title='T')` | Bootstrap modal | Forms in modals |
| `Alert(content='Попередження')` | Bootstrap alert | Info messages in a form |
| `UneditableField('field')` | Read-only field | Show but don't edit |

---

### Layout object attributes

```python
# kwargs → become HTML attributes
Field('title', placeholder='Hint')           # placeholder="Hint"
Field('title', autofocus=True)               # autofocus
Field('title', rows=8)                       # rows="8" (textarea)
Field('title', type='hidden')                # type="hidden"
Field('title', data_custom="val")            # data-custom="val" (underscore → hyphen!)

# Special kwargs
Field('title', css_class="extra-class")      # an additional CSS class
Field('title', css_id="my-id")              # HTML id
Field('title', wrapper_class="mt-3")        # class for the wrapping <div>
Field('title', template="custom.html")      # a custom template for this field
```

> **💡 Underscore → hyphen:** in Python kwargs, an underscore `_` becomes `-` in HTML.
> `data_name="val"` → `data-name="val"`. Exceptions: `css_class`, `css_id`, `wrapper_class`.

---

### Practical examples

#### Two-column Layout

```python
self.helper.layout = Layout(
    Row(
        Column('first_name', css_class='col-md-6'),
        Column('last_name',  css_class='col-md-6'),
    ),
    Row(
        Column('email', css_class='col-md-8'),
        Column('phone', css_class='col-md-4'),
    ),
    Submit('submit', 'Save'),
)
```

#### A form with sections (Fieldset)

```python
self.helper.layout = Layout(
    Fieldset('Personal details',
        'first_name', 'last_name', 'email',
    ),
    Fieldset('Address',
        Row(
            Column('city',    css_class='col-md-6'),
            Column('country', css_class='col-md-6'),
        ),
    ),
    HTML('<hr>'),
    Submit('submit', 'Save', css_class='btn btn-primary me-2'),
    HTML('<a href="#" class="btn btn-outline-secondary">Cancel</a>'),
)
```

#### A form with tabs

```python
from crispy_forms.bootstrap import TabHolder, Tab

self.helper.layout = Layout(
    TabHolder(
        Tab('Main',       'title', 'content'),
        Tab('Settings',   'priority', 'tags'),
        Tab('Reminders',  'remind_at'),
    ),
    Submit('submit', 'Save'),
)
```

#### Input with a prefix / suffix

```python
from crispy_forms.bootstrap import PrependedText, AppendedText

self.helper.layout = Layout(
    PrependedText('username', '@'),
    AppendedText('discount', '%'),
    PrependedText('price', '$', placeholder='0.00'),
)
```

#### Buttons in a row via HTML

```python
HTML('<hr class="my-4">'),
Submit('submit', 'Save', css_class='btn btn-primary me-2'),
HTML('<a href="{% url \'note_list\' %}" class="btn btn-outline-secondary">Cancel</a>'),
```

---

### Template Tags and Filters

```html
{% load crispy_forms_tags %}

{# The main tag — full rendering with FormHelper #}
{% crispy form %}

{# With an explicit helper (if the helper is not attached to the form) #}
{% crispy form my_helper %}

{# The filter — quick Bootstrap styling without FormHelper #}
{{ form|crispy }}

{# Formset — pass the helper explicitly #}
{% crispy formset helper %}

{# A single field on its own #}
{{ form.title|as_crispy_field }}
```

**When to use `{% crispy %}` vs `|crispy`:**

| | `{% crispy form %}` | `{{ form\|crispy }}` |
|--|--------------------|--------------------|
| FormHelper + Layout | Yes — full control | No — Bootstrap classes only |
| `<form>` tag + CSRF | Yes (by default) | No |
| Submit button | Via Layout | Not included |
| When | Production | A quick preview |

> **💡 Rule:** for any real form — always `{% crispy form %}` with FormHelper.
> `|crispy` — only for a quick preview during development.

---

### Common beginner mistakes

#### ❌ Forgot `{% load crispy_forms_tags %}`

```html
<!-- ❌ Error: TemplateSyntaxError: Invalid block tag 'crispy' -->
{% crispy form %}

<!-- ✅ Correct: load is required at the top of the template -->
{% load crispy_forms_tags %}
{% crispy form %}
```

#### ❌ Didn't add `crispy_bootstrap5` to INSTALLED_APPS

```python
# ❌ Error: TemplateDoesNotExist: bootstrap5/uni_form.html
INSTALLED_APPS = ['crispy_forms']   # core only, no template pack!

# ✅ You need both
INSTALLED_APPS = ['crispy_forms', 'crispy_bootstrap5']
```

#### ❌ Forgot `form_method` — the method is implicit (POST by default)

```python
# ❌ Without form_method — POST by default, but explicit code is better
self.helper = FormHelper()
# the form renders with method="post" (crispy's default), but the code doesn't show it

# ✅ Always specify it explicitly
self.helper.form_method = 'post'
```

#### ❌ `{% crispy %}` without an argument → IndexError

```html
<!-- ❌ Error: IndexError: pop index out of range -->
{% crispy %}

<!-- ✅ Correct: you must pass the form -->
{% crispy form %}
```

#### ❌ `{% crispy form %}` inside an HTML comment

```html
<!-- ❌ An HTML comment does NOT hide Django tags — crispy WILL RUN! -->
<!-- {% crispy form %} -->

<!-- ✅ To display the tag as text: HTML entities -->
&#123;% crispy form %&#125;

<!-- ✅ Or a verbatim block -->
{% verbatim %}{% crispy form %}{% endverbatim %}
```

> **🧠 Why:** the Django template engine processes `{% %}` tags BEFORE the browser ever sees the HTML comment.
> An HTML comment is just text for the browser. Django doesn't understand it.

#### ❌ Forgetting to filter the queryset of an FK field

```python
# ❌ Security: the user can attach someone else's notebook!
class NoteForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()

# ✅ Always filter FK fields by the current user
class NoteForm(forms.ModelForm):
    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
        self.helper = FormHelper()
```

---

## 🔵 Reference: The Full API

### All FormHelper attributes

| Attribute | Default | Description |
|---------|------------|------|
| `form_method` | `'POST'` | HTTP method: `'POST'` or `'GET'` |
| `form_action` | `''` | URL for `action=""` |
| `form_id` | `''` | HTML `id="..."` |
| `form_class` | `''` | CSS classes for `<form>` |
| `attrs` | `{}` | Arbitrary attributes: `{'data_id': '/url'}` |
| `form_tag` | `True` | `False` = renders without `<form>` tags |
| `disable_csrf` | `False` | Disable CSRF (for `form_tag=False`) |
| `include_media` | `True` | Insert `{{ form.media }}` |
| `render_unmentioned_fields` | `False` | Render fields not in the Layout |
| `render_hidden_fields` | `False` | Render all hidden fields |
| `render_required_fields` | `False` | Render all required fields |
| `form_show_errors` | `True` | Show errors |
| `form_show_labels` | `True` | Show labels |
| `form_error_title` | `None` | Title of the non-field errors block |
| `template` | (auto) | Custom form template |
| `field_template` | (auto) | Custom field template |
| `template_pack` | `settings` | Override the template pack |

---

### Formsets

```python
from django.forms import formset_factory
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit

ExampleFormSet = formset_factory(ExampleForm, extra=3)

class ExampleFormSetHelper(FormHelper):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.form_method = 'post'
        self.layout = Layout('favorite_color', 'favorite_food')
        self.render_required_fields = True
        self.add_input(Submit('submit', 'Save'))
```

```python
# views.py
formset = ExampleFormSet()
helper  = ExampleFormSetHelper()
return render(request, 'template.html', {'formset': formset, 'helper': helper})
```

```html
{% load crispy_forms_tags %}
{% crispy formset helper %}   {# the helper is passed explicitly! #}
```

#### A formset without an outer `<form>`

```html
<form method="POST">
    {% csrf_token %}
    {% crispy formset helper %}
    <button class="btn btn-primary">Save</button>
</form>
```

#### Extra Context in a formset layout

```python
self.layout = Layout(
    HTML('{% if forloop.first %}<h5>First item</h5>{% endif %}'),
    Fieldset('Item {{ forloop.counter }}', 'field'),
)
```

#### A tabular formset form

```python
helper.template = 'bootstrap5/table_inline_formset.html'
```

---

### The dynamic Layout API

> Changing the Layout in a view is useful for conditional forms (a different layout for different user roles, etc.)

#### Selecting by slice

```python
form.helper[1:3]       # items 1 and 2
form.helper[2]         # the third item
form.helper[:-1]       # all except the last
form.helper[0][0]      # the first one inside the first nested object
```

#### `wrap` — wrap each item

```python
# BEFORE: Layout('f1', 'f2', 'f3')
form.helper[1:3].wrap(Field, css_class="highlighted")
# AFTER: Layout('f1', Field('f2', css_class='highlighted'), Field('f3', ...))
```

#### `wrap_together` — wrap the whole slice together

```python
# BEFORE: Layout('f1', 'f2', 'f3')
form.helper[0:3].wrap_together(Div, css_class="form-block")
# AFTER: Layout(Div('f1', 'f2', 'f3', css_class='form-block'))
```

#### `update_attributes` — update attributes

```python
form.helper[0:3].update_attributes(css_class="my-class")
form.helper['password'].update_attributes(css_class="hero")
```

#### `filter` — search by type

```python
form.helper.filter(str).wrap(Field, css_class="hello")       # all top-level strings
form.helper.filter(str, max_level=2).wrap(Field, ...)        # two levels deep
form.helper.filter(str, greedy=True).wrap(Div, ...)          # unlimited depth
form.helper.filter(str, Div).wrap(Div, css_class="hello")    # several types
```

#### `filter_by_widget` / `exclude_by_widget`

```python
# Requires FormHelper(self) — a helper with a bound form
form.helper.filter_by_widget(forms.PasswordInput).wrap(Field, css_class="secure")
form.helper.exclude_by_widget(forms.PasswordInput).wrap(Field, css_class="normal")
```

#### Direct Layout manipulation

```python
layout = form.helper.layout
layout.append(HTML("<p>Hint</p>"))                  # append to the end
layout.insert(1, HTML("<p>At the second position</p>"))  # insert at a position
layout.pop(2)                                       # remove the third item
layout[0][1] = Field('title', css_class="new")     # replace an item
```

---

### Composing Layouts (reuse)

```python
# A shared block — defined once
class UserBlock(Layout):
    def __init__(self):
        super().__init__(
            Fieldset('User details', 'username', 'email')
        )

# Used in different forms
class RegisterForm(forms.Form):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            UserBlock(),                        # ← embed it
            'phone',
            Submit('submit', 'Sign up'),
        )
```

---

### Overriding templates

```python
# Globally for all instances of the class
from crispy_forms.layout import Div
Div.template = 'my_div_template.html'

# For a specific object in a Layout
Layout(
    Div('field1', template='custom_div.html')
)

# Via FormHelper
self.helper.template = 'my_form.html'
self.helper.field_template = 'my_field.html'
```

---

### Creating your own Template Pack

Minimal structure (`templates/chocolate/`):

```
chocolate/               ← pack name = the value of CRISPY_TEMPLATE_PACK
├── whole_uni_form.html  ← REQUIRED: the form template for {% crispy %}
├── field.html           ← REQUIRED: the template for a single field
├── uni_form.html        ← for the |crispy filter
└── layout/
    ├── baseinput.html   ← for Submit/Button
    └── div.html         ← for Div
```

```python
# settings.py
CRISPY_TEMPLATE_PACK = 'chocolate'
CRISPY_ALLOWED_TEMPLATE_PACKS = ('bootstrap5', 'chocolate')
```

> **Tip:** copy the templates from `crispy_bootstrap5`, then adapt the HTML/CSS to your framework.
> Since version 1.5.0, template packs are isolated — the templates of one pack cannot reference another.

---

## Related files

| File | What it shows |
|------|-----------|
| [DESIGN_FOUNDATIONS.md §14](../05_frontend_and_templates/design_foundations_full.md#14-detailed-crispy-forms-architecture) | Architecture, pipelines, before/after comparison |
| [crispy_notes_app/forms.py](../../notes_app/forms.py) | **Real code** — NoteForm, NotebookForm, TagForm with FormHelper + Layout |
| [crispy_notes_chat_app/README.md](../../README.md) | A step-by-step crispy tutorial with a 3-level comparison |
