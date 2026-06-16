# Forms Lab — Валідація і безпека форм

**Мета:** зрозуміти як Django Forms захищають від некоректних і шкідливих вхідних даних, навчитися писати custom validation і scoped querysets.

**Пов'язані файли:** `notes_app/forms.py`, `notes_app/tests/test_forms.py`.

---

## Частина 1 — Розберіть `NoteForm`

Відкрийте `notes_app/forms.py` і знайдіть `class NoteForm(forms.ModelForm)`.

```python
class NoteForm(forms.ModelForm):
    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        if user:
            self.fields['notebook'].queryset = Notebook.objects.filter(user=user)
            self.fields['tags'].queryset = Tag.objects.filter(user=user)
            self.fields['group'].queryset = user.groups.all()
        else:
            self.fields['notebook'].queryset = Notebook.objects.none()
            self.fields['tags'].queryset = Tag.objects.none()
            self.fields['group'].queryset = Group.objects.none()
```

**Питання:**

1. Що станеться якщо не фільтрувати queryset по `user`? Яка загроза безпеці?
2. Навіщо `Notebook.objects.none()` замість порожнього списку?
3. Чому `user` передається як keyword-only argument (`*args, user=None`)?

**Відповідь на питання 1:** без фільтрації студент може у HTML-запиті вказати `notebook_id` чужого записника. Django за замовчуванням приймає будь-який існуючий pk — без scoped queryset це IDOR через форму.

---

## Частина 2 — Розберіть `TagForm.clean_name()`

```python
class TagForm(forms.ModelForm):
    def clean_name(self):
        name = self.cleaned_data['name'].strip().lower()
        ...
```

**Завдання:** знайдіть повну реалізацію `clean_name()` у `forms.py`. Визначте:

- що перевіряє `clean_name`;
- чи є унікальність тегу для user задана на рівні моделі (`unique_together`) чи лише у формі;
- що відбудеться якщо прибрати `clean_name` і спробувати створити два однакові теги.

---

## Частина 3 — Напишіть тест на scoped queryset

Мета: переконатись, що `NoteForm` не показує записники чужого user.

```python
# Додайте до notes_app/tests/test_forms.py
from django.test import TestCase
from django.contrib.auth.models import User
from notes_app.forms import NoteForm
from notes_app.models import Notebook

class NoteFormQuerysetScopeTest(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pw')
        self.bob = User.objects.create_user('bob', password='pw')
        self.alice_nb = Notebook.objects.create(user=self.alice, title="Alice NB")
        self.bob_nb = Notebook.objects.create(user=self.bob, title="Bob NB")

    def test_notebook_queryset_scoped_to_user(self):
        form = NoteForm(user=self.alice)
        notebook_qs = form.fields['notebook'].queryset
        self.assertIn(self.alice_nb, notebook_qs)
        self.assertNotIn(self.bob_nb, notebook_qs)

    def test_notebook_queryset_empty_without_user(self):
        form = NoteForm()
        self.assertEqual(form.fields['notebook'].queryset.count(), 0)
```

Запустіть:

```bash
docker compose run --rm web python manage.py test notes_app.tests.test_forms -v 2
```

---

## Частина 4 — Додайте власну валідацію

**Завдання:** додайте до `NoteForm` метод `clean_title()`, який:

1. Прибирає пробіли на початку і кінці.
2. Відхиляє заголовки коротші за 3 символи.
3. Відхиляє заголовки, що починаються з `http://` або `https://`.

```python
def clean_title(self):
    title = self.cleaned_data['title'].strip()
    if len(title) < 3:
        raise forms.ValidationError("Заголовок має бути не коротше 3 символів.")
    if title.lower().startswith(('http://', 'https://')):
        raise forms.ValidationError("Заголовок не може бути URL-адресою.")
    return title
```

Напишіть тест, що перевіряє всі три випадки (short title, URL title, valid title).

**Критерій:** `form.is_valid()` повертає `False` для некоректних заголовків, `True` для коректних.

---

## Частина 5 — `ShareForm`

`forms.py` містить `ShareForm` — форму для ділення об'єкту з іншим користувачем за email/username.

**Завдання:**

1. Знайдіть `class ShareForm` у `forms.py`.
2. Визначте, яке поле вона валідує і де виконується пошук User.
3. Напишіть тест: передайте username неіснуючого user — форма має повернути помилку, а не виняток.

---

## Підсумок

| Патерн | Де у коді |
|--------|-----------|
| Scoped queryset (тільки свої об'єкти) | `NoteForm.__init__` |
| `clean_<field>()` — полева валідація | `TagForm.clean_name()` |
| Queryset security (IDOR через форму) | `NoteForm` — notebook, tags, group |
| Form без user → queryset = none() | `NoteForm.__init__` fallback |

---

## Оціни та обери (рівень аналізу і оцінювання)

### В.1. Де правильніше перевіряти унікальність тегу — у формі чи у моделі?

```python
# Варіант A: тільки у clean_name() форми
class TagForm(forms.ModelForm):
    def clean_name(self):
        # перевірка дублювання тут
        ...

# Варіант B: unique_together на рівні моделі
class Tag(models.Model):
    class Meta:
        unique_together = [('user', 'name')]
```

**Оціни:**
- Що трапиться якщо хтось обійде форму і зробить прямий `Tag.objects.create(...)` з дублем при Варіанті A?
- Що трапиться при Варіанті B, якщо у формі немає `try/except IntegrityError`?
- Знайди у `notes_app/models.py`, який варіант (або обидва) реалізовано.
- Сформулюй правило: де має жити validation — у моделі чи формі? Коли потрібні обидва?

---

### В.2. `ModelForm` vs `Form` — коли обирати що?

Notes Chat App використовує `ModelForm` для більшості форм.

**Оціни:**
- Знайди у `forms.py` форму, яка **не** є `ModelForm`. Чому вона не ModelForm?
- Коли `Form` (без Model) є правильним вибором?
- Яка б ціна переписати `ShareForm` як `ModelForm`? Що би ускладнилося?
- Сформулюй критерій: «я обираю `ModelForm` коли..., і `Form` коли...»

---

### В.3. Validation у формі vs validation у service

```python
# Підхід A: validation у clean_title() форми
class NoteForm(forms.ModelForm):
    def clean_title(self):
        title = self.cleaned_data['title'].strip()
        if len(title) < 3:
            raise ValidationError("Замалий заголовок.")
        return title

# Підхід B: validation у service
def create_note(user, title, content, ...):
    if len(title.strip()) < 3:
        raise ValueError("Замалий заголовок.")
    ...
```

**Оціни:**
- Що станеться якщо API endpoint або management command викликає `create_note` напряму (без форми)?
- Де у Notes Chat App реалізована валідація `title`? Знайди у `forms.py`.
- Коли validation у service є **обов'язковою**?
- Чи потрібне дублювання validation у формі і в service для Notes Chat App?
