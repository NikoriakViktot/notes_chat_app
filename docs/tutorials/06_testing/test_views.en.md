# test_views.py — Integration tests with the Test Client

---

## Django Test Client

> **Question:** What does an integration test check that a unit test CANNOT?

`self.client` is `django.test.Client`, a built-in HTTP client for tests.

```python
# Automatically available in every TestCase as self.client
from django.test import TestCase

class MyTest(TestCase):
    def test_something(self):
        self.client  # ← ready to use
```

It doesn't open a real browser. It simulates an HTTP request **inside the Django process**: bypassing the network, but going through the entire Django middleware stack.

```
self.client.get('/notes/')
    ↓
SecurityMiddleware         → checks HTTPS headers
SessionMiddleware          → loads the session from the test database
AuthenticationMiddleware   → sets request.user
CsrfViewMiddleware         → CSRF check (disabled for test client POST)
note_list view             → @login_required → selectors → QuerySet
HTML Response              ← the template is rendered with real data
    ↓
response.status_code       → 200 / 302 / 404
response.content           → HTML bytes
response.context           → the template context (for assertContains)
```

### What an integration test catches that a unit test WON'T

| What it checks | Unit (services) | Integration (views) |
|-------------|-----------------|---------------------|
| `@login_required` protects the view | ✗ | ✓ |
| URL routing (`/notes/` → note_list) | ✗ | ✓ |
| redirect after POST (302 → /notes/pk/) | ✗ | ✓ |
| form errors in the template context | ✗ | ✓ |
| Bob gets 404 when trying to access | ✗ | ✓ |
| The page HTML contains the note title | ✗ | ✓ |
| The create_note() business logic is correct | ✓ | ✓ |

---

## `force_login` vs `login`

```python
# force_login — fast, no password check (the standard in tests)
self.client.force_login(self.alice)
# → doesn't run the auth pipeline, doesn't check the password
# → simply sets the session cookie → request.user = alice
# → ideal for tests where we don't care about the login process itself

# login — the full auth pipeline (only if you are testing the login process itself)
success = self.client.login(username='alice', password='pass123')
# → authenticate() + login() + session
# → Use only in test_selenium or test_login_flow
```

---

## Key response attributes

```python
response = self.client.get(reverse('notes_app:note_list'))

response.status_code      # → 200, 302, 404, 403, 500
response.context          # → the template context {'notes': queryset, 'form': form}
response.content          # → the response HTML as bytes
response['Location']      # → the redirect URL (if 302)
response.context['form'].errors  # → {'title': ['This field is required.']}
```

### Assert methods for HTTP tests

```python
# HTTP status codes
self.assertEqual(response.status_code, 200)    # OK
self.assertEqual(response.status_code, 302)    # redirect
self.assertEqual(response.status_code, 404)    # not found
self.assertEqual(response.status_code, 403)    # forbidden

# Checking a redirect
self.assertRedirects(response, reverse('notes_app:note_list'),
                     fetch_redirect_response=False)
# fetch_redirect_response=False — we don't make a second GET request

# Text in the HTML
self.assertContains(response, 'Alice Note')    # the string is in the HTML
self.assertNotContains(response, 'Bob Secret') # the string is NOT in the HTML

# Checking that the URL contains login
self.assertIn('/accounts/login/', response['Location'])

# Form errors
self.assertIn('title', response.context['form'].errors)

# Presence in the database
self.assertTrue(Note.objects.filter(title='New Note').exists())
self.assertEqual(Note.objects.count(), 1)
```

---

## Structure of test_views.py

```python
# notes_app/tests/test_views.py
from django.contrib.auth.models import Group, User
from django.test import TestCase
from django.urls import reverse

from notes_app.models import Note, Notebook, Tag


class BaseViewTest(TestCase):
    """Base class with alice and bob for all view tests."""

    def setUp(self):
        self.alice = User.objects.create_user('alice', password='pass123')
        self.bob   = User.objects.create_user('bob',   password='pass123')


class AuthenticationViewTest(BaseViewTest):  # ← @login_required on all views
class NoteListViewTest(BaseViewTest):         # ← multi-tenant isolation
class NoteDetailViewTest(BaseViewTest):       # ← ownership + group access
class NoteCreateViewTest(BaseViewTest):       # ← form valid/invalid, IDOR prevention
class NoteEditViewTest(BaseViewTest):         # ← ownership check (someone else's → 404)
class NoteDeleteViewTest(BaseViewTest):       # ← ownership + cascade to the database
class NotebookViewTest(BaseViewTest):         # ← ownership via get_object_or_404
class GroupViewTest(BaseViewTest):            # ← membership check
class TodoListSharingViewTest(BaseViewTest):  # ← share/unshare workflow
```

---

## The four most important patterns

### Pattern 1 — @login_required: redirecting anonymous users

```python
class NoteListViewTest(BaseViewTest):

    def test_anonymous_redirects_to_login(self):
        """An anonymous user → redirect to /accounts/login/?next=/notes/"""
        response = self.client.get(reverse('notes_app:note_list'))
        # Not 200! → redirect to the login page
        self.assertEqual(response.status_code, 302)
        self.assertIn('/accounts/login/', response['Location'])

    def test_authenticated_gets_200(self):
        self.client.force_login(self.alice)
        response = self.client.get(reverse('notes_app:note_list'))
        self.assertEqual(response.status_code, 200)

    def test_note_list_shows_only_user_notes(self):
        """Multi-tenant: Alice doesn't see Bob's notes."""
        Note.objects.create(user=self.bob, title="Bob's Secret Note")
        self.client.force_login(self.alice)

        response = self.client.get(reverse('notes_app:note_list'))

        self.assertNotContains(response, "Bob's Secret Note")
```

