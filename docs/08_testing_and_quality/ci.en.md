# Continuous Integration

> CI runs checks automatically after a push or a pull request.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to check that the understanding is not merely theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## Workflow

`.github/workflows/django-tests.yml` has jobs for unit/integration/consumer tests and Selenium E2E.

The current commands require installed dependencies. If someone brings back the legacy async HTTP routes, the corresponding `async_views.py`, `async_selectors.py` and `async_services.py` must also be restored.

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `.github/workflows/django-tests.yml` | GitHub Actions config |

## Practical task

Explain which tests should run before a merge.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [Async and realtime](../09_async_and_realtime/README.md).
