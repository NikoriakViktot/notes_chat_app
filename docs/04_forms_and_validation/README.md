# Частина IV. Forms і Validation

Форма — це trust boundary: введення користувача стає безпечним лише після server-side validation. Ніколи не довіряй даним з браузера без перевірки.

**Передумови:** Частина III (Models).
**Рівень:** Intermediate.

---

## Розділи

| Документ | Що вивчимо |
|----------|-----------|
| [Django Forms](django_forms_full.md) | `Form`, `ModelForm`, `clean_<field>()`, `ValidationError`, PRG-патерн, CSRF |
| [Crispy Forms](crispy_forms_full.md) | `FormHelper`, `Layout`, Bootstrap 5 рендеринг, `{{ form\|crispy }}` |

---

## Ключові концепти

**Form validation pipeline:**

```
Browser POST
  → Django CsrfViewMiddleware (перевірка csrfmiddlewaretoken)
  → view: form = NoteForm(request.POST, user=request.user)
  → form.is_valid()
      → field-level validation (required, max_length, ...)
      → clean_<field>() — кастомна перевірка
      → clean() — крос-поле валідація
  → якщо valid: form.cleaned_data → service → redirect
  → якщо invalid: форма з помилками → render
```

**ModelForm:**

```python
class NoteForm(forms.ModelForm):
    class Meta:
        model  = Note
        fields = ['title', 'content', 'priority', 'notebook', 'tags', 'group']

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        # обмежуємо вибір: тільки власні записники і теги
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset     = Tag.objects.filter(user=user)

    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title.strip()) < 3:
            raise forms.ValidationError("Заголовок занадто короткий (мінімум 3 символи).")
        return title.strip()
```

**PRG — Post/Redirect/Get:**

```text
POST /notes/new/  →  create note  →  302 redirect /notes/42/
                                          ↓
                                    GET /notes/42/  →  200 OK

Без PRG: F5 після POST → повторне надсилання форми (дублікат запису).
З PRG: F5 після GET → безпечне перезавантаження сторінки.
```

**CSRF:**

```python
# У шаблоні ОБОВ'ЯЗКОВО:
<form method="post">
    {% csrf_token %}   ← генерує hidden input з token
    {{ form|crispy }}
    <button type="submit">Зберегти</button>
</form>

# CsrfViewMiddleware відхиляє POST без валідного token
```

**Crispy Forms:**

```python
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit, Row, Column

class NoteForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            'title',
            Row(Column('priority', css_class='col-md-4'),
                Column('notebook', css_class='col-md-8')),
            'content',
            'tags',
            Submit('submit', 'Зберегти', css_class='btn btn-primary'),
        )
```

---

## Де це у Notes Chat App

| Файл | Що показує |
|------|-----------|
| `notes_app/forms.py` | `NoteForm`, `NotebookForm`, `TagForm`, `GroupCreateForm`, `TodoListForm` |
| `notes_app/views.py` | `form.is_valid()` → `services.*` → `redirect()` |
| `notes_app/tests/test_forms.py` | тести valid data, invalid data, `clean_*` |
| `templates/notes_app/note_form.html` | `{% csrf_token %}`, `{{ form\|crispy }}` |

---

## Педагогічний зв'язок

```text
Частина IV: Form.is_valid() → cleaned_data
  → Частина VI: service.create_note(**cleaned_data)  (mutation)
  → Частина VIII: test_forms.py (unit-тести форм)

CSRF (Частина IV) → Частина VII: security (Cross-Site Request Forgery)
```

**Zero to Hero:** Крок 4 (crispy_notes) — перший `ModelForm` і `crispy`.

**Lab:** [Forms Lab](../labs/forms_lab.md) — написати форму з кастомною валідацією, тест на invalid data.

---

## Контрольні питання

- Що таке trust boundary стосовно форм? Чому не можна довіряти `request.POST` безпосередньо?
- Яка різниця між `Form` і `ModelForm`?
- Що таке CSRF-атака? Як `{% csrf_token %}` захищає від неї?
- Що таке PRG-патерн і чому він потрібен?
- Коли використовувати `clean_<field>()`, а коли `clean()`?
- Чому `ModelForm.__init__` приймає `user` — що це дає?
- Чому `form.cleaned_data` доступний тільки після `is_valid()` → `True`?

---

**Далі →** [Частина V. Templates і Frontend](../05_frontend_and_templates/README.md) — як відповідь рендериться у HTML.