### Pattern 2 — Ownership check: Bob gets 404

```python
class NoteDetailViewTest(BaseViewTest):

    def test_owner_gets_200(self):
        note = Note.objects.create(user=self.alice, title='Alice Note')
        self.client.force_login(self.alice)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)

    def test_non_owner_gets_404(self):
        """
        Bob tries to open Alice's note.
        selectors.get_note_detail(request.user, pk):
          → Note.objects.filter(Q(user=bob) | Q(group__in=bob_groups)).get(id=note_id)
          → SELECT WHERE pk=alice_note.pk AND (user_id=bob.id OR group_id IN (...))
          → Note.DoesNotExist → the view raises Http404 → 404

        Why 404 and not 403?
          403: "the resource exists, but access is forbidden" → the attacker knows the id exists
          404: "no such resource"                             → less information for an attack
        """
        alice_note = Note.objects.create(user=self.alice, title='Alice Private')
        self.client.force_login(self.bob)

        response = self.client.get(
            reverse('notes_app:note_detail', args=[alice_note.pk])
        )

        self.assertEqual(response.status_code, 404)

    def test_group_member_can_view_shared_note(self):
        """A group member sees a group note."""
        group = Group.objects.create(name='Team')
        group.user_set.add(self.alice, self.bob)
        note = Note.objects.create(user=self.alice, title='Team Note', group=group)

        self.client.force_login(self.bob)
        response = self.client.get(
            reverse('notes_app:note_detail', args=[note.pk])
        )
        self.assertEqual(response.status_code, 200)
```

### Pattern 3 — POST form: redirect on success, 200 on error

```python
class NoteCreateViewTest(BaseViewTest):

    def setUp(self):
        super().setUp()
        self.url = reverse('notes_app:note_create')

    def test_valid_post_creates_note_and_redirects(self):
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': 'New Note',
            'content': 'Content',
            'priority': 2,
        })

        # Check the redirect after a successful POST (the PRG pattern)
        self.assertEqual(response.status_code, 302)

        # Check that the record exists in the database
        self.assertTrue(Note.objects.filter(title='New Note', user=self.alice).exists())

    def test_invalid_post_returns_form_with_errors(self):
        """An empty title → the form is invalid → 200 (not a redirect)."""
        self.client.force_login(self.alice)

        response = self.client.post(self.url, data={
            'title': '',    # empty → invalid
            'priority': 1,
        })

        self.assertEqual(response.status_code, 200)
        self.assertFalse(Note.objects.exists())   # the note was not created
```

### Pattern 4 — IDOR prevention through the form

```python
class NoteCreateIDORTest(BaseViewTest):

    def test_note_create_with_bobs_notebook_fails(self):
        """
        Alice tries POST /notes/new/ with notebook=bob_notebook.id

        WITHOUT protection in the form: Alice could write a note into Bob's notebook
        WITH protection (NoteForm queryset): the form is invalid → 200, the note is not created
        """
        bob_nb = Notebook.objects.create(user=self.bob, title="Bob's Private")
        self.client.force_login(self.alice)

        response = self.client.post(
            reverse('notes_app:note_create'),
            data={
                'title': 'IDOR Attack',
                'notebook': bob_nb.pk,   # ← someone else's notebook
                'priority': 1,
            }
        )

        # The form is invalid → 200 (not a redirect)
        self.assertEqual(response.status_code, 200)
        # The note was not created → IDOR blocked ✓
        self.assertFalse(Note.objects.filter(title='IDOR Attack').exists())
```

---

## Access diagram: what each view returns for each user

```
                    alice     bob (not member)   bob (member of group)
note_list           200       200 (own notes)    200 (own notes)
note_detail (own)   200       404                404
note_detail (group) 200       404                200 ← group access!
note_edit           200       404                302+error
note_delete         302 ok    404                302+error
notebook_edit       200       404                404
group_detail        200       404                200 ← if member
group_delete        302 ok    403                403
```

---

## What each category of tests checks

```
AuthenticationViewTest    ← @login_required on every view
NoteListViewTest          ← multi-tenant: alice sees only her own notes
NoteDetailViewTest        ← ownership + group-based access
NoteCreateViewTest        ← form valid/invalid, IDOR prevention, note.user = request.user
NoteEditViewTest          ← ownership: someone else's → 404; your own → 302
NoteDeleteViewTest        ← ownership + cascade: the note is deleted from the database
NotebookViewTest          ← ownership: get_object_or_404(user=request.user)
GroupViewTest             ← membership check: someone else's → 404, non-member delete → 403
TodoListSharingViewTest   ← share/unshare workflow over HTTP
```

---

## Running the integration tests

```bash
# crispy_notes_project:
python manage.py test hello_app.tests.test_views -v 2

# notes_chat_app (Docker):
docker compose run --rm web python manage.py test notes_app.tests.test_views -v 2

# A specific class:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteDetailViewTest -v 2

# A specific test:
docker compose run --rm web python manage.py test \
  notes_app.tests.test_views.NoteDetailViewTest.test_group_member_can_view_shared_note -v 2
```

---

## Next

- **[test_consumers.py](test_consumers.md)** — WebSocket tests (notes_chat_app only)
