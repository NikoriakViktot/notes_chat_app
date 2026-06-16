# ORM Lab — Оптимізація запитів

**Мета:** зрозуміти проблему N+1, навчитися використовувати `select_related`, `prefetch_related` і `annotate` на реальному коді Notes Chat App.

**Передумови:** запущений Docker стек, знайомство з `selectors.py`.

---

## Частина 1 — Розберіть існуючий код

Відкрийте `notes_app/selectors.py` і знайдіть функцію `get_user_notes`:

```python
def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups), is_archived=archived
    ).select_related('notebook', 'group').prefetch_related('tags')
    ...
```

**Питання для аналізу:**

1. Чому тут `select_related('notebook', 'group')` а не `prefetch_related`?
2. Чому `prefetch_related('tags')` а не `select_related`?
3. Що станеться якщо прибрати обидва — скільки запитів виконає шаблон при списку з 20 нотаток?

---

## Частина 2 — Знайдіть N+1

Відкрийте `get_user_notebooks`:

```python
def get_user_notebooks(user):
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    )
```

**Завдання:** спробуйте прибрати `annotate(note_count=...)` і замість цього порахувати кількість нотаток у Python у циклі. Замірте різницю через Django Debug Toolbar або Django logging.

### Увімкнення SQL логування

Додайте до `settings.py` (тільки для розробки):

```python
LOGGING = {
    'version': 1,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG',
        },
    },
}
```

Або у Django shell:

```python
docker compose run --rm web python manage.py shell
```

```python
from django.db import connection, reset_queries
from django.conf import settings
settings.DEBUG = True

from notes_app.selectors import get_user_notebooks
from django.contrib.auth.models import User

reset_queries()
user = User.objects.first()
notebooks = list(get_user_notebooks(user))
for nb in notebooks:
    print(nb.note_count)     # вже є — без додаткового запиту
print(len(connection.queries))
```

---

## Частина 3 — Порівняйте `get_todo_list_detail`

```python
def get_todo_list_detail(user, pk):
    return TodoList.objects.prefetch_related(
        'items'
    ).get(Q(user=user) | Q(shared_with=user), pk=pk)
```

**Завдання:** додайте `select_related('user')` до цього queryset. Поясніть: чому це може зменшити кількість запитів при відображенні "список належить user X".

---

## Частина 4 — Самостійне завдання

**Умова:** `get_group_with_members` у `selectors.py` використовує `prefetch_related('user_set')`. Напишіть тест, що підтверджує: при 10 учасниках групи виконується не більше 2 SQL запитів.

```python
# notes_app/tests/test_selectors.py (новий файл)
from django.test import TestCase
from django.db import connection, reset_queries
from django.test.utils import override_settings
from django.contrib.auth.models import User, Group
from notes_app.selectors import get_group_with_members

class GroupMembersQueryCountTest(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user('owner', password='pw')
        self.group = Group.objects.create(name='testgroup')
        self.owner.groups.add(self.group)
        for i in range(9):
            u = User.objects.create_user(f'member{i}', password='pw')
            u.groups.add(self.group)

    @override_settings(DEBUG=True)
    def test_query_count(self):
        reset_queries()
        result = get_group_with_members(self.group.pk, self.owner)
        _ = list(result.user_set.all())  # матеріалізація prefetch
        self.assertLessEqual(len(connection.queries), 3)
```

**Критерій:** тест проходить без помилок і query count ≤ 3.

---

## Правила, виведені з коду

| Ситуація | Рішення |
|----------|---------|
| FK, яку ти завжди читаєш разом з об'єктом | `select_related('field')` |
| M2M або зворотній FK (один → багато) | `prefetch_related('field')` |
| Потрібен count без завантаження пов'язаних об'єктів | `annotate(n=Count('related'))` |
| Queryset ще не матеріалізований | виклик `list()` або ітерація у шаблоні |
| N+1 у шаблоні | `{% for tag in note.tags.all %}` без prefetch → N+1 |

---

## Оціни та обери (рівень аналізу і оцінювання)

Ці завдання не мають єдиної правильної відповіді — важлива якість аргументу.

### В.1. `annotate` vs Python-цикл

Дано дві реалізації підрахунку нотаток у Notebook:

```python
# Реалізація A — annotate
Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
)

# Реалізація B — Python
notebooks = list(Notebook.objects.filter(user=user))
for nb in notebooks:
    nb.note_count = Note.objects.filter(notebook=nb, is_archived=False).count()
```

**Оціни:**
- Скільки SQL запитів виконує кожна реалізація при 20 Notebook?
- За яких умов Реалізація B може бути прийнятною?
- Де у Notes Chat App використовується Реалізація A? Знайди у `selectors.py`.
- Напиши обґрунтований вибір (2–4 речення) для цього конкретного проєкту.

---

### В.2. `select_related` vs `prefetch_related` — де межа?

```python
# У get_user_notes:
.select_related('notebook', 'group').prefetch_related('tags')
```

**Оціни:**
- Чому `notebook` і `group` — через `select_related`, а `tags` — через `prefetch_related`?
- Що би сталося якби `tags` використовувало `select_related`?
- Чи міг `notebook` використовувати `prefetch_related`? Яка б різниця у кількості запитів?
- Сформулюй правило: «я обираю `select_related` коли..., і `prefetch_related` коли...»

---

### В.3. Оцінка існуючого selector

Відкрий `selectors.py` і знайди функцію `get_shopping_list_detail`.

**Оціни:**
- Чи є там `select_related` або `prefetch_related`? Якщо ні — чи потрібні вони?
- Скільки SQL запитів виконується при відображенні 50 позицій списку покупок?
- Запропонуй оптимізацію (або аргументуй, що існуючий код достатній).
- Напиши тест, що вимірює query count і підтверджує твою оцінку.
