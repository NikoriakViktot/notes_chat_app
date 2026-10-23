# Deployment Checklist

> A production checklist separates what is ready from what is merely desired.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to verify that the understanding is not only theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## Required before production

- `DEBUG=False`.
- Real `ALLOWED_HOSTS`.
- `SECRET_KEY` from the environment.
- PostgreSQL with a backup strategy.
- Redis for Channels.
- `collectstatic` and static serving.
- HTTPS and secure cookies.
- Application server without `--reload`.
- Reverse proxy.
- Logging and monitoring.

## Do not claim production-ready

Until the Docker mismatch and the hardcoded settings are fixed, the deployment docs should be a checklist, not a guarantee of a ready server.

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `notes_project/settings.py` | production-sensitive settings |
| `.env.example` | env template |

## Practical exercise

Make a list of the environment variables that settings.py is missing.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [Final project](../12_final_project/README.md).
