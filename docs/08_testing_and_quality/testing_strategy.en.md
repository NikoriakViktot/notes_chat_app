# Testing Strategy

> The testing pyramid helps you choose the right level of verification.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to check that the understanding is not merely theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## Levels

- Unit: models, services, forms.
- Integration: views via the Django TestClient.
- Consumer: Channels WebsocketCommunicator.
- E2E: Selenium browser flows.

## Commands

```bash
python manage.py test notes_app.tests.test_models -v 2
python manage.py test notes_app.tests.test_services -v 2
python manage.py test notes_app.tests.test_views -v 2
python manage.py test notes_app.tests.test_consumers -v 2
```

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `notes_app/tests/test_models.py` | model tests |
| `notes_app/tests/test_consumers.py` | WebSocket consumer tests |
| `notes_app/tests/test_selenium.py` | browser tests |

## Practical task

Add one regression test before changing behavior.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [CI](ci.md).
