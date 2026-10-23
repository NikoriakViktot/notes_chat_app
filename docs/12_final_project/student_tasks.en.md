# Student Tasks

Practical tasks for Notes Chat App at three difficulty levels.

---

## Level 1 — Minimal

Add a new field to the `Note` model, create and apply a migration, and show the field in the detail template.

**Steps:**

1. Add the field in `notes_app/models.py` (for example, `color = models.CharField(max_length=7, default='#808080', blank=True)`).
2. Create the migration: `docker compose run --rm web python manage.py makemigrations`.
3. Apply it: `docker compose run --rm web python manage.py migrate`.
4. Show the field in `templates/notes_app/note_detail.html`.

**Criteria:**

- The migration file exists in `notes_app/migrations/`.
- `manage.py check` passes without errors.
- The template displays the field without errors.
- Existing tests pass: `docker compose run --rm web python manage.py test notes_app.tests.test_models -v 2`.

---

## Level 2 — Core

Add an archive/unarchive flow through a service, a view, a URL, and a test.

**Steps:**

1. `Note` already has an `is_archived` field; use it.
2. Add a function in `notes_app/services.py` (similar to `toggle_pin`).
3. Add a selector in `notes_app/selectors.py` to fetch archived notes.
4. Add a view in `notes_app/views.py`.
5. Add a URL in `notes_app/urls.py`.
6. Add a test in `notes_app/tests/test_services.py` or `test_views.py`.

**Criteria:**

- The business logic lives in `services.py` (not in the view).
- The read query lives in `selectors.py`.
- Access rules are tested (it is impossible to archive someone else's note).
- All existing tests pass.

---

## Level 3 — Advanced

Restore the async HTTP demo or fix the Docker production blockers.

### Option A: Async HTTP demo

Current state: `async_views.py`, `async_selectors.py`, `async_services.py` are absent from the working tree.

Implement an async view for the note list:
- Use `async def note_list_async(request)`.
- Wrap the ORM calls with `database_sync_to_async`.
- Register the URL.
- Write a test.

### Option B: Production Docker

1. Move `SECRET_KEY` into an environment variable.
2. Add a `DEBUG=False` mode with a correct `ALLOWED_HOSTS`.
3. Remove `DebugExceptionMiddleware` or restrict it with an `if settings.DEBUG` condition.
4. Replace `uvicorn --reload` with a production command.
5. Document all the changes.

**Criteria (both options):**

- The command is documented.
- Tests / checks pass, or the blocker is described honestly.
- Existing features do not break.
