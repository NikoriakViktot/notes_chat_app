# ORM Lab — Query optimization

**Goal:** understand the N+1 problem and learn to use `select_related`, `prefetch_related`, and `annotate` on the real Notes Chat App code.

**Prerequisites:** a running Docker stack, familiarity with `selectors.py`.

---

## Part 1 — Take apart the existing code

Open `notes_app/selectors.py` and find the `get_user_notes` function:

```python
def get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None):
    user_groups = user.groups.all()
    qs = Note.objects.filter(
        Q(user=user) | Q(group__in=user_groups), is_archived=archived
    ).select_related('notebook', 'group').prefetch_related('tags')
    ...
```

**Questions for analysis:**

1. Why `select_related('notebook', 'group')` here and not `prefetch_related`?
2. Why `prefetch_related('tags')` and not `select_related`?
3. What happens if you remove both: how many queries will the template run for a list of 20 notes?

---

## Part 2 — Find the N+1

Open `get_user_notebooks`:

```python
def get_user_notebooks(user):
    return Notebook.objects.filter(user=user).annotate(
        note_count=Count('notes', filter=Q(notes__is_archived=False))
    )
```

**Task:** try removing `annotate(note_count=...)` and instead count the notes in Python in a loop. Measure the difference with Django Debug Toolbar or Django logging.

### Enabling SQL logging

Add this to `settings.py` (for development only):

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

Or in the Django shell:

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
    print(nb.note_count)     # already there — no extra query
print(len(connection.queries))
```

---

## Part 3 — Compare `get_todo_list_detail`

```python
def get_todo_list_detail(user, pk):
    return TodoList.objects.prefetch_related(
        'items'
    ).get(Q(user=user) | Q(shared_with=user), pk=pk)
```

**Task:** add `select_related('user')` to this queryset. Explain why this can reduce the number of queries when displaying "this list belongs to user X".

---

## Part 4 — Independent task

**Condition:** `get_group_with_members` in `selectors.py` uses `prefetch_related('user_set')`. Write a test that confirms that no more than 3 SQL queries run for a group with 10 members (the group + the `user_set` prefetch + the `.exists()` membership check), not 1 + N.

```python
# notes_app/tests/test_selectors.py (new file)
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
        _ = list(result.user_set.all())  # materialize the prefetch
        self.assertLessEqual(len(connection.queries), 3)
```

**Criterion:** the test passes without errors and the query count is ≤ 3.

---

## Rules derived from the code

| Situation | Solution |
|----------|---------|
| An FK you always read together with the object | `select_related('field')` |
| M2M or reverse FK (one → many) | `prefetch_related('field')` |
| You need a count without loading the related objects | `annotate(n=Count('related'))` |
| The queryset is not materialized yet | call `list()` or iterate in the template |
| N+1 in a template | `{% for tag in note.tags.all %}` without prefetch → N+1 |

---

## Evaluate and choose (analysis and evaluation level)

These tasks do not have a single correct answer; what matters is the quality of the argument.

### Q.1. `annotate` vs a Python loop

Here are two implementations of counting notes in a Notebook:

```python
# Implementation A — annotate
Notebook.objects.filter(user=user).annotate(
    note_count=Count('notes', filter=Q(notes__is_archived=False))
)

# Implementation B — Python
notebooks = list(Notebook.objects.filter(user=user))
for nb in notebooks:
    nb.note_count = Note.objects.filter(notebook=nb, is_archived=False).count()
```

**Evaluate:**
- How many SQL queries does each implementation run for 20 Notebooks?
- Under what conditions could Implementation B be acceptable?
- Where does Notes Chat App use Implementation A? Find it in `selectors.py`.
- Write a justified choice (2–4 sentences) for this specific project.

---

### Q.2. `select_related` vs `prefetch_related`: where is the line?

```python
# In get_user_notes:
.select_related('notebook', 'group').prefetch_related('tags')
```

**Evaluate:**
- Why do `notebook` and `group` go through `select_related`, while `tags` goes through `prefetch_related`?
- What would happen if `tags` used `select_related`?
- Could `notebook` use `prefetch_related`? What would the difference in the number of queries be?
- Formulate a rule: "I choose `select_related` when..., and `prefetch_related` when..."

---

### Q.3. Evaluating an existing selector

Open `selectors.py` and find the `get_shopping_list_detail` function.

**Evaluate:**
- Does it use `select_related` or `prefetch_related`? If not, are they needed?
- How many SQL queries run when displaying 50 items of a shopping list?
- Propose an optimization (or argue that the existing code is sufficient).
- Write a test that measures the query count and confirms your assessment.
